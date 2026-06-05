const { getRealtimeKitConfig } = require('./config');

const API_BASE = 'https://api.cloudflare.com/client/v4';

const _path = (config, suffix) => (
  `/accounts/${config.accountId}/realtime/kit/${config.appId}${suffix}`
);

const realtimeKitRequest = async (method, suffix, body) => {
  const config = getRealtimeKitConfig();
  const response = await fetch(`${API_BASE}${_path(config, suffix)}`, {
    method,
    headers: {
      Authorization: `Bearer ${config.apiToken}`,
      'Content-Type': 'application/json',
    },
    body: body == null ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  let payload = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch (_) {
      payload = { raw: text };
    }
  }

  if (!response.ok || payload?.success === false) {
    const message =
      payload?.errors?.[0]?.message ||
      payload?.message ||
      response.statusText ||
      'RealtimeKit request failed';
    const err = new Error(message);
    err.status = response.status;
    err.payload = payload;
    throw err;
  }

  return payload || { success: true };
};

const createMeeting = (body) => realtimeKitRequest('POST', '/meetings', body);
const getMeeting = (meetingId) =>
  realtimeKitRequest('GET', `/meetings/${encodeURIComponent(meetingId)}`);
const patchMeeting = (meetingId, body) =>
  realtimeKitRequest('PATCH', `/meetings/${encodeURIComponent(meetingId)}`, body);
const addParticipant = (meetingId, body) =>
  realtimeKitRequest(
    'POST',
    `/meetings/${encodeURIComponent(meetingId)}/participants`,
    body,
  );
const updateParticipant = (meetingId, participantId, body) =>
  realtimeKitRequest(
    'PATCH',
    `/meetings/${encodeURIComponent(meetingId)}/participants/${encodeURIComponent(participantId)}`,
    body,
  );
const listMeetingParticipants = (meetingId) =>
  realtimeKitRequest(
    'GET',
    `/meetings/${encodeURIComponent(meetingId)}/participants`,
  );
const deleteParticipant = (meetingId, participantId) =>
  realtimeKitRequest(
    'DELETE',
    `/meetings/${encodeURIComponent(meetingId)}/participants/${encodeURIComponent(participantId)}`,
  );
const kickActiveSessionParticipants = (meetingId, body) =>
  realtimeKitRequest(
    'POST',
    `/meetings/${encodeURIComponent(meetingId)}/active-session/kick`,
    body,
  );
const refreshParticipantToken = (meetingId, participantId) =>
  realtimeKitRequest(
    'POST',
    `/meetings/${encodeURIComponent(meetingId)}/participants/${encodeURIComponent(participantId)}/token`,
    {},
  );

module.exports = {
  createMeeting,
  getMeeting,
  patchMeeting,
  addParticipant,
  updateParticipant,
  listMeetingParticipants,
  deleteParticipant,
  kickActiveSessionParticipants,
  refreshParticipantToken,
};
