const { getAccessToken } = require('./oauth');

const API_BASE = 'https://api.zoom.us/v2';

const _parseJsonResponse = async (response) => {
  const text = await response.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch (_) {
    return { raw: text };
  }
};

const zoomRequest = async (method, path, body) => {
  const accessToken = await getAccessToken();
  const response = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const payload = await _parseJsonResponse(response);

  if (!response.ok) {
    const message =
      payload?.message ||
      payload?.error_description ||
      payload?.raw ||
      response.statusText ||
      'Zoom request failed';
    const err = new Error(message);
    err.status = response.status;
    err.payload = payload;
    throw err;
  }

  return Object.keys(payload).length === 0 ? { success: true } : payload;
};

const createMeeting = (hostUserId, body) =>
  zoomRequest(
    'POST',
    `/users/${encodeURIComponent(hostUserId)}/meetings`,
    body,
  );

const getMeeting = (meetingId) =>
  zoomRequest('GET', `/meetings/${encodeURIComponent(meetingId)}`);

const updateMeeting = (meetingId, body) =>
  zoomRequest('PATCH', `/meetings/${encodeURIComponent(meetingId)}`, body);

const deleteMeeting = (meetingId) =>
  zoomRequest('DELETE', `/meetings/${encodeURIComponent(meetingId)}`);

const getUserZak = async (hostUserId) => {
  const response = await zoomRequest(
    'GET',
    `/users/${encodeURIComponent(hostUserId)}/token?type=zak`,
  );
  return response?.token || null;
};

const updateUserSettings = (userId, body) =>
  zoomRequest(
    'PATCH',
    `/users/${encodeURIComponent(userId)}/settings`,
    body,
  );

const listMeetingParticipants = (meetingId) =>
  zoomRequest(
    'GET',
    `/metrics/meetings/${encodeURIComponent(meetingId)}/participants?type=live&page_size=300`,
  );

const endMeeting = (meetingId) =>
  zoomRequest(
    'PUT',
    `/meetings/${encodeURIComponent(meetingId)}/status`,
    { action: 'end' },
  );

module.exports = {
  zoomRequest,
  createMeeting,
  getMeeting,
  updateMeeting,
  deleteMeeting,
  getUserZak,
  updateUserSettings,
  listMeetingParticipants,
  endMeeting,
};
