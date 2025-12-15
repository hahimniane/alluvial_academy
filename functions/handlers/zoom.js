const admin = require('firebase-admin');
const {onRequest, onCall} = require('firebase-functions/v2/https');
const {DateTime} = require('luxon');
const {getZoomConfig} = require('../services/zoom/config');
const {verifyJoinToken, decryptString, signJoinToken} = require('../services/zoom/crypto');

const formatCountdownMessage = ({shiftStart, shiftEnd, now, teacherTimezone}) => {
  const startMs = shiftStart.getTime();
  const endMs = shiftEnd.getTime();
  const nowMs = now.getTime();

  const allowedStartMs = startMs - 10 * 60 * 1000;
  const allowedEndMs = endMs + 10 * 60 * 1000;

  const zone = teacherTimezone || 'UTC';
  const startText = DateTime.fromJSDate(shiftStart, {zone}).toFormat("ccc, LLL d • h:mm a ZZZZ");
  const endText = DateTime.fromJSDate(shiftEnd, {zone}).toFormat("ccc, LLL d • h:mm a ZZZZ");

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
    {shiftId, teacherId: teacherId || shiftData.teacher_id, exp: expSeconds},
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

module.exports = {
  joinZoomMeeting,
  getZoomJoinUrl,
};

