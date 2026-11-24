/**
 * The date of each student's most recent class they were actually present in,
 * kept on the student's user document so the admin Users page can show it
 * without reading any classes.
 *
 * Definition: the latest `shift_start` of a class whose presence record
 * (`livekit_sessions/{shiftId}_{uid}`) shows the student joined — a join, time
 * in class, or a first-join time — the same "present" signal the monthly
 * invoice uses (finance_billing.js attendedLastMonth). Stored as:
 *
 *   users/{studentId}.last_class_at        Timestamp
 *   users/{studentId}.last_class_shift_id  string
 *
 * The trigger only acts when a record turns from "not joined" to "joined" (or
 * its class moves), and only ever moves the date later, so a class's many
 * presence updates cost one user read. History is filled in by
 * dev-scripts/backfill_student_last_class.js.
 */
const admin = require('firebase-admin');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');

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

/** The student a presence record is about, when the record shows they were in class. */
const presentStudent = (session) => {
  if (!session) return null;
  const uid = str(session.user_id);
  const students = Array.isArray(session.student_ids) ? session.student_ids.map(str) : [];
  if (!uid || !students.includes(uid)) return null;
  const joined = Number(session.join_count) > 0 ||
    Number(session.total_presence_seconds) > 0 ||
    Boolean(session.first_joined_at);
  if (!joined) return null;
  const start = toDate(session.shift_start);
  return start ? {studentId: uid, start} : null;
};

/** What a presence write means for the student's last class, or null when nothing can change. */
const lastClassCandidate = (before, after) => {
  const now = presentStudent(after);
  if (!now) return null;
  const was = presentStudent(before);
  if (was && was.studentId === now.studentId && was.start.getTime() === now.start.getTime()) return null;
  return now;
};

/** True when `start` should replace what the user document stores. */
const isLater = (stored, start) => {
  const current = toDate(stored);
  return !current || start.getTime() > current.getTime();
};

/**
 * Moves the student's last_class_at later when this class is more recent.
 * A missing user document, or one that is not a student, is skipped.
 */
const recordLastClass = async ({db, Timestamp, shiftId, candidate}) => {
  const ref = db.collection('users').doc(candidate.studentId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return 'no_user';
    const data = snap.data() || {};
    if (str(data.user_type).toLowerCase() !== 'student') return 'not_student';
    if (!isLater(data.last_class_at, candidate.start)) return 'unchanged';
    tx.update(ref, {
      last_class_at: Timestamp.fromDate(candidate.start),
      last_class_shift_id: shiftId,
    });
    return 'updated';
  });
};

const recordStudentLastClass = onDocumentWritten(
  {document: 'livekit_sessions/{sessionId}', region: 'us-central1'},
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    const candidate = lastClassCandidate(before, after);
    if (!candidate) return;
    await recordLastClass({
      db: admin.firestore(),
      Timestamp: admin.firestore.Timestamp,
      shiftId: str(after.shift_id) || event.params.sessionId,
      candidate,
    });
  },
);

module.exports = {
  recordStudentLastClass,
  presentStudent,
  lastClassCandidate,
  isLater,
  recordLastClass,
  toDate,
};
