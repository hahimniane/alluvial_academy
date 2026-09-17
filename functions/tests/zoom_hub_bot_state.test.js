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

let autoId = 0;

const makeDocRef = (collectionName, id) => ({
  id,
  path: `${collectionName}/${id}`,
  get: async () => {
    const data = stores[collectionName]?.get(id);
    return { id, exists: data !== undefined, data: () => clone(data) };
  },
  set: async (data, options) => {
    if (!stores[collectionName]) stores[collectionName] = new Map();
    stores[collectionName].set(
      id,
      applyData(stores[collectionName].get(id), data, options?.merge === true),
    );
  },
  collection: (sub) => makeCollectionRef(`${collectionName}/${id}/${sub}`),
});

const makeCollectionRef = (name) => ({
  doc: (id) => makeDocRef(name, id ?? `auto_${(autoId += 1)}`),
  get: async () => ({
    docs: [...(stores[name] || new Map()).entries()]
      .map(([id, data]) => ({ id, data: () => clone(data) })),
  }),
});

const mockFirestore = jest.fn(() => ({
  collection: (name) => makeCollectionRef(name),
  batch: () => {
    const writes = [];
    return {
      set: (ref, data, options) => writes.push({ ref, data, options }),
      commit: async () => {
        for (const write of writes) await write.ref.set(write.data, write.options);
      },
    };
  },
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

/** Every presence event written across all shift subcollections. */
const presenceEvents = () => Object.entries(stores)
  .filter(([name]) => name.startsWith('class_presence_events/'))
  .flatMap(([, docs]) => [...docs.values()]);

beforeEach(() => {
  for (const name of Object.keys(stores)) delete stores[name];
  stores.hub_meetings = new Map();
  autoId = 0;
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

describe('rebuilding the member cache', () => {
  const { __test__ } = require('../handlers/zoom_hub_bot');

  test('does not bring a deleted hub back to life', async () => {
    // Observed live: deleting a hub, then deleting its members, fired this
    // rebuild and recreated the hub as a shell — no lane, no window, no
    // meeting — after which the bot's next state report filled it in and the
    // hub was properly back. Two ways in; the state endpoint was only one.
    stores['hub_meetings/gone_hub/members'] = new Map([
      ['m1', { uid: 'u1', shiftId: 's1', role: 'teacher' }],
    ]);

    const members = await __test__._rebuildBotAssignmentsCache(
      mockFirestore().collection('hub_meetings').doc('gone_hub'),
    );

    expect(members).toHaveLength(1);
    expect(stores.hub_meetings.has('gone_hub')).toBe(false);
  });

  test('still caches for a hub that exists', async () => {
    stores.hub_meetings.set('live_hub', { lane: 2, status: 'roomsOpen' });
    stores['hub_meetings/live_hub/members'] = new Map([
      ['m1', { uid: 'u1', shiftId: 's1', role: 'teacher' }],
    ]);

    await __test__._rebuildBotAssignmentsCache(
      mockFirestore().collection('hub_meetings').doc('live_hub'),
    );

    expect(stores.hub_meetings.get('live_hub').bot_assignments_cache.members)
      .toHaveLength(1);
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

describe('drop-out recording', () => {
  const inRoom = (uid, role, name) => ({ routingUid: uid, role, name });

  const hubWith = (participants) => ({
    lane: 2,
    status: 'roomsOpen',
    bot_status: 'roomsOpen',
    meetingNumber: '123',
    heartbeat_at: makeTimestamp(new Date(Date.now() - 4 * 60 * 1000)),
    live_participants_by_shift: participants,
  });

  const report = (participants, extra = {}) => makeRequest({
    hubDocId: 'hub_1',
    status: 'roomsOpen',
    stats: { inRoomOccupants: 1 },
    boIdByRoomName: { 'Room 1': `{BO-${Math.random()}}` },
    liveParticipantsByShift: participants,
    ...extra,
  });

  test('a teacher vanishing from their room is recorded as their own drop', () => {
    // This is the case the whole feature exists for, and the only signal that
    // sees it: teachers join through the Zoom desktop app, so no browser
    // heartbeat ever runs for them.
    stores.hub_meetings.set('hub_1', hubWith({
      shift_a: [inRoom('teacher_1', 'teacher', 'habibu barry'), inRoom('student_1', 'student', 'Amadou')],
    }));

    return zoomHubBotState(
      report({ shift_a: [inRoom('student_1', 'student', 'Amadou')] }),
      makeResponse(),
    ).then(() => {
      const events = presenceEvents();
      expect(events).toHaveLength(1);
      expect(events[0]).toMatchObject({
        shift_id: 'shift_a',
        uid: 'teacher_1',
        name: 'habibu barry',
        role: 'teacher',
        type: 'departed',
        cause: 'individual',
      });
    });
  });

  test('a whole room going at once is not blamed on anybody', async () => {
    stores.hub_meetings.set('hub_1', hubWith({
      shift_a: [inRoom('teacher_1', 'teacher'), inRoom('student_1', 'student')],
    }));

    await zoomHubBotState(report({ shift_a: [] }), makeResponse());

    const events = presenceEvents();
    expect(events).toHaveLength(2);
    expect(events.every((e) => e.cause === 'simultaneous')).toBe(true);
  });

  test('somebody the bot was moving is our doing, not a drop-out', async () => {
    stores.hub_meetings.set('hub_1', hubWith({
      shift_a: [inRoom('teacher_1', 'teacher'), inRoom('student_1', 'student')],
    }));

    await zoomHubBotState(
      report({ shift_a: [inRoom('student_1', 'student')] }, { routedUids: ['teacher_1'] }),
      makeResponse(),
    );

    expect(presenceEvents()[0]).toMatchObject({
      uid: 'teacher_1', cause: 'platform', cause_detail: 'bot_moved_them',
    });
  });

  test('the hub closing is recorded as ours, not as everyone quitting', async () => {
    stores.hub_meetings.set('hub_1', hubWith({
      shift_a: [inRoom('teacher_1', 'teacher'), inRoom('student_1', 'student')],
    }));

    await zoomHubBotState(makeRequest({ hubDocId: 'hub_1', status: 'left' }), makeResponse());

    const events = presenceEvents();
    expect(events).toHaveLength(2);
    expect(events.every((e) => e.cause === 'platform')).toBe(true);
    expect(events[0].cause_detail).toBe('hub_window_closed');
  });

  test('somebody coming back is recorded too, so the absence can be measured', async () => {
    stores.hub_meetings.set('hub_1', hubWith({ shift_a: [inRoom('student_1', 'student')] }));

    await zoomHubBotState(
      report({ shift_a: [inRoom('student_1', 'student'), inRoom('teacher_1', 'teacher')] }),
      makeResponse(),
    );

    expect(presenceEvents()[0]).toMatchObject({ uid: 'teacher_1', type: 'arrived' });
  });

  test('a report that changes nothing writes no events', async () => {
    const people = { shift_a: [inRoom('teacher_1', 'teacher')] };
    stores.hub_meetings.set('hub_1', hubWith(people));

    await zoomHubBotState(report(people), makeResponse());

    expect(presenceEvents()).toEqual([]);
  });

  test('an emptied room records the drop-out that used to vanish', async () => {
    // The live failure: the bot lists a class only while somebody is in its
    // room, so a teacher leaving removed the class from the report and nothing
    // at all was recorded. Reproduced end to end against the real endpoint.
    stores.hub_meetings.set('hub_1', hubWith({
      shift_a: [inRoom('teacher_1', 'teacher', 'habibu barry')],
      shift_b: [inRoom('teacher_2', 'teacher')],
    }));

    await zoomHubBotState(report({ shift_b: [inRoom('teacher_2', 'teacher')] }), makeResponse());

    const events = presenceEvents();
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({
      shift_id: 'shift_a', uid: 'teacher_1', type: 'departed', cause: 'individual',
    });
  });

  test('a bot that cannot see its rooms is not read as everyone leaving', async () => {
    // The danger the old guard was really for: believed literally, a blind
    // report is every person in every class dropping out in the same second.
    stores.hub_meetings.set('hub_1', {
      ...hubWith({
        shift_a: [inRoom('teacher_1', 'teacher')],
        shift_b: [inRoom('teacher_2', 'teacher')],
      }),
      rooms: [{ name: 'Room 1' }, { name: 'Room 2' }],
    });

    await zoomHubBotState(makeRequest({
      hubDocId: 'hub_1',
      status: 'roomsOpen',
      stats: { inRoomOccupants: 0, liveRoomCount: 0 },
      boIdByRoomName: { 'Room 1': '{X}' },
      liveParticipantsByShift: {},
    }), makeResponse());

    expect(presenceEvents()).toEqual([]);
  });

  test('a failure to record never breaks the bot\'s state report', async () => {
    stores.hub_meetings.set('hub_1', hubWith({ shift_a: [inRoom('teacher_1', 'teacher')] }));
    const firestore = require('firebase-admin').firestore;
    const realBatch = firestore().batch;
    firestore().batch = () => { throw new Error('firestore is unhappy'); };

    const res = makeResponse();
    await zoomHubBotState(report({ shift_a: [] }), res);

    expect(res.statusCode).toBe(200);
    expect(stores.hub_meetings.get('hub_1').status).toBe('roomsOpen');
    firestore().batch = realBatch;
  });
});
