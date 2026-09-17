/**
 * The sweep that summarises finished classes, and who is allowed to read the
 * result. A mistake in the first leaves holes in the history; a mistake in the
 * second shows one teacher another teacher's record.
 */
jest.mock('firebase-functions/v2/https', () => {
  const unwrap = (...args) => (typeof args[0] === 'function' ? args[0] : args[1]);
  class HttpsError extends Error {
    constructor(code, message, details) { super(message); this.code = code; this.details = details; }
  }
  return { onCall: (...a) => unwrap(...a), onRequest: (...a) => unwrap(...a), HttpsError };
});
jest.mock('firebase-functions/v2/scheduler', () => {
  const unwrap = (...args) => (typeof args[0] === 'function' ? args[0] : args[1]);
  return { onSchedule: (...a) => unwrap(...a) };
});

const stores = {};

const makeTimestamp = (date) => ({ toDate: () => date, valueOf: () => date.getTime() });
const serverTimestamp = () => makeTimestamp(new Date());

const clone = (value) => {
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object') {
    if (value.toDate) return value;
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, clone(v)]));
  }
  return value;
};

const docsOf = (name) => [...(stores[name] || new Map()).entries()]
  .map(([id, data]) => ({ id, exists: true, data: () => clone(data) }));

const makeDocRef = (collectionName, id) => ({
  id,
  get: async () => {
    const data = stores[collectionName]?.get(id);
    return { id, exists: data !== undefined, data: () => clone(data) };
  },
  set: async (data, options) => {
    if (!stores[collectionName]) stores[collectionName] = new Map();
    const previous = options?.merge === true ? stores[collectionName].get(id) || {} : {};
    stores[collectionName].set(id, { ...previous, ...clone(data) });
  },
  collection: (sub) => makeCollectionRef(`${collectionName}/${id}/${sub}`),
});

const makeCollectionRef = (name) => {
  const filters = [];
  const ref = {
    doc: (id) => makeDocRef(name, id ?? `auto_${Math.random()}`),
    where: (field, op, value) => { filters.push({ field, op, value }); return ref; },
    get: async () => {
      let docs = docsOf(name);
      for (const filter of filters) {
        docs = docs.filter((doc) => {
          const actual = doc.data()[filter.field];
          const left = actual && actual.toDate ? actual.toDate().getTime() : actual;
          const right = filter.value && filter.value.toDate
            ? filter.value.toDate().getTime() : filter.value;
          if (filter.op === '==') return left === right;
          if (filter.op === '>=') return left >= right;
          if (filter.op === '<') return left < right;
          if (filter.op === '<=') return left <= right;
          return true;
        });
      }
      return { docs, empty: docs.length === 0 };
    },
  };
  return ref;
};

const mockFirestore = jest.fn(() => ({
  collection: (name) => makeCollectionRef(name),
  batch: () => {
    const writes = [];
    return {
      set: (ref, data, options) => writes.push({ ref, data, options }),
      commit: async () => { for (const w of writes) await w.ref.set(w.data, w.options); },
    };
  },
}));
mockFirestore.FieldValue = { serverTimestamp };
mockFirestore.Timestamp = { fromDate: makeTimestamp };
mockFirestore.FieldPath = { documentId: () => '__name__' };

jest.mock('firebase-admin', () => ({ firestore: mockFirestore }));

const handlers = require('../handlers/presence_reports');
const { summariseFinishedClasses, startOfWeek, periodKey } = handlers.__test__;

const NOW = new Date('2026-09-16T15:00:00Z');
const ago = (minutes) => new Date(NOW.getTime() - minutes * 60 * 1000);

const addShift = (id, { endedMinutesAgo, teacherId = 'teacher_1' }) => {
  if (!stores.teaching_shifts) stores.teaching_shifts = new Map();
  stores.teaching_shifts.set(id, {
    teacher_id: teacherId,
    teacher_name: 'habibu barry',
    custom_name: 'Quran 1:1',
    shift_start: makeTimestamp(ago(endedMinutesAgo + 60)),
    shift_end: makeTimestamp(ago(endedMinutesAgo)),
  });
};

const addEvent = (shiftId, type, uid, when, extra = {}) => {
  const name = `class_presence_events/${shiftId}/events`;
  if (!stores[name]) stores[name] = new Map();
  stores[name].set(`e${stores[name].size}`, {
    shift_id: shiftId, type, uid, role: uid.startsWith('teacher') ? 'teacher' : 'student',
    name: uid, at: makeTimestamp(when), cause: type === 'departed' ? 'individual' : null, ...extra,
  });
};

beforeEach(() => {
  for (const key of Object.keys(stores)) delete stores[key];
  stores.teaching_shifts = new Map();
  stores.teaching_shifts_archive = new Map();
});

describe('summariseFinishedClasses', () => {
  test('summarises a class that has finished and settled', () => {
    addShift('shift_a', { endedMinutesAgo: 60 });
    addEvent('shift_a', 'departed', 'teacher_1', ago(100));
    addEvent('shift_a', 'arrived', 'teacher_1', ago(97));

    return summariseFinishedClasses({ now: NOW }).then((result) => {
      expect(result.written).toBe(1);
      const summary = stores.class_presence_summaries.get('shift_a');
      expect(summary).toMatchObject({
        teacher_id: 'teacher_1',
        teacher_drops: 1,
        teacher_seconds_lost: 180,
      });
    });
  });

  test('leaves a class alone until its grace period has run out', async () => {
    // Summarising a class that only just ended would miss anyone still inside
    // during the 15 minutes they are entitled to.
    addShift('shift_a', { endedMinutesAgo: 5 });
    addEvent('shift_a', 'departed', 'teacher_1', ago(20));

    const result = await summariseFinishedClasses({ now: NOW });
    expect(result.written).toBe(0);
    expect(stores.class_presence_summaries).toBeUndefined();
  });

  test('a class the bot never watched is not written as a clean sheet', async () => {
    addShift('shift_quiet', { endedMinutesAgo: 60 });

    const result = await summariseFinishedClasses({ now: NOW });
    expect(result.written).toBe(0);
    expect(result.skipped).toBe(1);
  });

  test('running twice does not rewrite what it already did', async () => {
    addShift('shift_a', { endedMinutesAgo: 60 });
    addEvent('shift_a', 'departed', 'teacher_1', ago(100));
    addEvent('shift_a', 'arrived', 'teacher_1', ago(97));

    const first = await summariseFinishedClasses({ now: NOW });
    const second = await summariseFinishedClasses({ now: NOW });
    expect(first.written).toBe(1);
    expect(second.written).toBe(0);
    expect(second.skipped).toBe(1);
  });

  test('a missed run repairs itself on the next sweep', async () => {
    // Several hours of classes, none summarised. One sweep should catch them
    // all rather than only the most recent.
    addShift('shift_1', { endedMinutesAgo: 60 });
    addShift('shift_2', { endedMinutesAgo: 180 });
    addShift('shift_3', { endedMinutesAgo: 300 });
    for (const id of ['shift_1', 'shift_2', 'shift_3']) {
      addEvent(id, 'departed', 'teacher_1', ago(400));
      addEvent(id, 'arrived', 'teacher_1', ago(397));
    }

    const result = await summariseFinishedClasses({ now: NOW });
    expect(result.written).toBe(3);
  });
});

describe('period keys', () => {
  test('a week starts on Monday', () => {
    expect(startOfWeek(new Date('2026-09-16T15:00:00Z')).toISOString().slice(0, 10))
      .toBe('2026-09-14');
    expect(startOfWeek(new Date('2026-09-14T00:00:00Z')).toISOString().slice(0, 10))
      .toBe('2026-09-14');
    // Sunday belongs to the week that began the previous Monday.
    expect(startOfWeek(new Date('2026-09-20T23:59:00Z')).toISOString().slice(0, 10))
      .toBe('2026-09-14');
  });

  test('a period key names its type and its start', () => {
    expect(periodKey('weekly', new Date('2026-09-14T00:00:00Z'))).toBe('weekly_2026-09-14');
  });
});

describe('who may read a report', () => {
  const { getPresenceReport, getPresenceOverview } = handlers;

  beforeEach(() => {
    stores.users = new Map([
      ['admin_1', { role: 'admin' }],
      ['teacher_1', { user_type: 'teacher' }],
      ['teacher_2', { user_type: 'teacher' }],
    ]);
    stores.presence_period_reports = new Map([
      ['teacher_1_weekly_2026-09-14', {
        uid: 'teacher_1', role: 'teacher', period_type: 'weekly',
        period_start: makeTimestamp(new Date('2026-09-14T00:00:00Z')),
        counted: { drops: 3, secondsLost: 400, longestSeconds: 200, neverReturned: 0 },
      }],
    ]);
  });

  test('a teacher can read their own', async () => {
    const result = await getPresenceReport({
      auth: { uid: 'teacher_1', token: {} },
      data: { referenceDate: '2026-09-16T15:00:00Z' },
    });
    expect(result.report).toMatchObject({ uid: 'teacher_1' });
  });

  test('a teacher cannot read somebody else\'s', async () => {
    await expect(getPresenceReport({
      auth: { uid: 'teacher_2', token: {} },
      data: { uid: 'teacher_1', referenceDate: '2026-09-16T15:00:00Z' },
    })).rejects.toMatchObject({ code: 'permission-denied' });
  });

  test('an admin can read anybody\'s', async () => {
    const result = await getPresenceReport({
      auth: { uid: 'admin_1', token: {} },
      data: { uid: 'teacher_1', referenceDate: '2026-09-16T15:00:00Z' },
    });
    expect(result.report).toMatchObject({ uid: 'teacher_1' });
  });

  test('signing out means reading nothing', async () => {
    await expect(getPresenceReport({ auth: null, data: {} }))
      .rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(getPresenceOverview({ auth: null, data: {} }))
      .rejects.toMatchObject({ code: 'unauthenticated' });
  });

  test('the overview is administrators only', async () => {
    await expect(getPresenceOverview({
      auth: { uid: 'teacher_1', token: {} }, data: {},
    })).rejects.toMatchObject({ code: 'permission-denied' });

    const result = await getPresenceOverview({
      auth: { uid: 'admin_1', token: {} },
      data: { referenceDate: '2026-09-16T15:00:00Z' },
    });
    expect(result.teachers.map((t) => t.uid)).toEqual(['teacher_1']);
  });

  test('a period with no report yet answers plainly instead of failing', async () => {
    const result = await getPresenceReport({
      auth: { uid: 'teacher_2', token: {} },
      data: { referenceDate: '2026-09-16T15:00:00Z' },
    });
    expect(result.success).toBe(true);
    expect(result.report).toBeNull();
  });

  test('a nonsense date is refused rather than guessed at', async () => {
    await expect(getPresenceReport({
      auth: { uid: 'teacher_1', token: {} },
      data: { referenceDate: 'last tuesday' },
    })).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

describe('the period a reader is actually looking at', () => {
  const { __test__ } = require('../handlers/presence_reports');
  const { periodKey, _periodFor } = __test__;

  // A card asks for the period it is in. Anything that only ever writes the
  // period that has ended writes a key nobody reads.
  const keyFor = (periodType, at) =>
    periodKey(periodType, _periodFor(periodType, new Date(at)).periodStart);

  test('a report built for "now" is the one a card asks for', () => {
    for (const at of ['2026-09-17T15:00:00Z', '2026-09-21T02:30:00Z', '2026-09-01T00:05:00Z']) {
      expect(keyFor('weekly', at)).toBe(keyFor('weekly', at));
      expect(keyFor('monthly', at)).toBe(keyFor('monthly', at));
    }
  });

  test('building only the finished period would never be read', () => {
    const monday = '2026-09-21T02:30:00Z';
    const weekBefore = new Date(Date.parse(monday) - 7 * 24 * 60 * 60 * 1000).toISOString();
    expect(keyFor('weekly', weekBefore)).not.toBe(keyFor('weekly', monday));
  });

  test('a week is keyed from its Monday, whatever day it is read on', () => {
    const monday = keyFor('weekly', '2026-09-14T00:00:00Z');
    expect(keyFor('weekly', '2026-09-17T15:00:00Z')).toBe(monday);
    expect(keyFor('weekly', '2026-09-20T23:59:00Z')).toBe(monday);
    expect(keyFor('weekly', '2026-09-21T00:00:00Z')).not.toBe(monday);
  });
});
