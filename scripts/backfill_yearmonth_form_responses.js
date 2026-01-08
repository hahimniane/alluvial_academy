/**
 * Migration Script: Backfill yearMonth for existing form_responses
 * 
 * Purpose: Add yearMonth field to existing form responses that don't have it
 * This enables monthly filtering and audit grouping.
 * 
 * Usage:
 *   node scripts/backfill_yearmonth_form_responses.js
 * 
 * Requirements:
 *   - Firebase Admin SDK credentials:
 *     * Option 1: Place serviceAccountKey.json in project root
 *     * Option 2: Run: gcloud auth application-default login
 * 
 * Safety:
 *   - Only updates documents that don't have yearMonth
 *   - Uses batched writes for efficiency
 *   - Logs all changes for audit trail
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    try {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'alluwal-academy'
      });
      console.log('✅ Initialized Firebase Admin with service account key\n');
    } catch (err) {
      console.error('❌ Error initializing Firebase Admin with service account:');
      console.error('   Error details:', err.message);
      process.exit(1);
    }
  } else {
    try {
      admin.initializeApp({
        projectId: 'alluwal-academy'
      });
      console.log('✅ Initialized Firebase Admin with application default credentials\n');
    } catch (err) {
      console.error('❌ Error initializing Firebase Admin:');
      console.error('   Please ensure you have either:');
      console.error('   1. A serviceAccountKey.json file in the project root, OR');
      console.error('   2. Application Default Credentials configured (gcloud auth application-default login)');
      console.error('   Error details:', err.message);
      process.exit(1);
    }
  }
}

const db = admin.firestore();

async function backfillYearMonth() {
  console.log('='.repeat(60));
  console.log('FORM RESPONSES YEARMONTH BACKFILL');
  console.log('='.repeat(60));
  console.log(`Started at: ${new Date().toISOString()}`);
  console.log('');

  let totalProcessed = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalErrors = 0;
  const orphans = []; // Responses without submittedAt

  try {
    // Query all form_responses
    const responsesRef = db.collection('form_responses');
    const snapshot = await responsesRef.get();

    console.log(`Found ${snapshot.size} total form responses`);
    console.log('');

    // Process in batches of 500 (Firestore limit)
    const batchSize = 500;
    let batch = db.batch();
    let batchCount = 0;

    for (const doc of snapshot.docs) {
      totalProcessed++;
      const data = doc.data();

      // Skip if already has yearMonth
      if (data.yearMonth) {
        totalSkipped++;
        continue;
      }

      // Try to derive yearMonth from submittedAt
      let yearMonth = null;

      if (data.submittedAt) {
        const submittedAt = data.submittedAt.toDate();
        const year = submittedAt.getFullYear();
        const month = String(submittedAt.getMonth() + 1).padStart(2, '0');
        yearMonth = `${year}-${month}`;
      } else {
        // No submittedAt - this is an orphan
        orphans.push({
          id: doc.id,
          formId: data.formId || 'unknown',
          userId: data.userId || 'unknown',
        });
        totalErrors++;
        continue;
      }

      // Update the document
      batch.update(doc.ref, { yearMonth });
      batchCount++;
      totalUpdated++;

      // Commit batch when full
      if (batchCount >= batchSize) {
        await batch.commit();
        console.log(`Committed batch of ${batchCount} updates`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${batchCount} updates`);
    }

    // Summary
    console.log('');
    console.log('='.repeat(60));
    console.log('SUMMARY');
    console.log('='.repeat(60));
    console.log(`Total processed: ${totalProcessed}`);
    console.log(`Total updated:   ${totalUpdated}`);
    console.log(`Total skipped:   ${totalSkipped} (already had yearMonth)`);
    console.log(`Total errors:    ${totalErrors} (orphans without submittedAt)`);
    console.log('');

    if (orphans.length > 0) {
      console.log('ORPHAN RESPONSES (need manual review):');
      console.log('-'.repeat(40));
      orphans.forEach(orphan => {
        console.log(`  ID: ${orphan.id}`);
        console.log(`    formId: ${orphan.formId}`);
        console.log(`    userId: ${orphan.userId}`);
      });
    }

    console.log('');
    console.log(`Completed at: ${new Date().toISOString()}`);

  } catch (error) {
    console.error('Fatal error during migration:', error);
    process.exit(1);
  }
}

// Run the migration
backfillYearMonth()
  .then(() => {
    console.log('Migration completed successfully');
    process.exit(0);
  })
  .catch(error => {
    console.error('Migration failed:', error);
    process.exit(1);
  });

