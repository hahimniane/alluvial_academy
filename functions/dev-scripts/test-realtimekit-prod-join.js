// End-to-end RealtimeKit join smoke test against REAL Cloudflare + prod Firestore.
// Runs the same services/realtimekit/client.js code path the Cloud Function uses,
// so a real meeting + participant tokens are minted. Writes joinable HTML pages.
//
// Usage:
//   CLOUDFLARE_ACCOUNT_ID=... REALTIMEKIT_APP_ID=... CLOUDFLARE_REALTIME_API_TOKEN=... \
//   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/sa.json \
//   node dev-scripts/test-realtimekit-prod-join.js
//
// Cleans nothing automatically; prints a cleanup command for the shift doc.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// config.js reads these at require-time via getRealtimeKitConfig(), so they must
// be set before we pull in the client.
const realtimeKit = require('../services/realtimekit/client');
const { getRealtimeKitConfig } = require('../services/realtimekit/config');

const UI_VERSION = '1.1.2';
const CLIENT_VERSION = '1.2.5';

const joinHtml = (token, label) => `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>RealtimeKit join - ${label}</title>
  <style>
    html, body, rtk-meeting { margin: 0; width: 100%; height: 100%; background: #000; }
    body { overflow: hidden; }
  </style>
</head>
<body>
  <rtk-meeting id="meeting" mode="fill" show-setup-screen="true"></rtk-meeting>
  <script type="module">
    import { defineCustomElements } from 'https://cdn.jsdelivr.net/npm/@cloudflare/realtimekit-ui@${UI_VERSION}/loader/index.es2017.js';
    defineCustomElements();
  </script>
  <script src="https://cdn.jsdelivr.net/npm/@cloudflare/realtimekit@${CLIENT_VERSION}/dist/browser.js"></script>
  <script>
    (async () => {
      const meeting = await RealtimeKitClient.init({ authToken: ${JSON.stringify(token)} });
      document.getElementById('meeting').meeting = meeting;
    })();
  </script>
</body>
</html>`;

const run = async () => {
  const config = getRealtimeKitConfig(); // throws if creds missing
  admin.initializeApp(); // uses GOOGLE_APPLICATION_CREDENTIALS

  const now = Date.now();
  const start = new Date(now - 5 * 60 * 1000);
  const end = new Date(now + 55 * 60 * 1000);

  const shiftRef = await admin.firestore().collection('teaching_shifts').add({
    custom_name: 'RealtimeKit Smoke Test',
    category: 'teaching',
    shift_start: admin.firestore.Timestamp.fromDate(start),
    shift_end: admin.firestore.Timestamp.fromDate(end),
    teacher_id: 'rtk-test-teacher',
    student_ids: ['rtk-test-student'],
    realtimekit_locked: false,
    created_by_script: 'test-realtimekit-prod-join',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('1) Created teaching_shift:', shiftRef.id);

  const meeting = await realtimeKit.createMeeting({
    title: 'RealtimeKit Smoke Test',
    persist_chat: true,
    session_keep_alive_time_in_secs: 600,
  });
  const meetingId = meeting?.data?.id;
  if (!meetingId) throw new Error('No meeting id returned');
  console.log('2) Created meeting:', meetingId);

  const teacher = await realtimeKit.addParticipant(meetingId, {
    custom_participant_id: 'rtk-test-teacher',
    preset_name: config.presets.teacher,
    name: 'Test Teacher',
  });
  const student = await realtimeKit.addParticipant(meetingId, {
    custom_participant_id: 'rtk-test-student',
    preset_name: config.presets.student,
    name: 'Test Student',
  });

  const teacherToken = teacher?.data?.token;
  const studentToken = student?.data?.token;
  if (!teacherToken || !studentToken) throw new Error('Missing participant token');
  console.log('3) Minted tokens — teacher preset:', config.presets.teacher,
    '| student preset:', config.presets.student);
  console.log('   teacher token:', `${String(teacherToken).slice(0, 18)}...`);
  console.log('   student token:', `${String(studentToken).slice(0, 18)}...`);

  await shiftRef.set({
    realtimekit_meeting_id: meetingId,
    realtimekit_provider: 'cloudflare_realtimekit',
    realtimekit_updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('4) Wrote realtimekit_meeting_id back to shift');

  const outDir = path.join(require('os').tmpdir(), 'rtk-smoke');
  fs.mkdirSync(outDir, { recursive: true });
  const teacherFile = path.join(outDir, 'join-teacher.html');
  const studentFile = path.join(outDir, 'join-student.html');
  fs.writeFileSync(teacherFile, joinHtml(teacherToken, 'Teacher'));
  fs.writeFileSync(studentFile, joinHtml(studentToken, 'Student'));
  console.log('5) Wrote joinable pages:');
  console.log('   Teacher:', teacherFile);
  console.log('   Student:', studentFile);

  console.log('\nOpen both in a browser to verify a real two-party join:');
  console.log(`   open "${teacherFile}" "${studentFile}"`);
  console.log('\nCleanup the test shift when done:');
  console.log(
    `   GOOGLE_APPLICATION_CREDENTIALS="$GOOGLE_APPLICATION_CREDENTIALS" node -e "const a=require('firebase-admin');a.initializeApp();a.firestore().doc('teaching_shifts/${shiftRef.id}').delete().then(()=>{console.log('deleted ${shiftRef.id}');process.exit(0)})"`,
  );
  process.exit(0);
};

run().catch((err) => {
  console.error('SMOKE TEST FAILED:', err.message);
  if (err.payload) console.error('payload:', JSON.stringify(err.payload));
  process.exit(1);
});
