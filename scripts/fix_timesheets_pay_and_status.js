#!/usr/bin/env node
/**
 * Comprehensive script to fix all timesheet and shift issues:
 * 1. Process ALL shifts (regardless of status) and fix status if needed
 * 2. Fix payment amounts for ALL timesheets based on actual time worked
 * 3. Ensure payment ALWAYS matches time worked - recalculate if ANY mismatch found
 * 4. Fix approved shifts/timesheets where payment doesn't reflect actual work time
 * 5. Fix overpaid shifts (> hourly rate for scheduled duration)
 * 6. Fix underpaid shifts (payment less than time worked * hourly rate)
 * 
 * Usage:
 *   node scripts/fix_timesheets_pay_and_status.js [--dry-run] [--days=<number>]
 * 
 * Options:
 *   --dry-run      : Preview changes without applying them
 *   --days=<number>: Only process shifts from the last X days (e.g. --days=7)
 *                    If omitted, all shifts are processed
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  const fs = require('fs');
  
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
const DRY_RUN = process.argv.includes('--dry-run');

// Parse --days=<number> argument
const daysArg = process.argv.find(arg => arg.startsWith('--days='));
const DAYS_FILTER = daysArg ? parseInt(daysArg.split('=')[1], 10) : null;

if (DAYS_FILTER !== null && (isNaN(DAYS_FILTER) || DAYS_FILTER <= 0)) {
  console.error('❌ Invalid --days value. Must be a positive integer (e.g. --days=7)');
  process.exit(1);
}

async function fixAllIssues() {
  console.log('🔧 Comprehensive Timesheet & Shift Fix Script');
  console.log('============================================\n');
  
  if (DRY_RUN) {
    console.log('⚠️  DRY RUN MODE - No changes will be applied');
  }

  if (DAYS_FILTER !== null) {
    const since = new Date();
    since.setDate(since.getDate() - DAYS_FILTER);
    console.log(`📅 DATE FILTER   - Processing shifts from the last ${DAYS_FILTER} day(s) (since ${since.toLocaleDateString()})`);
  } else {
    console.log('📅 DATE FILTER   - None (processing ALL shifts)');
  }

  console.log('');

  const stats = {
    shiftsFixed: 0,
    shiftsChecked: 0,
    timesheetsFixed: 0,
    timesheetsChecked: 0,
    zeroPayFixed: 0,
    overpaidFixed: 0,
    mismatchedPayFixed: 0,
    approvedPayFixed: 0,
    errors: []
  };

  // Compute the cutoff date once
  const cutoffDate = DAYS_FILTER !== null
    ? admin.firestore.Timestamp.fromDate((() => {
        const d = new Date();
        d.setDate(d.getDate() - DAYS_FILTER);
        d.setHours(0, 0, 0, 0);
        return d;
      })())
    : null;

  try {
    // Step 1: Fix shifts
    console.log('📋 Step 1: Checking shifts for status issues...');

    let shiftsQuery = db.collection('teaching_shifts');
    if (cutoffDate) {
      shiftsQuery = shiftsQuery.where('shift_start', '>=', cutoffDate);
    }
    const shiftsSnapshot = await shiftsQuery.get();
    
    stats.shiftsChecked = shiftsSnapshot.docs.length;
    console.log(`   Found ${stats.shiftsChecked} shifts to check\n`);

    let shiftBatch = db.batch();
    let shiftBatchCount = 0;
    const shiftBatchSize = 500;

    for (const shiftDoc of shiftsSnapshot.docs) {
      const shiftData = shiftDoc.data();
      const shiftId = shiftDoc.id;
      const shiftEnd = shiftData.shift_end?.toDate();
      const shiftStart = shiftData.shift_start?.toDate();
      
      if (!shiftEnd || !shiftStart) continue;

      const now = new Date();
      
      const shouldCheckStatus =
        shiftEnd < now ||
        (shiftData.status === 'active' && shiftEnd < now) ||
        (shiftData.status === 'scheduled' && shiftEnd < now);
      
      if (shouldCheckStatus) {
        const timesheetsSnapshot = await db.collection('timesheet_entries')
          .where('shift_id', '==', shiftId)
          .get();
        
        let totalWorkedMinutes = 0;
        let hasClockIn = shiftData.clock_in_time != null;
        
        for (const timesheetDoc of timesheetsSnapshot.docs) {
          const timesheetData = timesheetDoc.data();
          const clockIn = timesheetData.clock_in_timestamp;
          const clockOut = timesheetData.clock_out_timestamp;
          
          if (clockIn) {
            hasClockIn = true;
            const endTime = clockOut?.toDate() || shiftEnd;
            const worked = Math.floor((endTime - clockIn.toDate()) / 1000 / 60);
            if (worked > 0) totalWorkedMinutes += worked;
          }
        }
        
        const scheduledMinutes = Math.floor((shiftEnd - shiftStart) / 1000 / 60);
        const toleranceMinutes = 1;
        
        let newStatus;
        let completionState;
        
        if (!hasClockIn || totalWorkedMinutes === 0) {
          newStatus = 'missed';
          completionState = 'none';
        } else if (totalWorkedMinutes + toleranceMinutes >= scheduledMinutes) {
          newStatus = 'fullyCompleted';
          completionState = 'full';
        } else {
          newStatus = 'partiallyCompleted';
          completionState = 'partial';
        }
        
        const updateData = {
          status: newStatus,
          completion_state: completionState,
          worked_minutes: totalWorkedMinutes,
          last_modified: admin.firestore.FieldValue.serverTimestamp()
        };
        
        if (shiftData.status === 'active' && !shiftData.clock_out_time) {
          updateData.clock_out_time = admin.firestore.Timestamp.fromDate(shiftEnd);
        }
        
        if (!DRY_RUN) {
          shiftBatch.update(shiftDoc.ref, updateData);
          shiftBatchCount++;
          
          if (shiftBatchCount >= shiftBatchSize) {
            await shiftBatch.commit();
            console.log(`   Committed batch of ${shiftBatchCount} shift updates...`);
            shiftBatch = db.batch();
            shiftBatchCount = 0;
          }
        }
        
        stats.shiftsFixed++;
        console.log(`   ✓ Shift ${shiftId}: ${shiftData.status} → ${newStatus} (worked: ${totalWorkedMinutes} min)`);
      }
    }

    if (!DRY_RUN && shiftBatchCount > 0) {
      await shiftBatch.commit();
      console.log(`   Committed final batch of ${shiftBatchCount} shift updates...`);
    }

    console.log(`\n✅ Fixed ${stats.shiftsFixed} shifts\n`);

    // Step 2: Fix timesheet payment issues
    console.log('📋 Step 2: Fixing timesheet payment issues...');

    // Collect shift IDs that matched the date filter (to filter timesheets consistently)
    const filteredShiftIds = new Set(shiftsSnapshot.docs.map(d => d.id));

    // We always fetch all timesheet entries, then filter by shift_id if a date filter is active.
    // (Firestore doesn't support querying timesheets by shift date directly without a denormalized field.)
    const timesheetsSnapshot = await db.collection('timesheet_entries').get();
    stats.timesheetsChecked = cutoffDate
      ? timesheetsSnapshot.docs.filter(d => {
          const sid = d.data().shift_id || d.data().shiftId;
          return sid && filteredShiftIds.has(sid);
        }).length
      : timesheetsSnapshot.docs.length;

    console.log(`   Found ${stats.timesheetsChecked} timesheet entries to check\n`);

    let timesheetBatch = db.batch();
    let timesheetBatchCount = 0;
    const timesheetBatchSize = 500;

    for (const timesheetDoc of timesheetsSnapshot.docs) {
      const timesheetData = timesheetDoc.data();
      const timesheetId = timesheetDoc.id;
      const shiftId = timesheetData.shift_id || timesheetData.shiftId;
      
      if (!shiftId) continue;

      // If a date filter is active, skip timesheets that don't belong to a matching shift
      if (cutoffDate && !filteredShiftIds.has(shiftId)) continue;

      const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
      if (!shiftDoc.exists) continue;

      const shiftData = shiftDoc.data();
      const shiftStart = shiftData.shift_start?.toDate();
      const shiftEnd = shiftData.shift_end?.toDate();
      const hourlyRate = shiftData.hourly_rate || timesheetData.hourly_rate || 0;

      if (!shiftStart || !shiftEnd || hourlyRate <= 0) continue;

      const clockIn = timesheetData.clock_in_timestamp?.toDate();
      const clockOut = timesheetData.clock_out_timestamp?.toDate();
      
      if (!clockIn) continue;

      const effectiveStartTime = clockIn < shiftStart ? shiftStart : clockIn;
      const effectiveEndTime = clockOut && clockOut > shiftEnd ? shiftEnd : (clockOut || shiftEnd);
      
      const rawDuration = Math.round((effectiveEndTime - effectiveStartTime) / 1000 / 60);
      const scheduledDuration = Math.round((shiftEnd - shiftStart) / 1000 / 60);
      
      const billableMinutes = Math.min(Math.max(0, rawDuration), scheduledDuration);
      const hoursWorked = billableMinutes / 60.0;
      const correctPayment = Math.round(hoursWorked * hourlyRate * 100) / 100;
      
      const currentPayment = timesheetData.payment_amount || timesheetData.total_pay || 0;
      const timesheetStatus = timesheetData.status || 'pending';
      
      let needsFix = false;
      let fixReason = '';
      const updateData = {};
      
      const paymentTolerance = 0.01;
      const paymentMismatch = Math.abs(currentPayment - correctPayment) > paymentTolerance;
      
      if (paymentMismatch) {
        updateData.payment_amount = correctPayment;
        updateData.total_pay = correctPayment;
        if (billableMinutes > 0) updateData.hourly_rate = hourlyRate;
        needsFix = true;
        
        if (billableMinutes === 0 && currentPayment > paymentTolerance) {
          stats.zeroPayFixed++;
          fixReason = 'no work time but has payment';
        } else if (currentPayment === 0 && billableMinutes > 0) {
          stats.zeroPayFixed++;
          fixReason = 'zero payment';
        } else if (currentPayment > correctPayment + paymentTolerance) {
          stats.overpaidFixed++;
          fixReason = 'overpaid';
        } else {
          stats.mismatchedPayFixed++;
          fixReason = 'underpaid/mismatch';
        }
        
        if (timesheetStatus === 'approved') {
          stats.approvedPayFixed++;
          console.log(`   ⚠️  APPROVED timesheet mismatch: ${timesheetId} - Status: ${timesheetStatus}, Current: $${currentPayment.toFixed(2)}, Correct: $${correctPayment.toFixed(2)} (${billableMinutes} min @ $${hourlyRate}/hr) - ${fixReason}`);
        } else {
          console.log(`   ⚠️  Payment mismatch: ${timesheetId} - Status: ${timesheetStatus}, Current: $${currentPayment.toFixed(2)}, Correct: $${correctPayment.toFixed(2)} (${billableMinutes} min @ $${hourlyRate}/hr) - ${fixReason}`);
        }
      } else if (billableMinutes > 0 && !timesheetData.payment_amount && currentPayment > 0) {
        updateData.payment_amount = correctPayment;
        needsFix = true;
      }

      if (needsFix) {
        stats.timesheetsFixed++;
        if (!DRY_RUN) {
          updateData.updated_at = admin.firestore.FieldValue.serverTimestamp();
          timesheetBatch.update(timesheetDoc.ref, updateData);
          timesheetBatchCount++;
          
          if (timesheetBatchCount >= timesheetBatchSize) {
            await timesheetBatch.commit();
            console.log(`   Committed batch of ${timesheetBatchCount} timesheet updates...`);
            timesheetBatch = db.batch();
            timesheetBatchCount = 0;
          }
        }
      }
    }

    if (!DRY_RUN && timesheetBatchCount > 0) {
      await timesheetBatch.commit();
      console.log(`   Committed final batch of ${timesheetBatchCount} timesheet updates...`);
    }

    // Summary
    console.log('\n📊 Fix Summary:');
    console.log('================');
    if (DAYS_FILTER !== null) {
      console.log(`   Date range      : Last ${DAYS_FILTER} day(s)`);
    }
    console.log(`   Shifts checked  : ${stats.shiftsChecked}`);
    console.log(`   Shifts fixed    : ${stats.shiftsFixed}`);
    console.log(`   Timesheets checked: ${stats.timesheetsChecked}`);
    console.log(`   Timesheets fixed  : ${stats.timesheetsFixed}`);
    console.log(`   Zero pay fixed    : ${stats.zeroPayFixed}`);
    console.log(`   Overpaid fixed    : ${stats.overpaidFixed}`);
    console.log(`   Pay mismatch fixed: ${stats.mismatchedPayFixed}`);
    console.log(`   Approved fixed    : ${stats.approvedPayFixed}`);

    if (stats.errors.length > 0) {
      console.log(`\n⚠️  Errors encountered: ${stats.errors.length}`);
      stats.errors.forEach(err => console.log(`   - ${err}`));
    }

    if (DRY_RUN) {
      console.log('\n⚠️  This was a DRY RUN - no changes were applied');
      console.log('   Run without --dry-run to apply changes');
    } else {
      console.log('\n✅ All fixes completed successfully!');
    }

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error during fix:', error);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  }
}

fixAllIssues();
