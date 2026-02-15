/**
 * AI Tutor Cloud Function Handlers
 *
 * Provides callable functions for connecting students to the LiveKit AI tutor agent.
 */

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { RoomServiceClient, AgentDispatchClient } = require('livekit-server-sdk');
const { getLiveKitConfig, isLiveKitConfigured } = require('../services/livekit/config');
const { generateAccessToken } = require('../services/livekit/token');

// AI Tutor agent name (as registered in LiveKit Cloud)
const AI_TUTOR_AGENT_NAME = 'Alluwal';

/**
 * Helper: Get user display name from Firestore
 */
const getUserDisplayName = async (uid) => {
  if (!uid) return 'Student';
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return 'Student';
    const data = userDoc.data();
    const firstName = data.first_name || data.firstName || '';
    const lastName = data.last_name || data.lastName || '';
    const fullName = [firstName, lastName].filter(Boolean).join(' ');
    return fullName || data['e-mail'] || data.email || 'Student';
  } catch (_) {
    return 'Student';
  }
};

/**
 * Helper: Check if user is a student
 */
const isUserStudent = async (uid) => {
  if (!uid) return false;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    const data = userDoc.data();
    const role = data.role || data.user_type || data.userType || '';
    return role.toLowerCase() === 'student';
  } catch (_) {
    return false;
  }
};

/**
 * Helper: Get student's upcoming classes
 * Returns a formatted string of upcoming classes for the AI tutor
 */
const getStudentClasses = async (uid) => {
  if (!uid) return '';

  try {
    const db = admin.firestore();
    const now = new Date();

    // Query shifts where student is enrolled (check both field names)
    // Get shifts from today onwards
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Query by student_ids array (contains uid)
    const shiftsSnapshot = await db.collection('teaching_shifts')
      .where('student_ids', 'array-contains', uid)
      .where('start_time', '>=', admin.firestore.Timestamp.fromDate(todayStart))
      .orderBy('start_time', 'asc')
      .limit(10)
      .get();

    if (shiftsSnapshot.empty) {
      return 'No upcoming classes scheduled.';
    }

    const classes = [];
    const teacherCache = {};

    for (const doc of shiftsSnapshot.docs) {
      const shift = doc.data();
      const startTime = shift.start_time?.toDate?.() || new Date(shift.start_time);
      const endTime = shift.end_time?.toDate?.() || new Date(shift.end_time);

      // Get teacher name (with caching)
      let teacherName = 'Unknown Teacher';
      if (shift.teacher_id) {
        if (teacherCache[shift.teacher_id]) {
          teacherName = teacherCache[shift.teacher_id];
        } else {
          try {
            const teacherDoc = await db.collection('users').doc(shift.teacher_id).get();
            if (teacherDoc.exists) {
              const teacherData = teacherDoc.data();
              teacherName = [teacherData.first_name, teacherData.last_name].filter(Boolean).join(' ') || 'Teacher';
              teacherCache[shift.teacher_id] = teacherName;
            }
          } catch (_) {}
        }
      }

      // Format the class info
      const dayName = startTime.toLocaleDateString('en-US', { weekday: 'long' });
      const dateStr = startTime.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      const timeStr = startTime.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
      const endTimeStr = endTime.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });

      const subject = shift.subject || shift.subject_name || 'Class';

      classes.push(`${subject} with ${teacherName} on ${dayName} ${dateStr} from ${timeStr} to ${endTimeStr}`);
    }

    return classes.length > 0
      ? `Upcoming classes: ${classes.join('. ')}.`
      : 'No upcoming classes scheduled.';
  } catch (err) {
    console.warn('[AI Tutor] Failed to fetch student classes:', err.message);
    return 'Unable to load class schedule.';
  }
};

/**
 * Callable function: Get LiveKit token for AI Tutor session
 *
 * This creates a unique room for the student to interact with the AI tutor agent.
 * The room name follows a pattern that the LiveKit agent dispatcher recognizes.
 *
 * @param {Object} request - Firebase callable request
 * @returns {Object} LiveKit connection details for AI tutor session
 */
const getAITutorToken = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const uid = request.auth?.uid;

  // Require authentication
  if (!uid) {
    console.log('[AI Tutor] Unauthenticated request');
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  // Check LiveKit configuration
  if (!isLiveKitConfigured()) {
    console.error('[AI Tutor] LiveKit not configured');
    throw new HttpsError('unavailable', 'AI Tutor is not available at this time');
  }

  // Verify user is a student
  const isStudent = await isUserStudent(uid);
  if (!isStudent) {
    console.log('[AI Tutor] Non-student access attempt. uid:', uid);
    throw new HttpsError('permission-denied', 'AI Tutor is only available for students');
  }

  // Get user details and class schedule
  const displayName = await getUserDisplayName(uid);
  const classSchedule = await getStudentClasses(uid);

  console.log('[AI Tutor] Fetched class schedule for user:', uid);

  // Create a unique room name for this AI tutor session
  // The room name pattern should be recognized by the LiveKit agent dispatcher
  // Format: ai_tutor_{userId}_{timestamp}
  const timestamp = Date.now();
  const roomName = `ai_tutor_${uid}_${timestamp}`;

  // Token TTL: 1 hour for AI tutor sessions
  const ttlSeconds = 3600;

  // Generate LiveKit token with metadata for the AI agent
  // The agent uses {{metadata.user_name}} in its greeting template
  const livekitConfig = getLiveKitConfig();

  // Normalize the LiveKit URL for server API (ws -> http)
  const normalizeUrl = (url) => {
    if (!url) return url;
    if (url.startsWith('wss://')) return `https://${url.slice('wss://'.length)}`;
    if (url.startsWith('ws://')) return `http://${url.slice('ws://'.length)}`;
    return url;
  };

  const serverUrl = normalizeUrl(livekitConfig.url);

  // Create room with metadata for the agent
  const roomMetadata = JSON.stringify({
    user_name: displayName,
    session_type: 'ai_tutor',
    class_schedule: classSchedule,
  });

  try {
    // Create room service client
    const roomService = new RoomServiceClient(serverUrl, livekitConfig.apiKey, livekitConfig.apiSecret);

    // Create the room first
    console.log('[AI Tutor] Creating room:', roomName);
    await roomService.createRoom({
      name: roomName,
      metadata: roomMetadata,
      emptyTimeout: 300, // 5 minutes empty timeout
      maxParticipants: 2, // Just student and agent
    });
    console.log('[AI Tutor] Room created successfully');

    // Dispatch the AI agent to the room
    console.log('[AI Tutor] Dispatching agent:', AI_TUTOR_AGENT_NAME);
    const agentDispatch = new AgentDispatchClient(serverUrl, livekitConfig.apiKey, livekitConfig.apiSecret);
    await agentDispatch.createDispatch(roomName, AI_TUTOR_AGENT_NAME, {
      metadata: roomMetadata,
    });
    console.log('[AI Tutor] Agent dispatched successfully');
  } catch (roomErr) {
    console.error('[AI Tutor] Room/Agent setup error:', roomErr.message);
    // Continue even if room creation fails - it might already exist
    // The token will still work
  }

  const token = await generateAccessToken(roomName, {
    identity: uid,
    name: displayName,
    metadata: {
      user_name: displayName,
      role: 'student',
      session_type: 'ai_tutor',
      class_schedule: classSchedule,
    },
    ttlSeconds,
    videoGrant: {
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    },
  });

  console.log('[AI Tutor] Token generated. uid:', uid, 'room:', roomName, 'displayName:', displayName);

  // Log session start for analytics
  try {
    await admin.firestore().collection('ai_tutor_sessions').add({
      userId: uid,
      userName: displayName,
      roomName: roomName,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'started',
    });
  } catch (logErr) {
    console.warn('[AI Tutor] Failed to log session:', logErr.message);
    // Non-blocking - continue even if logging fails
  }

  return {
    success: true,
    livekitUrl: livekitConfig.url,
    token: token,
    roomName: roomName,
    displayName: displayName,
    expiresInSeconds: ttlSeconds,
    agentName: AI_TUTOR_AGENT_NAME,
  };
});

/**
 * Callable function: End AI Tutor session
 *
 * Updates the session log with end time and duration.
 *
 * @param {Object} request - Firebase callable request
 * @param {string} request.data.roomName - The room name of the session to end
 * @returns {Object} Success status
 */
const endAITutorSession = onCall({}, async (request) => {
  const uid = request.auth?.uid;
  const roomName = request.data?.roomName;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  if (!roomName || typeof roomName !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid roomName');
  }

  // Find and update the session
  try {
    const sessionsSnapshot = await admin.firestore()
      .collection('ai_tutor_sessions')
      .where('userId', '==', uid)
      .where('roomName', '==', roomName)
      .where('status', '==', 'started')
      .limit(1)
      .get();

    if (!sessionsSnapshot.empty) {
      const sessionDoc = sessionsSnapshot.docs[0];
      await sessionDoc.ref.update({
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'ended',
      });
      console.log('[AI Tutor] Session ended. uid:', uid, 'room:', roomName);
    }

    return { success: true };
  } catch (err) {
    console.error('[AI Tutor] Failed to end session:', err.message);
    // Don't throw - session ending is not critical
    return { success: true };
  }
});

module.exports = {
  getAITutorToken,
  endAITutorSession,
};
