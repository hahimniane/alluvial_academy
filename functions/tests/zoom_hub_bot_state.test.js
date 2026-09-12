/**
 * The bot's state endpoint. Two things here are easy to get wrong and expensive
 * when wrong: writing to a hub that no longer exists (a merge write creates it),
 * and the recycle estimate a waiting class is shown.
 */
process.env.ZOOM_HUB_BOT_KEY = 'test-bot-key';

jest.mock('firebase-functions/v2/https', () => {
  const unwrap = (...args) => (typeof args[0] === 'function' ? args[0] : args[1]);
  return { onCall: (...a) => unwrap(...a), onRequest: (...a) => unwrap(...a) };
});
jest.mock('firebase-functions/v2/firestore', () => {
  const unwrap = (...args) => (typeof args[0] === 'function' ? args[0] : args[1]);
  return { onDocumentWritten: (...a) => unwrap(...a) };
});

const stores = { hub_meetings: new Map() };

const makeTimestamp = (date) => ({ _date: date, toDate: () => date, valueOf: () => date.getTime() });
const serverTimestamp = () => makeTimestamp(new Date());

const clone = (value) => {
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object') {
    if (value.toDate) return value;
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, clone(v)]));
  }
  return value;
};

const applyData = (existing, data, merge = false) => {
  const next = merge ? { ...(existing || {}) } : {};
  for (const [key, value] of Object.entries(data || {})) next[key] = clone(value);
  return next;
};

const makeDocRef = (collectionName, id) => ({
  id,
  get: async () => {
    const data = stores[collectionName]?.get(id);
    return { id, exists: data !== undefined, data: () => clone(data) };
  },
  set: async (data, options) => {
    stores[collectionName].set(
      id,
      applyData(stores[collectionName].get(id), data, options?.merge === true),
    );
  },
  collection: () => ({ get: async () => ({ docs: [] }) }),
});

const mockFirestore = jest.fn(() => ({
  collection: (name) => ({ doc: (id) => makeDocRef(name, id) }),
}));
mockFirestore.FieldValue = { serverTimestamp };
mockFirestore.Timestamp = { fromDate: makeTimestamp };

jest.mock('firebase-admin', () => ({ firestore: mockFirestore }));
jest.mock('../services/zoom/client', () => ({
  endMeeting: jest.fn(async () => ({})),
  getUserZak: jest.fn(async () => 'zak'),
}));
jest.mock('../services/zoom/config', () => ({ getZoomConfig: () => ({ sdkKey: 'k' }) }));
jest.mock('../services/zoom/signature', () => ({ generateMeetingSdkSignature: () => 'sig' }));

const { zoomHubBotState } = require('../handlers/zoom_hub_bot');

const makeRequest = (body) => ({
  method: 'POST',
  body,
  get: (header) => (header.toLowerCase() === 'x-bot-key' ? 'test-bot-key' : undefined),
  headers: { 'x-bot-key': 'test-bot-key' },
});

const makeResponse = () => {
  const res = {
    statusCode: null,
    body: null,
    set: jest.fn(() => res),
    status: jest.fn((code) => { res.statusCode = code; return res; }),
    json: jest.fn((body) => { res.body = body; return res; }),
    send: jest.fn((body) => { res.body = body; return res; }),
  };
  return res;
};

beforeEach(() => {
  stores.hub_meetings = new Map();
});

describe('a hub that no longer exists', () => {
  test('is not recreated by a state report', async () => {
    // The hub was deleted while its bot was still in session — the bot's next
    // report used to merge a half-formed doc back into existence, with a status
    // of roomsOpen but no lane, window or meeting number.
    const res = makeResponse();
    await zoomHubBotState(makeRequest({
      hubDocId: 'deleted_hub',
      status: 'roomsOpen',
      stats: { inRoomOccupants: 0 },
    }), res);

    expect(res.statusCode).toBe(404);
    expect(stores.hub_meetings.has('deleted_hub')).toBe(false);
  });

  test('is not recreated by a recycle report either', async () => {
    const res = makeResponse();
    await zoomHubBotState(makeRequest({
      hubDocId: 'deleted_hub',
      status: 'recycling',
      rejoinExpectedAt: new Date().toISOString(),
    }), res);

    expect(res.statusCode).toBe(404);
    expect(stores.hub_meetings.has('deleted_hub')).toBe(false);
  });
});

describe('recycle estimate', () => {
  const liveHub = () => ({
    lane: 2,
    status: 'roomsOpen',
    bot_status: 'roomsOpen',
    meetingNumber: '123',
    heartbeat_at: makeTimestamp(new Date(Date.now() - 4 * 60 * 1000)),
  });

  test('records when the classroom will be back without disturbing hub state', async () => {
    const before = liveHub();
    stores.hub_meetings.set('hub_1', before);
    const expected = new Date(Date.now() + 175 * 1000);
    const res = makeResponse();

    await zoomHubBotState(makeRequest({
      hubDocId: 'hub_1',
      status: 'recycling',
      reason: 'silent 209s, probe unanswered',
      rejoinExpectedAt: expected.toISOString(),
    }), res);

    const hub = stores.hub_meetings.get('hub_1');
    expect(res.statusCode).toBe(200);
    expect(hub.bot_rejoin_expected_at.toDate().getTime()).toBe(expected.getTime());
    expect(hub.bot_recycle_reason).toBe('silent 209s, probe unanswered');
    expect(hub.bot_recycled_at).toBeTruthy();
    // The hub is between pages, not in a new state: the watchdog still has to
    // see the real last heartbeat, and routing still has to see roomsOpen.
    expect(hub.status).toBe('roomsOpen');
    expect(hub.bot_status).toBe('roomsOpen');
    expect(hub.heartbeat_at).toEqual(before.heartbeat_at);
  });

  test('is cleared once the bot is back, so nobody counts down to a past moment', async () => {
    stores.hub_meetings.set('hub_1', {
      ...liveHub(),
      bot_rejoin_expected_at: makeTimestamp(new Date(Date.now() - 60 * 1000)),
      bot_recycle_reason: 'silent 209s, probe unanswered',
    });
    const res = makeResponse();

    await zoomHubBotState(makeRequest({
      hubDocId: 'hub_1',
      status: 'roomsOpen',
      stats: { inRoomOccupants: 0 },
      boIdByRoomName: { 'Room 1': '{NEW-BO-ID}' },
    }), res);

    const hub = stores.hub_meetings.get('hub_1');
    expect(res.statusCode).toBe(200);
    expect(hub.bot_rejoin_expected_at).toBeNull();
    expect(hub.bot_recycle_reason).toBeNull();
  });

  test('a missing estimate is stored as nothing rather than an invalid date', async () => {
    stores.hub_meetings.set('hub_1', liveHub());
    const res = makeResponse();

    await zoomHubBotState(makeRequest({ hubDocId: 'hub_1', status: 'recycling' }), res);

    expect(res.statusCode).toBe(200);
    expect(stores.hub_meetings.get('hub_1').bot_rejoin_expected_at).toBeNull();
  });
});
