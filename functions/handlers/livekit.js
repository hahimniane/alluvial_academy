/**
 * LiveKit Cloud Function Handlers
 * 
 * Provides callable functions for LiveKit video integration.
 */

const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { RoomServiceClient, TrackType } = require('livekit-server-sdk');
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
      data.role === 'super_admin' ||
      data.user_type === 'admin' ||
      data.user_type === 'super_admin' ||
      data.userType === 'admin' ||
      data.userType === 'super_admin' ||
      data.is_admin === true ||
      data.isAdmin === true ||
      data.is_super_admin === true ||
      data.isSuperAdmin === true ||
      data.is_admin_teacher === true
    );
  } catch (_) {
    return false;
  }
};

/**
 * Helper: Convert ws/wss LiveKit URL to http/https for server APIs.
 *
 * LiveKit clients connect via ws/wss, but RoomServiceClient expects http(s).
 */
const normalizeLiveKitHostForServerApi = (url) => {
  if (!url || typeof url !== 'string') return url;
  if (url.startsWith('wss://')) return `https://${url.slice('wss://'.length)}`;
  if (url.startsWith('ws://')) return `http://${url.slice('ws://'.length)}`;
  return url;
};

/**
 * Helper: Load a shift and validate LiveKit provider.
 */
const getLiveKitShiftOrThrow = async (shiftId) => {
  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
  if (!shiftDoc.exists) {
    throw new HttpsError('not-found', 'Shift not found');
  }

  const shiftData = shiftDoc.data() || {};

  const normalizeProvider = (raw) => {
    if (typeof raw !== 'string') return null;
    const normalized = raw.trim().toLowerCase();
    if (!normalized) return null;
    if (normalized === 'livekit' || normalized === 'zoom') return normalized;
    return null;
  };

  const hasZoomData = () => {
    const zoomMeetingId = shiftData.zoom_meeting_id;
    const hubMeetingId = shiftData.hubMeetingId || shiftData.hub_meeting_id;
    const encryptedJoinUrl = shiftData.zoom_encrypted_join_url || shiftData.zoomEncryptedJoinUrl;
    return (
      (typeof zoomMeetingId === 'string' && zoomMeetingId.trim().length > 0) ||
      (typeof hubMeetingId === 'string' && hubMeetingId.trim().length > 0) ||
      (typeof encryptedJoinUrl === 'string' && encryptedJoinUrl.trim().length > 0)
    );
  };

  const inferredProvider = () => {
    const explicit =
      normalizeProvider(shiftData.video_provider) || normalizeProvider(shiftData.videoProvider);
    if (explicit) return explicit;

    if (hasZoomData()) return 'zoom';

    const category = typeof shiftData.shift_category === 'string' ? shiftData.shift_category : 'teaching';
    if (category === 'teaching') return 'livekit';

    return 'zoom';
  };

  const videoProvider = inferredProvider();
  if (videoProvider !== 'livekit') {
    throw new HttpsError('failed-precondition', 'This shift does not use LiveKit video');
  }

  const teacherId = shiftData.teacher_id;
  const rawStudentIds = shiftData.student_ids;
  const studentIds = Array.isArray(rawStudentIds) ? rawStudentIds : [];
  const roomName = shiftData.livekit_room_name || `shift_${shiftId}`;

  return { shiftData, teacherId, studentIds, roomName, shiftRef: shiftDoc.ref };
};

/**
 * Helper: Enforce that caller is a moderator (teacher or admin).
 */
const assertLiveKitModeratorOrThrow = async ({
  uid,
  teacherId,
  isAdmin,
}) => {
  const isTeacher = uid === teacherId;
  if (!isTeacher && !isAdmin) {
    throw new HttpsError('permission-denied', 'Only teachers/admins can manage this class');
  }
  return { isTeacher };
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
  const { shiftData, teacherId, studentIds, roomName } = await getLiveKitShiftOrThrow(shiftId);

  // Authorization check
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

  const roomLocked = shiftData.livekit_locked === true;
  if (roomLocked && userRole === 'student') {
    throw new HttpsError('failed-precondition', 'This class is locked by the teacher.');
  }

  // Parse shift times for time window check
  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  const now = new Date();
  const nowMs = now.getTime();
  const shiftStartMs = shiftStart.getTime();
  const shiftEndMs = shiftEnd.getTime();
  const allowedStartMs = Number.isFinite(shiftStartMs)
    ? shiftStartMs - 10 * 60 * 1000
    : nowMs - 10 * 60 * 1000;
  const allowedEndMs = Number.isFinite(shiftEndMs)
    ? shiftEndMs + 10 * 60 * 1000
    : nowMs + 2 * 60 * 60 * 1000;

  // Time window check (same as Zoom)
  if (nowMs < allowedStartMs) {
    const minutesUntil = Math.ceil((allowedStartMs - nowMs) / 60000);
    console.log('[LiveKit] Too early. uid:', uid, 'shiftId:', shiftId, 'minutesUntil:', minutesUntil);
    throw new HttpsError(
      'failed-precondition',
      `You can join 10 minutes before the class starts. Please wait ${minutesUntil} minute(s).`
    );
  }

  if (nowMs > allowedEndMs) {
    console.log('[LiveKit] Too late. uid:', uid, 'shiftId:', shiftId);
    throw new HttpsError('failed-precondition', 'The class window has ended');
  }

  // Get user details
  const displayName = await getUserDisplayName(uid);

  // Token TTL: from now until 15 minutes after shift end
  const ttlSeconds = Math.max(
    600,
    Math.floor((allowedEndMs + 5 * 60 * 1000 - nowMs) / 1000),
  );

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
    {},
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
    roomLocked,
    joinWindow: {
      allowedStartIso: new Date(allowedStartMs).toISOString(),
      allowedEndIso: new Date(allowedEndMs).toISOString(),
    },
  };
});

const _deriveShiftDisplayName = (shiftData) => {
  if (!shiftData) return 'Class';
  const custom = shiftData.custom_name || shiftData.customName;
  if (custom && String(custom).trim()) return String(custom).trim();
  const autoName = shiftData.auto_generated_name || shiftData.autoGeneratedName;
  if (autoName && String(autoName).trim()) return String(autoName).trim();
  const title = shiftData.shift_title || shiftData.shiftTitle;
  if (title && String(title).trim()) return String(title).trim();
  const subjectName = shiftData.subject_display_name || shiftData.subjectDisplayName;
  if (subjectName && String(subjectName).trim()) return String(subjectName).trim();
  return 'Class';
};

/**
 * Public guest join (no auth) for LiveKit.
 * Time window only (10 min before to 10 min after).
 */
const getLiveKitGuestJoin = onRequest({
  cors: true,
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (req, res) => {
  res.set('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (!isLiveKitConfigured()) {
    res.status(503).json({ success: false, error: 'LiveKit video is not configured' });
    return;
  }

  const shiftId = req.query.shiftId || req.query.shift_id || req.body?.shiftId;
  if (!shiftId || typeof shiftId !== 'string') {
    res.status(400).json({ success: false, error: 'Missing or invalid shiftId' });
    return;
  }

  let shiftData;
  let roomName;
  try {
    const result = await getLiveKitShiftOrThrow(shiftId);
    shiftData = result.shiftData;
    roomName = result.roomName;
  } catch (e) {
    const code = e?.code;
    const message = e?.message || 'Failed to load class';
    if (code === 'not-found') {
      res.status(404).json({ success: false, error: message });
      return;
    }
    if (code === 'failed-precondition') {
      res.status(400).json({ success: false, error: message });
      return;
    }
    res.status(500).json({ success: false, error: message });
    return;
  }

  if (shiftData.livekit_locked === true) {
    res.status(403).json({ success: false, error: 'This class is locked by the teacher.' });
    return;
  }

  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  const now = new Date();
  const nowMs = now.getTime();
  const shiftStartMs = shiftStart.getTime();
  const shiftEndMs = shiftEnd.getTime();
  const allowedStartMs = Number.isFinite(shiftStartMs)
    ? shiftStartMs - 10 * 60 * 1000
    : nowMs - 10 * 60 * 1000;
  const allowedEndMs = Number.isFinite(shiftEndMs)
    ? shiftEndMs + 10 * 60 * 1000
    : nowMs + 2 * 60 * 60 * 1000;

  if (nowMs < allowedStartMs) {
    const minutesUntil = Math.ceil((allowedStartMs - nowMs) / 60000);
    res.status(403).json({
      success: false,
      error: `You can join 10 minutes before the class starts. Please wait ${minutesUntil} minute(s).`,
    });
    return;
  }

  if (nowMs > allowedEndMs) {
    res.status(403).json({ success: false, error: 'The class window has ended' });
    return;
  }

  const livekitConfig = getLiveKitConfig();
  const rawName = req.query.name || req.body?.name || 'Guest';
  const displayName = String(rawName || 'Guest').trim().slice(0, 60) || 'Guest';
  const identity = `guest_${shiftId}_${Math.random().toString(36).slice(2, 10)}`;
  const ttlSeconds = Math.max(
    600,
    Math.floor((allowedEndMs + 5 * 60 * 1000 - nowMs) / 1000),
  );

  const token = await generateTokenForRole(
    roomName,
    'student',
    identity,
    displayName,
    { role: 'student', guest: true },
    ttlSeconds,
  );

  res.status(200).json({
    success: true,
    livekitUrl: livekitConfig.url,
    token,
    roomName,
    userRole: 'student',
    displayName,
    shiftName: _deriveShiftDisplayName(shiftData),
    expiresInSeconds: ttlSeconds,
    roomLocked: false,
  });
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
  const normalizeProvider = (raw) => {
    if (typeof raw !== 'string') return null;
    const normalized = raw.trim().toLowerCase();
    if (!normalized) return null;
    if (normalized === 'livekit' || normalized === 'zoom') return normalized;
    return null;
  };

  const hasZoomData = () => {
    const zoomMeetingId = shiftData.zoom_meeting_id;
    const hubMeetingId = shiftData.hubMeetingId || shiftData.hub_meeting_id;
    const encryptedJoinUrl = shiftData.zoom_encrypted_join_url || shiftData.zoomEncryptedJoinUrl;
    return (
      (typeof zoomMeetingId === 'string' && zoomMeetingId.trim().length > 0) ||
      (typeof hubMeetingId === 'string' && hubMeetingId.trim().length > 0) ||
      (typeof encryptedJoinUrl === 'string' && encryptedJoinUrl.trim().length > 0)
    );
  };

  const inferredProvider = () => {
    const explicit =
      normalizeProvider(shiftData.video_provider) || normalizeProvider(shiftData.videoProvider);
    if (explicit) return explicit;

    if (hasZoomData()) return 'zoom';

    const category = typeof shiftData.shift_category === 'string' ? shiftData.shift_category : 'teaching';
    if (category === 'teaching') return 'livekit';

    return 'zoom';
  };

  const videoProvider = inferredProvider();

  return {
    available: videoProvider === 'livekit',
    videoProvider: videoProvider,
    roomName: shiftData.livekit_room_name || `shift_${shiftId}`,
    reason: videoProvider === 'livekit'
      ? 'This class uses LiveKit video'
      : 'This class uses Zoom video',
  };
});

/**
 * Callable function: Get current room participants for a shift (presence preview)
 *
 * Useful for admins/teachers to see who is currently in the class before joining.
 *
 * @param {Object} request - Firebase callable request
 * @param {Object} request.data - Request data
 * @param {string} request.data.shiftId - The shift ID to inspect
 * @returns {Object} Room presence info
 */
const getLiveKitRoomPresence = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }

  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }

  const { shiftData, teacherId, studentIds, roomName } = await getLiveKitShiftOrThrow(shiftId);

  const isTeacher = uid === teacherId;
  const isStudent = studentIds.includes(uid);
  const isAdmin = await isUserAdmin(uid);

  if (!isTeacher && !isStudent && !isAdmin) {
    throw new HttpsError('permission-denied', 'You are not allowed to view this class');
  }

  // Time window check (match join window to avoid leaking presence outside class time)
  const shiftStart = shiftData.shift_start?.toDate
    ? shiftData.shift_start.toDate()
    : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate
    ? shiftData.shift_end.toDate()
    : new Date(shiftData.shift_end);

  if (Number.isNaN(shiftStart.getTime()) || Number.isNaN(shiftEnd.getTime())) {
    throw new HttpsError('failed-precondition', 'Shift timing is invalid');
  }

  const now = new Date();
  const allowedStartMs = shiftStart.getTime() - 10 * 60 * 1000;
  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;

  if (now.getTime() < allowedStartMs || now.getTime() > allowedEndMs) {
    return {
      success: true,
      roomName,
      participantCount: 0,
      participants: [],
      inJoinWindow: false,
      generatedAtIso: now.toISOString(),
    };
  }

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);

  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  let participantInfos = [];
  try {
    participantInfos = await roomService.listParticipants(roomName);
  } catch (err) {
    const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim();
    const message = rawMessage.toLowerCase();
    const code = err?.code;
    const status = err?.status;

    // Treat room-not-found as empty room (room is created on-demand).
    if (
      code === 5 ||
      code === 'not_found' ||
      status === 404 ||
      message.includes('not found') ||
      message.includes('notfound') ||
      message.includes('does not exist') ||
      message.includes('room does not exist')
    ) {
      participantInfos = [];
    } else {
      console.error('[LiveKit] Failed to list participants:', err);
      throw new HttpsError('internal', 'Failed to fetch room participants');
    }
  }

  // Sort by joined time when available.
  participantInfos.sort((a, b) => {
    const aMs = a.joinedAtMs || 0n;
    const bMs = b.joinedAtMs || 0n;
    if (aMs === bMs) return 0;
    return aMs < bMs ? -1 : 1;
  });

  const participants = participantInfos
    .filter((p) => p && p.identity)
    .map((p) => {
      const identity = p.identity;
      const role = identity === teacherId
        ? 'teacher'
        : (studentIds.includes(identity) ? 'student' : 'other');

      const joinedAtMs = p.joinedAtMs || 0n;
      const joinedAtIso = joinedAtMs > 0n
        ? new Date(Number(joinedAtMs)).toISOString()
        : null;

      return {
        identity,
        name: p.name || identity,
        role,
        joinedAtIso,
        isPublisher: p.isPublisher === true,
      };
    });

  return {
    success: true,
    roomName,
    participantCount: participants.length,
    participants,
    inJoinWindow: true,
    generatedAtIso: now.toISOString(),
  };
});

/**
 * Callable function: Mute a single participant's microphone tracks.
 *
 * @param {Object} request.data.shiftId
 * @param {Object} request.data.identity - Participant identity to mute
 * @param {Object} request.data.muted - Optional boolean (default true)
 */
const muteLiveKitParticipant = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const targetIdentity = request.data?.identity;
  const mutedRaw = request.data?.muted;
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (!targetIdentity || typeof targetIdentity !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid participant identity');
  }
  if (mutedRaw !== undefined && typeof mutedRaw !== 'boolean') {
    throw new HttpsError('invalid-argument', 'muted must be a boolean');
  }
  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }
  if (targetIdentity === uid) {
    throw new HttpsError('failed-precondition', 'You cannot mute yourself');
  }

  const muted = mutedRaw === undefined ? true : mutedRaw;

  const { teacherId, roomName } = await getLiveKitShiftOrThrow(shiftId);
  const isAdmin = await isUserAdmin(uid);
  const { isTeacher } = await assertLiveKitModeratorOrThrow({ uid, teacherId, isAdmin });
  if (isTeacher && targetIdentity === teacherId) {
    throw new HttpsError('permission-denied', 'Teachers cannot mute other moderators');
  }

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);
  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  let participant;
  try {
    participant = await roomService.getParticipant(roomName, targetIdentity);
  } catch (err) {
    const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim().toLowerCase();
    const code = err?.code;
    const status = err?.status;
    if (
      code === 5 ||
      code === 'not_found' ||
      status === 404 ||
      rawMessage.includes('not found') ||
      rawMessage.includes('does not exist')
    ) {
      throw new HttpsError('not-found', 'Participant not found');
    }
    console.error('[LiveKit] Failed to fetch participant:', err);
    throw new HttpsError('internal', 'Failed to fetch participant');
  }

  const audioTracks = (participant.tracks || []).filter(
    (t) => t && t.type === TrackType.AUDIO && t.sid && (muted ? t.muted !== true : t.muted === true)
  );

  for (const track of audioTracks) {
    await roomService.mutePublishedTrack(roomName, targetIdentity, track.sid, muted);
  }

  return {
    success: true,
    roomName,
    identity: targetIdentity,
    muted,
    mutedTracks: audioTracks.length,
    updatedTracks: audioTracks.length,
  };
});

/**
 * Callable function: Mute all participants (except caller).
 *
 * @param {Object} request.data.shiftId
 */
const muteAllLiveKitParticipants = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }

  const { teacherId, roomName } = await getLiveKitShiftOrThrow(shiftId);
  const isAdmin = await isUserAdmin(uid);
  const { isTeacher } = await assertLiveKitModeratorOrThrow({ uid, teacherId, isAdmin });

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);
  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  let participants = [];
  try {
    participants = await roomService.listParticipants(roomName);
  } catch (err) {
    const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim().toLowerCase();
    const code = err?.code;
    const status = err?.status;
    if (
      code === 5 ||
      code === 'not_found' ||
      status === 404 ||
      rawMessage.includes('not found') ||
      rawMessage.includes('does not exist')
    ) {
      participants = [];
    } else {
      console.error('[LiveKit] Failed to list participants:', err);
      throw new HttpsError('internal', 'Failed to fetch room participants');
    }
  }

  let mutedTracks = 0;
  let mutedParticipants = 0;

  for (const participant of participants) {
    const identity = participant?.identity;
    if (!identity) continue;
    if (identity === uid) continue; // never mute caller
    if (isTeacher && identity === teacherId) continue; // teacher can't mute other moderators

    const audioTracks = (participant.tracks || []).filter(
      (t) => t && t.type === TrackType.AUDIO && t.sid && t.muted !== true
    );
    if (audioTracks.length === 0) continue;

    for (const track of audioTracks) {
      await roomService.mutePublishedTrack(roomName, identity, track.sid, true);
      mutedTracks += 1;
    }
    mutedParticipants += 1;
  }

  return {
    success: true,
    roomName,
    mutedParticipants,
    mutedTracks,
  };
});

/**
 * Callable function: Kick a participant from a room.
 *
 * @param {Object} request.data.shiftId
 * @param {Object} request.data.identity
 */
const kickLiveKitParticipant = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const targetIdentity = request.data?.identity;
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (!targetIdentity || typeof targetIdentity !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid participant identity');
  }
  if (!isLiveKitConfigured()) {
    throw new HttpsError('unavailable', 'LiveKit video is not configured');
  }
  if (targetIdentity === uid) {
    throw new HttpsError('failed-precondition', 'You cannot remove yourself');
  }

  const { teacherId, roomName } = await getLiveKitShiftOrThrow(shiftId);
  const isAdmin = await isUserAdmin(uid);
  const { isTeacher } = await assertLiveKitModeratorOrThrow({ uid, teacherId, isAdmin });
  if (isTeacher && targetIdentity === teacherId) {
    throw new HttpsError('permission-denied', 'Teachers cannot remove other moderators');
  }

  const livekitConfig = getLiveKitConfig();
  const host = normalizeLiveKitHostForServerApi(livekitConfig.url);
  const roomService = new RoomServiceClient(host, livekitConfig.apiKey, livekitConfig.apiSecret);

  try {
    await roomService.removeParticipant(roomName, targetIdentity);
  } catch (err) {
    const rawMessage = `${err?.message || ''} ${String(err || '')}`.trim().toLowerCase();
    const code = err?.code;
    const status = err?.status;
    if (
      code === 5 ||
      code === 'not_found' ||
      status === 404 ||
      rawMessage.includes('not found') ||
      rawMessage.includes('does not exist')
    ) {
      throw new HttpsError('not-found', 'Participant not found');
    }
    console.error('[LiveKit] Failed to remove participant:', err);
    throw new HttpsError('internal', 'Failed to remove participant');
  }

  return {
    success: true,
    roomName,
    identity: targetIdentity,
  };
});

/**
 * Callable function: Lock/unlock a class room (prevents students from joining).
 *
 * @param {Object} request.data.shiftId
 * @param {Object} request.data.locked
 */
const setLiveKitRoomLock = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const shiftId = request.data?.shiftId;
  const locked = request.data?.locked;
  const uid = request.auth?.uid;

  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }
  if (typeof locked !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Missing or invalid locked flag');
  }

  const { teacherId, shiftRef } = await getLiveKitShiftOrThrow(shiftId);
  const isAdmin = await isUserAdmin(uid);
  await assertLiveKitModeratorOrThrow({ uid, teacherId, isAdmin });

  await shiftRef.update({
    livekit_locked: locked,
    livekit_locked_by: uid,
    livekit_locked_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    locked,
  };
});

module.exports = {
  getLiveKitJoinToken,
  checkLiveKitAvailability,
  getLiveKitRoomPresence,
  muteLiveKitParticipant,
  muteAllLiveKitParticipants,
  kickLiveKitParticipant,
  setLiveKitRoomLock,
  getLiveKitGuestJoin,
};
