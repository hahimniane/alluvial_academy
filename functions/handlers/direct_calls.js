/**
 * Direct Call Handler
 * 
 * Handles 1-on-1 audio/video calls between users outside of scheduled classes.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { generateAccessToken } = require('../services/livekit/token');
const { getLiveKitConfig } = require('../services/livekit/config');

/**
 * Create a direct call room and return tokens for the caller
 * 
 * This callable function:
 * 1. Creates a unique room name for the call
 * 2. Generates a LiveKit token for the caller
 * 3. Sends a push notification to the recipient
 */
const createDirectCall = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  // Ensure user is authenticated
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'You must be logged in to make calls'
    );
  }

  const callerId = request.auth.uid;
  const { recipientId, isAudioOnly } = request.data;

  if (!recipientId) {
    throw new HttpsError(
      'invalid-argument',
      'Recipient ID is required'
    );
  }

  console.log(`[DIRECT CALL] ${callerId} calling ${recipientId}, audio-only: ${isAudioOnly}`);

  try {
    // Get caller's user data
    const callerDoc = await admin.firestore()
      .collection('users')
      .doc(callerId)
      .get();

    if (!callerDoc.exists) {
      throw new HttpsError('not-found', 'Caller not found');
    }

    const callerData = callerDoc.data();
    const callerName = `${callerData.first_name || ''} ${callerData.last_name || ''}`.trim() || 'Unknown';

    // Get recipient's user data
    const recipientDoc = await admin.firestore()
      .collection('users')
      .doc(recipientId)
      .get();

    if (!recipientDoc.exists) {
      throw new HttpsError('not-found', 'Recipient not found');
    }

    const recipientData = recipientDoc.data();
    const recipientName = `${recipientData.first_name || ''} ${recipientData.last_name || ''}`.trim() || 'Unknown';

    // Create a unique room name for this call
    const roomName = `call_${[callerId, recipientId].sort().join('_')}_${Date.now()}`;

    // Get LiveKit config
    const { url: livekitUrl } = getLiveKitConfig();

    // Generate token for the caller
    const token = await generateAccessToken(roomName, {
      identity: callerId,
      name: callerName,
      metadata: {
        role: 'caller',
        callType: isAudioOnly ? 'audio' : 'video',
      },
      ttlSeconds: 3600, // 1 hour for calls
    });

    // Store the call in Firestore for tracking
    const callRef = await admin.firestore()
      .collection('direct_calls')
      .add({
        room_name: roomName,
        caller_id: callerId,
        caller_name: callerName,
        recipient_id: recipientId,
        recipient_name: recipientName,
        is_audio_only: isAudioOnly || false,
        status: 'ringing',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Send push notification to recipient
    const recipientToken = recipientData.fcmToken;
    if (recipientToken) {
      try {
        await admin.messaging().send({
          token: recipientToken,
          notification: {
            title: isAudioOnly ? 'Incoming Audio Call' : 'Incoming Video Call',
            body: `${callerName} is calling you`,
          },
          data: {
            type: 'incoming_call',
            callId: callRef.id,
            roomName,
            callerId,
            callerName,
            isAudioOnly: String(isAudioOnly || false),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            notification: {
              channelId: 'calls',
              priority: 'high',
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                badge: 1,
                sound: 'default',
                category: 'incoming_call',
              },
            },
          },
        });
        console.log(`[DIRECT CALL] Notification sent to ${recipientId}`);
      } catch (notifError) {
        console.error('[DIRECT CALL] Failed to send notification:', notifError);
        // Don't fail the call if notification fails
      }
    }

    console.log(`[DIRECT CALL] Call room created: ${roomName}`);

    return {
      success: true,
      callId: callRef.id,
      roomName,
      livekitUrl,
      token,
      displayName: callerName,
      recipientName,
    };
  } catch (error) {
    console.error('[DIRECT CALL] Error creating call:', error);
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError(
      'internal',
      'Failed to create call'
    );
  }
});

/**
 * Join an existing direct call (for the recipient)
 */
const joinDirectCall = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'You must be logged in to join calls'
    );
  }

  const userId = request.auth.uid;
  const { callId } = request.data;

  if (!callId) {
    throw new HttpsError(
      'invalid-argument',
      'Call ID is required'
    );
  }

  try {
    const callDoc = await admin.firestore()
      .collection('direct_calls')
      .doc(callId)
      .get();

    if (!callDoc.exists) {
      throw new HttpsError('not-found', 'Call not found');
    }

    const callData = callDoc.data();

    // Verify user is the recipient
    if (callData.recipient_id !== userId) {
      throw new HttpsError(
        'permission-denied',
        'You are not the recipient of this call'
      );
    }

    // Check call is still ringing
    if (callData.status !== 'ringing') {
      throw new HttpsError(
        'failed-precondition',
        `Call is ${callData.status}`
      );
    }

    // Get user data for display name
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    const userData = userDoc.data() || {};
    const displayName = `${userData.first_name || ''} ${userData.last_name || ''}`.trim() || 'Unknown';

    // Get LiveKit config
    const { url: livekitUrl } = getLiveKitConfig();

    // Generate token for the recipient
    const token = await generateAccessToken(callData.room_name, {
      identity: userId,
      name: displayName,
      metadata: {
        role: 'recipient',
        callType: callData.is_audio_only ? 'audio' : 'video',
      },
      ttlSeconds: 3600,
    });

    // Update call status
    await admin.firestore()
      .collection('direct_calls')
      .doc(callId)
      .update({
        status: 'connected',
        connected_at: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      roomName: callData.room_name,
      livekitUrl,
      token,
      displayName,
      callerName: callData.caller_name,
      isAudioOnly: callData.is_audio_only,
    };
  } catch (error) {
    console.error('[DIRECT CALL] Error joining call:', error);
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Failed to join call');
  }
});

/**
 * End a direct call
 */
const endDirectCall = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'You must be logged in'
    );
  }

  const userId = request.auth.uid;
  const { callId, reason } = request.data;

  if (!callId) {
    throw new HttpsError(
      'invalid-argument',
      'Call ID is required'
    );
  }

  try {
    const callDoc = await admin.firestore()
      .collection('direct_calls')
      .doc(callId)
      .get();

    if (!callDoc.exists) {
      return { success: true }; // Already ended
    }

    const callData = callDoc.data();

    // Verify user is a participant
    if (callData.caller_id !== userId && callData.recipient_id !== userId) {
      throw new HttpsError(
        'permission-denied',
        'You are not a participant in this call'
      );
    }

    // Update call status
    await admin.firestore()
      .collection('direct_calls')
      .doc(callId)
      .update({
        status: reason === 'declined' ? 'declined' : 'ended',
        ended_at: admin.firestore.FieldValue.serverTimestamp(),
        ended_by: userId,
        end_reason: reason || 'normal',
      });

    return { success: true };
  } catch (error) {
    console.error('[DIRECT CALL] Error ending call:', error);
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Failed to end call');
  }
});

module.exports = {
  createDirectCall,
  joinDirectCall,
  endDirectCall,
};
