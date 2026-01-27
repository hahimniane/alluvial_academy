const admin = require('firebase-admin');

const logTokenDetails = (tokens) => {
  tokens.forEach((tokenData, idx) => {
    // eslint-disable-next-line no-console
    console.log(`  Token ${idx}:`);
    // eslint-disable-next-line no-console
    console.log(`    Platform: ${tokenData.platform || 'unknown'}`);
    // eslint-disable-next-line no-console
    console.log(`    Token: ${tokenData.token ? `${tokenData.token.substring(0, 30)}...` : 'null'}`);
    // eslint-disable-next-line no-console
    console.log(`    Last Updated: ${tokenData.lastUpdated || 'unknown'}`);
  });
};

/**
 * Format a date in the user's timezone
 * @param {Date} date - The date to format
 * @param {string} timezone - IANA timezone string (e.g., 'America/New_York')
 * @returns {string} Formatted date string
 */
const formatDateInTimezone = (date, timezone = 'UTC') => {
  try {
    return date.toLocaleString('en-US', {
      timeZone: timezone,
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
  } catch (error) {
    // Fallback to UTC if timezone is invalid
    console.log(`Invalid timezone ${timezone}, falling back to UTC`);
    return date.toLocaleString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
  }
};

/**
 * Get user's timezone from their profile
 * @param {string} userId - The user's ID
 * @returns {Promise<string>} The user's timezone or default
 */
const getUserTimezone = async (userId) => {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      return userData.timezone || userData.preferred_timezone || 'UTC';
    }
    return 'UTC';
  } catch (error) {
    console.log(`Error getting timezone for user ${userId}:`, error);
    return 'UTC';
  }
};

const sendFCMNotificationToTeacher = async (teacherId, notification, data) => {
  try {
    console.log(`Sending FCM notification to teacher: ${teacherId}`);

    const teacherDoc = await admin.firestore().collection('users').doc(teacherId).get();

    if (!teacherDoc.exists) {
      console.log(`Teacher ${teacherId} not found`);
      return {success: false, reason: 'Teacher not found'};
    }

    const teacherData = teacherDoc.data();
    const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim();
    const fcmTokens = teacherData.fcmTokens || [];

    console.log(`\n=== Shift Notification for: ${teacherName} (${teacherId}) ===`);
    console.log(`FCM Tokens found: ${fcmTokens.length}`);

    if (fcmTokens.length === 0) {
      console.log(`⚠️ No FCM tokens found for teacher ${teacherId}`);
      return {success: false, reason: 'No FCM tokens'};
    }

    logTokenDetails(fcmTokens);

    const tokens = fcmTokens.map((tokenObj) => tokenObj.token).filter((t) => t);
    console.log(`Valid tokens extracted: ${tokens.length}`);

    if (tokens.length === 0) {
      console.log(`⚠️ No valid tokens found for teacher ${teacherId}`);
      return {success: false, reason: 'No valid tokens'};
    }

    console.log(`\nAttempting to send shift notification to ${tokens.length} token(s)...`);

    const message = {
      notification,
      data,
      tokens,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`\n📱 Shift Notification Result for ${teacherName}:`);
    console.log(`  Success: ${response.successCount}/${tokens.length}`);
    console.log(`  Failed: ${response.failureCount}/${tokens.length}`);

    response.responses.forEach((resp, idx) => {
      if (resp.success) {
        console.log(`  ✅ Token ${idx}: SUCCESS - Message ID: ${resp.messageId}`);
      } else {
        console.log(`  ❌ Token ${idx}: FAILED - Error: ${resp.error?.code} - ${resp.error?.message}`);
      }
    });

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('Error sending FCM notification:', error);
    return {success: false, error: error.message};
  }
};

/**
 * Send FCM notification to a student
 * @param {string} studentId - The student's user ID
 * @param {Object} notification - The notification payload (title, body)
 * @param {Object} data - Additional data payload
 * @returns {Promise<Object>} Result of the notification send
 */
const sendFCMNotificationToStudent = async (studentId, notification, data) => {
  try {
    console.log(`📚 Sending FCM notification to student: ${studentId}`);

    const studentDoc = await admin.firestore().collection('users').doc(studentId).get();

    if (!studentDoc.exists) {
      console.log(`Student ${studentId} not found`);
      return {success: false, reason: 'Student not found'};
    }

    const studentData = studentDoc.data();
    const studentName = `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim();
    const fcmTokens = studentData.fcmTokens || [];

    console.log(`\n=== Class Notification for: ${studentName} (${studentId}) ===`);
    console.log(`FCM Tokens found: ${fcmTokens.length}`);

    if (fcmTokens.length === 0) {
      console.log(`⚠️ No FCM tokens found for student ${studentId}`);
      return {success: false, reason: 'No FCM tokens'};
    }

    const tokens = fcmTokens.map((tokenObj) => tokenObj.token).filter((t) => t);

    if (tokens.length === 0) {
      console.log(`⚠️ No valid tokens found for student ${studentId}`);
      return {success: false, reason: 'No valid tokens'};
    }

    const message = {
      notification,
      data,
      tokens,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`\n📱 Class Notification Result for ${studentName}:`);
    console.log(`  Success: ${response.successCount}/${tokens.length}`);
    console.log(`  Failed: ${response.failureCount}/${tokens.length}`);

    return {
      success: response.successCount > 0,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('Error sending FCM notification to student:', error);
    return {success: false, error: error.message};
  }
};

/**
 * Send class reminder notifications to all students in a shift
 * @param {Object} shift - The shift document data
 * @param {string} shiftId - The shift ID
 * @param {number} minutesUntil - Minutes until the class starts
 * @returns {Promise<Object>} Result summary
 */
const sendClassRemindersToStudents = async (shift, shiftId, minutesUntil) => {
  const studentIds = shift.student_ids || [];
  
  if (studentIds.length === 0) {
    console.log(`No students enrolled in shift ${shiftId}`);
    return {success: true, sent: 0, reason: 'No students'};
  }

  console.log(`📚 Sending class reminders to ${studentIds.length} students for shift ${shiftId}`);

  let successCount = 0;
  let failCount = 0;

  const displayName = shift.custom_name || shift.auto_generated_name || 'Your class';
  const teacherName = shift.teacher_name || 'your teacher';

  for (const studentId of studentIds) {
    try {
      // Get student's timezone for personalized time display
      const timezone = await getUserTimezone(studentId);
      const shiftStart = shift.shift_start.toDate ? shift.shift_start.toDate() : new Date(shift.shift_start);
      const formattedTime = formatDateInTimezone(shiftStart, timezone);

      const notification = {
        title: '📚 Class Starting Soon!',
        body: `${displayName} with ${teacherName} starts in ${minutesUntil} minutes at ${formattedTime}`,
      };

      const data = {
        type: 'class_reminder',
        action: 'reminder',
        shiftId,
        minutesUntil: minutesUntil.toString(),
      };

      const result = await sendFCMNotificationToStudent(studentId, notification, data);
      
      if (result.success) {
        successCount++;
      } else {
        failCount++;
      }
    } catch (error) {
      console.error(`Error sending to student ${studentId}:`, error);
      failCount++;
    }
  }

  console.log(`✅ Student reminders sent: ${successCount}/${studentIds.length}, Failed: ${failCount}`);
  
  return {
    success: successCount > 0,
    sent: successCount,
    failed: failCount,
    total: studentIds.length,
  };
};

module.exports = {
  sendFCMNotificationToTeacher,
  sendFCMNotificationToStudent,
  sendClassRemindersToStudents,
  formatDateInTimezone,
  getUserTimezone,
};

