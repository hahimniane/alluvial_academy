/**
 * Read-only summary for in-class LiveKit audio issue reports.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
 *     node functions/dev-scripts/aggregate-livekit-audio-reports.js --days=14
 *
 * Options:
 *   --project=alluwal-academy
 *   --days=14
 *   --limit=500
 *   --collection=livekit_audio_reports
 *   --include-names
 *   --json
 */

const admin = require('firebase-admin');

const DEFAULT_PROJECT_ID = 'alluwal-academy';
const DEFAULT_COLLECTION = 'livekit_audio_reports';

function parseArgs(argv) {
  const args = {
    projectId: process.env.FIREBASE_PROJECT || DEFAULT_PROJECT_ID,
    collection: DEFAULT_COLLECTION,
    days: 14,
    limit: 500,
    includeNames: false,
    json: false,
  };

  for (const arg of argv.slice(2)) {
    if (arg === '--include-names') {
      args.includeNames = true;
    } else if (arg === '--json') {
      args.json = true;
    } else if (arg.startsWith('--project=')) {
      args.projectId = arg.slice('--project='.length);
    } else if (arg.startsWith('--collection=')) {
      args.collection = arg.slice('--collection='.length);
    } else if (arg.startsWith('--days=')) {
      args.days = Number(arg.slice('--days='.length));
    } else if (arg.startsWith('--limit=')) {
      args.limit = Number(arg.slice('--limit='.length));
    }
  }

  if (!Number.isFinite(args.days) || args.days <= 0) args.days = 14;
  if (!Number.isFinite(args.limit) || args.limit <= 0) args.limit = 500;
  return args;
}

function increment(map, value, amount = 1) {
  const key = value == null || value === '' ? '(missing)' : String(value);
  map.set(key, (map.get(key) || 0) + amount);
}

function topEntries(map, limit = 20) {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit);
}

function timestampToDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function hasCause(report, needle) {
  return asArray(report.suspectedCauses).some((cause) =>
    String(cause).includes(needle)
  );
}

function hasFinding(report, needle) {
  const diagnostics = report.diagnostics || {};
  return [
    ...asArray(diagnostics.clientAudioFindings),
    ...asArray(diagnostics.clientClassFindings),
  ].some((finding) => String(finding).includes(needle));
}

function classifyReport(report) {
  const diagnostics = report.diagnostics || {};
  const buckets = [];

  if (
    hasCause(report, 'receiver_webrtc_not_receiving_audio_packets') ||
    hasFinding(report, 'remote_inbound_audio_no_packets_or_bytes')
  ) {
    buckets.push('receiver_not_getting_audio_packets');
  }
  if (
    hasCause(report, 'receiver_audio_packet_loss') ||
    hasCause(report, 'receiver_audio_concealment') ||
    hasFinding(report, 'remote_inbound_audio_packets_lost') ||
    hasFinding(report, 'remote_inbound_audio_concealment')
  ) {
    buckets.push('packet_loss_or_concealment');
  }
  if (
    hasCause(report, 'receiver_not_subscribed_to_remote_audio') ||
    hasFinding(report, 'remote_audio_not_subscribed')
  ) {
    buckets.push('subscription_issue');
  }
  if (
    hasCause(report, 'receiver_audio_playback_blocked') ||
    hasCause(report, 'audio_playback_blocked_or_not_started') ||
    hasFinding(report, 'audio_playback_blocked_or_not_started') ||
    diagnostics.canPlaybackAudio === false ||
    diagnostics.audioPlaybackAllowedState === false
  ) {
    buckets.push('browser_or_app_audio_playback_blocked');
  }
  if (
    hasCause(report, 'sender_mic_enabled_but_not_published') ||
    hasCause(report, 'sender_mic_track_not_active') ||
    hasCause(report, 'sender_webrtc_not_sending_audio_packets') ||
    hasFinding(report, 'local_mic_enabled_in_ui_but_no_audio_publication') ||
    hasFinding(report, 'local_outbound_audio_no_packets_or_bytes')
  ) {
    buckets.push('sender_microphone_or_publish_issue');
  }
  if (
    hasCause(report, 'connection_not_stable') ||
    hasCause(report, 'reporter_connection_') ||
    hasCause(report, 'remote_connection_quality_issue') ||
    hasFinding(report, 'room_connecting_or_reconnecting') ||
    hasFinding(report, 'connection_quality')
  ) {
    buckets.push('connection_quality_or_reconnect');
  }

  if (buckets.length === 0) buckets.push('unclear_from_client_diagnostics');
  return buckets;
}

function collectWebRuntime(diagnostics) {
  const runtime = diagnostics?.webRuntime;
  if (!runtime || typeof runtime !== 'object') return null;
  return [
    runtime.platform,
    runtime.browserName || runtime.browser,
    runtime.browserVersion,
  ].filter(Boolean).join(' ');
}

async function loadReports(db, options) {
  const cutoff = new Date(Date.now() - options.days * 24 * 60 * 60 * 1000);
  const collection = db.collection(options.collection);

  try {
    const snap = await collection
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(cutoff))
      .orderBy('createdAt', 'desc')
      .limit(options.limit)
      .get();
    return snap.docs;
  } catch (error) {
    if (
      String(error && error.message ? error.message : error)
        .includes('Could not load the default credentials')
    ) {
      throw error;
    }
    console.error(
      `[warn] createdAt query failed (${error.message}). Falling back to latest ${options.limit} docs.`
    );
    const snap = await collection.limit(options.limit).get();
    return snap.docs;
  }
}

function summarize(docs, options) {
  const counts = {
    issueTypes: new Map(),
    issueCategories: new Map(),
    suspectedCauses: new Map(),
    diagnosticBuckets: new Map(),
    severities: new Map(),
    reporterRoles: new Map(),
    platforms: new Map(),
    webRuntimes: new Map(),
    playbackState: new Map(),
    localConnectionQuality: new Map(),
    remoteConnectionQuality: new Map(),
    dates: new Map(),
    rooms: new Map(),
    shifts: new Map(),
    teachers: new Map(),
  };

  let firstDate = null;
  let lastDate = null;
  const examples = [];

  for (const doc of docs) {
    const report = doc.data();
    const diagnostics = report.diagnostics || {};
    const date = timestampToDate(report.createdAt) ||
      timestampToDate(report.timestamp);

    if (date) {
      if (!firstDate || date < firstDate) firstDate = date;
      if (!lastDate || date > lastDate) lastDate = date;
      increment(counts.dates, date.toISOString().slice(0, 10));
    }

    increment(counts.issueTypes, report.issueType);
    for (const issueType of asArray(report.issueTypes)) {
      increment(counts.issueTypes, issueType);
    }
    increment(counts.issueCategories, report.issueCategory);
    for (const category of asArray(report.issueCategories)) {
      increment(counts.issueCategories, category);
    }
    for (const cause of asArray(report.suspectedCauses)) {
      increment(counts.suspectedCauses, cause);
    }
    for (const bucket of classifyReport(report)) {
      increment(counts.diagnosticBuckets, bucket);
    }
    increment(counts.severities, report.diagnosticSeverity);
    increment(counts.reporterRoles, report.reporterRole);
    increment(counts.platforms, diagnostics.platform || report.platform);
    increment(counts.webRuntimes, collectWebRuntime(diagnostics));

    const playbackBlocked =
      diagnostics.canPlaybackAudio === false ||
      diagnostics.audioPlaybackAllowedState === false;
    const playbackOk =
      diagnostics.canPlaybackAudio === true ||
      diagnostics.audioPlaybackAllowedState === true;
    increment(
      counts.playbackState,
      playbackBlocked ? 'blocked_or_false' : playbackOk ? 'ok_or_true' : 'unknown'
    );

    increment(
      counts.localConnectionQuality,
      diagnostics.localParticipant?.connectionQuality
    );
    for (const participant of asArray(diagnostics.remoteParticipants)) {
      increment(counts.remoteConnectionQuality, participant?.connectionQuality);
    }

    increment(counts.rooms, report.roomName);
    increment(counts.shifts, report.shiftName || report.shiftId);
    if (options.includeNames) increment(counts.teachers, report.teacherName);

    if (examples.length < 12) {
      examples.push({
        id: doc.id,
        date: date ? date.toISOString() : null,
        roomName: report.roomName || null,
        shift: options.includeNames ? report.shiftName || null : report.shiftId || null,
        reporterRole: report.reporterRole || null,
        issueType: report.issueType || null,
        severity: report.diagnosticSeverity || null,
        buckets: classifyReport(report),
        suspectedCauses: asArray(report.suspectedCauses).slice(0, 8),
        remoteParticipantCount: diagnostics.remoteParticipantCount ?? null,
        canPlaybackAudio: diagnostics.canPlaybackAudio ?? null,
        audioPlaybackAllowedState:
          diagnostics.audioPlaybackAllowedState ?? null,
      });
    }
  }

  return {
    projectId: options.projectId,
    collection: options.collection,
    totalReports: docs.length,
    range: {
      first: firstDate ? firstDate.toISOString() : null,
      last: lastDate ? lastDate.toISOString() : null,
      requestedDays: options.days,
    },
    topIssueTypes: topEntries(counts.issueTypes),
    topIssueCategories: topEntries(counts.issueCategories),
    topDiagnosticBuckets: topEntries(counts.diagnosticBuckets),
    topSuspectedCauses: topEntries(counts.suspectedCauses, 30),
    severities: topEntries(counts.severities),
    reporterRoles: topEntries(counts.reporterRoles),
    platforms: topEntries(counts.platforms),
    webRuntimes: topEntries(counts.webRuntimes),
    playbackState: topEntries(counts.playbackState),
    localConnectionQuality: topEntries(counts.localConnectionQuality),
    remoteConnectionQuality: topEntries(counts.remoteConnectionQuality),
    topDates: topEntries(counts.dates),
    topRooms: topEntries(counts.rooms, 12),
    topShifts: topEntries(counts.shifts, 12),
    topTeachers: options.includeNames ? topEntries(counts.teachers, 12) : [],
    examples,
  };
}

function printTable(title, entries) {
  console.log(`\n${title}`);
  if (entries.length === 0) {
    console.log('  none');
    return;
  }
  for (const [label, count] of entries) {
    console.log(`  ${String(count).padStart(4)}  ${label}`);
  }
}

function printSummary(summary) {
  console.log('\n=== LiveKit Audio Report Aggregate ===');
  console.log(`Project: ${summary.projectId}`);
  console.log(`Collection: ${summary.collection}`);
  console.log(`Reports: ${summary.totalReports}`);
  console.log(
    `Range: ${summary.range.first || 'unknown'} to ${summary.range.last || 'unknown'}`
  );

  printTable('Top issue types', summary.topIssueTypes);
  printTable('Diagnostic buckets', summary.topDiagnosticBuckets);
  printTable('Top suspected causes', summary.topSuspectedCauses);
  printTable('Playback state', summary.playbackState);
  printTable('Reporter roles', summary.reporterRoles);
  printTable('Platforms', summary.platforms);
  printTable('Web runtimes', summary.webRuntimes);
  printTable('Local connection quality', summary.localConnectionQuality);
  printTable('Remote connection quality', summary.remoteConnectionQuality);
  printTable('Top dates', summary.topDates);
  printTable('Top rooms', summary.topRooms);

  console.log('\nSupport-ready interpretation');
  console.log('- receiver_not_getting_audio_packets / subscription_issue: strongest LiveKit media routing or subscription evidence.');
  console.log('- packet_loss_or_concealment: likely network/TURN/jitter path issue.');
  console.log('- browser_or_app_audio_playback_blocked: likely autoplay/audio context/startAudio handling.');
  console.log('- sender_microphone_or_publish_issue: likely microphone permission/device/publish-side issue.');

  console.log('\nSample report IDs');
  for (const example of summary.examples) {
    console.log(
      `  ${example.id} ${example.date || ''} ${example.roomName || ''} ` +
      `${example.issueType || ''} ${example.buckets.join(',')}`
    );
  }
}

async function main() {
  const options = parseArgs(process.argv);
  admin.initializeApp({ projectId: options.projectId });
  const db = admin.firestore();
  let docs;

  try {
    docs = await loadReports(db, options);
  } catch (error) {
    const message = String(error && error.message ? error.message : error);
    if (message.includes('Could not load the default credentials')) {
      console.error('\nFirebase Admin credentials were not found.');
      console.error('Run with a service account or Application Default Credentials, for example:');
      console.error(
        '  GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json ' +
        'node functions/dev-scripts/aggregate-livekit-audio-reports.js --days=14'
      );
      console.error('\nNo reports were read and no data was changed.');
      process.exit(1);
    }
    throw error;
  }

  const summary = summarize(docs, options);
  if (options.json) {
    console.log(JSON.stringify(summary, null, 2));
  } else {
    printSummary(summary);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
