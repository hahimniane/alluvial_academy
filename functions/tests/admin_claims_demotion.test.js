/**
 * A person demoted on their user document loses admin custom claims too
 * (Firestore rules trust token.isAdmin / token.is_admin / an admin token.role).
 */

jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentWrittenWithAuthContext: jest.fn((_, handler) => handler),
}));

const mockRecordDecisionAudit = jest.fn(async () => {});
jest.mock('../services/decision_audit', () => ({
  recordDecisionAudit: (...args) => mockRecordDecisionAudit(...args),
}));

const mockAuth = {
  users: new Map(),
  getUser: jest.fn(async (uid) => {
    if (!mockAuth.users.has(uid)) throw Object.assign(new Error('no user'), { code: 'auth/user-not-found' });
    return { uid, customClaims: mockAuth.users.get(uid) };
  }),
  setCustomUserClaims: jest.fn(async (uid, claims) => {
    mockAuth.users.set(uid, claims);
  }),
};

jest.mock('firebase-admin', () => ({
  firestore: Object.assign(jest.fn(() => ({})), {
    FieldValue: { serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP') },
  }),
  auth: jest.fn(() => mockAuth),
}));

const {
  claimsWithoutAdmin,
  clearDemotedAdminClaims,
  demotedFromAdmin,
  isAdminFromUserData,
} = require('../services/admin_claims');
const { onUserDecisionWritten } = require('../handlers/decision_audits');

const snap = (data) => ({ exists: data !== null, data: () => data });
const event = (id, before, after) => ({
  id: `evt_${id}`,
  params: { entityId: id },
  authType: 'app_user',
  authId: 'admin_uid',
  data: { before: snap(before), after: snap(after) },
});

beforeEach(() => {
  mockAuth.users = new Map();
  mockAuth.getUser.mockClear();
  mockAuth.setCustomUserClaims.mockClear();
  mockRecordDecisionAudit.mockClear();
});

describe('admin claims on demotion', () => {
  test('who counts as an admin', () => {
    expect(isAdminFromUserData({ user_type: 'admin' })).toBe(true);
    expect(isAdminFromUserData({ user_type: 'super_admin' })).toBe(true);
    expect(isAdminFromUserData({ user_type: 'teacher', is_admin_teacher: true })).toBe(true);
    expect(isAdminFromUserData({ role: 'Admin', user_type: 'teacher' })).toBe(true);
    expect(isAdminFromUserData({ user_type: 'teacher', secondary_roles: ['admin'] })).toBe(false);
    expect(isAdminFromUserData(null)).toBe(false);
  });

  test('demotion means admin before and not after; deletes and promotions are not demotions', () => {
    expect(demotedFromAdmin({ user_type: 'admin' }, { user_type: 'teacher' })).toBe(true);
    expect(demotedFromAdmin({ user_type: 'teacher', is_admin_teacher: true }, { user_type: 'teacher', is_admin_teacher: false })).toBe(true);
    expect(demotedFromAdmin({ user_type: 'admin' }, { user_type: 'teacher', is_admin_teacher: true })).toBe(false);
    expect(demotedFromAdmin({ user_type: 'teacher' }, { user_type: 'admin' })).toBe(false);
    expect(demotedFromAdmin({ user_type: 'admin' }, null)).toBe(false);
    expect(demotedFromAdmin(null, { user_type: 'teacher' })).toBe(false);
  });

  test('claims lose every admin grant and keep the rest', () => {
    expect(claimsWithoutAdmin({ admin: true, isAdmin: true, is_admin_teacher: true, isAdminTeacher: true, plan: 'x' })).toEqual({
      changed: true,
      next: { admin: false, isAdmin: false, is_admin_teacher: false, isAdminTeacher: false, plan: 'x' },
    });
    expect(claimsWithoutAdmin({ is_admin: 'true', role: 'super_admin' })).toEqual({ changed: true, next: { is_admin: false } });
    expect(claimsWithoutAdmin({ admin: false, isAdmin: false, role: 'teacher' })).toEqual({
      changed: false,
      next: { admin: false, isAdmin: false, role: 'teacher' },
    });
    expect(claimsWithoutAdmin(undefined)).toEqual({ changed: false, next: {} });
  });

  test('clears the claims of a demoted admin, by the uid field when the doc id is not the uid', async () => {
    mockAuth.users.set('auth_uid', { admin: true, isAdmin: true });
    const r = await clearDemotedAdminClaims({
      before: { user_type: 'admin', uid: 'auth_uid' },
      after: { user_type: 'teacher', uid: 'auth_uid' },
      docId: 'legacy@example.org',
      auth: mockAuth,
    });
    expect(r).toEqual({ demoted: true, cleared: true, uid: 'auth_uid' });
    expect(mockAuth.users.get('auth_uid')).toEqual({ admin: false, isAdmin: false });
  });

  test('no claims, no Auth account or no demotion: nothing is written', async () => {
    mockAuth.users.set('u1', {});
    await clearDemotedAdminClaims({ before: { user_type: 'admin' }, after: { user_type: 'parent' }, docId: 'u1', auth: mockAuth });
    await clearDemotedAdminClaims({ before: { user_type: 'admin' }, after: { user_type: 'parent' }, docId: 'nobody', auth: mockAuth });
    await clearDemotedAdminClaims({ before: { user_type: 'teacher' }, after: { user_type: 'parent' }, docId: 'u1', auth: mockAuth });
    expect(mockAuth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  test('the users trigger clears claims on demotion and still records the decision', async () => {
    mockAuth.users.set('u2', { admin: true, isAdmin: true, is_admin_teacher: false, isAdminTeacher: false });
    await onUserDecisionWritten(event('u2', { user_type: 'admin', is_active: true }, { user_type: 'teacher', is_active: true }));
    expect(mockAuth.users.get('u2')).toEqual({ admin: false, isAdmin: false, is_admin_teacher: false, isAdminTeacher: false });
    expect(mockRecordDecisionAudit).toHaveBeenCalledWith(expect.objectContaining({ action: 'user.role_changed', entityId: 'u2' }));
  });

  test('the users trigger leaves Auth alone on ordinary writes (no extra calls on heartbeats)', async () => {
    mockAuth.users.set('u3', { admin: true });
    await onUserDecisionWritten(event('u3', { user_type: 'admin', last_seen: 1 }, { user_type: 'admin', last_seen: 2 }));
    await onUserDecisionWritten(event('u3', { user_type: 'teacher' }, { user_type: 'admin' }));
    expect(mockAuth.getUser).not.toHaveBeenCalled();
    expect(mockAuth.users.get('u3')).toEqual({ admin: true });
  });

  test('a failure clearing claims does not break the trigger', async () => {
    mockAuth.getUser.mockImplementationOnce(async () => {
      throw Object.assign(new Error('boom'), { code: 'auth/internal-error' });
    });
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    await expect(onUserDecisionWritten(event('u4', { user_type: 'admin' }, { user_type: 'student' }))).resolves.toBeUndefined();
    expect(spy).toHaveBeenCalled();
    spy.mockRestore();
  });
});
