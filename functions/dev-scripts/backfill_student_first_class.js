/**
 * Fills users/{studentId}.first_class_at / first_class_shift_id from every
 * attended class in history — live AND archived shifts, read through
 * utils/shifts_in_range.js — using the same definition as the
 * recordStudentFirstClass trigger (handlers/student_first_class.js).
 *
 *   node dev-scripts/backfill_student_first_class.js --project alluwal-dev            dry run
 *   node dev-scripts/backfill_student_first_class.js --project alluwal-dev --apply    write
 *
 * With --apply every student's stored value is made equal to the computed one:
 * set when missing, corrected when it differs, and removed when the student has
 * no attended class at all (e.g. a class that was later marked missed).
 * Prints counts only — never names, emails or ids.
 */
const admin = require('firebase-admin');
const {shiftsInRange} = require('../utils/shifts_in_range');
const {isAttendedClass, studentIdsOf, toDate} = require('../handlers/student_first_class');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const projectFlag = args.indexOf('--project');
const projectId = projectFlag >= 0 ? args[projectFlag + 1] : '';
if (!projectId) throw new Error('Pass an explicit Firebase project with --project <id>');

admin.initializeApp({projectId});
const db = admin.firestore();
const {Timestamp, FieldValue} = admin.firestore;

/** Earliest attended class per student: Map<studentId, {start: Date, shiftId}>. */
const earliestAttended = (docs) => {
  const best = new Map();
  for (const doc of docs) {
    const data = doc.data() || {};
    if (!isAttendedClass(data)) continue;
    const start = toDate(data.shift_start);
    for (const studentId of studentIdsOf(data)) {
      const current = best.get(studentId);
      if (!current || start.getTime() < current.start.getTime() ||
        (start.getTime() === current.start.getTime() && doc.id < current.shiftId)) {
        best.set(studentId, {start, shiftId: doc.id});
      }
    }
  }
  return best;
};

(async () => {
  const shifts = await shiftsInRange(db, {start: new Date(0), end: new Date('2100-01-01T00:00:00Z')});
  const best = earliestAttended(shifts);
  const students = await db.collection('users').where('user_type', '==', 'student').get();

  const counts = {shiftsRead: shifts.length, students: students.size, set: 0, corrected: 0, cleared: 0, unchanged: 0, noClass: 0};
  const writes = [];
  for (const doc of students.docs) {
    const data = doc.data() || {};
    const stored = toDate(data.first_class_at);
    const want = best.get(doc.id);
    if (!want) {
      if (stored || data.first_class_shift_id !== undefined) {
        counts.cleared += 1;
        writes.push({ref: doc.ref, data: {first_class_at: FieldValue.delete(), first_class_shift_id: FieldValue.delete()}});
      } else {
        counts.noClass += 1;
      }
      continue;
    }
    if (stored && stored.getTime() === want.start.getTime() && data.first_class_shift_id === want.shiftId) {
      counts.unchanged += 1;
      continue;
    }
    counts[stored ? 'corrected' : 'set'] += 1;
    writes.push({ref: doc.ref, data: {first_class_at: Timestamp.fromDate(want.start), first_class_shift_id: want.shiftId}});
  }

  if (apply) {
    for (let i = 0; i < writes.length; i += 400) {
      const batch = db.batch();
      for (const w of writes.slice(i, i + 400)) batch.update(w.ref, w.data);
      await batch.commit();
    }
  }
  console.log(JSON.stringify({project: projectId, mode: apply ? 'apply' : 'dry-run', ...counts, writes: writes.length}));
  process.exit(0);
})().catch((error) => {
  console.error('backfill failed:', error.message);
  process.exit(1);
});
