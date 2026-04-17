/**
 * fix-invoice-due-dates.js
 *
 * Migration: fix invoices where due_date was incorrectly set to the same
 * server timestamp as issued_date (a bug in the original createInvoice function).
 *
 * Detection: if abs(due_date - issued_date) < 120 seconds, the due_date was
 * never intentionally set and should be reset to issued_date + 7 days.
 *
 * Run once from the functions/ directory:
 *   node dev-scripts/fix-invoice-due-dates.js
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS or Firebase Admin SDK credentials.
 * Set FIREBASE_PROJECT env var or edit the projectId below.
 */

const admin = require('firebase-admin');

const PROJECT_ID = process.env.FIREBASE_PROJECT || 'alluwal-academy';
const DRY_RUN = process.env.DRY_RUN !== 'false'; // default: dry run
const DEFAULT_DAYS = 7; // days to add to issued_date for the new due_date

admin.initializeApp({projectId: PROJECT_ID});
const db = admin.firestore();

async function main() {
  console.log(`[fix-invoice-due-dates] project=${PROJECT_ID} dryRun=${DRY_RUN}`);

  const snap = await db.collection('invoices').get();
  console.log(`Loaded ${snap.size} invoices.`);

  let fixed = 0;
  let skipped = 0;
  const BATCH_SIZE = 400;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();

    const issuedTs = data.issued_date;
    const dueTs = data.due_date;

    if (!issuedTs || !dueTs) {
      console.log(`  SKIP ${doc.id}: missing issued_date or due_date`);
      skipped++;
      continue;
    }

    const issuedMs = issuedTs.toMillis();
    const dueMs = dueTs.toMillis();
    const diffSeconds = Math.abs(dueMs - issuedMs) / 1000;

    // If due_date is within 120 s of issued_date, it was set by the bug
    if (diffSeconds > 120) {
      skipped++;
      continue;
    }

    const newDueDate = new Date(issuedMs + DEFAULT_DAYS * 24 * 60 * 60 * 1000);
    const newDueTs = admin.firestore.Timestamp.fromDate(newDueDate);

    console.log(
      `  FIX ${doc.id}: issued=${new Date(issuedMs).toISOString()} ` +
      `old_due=${new Date(dueMs).toISOString()} ` +
      `new_due=${newDueDate.toISOString()}`
    );

    if (!DRY_RUN) {
      batch.update(doc.ref, {
        due_date: newDueTs,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      batchCount++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        console.log(`  Committed batch of ${batchCount}`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    fixed++;
  }

  if (!DRY_RUN && batchCount > 0) {
    await batch.commit();
    console.log(`  Committed final batch of ${batchCount}`);
  }

  console.log(`\nDone. Fixed: ${fixed}, Skipped: ${skipped}${DRY_RUN ? ' (DRY RUN — no writes)' : ''}`);
  if (DRY_RUN && fixed > 0) {
    console.log(`\nTo apply: DRY_RUN=false node dev-scripts/fix-invoice-due-dates.js`);
  }
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
