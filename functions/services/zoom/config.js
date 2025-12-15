// For Firebase Functions v2, environment variables are loaded from .env file
// No need for functions.config() anymore

const getConfigValue = (envKey) => {
  return process.env[envKey] || undefined;
};

const requireConfigValue = (envKey) => {
  const value = getConfigValue(envKey);
  if (!value) {
    throw new Error(`Missing Zoom configuration: set ${envKey} env var in .env file`);
  }
  return value;
};

/**
 * Get Zoom API configuration (for creating/managing meetings)
 */
const getZoomConfig = () => {
  const accountId = requireConfigValue('ZOOM_ACCOUNT_ID');
  const clientId = requireConfigValue('ZOOM_CLIENT_ID');
  const clientSecret = requireConfigValue('ZOOM_CLIENT_SECRET');
  const hostUser = requireConfigValue('ZOOM_HOST_USER');
  const joinTokenSecret = requireConfigValue('ZOOM_JOIN_TOKEN_SECRET');
  const encryptionKeyB64 = requireConfigValue('ZOOM_ENCRYPTION_KEY_B64');

  return {
    accountId,
    clientId,
    clientSecret,
    hostUser,
    joinTokenSecret,
    encryptionKeyB64,
  };
};

/**
 * Get Meeting SDK configuration (for generating Meeting SDK JWT)
 * These credentials are from the Meeting SDK-enabled General App in Zoom Marketplace
 */
const getMeetingSdkConfig = () => {
  const sdkKey = getConfigValue('ZOOM_MEETING_SDK_KEY');
  const sdkSecret = getConfigValue('ZOOM_MEETING_SDK_SECRET');
  
  // If Meeting SDK credentials are not set, return null (allows graceful fallback)
  if (!sdkKey || !sdkSecret) {
    return null;
  }
  
  return {
    sdkKey,
    sdkSecret,
  };
};

/**
 * Check if Meeting SDK is configured
 */
const isMeetingSdkConfigured = () => {
  const config = getMeetingSdkConfig();
  return config !== null;
};

module.exports = {
  getZoomConfig,
  getMeetingSdkConfig,
  isMeetingSdkConfigured,
};

