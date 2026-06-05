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

let mockPresetConfig;

jest.mock('../services/realtimekit/config', () => ({
  getRealtimeKitConfig: jest.fn(() => ({
    accountId: 'account_1',
    appId: 'app_1',
    apiToken: 'token_1',
    presets: mockPresetConfig,
  })),
  isRealtimeKitConfigured: jest.fn(() => true),
}));

const mockRealtimeKitClient = {
  createMeeting: jest.fn(async () => ({ success: true, data: { id: 'meeting_1' } })),
  getMeeting: jest.fn(async () => ({ success: true, data: { id: 'meeting_1' } })),
  addParticipant: jest.fn(async () => ({
    success: true,
    data: { id: 'participant_1', token: 'auth_token_1' },
  })),
  listMeetingParticipants: jest.fn(async () => ({ success: true, data: [] })),
  refreshParticipantToken: jest.fn(async () => ({
    success: true,
    data: { token: 'refreshed_auth_token_1' },
  })),
  updateParticipant: jest.fn(async () => ({ success: true, data: { id: 'participant_1' } })),
  deleteParticipant: jest.fn(async () => ({ success: true })),
  kickActiveSessionParticipants: jest.fn(async () => ({ success: true })),
};

jest.mock('../services/realtimekit/client', () => mockRealtimeKitClient);

let mockUsers;
let mockShifts;

const mockMakeDocRef = (collectionName, id) => ({
  get: async () => {
    const store = collectionName === 'users' ? mockUsers : mockShifts;
    const data = store[id];
    return {
      exists: data !== undefined,
      ref: mockMakeDocRef(collectionName, id),
      data: () => data,
    };
  },
  set: async (data, options) => {
    const store = collectionName === 'users' ? mockUsers : mockShifts;
    store[id] = options?.merge ? { ...(store[id] || {}), ...data } : data;
  },
  update: async (data) => {
    const store = collectionName === 'users' ? mockUsers : mockShifts;
    store[id] = { ...(store[id] || {}), ...data };
  },
});

const mockFirestore = jest.fn(() => ({
  collection: (name) => ({
    doc: (id) => mockMakeDocRef(name, id),
  }),
}));
mockFirestore.FieldValue = {
  serverTimestamp: () => new Date('2026-01-01T00:00:00.000Z'),
};

jest.mock('firebase-admin', () => ({
  apps: [],
  initializeApp: jest.fn(),
  firestore: mockFirestore,
}));

const {
  getRealtimeKitJoinToken,
  getRealtimeKitGuestJoin,
  getRealtimeKitRoomPresence,
  kickRealtimeKitParticipant,
  setRealtimeKitRoomLock,
  setRealtimeKitRecordingEnabled,
} = require('../handlers/realtimekit');

const makeResponse = () => {
  const res = {
    headers: {},
    statusCode: null,
    body: null,
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

describe('RealtimeKit class access', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockPresetConfig = {
      admin: 'teacher',
      teacher: 'teacher',
      student: 'student',
      parent: 'student',
      guest: 'student',
      teacherRecorder: 'teacher_recorder',
    };
    mockUsers = {
      student_1: {
        first_name: 'Student',
        last_name: 'One',
        access_suspended: false,
      },
      student_2: {
        first_name: 'Student',
        last_name: 'Two',
        access_suspended: true,
      },
      parent_1: {
        first_name: 'Parent',
        last_name: 'One',
      },
      teacher_1: {
        first_name: 'Teacher',
        last_name: 'One',
      },
      admin_1: {
        first_name: 'Admin',
        last_name: 'One',
        user_type: 'admin',
      },
      outsider_1: {
        first_name: 'Outside',
        last_name: 'User',
      },
    };
    mockUsers.student_1.guardian_ids = ['parent_1'];
    mockShifts = {
      shift_1: {
        teacher_id: 'teacher_1',
        student_ids: ['student_1'],
        shift_start: new Date(Date.now() - 5 * 60 * 1000),
        shift_end: new Date(Date.now() + 55 * 60 * 1000),
        subject_display_name: 'Quran',
      },
      shift_2: {
        teacher_id: 'teacher_1',
        student_ids: ['student_2'],
        shift_start: new Date(Date.now() - 5 * 60 * 1000),
        shift_end: new Date(Date.now() + 55 * 60 * 1000),
        subject_display_name: 'Arabic',
      },
    };
  });

  test('creates a meeting and participant token for an assigned student', async () => {
    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'student_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.provider).toBe('realtimekit');
    expect(result.authToken).toBe('auth_token_1');
    expect(result.userRole).toBe('student');
    expect(mockRealtimeKitClient.createMeeting).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'Quran' }),
    );
    // Cloudflare rejects session_keep_alive_time_in_secs above 600.
    const createArgs = mockRealtimeKitClient.createMeeting.mock.calls[0][0];
    expect(createArgs.session_keep_alive_time_in_secs).toBeLessThanOrEqual(600);
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({
        custom_participant_id: 'student_1',
        preset_name: 'student',
      }),
    );
    expect(mockShifts.shift_1.realtimekit_meeting_id).toBe('meeting_1');
  });

  test('blocks suspended students from joining', async () => {
    await expect(
      getRealtimeKitJoinToken({
        auth: { uid: 'student_2' },
        data: { shiftId: 'shift_2' },
      }),
    ).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  test('allows a linked parent to join through their student', async () => {
    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'parent_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.userRole).toBe('parent');
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({
        custom_participant_id: 'parent_1',
        preset_name: 'student',
      }),
    );
  });

  test('allows the assigned teacher to join with the teacher preset', async () => {
    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.userRole).toBe('teacher');
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({
        custom_participant_id: 'teacher_1',
        preset_name: 'teacher',
      }),
    );
  });

  test('recording is disabled by default for teacher joins', async () => {
    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.recordingEnabled).toBe(false);
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({
        custom_participant_id: 'teacher_1',
        preset_name: 'teacher',
      }),
    );
  });

  test('admin can enable class recording and teacher receives recorder preset', async () => {
    const toggle = await setRealtimeKitRecordingEnabled({
      auth: { uid: 'admin_1' },
      data: { shiftId: 'shift_1', enabled: true },
    });

    expect(toggle).toEqual({ success: true, recordingEnabled: true });
    expect(mockShifts.shift_1.realtimekit_recording_enabled).toBe(true);

    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.recordingEnabled).toBe(true);
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({
        custom_participant_id: 'teacher_1',
        preset_name: 'teacher_recorder',
      }),
    );
  });

  test('non-admin cannot enable class recording', async () => {
    await expect(
      setRealtimeKitRecordingEnabled({
        auth: { uid: 'teacher_1' },
        data: { shiftId: 'shift_1', enabled: true },
      }),
    ).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  test('allows an admin to join an unassigned class with the admin preset', async () => {
    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'admin_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.userRole).toBe('admin');
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({
        custom_participant_id: 'admin_1',
        preset_name: 'teacher',
      }),
    );
  });

  test('uses configured RealtimeKit preset names for every classroom role', async () => {
    mockPresetConfig = {
      admin: 'class-admin',
      teacher: 'class-teacher',
      student: 'class-student',
      parent: 'class-parent',
      guest: 'class-guest',
      teacherRecorder: 'class-recorder',
    };

    await getRealtimeKitJoinToken({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1' },
    });
    await getRealtimeKitJoinToken({
      auth: { uid: 'admin_1' },
      data: { shiftId: 'shift_1' },
    });
    await getRealtimeKitJoinToken({
      auth: { uid: 'student_1' },
      data: { shiftId: 'shift_1' },
    });
    await getRealtimeKitJoinToken({
      auth: { uid: 'parent_1' },
      data: { shiftId: 'shift_1' },
    });
    const res = makeResponse();
    await getRealtimeKitGuestJoin(
      { method: 'GET', query: { shiftId: 'shift_1', name: 'Guest One' } },
      res,
    );

    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({ custom_participant_id: 'teacher_1', preset_name: 'class-teacher' }),
    );
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({ custom_participant_id: 'admin_1', preset_name: 'class-admin' }),
    );
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({ custom_participant_id: 'student_1', preset_name: 'class-student' }),
    );
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({ custom_participant_id: 'parent_1', preset_name: 'class-parent' }),
    );
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({ name: 'Guest One', preset_name: 'class-guest' }),
    );
  });

  test('blocks unassigned users from joining', async () => {
    await expect(
      getRealtimeKitJoinToken({
        auth: { uid: 'outsider_1' },
        data: { shiftId: 'shift_1' },
      }),
    ).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  test('refreshes the token when the participant already exists', async () => {
    mockShifts.shift_1.realtimekit_meeting_id = 'meeting_1';
    mockRealtimeKitClient.listMeetingParticipants.mockResolvedValueOnce({
      success: true,
      data: [{
        id: 'participant_existing',
        custom_participant_id: 'student_1',
        preset_name: 'student',
      }],
    });

    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'student_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.authToken).toBe('refreshed_auth_token_1');
    expect(mockRealtimeKitClient.addParticipant).not.toHaveBeenCalled();
    expect(mockRealtimeKitClient.refreshParticipantToken).toHaveBeenCalledWith(
      'meeting_1',
      'participant_existing',
    );
  });

  test('existing participant preset is updated when recording permission changes', async () => {
    mockShifts.shift_1.realtimekit_meeting_id = 'meeting_1';
    mockShifts.shift_1.realtimekit_recording_enabled = false;
    mockRealtimeKitClient.listMeetingParticipants.mockResolvedValueOnce({
      success: true,
      data: [{
        id: 'participant_existing',
        custom_participant_id: 'teacher_1',
        preset_name: 'teacher_recorder',
      }],
    });

    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.presetName).toBe('teacher');
    expect(mockRealtimeKitClient.updateParticipant).toHaveBeenCalledWith(
      'meeting_1',
      'participant_existing',
      expect.objectContaining({ preset_name: 'teacher' }),
    );
    expect(mockRealtimeKitClient.refreshParticipantToken).toHaveBeenCalledWith(
      'meeting_1',
      'participant_existing',
    );
  });

  test('teacher can lock the room and students are blocked while locked', async () => {
    const lockResult = await setRealtimeKitRoomLock({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1', locked: true },
    });

    expect(lockResult).toEqual({ success: true, locked: true });
    expect(mockShifts.shift_1.realtimekit_locked).toBe(true);

    await expect(
      getRealtimeKitJoinToken({
        auth: { uid: 'student_1' },
        data: { shiftId: 'shift_1' },
      }),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  test('unassigned users cannot lock the room', async () => {
    await expect(
      setRealtimeKitRoomLock({
        auth: { uid: 'outsider_1' },
        data: { shiftId: 'shift_1', locked: true },
      }),
    ).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  test('locked rooms still allow the assigned teacher to join', async () => {
    mockShifts.shift_1.realtimekit_locked = true;

    const result = await getRealtimeKitJoinToken({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.userRole).toBe('teacher');
  });

  test('guest join returns a RealtimeKit token when the room is open', async () => {
    const res = makeResponse();

    await getRealtimeKitGuestJoin(
      { method: 'GET', query: { shiftId: 'shift_1', name: 'Guest One' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.body.success).toBe(true);
    expect(res.body.userRole).toBe('guest');
    expect(mockRealtimeKitClient.addParticipant).toHaveBeenCalledWith(
      'meeting_1',
      expect.objectContaining({
        name: 'Guest One',
        preset_name: 'student',
      }),
    );
  });

  test('presence returns an empty list before a meeting exists', async () => {
    const result = await getRealtimeKitRoomPresence({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.participantCount).toBe(0);
    expect(result.participants).toEqual([]);
    expect(mockRealtimeKitClient.listMeetingParticipants).not.toHaveBeenCalled();
  });

  test('presence lists RealtimeKit participants for authorized users', async () => {
    mockShifts.shift_1.realtimekit_meeting_id = 'meeting_1';
    mockRealtimeKitClient.listMeetingParticipants.mockResolvedValueOnce({
      success: true,
      data: [{
        id: 'participant_student',
        custom_participant_id: 'student_1',
        name: 'Student One',
        preset_name: 'student',
        created_at: '2026-01-01T00:00:00.000Z',
      }],
    });

    const result = await getRealtimeKitRoomPresence({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1' },
    });

    expect(result.success).toBe(true);
    expect(result.meetingId).toBe('meeting_1');
    expect(result.participantCount).toBe(1);
    expect(result.participants).toEqual([
      expect.objectContaining({
        identity: 'student_1',
        name: 'Student One',
        role: 'student',
      }),
    ]);
  });

  test('guest join is blocked while the room is locked', async () => {
    mockShifts.shift_1.realtimekit_locked = true;
    const res = makeResponse();

    await getRealtimeKitGuestJoin(
      { method: 'GET', query: { shiftId: 'shift_1', name: 'Guest One' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toContain('locked');
  });

  test('teacher can kick a participant from the RealtimeKit meeting', async () => {
    mockShifts.shift_1.realtimekit_meeting_id = 'meeting_1';
    mockRealtimeKitClient.listMeetingParticipants.mockResolvedValueOnce({
      success: true,
      data: [{
        id: 'participant_student',
        custom_participant_id: 'student_1',
        name: 'Student One',
      }],
    });

    const result = await kickRealtimeKitParticipant({
      auth: { uid: 'teacher_1' },
      data: { shiftId: 'shift_1', identity: 'student_1' },
    });

    expect(result).toEqual({ success: true, removed: true });
    expect(mockRealtimeKitClient.kickActiveSessionParticipants).toHaveBeenCalledWith(
      'meeting_1',
      { custom_participant_ids: ['student_1'] },
    );
    expect(mockRealtimeKitClient.deleteParticipant).not.toHaveBeenCalled();
  });

  test('admin can kick a participant from the RealtimeKit meeting', async () => {
    mockShifts.shift_1.realtimekit_meeting_id = 'meeting_1';
    mockRealtimeKitClient.listMeetingParticipants.mockResolvedValueOnce({
      success: true,
      data: [{
        id: 'participant_student',
        custom_participant_id: 'student_1',
        name: 'Student One',
      }],
    });

    const result = await kickRealtimeKitParticipant({
      auth: { uid: 'admin_1' },
      data: { shiftId: 'shift_1', identity: 'student_1' },
    });

    expect(result).toEqual({ success: true, removed: true });
    expect(mockRealtimeKitClient.kickActiveSessionParticipants).toHaveBeenCalledWith(
      'meeting_1',
      { custom_participant_ids: ['student_1'] },
    );
    expect(mockRealtimeKitClient.deleteParticipant).not.toHaveBeenCalled();
  });
});
