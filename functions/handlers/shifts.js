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

    // Safety Check: Verify that the task matches the current shift schedule
    // If the shift was rescheduled, the document times will differ from the task payload times.
    // We should ignore this stale task to prevent marking the shift as missed prematurely.
    if (shiftData.shift_end) {
      const currentShiftEnd = toDate(shiftData.shift_end);
      const taskShiftEnd = endDate; // From payload
      const diffMs = Math.abs(currentShiftEnd.getTime() - taskShiftEnd.getTime());
      
      // If difference is more than 1 minute, assume rescheduled/stale task
      if (diffMs > 60000) {
        console.log(`handleShiftEndTask: Mismatch in shift end time (Doc: ${currentShiftEnd.toISOString()} vs Task: ${taskShiftEnd.toISOString()}) - likely rescheduled. Skipping.`);
        res.status(200).json({success: true, message: 'Stale task - shift rescheduled'});
        return;
      }
    }

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

/**
 * Scheduled function that runs every 30 minutes to fix shifts that are still marked as "active"
 * but should be completed. Also handles missing clock-outs for timesheet entries.
 * 
 * Runs every 30 minutes
 */
const fixActiveShiftsStatus = onSchedule('every 30 minutes', async () => {
  console.log('🔍 Starting to fix active shifts status...\n');

  const db = admin.firestore();
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
        
        // Skip rejected timesheets when calculating worked time
        if (timesheetData.status === 'rejected') {
          continue;
        }

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
    console.error('❌ Error in fixActiveShiftsStatus:', error);
    throw error;
  }
});

/**
 * Scheduled function that runs every 30 minutes to comprehensively fix timesheet and shift issues:
 * 1. Fix shifts that are still "active" or "scheduled" but should be completed
 * 2. Fix payment amounts that are 0 but should have values
 * 3. Fix overpaid shifts (> hourly rate for scheduled duration)
 * 4. Ensure payment_amount is set correctly in all timesheet entries
 * 
 * Runs every 30 minutes
 */
const fixTimesheetsPayAndStatus = onSchedule('every 30 minutes', async () => {
  console.log('🔧 Comprehensive Timesheet & Shift Fix Script');
  console.log('============================================\n');

  const db = admin.firestore();
  const stats = {
    shiftsFixed: 0,
    shiftsChecked: 0,
    timesheetsFixed: 0,
    timesheetsChecked: 0,
    zeroPayFixed: 0,
    overpaidFixed: 0,
    errors: []
  };

  try {
    // Step 1: Fix shifts that are still "active" or "scheduled" but should be completed
    console.log('📋 Step 1: Fixing shifts that should be completed...');
    const shiftsSnapshot = await db.collection('teaching_shifts')
      .where('status', 'in', ['active', 'scheduled'])
      .get();
    
    stats.shiftsChecked = shiftsSnapshot.docs.length;
    console.log(`   Found ${stats.shiftsChecked} active/scheduled shifts to check\n`);

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
      
      // If shift end time has passed, check if it should be completed
      if (shiftEnd < now) {
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
        
        shiftBatch.update(shiftDoc.ref, updateData);
        shiftBatchCount++;
        
        if (shiftBatchCount >= shiftBatchSize) {
          await shiftBatch.commit();
          console.log(`   Committed batch of ${shiftBatchCount} shift updates...`);
          shiftBatch = db.batch();
          shiftBatchCount = 0;
        }
        
        stats.shiftsFixed++;
        console.log(`   ✓ Shift ${shiftId}: ${shiftData.status} → ${newStatus} (worked: ${totalWorkedMinutes} min)`);
      }
    }

    if (shiftBatchCount > 0) {
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
        
        // Skip rejected timesheets when calculating worked time
        if (timesheetData.status === 'rejected') {
          continue;
        }

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
      
      // Check if payment needs fixing
      let needsFix = false;
      const updateData = {};
      
      // Fix zero payment
      if (currentPayment === 0 && billableMinutes > 0) {
        updateData.payment_amount = correctPayment;
        updateData.total_pay = correctPayment;
        updateData.hourly_rate = hourlyRate;
        needsFix = true;
        stats.zeroPayFixed++;
      }
      
      // Fix overpayment (more than scheduled duration * hourly rate)
      const maxPayment = (scheduledDuration / 60.0) * hourlyRate;
      if (currentPayment > maxPayment + 0.01) { // Add small tolerance for rounding
        updateData.payment_amount = correctPayment;
        updateData.total_pay = correctPayment;
        updateData.hourly_rate = hourlyRate;
        needsFix = true;
        stats.overpaidFixed++;
        console.log(`   ⚠️  Overpaid: ${timesheetId} - Current: $${currentPayment.toFixed(2)}, Correct: $${correctPayment.toFixed(2)} (${billableMinutes} min @ $${hourlyRate}/hr)`);
      }
      
      // Ensure payment_amount is set even if it's correct
      if (!timesheetData.payment_amount && currentPayment > 0) {
        updateData.payment_amount = correctPayment;
        needsFix = true;
      }

      if (needsFix) {
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
      }
    }

    if (timesheetBatchCount > 0) {
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

    if (stats.errors.length > 0) {
      console.log(`\n⚠️  Errors encountered: ${stats.errors.length}`);
      stats.errors.forEach(err => console.log(`   - ${err}`));
    }

    console.log('\n✅ All fixes completed successfully!');
  } catch (error) {
    console.error('\n❌ Error in fixTimesheetsPayAndStatus:', error);
    console.error('Stack trace:', error.stack);
    throw error;
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
  fixActiveShiftsStatus,
  fixTimesheetsPayAndStatus,
};
