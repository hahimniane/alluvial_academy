/**
 * Pins the cost-reduction logic in zoom_hub_bot.js: the member-cache doc
 * shaping and the deterministic serializer used for report-on-change
 * heartbeat dedup. A regression in either silently re-inflates the Firestore
 * bill or, worse, makes the dedup skip real changes.
 */
const {__test__} = require('../handlers/zoom_hub_bot');

const {_botMemberFromDoc, _stableStringify} = __test__;

const fakeDoc = (id, data) => ({id, data: () => data});

describe('_botMemberFromDoc', () => {
  test('maps camelCase fields', () => {
    expect(_botMemberFromDoc(fakeDoc('u1', {
      uid: 'u1',
      userId: 'user-1',
      shiftId: 's1',
      role: 'student',
      displayName: 'Amina',
      routingDisplayName: 'Amina R',
      displayNameAliases: ['A.', ''],
    }))).toEqual({
      uid: 'u1',
      userId: 'user-1',
      shiftId: 's1',
      role: 'student',
      displayName: 'Amina',
      routingDisplayName: 'Amina R',
      displayNameAliases: ['A.'],
    });
  });

  test('maps snake_case fields and falls back to doc id for uid', () => {
    const member = _botMemberFromDoc(fakeDoc('doc-uid', {
      user_id: 'user-2',
      shift_id: 's2',
      role: 'teacher',
      display_name: 'Moussa',
      display_name_aliases: ['M'],
    }));
    expect(member.uid).toBe('doc-uid');
    expect(member.userId).toBe('user-2');
    expect(member.shiftId).toBe('s2');
    expect(member.displayName).toBe('Moussa');
    expect(member.displayNameAliases).toEqual(['M']);
  });

  test('omits empty optionals (same shape the endpoint always produced)', () => {
    const member = _botMemberFromDoc(fakeDoc('u3', {uid: 'u3', shiftId: 's3', role: ''}));
    expect(member).toEqual({uid: 'u3', shiftId: 's3', role: ''});
    expect('displayName' in member).toBe(false);
    expect('userId' in member).toBe(false);
  });
});

describe('_stableStringify (heartbeat change detection)', () => {
  test('key order does not create false "changed" signals', () => {
    const fromRequest = {s1: [{name: 'A', identity: 'x'}], s2: []};
    const fromFirestore = {s2: [], s1: [{identity: 'x', name: 'A'}]};
    expect(_stableStringify(fromRequest)).toBe(_stableStringify(fromFirestore));
  });

  test('a real participant change is detected', () => {
    const before = {s1: [{name: 'A'}]};
    const after = {s1: [{name: 'A'}, {name: 'B'}]};
    expect(_stableStringify(before)).not.toBe(_stableStringify(after));
  });

  test('handles primitives, null and arrays', () => {
    expect(_stableStringify(null)).toBe('null');
    expect(_stableStringify([1, 'a'])).toBe('[1,"a"]');
    expect(_stableStringify({b: 1, a: null})).toBe('{"a":null,"b":1}');
  });
});

describe('_selectPrimaryActiveHub (which hub a lane hosts)', () => {
  const {_selectPrimaryActiveHub} = __test__;
  const MINUTE = 60 * 1000;
  const now = new Date('2026-09-12T14:16:55Z');
  const at = (iso) => ({toDate: () => new Date(iso)});

  const hub = (id, {block, occupants = 0, heartbeatAgoMs = 10 * 1000, classEnd, liveShifts}) => ({
    id,
    data: () => ({
      blockIndex: block,
      stats: {inRoomOccupants: occupants},
      heartbeat_at: at(new Date(now.getTime() - heartbeatAgoMs).toISOString()),
      assigned_class_end: classEnd ? at(classEnd) : undefined,
      live_participants_by_shift: liveShifts,
    }),
  });

  test('a hub with people inside is kept, even though its own classes ended', () => {
    // 2026-09-12: habibu barry's 13:30-14:29 lesson was sitting in the spare
    // rooms of the 04:00 hub, whose own assigned classes had finished. The lane
    // switched away and the meeting ended under them, 13 minutes early.
    const occupiedOldHub = hub('hub_0400', {
      block: 3,
      occupants: 3,
      classEnd: '2026-09-12T09:30:00Z', // this hub's own classes ended hours ago
      liveShifts: {habibu_1330: [{name: 'habibu barry'}, {name: 'Amadou Diallo'}]},
    });
    const emptyNewHub = hub('hub_0630', {
      block: 1,
      occupants: 0,
      classEnd: '2026-09-13T00:00:00Z',
    });

    // habibu_1330 runs to 14:29, so at 14:16:55 it is still owed time.
    const chosen = _selectPrimaryActiveHub(
      [occupiedOldHub, emptyNewHub], now, new Set(['habibu_1330']),
    );
    expect(chosen.map((doc) => doc.id)).toEqual(['hub_0400']);
  });

  test('an empty hub hands the account to the newer block', () => {
    const emptyOldHub = hub('hub_0400', {block: 3, occupants: 0, classEnd: '2026-09-12T09:30:00Z'});
    const newHub = hub('hub_0630', {block: 1, occupants: 0, classEnd: '2026-09-13T00:00:00Z'});
    const chosen = _selectPrimaryActiveHub([emptyOldHub, newHub], now);
    expect(chosen.map((doc) => doc.id)).toEqual(['hub_0630']);
  });

  test('a straggler whose class is over still yields the account', () => {
    // 2026-08-21, lane 2: somebody stayed behind after their lesson and the
    // 20:00 class could not be hosted. Nobody in here is owed time, so the
    // newer block wins even though a person is present.
    const stragglerHub = hub('hub_0400', {
      block: 3,
      occupants: 1,
      classEnd: '2026-09-12T09:30:00Z',
      liveShifts: {finished_shift: [{name: 'Forgot To Leave'}]},
    });
    const newHub = hub('hub_0630', {block: 1, occupants: 0, classEnd: '2026-09-13T00:00:00Z'});
    const chosen = _selectPrimaryActiveHub([stragglerHub, newHub], now, new Set());
    expect(chosen.map((doc) => doc.id)).toEqual(['hub_0630']);
  });

  test('a dead bot cannot pin a lane with a stale head count', () => {
    // The occupancy number is whatever the bot last reported. If the bot has
    // stopped reporting, that number proves nothing and must not hold the lane.
    const staleOldHub = hub('hub_0400', {
      block: 3,
      occupants: 4,
      heartbeatAgoMs: 30 * MINUTE,
      classEnd: '2026-09-12T09:30:00Z',
    });
    const newHub = hub('hub_0630', {block: 1, occupants: 0, classEnd: '2026-09-13T00:00:00Z'});
    const chosen = _selectPrimaryActiveHub([staleOldHub, newHub], now);
    expect(chosen.map((doc) => doc.id)).toEqual(['hub_0630']);
  });

  test('one active hub is returned untouched', () => {
    const only = hub('hub_only', {block: 1, occupants: 0});
    expect(_selectPrimaryActiveHub([only], now).map((doc) => doc.id)).toEqual(['hub_only']);
  });
});
