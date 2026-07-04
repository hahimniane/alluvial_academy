/**
 * Live production acceptance test for Zoom hub routing.
 *
 * Run from the repo root:
 *   node functions/dev-scripts/live-zoom-hub-acceptance.js --classes=20
 *
 * The script creates temporary users/shifts, joins the deployed Zoom page in
 * real Chromium contexts, reports routing results, and removes its test data.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const { chromium } = require(path.join(
  REPO_ROOT,
  'services',
  'zoom-hub-bot',
  'node_modules',
  'playwright',
));

const PROJECT_ID = process.env.FIREBASE_PROJECT || 'alluwal-academy';
const CLASS_COUNT = Number(
  (process.argv.find((arg) => arg.startsWith('--classes=')) || '').split('=')[1] || 20,
);
const OPEN_BATCH_SIZE = Number(
  (process.argv.find((arg) => arg.startsWith('--batch-size=')) || '').split('=')[1] || 2,
);
const forceLaneIndexArg = process.argv.find((arg) => arg.startsWith('--force-lane-index='));
const FORCE_LANE_INDEX = forceLaneIndexArg
  ? Number(forceLaneIndexArg.split('=')[1])
  : null;
const KEEP = process.argv.includes('--keep');
const ALLOW_ACTIVE_HUBS = process.argv.includes('--allow-active-hubs');
const RUN_ID = `codex_${Date.now()}`;
const PASSWORD = `ZoomTest${Date.now()}!`;
const SITE_URL = process.env.SITE_URL || 'https://alluwaleducationhub.org';
const ZOOM_PAGE_URL = `${SITE_URL}/zoom_meeting.html`;
const FUNCTION_URL = `https://us-central1-${PROJECT_ID}.cloudfunctions.net/getZoomJoinInfo`;
const RESULT_TIMEOUT_MS = 180000;

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();
let browser;
let sessions = [];
let cleanupStarted = false;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const timestamp = (date) => admin.firestore.Timestamp.fromDate(date);

const compact = (value) => String(value || '').replace(/\s+/g, ' ').trim();

function laneIndexForClass(index) {
  if (FORCE_LANE_INDEX === null) return index % 2;
  if (!Number.isInteger(FORCE_LANE_INDEX) || FORCE_LANE_INDEX < 0) {
    throw new Error(`Invalid --force-lane-index value: ${forceLaneIndexArg}`);
  }
  return FORCE_LANE_INDEX;
}

function webApiKey() {
  if (process.env.FIREBASE_WEB_API_KEY) return process.env.FIREBASE_WEB_API_KEY;
  const optionsFile = PROJECT_ID === 'alluwal-dev'
    ? 'firebase_options_dev.dart'
    : 'firebase_options.dart';
  const source = fs.readFileSync(path.join(REPO_ROOT, 'lib', optionsFile), 'utf8');
  const webMatch = source.match(/static const FirebaseOptions web = FirebaseOptions\([\s\S]*?apiKey:\s*'([^']+)'/);
  const anyMatch = source.match(/apiKey:\s*'([^']+)'/);
  const key = webMatch?.[1] || anyMatch?.[1] || '';
  if (!key) throw new Error('Unable to find Firebase web API key');
  return key;
}

async function signIn(uid) {
  const user = await auth.getUser(uid);
  if (!user.email) throw new Error(`Auth user has no email: ${uid}`);
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${webApiKey()}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: user.email,
        password: PASSWORD,
        returnSecureToken: true,
      }),
    },
  );
  const body = await response.json();
  if (!response.ok) {
    throw new Error(`Auth sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  }
  return body.idToken;
}

async function callJoinInfo({ uid, shiftId }) {
  const idToken = await signIn(uid);
  const response = await fetch(FUNCTION_URL, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${idToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ data: { shiftId } }),
  });
  const body = await response.json();
  if (!response.ok || body.error) {
    throw new Error(`getZoomJoinInfo failed for ${uid}/${shiftId}: ${JSON.stringify(body)}`);
  }
  return body.result;
}

async function upsertAuthUser({ uid, email, displayName }) {
  try {
    await auth.createUser({
      uid,
      email,
      password: PASSWORD,
      displayName,
      emailVerified: true,
    });
  } catch (err) {
    if (err.code !== 'auth/uid-already-exists') throw err;
    await auth.updateUser(uid, { email, password: PASSWORD, displayName, emailVerified: true });
  }
}

async function createUserDoc({ uid, email, displayName, userType, role, guardianIds = [] }) {
  const [firstName, ...rest] = displayName.split(' ');
  await upsertAuthUser({ uid, email, displayName });
  await db.collection('users').doc(uid).set({
    uid,
    email,
    'e-mail': email,
    first_name: firstName || displayName,
    last_name: rest.join(' '),
    display_name: displayName,
    name: displayName,
    user_type: userType,
    role: role || userType,
    guardian_ids: guardianIds,
    is_active: true,
    codex_zoom_test_run: RUN_ID,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function createShift({ index, teacherUid, teacherName, studentUid, studentName }) {
  const start = new Date(Date.now() - 2 * 60 * 1000);
  const end = new Date(Date.now() + 58 * 60 * 1000);
  const uniqueSuffix = `${Date.now().toString(36).slice(-4)}${String(index).padStart(2, '0')}`;
  const shiftId = `${RUN_ID}_shift_${uniqueSuffix}`;
  const laneIndex = laneIndexForClass(index);
  await db.collection('teaching_shifts').doc(shiftId).set({
    id: shiftId,
    teacher_id: teacherUid,
    teacher_name: teacherName,
    student_ids: [studentUid],
    student_names: [studentName],
    shift_start: timestamp(start),
    shift_end: timestamp(end),
    admin_timezone: 'America/New_York',
    teacher_timezone: 'America/New_York',
    subject: 'quranStudies',
    subject_id: 'quran',
    subject_display_name: 'Quran',
    auto_generated_name: `Codex Zoom ${index} - Quran - ${studentName}`,
    custom_name: `Codex Zoom Acceptance ${index}`,
    hourly_rate: 0,
    status: 'scheduled',
    created_by_admin_id: 'codex',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    last_modified: admin.firestore.FieldValue.serverTimestamp(),
    recurrence: 'none',
    enhanced_recurrence: { type: 'none' },
    shift_category: 'teaching',
    category: 'teaching',
    video_provider: 'zoom',
    zoomRoutingMode: 'hub',
    zoom_routing_mode: 'hub',
    zoom_hub_lane_index: laneIndex,
    zoomHubLaneIndex: laneIndex,
    realtimekit_recording_enabled: false,
    codex_zoom_test_run: RUN_ID,
  }, { merge: true });
  return shiftId;
}

async function setupData() {
  const classes = [];
  for (let i = 0; i < CLASS_COUNT; i += 1) {
    const teacherUid = `${RUN_ID}_teacher_${String(i).padStart(2, '0')}`;
    const studentUid = `${RUN_ID}_student_${String(i).padStart(2, '0')}`;
    const teacherName = `Codex Teacher ${i + 1}`;
    const studentName = `Codex Student ${i + 1}`;
    await createUserDoc({
      uid: teacherUid,
      email: `${teacherUid}@alluwaleducationhub.org`,
      displayName: teacherName,
      userType: 'teacher',
      role: 'teacher',
    });
    await createUserDoc({
      uid: studentUid,
      email: `${studentUid}@alluwaleducationhub.org`,
      displayName: studentName,
      userType: 'student',
      role: 'student',
    });
    const shiftId = await createShift({
      index: i,
      teacherUid,
      teacherName,
      studentUid,
      studentName,
    });
    classes.push({ index: i, shiftId, teacherUid, studentUid, teacherName, studentName });
  }

  const parentUid = `${RUN_ID}_parent`;
  const adminUid = `${RUN_ID}_admin`;
  await createUserDoc({
    uid: parentUid,
    email: `${parentUid}@alluwaleducationhub.org`,
    displayName: 'Codex Parent',
    userType: 'parent',
    role: 'parent',
  });
  await createUserDoc({
    uid: adminUid,
    email: `${adminUid}@alluwaleducationhub.org`,
    displayName: 'Codex Admin',
    userType: 'admin',
    role: 'admin',
  });
  await db.collection('users').doc(classes[0].studentUid).set({
    guardian_ids: [parentUid],
    guardianIds: [parentUid],
  }, { merge: true });

  return { classes, parentUid, adminUid };
}

async function assertSafeToRun() {
  if (PROJECT_ID !== 'alluwal-academy' || ALLOW_ACTIVE_HUBS) return;
  const now = Date.now();
  const hubSnap = await db.collection('hub_meetings').get();
  const active = [];
  for (const doc of hubSnap.docs) {
    const data = doc.data() || {};
    const start = data.window_start?.toDate?.() || data.windowStart?.toDate?.() || null;
    const end = data.window_end?.toDate?.() || data.windowEnd?.toDate?.() || null;
    const status = String(data.status || data.bot_status || '').trim();
    if (!start || !end || start.getTime() > now || end.getTime() < now) continue;
    if (status === 'left' || status === 'ended') continue;
    active.push({
      hubDocId: doc.id,
      lane: data.lane || data.laneIndex || '',
      status,
      windowEnd: end.toISOString(),
      roomCount: Array.isArray(data.rooms) ? data.rooms.length : 0,
      memberCount: (await doc.ref.collection('members').count().get()).data().count,
    });
  }
  if (active.length === 0) return;
  throw new Error(
    `Refusing live production acceptance while hubs are active: ${JSON.stringify(active)}. ` +
    'Run in an isolated window, use alluwal-dev with local bots, or pass --allow-active-hubs for a deliberate spare-room smoke only.',
  );
}

function zoomUrl(joinInfo) {
  const params = new URLSearchParams({
    sdkKey: joinInfo.sdkKey,
    signature: joinInfo.signature,
    meetingNumber: joinInfo.meetingNumber,
    password: joinInfo.password || '',
    displayName: joinInfo.displayName || 'Participant',
    customerKey: joinInfo.customerKey,
    connectingText: 'Connecting To Class',
    routingStillConnectingText: 'Connecting To Class',
    routingHelpText: 'Connecting To Class',
    loadErrorText: 'Unable to load Zoom meeting.',
    joinErrorText: 'Unable to join Zoom meeting.',
    initErrorText: 'Unable to initialize Zoom meeting.',
    leftText: 'You left the class.',
    leaveMeetingText: 'Leave Meeting',
    breakoutRoomName: joinInfo.breakoutRoomName || '',
    breakoutRoomKey: joinInfo.breakoutRoomKey || '',
    autoJoinBreakoutRoom: joinInfo.autoJoinBreakoutRoom ? '1' : '0',
    embedded: '0',
  });
  return `${ZOOM_PAGE_URL}#${params.toString()}`;
}

async function waitForHubReady(hubIds) {
  const uniqueHubIds = Array.from(new Set(hubIds.filter(Boolean)));
  const deadline = Date.now() + 180000;
  while (Date.now() < deadline) {
    const states = [];
    for (const hubId of uniqueHubIds) {
      const snap = await db.collection('hub_meetings').doc(hubId).get();
      const data = snap.exists ? snap.data() || {} : {};
      states.push({
        hubId,
        status: compact(data.status || data.bot_status),
        heartbeat: data.heartbeat_at?.toDate?.()?.toISOString?.() || '',
      });
    }
    if (states.length > 0 && states.every((item) => item.status === 'roomsOpen')) {
      return states;
    }
    console.log('Waiting for hub rooms:', states);
    await sleep(5000);
  }
  throw new Error(`Hub rooms did not open in time: ${uniqueHubIds.join(', ')}`);
}

async function probePage(page) {
  return page.evaluate(async () => {
    const callZoom = (method) => new Promise((resolve) => {
      try {
        const zoom = window.ZoomMtg;
        if (!zoom || typeof zoom[method] !== 'function') {
          resolve({ unavailable: true });
          return;
        }
        zoom[method]({
          success: (value) => resolve(value && value.result ? value.result : value),
          error: (error) => resolve({ error }),
        });
      } catch (error) {
        resolve({ error: String(error && error.message || error) });
      }
    });
    const visibleText = document.body ? document.body.innerText || '' : '';
    return {
      pending: document.body?.classList?.contains('alluwal-private-routing-pending') || false,
      statusText: document.getElementById('status')?.textContent || '',
      visibleText: visibleText.slice(0, 2000),
      currentRoom: await callZoom('getCurrentBreakoutRoom'),
      userStatus: await callZoom('getUserStatus'),
      hasBreakoutManagementText: /Breakout Rooms\\s*(-|–)\\s*In Progress|Close All Rooms|Add Room|Broadcast/i.test(visibleText),
      hasNativeLeaveRoomText: /Leave Breakout Room/i.test(visibleText),
      hasLeaveMeetingButton: Boolean(document.getElementById('leaveMeetingButton')),
    };
  });
}

function roomNameFromProbe(probe) {
  const room = probe?.currentRoom || {};
  return compact(room.name || room.roomName || room.room_name || room.boName || room.topic);
}

function statusInRoom(probe) {
  const raw = probe?.userStatus?.status ??
    probe?.userStatus?.userStatus ??
    probe?.userStatus?.roomStatus ??
    probe?.userStatus?.value;
  const number = Number(raw);
  if (Number.isFinite(number)) return number === 3;
  const text = JSON.stringify(probe?.userStatus || {});
  if (/in[_ ]?room|started/i.test(text)) return true;
  if (/main[_ ]?session|not[_ ]?joined|closed|closing/i.test(text)) return false;
  return null;
}

async function waitForParticipant(session) {
  const deadline = Date.now() + RESULT_TIMEOUT_MS;
  let lastProbe = null;
  while (Date.now() < deadline) {
    lastProbe = await probePage(session.page);
    const currentRoom = roomNameFromProbe(lastProbe);
    const expectedRoom = compact(session.expectedRoom);
    const inExpectedRoom = currentRoom && currentRoom.toLowerCase() === expectedRoom.toLowerCase();
    const inRoom = statusInRoom(lastProbe);
    if (
      inExpectedRoom &&
      inRoom !== false &&
      !lastProbe.pending &&
      !lastProbe.hasBreakoutManagementText &&
      !lastProbe.hasNativeLeaveRoomText
    ) {
      return {
        ok: true,
        label: session.label,
        expectedRoom,
        currentRoom,
        userStatus: lastProbe.userStatus,
      };
    }
    await sleep(2500);
  }
  return {
    ok: false,
    label: session.label,
    expectedRoom: compact(session.expectedRoom),
    currentRoom: roomNameFromProbe(lastProbe),
    pending: lastProbe?.pending,
    statusText: lastProbe?.statusText,
    userStatus: lastProbe?.userStatus,
    hasBreakoutManagementText: lastProbe?.hasBreakoutManagementText,
    hasNativeLeaveRoomText: lastProbe?.hasNativeLeaveRoomText,
  };
}

async function openParticipant(browser, participant) {
  const context = await browser.newContext({
    viewport: participant.mobile
      ? { width: 390, height: 844 }
      : { width: 1100, height: 760 },
    permissions: ['camera', 'microphone'],
  });
  const page = await context.newPage();
  const logs = [];
  page.on('console', (message) => {
    const text = message.text();
    if (message.type() === 'error' || /unable|failed|error/i.test(text)) {
      logs.push(`${message.type()}: ${text}`.slice(0, 500));
    }
  });
  page.on('pageerror', (error) => logs.push(`pageerror: ${error.message}`));
  await page.goto(zoomUrl(participant.joinInfo), {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  });
  return { ...participant, context, page, logs };
}

function chunked(items, size) {
  const chunks = [];
  const chunkSize = Math.max(1, Number(size) || 1);
  for (let index = 0; index < items.length; index += chunkSize) {
    chunks.push(items.slice(index, index + chunkSize));
  }
  return chunks;
}

async function leaveAndClose(session) {
  try {
    await session.page.evaluate(() => new Promise((resolve) => {
      const zoom = window.ZoomMtg;
      if (!zoom || typeof zoom.leaveMeeting !== 'function') {
        resolve();
        return;
      }
      try {
        zoom.leaveMeeting({ success: resolve, error: resolve });
      } catch (_) {
        resolve();
      }
    }));
  } catch (_) {}
  await session.context.close().catch(() => {});
}

const isRunShiftId = (value) => String(value || '').startsWith(`${RUN_ID}_shift_`);
const isRunUid = (value) => String(value || '').startsWith(`${RUN_ID}_`);
const isSpareShiftId = (value) => String(value || '').startsWith('__spare_');

async function commitDeletes(refs) {
  let batch = db.batch();
  let count = 0;
  for (const ref of refs) {
    batch.delete(ref);
    count += 1;
    if (count >= 400) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();
}

async function cleanupHubDocs() {
  const hubSnap = await db.collection('hub_meetings').get();
  let deletedHubs = 0;
  let updatedHubs = 0;
  let deletedMembers = 0;

  for (const doc of hubSnap.docs) {
    const data = doc.data() || {};
    const rooms = Array.isArray(data.rooms) ? data.rooms : [];
    const runRooms = rooms.filter((room) => isRunShiftId(room.shiftId || room.shift_id));
    if (runRooms.length === 0) continue;

    const membersSnap = await doc.ref.collection('members').get();
    const runMemberRefs = membersSnap.docs
      .filter((memberDoc) => {
        const memberData = memberDoc.data() || {};
        return isRunUid(memberDoc.id) ||
          isRunUid(memberData.uid) ||
          isRunShiftId(memberData.shiftId || memberData.shift_id);
      })
      .map((memberDoc) => memberDoc.ref);
    await commitDeletes(runMemberRefs);
    deletedMembers += runMemberRefs.length;

    const classRooms = rooms.filter((room) => !isSpareShiftId(room.shiftId || room.shift_id));
    const onlyRunClassRooms = classRooms.length > 0 &&
      classRooms.every((room) => isRunShiftId(room.shiftId || room.shift_id));
    if (onlyRunClassRooms) {
      await commitDeletes(membersSnap.docs.map((memberDoc) => memberDoc.ref));
      await doc.ref.delete();
      deletedHubs += 1;
      continue;
    }

    const nextSpares = { ...(data.spares || {}) };
    for (const [name, shiftId] of Object.entries(nextSpares)) {
      if (isRunShiftId(shiftId)) nextSpares[name] = null;
    }
    const nextRooms = rooms.filter((room) => !isRunShiftId(room.shiftId || room.shift_id));
    await doc.ref.set({
      rooms: nextRooms,
      room_count: nextRooms.length,
      spares: nextSpares,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    updatedHubs += 1;
  }

  console.log(
    `Cleaned ${deletedHubs} test-only hub docs, updated ${updatedHubs} mixed hub docs, ` +
    `and deleted ${deletedMembers} test hub members for run ${RUN_ID}`,
  );
}

async function collectJoinInfos({ classes, parentUid, adminUid }) {
  const joinInfos = [];

  const firstClassByLane = new Map();
  for (const klass of classes) {
    const laneIndex = laneIndexForClass(klass.index);
    if (!firstClassByLane.has(laneIndex)) firstClassByLane.set(laneIndex, klass);
  }
  for (const klass of firstClassByLane.values()) {
    const joinInfo = await callJoinInfo({ uid: klass.teacherUid, shiftId: klass.shiftId });
    joinInfos.push({
      label: `teacher-${klass.index + 1}`,
      uid: klass.teacherUid,
      shiftId: klass.shiftId,
      expectedRoom: joinInfo.breakoutRoomName,
      joinInfo,
    });
  }

  for (const klass of classes) {
    for (const [role, uid] of [['teacher', klass.teacherUid], ['student', klass.studentUid]]) {
      const already = joinInfos.some((item) => item.uid === uid && item.shiftId === klass.shiftId);
      if (already) continue;
      const joinInfo = await callJoinInfo({ uid, shiftId: klass.shiftId });
      joinInfos.push({
        label: `${role}-${klass.index + 1}`,
        uid,
        shiftId: klass.shiftId,
        expectedRoom: joinInfo.breakoutRoomName,
        joinInfo,
        mobile: role === 'student' && klass.index === 0,
      });
    }
  }

  const parentJoinInfo = await callJoinInfo({ uid: parentUid, shiftId: classes[0].shiftId });
  joinInfos.push({
    label: 'parent-class-1',
    uid: parentUid,
    shiftId: classes[0].shiftId,
    expectedRoom: parentJoinInfo.breakoutRoomName,
    joinInfo: parentJoinInfo,
    mobile: true,
  });

  const adminJoinInfo = await callJoinInfo({ uid: adminUid, shiftId: classes[0].shiftId });
  joinInfos.push({
    label: 'admin-class-1',
    uid: adminUid,
    shiftId: classes[0].shiftId,
    expectedRoom: adminJoinInfo.breakoutRoomName,
    joinInfo: adminJoinInfo,
  });

  return joinInfos;
}

async function cleanup() {
  if (cleanupStarted) return;
  cleanupStarted = true;
  if (KEEP) {
    console.log(`Keeping test data for run ${RUN_ID}`);
    return;
  }

  const userSnap = await db.collection('users')
    .where('codex_zoom_test_run', '==', RUN_ID)
    .get();
  const shiftSnap = await db.collection('teaching_shifts')
    .where('codex_zoom_test_run', '==', RUN_ID)
    .get();

  let batch = db.batch();
  let count = 0;
  for (const doc of [...shiftSnap.docs, ...userSnap.docs]) {
    batch.delete(doc.ref);
    count += 1;
    if (count >= 400) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();

  await cleanupHubDocs();

  for (const doc of userSnap.docs) {
    await auth.deleteUser(doc.id).catch(() => {});
  }
  console.log(`Cleaned ${shiftSnap.size} shifts and ${userSnap.size} users for run ${RUN_ID}`);
}

async function shutdownFromSignal(signal) {
  console.warn(`Received ${signal}; closing live Zoom acceptance resources`);
  for (const session of sessions) {
    await leaveAndClose(session).catch(() => {});
  }
  sessions = [];
  if (browser) await browser.close().catch(() => {});
  await cleanup().catch((err) => console.error('Signal cleanup failed', err));
  process.exit(130);
}

process.once('SIGINT', () => {
  shutdownFromSignal('SIGINT').catch((err) => {
    console.error(err);
    process.exit(130);
  });
});
process.once('SIGTERM', () => {
  shutdownFromSignal('SIGTERM').catch((err) => {
    console.error(err);
    process.exit(143);
  });
});

async function main() {
  console.log(
    `Starting live Zoom hub acceptance run ${RUN_ID} with ${CLASS_COUNT} classes` +
    (FORCE_LANE_INDEX === null ? '' : ` on forced lane index ${FORCE_LANE_INDEX}`),
  );
  await assertSafeToRun();
  const data = await setupData();
  try {
    const joinInfos = await collectJoinInfos(data);
    const hubIds = joinInfos.map((item) => item.joinInfo.hubMeetingId);
    const ready = await waitForHubReady(hubIds);
    console.log('Hub rooms open:', ready);

    browser = await chromium.launch({
      headless: true,
      args: [
        '--autoplay-policy=no-user-gesture-required',
        '--disable-background-timer-throttling',
        '--disable-dev-shm-usage',
        '--use-fake-ui-for-media-stream',
        '--use-fake-device-for-media-stream',
        '--window-size=1100,760',
      ],
    });

    const results = [];
    for (const [batchIndex, batch] of chunked(joinInfos, OPEN_BATCH_SIZE).entries()) {
      console.log(`Opening participant batch ${batchIndex + 1}/${Math.ceil(joinInfos.length / OPEN_BATCH_SIZE)} (${batch.length})`);
      const batchSessions = await Promise.all(batch.map((participant) => openParticipant(browser, participant)));
      sessions.push(...batchSessions);
      const batchResults = await Promise.all(batchSessions.map(waitForParticipant));
      results.push(...batchResults);
      if (batchResults.every((item) => item.ok)) {
        for (const session of batchSessions) {
          await leaveAndClose(session).catch(() => {});
        }
        sessions = sessions.filter((item) => !batchSessions.includes(item));
      }
    }

    const duplicateSource = joinInfos.find((item) => item.label === 'student-2') || joinInfos[0];
    const duplicateSession = await openParticipant(browser, {
      ...duplicateSource,
      label: `${duplicateSource.label}-duplicate-rejoin`,
    });
    sessions.push(duplicateSession);
    const duplicateResult = await waitForParticipant(duplicateSession);
    results.push(duplicateResult);
    if (duplicateResult.ok) {
      await leaveAndClose(duplicateSession).catch(() => {});
      sessions = sessions.filter((item) => item !== duplicateSession);
    }

    const rejoinSource = joinInfos.find((item) => item.label === 'student-3') || joinInfos[0];
    if (rejoinSource) {
      const initialDropSession = await openParticipant(browser, rejoinSource);
      sessions.push(initialDropSession);
      results.push(await waitForParticipant(initialDropSession));
      await leaveAndClose(initialDropSession).catch(() => {});
      sessions = sessions.filter((item) => item !== initialDropSession);
      const rejoinSession = await openParticipant(browser, {
        ...rejoinSource,
        label: `${rejoinSource.label}-after-drop`,
      });
      sessions.push(rejoinSession);
      results.push(await waitForParticipant(rejoinSession));
    }

    const failed = results.filter((item) => !item.ok);
    console.log(JSON.stringify({
      runId: RUN_ID,
      classes: CLASS_COUNT,
      participantsAttempted: results.length,
      passed: results.length - failed.length,
      failed: failed.length,
      failures: failed,
      rooms: results.filter((item) => item.ok).map((item) => ({
        label: item.label,
        room: item.currentRoom,
      })),
    }, null, 2));

    if (failed.length > 0) {
      for (const failedResult of failed.slice(0, 5)) {
        const session = sessions.find((item) => item.label === failedResult.label);
        if (!session) continue;
        const screenshotPath = path.join(
          REPO_ROOT,
          'output',
          'playwright',
          `${RUN_ID}_${failedResult.label}.png`,
        );
        fs.mkdirSync(path.dirname(screenshotPath), { recursive: true });
        await session.page.screenshot({ path: screenshotPath, fullPage: true }).catch(() => {});
        console.log(`Screenshot: ${screenshotPath}`);
      }
      throw new Error(`${failed.length} live Zoom participant(s) failed routing`);
    }
  } finally {
    for (const session of sessions) {
      await leaveAndClose(session).catch(() => {});
    }
    if (browser) await browser.close().catch(() => {});
    await cleanup();
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
