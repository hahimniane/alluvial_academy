const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
try {
  const serviceAccount = require(path.join(__dirname, '../serviceAccountKey.json'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'alluwal-academy',
  });
} catch (error) {
  // Fallback to application default credentials
  admin.initializeApp({
    projectId: 'alluwal-academy',
  });
}

const db = admin.firestore();

/**
 * Script to fix shifts that are still marked as "active" but should be completed
 * Also handles missing clock-outs for timesheet entries
 */
async function fixActiveShiftsStatus() {
  console.log('🔍 Starting to fix active shifts status...\n');

  const now = admin.firestore.Timestamp.now();
  const nowDate = now.toDate();

  try {
    // 1. Find all shifts with status "active" that have passed their end time
    console.log('📋 Finding shifts with status "active" that have ended...');
    const activeShiftsQuery = await db
      .collection('teaching_shifts')
      .where('status', '==', 'active')
      .get();

    console.log(`Found ${activeShiftsQuery.size} shifts with status "active"\n`);

    let fixedShifts = 0;
    let fixedTimesheets = 0;
    let skippedShifts = 0;

    for (const shiftDoc of activeShiftsQuery.docs) {
      const shiftData = shiftDoc.data();
      const shiftId = shiftDoc.id;
      const shiftEnd = shiftData.shift_end?.toDate() || shiftData.shiftEnd?.toDate();
      const shiftStart = shiftData.shift_start?.toDate() || shiftData.shiftStart?.toDate();

      if (!shiftEnd) {
        console.log(`⚠️  Shift ${shiftId} has no end time, skipping...`);
        skippedShifts++;
        continue;
      }

      // Check if shift end time has passed
      if (shiftEnd > nowDate) {
        // Shift hasn't ended yet, skip it
        continue;
      }

      console.log(`\n🔧 Processing shift ${shiftId}`);
      console.log(`   End time: ${shiftEnd.toISOString()}`);
      console.log(`   Current time: ${nowDate.toISOString()}`);

      // 2. Check for timesheet entries for this shift
      const timesheetQuery = await db
        .collection('timesheet_entries')
        .where('shift_id', '==', shiftId)
        .get();

      if (timesheetQuery.empty) {
        // No timesheet entries - shift was missed
        console.log(`   ❌ No timesheet entries found - marking as MISSED`);
        await shiftDoc.ref.update({
          status: 'missed',
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        fixedShifts++;
        continue;
      }

      // 3. Check timesheet entries for clock-out status
      let hasActiveEntry = false;
      let hasCompletedEntry = false;
      let totalWorkedMinutes = 0;

      for (const timesheetDoc of timesheetQuery.docs) {
        const timesheetData = timesheetDoc.data();
        const clockIn = timesheetData.clock_in_time?.toDate() || 
                       timesheetData.clock_in_timestamp?.toDate();
        const clockOut = timesheetData.clock_out_time?.toDate() || 
                        timesheetData.clock_out_timestamp?.toDate();

        if (!clockIn) {
          continue;
        }

        if (!clockOut) {
          // Active entry without clock-out - need to auto clock-out
          console.log(`   ⏰ Found active timesheet entry ${timesheetDoc.id} without clock-out`);
          
          // Auto clock-out at shift end time (capped)
          const effectiveEndTime = shiftEnd;
          const workedMs = Math.max(0, effectiveEndTime.getTime() - clockIn.getTime());
          const workedMinutes = Math.floor(workedMs / 60000);
          totalWorkedMinutes += workedMinutes;

          // Calculate payment
          const hourlyRate = timesheetData.hourly_rate || shiftData.hourly_rate || 0;
          const hoursWorked = workedMs / 3600000;
          const calculatedPay = Math.round(hoursWorked * hourlyRate * 100) / 100;

          // Format duration
          const hours = Math.floor(workedMinutes / 60);
          const minutes = workedMinutes % 60;
          const totalHours = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`;

          const updates = {
            clock_out_time: admin.firestore.Timestamp.fromDate(effectiveEndTime),
            clock_out_timestamp: admin.firestore.Timestamp.fromDate(effectiveEndTime),
            effective_end_timestamp: admin.firestore.Timestamp.fromDate(effectiveEndTime),
            total_hours: totalHours,
            total_pay: calculatedPay,
            payment_amount: calculatedPay,
            status: 'pending',
            completion_method: 'auto',
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          };

          await timesheetDoc.ref.update(updates);
          console.log(`   ✅ Auto-clocked out timesheet entry ${timesheetDoc.id}`);
          console.log(`      Worked: ${totalHours}, Pay: $${calculatedPay.toFixed(2)}`);
          fixedTimesheets++;
          hasCompletedEntry = true;
        } else {
          // Entry already has clock-out
          hasCompletedEntry = true;
          const workedMs = clockOut.getTime() - clockIn.getTime();
          const workedMinutes = Math.floor(workedMs / 60000);
          totalWorkedMinutes += workedMinutes;
        }
      }

      // 4. Determine shift status based on worked time
      const scheduledDurationMs = shiftEnd.getTime() - shiftStart.getTime();
      const scheduledMinutes = Math.floor(scheduledDurationMs / 60000);
      const workedPercentage = scheduledMinutes > 0 
        ? (totalWorkedMinutes / scheduledMinutes) * 100 
        : 0;

      let newStatus;
      if (totalWorkedMinutes === 0) {
        newStatus = 'missed';
        console.log(`   📊 Status: MISSED (no time worked)`);
      } else if (workedPercentage >= 90) {
        newStatus = 'fullyCompleted';
        console.log(`   📊 Status: FULLY COMPLETED (${workedPercentage.toFixed(1)}% worked)`);
      } else if (workedPercentage >= 50) {
        newStatus = 'partiallyCompleted';
        console.log(`   📊 Status: PARTIALLY COMPLETED (${workedPercentage.toFixed(1)}% worked)`);
      } else {
        newStatus = 'partiallyCompleted';
        console.log(`   📊 Status: PARTIALLY COMPLETED (${workedPercentage.toFixed(1)}% worked)`);
      }

      // 5. Update shift status
      await shiftDoc.ref.update({
        status: newStatus,
        total_worked_minutes: totalWorkedMinutes,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      fixedShifts++;
      console.log(`   ✅ Updated shift ${shiftId} to status: ${newStatus}`);
    }

    // 6. Also check for any timesheet entries without clock-out that are past their shift end
    console.log('\n🔍 Checking for orphaned active timesheet entries...');
    const activeTimesheetsQuery = await db
      .collection('timesheet_entries')
      .where('clock_out_time', '==', null)
      .get();

    let orphanedFixed = 0;
    for (const timesheetDoc of activeTimesheetsQuery.docs) {
      const timesheetData = timesheetDoc.data();
      const shiftId = timesheetData.shift_id;
      const clockIn = timesheetData.clock_in_time?.toDate() || 
                     timesheetData.clock_in_timestamp?.toDate();

      if (!shiftId || !clockIn) {
        continue;
      }

      // Get shift to check end time
      const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
      if (!shiftDoc.exists) {
        continue;
      }

      const shiftData = shiftDoc.data();
      const shiftEnd = shiftData.shift_end?.toDate() || shiftData.shiftEnd?.toDate();
      
      if (!shiftEnd || shiftEnd > nowDate) {
        // Shift hasn't ended yet, skip
        continue;
      }

      // This timesheet entry should have been clocked out
      console.log(`\n   ⏰ Found orphaned active timesheet ${timesheetDoc.id} for shift ${shiftId}`);
      
      // Auto clock-out
      const effectiveEndTime = shiftEnd;
      const workedMs = Math.max(0, effectiveEndTime.getTime() - clockIn.getTime());
      const workedMinutes = Math.floor(workedMs / 60000);

      const hourlyRate = timesheetData.hourly_rate || shiftData.hourly_rate || 0;
      const hoursWorked = workedMs / 3600000;
      const calculatedPay = Math.round(hoursWorked * hourlyRate * 100) / 100;

      const hours = Math.floor(workedMinutes / 60);
      const minutes = workedMinutes % 60;
      const totalHours = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`;

      await timesheetDoc.ref.update({
        clock_out_time: admin.firestore.Timestamp.fromDate(effectiveEndTime),
        clock_out_timestamp: admin.firestore.Timestamp.fromDate(effectiveEndTime),
        effective_end_timestamp: admin.firestore.Timestamp.fromDate(effectiveEndTime),
        total_hours: totalHours,
        total_pay: calculatedPay,
        payment_amount: calculatedPay,
        status: 'pending',
        completion_method: 'auto',
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`   ✅ Auto-clocked out orphaned entry`);
      orphanedFixed++;
      fixedTimesheets++;
    }

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 SUMMARY');
    console.log('='.repeat(60));
    console.log(`✅ Fixed shifts: ${fixedShifts}`);
    console.log(`✅ Fixed timesheet entries: ${fixedTimesheets}`);
    console.log(`⏭️  Skipped shifts: ${skippedShifts}`);
    console.log(`🔍 Orphaned entries fixed: ${orphanedFixed}`);
    console.log('='.repeat(60));
    console.log('\n✨ Done!');

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Run the script
fixActiveShiftsStatus()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });

