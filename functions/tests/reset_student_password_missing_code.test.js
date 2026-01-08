/**
 * resetStudentPassword should handle legacy/bulk-created student accounts that are missing `student_code`.
 *
 * Expected behavior:
 * - Generates a unique `student_code` based on first/last name.
 * - Aligns Firebase Auth email to `{student_code}@alluwaleducationhub.org`.
 * - Stores the new password in Firestore `temp_password`.
 * - Preserves any existing Firestore email in `legacy_email`.
 */

jest.mock('firebase-functions/v2/https', () => {
  class MockHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }

  return {
    onCall: (fn) => fn,
    HttpsError: MockHttpsError,
  };
});

jest.mock('../utils/password', () => ({
  generateRandomPassword: jest.fn(() => 'RANDOM_PASS'),
}));

jest.mock('../services/email/senders', () => ({
  sendStudentNotificationEmail: jest.fn(() => Promise.resolve()),
}));

let mockStore;
let mockFirestore;
let mockAuth;

class DocSnap {
  constructor(id, data) {
    this.id = id;
    this.exists = data !== undefined;
    this._data = data;
  }
  data() {
    return this._data;
  }
}

class DocRef {
  constructor(collectionName, id) {
    this.collectionName = collectionName;
    this.id = id;
  }
  async get() {
    const data = mockStore[this.collectionName].get(this.id);
    return new DocSnap(this.id, data);
  }
  async update(updates) {
    const current = mockStore[this.collectionName].get(this.id);
    if (current === undefined) throw new Error(`Missing doc: ${this.collectionName}/${this.id}`);
    mockStore[this.collectionName].set(this.id, { ...current, ...updates });
  }
  async set(data, options) {
    const merge = !!(options && options.merge);
    const current = mockStore[this.collectionName].get(this.id);
    if (!merge || current === undefined) {
      mockStore[this.collectionName].set(this.id, { ...data });
      return;
    }
    mockStore[this.collectionName].set(this.id, { ...current, ...data });
  }
}

class QuerySnap {
  constructor(docs) {
    this.docs = docs;
    this.empty = docs.length === 0;
    this.size = docs.length;
  }
}

class Query {
  constructor(collectionName, field, value) {
    this.collectionName = collectionName;
    this.field = field;
    this.value = value;
    this._limit = null;
  }
  limit(n) {
    this._limit = n;
    return this;
  }
  async get() {
    const docs = [];
    const map = mockStore[this.collectionName];
    for (const [id, data] of map.entries()) {
      if (data && data[this.field] === this.value) {
        docs.push(new DocSnap(id, data));
      }
    }
    const sliced = this._limit != null ? docs.slice(0, this._limit) : docs;
    return new QuerySnap(sliced);
  }
}

class CollectionRef {
  constructor(name) {
    this.name = name;
  }
  doc(id) {
    return new DocRef(this.name, id);
  }
  where(field, op, value) {
    if (op !== '==') throw new Error(`Unsupported op in test: ${op}`);
    return new Query(this.name, field, value);
  }
}

jest.mock('firebase-admin', () => {
  const firestoreFn = jest.fn(() => mockFirestore);
  firestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => ({ __op: 'serverTimestamp' })),
  };
  return {
    apps: [],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
    auth: jest.fn(() => mockAuth),
  };
});

const { resetStudentPassword } = require('../handlers/password');

describe('resetStudentPassword (missing student_code)', () => {
  beforeEach(() => {
    mockStore = {
      users: new Map(),
      students: new Map(),
    };

    mockFirestore = {
      collection: (name) => new CollectionRef(name),
    };

    const authUsersByUid = new Map();
    const authUidByEmail = new Map();

    const upsertAuthUser = (uid, updates) => {
      const current = authUsersByUid.get(uid) || { uid };
      const next = { ...current, ...updates };
      authUsersByUid.set(uid, next);
      if (current.email && authUidByEmail.get(current.email) === uid) {
        authUidByEmail.delete(current.email);
      }
      if (next.email) {
        authUidByEmail.set(next.email.toLowerCase(), uid);
      }
      return next;
    };

    // Legacy/bulk-created student auth account with a real email.
    upsertAuthUser('student_uid', { email: 'kadiza98@yahoo.com' });

    mockAuth = {
      getUser: jest.fn(async (uid) => {
        const user = authUsersByUid.get(uid);
        if (!user) {
          const err = new Error('not found');
          err.code = 'auth/user-not-found';
          throw err;
        }
        return user;
      }),
      getUserByEmail: jest.fn(async (email) => {
        const uid = authUidByEmail.get(String(email).toLowerCase());
        if (!uid) {
          const err = new Error('not found');
          err.code = 'auth/user-not-found';
          throw err;
        }
        return authUsersByUid.get(uid);
      }),
      updateUser: jest.fn(async (uid, updates) => upsertAuthUser(uid, updates)),
      createUser: jest.fn(async (data) => upsertAuthUser(data.uid, data)),
    };

    // Admin caller
    mockStore.users.set('admin_uid', {
      user_type: 'admin',
      first_name: 'Admin',
      last_name: 'User',
    });

    // Student missing student_code/temp_password
    mockStore.users.set('student_uid', {
      user_type: 'student',
      first_name: 'Djenabou',
      last_name: 'Diallo',
      'e-mail': 'kadiza98@yahoo.com',
      is_adult_student: true,
      guardian_ids: [],
    });
  });

  test('generates student_code + aligns login email + stores temp_password', async () => {
    const result = await resetStudentPassword({
      auth: { uid: 'admin_uid' },
      data: {
        studentId: 'student_uid',
        sendEmailToParent: false,
        customPassword: '123456',
      },
    });

    expect(result.success).toBe(true);
    expect(result.newPassword).toBe('123456');
    expect(result.studentCode).toBe('djenabou.diallo');

    const updatedUser = mockStore.users.get('student_uid');
    expect(updatedUser.student_code).toBe('djenabou.diallo');
    expect(updatedUser.temp_password).toBe('123456');
    expect(updatedUser['e-mail']).toBe('djenabou.diallo@alluwaleducationhub.org');
    expect(updatedUser.legacy_email).toBe('kadiza98@yahoo.com');

    const authUser = await mockAuth.getUser('student_uid');
    expect(authUser.email).toBe('djenabou.diallo@alluwaleducationhub.org');
  });
});

