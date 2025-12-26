/**
 * LiveKit Test Handler
 * 
 * Simple test endpoint to verify LiveKit connection works.
 * For development/testing only.
 */

const { onRequest, HttpsError } = require('firebase-functions/v2/https');
const { getLiveKitConfig, isLiveKitConfigured } = require('../services/livekit/config');
const { generateAccessToken } = require('../services/livekit/token');

/**
 * HTTP endpoint to test LiveKit configuration and generate a test token.
 * 
 * Usage: GET /testLiveKit?name=TestUser
 * 
 * Returns a token that can be used to join a test room.
 */
const testLiveKit = onRequest({ 
  cors: true,
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (req, res) => {
  try {
    // Check if LiveKit is configured
    if (!isLiveKitConfigured()) {
      return res.status(500).json({
        success: false,
        error: 'LiveKit not configured',
        message: 'LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET must be set',
      });
    }

    const config = getLiveKitConfig();
    const displayName = req.query.name || 'TestUser';
    const roomName = 'test-room-' + Date.now();
    const identity = 'test-user-' + Math.random().toString(36).substring(7);

    // Generate a test token with full permissions
    const token = await generateAccessToken(roomName, {
      identity: identity,
      name: displayName,
      ttlSeconds: 600, // 10 minutes
      videoGrant: {
        canPublish: true,
        canPublishData: true,
        canSubscribe: true,
      },
    });

    console.log('[TestLiveKit] Generated test token for room:', roomName, 'identity:', identity);

    // Return success with connection details
    res.status(200).json({
      success: true,
      message: 'LiveKit is configured correctly!',
      livekitUrl: config.url,
      token: token,
      roomName: roomName,
      identity: identity,
      displayName: displayName,
      expiresInSeconds: 600,
      testPageUrl: `https://meet.livekit.io/custom?liveKitUrl=${encodeURIComponent(config.url)}&token=${encodeURIComponent(token)}`,
    });
  } catch (error) {
    console.error('[TestLiveKit] Error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

module.exports = {
  testLiveKit,
};

