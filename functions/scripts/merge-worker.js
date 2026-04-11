#!/usr/bin/env node
'use strict';

const os = require('os');
const path = require('path');
const fs = require('fs/promises');
const admin = require('firebase-admin');
const { execFile } = require('child_process');
const { promisify } = require('util');

const execFileAsync = promisify(execFile);

const CLASS_RECORDINGS_COLLECTION = 'class_recordings';
const MERGE_CONCURRENCY = Math.max(
  1,
  Number.parseInt(process.env.MERGE_CONCURRENCY || '2', 10) || 2,
);
const MERGE_RECORDING_LIMIT = Math.max(
  1,
  Number.parseInt(process.env.MERGE_RECORDING_LIMIT || '20', 10) || 20,
);
const TILE_WIDTH = Math.max(
  320,
  Number.parseInt(process.env.MERGE_TILE_WIDTH || '640', 10) || 640,
);
const TILE_HEIGHT = Math.max(
  180,
  Number.parseInt(process.env.MERGE_TILE_HEIGHT || '360', 10) || 360,
);
const DELETE_SOURCE_TRACKS = ['1', 'true', 'yes', 'on'].includes(
  String(process.env.DELETE_SOURCE_TRACKS || '').trim().toLowerCase(),
);
const FFMPEG_BIN = process.env.FFMPEG_BIN || 'ffmpeg';

let db = null;

function normalizeStatus(raw) {
  const normalized = String(raw || '').trim().toLowerCase();
  return normalized || '';
}

function looksLikeStorageFilePath(rawPath) {
  const normalized = String(rawPath || '').trim().replace(/\/+$/, '');
  if (!normalized) return false;
  const lastSegment = normalized.split('/').pop() || '';
  return lastSegment.includes('.');
}

function normalizeTrackFiles(value) {
  if (!Array.isArray(value)) return [];

  const seen = new Set();
  const result = [];
  for (const item of value) {
    if (!item || typeof item !== 'object') continue;

    const identity = String(item.identity || '').trim();
    const filePath = String(item.file_path || item.filePath || '').trim();
    const status = normalizeStatus(item.status);
    const startedAtIso = String(item.started_at_iso || item.startedAtIso || '').trim();
    const dedupeKey = filePath || `${identity}::${startedAtIso || 'unknown'}`;
    if (!dedupeKey || seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);

    result.push({
      identity: identity || 'participant',
      filePath,
      status,
      startedAtIso: startedAtIso || null,
    });
  }

  return result;
}

function normalizeServiceAccountJson(raw) {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;

  const candidates = [trimmed];
  try {
    const decoded = Buffer.from(trimmed, 'base64').toString('utf8').trim();
    if (decoded) candidates.push(decoded);
  } catch (_) {}

  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      if (!parsed || typeof parsed !== 'object') continue;
      if (!parsed.client_email || !parsed.private_key) continue;
      return parsed;
    } catch (_) {}
  }

  return null;
}

function getDefaultBucketName() {
  const envBucket = String(process.env.LIVEKIT_RECORDING_GCP_BUCKET || '').trim();
  if (envBucket) return envBucket;

  try {
    const firebaseConfigRaw = process.env.FIREBASE_CONFIG;
    if (!firebaseConfigRaw) return '';
    const firebaseConfig = JSON.parse(firebaseConfigRaw);
    return String(firebaseConfig?.storageBucket || '').trim();
  } catch (_) {
    return '';
  }
}

function initializeAdmin() {
  if (admin.apps.length > 0) {
    db ||= admin.firestore();
    return;
  }

  const serviceAccount =
    normalizeServiceAccountJson(process.env.FIREBASE_SERVICE_ACCOUNT_JSON) ||
    normalizeServiceAccountJson(process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON);
  const storageBucket = getDefaultBucketName();

  const options = {};
  if (serviceAccount) {
    options.credential = admin.credential.cert(serviceAccount);
  }
  if (storageBucket) {
    options.storageBucket = storageBucket;
  }

  admin.initializeApp(options);
  db = admin.firestore();
}

function recordingBucket(recordingData) {
  const bucketName = String(recordingData?.bucket || getDefaultBucketName() || '').trim();
  return bucketName ? admin.storage().bucket(bucketName) : admin.storage().bucket();
}

function compositeOutputPath(recordingData) {
  const merged = String(recordingData?.merged_file_path || '').trim();
  if (merged) return merged;
  const basePath = String(recordingData?.file_path || '').trim().replace(/\/+$/, '');
  if (!basePath || looksLikeStorageFilePath(basePath)) {
    throw new Error('Recording file_path is not a mergeable directory prefix');
  }
  return `${basePath}/composite.mp4`;
}

async function listPendingRecordings() {
  const ref = db.collection(CLASS_RECORDINGS_COLLECTION);
  try {
    const snapshot = await ref
      .where('merge_status', '==', 'pending')
      .orderBy('updated_at', 'asc')
      .limit(MERGE_RECORDING_LIMIT)
      .get();
    return snapshot.docs;
  } catch (err) {
    console.warn('[merge-worker] Indexed query unavailable, falling back:', err?.message || err);
    const snapshot = await ref
      .where('merge_status', '==', 'pending')
      .limit(MERGE_RECORDING_LIMIT)
      .get();
    return snapshot.docs;
  }
}

async function syncShiftMergeState({ shiftId, segmentId, mergeStatus, mergedFilePath, error }) {
  if (!shiftId || !segmentId) return;

  const shiftRef = db.collection('teaching_shifts').doc(String(shiftId));
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(shiftRef);
    if (!snap.exists) return;

    const data = snap.data() || {};
    const current = data.livekit_recording || {};
    const currentSegmentId =
      current.current_segment_id || data.livekit_recording_current_segment_id || null;
    if (currentSegmentId !== segmentId) return;

    tx.update(shiftRef, {
      'livekit_recording.merge_status': mergeStatus || admin.firestore.FieldValue.delete(),
      'livekit_recording.merged_file_path': mergedFilePath || admin.firestore.FieldValue.delete(),
      'livekit_recording.updated_at': admin.firestore.FieldValue.serverTimestamp(),
      'livekit_recording.error': error || admin.firestore.FieldValue.delete(),
      livekit_recording_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      livekit_recording_error: error || admin.firestore.FieldValue.delete(),
    });
  });
}

async function ffmpeg(args) {
  try {
    await execFileAsync(FFMPEG_BIN, args, { maxBuffer: 16 * 1024 * 1024 });
  } catch (err) {
    const stderr = String(err?.stderr || err?.message || err).trim();
    throw new Error(stderr || 'ffmpeg failed');
  }
}

async function concatIdentityFiles(identity, files, tempDir) {
  if (files.length === 1) {
    return files[0];
  }

  const safeIdentity = identity.replace(/[^a-z0-9._-]+/gi, '_').slice(0, 80) || 'participant';
  const concatListPath = path.join(tempDir, `${safeIdentity}_concat.txt`);
  const outputPath = path.join(tempDir, `${safeIdentity}_stitched.mp4`);
  const concatList = files
    .map((filePath) => `file '${filePath.replace(/'/g, `'\\''`)}'`)
    .join('\n');
  await fs.writeFile(concatListPath, `${concatList}\n`, 'utf8');

  try {
    await ffmpeg([
      '-y',
      '-f', 'concat',
      '-safe', '0',
      '-i', concatListPath,
      '-c', 'copy',
      outputPath,
    ]);
  } catch (_) {
    await ffmpeg([
      '-y',
      '-f', 'concat',
      '-safe', '0',
      '-i', concatListPath,
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '23',
      '-c:a', 'aac',
      '-b:a', '128k',
      outputPath,
    ]);
  }

  return outputPath;
}

async function buildCompositeVideo(inputFiles, outputPath) {
  if (inputFiles.length === 0) {
    throw new Error('No input files available to merge');
  }

  if (inputFiles.length === 1) {
    await ffmpeg([
      '-y',
      '-i', inputFiles[0],
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '23',
      '-c:a', 'aac',
      '-b:a', '128k',
      outputPath,
    ]);
    return;
  }

  const args = ['-y'];
  for (const inputFile of inputFiles) {
    args.push('-i', inputFile);
  }

  const filterParts = [];
  const videoRefs = [];
  const audioRefs = [];
  for (let i = 0; i < inputFiles.length; i += 1) {
    filterParts.push(
      `[${i}:v]scale=${TILE_WIDTH}:${TILE_HEIGHT}:force_original_aspect_ratio=decrease,` +
      `pad=${TILE_WIDTH}:${TILE_HEIGHT}:(ow-iw)/2:(oh-ih)/2[v${i}]`,
    );
    videoRefs.push(`[v${i}]`);
    audioRefs.push(`[${i}:a]`);
  }

  const gridColumns = Math.ceil(Math.sqrt(inputFiles.length));
  const layout = Array.from({ length: inputFiles.length }, (_, index) => {
    const row = Math.floor(index / gridColumns);
    const col = index % gridColumns;
    return `${col * TILE_WIDTH}_${row * TILE_HEIGHT}`;
  }).join('|');

  filterParts.push(
    `${videoRefs.join('')}xstack=inputs=${inputFiles.length}:layout=${layout}:fill=black[v]`,
  );
  filterParts.push(
    `${audioRefs.join('')}amix=inputs=${inputFiles.length}:duration=longest:normalize=0[a]`,
  );

  args.push(
    '-filter_complex', filterParts.join(';'),
    '-map', '[v]',
    '-map', '[a]',
    '-c:v', 'libx264',
    '-preset', 'fast',
    '-crf', '23',
    '-c:a', 'aac',
    '-b:a', '128k',
    outputPath,
  );

  await ffmpeg(args);
}

async function withConcurrency(items, limit, worker) {
  const results = new Array(items.length);
  let index = 0;

  const runners = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const currentIndex = index;
      index += 1;
      if (currentIndex >= items.length) return;
      results[currentIndex] = await worker(items[currentIndex], currentIndex);
    }
  });

  await Promise.all(runners);
  return results;
}

async function trackFilesReady(bucket, trackFiles) {
  if (trackFiles.length === 0) return false;
  for (const item of trackFiles) {
    const [exists] = await bucket.file(item.filePath).exists();
    if (!exists) return false;
  }
  return true;
}

async function claimRecordingForMerge(recordingRef) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(recordingRef);
    if (!snap.exists) {
      return { claimed: false, data: null };
    }

    const data = snap.data() || {};
    if (normalizeStatus(data.merge_status) !== 'pending') {
      return { claimed: false, data: null };
    }

    tx.update(recordingRef, {
      merge_status: 'merging',
      error: admin.firestore.FieldValue.delete(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      claimed: true,
      data,
    };
  });
}

async function markMergeCompleted(recordingRef, recordingData, mergedFilePath) {
  await recordingRef.set({
    merge_status: 'completed',
    merged_file_path: mergedFilePath,
    merge_completed_at: admin.firestore.FieldValue.serverTimestamp(),
    merge_completed_at_iso: new Date().toISOString(),
    error: admin.firestore.FieldValue.delete(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await syncShiftMergeState({
    shiftId: recordingData.shift_id,
    segmentId: recordingData.segment_id,
    mergeStatus: 'completed',
    mergedFilePath,
    error: null,
  });
}

async function markMergeFailed(recordingRef, recordingData, error) {
  await recordingRef.set({
    merge_status: 'failed',
    error,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await syncShiftMergeState({
    shiftId: recordingData.shift_id,
    segmentId: recordingData.segment_id,
    mergeStatus: 'failed',
    mergedFilePath: null,
    error,
  });
}

async function resetMergePending(recordingRef, recordingData) {
  await recordingRef.set({
    merge_status: 'pending',
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await syncShiftMergeState({
    shiftId: recordingData.shift_id,
    segmentId: recordingData.segment_id,
    mergeStatus: 'pending',
    mergedFilePath: null,
    error: null,
  });
}

async function maybeDeleteSourceTracks(bucket, trackFiles) {
  if (!DELETE_SOURCE_TRACKS) return;

  await Promise.all(trackFiles.map(async (item) => {
    try {
      await bucket.file(item.filePath).delete({ ignoreNotFound: true });
    } catch (err) {
      console.warn('[merge-worker] Failed to delete source track:', item.filePath, err?.message || err);
    }
  }));
}

async function mergeRecording(doc) {
  const recordingRef = doc.ref;
  const recordingData = doc.data() || {};
  const bucket = recordingBucket(recordingData);
  const initialTrackFiles = normalizeTrackFiles(recordingData.track_files)
    .filter((item) => item.status !== 'failed')
    .filter((item) => item.filePath && looksLikeStorageFilePath(item.filePath));

  if (initialTrackFiles.length === 0 || !(await trackFilesReady(bucket, initialTrackFiles))) {
    return { recordingId: doc.id, status: 'skipped_missing_tracks' };
  }

  const claim = await claimRecordingForMerge(recordingRef);
  if (!claim.claimed) {
    return { recordingId: doc.id, status: 'skipped_claimed_elsewhere' };
  }

  const freshData = claim.data || recordingData;
  const trackFiles = normalizeTrackFiles(freshData.track_files)
    .filter((item) => item.status !== 'failed')
    .filter((item) => item.filePath && looksLikeStorageFilePath(item.filePath));
  if (trackFiles.length === 0 || !(await trackFilesReady(bucket, trackFiles))) {
    await resetMergePending(recordingRef, freshData);
    return { recordingId: doc.id, status: 'skipped_new_tracks_pending' };
  }

  const mergedFilePath = compositeOutputPath(freshData);
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'recording-merge-'));

  try {
    const grouped = new Map();
    for (const item of trackFiles.sort((a, b) => {
      const aMs = Date.parse(a.startedAtIso || '') || 0;
      const bMs = Date.parse(b.startedAtIso || '') || 0;
      if (aMs !== bMs) return aMs - bMs;
      return a.filePath.localeCompare(b.filePath);
    })) {
      if (!grouped.has(item.identity)) {
        grouped.set(item.identity, []);
      }
      grouped.get(item.identity).push(item);
    }

    const perIdentityFiles = [];
    for (const [identity, files] of grouped.entries()) {
      const localDownloads = [];
      for (let i = 0; i < files.length; i += 1) {
        const localPath = path.join(
          tempDir,
          `${identity.replace(/[^a-z0-9._-]+/gi, '_') || 'participant'}_${i}.mp4`,
        );
        await bucket.file(files[i].filePath).download({ destination: localPath });
        localDownloads.push(localPath);
      }
      perIdentityFiles.push(await concatIdentityFiles(identity, localDownloads, tempDir));
    }

    const compositeLocalPath = path.join(tempDir, 'composite.mp4');
    await buildCompositeVideo(perIdentityFiles, compositeLocalPath);
    await bucket.upload(compositeLocalPath, {
      destination: mergedFilePath,
      metadata: { contentType: 'video/mp4' },
      resumable: false,
    });

    await markMergeCompleted(recordingRef, freshData, mergedFilePath);
    await maybeDeleteSourceTracks(bucket, trackFiles);

    return {
      recordingId: doc.id,
      status: 'completed',
      mergedFilePath,
    };
  } catch (err) {
    const message = `${err?.message || String(err || 'Merge failed')}`.trim().slice(0, 500);
    await markMergeFailed(recordingRef, freshData, message);
    return {
      recordingId: doc.id,
      status: 'failed',
      error: message,
    };
  } finally {
    await fs.rm(tempDir, { recursive: true, force: true });
  }
}

async function main() {
  initializeAdmin();
  db ||= admin.firestore();

  const docs = await listPendingRecordings();
  if (docs.length === 0) {
    console.log('[merge-worker] No pending recordings found');
    return;
  }

  const results = await withConcurrency(docs, MERGE_CONCURRENCY, mergeRecording);
  const summary = results.reduce((acc, item) => {
    acc[item.status] = (acc[item.status] || 0) + 1;
    return acc;
  }, {});

  console.log('[merge-worker] Completed run', {
    processed: results.length,
    summary,
  });
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('[merge-worker] Fatal error:', err);
    process.exit(1);
  });
