/**
 * Teaching shifts for a period, from the live collection AND the archive.
 *
 * Classes whose window ended more than 60 days ago move nightly from
 * `teaching_shifts` to `teaching_shifts_archive`. Anything that counts a
 * period — invoices, attendance reports, pay — must read both, or the early
 * days of the month silently vanish once they age out. A guard test refuses
 * new range queries on the live collection outside this module.
 */
const LIVE = 'teaching_shifts';
const ARCHIVE = 'teaching_shifts_archive';

const shiftsInRange = async (db, {start, end, endInclusive = false, teacherId = null}) => {
  const {Timestamp} = require('firebase-admin').firestore;
  const toTs = (v) => (v instanceof Date ? Timestamp.fromDate(v) : v);
  const build = (collection) => {
    let q = db.collection(collection);
    if (teacherId) q = q.where('teacher_id', '==', teacherId);
    q = q.where('shift_start', '>=', toTs(start));
    return endInclusive ? q.where('shift_start', '<=', toTs(end)) : q.where('shift_start', '<', toTs(end));
  };
  const live = await build(LIVE).get();
  const docs = [...live.docs];
  const seen = new Set(docs.map((d) => d.id));
  const archived = await build(ARCHIVE).get();
  for (const d of archived.docs) {
    if (!seen.has(d.id)) {
      seen.add(d.id);
      docs.push(d);
    }
  }
  return docs;
};

/** Shift documents by id, looking in the archive for any the live collection no longer holds. */
const shiftsByIds = async (db, ids) => {
  const {FieldPath} = require('firebase-admin').firestore;
  const wanted = [...new Set((ids || []).map((v) => String(v || '').trim()).filter(Boolean))];
  const found = new Map();
  for (const collection of [LIVE, ARCHIVE]) {
    const missing = wanted.filter((id) => !found.has(id));
    for (let i = 0; i < missing.length; i += 10) {
      const snap = await db.collection(collection).where(FieldPath.documentId(), 'in', missing.slice(i, i + 10)).get();
      for (const d of snap.docs) found.set(d.id, d);
    }
    if (found.size === wanted.length) break;
  }
  return wanted.map((id) => found.get(id)).filter(Boolean);
};

module.exports = {shiftsInRange, shiftsByIds, LIVE, ARCHIVE};
