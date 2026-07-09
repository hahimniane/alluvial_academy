const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { DateTime } = require('luxon');
const { getZoomConfig } = require('../services/zoom/config');
const zoomClient = require('../services/zoom/client');
const { generateMeetingSdkSignature } = require('../services/zoom/signature');
const { createTransporter } = require('../services/email/transporter');

const ZOOM_JOIN_SECRETS = [
  'ZOOM_SDK_KEY',
  'ZOOM_SDK_SECRET',
  'ZOOM_S2S_ACCOUNT_ID',
  'ZOOM_S2S_CLIENT_ID',
  'ZOOM_S2S_CLIENT_SECRET',
];

const ZOOM_WEBHOOK_SECRETS = ['ZOOM_WEBHOOK_SECRET_TOKEN'];
const BATCH_WRITE_LIMIT = 400;
const LATE_GRACE_MINUTES = 5;
const JOIN_WINDOW_BEFORE_MS = 10 * 60 * 1000;
const JOIN_WINDOW_AFTER_MS = 10 * 60 * 1000;
const ZOOM_HOST_CONFLICT_LOOKBACK_MS = 24 * 60 * 60 * 1000;
const ZOOM_HUB_WINDOW_PADDING_MS = 15 * 60 * 1000;
const ZOOM_HUB_PREP_LOOKAHEAD_MS = 60 * 60 * 1000;
const ZOOM_HUB_BOT_STALE_MS = 2 * 60 * 1000;
const ZOOM_HUB_STATUS_LOOKBACK_MS = 24 * 60 * 60 * 1000;
const ZOOM_HUB_STATUS_LOOKAHEAD_MS = 2 * 60 * 60 * 1000;
const ZOOM_HUB_CAPACITY_FORECAST_DAYS = 90;
const ZOOM_HUB_CAPACITY_WARNING_RATIO = 0.75;
const ZOOM_HUB_SEAT_WARNING_RATIO = 0.8;
const ZOOM_HUB_PARTICIPANT_CAP_PER_LANE = Number(
  process.env.ZOOM_HUB_PARTICIPANT_CAP_PER_LANE || 100,
);
const ZOOM_HUB_RESERVED_SEATS_PER_LANE = 1;
// A hub whose bot reports rooms open yet its live breakout list reads empty
// (getBreakoutRooms == 0) while members are expected has a corrupted meeting
// instance the bot cannot repair in place. After this many consecutive watcher
// checks, end the meeting so the bot rejoins a clean instance. Never triggered
// for a healthy hub (its live room count is > 0).
const ZOOM_HUB_POISON_RESET_STREAK = 2;
// Zoom meetings have a hard maximum runtime. Keep hub windows well below it
// so one shared classroom hub never expires while unrelated classes are live.
const ZOOM_HUB_SAFE_MAX_MEETING_MINUTES = 28 * 60;
const ZOOM_HUB_SPARE_ROOM_COUNT = 5;
const ZOOM_HUB_MAX_ROOM_COUNT = 48;
const ZOOM_HUB_DEFAULT_TIMEZONE = 'America/New_York';
const ZOOM_HUB_DEFAULT_BOUNDARIES = ['05:00', '12:00', '17:00'];
const DEFAULT_ZOOM_CLASSROOM_HOST_ACCOUNTS = [
  'billing@alluwaleducationhub.org',
  'support@alluwaleducationhub.org',
];

const _normalizeUidList = (rawList) => {
  if (!Array.isArray(rawList)) return [];
  const seen = new Set();
  const result = [];
  for (const item of rawList) {
    if (typeof item !== 'string') continue;
    const value = item.trim();
    if (!value || seen.has(value)) continue;
    seen.add(value);
    result.push(value);
  }
  return result;
};

const _toDate = (raw) => {
  if (!raw) return null;
  if (raw instanceof Date) return raw;
  if (raw.toDate) return raw.toDate();
  if (typeof raw === 'number') {
    const date = new Date(raw > 9999999999 ? raw : raw * 1000);
    return Number.isFinite(date.getTime()) ? date : null;
  }
  const date = new Date(raw);
  return Number.isFinite(date.getTime()) ? date : null;
};

const _roleList = (value) => {
  if (!Array.isArray(value)) return [];
  return value
    .map((role) => String(role || '').trim().toLowerCase())
    .filter(Boolean);
};

const _truthy = (value) =>
  value === true || value === 'true' || value === 1 || value === '1';

const _isAdminRole = (role) => (
  role === 'admin' ||
  role === 'super_admin' ||
  role === 'admin_teacher'
);

const getUserDataForCaller = async (uid, token = {}) => {
  if (!uid) return null;
  const db = admin.firestore();
  const userDoc = await db.collection('users').doc(uid).get();
  if (userDoc.exists) return userDoc.data() || {};

  const rawEmail = typeof token?.email === 'string' ? token.email.trim() : '';
  if (!rawEmail) return null;

  const lowerEmail = rawEmail.toLowerCase();
  for (const docId of [lowerEmail, rawEmail]) {
    const emailDoc = await db.collection('users').doc(docId).get();
    if (emailDoc.exists) return emailDoc.data() || {};
  }

  for (const field of ['email', 'e-mail']) {
    const query = await db.collection('users')
      .where(field, '==', lowerEmail)
      .limit(1)
      .get();
    if (!query.empty) return query.docs[0].data() || {};
  }

  return null;
};

const _emailCandidatesFromUser = (data = {}, token = {}) => {
  const candidates = [
    token.email,
    data.email,
    data['e-mail'],
    data.user_email,
    data.userEmail,
  ]
    .map((value) => String(value || '').trim().toLowerCase())
    .filter(Boolean);
  return new Set(candidates);
};

const _isUserShiftTeacher = async ({ uid, token = {}, teacherId }) => {
  const normalizedUid = String(uid || '').trim();
  const normalizedTeacherId = String(teacherId || '').trim();
  if (!normalizedUid || !normalizedTeacherId) return false;
  if (normalizedUid === normalizedTeacherId) return true;

  try {
    const db = admin.firestore();
    const [callerData, teacherDoc] = await Promise.all([
      getUserDataForCaller(normalizedUid, token),
      db.collection('users').doc(normalizedTeacherId).get(),
    ]);
    if (!teacherDoc.exists) return false;
    const teacherData = teacherDoc.data() || {};
    const callerEmails = _emailCandidatesFromUser(callerData || {}, token);
    if (callerEmails.size === 0) return false;
    const teacherEmails = _emailCandidatesFromUser(teacherData);
    for (const email of teacherEmails) {
      if (callerEmails.has(email)) return true;
    }
  } catch (_) {
    return false;
  }
  return false;
};

const isUserAdmin = async (uid, token = {}) => {
  if (!uid) return false;
  try {
    const tokenRole = String(token.role || token.user_type || token.userType || '')
      .trim()
      .toLowerCase();
    const tokenRoles = [
      ..._roleList(token.roles),
      ..._roleList(token.secondary_roles),
      ..._roleList(token.secondaryRoles),
    ];
    if (
      _isAdminRole(tokenRole) ||
      tokenRoles.some(_isAdminRole) ||
      _truthy(token.admin) ||
      _truthy(token.isAdmin) ||
      _truthy(token.is_admin) ||
      _truthy(token.is_super_admin) ||
      _truthy(token.isSuperAdmin) ||
      _truthy(token.is_admin_teacher) ||
      _truthy(token.isAdminTeacher)
    ) {
      return true;
    }

    const data = await getUserDataForCaller(uid, token);
    if (!data) return false;
    const role = String(data.role || '').trim().toLowerCase();
    const userType = String(data.user_type || data.userType || '')
      .trim()
      .toLowerCase();
    const secondaryRoles = [
      ..._roleList(data.roles),
      ..._roleList(data.secondary_roles),
      ..._roleList(data.secondaryRoles),
    ];
    return (
      _isAdminRole(role) ||
      _isAdminRole(userType) ||
      secondaryRoles.some(_isAdminRole) ||
      _truthy(data.is_admin) ||
      _truthy(data.isAdmin) ||
      _truthy(data.is_super_admin) ||
      _truthy(data.isSuperAdmin) ||
      _truthy(data.is_admin_teacher) ||
      _truthy(data.isAdminTeacher)
    );
  } catch (_) {
    return false;
  }
};

const getGuardianIdsForStudents = async (studentIds) => {
  const guardianIds = new Set();
  for (const studentId of _normalizeUidList(studentIds)) {
    const studentDoc = await admin.firestore().collection('users').doc(studentId).get();
    if (!studentDoc.exists) continue;
    const data = studentDoc.data() || {};
    for (const guardianId of _normalizeUidList([
      ...(Array.isArray(data.guardian_ids) ? data.guardian_ids : []),
      ...(Array.isArray(data.guardianIds) ? data.guardianIds : []),
    ])) {
      guardianIds.add(guardianId);
    }
  }
  return guardianIds;
};

const isUserParentOfStudent = async (uid, studentIds) => {
  if (!uid) return false;
  const guardianIds = await getGuardianIdsForStudents(studentIds);
  return guardianIds.has(uid);
};

const isStudentAccessSuspended = async (uid) => {
  if (!uid) return false;
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  if (!userDoc.exists) return false;
  const data = userDoc.data() || {};
  return data.access_suspended === true || data.accessSuspended === true;
};

const _normalizeRequestedClassRole = (activeRole) => {
  const role = String(activeRole || '').trim().toLowerCase();
  if (role === 'super_admin' || role === 'admin_teacher') return 'admin';
  if (['admin', 'teacher', 'student', 'parent'].includes(role)) return role;
  return '';
};

const _resolveClassroomRole = ({ activeRole, isTeacher, isStudent, isAdmin, isParent }) => {
  const requestedRole = _normalizeRequestedClassRole(activeRole);
  if (requestedRole === 'teacher' && isTeacher) return 'teacher';
  if (requestedRole === 'student' && isStudent) return 'student';
  if (requestedRole === 'parent' && isParent) return 'parent';
  if (requestedRole === 'admin' && isAdmin) return 'admin';

  if (isTeacher) return 'teacher';
  if (isAdmin) return 'admin';
  if (isParent) return 'parent';
  return 'student';
};

const getAccessForUser = async ({ uid, token, teacherId, studentIds, activeRole }) => {
  const isTeacher = await _isUserShiftTeacher({ uid, token, teacherId });
  const isStudent = studentIds.includes(uid);
  const isAdmin = await isUserAdmin(uid, token);
  const isParent = !isTeacher && !isStudent
    ? await isUserParentOfStudent(uid, studentIds)
    : false;

  if (!isTeacher && !isStudent && !isAdmin && !isParent) {
    throw new HttpsError('permission-denied', 'You are not allowed to join this class');
  }

  const resolvedRole = _resolveClassroomRole({
    activeRole,
    isTeacher,
    isStudent,
    isAdmin,
    isParent,
  });
  if (resolvedRole === 'student' && await isStudentAccessSuspended(uid)) {
    throw new HttpsError(
      'permission-denied',
      'Class access is suspended because of an outstanding unpaid invoice.',
    );
  }
  return resolvedRole;
};

const getUserDisplayName = async (uid, fallback = 'Participant') => {
  if (!uid) return fallback;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return fallback;
    const data = userDoc.data() || {};
    const fullName = [data.first_name || data.firstName, data.last_name || data.lastName]
      .filter(Boolean)
      .join(' ')
      .trim();
    return fullName || data['e-mail'] || data.email || fallback;
  } catch (_) {
    return fallback;
  }
};

const _deriveShiftDisplayName = (shiftData) => {
  const candidates = [
    shiftData.custom_name,
    shiftData.customName,
    shiftData.auto_generated_name,
    shiftData.autoGeneratedName,
    shiftData.shift_title,
    shiftData.shiftTitle,
    shiftData.subject_display_name,
    shiftData.subjectDisplayName,
  ];
  for (const candidate of candidates) {
    const value = String(candidate || '').trim();
    if (value) return value;
  }
  return 'Class';
};

const _joinWindowForShift = (shiftData, nowMs = Date.now()) => {
  const shiftStart = _toDate(shiftData.shift_start || shiftData.shiftStart);
  const shiftEnd = _toDate(shiftData.shift_end || shiftData.shiftEnd);
  const startMs = shiftStart?.getTime();
  const endMs = shiftEnd?.getTime();
  const allowedStartMs = Number.isFinite(startMs)
    ? startMs - JOIN_WINDOW_BEFORE_MS
    : nowMs - JOIN_WINDOW_BEFORE_MS;
  const allowedEndMs = Number.isFinite(endMs)
    ? endMs + JOIN_WINDOW_AFTER_MS
    : nowMs + 2 * 60 * 60 * 1000;

  return { allowedStartMs, allowedEndMs };
};

const assertJoinWindowOrThrow = (shiftData) => {
  const nowMs = Date.now();
  const { allowedStartMs, allowedEndMs } = _joinWindowForShift(shiftData, nowMs);

  if (nowMs < allowedStartMs) {
    const minutesUntil = Math.ceil((allowedStartMs - nowMs) / 60000);
    throw new HttpsError(
      'failed-precondition',
      `You can join 10 minutes before the class starts. Please wait ${minutesUntil} minute(s).`,
    );
  }
  if (nowMs > allowedEndMs) {
    throw new HttpsError('failed-precondition', 'The class window has ended');
  }
  return {
    allowedStartIso: new Date(allowedStartMs).toISOString(),
    allowedEndIso: new Date(allowedEndMs).toISOString(),
  };
};

const _isWithinJoinWindow = (shiftData, nowMs = Date.now()) => {
  const { allowedStartMs, allowedEndMs } = _joinWindowForShift(shiftData, nowMs);
  return nowMs >= allowedStartMs && nowMs <= allowedEndMs;
};

const getZoomShiftOrThrow = async (shiftId) => {
  const shiftRef = admin.firestore().collection('teaching_shifts').doc(shiftId);
  const shiftDoc = await shiftRef.get();
  if (!shiftDoc.exists) throw new HttpsError('not-found', 'Shift not found');

  const shiftData = shiftDoc.data() || {};
  const provider = String(shiftData.video_provider || shiftData.videoProvider || '')
    .trim()
    .toLowerCase();
  if (provider !== 'zoom') {
    throw new HttpsError('failed-precondition', 'This class is not configured for Zoom');
  }

  const teacherId = String(shiftData.teacher_id || shiftData.teacherId || '').trim();
  const studentIds = _normalizeUidList(shiftData.student_ids || shiftData.studentIds || []);
  const meetingId = String(shiftData.zoom_meeting_id || shiftData.zoomMeetingId || '').trim();

  return { shiftRef, shiftData, teacherId, studentIds, meetingId };
};

const _getZoomHostAccountForTeacher = async (teacherId, { required = true } = {}) => {
  const teacherDoc = await admin.firestore().collection('users').doc(teacherId).get();
  if (!teacherDoc.exists) {
    if (!required) return '';
    throw new HttpsError('failed-precondition', 'Teacher not found');
  }
  const data = teacherDoc.data() || {};
  const hostAccount = String(
    data.zoom_host_account ||
    data.zoomHostAccount ||
    data.zoom_host_email ||
    data.zoomHostEmail ||
    '',
  ).trim();
  if (!hostAccount) {
    if (!required) return '';
    throw new HttpsError(
      'failed-precondition',
      'Assign zoom_host_account before enabling Zoom for this teacher.',
    );
  }
  return hostAccount;
};

const _meetingDurationMinutes = (shiftData) => {
  const start = _toDate(shiftData.shift_start || shiftData.shiftStart);
  const end = _toDate(shiftData.shift_end || shiftData.shiftEnd);
  if (!start || !end || end <= start) return 60;
  return Math.max(
    1,
    Math.ceil((end.getTime() + JOIN_WINDOW_AFTER_MS - start.getTime()) / 60000),
  );
};

const _hostAccountCandidates = (hostAccount) => {
  const raw = String(hostAccount || '').trim();
  const lower = raw.toLowerCase();
  return Array.from(new Set([raw, lower].filter(Boolean)));
};

const _zoomClassroomHostAccounts = () => {
  const configured = String(process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  return Array.from(new Set((configured.length > 0
    ? configured
    : DEFAULT_ZOOM_CLASSROOM_HOST_ACCOUNTS).filter(Boolean)));
};

const _hashString = (value) => {
  const text = String(value || '');
  let hash = 0;
  for (let i = 0; i < text.length; i += 1) {
    hash = ((hash << 5) - hash) + text.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
};

const _shiftCategory = (shiftData) =>
  String(shiftData.category || shiftData.shift_category || 'teaching')
    .trim()
    .toLowerCase();

const _usesHubRouting = ({ shiftData, meetingId }) => {
  const mode = String(shiftData.zoomRoutingMode || shiftData.zoom_routing_mode || '')
    .trim()
    .toLowerCase();
  if (
    mode === 'single' ||
    shiftData.zoom_disable_hub_routing === true ||
    shiftData.zoomDisableHubRouting === true
  ) {
    return false;
  }
  if (String(shiftData.hubMeetingId || shiftData.hub_meeting_id || '').trim()) {
    return true;
  }
  if (mode === 'hub' || mode === 'hybrid' || mode === 'selfselect') {
    return true;
  }
  return _shiftCategory(shiftData) === 'teaching';
};

const _parseBoundaryMinutes = (value) => {
  const match = String(value || '').trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
};

const _normalizeHubBoundaries = (raw) => {
  const source = Array.isArray(raw) ? raw : String(raw || '').split(',');
  const minutes = source
    .map(_parseBoundaryMinutes)
    .filter((item) => Number.isFinite(item))
    .sort((a, b) => a - b);
  const unique = Array.from(new Set(minutes));
  return unique.length >= 2
    ? unique
    : ZOOM_HUB_DEFAULT_BOUNDARIES.map(_parseBoundaryMinutes);
};

const _formatBoundaryMinutes = (minutes) => {
  const hour = Math.floor(minutes / 60);
  const minute = minutes % 60;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
};

const _loadZoomHubBlockConfig = async () => {
  let data = {};
  try {
    const doc = await admin.firestore()
      .collection('system_settings')
      .doc('zoom_hub_blocks')
      .get();
    data = doc.exists ? doc.data() || {} : {};
  } catch (_) {
    data = {};
  }
  const timezone = String(
    data.timezone ||
    data.timeZone ||
    process.env.ZOOM_HUB_TIMEZONE ||
    ZOOM_HUB_DEFAULT_TIMEZONE,
  ).trim() || ZOOM_HUB_DEFAULT_TIMEZONE;
  const envBoundaries = process.env.ZOOM_HUB_BLOCK_BOUNDARIES;
  const boundaries = _normalizeHubBoundaries(
    data.boundaries ||
    data.block_boundaries ||
    data.blockBoundaries ||
    envBoundaries ||
    ZOOM_HUB_DEFAULT_BOUNDARIES,
  );
  const concurrentMeetingsPerUser = Number(
    data.concurrent_meetings_per_user ||
    data.concurrentMeetingsPerUser ||
    process.env.ZOOM_HUB_CONCURRENT_MEETINGS_PER_USER ||
    1,
  );
  return {
    timezone,
    boundaries,
    boundaryLabels: boundaries.map(_formatBoundaryMinutes),
    concurrentMeetingsPerUser: Number.isFinite(concurrentMeetingsPerUser)
      ? Math.max(1, concurrentMeetingsPerUser)
      : 1,
  };
};

const _dateTimeAtBoundary = (dateTime, minutes) =>
  dateTime.startOf('day').plus({ minutes });

const _blockForShift = (shiftData, config) => {
  const startDate = _toDate(shiftData.shift_start || shiftData.shiftStart) || new Date();
  const zone = config.timezone || ZOOM_HUB_DEFAULT_TIMEZONE;
  const start = DateTime.fromJSDate(startDate).setZone(zone);
  const boundaries = config.boundaries || _normalizeHubBoundaries(ZOOM_HUB_DEFAULT_BOUNDARIES);
  const minuteOfDay = start.hour * 60 + start.minute;
  let blockIndex;
  let blockStart;
  let blockEnd;

  if (minuteOfDay < boundaries[0]) {
    blockIndex = boundaries.length;
    blockStart = _dateTimeAtBoundary(start.minus({ days: 1 }), boundaries[boundaries.length - 1]);
    blockEnd = _dateTimeAtBoundary(start, boundaries[0]);
  } else {
    const nextIndex = boundaries.findIndex((minutes) => minuteOfDay < minutes);
    if (nextIndex === -1) {
      blockIndex = boundaries.length;
      blockStart = _dateTimeAtBoundary(start, boundaries[boundaries.length - 1]);
      blockEnd = _dateTimeAtBoundary(start.plus({ days: 1 }), boundaries[0]);
    } else {
      blockIndex = nextIndex;
      blockStart = _dateTimeAtBoundary(start, boundaries[nextIndex - 1]);
      blockEnd = _dateTimeAtBoundary(start, boundaries[nextIndex]);
    }
  }

  return {
    blockIndex,
    blockStart: blockStart.toJSDate(),
    blockEnd: blockEnd.toJSDate(),
    dayKey: blockStart.toISODate(),
    timezone: zone,
  };
};

const _truncate = (value, maxLength) => {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (text.length <= maxLength) return text;
  return text.slice(0, Math.max(0, maxLength - 3)).trimEnd() + '...';
};

const _formatTimeForRoom = (shiftData) => {
  const start = _toDate(shiftData.shift_start || shiftData.shiftStart);
  if (!start) return '';
  return start.toISOString().slice(11, 16);
};

const _breakoutRoomNameForShift = (shiftId, shiftData) => {
  const teacherName = String(
    shiftData.teacher_name ||
    shiftData.teacherName ||
    'Teacher',
  ).trim();
  const studentNames = Array.isArray(shiftData.student_names)
    ? shiftData.student_names
    : Array.isArray(shiftData.studentNames)
      ? shiftData.studentNames
      : [];
  const students = studentNames.length > 0
    ? studentNames.slice(0, 2).join(', ')
    : 'Students';
  const suffix = studentNames.length > 2 ? ` +${studentNames.length - 2}` : '';
  const time = _formatTimeForRoom(shiftData);
  const shortId = String(shiftId || '').slice(-6);
  return _truncate(
    [shortId, teacherName, `${students}${suffix}`, time].filter(Boolean).join(' | '),
    30,
  );
};

const _laneIndexForShift = ({ shiftId, shiftData }) => {
  const override = Number(
    shiftData.zoom_hub_lane_index ??
    shiftData.zoomHubLaneIndex ??
    shiftData.zoom_hub_lane ??
    shiftData.zoomHubLane,
  );
  if (Number.isInteger(override) && override >= 0) return override;
  const hostAccounts = _zoomClassroomHostAccounts();
  const hashKey = String(shiftData.teacher_id || shiftData.teacherId || shiftId || '');
  return hostAccounts.length > 0 ? _hashString(hashKey) % hostAccounts.length : 0;
};

const _hubMetaForShift = async ({ shiftId, shiftData, forcedLaneIndex = null }) => {
  const config = await _loadZoomHubBlockConfig();
  const hostAccounts = _zoomClassroomHostAccounts();
  const laneIndex = Number.isInteger(forcedLaneIndex) && forcedLaneIndex >= 0
    ? forcedLaneIndex
    : _laneIndexForShift({ shiftId, shiftData });
  const hostAccount = hostAccounts[laneIndex] || DEFAULT_ZOOM_CLASSROOM_HOST_ACCOUNTS[0];
  const block = _blockForShift(shiftData, config);
  return {
    dayKey: block.dayKey,
    blockIndex: block.blockIndex,
    blockStart: block.blockStart,
    blockEnd: block.blockEnd,
    timezone: block.timezone,
    laneIndex,
    lane: laneIndex + 1,
    hostAccount,
    blockBoundaries: config.boundaryLabels,
    concurrentMeetingsPerUser: config.concurrentMeetingsPerUser,
    hubDocId: `zoom_hub_${block.dayKey}_${block.blockIndex}_${laneIndex + 1}`,
  };
};

const _mergeHubRoom = (rooms, room) => {
  const byShiftId = new Map();
  for (const item of Array.isArray(rooms) ? rooms : []) {
    if (!item || typeof item !== 'object') continue;
    const itemShiftId = String(item.shiftId || item.shift_id || '').trim();
    const itemName = String(item.name || '').trim();
    if (!itemShiftId || !itemName) continue;
    byShiftId.set(itemShiftId, {
      shiftId: itemShiftId,
      name: itemName,
      teacherId: String(item.teacherId || item.teacher_id || '').trim(),
      studentIds: _normalizeUidList(item.studentIds || item.student_ids || []),
      visitorIds: _normalizeUidList(item.visitorIds || item.visitor_ids || []),
      ...(item.spare === true ? { spare: true } : {}),
    });
  }
  const existing = byShiftId.get(room.shiftId) || {};
  byShiftId.set(room.shiftId, {
    ...existing,
    ...room,
    studentIds: _normalizeUidList([
      ..._normalizeUidList(existing.studentIds || existing.student_ids || []),
      ..._normalizeUidList(room.studentIds || room.student_ids || []),
    ]),
    visitorIds: _normalizeUidList([
      ..._normalizeUidList(existing.visitorIds || existing.visitor_ids || []),
      ..._normalizeUidList(room.visitorIds || room.visitor_ids || []),
    ]),
  });
  return Array.from(byShiftId.values()).sort((a, b) => a.name.localeCompare(b.name));
};

const _hubRoomsForJoiningUser = ({ rooms, targetRoomName, uid }) => {
  const userId = String(uid || '').trim();
  const targetName = String(targetRoomName || '').trim();
  if (!userId || !targetName || !Array.isArray(rooms)) return rooms || [];

  return rooms.map((room) => {
    const name = String(room?.name || '').trim();
    if (name !== targetName) return room;

    const teacherId = String(room.teacherId || room.teacher_id || '').trim();
    const studentIds = _normalizeUidList(room.studentIds || room.student_ids || []);
    const visitorIds = _normalizeUidList(room.visitorIds || room.visitor_ids || []);
    if (teacherId === userId || studentIds.includes(userId) || visitorIds.includes(userId)) return room;

    return {
      ...room,
      studentIds,
      visitorIds: [...visitorIds, userId],
    };
  });
};

const _targetHubRoomForJoin = ({ rooms, shiftId, roomName, uid }) => {
  const targetShiftId = String(shiftId || '').trim();
  const targetName = String(roomName || '').trim();
  const userId = String(uid || '').trim();
  const baseRooms = Array.isArray(rooms) ? rooms : [];

  const roomsWithVisitor = baseRooms.map((room) => {
    const roomShiftId = String(room?.shiftId || room?.shift_id || '').trim();
    const name = String(room?.name || '').trim();
    const isTarget = (targetShiftId && roomShiftId === targetShiftId) ||
      (!targetShiftId && targetName && name === targetName);
    if (!isTarget || !userId) return room;

    const teacherId = String(room.teacherId || room.teacher_id || '').trim();
    const studentIds = _normalizeUidList(room.studentIds || room.student_ids || []);
    const visitorIds = _normalizeUidList(room.visitorIds || room.visitor_ids || []);
    if (teacherId === userId || studentIds.includes(userId) || visitorIds.includes(userId)) return room;

    return {
      ...room,
      studentIds,
      visitorIds: [...visitorIds, userId],
    };
  });

  const targetRoom = roomsWithVisitor.find((room) => {
    const roomShiftId = String(room?.shiftId || room?.shift_id || '').trim();
    const name = String(room?.name || '').trim();
    return (targetShiftId && roomShiftId === targetShiftId) ||
      (!targetShiftId && targetName && name === targetName);
  }) || null;

  return {
    rooms: roomsWithVisitor,
    targetRoom,
  };
};

const _zoomBreakoutSettingsForRooms = (rooms) => ({
  breakout_room: {
    enable: true,
    rooms: rooms.map((room) => ({
      name: room.name,
      participants: [],
    })),
  },
});

const _zoomClassroomMeetingSettings = (extraSettings = {}) => ({
  host_video: true,
  participant_video: true,
  join_before_host: true,
  jbh_time: 0,
  waiting_room: false,
  mute_upon_entry: false,
  approval_type: 2,
  registration_type: 1,
  meeting_authentication: false,
  audio: 'both',
  auto_recording: 'none',
  ...extraSettings,
});

const _zoomMeetingStatus = (meeting) =>
  String(meeting?.status || '').trim().toLowerCase();

const _isStartedZoomMeeting = (meeting) =>
  _zoomMeetingStatus(meeting) === 'started';

const _getTeacherIdsForZoomHost = async ({ db, hostAccount, currentTeacherId }) => {
  const teacherIds = new Set([currentTeacherId].filter(Boolean));
  const fields = [
    'zoom_host_account',
    'zoomHostAccount',
    'zoom_host_email',
    'zoomHostEmail',
    'email',
    'e-mail',
  ];

  for (const field of fields) {
    for (const candidate of _hostAccountCandidates(hostAccount)) {
      try {
        const snap = await db.collection('users')
          .where(field, '==', candidate)
          .get();
        snap.docs.forEach((doc) => {
          const data = doc.data() || {};
          if (_isTeacherRecord(data)) teacherIds.add(doc.id);
        });
      } catch (_) {
        // Some legacy fields may not be indexed in every environment.
      }
    }
  }

  return Array.from(teacherIds);
};

const _findStartedZoomHostConflict = async ({
  currentShiftId,
  currentTeacherId,
  hostAccount,
}) => {
  const db = admin.firestore();
  const teacherIds = await _getTeacherIdsForZoomHost({
    db,
    hostAccount,
    currentTeacherId,
  });
  const now = new Date();
  const nowMs = now.getTime();
  const lookback = admin.firestore.Timestamp.fromDate(
    new Date(nowMs - ZOOM_HOST_CONFLICT_LOOKBACK_MS),
  );
  const maxStartMs = nowMs + JOIN_WINDOW_BEFORE_MS;

  for (const teacherId of teacherIds) {
    const snap = await db.collection('teaching_shifts')
      .where('teacher_id', '==', teacherId)
      .where('shift_start', '>=', lookback)
      .get();

    for (const doc of snap.docs) {
      if (doc.id === currentShiftId) continue;
      const data = doc.data() || {};
      const provider = String(data.video_provider || data.videoProvider || '')
        .trim()
        .toLowerCase();
      const meetingId = String(data.zoom_meeting_id || data.zoomMeetingId || '')
        .trim();
      if (provider !== 'zoom' || !meetingId) continue;

      const shiftStart = _toDate(data.shift_start || data.shiftStart);
      if (shiftStart && shiftStart.getTime() > maxStartMs) continue;

      let meeting;
      try {
        meeting = await zoomClient.getMeeting(meetingId);
      } catch (err) {
        console.warn('[Zoom] Conflict meeting lookup failed:', meetingId, err.message);
        continue;
      }

      const status = String(meeting?.status || '').trim().toLowerCase();
      if (status !== 'started') continue;

      const inJoinWindow = _isWithinJoinWindow(data, nowMs);
      if (!inJoinWindow && typeof zoomClient.endMeeting === 'function') {
        try {
          await zoomClient.endMeeting(meetingId);
          continue;
        } catch (err) {
          console.warn('[Zoom] Failed to end stale meeting:', meetingId, err.message);
        }
      }

      return {
        shiftId: doc.id,
        meetingId,
        shiftName: _deriveShiftDisplayName(data),
        teacherName: data.teacher_name || data.teacherName || '',
        inJoinWindow,
      };
    }
  }

  return null;
};

const ensureZoomHostClassroomSettings = async (hostAccount) => {
  if (typeof zoomClient.updateUserSettings !== 'function') return;
  try {
    await zoomClient.updateUserSettings(hostAccount, {
      in_meeting: {
        // Everyone (teacher/student/parent/admin) must be able to share their
        // screen. In the hub model all humans are participants (role 0; only the
        // bot is host), so participant sharing must be fully enabled:
        screen_sharing: true,
        who_can_share_screen: 'all',
        // ...even while someone else is already sharing (otherwise only the host
        // — the bot, which isn't in the breakout room — could share, blocking a
        // teacher whose student is presenting).
        who_can_share_screen_when_someone_is_sharing: 'all',
        disable_screen_sharing_for_hosts_meetings: false,
        disable_screen_sharing_for_in_meeting_guests: false,
      },
    });
  } catch (err) {
    console.warn(
      '[Zoom] Unable to update host classroom sharing settings; continuing join:',
      err.message,
    );
  }
};

const ensureZoomMeeting = async ({ shiftRef, shiftData, meetingId, hostAccount }) => {
  if (meetingId) {
    try {
      const meeting = await zoomClient.getMeeting(meetingId);
      if (typeof zoomClient.updateMeeting === 'function') {
        try {
          await zoomClient.updateMeeting(meetingId, {
            settings: _zoomClassroomMeetingSettings(),
          });
        } catch (err) {
          console.warn('[Zoom] Unable to normalize stored meeting settings:', err.message);
        }
      }
      return meeting;
    } catch (err) {
      console.warn('[Zoom] Stored meeting lookup failed; creating a new one:', err.message);
    }
  }

  const shiftStart = _toDate(shiftData.shift_start || shiftData.shiftStart);
  const meeting = await zoomClient.createMeeting(hostAccount, {
    topic: _deriveShiftDisplayName(shiftData),
    type: 2,
    start_time: shiftStart ? shiftStart.toISOString() : new Date().toISOString(),
    duration: _meetingDurationMinutes(shiftData),
    timezone: shiftData.admin_timezone || shiftData.adminTimezone || 'UTC',
    settings: _zoomClassroomMeetingSettings(),
  });
  const nextMeetingId = String(meeting?.id || '').trim();
  if (!nextMeetingId) throw new Error('Zoom did not return a meeting ID');

  await shiftRef.set({
    zoom_meeting_id: nextMeetingId,
    zoom_meeting_number: nextMeetingId,
    zoom_password: meeting.password || '',
    zoom_join_url: meeting.join_url || meeting.joinUrl || '',
    zoom_host_email: meeting.host_email || hostAccount,
    zoom_created_at: admin.firestore.FieldValue.serverTimestamp(),
    zoom_meeting_created_at: admin.firestore.FieldValue.serverTimestamp(),
    zoom_updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return meeting;
};

const _spareRoomNames = () =>
  Array.from({ length: ZOOM_HUB_SPARE_ROOM_COUNT }, (_, index) => `Spare ${index + 1}`);

const _isSpareRoom = (room) =>
  room?.spare === true || /^Spare \d+$/i.test(String(room?.name || '').trim());

const _classRoomsOnly = (rooms) =>
  (Array.isArray(rooms) ? rooms : []).filter((room) => {
    const shiftId = String(room?.shiftId || room?.shift_id || '').trim();
    if (!shiftId || shiftId.startsWith('__spare_')) return false;
    return true;
  });

const _withSpareRooms = (rooms) => {
  let merged = Array.isArray(rooms) ? rooms : [];
  for (const [index, name] of _spareRoomNames().entries()) {
    const spareNameExists = merged.some((room) =>
      String(room?.name || '').trim().toLowerCase() === name.toLowerCase());
    if (spareNameExists) continue;
    merged = _mergeHubRoom(merged, {
      shiftId: `__spare_${index + 1}`,
      name,
      teacherId: '',
      studentIds: [],
      spare: true,
    });
  }
  return merged;
};

const _roomNameFromShift = (shiftId, shiftData) => {
  const stored = String(
    shiftData.breakoutRoomName ||
    shiftData.breakout_room_name ||
    '',
  ).trim();
  return stored || _breakoutRoomNameForShift(shiftId, shiftData);
};

const _roomForShift = (shiftId, shiftData, nameOverride = '') => ({
  shiftId,
  name: String(nameOverride || _roomNameFromShift(shiftId, shiftData)).trim(),
  teacherId: String(shiftData.teacher_id || shiftData.teacherId || '').trim(),
  studentIds: _normalizeUidList(shiftData.student_ids || shiftData.studentIds || []),
});

const _hubWindowForShiftDocs = (shiftDocs) => {
  const starts = [];
  const ends = [];
  for (const doc of shiftDocs) {
    const data = doc.data ? doc.data() || {} : doc.data || {};
    const start = _toDate(data.shift_start || data.shiftStart);
    const end = _toDate(data.shift_end || data.shiftEnd);
    if (start) starts.push(start.getTime());
    if (end) ends.push(end.getTime());
  }
  const now = Date.now();
  const firstStartMs = starts.length ? Math.min(...starts) : now;
  const lastEndMs = ends.length ? Math.max(...ends) : firstStartMs + 60 * 60 * 1000;
  const windowStart = new Date(firstStartMs - ZOOM_HUB_WINDOW_PADDING_MS);
  const windowEnd = new Date(lastEndMs + ZOOM_HUB_WINDOW_PADDING_MS);
  const duration = Math.max(1, Math.ceil((windowEnd.getTime() - windowStart.getTime()) / 60000));
  return { windowStart, windowEnd, duration };
};

const _hubWindowExceedsSafeZoomLifetime = (windowInfo) =>
  Number(windowInfo?.duration || 0) > ZOOM_HUB_SAFE_MAX_MEETING_MINUTES;

const _queryZoomShiftDocsForHubBlock = async (meta) => {
  const snapshot = await admin.firestore().collection('teaching_shifts')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(meta.blockStart))
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(meta.blockEnd))
    .get();

  const docs = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const provider = String(data.video_provider || data.videoProvider || '')
      .trim()
      .toLowerCase();
    const meetingId = String(data.zoom_meeting_id || data.zoomMeetingId || '').trim();
    if (provider !== 'zoom') continue;
    if (!_usesHubRouting({ shiftData: data, meetingId })) continue;
    if (_laneIndexForShift({ shiftId: doc.id, shiftData: data }) !== meta.laneIndex) continue;
    docs.push(doc);
  }
  return docs.sort((a, b) => {
    const aData = a.data() || {};
    const bData = b.data() || {};
    const aStart = _toDate(aData.shift_start || aData.shiftStart)?.getTime() || 0;
    const bStart = _toDate(bData.shift_start || bData.shiftStart)?.getTime() || 0;
    if (aStart !== bStart) return aStart - bStart;
    return a.id.localeCompare(b.id);
  });
};

const _buildHubRoomsForBlock = async ({ meta, targetShiftId, targetShiftData, hubData }) => {
  const docs = await _queryZoomShiftDocsForHubBlock(meta);
  const byShiftId = new Map();
  for (const doc of docs) byShiftId.set(doc.id, doc.data() || {});
  if (targetShiftId && targetShiftData) byShiftId.set(targetShiftId, targetShiftData);
  const hubStatus = String(hubData?.status || '').trim();
  const hubAlreadyOpen = hubStatus === 'roomsOpen';

  if (hubAlreadyOpen) {
    let rooms = _withSpareRooms(Array.isArray(hubData?.rooms) ? hubData.rooms : []);
    const targetRoom = rooms.find((room) => room.shiftId === targetShiftId) || null;
    if (targetShiftId && targetShiftData && !targetRoom) {
      const spares = hubData?.spares && typeof hubData.spares === 'object' ? hubData.spares : {};
      const spareName = _spareRoomNames().find((name, index) => {
        const room = rooms.find((item) =>
          String(item?.name || '').trim().toLowerCase() === name.toLowerCase());
        if (!room) return false;
        const recordedShiftId = String(spares[name] || '').trim();
        const roomShiftId = String(room.shiftId || room.shift_id || '').trim();
        const placeholderShiftId = `__spare_${index + 1}`;
        const roomIsFree = !roomShiftId || roomShiftId === placeholderShiftId || roomShiftId === targetShiftId;
        const spareIsFree = !recordedShiftId || recordedShiftId === targetShiftId;
        return roomIsFree && spareIsFree;
      });
      if (spareName) {
        rooms = rooms.map((room) =>
          String(room?.name || '').trim().toLowerCase() === spareName.toLowerCase()
            ? { ..._roomForShift(targetShiftId, targetShiftData, spareName), spare: true }
            : room);
        return {
          rooms,
          targetRoom: rooms.find((room) => room.shiftId === targetShiftId) || null,
          overflowShiftIds: [],
          assignedSpareName: spareName,
          shiftDocs: docs,
        };
      }
    }

    return {
      rooms,
      targetRoom,
      overflowShiftIds: targetRoom ? [] : [targetShiftId].filter(Boolean),
      assignedSpareName: '',
      shiftDocs: docs,
    };
  }

  const maxClassRooms = ZOOM_HUB_MAX_ROOM_COUNT - ZOOM_HUB_SPARE_ROOM_COUNT;
  const classRooms = Array.from(byShiftId.entries())
    .sort((first, second) => {
      const firstStart = _toDate(first[1].shift_start || first[1].shiftStart)?.getTime() || 0;
      const secondStart = _toDate(second[1].shift_start || second[1].shiftStart)?.getTime() || 0;
      if (firstStart !== secondStart) return firstStart - secondStart;
      return first[0].localeCompare(second[0]);
    })
    .map(([shiftId, data]) => _roomForShift(shiftId, data));

  const overflowShiftIds = classRooms.slice(maxClassRooms).map((room) => room.shiftId);
  const trimmedClassRooms = classRooms.slice(0, maxClassRooms);
  let rooms = _withSpareRooms(trimmedClassRooms);

  const targetRoom = rooms.find((room) => room.shiftId === targetShiftId) || null;

  return {
    rooms,
    targetRoom,
    overflowShiftIds,
    assignedSpareName: '',
    shiftDocs: docs,
  };
};

const _alertBodyLines = (fields) =>
  Object.entries(fields || {})
    .filter(([, value]) => value !== null && value !== undefined && String(value).trim())
    .map(([key, value]) => `${key}: ${value}`);

const _escapeHtml = (value) =>
  String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const _collectZoomAdminNotificationTargets = async () => {
  const snapshot = await admin.firestore()
    .collection('users')
    .where('role', '==', 'admin')
    .get();
  const emails = [];
  const tokens = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const email = String(data.email || data['e-mail'] || '').trim();
    if (email) emails.push(email);
    const fcmToken = String(data.fcmToken || data.fcm_token || '').trim();
    if (fcmToken) tokens.push(fcmToken);
  }
  return {
    emails: Array.from(new Set(emails)),
    tokens: Array.from(new Set(tokens)),
  };
};

const _sendZoomHubAdminAlert = async ({
  alertId,
  reason,
  title,
  body,
  severity = 'critical',
  data = {},
}) => {
  const db = admin.firestore();
  const normalizedAlertId = String(alertId || '').trim() ||
    `zoom_hub_${reason || 'alert'}_${Date.now()}`;
  const alertRef = db.collection('system_alerts').doc(normalizedAlertId);
  const existingDoc = await alertRef.get().catch(() => null);
  const existing = existingDoc?.exists ? existingDoc.data() || {} : {};

  await alertRef.set({
    type: 'zoom_hub',
    severity,
    reason,
    title,
    body,
    data,
    acknowledged: false,
    created_at: existing.created_at || admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  if (existing.notification_sent_at) return;

  try {
    const targets = await _collectZoomAdminNotificationTargets();
    if (targets.emails.length > 0) {
      const transporter = createTransporter();
      await transporter.sendMail({
        from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
        to: targets.emails.join(', '),
        subject: title,
        html: `
          <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #111827;">
            <h2 style="margin: 0 0 12px;">${_escapeHtml(title)}</h2>
            <p>${_escapeHtml(body)}</p>
            <ul>
              ${_alertBodyLines(data).map((line) => `<li>${_escapeHtml(line)}</li>`).join('')}
            </ul>
          </div>
        `,
      });
    }
    if (targets.tokens.length > 0 && admin.messaging) {
      await admin.messaging().sendEachForMulticast({
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries({
            type: 'zoom_hub_alert',
            reason,
            ...data,
          }).map(([key, value]) => [key, String(value ?? '')]),
        ),
        tokens: targets.tokens,
      });
    }
    await alertRef.set({
      notification_sent_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (err) {
    console.error('[ZoomHub] Failed to send admin alert:', err);
    await alertRef.set({
      notification_error: err.message || String(err),
    }, { merge: true });
  }
};

const _zoomHubOverflowAlertData = ({ shiftId, shiftData, reason, meta }) => ({
  shiftId,
  shiftName: _deriveShiftDisplayName(shiftData),
  teacherId: shiftData.teacher_id || shiftData.teacherId || '',
  teacherName: shiftData.teacher_name || shiftData.teacherName || '',
  reason,
  hubDocId: meta?.hubDocId || '',
  lane: meta?.lane || '',
  blockIndex: meta?.blockIndex || '',
  dayKey: meta?.dayKey || '',
});

const _fallBackToSingleZoomMeeting = async ({
  shiftRef,
  shiftData,
  shiftId,
  meetingId,
  reason,
  meta,
}) => {
  const teacherId = String(shiftData.teacher_id || shiftData.teacherId || '').trim();
  const hostAccount = await _getZoomHostAccountForTeacher(teacherId, { required: false });
  await _sendZoomHubAdminAlert({
    alertId: `${shiftId}_${reason}`,
    reason,
    title: 'Critical Zoom hub routing fallback',
    body: `${_deriveShiftDisplayName(shiftData)} could not fit in the Zoom hub and was moved to single Zoom mode.`,
    data: _zoomHubOverflowAlertData({ shiftId, shiftData, reason, meta }),
  });
  if (!hostAccount) {
    throw new HttpsError(
      'resource-exhausted',
      'This Zoom hub is full and this teacher has no single Zoom host account configured.',
    );
  }
  const meeting = await ensureZoomMeeting({
    shiftRef,
    shiftData,
    meetingId,
    hostAccount,
  });
  await shiftRef.set({
    zoomRoutingMode: 'single',
    zoom_routing_mode: 'single',
    zoom_disable_hub_routing: true,
    zoom_hub_fallback_reason: reason,
    zoom_updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return {
    meeting,
    hostAccount,
    routingMode: 'single',
    hubMeetingId: null,
    breakoutRoomName: '',
    breakoutRooms: [],
    targetRoom: null,
    fallbackReason: reason,
  };
};

const ensureZoomHubMeeting = async ({
  shiftRef,
  shiftData,
  shiftId,
  forcedLaneIndex = null,
  allowOverflowSpill = true,
}) => {
  const db = admin.firestore();
  const meta = await _hubMetaForShift({ shiftId, shiftData, forcedLaneIndex });
  const hubRef = db.collection('hub_meetings').doc(meta.hubDocId);

  let hubDoc = await hubRef.get();
  let hubData = hubDoc.exists ? hubDoc.data() || {} : {};
  const roomPlan = await _buildHubRoomsForBlock({
    meta,
    targetShiftId: shiftId,
    targetShiftData: shiftData,
    hubData,
  });
  if (!roomPlan.targetRoom) {
    const hostAccounts = _zoomClassroomHostAccounts();
    if (allowOverflowSpill && hostAccounts.length > 1) {
      const alternateLaneIndexes = hostAccounts
        .map((_, index) => index)
        .filter((index) => index !== meta.laneIndex);
      for (const alternateLaneIndex of alternateLaneIndexes) {
        try {
          const spilled = await ensureZoomHubMeeting({
            shiftRef,
            shiftData: {
              ...shiftData,
              zoom_hub_lane_index: alternateLaneIndex,
              zoomHubLaneIndex: alternateLaneIndex,
            },
            shiftId,
            forcedLaneIndex: alternateLaneIndex,
            allowOverflowSpill: false,
          });
          if (spilled.routingMode !== 'hub') return spilled;
          await shiftRef.set({
            zoom_hub_lane_index: alternateLaneIndex,
            zoomHubLaneIndex: alternateLaneIndex,
            zoom_hub_overflow_from_lane: meta.laneIndex,
            zoom_hub_overflow_at: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          await _sendZoomHubAdminAlert({
            alertId: `${shiftId}_spilled_to_lane_${alternateLaneIndex + 1}`,
            reason: 'spilled_to_other_lane',
            title: 'Zoom hub class moved to another lane',
            body: `${_deriveShiftDisplayName(shiftData)} overflowed lane ${meta.lane} and was routed to lane ${alternateLaneIndex + 1}.`,
            severity: 'warning',
            data: {
              ..._zoomHubOverflowAlertData({
                shiftId,
                shiftData,
                reason: 'spilled_to_other_lane',
                meta,
              }),
              targetLane: alternateLaneIndex + 1,
            },
          });
          return spilled;
        } catch (err) {
          if (err instanceof HttpsError && err.code !== 'resource-exhausted') throw err;
          if (!(err instanceof HttpsError)) console.warn('[ZoomHub] Alternate lane spill failed:', err);
        }
      }
    }
    return _fallBackToSingleZoomMeeting({
      shiftRef,
      shiftData,
      shiftId,
      meetingId: String(shiftData.zoom_meeting_id || shiftData.zoomMeetingId || '').trim(),
      reason: hubData?.status === 'roomsOpen' ? 'spares_exhausted' : 'room_cap_exceeded',
      meta,
    });
  }
  const rooms = roomPlan.rooms;
  const roomName = roomPlan.targetRoom.name;
  const windowInfo = _hubWindowForShiftDocs([
    ...roomPlan.shiftDocs,
    { id: shiftId, data: () => shiftData },
  ]);
  if (_hubWindowExceedsSafeZoomLifetime(windowInfo)) {
    return _fallBackToSingleZoomMeeting({
      shiftRef,
      shiftData,
      shiftId,
      meetingId: String(shiftData.zoom_meeting_id || shiftData.zoomMeetingId || '').trim(),
      reason: 'hub_window_exceeds_zoom_lifetime',
      meta,
    });
  }
  let meetingId = String(
    hubData.zoom_meeting_id ||
    hubData.zoomMeetingId ||
    hubData.meetingNumber ||
    hubData.meeting_number ||
    '',
  ).trim();
  let createdMeeting = null;

  if (!meetingId) {
    // Enforce "everyone can share their screen" on the host account BEFORE the
    // hub meeting is created — Zoom applies these settings at meeting-start, so
    // setting them only at join time is too late for a long-running hub.
    await ensureZoomHostClassroomSettings(meta.hostAccount);
    createdMeeting = await zoomClient.createMeeting(meta.hostAccount, {
      topic: `Alluwal Classrooms ${meta.dayKey} Block ${meta.blockIndex} Lane ${meta.lane}`,
      type: 2,
      start_time: windowInfo.windowStart.toISOString(),
      duration: windowInfo.duration,
      timezone: meta.timezone,
      settings: _zoomClassroomMeetingSettings({
        breakout_room: {
          enable: true,
          rooms: [],
        },
      }),
    });

    const createdMeetingId = String(createdMeeting?.id || '').trim();
    if (!createdMeetingId) throw new Error('Zoom did not return a hub meeting ID');
    meetingId = createdMeetingId;

    let shouldUseCreatedMeeting = true;
    await db.runTransaction(async (tx) => {
      const current = await tx.get(hubRef);
      const currentData = current.exists ? current.data() || {} : {};
      const currentMeetingId = String(
        currentData.zoom_meeting_id ||
        currentData.zoomMeetingId ||
        currentData.meetingNumber ||
        '',
      ).trim();
      if (currentMeetingId) {
        hubData = currentData;
        meetingId = currentMeetingId;
        shouldUseCreatedMeeting = false;
        return;
      }
      tx.set(hubRef, {
        dayKey: meta.dayKey,
        blockIndex: meta.blockIndex,
        block_start: admin.firestore.Timestamp.fromDate(meta.blockStart),
        block_end: admin.firestore.Timestamp.fromDate(meta.blockEnd),
        window_start: admin.firestore.Timestamp.fromDate(windowInfo.windowStart),
        window_end: admin.firestore.Timestamp.fromDate(windowInfo.windowEnd),
        laneIndex: meta.laneIndex,
        lane: meta.lane,
        hostAccount: meta.hostAccount,
        zoom_meeting_id: createdMeetingId,
        meetingNumber: createdMeetingId,
        zoom_password: createdMeeting.password || '',
        zoom_join_url: createdMeeting.join_url || createdMeeting.joinUrl || '',
        status: 'scheduled',
        rooms,
        room_count: rooms.length,
        overflow_shift_ids: roomPlan.overflowShiftIds,
        spares: Object.fromEntries(_spareRoomNames().map((name) => [name, null])),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      hubData = {
        dayKey: meta.dayKey,
        blockIndex: meta.blockIndex,
        block_start: admin.firestore.Timestamp.fromDate(meta.blockStart),
        block_end: admin.firestore.Timestamp.fromDate(meta.blockEnd),
        window_start: admin.firestore.Timestamp.fromDate(windowInfo.windowStart),
        window_end: admin.firestore.Timestamp.fromDate(windowInfo.windowEnd),
        laneIndex: meta.laneIndex,
        lane: meta.lane,
        hostAccount: meta.hostAccount,
        zoom_meeting_id: createdMeetingId,
        meetingNumber: createdMeetingId,
        zoom_password: createdMeeting.password || '',
        zoom_join_url: createdMeeting.join_url || createdMeeting.joinUrl || '',
        rooms,
      };
    });

    if (!shouldUseCreatedMeeting && typeof zoomClient.deleteMeeting === 'function') {
      try {
        await zoomClient.deleteMeeting(createdMeetingId);
      } catch (err) {
        console.warn('[Zoom] Unable to delete duplicate hub meeting:', err.message);
      }
      createdMeeting = null;
    }
  }

  const nextSpares = {
    ...(Object.fromEntries(_spareRoomNames().map((name) => [name, null]))),
    ...(hubData.spares && typeof hubData.spares === 'object' ? hubData.spares : {}),
  };
  if (roomPlan.assignedSpareName) {
    nextSpares[roomPlan.assignedSpareName] = shiftId;
  }
  await hubRef.set({
    dayKey: meta.dayKey,
    blockIndex: meta.blockIndex,
    block_start: admin.firestore.Timestamp.fromDate(meta.blockStart),
    block_end: admin.firestore.Timestamp.fromDate(meta.blockEnd),
    window_start: admin.firestore.Timestamp.fromDate(windowInfo.windowStart),
    window_end: admin.firestore.Timestamp.fromDate(windowInfo.windowEnd),
    laneIndex: meta.laneIndex,
    lane: meta.lane,
    hostAccount: meta.hostAccount,
    zoom_meeting_id: meetingId,
    meetingNumber: meetingId,
    rooms,
    room_count: rooms.length,
    overflow_shift_ids: roomPlan.overflowShiftIds,
    spares: nextSpares,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  let batch = db.batch();
  let batchCount = 0;
  for (const room of _classRoomsOnly(rooms)) {
    if (!room.shiftId || String(room.shiftId).startsWith('__spare_')) continue;
    const ref = db.collection('teaching_shifts').doc(room.shiftId);
    batch.set(ref, {
      hubMeetingId: meta.hubDocId,
      hub_meeting_id: meta.hubDocId,
      zoomRoutingMode: 'hub',
      zoom_routing_mode: 'hub',
      breakoutRoomName: room.name,
      breakout_room_name: room.name,
      breakoutRoomKey: room.shiftId,
      breakout_room_key: room.shiftId,
      zoom_meeting_id: meetingId,
      zoom_meeting_number: meetingId,
      zoom_host_email: meta.hostAccount,
      zoom_host_account: meta.hostAccount,
      zoom_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    batchCount += 1;
    if (batchCount >= BATCH_WRITE_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }
  if (batchCount > 0) await batch.commit();

  if (typeof zoomClient.updateMeeting === 'function') {
    try {
      const hubStatus = String(hubData.status || '').trim();
      if (hubStatus !== 'roomsOpen') {
        await zoomClient.updateMeeting(meetingId, {
          settings: _zoomBreakoutSettingsForRooms(rooms),
        });
      }
    } catch (err) {
      console.warn('[Zoom] Unable to update hub breakout rooms; SDK automation will retry:', err.message);
    }
  }

  let meeting = createdMeeting;
  if (!meeting) {
    try {
      meeting = await zoomClient.getMeeting(meetingId);
    } catch (err) {
      console.warn('[Zoom] Hub meeting lookup failed; using stored hub data:', err.message);
      meeting = {};
    }
  }

  return {
    meeting: {
      ...meeting,
      id: meetingId,
      password: meeting?.password || hubData.zoom_password || '',
      join_url: meeting?.join_url || meeting?.joinUrl || hubData.zoom_join_url || '',
      host_email: meeting?.host_email || meta.hostAccount,
    },
    hostAccount: meta.hostAccount,
    routingMode: 'hub',
    hubMeetingId: meta.hubDocId,
    breakoutRoomName: roomName,
    breakoutRooms: rooms,
    targetRoom: roomPlan.targetRoom,
    // When everyone is removed (last class + 15 min). Drives the participant
    // "class ends in N minutes" countdown.
    classEndsAtIso: windowInfo.windowEnd.toISOString(),
    meta,
  };
};

const _writeZoomHubMember = async ({
  hubMeetingId,
  uid,
  userId,
  shiftId,
  role,
  displayName,
  realDisplayName,
  routingDisplayName,
}) => {
  if (!hubMeetingId || !uid || !shiftId) return;
  const baseDisplayName = String(realDisplayName || displayName || '').trim();
  const displayNameAliases = _zoomHubDisplayNameAliases({
    displayName,
    routingDisplayName,
    realDisplayName: baseDisplayName,
  });
  await admin.firestore()
    .collection('hub_meetings')
    .doc(hubMeetingId)
    .collection('members')
    .doc(uid)
    .set({
      uid,
      userId: userId || uid,
      user_id: userId || uid,
      shiftId,
      shift_id: shiftId,
      role,
      displayName,
      display_name: displayName,
      routingDisplayName: routingDisplayName || displayName,
      routing_display_name: routingDisplayName || displayName,
      displayNameAliases,
      display_name_aliases: displayNameAliases,
      realDisplayName: baseDisplayName,
      real_display_name: baseDisplayName,
      addedAt: admin.firestore.FieldValue.serverTimestamp(),
      added_at: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
};

const _zoomHubCustomerKey = ({ uid, shiftId }) => {
  const normalizedUid = String(uid || '').trim();
  const normalizedShiftId = String(shiftId || '').trim();
  if (!normalizedUid || !normalizedShiftId) return normalizedUid;
  const digest = crypto
    .createHash('sha256')
    .update(`${normalizedUid}:${normalizedShiftId}`)
    .digest('base64url')
    .slice(0, 24);
  return `zh_${digest}`;
};

const _zoomHubDisplayToken = (routingKey) =>
  String(routingKey || '').trim().replace(/^zh_/, '').slice(0, 8);

const _zoomHubRoutingDisplayName = ({ displayName, routingKey }) => {
  const base = String(displayName || '').replace(/\s+/g, ' ').trim() || 'Participant';
  const token = _zoomHubDisplayToken(routingKey);
  if (!token) return base;
  const suffix = `#${token}`;
  const maxBaseLength = Math.max(1, 64 - suffix.length - 1);
  return `${_truncate(base, maxBaseLength)} ${suffix}`;
};

const _zoomHubDisplayNameAliases = ({ displayName, routingDisplayName, realDisplayName }) => {
  const aliases = new Set();
  for (const value of [realDisplayName, displayName, routingDisplayName]) {
    const normalized = String(value || '').replace(/\s+/g, ' ').trim();
    if (normalized) aliases.add(normalized);
  }
  return Array.from(aliases);
};

const _zoomParticipantDisplayName = (participant) =>
  String(
    participant?.user_name ||
    participant?.userName ||
    participant?.displayName ||
    participant?.display_name ||
    participant?.name ||
    '',
  ).replace(/\s+/g, ' ').trim();

const _isZoomHubRoutingKey = (value) => String(value || '').trim().startsWith('zh_');

const _findHubMemberForRoutingKey = async ({ meetingId, routingKey }) => {
  const normalizedMeetingId = String(meetingId || '').trim();
  const normalizedRoutingKey = String(routingKey || '').trim();
  if (!normalizedMeetingId || !_isZoomHubRoutingKey(normalizedRoutingKey)) return null;

  const db = admin.firestore();
  const queries = [
    db.collection('hub_meetings').where('meetingNumber', '==', normalizedMeetingId),
    db.collection('hub_meetings').where('meeting_number', '==', normalizedMeetingId),
    db.collection('hub_meetings').where('zoom_meeting_id', '==', normalizedMeetingId),
  ];

  for (const query of queries) {
    const hubSnapshot = await query.get();
    for (const hubDoc of hubSnapshot.docs) {
      const memberDoc = await hubDoc.ref.collection('members').doc(normalizedRoutingKey).get();
      if (!memberDoc.exists) continue;
      const data = memberDoc.data() || {};
      const shiftId = String(data.shiftId || data.shift_id || '').trim();
      const userId = String(data.userId || data.user_id || '').trim();
      if (shiftId && userId) {
        return {
          hubDoc,
          shiftId,
          userId,
          realDisplayName: String(
            data.realDisplayName ||
            data.real_display_name ||
            data.displayName ||
            data.display_name ||
            '',
          ).trim(),
        };
      }
    }
  }
  return null;
};

const _findHubMemberForRoutingDisplayName = async ({ meetingId, displayName }) => {
  const normalizedMeetingId = String(meetingId || '').trim();
  const normalizedDisplayName = String(displayName || '').replace(/\s+/g, ' ').trim();
  if (!normalizedMeetingId || !normalizedDisplayName) return null;

  const db = admin.firestore();
  const matches = [];
  const seenMatches = new Set();
  const queries = [
    db.collection('hub_meetings').where('meetingNumber', '==', normalizedMeetingId),
    db.collection('hub_meetings').where('meeting_number', '==', normalizedMeetingId),
    db.collection('hub_meetings').where('zoom_meeting_id', '==', normalizedMeetingId),
  ];

  for (const query of queries) {
    const hubSnapshot = await query.get();
    for (const hubDoc of hubSnapshot.docs) {
      const membersSnapshot = await hubDoc.ref.collection('members').get();
      for (const memberDoc of membersSnapshot.docs) {
        const data = memberDoc.data() || {};
        const displayCandidates = [
          data.displayName,
          data.display_name,
          data.routingDisplayName,
          data.routing_display_name,
          ...(Array.isArray(data.displayNameAliases) ? data.displayNameAliases : []),
          ...(Array.isArray(data.display_name_aliases) ? data.display_name_aliases : []),
        ]
          .map((value) => String(value || '').replace(/\s+/g, ' ').trim())
          .filter(Boolean);
        if (!displayCandidates.includes(normalizedDisplayName)) continue;
        const shiftId = String(data.shiftId || data.shift_id || '').trim();
        const userId = String(data.userId || data.user_id || '').trim();
        if (shiftId && userId) {
          const matchKey = `${hubDoc.id}:${memberDoc.id}`;
          if (seenMatches.has(matchKey)) continue;
          seenMatches.add(matchKey);
          matches.push({
            hubDoc,
            shiftId,
            userId,
            realDisplayName: String(
              data.realDisplayName ||
              data.real_display_name ||
              data.displayName ||
              data.display_name ||
              '',
            ).trim(),
          });
        }
      }
    }
  }
  return matches.length === 1 ? matches[0] : null;
};

const _isoOrNull = (value) => {
  const date = _toDate(value);
  return date ? date.toISOString() : null;
};

const _numberOrZero = (value) => {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
};

const _normalizeZoomHubRooms = (rawRooms) =>
  (Array.isArray(rawRooms) ? rawRooms : [])
    .map((room) => ({
      shiftId: String(room?.shiftId || room?.shift_id || '').trim(),
      name: String(room?.name || '').trim(),
      spare: room?.spare === true ||
        String(room?.shiftId || room?.shift_id || '').startsWith('__spare_'),
    }))
    .filter((room) => room.name);

const _hubStatusValue = (hubData = {}) =>
  String(hubData.status || hubData.bot_status || '').trim();

const _hubStatusRelevantForDashboard = ({ hubData, now }) => {
  const nowMs = now.getTime();
  const start = _toDate(hubData.window_start || hubData.windowStart);
  const end = _toDate(hubData.window_end || hubData.windowEnd);
  const heartbeat = _toDate(hubData.heartbeat_at || hubData.heartbeatAt);
  const status = _hubStatusValue(hubData);
  if (start && end) {
    return start.getTime() <= nowMs + ZOOM_HUB_STATUS_LOOKAHEAD_MS &&
      end.getTime() >= nowMs - ZOOM_HUB_STATUS_LOOKBACK_MS;
  }
  if (heartbeat && heartbeat.getTime() >= nowMs - ZOOM_HUB_STATUS_LOOKBACK_MS) {
    return true;
  }
  return ['joined', 'roomsOpen', 'error', 'resetMeeting'].includes(status);
};

const _shiftTitleForRoutingStatus = (shiftData = {}, fallback = '') => {
  const hasShiftData = shiftData && Object.keys(shiftData).length > 0;
  const derived = hasShiftData ? _deriveShiftDisplayName(shiftData) : '';
  return derived && derived !== 'Class' ? derived : fallback || derived || 'Classroom';
};

const _shiftIsScheduledNow = ({ shiftData = {}, now }) => {
  const start = _toDate(shiftData.shift_start || shiftData.startTime || shiftData.start_time);
  const end = _toDate(shiftData.shift_end || shiftData.endTime || shiftData.end_time);
  if (!start || !end) return false;
  const nowMs = now.getTime();
  return start.getTime() <= nowMs && end.getTime() >= nowMs;
};

const _shiftStatusValue = (shiftData = {}) =>
  String(
    shiftData.status ||
    shiftData.completion_status ||
    shiftData.completionState ||
    '',
  ).trim().toLowerCase();

const _shiftCancelledForCapacity = (shiftData = {}) => {
  if (
    shiftData.deleted === true ||
    shiftData.is_deleted === true ||
    shiftData.archived === true
  ) {
    return true;
  }
  const status = _shiftStatusValue(shiftData);
  return ['cancelled', 'canceled', 'deleted', 'void'].includes(status) ||
    status.includes('cancel');
};

const _studentCountForCapacity = (shiftData = {}) => {
  const students = Array.isArray(shiftData.student_ids)
    ? shiftData.student_ids
    : Array.isArray(shiftData.studentIds)
      ? shiftData.studentIds
      : [];
  return students.length;
};

const _peakZoomHubOverlap = (shifts = [], timezone = ZOOM_HUB_DEFAULT_TIMEZONE) => {
  const events = [];
  for (const shift of shifts) {
    const start = _toDate(shift.start);
    const end = _toDate(shift.end);
    if (!start || !end || end <= start) continue;
    events.push({
      t: start.getTime(),
      classDelta: 1,
      seatDelta: Number(shift.seats || 0),
      label: DateTime.fromJSDate(start).setZone(timezone).toFormat('yyyy-LL-dd HH:mm'),
    });
    events.push({
      t: end.getTime(),
      classDelta: -1,
      seatDelta: -Number(shift.seats || 0),
      label: DateTime.fromJSDate(end).setZone(timezone).toFormat('yyyy-LL-dd HH:mm'),
    });
  }
  events.sort((a, b) => a.t - b.t || a.classDelta - b.classDelta);

  let classes = 0;
  let seats = 0;
  let peakClasses = 0;
  let peakSeats = 0;
  let peakAt = null;
  for (const event of events) {
    classes += event.classDelta;
    seats += event.seatDelta;
    if (classes > peakClasses || seats > peakSeats) {
      peakClasses = Math.max(peakClasses, classes);
      peakSeats = Math.max(peakSeats, seats);
      peakAt = event.label;
    }
  }
  return { classes: peakClasses, seats: peakSeats, at: peakAt };
};

const _zoomHubCapacityStatus = ({
  totalRooms,
  laneRoomCounts,
  lanePeaks,
  classRoomCapPerLane,
  totalRoomCap,
  warningRoomsPerLane,
  warningRoomsTotal,
  participantCapPerLane,
  warningSeatsPerLane,
}) => {
  const hardReasons = [];
  const warningReasons = [];
  if (totalRooms > totalRoomCap) hardReasons.push('total_room_cap');
  if (totalRooms >= warningRoomsTotal) warningReasons.push('total_room_pressure');

  laneRoomCounts.forEach((count, index) => {
    if (count > classRoomCapPerLane) hardReasons.push(`lane_${index + 1}_room_cap`);
    else if (count >= warningRoomsPerLane) warningReasons.push(`lane_${index + 1}_room_pressure`);
  });
  lanePeaks.forEach((peak, index) => {
    if (peak.seats > participantCapPerLane) hardReasons.push(`lane_${index + 1}_seat_cap`);
    else if (peak.seats >= warningSeatsPerLane) warningReasons.push(`lane_${index + 1}_seat_pressure`);
  });

  if (hardReasons.length) return { status: 'hard_limit', reasons: hardReasons };
  if (warningReasons.length) return { status: 'warning', reasons: warningReasons };
  return { status: 'ok', reasons: [] };
};

const _buildZoomHubCapacityForecast = async ({ now = new Date() } = {}) => {
  const db = admin.firestore();
  const config = await _loadZoomHubBlockConfig();
  const timezone = config.timezone || ZOOM_HUB_DEFAULT_TIMEZONE;
  const start = DateTime.fromJSDate(now).setZone(timezone).startOf('day');
  const end = start.plus({ days: ZOOM_HUB_CAPACITY_FORECAST_DAYS });
  const hostAccounts = _zoomClassroomHostAccounts();
  const laneCount = Math.max(1, hostAccounts.length);
  const classRoomCapPerLane = ZOOM_HUB_MAX_ROOM_COUNT - ZOOM_HUB_SPARE_ROOM_COUNT;
  const totalRoomCap = classRoomCapPerLane * laneCount;
  const participantCapPerLane = Number.isFinite(ZOOM_HUB_PARTICIPANT_CAP_PER_LANE)
    ? Math.max(1, ZOOM_HUB_PARTICIPANT_CAP_PER_LANE)
    : 100;
  const humanParticipantCapPerLane = Math.max(
    1,
    participantCapPerLane - ZOOM_HUB_RESERVED_SEATS_PER_LANE,
  );
  const warningRoomsPerLane = Math.floor(classRoomCapPerLane * ZOOM_HUB_CAPACITY_WARNING_RATIO);
  const warningRoomsTotal = Math.floor(totalRoomCap * ZOOM_HUB_CAPACITY_WARNING_RATIO);
  const warningSeatsPerLane = Math.floor(humanParticipantCapPerLane * ZOOM_HUB_SEAT_WARNING_RATIO);

  const snapshot = await db.collection('teaching_shifts')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(start.toJSDate()))
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(end.toJSDate()))
    .orderBy('shift_start')
    .get();

  const shifts = [];
  let nonHubZoomRecords = 0;
  let lastScheduledDay = null;
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const startDate = _toDate(data.shift_start || data.shiftStart);
    const endDate = _toDate(data.shift_end || data.shiftEnd);
    if (!startDate || !endDate || endDate <= startDate) continue;
    const provider = String(data.video_provider || data.videoProvider || '')
      .trim()
      .toLowerCase();
    if (provider !== 'zoom') continue;
    if (_shiftCancelledForCapacity(data)) continue;
    if (!_usesHubRouting({ shiftData: data, meetingId: String(data.zoom_meeting_id || '') })) {
      nonHubZoomRecords += 1;
      continue;
    }

    const laneIndex = _laneIndexForShift({ shiftId: doc.id, shiftData: data });
    const block = _blockForShift(data, config);
    const localStart = DateTime.fromJSDate(startDate).setZone(timezone);
    lastScheduledDay = !lastScheduledDay || localStart.toISODate() > lastScheduledDay
      ? localStart.toISODate()
      : lastScheduledDay;
    shifts.push({
      id: doc.id,
      start: startDate,
      end: endDate,
      day: localStart.toISODate(),
      blockDay: block.dayKey,
      blockIndex: block.blockIndex,
      blockLabel: `${DateTime.fromJSDate(block.blockStart).setZone(timezone).toFormat('HH:mm')}-${DateTime.fromJSDate(block.blockEnd).setZone(timezone).toFormat('HH:mm')}`,
      lane: laneIndex + 1,
      seats: Math.max(1, 1 + _studentCountForCapacity(data)),
    });
  }

  const dayCounts = new Map();
  const blockGroups = new Map();
  for (const shift of shifts) {
    dayCounts.set(shift.day, (dayCounts.get(shift.day) || 0) + 1);
    const key = `${shift.blockDay}|${shift.blockIndex}|${shift.blockLabel}`;
    const group = blockGroups.get(key) || {
      day: shift.blockDay,
      blockIndex: shift.blockIndex,
      blockLabel: shift.blockLabel,
      totalRooms: 0,
      laneRoomCounts: Array.from({ length: laneCount }, () => 0),
      shifts: [],
    };
    group.totalRooms += 1;
    if (!group.laneRoomCounts[shift.lane - 1]) group.laneRoomCounts[shift.lane - 1] = 0;
    group.laneRoomCounts[shift.lane - 1] += 1;
    group.shifts.push(shift);
    blockGroups.set(key, group);
  }

  const blocks = [];
  for (const group of blockGroups.values()) {
    const lanePeaks = Array.from({ length: laneCount }, (_, index) =>
      _peakZoomHubOverlap(group.shifts.filter((shift) => shift.lane === index + 1), timezone));
    const overallPeak = _peakZoomHubOverlap(group.shifts, timezone);
    const capacity = _zoomHubCapacityStatus({
      totalRooms: group.totalRooms,
      laneRoomCounts: group.laneRoomCounts,
      lanePeaks,
      classRoomCapPerLane,
      totalRoomCap,
      warningRoomsPerLane,
      warningRoomsTotal,
      participantCapPerLane: humanParticipantCapPerLane,
      warningSeatsPerLane,
    });
    const lanePressure = group.laneRoomCounts.map((count, index) => ({
      lane: index + 1,
      rooms: count || 0,
      roomHeadroom: Math.max(0, classRoomCapPerLane - (count || 0)),
      peakConcurrentClasses: lanePeaks[index]?.classes || 0,
      peakSeats: lanePeaks[index]?.seats || 0,
      seatHeadroom: Math.max(0, humanParticipantCapPerLane - (lanePeaks[index]?.seats || 0)),
    }));
    blocks.push({
      day: group.day,
      blockIndex: group.blockIndex,
      block: group.blockLabel,
      totalRooms: group.totalRooms,
      totalRoomHeadroom: Math.max(0, totalRoomCap - group.totalRooms),
      peakConcurrentClasses: overallPeak.classes,
      peakAt: overallPeak.at,
      status: capacity.status,
      reasons: capacity.reasons,
      lanes: lanePressure,
    });
  }

  const blockPressureScore = (block) => {
    const laneRoomPressure = block.lanes.reduce((max, lane) =>
      Math.max(max, lane.rooms / classRoomCapPerLane), 0);
    const laneSeatPressure = block.lanes.reduce((max, lane) =>
      Math.max(max, lane.peakSeats / humanParticipantCapPerLane), 0);
    return Math.max(block.totalRooms / totalRoomCap, laneRoomPressure, laneSeatPressure);
  };
  const blocksByPressure = [...blocks].sort((a, b) =>
    blockPressureScore(b) - blockPressureScore(a) ||
    a.day.localeCompare(b.day) ||
    a.blockIndex - b.blockIndex);
  const blocksByDate = [...blocks].sort((a, b) =>
    a.day.localeCompare(b.day) ||
    a.blockIndex - b.blockIndex);
  const nextHardLimit = blocksByDate.find((block) => block.status === 'hard_limit') || null;
  const nextWarning = blocksByDate.find((block) => block.status === 'warning') || null;
  const busiestBlock = blocksByPressure[0] || null;
  const topDays = Array.from(dayCounts.entries())
    .map(([day, count]) => ({ day, hubRoutedZoomShifts: count }))
    .sort((a, b) => b.hubRoutedZoomShifts - a.hubRoutedZoomShifts || a.day.localeCompare(b.day))
    .slice(0, 14);
  const topBlocks = blocksByPressure.slice(0, 14);
  const summaryStatus = nextHardLimit ? 'add_account' : nextWarning ? 'watch' : 'ok';
  const recommendation = nextHardLimit
    ? `Add another Zoom account before ${nextHardLimit.day} ${nextHardLimit.block}.`
    : nextWarning
      ? `Start planning another Zoom account before ${nextWarning.day} ${nextWarning.block}.`
      : `No additional Zoom account is needed in the generated schedule through ${lastScheduledDay || end.minus({ days: 1 }).toISODate()} based on peak concurrent human participants and hub-block room pressure.`;

  return {
    success: true,
    generatedAt: now.toISOString(),
    horizonStart: start.toISODate(),
    horizonEnd: lastScheduledDay || end.minus({ days: 1 }).toISODate(),
    summaryStatus,
    recommendation,
    capacity: {
      laneCount,
      hostAccounts,
      blockBoundaries: config.boundaryLabels,
      classRoomCapPerLane,
      classRoomCapTotal: totalRoomCap,
      warningRoomsPerLane,
      warningRoomsTotal,
      participantCapPerLane,
      reservedSeatsPerLane: ZOOM_HUB_RESERVED_SEATS_PER_LANE,
      humanParticipantCapPerLane,
      warningSeatsPerLane,
      spareRoomsPerHub: ZOOM_HUB_SPARE_ROOM_COUNT,
    },
    totals: {
      scannedHubRoutedZoomShifts: shifts.length,
      nonHubZoomRecords,
      daysWithHubShifts: dayCounts.size,
    },
    nextHardLimit,
    nextWarning,
    busiestBlock,
    topDays,
    topBlocks,
  };
};

const _buildZoomHubRoutingStatus = async ({ now = new Date() } = {}) => {
  const db = admin.firestore();
  const [hubSnapshot, alertSnapshot] = await Promise.all([
    db.collection('hub_meetings').get(),
    db.collection('system_alerts').get(),
  ]);

  const shiftCache = new Map();
  const loadShift = async (shiftId) => {
    const id = String(shiftId || '').trim();
    if (!id || id.startsWith('__spare_')) return null;
    if (shiftCache.has(id)) return shiftCache.get(id);
    const doc = await db.collection('teaching_shifts').doc(id).get();
    const value = doc.exists ? { id: doc.id, data: doc.data() || {} } : null;
    shiftCache.set(id, value);
    return value;
  };

  const hubs = [];
  for (const hubDoc of hubSnapshot.docs) {
    const hubData = hubDoc.data() || {};
    if (!_hubStatusRelevantForDashboard({ hubData, now })) continue;

    const rooms = _normalizeZoomHubRooms(hubData.rooms);
    const membersSnapshot = await hubDoc.ref.collection('members').get();
    const members = membersSnapshot.docs.map((doc) => {
      const data = doc.data() || {};
      return {
        id: doc.id,
        uid: String(data.uid || doc.id || '').trim(),
        shiftId: String(data.shiftId || data.shift_id || '').trim(),
        role: String(data.role || '').trim(),
        displayName: String(
          data.realDisplayName ||
          data.real_display_name ||
          data.displayName ||
          data.display_name ||
          '',
        ).trim(),
      };
    }).filter((member) => member.uid && member.shiftId);

    const memberCountByShift = new Map();
    for (const member of members) {
      memberCountByShift.set(
        member.shiftId,
        (memberCountByShift.get(member.shiftId) || 0) + 1,
      );
    }

    const classRooms = [];
    for (const room of rooms) {
      if (room.spare && !room.shiftId) continue;
      const shift = await loadShift(room.shiftId);
      const shiftData = shift?.data || {};
      const scheduledNow = shift ? _shiftIsScheduledNow({ shiftData, now }) : false;
      classRooms.push({
        shiftId: room.shiftId || null,
        roomName: room.name,
        title: _shiftTitleForRoutingStatus(shiftData, room.name),
        teacherName: String(
          shiftData.teacher_name ||
          shiftData.teacherName ||
          shiftData.teacher_display_name ||
          '',
        ).trim(),
        studentNames: Array.isArray(shiftData.student_names)
          ? shiftData.student_names.map((name) => String(name || '').trim()).filter(Boolean)
          : [],
        start: _isoOrNull(shiftData.shift_start || shiftData.startTime || shiftData.start_time),
        end: _isoOrNull(shiftData.shift_end || shiftData.endTime || shiftData.end_time),
        scheduledNow,
        targetMemberCount: memberCountByShift.get(room.shiftId) || 0,
        spare: room.spare,
      });
    }

    const stats = (hubData.stats && typeof hubData.stats === 'object') ? hubData.stats : {};
    const heartbeatAt = _toDate(hubData.heartbeat_at || hubData.heartbeatAt);
    const heartbeatAgeMs = heartbeatAt ? Math.max(0, now.getTime() - heartbeatAt.getTime()) : null;
    const heartbeatFresh = heartbeatAgeMs !== null && heartbeatAgeMs <= ZOOM_HUB_BOT_STALE_MS;
    const windowStart = _toDate(hubData.window_start || hubData.windowStart);
    const windowEnd = _toDate(hubData.window_end || hubData.windowEnd);
    const active = Boolean(windowStart && windowEnd &&
      windowStart.getTime() <= now.getTime() &&
      windowEnd.getTime() >= now.getTime());

    hubs.push({
      hubDocId: hubDoc.id,
      lane: _numberOrZero(hubData.lane || hubData.zoom_hub_lane || hubData.zoom_hub_lane_index),
      blockIndex: _numberOrZero(hubData.blockIndex ?? hubData.block_index),
      hostAccount: String(hubData.hostAccount || hubData.host_account || '').trim(),
      meetingNumber: String(
        hubData.meetingNumber ||
        hubData.meeting_number ||
        hubData.zoom_meeting_id ||
        '',
      ).trim(),
      status: _hubStatusValue(hubData) || 'unknown',
      active,
      roomsOpen: _hubStatusValue(hubData) === 'roomsOpen',
      heartbeatAt: heartbeatAt ? heartbeatAt.toISOString() : null,
      heartbeatAgeMs,
      heartbeatFresh,
      windowStart: windowStart ? windowStart.toISOString() : null,
      windowEnd: windowEnd ? windowEnd.toISOString() : null,
      plannedRoomCount: rooms.length,
      classRoomCount: rooms.filter((room) => !room.spare).length,
      liveRoomCount: _numberOrZero(stats.liveRoomCount),
      inRoomOccupants: _numberOrZero(stats.inRoomOccupants),
      attendeeCount: _numberOrZero(stats.attendeeCount),
      customerKeyCount: _numberOrZero(stats.customerKeyCount),
      routableRoomCount: _numberOrZero(stats.routableRoomCount),
      targetMemberCount: members.length || _numberOrZero(stats.targetMemberCount),
      lastRoutingActionCount: _numberOrZero(stats.routedCount),
      botError: hubData.bot_error ? String(hubData.bot_error) : '',
      forceRejoinAt: _isoOrNull(hubData.force_rejoin_at || hubData.forceRejoinAt),
      classes: classRooms.sort((a, b) => (
        Number(b.scheduledNow) - Number(a.scheduledNow) ||
        b.targetMemberCount - a.targetMemberCount ||
        String(a.start || '').localeCompare(String(b.start || '')) ||
        a.roomName.localeCompare(b.roomName)
      )),
    });
  }

  hubs.sort((a, b) => (
    a.lane - b.lane ||
    a.blockIndex - b.blockIndex ||
    String(a.windowStart || '').localeCompare(String(b.windowStart || ''))
  ));

  const alertCutoffMs = now.getTime() - ZOOM_HUB_STATUS_LOOKBACK_MS;
  const incidents = alertSnapshot.docs
    .map((doc) => {
      const data = doc.data() || {};
      const createdAt = _toDate(data.created_at || data.createdAt || data.updated_at);
      return {
        id: doc.id,
        type: String(data.type || '').trim(),
        severity: String(data.severity || '').trim() || 'warning',
        reason: String(data.reason || '').trim(),
        title: String(data.title || data.reason || doc.id).trim(),
        createdAt: createdAt ? createdAt.toISOString() : null,
        open: data.resolved !== true && data.status !== 'resolved' && !data.resolved_at,
        hubDocId: String(data.data?.hubDocId || data.hubDocId || '').trim(),
        lane: _numberOrZero(data.data?.lane || data.lane),
      };
    })
    .filter((incident) => incident.type === 'zoom_hub')
    .filter((incident) => (
      incident.open ||
      (incident.createdAt && new Date(incident.createdAt).getTime() >= alertCutoffMs)
    ))
    .sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')))
    .slice(0, 12);

  const totals = hubs.reduce((acc, hub) => {
    if (hub.active) acc.activeHubs += 1;
    if (hub.roomsOpen) acc.roomsOpen += 1;
    if (hub.heartbeatFresh) acc.onlineBots += 1;
    else if (hub.active) acc.staleBots += 1;
    acc.inRoomOccupants += hub.inRoomOccupants;
    acc.attendeeCount += hub.attendeeCount;
    acc.targetMemberCount += hub.targetMemberCount;
    acc.liveRoomCount += hub.liveRoomCount;
    acc.plannedRoomCount += hub.plannedRoomCount;
    acc.lastRoutingActionCount += hub.lastRoutingActionCount;
    acc.scheduledClassCount += hub.classes.filter((classRoom) => classRoom.scheduledNow).length;
    return acc;
  }, {
    activeHubs: 0,
    roomsOpen: 0,
    onlineBots: 0,
    staleBots: 0,
    inRoomOccupants: 0,
    attendeeCount: 0,
    targetMemberCount: 0,
    liveRoomCount: 0,
    plannedRoomCount: 0,
    lastRoutingActionCount: 0,
    scheduledClassCount: 0,
  });

  return {
    success: true,
    generatedAt: now.toISOString(),
    totals: {
      ...totals,
      openIncidentCount: incidents.filter((incident) => incident.open).length,
    },
    hubs,
    incidents,
  };
};

const getZoomHubRoutingStatus = onCall({ cors: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!await isUserAdmin(uid, request.auth?.token || {})) {
    throw new HttpsError('permission-denied', 'Only admins can view Zoom hub routing status');
  }
  return _buildZoomHubRoutingStatus();
});

const getZoomHubCapacityForecast = onCall({ cors: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!await isUserAdmin(uid, request.auth?.token || {})) {
    throw new HttpsError('permission-denied', 'Only admins can view Zoom hub capacity forecasts');
  }
  return _buildZoomHubCapacityForecast();
});

const getZoomJoinInfo = onCall({
  cors: true,
  secrets: ZOOM_JOIN_SECRETS,
}, async (request) => {
  const uid = request.auth?.uid;
  const shiftId = request.data?.shiftId;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!shiftId || typeof shiftId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid shiftId');
  }

  const { sdkKey } = getZoomConfig();
  if (!sdkKey) {
    throw new HttpsError('unavailable', 'Zoom Meeting SDK is not configured');
  }

  const { shiftRef, shiftData, teacherId, studentIds, meetingId } =
    await getZoomShiftOrThrow(shiftId);
  const joinWindow = assertJoinWindowOrThrow(shiftData);
  const role = await getAccessForUser({
    uid,
    token: request.auth?.token,
    teacherId,
    studentIds,
    activeRole: request.data?.activeRole,
  });
  const useHubRouting = _usesHubRouting({ shiftData, meetingId });
  const teacherHostAccount = await _getZoomHostAccountForTeacher(teacherId, {
    required: !useHubRouting,
  });
  const isTeacherForShift = uid === teacherId;
  const routing = useHubRouting
    ? await ensureZoomHubMeeting({
      shiftRef,
      shiftData,
      shiftId,
    })
    : {
      meeting: await ensureZoomMeeting({
        shiftRef,
        shiftData,
        meetingId,
        hostAccount: teacherHostAccount,
      }),
      hostAccount: teacherHostAccount,
      routingMode: 'single',
      hubMeetingId: null,
      breakoutRoomName: '',
      breakoutRooms: [],
    };
  // Never hand out a hub the bot has abandoned. If the resolved hub's bot was
  // present but its heartbeat has since gone clearly stale (bot left/crashed and
  // the watchdog has not recovered it yet), joining would drop the user into a
  // bot-less main session. Ask them to retry — watchZoomHubBots restores the bot
  // within ~2 min. A hub with NO heartbeat yet is freshly provisioned and the
  // bot is on its way in, so it is left alone (not a false positive).
  if (routing.routingMode === 'hub' && routing.hubMeetingId) {
    const hubSnap = await admin.firestore()
      .collection('hub_meetings').doc(routing.hubMeetingId).get();
    const hubInfo = hubSnap.exists ? hubSnap.data() || {} : {};
    const hb = _toDate(hubInfo.heartbeat_at || hubInfo.heartbeatAt);
    if (hb && hb.getTime() + 2 * ZOOM_HUB_BOT_STALE_MS < Date.now()) {
      await _sendZoomHubAdminAlert({
        alertId: `${routing.hubMeetingId}_stale_on_join`,
        reason: 'stale_hub_on_join',
        title: 'Join blocked: hub bot not present',
        body: `A user tried to join ${_deriveShiftDisplayName(shiftData)} but the bot for ${routing.hubMeetingId} is not present (heartbeat stale). Asked them to retry while the watchdog recovers it.`,
        severity: 'critical',
        data: { hubDocId: routing.hubMeetingId, shiftId },
      }).catch(() => {});
      throw new HttpsError(
        'unavailable',
        'Your class is reconnecting. Please tap Join again in a moment.',
      );
    }
  }
  await ensureZoomHostClassroomSettings(routing.hostAccount);
  const meeting = routing.meeting;
  const meetingNumber = String(meeting.id || meeting.meetingNumber || '').trim();
  const userRole = isTeacherForShift ? 'teacher' : role;
  const sdkRole = 0;
  const signature = generateMeetingSdkSignature({
    meetingNumber,
    role: sdkRole,
  });
  const participantSignature = signature;

  const realDisplayName = await getUserDisplayName(uid);
  const hubCustomerKey = routing.routingMode === 'hub'
    ? _zoomHubCustomerKey({ uid, shiftId })
    : '';
  const nativeRoutingDisplayName = routing.routingMode === 'hub'
    ? _zoomHubRoutingDisplayName({ displayName: realDisplayName, routingKey: hubCustomerKey })
    : realDisplayName;
  // Participants see their real name in the classroom. Per-class separation and
  // presence mapping ride on the hidden customerKey (zh_<hash(uid:shiftId)>),
  // not the display name, so clients keep a clean visible name. The
  // deterministic routing display name is still stored on the hub member as a
  // fallback for old native builds that did not send customerKey.
  const displayName = realDisplayName;
  const targetHubRoom = routing.targetRoom || _targetHubRoomForJoin({
    rooms: routing.breakoutRooms || [],
    shiftId,
    roomName: routing.breakoutRoomName || '',
  }).targetRoom;
  if (routing.routingMode === 'hub' && !targetHubRoom) {
    throw new HttpsError('internal', 'Unable to resolve the classroom breakout room');
  }
  if (routing.routingMode === 'hub') {
    await _writeZoomHubMember({
      hubMeetingId: routing.hubMeetingId,
      uid: hubCustomerKey,
      userId: uid,
      shiftId,
      role: userRole,
      displayName,
      realDisplayName,
      routingDisplayName: nativeRoutingDisplayName,
    });
  }
  const customerKey = routing.routingMode === 'hub'
    ? hubCustomerKey
    : uid;
  return {
    success: true,
    provider: 'zoom',
    meetingNumber,
    password: meeting.password || shiftData.zoom_password || '',
    signature,
    participantSignature,
    sdkKey,
    zak: null,
    displayName,
    realDisplayName,
    nativeDisplayName: displayName,
    routingDisplayName: nativeRoutingDisplayName,
    role: sdkRole,
    userRole,
    customerKey,
    shiftName: _deriveShiftDisplayName(shiftData),
    joinUrl: meeting.join_url || meeting.joinUrl || shiftData.zoom_join_url || '',
    routingMode: routing.routingMode,
    hubMeetingId: routing.hubMeetingId,
    hubController: false,
    hostRoleBlockedReason: '',
    breakoutRoomName: routing.breakoutRoomName || '',
    breakoutRoomKey: shiftId,
    classEndsAtIso: routing.classEndsAtIso || null,
    targetBreakoutRoom: targetHubRoom || null,
    hubBreakoutRooms: [],
    assignmentToken: '',
    autoOpenBreakoutRooms: false,
    autoJoinBreakoutRoom: routing.routingMode === 'hub',
    joinWindow,
  };
});

const _isTeacherRecord = (data) => {
  const userType = String(data.user_type || data.userType || '').trim().toLowerCase();
  const secondaryRoles = [
    ..._roleList(data.roles),
    ..._roleList(data.secondary_roles),
    ..._roleList(data.secondaryRoles),
  ];
  return userType === 'teacher' || secondaryRoles.includes('teacher');
};

const _commitAndResetBatch = async ({ db, batch, count }) => {
  if (count > 0) await batch.commit();
  return { batch: db.batch(), count: 0 };
};

const setTeacherZoomEnabled = onCall({ cors: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (!(await isUserAdmin(uid, request.auth?.token))) {
    throw new HttpsError('permission-denied', 'Only admins can manage Zoom routing');
  }

  const teacherId = String(request.data?.teacherId || request.data?.teacher_id || '').trim();
  const enabled = request.data?.enabled === true;
  const requestedHostAccount = String(
    request.data?.zoomHostAccount || request.data?.zoom_host_account || '',
  ).trim();
  // Optional student scoping: when enabling, the admin may restrict the switch
  // to only the shifts that include these students. Empty/absent = all shifts.
  const rawStudentIds = request.data?.studentIds ?? request.data?.student_ids;
  const scopedStudentIds = Array.isArray(rawStudentIds)
    ? rawStudentIds.map((s) => String(s || '').trim()).filter(Boolean)
    : [];
  const useStudentScope = enabled && scopedStudentIds.length > 0;
  const scopedStudentSet = new Set(scopedStudentIds);
  if (!teacherId) {
    throw new HttpsError('invalid-argument', 'Missing teacherId');
  }

  const db = admin.firestore();
  const teacherRef = db.collection('users').doc(teacherId);
  const teacherDoc = await teacherRef.get();
  if (!teacherDoc.exists) throw new HttpsError('not-found', 'Teacher not found');
  const teacherData = teacherDoc.data() || {};
  if (!_isTeacherRecord(teacherData)) {
    throw new HttpsError('failed-precondition', 'Zoom can only be enabled for teachers');
  }

  const existingHostAccount = String(
    teacherData.zoom_host_account ||
    teacherData.zoomHostAccount ||
    '',
  ).trim();
  const zoomHostAccount = requestedHostAccount || existingHostAccount;
  const requestedRoutingMode = String(
    request.data?.zoomRoutingMode || request.data?.zoom_routing_mode || '',
  ).trim().toLowerCase();
  const requestedSingleMode = requestedRoutingMode === 'single' ||
    request.data?.zoomDisableHubRouting === true ||
    request.data?.zoom_disable_hub_routing === true;
  const reservedHubHostAccounts = new Set(
    _zoomClassroomHostAccounts().map((email) => String(email).trim().toLowerCase()),
  );
  if (
    enabled &&
    requestedSingleMode &&
    zoomHostAccount &&
    reservedHubHostAccounts.has(zoomHostAccount.toLowerCase())
  ) {
    throw new HttpsError(
      'failed-precondition',
      'This Zoom account is reserved for classroom hubs. Assign a different account for single Zoom classes.',
    );
  }

  await teacherRef.set({
    use_zoom: enabled,
    ...(enabled && zoomHostAccount ? { zoom_host_account: zoomHostAccount } : {}),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const now = admin.firestore.Timestamp.fromDate(new Date());
  const shiftsSnapshot = await db.collection('teaching_shifts')
    .where('teacher_id', '==', teacherId)
    .where('shift_start', '>=', now)
    .get();

  let batch = db.batch();
  let batchCount = 0;
  let updatedCount = 0;
  for (const doc of shiftsSnapshot.docs) {
    const data = doc.data() || {};
    const category = String(data.category || data.shift_category || 'teaching')
      .trim()
      .toLowerCase();
    if (category !== 'teaching') continue;

    // When scoped, only move shifts that include at least one selected student;
    // leave every other class exactly as it was.
    if (useStudentScope) {
      const shiftStudentIds = Array.isArray(data.student_ids)
        ? data.student_ids.map((s) => String(s || '').trim())
        : [];
      if (!shiftStudentIds.some((id) => scopedStudentSet.has(id))) continue;
    }

    batch.set(doc.ref, {
      video_provider: enabled ? 'zoom' : 'realtimekit',
      ...(enabled && requestedRoutingMode
        ? {
          zoomRoutingMode: requestedRoutingMode,
          zoom_routing_mode: requestedRoutingMode,
        }
        : {}),
      ...(enabled && requestedSingleMode ? { zoom_disable_hub_routing: true } : {}),
      zoom_routing_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    batchCount += 1;
    updatedCount += 1;

    if (batchCount >= BATCH_WRITE_LIMIT) {
      const reset = await _commitAndResetBatch({ db, batch, count: batchCount });
      batch = reset.batch;
      batchCount = reset.count;
    }
  }
  if (batchCount > 0) await batch.commit();

  return {
    success: true,
    teacherId,
    useZoom: enabled,
    zoomHostAccount: enabled ? zoomHostAccount : existingHostAccount,
    updatedShiftCount: updatedCount,
    scopedStudentCount: useStudentScope ? scopedStudentIds.length : 0,
  };
});

const _prepareZoomHubForShiftDoc = async (shiftDoc) => {
  const shiftData = shiftDoc.data() || {};
  const shiftRef = admin.firestore().collection('teaching_shifts').doc(shiftDoc.id);
  const teacherId = String(shiftData.teacher_id || shiftData.teacherId || '').trim();
  const teacherHostAccount = teacherId
    ? await _getZoomHostAccountForTeacher(teacherId, { required: false })
    : '';
  await ensureZoomHubMeeting({
    shiftRef,
    shiftData,
    shiftId: shiftDoc.id,
    fallbackHostAccount: teacherHostAccount,
  });
};

const prepareZoomHubs = onSchedule({
  schedule: 'every 10 minutes',
  region: 'us-central1',
  secrets: ZOOM_JOIN_SECRETS,
}, async () => {
  const db = admin.firestore();
  const now = new Date();
  const scanStart = new Date(now.getTime() - ZOOM_HUB_WINDOW_PADDING_MS);
  const lookahead = new Date(now.getTime() + ZOOM_HUB_PREP_LOOKAHEAD_MS);
  const snapshot = await db.collection('teaching_shifts')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(scanStart))
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(lookahead))
    .get();
  const prepared = new Set();
  let preparedCount = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const provider = String(data.video_provider || data.videoProvider || '')
      .trim()
      .toLowerCase();
    const meetingId = String(data.zoom_meeting_id || data.zoomMeetingId || '').trim();
    if (provider !== 'zoom' || !_usesHubRouting({ shiftData: data, meetingId })) continue;
    const meta = await _hubMetaForShift({ shiftId: doc.id, shiftData: data });
    if (prepared.has(meta.hubDocId)) continue;
    prepared.add(meta.hubDocId);
    await _prepareZoomHubForShiftDoc(doc);
    preparedCount += 1;
  }
  console.log(`[ZoomHub] Prepared ${preparedCount} hub(s) for ${snapshot.docs.length} upcoming Zoom shift(s).`);
});

const _shiftStartMs = (shiftData) => {
  const v = shiftData && (shiftData.shift_start || shiftData.shiftStart);
  if (!v) return null;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (typeof v.toDate === 'function') return v.toDate().getTime();
  if (typeof v === 'number') return v;
  if (typeof v === 'string') { const t = Date.parse(v); return Number.isNaN(t) ? null : t; }
  if (v._seconds != null) return v._seconds * 1000;
  if (v.seconds != null) return v.seconds * 1000;
  return null;
};

// Only re-provision when something that affects the hub/room actually changed.
// ensureZoomHubMeeting writes hub metadata back onto the shift doc, so without
// this guard the trigger would re-fire on its own writes.
const _provisioningRelevantChange = (before, after) => {
  if (!before) return true; // newly created shift
  const field = (d, a, b) => {
    const v = d[a] !== undefined ? d[a] : d[b];
    if (v && typeof v.toMillis === 'function') return v.toMillis();
    return v === undefined ? null : v;
  };
  // Only compare fields that ensureZoomHubMeeting NEVER writes back to the shift
  // doc, otherwise the trigger would re-fire on its own writes. (It writes
  // hub_meeting_id, zoom_meeting_id, zoom_hub_lane_index, zoom_join_url, etc.)
  const pairs = [
    ['shift_start', 'shiftStart'],
    ['teacher_id', 'teacherId'],
    ['video_provider', 'videoProvider'],
    ['zoom_enabled', 'zoomEnabled'],
  ];
  for (const [a, b] of pairs) {
    if (JSON.stringify(field(before, a, b)) !== JSON.stringify(field(after, a, b))) return true;
  }
  const roster = (d) => JSON.stringify(d.student_ids || d.studentIds || []);
  return roster(before) !== roster(after);
};

// Eagerly provision a hub the moment a Zoom hub-routed shift is created or moved
// into the imminent window, so an ad-hoc "create a class right now" is routable
// without waiting for the 10-minute prepareZoomHubs cycle. Writing the hub doc
// makes the bot join it on its next poll, so joins land in the correct room.
const onTeachingShiftWritten = onDocumentWritten({
  document: 'teaching_shifts/{shiftId}',
  region: 'us-central1',
  secrets: ZOOM_JOIN_SECRETS,
}, async (event) => {
  const afterSnap = event.data && event.data.after;
  if (!afterSnap || !afterSnap.exists) return; // deletion — nothing to provision
  const shiftData = afterSnap.data() || {};
  const before = event.data.before && event.data.before.exists
    ? event.data.before.data()
    : null;

  const provider = String(shiftData.video_provider || shiftData.videoProvider || '')
    .trim()
    .toLowerCase();
  const meetingId = String(shiftData.zoom_meeting_id || shiftData.zoomMeetingId || '').trim();
  if (provider !== 'zoom' || !_usesHubRouting({ shiftData, meetingId })) return;

  const startMs = _shiftStartMs(shiftData);
  if (startMs == null) return;
  const now = Date.now();
  if (startMs < now - ZOOM_HUB_WINDOW_PADDING_MS) return; // already past its window
  if (startMs > now + ZOOM_HUB_PREP_LOOKAHEAD_MS) return; // too far out; prepareZoomHubs handles it

  if (!_provisioningRelevantChange(before, shiftData)) return; // avoid self-trigger loops

  try {
    await _prepareZoomHubForShiftDoc(afterSnap);
    console.log(`[ZoomHub] Eagerly provisioned hub for imminent shift ${event.params.shiftId}`);
  } catch (err) {
    console.error(`[ZoomHub] Eager provision failed for shift ${event.params.shiftId}:`, err);
  }
});

const _writeZoomHubBotAlert = async ({ hubDocId, hubData, reason }) => {
  const title = reason === 'heartbeat_stale'
    ? 'Critical Zoom hub bot heartbeat is stale'
    : 'Critical Zoom hub rooms are not open';
  const body = reason === 'heartbeat_stale'
    ? `Zoom hub ${hubDocId} is inside its class window but the bot heartbeat is stale.`
    : `Zoom hub ${hubDocId} is inside its class window but rooms are not open.`;
  await _sendZoomHubAdminAlert({
    alertId: `${hubDocId}_${reason}`,
    reason,
    title,
    body,
    data: {
      hubDocId,
      lane: hubData.lane || hubData.laneIndex || '',
      status: hubData.status || hubData.bot_status || '',
      meetingNumber: hubData.meetingNumber || hubData.zoom_meeting_id || '',
    },
  });
};

const watchZoomHubBots = onSchedule({
  schedule: 'every 2 minutes',
  region: 'us-central1',
  secrets: ZOOM_JOIN_SECRETS,
}, async () => {
  const now = new Date();
  const snapshot = await admin.firestore().collection('hub_meetings').get();

  // Precompute, per lane, the newest currently-active block index. A hub is
  // "superseded" when a newer block on the same lane is already active — its
  // classes must take the shared account, so an older block whose own classes
  // are over must release the account even if someone forgot to leave.
  const laneNewestActiveBlock = new Map();
  for (const doc of snapshot.docs) {
    const d = doc.data() || {};
    const ws = _toDate(d.window_start || d.windowStart);
    const we = _toDate(d.window_end || d.windowEnd);
    if (!ws || !we) continue;
    if (ws.getTime() > now.getTime() || we.getTime() < now.getTime()) continue;
    const lane = Number(d.lane ?? d.laneIndex);
    const blockIndex = Number(d.blockIndex ?? d.block_index);
    if (!Number.isFinite(lane) || !Number.isFinite(blockIndex)) continue;
    const prev = laneNewestActiveBlock.get(lane);
    if (prev === undefined || blockIndex > prev) laneNewestActiveBlock.set(lane, blockIndex);
  }

  let alertCount = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const windowStart = _toDate(data.window_start || data.windowStart);
    const windowEnd = _toDate(data.window_end || data.windowEnd);
    if (!windowStart || !windowEnd) continue;
    if (windowStart.getTime() > now.getTime()) continue;

    const stats = (data.stats && typeof data.stats === 'object') ? data.stats : {};
    const inRoom = Number(stats.inRoomOccupants || 0);
    const meetingNumber = String(
      data.meetingNumber || data.zoom_meeting_id || data.meeting_number || '',
    ).trim();
    const lane = Number(data.lane ?? data.laneIndex);
    const blockIndex = Number(data.blockIndex ?? data.block_index);
    const realClassEnd = windowEnd.getTime() - ZOOM_HUB_WINDOW_PADDING_MS;
    const classesOver = now.getTime() > realClassEnd;
    const superseded = Number.isFinite(lane) &&
      Number.isFinite(blockIndex) &&
      (laneNewestActiveBlock.get(lane) ?? -Infinity) > blockIndex;

    // Policy: a class may stay at most 15 minutes past its scheduled end, then
    // everyone is removed. window_end already IS (last class end + 15 min), so we
    // END this hub's Zoom meeting — regardless of who is still inside — once:
    //  - now is at/after window_end (the 15-minute limit); or
    //  - it is superseded by a newer block whose classes are due and this hub's
    //    own real classes are over (hand the shared account over early).
    // This guarantees a forgotten participant can never hold the account or push
    // the meeting toward Zoom's 30h cap.
    const shouldEndMeeting =
      (now.getTime() >= windowEnd.getTime()) ||
      (superseded && classesOver);

    if (shouldEndMeeting) {
      if (!data.ended_at && meetingNumber && typeof zoomClient.endMeeting === 'function') {
        try {
          await zoomClient.endMeeting(meetingNumber);
          await doc.ref.set({
            ended_at: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          const why = (now.getTime() >= windowEnd.getTime())
            ? (inRoom > 0 ? 'reached 15-min limit with stragglers' : 'reached 15-min limit, empty')
            : 'superseded by newer block';
          console.warn(`[ZoomHub] Ended hub meeting ${meetingNumber} (${doc.id}) to free the account (${why}).`);
          if (inRoom > 0) {
            await _writeZoomHubBotAlert({
              hubDocId: doc.id, hubData: data, reason: 'stragglers_removed_at_time_limit',
            });
            alertCount += 1;
          }
        } catch (err) {
          console.warn(`[ZoomHub] Failed to end hub meeting ${meetingNumber}:`, err.message || err);
        }
      }
      continue;
    }
    const status = String(data.status || data.bot_status || '').trim();
    const heartbeat = _toDate(data.heartbeat_at || data.heartbeatAt);
    const staleHeartbeat = !heartbeat ||
      heartbeat.getTime() + ZOOM_HUB_BOT_STALE_MS < now.getTime();

    // Detect the "poisoned meeting" state: the bot is alive and reports rooms
    // open, but its live breakout list is empty while members are expected, so
    // it cannot route anyone. Only reset when nobody is inside a room, so a live
    // class is never interrupted.
    const liveRoomCount = Number(stats.liveRoomCount);
    const targetMemberCount = Number(stats.targetMemberCount || 0);
    const isPoisoned = status === 'roomsOpen' &&
      !staleHeartbeat &&
      Number.isFinite(liveRoomCount) && liveRoomCount === 0 &&
      targetMemberCount > 0 &&
      inRoom === 0;

    if (status === 'roomsOpen' && !staleHeartbeat && !isPoisoned) {
      // Zombie check: the bot claims a healthy, open meeting, but the meeting may
      // have actually ended server-side (Zoom-side end, 30h cap, admin action) —
      // the bot's browser session keeps reporting stale rooms and neither the
      // poison nor heartbeat check catches it. Verify real liveness via REST; if
      // the meeting is not 'started', stamp force_rejoin_at so the bot reloads
      // into a fresh instance. Throttled so we don't re-stamp before it reloads.
      const lastForceRejoin = _toDate(data.force_rejoin_at || data.forceRejoinAt);
      const recentlyForced = lastForceRejoin &&
        lastForceRejoin.getTime() + 3 * 60 * 1000 > now.getTime();
      if (meetingNumber && !recentlyForced && inRoom === 0 &&
        typeof zoomClient.getMeeting === 'function') {
        let meetingLive = true;
        try {
          const meeting = await zoomClient.getMeeting(meetingNumber);
          meetingLive = String(meeting?.status || '').trim() === 'started';
        } catch (err) {
          // A 404/3001 means the meeting no longer exists = definitely not live.
          const text = String(err?.message || err || '');
          meetingLive = !/3001|not exist|not found|404/i.test(text);
        }
        if (!meetingLive) {
          await doc.ref.set({
            force_rejoin_at: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          await _writeZoomHubBotAlert({
            hubDocId: doc.id,
            hubData: data,
            reason: 'zombie_meeting_forced_rejoin',
          });
          alertCount += 1;
          console.warn(`[ZoomHub] Zombie hub ${doc.id}: meeting ${meetingNumber} not live; forced bot rejoin.`);
          continue;
        }
      }
      if (Number(data.poison_streak) > 0) {
        await doc.ref.set({ poison_streak: 0 }, { merge: true });
      }
      continue;
    }

    if (isPoisoned) {
      const streak = (Number(data.poison_streak) || 0) + 1;
      if (streak >= ZOOM_HUB_POISON_RESET_STREAK &&
        meetingNumber &&
        typeof zoomClient.endMeeting === 'function') {
        try {
          await zoomClient.endMeeting(meetingNumber);
          await doc.ref.set({
            poison_streak: 0,
            poison_reset_at: admin.firestore.FieldValue.serverTimestamp(),
            last_poison_reset_meeting: meetingNumber,
          }, { merge: true });
          console.warn(`[ZoomHub] Auto-reset poisoned hub ${doc.id} (ended meeting ${meetingNumber}); bot will rejoin a clean instance.`);
        } catch (err) {
          await doc.ref.set({
            poison_streak: streak,
            bot_end_error: err.message || String(err),
          }, { merge: true });
          console.warn(`[ZoomHub] Failed to auto-reset poisoned hub ${doc.id}:`, err.message || err);
        }
      } else {
        await doc.ref.set({ poison_streak: streak }, { merge: true });
      }
      await _writeZoomHubBotAlert({
        hubDocId: doc.id,
        hubData: data,
        reason: 'breakout_unreadable_poisoned',
      });
      alertCount += 1;
      continue;
    }

    await _writeZoomHubBotAlert({
      hubDocId: doc.id,
      hubData: data,
      reason: status !== 'roomsOpen' ? 'rooms_not_open' : 'heartbeat_stale',
    });
    alertCount += 1;
  }
  if (alertCount > 0) {
    console.warn(`[ZoomHub] Bot watcher wrote ${alertCount} alert(s).`);
  }
});

const _rawBodyString = (req) => {
  if (req.rawBody) return Buffer.from(req.rawBody).toString('utf8');
  return JSON.stringify(req.body || {});
};

const _buildZoomSignature = ({ secretToken, timestamp, rawBody }) => {
  const message = `v0:${timestamp}:${rawBody}`;
  return `v0=${crypto.createHmac('sha256', secretToken).update(message).digest('hex')}`;
};

const verifyZoomWebhookSignature = (req) => {
  const { webhookSecretToken } = getZoomConfig();
  if (!webhookSecretToken) return false;
  const timestamp = req.get?.('x-zm-request-timestamp') ||
    req.headers?.['x-zm-request-timestamp'];
  const signature = req.get?.('x-zm-signature') || req.headers?.['x-zm-signature'];
  if (!timestamp || !signature) return false;

  const expected = _buildZoomSignature({
    secretToken: webhookSecretToken,
    timestamp,
    rawBody: _rawBodyString(req),
  });
  const expectedBuffer = Buffer.from(expected);
  const actualBuffer = Buffer.from(String(signature));
  return expectedBuffer.length === actualBuffer.length &&
    crypto.timingSafeEqual(expectedBuffer, actualBuffer);
};

const buildZoomWebhookValidationResponse = (plainToken) => {
  const { webhookSecretToken } = getZoomConfig();
  return {
    plainToken,
    encryptedToken: crypto
      .createHmac('sha256', webhookSecretToken)
      .update(plainToken)
      .digest('hex'),
  };
};

const _findShiftsForZoomMeeting = async (meetingId) => {
  const normalizedMeetingId = String(meetingId || '').trim();
  if (!normalizedMeetingId) return [];

  const db = admin.firestore();
  const byId = new Map();
  const candidateFields = ['zoom_meeting_id', 'zoom_meeting_number'];
  for (const field of candidateFields) {
    const snapshot = await db.collection('teaching_shifts')
      .where(field, '==', normalizedMeetingId)
      .get();
    snapshot.docs.forEach((doc) => byId.set(doc.id, doc));
  }

  const numericMeetingId = Number(normalizedMeetingId);
  if (Number.isFinite(numericMeetingId)) {
    const snapshot = await db.collection('teaching_shifts')
      .where('zoom_meeting_id', '==', numericMeetingId)
      .get();
    snapshot.docs.forEach((doc) => byId.set(doc.id, doc));
  }

  return Array.from(byId.values());
};

const _shiftContainsUser = (shiftData, userId) => {
  if (!userId) return false;
  const teacherId = String(shiftData.teacher_id || shiftData.teacherId || '').trim();
  if (teacherId === userId) return true;
  return _normalizeUidList(shiftData.student_ids || shiftData.studentIds || [])
    .includes(userId);
};

const _selectShiftForZoomMeeting = async ({ meetingId, userId, at }) => {
  const shifts = await _findShiftsForZoomMeeting(meetingId);
  if (shifts.length <= 1) return shifts[0] || null;

  const atMs = (at || new Date()).getTime();
  const userMatches = userId
    ? shifts.filter((doc) => _shiftContainsUser(doc.data() || {}, userId))
    : shifts;
  const candidates = userMatches.length > 0 ? userMatches : shifts;
  const inWindow = candidates.filter((doc) =>
    _isWithinJoinWindow(doc.data() || {}, atMs));
  const ranked = (inWindow.length > 0 ? inWindow : candidates)
    .slice()
    .sort((a, b) => {
      const aStart = _toDate((a.data() || {}).shift_start || (a.data() || {}).shiftStart);
      const bStart = _toDate((b.data() || {}).shift_start || (b.data() || {}).shiftStart);
      const aDistance = aStart ? Math.abs(aStart.getTime() - atMs) : Number.MAX_SAFE_INTEGER;
      const bDistance = bStart ? Math.abs(bStart.getTime() - atMs) : Number.MAX_SAFE_INTEGER;
      return aDistance - bDistance;
    });
  return ranked[0] || null;
};

const _directUserIdFromParticipant = (participant) =>
  String(
    participant?.customer_key ||
    participant?.customerKey ||
    participant?.customerKeyValue ||
    '',
  ).trim();

const _isZoomHubBotParticipant = (participant) => {
  const customerKey = _directUserIdFromParticipant(participant).toLowerCase();
  const name = _zoomParticipantDisplayName(participant).toLowerCase();
  return (
    customerKey.startsWith('zoom_hub_bot_lane_') ||
    name.includes('alluwal hub bot lane')
  );
};

const _userIdFromParticipant = async ({ participant, shiftData }) => {
  const direct = _directUserIdFromParticipant(participant);
  if (direct && !_isZoomHubRoutingKey(direct)) return direct;

  const teacherId = String(shiftData.teacher_id || shiftData.teacherId || '').trim();
  const teacherName = String(shiftData.teacher_name || shiftData.teacherName || '')
    .trim()
    .toLowerCase();
  const participantName = _zoomParticipantDisplayName(participant).toLowerCase();
  if (teacherId && teacherName && participantName && participantName === teacherName) {
    return teacherId;
  }

  const zoomHostAccount = String(
    shiftData.zoom_host_email ||
    shiftData.zoom_host_account ||
    shiftData.zoomHostAccount ||
    '',
  ).trim().toLowerCase();
  const participantEmail = String(participant?.email || '').trim().toLowerCase();
  const participantUserId = String(participant?.user_id || participant?.id || '')
    .trim()
    .toLowerCase();

  if (
    zoomHostAccount &&
    (participantEmail === zoomHostAccount || participantUserId === zoomHostAccount)
  ) {
    return teacherId;
  }

  if (participantEmail) {
    for (const field of ['e-mail', 'email']) {
      const userSnapshot = await admin.firestore().collection('users')
        .where(field, '==', participantEmail)
        .limit(1)
        .get();
      if (!userSnapshot.empty) return userSnapshot.docs[0].id;
    }
  }

  return '';
};

const _roleForUserInShift = ({ userId, shiftData }) => {
  const teacherId = String(shiftData.teacher_id || shiftData.teacherId || '').trim();
  if (userId === teacherId) return 'teacher';
  const studentIds = _normalizeUidList(shiftData.student_ids || shiftData.studentIds || []);
  if (studentIds.includes(userId)) return 'student';
  return 'participant';
};

const _normalizeWindows = (raw) => {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((item) => item && typeof item === 'object')
    .map((item) => ({
      join_at: item.join_at,
      leave_at: item.leave_at ?? null,
    }));
};

const _findLastOpenWindowIndex = (windows) => {
  for (let i = windows.length - 1; i >= 0; i -= 1) {
    if (windows[i].leave_at == null) return i;
  }
  return -1;
};

const _clampedPresenceSeconds = ({ start, end, shiftStart, shiftEnd }) => {
  if (!start || !end || end <= start) return 0;
  let effectiveStart = start;
  let effectiveEnd = end;
  if (shiftStart && effectiveStart < shiftStart) effectiveStart = shiftStart;
  if (shiftEnd && effectiveEnd > shiftEnd) effectiveEnd = shiftEnd;
  if (effectiveEnd <= effectiveStart) return 0;
  return Math.floor((effectiveEnd.getTime() - effectiveStart.getTime()) / 1000);
};

const _recordZoomParticipantJoin = async ({ shiftDoc, userId, participant, at }) => {
  const db = admin.firestore();
  const shiftData = shiftDoc.data() || {};
  const nowDate = at || new Date();
  const nowTimestamp = admin.firestore.Timestamp.fromDate(nowDate);
  const shiftStart = _toDate(shiftData.shift_start || shiftData.shiftStart);
  const shiftEnd = _toDate(shiftData.shift_end || shiftData.shiftEnd);
  const docRef = db.collection('livekit_sessions').doc(`${shiftDoc.id}_${userId}`);
  const role = _roleForUserInShift({ userId, shiftData });

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    const existingData = snap.exists ? snap.data() || {} : {};
    const windows = _normalizeWindows(existingData.presence_windows);
    if (_findLastOpenWindowIndex(windows) === -1) {
      windows.push({ join_at: nowTimestamp, leave_at: null });
    }

    const joinsBeforeStart = shiftStart && nowDate < shiftStart ? 1 : 0;
    const lateBoundary = shiftStart
      ? new Date(shiftStart.getTime() + LATE_GRACE_MINUTES * 60 * 1000)
      : null;
    const joinsLate = lateBoundary && nowDate > lateBoundary ? 1 : 0;
    const firstJoinOffsetMinutes = shiftStart
      ? Math.round((nowDate.getTime() - shiftStart.getTime()) / 60000)
      : null;

    const baseData = {
      shift_id: shiftDoc.id,
      user_id: userId,
      role,
      joined_at: nowTimestamp,
      left_at: null,
      disconnect_reason: null,
      last_event: 'join',
      platform: 'zoom',
      room_name: String(shiftData.zoom_meeting_id || ''),
      zoom_participant_id: participant?.id || participant?.user_id || null,
      zoom_participant_name: participant?.user_name || participant?.userName || null,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      open_presence_since: nowTimestamp,
      presence_windows: windows,
      session_schema_version: 2,
      teacher_id: String(shiftData.teacher_id || shiftData.teacherId || ''),
      student_ids: _normalizeUidList(shiftData.student_ids || shiftData.studentIds || []),
    };
    if (shiftStart) {
      baseData.shift_start = admin.firestore.Timestamp.fromDate(shiftStart);
    }
    if (shiftEnd) {
      baseData.shift_end = admin.firestore.Timestamp.fromDate(shiftEnd);
    }

    if (!snap.exists) {
      const createData = {
        ...baseData,
        join_count: 1,
        leave_count: 0,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        first_joined_at: nowTimestamp,
        joins_before_start_count: joinsBeforeStart,
        joins_late_count: joinsLate,
        total_presence_seconds: 0,
      };
      if (firstJoinOffsetMinutes != null) {
        createData.first_join_offset_minutes = firstJoinOffsetMinutes;
      }
      if (shiftStart) {
        createData.first_join_before_start = nowDate < shiftStart;
      }
      tx.set(docRef, createData);
      return;
    }

    const updateData = {
      ...baseData,
      join_count: admin.firestore.FieldValue.increment(1),
      joins_before_start_count: admin.firestore.FieldValue.increment(joinsBeforeStart),
      joins_late_count: admin.firestore.FieldValue.increment(joinsLate),
    };
    if (existingData.first_joined_at == null) {
      updateData.first_joined_at = nowTimestamp;
      if (firstJoinOffsetMinutes != null) {
        updateData.first_join_offset_minutes = firstJoinOffsetMinutes;
        updateData.first_join_before_start = shiftStart ? nowDate < shiftStart : false;
      }
    }
    tx.set(docRef, updateData, { merge: true });
  });
};

const _recordZoomParticipantLeave = async ({ shiftDoc, userId, participant, at }) => {
  const db = admin.firestore();
  const shiftData = shiftDoc.data() || {};
  const nowDate = at || new Date();
  const nowTimestamp = admin.firestore.Timestamp.fromDate(nowDate);
  const shiftStart = _toDate(shiftData.shift_start || shiftData.shiftStart);
  const shiftEnd = _toDate(shiftData.shift_end || shiftData.shiftEnd);
  const docRef = db.collection('livekit_sessions').doc(`${shiftDoc.id}_${userId}`);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    const existingData = snap.exists ? snap.data() || {} : {};
    const windows = _normalizeWindows(existingData.presence_windows);
    let addedPresenceSeconds = 0;
    const openWindowIndex = _findLastOpenWindowIndex(windows);
    if (openWindowIndex !== -1) {
      const joinedAt = _toDate(windows[openWindowIndex].join_at);
      addedPresenceSeconds = _clampedPresenceSeconds({
        start: joinedAt,
        end: nowDate,
        shiftStart,
        shiftEnd,
      });
      windows[openWindowIndex] = {
        join_at: windows[openWindowIndex].join_at,
        leave_at: nowTimestamp,
      };
    }

    const updateData = {
      shift_id: shiftDoc.id,
      user_id: userId,
      role: _roleForUserInShift({ userId, shiftData }),
      leave_count: admin.firestore.FieldValue.increment(1),
      left_at: nowTimestamp,
      disconnect_reason: 'zoom_participant_left',
      last_event: 'leave',
      platform: 'zoom',
      room_name: String(shiftData.zoom_meeting_id || ''),
      zoom_participant_id: participant?.id || participant?.user_id || null,
      zoom_participant_name: participant?.user_name || participant?.userName || null,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      open_presence_since: null,
      presence_windows: windows,
      session_schema_version: 2,
      teacher_id: String(shiftData.teacher_id || shiftData.teacherId || ''),
      student_ids: _normalizeUidList(shiftData.student_ids || shiftData.studentIds || []),
    };
    if (shiftStart) {
      updateData.shift_start = admin.firestore.Timestamp.fromDate(shiftStart);
    }
    if (shiftEnd) {
      updateData.shift_end = admin.firestore.Timestamp.fromDate(shiftEnd);
    }
    if (addedPresenceSeconds > 0) {
      updateData.total_presence_seconds =
        admin.firestore.FieldValue.increment(addedPresenceSeconds);
    }
    tx.set(docRef, updateData, { merge: true });
  });
};

const _closeOpenSessionsForMeeting = async ({ shiftDoc, at }) => {
  const db = admin.firestore();
  const sessionsSnapshot = await db.collection('livekit_sessions')
    .where('shift_id', '==', shiftDoc.id)
    .get();
  for (const sessionDoc of sessionsSnapshot.docs) {
    const data = sessionDoc.data() || {};
    const windows = _normalizeWindows(data.presence_windows);
    if (_findLastOpenWindowIndex(windows) === -1) continue;
    const userId = String(data.user_id || '').trim();
    if (!userId) continue;
    await _recordZoomParticipantLeave({
      shiftDoc,
      userId,
      participant: {},
      at,
    });
  }
};

const _eventDate = (body, participant) => (
  _toDate(participant?.join_time) ||
  _toDate(participant?.leave_time) ||
  _toDate(body?.payload?.object?.end_time) ||
  _toDate(body?.event_ts) ||
  new Date()
);

const handleZoomPresenceWebhook = async (body) => {
  const event = String(body?.event || '').trim();
  const object = body?.payload?.object || {};
  const meetingId = object.id || object.meeting_id || object.meetingId;

  if (event === 'meeting.ended') {
    const shiftDocs = await _findShiftsForZoomMeeting(meetingId);
    if (shiftDocs.length === 0) {
      return { success: true, ignored: true, reason: 'shift_not_found' };
    }
    const endedAt = _eventDate(body, null);
    for (const shiftDoc of shiftDocs) {
      await _closeOpenSessionsForMeeting({ shiftDoc, at: endedAt });
    }
    return { success: true, closedOpenSessions: true, shiftCount: shiftDocs.length };
  }

  const participant = object.participant || {};
  if (_isZoomHubBotParticipant(participant)) {
    return { success: true, ignored: true, reason: 'hub_bot_participant' };
  }
  const at = _eventDate(body, participant);
  const directUserId = _directUserIdFromParticipant(participant);
  const hubMember = await _findHubMemberForRoutingKey({
    meetingId,
    routingKey: directUserId,
  }) || await _findHubMemberForRoutingDisplayName({
    meetingId,
    displayName: _zoomParticipantDisplayName(participant),
  });
  let shiftDoc = null;
  let userId = '';
  const participantForRecord = hubMember?.realDisplayName
    ? {
      ...participant,
      user_name: hubMember.realDisplayName,
      userName: hubMember.realDisplayName,
      displayName: hubMember.realDisplayName,
    }
    : participant;
  if (hubMember) {
    shiftDoc = await admin.firestore()
      .collection('teaching_shifts')
      .doc(hubMember.shiftId)
      .get();
    userId = hubMember.userId;
  } else {
    shiftDoc = await _selectShiftForZoomMeeting({
      meetingId,
      userId: directUserId,
      at,
    });
  }
  if (!shiftDoc || !shiftDoc.exists) {
    return { success: true, ignored: true, reason: 'shift_not_found' };
  }

  userId = userId || await _userIdFromParticipant({
    participant: participantForRecord,
    shiftData: shiftDoc.data() || {},
  });
  if (!userId) {
    return { success: true, ignored: true, reason: 'participant_not_mapped' };
  }

  if (event === 'meeting.participant_joined') {
    await _recordZoomParticipantJoin({ shiftDoc, userId, participant: participantForRecord, at });
    return { success: true, recorded: 'join', userId };
  }
  if (event === 'meeting.participant_left') {
    await _recordZoomParticipantLeave({ shiftDoc, userId, participant: participantForRecord, at });
    return { success: true, recorded: 'leave', userId };
  }
  return { success: true, ignored: true, reason: 'unsupported_event' };
};

const zoomWebhook = onRequest({
  cors: true,
  secrets: ZOOM_WEBHOOK_SECRETS,
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

  try {
    // Answer the endpoint validation challenge first: Zoom must be able to
    // register the URL, and the response itself is authenticated via the
    // secret-token HMAC, so it does not depend on the request signature.
    if (req.body?.event === 'endpoint.url_validation') {
      const plainToken = req.body?.payload?.plainToken;
      if (!plainToken) {
        res.status(400).json({ success: false, error: 'Missing plainToken' });
        return;
      }
      res.status(200).json(buildZoomWebhookValidationResponse(plainToken));
      return;
    }

    if (!verifyZoomWebhookSignature(req)) {
      res.status(401).json({ success: false, error: 'Invalid Zoom webhook signature' });
      return;
    }

    const result = await handleZoomPresenceWebhook(req.body || {});
    res.status(200).json(result);
  } catch (err) {
    console.error('[Zoom] Webhook failed:', err);
    res.status(500).json({
      success: false,
      error: err.message || 'Zoom webhook failed',
    });
  }
});

module.exports = {
  getZoomJoinInfo,
  getZoomHubCapacityForecast,
  getZoomHubRoutingStatus,
  setTeacherZoomEnabled,
  prepareZoomHubs,
  watchZoomHubBots,
  onTeachingShiftWritten,
  zoomWebhook,
  __test__: {
    _blockForShift,
    _buildHubRoomsForBlock,
    _buildZoomHubCapacityForecast,
    _hubMetaForShift,
    _buildZoomHubRoutingStatus,
    _hubWindowExceedsSafeZoomLifetime,
    _hubWindowForShiftDocs,
    _laneIndexForShift,
    _loadZoomHubBlockConfig,
    _writeZoomHubMember,
    buildZoomWebhookValidationResponse,
    handleZoomPresenceWebhook,
    verifyZoomWebhookSignature,
    generateMeetingSdkSignature,
  },
};
