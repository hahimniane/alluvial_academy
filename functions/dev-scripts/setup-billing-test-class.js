// One-off: create a 'billing' teacher account + a live teaching shift so it can
// be joined via the web app right now. PROD test data — delete when done.
//
//   GOOGLE_APPLICATION_CREDENTIALS=/abs/sa.json node dev-scripts/setup-billing-test-class.js

const admin = require('firebase-admin');
admin.initializeApp();

const BILLING_EMAIL = 'billing@alluwaleducationhub.org';
const BILLING_PASSWORD = '111111';
const TEST_STUDENT_UID = 'GoNHveXUvWYPHolyb8NQU0kuXfE2';
const TEST_STUDENT_NAME = 'Test Student';

const run = async () => {
  const auth = admin.auth();
  const db = admin.firestore();

  // 1. Auth account (create or reset password).
  let billing;
  try {
    billing = await auth.getUserByEmail(BILLING_EMAIL);
    await auth.updateUser(billing.uid, {
      password: BILLING_PASSWORD,
      emailVerified: true,
      disabled: false,
    });
    console.log('Billing auth existed -> password reset. uid:', billing.uid);
  } catch (_) {
    billing = await auth.createUser({
      email: BILLING_EMAIL,
      password: BILLING_PASSWORD,
      emailVerified: true,
      displayName: 'Billing Test',
    });
    console.log('Billing auth created. uid:', billing.uid);
  }
  const billingUid = billing.uid;

  // 2. Firestore user doc (teacher).
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('users').doc(billingUid).set({
    uid: billingUid,
    'e-mail': BILLING_EMAIL,
    first_name: 'Billing',
    last_name: 'Test',
    user_type: 'teacher',
    is_active: true,
    email_verified: true,
    password_reset_required: false,
    title: 'Teacher',
    timezone: 'America/New_York',
    date_added: now,
    updated_at: now,
    created_by_admin: true,
  }, { merge: true });
  console.log('Billing user doc upserted (user_type=teacher).');

  // 3. Live teaching shift (now -5min -> +60min).
  const start = new Date(Date.now() - 5 * 60 * 1000);
  const end = new Date(Date.now() + 60 * 60 * 1000);
  const ref = db.collection('teaching_shifts').doc();
  await ref.set({
    id: ref.id,
    teacher_id: billingUid,
    teacher_name: 'Billing Test',
    student_ids: [TEST_STUDENT_UID],
    student_names: [TEST_STUDENT_NAME],
    shift_start: admin.firestore.Timestamp.fromDate(start),
    shift_end: admin.firestore.Timestamp.fromDate(end),
    created_at: admin.firestore.Timestamp.fromDate(new Date()),
    last_modified: now,
    admin_timezone: 'America/New_York',
    teacher_timezone: 'America/New_York',
    subject: 'quranStudies',
    subject_display_name: 'Quran Studies',
    auto_generated_name: 'Billing Test - Quran - Test Student',
    hourly_rate: 0,
    status: 'scheduled',
    recurrence: 'none',
    is_published: true,
    shift_category: 'teaching',
    realtimekit_locked: false,
    created_by_admin_id: billingUid,
    created_by_script: 'setup-billing-test-class',
  });

  console.log('\n=== DONE ===');
  console.log('Billing login:', BILLING_EMAIL, '/', BILLING_PASSWORD);
  console.log('Billing uid  :', billingUid);
  console.log('Shift id     :', ref.id);
  console.log('Join window  :', start.toISOString(), '->', end.toISOString());
  console.log('\nCleanup later:');
  console.log(
    `  node -e "const a=require('firebase-admin');a.initializeApp();Promise.all([a.firestore().doc('teaching_shifts/${ref.id}').delete(),a.firestore().doc('users/${billingUid}').delete(),a.auth().deleteUser('${billingUid}')]).then(()=>{console.log('cleaned');process.exit(0)})"`,
  );
  process.exit(0);
};

run().catch((e) => { console.error('SETUP FAILED:', e.message); process.exit(1); });
