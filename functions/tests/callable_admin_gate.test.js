const mockUsersByUid = new Map();

jest.mock('firebase-admin', () => ({
  firestore: () => ({
    collection: () => ({
      doc: (id) => ({
        get: async () => ({
          exists: mockUsersByUid.has(id),
          data: () => mockUsersByUid.get(id),
        }),
      }),
      where: () => ({
        limit: () => ({get: async () => ({empty: true, docs: []})}),
      }),
    }),
  }),
  auth: () => ({verifyIdToken: async () => { throw new Error('no token'); }}),
}));

const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');

const expectRejection = async (promise, code) => {
  await expect(promise).rejects.toMatchObject({code: expect.stringContaining(code)});
};

describe('verifyCallableCallerIsAdmin', () => {
  beforeEach(() => mockUsersByUid.clear());

  test('rejects a caller with no identity', async () => {
    await expectRejection(verifyCallableCallerIsAdmin({data: {userType: 'admin'}}), 'unauthenticated');
  });

  test('reads identity from the v2 request, not just the v1 context', async () => {
    mockUsersByUid.set('admin_1', {user_type: 'admin'});
    const result = await verifyCallableCallerIsAdmin({auth: {uid: 'admin_1'}, data: {}});
    expect(result.callerUid).toBe('admin_1');
  });

  test('still accepts the v1 (data, context) shape', async () => {
    mockUsersByUid.set('admin_1', {user_type: 'admin'});
    const result = await verifyCallableCallerIsAdmin({}, {auth: {uid: 'admin_1'}});
    expect(result.callerUid).toBe('admin_1');
  });

  test('rejects a signed-in teacher', async () => {
    mockUsersByUid.set('teacher_1', {user_type: 'teacher'});
    await expectRejection(
      verifyCallableCallerIsAdmin({auth: {uid: 'teacher_1'}, data: {}}),
      'permission-denied'
    );
  });

  test('rejects a signed-in parent asking for an admin account', async () => {
    mockUsersByUid.set('parent_1', {user_type: 'parent'});
    await expectRejection(
      verifyCallableCallerIsAdmin({auth: {uid: 'parent_1'}, data: {userType: 'admin'}}),
      'permission-denied'
    );
  });

  test('rejects a caller with no user profile', async () => {
    await expectRejection(
      verifyCallableCallerIsAdmin({auth: {uid: 'ghost'}, data: {}}),
      'permission-denied'
    );
  });

  test('accepts an admin claim on the token when no profile exists', async () => {
    const result = await verifyCallableCallerIsAdmin({
      auth: {uid: 'claims_admin', token: {admin: true, email: 'a@b.c'}},
      data: {},
    });
    expect(result.callerUid).toBe('claims_admin');
  });
});
