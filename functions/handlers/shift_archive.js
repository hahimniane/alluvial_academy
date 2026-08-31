const admin = require('firebase-admin');
const {onSchedule} = require('firebase-functions/v2/scheduler');

const LIVE_COLLECTION = 'teaching_shifts';
const ARCHIVE_COLLECTION = 'teaching_shifts_archive';

// Shifts whose class window ended this many days ago move to the archive.
// The live collection then only carries recent history + the generated
// future, which is what both web apps hydrate — old shifts stop costing a
// document read on every schedule load.
const RETENTION_DAYS = 60;

// Per-run ceiling so a nightly run stays far from function limits; the
// backlog simply drains over consecutive nights.
const MAX_DOCS_PER_RUN = 3000;

/**
 * Moves old finished shifts into `teaching_shifts_archive` (same doc ids,
 * plus `archived_at`). Never touches:
 * - shifts still marked `active` (a 60-day-old "active" shift is data damage
 *   worth surfacing, not silently archiving),
 * - the base/anchor shift of a template that is still active (its id IS the
 *   template id and series editing resolves through it).
 * Timesheets, audits and invoices live in their own collections and keep
 * working; anything that needs an archived shift can read the archive.
 */
const archiveOldShiftsCore = async ({maxDocs = MAX_DOCS_PER_RUN} = {}) => {
  const db = admin.firestore();
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - RETENTION_DAYS * 24 * 3600e3),
  );

  const activeTemplateIds = new Set();
  const templatesSnap = await db
    .collection('shift_templates')
    .where('is_active', '==', true)
    .get();
  templatesSnap.forEach((doc) => activeTemplateIds.add(doc.id));

  let moved = 0;
  let skippedActive = 0;
  let skippedAnchors = 0;
  let cursor = null;

  while (moved < maxDocs) {
    let query = db
      .collection(LIVE_COLLECTION)
      .where('shift_end', '<', cutoff)
      .orderBy('shift_end')
      .limit(300);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) break;
    cursor = snap.docs[snap.docs.length - 1];

    const movable = [];
    for (const doc of snap.docs) {
      const status = ((doc.data() || {}).status || '').toString().toLowerCase();
      if (status === 'active') {
        skippedActive += 1;
        continue;
      }
      if (activeTemplateIds.has(doc.id)) {
        skippedAnchors += 1;
        continue;
      }
      movable.push(doc);
      if (moved + movable.length >= maxDocs) break;
    }

    // 250 moves = 500 batch ops (set + delete), the Firestore batch ceiling.
    for (let i = 0; i < movable.length; i += 250) {
      const chunk = movable.slice(i, i + 250);
      const batch = db.batch();
      for (const doc of chunk) {
        batch.set(db.collection(ARCHIVE_COLLECTION).doc(doc.id), {
          ...doc.data(),
          archived_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        batch.delete(doc.ref);
      }
      await batch.commit();
      moved += chunk.length;
    }
  }

  console.log(
    `archiveOldShifts: moved=${moved} skippedActive=${skippedActive} skippedAnchors=${skippedAnchors} cutoff=${cutoff.toDate().toISOString()}`,
  );
  return {moved, skippedActive, skippedAnchors};
};

// 03:30 ET, after the nightly shift generation — the two never contend.
const archiveOldShifts = onSchedule(
  {schedule: '30 3 * * *', timeZone: 'America/New_York', memory: '512MiB'},
  async () => {
    await archiveOldShiftsCore({});
  },
);

module.exports = {
  archiveOldShifts,
  archiveOldShiftsCore,
};
