'use strict';

/**
 * Announcement pushes: who is in the audience, which device tokens they get,
 * and that a push goes out once however often the create event fires.
 */

const admin = require('firebase-admin');
const {__test__} = require('../handlers/announcements');
const {audienceOf, rolesOfUser, isReachableUser, recipientTokens, chunksOf, pushBody, sendAnnouncementPush} = __test__;

const user = (id, data) => ({id, data: () => data});

describe('audience and roles', () => {
  test('keeps only the four known roles, lowercased and unique', () => {
    expect(audienceOf({audience: ['Teacher', 'parent', 'parent', 'circle_member', '', null]}))
      .toEqual(['teacher', 'parent']);
    expect(audienceOf({})).toEqual([]);
  });

  test('a user holds user_type and secondary_roles; super_admin and admin teachers count as admin', () => {
    expect([...rolesOfUser({user_type: 'teacher', secondary_roles: ['Parent']})].sort()).toEqual(['parent', 'teacher']);
    expect([...rolesOfUser({user_type: 'super_admin'})]).toEqual(['admin']);
    expect([...rolesOfUser({user_type: 'teacher', is_admin_teacher: true})].sort()).toEqual(['admin', 'teacher']);
  });

  test('deactivated, merged and archived accounts are not reachable', () => {
    expect(isReachableUser({})).toBe(true);
    expect(isReachableUser({is_active: true})).toBe(true);
    expect(isReachableUser({is_active: false})).toBe(false);
    expect(isReachableUser({merged_into: 'other'})).toBe(false);
    expect(isReachableUser({deactivated_at: new Date()})).toBe(false);
    expect(isReachableUser({is_archived: true})).toBe(false);
  });
});

describe('recipientTokens', () => {
  const docs = [
    user('t1', {user_type: 'teacher', fcmTokens: [{token: 'tok-t1a'}, {token: 'tok-t1b'}]}),
    user('p1', {user_type: 'parent', fcmTokens: [{token: 'tok-p1'}]}),
    user('tp', {user_type: 'teacher', secondary_roles: ['parent'], fcmTokens: [{token: 'tok-tp'}]}),
    user('s1', {user_type: 'student', fcmToken: 'tok-s1-legacy'}),
    user('off', {user_type: 'parent', is_active: false, fcmTokens: [{token: 'tok-off'}]}),
    user('none', {user_type: 'parent'}),
    // The same parent again, as returned by the secondary_roles query.
    user('p1', {user_type: 'parent', fcmTokens: [{token: 'tok-p1'}]}),
  ];

  test('parents only: primary and secondary parents, active accounts, no duplicates', () => {
    expect(recipientTokens(docs, ['parent']).sort()).toEqual(['tok-p1', 'tok-tp']);
  });

  test('teachers get every device token', () => {
    expect(recipientTokens(docs, ['teacher']).sort()).toEqual(['tok-t1a', 'tok-t1b', 'tok-tp']);
  });

  test('falls back to the legacy single token', () => {
    expect(recipientTokens(docs, ['student'])).toEqual(['tok-s1-legacy']);
  });

  test('a token shared by two accounts is sent once', () => {
    const shared = [
      user('a', {user_type: 'student', fcmTokens: [{token: 'same'}]}),
      user('b', {user_type: 'student', fcmTokens: [{token: 'same'}]}),
    ];
    expect(recipientTokens(shared, ['student'])).toEqual(['same']);
  });
});

describe('helpers', () => {
  test('chunks tokens into multicast-sized batches', () => {
    const tokens = Array.from({length: 1201}, (_, i) => `t${i}`);
    expect(chunksOf(tokens).map((chunk) => chunk.length)).toEqual([500, 500, 201]);
  });

  test('push body is one line and capped', () => {
    expect(pushBody('Line one\n\nLine two')).toBe('Line one Line two');
    expect(pushBody('x'.repeat(500))).toHaveLength(240);
  });
});

describe('sendAnnouncementPush', () => {
  beforeAll(() => {
    admin.firestore.FieldValue = {serverTimestamp: () => 'SERVER_TIMESTAMP'};
  });

  const makeDb = (announcement, users) => {
    const state = {announcement: {...announcement}, updates: []};
    const ref = {
      update: jest.fn(async (patch) => {
        state.updates.push(patch);
        Object.assign(state.announcement, patch);
      }),
    };
    const usersQuery = (field, op, values) => ({
      get: async () => ({
        docs: users.filter((entry) => {
          const data = entry.data();
          if (op === 'in') return values.includes(data[field]);
          return Array.isArray(data[field]) && data[field].some((role) => values.includes(role));
        }),
      }),
    });
    const db = {
      collection: (name) => (name === 'announcements' ?
        {doc: () => ref} :
        {where: usersQuery}),
      runTransaction: async (fn) => fn({
        get: async () => ({exists: true, data: () => state.announcement}),
        update: (_ref, patch) => Object.assign(state.announcement, patch),
      }),
    };
    return {db, state};
  };

  const users = [
    user('t1', {user_type: 'teacher', fcmTokens: [{token: 'tok-t1'}]}),
    user('p1', {user_type: 'parent', fcmTokens: [{token: 'tok-p1'}]}),
    user('tp', {user_type: 'teacher', secondary_roles: ['parent'], fcmTokens: [{token: 'tok-tp'}]}),
  ];

  test('sends to the audience once and records the counts', async () => {
    const {db, state} = makeDb({
      title: 'Bayana update', body: 'Starts Friday', audience: ['parent'],
      status: 'published', send_push: true,
    }, users);
    const messaging = {
      sendEachForMulticast: jest.fn(async ({tokens}) => ({successCount: tokens.length, failureCount: 0})),
    };

    const first = await sendAnnouncementPush({db, messaging, announcementId: 'a1'});
    expect(first).toEqual({skipped: false, tokenCount: 2, successCount: 2, failureCount: 0});
    expect(messaging.sendEachForMulticast).toHaveBeenCalledTimes(1);
    const message = messaging.sendEachForMulticast.mock.calls[0][0];
    expect(message.tokens.sort()).toEqual(['tok-p1', 'tok-tp']);
    expect(message.notification).toEqual({title: 'Bayana update', body: 'Starts Friday'});
    expect(message.data).toEqual({type: 'announcement', announcementId: 'a1'});
    expect(state.announcement.push_sent_at).toBeDefined();
    expect(state.announcement.push_success_count).toBe(2);

    const again = await sendAnnouncementPush({db, messaging, announcementId: 'a1'});
    expect(again).toEqual({skipped: true});
    expect(messaging.sendEachForMulticast).toHaveBeenCalledTimes(1);
  });

  test('does nothing when the push switch is off or the announcement is archived', async () => {
    const messaging = {sendEachForMulticast: jest.fn()};
    for (const announcement of [
      {title: 'x', audience: ['teacher'], status: 'published', send_push: false},
      {title: 'x', audience: ['teacher'], status: 'archived', send_push: true},
    ]) {
      const {db} = makeDb(announcement, users);
      expect(await sendAnnouncementPush({db, messaging, announcementId: 'a2'})).toEqual({skipped: true});
    }
    expect(messaging.sendEachForMulticast).not.toHaveBeenCalled();
  });
});
