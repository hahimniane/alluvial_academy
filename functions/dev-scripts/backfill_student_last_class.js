/**
 * Fills users/{studentId}.last_class_at / last_class_shift_id from every
 * presence record (livekit_sessions), using the same definition as the
 * recordStudentLastClass trigger (handlers/student_last_class.js). Classes in
 * the future are ignored.
 *
 *   node dev-scripts/backfill_student_last_class.js --project alluwal-dev            dry run
 *   node dev-scripts/backfill_student_last_class.js --project alluwal-dev --apply    write
 *
 * With --apply every student's stored value is made equal to the computed one:
 * set when missing, corrected when it differs, removed when the student has no
 * class they were present in. Prints counts only — never names, emails or ids.
 */
const admin = require('firebase-admin');
const {presentStudent, toDate} = require('../handlers/student_last_class');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const projectFlag = args.indexOf('--project');
const projectId = projectFlag >= 0 ? args[projectFlag + 1] : '';
if (!projectId) throw new Error('Pass an explicit Firebase project with --project <id>');

admin.initializeApp({projectId});
const db = admin.firestore();
const {Timestamp, FieldValue} = admin.firestore;

(async () => {
  const now = Date.now();
  const sessions = await db.collection('livekit_sessions').get();
  const best = new Map();
  for (const doc of sessions.docs) {
    const data = doc.data() || {};
    const present = presentStudent(data);
    if (!present || present.start.getTime() > now) continue;
    const shiftId = str(data.shift_id) || doc.id;
    const current = best.get(present.studentId);
    if (!current || present.start.getTime() > current.start.getTime() ||
      (present.start.getTime() === current.start.getTime() && shiftId < current.shiftId)) {
      best.set(present.studentId, {start: present.start, shiftId});
    }
  }
  const students = await db.collection('users').where('user_type', '==', 'student').get();

  const counts = {sessionsRead: sessions.size, students: students.size, set: 0, corrected: 0, cleared: 0, unchanged: 0, noClass: 0};
  const writes = [];
  for (const doc of students.docs) {
    const data = doc.data() || {};
    const stored = toDate(data.last_class_at);
    const want = best.get(doc.id);
    if (!want) {
      if (stored || data.last_class_shift_id !== undefined) {
        counts.cleared += 1;
        writes.push({ref: doc.ref, data: {last_class_at: FieldValue.delete(), last_class_shift_id: FieldValue.delete()}});
      } else {
        counts.noClass += 1;
      }
      continue;
    }
    if (stored && stored.getTime() === want.start.getTime() && data.last_class_shift_id === want.shiftId) {
      counts.unchanged += 1;
      continue;
    }
    counts[stored ? 'corrected' : 'set'] += 1;
    writes.push({ref: doc.ref, data: {last_class_at: Timestamp.fromDate(want.start), last_class_shift_id: want.shiftId}});
  }

  if (apply) {
    for (let i = 0; i < writes.length; i += 400) {
      const batch = db.batch();
      for (const w of writes.slice(i, i + 400)) batch.update(w.ref, w.data);
      await batch.commit();
    }
  }
  console.log(JSON.stringify({project: projectId, apply, ...counts}, null, 2));
  process.exit(0);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});

function str(v) {
  return (v === null || v === undefined ? '' : String(v)).trim();
}
