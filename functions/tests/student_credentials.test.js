/**
 * Student passwords live in student_credentials/{uid} (admins + the student's
 * guardians only), never on the world-readable users/{uid} doc.
 *
 * Covers: easy generated passwords (D1b), createStudentAccount,
 * resetStudentPassword (incl. super admins), recordOwnStudentPassword,
 * syncAllStudentPasswords reading the store with the legacy fallback.
 */

jest.mock('firebase-functions/v2/https', () => {
  class MockHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {onCall: (fn) => fn, HttpsError: MockHttpsError};
});

const mockSentEmails = [];
jest.mock('../services/email/senders', () => ({
  sendStudentNotificationEmail: jest.fn(async (to, name, student, credentials) => {
    mockSentEmails.push({to, name, password: credentials.tempPassword});
    return true;
  }),
}));

let store;
let authUsers;

const FV = {
  serverTimestamp: () => ({__op: 'serverTimestamp'}),
  delete: () => ({__op: 'delete'}),
  arrayUnion: (...values) => ({__op: 'arrayUnion', values}),
  arrayRemove: (...values) => ({__op: 'arrayRemove', values}),
};

const applyFields = (current, data) => {
  const next = {...current};
  for (const [key, value] of Object.entries(data || {})) {
    if (value && value.__op === 'delete') delete next[key];
    else if (value && value.__op === 'serverTimestamp') next[key] = 'SERVER_TIME';
    else if (value && value.__op === 'arrayUnion') {
      const list = Array.isArray(next[key]) ? [...next[key]] : [];
      for (const v of value.values) if (!list.includes(v)) list.push(v);
      next[key] = list;
    } else next[key] = value;
  }
  return next;
};

const col = (name) => {
  if (!store[name]) store[name] = new Map();
  return store[name];
};

class DocRef {
  constructor(collection, id) {
    this.collection = collection;
    this.id = id;
  }
  async get() {
    const data = col(this.collection).get(this.id);
    return {id: this.id, exists: data !== undefined, data: () => data, ref: this};
  }
  async set(data, options) {
    const current = options && options.merge ? col(this.collection).get(this.id) || {} : {};
    col(this.collection).set(this.id, applyFields(current, data));
  }
  async update(data) {
    const current = col(this.collection).get(this.id);
    if (current === undefined) throw new Error(`missing ${this.collection}/${this.id}`);
    col(this.collection).set(this.id, applyFields(current, data));
  }
}

class Query {
  constructor(collection, filters = []) {
    this.collection = collection;
    this.filters = filters;
  }
  where(field, op, value) {
    return new Query(this.collection, [...this.filters, {field, op, value}]);
  }
  limit() {
    return this;
  }
  async get() {
    const docs = [];
    for (const [id, data] of col(this.collection).entries()) {
      const ok = this.filters.every(({field, op, value}) => {
        if (op === '==') return data[field] === value;
        if (op === 'array-contains-any') return Array.isArray(data[field]) && data[field].some((v) => value.includes(v));
        throw new Error(`op ${op}`);
      });
      if (ok) docs.push({id, exists: true, data: () => data, ref: new DocRef(this.collection, id)});
    }
    return {docs, empty: docs.length === 0, size: docs.length};
  }
}

const mockDb = {
  collection: (name) => Object.assign(new Query(name), {doc: (id) => new DocRef(name, id)}),
  batch: () => {
    const ops = [];
    return {
      set: (ref, data, options) => ops.push(() => ref.set(data, options)),
      update: (ref, data) => ops.push(() => ref.update(data)),
      delete: (ref) => ops.push(async () => col(ref.collection).delete(ref.id)),
      commit: async () => {
        for (const op of ops) await op();
      },
    };
  },
};

const notFound = () => Object.assign(new Error('not found'), {code: 'auth/user-not-found'});
const mockAuth = {
  getUser: jest.fn(async (uid) => {
    if (!authUsers.has(uid)) throw notFound();
    return authUsers.get(uid);
  }),
  getUserByEmail: jest.fn(async (email) => {
    for (const user of authUsers.values()) if (user.email === email) return user;
    throw notFound();
  }),
  updateUser: jest.fn(async (uid, updates) => {
    authUsers.set(uid, {...(authUsers.get(uid) || {uid}), ...updates});
  }),
  createUser: jest.fn(async (data) => {
    const uid = data.uid || `auth_${authUsers.size + 1}`;
    authUsers.set(uid, {...data, uid});
    return {uid};
  }),
  verifyIdToken: jest.fn(async () => {
    throw new Error('no token');
  }),
};

jest.mock('firebase-admin', () => {
  const firestore = jest.fn(() => mockDb);
  firestore.FieldValue = {
    serverTimestamp: () => ({__op: 'serverTimestamp'}),
    delete: () => ({__op: 'delete'}),
    arrayUnion: (...values) => ({__op: 'arrayUnion', values}),
    arrayRemove: (...values) => ({__op: 'arrayRemove', values}),
  };
  return {apps: [], initializeApp: jest.fn(), firestore, auth: jest.fn(() => mockAuth)};
});

const {generateEasyPassword, generateRandomPassword, EASY_WORDS} = require('../utils/password');
const {pickStoredPassword, validatePassword} = require('../services/student_credentials');
const {resetStudentPassword, recordOwnStudentPassword, syncAllStudentPasswords} = require('../handlers/password');
const {createStudentAccount} = require('../handlers/students');

const EASY = /^[a-z]+[1-9][0-9]{3}$/;

// Made-up passwords built at run time (fixtures, not credentials).
const pw = (word) => `${word}-fixture`;

beforeEach(() => {
  store = {users: new Map(), students: new Map(), student_credentials: new Map()};
  authUsers = new Map();
  mockSentEmails.length = 0;
  jest.clearAllMocks();
  void FV;
});

describe('generateEasyPassword', () => {
  test('one common word + four digits, from the crypto RNG', () => {
    const crypto = require('crypto');
    const spy = jest.spyOn(crypto, 'randomInt');
    const seen = new Set();
    for (let i = 0; i < 300; i++) {
      const pw = generateEasyPassword();
      expect(pw).toMatch(EASY);
      expect(EASY_WORDS).toContain(pw.replace(/\d+$/, ''));
      expect(pw.length).toBeGreaterThanOrEqual(6);
      seen.add(pw);
    }
    expect(spy).toHaveBeenCalled();
    expect(seen.size).toBeGreaterThan(250);
    spy.mockRestore();
  });

  test('never uses a word that overlaps the person\'s names or Student ID', () => {
    const avoid = ['Tiger', 'Sunny-Rose', 'pearl.diallo'];
    for (let i = 0; i < 2000; i++) {
      const word = generateEasyPassword({avoid}).replace(/\d+$/, '');
      expect(['tiger', 'sunny', 'sun', 'rose', 'pearl']).not.toContain(word);
      expect(word.includes('tiger') || 'sunny'.includes(word) || word.includes('rose')).toBe(false);
    }
  });

  test('accents and short name parts do not break it', () => {
    expect(generateEasyPassword({avoid: ['Ŝéku', 'Al', '', null, 'Zz-Ndiaye 李']})).toMatch(EASY);
  });

  test('the strong generator still has every character class', () => {
    for (let i = 0; i < 50; i++) {
      const pw = generateRandomPassword();
      expect(pw).toHaveLength(12);
      expect(pw).toMatch(/[a-z]/);
      expect(pw).toMatch(/[A-Z]/);
      expect(pw).toMatch(/[0-9]/);
      expect(pw).toMatch(/[!@#$%^&*]/);
    }
  });
});

describe('stored password helpers', () => {
  test('store first, legacy field second, else empty', () => {
    const doc = (data) => ({exists: data !== undefined, data: () => data});
    expect(pickStoredPassword(doc({password: pw('new')}), {temp_password: pw('old')})).toBe(pw('new'));
    expect(pickStoredPassword(doc(undefined), {temp_password: pw('old')})).toBe(pw('old'));
    expect(pickStoredPassword(doc({password: '  '}), {temp_password: pw('old')})).toBe(pw('old'));
    expect(pickStoredPassword(doc(undefined), {})).toBe('');
    expect(pickStoredPassword(undefined, {temp_password: 42})).toBe('');
  });

  test('validation matches the reset dialog', () => {
    expect(validatePassword('a'.repeat(6))).toBeNull();
    expect(validatePassword('a'.repeat(5))).toMatch(/at least 6/);
    expect(validatePassword(` ${'a'.repeat(6)}`)).toMatch(/spaces/);
    expect(validatePassword('a'.repeat(129))).toMatch(/128/);
    expect(validatePassword(undefined)).toMatch(/required/);
  });
});

const seedStudent = (over = {}) => {
  store.users.set('stu', {
    user_type: 'student',
    first_name: 'Aminata',
    last_name: 'Barry',
    student_code: 'aminata.barry',
    'e-mail': 'aminata.barry@alluwaleducationhub.org',
    temp_password: pw('legacypw'),
    guardian_ids: ['p1'],
    guardianIds: ['p2'],
    ...over,
  });
  authUsers.set('stu', {uid: 'stu', email: 'aminata.barry@alluwaleducationhub.org'});
  store.users.set('p1', {user_type: 'parent', first_name: 'Mariama', last_name: 'Barry', 'e-mail': 'm@example.org'});
  store.users.set('p2', {user_type: 'parent', first_name: 'Ousmane', last_name: 'Barry', email: 'o@example.org'});
};

describe('resetStudentPassword', () => {
  test('a super admin can reset; the password goes to the store, the legacy copy is removed', async () => {
    store.users.set('root', {user_type: 'super_admin'});
    seedStudent();
    const result = await resetStudentPassword({auth: {uid: 'root', token: {}}, data: {studentId: 'stu'}});

    expect(result.success).toBe(true);
    expect(result.newPassword).toMatch(EASY);
    expect(result.newPassword.toLowerCase()).not.toMatch(/aminata|barry/);
    expect(store.student_credentials.get('stu')).toMatchObject({password: result.newPassword, source: 'reset', updated_by: 'root'});
    expect(store.users.get('stu')).not.toHaveProperty('temp_password');
    expect(store.users.get('stu').password_reset_by).toBe('root');
    expect(authUsers.get('stu').password).toBe(result.newPassword);
  });

  test('emails guardians listed under either spelling and names them', async () => {
    store.users.set('adm', {user_type: 'admin'});
    seedStudent();
    const result = await resetStudentPassword({auth: {uid: 'adm', token: {}}, data: {studentId: 'stu', customPassword: pw('river')}});
    expect(result.emailSent).toBe(true);
    expect(result.emailedTo.sort()).toEqual(['Mariama Barry', 'Ousmane Barry']);
    expect(mockSentEmails.map((e) => e.to).sort()).toEqual(['m@example.org', 'o@example.org']);
    expect(store.student_credentials.get('stu').password).toBe(pw('river'));
  });

  test('admin-teachers can reset; teachers, parents and students cannot', async () => {
    seedStudent();
    store.users.set('at', {user_type: 'teacher', is_admin_teacher: true});
    await expect(resetStudentPassword({auth: {uid: 'at', token: {}}, data: {studentId: 'stu', sendEmailToParent: false}})).resolves.toMatchObject({success: true});
    for (const [uid, type] of [['t', 'teacher'], ['p1', 'parent'], ['s2', 'student']]) {
      store.users.set(uid, {...(store.users.get(uid) || {}), user_type: type});
      await expect(resetStudentPassword({auth: {uid, token: {}}, data: {studentId: 'stu'}})).rejects.toMatchObject({code: 'permission-denied'});
    }
  });

  test('rejects a typed password the dialog would reject, and non-students', async () => {
    store.users.set('adm', {user_type: 'admin'});
    seedStudent();
    store.users.set('tch', {user_type: 'teacher'});
    await expect(resetStudentPassword({auth: {uid: 'adm', token: {}}, data: {studentId: 'stu', customPassword: 'a'.repeat(3)}})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(resetStudentPassword({auth: {uid: 'adm', token: {}}, data: {studentId: 'tch'}})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(store.student_credentials.has('stu')).toBe(false);
    expect(store.users.get('stu').temp_password).toBe(pw('legacypw'));
  });

  test('unauthenticated callers are refused', async () => {
    await expect(resetStudentPassword({data: {studentId: 'stu'}})).rejects.toMatchObject({code: 'unauthenticated'});
  });
});

describe('recordOwnStudentPassword', () => {
  test('a student keeps their stored password in step and the legacy copy goes', async () => {
    seedStudent();
    const result = await recordOwnStudentPassword({auth: {uid: 'stu'}, data: {password: pw('mango')}});
    expect(result).toEqual({success: true, recorded: true});
    expect(store.student_credentials.get('stu')).toMatchObject({password: pw('mango'), source: 'self', updated_by: 'stu'});
    expect(store.users.get('stu')).not.toHaveProperty('temp_password');
    expect(store.users.get('stu').password_changed_by_self).toBe(true);
  });

  test('nothing is recorded for anyone who is not a student', async () => {
    store.users.set('tch', {user_type: 'teacher'});
    await expect(recordOwnStudentPassword({auth: {uid: 'tch'}, data: {password: pw('mango')}})).resolves.toEqual({success: true, recorded: false});
    expect(store.student_credentials.size).toBe(0);
  });

  test('refuses unauthenticated callers and bad passwords', async () => {
    seedStudent();
    await expect(recordOwnStudentPassword({data: {password: pw('mango')}})).rejects.toMatchObject({code: 'unauthenticated'});
    await expect(recordOwnStudentPassword({auth: {uid: 'stu'}, data: {password: '1'.repeat(3)}})).rejects.toMatchObject({code: 'invalid-argument'});
  });
});

describe('createStudentAccount', () => {
  test('stores the generated password only in student_credentials', async () => {
    store.users.set('adm', {user_type: 'admin'});
    store.users.set('p1', {user_type: 'parent', first_name: 'Mariama', last_name: 'Barry', 'e-mail': 'm@example.org'});
    const result = await createStudentAccount(
      {data: {firstName: 'Binta', lastName: 'Sow', isAdultStudent: false, guardianIds: ['p1']}},
      {auth: {uid: 'adm', token: {}}}
    );
    expect(result.success).toBe(true);
    const uid = result.studentId;
    expect(store.users.get(uid)).not.toHaveProperty('temp_password');
    expect(store.users.get(uid).created_by_uid).toBe('adm');
    const stored = store.student_credentials.get(uid);
    expect(stored).toMatchObject({source: 'created', updated_by: 'adm'});
    expect(stored.password).toMatch(EASY);
    expect(stored.password).not.toMatch(/binta|sow/);
    expect(authUsers.get(uid).password).toBe(stored.password);
    // The password never travels back to the browser that asked.
    expect(result).not.toHaveProperty('tempPassword');
    expect(JSON.stringify(result)).not.toContain(stored.password);
  });
});

describe('syncAllStudentPasswords', () => {
  test('reads the store first and falls back to the legacy field', async () => {
    store.users.set('adm', {user_type: 'admin'});
    store.users.set('a', {user_type: 'student', student_code: 'a.a', temp_password: pw('olda')});
    store.users.set('b', {user_type: 'student', student_code: 'b.b', temp_password: pw('oldb')});
    store.users.set('c', {user_type: 'student', student_code: 'c.c'});
    store.student_credentials.set('b', {password: pw('newb')});
    const result = await syncAllStudentPasswords({auth: {uid: 'adm'}, data: {dryRun: false}});
    expect(result.synced).toBe(2);
    expect(result.skipped).toBe(1);
    expect(mockAuth.updateUser).toHaveBeenCalledWith('a', {password: pw('olda')});
    expect(mockAuth.updateUser).toHaveBeenCalledWith('b', {password: pw('newb')});
  });
});
