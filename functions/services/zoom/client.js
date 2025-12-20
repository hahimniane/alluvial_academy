const { getZoomConfig } = require('./config');

let cachedAccessToken = null;
let cachedAccessTokenExpiryMs = 0;

const parseZoomErrorBody = (text) => {
  if (!text) return null;
  try {
    const json = JSON.parse(text);
    const code = Number(json?.code);
    const message = typeof json?.message === 'string' ? json.message : null;
    if (!Number.isFinite(code) && !message) return null;
    return { code: Number.isFinite(code) ? code : null, message };
  } catch (_) {
    return null;
  }
};

const extractEmailFromZoomMessage = (message) => {
  if (typeof message !== 'string') return null;
  // Zoom 1114 messages look like: "Unable to assign 'user@example.com' as an alternative host ..."
  const m = message.match(/'([^']+@[^']+)'/);
  return m?.[1] || null;
};

const uniqueNonEmptyStrings = (values) => {
  if (!Array.isArray(values)) return [];
  const out = [];
  const seen = new Set();
  for (const raw of values) {
    const v = typeof raw === 'string' ? raw.trim() : '';
    if (!v || seen.has(v)) continue;
    seen.add(v);
    out.push(v);
  }
  return out;
};

const getAccessToken = async () => {
  const { accountId, clientId, clientSecret } = getZoomConfig();

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
 * @param {Object} options
 * @param {string} options.topic - Meeting topic/title
 * @param {string} options.startTimeIso - Start time in ISO format
 * @param {number} options.durationMinutes - Duration in minutes
 * @param {string} [options.agenda] - Meeting agenda
 * @param {string} [options.timezone='UTC'] - Timezone
 * @param {string} [options.hostUser] - Optional host user (overrides ZOOM_HOST_USER env var)
 * @returns {Promise<{id: string, joinUrl: string, passcode: string|null, hostUser: string}>}
 */
const createMeeting = async ({ topic, startTimeIso, durationMinutes, agenda, timezone = 'UTC', hostUser: hostUserOverride, breakoutRooms, alternativeHosts }) => {
  // Use provided host or fall back to env var (backward compatibility).
  const hostUser = hostUserOverride || getZoomConfig().hostUser;
  if (!hostUser) {
    throw new Error('Missing Zoom host user: set ZOOM_HOST_USER or configure at least one active host in Firestore.');
  }
  const token = await getAccessToken();

  // Build settings object
  const settings = {
    join_before_host: true,
    waiting_room: false,
    host_video: true,
    participant_video: true,
    mute_upon_entry: false,
  };

  // Add breakout rooms if provided
  if (breakoutRooms) {
    settings.breakout_room = {
      enable: true,
      rooms: breakoutRooms
    };
  }

  const altHosts = uniqueNonEmptyStrings(alternativeHosts);
  if (altHosts.length > 0) {
    settings.alternative_hosts = altHosts.join(',');
  }

  const createOnce = async (settingsPayload) => {
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
        settings: settingsPayload,
      }),
    });

    if (!resp.ok) {
      const text = await resp.text().catch(() => '');
      const zoomErr = parseZoomErrorBody(text);
      const err = new Error(`Zoom create meeting failed (${resp.status}): ${text || resp.statusText}`);
      err.status = resp.status;
      err.zoomCode = zoomErr?.code ?? null;
      err.zoomMessage = zoomErr?.message ?? null;
      err.zoomRawBody = text || null;
      throw err;
    }

    return resp.json();
  };

  let json;
  try {
    json = await createOnce(settings);
  } catch (err) {
    if (err?.zoomCode === 1114 && altHosts.length > 0) {
      console.warn('[Zoom] Alternative host assignment rejected (1114) during create; retrying without alternative hosts.');
      const retrySettings = { ...settings };
      delete retrySettings.alternative_hosts;
      json = await createOnce(retrySettings);
    } else {
      throw err;
    }
  }

  if (!json.id || !json.join_url) {
    throw new Error('Zoom create meeting response missing id or join_url');
  }

  // Return passcode if available in the create response
  // Also return the hostUser that was used (for storing on shift)
  return {
    id: String(json.id),
    joinUrl: String(json.join_url),
    passcode: json.password || json.passcode || null,
    hostUser: hostUser,
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

/**
 * Update an existing Zoom meeting
 * @param {string} meetingId - The Zoom meeting ID to update
 * @param {Object} options - Fields to update
 * @returns {Promise<{success: boolean}>}
 */
const updateMeeting = async (meetingId, options) => {
  const token = await getAccessToken();

  const patchMeeting = async (payload) => {
    const resp = await fetch(`https://api.zoom.us/v2/meetings/${encodeURIComponent(meetingId)}`, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    if (!resp.ok) {
      const text = await resp.text().catch(() => '');
      const zoomErr = parseZoomErrorBody(text);
      const err = new Error(`Zoom update meeting failed (${resp.status}): ${text || resp.statusText}`);
      err.status = resp.status;
      err.zoomCode = zoomErr?.code ?? null;
      err.zoomMessage = zoomErr?.message ?? null;
      err.zoomRawBody = text || null;
      throw err;
    }
  };

  // First: update topic/time/duration/breakout rooms (critical for scheduling).
  const primaryPayload = {};
  if (options.topic) primaryPayload.topic = options.topic;
  if (options.startTimeIso) primaryPayload.start_time = options.startTimeIso;
  if (options.durationMinutes) primaryPayload.duration = options.durationMinutes;

  if (options.breakoutRooms) {
    primaryPayload.settings = {
      breakout_room: {
        enable: true,
        rooms: options.breakoutRooms,
      },
    };
  }

  if (Object.keys(primaryPayload).length > 0) {
    await patchMeeting(primaryPayload);
  }

  // Second (best-effort): assign alternative hosts. Zoom rejects the whole update if any email is invalid.
  // We iteratively remove invalid emails (1114) until the request succeeds or the list is exhausted.
  let remainingAltHosts = uniqueNonEmptyStrings(options.alternativeHosts);
  while (remainingAltHosts.length > 0) {
    try {
      await patchMeeting({
        settings: { alternative_hosts: remainingAltHosts.join(',') },
      });
      break;
    } catch (err) {
      if (err?.zoomCode === 1114) {
        const badEmail = extractEmailFromZoomMessage(err.zoomMessage) || extractEmailFromZoomMessage(err.zoomRawBody);
        if (badEmail && remainingAltHosts.includes(badEmail)) {
          console.warn(`[Zoom] Skipping invalid alternative host: ${badEmail}`);
          remainingAltHosts = remainingAltHosts.filter((e) => e !== badEmail);
          continue;
        }
        console.warn(`[Zoom] Alternative host assignment rejected (1114); proceeding without alternative hosts.`);
        break;
      }
      throw err;
    }
  }

  return { success: true };
};

/**
 * Update meeting breakout rooms
 * Used to add new breakout rooms to an existing meeting
 * @param {string} meetingId - The Zoom meeting ID
 * @param {Array} breakoutRooms - Array of breakout room configs {name: string, participants: string[]}
 * @returns {Promise<{success: boolean}>}
 */
const updateMeetingBreakoutRooms = async (meetingId, breakoutRooms) => {
  const token = await getAccessToken();

  const resp = await fetch(`https://api.zoom.us/v2/meetings/${encodeURIComponent(meetingId)}`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      settings: {
        breakout_room: {
          enable: true,
          rooms: breakoutRooms
        }
      }
    }),
  });

  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    throw new Error(`Zoom update breakout rooms failed (${resp.status}): ${text || resp.statusText}`);
  }

  return { success: true };
};

/**
 * Delete a Zoom meeting
 * @param {string} meetingId - The Zoom meeting ID to delete
 * @returns {Promise<{success: boolean}>}
 */
const deleteMeeting = async (meetingId) => {
  const token = await getAccessToken();

  const resp = await fetch(`https://api.zoom.us/v2/meetings/${encodeURIComponent(meetingId)}`, {
    method: 'DELETE',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  // 204 = success, 404 = meeting already deleted/doesn't exist (still success for our purposes)
  if (resp.status === 204 || resp.status === 404) {
    return { success: true };
  }

  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    throw new Error(`Zoom delete meeting failed (${resp.status}): ${text || resp.statusText}`);
  }

  return { success: true };
};

module.exports = {
  createMeeting,
  getMeetingDetails,
  updateMeeting,
  updateMeetingBreakoutRooms,
  deleteMeeting,
};
