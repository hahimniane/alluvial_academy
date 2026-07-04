const jwt = require('jsonwebtoken');

describe('Zoom Meeting SDK signature', () => {
  const originalEnv = process.env;
  const originalNow = Date.now;

  beforeEach(() => {
    jest.resetModules();
    process.env = {
      ...originalEnv,
      ZOOM_SDK_KEY: 'sdk_key_123',
      ZOOM_SDK_SECRET: 'sdk_secret_456',
    };
    Date.now = jest.fn(() => new Date('2026-07-01T12:00:00.000Z').getTime());
  });

  afterEach(() => {
    process.env = originalEnv;
    Date.now = originalNow;
  });

  test('generates the current Meeting SDK JWT payload', () => {
    const { generateMeetingSdkSignature } = require('../services/zoom/signature');

    const signature = generateMeetingSdkSignature({
      meetingNumber: '987654321',
      role: 1,
    });
    const decoded = jwt.verify(signature, 'sdk_secret_456');

    expect(decoded.appKey).toBe('sdk_key_123');
    expect(decoded.mn).toBe('987654321');
    expect(decoded.role).toBe(1);
    expect(decoded.exp).toBe(decoded.tokenExp);
    expect(decoded.exp - decoded.iat).toBe(7200);
  });
});
