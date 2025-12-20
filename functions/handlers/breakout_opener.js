const { onCall, HttpsError, onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { getZoomConfig } = require('../services/zoom/config');
const { sendFCMNotificationToTeacher } = require('../services/notifications/fcm');

const normalizeEmail = (value) => {
  if (typeof value !== 'string') return null;
  const email = value.trim().toLowerCase();
  return email || null;
};

const getHostKeyForHostEmail = (hostEmail) => {
  const normalized = normalizeEmail(hostEmail);
  if (!normalized) return null;

  // Prefer a JSON mapping so multiple hosts can be supported without code changes.
  // Example: {"nenenane2@gmail.com":"346048","support@alluwaleducationhub.org":"419171"}
  const json = process.env.ZOOM_HOST_KEYS_JSON;
  if (typeof json === 'string' && json.trim()) {
    try {
      const map = JSON.parse(json);
      const key = map?.[normalized];
      if (typeof key === 'string' && key.trim()) return key.trim();
    } catch (e) {
      console.warn('[BreakoutOpener] Invalid ZOOM_HOST_KEYS_JSON:', e.message);
    }
  }

  // Common explicit env vars (recommended for secrets managers).
  if (normalized === 'support@alluwaleducationhub.org' && process.env.ZOOM_HOST_KEY_SUPPORT) {
    return String(process.env.ZOOM_HOST_KEY_SUPPORT).trim();
  }
  if (normalized === 'nenenane2@gmail.com' && process.env.ZOOM_HOST_KEY_NENENANE2) {
    return String(process.env.ZOOM_HOST_KEY_NENENANE2).trim();
  }

  // Backward compatibility: single-host deployments use ZOOM_HOST_KEY + ZOOM_HOST_USER.
  const defaultHost = normalizeEmail(process.env.ZOOM_HOST_USER);
  if (defaultHost && normalized === defaultHost && process.env.ZOOM_HOST_KEY) {
    return String(process.env.ZOOM_HOST_KEY).trim();
  }

  return null;
};

/**
 * Cloud Task handler to open breakout rooms for a shift
 * This is the backup mechanism - triggered X minutes after shift start
 * if teachers haven't opened rooms via the app
 *
 * Flow:
 * 1. Check if breakout rooms are already opened (via Firestore flag)
 * 2. If not, call the bot service to join and open rooms
 * 3. Update shift with room status
 */
const openBreakoutRooms = onRequest(
  { timeoutSeconds: 120, memory: '256MiB' },
  async (req, res) => {
    // ... (keep existing openBreakoutRooms logic, but ensure it uses v2 onRequest)
    // Verify this is a Cloud Tasks request
    const taskName = req.headers['x-cloudtasks-taskname'];
    if (!taskName && process.env.NODE_ENV === 'production') {
      console.warn('[BreakoutOpener] Request missing Cloud Tasks header');
      res.status(403).send('Forbidden');
      return;
    }

    const { shiftId, zoomMeetingId } = req.body;

    if (!shiftId || !zoomMeetingId) {
      console.error('[BreakoutOpener] Missing required fields:', { shiftId, zoomMeetingId });
      res.status(400).send('Missing shiftId or zoomMeetingId');
      return;
    }

    console.log(`[BreakoutOpener] Processing shift ${shiftId}, meeting ${zoomMeetingId}`);

    const db = admin.firestore();

    try {
      // Check if rooms are already opened
      const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();

      if (!shiftDoc.exists) {
        console.warn(`[BreakoutOpener] Shift ${shiftId} not found`);
        res.status(404).send('Shift not found');
        return;
      }

      const shiftData = shiftDoc.data();

      // Check if rooms were already opened by a teacher
      if (shiftData.breakout_rooms_opened_at) {
        console.log(`[BreakoutOpener] Rooms already opened for shift ${shiftId} at ${shiftData.breakout_rooms_opened_at.toDate()}`);
        res.status(200).json({
          status: 'already_opened',
          openedAt: shiftData.breakout_rooms_opened_at.toDate().toISOString(),
        });
        return;
      }

      // Check if shift is cancelled or completed
      if (shiftData.status === 'cancelled' || shiftData.status === 'completed') {
        console.log(`[BreakoutOpener] Shift ${shiftId} is ${shiftData.status}, skipping`);
        res.status(200).json({ status: 'skipped', reason: shiftData.status });
        return;
      }

      console.log(`[BreakoutOpener] Breakout rooms not opened yet for shift ${shiftId}. Sending teacher reminder.`);

      const teacherId = shiftData.teacher_id;
      if (teacherId) {
        try {
          await sendFCMNotificationToTeacher(
            teacherId,
            {
              title: 'Open breakout rooms',
              body: 'Please open breakout rooms in Zoom so students are routed to class.',
            },
            {
              type: 'zoom',
              action: 'open_breakout_rooms',
              shiftId: String(shiftId),
              zoomMeetingId: String(zoomMeetingId),
            }
          );
        } catch (notifyErr) {
          console.warn(`[BreakoutOpener] Failed to send FCM reminder for shift ${shiftId}:`, notifyErr?.message || notifyErr);
        }
      } else {
        console.warn(`[BreakoutOpener] Shift ${shiftId} missing teacher_id; cannot send reminder.`);
      }

      // For now, mark that we attempted to open rooms
      await db.collection('teaching_shifts').doc(shiftId).update({
        breakout_opener_triggered_at: admin.firestore.FieldValue.serverTimestamp(),
        breakout_opener_status: 'reminder_sent',
        breakout_opener_reminded_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Also log to a separate collection for monitoring
      await db.collection('breakout_opener_logs').add({
        shiftId,
        zoomMeetingId,
        triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'reminder_sent',
        message: 'Teacher reminder sent (auto-open not available)',
      });

      res.status(200).json({
        status: 'reminded',
        message: 'Teacher reminder sent to open breakout rooms',
        shiftId,
        zoomMeetingId,
      });

    } catch (error) {
      console.error(`[BreakoutOpener] Error processing shift ${shiftId}:`, error);
      res.status(500).json({
        status: 'error',
        error: error.message,
      });
    }
  }
);

/**
 * Callable function for teachers to mark breakout rooms as opened
 * Call this from the app when a teacher opens breakout rooms manually
 */
const markBreakoutRoomsOpened = onCall(async (request) => {
  console.log('[BreakoutOpener] markBreakoutRoomsOpened called with data:', JSON.stringify(request.data));
  const shiftId = request.data?.shiftId || (typeof request.data === 'string' ? request.data : null);
  const uid = request.auth?.uid;

  if (!shiftId) {
    console.warn('[BreakoutOpener] markBreakoutRoomsOpened called without shiftId');
    throw new HttpsError('invalid-argument', 'Missing shiftId');
  }

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be authenticated');
  }

  const db = admin.firestore();
  const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();

  if (!shiftDoc.exists) {
    throw new HttpsError('not-found', 'Shift not found');
  }

  const shiftData = shiftDoc.data();

  // Verify caller is a teacher for this shift (or is admin)
  const userDoc = await db.collection('users').doc(uid).get();
  const userData = userDoc.exists ? userDoc.data() : null;
  const isAdmin = userData?.user_type === 'admin' || userData?.isAdmin === true;
  const isTeacherForShift = shiftData.teacher_id === uid;

  if (!isAdmin && !isTeacherForShift) {
    throw new HttpsError('permission-denied', 'Not authorized for this shift');
  }

  // Mark rooms as opened
  await db.collection('teaching_shifts').doc(shiftId).update({
    breakout_rooms_opened_at: admin.firestore.FieldValue.serverTimestamp(),
    breakout_rooms_opened_by: uid,
  });

  // Cancel the backup Cloud Task since rooms are now open
  try {
    const { cancelBreakoutOpener } = require('../services/zoom/breakout_scheduler');
    await cancelBreakoutOpener(shiftId);
  } catch (e) {
    console.warn(`[BreakoutOpener] Failed to cancel backup task for ${shiftId}:`, e);
  }

  console.log(`[BreakoutOpener] Rooms marked as opened for shift ${shiftId} by ${uid}`);

  return { success: true, shiftId };
});

/**
 * Get Zoom host key for a teacher to claim host
 * Only returns host key to authenticated teachers for their shifts
 */
const getZoomHostKey = onCall(async (request) => {
  console.log('[BreakoutOpener] getZoomHostKey called with data:', JSON.stringify(request.data));
  const shiftId = request.data?.shiftId || (typeof request.data === 'string' ? request.data : null);
  const uid = request.auth?.uid;

  if (!shiftId) {
    console.warn('[BreakoutOpener] getZoomHostKey called without shiftId. request.data is:', request.data);
    throw new HttpsError('invalid-argument', 'Missing shiftId');
  }

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be authenticated');
  }

  const db = admin.firestore();
  const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();

  if (!shiftDoc.exists) {
    throw new HttpsError('not-found', 'Shift not found');
  }

  const shiftData = shiftDoc.data();

  if (!shiftData.zoom_meeting_id) {
    throw new HttpsError('not-found', 'Zoom meeting not configured for this shift');
  }

  // Verify caller is a teacher for this shift
  if (shiftData.teacher_id !== uid) {
    throw new HttpsError('permission-denied', 'Not a teacher for this shift');
  }

  // Only allow host key retrieval during the same time window as joining the meeting.
  const shiftStart = shiftData.shift_start?.toDate ? shiftData.shift_start.toDate() : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate ? shiftData.shift_end.toDate() : new Date(shiftData.shift_end);
  const now = new Date();
  const allowedStartMs = shiftStart.getTime() - 10 * 60 * 1000;
  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;
  if (now.getTime() < allowedStartMs || now.getTime() > allowedEndMs) {
    throw new HttpsError('failed-precondition', 'Host key is only available during the meeting join window');
  }

  // Determine which Zoom host owns this meeting.
  let zoomConfig;
  try {
    zoomConfig = getZoomConfig();
  } catch (e) {
    throw new HttpsError('failed-precondition', `Zoom integration not configured: ${e.message}`);
  }
  const hostEmail = shiftData.zoom_host_email || zoomConfig.hostUser || process.env.ZOOM_HOST_USER;

  const hostKey = getHostKeyForHostEmail(hostEmail);

  if (!hostKey) {
    console.warn('[BreakoutOpener] Host key not configured for meeting host:', hostEmail);
    throw new HttpsError('failed-precondition', 'Host key not configured for this meeting host');
  }

  console.log(`[BreakoutOpener] Returning host key for shift ${shiftId} to teacher ${uid}`);

  return {
    hostKey,
    shiftId,
    meetingId: shiftData.zoom_meeting_id,
    hostEmail,
  };
});

module.exports = {
  openBreakoutRooms,
  markBreakoutRoomsOpened,
  getZoomHostKey,
};
