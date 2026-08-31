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
