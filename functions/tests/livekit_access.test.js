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

jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (_schedule, fn) => fn,
}));

jest.mock('livekit-server-sdk', () => ({
  RoomServiceClient: jest.fn(),
  EgressClient: jest.fn(),
  TrackType: {},
  TrackSource: {},
  EgressStatus: {
    EGRESS_STARTING: 'EGRESS_STARTING',
    EGRESS_ACTIVE: 'EGRESS_ACTIVE',
    EGRESS_ENDING: 'EGRESS_ENDING',
  },
  EncodedFileOutput: jest.fn(),
  EncodedFileType: {},
  SegmentedFileOutput: jest.fn(),
  GCPUpload: jest.fn(),
  AutoTrackEgress: jest.fn(),
  RoomEgress: jest.fn(),
  RoomCompositeEgressRequest: jest.fn(),
}));

jest.mock('../services/livekit/config', () => ({
  getLiveKitConfig: jest.fn(() => ({
    url: 'wss://livekit.test',
    apiKey: 'key',
    apiSecret: 'secret',
  })),
  isLiveKitConfigured: jest.fn(() => true),
}));

jest.mock('../services/livekit/token', () => ({
  generateTokenForRole: jest.fn(() => 'token'),
}));

let mockUsers;

jest.mock('firebase-admin', () => ({
  apps: [],
  initializeApp: jest.fn(),
  firestore: jest.fn(() => ({
    collection: (name) => ({
      doc: (id) => ({
        get: async () => {
          if (name !== 'users') throw new Error(`Unexpected collection: ${name}`);
          const data = mockUsers[id];
          return {
            exists: data !== undefined,
            data: () => data,
          };
        },
      }),
    }),
  })),
}));

const {__test__} = require('../handlers/livekit');

describe('LiveKit invoice access enforcement helpers', () => {
  beforeEach(() => {
    mockUsers = {};
  });

  test('detects suspended student using snake_case field', async () => {
    mockUsers.student_1 = {access_suspended: true};

    await expect(__test__.isStudentAccessSuspended('student_1'))
      .resolves.toBe(true);
  });

  test('detects suspended student using camelCase field', async () => {
    mockUsers.student_1 = {accessSuspended: true};

    await expect(__test__.isStudentAccessSuspended('student_1'))
      .resolves.toBe(true);
  });

  test('allows students without suspension flag', async () => {
    mockUsers.student_1 = {access_suspended: false};

    await expect(__test__.isStudentAccessSuspended('student_1'))
      .resolves.toBe(false);
  });
});
