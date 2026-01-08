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
 * This script will:
 * - Process all shifts in the database (not filtered by status)
 * - Check ALL timesheets and compare payment against actual time worked
 * - Fix payment even if timesheet is already approved
 * - Recalculate payment based on: billable minutes * hourly rate
 * 
 * Usage:
 *   node scripts/fix_timesheets_pay_and_status.js [--dry-run]
 * 
 * Options:
 *   --dry-run: Preview changes without applying them
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

async function fixAllIssues() {
  console.log('🔧 Comprehensive Timesheet & Shift Fix Script');
  console.log('============================================\n');
  
  if (DRY_RUN) {
    console.log('⚠️  DRY RUN MODE - No changes will be applied\n');
  }

  const stats = {
    shiftsFixed: 0,
    shiftsChecked: 0,
    timesheetsFixed: 0,
    timesheetsChecked: 0,
    zeroPayFixed: 0,
    overpaidFixed: 0,
    mismatchedPayFixed: 0, // Payment doesn't match time worked
    approvedPayFixed: 0, // Approved but payment is wrong
    errors: []
  };

  try {
    // Step 1: Fix shifts that are still "active" but should be completed
    // Process ALL shifts to ensure status matches actual completion
    console.log('📋 Step 1: Checking ALL shifts for status issues...');
    const shiftsSnapshot = await db.collection('teaching_shifts').get();
    
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
      
      if (!shiftEnd || !shiftStart) {
        continue;
      }

      const now = new Date();
      
      // Check all shifts - fix status if it doesn't match actual completion
      // Process shifts where end time has passed OR where status doesn't match completion
      const shouldCheckStatus = shiftEnd < now || 
        (shiftData.status === 'active' && shiftEnd < now) ||
        (shiftData.status === 'scheduled' && shiftEnd < now);
      
      if (shouldCheckStatus) {
        // Get timesheet entries for this shift
        const timesheetsSnapshot = await db.collection('timesheet_entries')
          .where('shift_id', '==', shiftId)
          .get();
        
        let totalWorkedMinutes = 0;
        let hasClockIn = shiftData.clock_in_time != null;
        
        // Calculate worked minutes from timesheet entries
        for (const timesheetDoc of timesheetsSnapshot.docs) {
          const timesheetData = timesheetDoc.data();
          const clockIn = timesheetData.clock_in_timestamp;
          const clockOut = timesheetData.clock_out_timestamp;
          
          if (clockIn) {
            hasClockIn = true;
            const endTime = clockOut?.toDate() || shiftEnd;
            const worked = Math.floor((endTime - clockIn.toDate()) / 1000 / 60);
            if (worked > 0) {
              totalWorkedMinutes += worked;
            }
          }
        }
        
        // Determine new status
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
        
        // If shift was active but should be completed, ensure clock_out_time is set
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

    // Step 2: Fix all timesheet payment issues
    console.log('📋 Step 2: Fixing timesheet payment issues...');
    const timesheetsSnapshot = await db.collection('timesheet_entries').get();
    stats.timesheetsChecked = timesheetsSnapshot.docs.length;
    console.log(`   Found ${stats.timesheetsChecked} timesheet entries to check\n`);

    let timesheetBatch = db.batch();
    let timesheetBatchCount = 0;
    const timesheetBatchSize = 500;

    for (const timesheetDoc of timesheetsSnapshot.docs) {
      const timesheetData = timesheetDoc.data();
      const timesheetId = timesheetDoc.id;
      const shiftId = timesheetData.shift_id || timesheetData.shiftId;
      
      if (!shiftId) {
        continue; // Skip orphaned entries (handled by cleanup script)
      }

      // Get shift data
      const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
      if (!shiftDoc.exists) {
        continue; // Skip orphaned entries
      }

      const shiftData = shiftDoc.data();
      const shiftStart = shiftData.shift_start?.toDate();
      const shiftEnd = shiftData.shift_end?.toDate();
      const hourlyRate = shiftData.hourly_rate || timesheetData.hourly_rate || 0;

      if (!shiftStart || !shiftEnd || hourlyRate <= 0) {
        continue;
      }

      // Get clock-in and clock-out times
      const clockIn = timesheetData.clock_in_timestamp?.toDate();
      const clockOut = timesheetData.clock_out_timestamp?.toDate();
      
      if (!clockIn) {
        continue; // No clock-in, can't calculate payment
      }

      // Cap start time to shift start (no payment for early clock-ins)
      const effectiveStartTime = clockIn < shiftStart ? shiftStart : clockIn;
      
      // Cap end time to shift end (no payment for late clock-outs)
      const effectiveEndTime = clockOut && clockOut > shiftEnd ? shiftEnd : (clockOut || shiftEnd);
      
      // Calculate duration
      const rawDuration = Math.floor((effectiveEndTime - effectiveStartTime) / 1000 / 60); // minutes
      const scheduledDuration = Math.floor((shiftEnd - shiftStart) / 1000 / 60); // minutes
      
      // Cap total duration to scheduled duration (prevent overpayment)
      const billableMinutes = Math.min(Math.max(0, rawDuration), scheduledDuration);
      const hoursWorked = billableMinutes / 60.0;
      const correctPayment = Math.round(hoursWorked * hourlyRate * 100) / 100; // Round to 2 decimals
      
      // Get current payment
      const currentPayment = timesheetData.payment_amount || timesheetData.total_pay || 0;
      const timesheetStatus = timesheetData.status || 'pending';
      
      // Check if payment needs fixing
      let needsFix = false;
      let fixReason = '';
      const updateData = {};
      
      // Tolerance for rounding differences (1 cent)
      const paymentTolerance = 0.01;
      const paymentMismatch = Math.abs(currentPayment - correctPayment) > paymentTolerance;
      
      // ALWAYS check if payment matches time worked - regardless of status (including approved)
      // This includes cases where billableMinutes is 0 (payment should be 0) or where payment doesn't match
      if (paymentMismatch) {
        updateData.payment_amount = correctPayment;
        updateData.total_pay = correctPayment;
        if (billableMinutes > 0) {
          updateData.hourly_rate = hourlyRate;
        }
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
        
        // Track approved timesheets that are being fixed
        if (timesheetStatus === 'approved') {
          stats.approvedPayFixed++;
          console.log(`   ⚠️  APPROVED timesheet mismatch: ${timesheetId} - Status: ${timesheetStatus}, Current: $${currentPayment.toFixed(2)}, Correct: $${correctPayment.toFixed(2)} (${billableMinutes} min @ $${hourlyRate}/hr) - ${fixReason}`);
        } else {
          console.log(`   ⚠️  Payment mismatch: ${timesheetId} - Status: ${timesheetStatus}, Current: $${currentPayment.toFixed(2)}, Correct: $${correctPayment.toFixed(2)} (${billableMinutes} min @ $${hourlyRate}/hr) - ${fixReason}`);
        }
      } else if (billableMinutes > 0) {
        // Ensure payment_amount field exists even if payment is correct
        if (!timesheetData.payment_amount && currentPayment > 0) {
          updateData.payment_amount = correctPayment;
          needsFix = true;
        }
      }

      if (needsFix && !DRY_RUN) {
        updateData.updated_at = admin.firestore.FieldValue.serverTimestamp();
        timesheetBatch.update(timesheetDoc.ref, updateData);
        timesheetBatchCount++;
        
        if (timesheetBatchCount >= timesheetBatchSize) {
          await timesheetBatch.commit();
          console.log(`   Committed batch of ${timesheetBatchCount} timesheet updates...`);
          timesheetBatch = db.batch();
          timesheetBatchCount = 0;
        }
        
        stats.timesheetsFixed++;
      } else if (needsFix) {
        stats.timesheetsFixed++;
      }
    }

    if (!DRY_RUN && timesheetBatchCount > 0) {
      await timesheetBatch.commit();
      console.log(`   Committed final batch of ${timesheetBatchCount} timesheet updates...`);
    }

    // Summary
    console.log('\n📊 Fix Summary:');
    console.log('================');
    console.log(`   Shifts checked: ${stats.shiftsChecked}`);
    console.log(`   Shifts fixed: ${stats.shiftsFixed}`);
    console.log(`   Timesheets checked: ${stats.timesheetsChecked}`);
    console.log(`   Timesheets fixed: ${stats.timesheetsFixed}`);
    console.log(`   Zero payment fixed: ${stats.zeroPayFixed}`);
    console.log(`   Overpaid fixed: ${stats.overpaidFixed}`);
    console.log(`   Payment mismatch fixed: ${stats.mismatchedPayFixed}`);
    console.log(`   Approved timesheets fixed: ${stats.approvedPayFixed}`);

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

// Run the fix
fixAllIssues();

