const admin = require('firebase-admin');
const {
  tasksClient,
  queuePath,
  taskName,
  buildFunctionUrl,
  encodeTaskBody,
  toScheduleTime,
  ensureFutureDate,
  deleteTaskIfExists,
  getTasksServiceAccount,
  PROJECT_ID,
} = require('../tasks/config');

const BREAKOUT_TASK_QUEUE = process.env.BREAKOUT_TASK_QUEUE || 'shift-lifecycle-queue';

/**
 * Schedule a Cloud Task to open breakout rooms for a shift
 * This is a backup mechanism - if teachers don't open rooms via the app,
 * the bot will open them automatically
 *
 * @param {string} shiftId - The shift ID
 * @param {string} zoomMeetingId - The Zoom meeting ID
 * @param {Date} shiftStart - When the shift starts
 * @param {number} delayMinutes - Minutes after shift start to trigger (default: 3)
 */
const scheduleBreakoutOpener = async (shiftId, zoomMeetingId, shiftStart, delayMinutes = 3) => {
  if (!PROJECT_ID) {
    console.warn('[BreakoutScheduler] No PROJECT_ID, skipping task scheduling');
    return null;
  }

  const db = admin.firestore();

  // Schedule task for X minutes after shift start
  const triggerTime = new Date(shiftStart.getTime() + delayMinutes * 60 * 1000);
  const scheduleTime = ensureFutureDate(triggerTime);

  const taskId = `breakout-${shiftId}`;
  const fullTaskName = taskName(shiftId, 'breakout-open');

  // Delete any existing task for this shift
  await deleteTaskIfExists(fullTaskName);

  const payload = {
    shiftId,
    zoomMeetingId,
    scheduledFor: scheduleTime.toISOString(),
  };

  const serviceAccount = await getTasksServiceAccount();
  const functionUrl = buildFunctionUrl('openBreakoutRooms');

  const task = {
    name: fullTaskName,
    scheduleTime: toScheduleTime(scheduleTime),
    httpRequest: {
      httpMethod: 'POST',
      url: functionUrl,
      headers: { 'Content-Type': 'application/json' },
      body: encodeTaskBody(payload),
      oidcToken: {
        serviceAccountEmail: serviceAccount,
        audience: functionUrl,
      },
    },
  };

  try {
    const [createdTask] = await tasksClient.createTask({
      parent: queuePath(),
      task,
    });

    console.log(`[BreakoutScheduler] Scheduled breakout opener for shift ${shiftId} at ${scheduleTime.toISOString()}`);
    console.log(`[BreakoutScheduler] Task: ${createdTask.name}`);

    // Store task reference in Firestore
    await db.collection('teaching_shifts').doc(shiftId).update({
      breakout_task_scheduled: admin.firestore.FieldValue.serverTimestamp(),
      breakout_task_trigger_time: admin.firestore.Timestamp.fromDate(scheduleTime),
    });

    return {
      taskName: createdTask.name,
      scheduledFor: scheduleTime.toISOString(),
    };
  } catch (error) {
    console.error(`[BreakoutScheduler] Failed to schedule task for shift ${shiftId}:`, error.message);
    return null;
  }
};

/**
 * Cancel a scheduled breakout opener task
 * Call this when rooms are opened manually by a teacher
 *
 * @param {string} shiftId - The shift ID
 */
const cancelBreakoutOpener = async (shiftId) => {
  const fullTaskName = taskName(shiftId, 'breakout-open');

  try {
    await deleteTaskIfExists(fullTaskName);
    console.log(`[BreakoutScheduler] Cancelled breakout opener for shift ${shiftId}`);

    // Update Firestore
    const db = admin.firestore();
    await db.collection('teaching_shifts').doc(shiftId).update({
      breakout_task_cancelled: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { cancelled: true };
  } catch (error) {
    console.warn(`[BreakoutScheduler] Could not cancel task for shift ${shiftId}:`, error.message);
    return { cancelled: false, error: error.message };
  }
};

module.exports = {
  scheduleBreakoutOpener,
  cancelBreakoutOpener,
};
