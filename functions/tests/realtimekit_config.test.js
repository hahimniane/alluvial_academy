const {
  clearConfigCache,
  getRealtimeKitConfig,
  isRealtimeKitConfigured,
} = require('../services/realtimekit/config');

const REALTIMEKIT_ENV_KEYS = [
  'CLOUDFLARE_ACCOUNT_ID',
  'REALTIMEKIT_APP_ID',
  'CLOUDFLARE_REALTIME_API_TOKEN',
  'REALTIMEKIT_TEACHER_PRESET',
  'REALTIMEKIT_ADMIN_PRESET',
  'REALTIMEKIT_STUDENT_PRESET',
  'REALTIMEKIT_PARENT_PRESET',
  'REALTIMEKIT_GUEST_PRESET',
  'REALTIMEKIT_TEACHER_RECORDER_PRESET',
];

const originalEnv = {};

describe('RealtimeKit config', () => {
  beforeAll(() => {
    for (const key of REALTIMEKIT_ENV_KEYS) {
      originalEnv[key] = process.env[key];
    }
  });

  beforeEach(() => {
    clearConfigCache();
    for (const key of REALTIMEKIT_ENV_KEYS) {
      delete process.env[key];
    }
  });

  afterAll(() => {
    clearConfigCache();
    for (const key of REALTIMEKIT_ENV_KEYS) {
      if (originalEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = originalEnv[key];
      }
    }
  });

  test('requires Cloudflare account, app, and API token credentials', () => {
    expect(isRealtimeKitConfigured()).toBe(false);
    expect(() => getRealtimeKitConfig()).toThrow(
      /CLOUDFLARE_ACCOUNT_ID, REALTIMEKIT_APP_ID, CLOUDFLARE_REALTIME_API_TOKEN/,
    );

    process.env.CLOUDFLARE_ACCOUNT_ID = ' account_1 ';
    process.env.REALTIMEKIT_APP_ID = ' app_1 ';
    clearConfigCache();

    expect(() => getRealtimeKitConfig()).toThrow(
      /CLOUDFLARE_REALTIME_API_TOKEN/,
    );
  });

  test('trims required credentials and uses default role presets', () => {
    process.env.CLOUDFLARE_ACCOUNT_ID = ' account_1 ';
    process.env.REALTIMEKIT_APP_ID = ' app_1 ';
    process.env.CLOUDFLARE_REALTIME_API_TOKEN = ' token_1 ';

    const config = getRealtimeKitConfig();

    expect(config).toEqual({
      accountId: 'account_1',
      appId: 'app_1',
      apiToken: 'token_1',
      presets: {
        admin: 'teacher',
        teacher: 'teacher',
        student: 'student',
        parent: 'student',
        guest: 'student',
        teacherRecorder: 'teacher_recorder',
      },
    });
    expect(isRealtimeKitConfigured()).toBe(true);
  });

  test('uses optional custom preset names when configured', () => {
    process.env.CLOUDFLARE_ACCOUNT_ID = 'account_1';
    process.env.REALTIMEKIT_APP_ID = 'app_1';
    process.env.CLOUDFLARE_REALTIME_API_TOKEN = 'token_1';
    process.env.REALTIMEKIT_TEACHER_PRESET = ' class-teacher ';
    process.env.REALTIMEKIT_ADMIN_PRESET = ' class-admin ';
    process.env.REALTIMEKIT_STUDENT_PRESET = ' class-student ';
    process.env.REALTIMEKIT_PARENT_PRESET = ' class-parent ';
    process.env.REALTIMEKIT_GUEST_PRESET = ' class-guest ';
    process.env.REALTIMEKIT_TEACHER_RECORDER_PRESET = ' class-recorder ';

    const config = getRealtimeKitConfig();

    expect(config.presets).toEqual({
      admin: 'class-admin',
      teacher: 'class-teacher',
      student: 'class-student',
      parent: 'class-parent',
      guest: 'class-guest',
      teacherRecorder: 'class-recorder',
    });
  });

  test('rejects attendee presets that reuse host presets', () => {
    process.env.CLOUDFLARE_ACCOUNT_ID = 'account_1';
    process.env.REALTIMEKIT_APP_ID = 'app_1';
    process.env.CLOUDFLARE_REALTIME_API_TOKEN = 'token_1';
    process.env.REALTIMEKIT_TEACHER_PRESET = 'host';
    process.env.REALTIMEKIT_STUDENT_PRESET = 'host';

    expect(() => getRealtimeKitConfig()).toThrow(
      /REALTIMEKIT_STUDENT_PRESET/,
    );
  });
});
