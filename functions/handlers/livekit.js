/**
 * LiveKit Cloud Function Handlers
 * 
 * Provides callable functions for LiveKit video integration.
 */

const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const {
  RoomServiceClient,
  TrackType,
  EgressClient,
  EgressStatus,
  EncodedFileOutput,
  EncodedFileType,
  GCPUpload,
} = require('livekit-server-sdk');
const { getLiveKitConfig, isLiveKitConfigured } = require('../services/livekit/config');
const { generateTokenForRole } = require('../services/livekit/token');

const CLASS_RECORDINGS_COLLECTION = 'class_recordings';

/**
 * Helper: Get user display name from Firestore
 */
const getUserDisplayName = async (uid) => {
  if (!uid) return 'Participant';
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return 'Participant';
    const data = userDoc.data();
    const firstName = data.first_name || data.firstName || '';
    const lastName = data.last_name || data.lastName || '';
    const fullName = [firstName, lastName].filter(Boolean).join(' ');
    return fullName || data['e-mail'] || data.email || 'Participant';
  } catch (_) {
    return 'Participant';
  }
};

/**
 * Helper: Check if user is a parent of any student in the given list
 */
const isUserParentOfStudent = async (uid, studentIds) => {
  if (!uid || !Array.isArray(studentIds) || studentIds.length === 0) return false;
  try {
    for (const studentId of studentIds) {
      const studentDoc = await admin.firestore().collection('users').doc(studentId).get();
      if (!studentDoc.exists) continue;
      const data = studentDoc.data();
      const guardianIds = data.guardian_ids || data.guardianIds || [];
      if (Array.isArray(guardianIds) && guardianIds.includes(uid)) return true;
    }
    return false;
  } catch (_) {
    return false;
  }
};

/**
 * Helper: Check if user is admin
 */
const isUserAdmin = async (uid) => {
  if (!uid) return false;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    const data = userDoc.data();
    return (
      data.role === 'admin' ||
      data.role === 'super_admin' ||
      data.user_type === 'admin' ||
      data.user_type === 'super_admin' ||
      data.userType === 'admin' ||
      data.userType === 'super_admin' ||
      data.is_admin === true ||
      data.isAdmin === true ||
      data.is_super_admin === true ||
      data.isSuperAdmin === true ||
      data.is_admin_teacher === true
    );
  } catch (_) {
    return false;
  }
};

/**
 * Helper: Convert ws/wss LiveKit URL to http/https for server APIs.
 *
 * LiveKit clients connect via ws/wss, but RoomServiceClient expects http(s).
 */
const normalizeLiveKitHostForServerApi = (url) => {
  if (!url || typeof url !== 'string') return url;
  if (url.startsWith('wss://')) return `https://${url.slice('wss://'.length)}`;
  if (url.startsWith('ws://')) return `http://${url.slice('ws://'.length)}`;
  return url;
};

/**
 * Helper: Load a shift and validate LiveKit provider.
 */
const getLiveKitShiftOrThrow = async (shiftId) => {
  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
  if (!shiftDoc.exists) {
    throw new HttpsError('not-found', 'Shift not found');
  }

  const shiftData = shiftDoc.data() || {};

  const normalizeProvider = (raw) => {
    if (typeof raw !== 'string') return null;
    const normalized = raw.trim().toLowerCase();
    if (!normalized) return null;
    if (normalized === 'livekit' || normalized === 'zoom') return normalized;
    return null;
  };

  const hasZoomData = () => {
    const zoomMeetingId = shiftData.zoom_meeting_id;
    const hubMeetingId = shiftData.hubMeetingId || shiftData.hub_meeting_id;
    const encryptedJoinUrl = shiftData.zoom_encrypted_join_url || shiftData.zoomEncryptedJoinUrl;
    return (
      (typeof zoomMeetingId === 'string' && zoomMeetingId.trim().length > 0) ||
      (typeof hubMeetingId === 'string' && hubMeetingId.trim().length > 0) ||
      (typeof encryptedJoinUrl === 'string' && encryptedJoinUrl.trim().length > 0)
    );
  };

  const inferredProvider = () => {
    const explicit =
      normalizeProvider(shiftData.video_provider) || normalizeProvider(shiftData.videoProvider);
    if (explicit) return explicit;

    if (hasZoomData()) return 'zoom';

    const category = typeof shiftData.shift_category === 'string' ? shiftData.shift_category : 'teaching';
    if (category === 'teaching') return 'livekit';

    return 'zoom';
  };

  const videoProvider = inferredProvider();
  if (videoProvider !== 'livekit') {
    throw new HttpsError('failed-precondition', 'This shift does not use LiveKit video');
  }

  const teacherId = shiftData.teacher_id;
  const rawStudentIds = shiftData.student_ids;
  const studentIds = Array.isArray(rawStudentIds) ? rawStudentIds : [];
  const roomName = shiftData.livekit_room_name || `shift_${shiftId}`;

  return { shiftData, teacherId, studentIds, roomName, shiftRef: shiftDoc.ref };
};

/**
 * Helper: Enforce that caller is a moderator (teacher or admin).
 */
const assertLiveKitModeratorOrThrow = async ({
  uid,
  teacherId,
  isAdmin,
}) => {
  const isTeacher = uid === teacherId;
  if (!isTeacher && !isAdmin) {
    throw new HttpsError('permission-denied', 'Only teachers/admins can manage this class');
  }
  return { isTeacher };
};

const _parseBooleanEnv = (raw, fallback = false) => {
  if (raw === undefined || raw === null) return fallback;
  const normalized = String(raw).trim().toLowerCase();
  if (!normalized) return fallback;
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
};

const _isLiveKitNotFoundError = (err) => {
  const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim().toLowerCase();
  const code = err?.code;
  const status = err?.status;
  return (
    code === 5 ||
    code === 'not_found' ||
    status === 404 ||
    rawMessage.includes('not found') ||
    rawMessage.includes('does not exist') ||
    rawMessage.includes('room does not exist')
  );
};

const _isLiveKitAlreadyExistsError = (err) => {
  const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim().toLowerCase();
  const code = err?.code;
  const status = err?.status;
  return (
    code === 6 ||
    code === 'already_exists' ||
    status === 409 ||
    rawMessage.includes('already exists') ||
    rawMessage.includes('duplicate')
  );
};

const _normalizeServiceAccountJson = (raw) => {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;

  const candidates = [trimmed];
  try {
    const decoded = Buffer.from(trimmed, 'base64').toString('utf8').trim();
    if (decoded) {
      candidates.push(decoded);
    }
  } catch (_) {}

  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      if (!parsed || typeof parsed !== 'object') continue;
      if (!parsed.client_email || !parsed.private_key) continue;
      return JSON.stringify(parsed);
    } catch (_) {}
  }

  return null;
};

const _safePathSegment = (raw, fallback = 'unknown') => {
  const cleaned = String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/^-+/, '')
    .replace(/-+$/, '')
    .slice(0, 80);
  return cleaned || fallback;
};

const _toJsDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value?.toDate === 'function') {
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
};

const _normalizeRecordingStatus = (raw) => {
  const normalized = String(raw || '').trim().toLowerCase();
  if (!normalized) return '';
  return normalized;
};

const _isEgressInProgress = (status) => (
  status === EgressStatus.EGRESS_STARTING ||
  status === EgressStatus.EGRESS_ACTIVE ||
  status === EgressStatus.EGRESS_ENDING
);

const _getEgressInfoById = async (egressClient, egressId) => {
  if (!egressId || typeof egressId !== 'string') return null;
  try {
    const items = await egressClient.listEgress({ egressId });
    if (!Array.isArray(items) || items.length === 0) return null;
    return items[0] || null;
  } catch (err) {
    if (_isLiveKitNotFoundError(err)) return null;
    throw err;
  }
};

const _buildRecordingFilePath = ({ shiftId, roomName, prefix }) => {
  const now = new Date();
  const year = String(now.getUTCFullYear());
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  const day = String(now.getUTCDate()).padStart(2, '0');
  const timestamp = now.toISOString().replace(/[:.]/g, '-');
  const safeShiftId = _safePathSegment(shiftId, 'shift');
  const safeRoom = _safePathSegment(roomName, 'room');
  return `${prefix}/${year}/${month}/${day}/${safeShiftId}/${safeRoom}_${timestamp}.mp4`;
};

const _normalizeUserRoleString = (raw) => {
  if (typeof raw !== 'string') return '';
  return raw.trim().toLowerCase();
};

const _extractUserRole = (userData) => {
  if (!userData || typeof userData !== 'object') return '';
  return _normalizeUserRoleString(
    userData.user_type || userData.userType || userData.role,
  );
};

const _extractUserAvailableRoles = (userData) => {
  if (!userData || typeof userData !== 'object') return [];

  const roles = new Set();
  const primaryRole = _extractUserRole(userData);
  if (primaryRole) roles.add(primaryRole);

  // Keep parity with app-side role switching rules.
  if (primaryRole === 'admin' || primaryRole === 'super_admin') {
    roles.add('teacher');
  }

  const isAdminTeacher =
    userData.is_admin_teacher === true || userData.isAdminTeacher === true;
  if (primaryRole === 'teacher' && isAdminTeacher) {
    roles.add('admin');
  }

  const secondaryRoles = Array.isArray(userData.secondary_roles)
    ? userData.secondary_roles
    : (Array.isArray(userData.secondaryRoles) ? userData.secondaryRoles : []);
  for (const rawRole of secondaryRoles) {
    const normalized = _normalizeUserRoleString(rawRole);
    if (normalized) roles.add(normalized);
  }

  return Array.from(roles);
};

const _resolveEffectiveRole = ({ userData, requestedRole }) => {
  const availableRoles = _extractUserAvailableRoles(userData);
  if (availableRoles.length === 0) return '';

  const requested = _normalizeUserRoleString(requestedRole);
  if (!requested) {
    // No explicit override from the client: use primary/current role.
    return availableRoles[0];
  }

  if (!availableRoles.includes(requested)) {
    return '';
  }

  return requested;
};

const _toIsoString = (value) => {
  const date = _toJsDate(value);
  return date ? date.toISOString() : null;
};

const _toFirestoreTimestamp = (value) => {
  const date = _toJsDate(value);
  if (!date) return null;
  if (Number.isNaN(date.getTime())) return null;
  return admin.firestore.Timestamp.fromDate(date);
};

const _normalizeStringArray = (value) => {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const result = [];
  for (const item of value) {
    if (typeof item !== 'string') continue;
    const trimmed = item.trim();
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    result.push(trimmed);
  }
  return result;
};

const _recordingDocId = (shiftId, segmentId) => {
  const safeShift = _safePathSegment(shiftId, 'shift');
  const safeSegment = _safePathSegment(segmentId, 'segment');
  return `${safeShift}_${safeSegment}`;
};

const _upsertClassRecordingDoc = async ({
  shiftId,
  shiftData,
  teacherId,
  studentIds,
  roomName,
  segmentId,
  filePath,
  bucket,
  layout,
  status,
  egressId,
  error,
  requestedBy,
  requestedAtIso,
  startedAtIso,
  failedAtIso,
}) => {
  if (!shiftId || !segmentId || !filePath) return null;

  const docId = _recordingDocId(shiftId, segmentId);
  const recordingRef = admin.firestore().collection(CLASS_RECORDINGS_COLLECTION).doc(docId);

  const shiftStartTs = _toFirestoreTimestamp(shiftData?.shift_start);
  const shiftEndTs = _toFirestoreTimestamp(shiftData?.shift_end);
  const requestedAtTs = _toFirestoreTimestamp(requestedAtIso);
  const startedAtTs = _toFirestoreTimestamp(startedAtIso);
  const failedAtTs = _toFirestoreTimestamp(failedAtIso);
  const sortTs = startedAtTs || requestedAtTs || shiftStartTs || admin.firestore.Timestamp.now();
  const sortIso =
    startedAtIso ||
    requestedAtIso ||
    _toIsoString(shiftData?.shift_start) ||
    new Date().toISOString();

  await recordingRef.set(
    {
      recording_id: docId,
      shift_id: shiftId,
      segment_id: segmentId,
      room_name: roomName || shiftData?.livekit_room_name || `shift_${shiftId}`,
      shift_name: _deriveShiftDisplayName(shiftData),
      subject_name:
        shiftData?.subject_display_name ||
        shiftData?.subjectDisplayName ||
        shiftData?.subject_name ||
        '',
      teacher_id: teacherId || null,
      teacher_name: shiftData?.teacher_name || shiftData?.teacherName || '',
      student_ids: _normalizeStringArray(studentIds),
      shift_start: shiftStartTs || null,
      shift_end: shiftEndTs || null,
      file_path: filePath,
      bucket: bucket || null,
      layout: layout || null,
      status: status || 'starting',
      egress_id: egressId || null,
      error: error || admin.firestore.FieldValue.delete(),
      requested_by: requestedBy || null,
      requested_at_iso: requestedAtIso || null,
      requested_at: requestedAtTs || null,
      started_at_iso: startedAtIso || null,
      started_at: startedAtTs || null,
      failed_at_iso: failedAtIso || null,
      failed_at: failedAtTs || null,
      sort_iso: sortIso,
      sort_ts: sortTs,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return docId;
};

const _sortRecordingsNewestFirst = (a, b) => {
  const aMs =
    Date.parse(a.startedAtIso || '') ||
    Date.parse(a.requestedAtIso || '') ||
    Date.parse(a.shiftStartIso || '') ||
    Date.parse(a.updatedAtIso || '') ||
    0;
  const bMs =
    Date.parse(b.startedAtIso || '') ||
    Date.parse(b.requestedAtIso || '') ||
    Date.parse(b.shiftStartIso || '') ||
    Date.parse(b.updatedAtIso || '') ||
    0;
  if (aMs !== bMs) return bMs - aMs;
  return String(b.recordingId || '').localeCompare(String(a.recordingId || ''));
};

const _getLiveKitRecordingConfig = () => {
  const enabled = _parseBooleanEnv(process.env.LIVEKIT_RECORDING_ENABLED, true);
  if (!enabled) {
    return { enabled: false, reason: 'LIVEKIT_RECORDING_ENABLED=false' };
  }

  let bucket = process.env.LIVEKIT_RECORDING_GCP_BUCKET?.trim();
  if (!bucket) {
    try {
      const firebaseConfigRaw = process.env.FIREBASE_CONFIG;
      if (firebaseConfigRaw) {
        const firebaseConfig = JSON.parse(firebaseConfigRaw);
        const storageBucket = firebaseConfig?.storageBucket;
        if (typeof storageBucket === 'string' && storageBucket.trim()) {
          bucket = storageBucket.trim();
        }
      }
    } catch (_) {}
  }
  const credentialsRaw = process.env.LIVEKIT_RECORDING_GCP_CREDENTIALS_JSON;
  const credentialsJson = _normalizeServiceAccountJson(credentialsRaw);
  const layout = process.env.LIVEKIT_RECORDING_LAYOUT?.trim() || 'grid';
  const prefixRaw = process.env.LIVEKIT_RECORDING_FILE_PREFIX?.trim() || 'class-recordings';
  const prefix = prefixRaw.replace(/^\/+/, '').replace(/\/+$/, '');
  const hasBucket = Boolean(bucket);
  const hasCredentials = Boolean(credentialsJson);

  if (!hasBucket || !hasCredentials) {
    const missing = [];
    if (!hasBucket) {
      missing.push('LIVEKIT_RECORDING_GCP_BUCKET (or FIREBASE_CONFIG.storageBucket)');
    }
    if (!hasCredentials) {
      missing.push('LIVEKIT_RECORDING_GCP_CREDENTIALS_JSON');
    }
    return {
      enabled: false,
      reason: `Recording storage not configured: missing ${missing.join(', ')}`,
    };
  }

  return {
    enabled: true,
    mode: 'gcp',
    bucket,
    credentialsJson,
    layout,
    prefix,
  };
};

/**
 * Callable function: Ensure class recording is running for a LiveKit shift.
 *
 * This is intended to be called automatically by the app when any authorized
 * class participant connects to the room.
 */
const ensureLiveKitShiftRecording = onCall({
  secrets: [
    'LIVEKIT_URL',
    'LIVEKIT_API_KEY',
    'LIVEKIT_API_SECRET',
    'LIVEKIT_RECORDING_GCP_BUCKET',
    'LIVEKIT_RECORDING_GCP_CREDENTIALS_JSON',
  ],
}, async (request) => {
  const uid = request.auth?.uid;
  const shiftId = request.data?.shiftId;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }

  const recordingConfig = _getLiveKitRecordingConfig();
  if (!recordingConfig.enabled) {
    return {
      success: true,
      recordingEnabled: false,
      recordingStarted: false,
      reason: recordingConfig.reason,
    };
  }

  const { shiftData, teacherId, studentIds, roomName, shiftRef } = await getLiveKitShiftOrThrow(shiftId);
  const isTeacher = uid === teacherId;
  const isStudent = studentIds.includes(uid);
  const isAdmin = await isUserAdmin(uid);
  const isParent = !isTeacher && !isStudent && !isAdmin
    ? await isUserParentOfStudent(uid, studentIds)
    : false;

  if (!isTeacher && !isStudent && !isAdmin && !isParent) {
    throw new HttpsError('permission-denied', 'You are not allowed to join this class');
  }

  if (shiftData.livekit_recording_disabled === true) {
    return {
      success: true,
      recordingEnabled: false,
      recordingStarted: false,
      reason: 'Recording disabled for this class',
    };
  }

  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);
  const nowMs = Date.now();
  const shiftStartMs = shiftStart.getTime();
  const shiftEndMs = shiftEnd.getTime();
  const allowedStartMs = Number.isFinite(shiftStartMs)
    ? shiftStartMs - 10 * 60 * 1000
    : nowMs - 10 * 60 * 1000;
  const allowedEndMs = Number.isFinite(shiftEndMs)
    ? shiftEndMs + 10 * 60 * 1000
    : nowMs + 2 * 60 * 60 * 1000;

  if (nowMs < allowedStartMs || nowMs > allowedEndMs) {
    return {
      success: true,
      recordingEnabled: true,
      recordingStarted: false,
      reason: 'Outside recording window',
    };
  }

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);
  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);
  const egressClient = new EgressClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  const existingRecording = shiftData.livekit_recording || {};
  const existingStatus = _normalizeRecordingStatus(
    existingRecording.status || shiftData.livekit_recording_status,
  );
  const existingEgressId =
    existingRecording.egress_id || shiftData.livekit_recording_egress_id || null;
  let existingEgressInProgress = false;

  if (existingEgressId) {
    const existingEgressInfo = await _getEgressInfoById(egressClient, existingEgressId);
    if (existingEgressInfo && _isEgressInProgress(existingEgressInfo.status)) {
      existingEgressInProgress = true;
      return {
        success: true,
        recordingEnabled: true,
        recordingStarted: false,
        alreadyRecording: true,
        status: existingStatus || 'active',
        egressId: existingEgressId,
        filePath:
          existingRecording.file_path || shiftData.livekit_recording_file_path || null,
      };
    }
  }

  const filePath = _buildRecordingFilePath({
    shiftId,
    roomName,
    prefix: recordingConfig.prefix,
  });
  const requestedAtIso = new Date().toISOString();

  const decision = await admin.firestore().runTransaction(async (tx) => {
    const currentSnap = await tx.get(shiftRef);
    if (!currentSnap.exists) {
      throw new HttpsError('not-found', 'Shift not found');
    }

    const currentData = currentSnap.data() || {};
    const existing = currentData.livekit_recording || {};
    const status = _normalizeRecordingStatus(
      existing.status || currentData.livekit_recording_status,
    );
    const egressId = existing.egress_id || currentData.livekit_recording_egress_id || null;
    const existingFilePath =
      existing.file_path || currentData.livekit_recording_file_path || null;
    const lastRequestedAt = _toJsDate(
      existing.requested_at || currentData.livekit_recording_requested_at,
    );
    const requestedAgeMs = lastRequestedAt
      ? Math.max(0, Date.now() - lastRequestedAt.getTime())
      : null;

    if (status === 'starting' && requestedAgeMs != null && requestedAgeMs < 120000) {
      return {
        shouldStart: false,
        status: 'starting',
        egressId,
        filePath: existingFilePath,
      };
    }

    if (
      status === 'active' &&
      existingEgressInProgress &&
      existingEgressId &&
      egressId === existingEgressId
    ) {
      return {
        shouldStart: false,
        status: 'active',
        egressId,
        filePath: existingFilePath,
      };
    }

    const previousSegments = Array.isArray(currentData.livekit_recording_segments)
      ? currentData.livekit_recording_segments
      : [];
    const segmentId = `seg_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const nextSegments = [
      ...previousSegments,
      {
        segment_id: segmentId,
        file_path: filePath,
        requested_by: uid,
        requested_at_iso: requestedAtIso,
        status: 'starting',
      },
    ];

    tx.update(shiftRef, {
      'livekit_recording.status': 'starting',
      'livekit_recording.room_name': roomName,
      'livekit_recording.file_path': filePath,
      'livekit_recording.current_segment_id': segmentId,
      'livekit_recording.requested_by': uid,
      'livekit_recording.requested_at': admin.firestore.FieldValue.serverTimestamp(),
      'livekit_recording.updated_at': admin.firestore.FieldValue.serverTimestamp(),
      'livekit_recording.error': admin.firestore.FieldValue.delete(),
      livekit_recording_status: 'starting',
      livekit_recording_file_path: filePath,
      livekit_recording_current_segment_id: segmentId,
      livekit_recording_requested_by: uid,
      livekit_recording_requested_at: admin.firestore.FieldValue.serverTimestamp(),
      livekit_recording_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      livekit_recording_error: admin.firestore.FieldValue.delete(),
      livekit_recording_segments: nextSegments,
    });

    return {
      shouldStart: true,
      status: 'starting',
      egressId: null,
      segmentId,
      filePath,
    };
  });

  if (!decision.shouldStart) {
    return {
      success: true,
      recordingEnabled: true,
      recordingStarted: false,
      alreadyRecording: true,
      status: decision.status,
      egressId: decision.egressId || null,
      filePath: decision.filePath || null,
    };
  }

  await _upsertClassRecordingDoc({
    shiftId,
    shiftData,
    teacherId,
    studentIds,
    roomName,
    segmentId: decision.segmentId,
    filePath: decision.filePath,
    bucket: recordingConfig.bucket,
    layout: recordingConfig.layout,
    status: 'starting',
    requestedBy: uid,
    requestedAtIso,
  });

  try {
    try {
      await roomService.createRoom({
        name: roomName,
        emptyTimeout: 10 * 60,
        departureTimeout: 2 * 60,
      });
    } catch (createErr) {
      if (!_isLiveKitAlreadyExistsError(createErr)) {
        throw createErr;
      }
    }

    const output = new EncodedFileOutput({
      fileType: EncodedFileType.MP4,
      filepath: decision.filePath,
      output: {
        case: 'gcp',
        value: new GCPUpload({
          bucket: recordingConfig.bucket,
          credentials: recordingConfig.credentialsJson,
        }),
      },
    });

    const egressInfo = await egressClient.startRoomCompositeEgress(
      roomName,
      { file: output },
      { layout: recordingConfig.layout },
    );

    const startedAtIso = new Date().toISOString();
    await admin.firestore().runTransaction(async (tx) => {
      const currentSnap = await tx.get(shiftRef);
      const currentData = currentSnap.data() || {};
      const segments = Array.isArray(currentData.livekit_recording_segments)
        ? currentData.livekit_recording_segments
        : [];
      const segmentId = decision.segmentId;
      const nextSegments = segments.map((segment) => {
        if (!segmentId || segment?.segment_id !== segmentId) return segment;
        return {
          ...segment,
          status: 'active',
          egress_id: egressInfo.egressId || null,
          started_at_iso: startedAtIso,
        };
      });

      tx.update(shiftRef, {
        'livekit_recording.status': 'active',
        'livekit_recording.room_name': roomName,
        'livekit_recording.layout': recordingConfig.layout,
        'livekit_recording.storage_mode': recordingConfig.mode,
        'livekit_recording.bucket': recordingConfig.bucket || admin.firestore.FieldValue.delete(),
        'livekit_recording.egress_id': egressInfo.egressId || null,
        'livekit_recording.started_at': admin.firestore.FieldValue.serverTimestamp(),
        'livekit_recording.started_by': uid,
        'livekit_recording.updated_at': admin.firestore.FieldValue.serverTimestamp(),
        'livekit_recording.error': admin.firestore.FieldValue.delete(),
        livekit_recording_status: 'active',
        livekit_recording_egress_id: egressInfo.egressId || null,
        livekit_recording_started_at: admin.firestore.FieldValue.serverTimestamp(),
        livekit_recording_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        livekit_recording_error: admin.firestore.FieldValue.delete(),
        livekit_recording_segments: nextSegments,
      });
    });

    await _upsertClassRecordingDoc({
      shiftId,
      shiftData,
      teacherId,
      studentIds,
      roomName,
      segmentId: decision.segmentId,
      filePath: decision.filePath,
      bucket: recordingConfig.bucket,
      layout: recordingConfig.layout,
      status: 'active',
      egressId: egressInfo.egressId || null,
      requestedBy: uid,
      requestedAtIso,
      startedAtIso,
    });

    return {
      success: true,
      recordingEnabled: true,
      recordingStarted: true,
      status: 'active',
      egressId: egressInfo.egressId || null,
      filePath: decision.filePath,
    };
  } catch (err) {
    const message = `${err?.message || String(err)}`.trim().slice(0, 500);
    console.error('[LiveKit] Failed to start shift recording:', err);
    const failedAtIso = new Date().toISOString();

    await admin.firestore().runTransaction(async (tx) => {
      const currentSnap = await tx.get(shiftRef);
      const currentData = currentSnap.data() || {};
      const segments = Array.isArray(currentData.livekit_recording_segments)
        ? currentData.livekit_recording_segments
        : [];
      const segmentId = decision.segmentId;
      const nextSegments = segments.map((segment) => {
        if (!segmentId || segment?.segment_id !== segmentId) return segment;
        return {
          ...segment,
          status: 'failed',
          error: message,
          failed_at_iso: failedAtIso,
        };
      });

      tx.update(shiftRef, {
        'livekit_recording.status': 'failed',
        'livekit_recording.error': message,
        'livekit_recording.failed_at': admin.firestore.FieldValue.serverTimestamp(),
        'livekit_recording.updated_at': admin.firestore.FieldValue.serverTimestamp(),
        livekit_recording_status: 'failed',
        livekit_recording_error: message,
        livekit_recording_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        livekit_recording_segments: nextSegments,
      });
    });

    await _upsertClassRecordingDoc({
      shiftId,
      shiftData,
      teacherId,
      studentIds,
      roomName,
      segmentId: decision.segmentId,
      filePath: decision.filePath,
      bucket: recordingConfig.bucket,
      layout: recordingConfig.layout,
      status: 'failed',
      error: message,
      requestedBy: uid,
      requestedAtIso,
      failedAtIso,
    });

    return {
      success: false,
      recordingEnabled: true,
      recordingStarted: false,
      retryable: _isLiveKitNotFoundError(err),
      error: message || 'Failed to start class recording',
    };
  }
});

/**
 * Callable function: Get LiveKit join token for a shift
 * 
 * @param {Object} request - Firebase callable request
 * @param {Object} request.data - Request data
 * @param {string} request.data.shiftId - The shift ID to join
 * @returns {Object} LiveKit connection details
 */
const getLiveKitJoinToken = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  // Require authentication
  if (!uid) {
    console.log('[LiveKit] Unauthenticated request');
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  // Validate shiftId
  if (!shiftId || typeof shiftId !== 'string') {
    console.log('[LiveKit] Invalid shiftId from uid:', uid);
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }

  // Check LiveKit configuration
  if (!isLiveKitConfigured()) {
    console.error('[LiveKit] LiveKit not configured');
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }

  // Get shift document
  const { shiftData, teacherId, studentIds, roomName } = await getLiveKitShiftOrThrow(shiftId);

  // Authorization check
  const isTeacher = uid === teacherId;
  const isStudent = studentIds.includes(uid);
  const isAdmin = await isUserAdmin(uid);
  const isParent = !isTeacher && !isStudent && !isAdmin
    ? await isUserParentOfStudent(uid, studentIds)
    : false;

  if (!isTeacher && !isStudent && !isAdmin && !isParent) {
    console.log('[LiveKit] Unauthorized access attempt. uid:', uid, 'shiftId:', shiftId);
    throw new HttpsError('permission-denied', 'You are not allowed to join this class');
  }

  // Determine user role
  let userRole;
  if (isAdmin) {
    userRole = 'admin';
  } else if (isTeacher) {
    userRole = 'teacher';
  } else if (isParent) {
    userRole = 'parent';
  } else {
    userRole = 'student';
  }

  const roomLocked = shiftData.livekit_locked === true;
  if (roomLocked && (userRole === 'student' || userRole === 'parent')) {
    throw new HttpsError('failed-precondition', 'This class is locked by the teacher.');
  }

  // Parse shift times for time window check
  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  const now = new Date();
  const nowMs = now.getTime();
  const shiftStartMs = shiftStart.getTime();
  const shiftEndMs = shiftEnd.getTime();
  const allowedStartMs = Number.isFinite(shiftStartMs)
    ? shiftStartMs - 10 * 60 * 1000
    : nowMs - 10 * 60 * 1000;
  const allowedEndMs = Number.isFinite(shiftEndMs)
    ? shiftEndMs + 10 * 60 * 1000
    : nowMs + 2 * 60 * 60 * 1000;

  // Time window check (same as Zoom)
  if (nowMs < allowedStartMs) {
    const minutesUntil = Math.ceil((allowedStartMs - nowMs) / 60000);
    console.log('[LiveKit] Too early. uid:', uid, 'shiftId:', shiftId, 'minutesUntil:', minutesUntil);
    throw new HttpsError(
      'failed-precondition',
      `You can join 10 minutes before the class starts. Please wait ${minutesUntil} minute(s).`
    );
  }

  if (nowMs > allowedEndMs) {
    console.log('[LiveKit] Too late. uid:', uid, 'shiftId:', shiftId);
    throw new HttpsError('failed-precondition', 'The class window has ended');
  }

  // Get user details
  const displayName = await getUserDisplayName(uid);

  // Token TTL: from now until 15 minutes after shift end
  const ttlSeconds = Math.max(
    600,
    Math.floor((allowedEndMs + 5 * 60 * 1000 - nowMs) / 1000),
  );

  // Generate LiveKit token
  const livekitConfig = getLiveKitConfig();
  
  // Debug: Log config (without exposing secret)
  console.log('[LiveKit] Using config - URL:', livekitConfig.url);
  console.log('[LiveKit] Using config - API Key:', livekitConfig.apiKey);
  console.log('[LiveKit] Using config - API Secret length:', livekitConfig.apiSecret?.length || 0);
  
  const token = await generateTokenForRole(
    roomName,
    userRole,
    uid,
    displayName,
    {},
    ttlSeconds
  );
  
  // Debug: Log token info
  console.log('[LiveKit] Generated token length:', token?.length || 0);
  if (token) {
    const tokenParts = token.split('.');
    if (tokenParts.length >= 2) {
      try {
        const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
        console.log('[LiveKit] Token payload - sub:', payload.sub);
        console.log('[LiveKit] Token payload - iss:', payload.iss);
        console.log('[LiveKit] Token payload - room:', payload.video?.room);
        console.log('[LiveKit] Token payload - exp:', new Date(payload.exp * 1000).toISOString());
      } catch (e) {
        console.warn('[LiveKit] Could not parse token payload:', e.message);
      }
    }
  }

  // Update last token issued timestamp (optional tracking)
  try {
    await admin.firestore().collection('teaching_shifts').doc(shiftId).update({
      livekit_last_token_issued_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (updateErr) {
    console.warn('[LiveKit] Failed to update token timestamp:', updateErr.message);
    // Non-blocking - continue even if update fails
  }

  console.log('[LiveKit] Token generated. uid:', uid, 'shiftId:', shiftId, 'role:', userRole, 'room:', roomName);

  return {
    success: true,
    livekitUrl: livekitConfig.url,
    token: token,
    roomName: roomName,
    userRole: userRole,
    displayName: displayName,
    expiresInSeconds: ttlSeconds,
    roomLocked,
    joinWindow: {
      allowedStartIso: new Date(allowedStartMs).toISOString(),
      allowedEndIso: new Date(allowedEndMs).toISOString(),
    },
  };
});

const _deriveShiftDisplayName = (shiftData) => {
  if (!shiftData) return 'Class';
  const custom = shiftData.custom_name || shiftData.customName;
  if (custom && String(custom).trim()) return String(custom).trim();
  const autoName = shiftData.auto_generated_name || shiftData.autoGeneratedName;
  if (autoName && String(autoName).trim()) return String(autoName).trim();
  const title = shiftData.shift_title || shiftData.shiftTitle;
  if (title && String(title).trim()) return String(title).trim();
  const subjectName = shiftData.subject_display_name || shiftData.subjectDisplayName;
  if (subjectName && String(subjectName).trim()) return String(subjectName).trim();
  return 'Class';
};

/**
 * Public guest join (no auth) for LiveKit.
 * Time window only (10 min before to 10 min after).
 */
const getLiveKitGuestJoin = onRequest({
  cors: true,
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (req, res) => {
  res.set('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (!isLiveKitConfigured()) {
    res.status(503).json({ success: false, error: 'LiveKit video is not configured' });
    return;
  }

  const shiftId = req.query.shiftId || req.query.shift_id || req.body?.shiftId;
  if (!shiftId || typeof shiftId !== 'string') {
    res.status(400).json({ success: false, error: 'Missing or invalid shiftId' });
    return;
  }

  let shiftData;
  let roomName;
  try {
    const result = await getLiveKitShiftOrThrow(shiftId);
    shiftData = result.shiftData;
    roomName = result.roomName;
  } catch (e) {
    const code = e?.code;
    const message = e?.message || 'Failed to load class';
    if (code === 'not-found') {
      res.status(404).json({ success: false, error: message });
      return;
    }
    if (code === 'failed-precondition') {
      res.status(400).json({ success: false, error: message });
      return;
    }
    res.status(500).json({ success: false, error: message });
    return;
  }

  if (shiftData.livekit_locked === true) {
    res.status(403).json({ success: false, error: 'This class is locked by the teacher.' });
    return;
  }

  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  const now = new Date();
  const nowMs = now.getTime();
  const shiftStartMs = shiftStart.getTime();
  const shiftEndMs = shiftEnd.getTime();
  const allowedStartMs = Number.isFinite(shiftStartMs)
    ? shiftStartMs - 10 * 60 * 1000
    : nowMs - 10 * 60 * 1000;
  const allowedEndMs = Number.isFinite(shiftEndMs)
    ? shiftEndMs + 10 * 60 * 1000
    : nowMs + 2 * 60 * 60 * 1000;

  if (nowMs < allowedStartMs) {
    const minutesUntil = Math.ceil((allowedStartMs - nowMs) / 60000);
    res.status(403).json({
      success: false,
      error: `You can join 10 minutes before the class starts. Please wait ${minutesUntil} minute(s).`,
    });
    return;
  }

  if (nowMs > allowedEndMs) {
    res.status(403).json({ success: false, error: 'The class window has ended' });
    return;
  }

  const livekitConfig = getLiveKitConfig();
  const rawName = req.query.name || req.body?.name || 'Guest';
  const displayName = String(rawName || 'Guest').trim().slice(0, 60) || 'Guest';
  const identity = `guest_${shiftId}_${Math.random().toString(36).slice(2, 10)}`;
  const ttlSeconds = Math.max(
    600,
    Math.floor((allowedEndMs + 5 * 60 * 1000 - nowMs) / 1000),
  );

  const token = await generateTokenForRole(
    roomName,
    'student',
    identity,
    displayName,
    { role: 'student', guest: true },
    ttlSeconds,
  );

  res.status(200).json({
    success: true,
    livekitUrl: livekitConfig.url,
    token,
    roomName,
    userRole: 'student',
    displayName,
    shiftName: _deriveShiftDisplayName(shiftData),
    expiresInSeconds: ttlSeconds,
    roomLocked: false,
  });
});

/**
 * Callable function: Check if LiveKit is available for a shift
 * 
 * @param {Object} request - Firebase callable request
 * @param {Object} request.data - Request data
 * @param {string} request.data.shiftId - The shift ID to check
 * @returns {Object} Availability status
 */
const checkLiveKitAvailability = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  // Check if LiveKit is configured globally
  const configured = isLiveKitConfigured();

  if (!configured) {
    return {
      available: false,
      reason: 'LiveKit is not configured on this server',
    };
  }

  if (!shiftId) {
    return {
      available: configured,
      reason: configured ? 'LiveKit is configured' : 'LiveKit is not configured',
    };
  }

  // Check shift-specific settings
  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
  if (!shiftDoc.exists) {
    return {
      available: false,
      reason: 'Shift not found',
    };
  }

  const shiftData = shiftDoc.data() || {};
  const normalizeProvider = (raw) => {
    if (typeof raw !== 'string') return null;
    const normalized = raw.trim().toLowerCase();
    if (!normalized) return null;
    if (normalized === 'livekit' || normalized === 'zoom') return normalized;
    return null;
  };

  const hasZoomData = () => {
    const zoomMeetingId = shiftData.zoom_meeting_id;
    const hubMeetingId = shiftData.hubMeetingId || shiftData.hub_meeting_id;
    const encryptedJoinUrl = shiftData.zoom_encrypted_join_url || shiftData.zoomEncryptedJoinUrl;
    return (
      (typeof zoomMeetingId === 'string' && zoomMeetingId.trim().length > 0) ||
      (typeof hubMeetingId === 'string' && hubMeetingId.trim().length > 0) ||
      (typeof encryptedJoinUrl === 'string' && encryptedJoinUrl.trim().length > 0)
    );
  };

  const inferredProvider = () => {
    const explicit =
      normalizeProvider(shiftData.video_provider) || normalizeProvider(shiftData.videoProvider);
    if (explicit) return explicit;

    if (hasZoomData()) return 'zoom';

    const category = typeof shiftData.shift_category === 'string' ? shiftData.shift_category : 'teaching';
    if (category === 'teaching') return 'livekit';

    return 'zoom';
  };

  const videoProvider = inferredProvider();

  return {
    available: videoProvider === 'livekit',
    videoProvider: videoProvider,
    roomName: shiftData.livekit_room_name || `shift_${shiftId}`,
    reason: videoProvider === 'livekit'
      ? 'This class uses LiveKit video'
      : 'This class uses Zoom video',
  };
});

/**
 * Callable function: Get current room participants for a shift (presence preview)
 *
 * Useful for admins/teachers to see who is currently in the class before joining.
 *
 * @param {Object} request - Firebase callable request
 * @param {Object} request.data - Request data
 * @param {string} request.data.shiftId - The shift ID to inspect
 * @returns {Object} Room presence info
 */
const getLiveKitRoomPresence = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }

  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }

  const { shiftData, teacherId, studentIds, roomName } = await getLiveKitShiftOrThrow(shiftId);

  const isTeacher = uid === teacherId;
  const isStudent = studentIds.includes(uid);
  const isAdmin = await isUserAdmin(uid);
  const isParent = !isTeacher && !isStudent && !isAdmin
    ? await isUserParentOfStudent(uid, studentIds)
    : false;

  if (!isTeacher && !isStudent && !isAdmin && !isParent) {
    throw new HttpsError('permission-denied', 'You are not allowed to view this class');
  }

  // Time window check (match join window to avoid leaking presence outside class time)
  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  if (Number.isNaN(shiftStart.getTime()) || Number.isNaN(shiftEnd.getTime())) {
    throw new HttpsError('failed-precondition', 'Shift timing is invalid');
  }

  const now = new Date();
  const allowedStartMs = shiftStart.getTime() - 10 * 60 * 1000;
  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;

  if (now.getTime() < allowedStartMs || now.getTime() > allowedEndMs) {
    return {
      success: true,
      roomName,
      participantCount: 0,
      participants: [],
      inJoinWindow: false,
      generatedAtIso: now.toISOString(),
    };
  }

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);

  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  let participantInfos = [];
  try {
    participantInfos = await roomService.listParticipants(roomName);
  } catch (err) {
    const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim();
    const message = rawMessage.toLowerCase();
    const code = err?.code;
    const status = err?.status;

    // Treat room-not-found as empty room (room is created on-demand).
    if (
      code === 5 ||
      code === 'not_found' ||
      status === 404 ||
      message.includes('not found') ||
      message.includes('notfound') ||
      message.includes('does not exist') ||
      message.includes('room does not exist')
    ) {
      participantInfos = [];
    } else {
      console.error('[LiveKit] Failed to list participants:', err);
      throw new HttpsError('internal', 'Failed to fetch room participants');
    }
  }

  // Sort by joined time when available.
  participantInfos.sort((a, b) => {
    const aMs = a.joinedAtMs || 0n;
    const bMs = b.joinedAtMs || 0n;
    if (aMs === bMs) return 0;
    return aMs < bMs ? -1 : 1;
  });

  const participants = participantInfos
    .filter((p) => p && p.identity)
    .map((p) => {
      const identity = p.identity;
      const role = identity === teacherId
        ? 'teacher'
        : (studentIds.includes(identity) ? 'student' : identity === uid && isParent ? 'parent' : 'other');

      const joinedAtMs = p.joinedAtMs || 0n;
      const joinedAtIso = joinedAtMs > 0n
        ? new Date(Number(joinedAtMs)).toISOString()
        : null;

      return {
        identity,
        name: p.name || identity,
        role,
        joinedAtIso,
        isPublisher: p.isPublisher === true,
      };
    });

  return {
    success: true,
    roomName,
    participantCount: participants.length,
    participants,
    inJoinWindow: true,
    generatedAtIso: now.toISOString(),
  };
});

/**
 * Callable function: Mute a single participant's microphone tracks.
 *
 * @param {Object} request.data.shiftId
 * @param {Object} request.data.identity - Participant identity to mute
 * @param {Object} request.data.muted - Optional boolean (default true)
 */
const muteLiveKitParticipant = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const targetIdentity = request.data?.identity;
  const mutedRaw = request.data?.muted;
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (!targetIdentity || typeof targetIdentity !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid participant identity');
  }
  if (mutedRaw !== undefined && typeof mutedRaw !== 'boolean') {
    throw new HttpsError('invalid-argument', 'muted must be a boolean');
  }
  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }
  if (targetIdentity === uid) {
    throw new HttpsError('failed-precondition', 'You cannot mute yourself');
  }

  const muted = mutedRaw === undefined ? true : mutedRaw;

  const { teacherId, roomName } = await getLiveKitShiftOrThrow(shiftId);
  const isAdmin = await isUserAdmin(uid);
  const { isTeacher } = await assertLiveKitModeratorOrThrow({ uid, teacherId, isAdmin });
  if (isTeacher && targetIdentity === teacherId) {
    throw new HttpsError('permission-denied', 'Teachers cannot mute other moderators');
  }

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);
  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  let participant;
  try {
    participant = await roomService.getParticipant(roomName, targetIdentity);
  } catch (err) {
    const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim().toLowerCase();
    const code = err?.code;
    const status = err?.status;
    if (
      code === 5 ||
      code === 'not_found' ||
      status === 404 ||
      rawMessage.includes('not found') ||
      rawMessage.includes('does not exist')
    ) {
      throw new HttpsError('not-found', 'Participant not found');
    }
    console.error('[LiveKit] Failed to fetch participant:', err);
    throw new HttpsError('internal', 'Failed to fetch participant');
  }

  const audioTracks = (participant.tracks || []).filter(
    (t) => t && t.type === TrackType.AUDIO && t.sid && (muted ? t.muted !== true : t.muted === true)
  );

  for (const track of audioTracks) {
    await roomService.mutePublishedTrack(roomName, targetIdentity, track.sid, muted);
  }

  return {
    success: true,
    roomName,
    identity: targetIdentity,
    muted,
    mutedTracks: audioTracks.length,
    updatedTracks: audioTracks.length,
  };
});

/**
 * Callable function: Mute all participants (except caller).
 *
 * @param {Object} request.data.shiftId
 */
const muteAllLiveKitParticipants = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }

  const { teacherId, roomName } = await getLiveKitShiftOrThrow(shiftId);
  const isAdmin = await isUserAdmin(uid);
  const { isTeacher } = await assertLiveKitModeratorOrThrow({ uid, teacherId, isAdmin });

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);
  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  let participants = [];
  try {
    participants = await roomService.listParticipants(roomName);
  } catch (err) {
    const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim().toLowerCase();
    const code = err?.code;
    const status = err?.status;
    if (
      code === 5 ||
      code === 'not_found' ||
      status === 404 ||
      rawMessage.includes('not found') ||
      rawMessage.includes('does not exist')
    ) {
      participants = [];
    } else {
      console.error('[LiveKit] Failed to list participants:', err);
      throw new HttpsError('internal', 'Failed to fetch room participants');
    }
  }

  let mutedTracks = 0;
  let mutedParticipants = 0;

  for (const participant of participants) {
    const identity = participant?.identity;
    if (!identity) continue;
    if (identity === uid) continue; // never mute caller
    if (isTeacher && identity === teacherId) continue; // teacher can't mute other moderators

    const audioTracks = (participant.tracks || []).filter(
      (t) => t && t.type === TrackType.AUDIO && t.sid && t.muted !== true
    );
    if (audioTracks.length === 0) continue;

    for (const track of audioTracks) {
      await roomService.mutePublishedTrack(roomName, identity, track.sid, true);
      mutedTracks += 1;
    }
    mutedParticipants += 1;
  }

  return {
    success: true,
    roomName,
    mutedParticipants,
    mutedTracks,
  };
});

/**
 * Callable function: Kick a participant from a room.
 *
 * @param {Object} request.data.shiftId
 * @param {Object} request.data.identity
 */
const kickLiveKitParticipant = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const targetIdentity = request.data?.identity;
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (!targetIdentity || typeof targetIdentity !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid participant identity');
  }
  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }
  if (targetIdentity === uid) {
    throw new HttpsError('failed-precondition', 'You cannot remove yourself');
  }

  const { teacherId, roomName } = await getLiveKitShiftOrThrow(shiftId);
  const isAdmin = await isUserAdmin(uid);
  const { isTeacher } = await assertLiveKitModeratorOrThrow({ uid, teacherId, isAdmin });
  if (isTeacher && targetIdentity === teacherId) {
    throw new HttpsError('permission-denied', 'Teachers cannot remove other moderators');
  }

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);
  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  try {
    await roomService.removeParticipant(roomName, targetIdentity);
  } catch (err) {
    const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim().toLowerCase();
    const code = err?.code;
    const status = err?.status;
    if (
      code === 5 ||
      code === 'not_found' ||
      status === 404 ||
      rawMessage.includes('not found') ||
      rawMessage.includes('does not exist')
    ) {
      throw new HttpsError('not-found', 'Participant not found');
    }
    console.error('[LiveKit] Failed to remove participant:', err);
    throw new HttpsError('internal', 'Failed to remove participant');
  }

  return {
    success: true,
    roomName,
    identity: targetIdentity,
  };
});

/**
 * Callable function: Lock/unlock a class room (prevents students from joining).
 *
 * @param {Object} request.data.shiftId
 * @param {Object} request.data.locked
 */
const setLiveKitRoomLock = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const locked = request.data?.locked;
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (typeof locked !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Missing or invalid locked flag');
  }

  const { teacherId, shiftRef } = await getLiveKitShiftOrThrow(shiftId);
  const isAdmin = await isUserAdmin(uid);
  await assertLiveKitModeratorOrThrow({ uid, teacherId, isAdmin });

  await shiftRef.update({
    livekit_locked: locked,
    livekit_locked_by: uid,
    livekit_locked_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    locked,
  };
});

/**
 * Callable function: List class recordings available to caller.
 *
 * Access rules:
 * - admin/super_admin: all recordings
 * - teacher: recordings where teacher_id == caller uid
 * - student: recordings where student_ids includes caller uid
 */
const listClassRecordings = onCall({}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  const requestedLimit = Number(request.data?.limit);
  const requestedScanLimit = Number(request.data?.scanLimit);
  const includeFailedRequested = request.data?.includeFailed === true;

  const limit = Number.isFinite(requestedLimit)
    ? Math.max(1, Math.min(100, Math.floor(requestedLimit)))
    : 30;
  const scanLimit = Number.isFinite(requestedScanLimit)
    ? Math.max(20, Math.min(1000, Math.floor(requestedScanLimit)))
    : 500;

  const recordingsRef = admin.firestore().collection(CLASS_RECORDINGS_COLLECTION);
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  const userData = userDoc.exists ? (userDoc.data() || {}) : {};
  const accessRole = _resolveEffectiveRole({
    userData,
    requestedRole: request.data?.activeRole,
  });

  if (!accessRole) {
    throw new HttpsError(
      'permission-denied',
      'Requested role is not available for this user',
    );
  }

  let snapshot;

  if (accessRole === 'admin' || accessRole === 'super_admin') {
    try {
      snapshot = await recordingsRef.orderBy('updated_at', 'desc').limit(scanLimit).get();
    } catch (err) {
      console.warn('[LiveKit] listClassRecordings: falling back to unordered admin query:', err?.message || err);
      snapshot = await recordingsRef.limit(scanLimit).get();
    }
  } else if (accessRole === 'teacher') {
    snapshot = await recordingsRef.where('teacher_id', '==', uid).limit(scanLimit).get();
  } else if (accessRole === 'student') {
    snapshot = await recordingsRef.where('student_ids', 'array-contains', uid).limit(scanLimit).get();
  } else {
    throw new HttpsError(
      'permission-denied',
      'Only students, teachers, and admins can view class recordings',
    );
  }

  const includeFailed =
    includeFailedRequested &&
    (accessRole === 'admin' || accessRole === 'super_admin');
  const recordings = snapshot.docs
    .map((doc) => {
      const data = doc.data() || {};
      const status = _normalizeRecordingStatus(data.status);
      const filePath = typeof data.file_path === 'string' ? data.file_path : null;

      return {
        recordingId: doc.id,
        shiftId: data.shift_id || null,
        segmentId: data.segment_id || null,
        shiftName: data.shift_name || 'Class Recording',
        subjectName: data.subject_name || '',
        teacherId: data.teacher_id || null,
        teacherName: data.teacher_name || '',
        status: status || 'unknown',
        error: data.error || null,
        filePath,
        bucket: data.bucket || null,
        shiftStartIso: _toIsoString(data.shift_start),
        shiftEndIso: _toIsoString(data.shift_end),
        requestedAtIso: data.requested_at_iso || _toIsoString(data.requested_at),
        startedAtIso: data.started_at_iso || _toIsoString(data.started_at),
        failedAtIso: data.failed_at_iso || _toIsoString(data.failed_at),
        updatedAtIso: _toIsoString(data.updated_at),
      };
    })
    .filter((item) => Boolean(item.filePath))
    .filter((item) => includeFailed || item.status !== 'failed')
    .map((item) => ({
      ...item,
      canPlay: item.status !== 'starting' && item.status !== 'failed',
    }))
    .sort(_sortRecordingsNewestFirst);

  return {
    success: true,
    role: accessRole,
    recordings: recordings.slice(0, limit),
    hasMore: recordings.length > limit,
    scannedCount: recordings.length,
  };
});

/**
 * Callable function: Generate short-lived playback URL for one recording.
 *
 * Access rules:
 * - admin/super_admin: any recording
 * - teacher: only own recordings
 * - student: only recordings where they were assigned to the class
 */
const getClassRecordingPlaybackUrl = onCall({}, async (request) => {
  const uid = request.auth?.uid;
  const recordingId = request.data?.recordingId;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }
  if (!recordingId || typeof recordingId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid recordingId');
  }

  const recordingRef = admin.firestore().collection(CLASS_RECORDINGS_COLLECTION).doc(recordingId);
  const recordingSnap = await recordingRef.get();
  if (!recordingSnap.exists) {
    throw new HttpsError('not-found', 'Recording not found');
  }

  const data = recordingSnap.data() || {};
  const filePath = typeof data.file_path === 'string' ? data.file_path.trim() : '';
  if (!filePath) {
    throw new HttpsError('failed-precondition', 'Recording file path is missing');
  }

  const teacherId = typeof data.teacher_id === 'string' ? data.teacher_id.trim() : '';
  const studentIds = _normalizeStringArray(data.student_ids);
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  const userData = userDoc.exists ? (userDoc.data() || {}) : {};
  const accessRole = _resolveEffectiveRole({
    userData,
    requestedRole: request.data?.activeRole,
  });

  if (!accessRole) {
    throw new HttpsError('permission-denied', 'Requested role is not available for this user');
  }

  const isAdmin = accessRole === 'admin' || accessRole === 'super_admin';
  const isTeacher = accessRole === 'teacher' && Boolean(teacherId) && uid === teacherId;
  const isStudent = accessRole === 'student' && studentIds.includes(uid);
  if (!isAdmin && !isTeacher && !isStudent) {
    throw new HttpsError('permission-denied', 'You are not allowed to access this recording');
  }

  const bucketName = typeof data.bucket === 'string' && data.bucket.trim()
    ? data.bucket.trim()
    : (process.env.LIVEKIT_RECORDING_GCP_BUCKET || '').trim();
  const bucket = bucketName ? admin.storage().bucket(bucketName) : admin.storage().bucket();
  const file = bucket.file(filePath);

  const [exists] = await file.exists();
  if (!exists) {
    throw new HttpsError(
      'failed-precondition',
      'Recording file is not available yet. Please try again shortly.',
    );
  }

  const [metadata] = await file.getMetadata();
  const expiresAtMs = Date.now() + 15 * 60 * 1000;

  let url;
  let expiresAtIso = new Date(expiresAtMs).toISOString();

  try {
    [url] = await file.getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: expiresAtMs,
      responseDisposition: 'inline',
    });
  } catch (_signErr) {
    // getSignedUrl requires the Service Account Token Creator IAM role, which may not be
    // granted to the default Cloud Functions service account. Fall back to a Firebase
    // Storage download-token URL, which only needs storage.objects.update.
    let token = metadata?.metadata?.firebaseStorageDownloadTokens;
    if (!token) {
      const { randomUUID } = require('crypto');
      token = randomUUID();
      await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
    }
    url = `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket.name)}/o/${encodeURIComponent(filePath)}?alt=media&token=${token}`;
    expiresAtIso = null;
  }

  await recordingRef.set({
    last_playback_requested_at: admin.firestore.FieldValue.serverTimestamp(),
    last_playback_requested_by: uid,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    success: true,
    recordingId,
    shiftId: data.shift_id || null,
    filePath,
    url,
    contentType: metadata?.contentType || 'video/mp4',
    sizeBytes: metadata?.size ? Number(metadata.size) : null,
    expiresAtIso,
  };
});

module.exports = {
  getLiveKitJoinToken,
  ensureLiveKitShiftRecording,
  checkLiveKitAvailability,
  getLiveKitRoomPresence,
  muteLiveKitParticipant,
  muteAllLiveKitParticipants,
  kickLiveKitParticipant,
  setLiveKitRoomLock,
  getLiveKitGuestJoin,
  listClassRecordings,
  getClassRecordingPlaybackUrl,
};
