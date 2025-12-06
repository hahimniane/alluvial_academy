#!/usr/bin/env node
/**
 * Script to clean up orphaned timesheet entries (where the shift no longer exists)
 * 
 * Usage:
 *   node scripts/cleanup_orphaned_timesheets.js
 * 
 * Or from the functions directory:
 *   node ../scripts/cleanup_orphaned_timesheets.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
// Try to use existing initialization, or initialize from service account
if (!admin.apps.length) {
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  const fs = require('fs');
  
  // Check if service account key exists
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
    // Try to use application default credentials (from firebase login)
    try {
      admin.initializeApp({
        projectId: 'alluwal-academy'
      });
      console.log('✅ Initialized Firebase Admin with application default credentials\n');
    } catch (error) {
      console.error('❌ Error initializing Firebase Admin:');
      console.error('   Could not find serviceAccountKey.json and application default credentials failed');
      console.error('   Options:');
      console.error('   1. Run: firebase login');
      console.error('   2. Or place serviceAccountKey.json in project root');
      console.error('   Error details:', error.message);
      process.exit(1);
    }
  }
}

const db = admin.firestore();

async function cleanupOrphanedTimesheets() {
  console.log('🔧 Orphaned Timesheet Cleanup Script');
  console.log('=====================================\n');

  try {
    const timesheetCollection = db.collection('timesheet_entries');
    const shiftsCollection = db.collection('teaching_shifts');

    // Get all timesheet entries
    console.log('📋 Fetching all timesheet entries...');
    const timesheetSnapshot = await timesheetCollection.get();
    console.log(`   Found ${timesheetSnapshot.docs.length} timesheet entries\n`);

    if (timesheetSnapshot.docs.length === 0) {
      console.log('✅ No timesheet entries found. Nothing to clean up.');
      process.exit(0);
    }

    // Check each timesheet entry
    console.log('🔍 Checking for orphaned entries...');
    const orphanedEntries = {}; // timesheetId -> shiftId
    let checkedCount = 0;
    let batchCount = 0;
    let batch = db.batch();
    const batchSize = 500; // Firestore batch limit

    for (const doc of timesheetSnapshot.docs) {
      const data = doc.data();
      const shiftId = data.shift_id || data.shiftId;

      if (!shiftId || shiftId === '') {
        // Timesheet without shift_id - consider it orphaned
        orphanedEntries[doc.id] = 'no_shift_id';
        batch.delete(doc.ref);
        batchCount++;

        // Commit batch if we reach the limit
        if (batchCount >= batchSize) {
          await batch.commit();
          console.log(`   Committed batch of ${batchCount} deletions...`);
          batch = db.batch(); // Create new batch
          batchCount = 0;
        }
        checkedCount++;
        continue;
      }

      // Check if shift exists
      const shiftDoc = await shiftsCollection.doc(shiftId).get();
      if (!shiftDoc.exists) {
        orphanedEntries[doc.id] = shiftId;
        batch.delete(doc.ref);
        batchCount++;

        // Commit batch if we reach the limit
        if (batchCount >= batchSize) {
          await batch.commit();
          console.log(`   Committed batch of ${batchCount} deletions...`);
          batch = db.batch(); // Create new batch
          batchCount = 0;
        }
      }

      checkedCount++;
      if (checkedCount % 100 === 0) {
        console.log(`   Checked ${checkedCount}/${timesheetSnapshot.docs.length} entries...`);
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      console.log(`   Committed final batch of ${batchCount} deletions...`);
    }

    console.log('\n📊 Cleanup Summary:');
    console.log(`   Total entries checked: ${checkedCount}`);
    console.log(`   Orphaned entries found: ${Object.keys(orphanedEntries).length}`);
    console.log(`   Entries deleted: ${Object.keys(orphanedEntries).length}`);

    if (Object.keys(orphanedEntries).length > 0) {
      console.log('\n🗑️  Deleted orphaned timesheet IDs:');
      for (const [timesheetId, shiftId] of Object.entries(orphanedEntries)) {
        const shiftInfo = shiftId === 'no_shift_id' ? 'MISSING' : shiftId;
        console.log(`   - ${timesheetId} (shift: ${shiftInfo})`);
      }
    }

    console.log('\n✅ Cleanup completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error during cleanup:', error);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  }
}

// Run the cleanup
cleanupOrphanedTimesheets();

