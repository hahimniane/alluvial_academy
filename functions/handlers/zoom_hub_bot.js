const crypto = require('crypto');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
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

const _safeText = (value, maxLength = 160) =>
  String(value || '').replace(/\s+/g, ' ').trim().slice(0, maxLength);

const _safeNumberOrNull = (value) => {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
};

const _sanitizeLiveParticipantsByShift = (raw) => {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const result = {};
  for (const [rawShiftId, rawParticipants] of Object.entries(raw).slice(0, 120)) {
    const shiftId = _safeText(rawShiftId, 180);
    if (!shiftId || !Array.isArray(rawParticipants)) continue;
    const participants = [];
    for (const participant of rawParticipants.slice(0, 40)) {
      if (!participant || typeof participant !== 'object') continue;
      const identity = _safeText(
        participant.identity || participant.userId || participant.user_id,
        180,
      );
      const routingUid = _safeText(
        participant.routingUid || participant.routing_uid || participant.uid,
        180,
      );
      const name = _safeText(
        participant.name ||
        participant.displayName ||
        participant.display_name ||
        'Participant',
        120,
      ) || 'Participant';
      const role = _safeText(participant.role || 'participant', 40) || 'participant';
      const zoomUserId = _safeNumberOrNull(
        participant.zoomUserId || participant.zoom_user_id || participant.zoomParticipantId,
      );
      if (!identity && !routingUid && !name) continue;
      participants.push({
        identity,
        routingUid,
        routing_uid: routingUid,
        zoomUserId,
        zoom_user_id: zoomUserId,
        name,
        role,
        source: 'zoom_hub_bot',
      });
    }
    result[shiftId] = participants;
  }
  return result;
};

const _hubIsActive = (hubData, now) => {
  const start = _toDate(hubData.window_start || hubData.windowStart);
  const end = _toDate(hubData.window_end || hubData.windowEnd);
  if (!start || !end) return false;
  return start.getTime() <= now.getTime() && end.getTime() >= now.getTime();
};

const ZOOM_HUB_STALE_MS = 2 * 60 * 1000;

const _hubBlockIndex = (hubData) => {
  const n = Number(hubData.blockIndex ?? hubData.block_index);
  return Number.isFinite(n) ? n : 0;
};

const _hubInRoomOccupants = (hubData) => {
  const stats = (hubData.stats && typeof hubData.stats === 'object') ? hubData.stats : {};
  const n = Number(stats.inRoomOccupants);
  return Number.isFinite(n) ? n : 0;
};

const _msOf = (value) => {
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number') return value;
  const date = _toDate(value);
  return date ? date.getTime() : Date.now();
};

const _hubHeartbeatFresh = (hubData, now) => {
  const hb = _toDate(hubData.heartbeat_at || hubData.heartbeatAt);
  return Boolean(hb) && hb.getTime() + ZOOM_HUB_STALE_MS >= _msOf(now);
};

const _msOfOrNull = (value) => {
  const date = _toDate(value);
  return date ? date.getTime() : null;
};

// Hub windows are padded 15 min on each side; the REAL scheduled classes run
// within [window_start + PAD, window_end - PAD]. We use the real end to decide
// whether a class is genuinely still running vs. someone who forgot to leave.
const ZOOM_HUB_WINDOW_PAD_MS = 15 * 60 * 1000;
const _hubRealClassEnd = (data) => {
  const assignedEnd = _toDate(data.assigned_class_end || data.assignedClassEnd);
  if (assignedEnd) return assignedEnd.getTime();
  const end = _toDate(data.window_end || data.windowEnd);
  return end ? end.getTime() - ZOOM_HUB_WINDOW_PAD_MS : null;
};

// Each licensed account can host only ONE meeting at a time, so a lane must
// host exactly one hub even when block windows overlap at a boundary.
// A hub is "protected" (finish it before switching) only while its REAL
// scheduled classes are still running AND someone is inside a room. Past the
// last scheduled class end, a lingering participant does NOT protect it — a
// newer block wins — so a teacher/student who forgets to leave can never starve
// the next block of the shared account. With no protected hub, host the newest
// block. This stops the block-boundary "Already has other meetings" (3000) storm
// and the forgot-to-leave account-starvation case.
const _selectPrimaryActiveHub = (activeDocs, now) => {
  if (activeDocs.length <= 1) return activeDocs;
  const nowMs = _msOf(now);
  const protectedHubs = activeDocs.filter((doc) => {
    const data = doc.data() || {};
    const realEnd = _hubRealClassEnd(data);
    return _hubInRoomOccupants(data) > 0 &&
      _hubHeartbeatFresh(data, now) &&
      realEnd !== null && nowMs <= realEnd;
  });
  const dueHubs = activeDocs.filter((doc) => {
    const data = doc.data() || {};
    const realEnd = _hubRealClassEnd(data);
    return realEnd !== null && nowMs <= realEnd;
  });
  const pool = protectedHubs.length > 0
    ? protectedHubs
    : (dueHubs.length > 0 ? dueHubs : activeDocs);
  const sorted = pool.slice().sort((a, b) => {
    const aData = a.data() || {};
    const bData = b.data() || {};
    if (protectedHubs.length > 0) {
      return _hubBlockIndex(aData) - _hubBlockIndex(bData);
    }
    const blockDiff = _hubBlockIndex(bData) - _hubBlockIndex(aData);
    if (blockDiff !== 0) return blockDiff;
    return (_hubRealClassEnd(bData) || 0) - (_hubRealClassEnd(aData) || 0);
  });
  return [sorted[0]];
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

    const activeDocs = snapshot.docs.filter((doc) => _hubIsActive(doc.data() || {}, now));
    const primaryDocs = _selectPrimaryActiveHub(activeDocs, now);

    const directives = [];
    for (const doc of primaryDocs) {
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

// Shapes one members-subcollection doc into the object the bot consumes.
const _botMemberFromDoc = (doc) => {
  const data = doc.data() || {};
  const displayName = String(data.displayName || data.display_name || '').trim();
  const routingDisplayName = String(
    data.routingDisplayName || data.routing_display_name || '',
  ).trim();
  const displayNameAliases = [
    ...(Array.isArray(data.displayNameAliases) ? data.displayNameAliases : []),
    ...(Array.isArray(data.display_name_aliases) ? data.display_name_aliases : []),
  ]
    .map((value) => String(value || '').trim())
    .filter(Boolean);
  return {
    uid: String(data.uid || doc.id || '').trim(),
    ...(String(data.userId || data.user_id || '').trim()
      ? { userId: String(data.userId || data.user_id || '').trim() }
      : {}),
    shiftId: String(data.shiftId || data.shift_id || '').trim(),
    role: String(data.role || '').trim(),
    ...(displayName ? { displayName } : {}),
    ...(routingDisplayName ? { routingDisplayName } : {}),
    ...(displayNameAliases.length ? { displayNameAliases } : {}),
  };
};

// The bots poll assignments every few seconds, so re-reading the whole
// members subcollection per poll multiplies into millions of document reads
// a month. The member list is instead cached on the hub doc and refreshed by
// the member-write trigger below; each poll then costs one document read.
const _rebuildBotAssignmentsCache = async (hubRef) => {
  const membersSnapshot = await hubRef.collection('members').get();
  const members = membersSnapshot.docs
    .map(_botMemberFromDoc)
    .filter((member) => member.uid && member.shiftId);
  await hubRef.set({
    bot_assignments_cache: {
      members,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, { merge: true });
  return members;
};

// Keeps the cached member list in sync with every member add/update/remove.
const onZoomHubMemberWritten = onDocumentWritten(
  'hub_meetings/{hubId}/members/{memberId}',
  async (event) => {
    const hubRef = admin.firestore().collection('hub_meetings').doc(event.params.hubId);
    try {
      await _rebuildBotAssignmentsCache(hubRef);
    } catch (err) {
      console.error('[ZoomHubBot] member cache rebuild failed:', err);
    }
  },
);

// Deterministic serialization for change detection (object key order in
// Firestore data is not guaranteed to match the incoming request body).
const _stableStringify = (value) => {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(_stableStringify).join(',')}]`;
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${_stableStringify(value[key])}`).join(',')}}`;
};

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
    // Serve from the cached member list (1 read/poll); fall back to a live
    // subcollection read once for hubs created before the cache existed —
    // that read also backfills the cache.
    const cachedMembers = hubData.bot_assignments_cache &&
      Array.isArray(hubData.bot_assignments_cache.members)
      ? hubData.bot_assignments_cache.members
      : null;
    const members = cachedMembers ?? await _rebuildBotAssignmentsCache(hubRef);

    res.status(200).json({
      success: true,
      hubDocId,
      rooms: _roomList(hubData.rooms)
        .filter((room) => room.shiftId && !String(room.shiftId).startsWith('__spare_'))
        .map((room) => ({ shiftId: room.shiftId, name: room.name })),
      members,
      // When the watcher detects the bot's meeting is not actually live
      // (a "zombie" session), it stamps force_rejoin_at; the bot reloads to
      // rejoin a fresh instance. Returned in ms so the bot can compare it to
      // when its current page loaded.
      forceRejoinAt: _msOfOrNull(hubData.force_rejoin_at || hubData.forceRejoinAt),
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
    const allowedStatuses = new Set(['joined', 'roomsOpen', 'error', 'left', 'resetMeeting']);
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
    const liveParticipantsProvided = Object.prototype.hasOwnProperty.call(
      req.body || {},
      'liveParticipantsByShift',
    ) || Object.prototype.hasOwnProperty.call(
      req.body || {},
      'live_participants_by_shift',
    );
    const liveParticipantsByShift = liveParticipantsProvided
      ? _sanitizeLiveParticipantsByShift(
        req.body?.liveParticipantsByShift || req.body?.live_participants_by_shift,
      )
      : null;
    // Report-on-change: bots post every few seconds, but the payload rarely
    // changes mid-class. Skip the Firestore write when nothing meaningful
    // (status, room ids, live participants) changed AND the last heartbeat is
    // fresh (<60s) — the health watcher only checks staleness at 2-minute
    // granularity, so a 60s keepalive loses nothing. Every actual change
    // still lands immediately, and lifecycle statuses ('left',
    // 'resetMeeting', 'error') always take the full path because side
    // effects (ending the meeting, alerting) hang off them.
    const _msOf = (raw) => {
      const date = _toDate(raw);
      return date ? date.getTime() : 0;
    };
    if (hubDoc.exists && status === 'roomsOpen') {
      const lastBeatMs = Math.max(_msOf(hubData.heartbeat_at), _msOf(hubData.heartbeatAt));
      const sameStatus = status === String(hubData.bot_status || hubData.status || '').trim();
      const sameRooms = !hasRoomIds ||
        _stableStringify(boIdByRoomName) ===
          _stableStringify(hubData.boIdByRoomName || hubData.bo_id_by_room_name || {});
      const sameParticipants = !liveParticipantsProvided ||
        _stableStringify(liveParticipantsByShift || {}) ===
          _stableStringify(hubData.liveParticipantsByShift || hubData.live_participants_by_shift || {});
      if (sameStatus && sameRooms && sameParticipants && Date.now() - lastBeatMs < 60000) {
        res.status(200).json({ success: true, deduped: true });
        return;
      }
    }

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
    if (liveParticipantsProvided || status === 'left') {
      nextData.liveParticipantsByShift = status === 'left' ? {} : liveParticipantsByShift;
      nextData.live_participants_by_shift = status === 'left' ? {} : liveParticipantsByShift;
      nextData.liveParticipantsUpdatedAt = admin.firestore.FieldValue.serverTimestamp();
      nextData.live_participants_updated_at = admin.firestore.FieldValue.serverTimestamp();
    }
    await ref.set({
      ...nextData,
    }, { merge: true });
    const meetingNumber = String(
      hubData.meetingNumber ||
      hubData.zoom_meeting_id ||
      hubData.meeting_number ||
      '',
    ).trim();
    // 'left' = bot is done with this hub (window over): end the meeting.
    // 'resetMeeting' = bot detected a corrupted/unrecoverable meeting instance
    // (breakout state unreadable and un-resettable in place). End the meeting so
    // the bot can rejoin a clean instance. Refuse to end if anyone is inside a
    // room, so a live class is never interrupted.
    const shouldEnd = (status === 'left') ||
      (status === 'resetMeeting' && _hubInRoomOccupants(hubData) === 0);
    if (shouldEnd && meetingNumber && typeof zoomClient.endMeeting === 'function') {
      try {
        await zoomClient.endMeeting(meetingNumber);
        await ref.set({
          ...(status === 'resetMeeting'
            ? { reset_at: admin.firestore.FieldValue.serverTimestamp() }
            : { ended_at: admin.firestore.FieldValue.serverTimestamp() }),
          bot_end_error: null,
        }, { merge: true });
        if (status === 'resetMeeting') {
          console.warn(`[ZoomHubBot] Reset corrupted hub ${hubDocId} (ended meeting ${meetingNumber}); bot will rejoin fresh.`);
        }
      } catch (err) {
        await ref.set({
          bot_end_error: err.message || String(err),
        }, { merge: true });
        console.warn('[ZoomHubBot] Failed to end hub meeting:', meetingNumber, err.message || err);
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
  onZoomHubMemberWritten,
  __test__: {
    _botAuthorized,
    _hubIsActive,
    _roomList,
    _sanitizeLiveParticipantsByShift,
    _selectPrimaryActiveHub,
    _hubInRoomOccupants,
    _botMemberFromDoc,
    _stableStringify,
  },
};
