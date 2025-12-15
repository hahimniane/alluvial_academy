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

module.exports = {
  getZoomConfig,
};

