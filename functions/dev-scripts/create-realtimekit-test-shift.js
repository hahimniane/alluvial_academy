// One-off helper: create a teaching shift in its join window so the RealtimeKit
// join flow (incl. the public guest endpoint) can be smoke-tested end to end.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/alluwal-dev-sa.json \
//   node dev-scripts/create-realtimekit-test-shift.js
//
// Prints the created shift ID. Delete the doc when finished testing.

const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'alluwal-dev';

admin.initializeApp({ projectId: PROJECT_ID });

const run = async () => {
  const now = Date.now();
  const start = new Date(now - 5 * 60 * 1000); // started 5 min ago (in window)
  const end = new Date(now + 55 * 60 * 1000); // ends in 55 min

  const doc = {
    custom_name: 'RealtimeKit Smoke Test',
    category: 'teaching',
    shift_start: admin.firestore.Timestamp.fromDate(start),
    shift_end: admin.firestore.Timestamp.fromDate(end),
    teacher_id: 'rtk-test-teacher',
    student_ids: ['rtk-test-student'],
    realtimekit_locked: false,
    created_by_script: 'create-realtimekit-test-shift',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  const ref = await admin.firestore().collection('teaching_shifts').add(doc);
  console.log('Created teaching_shift:', ref.id);
  console.log('Join window:', start.toISOString(), '->', end.toISOString());
  console.log('\nTest the guest join endpoint:');
  console.log(
    `  curl -s "https://us-central1-${PROJECT_ID}.cloudfunctions.net/getRealtimeKitGuestJoin?shiftId=${ref.id}&name=SmokeTest" | jq .`,
  );
  console.log('\nCleanup when done:');
  console.log(
    `  node -e "require('firebase-admin').initializeApp({projectId:'${PROJECT_ID}'});require('firebase-admin').firestore().doc('teaching_shifts/${ref.id}').delete().then(()=>console.log('deleted'))"`,
  );
  process.exit(0);
};

run().catch((err) => {
  console.error('Failed to create test shift:', err.message);
  process.exit(1);
});
