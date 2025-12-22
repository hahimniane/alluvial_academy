const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Execute programmed clock-ins that are scheduled to run at their exact shift start times
 * This function should be called by a cron job every minute to check for clock-ins due to execute
 */
const executeProgrammedClockIns = async (data, context) => {
  try {
    console.log('🔄 Executing programmed clock-ins...');

    const db = admin.firestore();
    const now = new Date();
    const startWindow = new Date(now.getTime() - 30 * 1000); // 30 seconds ago
    const endWindow = new Date(now.getTime() + 30 * 1000); // 30 seconds from now

    console.log(`⏰ Checking for programmed clock-ins between ${startWindow.toISOString()} and ${endWindow.toISOString()}`);

    // Find programmed clock-ins ready for execution
    const snapshot = await db
      .collection('programmed_clock_ins')
      .where('status', '==', 'scheduled')
      .where('scheduled_execution_time', '>=', admin.firestore.Timestamp.fromDate(startWindow))
      .where('scheduled_execution_time', '<=', admin.firestore.Timestamp.fromDate(endWindow))
      .get();

    console.log(`📋 Found ${snapshot.docs.length} programmed clock-ins to execute`);

    const results = [];
    let successCount = 0;
    let failureCount = 0;

    for (const doc of snapshot.docs) {
      try {
        const programmedData = doc.data();
        const shiftId = programmedData.shift_id;
        const teacherId = programmedData.teacher_id;
        const programmedId = doc.id;

        console.log(`⚡ Executing programmed clock-in ${programmedId} for teacher ${teacherId}, shift ${shiftId}`);

        // Check if the shift still exists and is valid
        const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
        if (!shiftDoc.exists) {
          console.warn(`⚠️ Shift ${shiftId} no longer exists, cancelling programmed clock-in`);
          await doc.ref.update({
            status: 'cancelled',
            cancelled_at: admin.firestore.FieldValue.serverTimestamp(),
            cancellation_reason: 'shift_no_longer_exists',
          });
          continue;
        }

        // Check if teacher already has an open timesheet for this shift
        const existingTimesheet = await db
          .collection('timesheet_entries')
          .where('teacher_id', '==', teacherId)
          .where('shift_id', '==', shiftId)
          .where('clock_out_timestamp', '==', null)
          .limit(1)
          .get();

        if (!existingTimesheet.empty) {
          console.warn(`⚠️ Teacher ${teacherId} already has an open timesheet for shift ${shiftId}, cancelling programmed clock-in`);
          await doc.ref.update({
            status: 'cancelled',
            cancelled_at: admin.firestore.FieldValue.serverTimestamp(),
            cancellation_reason: 'already_clocked_in',
          });
          continue;
        }

        // Create the location data from stored values
        const location = {
          latitude: programmedData.location_latitude,
          longitude: programmedData.location_longitude,
          address: programmedData.location_address,
          neighborhood: programmedData.location_neighborhood,
        };

        // Create the timesheet entry
        const timesheetData = {
          teacher_id: teacherId,
          shift_id: shiftId,
          date: now.toISOString().split('T')[0], // YYYY-MM-DD format
          start_time: now.toLocaleTimeString('en-US', {
            hour12: false,
            hour: '2-digit',
            minute: '2-digit'
          }), // HH:MM format
          end_time: null,
          total_hours: '00:00',
          status: 'active', // Set as active since they're clocked in
          clock_in_timestamp: admin.firestore.Timestamp.fromDate(now),
          clock_out_timestamp: null,
          payment_amount: 0.0, // Will be calculated later
          employee_notes: `Auto-programmed clock-in at ${now.toISOString()}`,
          platform: programmedData.platform || 'programmed',
          location_data: location,
          programmed_clock_in: true, // Mark as programmed
          programmed_id: programmedId, // Reference to the programmed entry
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Add the timesheet entry
        await db.collection('timesheet_entries').add(timesheetData);

        // Mark programmed clock-in as executed
        await doc.ref.update({
          status: 'executed',
          executed_at: admin.firestore.FieldValue.serverTimestamp(),
          actual_execution_time: admin.firestore.Timestamp.fromDate(now),
        });

        console.log(`✅ Successfully executed programmed clock-in ${programmedId}`);
        results.push({
          programmedId,
          status: 'success',
          message: 'Clock-in executed successfully',
        });
        successCount++;

      } catch (error) {
        console.error(`❌ Error executing programmed clock-in ${doc.id}:`, error);

        // Mark as failed
        await doc.ref.update({
          status: 'failed',
          failed_at: admin.firestore.FieldValue.serverTimestamp(),
          failure_reason: error.message,
        });

        results.push({
          programmedId: doc.id,
          status: 'error',
          message: error.message,
        });
        failureCount++;
      }
    }

    console.log(`🎯 Execution complete: ${successCount} successful, ${failureCount} failed`);

    return {
      success: true,
      executedCount: successCount,
      failedCount: failureCount,
      results,
    };

  } catch (error) {
    console.error('❌ Error in executeProgrammedClockIns:', error);
    throw new functions.https.HttpsError('internal', `Failed to execute programmed clock-ins: ${error.message}`);
  }
};

module.exports = {
  executeProgrammedClockIns,
};
