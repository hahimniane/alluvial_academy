const admin = require('firebase-admin');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { DateTime } = require('luxon');
const jwt = require('jsonwebtoken');
const { getZoomConfig, getMeetingSdkConfig } = require('../services/zoom/config');
const { getMeetingDetails } = require('../services/zoom/client');
const { verifyJoinToken, decryptString, signJoinToken, encryptString } = require('../services/zoom/crypto');

// ... (keep existing code until generateMeetingSdkJwt) ...

/**
 * Generate a Meeting SDK JWT for native in-app Zoom join
 * Uses HS256 algorithm as required by Zoom Meeting SDK
 * @param {string} sdkKey - Meeting SDK Client ID / Key
 * @param {string} sdkSecret - Meeting SDK Client Secret
 * @param {number} ttlSeconds - Token TTL (min 1800, max 172800)
 * @returns {string} JWT token
 */
const generateMeetingSdkJwt = (sdkKey, sdkSecret, ttlSeconds = 3600) => {
  // Clamp TTL to Zoom's requirements: min 30 minutes, max 48 hours
  const clampedTtl = Math.max(1800, Math.min(172800, ttlSeconds));

  const nowUnix = Math.floor(Date.now() / 1000);
  // Subtract 60s for clock drift/skew to prevent "token issued in future" errors
  const iat = nowUnix - 60;
  const exp = iat + clampedTtl; // Keep duration consistent relative to iat

  // Meeting SDK JWT payload (for native iOS/Android SDK auth)
  // Native SDKs require: appKey (not sdkKey), iat, exp, tokenExp
  const payload = {
    appKey: sdkKey,
    iat,
    exp,
    tokenExp: exp,
  };

  // Sign with HS256
  return jwt.sign(payload, sdkSecret, {
    algorithm: 'HS256',
    header: { typ: 'JWT' }
  });
};

const formatCountdownMessage = ({ shiftStart, shiftEnd, now, teacherTimezone }) => {
  const startMs = shiftStart.getTime();
  const endMs = shiftEnd.getTime();
  const nowMs = now.getTime();

  const allowedStartMs = startMs - 10 * 60 * 1000;
  const allowedEndMs = endMs + 10 * 60 * 1000;

  const zone = teacherTimezone || 'UTC';
  const startText = DateTime.fromJSDate(shiftStart, { zone }).toFormat("ccc, LLL d • h:mm a ZZZZ");
  const endText = DateTime.fromJSDate(shiftEnd, { zone }).toFormat("ccc, LLL d • h:mm a ZZZZ");

  if (nowMs < allowedStartMs) {
    const minutes = Math.ceil((allowedStartMs - nowMs) / 60000);
    return {
      title: 'Zoom link not active yet',
      body: `This link will activate about ${minutes} minute(s) before your shift starts.`,
      detail: `Shift time: ${startText} → ${endText}`,
    };
  }

  if (nowMs > allowedEndMs) {
    return {
      title: 'Zoom link expired',
      body: 'This link is only available until 10 minutes after your shift ends.',
      detail: `Shift time: ${startText} → ${endText}`,
    };
  }

  return {
    title: 'Please try again',
    body: 'Unable to join right now.',
    detail: `Shift time: ${startText} → ${endText}`,
  };
};

const joinZoomMeeting = onRequest(async (req, res) => {
  res.set('Cache-Control', 'no-store');

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  let zoomConfig;
  try {
    zoomConfig = getZoomConfig();
  } catch (e) {
    res.status(503).send('Zoom integration is not configured.');
    return;
  }

  const token = req.query?.token;
  if (!token || typeof token !== 'string') {
    res.status(400).send('Missing token');
    return;
  }

  let payload;
  try {
    payload = verifyJoinToken(token, zoomConfig.joinTokenSecret);
  } catch (_) {
    res.status(401).send('Invalid or expired token');
    return;
  }

  const shiftId = payload.shiftId;
  const teacherId = payload.teacherId;
  if (!shiftId || typeof shiftId !== 'string') {
    res.status(400).send('Invalid token payload');
    return;
  }

  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
  if (!shiftDoc.exists) {
    res.status(404).send('Shift not found');
    return;
  }

  const shiftData = shiftDoc.data() || {};
  if (teacherId && shiftData.teacher_id && teacherId !== shiftData.teacher_id) {
    res.status(403).send('Not authorized for this shift');
    return;
  }

  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate ? shiftData.shift_end.toDate() : new Date(shiftData.shift_end);

  const now = new Date();
  const allowedStartMs = shiftStart.getTime() - 10 * 60 * 1000;
  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;

  if (now.getTime() < allowedStartMs || now.getTime() > allowedEndMs) {
    const message = formatCountdownMessage({
      shiftStart,
      shiftEnd,
      now,
      teacherTimezone: shiftData.teacher_timezone,
    });
    res.status(403).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>${message.title}</title>
        <style>
          body { font-family: Arial, sans-serif; background: #f8fafc; margin: 0; padding: 24px; color: #111827; }
          .card { max-width: 640px; margin: 0 auto; background: white; border-radius: 12px; padding: 20px; box-shadow: 0 8px 24px rgba(0,0,0,0.06); }
          .title { font-size: 18px; font-weight: 700; margin: 0 0 8px 0; }
          .body { margin: 0 0 10px 0; }
          .detail { color: #6b7280; font-size: 14px; margin: 0; }
        </style>
      </head>
      <body>
        <div class="card">
          <p class="title">${message.title}</p>
          <p class="body">${message.body}</p>
          <p class="detail">${message.detail}</p>
        </div>
      </body>
      </html>
    `);
    return;
  }

  const encryptedJoinUrl = shiftData.zoom_encrypted_join_url;
  if (!encryptedJoinUrl) {
    res.status(404).send('Zoom meeting not available for this shift');
    return;
  }

  let joinUrl;
  try {
    joinUrl = decryptString(encryptedJoinUrl, zoomConfig.encryptionKeyB64);
  } catch (e) {
    console.error('[Zoom] Failed to decrypt join URL:', e);
    res.status(500).send('Unable to join meeting');
    return;
  }

  res.redirect(302, joinUrl);
});

/**
 * Callable function to get a Zoom join URL with token for a shift
 * This allows the Flutter app to get a valid join URL without exposing the token secret
 */
const getZoomJoinUrl = onCall(async (request) => {
  const shiftId = request.data?.shiftId;
  const teacherId = request.auth?.uid;

  if (!shiftId || typeof shiftId !== 'string') {
    throw new Error('Missing or invalid shiftId');
  }

  let zoomConfig;
  try {
    zoomConfig = getZoomConfig();
  } catch (e) {
    throw new Error('Zoom integration is not configured');
  }

  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
  if (!shiftDoc.exists) {
    throw new Error('Shift not found');
  }

  const shiftData = shiftDoc.data() || {};

  // Verify teacher is authorized for this shift
  if (teacherId && shiftData.teacher_id && teacherId !== shiftData.teacher_id) {
    throw new Error('Not authorized for this shift');
  }

  if (!shiftData.zoom_meeting_id || !shiftData.zoom_encrypted_join_url) {
    throw new Error('Zoom meeting not available for this shift');
  }

  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  const now = new Date();
  const allowedStartMs = shiftStart.getTime() - 10 * 60 * 1000;
  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;

  if (now.getTime() < allowedStartMs || now.getTime() > allowedEndMs) {
    const message = formatCountdownMessage({
      shiftStart,
      shiftEnd,
      now,
      teacherTimezone: shiftData.teacher_timezone,
    });
    throw new Error(`${message.title}: ${message.body}`);
  }

  // Generate join token
  const allowedEndMsForToken = shiftEnd.getTime() + 10 * 60 * 1000;
  const expSeconds = Math.floor((allowedEndMsForToken + 5 * 60 * 1000) / 1000);

  const joinToken = signJoinToken(
    { shiftId, teacherId: teacherId || shiftData.teacher_id, exp: expSeconds },
    zoomConfig.joinTokenSecret
  );

  // Build the join URL using the HTTP function
  // For v2 functions, we need to construct the URL properly
  const projectId = process.env.GCLOUD_PROJECT || 'alluwal-academy';
  const region = 'us-central1';
  const joinUrl = `https://${region}-${projectId}.cloudfunctions.net/joinZoomMeeting?token=${encodeURIComponent(joinToken)}`;

  return {
    success: true,
    joinUrl,
    meetingId: shiftData.zoom_meeting_id,
  };
});



/**
 * Check if user is admin by checking their user document
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
 * Get user display name from user document
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
 * Callable function to get Meeting SDK join payload for in-app Zoom join
 * Returns meeting number, passcode, and Meeting SDK JWT
 * 
 * SECURITY: This function enforces:
 * - Authentication required
 * - Authorization (teacher, student, or admin)
 * - Time window (10 min before to 10 min after shift)
 * - Never logs sensitive data (passcode, JWT)
 */
const getZoomMeetingSdkJoinPayload = onCall(async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  // Require authentication
  if (!uid) {
    console.log('[ZoomSDK] Unauthenticated request');
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  // Validate shiftId
  if (!shiftId || typeof shiftId !== 'string') {
    console.log('[ZoomSDK] Invalid shiftId from uid:', uid);
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }

  // Get Zoom config
  let zoomConfig;
  try {
    zoomConfig = getZoomConfig();
  } catch (e) {
    console.error('[ZoomSDK] Zoom config error');
    throw new HttpsError('unavailable', 'Zoom integration is not configured');
  }

  // Get Meeting SDK config
  const meetingSdkConfig = getMeetingSdkConfig();
  if (!meetingSdkConfig) {
    console.error('[ZoomSDK] Meeting SDK not configured');
    throw new HttpsError('unavailable', 'Meeting SDK is not configured');
  }

  // Get shift document
  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
  if (!shiftDoc.exists) {
    console.log('[ZoomSDK] Shift not found:', shiftId, 'uid:', uid);
    throw new HttpsError('not-found', 'Shift not found');
  }

  const shiftData = shiftDoc.data() || {};

  // Authorization check
  const teacherId = shiftData.teacher_id;
  const studentIds = shiftData.student_ids || [];
  const isTeacher = uid === teacherId;
  const isStudent = studentIds.includes(uid);
  const isAdmin = await isUserAdmin(uid);

  if (!isTeacher && !isStudent && !isAdmin) {
    console.log('[ZoomSDK] Unauthorized access attempt. uid:', uid, 'shiftId:', shiftId);
    throw new HttpsError('permission-denied', 'You are not allowed to join this meeting');
  }

  // Check Zoom meeting exists
  if (!shiftData.zoom_meeting_id) {
    console.log('[ZoomSDK] No Zoom meeting for shift:', shiftId);
    throw new HttpsError('not-found', 'Zoom meeting not configured for this shift');
  }

  // Parse shift times
  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  const now = new Date();
  const allowedStartMs = shiftStart.getTime() - 10 * 60 * 1000; // 10 min before
  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;     // 10 min after

  // Time window check
  if (now.getTime() < allowedStartMs) {
    const minutesUntil = Math.ceil((allowedStartMs - now.getTime()) / 60000);
    console.log('[ZoomSDK] Too early. uid:', uid, 'shiftId:', shiftId, 'minutesUntil:', minutesUntil);
    throw new HttpsError(
      'failed-precondition',
      `You can join 10 minutes before the shift starts. Please wait ${minutesUntil} minute(s).`
    );
  }

  if (now.getTime() > allowedEndMs) {
    console.log('[ZoomSDK] Too late. uid:', uid, 'shiftId:', shiftId);
    throw new HttpsError('failed-precondition', 'The meeting window has ended');
  }

  // Get passcode
  let passcode = null;

  // Try to get existing encrypted passcode
  if (shiftData.zoom_encrypted_meeting_passcode) {
    try {
      passcode = decryptString(shiftData.zoom_encrypted_meeting_passcode, zoomConfig.encryptionKeyB64);
    } catch (decryptErr) {
      console.warn('[ZoomSDK] Failed to decrypt stored passcode for shift:', shiftId);
    }
  }

  // If no passcode, fetch from Zoom API and persist
  if (!passcode) {
    try {
      console.log('[ZoomSDK] Fetching passcode from Zoom API for shift:', shiftId);
      const meetingDetails = await getMeetingDetails(shiftData.zoom_meeting_id);
      passcode = meetingDetails.passcode;

      if (passcode) {
        // Encrypt and persist for future use
        const encryptedPasscode = encryptString(passcode, zoomConfig.encryptionKeyB64);
        await admin.firestore().collection('teaching_shifts').doc(shiftId).update({
          zoom_encrypted_meeting_passcode: encryptedPasscode,
          zoom_meeting_passcode_created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('[ZoomSDK] Passcode persisted for shift:', shiftId);
      }
    } catch (fetchErr) {
      console.error('[ZoomSDK] Failed to fetch meeting details for shift:', shiftId);
      // Continue without passcode - some meetings may not require it
    }
  }

  // Generate Meeting SDK JWT
  // TTL: from now until 15 minutes after shift end (reasonable buffer)
  const ttlSeconds = Math.max(1800, Math.floor((allowedEndMs + 5 * 60 * 1000 - now.getTime()) / 1000));
  const meetingSdkJwt = generateMeetingSdkJwt(
    meetingSdkConfig.sdkKey,
    meetingSdkConfig.sdkSecret,
    ttlSeconds
  );

  // Get user display name
  const displayName = await getUserDisplayName(uid);

  // Log success (no sensitive data)
  console.log('[ZoomSDK] Payload generated. uid:', uid, 'shiftId:', shiftId, 'role:', isAdmin ? 'admin' : (isTeacher ? 'teacher' : 'student'));

  return {
    success: true,
    shiftId,
    meetingNumber: String(shiftData.zoom_meeting_id),
    meetingPasscode: passcode || '',
    meetingSdkJwt,
    displayName,
    joinWindow: {
      allowedStartIso: new Date(allowedStartMs).toISOString(),
      allowedEndIso: new Date(allowedEndMs).toISOString(),
    },
  };
});

module.exports = {
  joinZoomMeeting,
  getZoomJoinUrl,
  getZoomMeetingSdkJoinPayload,
};

