const _firstNonEmpty = (names) => {
  for (const name of names) {
    const value = process.env[name];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return '';
};

const getZoomConfig = () => ({
  accountId: _firstNonEmpty(['ZOOM_S2S_ACCOUNT_ID', 'ZOOM_ACCOUNT_ID']),
  clientId: _firstNonEmpty(['ZOOM_S2S_CLIENT_ID', 'ZOOM_CLIENT_ID']),
  clientSecret: _firstNonEmpty(['ZOOM_S2S_CLIENT_SECRET', 'ZOOM_CLIENT_SECRET']),
  sdkKey: _firstNonEmpty([
    'ZOOM_SDK_KEY',
    'ZOOM_MEETING_SDK_KEY',
    'ZOOM_MEETING_SDK_CLIENT_ID',
  ]),
  sdkSecret: _firstNonEmpty([
    'ZOOM_SDK_SECRET',
    'ZOOM_MEETING_SDK_SECRET',
    'ZOOM_MEETING_SDK_CLIENT_SECRET',
  ]),
  webhookSecretToken: _firstNonEmpty(['ZOOM_WEBHOOK_SECRET_TOKEN']),
});

const isZoomApiConfigured = () => {
  const config = getZoomConfig();
  return Boolean(config.accountId && config.clientId && config.clientSecret);
};

const isZoomSdkConfigured = () => {
  const config = getZoomConfig();
  return Boolean(config.sdkKey && config.sdkSecret);
};

module.exports = {
  getZoomConfig,
  isZoomApiConfigured,
  isZoomSdkConfigured,
};
