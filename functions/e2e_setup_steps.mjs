// End-to-end proof of the setup sequence on the "test1" enrollment: account →
// schedule → existing parent linked and notified (no invite). Runs as a
// throwaway admin created for the run and deleted afterwards; every write is
// snapshotted first and restored at the end.
//
//   cd functions && node e2e_setup_steps.mjs
import admin from 'firebase-admin';

const PROJECT = 'alluwal-academy';
const API_KEY = 'AIzaSyAi_iLhoVPezrUJTTu2az67Y1Pv31IsuP4';
const FN = (name) => `https://us-central1-${PROJECT}.cloudfunctions.net/${name}`;
const ENROLLMENT = 'sLL5pEKkb79pkSOHnJgv'; // "test1", contact support@alluwaleducationhub.org
const TEST_PARENT = '71tT2s7uCjO83STGCPy33AVr7M32'; // "test parent"
const TEST_TEACHER = 'wkfFb38hISb3pc5ip5XxQqg2K4q2'; // "Billing Test"

admin.initializeApp({credential: admin.credential.applicationDefault(), projectId: PROJECT});
const db = admin.firestore();
const stamp = Date.now();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const check = (cond, msg) => { if (!cond) throw new Error(`CHECK FAILED: ${msg}`); log('✔', msg); };

const call = async (name, idToken, data) => {
  const res = await fetch(FN(name), {
    method: 'POST',
    headers: {'Content-Type': 'application/json', Authorization: `Bearer ${idToken}`},
    body: JSON.stringify({data}),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.error) throw new Error(`${name} → ${res.status} ${JSON.stringify(body.error || body).slice(0, 300)}`);
  return body.result;
};

// ---- snapshots ------------------------------------------------------------
const enrollmentRef = db.collection('enrollments').doc(ENROLLMENT);
const parentRef = db.collection('users').doc(TEST_PARENT);
const enrollmentBefore = (await enrollmentRef.get()).data();
const parentBefore = (await parentRef.get()).data();
check(enrollmentBefore && parentBefore, 'snapshots taken');
check(!(enrollmentBefore.metadata || {}).studentUserId, 'test1 has no account yet (needs-account stage)');

// ---- throwaway admin --------------------------------------------------------
const adminEmail = `e2e-admin-${stamp}@alluwaleducationhub.org`;
const adminPassword = `E2e!${stamp}${Math.random().toString(36).slice(2, 10)}`;
const adminUser = await admin.auth().createUser({email: adminEmail, password: adminPassword, displayName: 'E2E Admin'});
await db.collection('users').doc(adminUser.uid).set({
  'e-mail': adminEmail, first_name: 'E2E', last_name: 'Admin', user_type: 'admin', role: 'admin', is_active: true,
  e2e: true, date_added: admin.firestore.FieldValue.serverTimestamp(),
});
const signIn = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
  method: 'POST', headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({email: adminEmail, password: adminPassword, returnSecureToken: true}),
}).then((r) => r.json());
check(signIn.idToken, 'throwaway admin signed in');
const token = signIn.idToken;

let studentUid = '';
let shiftId = '';
try {
  // ---- step 3 pre-flight: who has the email? ----------------------------------
  const p1 = await call('lookupParentByEmail', token, {email: 'support@alluwaleducationhub.org'});
  check(p1.found === true && p1.canLink === true && p1.role === 'parent' && p1.parentUid === TEST_PARENT, `lookup: existing parent found (${p1.name})`);
  const p2 = await call('lookupParentByEmail', token, {email: 'billing@alluwaleducationhub.org'});
  check(p2.found === true && p2.canLink === false && p2.role === 'teacher', 'lookup: a teacher email is refused as a parent');
  const p3 = await call('lookupParentByEmail', token, {email: `nobody-${stamp}@example.com`});
  check(p3.found === false, 'lookup: unknown email → invite path');

  // ---- step 1: account ---------------------------------------------------------
  const created = await call('createStudentAccount', token, {
    firstName: 'test1', lastName: 'Unknown', isAdultStudent: false, phoneNumber: '', guardianIds: [],
  });
  studentUid = created.studentId;
  check(studentUid && created.existing !== true, `account created (${studentUid}, code ${created.studentCode})`);
  await enrollmentRef.set({metadata: {studentUserId: studentUid, studentAccountCreatedAt: admin.firestore.FieldValue.serverTimestamp()}}, {merge: true});

  // Parent step must still be locked: no schedule yet.
  const noShift = await db.collection('teaching_shifts').where('student_ids', 'array-contains', studentUid).limit(1).get();
  check(noShift.empty, 'schedule step is what the client sees next (no shift yet → parent locked)');

  // ---- step 2: schedule (what the editor writes, minimal) -----------------------
  const start = new Date(Date.now() + 14 * 86400000);
  const end = new Date(start.getTime() + 3600000);
  const shiftRef = await db.collection('teaching_shifts').add({
    teacher_id: TEST_TEACHER, student_ids: [studentUid], subject: 'E2E setup check', subject_id: 'e2e',
    shift_start: admin.firestore.Timestamp.fromDate(start), shift_end: admin.firestore.Timestamp.fromDate(end),
    status: 'scheduled', category: 'class', e2e: true, created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  shiftId = shiftRef.id;
  const hasShift = await db.collection('teaching_shifts').where('student_ids', 'array-contains', studentUid).limit(1).get();
  check(!hasShift.empty, `schedule detected by the same query both apps use (shift ${shiftId})`);

  // ---- step 3: existing parent → link + notify, no invite -----------------------
  const linked = await call('inviteParentForEnrollment', token, {
    enrollmentId: ENROLLMENT, studentUid, email: 'support@alluwaleducationhub.org',
    firstName: p1.firstName || 'test', lastName: p1.lastName || 'parent', phone: '',
  });
  check(linked.status === 'linked' && linked.parentAlreadyExists === true && linked.createdAuthUser === false,
    'existing parent linked, no account created');
  check(linked.inviteSent === true, `"account is ready" email sent to support@ (inviteError=${linked.inviteError})`);

  const enrollmentAfter = (await enrollmentRef.get()).data();
  check(enrollmentAfter.metadata.parentInviteStatus === 'linked' && enrollmentAfter.contact.guardianId === TEST_PARENT, 'enrollment stamped linked + guardianId');
  const studentAfter = (await db.collection('users').doc(studentUid).get()).data();
  check((studentAfter.guardian_ids || []).includes(TEST_PARENT), 'student.guardian_ids has the parent');
  const parentAfter = (await parentRef.get()).data();
  check((parentAfter.children_ids || []).includes(studentUid), 'parent.children_ids has the student');
  check(parentAfter.user_type === 'parent', 'parent role untouched');
  log('ALL CHECKS PASSED');
} finally {
  // ---- restore everything --------------------------------------------------------
  log('cleaning up…');
  if (shiftId) await db.collection('teaching_shifts').doc(shiftId).delete().catch((e) => log('shift delete', e.message));
  if (studentUid) {
    await admin.auth().deleteUser(studentUid).catch((e) => log('student auth delete', e.message));
    await db.collection('users').doc(studentUid).delete().catch((e) => log('student doc delete', e.message));
  }
  await parentRef.set(parentBefore);
  await enrollmentRef.set(enrollmentBefore);
  await admin.auth().deleteUser(adminUser.uid).catch((e) => log('admin auth delete', e.message));
  await db.collection('users').doc(adminUser.uid).delete().catch((e) => log('admin doc delete', e.message));
  const restoredE = (await enrollmentRef.get()).data();
  const restoredP = (await parentRef.get()).data();
  log('restored: enrollment metadata.studentUserId =', (restoredE.metadata || {}).studentUserId || '(none)',
    '| parentInviteStatus =', (restoredE.metadata || {}).parentInviteStatus || '(none)',
    '| parent children =', JSON.stringify(restoredP.children_ids));
  if (shiftId) {
    const chats = await db.collection('chats').where('shift_id', '==', shiftId).get().catch(() => ({docs: []}));
    for (const c of chats.docs) { await c.ref.delete(); log('deleted chat', c.id); }
  }
}
