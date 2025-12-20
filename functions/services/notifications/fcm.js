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

module.exports = {
  sendFCMNotificationToTeacher,
};

