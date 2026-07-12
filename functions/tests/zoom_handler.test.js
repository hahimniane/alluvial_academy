const crypto = require('crypto');

jest.mock('firebase-functions/v2/https', () => {
  const unwrap = (...args) => (typeof args[0] === 'function' ? args[0] : args[1]);
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {
    onCall: (...args) => unwrap(...args),
    onRequest: (...args) => unwrap(...args),
    HttpsError,
  };
});

jest.mock('firebase-functions/v2/scheduler', () => {
  const unwrap = (...args) => (typeof args[0] === 'function' ? args[0] : args[1]);
  return {
    onSchedule: (...args) => unwrap(...args),
  };
});

jest.mock('firebase-functions/v2/firestore', () => {
  const unwrap = (...args) => (typeof args[0] === 'function' ? args[0] : args[1]);
  return {
    onDocumentWritten: (...args) => unwrap(...args),
  };
});

const stores = {};

const makeTimestamp = (date) => ({
  _date: date,
  toDate: () => date,
  valueOf: () => date.getTime(),
});

const fieldValueIncrement = (amount) => ({ __op: 'increment', amount });
const serverTimestamp = () => makeTimestamp(new Date('2026-07-01T12:00:00.000Z'));

const getComparable = (value) => {
  if (value?.toDate) return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  return value;
};

const clone = (value) => {
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object') {
    if (value.toDate || value.__op) return value;
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, clone(item)]));
  }
  return value;
};

const applyData = (existing, data, merge = false) => {
  const next = merge ? { ...(existing || {}) } : {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value && value.__op === 'increment') {
      next[key] = (Number(next[key]) || 0) + value.amount;
    } else {
      next[key] = clone(value);
    }
  }
  return next;
};

const makeDocSnapshot = (collectionName, id) => {
  const data = stores[collectionName]?.get(id);
  const ref = makeDocRef(collectionName, id);
  return {
    id,
    exists: data !== undefined,
    ref,
    data: () => clone(data),
  };
};

const makeDocRef = (collectionName, id) => ({
  id,
  path: `${collectionName}/${id}`,
  get: async () => makeDocSnapshot(collectionName, id),
  set: async (data, options) => {
    if (!stores[collectionName]) stores[collectionName] = new Map();
    stores[collectionName].set(
      id,
      applyData(stores[collectionName].get(id), data, options?.merge === true),
    );
  },
  update: async (data) => {
    if (!stores[collectionName]) stores[collectionName] = new Map();
    stores[collectionName].set(
      id,
      applyData(stores[collectionName].get(id), data, true),
    );
  },
  collection: (name) => makeCollectionRef(`${collectionName}/${id}/${name}`),
});

const makeQuery = (collectionName, filters = [], limitValue = null) => ({
  where: (field, op, value) =>
    makeQuery(collectionName, [...filters, { field, op, value }], limitValue),
  limit: (value) => makeQuery(collectionName, filters, value),
  get: async () => {
    let docs = Array.from(stores[collectionName].entries())
      .map(([id]) => makeDocSnapshot(collectionName, id))
      .filter((doc) => {
        const data = doc.data() || {};
        return filters.every(({ field, op, value }) => {
          const actual = getComparable(data[field]);
          const expected = getComparable(value);
          if (op === '==') return actual === expected;
          if (op === '>=') return actual >= expected;
          if (op === '<=') return actual <= expected;
          if (op === '<') return actual < expected;
          throw new Error(`Unsupported op ${op}`);
        });
      });
    if (limitValue != null) docs = docs.slice(0, limitValue);
    return {
      empty: docs.length === 0,
      docs,
    };
  },
});

const makeCollectionRef = (name) => {
  if (!stores[name]) stores[name] = new Map();
  return {
    doc: (id) => makeDocRef(name, id),
    where: (field, op, value) => makeQuery(name).where(field, op, value),
    get: () => makeQuery(name).get(),
  };
};

const mockDb = {
  collection: (name) => makeCollectionRef(name),
  batch: () => {
    const operations = [];
    return {
      set: (ref, data, options) => operations.push(() => ref.set(data, options)),
      update: (ref, data) => operations.push(() => ref.update(data)),
      commit: async () => {
        for (const operation of operations) await operation();
      },
    };
  },
  runTransaction: async (callback) => callback({
    get: (ref) => ref.get(),
    set: (ref, data, options) => ref.set(data, options),
    update: (ref, data) => ref.update(data),
  }),
};

const mockFirestore = jest.fn(() => mockDb);
mockFirestore.FieldValue = {
  increment: fieldValueIncrement,
  serverTimestamp,
};
mockFirestore.Timestamp = {
  fromDate: makeTimestamp,
};
const mockSendEachForMulticast = jest.fn(async () => ({ successCount: 0, failureCount: 0 }));
const mockMessaging = jest.fn(() => ({
  sendEachForMulticast: mockSendEachForMulticast,
}));

jest.mock('firebase-admin', () => ({
  firestore: mockFirestore,
  messaging: mockMessaging,
}));

const mockSendMail = jest.fn(async () => ({}));
jest.mock('../services/email/transporter', () => ({
  createTransporter: jest.fn(() => ({
    sendMail: mockSendMail,
  })),
}));

const mockZoomClient = {
  createMeeting: jest.fn(),
  getMeeting: jest.fn(),
  getUserZak: jest.fn(),
  updateUserSettings: jest.fn(),
  updateMeeting: jest.fn(),
  deleteMeeting: jest.fn(),
  endMeeting: jest.fn(),
  listMeetingParticipants: jest.fn(),
};

jest.mock('../services/zoom/client', () => mockZoomClient);

const makeResponse = () => {
  const res = {
    statusCode: null,
    body: null,
    headers: {},
    set: jest.fn((key, value) => {
      res.headers[key] = value;
      return res;
    }),
    status: jest.fn((code) => {
      res.statusCode = code;
      return res;
    }),
    send: jest.fn((body) => {
      res.body = body;
      return res;
    }),
    json: jest.fn((body) => {
      res.body = body;
      return res;
    }),
  };
  return res;
};

const signBody = (body) => {
  const raw = JSON.stringify(body);
  const timestamp = '1782916800';
  const signature = `v0=${crypto
    .createHmac('sha256', 'webhook_secret')
    .update(`v0:${timestamp}:${raw}`)
    .digest('hex')}`;
  return {
    method: 'POST',
    body,
    rawBody: Buffer.from(raw),
    headers: {
      'x-zm-request-timestamp': timestamp,
      'x-zm-signature': signature,
    },
    get: (name) => ({
      'x-zm-request-timestamp': timestamp,
      'x-zm-signature': signature,
    }[name.toLowerCase()]),
  };
};

const addHubLoadShifts = ({
  count,
  laneIndex,
  start,
  end,
  idPrefix = `lane_${laneIndex}`,
}) => {
  for (let index = 0; index < count; index += 1) {
    stores.teaching_shifts.set(`${idPrefix}_${String(index).padStart(2, '0')}`, {
      teacher_id: `${idPrefix}_teacher_${index}`,
      teacher_name: `${idPrefix} Teacher ${index}`,
      student_ids: [`${idPrefix}_student_${index}`],
      student_names: [`${idPrefix} Student ${index}`],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: `${idPrefix} Load ${index}`,
      zoom_hub_lane_index: laneIndex,
    });
  }
};

describe('Zoom handler', () => {
  let zoomHandlers;

  beforeEach(() => {
    jest.clearAllMocks();
    jest.resetModules();
    process.env.ZOOM_WEBHOOK_SECRET_TOKEN = 'webhook_secret';
    process.env.ZOOM_SDK_KEY = 'sdk_key';
    process.env.ZOOM_SDK_SECRET = 'sdk_secret';
    delete process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS;
    delete process.env.ZOOM_HUB_MAX_CLASS_DURATION_MINUTES;
    delete process.env.ZOOM_HUB_BLOCK_BOUNDARIES;
    for (const key of Object.keys(stores)) stores[key].clear();
    stores.users = new Map();
    stores.teaching_shifts = new Map();
    stores.hub_meetings = new Map();
    stores.livekit_sessions = new Map();
    mockZoomClient.createMeeting.mockResolvedValue({
      id: 'created_meeting',
      password: 'passcode',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/created_meeting?pwd=passcode',
    });
    mockZoomClient.getMeeting.mockResolvedValue({
      id: 'existing_meeting',
      password: 'passcode',
      host_email: 'host@example.com',
      status: 'waiting',
    });
    mockZoomClient.getUserZak.mockResolvedValue('zak_token');
    mockZoomClient.updateUserSettings.mockResolvedValue({ success: true });
    mockZoomClient.updateMeeting.mockResolvedValue({ success: true });
    mockZoomClient.deleteMeeting.mockResolvedValue({ success: true });
    mockZoomClient.endMeeting.mockResolvedValue({ success: true });
    mockZoomClient.listMeetingParticipants.mockResolvedValue({ participants: [] });
    zoomHandlers = require('../handlers/zoom');
  });

  test('single-class teacher joins as participant even when the same Zoom host has another started meeting', async () => {
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('teacher_2', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.teaching_shifts.set('current_shift', {
      teacher_id: 'teacher_1',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      zoomRoutingMode: 'single',
      custom_name: 'Current Zoom Class',
    });
    stores.teaching_shifts.set('other_shift', {
      teacher_id: 'teacher_2',
      student_ids: ['student_2'],
      shift_start: makeTimestamp(new Date(now - 20 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 40 * 60 * 1000)),
      video_provider: 'zoom',
      zoom_meeting_id: 'other_meeting',
      custom_name: 'Other Zoom Class',
    });
    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'current_shift' },
    });

    expect(result.success).toBe(true);
    expect(result.provider).toBe('zoom');
    expect(result.userRole).toBe('teacher');
    expect(result.role).toBe(0);
    expect(result.zak).toBeNull();
    expect(result.signature).toBe(result.participantSignature);
    expect(mockZoomClient.createMeeting).toHaveBeenCalled();
    expect(mockZoomClient.getUserZak).not.toHaveBeenCalled();
  });

  test('teacher auth alias joins Zoom as teacher when verified email matches the assigned teacher record', async () => {
    const now = Date.now();
    stores.users.set('teacher_alias_doc', {
      user_type: 'teacher',
      email: 'teacher.alias@example.com',
      zoom_host_account: 'host@example.com',
    });
    stores.teaching_shifts.set('alias_shift', {
      teacher_id: 'teacher_alias_doc',
      teacher_name: 'Teacher Alias',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      zoomRoutingMode: 'single',
      custom_name: 'Alias Teacher Class',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: {
        uid: 'auth_uid_for_teacher_alias',
        token: { email: 'teacher.alias@example.com' },
      },
      data: { shiftId: 'alias_shift' },
    });

    expect(result.success).toBe(true);
    expect(result.userRole).toBe('teacher');
    expect(result.customerKey).toBe('auth_uid_for_teacher_alias');
  });

  test('honors active student role for an admin who is assigned as a student', async () => {
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('admin_1', {
      user_type: 'admin',
    });
    stores.teaching_shifts.set('multi_role_shift', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['admin_1'],
      student_names: ['Admin Student'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      zoomRoutingMode: 'single',
      custom_name: 'Multi Role Class',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { shiftId: 'multi_role_shift', activeRole: 'student' },
    });

    expect(result.success).toBe(true);
    expect(result.userRole).toBe('student');
    expect(result.customerKey).toBe('admin_1');
    expect(result.role).toBe(0);
  });

  test('does not apply student cutoff when the same assigned user joins Zoom as admin', async () => {
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('admin_1', {
      user_type: 'admin',
      access_suspended: true,
    });
    stores.teaching_shifts.set('multi_role_shift', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['admin_1'],
      student_names: ['Admin Student'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      zoomRoutingMode: 'single',
      custom_name: 'Multi Role Class',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { shiftId: 'multi_role_shift', activeRole: 'admin' },
    });

    expect(result.success).toBe(true);
    expect(result.userRole).toBe('admin');
    expect(result.customerKey).toBe('admin_1');
    expect(result.role).toBe(0);
  });

  test('allows teacher participant join when another host meeting is not started', async () => {
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('teacher_2', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.teaching_shifts.set('current_shift', {
      teacher_id: 'teacher_1',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      zoomRoutingMode: 'single',
      custom_name: 'Current Zoom Class',
    });
    stores.teaching_shifts.set('other_shift', {
      teacher_id: 'teacher_2',
      student_ids: ['student_2'],
      shift_start: makeTimestamp(new Date(now - 20 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 40 * 60 * 1000)),
      video_provider: 'zoom',
      zoom_meeting_id: 'other_meeting',
      custom_name: 'Other Zoom Class',
    });
    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'current_shift' },
    });

    expect(result.success).toBe(true);
    expect(result.provider).toBe('zoom');
    expect(result.userRole).toBe('teacher');
    expect(result.role).toBe(0);
    expect(result.zak).toBeNull();
    expect(result.signature).toBe(result.participantSignature);
    expect(result.joinUrl).toBe('https://zoom.us/j/created_meeting?pwd=passcode');
    expect(stores.teaching_shifts.get('current_shift').zoom_join_url)
      .toBe('https://zoom.us/j/created_meeting?pwd=passcode');
    expect(mockZoomClient.updateUserSettings).toHaveBeenCalledWith(
      'host@example.com',
      {
        in_meeting: {
          screen_sharing: true,
          who_can_share_screen: 'all',
          who_can_share_screen_when_someone_is_sharing: 'all',
          disable_screen_sharing_for_hosts_meetings: false,
          disable_screen_sharing_for_in_meeting_guests: false,
        },
      },
    );
    expect(mockZoomClient.createMeeting).toHaveBeenCalledWith(
      'host@example.com',
      expect.objectContaining({
        topic: 'Current Zoom Class',
        settings: expect.objectContaining({
          join_before_host: true,
          waiting_room: false,
          meeting_authentication: false,
        }),
      }),
    );
    expect(mockZoomClient.getUserZak).not.toHaveBeenCalled();
  });

  test('does not block Zoom join if host sharing setting update is denied', async () => {
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.teaching_shifts.set('current_shift', {
      teacher_id: 'teacher_1',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      zoomRoutingMode: 'single',
      custom_name: 'Current Zoom Class',
    });
    mockZoomClient.updateUserSettings.mockRejectedValueOnce(
      new Error('Invalid access token, does not contain scopes'),
    );

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'current_shift' },
    });

    expect(result.success).toBe(true);
    expect(result.userRole).toBe('teacher');
    expect(result.role).toBe(0);
    expect(mockZoomClient.createMeeting).toHaveBeenCalled();
    expect(mockZoomClient.getUserZak).not.toHaveBeenCalled();
  });

  test('normalizes stored single meeting settings before returning participant join info', async () => {
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.teaching_shifts.set('current_shift', {
      teacher_id: 'teacher_1',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      zoomRoutingMode: 'single',
      zoom_meeting_id: 'existing_meeting',
      zoom_password: 'stored_pass',
      custom_name: 'Current Zoom Class',
    });
    mockZoomClient.getMeeting.mockResolvedValueOnce({
      id: 'existing_meeting',
      password: 'passcode',
      host_email: 'host@example.com',
      status: 'waiting',
      join_url: 'https://zoom.us/j/existing_meeting?pwd=passcode',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'current_shift' },
    });

    expect(result.success).toBe(true);
    expect(result.role).toBe(0);
    expect(result.zak).toBeNull();
    expect(result.meetingNumber).toBe('existing_meeting');
    expect(mockZoomClient.updateMeeting).toHaveBeenCalledWith(
      'existing_meeting',
      expect.objectContaining({
        settings: expect.objectContaining({
          join_before_host: true,
          waiting_room: false,
          meeting_authentication: false,
        }),
      }),
    );
    expect(mockZoomClient.createMeeting).not.toHaveBeenCalled();
    expect(mockZoomClient.getUserZak).not.toHaveBeenCalled();
  });

  test('routes a new Zoom teaching shift through a block hub as a participant', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com,backup@example.com';
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'legacy-host@example.com',
    });
    stores.users.set('student_1', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift' },
    });

    const updatedShift = stores.teaching_shifts.get('hub_shift');
    expect(result.success).toBe(true);
    expect(result.meetingNumber).toBe('hub_meeting_1');
    expect(result.routingMode).toBe('hub');
    expect(result.role).toBe(0);
    expect(result.zak).toBeNull();
    expect(result.participantSignature).toBe(result.signature);
    expect(result.hubController).toBe(false);
    expect(result.autoOpenBreakoutRooms).toBe(false);
    expect(result.autoJoinBreakoutRoom).toBe(true);
    expect(typeof result.classEndsAtIso).toBe('string');
    expect(Number.isFinite(Date.parse(result.classEndsAtIso))).toBe(true);
    expect(result.breakoutRoomName).toContain('Teacher One');
    expect(result.hubBreakoutRooms).toEqual([]);
    expect(result.assignmentToken).toBe('');
    expect(updatedShift.zoom_meeting_id).toBe('hub_meeting_1');
    expect(updatedShift.zoomRoutingMode).toBe('hub');
    expect(updatedShift.breakoutRoomName).toBe(result.breakoutRoomName);
    expect(stores.hub_meetings.get(result.hubMeetingId).rooms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          shiftId: 'hub_shift',
          name: result.breakoutRoomName,
        }),
        expect.objectContaining({ spare: true }),
      ]),
    );
    expect(result.customerKey).toMatch(/^zh_/);
    expect(result.customerKey).not.toBe('teacher_1');
    expect(stores[`hub_meetings/${result.hubMeetingId}/members`].get(result.customerKey)).toEqual(
      expect.objectContaining({
        uid: result.customerKey,
        userId: 'teacher_1',
        shiftId: 'hub_shift',
        role: 'teacher',
      }),
    );
    expect(mockZoomClient.updateMeeting).toHaveBeenCalledWith(
      'hub_meeting_1',
      expect.objectContaining({
        settings: expect.objectContaining({
          breakout_room: expect.objectContaining({ enable: true }),
        }),
      }),
    );
  });

  test('routes legacy stored teaching Zoom meetings through the hub unless explicitly single', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com,backup@example.com';
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'legacy-host@example.com',
    });
    stores.users.set('student_1', { user_type: 'student' });
    stores.teaching_shifts.set('legacy_shift', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      zoom_meeting_id: 'old_single_meeting',
      custom_name: 'Legacy Stored Class',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'legacy_shift' },
    });

    const updatedShift = stores.teaching_shifts.get('legacy_shift');
    expect(result.success).toBe(true);
    expect(result.routingMode).toBe('hub');
    expect(result.meetingNumber).toBe('hub_meeting_1');
    expect(result.role).toBe(0);
    expect(result.zak).toBeNull();
    expect(result.hubController).toBe(false);
    expect(result.breakoutRoomName).toContain('Teacher One');
    expect(updatedShift.zoom_meeting_id).toBe('hub_meeting_1');
    expect(updatedShift.zoomRoutingMode).toBe('hub');
    expect(mockZoomClient.createMeeting).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        topic: expect.stringContaining('Alluwal Classrooms'),
      }),
    );
  });

  test('hub teachers rejoin as participants even when the hub meeting is already started', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com';
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('student_1', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const firstResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift' },
    });
    mockZoomClient.getMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
      status: 'started',
    });
    const rejoinResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift' },
    });

    expect(firstResult.role).toBe(0);
    expect(firstResult.hubController).toBe(false);
    expect(rejoinResult.success).toBe(true);
    expect(rejoinResult.userRole).toBe('teacher');
    expect(rejoinResult.role).toBe(0);
    expect(rejoinResult.zak).toBeNull();
    expect(rejoinResult.participantSignature).toBe(rejoinResult.signature);
    expect(rejoinResult.meetingNumber).toBe(firstResult.meetingNumber);
    expect(rejoinResult.hubMeetingId).toBe(firstResult.hubMeetingId);
    expect(rejoinResult.hubController).toBe(false);
    expect(rejoinResult.autoOpenBreakoutRooms).toBe(false);
    expect(rejoinResult.autoJoinBreakoutRoom).toBe(true);
    expect(rejoinResult.hostRoleBlockedReason).toBe('');
    expect(rejoinResult.customerKey).toMatch(/^zh_/);
    expect(stores[`hub_meetings/${rejoinResult.hubMeetingId}/members`].get(rejoinResult.customerKey)).toEqual(
      expect.objectContaining({ userId: 'teacher_1', shiftId: 'hub_shift', role: 'teacher' }),
    );
    expect(mockZoomClient.getUserZak).not.toHaveBeenCalled();
  });

  test('hub-routed teachers do not need personal Zoom host accounts', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com,backup@example.com';
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
    });
    stores.users.set('student_1', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift' },
    });

    expect(result.success).toBe(true);
    expect(result.routingMode).toBe('hub');
    expect(result.role).toBe(0);
    expect(result.zak).toBeNull();
    expect(result.hubController).toBe(false);
    expect(result.autoJoinBreakoutRoom).toBe(true);
    expect(mockZoomClient.createMeeting).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        topic: expect.stringContaining('Alluwal Classrooms'),
      }),
    );
  });

  test('routes additional hub teachers as participants while a fresh lane controller exists', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com';
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('teacher_a', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('student_1', { user_type: 'student' });
    stores.users.set('student_2', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift_1', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class 1',
    });
    stores.teaching_shifts.set('hub_shift_2', {
      teacher_id: 'teacher_a',
      teacher_name: 'Teacher Two',
      student_ids: ['student_2'],
      student_names: ['Student Two'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class 2',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const controllerResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift_1' },
    });
    const secondTeacherResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_a' },
      data: { shiftId: 'hub_shift_2' },
    });

    expect(controllerResult.success).toBe(true);
    expect(controllerResult.role).toBe(0);
    expect(controllerResult.hubController).toBe(false);
    expect(controllerResult.autoOpenBreakoutRooms).toBe(false);

    expect(secondTeacherResult.success).toBe(true);
    expect(secondTeacherResult.userRole).toBe('teacher');
    expect(secondTeacherResult.role).toBe(0);
    expect(secondTeacherResult.zak).toBeNull();
    expect(secondTeacherResult.meetingNumber).toBe(controllerResult.meetingNumber);
    expect(secondTeacherResult.hubMeetingId).toBe(controllerResult.hubMeetingId);
    expect(secondTeacherResult.hubController).toBe(false);
    expect(secondTeacherResult.autoOpenBreakoutRooms).toBe(false);
    expect(secondTeacherResult.autoJoinBreakoutRoom).toBe(true);
    expect(secondTeacherResult.breakoutRoomName).toContain('Teacher Two');
    expect(secondTeacherResult.targetBreakoutRoom).toEqual(
      expect.objectContaining({ shiftId: 'hub_shift_2' }),
    );
    expect(secondTeacherResult.hubBreakoutRooms).toEqual([]);
    expect(stores[`hub_meetings/${controllerResult.hubMeetingId}/members`].get(controllerResult.customerKey)).toEqual(
      expect.objectContaining({ userId: 'teacher_1', shiftId: 'hub_shift_1', role: 'teacher' }),
    );
    expect(stores[`hub_meetings/${controllerResult.hubMeetingId}/members`].get(secondTeacherResult.customerKey)).toEqual(
      expect.objectContaining({ userId: 'teacher_a', shiftId: 'hub_shift_2', role: 'teacher' }),
    );
    expect(mockZoomClient.getUserZak).not.toHaveBeenCalled();
  });

  test('prepares all same-segment hub rooms plus spares before rooms are opened', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com';
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('teacher_a', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    stores.users.set('student_1', { user_type: 'student' });
    stores.users.set('student_2', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift_1', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class 1',
    });
    stores.teaching_shifts.set('hub_shift_2', {
      teacher_id: 'teacher_a',
      teacher_name: 'Teacher Two',
      student_ids: ['student_2'],
      student_names: ['Student Two'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class 2',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const controllerResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift_1' },
    });

    const hub = stores.hub_meetings.get(controllerResult.hubMeetingId);
    expect(hub.rooms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ shiftId: 'hub_shift_1' }),
        expect.objectContaining({ shiftId: 'hub_shift_2' }),
        expect.objectContaining({ shiftId: '__spare_1', spare: true }),
        expect.objectContaining({ shiftId: '__spare_5', spare: true }),
      ]),
    );
    expect(hub.room_count).toBe(7);
    expect(controllerResult.role).toBe(0);
    expect(mockZoomClient.getUserZak).not.toHaveBeenCalled();
  });

  test('hub routing does not require a personal teacher Zoom host record', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com';
    const now = Date.now();
    stores.users.set('student_1', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift_missing_teacher_doc', {
      teacher_id: 'missing_teacher_doc',
      teacher_name: 'Missing Teacher',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Class With Missing Teacher Doc',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_missing_teacher_doc',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_missing_teacher_doc?pwd=hub_pass',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'missing_teacher_doc' },
      data: { shiftId: 'hub_shift_missing_teacher_doc' },
    });

    expect(result.success).toBe(true);
    expect(result.routingMode).toBe('hub');
    expect(result.autoJoinBreakoutRoom).toBe(true);
    expect(result.meetingNumber).toBe('hub_meeting_missing_teacher_doc');
    expect(stores.teaching_shifts.get('hub_shift_missing_teacher_doc')).toEqual(
      expect.objectContaining({
        zoomRoutingMode: 'hub',
        zoom_host_account: 'host@example.com',
      }),
    );
  });

  test('routes a late-added class into a spare room after hub rooms are already open', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com';
    const now = Date.now();
    const start = new Date(now - 5 * 60 * 1000);
    const end = new Date(now + 55 * 60 * 1000);
    stores.users.set('teacher_1', { user_type: 'teacher' });
    stores.users.set('teacher_late', { user_type: 'teacher' });
    stores.users.set('student_1', { user_type: 'student' });
    stores.users.set('student_late', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift_1', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Original Hub Class',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const firstResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift_1' },
    });
    const firstHub = stores.hub_meetings.get(firstResult.hubMeetingId);
    stores.hub_meetings.set(firstResult.hubMeetingId, {
      ...firstHub,
      status: 'roomsOpen',
      spares: {
        'Spare 1': null,
        'Spare 2': null,
        'Spare 3': null,
        'Spare 4': null,
        'Spare 5': null,
      },
    });
    const updateMeetingCallsAfterOpen = mockZoomClient.updateMeeting.mock.calls.length;

    stores.teaching_shifts.set('late_shift', {
      teacher_id: 'teacher_late',
      teacher_name: 'Late Teacher',
      student_ids: ['student_late'],
      student_names: ['Late Student'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Late Hub Class',
    });

    const lateResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_late' },
      data: { shiftId: 'late_shift' },
    });

    const hub = stores.hub_meetings.get(firstResult.hubMeetingId);
    const roomNames = hub.rooms.map((room) => room.name);
    expect(lateResult.success).toBe(true);
    expect(lateResult.routingMode).toBe('hub');
    expect(lateResult.meetingNumber).toBe('hub_meeting_1');
    expect(lateResult.breakoutRoomName).toBe('Spare 1');
    expect(lateResult.targetBreakoutRoom).toEqual(
      expect.objectContaining({ shiftId: 'late_shift', name: 'Spare 1', spare: true }),
    );
    expect(hub.rooms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ shiftId: 'hub_shift_1' }),
        expect.objectContaining({ shiftId: 'late_shift', name: 'Spare 1', spare: true }),
      ]),
    );
    expect(roomNames.filter((name) => name === 'Spare 1')).toHaveLength(1);
    expect(hub.spares['Spare 1']).toBe('late_shift');
    expect(stores.teaching_shifts.get('late_shift')).toEqual(
      expect.objectContaining({
        breakoutRoomName: 'Spare 1',
        zoom_meeting_id: 'hub_meeting_1',
        zoomRoutingMode: 'hub',
      }),
    );
    expect(mockZoomClient.updateMeeting).toHaveBeenCalledTimes(updateMeetingCallsAfterOpen);
  });

  test('hands a stale hub join to a healthy active hub spare room', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host-one@example.com,host-two@example.com';
    const now = Date.now();
    const start = new Date(now - 5 * 60 * 1000);
    const end = new Date(now + 170 * 60 * 1000);
    stores.users.set('teacher_billing', { user_type: 'teacher' });
    stores.users.set('student_billing', { user_type: 'student' });

    const shiftData = {
      teacher_id: 'teacher_billing',
      teacher_name: 'Billing Teacher',
      student_ids: ['student_billing'],
      student_names: ['Billing Student'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Billing Test',
      zoom_hub_lane_index: 1,
    };
    stores.teaching_shifts.set('billing_shift', shiftData);

    const oldMeta = await zoomHandlers.__test__._hubMetaForShift({
      shiftId: 'billing_shift',
      shiftData,
    });
    stores.hub_meetings.set(oldMeta.hubDocId, {
      dayKey: oldMeta.dayKey,
      blockIndex: oldMeta.blockIndex,
      laneIndex: oldMeta.laneIndex,
      lane: oldMeta.lane,
      hostAccount: oldMeta.hostAccount,
      status: 'roomsOpen',
      meetingNumber: 'old_stale_meeting',
      zoom_meeting_id: 'old_stale_meeting',
      zoom_password: 'old_pass',
      window_start: makeTimestamp(new Date(now - 30 * 60 * 1000)),
      window_end: makeTimestamp(new Date(end.getTime() + 15 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 60 * 1000)),
      rooms: [
        { shiftId: 'billing_shift', name: 'Spare 1', teacherId: 'teacher_billing', studentIds: ['student_billing'], spare: true },
        { shiftId: '__spare_2', name: 'Spare 2', teacherId: '', studentIds: [], spare: true },
        { shiftId: '__spare_3', name: 'Spare 3', teacherId: '', studentIds: [], spare: true },
        { shiftId: '__spare_4', name: 'Spare 4', teacherId: '', studentIds: [], spare: true },
        { shiftId: '__spare_5', name: 'Spare 5', teacherId: '', studentIds: [], spare: true },
      ],
      spares: {
        'Spare 1': 'billing_shift',
        'Spare 2': null,
        'Spare 3': null,
        'Spare 4': null,
        'Spare 5': null,
      },
    });

    stores.hub_meetings.set('healthy_hub', {
      dayKey: oldMeta.dayKey,
      blockIndex: oldMeta.blockIndex + 1,
      laneIndex: 0,
      lane: 1,
      hostAccount: 'host-one@example.com',
      status: 'roomsOpen',
      meetingNumber: 'fresh_meeting',
      zoom_meeting_id: 'fresh_meeting',
      zoom_password: 'fresh_pass',
      window_start: makeTimestamp(new Date(now - 30 * 60 * 1000)),
      window_end: makeTimestamp(new Date(end.getTime() + 30 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 30 * 1000)),
      rooms: [
        { shiftId: 'other_shift', name: 'Other Room', teacherId: 'other_teacher', studentIds: [] },
        { shiftId: '__spare_1', name: 'Spare 1', teacherId: '', studentIds: [], spare: true },
        { shiftId: '__spare_2', name: 'Spare 2', teacherId: '', studentIds: [], spare: true },
        { shiftId: '__spare_3', name: 'Spare 3', teacherId: '', studentIds: [], spare: true },
        { shiftId: '__spare_4', name: 'Spare 4', teacherId: '', studentIds: [], spare: true },
        { shiftId: '__spare_5', name: 'Spare 5', teacherId: '', studentIds: [], spare: true },
      ],
      spares: {
        'Spare 1': null,
        'Spare 2': null,
        'Spare 3': null,
        'Spare 4': null,
        'Spare 5': null,
      },
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_billing' },
      data: { shiftId: 'billing_shift' },
    });

    expect(result.success).toBe(true);
    expect(result.routingMode).toBe('hub');
    expect(result.hubMeetingId).toBe('healthy_hub');
    expect(result.meetingNumber).toBe('fresh_meeting');
    expect(result.password).toBe('fresh_pass');
    expect(result.breakoutRoomName).toBe('Spare 1');
    expect(result.targetBreakoutRoom).toEqual(
      expect.objectContaining({ shiftId: 'billing_shift', name: 'Spare 1', spare: true }),
    );
    expect(stores.hub_meetings.get('healthy_hub').spares['Spare 1'])
      .toBe('billing_shift');
    expect(stores.hub_meetings.get('healthy_hub').rooms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ shiftId: 'billing_shift', name: 'Spare 1', spare: true }),
      ]),
    );
    expect(stores.teaching_shifts.get('billing_shift')).toEqual(
      expect.objectContaining({
        hubMeetingId: 'healthy_hub',
        hub_meeting_id: 'healthy_hub',
        zoom_meeting_id: 'fresh_meeting',
        breakoutRoomName: 'Spare 1',
        zoom_hub_handoff_from: oldMeta.hubDocId,
      }),
    );
    expect(stores[`hub_meetings/healthy_hub/members`].get(result.customerKey)).toEqual(
      expect.objectContaining({
        userId: 'teacher_billing',
        shiftId: 'billing_shift',
        role: 'teacher',
      }),
    );
    expect(stores.system_alerts.get(`${oldMeta.hubDocId}_billing_shift_stale_handoff`))
      .toEqual(expect.objectContaining({ reason: 'stale_hub_handoff', severity: 'warning' }));
  });

  test('blocks and logs an overlong hub-routed shift on direct Firestore write', async () => {
    const now = Date.now();
    stores.teaching_shifts.set('too_long_shift', {
      teacher_id: 'teacher_long',
      teacher_name: 'Long Teacher',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now + 30 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 5 * 60 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Too Long Zoom Class',
    });

    await zoomHandlers.onTeachingShiftWritten({
      params: { shiftId: 'too_long_shift' },
      data: {
        before: { exists: false, data: () => ({}) },
        after: makeDocSnapshot('teaching_shifts', 'too_long_shift'),
      },
    });

    expect(stores.teaching_shifts.get('too_long_shift')).toEqual(
      expect.objectContaining({
        zoom_hub_guardrail_blocked: true,
        zoom_hub_guardrail_reason: 'duration_exceeds_limit',
        zoomRoutingMode: 'blocked',
        zoom_routing_mode: 'blocked',
        zoom_disable_hub_routing: true,
      }),
    );
    expect(stores.system_alerts.get('too_long_shift_zoom_hub_guardrail'))
      .toEqual(expect.objectContaining({
        reason: 'zoom_hub_shift_guardrail',
        severity: 'warning',
        data: expect.objectContaining({
          shiftId: 'too_long_shift',
          guardrailReason: 'duration_exceeds_limit',
        }),
      }));
    expect(mockZoomClient.createMeeting).not.toHaveBeenCalled();
  });

  test('does not route no-student admin clock-in shifts through Zoom hubs', async () => {
    const now = Date.now();
    stores.users.set('admin_teacher', { role: 'admin', user_type: 'admin' });
    stores.teaching_shifts.set('admin_clock_shift', {
      teacher_id: 'admin_teacher',
      teacher_name: 'Admin Teacher',
      student_ids: [],
      student_names: [],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 7 * 60 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Admin clock-in shift',
    });

    await zoomHandlers.onTeachingShiftWritten({
      params: { shiftId: 'admin_clock_shift' },
      data: {
        before: { exists: false, data: () => ({}) },
        after: makeDocSnapshot('teaching_shifts', 'admin_clock_shift'),
      },
    });

    expect(stores.teaching_shifts.get('admin_clock_shift'))
      .not.toEqual(expect.objectContaining({
        zoom_hub_guardrail_blocked: true,
      }));
    expect(stores.system_alerts.get('admin_clock_shift_zoom_hub_guardrail'))
      .toBeUndefined();
    await expect(zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'admin_teacher', token: { role: 'admin' } },
      data: { shiftId: 'admin_clock_shift' },
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('clock-in/admin work'),
    });
    expect(mockZoomClient.createMeeting).not.toHaveBeenCalled();
  });

  test('records blocked Zoom shift attempts for admin review', async () => {
    stores.users.set('admin_1', {
      role: 'admin',
      user_type: 'admin',
      first_name: 'Aisha',
      last_name: 'Admin',
      'e-mail': 'admin@example.com',
    });

    const result = await zoomHandlers.recordZoomHubGuardrailAttempt({
      auth: { uid: 'admin_1', token: {} },
      data: {
        operation: 'create_shift',
        source: 'create_shift_dialog',
        message: 'This class is too long for Zoom routing.',
        shiftAttempt: {
          teacherId: 'teacher_1',
          teacherName: 'Teacher One',
          teacherEmail: 'teacher@example.com',
          studentIds: ['student_1'],
          studentNames: ['Student One'],
          shiftStartIso: '2026-07-09T17:00:00.000Z',
          shiftEndIso: '2026-07-09T22:00:00.000Z',
          timezone: 'America/New_York',
          customName: 'Billing Test',
          notes: 'Admin typed this before save.',
        },
      },
    });

    expect(result).toEqual(expect.objectContaining({
      success: true,
      attemptId: expect.stringContaining('zoom_hub_guardrail_attempt_'),
    }));
    expect(stores.system_alerts.get(result.attemptId)).toEqual(
      expect.objectContaining({
        type: 'zoom_hub_shift_guardrail',
        severity: 'warning',
        reason: 'zoom_hub_shift_guardrail',
        attemptedByUid: 'admin_1',
        attemptedByEmail: 'admin@example.com',
        attemptedByName: 'Aisha Admin',
        guardrailMessage: 'This class is too long for Zoom routing.',
        shiftAttempt: expect.objectContaining({
          teacherId: 'teacher_1',
          teacherName: 'Teacher One',
          studentNames: ['Student One'],
          customName: 'Billing Test',
          notes: 'Admin typed this before save.',
        }),
      }),
    );
    expect(stores.admin_notifications.get(result.notificationId)).toEqual(
      expect.objectContaining({
        type: 'zoom_hub_shift_guardrail',
        action_required: true,
        read: false,
        systemAlertId: result.systemAlertId,
        attemptedByUid: 'admin_1',
      }),
    );
  });

  test('rejects join attempts for unsafe hub-routed shift times', async () => {
    const now = Date.now();
    stores.users.set('teacher_long', { user_type: 'teacher' });
    stores.teaching_shifts.set('join_too_long_shift', {
      teacher_id: 'teacher_long',
      teacher_name: 'Long Teacher',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 4 * 60 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Join Too Long Zoom Class',
    });

    await expect(zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_long', token: {} },
      data: { shiftId: 'join_too_long_shift' },
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('was not created'),
    });

    expect(stores.teaching_shifts.get('join_too_long_shift'))
      .toEqual(expect.objectContaining({ zoom_hub_guardrail_blocked: true }));
    expect(stores.system_alerts.get('join_too_long_shift_zoom_hub_guardrail'))
      .toEqual(expect.objectContaining({ reason: 'zoom_hub_shift_guardrail' }));
    expect(mockZoomClient.createMeeting).not.toHaveBeenCalled();
  });

  test('allows normal classes that cross a soft routing block boundary', () => {
    const decision = zoomHandlers.__test__._zoomHubShiftGuardrailDecision({
      shift_start: makeTimestamp(new Date('2026-07-09T20:30:00.000Z')),
      shift_end: makeTimestamp(new Date('2026-07-09T22:00:00.000Z')),
    }, {
      timezone: 'America/New_York',
      boundaries: [300, 720, 1020],
      boundaryLabels: ['05:00', '12:00', '17:00'],
      concurrentMeetingsPerUser: 1,
    });

    expect(decision.ok).toBe(true);
    expect(decision.details.crossesSoftHubBlock).toBe(true);
  });

  test('plans overlapping cross-boundary classes into one rolling hub segment', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com';
    const crossBoundaryShift = {
      teacher_id: 'teacher_cross',
      teacher_name: 'Cross Teacher',
      student_ids: ['student_cross'],
      student_names: ['Cross Student'],
      shift_start: makeTimestamp(new Date('2026-07-09T20:00:00.000Z')),
      shift_end: makeTimestamp(new Date('2026-07-09T21:30:00.000Z')),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Cross Boundary Class',
      zoom_hub_lane_index: 0,
    };
    const nextBlockShift = {
      teacher_id: 'teacher_next',
      teacher_name: 'Next Teacher',
      student_ids: ['student_next'],
      student_names: ['Next Student'],
      shift_start: makeTimestamp(new Date('2026-07-09T21:00:00.000Z')),
      shift_end: makeTimestamp(new Date('2026-07-09T22:00:00.000Z')),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Next Block Class',
      zoom_hub_lane_index: 0,
    };
    stores.teaching_shifts.set('cross_shift', crossBoundaryShift);
    stores.teaching_shifts.set('next_shift', nextBlockShift);

    const crossMeta = await zoomHandlers.__test__._hubMetaForShift({
      shiftId: 'cross_shift',
      shiftData: crossBoundaryShift,
    });
    const nextMeta = await zoomHandlers.__test__._hubMetaForShift({
      shiftId: 'next_shift',
      shiftData: nextBlockShift,
    });
    const roomPlan = await zoomHandlers.__test__._buildHubRoomsForBlock({
      meta: crossMeta,
      targetShiftId: 'cross_shift',
      targetShiftData: crossBoundaryShift,
      hubData: {},
    });

    expect(crossMeta.hubDocId).toBe(nextMeta.hubDocId);
    expect(crossMeta.rollingSegment).toBe(true);
    expect(crossMeta.segmentShiftIds).toEqual(['cross_shift', 'next_shift']);
    expect(crossMeta.segmentLabel).toBe('16:00-18:00');
    expect(roomPlan.rooms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ shiftId: 'cross_shift' }),
        expect.objectContaining({ shiftId: 'next_shift' }),
        expect.objectContaining({ shiftId: '__spare_1', spare: true }),
        expect.objectContaining({ shiftId: '__spare_5', spare: true }),
      ]),
    );
    expect(roomPlan.targetRoom).toEqual(
      expect.objectContaining({ shiftId: 'cross_shift' }),
    );
  });

  test('falls back to single Zoom when an open hub has no spare rooms left', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com';
    const now = Date.now();
    const start = new Date(now - 5 * 60 * 1000);
    const end = new Date(now + 55 * 60 * 1000);
    stores.users.set('teacher_1', { user_type: 'teacher' });
    stores.users.set('teacher_late', {
      user_type: 'teacher',
      zoom_host_account: 'teacher-host@example.com',
    });
    stores.users.set('student_1', { user_type: 'student' });
    stores.users.set('student_late', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift_1', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Original Hub Class',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    }).mockResolvedValueOnce({
      id: 'single_late_meeting',
      password: 'single_pass',
      host_email: 'teacher-host@example.com',
      join_url: 'https://zoom.us/j/single_late_meeting?pwd=single_pass',
    });

    const firstResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift_1' },
    });
    const firstHub = stores.hub_meetings.get(firstResult.hubMeetingId);
    stores.hub_meetings.set(firstResult.hubMeetingId, {
      ...firstHub,
      status: 'roomsOpen',
      rooms: [
        ...firstHub.rooms.filter((room) => room.shiftId === 'hub_shift_1'),
        { shiftId: 'filled_spare_1', name: 'Spare 1', teacherId: 'spare_teacher_1', studentIds: [], spare: true },
        { shiftId: 'filled_spare_2', name: 'Spare 2', teacherId: 'spare_teacher_2', studentIds: [], spare: true },
        { shiftId: 'filled_spare_3', name: 'Spare 3', teacherId: 'spare_teacher_3', studentIds: [], spare: true },
        { shiftId: 'filled_spare_4', name: 'Spare 4', teacherId: 'spare_teacher_4', studentIds: [], spare: true },
        { shiftId: 'filled_spare_5', name: 'Spare 5', teacherId: 'spare_teacher_5', studentIds: [], spare: true },
      ],
      spares: {
        'Spare 1': 'filled_spare_1',
        'Spare 2': 'filled_spare_2',
        'Spare 3': 'filled_spare_3',
        'Spare 4': 'filled_spare_4',
        'Spare 5': 'filled_spare_5',
      },
    });
    stores.teaching_shifts.set('late_shift', {
      teacher_id: 'teacher_late',
      teacher_name: 'Late Teacher',
      student_ids: ['student_late'],
      student_names: ['Late Student'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Late Hub Class',
    });

    const lateResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_late' },
      data: { shiftId: 'late_shift' },
    });

    expect(lateResult.success).toBe(true);
    expect(lateResult.routingMode).toBe('single');
    expect(lateResult.autoJoinBreakoutRoom).toBe(false);
    expect(lateResult.meetingNumber).toBe('single_late_meeting');
    expect(lateResult.breakoutRoomName).toBe('');
    expect(stores.teaching_shifts.get('late_shift')).toEqual(
      expect.objectContaining({
        zoomRoutingMode: 'single',
        zoom_routing_mode: 'single',
        zoom_disable_hub_routing: true,
        zoom_hub_fallback_reason: 'spares_exhausted',
        zoom_meeting_id: 'single_late_meeting',
      }),
    );
    expect(stores.hub_meetings.get(firstResult.hubMeetingId).rooms
      .some((room) => room.shiftId === 'late_shift'))
      .toBe(false);
    expect(stores.system_alerts.get('late_shift_spares_exhausted')).toEqual(
      expect.objectContaining({
        reason: 'spares_exhausted',
        severity: 'critical',
      }),
    );
    expect(mockZoomClient.createMeeting).toHaveBeenCalledWith(
      'teacher-host@example.com',
      expect.objectContaining({ topic: 'Late Hub Class' }),
    );
  });

  test('spills an overflowing hub class to the other licensed lane', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host-one@example.com,host-two@example.com';
    const now = Date.now();
    const start = new Date(now - 5 * 60 * 1000);
    const end = new Date(now + 55 * 60 * 1000);
    stores.users.set('teacher_target', { user_type: 'teacher' });
    stores.users.set('student_target', { user_type: 'student' });
    stores.users.set('admin_1', {
      role: 'admin',
      email: 'admin@example.com',
      fcmToken: 'admin_token',
    });
    addHubLoadShifts({
      count: 43,
      laneIndex: 0,
      start,
      end,
      idPrefix: 'lane0_load',
    });
    stores.teaching_shifts.set('zz_overflow_target', {
      teacher_id: 'teacher_target',
      teacher_name: 'Target Teacher',
      student_ids: ['student_target'],
      student_names: ['Target Student'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Overflow Target Class',
      zoom_hub_lane_index: 0,
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'lane_two_hub',
      password: 'hub_pass',
      host_email: 'host-two@example.com',
      join_url: 'https://zoom.us/j/lane_two_hub?pwd=hub_pass',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_target' },
      data: { shiftId: 'zz_overflow_target' },
    });

    const updatedShift = stores.teaching_shifts.get('zz_overflow_target');
    expect(result.success).toBe(true);
    expect(result.routingMode).toBe('hub');
    expect(result.meetingNumber).toBe('lane_two_hub');
    expect(result.hubMeetingId).toMatch(/_2$/);
    expect(result.breakoutRoomName).toContain('Target Teacher');
    expect(updatedShift.zoom_hub_lane_index).toBe(1);
    expect(updatedShift.zoom_hub_overflow_from_lane).toBe(0);
    expect(stores.hub_meetings.get(result.hubMeetingId).hostAccount).toBe('host-two@example.com');
    expect(stores.system_alerts.get('zz_overflow_target_spilled_to_lane_2')).toEqual(
      expect.objectContaining({
        reason: 'spilled_to_other_lane',
        severity: 'warning',
      }),
    );
    expect(mockSendMail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'admin@example.com',
      subject: 'Zoom hub class moved to another lane',
    }));
    expect(mockSendEachForMulticast).toHaveBeenCalledWith(expect.objectContaining({
      tokens: ['admin_token'],
    }));
  });

  test('scheduler proactively prepares overflow classes on the alternate lane', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host-one@example.com,host-two@example.com';
    const now = Date.now();
    const start = new Date(now + 30 * 60 * 1000);
    const end = new Date(now + 90 * 60 * 1000);
    stores.users.set('admin_1', {
      role: 'admin',
      email: 'admin@example.com',
    });
    addHubLoadShifts({
      count: 44,
      laneIndex: 0,
      start,
      end,
      idPrefix: 'sched_overflow',
    });
    mockZoomClient.createMeeting
      .mockResolvedValueOnce({
        id: 'lane_one_sched_hub',
        password: 'hub_pass',
        host_email: 'host-one@example.com',
        join_url: 'https://zoom.us/j/lane_one_sched_hub?pwd=hub_pass',
      })
      .mockResolvedValueOnce({
        id: 'lane_two_sched_hub',
        password: 'hub_pass',
        host_email: 'host-two@example.com',
        join_url: 'https://zoom.us/j/lane_two_sched_hub?pwd=hub_pass',
      });

    await zoomHandlers.prepareZoomHubs();

    const hubEntries = Array.from(stores.hub_meetings.entries());
    const laneOneHub = hubEntries.find(([, data]) => data.hostAccount === 'host-one@example.com');
    const laneTwoHub = hubEntries.find(([, data]) => data.hostAccount === 'host-two@example.com');
    const overflowShift = stores.teaching_shifts.get('sched_overflow_43');

    expect(laneOneHub).toBeDefined();
    expect(laneTwoHub).toBeDefined();
    expect(laneOneHub[1].rooms).toHaveLength(48);
    expect(laneOneHub[1].rooms.some((room) => room.shiftId === 'sched_overflow_43')).toBe(false);
    expect(laneTwoHub[1].rooms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ shiftId: 'sched_overflow_43' }),
      ]),
    );
    expect(overflowShift.zoom_hub_lane_index).toBe(1);
    expect(overflowShift.zoom_hub_overflow_from_lane).toBe(0);
    expect(overflowShift.hubMeetingId).toBe(laneTwoHub[0]);
    expect(stores.system_alerts.get('sched_overflow_43_spilled_to_lane_2'))
      .toEqual(expect.objectContaining({ reason: 'spilled_to_other_lane' }));
  });

  test('admin preflight rejects a new Zoom class that would break hub capacity', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host-one@example.com,host-two@example.com';
    const now = Date.now();
    const start = new Date(now + 30 * 60 * 1000);
    const end = new Date(now + 90 * 60 * 1000);
    stores.users.set('admin_1', {
      role: 'admin',
      first_name: 'Hassimiou',
      last_name: 'Niane',
      email: 'cto@example.com',
      fcmToken: 'cto_token',
    });
    addHubLoadShifts({
      count: 43,
      laneIndex: 0,
      start,
      end,
      idPrefix: 'preflight_lane0_full',
    });
    addHubLoadShifts({
      count: 43,
      laneIndex: 1,
      start,
      end,
      idPrefix: 'preflight_lane1_full',
    });

    await expect(zoomHandlers.validateZoomShiftCapacity({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: {
        operation: 'create_shift',
        source: 'create_shift_dialog',
        shiftAttempt: {
          teacherId: 'teacher_capacity',
          teacherName: 'Capacity Teacher',
          studentIds: ['student_capacity'],
          studentNames: ['Capacity Student'],
          shiftStartIso: start.toISOString(),
          shiftEndIso: end.toISOString(),
          category: 'teaching',
          videoProvider: 'zoom',
          customName: 'Capacity Breaking Class',
        },
      },
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('Zoom hub'),
    });

    const attempts = Array.from(stores.system_alerts.values())
      .filter((item) =>
        item.type === 'zoom_hub_shift_guardrail' &&
        item.reason === 'room_cap_exceeded');
    expect(attempts).toHaveLength(1);
    expect(attempts[0]).toEqual(expect.objectContaining({
      attemptedByName: 'Hassimiou Niane',
      guardrailMessage: expect.stringContaining('safe limit is 48'),
    }));
    expect(mockSendMail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'cto@example.com',
      subject: 'Zoom class blocked by routing guardrail',
    }));
    expect(mockSendEachForMulticast).toHaveBeenCalledWith(expect.objectContaining({
      tokens: ['cto_token'],
    }));
  });

  test('direct Firestore write of a capacity-breaking Zoom class is quarantined', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host-one@example.com,host-two@example.com';
    const now = Date.now();
    const start = new Date(now + 30 * 60 * 1000);
    const end = new Date(now + 90 * 60 * 1000);
    stores.users.set('admin_1', { role: 'admin', email: 'admin@example.com' });
    addHubLoadShifts({
      count: 43,
      laneIndex: 0,
      start,
      end,
      idPrefix: 'direct_lane0_full',
    });
    addHubLoadShifts({
      count: 43,
      laneIndex: 1,
      start,
      end,
      idPrefix: 'direct_lane1_full',
    });
    stores.teaching_shifts.set('zz_capacity_breaking_shift', {
      teacher_id: 'teacher_capacity',
      teacher_name: 'Capacity Teacher',
      student_ids: ['student_capacity'],
      student_names: ['Capacity Student'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Direct Capacity Breaking Class',
    });

    await zoomHandlers.onTeachingShiftWritten({
      params: { shiftId: 'zz_capacity_breaking_shift' },
      data: {
        before: { exists: false, data: () => ({}) },
        after: makeDocSnapshot('teaching_shifts', 'zz_capacity_breaking_shift'),
      },
    });

    expect(stores.teaching_shifts.get('zz_capacity_breaking_shift')).toEqual(
      expect.objectContaining({
        zoom_hub_guardrail_blocked: true,
        zoom_hub_guardrail_reason: 'room_cap_exceeded',
        zoomRoutingMode: 'blocked',
        zoom_disable_hub_routing: true,
      }),
    );
    expect(stores.system_alerts.get('zz_capacity_breaking_shift_zoom_hub_guardrail'))
      .toEqual(expect.objectContaining({
        reason: 'zoom_hub_shift_guardrail',
        data: expect.objectContaining({
          guardrailReason: 'room_cap_exceeded',
        }),
      }));
    expect(mockZoomClient.createMeeting).not.toHaveBeenCalled();
  });

  test('daily capacity forecast stays hidden when future Zoom schedule is safe', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host-one@example.com,host-two@example.com';
    const now = Date.now();
    stores.users.set('admin_1', {
      role: 'admin',
      email: 'admin@example.com',
    });
    stores.teaching_shifts.set('safe_future_zoom_shift', {
      teacher_id: 'teacher_safe',
      teacher_name: 'Safe Teacher',
      student_ids: ['student_safe'],
      student_names: ['Safe Student'],
      shift_start: makeTimestamp(new Date(now + 24 * 60 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 25 * 60 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Safe Future Class',
      zoom_hub_lane_index: 0,
    });

    await zoomHandlers.watchZoomHubCapacityForecast();

    expect(stores.admin_notifications.get('zoom_hub_daily_capacity_forecast'))
      .toEqual(expect.objectContaining({
        type: 'zoom_hub_capacity_forecast',
        resolved: true,
        open: false,
        read: true,
      }));
    expect(mockSendMail).not.toHaveBeenCalled();
  });

  test('daily capacity forecast writes a notification when future Zoom schedule breaks capacity', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host-one@example.com,host-two@example.com';
    const now = Date.now();
    const start = new Date(now + 24 * 60 * 60 * 1000);
    const end = new Date(now + 25 * 60 * 60 * 1000);
    stores.users.set('admin_1', {
      role: 'admin',
      first_name: 'Hassimiou',
      last_name: 'Niane',
      email: 'cto@example.com',
      fcmToken: 'cto_token',
    });
    addHubLoadShifts({
      count: 43,
      laneIndex: 0,
      start,
      end,
      idPrefix: 'forecast_lane0_full',
    });
    addHubLoadShifts({
      count: 43,
      laneIndex: 1,
      start,
      end,
      idPrefix: 'forecast_lane1_full',
    });
    stores.teaching_shifts.set('forecast_capacity_breaking_shift', {
      teacher_id: 'teacher_forecast',
      teacher_name: 'Forecast Teacher',
      student_ids: ['student_forecast'],
      student_names: ['Forecast Student'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Forecast Breaking Class',
      zoom_hub_lane_index: 0,
    });

    await zoomHandlers.watchZoomHubCapacityForecast();

    const notification = stores.admin_notifications.get('zoom_hub_daily_capacity_forecast');
    expect(notification).toEqual(expect.objectContaining({
      type: 'zoom_hub_capacity_forecast',
      resolved: false,
      open: true,
      action_required: true,
      problemCount: expect.any(Number),
      title: 'Zoom schedule risk detected',
    }));
    expect(notification.problemCount).toBeGreaterThan(0);
    expect(notification.problems).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          kind: 'unsafe_segment',
          reasons: expect.arrayContaining(['room_cap_exceeded']),
        }),
      ]),
    );
    expect(mockSendMail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'cto@example.com',
      subject: 'Zoom schedule risk detected',
    }));
    expect(mockSendEachForMulticast).toHaveBeenCalledWith(expect.objectContaining({
      tokens: ['cto_token'],
    }));
  });

  test('falls back to single Zoom mode and alerts admins when both hub lanes are full', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host-one@example.com,host-two@example.com';
    const now = Date.now();
    const start = new Date(now - 5 * 60 * 1000);
    const end = new Date(now + 55 * 60 * 1000);
    stores.users.set('teacher_target', {
      user_type: 'teacher',
      zoom_host_account: 'teacher-host@example.com',
    });
    stores.users.set('student_target', { user_type: 'student' });
    stores.users.set('admin_1', {
      role: 'admin',
      email: 'admin@example.com',
      fcmToken: 'admin_token',
    });
    addHubLoadShifts({
      count: 43,
      laneIndex: 0,
      start,
      end,
      idPrefix: 'lane0_full',
    });
    addHubLoadShifts({
      count: 43,
      laneIndex: 1,
      start,
      end,
      idPrefix: 'lane1_full',
    });
    stores.teaching_shifts.set('zz_overflow_target', {
      teacher_id: 'teacher_target',
      teacher_name: 'Target Teacher',
      student_ids: ['student_target'],
      student_names: ['Target Student'],
      shift_start: makeTimestamp(start),
      shift_end: makeTimestamp(end),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Overflow Target Class',
      zoom_hub_lane_index: 0,
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'single_fallback_meeting',
      password: 'single_pass',
      host_email: 'teacher-host@example.com',
      join_url: 'https://zoom.us/j/single_fallback_meeting?pwd=single_pass',
    });

    const result = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_target' },
      data: { shiftId: 'zz_overflow_target' },
    });

    const updatedShift = stores.teaching_shifts.get('zz_overflow_target');
    expect(result.success).toBe(true);
    expect(result.routingMode).toBe('single');
    expect(result.autoJoinBreakoutRoom).toBe(false);
    expect(result.meetingNumber).toBe('single_fallback_meeting');
    expect(updatedShift.zoomRoutingMode).toBe('single');
    expect(updatedShift.zoom_disable_hub_routing).toBe(true);
    expect(updatedShift.zoom_hub_fallback_reason).toBe('room_cap_exceeded');
    expect(mockZoomClient.createMeeting).toHaveBeenCalledWith(
      'teacher-host@example.com',
      expect.objectContaining({ topic: 'Overflow Target Class' }),
    );
    expect(stores.system_alerts.get('zz_overflow_target_room_cap_exceeded')).toEqual(
      expect.objectContaining({
        reason: 'room_cap_exceeded',
        severity: 'critical',
      }),
    );
    expect(mockSendMail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'admin@example.com',
      subject: 'Critical Zoom hub routing fallback',
    }));
    expect(mockSendEachForMulticast).toHaveBeenCalledWith(expect.objectContaining({
      tokens: ['admin_token'],
    }));
  });

  test('bot endpoints require the bot key and expose host-only credentials only to the bot', async () => {
    process.env.ZOOM_HUB_BOT_KEY = 'bot-key';
    const botHandlers = require('../handlers/zoom_hub_bot');
    const now = Date.now();
    stores.hub_meetings.set('hub_1', {
      lane: 1,
      meetingNumber: 'hub_meeting',
      zoom_password: 'hub_pass',
      hostAccount: 'host@example.com',
      window_start: makeTimestamp(new Date(now - 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 60 * 60 * 1000)),
      rooms: [
        { shiftId: 'shift_1', name: 'Room One' },
        { shiftId: 'late_shift', name: 'Spare 1', spare: true },
        { shiftId: '__spare_2', name: 'Spare 2', spare: true },
      ],
    });
    stores['hub_meetings/hub_1/members'] = new Map([
      ['teacher_1', {
        uid: 'teacher_1',
        shiftId: 'shift_1',
        role: 'teacher',
        displayName: 'Teacher One',
        routingDisplayName: 'Teacher One #abc12345',
        displayNameAliases: ['Teacher One', 'Teacher One #abc12345'],
      }],
      ['student_1', { uid: 'student_1', shiftId: 'shift_1', role: 'student' }],
      ['late_teacher', {
        uid: 'late_teacher',
        shiftId: 'late_shift',
        role: 'teacher',
        display_name: 'Late Teacher',
      }],
    ]);

    const unauthorized = makeResponse();
    await botHandlers.zoomHubBotDirectives({
      method: 'GET',
      query: { lane: '1' },
      headers: {},
      get: () => undefined,
    }, unauthorized);

    expect(unauthorized.status).toHaveBeenCalledWith(401);

    const directivesRes = makeResponse();
    await botHandlers.zoomHubBotDirectives({
      method: 'GET',
      query: { lane: '1' },
      headers: { 'x-bot-key': 'bot-key' },
      get: (name) => ({ 'x-bot-key': 'bot-key' }[name.toLowerCase()]),
    }, directivesRes);

    expect(directivesRes.status).toHaveBeenCalledWith(200);
    expect(directivesRes.body.directives).toEqual([
      expect.objectContaining({
        hubDocId: 'hub_1',
        meetingNumber: 'hub_meeting',
        password: 'hub_pass',
        hostAccount: 'host@example.com',
        sdkKey: 'sdk_key',
        signatureRole1: expect.any(String),
        zak: 'zak_token',
        rooms: ['Room One', 'Spare 1', 'Spare 2'],
      }),
    ]);
    expect(mockZoomClient.getUserZak).toHaveBeenCalledWith('host@example.com');

    const assignmentsRes = makeResponse();
    await botHandlers.zoomHubBotAssignments({
      method: 'GET',
      query: { hubDocId: 'hub_1' },
      headers: { 'x-bot-key': 'bot-key' },
      get: (name) => ({ 'x-bot-key': 'bot-key' }[name.toLowerCase()]),
    }, assignmentsRes);

    expect(assignmentsRes.status).toHaveBeenCalledWith(200);
    expect(assignmentsRes.body.rooms).toEqual([
      { shiftId: 'shift_1', name: 'Room One' },
      { shiftId: 'late_shift', name: 'Spare 1' },
    ]);
    expect(assignmentsRes.body.members).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          uid: 'teacher_1',
          shiftId: 'shift_1',
          role: 'teacher',
          displayName: 'Teacher One',
          routingDisplayName: 'Teacher One #abc12345',
          displayNameAliases: ['Teacher One', 'Teacher One #abc12345'],
        }),
        { uid: 'student_1', shiftId: 'shift_1', role: 'student' },
        {
          uid: 'late_teacher',
          shiftId: 'late_shift',
          role: 'teacher',
          displayName: 'Late Teacher',
        },
      ]),
    );

    const stateRes = makeResponse();
    await botHandlers.zoomHubBotState({
      method: 'POST',
      body: {
        hubDocId: 'hub_1',
        status: 'roomsOpen',
        boIdByRoomName: { 'Room One': 'bo_1' },
        liveParticipantsByShift: {
          shift_1: [
            {
              identity: 'student_1',
              routingUid: 'zh_student_1',
              zoomUserId: 1234,
              name: 'Student One',
              role: 'student',
            },
          ],
        },
        stats: { routedCount: 2 },
      },
      headers: { 'x-bot-key': 'bot-key' },
      get: (name) => ({ 'x-bot-key': 'bot-key' }[name.toLowerCase()]),
    }, stateRes);

    expect(stateRes.status).toHaveBeenCalledWith(200);
    expect(stores.hub_meetings.get('hub_1')).toEqual(
      expect.objectContaining({
        status: 'roomsOpen',
        bot_status: 'roomsOpen',
        boIdByRoomName: { 'Room One': 'bo_1' },
        bo_id_by_room_name: { 'Room One': 'bo_1' },
        liveParticipantsByShift: {
          shift_1: [
            expect.objectContaining({
              identity: 'student_1',
              routingUid: 'zh_student_1',
              name: 'Student One',
              role: 'student',
              source: 'zoom_hub_bot',
            }),
          ],
        },
        live_participants_by_shift: {
          shift_1: [
            expect.objectContaining({
              identity: 'student_1',
              routing_uid: 'zh_student_1',
              name: 'Student One',
              role: 'student',
              source: 'zoom_hub_bot',
            }),
          ],
        },
        stats: { routedCount: 2 },
      }),
    );

    const directivesWithRoomIdsRes = makeResponse();
    await botHandlers.zoomHubBotDirectives({
      method: 'GET',
      query: { lane: '1' },
      headers: { 'x-bot-key': 'bot-key' },
      get: (name) => ({ 'x-bot-key': 'bot-key' }[name.toLowerCase()]),
    }, directivesWithRoomIdsRes);

    expect(directivesWithRoomIdsRes.status).toHaveBeenCalledWith(200);
    expect(directivesWithRoomIdsRes.body.directives[0]).toEqual(
      expect.objectContaining({
        boIdByRoomName: { 'Room One': 'bo_1' },
      }),
    );

    const restartHeartbeatRes = makeResponse();
    await botHandlers.zoomHubBotState({
      method: 'POST',
      body: {
        hubDocId: 'hub_1',
        status: 'roomsOpen',
        boIdByRoomName: {},
        stats: { routedCount: 0, restarted: true },
      },
      headers: { 'x-bot-key': 'bot-key' },
      get: (name) => ({ 'x-bot-key': 'bot-key' }[name.toLowerCase()]),
    }, restartHeartbeatRes);

    expect(restartHeartbeatRes.status).toHaveBeenCalledWith(200);
    expect(stores.hub_meetings.get('hub_1')).toEqual(
      expect.objectContaining({
        boIdByRoomName: { 'Room One': 'bo_1' },
        bo_id_by_room_name: { 'Room One': 'bo_1' },
        stats: { routedCount: 0, restarted: true },
      }),
    );

    const leftRes = makeResponse();
    await botHandlers.zoomHubBotState({
      method: 'POST',
      body: {
        hubDocId: 'hub_1',
        status: 'left',
      },
      headers: { 'x-bot-key': 'bot-key' },
      get: (name) => ({ 'x-bot-key': 'bot-key' }[name.toLowerCase()]),
    }, leftRes);

    expect(leftRes.status).toHaveBeenCalledWith(200);
    expect(mockZoomClient.endMeeting).toHaveBeenCalledWith('hub_meeting');
    expect(stores.hub_meetings.get('hub_1')).toEqual(
      expect.objectContaining({
        status: 'left',
        bot_status: 'left',
        bot_end_error: null,
        boIdByRoomName: { 'Room One': 'bo_1' },
      }),
    );
  });

  test('admin routing status aggregates live hub docs without exposing bot credentials', async () => {
    const now = Date.now();
    stores.users.set('admin_1', { role: 'admin', email: 'admin@example.com' });
    stores.teaching_shifts.set('shift_1', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_names: ['Student One', 'Student Two'],
      custom_name: 'Billing Test',
      shift_start: makeTimestamp(new Date(now - 15 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 45 * 60 * 1000)),
      video_provider: 'zoom',
    });
    stores.hub_meetings.set('hub_1', {
      lane: 2,
      blockIndex: 3,
      meetingNumber: 'hub_meeting',
      zoom_password: 'hub_pass',
      hostAccount: 'support@example.com',
      status: 'roomsOpen',
      bot_status: 'roomsOpen',
      window_start: makeTimestamp(new Date(now - 20 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 60 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      rooms: [
        { shiftId: 'shift_1', name: 'Billing Test' },
        { shiftId: '__spare_1', name: 'Spare 1', spare: true },
      ],
      stats: {
        liveRoomCount: 2,
        inRoomOccupants: 3,
        attendeeCount: 4,
        customerKeyCount: 4,
        routableRoomCount: 2,
        targetMemberCount: 3,
        routedCount: 1,
      },
    });
    stores['hub_meetings/hub_1/members'] = new Map([
      ['teacher_1', { uid: 'teacher_1', shiftId: 'shift_1', role: 'teacher', displayName: 'Teacher One' }],
      ['student_1', { uid: 'student_1', shiftId: 'shift_1', role: 'student', displayName: 'Student One' }],
      ['student_2', { uid: 'student_2', shiftId: 'shift_1', role: 'student', displayName: 'Student Two' }],
    ]);
    stores.system_alerts.set('hub_1_heartbeat_stale', {
      type: 'zoom_hub',
      severity: 'critical',
      reason: 'heartbeat_stale',
      title: 'Critical Zoom hub bot heartbeat is stale',
      created_at: makeTimestamp(new Date(now - 30 * 60 * 1000)),
      data: { hubDocId: 'hub_1', lane: 2 },
    });

    const result = await zoomHandlers.getZoomHubRoutingStatus({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: {},
    });

    expect(result.success).toBe(true);
    expect(result.totals).toEqual(expect.objectContaining({
      activeHubs: 1,
      roomsOpen: 1,
      onlineBots: 1,
      inRoomOccupants: 3,
      attendeeCount: 4,
      targetMemberCount: 3,
      scheduledClassCount: 1,
      lastRoutingActionCount: 1,
      openIncidentCount: 0,
    }));
    expect(result.hubs).toEqual([
      expect.objectContaining({
        hubDocId: 'hub_1',
        lane: 2,
        hostAccount: 'support@example.com',
        meetingNumber: 'hub_meeting',
        status: 'roomsOpen',
        heartbeatFresh: true,
        plannedRoomCount: 2,
        liveRoomCount: 2,
        targetMemberCount: 3,
        classes: [
          expect.objectContaining({
            shiftId: 'shift_1',
            roomName: 'Billing Test',
            title: 'Billing Test',
            teacherName: 'Teacher One',
            scheduledNow: true,
            targetMemberCount: 3,
          }),
          expect.objectContaining({
            shiftId: '__spare_1',
            roomName: 'Spare 1',
            spare: true,
          }),
        ],
      }),
    ]);
    expect(result.hubs[0]).not.toHaveProperty('zak');
    expect(result.hubs[0]).not.toHaveProperty('signatureRole1');
    expect(result.hubs[0]).not.toHaveProperty('password');
    expect(result.incidents[0]).toEqual(expect.objectContaining({
      id: 'hub_1_heartbeat_stale',
      reason: 'heartbeat_stale',
      open: false,
      hubDocId: 'hub_1',
      lane: 2,
    }));
    expect(stores.system_alerts.get('hub_1_heartbeat_stale')).toEqual(
      expect.objectContaining({
        resolved: true,
        status: 'resolved',
        auto_resolved: true,
        auto_resolved_reason: 'hub_recovered_or_window_closed',
      }),
    );
  });

  test('admin routing status keeps a current unhealthy hub alert open', async () => {
    const now = Date.now();
    stores.users.set('admin_1', { role: 'admin', email: 'admin@example.com' });
    stores.hub_meetings.set('hub_1', {
      lane: 2,
      blockIndex: 3,
      meetingNumber: 'hub_meeting',
      hostAccount: 'support@example.com',
      status: 'joined',
      bot_status: 'joined',
      window_start: makeTimestamp(new Date(now - 20 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 60 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      rooms: [],
      stats: {},
    });
    stores.system_alerts.set('hub_1_rooms_not_open', {
      type: 'zoom_hub',
      severity: 'critical',
      reason: 'rooms_not_open',
      title: 'Critical Zoom hub rooms are not open',
      created_at: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      data: { hubDocId: 'hub_1', lane: 2 },
    });

    const result = await zoomHandlers.getZoomHubRoutingStatus({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: {},
    });

    expect(result.totals.openIncidentCount).toBe(1);
    expect(result.incidents[0]).toEqual(expect.objectContaining({
      id: 'hub_1_rooms_not_open',
      reason: 'rooms_not_open',
      open: true,
      hubDocId: 'hub_1',
    }));
    expect(stores.system_alerts.get('hub_1_rooms_not_open')).not.toHaveProperty('resolved');
  });

  test('routing status is admin-only', async () => {
    stores.users.set('teacher_1', { user_type: 'teacher' });

    await expect(zoomHandlers.getZoomHubRoutingStatus({
      auth: { uid: 'teacher_1', token: { role: 'teacher' } },
      data: {},
    })).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  test('bot watcher alerts admins when a live hub heartbeat is stale', async () => {
    const now = Date.now();
    stores.users.set('admin_1', {
      role: 'admin',
      email: 'admin@example.com',
      fcmToken: 'admin_token',
    });
    stores.hub_meetings.set('stale_hub', {
      lane: 2,
      status: 'roomsOpen',
      bot_status: 'roomsOpen',
      meetingNumber: 'hub_meeting',
      window_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 3 * 60 * 1000)),
    });

    await zoomHandlers.watchZoomHubBots();

    expect(stores.system_alerts.get('stale_hub_heartbeat_stale')).toEqual(
      expect.objectContaining({
        type: 'zoom_hub',
        severity: 'critical',
        reason: 'heartbeat_stale',
        title: 'Critical Zoom hub bot heartbeat is stale',
        data: expect.objectContaining({
          hubDocId: 'stale_hub',
          lane: 2,
          status: 'roomsOpen',
          meetingNumber: 'hub_meeting',
        }),
      }),
    );
    expect(mockSendMail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'admin@example.com',
      subject: 'Critical Zoom hub bot heartbeat is stale',
    }));
    expect(mockSendEachForMulticast).toHaveBeenCalledWith(expect.objectContaining({
      tokens: ['admin_token'],
    }));
  });

  test('bot watcher auto-resolves recovered hub alerts', async () => {
    const now = Date.now();
    stores.hub_meetings.set('recovered_hub', {
      lane: 1,
      status: 'roomsOpen',
      bot_status: 'roomsOpen',
      meetingNumber: 'hub_meeting',
      window_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: {
        liveRoomCount: 2,
        targetMemberCount: 1,
        inRoomOccupants: 1,
      },
    });
    stores.system_alerts.set('recovered_hub_rooms_not_open', {
      type: 'zoom_hub',
      severity: 'critical',
      reason: 'rooms_not_open',
      title: 'Critical Zoom hub rooms are not open',
      created_at: makeTimestamp(new Date(now - 20 * 60 * 1000)),
      data: { hubDocId: 'recovered_hub', lane: 1 },
    });

    await zoomHandlers.watchZoomHubBots();

    expect(stores.system_alerts.get('recovered_hub_rooms_not_open')).toEqual(
      expect.objectContaining({
        resolved: true,
        status: 'resolved',
        auto_resolved: true,
        auto_resolved_reason: 'hub_recovered_or_window_closed',
      }),
    );
    expect(mockSendMail).not.toHaveBeenCalled();
    expect(mockSendEachForMulticast).not.toHaveBeenCalled();
  });

  test('bot watcher auto-resets a poisoned hub whose live breakout list is empty', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    stores.hub_meetings.set('poison_hub', {
      lane: 1,
      status: 'roomsOpen',
      bot_status: 'roomsOpen',
      meetingNumber: 'poison_meeting',
      window_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { liveRoomCount: 0, targetMemberCount: 3, inRoomOccupants: 0 },
      poison_streak: 1,
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).toHaveBeenCalledWith('poison_meeting');
    expect(stores.hub_meetings.get('poison_hub')).toEqual(expect.objectContaining({
      poison_streak: 0,
      last_poison_reset_meeting: 'poison_meeting',
    }));
  });

  test('bot watcher waits one cycle before resetting a poisoned hub', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    stores.hub_meetings.set('poison_hub_new', {
      lane: 1,
      status: 'roomsOpen',
      bot_status: 'roomsOpen',
      meetingNumber: 'poison_meeting_new',
      window_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { liveRoomCount: 0, targetMemberCount: 3, inRoomOccupants: 0 },
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).not.toHaveBeenCalled();
    expect(stores.hub_meetings.get('poison_hub_new').poison_streak).toBe(1);
  });

  test('bot watcher never resets a poisoned hub with participants inside rooms', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    stores.hub_meetings.set('occupied_hub', {
      lane: 1,
      status: 'roomsOpen',
      bot_status: 'roomsOpen',
      meetingNumber: 'occupied_meeting',
      window_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { liveRoomCount: 0, targetMemberCount: 3, inRoomOccupants: 2 },
      poison_streak: 9,
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).not.toHaveBeenCalled();
  });

  test('bot watcher leaves a healthy hub alone and clears its poison streak', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    mockZoomClient.getMeeting.mockResolvedValueOnce({ id: 'healthy_meeting', status: 'started' });
    stores.hub_meetings.set('healthy_hub', {
      lane: 2,
      status: 'roomsOpen',
      bot_status: 'roomsOpen',
      meetingNumber: 'healthy_meeting',
      window_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { liveRoomCount: 16, targetMemberCount: 3, inRoomOccupants: 0 },
      poison_streak: 1,
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).not.toHaveBeenCalled();
    expect(stores.hub_meetings.get('healthy_hub').poison_streak).toBe(0);
    expect(stores.hub_meetings.get('healthy_hub').force_rejoin_at).toBeUndefined();
  });

  test('bot watcher forces a rejoin when a bot claims health but the meeting is not live (zombie)', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    // Bot reports a healthy, open meeting with rooms, but Zoom says the meeting
    // actually ended server-side — a zombie session that neither the poison nor
    // heartbeat check would catch.
    mockZoomClient.getMeeting.mockResolvedValueOnce({ id: 'zombie_meeting', status: 'waiting' });
    stores.hub_meetings.set('zombie_hub', {
      lane: 1,
      status: 'roomsOpen',
      bot_status: 'roomsOpen',
      meetingNumber: 'zombie_meeting',
      window_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { liveRoomCount: 8, targetMemberCount: 2, inRoomOccupants: 0 },
    });

    await zoomHandlers.watchZoomHubBots();

    // We do NOT end the meeting here (it is already ended); we stamp the signal
    // that makes the bot reload into a fresh instance.
    expect(stores.hub_meetings.get('zombie_hub').force_rejoin_at).toBeDefined();
  });

  test('bot watcher ends an expired hub meeting to free the account for the next block', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    stores.hub_meetings.set('expired_hub', {
      lane: 1,
      status: 'roomsOpen',
      meetingNumber: 'expired_meeting',
      window_start: makeTimestamp(new Date(now - 90 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { inRoomOccupants: 0 },
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).toHaveBeenCalledWith('expired_meeting');
    expect(stores.hub_meetings.get('expired_hub').ended_at).toBeDefined();
  });

  test('bot watcher removes stragglers at the 15-minute limit (ends the meeting past window_end)', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    // window_end (= last class + 15 min) has passed and someone is still inside:
    // policy says everyone is removed now.
    stores.hub_meetings.set('over_limit_hub', {
      lane: 1,
      status: 'roomsOpen',
      meetingNumber: 'over_limit_meeting',
      window_start: makeTimestamp(new Date(now - 90 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now - 1 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { inRoomOccupants: 2 },
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).toHaveBeenCalledWith('over_limit_meeting');
    expect(stores.hub_meetings.get('over_limit_hub').ended_at).toBeDefined();
  });

  test('bot watcher does NOT remove participants before the 15-minute limit', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    mockZoomClient.getMeeting.mockResolvedValueOnce({ id: 'within_limit_meeting', status: 'started' });
    // Still within the allowed 15-minute grace (window_end is 8 min in the
    // future), class running over — must NOT be ended.
    stores.hub_meetings.set('within_limit_hub', {
      lane: 1,
      status: 'roomsOpen',
      meetingNumber: 'within_limit_meeting',
      window_start: makeTimestamp(new Date(now - 90 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 8 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { liveRoomCount: 5, targetMemberCount: 1, inRoomOccupants: 2 },
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).not.toHaveBeenCalled();
  });

  test('bot watcher ends a superseded old block even with stragglers, to free the account for the newer block', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    // Newer block is live; the old block's real classes are over but someone
    // forgot to leave. The old block must release the shared account.
    mockZoomClient.getMeeting.mockResolvedValueOnce({ id: 'new_meeting', status: 'started' });
    stores.hub_meetings.set('old_block', {
      lane: 1, blockIndex: 2,
      status: 'roomsOpen', meetingNumber: 'old_meeting',
      window_start: makeTimestamp(new Date(now - 120 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now - 5 * 60 * 1000)), // realEnd = now-20min
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { inRoomOccupants: 2 },
    });
    stores.hub_meetings.set('new_block', {
      lane: 1, blockIndex: 3,
      status: 'roomsOpen', meetingNumber: 'new_meeting',
      window_start: makeTimestamp(new Date(now - 2 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now + 60 * 60 * 1000)),
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { liveRoomCount: 5, targetMemberCount: 1, inRoomOccupants: 0 },
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).toHaveBeenCalledWith('old_meeting');
    expect(mockZoomClient.endMeeting).not.toHaveBeenCalledWith('new_meeting');
    expect(stores.hub_meetings.get('old_block').ended_at).toBeDefined();
  });

  test('bot watcher force-ends a lingering hub past the hard grace even with stragglers', async () => {
    const now = Date.now();
    mockZoomClient.endMeeting.mockClear();
    // No competing block, but someone never left and it is now well past the
    // window end + grace — force-end so it cannot hold the account or approach
    // Zoom's 30h cap.
    stores.hub_meetings.set('lingering_hub', {
      lane: 2, blockIndex: 1,
      status: 'roomsOpen', meetingNumber: 'lingering_meeting',
      window_start: makeTimestamp(new Date(now - 120 * 60 * 1000)),
      window_end: makeTimestamp(new Date(now - 12 * 60 * 1000)), // past window_end + 10min grace
      heartbeat_at: makeTimestamp(new Date(now - 10 * 1000)),
      stats: { inRoomOccupants: 2 },
    });

    await zoomHandlers.watchZoomHubBots();

    expect(mockZoomClient.endMeeting).toHaveBeenCalledWith('lingering_meeting');
    expect(stores.hub_meetings.get('lingering_hub').ended_at).toBeDefined();
  });

  test('directives serve only one hub per lane, preferring a block with a live class', () => {
    const { _selectPrimaryActiveHub } = require('../handlers/zoom_hub_bot').__test__;
    const now = Date.now();
    // realEndInMs: when the block's real (unpadded) classes end. window_end is
    // realEnd + 15min pad.
    const mkDoc = (id, blockIndex, inRoomOccupants, realEndInMs = 30 * 60 * 1000, heartbeatAgoMs = 10 * 1000) => ({
      id,
      data: () => ({
        blockIndex,
        heartbeat_at: makeTimestamp(new Date(now - heartbeatAgoMs)),
        window_end: makeTimestamp(new Date(now + realEndInMs + 15 * 60 * 1000)),
        stats: { inRoomOccupants },
      }),
    });

    // Boundary overlap, old block's class is still genuinely running -> keep old.
    const withLiveOld = _selectPrimaryActiveHub([
      mkDoc('block2', 2, 3, 20 * 60 * 1000),
      mkDoc('block3', 3, 0),
    ], now);
    expect(withLiveOld).toHaveLength(1);
    expect(withLiveOld[0].id).toBe('block2');

    // Old block drained (no occupants) -> move to the newest block.
    const drainedOld = _selectPrimaryActiveHub([
      mkDoc('block2', 2, 0),
      mkDoc('block3', 3, 0),
    ], now);
    expect(drainedOld).toHaveLength(1);
    expect(drainedOld[0].id).toBe('block3');

    // Forgot-to-leave: old block's real classes already ENDED but someone is
    // still inside -> the straggler must NOT protect it; the newer block wins.
    const stragglerOld = _selectPrimaryActiveHub([
      mkDoc('block2', 2, 2, -5 * 60 * 1000), // realEnd 5 min in the past
      mkDoc('block3', 3, 0),
    ], now);
    expect(stragglerOld[0].id).toBe('block3');

    // A stale "live" reading (dead heartbeat) is not trusted as live.
    const staleLive = _selectPrimaryActiveHub([
      mkDoc('block2', 2, 3, 20 * 60 * 1000, 10 * 60 * 1000),
      mkDoc('block3', 3, 0),
    ], now);
    expect(staleLive[0].id).toBe('block3');
  });

  test('bot resetMeeting ends a corrupted empty hub so it can rejoin fresh', async () => {
    const botHandlers = require('../handlers/zoom_hub_bot');
    process.env.ZOOM_HUB_BOT_KEY = 'bot-key';
    mockZoomClient.endMeeting.mockClear();
    stores.hub_meetings.set('corrupt_hub', {
      lane: 1,
      status: 'roomsOpen',
      meetingNumber: 'corrupt_meeting',
      stats: { inRoomOccupants: 0 },
    });

    const res = makeResponse();
    await botHandlers.zoomHubBotState({
      method: 'POST',
      body: { hubDocId: 'corrupt_hub', status: 'resetMeeting' },
      headers: { 'x-bot-key': 'bot-key' },
      get: (name) => ({ 'x-bot-key': 'bot-key' }[name.toLowerCase()]),
    }, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mockZoomClient.endMeeting).toHaveBeenCalledWith('corrupt_meeting');
    expect(stores.hub_meetings.get('corrupt_hub').reset_at).toBeDefined();
  });

  test('bot resetMeeting never ends a hub that has participants inside rooms', async () => {
    const botHandlers = require('../handlers/zoom_hub_bot');
    process.env.ZOOM_HUB_BOT_KEY = 'bot-key';
    mockZoomClient.endMeeting.mockClear();
    stores.hub_meetings.set('busy_hub', {
      lane: 1,
      status: 'roomsOpen',
      meetingNumber: 'busy_meeting',
      stats: { inRoomOccupants: 2 },
    });

    const res = makeResponse();
    await botHandlers.zoomHubBotState({
      method: 'POST',
      body: { hubDocId: 'busy_hub', status: 'resetMeeting' },
      headers: { 'x-bot-key': 'bot-key' },
      get: (name) => ({ 'x-bot-key': 'bot-key' }[name.toLowerCase()]),
    }, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mockZoomClient.endMeeting).not.toHaveBeenCalled();
  });

  test('returns the same hub room target for a student without host automation', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com,backup@example.com';
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'legacy-host@example.com',
    });
    stores.users.set('student_1', { user_type: 'student' });
    stores.teaching_shifts.set('hub_shift', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const teacherResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift' },
    });
    const studentResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'student_1' },
      data: { shiftId: 'hub_shift' },
    });

    expect(studentResult.success).toBe(true);
    expect(studentResult.meetingNumber).toBe('hub_meeting_1');
    expect(studentResult.role).toBe(0);
    expect(studentResult.zak).toBeNull();
    expect(studentResult.breakoutRoomName).toBe(teacherResult.breakoutRoomName);
    expect(studentResult.autoOpenBreakoutRooms).toBe(false);
    expect(studentResult.autoJoinBreakoutRoom).toBe(true);
    expect(studentResult.targetBreakoutRoom).toEqual(
      expect.objectContaining({ shiftId: 'hub_shift' }),
    );
    expect(studentResult.hubBreakoutRooms).toEqual([]);
    expect(stores[`hub_meetings/${teacherResult.hubMeetingId}/members`].get(studentResult.customerKey)).toEqual(
      expect.objectContaining({ userId: 'student_1', shiftId: 'hub_shift', role: 'student' }),
    );
  });

  test('routes parents and admins into the clicked class room on hub joins', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com,backup@example.com';
    const now = Date.now();
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'legacy-host@example.com',
    });
    stores.users.set('student_1', {
      user_type: 'student',
      guardian_ids: ['parent_1'],
    });
    stores.users.set('parent_1', { user_type: 'parent' });
    stores.users.set('admin_1', { role: 'admin', first_name: 'Admin', last_name: 'One' });
    stores.teaching_shifts.set('hub_shift', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Routed Class',
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const teacherResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'hub_shift' },
    });
    stores.teaching_shifts.set('hub_shift_2', {
      teacher_id: 'teacher_2',
      teacher_name: 'Teacher One Backup',
      student_ids: ['student_2'],
      student_names: ['Student Two'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      hubMeetingId: teacherResult.hubMeetingId,
      breakoutRoomName: `${teacherResult.breakoutRoomName} Extra`,
    });
    const parentResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'parent_1' },
      data: { shiftId: 'hub_shift' },
    });
    const adminResult = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { shiftId: 'hub_shift' },
    });

    expect(parentResult.success).toBe(true);
    expect(parentResult.userRole).toBe('parent');
    expect(parentResult.role).toBe(0);
    expect(parentResult.breakoutRoomName).toBe(teacherResult.breakoutRoomName);
    expect(parentResult.breakoutRoomKey).toBe('hub_shift');
    expect(parentResult.targetBreakoutRoom).toEqual(
      expect.objectContaining({ shiftId: 'hub_shift' }),
    );
    expect(parentResult.autoJoinBreakoutRoom).toBe(true);
    expect(parentResult.hubBreakoutRooms).toEqual([]);
    expect(parentResult.assignmentToken).toBe('');

    expect(adminResult.success).toBe(true);
    expect(adminResult.userRole).toBe('admin');
    expect(adminResult.role).toBe(0);
    expect(adminResult.breakoutRoomName).toBe(teacherResult.breakoutRoomName);
    expect(adminResult.breakoutRoomKey).toBe('hub_shift');
    expect(adminResult.targetBreakoutRoom).toEqual(
      expect.objectContaining({ shiftId: 'hub_shift' }),
    );
    expect(adminResult.autoJoinBreakoutRoom).toBe(true);
    expect(adminResult.hubBreakoutRooms).toEqual([]);
    expect(adminResult.assignmentToken).toBe('');
    expect(stores[`hub_meetings/${teacherResult.hubMeetingId}/members`].get(parentResult.customerKey)).toEqual(
      expect.objectContaining({ userId: 'parent_1', shiftId: 'hub_shift', role: 'parent' }),
    );
    expect(stores[`hub_meetings/${teacherResult.hubMeetingId}/members`].get(adminResult.customerKey)).toEqual(
      expect.objectContaining({ userId: 'admin_1', shiftId: 'hub_shift', role: 'admin' }),
    );
  });

  test('keeps one admin separately routed when they click multiple classes in the same hub', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com,backup@example.com';
    const now = Date.now();
    stores.users.set('admin_1', { role: 'admin' });
    stores.users.set('teacher_1', { user_type: 'teacher' });
    stores.users.set('teacher_2', { user_type: 'teacher' });
    stores.teaching_shifts.set('hub_shift_a', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Class A',
      zoom_hub_lane_index: 0,
    });
    stores.teaching_shifts.set('hub_shift_b', {
      teacher_id: 'teacher_2',
      teacher_name: 'Teacher Two',
      student_ids: ['student_2'],
      student_names: ['Student Two'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Class B',
      zoom_hub_lane_index: 0,
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const firstJoin = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { shiftId: 'hub_shift_a' },
    });
    const secondJoin = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { shiftId: 'hub_shift_b' },
    });

    expect(firstJoin.hubMeetingId).toBe(secondJoin.hubMeetingId);
    expect(firstJoin.meetingNumber).toBe('hub_meeting_1');
    expect(secondJoin.meetingNumber).toBe('hub_meeting_1');
    expect(firstJoin.customerKey).toMatch(/^zh_/);
    expect(secondJoin.customerKey).toMatch(/^zh_/);
    expect(firstJoin.customerKey).not.toBe(secondJoin.customerKey);
    // Display name stays clean (no per-class suffix); separation rides on the
    // hidden customerKey, not the visible name.
    expect(firstJoin.displayName).toBe('Participant');
    expect(secondJoin.displayName).toBe('Participant');
    expect(firstJoin.realDisplayName).toBe('Participant');
    expect(secondJoin.realDisplayName).toBe('Participant');
    expect(firstJoin.breakoutRoomName).not.toBe(secondJoin.breakoutRoomName);

    const members = stores[`hub_meetings/${firstJoin.hubMeetingId}/members`];
    expect(members.get(firstJoin.customerKey)).toEqual(
      expect.objectContaining({
        userId: 'admin_1',
        shiftId: 'hub_shift_a',
        role: 'admin',
        displayName: firstJoin.displayName,
        realDisplayName: 'Participant',
      }),
    );
    expect(members.get(secondJoin.customerKey)).toEqual(
      expect.objectContaining({
        userId: 'admin_1',
        shiftId: 'hub_shift_b',
        role: 'admin',
        displayName: secondJoin.displayName,
        realDisplayName: 'Participant',
      }),
    );

    const joined = {
      event: 'meeting.participant_joined',
      event_ts: 1782916810000,
      payload: {
        object: {
          id: 'hub_meeting_1',
          participant: {
            id: 'zoom_admin_1',
            user_name: secondJoin.displayName,
            customer_key: secondJoin.customerKey,
            join_time: '2026-07-01T12:02:00Z',
          },
        },
      },
    };

    await zoomHandlers.zoomWebhook(signBody(joined), makeResponse());

    expect(stores.livekit_sessions.has('hub_shift_a_admin_1')).toBe(false);
    const session = stores.livekit_sessions.get('hub_shift_b_admin_1');
    expect(session).toBeDefined();
    expect(session.shift_id).toBe('hub_shift_b');
    expect(session.user_id).toBe('admin_1');
    expect(session.zoom_participant_name).toBe('Participant');
  });

  test('keeps native mobile hub display names clean while storing routing aliases', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS = 'host@example.com,backup@example.com';
    const now = Date.now();
    stores.users.set('admin_1', { role: 'admin' });
    stores.users.set('teacher_1', { user_type: 'teacher' });
    stores.users.set('teacher_2', { user_type: 'teacher' });
    stores.teaching_shifts.set('hub_shift_a', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Class A',
      zoom_hub_lane_index: 0,
    });
    stores.teaching_shifts.set('hub_shift_b', {
      teacher_id: 'teacher_2',
      teacher_name: 'Teacher Two',
      student_ids: ['student_2'],
      student_names: ['Student Two'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 55 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Hub Class B',
      zoom_hub_lane_index: 0,
    });
    mockZoomClient.createMeeting.mockResolvedValueOnce({
      id: 'hub_meeting_1',
      password: 'hub_pass',
      host_email: 'host@example.com',
      join_url: 'https://zoom.us/j/hub_meeting_1?pwd=hub_pass',
    });

    const firstJoin = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { shiftId: 'hub_shift_a', clientPlatform: 'native_mobile' },
    });
    const secondJoin = await zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { shiftId: 'hub_shift_b', clientPlatform: 'native_mobile' },
    });

    expect(firstJoin.customerKey).toMatch(/^zh_/);
    expect(secondJoin.customerKey).toMatch(/^zh_/);
    expect(firstJoin.customerKey).not.toBe(secondJoin.customerKey);
    expect(firstJoin.displayName).toBe('Participant');
    expect(secondJoin.displayName).toBe('Participant');
    expect(firstJoin.nativeDisplayName).toBe(firstJoin.displayName);
    expect(secondJoin.nativeDisplayName).toBe(secondJoin.displayName);
    expect(firstJoin.routingDisplayName).toMatch(/^Participant #[A-Za-z0-9_-]{8}$/);
    expect(secondJoin.routingDisplayName).toMatch(/^Participant #[A-Za-z0-9_-]{8}$/);
    expect(firstJoin.routingDisplayName).not.toBe(secondJoin.routingDisplayName);
    expect(secondJoin.realDisplayName).toBe('Participant');

    const members = stores[`hub_meetings/${firstJoin.hubMeetingId}/members`];
    expect(members.get(secondJoin.customerKey)).toEqual(
      expect.objectContaining({
        userId: 'admin_1',
        shiftId: 'hub_shift_b',
        role: 'admin',
        displayName: secondJoin.displayName,
        realDisplayName: 'Participant',
        routingDisplayName: secondJoin.routingDisplayName,
        displayNameAliases: expect.arrayContaining([
          'Participant',
          secondJoin.routingDisplayName,
        ]),
      }),
    );

    const joinedWithoutCustomerKey = {
      event: 'meeting.participant_joined',
      event_ts: 1782916810000,
      payload: {
        object: {
          id: 'hub_meeting_1',
          participant: {
            id: 'zoom_admin_native',
            user_name: secondJoin.routingDisplayName,
            join_time: '2026-07-01T12:02:00Z',
          },
        },
      },
    };

    await zoomHandlers.zoomWebhook(signBody(joinedWithoutCustomerKey), makeResponse());

    expect(stores.livekit_sessions.has('hub_shift_a_admin_1')).toBe(false);
    const session = stores.livekit_sessions.get('hub_shift_b_admin_1');
    expect(session).toBeDefined();
    expect(session.shift_id).toBe('hub_shift_b');
    expect(session.user_id).toBe('admin_1');
    expect(session.zoom_participant_name).toBe('Participant');
  });

  test('responds to Zoom webhook URL validation', async () => {
    const body = {
      event: 'endpoint.url_validation',
      payload: { plainToken: 'plain_token_123' },
    };
    const res = makeResponse();

    await zoomHandlers.zoomWebhook(signBody(body), res);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({
      plainToken: 'plain_token_123',
      encryptedToken: crypto
        .createHmac('sha256', 'webhook_secret')
        .update('plain_token_123')
        .digest('hex'),
    });
  });

  test('answers URL validation even when the request is unsigned', async () => {
    const body = {
      event: 'endpoint.url_validation',
      payload: { plainToken: 'plain_token_456' },
    };
    const req = {
      method: 'POST',
      body,
      rawBody: Buffer.from(JSON.stringify(body)),
      headers: {},
      get: () => undefined,
    };
    const res = makeResponse();

    await zoomHandlers.zoomWebhook(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({
      plainToken: 'plain_token_456',
      encryptedToken: crypto
        .createHmac('sha256', 'webhook_secret')
        .update('plain_token_456')
        .digest('hex'),
    });
  });

  test('rejects real events with an invalid signature', async () => {
    const body = {
      event: 'meeting.participant_joined',
      payload: { object: { id: '987654321', participant: {} } },
    };
    const req = {
      method: 'POST',
      body,
      rawBody: Buffer.from(JSON.stringify(body)),
      headers: {
        'x-zm-request-timestamp': '1782916800',
        'x-zm-signature': 'v0=deadbeef',
      },
      get: (name) => ({
        'x-zm-request-timestamp': '1782916800',
        'x-zm-signature': 'v0=deadbeef',
      }[name.toLowerCase()]),
    };
    const res = makeResponse();

    await zoomHandlers.zoomWebhook(req, res);

    expect(res.statusCode).toBe(401);
  });

  test('writes Zoom participant presence into livekit_sessions', async () => {
    stores.teaching_shifts.set('shift_1', {
      teacher_id: 'teacher_1',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date('2026-07-01T12:00:00.000Z')),
      shift_end: makeTimestamp(new Date('2026-07-01T13:00:00.000Z')),
      video_provider: 'zoom',
      zoom_meeting_id: '987654321',
    });

    const joined = {
      event: 'meeting.participant_joined',
      event_ts: 1782916810000,
      payload: {
        object: {
          id: '987654321',
          participant: {
            id: 'zoom_participant_1',
            customer_key: 'teacher_1',
            user_name: 'Teacher One',
            join_time: '2026-07-01T12:01:00Z',
          },
        },
      },
    };
    const left = {
      event: 'meeting.participant_left',
      event_ts: 1782917100000,
      payload: {
        object: {
          id: '987654321',
          participant: {
            id: 'zoom_participant_1',
            customer_key: 'teacher_1',
            user_name: 'Teacher One',
            leave_time: '2026-07-01T12:06:00Z',
          },
        },
      },
    };

    await zoomHandlers.zoomWebhook(signBody(joined), makeResponse());
    await zoomHandlers.zoomWebhook(signBody(left), makeResponse());

    const session = stores.livekit_sessions.get('shift_1_teacher_1');
    expect(session.shift_id).toBe('shift_1');
    expect(session.user_id).toBe('teacher_1');
    expect(session.role).toBe('teacher');
    expect(session.join_count).toBe(1);
    expect(session.leave_count).toBe(1);
    expect(session.presence_windows).toHaveLength(1);
    expect(session.presence_windows[0].join_at.toDate().toISOString())
      .toBe('2026-07-01T12:01:00.000Z');
    expect(session.presence_windows[0].leave_at.toDate().toISOString())
      .toBe('2026-07-01T12:06:00.000Z');
    expect(session.total_presence_seconds).toBe(5 * 60);
  });

  test('ignores Zoom hub bot presence webhook events', async () => {
    stores.teaching_shifts.set('shift_1', {
      teacher_id: 'teacher_1',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date('2026-07-01T12:00:00.000Z')),
      shift_end: makeTimestamp(new Date('2026-07-01T13:00:00.000Z')),
      video_provider: 'zoom',
      zoom_meeting_id: '987654321',
    });

    const joined = {
      event: 'meeting.participant_joined',
      event_ts: 1782916810000,
      payload: {
        object: {
          id: '987654321',
          participant: {
            id: 'zoom_bot_1',
            customer_key: 'zoom_hub_bot_lane_1',
            user_name: 'Alluwal Hub Bot Lane 1',
            join_time: '2026-07-01T12:01:00Z',
          },
        },
      },
    };

    const res = makeResponse();
    await zoomHandlers.zoomWebhook(signBody(joined), res);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({
      success: true,
      ignored: true,
      reason: 'hub_bot_participant',
    });
    expect(stores.livekit_sessions.size).toBe(0);
  });

  test('maps Zoom participant presence to the teacher by display name when customer key is missing', async () => {
    stores.teaching_shifts.set('shift_1', {
      teacher_id: 'teacher_1',
      teacher_name: 'Teacher One',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date('2026-07-01T12:00:00.000Z')),
      shift_end: makeTimestamp(new Date('2026-07-01T13:00:00.000Z')),
      video_provider: 'zoom',
      zoom_meeting_id: '987654321',
    });

    const joined = {
      event: 'meeting.participant_joined',
      event_ts: 1782916810000,
      payload: {
        object: {
          id: '987654321',
          participant: {
            id: 'zoom_participant_1',
            user_name: 'Teacher One',
            join_time: '2026-07-01T12:01:00Z',
          },
        },
      },
    };

    await zoomHandlers.zoomWebhook(signBody(joined), makeResponse());

    const session = stores.livekit_sessions.get('shift_1_teacher_1');
    expect(session).toBeDefined();
    expect(session.user_id).toBe('teacher_1');
    expect(session.role).toBe('teacher');
    expect(session.presence_windows[0].leave_at).toBeNull();
  });

  test('maps shared hub Zoom webhook events to the matching simultaneous shift', async () => {
    stores.teaching_shifts.set('shift_teacher_1', {
      teacher_id: 'teacher_1',
      student_ids: ['student_1'],
      shift_start: makeTimestamp(new Date('2026-07-01T12:00:00.000Z')),
      shift_end: makeTimestamp(new Date('2026-07-01T13:00:00.000Z')),
      video_provider: 'zoom',
      zoom_meeting_id: 'hub_meeting',
      hubMeetingId: 'hub_1',
    });
    stores.teaching_shifts.set('shift_teacher_2', {
      teacher_id: 'teacher_2',
      student_ids: ['student_2'],
      shift_start: makeTimestamp(new Date('2026-07-01T12:00:00.000Z')),
      shift_end: makeTimestamp(new Date('2026-07-01T13:00:00.000Z')),
      video_provider: 'zoom',
      zoom_meeting_id: 'hub_meeting',
      hubMeetingId: 'hub_1',
    });

    const joined = {
      event: 'meeting.participant_joined',
      event_ts: 1782916810000,
      payload: {
        object: {
          id: 'hub_meeting',
          participant: {
            id: 'zoom_participant_2',
            customer_key: 'student_2',
            user_name: 'Student Two',
            join_time: '2026-07-01T12:02:00Z',
          },
        },
      },
    };

    await zoomHandlers.zoomWebhook(signBody(joined), makeResponse());

    expect(stores.livekit_sessions.has('shift_teacher_1_student_2')).toBe(false);
    const session = stores.livekit_sessions.get('shift_teacher_2_student_2');
    expect(session.shift_id).toBe('shift_teacher_2');
    expect(session.user_id).toBe('student_2');
    expect(session.role).toBe('student');
  });

  test('admin toggle updates teacher flag and upcoming teaching shifts', async () => {
    stores.users.set('admin_1', { role: 'admin' });
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    const dayMs = 24 * 60 * 60 * 1000;
    const future = new Date(Date.now() + dayMs);
    const past = new Date(Date.now() - dayMs);
    stores.teaching_shifts.set('future_teaching', {
      teacher_id: 'teacher_1',
      category: 'teaching',
      shift_start: makeTimestamp(future),
      video_provider: 'realtimekit',
    });
    stores.teaching_shifts.set('past_teaching', {
      teacher_id: 'teacher_1',
      category: 'teaching',
      shift_start: makeTimestamp(past),
      video_provider: 'realtimekit',
    });
    stores.teaching_shifts.set('future_meeting', {
      teacher_id: 'teacher_1',
      category: 'meeting',
      shift_start: makeTimestamp(future),
      video_provider: 'zoom',
    });

    const result = await zoomHandlers.setTeacherZoomEnabled({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { teacherId: 'teacher_1', enabled: true },
    });

    expect(result.success).toBe(true);
    expect(result.updatedShiftCount).toBe(1);
    expect(stores.users.get('teacher_1').use_zoom).toBe(true);
    expect(stores.teaching_shifts.get('future_teaching').video_provider)
      .toBe('zoom');
    expect(stores.teaching_shifts.get('past_teaching').video_provider)
      .toBe('realtimekit');
    expect(stores.teaching_shifts.get('future_meeting').video_provider)
      .toBe('zoom');
  });

  test('admin toggle allows reserved hub accounts for default hub-routed teachers', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS =
      'billing@alluwaleducationhub.org,support@alluwaleducationhub.org';
    stores.users.set('admin_1', { role: 'admin' });
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'support@alluwaleducationhub.org',
    });
    const future = new Date(Date.now() + 24 * 60 * 60 * 1000);
    stores.teaching_shifts.set('future_teaching', {
      teacher_id: 'teacher_1',
      category: 'teaching',
      shift_start: makeTimestamp(future),
      video_provider: 'realtimekit',
    });

    const result = await zoomHandlers.setTeacherZoomEnabled({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { teacherId: 'teacher_1', enabled: true },
    });

    expect(result.success).toBe(true);
    expect(result.updatedShiftCount).toBe(1);
    expect(stores.users.get('teacher_1').use_zoom).toBe(true);
    expect(stores.teaching_shifts.get('future_teaching').video_provider)
      .toBe('zoom');
  });

  test('admin toggle rejects reserved hub accounts for explicit single Zoom mode', async () => {
    process.env.ZOOM_CLASSROOM_HOST_ACCOUNTS =
      'billing@alluwaleducationhub.org,support@alluwaleducationhub.org';
    stores.users.set('admin_1', { role: 'admin' });
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'billing@alluwaleducationhub.org',
    });

    await expect(zoomHandlers.setTeacherZoomEnabled({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: {
        teacherId: 'teacher_1',
        enabled: true,
        zoomRoutingMode: 'single',
      },
    })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  test('admin toggle with studentIds only moves those students\' shifts', async () => {
    stores.users.set('admin_1', { role: 'admin' });
    stores.users.set('teacher_1', {
      user_type: 'teacher',
      zoom_host_account: 'host@example.com',
    });
    const future = new Date(Date.now() + 24 * 60 * 60 * 1000);
    stores.teaching_shifts.set('shift_selected', {
      teacher_id: 'teacher_1',
      category: 'teaching',
      shift_start: makeTimestamp(future),
      student_ids: ['student_A'],
      video_provider: 'realtimekit',
    });
    // Group class containing a selected student should also move.
    stores.teaching_shifts.set('shift_group', {
      teacher_id: 'teacher_1',
      category: 'teaching',
      shift_start: makeTimestamp(future),
      student_ids: ['student_B', 'student_A'],
      video_provider: 'realtimekit',
    });
    // Unselected student's class must stay exactly as it was.
    stores.teaching_shifts.set('shift_other', {
      teacher_id: 'teacher_1',
      category: 'teaching',
      shift_start: makeTimestamp(future),
      student_ids: ['student_C'],
      video_provider: 'realtimekit',
    });

    const result = await zoomHandlers.setTeacherZoomEnabled({
      auth: { uid: 'admin_1', token: { role: 'admin' } },
      data: { teacherId: 'teacher_1', enabled: true, studentIds: ['student_A'] },
    });

    expect(result.success).toBe(true);
    expect(result.updatedShiftCount).toBe(2);
    expect(result.scopedStudentCount).toBe(1);
    expect(stores.teaching_shifts.get('shift_selected').video_provider)
      .toBe('zoom');
    expect(stores.teaching_shifts.get('shift_group').video_provider)
      .toBe('zoom');
    expect(stores.teaching_shifts.get('shift_other').video_provider)
      .toBe('realtimekit');
    expect(stores.users.get('teacher_1').use_zoom).toBe(true);
  });

  test('flags hub windows that would exceed the safe Zoom meeting lifetime', () => {
    const {
      _hubWindowExceedsSafeZoomLifetime,
      _hubWindowForShiftDocs,
    } = zoomHandlers.__test__;
    const base = Date.now();

    const normalWindow = _hubWindowForShiftDocs([
      {
        data: () => ({
          shift_start: makeTimestamp(new Date(base)),
          shift_end: makeTimestamp(new Date(base + 60 * 60 * 1000)),
        }),
      },
    ]);
    const longWindow = _hubWindowForShiftDocs([
      {
        data: () => ({
          shift_start: makeTimestamp(new Date(base)),
          shift_end: makeTimestamp(new Date(base + 29 * 60 * 60 * 1000)),
        }),
      },
    ]);

    expect(_hubWindowExceedsSafeZoomLifetime(normalWindow)).toBe(false);
    expect(_hubWindowExceedsSafeZoomLifetime(longWindow)).toBe(true);
  });

  test('blocks an overlong class instead of stretching a shared hub past Zoom lifetime', async () => {
    const now = Date.now();
    stores.users.set('long_teacher', {
      user_type: 'teacher',
      zoom_host_account: 'teacher-host@example.com',
    });
    stores.teaching_shifts.set('long_shift', {
      teacher_id: 'long_teacher',
      teacher_name: 'Long Teacher',
      student_ids: ['student_1'],
      student_names: ['Student One'],
      shift_start: makeTimestamp(new Date(now - 5 * 60 * 1000)),
      shift_end: makeTimestamp(new Date(now + 29 * 60 * 60 * 1000)),
      video_provider: 'zoom',
      category: 'teaching',
      custom_name: 'Overlong Zoom Class',
    });

    await expect(zoomHandlers.getZoomJoinInfo({
      auth: { uid: 'long_teacher', token: {} },
      data: { shiftId: 'long_shift' },
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('was not created'),
    });

    expect(stores.teaching_shifts.get('long_shift').zoom_disable_hub_routing)
      .toBe(true);
    expect(stores.teaching_shifts.get('long_shift').zoom_hub_guardrail_reason)
      .toBe('duration_exceeds_limit');
    expect(mockZoomClient.createMeeting).not.toHaveBeenCalled();
  });
});
