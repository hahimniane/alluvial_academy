const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onCall} = require('firebase-functions/v2/https');

/**
 * Update user's timezone in their profile
 * This should be called from the client app during login or when timezone changes
 */
const updateUserTimezone = onCall(async (request) => {
  const data = request.data || {};
  const {timezone} = data;
  
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }
  
  if (!timezone) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Timezone is required'
    );
  }
  
  const userId = request.auth.uid;
  
  try {
    // Update the user's timezone in Firestore
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        timezone: timezone,
        timezone_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    console.log(`[TIMEZONE] Updated timezone for user ${userId}: ${timezone}`);
    
    return {
      success: true,
      timezone: timezone,
      message: `Timezone updated to ${timezone}`,
    };
  } catch (error) {
    console.error('[TIMEZONE] Error updating user timezone:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update timezone'
    );
  }
});

/**
 * Get user's timezone from their profile
 */
const getUserTimezone = onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }
  
  const userId = request.auth.uid;
  
  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'User not found'
      );
    }
    
    const userData = userDoc.data();
    const timezone = userData.timezone || null;
    
    return {
      success: true,
      timezone: timezone,
      hasTimezone: !!timezone,
    };
  } catch (error) {
    console.error('[TIMEZONE] Error getting user timezone:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get timezone'
    );
  }
});

module.exports = {
  updateUserTimezone,
  getUserTimezone,
};
