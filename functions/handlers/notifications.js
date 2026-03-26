const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {createTransporter} = require('../services/email/transporter');

const logTokenDetails = (tokens) => {
  tokens.forEach((tokenData, idx) => {
    console.log(`  Token ${idx}:`);
    console.log(`    Platform: ${tokenData.platform || 'unknown'}`);
    console.log(`    Token: ${tokenData.token ? `${tokenData.token.substring(0, 30)}...` : 'null'}`);
    console.log(`    Last Updated: ${tokenData.lastUpdated || 'unknown'}`);
  });
};

const sendAdminNotification = async (data) => {
  console.log('--- ADMIN NOTIFICATION SENDER ---');

  try {
    const requestData = data.data || data;

    const {
      recipientType,
      recipientRole,
      recipientIds,
      notificationTitle,
      notificationBody,
      notificationData,
      sendEmail,
      adminId,
    } = requestData;

    console.log('Notification request:', {
      recipientType,
      recipientRole,
      recipientIds: recipientIds?.length || 0,
      title: notificationTitle,
      sendEmail,
      adminId,
    });

    if (!notificationTitle || !notificationBody) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Notification title and body are required'
      );
    }

    if (!recipientType) {
      throw new functions.https.HttpsError('invalid-argument', 'Recipient type is required');
    }

    if (adminId) {
      const adminDoc = await admin.firestore().collection('users').doc(adminId).get();

      if (!adminDoc.exists) {
        throw new functions.https.HttpsError('permission-denied', 'Admin user not found');
      }

      const adminData = adminDoc.data();
      const isAdmin = adminData.user_type === 'admin' || adminData.is_admin_teacher === true;

      if (!isAdmin) {
        throw new functions.https.HttpsError('permission-denied', 'Only administrators can send notifications');
      }

      console.log(`Admin ${adminData['e-mail']} (${adminId}) is sending notifications`);
    }

    let targetUserIds = [];

    if (recipientType === 'individual' || recipientType === 'selected') {
      if (!recipientIds || !Array.isArray(recipientIds) || recipientIds.length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Recipient IDs are required for individual/selected notifications'
        );
      }
      targetUserIds = recipientIds;
    } else if (recipientType === 'role') {
      if (!recipientRole) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Recipient role is required when sending to a role'
        );
      }

      const usersSnapshot = await admin
        .firestore()
        .collection('users')
        .where('user_type', '==', recipientRole)
        .where('is_active', '==', true)
        .get();

      targetUserIds = usersSnapshot.docs.map((doc) => doc.id);
      console.log(`Found ${targetUserIds.length} active ${recipientRole}s`);
    }

    if (targetUserIds.length === 0) {
      return {
        success: false,
        message: 'No recipients found',
        totalRecipients: 0,
      };
    }

    const notification = {
      title: notificationTitle,
      body: notificationBody,
    };

    const messageData = {
      type: 'admin_notification',
      timestamp: new Date().toISOString(),
      ...(notificationData || {}),
    };

    const results = {
      totalRecipients: targetUserIds.length,
      fcmSuccess: 0,
      fcmFailed: 0,
      emailsSent: 0,
      emailsFailed: 0,
      details: [],
    };

    for (const userId of targetUserIds) {
      const recipientResult = {
        userId,
        fcmSent: false,
        emailSent: false,
        errors: [],
      };

      try {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();

        if (!userDoc.exists) {
          recipientResult.errors.push('User not found');
          results.details.push(recipientResult);
          continue;
        }

        const userData = userDoc.data();
        const userEmail = userData['e-mail'] || userData.email;
        const userName = `${userData.first_name || ''} ${userData.last_name || ''}`.trim();

        console.log(`\n=== Processing user: ${userName} (${userId}) ===`);
        console.log(`Email: ${userEmail}`);

        const fcmTokens = userData.fcmTokens || [];
        console.log(`FCM Tokens found: ${fcmTokens.length}`);
        if (fcmTokens.length > 0) {
          logTokenDetails(fcmTokens);

          const tokens = fcmTokens.map((t) => t.token).filter((t) => t);
          console.log(`Valid tokens extracted: ${tokens.length}`);

          if (tokens.length > 0) {
            try {
              console.log(`\nAttempting to send FCM message to ${tokens.length} token(s)...`);
              const fcmMessage = {
                notification,
                data: messageData,
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

              const response = await admin.messaging().sendEachForMulticast(fcmMessage);

              console.log(`\n📱 FCM Send Result for ${userName}:`);
              console.log(`  Success: ${response.successCount}/${tokens.length}`);
              console.log(`  Failed: ${response.failureCount}/${tokens.length}`);

              response.responses.forEach((resp, idx) => {
                if (resp.success) {
                  console.log(`  ✅ Token ${idx}: SUCCESS - Message ID: ${resp.messageId}`);
                } else {
                  console.log(
                    `  ❌ Token ${idx}: FAILED - Error: ${resp.error?.code} - ${resp.error?.message}`
                  );
                }
              });

              if (response.successCount > 0) {
                recipientResult.fcmSent = true;
                results.fcmSuccess += 1;
              } else {
                results.fcmFailed += 1;
                recipientResult.errors.push('FCM send failed');
              }

              console.log(`FCM sent to ${userName}: ${response.successCount}/${tokens.length} success`);
            } catch (fcmError) {
              console.error(`FCM error for ${userId}:`, fcmError);
              recipientResult.errors.push(`FCM error: ${fcmError.message}`);
              results.fcmFailed += 1;
            }
          }
        } else {
          recipientResult.errors.push('No FCM tokens');
        }

        if (sendEmail && userEmail) {
          try {
            const transporter = createTransporter();

            const mailOptions = {
              from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
              to: userEmail,
              subject: `📢 ${notificationTitle}`,
              html: `
                <!DOCTYPE html>
                <html>
                <head>
                  <meta charset="UTF-8" />
                  <title>${notificationTitle}</title>
                  <style>
                    body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
                    .container { max-width: 600px; margin: 0 auto; background-color: white; }
                    .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 30px 20px; text-align: center; }
                    .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
                    .content { padding: 30px 20px; }
                    .notification-box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
                    .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
                  </style>
                </head>
                <body>
                  <div class="container">
                    <div class="header">
                      <h1>📢 Important Notification</h1>
                      <p>From Alluwal Education Hub</p>
                    </div>
                    
                    <div class="content">
                      <p>Dear ${userName || 'User'},</p>
                      
                      <div class="notification-box">
                        <h2 style="margin-top: 0; color: #0386FF;">${notificationTitle}</h2>
                        <p style="margin: 0; white-space: pre-wrap;">${notificationBody}</p>
                      </div>
                      
                      <p>This notification was sent by the Alluwal Academy administration. If you have any questions, please contact us.</p>
                      
                      <p>Best regards,<br>
                      Alluwal Academy Team</p>
                    </div>
                    
                    <div class="footer">
                      <p>© ${new Date().getFullYear()} Alluwal Education Hub. All rights reserved.</p>
                      <p>This is an automated notification. Please do not reply to this email.</p>
                    </div>
                  </div>
                </body>
                </html>
              `,
            };

            await transporter.sendMail(mailOptions);
            recipientResult.emailSent = true;
            results.emailsSent += 1;
            console.log(`Email sent to ${userName} (${userEmail})`);
          } catch (emailError) {
            console.error(`Email error for ${userId}:`, emailError);
            recipientResult.errors.push(`Email error: ${emailError.message}`);
            results.emailsFailed += 1;
          }
        }
      } catch (error) {
        console.error(`Error processing recipient ${userId}:`, error);
        recipientResult.errors.push(error.message);
      }

      results.details.push(recipientResult);
    }

    try {
      await admin.firestore().collection('notification_history').add({
        sentBy: adminId || 'system',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        recipientType,
        recipientRole,
        recipientIds: targetUserIds,
        title: notificationTitle,
        body: notificationBody,
        additionalData: notificationData || {},
        emailRequested: sendEmail || false,
        results: {
          totalRecipients: results.totalRecipients,
          fcmSuccess: results.fcmSuccess,
          fcmFailed: results.fcmFailed,
          emailsSent: results.emailsSent,
          emailsFailed: results.emailsFailed,
        },
      });
    } catch (error) {
      console.error('Error saving notification history:', error);
    }

    console.log('Notification sending completed:', {
      totalRecipients: results.totalRecipients,
      fcmSuccess: results.fcmSuccess,
      fcmFailed: results.fcmFailed,
      emailsSent: results.emailsSent,
      emailsFailed: results.emailsFailed,
    });

    return {
      success: true,
      message: `Notifications sent to ${results.totalRecipients} recipients`,
      results,
    };
  } catch (error) {
    console.error('Error in sendAdminNotification:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send notifications: ${error.message}`
    );
  }
};

/**
 * Send FCM to a single teacher when an audit becomes visible (coach submitted, etc.).
 * Callable; caller must be authenticated (admin / coach with elevated access).
 */
const sendAuditNotification = async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be signed in to send audit notifications'
    );
  }

  const requestData = data.data || data;
  const {teacherId, auditId, yearMonth, status} = requestData;

  if (!teacherId || !auditId || !yearMonth) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'teacherId, auditId, and yearMonth are required'
    );
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Caller not found');
  }
  const callerData = callerDoc.data();
  const callerType = String(callerData.user_type || '').toLowerCase();
  const isAdmin =
    callerType === 'admin' ||
    callerType === 'ceo' ||
    callerType === 'founder' ||
    callerData.is_admin_teacher === true;

  const auditSnap = await admin.firestore().collection('teacher_audits').doc(auditId).get();
  if (!auditSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Audit not found');
  }
  const auditData = auditSnap.data();
  if (auditData.userId !== teacherId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'teacherId does not match this audit'
    );
  }

  const coachEval = auditData.coachEvaluation || {};
  const auditCoachId = coachEval.coachId || '';
  const isAssignedCoach =
    callerType === 'teacher' && auditCoachId && auditCoachId === context.auth.uid;

  if (!isAdmin && !isAssignedCoach) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only authorized reviewers or the assigned coach can send audit notifications'
    );
  }

  const userDoc = await admin.firestore().collection('users').doc(teacherId).get();
  if (!userDoc.exists) {
    return {success: false, message: 'Teacher not found'};
  }

  const userData = userDoc.data();
  const fcmTokensArray = userData.fcmTokens || [];
  const tokens = [];

  if (Array.isArray(fcmTokensArray) && fcmTokensArray.length > 0) {
    fcmTokensArray.forEach((tokenObj) => {
      if (tokenObj && tokenObj.token) {
        tokens.push(tokenObj.token);
      }
    });
  }

  // Fall back to legacy single token field.
  if (tokens.length === 0 && userData.fcmToken) {
    tokens.push(userData.fcmToken);
    console.log('[AUDIT] Using legacy fcmToken for teacher', teacherId);
  }

  if (tokens.length === 0) {
    return {success: false, message: 'No FCM tokens for teacher', teacherId};
  }

  const title = 'Monthly audit update';
  const body = `Your audit for ${yearMonth} is ready to review.`;

  const messageData = {
    type: 'audit_notification',
    auditId: String(auditId),
    yearMonth: String(yearMonth),
    status: String(status || ''),
    timestamp: new Date().toISOString(),
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  };

  try {
    const fcmMessage = {
      notification: {title, body},
      data: messageData,
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

    const response = await admin.messaging().sendEachForMulticast(fcmMessage);

    // Clean up invalid tokens so future sends can recover.
    const tokensToRemove = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const errorCode = resp.error?.code;
        if (
          errorCode === 'messaging/invalid-registration-token' ||
          errorCode === 'messaging/registration-token-not-registered'
        ) {
          tokensToRemove.push(tokens[idx]);
        }
      }
    });

    if (tokensToRemove.length > 0) {
      try {
        const currentTokens = userData.fcmTokens || [];
        const updatedTokens = currentTokens.filter(
          (t) => t && !tokensToRemove.includes(t.token)
        );
        const updatePayload = {fcmTokens: updatedTokens};
        if (userData.fcmToken && tokensToRemove.includes(userData.fcmToken)) {
          updatePayload.fcmToken = admin.firestore.FieldValue.delete();
        }
        await admin.firestore().collection('users').doc(teacherId).update(updatePayload);
        console.log(
          `[AUDIT] Removed ${tokensToRemove.length} invalid token(s) for ${teacherId}`
        );
      } catch (cleanupError) {
        console.error('[AUDIT] Failed to remove invalid tokens:', cleanupError);
      }
    }

    return {
      success: response.successCount > 0,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (e) {
    console.error('sendAuditNotification FCM error:', e);
    throw new functions.https.HttpsError('internal', e.message || 'FCM send failed');
  }
};

module.exports = {
  sendAdminNotification,
  sendAuditNotification,
};

