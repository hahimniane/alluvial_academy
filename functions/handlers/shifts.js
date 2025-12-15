const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onCall, onRequest} = require('firebase-functions/v2/https');
const {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {
  ensureTasksConfig,
  queuePath,
  taskName,
  ensureFutureDate,
  deleteTaskIfExists,
  getTasksServiceAccount,
  tasksClient,
  FUNCTION_REGION,
  PROJECT_ID,
} = require('../services/tasks/config');
const {sendFCMNotificationToTeacher} = require('../services/notifications/fcm');
const {ensureZoomMeetingAndEmailTeacher} = require('../services/zoom/shift_zoom');

const toDate = (timestamp) => (timestamp.toDate ? timestamp.toDate() : new Date(timestamp));

const formatShiftDateTime = (timestamp) => {
  try {
    const date = toDate(timestamp);
    return date.toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  } catch (error) {
    return 'Unknown date';
  }
};

const formatDuration = (ms) => {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600).toString().padStart(2, '0');
  const minutes = Math.floor((totalSeconds % 3600) / 60).toString().padStart(2, '0');
  const seconds = (totalSeconds % 60).toString().padStart(2, '0');
  return `${hours}:${minutes}:${seconds}`;
};

const parseClockIn = (data, defaultDate) => {
  if (data.clock_in_timestamp) {
    return data.clock_in_timestamp.toDate();
  }
  const timeString = data.start_time;
  if (typeof timeString === 'string') {
    const match = timeString.trim().match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
    if (match) {
      let hour = parseInt(match[1], 10);
      const minute = parseInt(match[2], 10);
      const meridiem = match[3].toUpperCase();
      if (meridiem === 'PM' && hour < 12) hour += 12;
      if (meridiem === 'AM' && hour === 12) hour = 0;
      const parsed = new Date(defaultDate);
      parsed.setHours(hour, minute, 0, 0);
      return parsed;
    }
  }
  return new Date(defaultDate);
};

const scheduleShiftLifecycle = onCall(async (request) => {
  const data = request.data || {};
  console.log('[DEBUG] scheduleShiftLifecycle invoked with data:', JSON.stringify(data));

  if (!request.auth) {
    console.error('[ERROR] scheduleShiftLifecycle: Authentication is required.');
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const {shiftId, cancel} = data;
  if (!shiftId) {
    console.error('[ERROR] scheduleShiftLifecycle: shiftId is required.');
    throw new functions.https.HttpsError('invalid-argument', 'The function must be called with a "shiftId" argument.');
  }

  console.log(`[INFO] Processing shiftId: ${shiftId}, cancel: ${cancel || false}`);

  try {
    console.log('[DEBUG] Verifying Cloud Tasks configuration...');
    await ensureTasksConfig();
    console.log('[DEBUG] Cloud Tasks configuration verified successfully.');

    const queue = queuePath();
    const startTaskName = taskName(shiftId, 'start');
    const endTaskName = taskName(shiftId, 'end');

    console.log(`[DEBUG] Deleting any existing tasks for shiftId: ${shiftId}`);
    await Promise.all([deleteTaskIfExists(startTaskName), deleteTaskIfExists(endTaskName)]);
    console.log('[DEBUG] Existing tasks deleted.');

    if (cancel) {
      console.log(`[INFO] Cancellation requested. No new tasks will be created for shiftId: ${shiftId}.`);
      return {success: true, message: 'Tasks cancelled successfully.'};
    }

    const db = admin.firestore();
    const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
    if (!shiftDoc.exists) {
      console.error(`[ERROR] Shift document with id ${shiftId} not found.`);
      throw new functions.https.HttpsError('not-found', 'Shift not found.');
    }
    const shiftData = shiftDoc.data();
    console.log('[DEBUG] Fetched shift data:', JSON.stringify(shiftData));

    const shiftStart = toDate(shiftData.shift_start);
    const shiftEnd = toDate(shiftData.shift_end);

    const scheduledStart = ensureFutureDate(new Date(shiftStart));
    const scheduledEnd = ensureFutureDate(new Date(shiftEnd));

    const startTask = {
      httpRequest: {
        httpMethod: 'POST',
        url: `https://${FUNCTION_REGION}-${PROJECT_ID}.cloudfunctions.net/handleShiftStartTask`,
        oidcToken: {
          serviceAccountEmail: await getTasksServiceAccount(),
        },
        headers: {'Content-Type': 'application/json'},
        body: Buffer.from(JSON.stringify({shiftId})).toString('base64'),
      },
      scheduleTime: {
        seconds: Math.floor(scheduledStart.getTime() / 1000),
      },
      name: startTaskName,
    };
    console.log('[DEBUG] Start task payload:', JSON.stringify(startTask));

    const endTask = {
      httpRequest: {
        httpMethod: 'POST',
        url: `https://${FUNCTION_REGION}-${PROJECT_ID}.cloudfunctions.net/handleShiftEndTask`,
        oidcToken: {
          serviceAccountEmail: await getTasksServiceAccount(),
        },
        headers: {'Content-Type': 'application/json'},
        body: Buffer.from(
          JSON.stringify({shiftId, shiftStart: shiftStart.toISOString(), shiftEnd: shiftEnd.toISOString()})
        ).toString('base64'),
      },
      scheduleTime: {
        seconds: Math.floor(scheduledEnd.getTime() / 1000),
      },
      name: endTaskName,
    };
    console.log('[DEBUG] End task payload:', JSON.stringify(endTask));

    const results = {};
    try {
      console.log(`[DEBUG] Creating start task in queue: ${queue}`);
      await tasksClient.createTask({parent: queue, task: startTask});
      results.startTaskCreated = true;
      console.log(`[INFO] Shift ${shiftId}: start task scheduled for ${scheduledStart.toISOString()}`);
    } catch (error) {
      console.error('[FATAL] Failed to create start task:', error.message, {
        code: error.code,
        details: error.details,
      });
      throw new functions.https.HttpsError('internal', `Failed to schedule start task: ${error.message}`);
    }

    try {
      console.log(`[DEBUG] Creating end task in queue: ${queue}`);
      await tasksClient.createTask({parent: queue, task: endTask});
      results.endTaskCreated = true;
      console.log(`[INFO] Shift ${shiftId}: end task scheduled for ${scheduledEnd.toISOString()}`);
    } catch (error) {
      console.error('[FATAL] Failed to create end task:', error.message, {
        code: error.code,
        details: error.details,
      });
      throw new functions.https.HttpsError('internal', `Failed to schedule end task: ${error.message}`);
    }

    console.log(`[SUCCESS] scheduleShiftLifecycle completed for shiftId: ${shiftId}`);
    // Best-effort: create Zoom meeting + email invite for newly created shifts.
    // This is intentionally non-blocking and should not fail lifecycle scheduling.
    try {
      await ensureZoomMeetingAndEmailTeacher({shiftId, shiftData});
    } catch (zoomError) {
      console.error(`[Zoom] Failed to ensure Zoom meeting for shift ${shiftId}:`, zoomError);
      try {
        await admin
          .firestore()
          .collection('teaching_shifts')
          .doc(shiftId)
          .update({
            zoom_error: String(zoomError?.message || zoomError),
            zoom_error_at: admin.firestore.FieldValue.serverTimestamp(),
          });
      } catch (updateError) {
        console.error('[Zoom] Failed to record zoom_error on shift doc:', updateError);
      }
    }
    return {success: true, results};
  } catch (error) {
    console.error(`[FATAL] Unhandled error in scheduleShiftLifecycle for shiftId: ${shiftId}:`, error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', `An unexpected error occurred: ${error.message}`);
  }
});

/**
 * Send notification to teacher about missed shift
 */
async function sendMissedShiftNotification(teacherId, shiftId, shiftData) {
  try {
    const displayName = shiftData.custom_name || shiftData.auto_generated_name || 'Your shift';
    const shiftStart = shiftData.shift_start.toDate ? shiftData.shift_start.toDate() : new Date(shiftData.shift_start);
    const shiftDateTime = formatShiftDateTime(shiftStart);
    
    const notification = {
      title: '❌ Missed Shift',
      body: `You missed ${displayName} scheduled for ${shiftDateTime}`,
    };
    
    const data = {
      type: 'shift',
      action: 'missed',
      shiftId: shiftId,
      teacherId: teacherId,
    };
    
    await sendFCMNotificationToTeacher(teacherId, notification, data);
    console.log(`Missed shift notification sent for shift ${shiftId}`);
  } catch (error) {
    console.error('Error in sendMissedShiftNotification:', error);
    throw error;
  }
}

const handleShiftStartTask = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const payload = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    const {shiftId} = payload;

    if (!shiftId) {
      res.status(400).json({success: false, error: 'shiftId is required'});
      return;
    }

    const shiftRef = admin.firestore().collection('teaching_shifts').doc(shiftId);
    const snapshot = await shiftRef.get();

    if (!snapshot.exists) {
      console.log(`handleShiftStartTask: shift ${shiftId} not found`);
      res.status(200).json({success: true, message: 'Shift not found (no-op)'});
      return;
    }

    const shiftData = snapshot.data();

    if (shiftData.status !== 'scheduled') {
      console.log(`handleShiftStartTask: shift ${shiftId} already ${shiftData.status} - skipping`);
      res.status(200).json({
        success: true,
        message: `Shift already ${shiftData.status}`,
      });
      return;
    }

    await shiftRef.update({
      status: 'active',
      activated_at: admin.firestore.FieldValue.serverTimestamp(),
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`handleShiftStartTask: shift ${shiftId} marked active`);
    res.status(200).json({success: true, message: 'Shift marked active'});
  } catch (error) {
    console.error('handleShiftStartTask error:', error);
    res.status(500).json({success: false, error: error.message || String(error)});
  }
});

const handleShiftEndTask = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const payload = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    const {shiftId, shiftStart, shiftEnd} = payload;

    if (!shiftId || !shiftStart || !shiftEnd) {
      res.status(400).json({success: false, error: 'shiftId, shiftStart, and shiftEnd are required'});
      return;
    }

    const startDate = new Date(shiftStart);
    const endDate = new Date(shiftEnd);

    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
      res
        .status(400)
        .json({success: false, error: 'shiftStart and shiftEnd must be ISO date strings'});
      return;
    }

    const shiftRef = admin.firestore().collection('teaching_shifts').doc(shiftId);
    const snapshot = await shiftRef.get();

    if (!snapshot.exists) {
      console.log(`handleShiftEndTask: shift ${shiftId} not found`);
      res.status(200).json({success: true, message: 'Shift not found (no-op)'});
      return;
    }

    const shiftData = snapshot.data();

    if (shiftData.status === 'cancelled') {
      console.log(`handleShiftEndTask: shift ${shiftId} cancelled - skipping`);
      res.status(200).json({success: true, message: 'Shift cancelled'});
      return;
    }

    // First check if teacher clocked in via the shift's clock_in_time field
    const hasClockInOnShift = shiftData.clock_in_time != null;
    
    const timesheetsSnapshot = await admin
      .firestore()
      .collection('timesheet_entries')
      .where('shift_id', '==', shiftId)
      .get();

    let workedMs = 0;
    let autoClockOutPerformed = false;
    
    // If no timesheet entries but shift has clock_in_time, calculate from that
    if (timesheetsSnapshot.empty && hasClockInOnShift) {
      const clockInTime = shiftData.clock_in_time.toDate();
      const clockOutTime = shiftData.clock_out_time ? shiftData.clock_out_time.toDate() : endDate;
      workedMs = Math.max(0, clockOutTime.getTime() - clockInTime.getTime());
      
      if (!shiftData.clock_out_time) {
        autoClockOutPerformed = true;
      }
    }

    // Check for overlap to prevent double counting
    // Sort by clock-in time
    timesheetsSnapshot.docs.sort((a, b) => {
      const timeA = a.data().clock_in_timestamp ? a.data().clock_in_timestamp.toDate().getTime() : 0;
      const timeB = b.data().clock_in_timestamp ? b.data().clock_in_timestamp.toDate().getTime() : 0;
      return timeA - timeB;
    });

    let lastEndTime = 0;

    for (const doc of timesheetsSnapshot.docs) {
      const data = doc.data();
      const clockIn = parseClockIn(data, startDate);
      let clockOut = data.clock_out_timestamp ? data.clock_out_timestamp.toDate() : null;
      const updates = {};

      if (!clockOut) {
        autoClockOutPerformed = true;
        clockOut = endDate;
        updates.clock_out_timestamp = admin.firestore.Timestamp.fromDate(endDate);
        updates.end_time = endDate.toLocaleTimeString('en-US', {
          hour: 'numeric',
          minute: '2-digit',
        });
        updates.completion_method = 'auto';
        updates.clock_out_platform = 'system';
      }

      // CRITICAL: Cap clock-in and clock-out times to scheduled shift boundaries
      // No payment for time outside scheduled window
      const startTimeMs = clockIn.getTime();
      const endTimeMs = clockOut.getTime();
      const effectiveStartTimeMs = Math.max(startTimeMs, startDate.getTime());
      const effectiveEndTimeMs = Math.min(endTimeMs, endDate.getTime());
      
      // Calculate effective duration (handling overlaps and capping to scheduled time)
      const effectiveStartTime = Math.max(effectiveStartTimeMs, lastEndTime);
      
      if (effectiveEndTimeMs > effectiveStartTime) {
        const durationMs = Math.max(0, effectiveEndTimeMs - effectiveStartTime);
        workedMs += durationMs;
        lastEndTime = effectiveEndTimeMs;
      }

      // Calculate billable duration (capped to scheduled duration)
      const scheduledDurationMs = endDate.getTime() - startDate.getTime();
      const rawDurationMs = Math.max(0, effectiveEndTimeMs - effectiveStartTimeMs);
      const billableDurationMs = Math.min(rawDurationMs, scheduledDurationMs);

      const totalHoursString = formatDuration(billableDurationMs);
      if (!data.total_hours || data.total_hours === '00:00' || updates.completion_method === 'auto') {
        updates.total_hours = totalHoursString;
      }

      // Calculate and save payment (capped to scheduled duration)
      if (updates.completion_method === 'auto' || !data.payment_amount) {
        const hourlyRate = data.hourly_rate || shiftData.hourly_rate || 0;
        const hoursWorked = billableDurationMs / 3600000; // Convert ms to hours
        const calculatedPay = Math.round(hoursWorked * hourlyRate * 100) / 100; // Round to 2 decimals
        
        updates.total_pay = calculatedPay;
        updates.payment_amount = calculatedPay;
        updates.effective_end_timestamp = admin.firestore.Timestamp.fromDate(new Date(effectiveEndTimeMs));
      }

      if (Object.keys(updates).length > 0) {
        updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
        await doc.ref.update(updates);
      }
    }

    // Calculate worked minutes (round up to ensure any work counts)
    const workedMinutes = Math.ceil(workedMs / 60000);

    const scheduledMinutes = Math.max(
      1,
      Math.round((endDate.getTime() - startDate.getTime()) / 60000)
    );
    // No tolerance
    const toleranceMinutes = 0;

    let newStatus = 'partiallyCompleted';
    let completionState = 'partial';
    let missedReason = null;

    // Check if teacher never clocked in (no timesheet entries AND no clock_in_time on shift)
    const neverClockedIn = timesheetsSnapshot.empty && !hasClockInOnShift;
    
    if (neverClockedIn || workedMinutes === 0) {
      newStatus = 'missed';
      completionState = 'none';
      missedReason = 'Teacher did not clock in before shift ended';
    } else if (workedMinutes + toleranceMinutes >= scheduledMinutes) {
      newStatus = 'fullyCompleted';
      completionState = 'full';
    }

    const updatePayload = {
      worked_minutes: workedMinutes,
      completion_state: completionState,
      auto_clock_out: autoClockOutPerformed,
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (autoClockOutPerformed) {
      updatePayload.auto_clock_out_reason = 'System auto clock-out at shift end';
      // Also update the shift's clock_out_time if it was auto-clocked out
      if (!shiftData.clock_out_time) {
        updatePayload.clock_out_time = admin.firestore.Timestamp.fromDate(endDate);
      }
    } else {
      updatePayload.auto_clock_out_reason = admin.firestore.FieldValue.delete();
    }

    if (missedReason) {
      updatePayload.missed_reason = missedReason;
      updatePayload.missed_at = admin.firestore.FieldValue.serverTimestamp();
    } else {
      updatePayload.missed_reason = admin.firestore.FieldValue.delete();
      updatePayload.missed_at = admin.firestore.FieldValue.delete();
    }

    if (shiftData.status !== 'cancelled') {
      updatePayload.status = newStatus;
    }

    await shiftRef.update(updatePayload);

    // Send notification if shift was missed
    if (newStatus === 'missed' && !shiftData.missed_notification_sent) {
      try {
        await sendMissedShiftNotification(shiftData.teacher_id, shiftId, shiftData);
        await shiftRef.update({missed_notification_sent: true});
      } catch (notifError) {
        console.error('Failed to send missed shift notification:', notifError);
      }
    }

    res.status(200).json({
      success: true,
      workedMinutes,
      scheduledMinutes,
      status: newStatus,
    });
  } catch (error) {
    console.error('handleShiftEndTask error:', error);
    res.status(500).json({success: false, error: error.message || String(error)});
  }
});

const onShiftCreated = onDocumentCreated('teaching_shifts/{shiftId}', async (event) => {
  try {
    const shiftData = event.data.data();
    const shiftId = event.params.shiftId;

    console.log(`🎓 New shift created: ${shiftId}`);

    const teacherId = shiftData.teacher_id;
    const teacherName = shiftData.teacher_name || 'Teacher';
    const studentNames = (shiftData.student_names || []).join(', ') || 'students';
    const subject = shiftData.subject_display_name || shiftData.subject || 'Class';
    const shiftStart = shiftData.shift_start;
    const shiftDateTime = formatShiftDateTime(shiftStart);

    const notification = {
      title: '🎓 New Shift Assigned',
      body: `${subject} with ${studentNames} on ${shiftDateTime}`,
    };

    const data = {
      type: 'shift',
      action: 'created',
      shiftId,
      teacherId,
      shiftStart: shiftStart.toDate().toISOString(),
    };

    await sendFCMNotificationToTeacher(teacherId, notification, data);

    console.log(`✅ Shift created notification sent to ${teacherName}`);
  } catch (error) {
    console.error('Error in onShiftCreated:', error);
  }
});

const onShiftUpdated = onDocumentUpdated('teaching_shifts/{shiftId}', async (event) => {
  try {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const shiftId = event.params.shiftId;

    if (afterData.status === 'cancelled' && beforeData.status !== 'cancelled') {
      console.log('Shift cancelled - skipping onShiftUpdated');
      return;
    }

    if (afterData.status !== beforeData.status) {
      console.log('Only status changed - skipping onShiftUpdated');
      return;
    }

    console.log(`📝 Shift updated: ${shiftId}`);

    const teacherId = afterData.teacher_id;
    const displayName = afterData.custom_name || afterData.auto_generated_name || 'Your shift';
    const shiftDateTime = formatShiftDateTime(afterData.shift_start);

    const changes = [];
    if (beforeData.shift_start?.toDate().getTime() !== afterData.shift_start?.toDate().getTime()) {
      changes.push('time changed');
    }
    if (JSON.stringify(beforeData.student_ids) !== JSON.stringify(afterData.student_ids)) {
      changes.push('students changed');
    }
    if (beforeData.subject !== afterData.subject) {
      changes.push('subject changed');
    }

    const changesText = changes.length > 0 ? changes.join(', ') : 'details updated';

    const notification = {
      title: '📝 Shift Updated',
      body: `${displayName} on ${shiftDateTime} - ${changesText}`,
    };

    const data = {
      type: 'shift',
      action: 'updated',
      shiftId,
      teacherId,
      changes: changesText,
    };

    await sendFCMNotificationToTeacher(teacherId, notification, data);

    console.log('✅ Shift updated notification sent');
  } catch (error) {
    console.error('Error in onShiftUpdated:', error);
  }
});

const onShiftCancelled = onDocumentUpdated('teaching_shifts/{shiftId}', async (event) => {
  try {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const shiftId = event.params.shiftId;

    if (afterData.status === 'cancelled' && beforeData.status !== 'cancelled') {
      console.log(`⚠️ Shift cancelled: ${shiftId}`);

      const teacherId = afterData.teacher_id;
      const displayName = afterData.custom_name || afterData.auto_generated_name || 'Your shift';
      const shiftDateTime = formatShiftDateTime(afterData.shift_start);

      const notification = {
        title: '⚠️ Shift Cancelled',
        body: `${displayName} on ${shiftDateTime} has been cancelled`,
      };

      const data = {
        type: 'shift',
        action: 'cancelled',
        shiftId,
        teacherId,
      };

      await sendFCMNotificationToTeacher(teacherId, notification, data);

      console.log('✅ Shift cancelled notification sent');
    }
  } catch (error) {
    console.error('Error in onShiftCancelled:', error);
  }
});

const onShiftDeleted = onDocumentDeleted('teaching_shifts/{shiftId}', async (event) => {
  try {
    const shiftData = event.data.data();
    const shiftId = event.params.shiftId;

    console.log(`🗑️ Shift deleted: ${shiftId}`);

    const teacherId = shiftData.teacher_id;
    const displayName = shiftData.custom_name || shiftData.auto_generated_name || 'A shift';
    const shiftDateTime = formatShiftDateTime(shiftData.shift_start);

    const notification = {
      title: '🗑️ Shift Deleted',
      body: `${displayName} on ${shiftDateTime} has been removed`,
    };

    const data = {
      type: 'shift',
      action: 'deleted',
      shiftId,
      teacherId,
    };

    await sendFCMNotificationToTeacher(teacherId, notification, data);

    console.log('✅ Shift deleted notification sent');
  } catch (error) {
    console.error('Error in onShiftDeleted:', error);
  }
});

const sendScheduledShiftReminders = onSchedule('every 5 minutes', async () => {
  try {
    console.log('🔔 Running scheduled shift reminders check...');

    const now = admin.firestore.Timestamp.now();
    const oneHourFromNow = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000));

    const upcomingShiftsSnapshot = await admin
      .firestore()
      .collection('teaching_shifts')
      .where('shift_start', '>', now)
      .where('shift_start', '<=', oneHourFromNow)
      .where('status', '==', 'scheduled')
      .get();

    console.log(`Found ${upcomingShiftsSnapshot.size} upcoming shifts in next hour`);

    if (upcomingShiftsSnapshot.empty) {
      console.log('No upcoming shifts - skipping reminders');
      return;
    }

    let remindersSent = 0;

    for (const shiftDoc of upcomingShiftsSnapshot.docs) {
      try {
        const shift = shiftDoc.data();
        const shiftId = shiftDoc.id;
        const teacherId = shift.teacher_id;
        const shiftStart = shift.shift_start.toDate();
        const minutesUntilShift = Math.floor((shiftStart.getTime() - Date.now()) / 1000 / 60);

        const teacherDoc = await admin.firestore().collection('users').doc(teacherId).get();

        if (!teacherDoc.exists) continue;

        const teacherData = teacherDoc.data();
        const notifPrefs = teacherData.notificationPreferences || {};
        const isEnabled = notifPrefs.shiftEnabled !== false;
        const reminderMinutes = notifPrefs.shiftMinutes || 15;

        if (!isEnabled) {
          console.log(`Shift reminders disabled for teacher ${teacherId}`);
          continue;
        }

        const shouldSendReminder = Math.abs(minutesUntilShift - reminderMinutes) <= 2;

        if (!shouldSendReminder) {
          console.log(
            `Not time yet for shift ${shiftId} (${minutesUntilShift} mins vs ${reminderMinutes} mins preference)`
          );
          continue;
        }

        const reminderSentKey = `reminder_sent_${reminderMinutes}min`;
        if (shift[reminderSentKey] === true) {
          console.log(`Reminder already sent for shift ${shiftId}`);
          continue;
        }

        const displayName = shift.custom_name || shift.auto_generated_name || 'Your shift';
        const shiftDateTime = formatShiftDateTime(shift.shift_start);

        const notification = {
          title: '🔔 Shift Reminder',
          body: `${displayName} starts in ${minutesUntilShift} minutes at ${shiftDateTime}`,
        };

        const data = {
          type: 'shift',
          action: 'reminder',
          shiftId,
          teacherId,
          minutesUntilShift: minutesUntilShift.toString(),
        };

        const result = await sendFCMNotificationToTeacher(teacherId, notification, data);

        if (result.success) {
          await shiftDoc.ref.update({
            [reminderSentKey]: true,
          });
          remindersSent += 1;
          console.log(`✅ Reminder sent for shift ${shiftId}`);
        }
      } catch (error) {
        console.error('Error processing shift reminder:', error);
      }
    }

    console.log(`✅ Scheduled reminders completed: ${remindersSent} reminders sent`);
  } catch (error) {
    console.error('Error in sendScheduledShiftReminders:', error);
  }
});

module.exports = {
  scheduleShiftLifecycle,
  handleShiftStartTask,
  handleShiftEndTask,
  onShiftCreated,
  onShiftUpdated,
  onShiftCancelled,
  onShiftDeleted,
  sendScheduledShiftReminders,
};
