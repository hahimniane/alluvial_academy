/**
 * LiveKit Cloud Function Handlers
 * 
 * Provides callable functions for LiveKit video integration.
 */

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getLiveKitConfig, isLiveKitConfigured } = require('../services/livekit/config');
const { generateTokenForRole } = require('../services/livekit/token');

/**
 * Helper: Get user display name from Firestore
 */
const getUserDisplayName = async (uid) => {
  if (!uid) return 'Participant';
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return 'Participant';
    const data = userDoc.data();
    const firstName = data.first_name || data.firstName || '';
    const lastName = data.last_name || data.lastName || '';
    const fullName = [firstName, lastName].filter(Boolean).join(' ');
    return fullName || data['e-mail'] || data.email || 'Participant';
  } catch (_) {
    return 'Participant';
  }
};

/**
 * Helper: Get user email from Firestore
 */
const getUserEmail = async (uid) => {
  if (!uid) return null;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return null;
    const data = userDoc.data();
    return data['e-mail'] || data.email || data.Email || data.mail || null;
  } catch (_) {
    return null;
  }
};

/**
 * Helper: Check if user is admin
 */
const isUserAdmin = async (uid) => {
  if (!uid) return false;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    const data = userDoc.data();
    return (
      data.role === 'admin' ||
      data.user_type === 'admin' ||
      data.userType === 'admin' ||
      data.is_admin === true ||
      data.isAdmin === true ||
      data.is_admin_teacher === true
    );
  } catch (_) {
    return false;
  }
};

/**
 * Callable function: Get LiveKit join token for a shift
 * 
 * @param {Object} request - Firebase callable request
 * @param {Object} request.data - Request data
 * @param {string} request.data.shiftId - The shift ID to join
 * @returns {Object} LiveKit connection details
 */
const getLiveKitJoinToken = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  // Require authentication
  if (!uid) {
    console.log('[LiveKit] Unauthenticated request');
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  // Validate shiftId
  if (!shiftId || typeof shiftId !== 'string') {
    console.log('[LiveKit] Invalid shiftId from uid:', uid);
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }

  // Check LiveKit configuration
  if (!isLiveKitConfigured()) {
    console.error('[LiveKit] LiveKit not configured');
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }

  // Get shift document
  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
  if (!shiftDoc.exists) {
    console.log('[LiveKit] Shift not found:', shiftId, 'uid:', uid);
    throw new HttpsError('not-found', 'Shift not found');
  }

  const shiftData = shiftDoc.data() || {};

  // Check video provider
  const videoProvider = shiftData.video_provider || 'zoom';
  if (videoProvider !== 'livekit') {
    console.log('[LiveKit] Shift uses different video provider:', videoProvider, 'shiftId:', shiftId);
    throw new HttpsError('failed-precondition', 'This shift does not use LiveKit video');
  }

  // Authorization check
  const teacherId = shiftData.teacher_id;
  const studentIds = shiftData.student_ids || [];
  const isTeacher = uid === teacherId;
  const isStudent = studentIds.includes(uid);
  const isAdmin = await isUserAdmin(uid);

  if (!isTeacher && !isStudent && !isAdmin) {
    console.log('[LiveKit] Unauthorized access attempt. uid:', uid, 'shiftId:', shiftId);
    throw new HttpsError('permission-denied', 'You are not allowed to join this class');
  }

  // Determine user role
  let userRole;
  if (isAdmin) {
    userRole = 'admin';
  } else if (isTeacher) {
    userRole = 'teacher';
  } else {
    userRole = 'student';
  }

  // Parse shift times for time window check
  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  const now = new Date();
  const allowedStartMs = shiftStart.getTime() - 10 * 60 * 1000; // 10 min before
  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;     // 10 min after

  // Time window check (same as Zoom)
  if (now.getTime() < allowedStartMs) {
    const minutesUntil = Math.ceil((allowedStartMs - now.getTime()) / 60000);
    console.log('[LiveKit] Too early. uid:', uid, 'shiftId:', shiftId, 'minutesUntil:', minutesUntil);
    throw new HttpsError(
      'failed-precondition',
      `You can join 10 minutes before the class starts. Please wait ${minutesUntil} minute(s).`
    );
  }

  if (now.getTime() > allowedEndMs) {
    console.log('[LiveKit] Too late. uid:', uid, 'shiftId:', shiftId);
    throw new HttpsError('failed-precondition', 'The class window has ended');
  }

  // Generate room name
  const roomName = shiftData.livekit_room_name || `shift_${shiftId}`;

  // Get user details
  const displayName = await getUserDisplayName(uid);
  const userEmail = await getUserEmail(uid);

  // Token TTL: from now until 15 minutes after shift end
  const ttlSeconds = Math.max(600, Math.floor((allowedEndMs + 5 * 60 * 1000 - now.getTime()) / 1000));

  // Generate LiveKit token
  const livekitConfig = getLiveKitConfig();
  
  // Debug: Log config (without exposing secret)
  console.log('[LiveKit] Using config - URL:', livekitConfig.url);
  console.log('[LiveKit] Using config - API Key:', livekitConfig.apiKey);
  console.log('[LiveKit] Using config - API Secret length:', livekitConfig.apiSecret?.length || 0);
  
  const token = await generateTokenForRole(
    roomName,
    userRole,
    uid,
    displayName,
    {
      email: userEmail,
      shiftId: shiftId,
    },
    ttlSeconds
  );
  
  // Debug: Log token info
  console.log('[LiveKit] Generated token length:', token?.length || 0);
  if (token) {
    const tokenParts = token.split('.');
    if (tokenParts.length >= 2) {
      try {
        const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
        console.log('[LiveKit] Token payload - sub:', payload.sub);
        console.log('[LiveKit] Token payload - iss:', payload.iss);
        console.log('[LiveKit] Token payload - room:', payload.video?.room);
        console.log('[LiveKit] Token payload - exp:', new Date(payload.exp * 1000).toISOString());
      } catch (e) {
        console.warn('[LiveKit] Could not parse token payload:', e.message);
      }
    }
  }

  // Update last token issued timestamp (optional tracking)
  try {
    await admin.firestore().collection('teaching_shifts').doc(shiftId).update({
      livekit_last_token_issued_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (updateErr) {
    console.warn('[LiveKit] Failed to update token timestamp:', updateErr.message);
    // Non-blocking - continue even if update fails
  }

  console.log('[LiveKit] Token generated. uid:', uid, 'shiftId:', shiftId, 'role:', userRole, 'room:', roomName);

  return {
    success: true,
    livekitUrl: livekitConfig.url,
    token: token,
    roomName: roomName,
    userRole: userRole,
    displayName: displayName,
    expiresInSeconds: ttlSeconds,
    joinWindow: {
      allowedStartIso: new Date(allowedStartMs).toISOString(),
      allowedEndIso: new Date(allowedEndMs).toISOString(),
    },
  };
});

/**
 * Callable function: Check if LiveKit is available for a shift
 * 
 * @param {Object} request - Firebase callable request
 * @param {Object} request.data - Request data
 * @param {string} request.data.shiftId - The shift ID to check
 * @returns {Object} Availability status
 */
const checkLiveKitAvailability = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  // Check if LiveKit is configured globally
  const configured = isLiveKitConfigured();

  if (!configured) {
    return {
      available: false,
      reason: 'LiveKit is not configured on this server',
    };
  }

  if (!shiftId) {
    return {
      available: configured,
      reason: configured ? 'LiveKit is configured' : 'LiveKit is not configured',
    };
  }

  // Check shift-specific settings
  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
  if (!shiftDoc.exists) {
    return {
      available: false,
      reason: 'Shift not found',
    };
  }

  const shiftData = shiftDoc.data() || {};
  const videoProvider = shiftData.video_provider || 'zoom';

  return {
    available: videoProvider === 'livekit',
    videoProvider: videoProvider,
    roomName: shiftData.livekit_room_name || `shift_${shiftId}`,
    reason: videoProvider === 'livekit'
      ? 'This class uses LiveKit video'
      : 'This class uses Zoom video',
  };
});

module.exports = {
  getLiveKitJoinToken,
  checkLiveKitAvailability,
};

