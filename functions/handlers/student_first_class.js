/**
 * The date of each student's first attended class, kept on the student's user
 * document so the admin Users page can show it without reading any classes.
 *
 * Definition: the earliest `shift_start` of a teaching class (category
 * teaching, the default) that lists the student in `student_ids` and whose
 * status is completed, fullyCompleted or partiallyCompleted — the same
 * "attended their first class" signal that creates the family's first invoice
 * (finance_billing.js COMPLETED_STATUSES). Stored as:
 *
 *   users/{studentId}.first_class_at        Timestamp
 *   users/{studentId}.first_class_shift_id  string
 *
 * The trigger only ever moves the date earlier, so it reads one user document
 * per student when a class completes and writes nothing when the stored date
 * is already earlier. History (live + archived classes) is filled in by
 * dev-scripts/backfill_student_first_class.js, which reads through
 * utils/shifts_in_range.js.
 */
const admin = require('firebase-admin');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');

const ATTENDED_STATUSES = new Set(['completed', 'fullyCompleted', 'partiallyCompleted']);

const str = (v) => (v === null || v === undefined ? '' : String(v)).trim();

const toDate = (v) => {
  if (!v) return null;
  if (v instanceof Date) return Number.isNaN(v.getTime()) ? null : v;
  if (typeof v.toDate === 'function') {
    const d = v.toDate();
    return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
  }
  if (typeof v === 'string') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
};

const studentIdsOf = (shift) =>
  [...new Set((Array.isArray(shift && shift.student_ids) ? shift.student_ids : []).map(str).filter(Boolean))];

/** Whether a shift document counts as an attended teaching class. */
const isAttendedClass = (shift) => {
  if (!shift) return false;
  const category = str(shift.category || shift.shift_category || 'teaching').toLowerCase();
  if (category !== 'teaching') return false;
  if (!ATTENDED_STATUSES.has(str(shift.status))) return false;
  return toDate(shift.shift_start) !== null;
};

/**
 * What a shift write means for first-class dates: the students whose stored
 * date may need to move earlier, and the date. Null when the write cannot
 * change anyone's first class (not attended, or nothing relevant changed).
 */
const firstClassCandidate = (before, after) => {
  if (!isAttendedClass(after)) return null;
  const start = toDate(after.shift_start);
  const students = studentIdsOf(after);
  if (students.length === 0) return null;
  if (isAttendedClass(before)) {
    const beforeStart = toDate(before.shift_start);
    const beforeStudents = new Set(studentIdsOf(before));
    const sameStart = beforeStart && beforeStart.getTime() === start.getTime();
    const added = students.filter((id) => !beforeStudents.has(id));
    if (sameStart && added.length === 0) return null;
    if (sameStart) return {students: added, start};
  }
  return {students, start};
};

/** True when `start` should replace what the user document stores. */
const isEarlier = (stored, start) => {
  const current = toDate(stored);
  return !current || start.getTime() < current.getTime();
};

/**
 * Moves each student's first_class_at earlier when this class predates it.
 * Students without a user document, or whose user_type is not student, are
 * skipped (never created).
 */
const recordFirstClass = async ({db, Timestamp, shiftId, candidate}) => {
  const results = [];
  for (const studentId of candidate.students) {
    const ref = db.collection('users').doc(studentId);
    const outcome = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return 'no_user';
      const data = snap.data() || {};
      if (str(data.user_type).toLowerCase() !== 'student') return 'not_student';
      if (!isEarlier(data.first_class_at, candidate.start)) return 'unchanged';
      tx.update(ref, {
        first_class_at: Timestamp.fromDate(candidate.start),
        first_class_shift_id: shiftId,
      });
      return 'updated';
    });
    results.push({studentId, outcome});
  }
  return results;
};

const recordStudentFirstClass = onDocumentWritten(
  {document: 'teaching_shifts/{shiftId}', region: 'us-central1'},
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    const candidate = firstClassCandidate(before, after);
    if (!candidate) return;
    await recordFirstClass({
      db: admin.firestore(),
      Timestamp: admin.firestore.Timestamp,
      shiftId: event.params.shiftId,
      candidate,
    });
  },
);

module.exports = {
  recordStudentFirstClass,
  ATTENDED_STATUSES,
  isAttendedClass,
  firstClassCandidate,
  isEarlier,
  recordFirstClass,
  studentIdsOf,
  toDate,
};
