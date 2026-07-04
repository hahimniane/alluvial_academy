const jwt = require('jsonwebtoken');
const { getZoomConfig } = require('./config');

const generateMeetingSdkSignature = ({
  meetingNumber,
  role = 0,
  expiresInSeconds = 2 * 60 * 60,
}) => {
  const { sdkKey, sdkSecret } = getZoomConfig();
  if (!sdkKey || !sdkSecret) {
    throw new Error('Zoom Meeting SDK credentials are not configured');
  }

  const normalizedMeetingNumber = String(meetingNumber || '').trim();
  if (!normalizedMeetingNumber) {
    throw new Error('Zoom meeting number is required');
  }

  const nowSeconds = Math.floor(Date.now() / 1000) - 30;
  const exp = nowSeconds + Math.max(1800, expiresInSeconds);
  const normalizedRole = Number(role) === 1 ? 1 : 0;

  return jwt.sign(
    {
      appKey: sdkKey,
      mn: normalizedMeetingNumber,
      role: normalizedRole,
      iat: nowSeconds,
      exp,
      tokenExp: exp,
    },
    sdkSecret,
    {
      algorithm: 'HS256',
      header: { alg: 'HS256', typ: 'JWT' },
    },
  );
};

module.exports = {
  generateMeetingSdkSignature,
};
