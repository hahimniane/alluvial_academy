/**
 * Which students still have a class coming up: an active weekly schedule, or
 * a scheduled class from `now` on. This looks forward only, so the live
 * collection is the whole truth: the archive holds classes that ended more
 * than 60 days ago and never an upcoming one. (Period totals — pay, invoices,
 * attendance — read through shifts_in_range instead.)
 */
const str = (v) => (v == null ? '' : String(v)).trim();

const studentsWithUpcomingClasses = async (db, candidateIds, now) => {
  const withClasses = new Set();
  const templates = await db.collection('shift_templates').where('is_active', '==', true).select('student_ids').get();
  for (const doc of templates.docs) {
    for (const id of (doc.data() || {}).student_ids || []) withClasses.add(str(id));
  }
  const unknown = [...new Set(candidateIds.map(str).filter(Boolean))].filter((id) => !withClasses.has(id));
  await Promise.all(unknown.map(async (id) => {
    const snap = await db.collection('teaching_shifts')
      .where('student_ids', 'array-contains', id)
      .where('shift_start', '>=', now)
      .limit(5)
      .get();
    if (snap.docs.some((d) => str((d.data() || {}).status).toLowerCase() === 'scheduled')) withClasses.add(id);
  }));
  return withClasses;
};

module.exports = {studentsWithUpcomingClasses};
