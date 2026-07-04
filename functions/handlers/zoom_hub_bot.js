const crypto = require('crypto');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const { getZoomConfig } = require('../services/zoom/config');
const zoomClient = require('../services/zoom/client');
const { generateMeetingSdkSignature } = require('../services/zoom/signature');

const ZOOM_HUB_BOT_SECRETS = [
  'ZOOM_HUB_BOT_KEY',
  'ZOOM_SDK_KEY',
  'ZOOM_SDK_SECRET',
  'ZOOM_S2S_ACCOUNT_ID',
  'ZOOM_S2S_CLIENT_ID',
  'ZOOM_S2S_CLIENT_SECRET',
];

const _toDate = (raw) => {
  if (!raw) return null;
  if (raw instanceof Date) return raw;
  if (raw.toDate) return raw.toDate();
  const date = new Date(raw);
  return Number.isFinite(date.getTime()) ? date : null;
};

const _timingSafeEqualText = (first, second) => {
  const firstBuffer = Buffer.from(String(first || ''));
  const secondBuffer = Buffer.from(String(second || ''));
  if (firstBuffer.length !== secondBuffer.length) return false;
  if (firstBuffer.length === 0) return false;
  return crypto.timingSafeEqual(firstBuffer, secondBuffer);
};

const _botAuthorized = (req) => {
  const configured = String(process.env.ZOOM_HUB_BOT_KEY || '').trim();
  const provided = String(
    req.get?.('x-bot-key') ||
    req.headers?.['x-bot-key'] ||
    '',
  ).trim();
  return _timingSafeEqualText(provided, configured);
};

const _requireBot = (req, res) => {
  if (_botAuthorized(req)) return true;
  res.status(401).json({ success: false, error: 'Unauthorized' });
  return false;
};

const _roomList = (rawRooms) =>
  (Array.isArray(rawRooms) ? rawRooms : [])
    .map((room) => ({
      shiftId: String(room?.shiftId || room?.shift_id || '').trim(),
      name: String(room?.name || '').trim(),
      spare: room?.spare === true,
    }))
    .filter((room) => room.name);

const _hubIsActive = (hubData, now) => {
  const start = _toDate(hubData.window_start || hubData.windowStart);
  const end = _toDate(hubData.window_end || hubData.windowEnd);
  if (!start || !end) return false;
  return start.getTime() <= now.getTime() && end.getTime() >= now.getTime();
};

const zoomHubBotDirectives = onRequest({
  cors: true,
  secrets: ZOOM_HUB_BOT_SECRETS,
}, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }
  if (!_requireBot(req, res)) return;

  try {
    const lane = Number(req.query?.lane);
    if (!Number.isInteger(lane) || lane < 1) {
      res.status(400).json({ success: false, error: 'Missing or invalid lane' });
      return;
    }

    const { sdkKey } = getZoomConfig();
    if (!sdkKey) {
      res.status(503).json({ success: false, error: 'Zoom SDK is not configured' });
      return;
    }

    const now = new Date();
    const snapshot = await admin.firestore().collection('hub_meetings')
      .where('lane', '==', lane)
      .get();

    const directives = [];
    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      if (!_hubIsActive(data, now)) continue;
      const meetingNumber = String(
        data.meetingNumber ||
        data.meeting_number ||
        data.zoom_meeting_id ||
        data.zoomMeetingId ||
        '',
      ).trim();
      const hostAccount = String(data.hostAccount || data.host_account || '').trim();
      if (!meetingNumber || !hostAccount) continue;
      const zak = await zoomClient.getUserZak(hostAccount);
      directives.push({
        hubDocId: doc.id,
        meetingNumber,
        password: String(data.zoom_password || data.password || '').trim(),
        hostAccount,
        sdkKey,
        signatureRole1: generateMeetingSdkSignature({ meetingNumber, role: 1 }),
        zak,
        rooms: _roomList(data.rooms).map((room) => room.name),
        boIdByRoomName: data.boIdByRoomName || data.bo_id_by_room_name || {},
        windowStart: _toDate(data.window_start || data.windowStart)?.toISOString() || null,
        windowEnd: _toDate(data.window_end || data.windowEnd)?.toISOString() || null,
      });
    }

    res.status(200).json({ success: true, directives });
  } catch (err) {
    console.error('[ZoomHubBot] directives failed:', err);
    res.status(500).json({ success: false, error: err.message || 'Unable to load directives' });
  }
});

const zoomHubBotAssignments = onRequest({
  cors: true,
  secrets: ZOOM_HUB_BOT_SECRETS,
}, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }
  if (!_requireBot(req, res)) return;

  try {
    const hubDocId = String(req.query?.hubDocId || '').trim();
    if (!hubDocId) {
      res.status(400).json({ success: false, error: 'Missing hubDocId' });
      return;
    }
    const hubRef = admin.firestore().collection('hub_meetings').doc(hubDocId);
    const hubDoc = await hubRef.get();
    if (!hubDoc.exists) {
      res.status(404).json({ success: false, error: 'Hub not found' });
      return;
    }
    const hubData = hubDoc.data() || {};
    const membersSnapshot = await hubRef.collection('members').get();
    const members = membersSnapshot.docs
      .map((doc) => {
        const data = doc.data() || {};
        const displayName = String(data.displayName || data.display_name || '').trim();
        return {
          uid: String(data.uid || doc.id || '').trim(),
          shiftId: String(data.shiftId || data.shift_id || '').trim(),
          role: String(data.role || '').trim(),
          ...(displayName ? { displayName } : {}),
        };
      })
      .filter((member) => member.uid && member.shiftId);

    res.status(200).json({
      success: true,
      hubDocId,
      rooms: _roomList(hubData.rooms)
        .filter((room) => room.shiftId && !String(room.shiftId).startsWith('__spare_'))
        .map((room) => ({ shiftId: room.shiftId, name: room.name })),
      members,
    });
  } catch (err) {
    console.error('[ZoomHubBot] assignments failed:', err);
    res.status(500).json({ success: false, error: err.message || 'Unable to load assignments' });
  }
});

const zoomHubBotState = onRequest({
  cors: true,
  secrets: ZOOM_HUB_BOT_SECRETS,
}, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }
  if (!_requireBot(req, res)) return;

  try {
    const hubDocId = String(req.body?.hubDocId || '').trim();
    const status = String(req.body?.status || '').trim();
    if (!hubDocId || !status) {
      res.status(400).json({ success: false, error: 'Missing hubDocId or status' });
      return;
    }
    const allowedStatuses = new Set(['joined', 'roomsOpen', 'error', 'left']);
    if (!allowedStatuses.has(status)) {
      res.status(400).json({ success: false, error: 'Invalid bot status' });
      return;
    }
    const ref = admin.firestore().collection('hub_meetings').doc(hubDocId);
    const hubDoc = await ref.get();
    const hubData = hubDoc.exists ? hubDoc.data() || {} : {};
    const boIdByRoomName = req.body?.boIdByRoomName || {};
    const hasRoomIds = boIdByRoomName &&
      typeof boIdByRoomName === 'object' &&
      Object.keys(boIdByRoomName).length > 0;
    const nextData = {
      status,
      bot_status: status,
      stats: req.body?.stats || {},
      bot_error: req.body?.error || null,
      heartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
      heartbeat_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (hasRoomIds) {
      nextData.boIdByRoomName = boIdByRoomName;
      nextData.bo_id_by_room_name = boIdByRoomName;
    }
    await ref.set({
      ...nextData,
    }, { merge: true });
    if (status === 'left' && typeof zoomClient.endMeeting === 'function') {
      const meetingNumber = String(
        hubData.meetingNumber ||
        hubData.zoom_meeting_id ||
        hubData.meeting_number ||
        '',
      ).trim();
      if (meetingNumber) {
        try {
          await zoomClient.endMeeting(meetingNumber);
          await ref.set({
            ended_at: admin.firestore.FieldValue.serverTimestamp(),
            bot_end_error: null,
          }, { merge: true });
        } catch (err) {
          await ref.set({
            bot_end_error: err.message || String(err),
          }, { merge: true });
          console.warn('[ZoomHubBot] Failed to end hub meeting:', meetingNumber, err.message || err);
        }
      }
    }
    res.status(200).json({ success: true });
  } catch (err) {
    console.error('[ZoomHubBot] state update failed:', err);
    res.status(500).json({ success: false, error: err.message || 'Unable to save bot state' });
  }
});

module.exports = {
  zoomHubBotDirectives,
  zoomHubBotAssignments,
  zoomHubBotState,
  __test__: {
    _botAuthorized,
    _hubIsActive,
    _roomList,
  },
};
