const mockUsers = new Map();
const mockAudits = new Map();
let mockMulticasts = [];

jest.mock('firebase-admin', () => ({
  firestore: () => ({
    collection: (name) => ({
      doc: (id) => {
        const store = name === 'teacher_audits' ? mockAudits : mockUsers;
        return {
          get: async () => ({
            exists: store.has(id),
            data: () => store.get(id),
          }),
          update: async () => {},
        };
      },
      where: () => ({limit: () => ({get: async () => ({empty: true, docs: []})})}),
    }),
  }),
  auth: () => ({
    verifyIdToken: async () => {
      throw new Error('no token');
    },
  }),
  messaging: () => ({
    sendEachForMulticast: async (message) => {
      mockMulticasts.push(message);
      return {
        successCount: message.tokens.length,
        failureCount: 0,
        responses: message.tokens.map(() => ({success: true})),
      };
    },
  }),
}));

const {sendAuditNotification} = require('../handlers/notifications');

const VALID = {teacherId: 'teacher_1', auditId: 'audit_1', yearMonth: '2026-08'};

const expectRejection = async (promise, code) => {
  await expect(promise).rejects.toMatchObject({
    code: expect.stringContaining(code),
  });
};

describe('sendAuditNotification caller identity', () => {
  beforeEach(() => {
    mockUsers.clear();
    mockAudits.clear();
    mockMulticasts = [];
    mockUsers.set('teacher_1', {fcmTokens: [{token: 'tok_1'}]});
    mockAudits.set('audit_1', {
      userId: 'teacher_1',
      coachEvaluation: {coachId: 'coach_1'},
    });
  });

  test('an unauthenticated caller gets unauthenticated, not a TypeError', async () => {
    // The v2 onCall hands the handler ONE request object, so `context` is
    // undefined; reaching into it used to throw and surface as `internal`.
    await expectRejection(sendAuditNotification({data: VALID}), 'unauthenticated');
  });

  test('reads identity from the v2 request', async () => {
    mockUsers.set('admin_1', {user_type: 'admin'});
    const result = await sendAuditNotification({
      auth: {uid: 'admin_1'},
      data: VALID,
    });
    expect(result.success).toBe(true);
    expect(mockMulticasts).toHaveLength(1);
  });

  test('still accepts the v1 (data, context) shape', async () => {
    mockUsers.set('admin_1', {user_type: 'admin'});
    const result = await sendAuditNotification(VALID, {auth: {uid: 'admin_1'}});
    expect(result.success).toBe(true);
  });

  test('the audit\'s own coach is allowed through', async () => {
    mockUsers.set('coach_1', {user_type: 'teacher'});
    const result = await sendAuditNotification({
      auth: {uid: 'coach_1'},
      data: VALID,
    });
    expect(result.success).toBe(true);
  });

  test('a teacher who is not this audit\'s coach is refused', async () => {
    mockUsers.set('teacher_2', {user_type: 'teacher'});
    await expectRejection(
      sendAuditNotification({auth: {uid: 'teacher_2'}, data: VALID}),
      'permission-denied'
    );
  });

  test('an admin teacher flag counts as admin', async () => {
    mockUsers.set('lead_1', {user_type: 'teacher', is_admin_teacher: true});
    const result = await sendAuditNotification({
      auth: {uid: 'lead_1'},
      data: VALID,
    });
    expect(result.success).toBe(true);
  });

  test('a caller with no user profile is refused', async () => {
    await expectRejection(
      sendAuditNotification({auth: {uid: 'ghost'}, data: VALID}),
      'permission-denied'
    );
  });
});
