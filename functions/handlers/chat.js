const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');

/**
 * Trigger when a new chat message is created
 * Sends push notification to all recipients in the chat
 */
const onChatMessageCreated = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log('[CHAT] No data in message snapshot');
      return null;
    }

    const messageData = snapshot.data();
    const {chatId} = event.params;
    const senderId = messageData.sender_id;
    const senderName = messageData.sender_name || 'Someone';
    const messageContent = messageData.content || '';
    
    // Get sender's profile picture
    let senderProfilePicture = '';
    try {
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();
      if (senderDoc.exists) {
        const senderData = senderDoc.data();
        // Check both field names (profile_picture_url is the newer format)
        senderProfilePicture = senderData.profile_picture_url || senderData.profile_picture || '';
      }
    } catch (err) {
      console.log('[CHAT] Could not fetch sender profile:', err.message);
    }

    console.log(`[CHAT] New message in chat ${chatId} from ${senderName}`);

    try {
      // Get the chat document to find participants
      const chatDoc = await admin.firestore()
        .collection('chats')
        .doc(chatId)
        .get();

      if (!chatDoc.exists) {
        console.log(`[CHAT] Chat ${chatId} not found`);
        return null;
      }

      const chatData = chatDoc.data();
      const participants = chatData.participants || [];
      const chatType = chatData.chat_type || 'individual';
      const groupName = chatData.group_name;

      // Get recipients (everyone except the sender)
      const recipientIds = participants.filter(id => id !== senderId);

      if (recipientIds.length === 0) {
        console.log('[CHAT] No recipients to notify');
        return null;
      }

      // Fetch recipient user data and FCM tokens
      const recipientDocs = await admin.firestore()
        .collection('users')
        .where(admin.firestore.FieldPath.documentId(), 'in', recipientIds.slice(0, 10)) // Firestore limit
        .get();

      const tokensToSend = [];
      const recipientData = {};

      recipientDocs.forEach(doc => {
        const userData = doc.data();
        recipientData[doc.id] = userData;
        
        // Check notification preferences
        const notificationPrefs = userData.notificationPreferences || {};
        const chatEnabled = notificationPrefs.chatEnabled !== false; // Default to true
        
        if (!chatEnabled) {
          console.log(`[CHAT] User ${doc.id} has chat notifications disabled`);
          return;
        }

        // Get FCM tokens - support both single token (legacy) and token array (new format)
        const fcmTokensArray = userData.fcmTokens || [];
        const singleToken = userData.fcmToken;
        
        // Add tokens from the array format
        if (Array.isArray(fcmTokensArray) && fcmTokensArray.length > 0) {
          fcmTokensArray.forEach(tokenObj => {
            if (tokenObj && tokenObj.token) {
              tokensToSend.push({
                token: tokenObj.token,
                userId: doc.id,
                platform: tokenObj.platform || 'unknown',
              });
            }
          });
        } 
        // Fall back to single token if no array
        else if (singleToken) {
          tokensToSend.push({
            token: singleToken,
            userId: doc.id,
            platform: 'legacy',
          });
        }
      });

      if (tokensToSend.length === 0) {
        console.log('[CHAT] No valid FCM tokens to send notifications');
        return null;
      }

      // Prepare notification
      const title = chatType === 'group' 
        ? `${groupName}: ${senderName}`
        : senderName;
      
      // Truncate message for preview
      const maxPreviewLength = 100;
      const messagePreview = messageContent.length > maxPreviewLength
        ? messageContent.substring(0, maxPreviewLength) + '...'
        : messageContent;

      // Send notifications
      const sendPromises = tokensToSend.map(async ({token, userId, platform}) => {
        const message = {
          token,
          notification: {
            title,
            body: messagePreview,
          },
          data: {
            type: 'chat_message',
            chatId,
            senderId,
            senderName,
            senderProfilePicture: senderProfilePicture || '',
            messagePreview: messagePreview,
            chatType,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            notification: {
              channelId: 'chat_messages',
              priority: 'high',
              defaultSound: true,
            },
          },
          apns: {
            payload: {
              aps: {
                badge: 1,
                sound: 'default',
                category: 'chat_message',
              },
            },
          },
        };

        try {
          await admin.messaging().send(message);
          console.log(`[CHAT] Notification sent to user ${userId} (${platform})`);
          return {success: true, userId, platform};
        } catch (error) {
          console.error(`[CHAT] Failed to send to user ${userId} (${platform}):`, error.message);
          
          // If token is invalid, remove it from user document
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            try {
              // Get current tokens and remove the invalid one
              const userDoc = await admin.firestore()
                .collection('users')
                .doc(userId)
                .get();
              
              if (userDoc.exists) {
                const userData = userDoc.data();
                const currentTokens = userData.fcmTokens || [];
                const updatedTokens = currentTokens.filter(t => t && t.token !== token);
                
                await admin.firestore()
                  .collection('users')
                  .doc(userId)
                  .update({
                    fcmTokens: updatedTokens,
                    fcmToken: admin.firestore.FieldValue.delete(), // Also remove legacy field
                  });
                console.log(`[CHAT] Removed invalid token for user ${userId}`);
              }
            } catch (updateError) {
              console.error(`[CHAT] Failed to remove invalid token:`, updateError);
            }
          }
          return {success: false, userId, platform, error: error.message};
        }
      });

      const results = await Promise.all(sendPromises);
      const successCount = results.filter(r => r.success).length;
      console.log(`[CHAT] Sent ${successCount}/${tokensToSend.length} notifications`);

      return {success: true, notificationsSent: successCount};
    } catch (error) {
      console.error('[CHAT] Error processing message notification:', error);
      return {success: false, error: error.message};
    }
  }
);

/**
 * Update chat notification preferences for a user
 */
const updateChatNotificationPreference = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const {chatEnabled} = data;
  const userId = context.auth.uid;

  if (typeof chatEnabled !== 'boolean') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'chatEnabled must be a boolean'
    );
  }

  try {
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .set({
        notificationPreferences: {
          chatEnabled,
          chatUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }
      }, {merge: true});

    console.log(`[CHAT] Updated chat notification preference for ${userId}: ${chatEnabled}`);
    return {success: true, chatEnabled};
  } catch (error) {
    console.error('[CHAT] Error updating preference:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update preference');
  }
});

/**
 * Sync chat permissions when a teaching shift is updated
 * This ensures chat eligibility stays in sync with teaching relationships
 */
const onShiftStatusChange = onDocumentUpdated(
  'teaching_shifts/{shiftId}',
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const {shiftId} = event.params;

    // Check if status changed or students/teacher changed
    const statusChanged = beforeData.status !== afterData.status;
    const teacherChanged = beforeData.teacher_id !== afterData.teacher_id;
    const studentsChanged = JSON.stringify(beforeData.student_ids?.sort()) !== 
                           JSON.stringify(afterData.student_ids?.sort());

    if (!statusChanged && !teacherChanged && !studentsChanged) {
      return null;
    }

    console.log(`[CHAT PERMISSIONS] Shift ${shiftId} changed:`, {
      statusChanged,
      teacherChanged,
      studentsChanged,
      newStatus: afterData.status,
    });

    const teacherId = afterData.teacher_id;
    const studentIds = afterData.student_ids || [];

    if (!teacherId || studentIds.length === 0) {
      return null;
    }

    try {
      // If shift is cancelled, mark chat permissions as inactive after grace period
      if (afterData.status === 'cancelled') {
        await updateChatPermissionsForShift(teacherId, studentIds, shiftId, false);
        console.log(`[CHAT PERMISSIONS] Marked permissions inactive for cancelled shift ${shiftId}`);
      } 
      // If shift is active/scheduled, ensure permissions exist
      else if (afterData.status === 'scheduled' || afterData.status === 'in_progress') {
        await updateChatPermissionsForShift(teacherId, studentIds, shiftId, true);
        console.log(`[CHAT PERMISSIONS] Updated permissions for active shift ${shiftId}`);
      }

      return {success: true};
    } catch (error) {
      console.error('[CHAT PERMISSIONS] Error syncing permissions:', error);
      return {success: false, error: error.message};
    }
  }
);

/**
 * Helper function to update chat permissions for a shift
 */
async function updateChatPermissionsForShift(teacherId, studentIds, shiftId, isActive) {
  const batch = admin.firestore().batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const studentId of studentIds) {
    // Create a deterministic chat permission ID
    const permissionId = [teacherId, studentId].sort().join('_') + '_teacher_student';
    const permissionRef = admin.firestore()
      .collection('chat_permissions')
      .doc(permissionId);

    const permissionData = {
      participants: [teacherId, studentId].sort(),
      permission_type: 'teacher_student',
      relationship_source: {
        type: 'shift',
        shift_id: shiftId,
        student_id: studentId,
      },
      is_active: isActive,
      updated_at: now,
    };

    // Use merge to preserve existing data while updating status
    batch.set(permissionRef, permissionData, {merge: true});

    // If becoming active, also set created_at if not exists
    if (isActive) {
      batch.set(permissionRef, {
        created_at: now,
      }, {merge: true});
    }

    // Also check if student has parents and create teacher-parent permissions
    const studentDoc = await admin.firestore()
      .collection('users')
      .doc(studentId)
      .get();

    if (studentDoc.exists) {
      const studentData = studentDoc.data();
      const guardianIds = studentData.guardian_ids || [];

      for (const parentId of guardianIds) {
        const parentPermissionId = [teacherId, parentId].sort().join('_') + '_teacher_parent';
        const parentPermissionRef = admin.firestore()
          .collection('chat_permissions')
          .doc(parentPermissionId);

        const parentPermissionData = {
          participants: [teacherId, parentId].sort(),
          permission_type: 'teacher_parent',
          relationship_source: {
            type: 'shift',
            shift_id: shiftId,
            student_id: studentId,
          },
          is_active: isActive,
          updated_at: now,
        };

        batch.set(parentPermissionRef, parentPermissionData, {merge: true});
      }
    }
  }

  await batch.commit();
}

/**
 * When a new teaching shift is created, create chat permissions
 */
const onShiftCreated = onDocumentCreated(
  'teaching_shifts/{shiftId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const shiftData = snapshot.data();
    const {shiftId} = event.params;
    const teacherId = shiftData.teacher_id;
    const studentIds = shiftData.student_ids || [];

    if (!teacherId || studentIds.length === 0) {
      return null;
    }

    console.log(`[CHAT PERMISSIONS] New shift ${shiftId} created with ${studentIds.length} students`);

    try {
      await updateChatPermissionsForShift(teacherId, studentIds, shiftId, true);
      console.log(`[CHAT PERMISSIONS] Created permissions for new shift ${shiftId}`);
      return {success: true};
    } catch (error) {
      console.error('[CHAT PERMISSIONS] Error creating permissions:', error);
      return {success: false, error: error.message};
    }
  }
);

module.exports = {
  onChatMessageCreated,
  updateChatNotificationPreference,
  onShiftStatusChange,
  onShiftCreated,
};
