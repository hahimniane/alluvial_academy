const admin = require('firebase-admin');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {sendFCMNotificationToTeacher} = require('../services/notifications/fcm');

/**
 * Scheduled function that runs daily to check for incomplete Readiness Forms
 * from completed shifts in the last 2 days.
 * 
 * Runs at 9:00 PM daily (21:00)
 * 
 * Logic:
 * 1. Query all completed shifts from the last 2 days
 * 2. Check if each shift has a corresponding form response
 * 3. Send notifications to teachers with pending forms
 */
const checkIncompleteReadinessForms = onSchedule({
  schedule: 'every day 21:00',
  timeZone: 'America/New_York',
  memory: '256MiB',
  region: 'us-central1',
}, async (event) => {
  console.log('🔍 Starting daily check for incomplete Readiness Forms...');

  try {
    const now = new Date();
    const twoDaysAgo = new Date(now.getTime() - (2 * 24 * 60 * 60 * 1000));

    console.log(`📅 Checking shifts from ${twoDaysAgo.toISOString()} to ${now.toISOString()}`);

    // Query completed shifts from the last 2 days
    const completedShifts = await admin
      .firestore()
      .collection('teaching_shifts')
      .where('shift_end', '>=', admin.firestore.Timestamp.fromDate(twoDaysAgo))
      .where('shift_end', '<=', admin.firestore.Timestamp.fromDate(now))
      .where('status', 'in', ['fullyCompleted', 'partiallyCompleted', 'completed'])
      .get();

    console.log(`📊 Found ${completedShifts.size} completed shifts in the last 2 days`);

    if (completedShifts.empty) {
      console.log('✅ No completed shifts to check');
      return;
    }

    // Group shifts by teacher and check for missing forms
    const teacherPendingForms = new Map();

    for (const shiftDoc of completedShifts.docs) {
      const shiftData = shiftDoc.data();
      const shiftId = shiftDoc.id;
      const teacherId = shiftData.teacher_id;

      if (!teacherId) {
        console.log(`⚠️ Shift ${shiftId} has no teacher_id, skipping`);
        continue;
      }

      // Find timesheet entries for this shift
      const timesheetEntries = await admin
        .firestore()
        .collection('timesheet_entries')
        .where('shift_id', '==', shiftId)
        .get();

      if (timesheetEntries.empty) {
        console.log(`⚠️ Shift ${shiftId} has no timesheet entries, skipping`);
        continue;
      }

      // Check each timesheet entry for a form response
      for (const timesheetDoc of timesheetEntries.docs) {
        const timesheetData = timesheetDoc.data();
        const timesheetId = timesheetDoc.id;
        const formResponseId = timesheetData.form_response_id;

        // Check if form response exists
        let hasFormResponse = false;

        if (formResponseId) {
          const formDoc = await admin
            .firestore()
            .collection('form_responses')
            .doc(formResponseId)
            .get();
          hasFormResponse = formDoc.exists;
        }

        // If no form response found, try querying by timesheet_id
        if (!hasFormResponse) {
          const formQuery = await admin
            .firestore()
            .collection('form_responses')
            .where('timesheet_id', '==', timesheetId)
            .limit(1)
            .get();
          
          hasFormResponse = !formQuery.empty;
        }

        // If still no form, try by timesheetId (camelCase)
        if (!hasFormResponse) {
          const formQuery = await admin
            .firestore()
            .collection('form_responses')
            .where('timesheetId', '==', timesheetId)
            .limit(1)
            .get();
          
          hasFormResponse = !formQuery.empty;
        }

        // If no form response found, add to pending list
        if (!hasFormResponse) {
          if (!teacherPendingForms.has(teacherId)) {
            teacherPendingForms.set(teacherId, {
              teacherName: shiftData.teacher_name || 'Teacher',
              pendingForms: [],
            });
          }

          teacherPendingForms.get(teacherId).pendingForms.push({
            shiftId,
            timesheetId,
            shiftName: shiftData.display_name || shiftData.subject_display_name || 'Shift',
            shiftEnd: shiftData.shift_end,
          });
        }
      }
    }

    console.log(`👥 Found ${teacherPendingForms.size} teachers with pending forms`);

    // Send notifications to teachers with pending forms
    let notificationsSent = 0;
    let notificationsFailed = 0;

    for (const [teacherId, teacherData] of teacherPendingForms) {
      const {teacherName, pendingForms} = teacherData;
      const formCount = pendingForms.length;

      console.log(`📧 Sending notification to ${teacherName} (${teacherId}) - ${formCount} pending form(s)`);

      try {
        // Construct notification message
        const title = formCount === 1
          ? 'Readiness Form Required'
          : `${formCount} Readiness Forms Required`;

        let body;
        if (formCount === 1) {
          body = `Please complete your Readiness Form for "${pendingForms[0].shiftName}"`;
        } else {
          body = `You have ${formCount} incomplete Readiness Forms from recent shifts`;
        }

        // Send FCM notification. Use type 'form_required' so the app opens the same
        // daily-report form (from config/template), not a hardcoded form ID.
        const notificationData = {
          type: 'form_required',
          formCount: formCount.toString(),
          teacherId,
        };

        // If only one form, include shiftId and timesheetId so the app can open
        // the correct form (readiness/daily report from config or template).
        if (formCount === 1) {
          notificationData.timesheetId = pendingForms[0].timesheetId;
          notificationData.shiftId = pendingForms[0].shiftId;
        }

        await sendFCMNotificationToTeacher(teacherId, {
          title,
          body,
          data: notificationData,
        });

        notificationsSent++;
        console.log(`✅ Notification sent to ${teacherName}`);
      } catch (error) {
        notificationsFailed++;
        console.error(`❌ Failed to send notification to ${teacherName}:`, error);
      }
    }

    console.log(`✅ Daily form check completed: ${notificationsSent} sent, ${notificationsFailed} failed`);
  } catch (error) {
    console.error('❌ Error in checkIncompleteReadinessForms:', error);
    throw error;
  }
});

module.exports = {
  checkIncompleteReadinessForms,
};

