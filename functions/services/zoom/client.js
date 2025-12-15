const {getZoomConfig} = require('./config');

let cachedAccessToken = null;
let cachedAccessTokenExpiryMs = 0;

const getAccessToken = async () => {
  const {accountId, clientId, clientSecret} = getZoomConfig();

  const now = Date.now();
  if (cachedAccessToken && now < cachedAccessTokenExpiryMs - 30_000) {
    return cachedAccessToken;
  }

  if (typeof fetch !== 'function') {
    throw new Error('Global fetch is not available (Node 20+ required).');
  }

  const tokenUrl = new URL('https://zoom.us/oauth/token');
  tokenUrl.searchParams.set('grant_type', 'account_credentials');
  tokenUrl.searchParams.set('account_id', accountId);

  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const resp = await fetch(tokenUrl.toString(), {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basic}`,
    },
  });

  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    throw new Error(`Zoom token request failed (${resp.status}): ${text || resp.statusText}`);
  }

  const json = await resp.json();
  if (!json.access_token) {
    throw new Error('Zoom token response missing access_token');
  }

  const expiresInSeconds = Number(json.expires_in || 3600);
  cachedAccessToken = json.access_token;
  cachedAccessTokenExpiryMs = Date.now() + expiresInSeconds * 1000;
  return cachedAccessToken;
};

/**
 * Create a new Zoom meeting
 * @returns {Promise<{id: string, joinUrl: string, passcode: string|null}>}
 */
const createMeeting = async ({topic, startTimeIso, durationMinutes, agenda, timezone = 'UTC'}) => {
  const {hostUser} = getZoomConfig();
  const token = await getAccessToken();

  const resp = await fetch(`https://api.zoom.us/v2/users/${encodeURIComponent(hostUser)}/meetings`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      topic,
      type: 2,
      start_time: startTimeIso,
      duration: durationMinutes,
      timezone,
      agenda,
      settings: {
        join_before_host: true,
        waiting_room: false,
        host_video: true,
        participant_video: true,
        mute_upon_entry: false,
      },
    }),
  });

  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    throw new Error(`Zoom create meeting failed (${resp.status}): ${text || resp.statusText}`);
  }

  const json = await resp.json();
  if (!json.id || !json.join_url) {
    throw new Error('Zoom create meeting response missing id or join_url');
  }
  
  // Return passcode if available in the create response
  return {
    id: String(json.id),
    joinUrl: String(json.join_url),
    passcode: json.password || json.passcode || null,
  };
};

/**
 * Get meeting details from Zoom API
 * Used to retrieve passcode for existing meetings that don't have it stored
 * @param {string} meetingId - The Zoom meeting ID
 * @returns {Promise<{id: string, topic: string, passcode: string|null, joinUrl: string}>}
 */
const getMeetingDetails = async (meetingId) => {
  const token = await getAccessToken();

  const resp = await fetch(`https://api.zoom.us/v2/meetings/${encodeURIComponent(meetingId)}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    throw new Error(`Zoom get meeting failed (${resp.status}): ${text || resp.statusText}`);
  }

  const json = await resp.json();
  
  return {
    id: String(json.id),
    topic: json.topic || '',
    passcode: json.password || json.passcode || null,
    joinUrl: json.join_url || '',
    startTime: json.start_time || null,
    duration: json.duration || null,
  };
};

module.exports = {
  createMeeting,
  getMeetingDetails,
};

