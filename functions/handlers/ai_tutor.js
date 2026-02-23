/**
 * AI Tutor Cloud Function Handlers
 *
 * Provides callable functions for connecting students to the LiveKit AI tutor agent.
 */

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { RoomServiceClient, AgentDispatchClient } = require('livekit-server-sdk');
const { DateTime } = require('luxon');
const { getLiveKitConfig, isLiveKitConfigured } = require('../services/livekit/config');
const { generateAccessToken } = require('../services/livekit/token');

// AI Tutor agent name (as registered in LiveKit Cloud)
const AI_TUTOR_AGENT_NAME = 'Alluwal';

const normalizeTimezone = (timezone) => {
  const tz = typeof timezone === 'string' ? timezone.trim() : '';
  if (!tz) return 'UTC';
  try {
    const test = DateTime.now().setZone(tz);
    return test.isValid ? tz : 'UTC';
  } catch (_) {
    return 'UTC';
  }
};

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
 * Helper: Get normalized user role
 */
const getUserRole = async (uid) => {
  if (!uid) return '';
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return '';
    const data = userDoc.data();
    const role = data.role || data.user_type || data.userType || '';
    return role.toString().trim().toLowerCase();
  } catch (_) {
    return '';
  }
};

/**
 * Helper: Get user's timezone
 */
const getUserTimezone = async (uid) => {
  if (!uid) return 'UTC';
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return 'UTC';
    const data = userDoc.data() || {};
    return normalizeTimezone(data.timezone);
  } catch (_) {
    return 'UTC';
  }
};

/**
 * Helper: Check if AI Tutor is enabled for user
 */
const checkAITutorEnabled = async (uid) => {
  if (!uid) return false;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    const data = userDoc.data() || {};
    return data.ai_tutor_enabled === true;
  } catch (_) {
    return false;
  }
};

/**
 * Helper: Get student's upcoming classes
 * Returns a formatted string of upcoming classes for the AI tutor
 */
const getStudentClasses = async (uid, studentTimezone = 'UTC') => {
  if (!uid) return '';

  try {
    const db = admin.firestore();
    const now = new Date();
    const nowTs = admin.firestore.Timestamp.fromDate(now);
    const resolvedStudentTimezone = normalizeTimezone(studentTimezone);

    const classes = [];
    const teacherCache = {};
    const isMissingIndexError = (err) => {
      if (!err) return false;
      const code = err.code;
      const msg = (err.message || err.toString() || '').toLowerCase();
      return (
        code === 9 ||
        msg.includes('failed_precondition') ||
        msg.includes('requires an index')
      );
    };

    const toDate = (value) => {
      if (!value) return null;
      if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
      if (typeof value.toDate === 'function') {
        const dt = value.toDate();
        return dt instanceof Date && !Number.isNaN(dt.getTime()) ? dt : null;
      }
      if (typeof value === 'string' || typeof value === 'number') {
        const dt = new Date(value);
        return Number.isNaN(dt.getTime()) ? null : dt;
      }
      return null;
    };

    const normalizeSubject = (raw) => {
      const subject = (raw || 'Class').toString().trim();
      if (!subject) return 'Class';
      return subject
        .replace(/([a-z])([A-Z])/g, '$1 $2')
        .replace(/_/g, ' ')
        .replace(/\b\w/g, (c) => c.toUpperCase());
    };

    const formatHHmm = (value, sourceTimezone = resolvedStudentTimezone) => {
      const raw = (value || '').toString().trim();
      const match = raw.match(/^(\d{1,2}):(\d{2})$/);
      if (!match) return raw;
      const hours = Number(match[1]);
      const minutes = Number(match[2]);
      if (!Number.isInteger(hours) || !Number.isInteger(minutes)) return raw;
      const sourceTz = normalizeTimezone(sourceTimezone);
      const sourceDt = DateTime.now().setZone(sourceTz).set({
        hour: hours,
        minute: minutes,
        second: 0,
        millisecond: 0,
      });
      if (!sourceDt.isValid) return raw;
      return sourceDt.setZone(resolvedStudentTimezone).toFormat('h:mm a');
    };

    const getTeacherName = async (teacherId, fallbackName = 'Teacher') => {
      if (!teacherId) return fallbackName;
      if (teacherCache[teacherId]) return teacherCache[teacherId];
      try {
        const teacherDoc = await db.collection('users').doc(teacherId).get();
        if (teacherDoc.exists) {
          const teacherData = teacherDoc.data() || {};
          const fullName = [teacherData.first_name, teacherData.last_name]
            .filter(Boolean)
            .join(' ')
            .trim();
          const teacherName = fullName || fallbackName;
          teacherCache[teacherId] = teacherName;
          return teacherName;
        }
      } catch (_) {}
      teacherCache[teacherId] = fallbackName;
      return fallbackName;
    };

    const formatShiftLine = async (shift) => {
      const startTime = toDate(shift.shift_start || shift.start_time);
      const endTime = toDate(shift.shift_end || shift.end_time);
      if (!startTime || startTime < now) return null;

      const startDt = DateTime.fromJSDate(startTime, { zone: 'utc' })
        .setZone(resolvedStudentTimezone);
      if (!startDt.isValid) return null;
      const endDt = endTime
        ? DateTime.fromJSDate(endTime, { zone: 'utc' }).setZone(resolvedStudentTimezone)
        : null;

      const teacherName = await getTeacherName(
        shift.teacher_id,
        shift.teacher_name || 'Teacher',
      );
      const dayName = startDt.toFormat('cccc');
      const dateStr = startDt.toFormat('LLL d');
      const timeStr = startDt.toFormat('h:mm a');
      const endTimeStr = endDt
        ? endDt.toFormat('h:mm a')
        : 'end time not set';
      const subject = normalizeSubject(
        shift.subject_display_name ||
          shift.subject_name ||
          shift.custom_name ||
          shift.auto_generated_name ||
          shift.subject,
      );

      return `${subject} with ${teacherName} on ${dayName} ${dateStr} from ${timeStr} to ${endTimeStr}`;
    };

    let shiftDocs = [];

    // Primary lookup: current teaching_shifts schema uses shift_start/shift_end timestamps.
    try {
      const shiftsSnapshot = await db.collection('teaching_shifts')
        .where('student_ids', 'array-contains', uid)
        .where('shift_start', '>=', nowTs)
        .orderBy('shift_start', 'asc')
        .limit(10)
        .get();
      shiftDocs = shiftsSnapshot.docs;
    } catch (err) {
      if (isMissingIndexError(err)) {
        console.warn('[AI Tutor] Missing index for shift_start query; continuing with fallbacks.');
      } else {
        throw err;
      }
    }

    // Legacy fallback for older docs that used start_time/end_time as timestamps.
    if (shiftDocs.length === 0) {
      try {
        const legacySnapshot = await db.collection('teaching_shifts')
          .where('student_ids', 'array-contains', uid)
          .where('start_time', '>=', nowTs)
          .orderBy('start_time', 'asc')
          .limit(10)
          .get();
        shiftDocs = legacySnapshot.docs;
      } catch (err) {
        if (isMissingIndexError(err)) {
          console.warn('[AI Tutor] Missing index for legacy start_time query; skipping legacy query.');
        } else {
          throw err;
        }
      }
    }

    // Final fallback if legacy query cannot run: in-memory filter over student shifts.
    if (shiftDocs.length === 0) {
      try {
        const broadSnapshot = await db.collection('teaching_shifts')
          .where('student_ids', 'array-contains', uid)
          .limit(200)
          .get();
        const filtered = broadSnapshot.docs
          .filter((doc) => {
            const data = doc.data() || {};
            const start = toDate(data.start_time);
            return !!start && start >= now;
          })
          .sort((a, b) => {
            const aStart = toDate((a.data() || {}).start_time);
            const bStart = toDate((b.data() || {}).start_time);
            return (aStart?.getTime() || 0) - (bStart?.getTime() || 0);
          })
          .slice(0, 10);
        shiftDocs = filtered;
      } catch (err) {
        if (!isMissingIndexError(err)) {
          throw err;
        }
      }
    }

    for (const doc of shiftDocs) {
      const shift = doc.data() || {};
      const line = await formatShiftLine(shift);
      if (line) classes.push(line);
    }

    if (classes.length > 0) {
      return `Upcoming classes (all times in your timezone: ${resolvedStudentTimezone}): ${classes.join('. ')}.`;
    }

    // Fallback: if future shift instances are not generated yet, use active templates.
    const templatesSnapshot = await db.collection('shift_templates')
      .where('student_ids', 'array-contains', uid)
      .limit(10)
      .get();

    const weekdayNames = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    for (const doc of templatesSnapshot.docs) {
      const template = doc.data() || {};
      if (template.is_active === false) continue;

      const teacherName = await getTeacherName(
        template.teacher_id,
        template.teacher_name || 'Teacher',
      );
      const subject = normalizeSubject(
        template.subject_display_name ||
          template.subject_name ||
          template.custom_name ||
          template.auto_generated_name ||
          template.subject,
      );

      const recurrence = template.enhanced_recurrence || {};
      const templateTimezone = normalizeTimezone(
        template.teacher_timezone || template.admin_timezone || resolvedStudentTimezone,
      );
      const recurrenceType = (recurrence.type || '').toString().toLowerCase();
      const selectedWeekdays = Array.isArray(recurrence.selectedWeekdays)
        ? recurrence.selectedWeekdays
        : [];
      const weekdayText = [...new Set(selectedWeekdays
        .map((day) => {
          const sourceDay = Number(day);
          if (!Number.isInteger(sourceDay) || sourceDay < 1 || sourceDay > 7) {
            return null;
          }
          const weekStart = DateTime.now().setZone(templateTimezone).startOf('week');
          let sourceDate = weekStart;
          for (let i = 0; i < 7; i++) {
            if (sourceDate.weekday === sourceDay) break;
            sourceDate = sourceDate.plus({ days: 1 });
          }
          const shifted = sourceDate
            .set({ hour: 12, minute: 0, second: 0, millisecond: 0 })
            .setZone(resolvedStudentTimezone);
          return weekdayNames[shifted.weekday] || null;
        })
        .filter(Boolean))]
        .join(', ');

      const startTime = formatHHmm(template.start_time, templateTimezone);
      const endTime = formatHHmm(template.end_time, templateTimezone);
      const timeRange = startTime && endTime
        ? `${startTime} to ${endTime}`
        : (startTime || endTime || 'time not set');

      let pattern = 'schedule pattern not set';
      if (recurrenceType === 'weekly' && weekdayText) {
        pattern = `every ${weekdayText}`;
      } else if (recurrenceType === 'daily') {
        pattern = 'every day';
      } else if (recurrenceType) {
        pattern = `${recurrenceType} schedule`;
      }

      classes.push(`${subject} with ${teacherName} ${pattern} at ${timeRange}`);
    }

    return classes.length > 0
      ? `Class schedule (all times in your timezone: ${resolvedStudentTimezone}): ${classes.join('. ')}.`
      : `No upcoming classes scheduled in your timezone (${resolvedStudentTimezone}).`;
  } catch (err) {
    console.warn('[AI Tutor] Failed to fetch student classes:', err.message);
    return 'Unable to load class schedule.';
  }
};

/**
 * Helper: Get teacher upcoming classes
 * Returns a formatted string of upcoming classes for the AI assistant
 */
const getTeacherClasses = async (uid, teacherTimezone = 'UTC') => {
  if (!uid) return '';

  try {
    const db = admin.firestore();
    const now = new Date();
    const nowTs = admin.firestore.Timestamp.fromDate(now);
    const resolvedTimezone = normalizeTimezone(teacherTimezone);

    const classes = [];
    const isMissingIndexError = (err) => {
      if (!err) return false;
      const code = err.code;
      const msg = (err.message || err.toString() || '').toLowerCase();
      return (
        code === 9 ||
        msg.includes('failed_precondition') ||
        msg.includes('requires an index')
      );
    };

    const toDate = (value) => {
      if (!value) return null;
      if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
      if (typeof value.toDate === 'function') {
        const dt = value.toDate();
        return dt instanceof Date && !Number.isNaN(dt.getTime()) ? dt : null;
      }
      if (typeof value === 'string' || typeof value === 'number') {
        const dt = new Date(value);
        return Number.isNaN(dt.getTime()) ? null : dt;
      }
      return null;
    };

    const normalizeSubject = (raw) => {
      const subject = (raw || 'Class').toString().trim();
      if (!subject) return 'Class';
      return subject
        .replace(/([a-z])([A-Z])/g, '$1 $2')
        .replace(/_/g, ' ')
        .replace(/\b\w/g, (c) => c.toUpperCase());
    };

    const formatShiftLine = (shift) => {
      const startTime = toDate(shift.shift_start || shift.start_time);
      const endTime = toDate(shift.shift_end || shift.end_time);
      if (!startTime || startTime < now) return null;

      const startDt = DateTime.fromJSDate(startTime, { zone: 'utc' })
        .setZone(resolvedTimezone);
      if (!startDt.isValid) return null;
      const endDt = endTime
        ? DateTime.fromJSDate(endTime, { zone: 'utc' }).setZone(resolvedTimezone)
        : null;

      const subject = normalizeSubject(
        shift.subject_display_name ||
          shift.subject_name ||
          shift.custom_name ||
          shift.auto_generated_name ||
          shift.subject,
      );

      const studentNames = Array.isArray(shift.student_names)
        ? shift.student_names.filter(Boolean)
        : [];
      const studentLabel = studentNames.length === 0
        ? 'students not listed'
        : (studentNames.length <= 2
            ? studentNames.join(' and ')
            : `${studentNames.slice(0, 2).join(', ')} and ${studentNames.length - 2} more`);

      return `${subject} with ${studentLabel} on ${startDt.toFormat('cccc LLL d')} from ${startDt.toFormat('h:mm a')} to ${endDt ? endDt.toFormat('h:mm a') : 'end time not set'}`;
    };

    let shiftDocs = [];
    try {
      const shiftsSnapshot = await db.collection('teaching_shifts')
        .where('teacher_id', '==', uid)
        .where('shift_start', '>=', nowTs)
        .orderBy('shift_start', 'asc')
        .limit(10)
        .get();
      shiftDocs = shiftsSnapshot.docs;
    } catch (err) {
      if (isMissingIndexError(err)) {
        console.warn('[AI Tutor] Missing index for teacher shift_start query; continuing with fallback.');
      } else {
        throw err;
      }
    }

    // In-memory fallback (avoids index requirement)
    if (shiftDocs.length === 0) {
      const broadSnapshot = await db.collection('teaching_shifts')
        .where('teacher_id', '==', uid)
        .limit(200)
        .get();
      shiftDocs = broadSnapshot.docs
        .filter((doc) => {
          const data = doc.data() || {};
          const start = toDate(data.shift_start || data.start_time);
          return !!start && start >= now;
        })
        .sort((a, b) => {
          const aStart = toDate((a.data() || {}).shift_start || (a.data() || {}).start_time);
          const bStart = toDate((b.data() || {}).shift_start || (b.data() || {}).start_time);
          return (aStart?.getTime() || 0) - (bStart?.getTime() || 0);
        })
        .slice(0, 10);
    }

    for (const doc of shiftDocs) {
      const line = formatShiftLine(doc.data() || {});
      if (line) classes.push(line);
    }

    if (classes.length > 0) {
      return `Your teaching schedule (all times in your timezone: ${resolvedTimezone}): ${classes.join('. ')}.`;
    }

    // Template fallback for teachers
    const templatesSnapshot = await db.collection('shift_templates')
      .where('teacher_id', '==', uid)
      .where('is_active', '==', true)
      .limit(10)
      .get();

    const weekdayNames = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    for (const doc of templatesSnapshot.docs) {
      const template = doc.data() || {};
      const subject = normalizeSubject(
        template.subject_display_name ||
          template.subject_name ||
          template.custom_name ||
          template.auto_generated_name ||
          template.subject,
      );

      const recurrence = template.enhanced_recurrence || {};
      const recurrenceType = (recurrence.type || '').toString().toLowerCase();
      const selectedWeekdays = Array.isArray(recurrence.selectedWeekdays)
        ? recurrence.selectedWeekdays
        : [];
      const weekdayText = selectedWeekdays
        .map((day) => weekdayNames[Number(day)])
        .filter(Boolean)
        .join(', ');

      const startTime = (template.start_time || '').toString().trim();
      const endTime = (template.end_time || '').toString().trim();
      const timeRange = startTime && endTime
        ? `${startTime} to ${endTime}`
        : (startTime || endTime || 'time not set');

      let pattern = 'schedule pattern not set';
      if (recurrenceType === 'weekly' && weekdayText) {
        pattern = `every ${weekdayText}`;
      } else if (recurrenceType === 'daily') {
        pattern = 'every day';
      } else if (recurrenceType) {
        pattern = `${recurrenceType} schedule`;
      }

      classes.push(`${subject} ${pattern} at ${timeRange}`);
    }

    return classes.length > 0
      ? `Your teaching schedule (all times in your timezone: ${resolvedTimezone}): ${classes.join('. ')}.`
      : `No upcoming classes scheduled in your timezone (${resolvedTimezone}).`;
  } catch (err) {
    console.warn('[AI Tutor] Failed to fetch teacher classes:', err.message);
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

  // Verify role: AI tutor currently supports students and teachers.
  const userRoleRaw = await getUserRole(uid);
  const isTeacher = userRoleRaw.includes('teacher');
  const isStudent = userRoleRaw === 'student';
  const sessionRole = isTeacher ? 'teacher' : (isStudent ? 'student' : '');
  if (!sessionRole) {
    console.log('[AI Tutor] Unsupported role access attempt. uid:', uid, 'role:', userRoleRaw);
    throw new HttpsError('permission-denied', 'AI Tutor is only available for students and teachers');
  }

  // Check if AI Tutor is enabled for this user
  const aiTutorEnabled = await checkAITutorEnabled(uid);
  if (!aiTutorEnabled) {
    console.log('[AI Tutor] Access denied - AI Tutor not enabled. uid:', uid);
    throw new HttpsError('permission-denied', 'AI Tutor access has not been enabled for your account');
  }

  // Get user details and role-specific class schedule
  const displayName = await getUserDisplayName(uid);
  const userTimezone = await getUserTimezone(uid);
  const classSchedule = isTeacher
    ? await getTeacherClasses(uid, userTimezone)
    : await getStudentClasses(uid, userTimezone);
  const classScheduleStatus =
    typeof classSchedule === 'string' &&
    classSchedule.startsWith('Unable to load class schedule.')
      ? 'unavailable'
      : 'available';

  console.log('[AI Tutor] Fetched class schedule for user:', uid, 'role:', sessionRole, 'timezone:', userTimezone, 'status:', classScheduleStatus, 'summary:', classSchedule.slice(0, 220));

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
    user_role: sessionRole,
    user_timezone: userTimezone,
    class_schedule_status: classScheduleStatus,
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
      role: sessionRole,
      user_role: sessionRole,
      session_type: 'ai_tutor',
      user_timezone: userTimezone,
      class_schedule_status: classScheduleStatus,
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
      userRole: sessionRole,
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
    userRole: sessionRole,
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
