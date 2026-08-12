/**
 * findUserByEmailOrCode backs the "Already have a child enrolled?" box on the
 * public enrollment page.
 *
 * The case that broke in production: a parent enrols a child under their own
 * email, so `users` holds both a student doc and a parent doc with the same
 * `e-mail`. Firestore returns equality matches in document-ID order, and the
 * old code read only the first one — when the student sorted first the lookup
 * reported "No parent account found" even though the parent was right there.
 */

jest.mock('firebase-functions/v2/https', () => ({}));

jest.mock('firebase-functions', () => {
  class MockHttpsError extends Error {
    constructor(code, message, details) {
      super(message);
      this.code = code;
      this.details = details;
    }
  }
  return {
    https: { HttpsError: MockHttpsError, onCall: (fn) => fn },
  };
});

jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: () => () => {},
  onDocumentDeleted: () => () => {},
  onDocumentUpdated: () => () => {},
  onDocumentWritten: () => () => {},
}));

jest.mock('../services/email/transporter', () => ({
  createTransporter: jest.fn(() => Promise.resolve({ sendMail: jest.fn() })),
}));

let mockUsers;

// Firestore returns equality matches in document-ID order; mirror that so the
// ordering this bug depended on is actually exercised.
const mockQuery = (field, value, limit) => ({
  limit: (n) => mockQuery(field, value, n),
  get: async () => {
    const docs = [...mockUsers.entries()]
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .filter(([, data]) => data[field] === value)
      .slice(0, limit ?? Infinity)
      .map(([id, data]) => ({ id, exists: true, data: () => data }));
    return { docs, empty: docs.length === 0, size: docs.length };
  },
});

jest.mock('firebase-admin', () => ({
  apps: [{}],
  initializeApp: jest.fn(),
  firestore: () => ({
    collection: (name) => {
      if (name !== 'users') throw new Error(`unexpected collection ${name}`);
      return { where: (field, _op, value) => mockQuery(field, value) };
    },
  }),
}));

const { findUserByEmailOrCode } = require('../handlers/users');

const parentDoc = {
  'e-mail': 'nenenane2@gmail.com',
  user_type: 'parent',
  first_name: 'nene',
  last_name: 'nane',
  phone_number: '+15551234567',
  kiosk_code: 'NNPR32838561',
  children_ids: ['child1', 'child2'],
};

const childDoc = {
  'e-mail': 'nenenane2@gmail.com',
  user_type: 'student',
  first_name: 'Test',
  last_name: 'student',
};

beforeEach(() => {
  mockUsers = new Map();
});

describe('findUserByEmailOrCode', () => {
  it('links the parent when a child shares the same email and sorts first', async () => {
    // 't' < 'x', so the student doc is what Firestore hands back first.
    mockUsers.set('tphVH12F', childDoc);
    mockUsers.set('x5QIdS7c', parentDoc);

    const result = await findUserByEmailOrCode({ identifier: 'nenenane2@gmail.com' });

    expect(result).toEqual({
      found: true,
      userId: 'x5QIdS7c',
      firstName: 'nene',
      lastName: 'nane',
      email: 'nenenane2@gmail.com',
      phone: '+15551234567',
      kiosqueCode: 'NNPR32838561',
    });
  });

  it('links the parent regardless of which doc sorts first', async () => {
    mockUsers.set('aaaa0001', parentDoc);
    mockUsers.set('zzzz9999', childDoc);

    const result = await findUserByEmailOrCode({ identifier: 'nenenane2@gmail.com' });

    expect(result.found).toBe(true);
    expect(result.userId).toBe('aaaa0001');
  });

  it('uppercases and pads are tolerated on the email', async () => {
    mockUsers.set('x5QIdS7c', parentDoc);

    const result = await findUserByEmailOrCode({ identifier: '  NeneNane2@Gmail.com  ' });

    expect(result.found).toBe(true);
    expect(result.userId).toBe('x5QIdS7c');
  });

  it('finds the parent by kiosk code', async () => {
    mockUsers.set('tphVH12F', childDoc);
    mockUsers.set('x5QIdS7c', parentDoc);

    const result = await findUserByEmailOrCode({ identifier: 'NNPR32838561' });

    expect(result.found).toBe(true);
    expect(result.userId).toBe('x5QIdS7c');
  });

  it('reports not found when only a student matches', async () => {
    mockUsers.set('tphVH12F', childDoc);

    expect(await findUserByEmailOrCode({ identifier: 'nenenane2@gmail.com' }))
      .toEqual({ found: false });
  });

  it('reports not found for a parent with no children yet', async () => {
    mockUsers.set('p1', { ...parentDoc, children_ids: [] });

    expect(await findUserByEmailOrCode({ identifier: 'nenenane2@gmail.com' }))
      .toEqual({ found: false });
  });

  it('reports not found for an unknown identifier', async () => {
    mockUsers.set('x5QIdS7c', parentDoc);

    expect(await findUserByEmailOrCode({ identifier: 'nobody@example.com' }))
      .toEqual({ found: false });
  });

  it('rejects an empty identifier', async () => {
    await expect(findUserByEmailOrCode({ identifier: '   ' })).rejects.toThrow();
  });

  it('accepts the callable wrapper shape', async () => {
    mockUsers.set('x5QIdS7c', parentDoc);

    const result = await findUserByEmailOrCode({ data: { identifier: 'nenenane2@gmail.com' } });

    expect(result.found).toBe(true);
  });
});
