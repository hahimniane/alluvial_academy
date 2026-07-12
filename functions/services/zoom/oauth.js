const { getZoomConfig } = require('./config');

let cachedToken = null;

const _parseJsonResponse = async (response) => {
  const text = await response.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch (_) {
    return { raw: text };
  }
};

const getAccessToken = async () => {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAtMs > now + 60 * 1000) {
    return cachedToken.token;
  }

  const { accountId, clientId, clientSecret } = getZoomConfig();
  if (!accountId || !clientId || !clientSecret) {
    throw new Error('Zoom Server-to-Server OAuth is not configured');
  }

  const tokenUrl = new URL('https://zoom.us/oauth/token');
  tokenUrl.searchParams.set('grant_type', 'account_credentials');
  tokenUrl.searchParams.set('account_id', accountId);

  const response = await fetch(tokenUrl.toString(), {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
    },
  });
  const payload = await _parseJsonResponse(response);

  if (!response.ok || !payload.access_token) {
    const message =
      payload?.message ||
      payload?.error_description ||
      payload?.raw ||
      response.statusText ||
      'Zoom OAuth token request failed';
    const err = new Error(message);
    err.status = response.status;
    err.payload = payload;
    throw err;
  }

  const expiresInSeconds = Number(payload.expires_in) || 3600;
  cachedToken = {
    token: payload.access_token,
    expiresAtMs: now + Math.max(60, expiresInSeconds - 60) * 1000,
  };
  return cachedToken.token;
};

const clearCachedAccessToken = () => {
  cachedToken = null;
};

module.exports = {
  getAccessToken,
  clearCachedAccessToken,
};
