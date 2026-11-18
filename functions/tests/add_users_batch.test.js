/**
 * Add users (admin Users page, slice C): createMultipleUsers works for 2+
 * people of any mix, reports every row by index, never returns a password;
 * createUserWithEmail saves the hourly rate; createStudentAccount refuses a
 * name with no Latin letters and mirrors its Student ID rules.
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

const mockWelcome = [];
const mockStudentMail = [];
jest.mock('../services/email/senders', () => ({
  sendWelcomeEmail: jest.fn(async (email, first, last, password, type, familyCode) => {
    mockWelcome.push({email, type, familyCode, password});
    return true;
  }),
  sendStudentNotificationEmail: jest.fn(async (to) => {
    mockStudentMail.push(to);
    return true;
  }),
}));

let store;
let authUsers;

const applyFields = (current, data) => {
  const next = {...current};
  for (const [key, value] of Object.entries(data || {})) {
    if (value && value.__op === 'serverTimestamp') next[key] = 'SERVER_TIME';
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
      commit: async () => {
        for (const op of ops) await op();
      },
    };
  },
};

const notFound = () => Object.assign(new Error('not found'), {code: 'auth/user-not-found'});
const mockAuth = {
  getUserByEmail: jest.fn(async (email) => {
    for (const user of authUsers.values()) if (user.email === email) return user;
    throw notFound();
  }),
  createUser: jest.fn(async (data) => {
    for (const user of authUsers.values()) {
      if (user.email === data.email) {
        throw Object.assign(new Error('The email address is already in use by another account.'), {code: 'auth/email-already-exists'});
      }
    }
    if (!/^[^@\s]+@[^@\s]+$/.test(data.email) || /^\.|\.@/.test(data.email)) {
      throw Object.assign(new Error('The email address is improperly formatted.'), {code: 'auth/invalid-email'});
    }
    const uid = `auth_${authUsers.size + 1}`;
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
    arrayUnion: (...values) => ({__op: 'arrayUnion', values}),
  };
  return {apps: [], initializeApp: jest.fn(), firestore, auth: jest.fn(() => mockAuth)};
});

const {createMultipleUsers, createUserWithEmail, MAX_BATCH_USERS} = require('../handlers/users');
const {createStudentAccount, generateStudentCode} = require('../handlers/students');

// A v2 callable request: `rawRequest` is circular, as Express requests are.
const asAdmin = (data, uid = 'adm') => {
  const rawRequest = {headers: {authorization: 'Bearer x'}};
  rawRequest.self = rawRequest;
  return {auth: {uid, token: {}}, data, rawRequest};
};

const teacherRow = (over = {}) => ({
  email: 'nafi.bah@example.org',
  firstName: 'Nafissatou',
  lastName: 'Bah',
  userType: 'teacher',
  title: 'Teacher',
  kioskCode: 'NBTC04712345',
  phoneNumber: '+224621000001',
  countryCode: '+224',
  hourlyRate: '5.50',
  ...over,
});

beforeEach(() => {
  store = {users: new Map(), students: new Map(), student_credentials: new Map()};
  authUsers = new Map();
  mockWelcome.length = 0;
  mockStudentMail.length = 0;
  jest.clearAllMocks();
  store.users.set('adm', {user_type: 'admin'});
  store.users.set('p1', {user_type: 'parent', first_name: 'Mariama', last_name: 'Barry', 'e-mail': 'mariama@example.org', kiosk_code: 'MBPR00112345'});
});

const profileByEmail = (email) => [...store.users.values()].find((u) => u['e-mail'] === email);

describe('createMultipleUsers', () => {
  test('a mixed batch creates every row and reports each by index', async () => {
    const result = await createMultipleUsers(asAdmin({
      users: [
        teacherRow(),
        {email: 'kadi.sow@example.org', firstName: 'Kadiatou', lastName: 'Sow', userType: 'parent', title: 'Parent', kioskCode: 'KSPR01212345'},
        {firstName: 'Alpha', lastName: 'Barry', userType: 'student', isAdultStudent: false, guardianIds: ['p1'], phoneNumber: ''},
        {email: 'oumar@example.org', firstName: 'Oumar', lastName: 'Diallo', userType: 'student', isAdultStudent: true},
      ],
    }));
    expect(result).toMatchObject({totalUsers: 4, successful: 4, failed: 0});
    expect(result.results.map((r) => r.index)).toEqual([0, 1, 2, 3]);

    const teacher = profileByEmail('nafi.bah@example.org');
    expect(teacher).toMatchObject({user_type: 'teacher', hourly_rate: 5.5, kiosk_code: 'NBTC04712345', created_by_uid: 'adm'});

    const parent = profileByEmail('kadi.sow@example.org');
    expect(parent.kiosque_code).toMatch(/^[A-Z0-9]{6}$/);
    expect(parent).not.toHaveProperty('hourly_rate');
    expect(mockWelcome.find((m) => m.email === 'kadi.sow@example.org').familyCode).toBe(parent.kiosque_code);

    expect(result.results[2].result).toMatchObject({studentCode: 'alpha.barry', aliasEmail: 'alpha.barry@alluwaleducationhub.org'});
    expect(store.users.get('p1').children_ids).toEqual([result.results[2].result.studentId]);
    expect(mockStudentMail).toEqual(['mariama@example.org']);
    expect(result.results[3].result).toMatchObject({studentCode: 'oumar.diallo', isAdultStudent: true, emailsToGuardians: 0});
    expect(store.users.get(result.results[3].result.studentId).created_by_uid).toBe('adm');
  });

  test('never returns a password', async () => {
    const result = await createMultipleUsers(asAdmin({
      users: [teacherRow(), {firstName: 'Alpha', lastName: 'Barry', userType: 'student', isAdultStudent: false, guardianIds: ['p1']}],
    }));
    const text = JSON.stringify(result);
    for (const cred of store.student_credentials.values()) expect(text).not.toContain(cred.password);
    for (const mail of mockWelcome) expect(text).not.toContain(mail.password);
    expect(text).not.toMatch(/tempPassword|password"/i);
  });

  test('one bad row among good rows: the others are created, the bad one is reported by index', async () => {
    const result = await createMultipleUsers(asAdmin({
      users: [
        teacherRow(),
        teacherRow({email: '', firstName: 'No', lastName: 'Email'}),
        teacherRow({email: 'third@example.org', firstName: 'Third', lastName: 'Person'}),
      ],
    }));
    expect(result).toMatchObject({successful: 2, failed: 1});
    expect(result.errors).toEqual([expect.objectContaining({index: 1, success: false, error: 'Missing required fields: email'})]);
    expect(result.results.map((r) => r.index)).toEqual([0, 2]);
  });

  test('the same email twice in one batch: the second row fails, the first stands', async () => {
    const result = await createMultipleUsers(asAdmin({users: [teacherRow(), teacherRow({firstName: 'Other'})]}));
    expect(result.successful).toBe(1);
    expect(result.errors[0]).toMatchObject({index: 1, error: 'The email address is already in use by another account.'});
  });

  test('an email that already has an account fails that row only', async () => {
    authUsers.set('old', {uid: 'old', email: 'nafi.bah@example.org'});
    const result = await createMultipleUsers(asAdmin({
      users: [teacherRow(), teacherRow({email: 'new@example.org'})],
    }));
    expect(result.errors.map((e) => e.index)).toEqual([0]);
    expect(result.results.map((r) => r.index)).toEqual([1]);
  });

  test('two students with the same name get first.last then 1first.last, as the preview predicts', async () => {
    const row = {firstName: 'Aïcha', lastName: "N'Diaye", userType: 'student', isAdultStudent: true};
    const result = await createMultipleUsers(asAdmin({users: [row, {...row}]}));
    expect(result.results.map((r) => r.result.studentCode)).toEqual(['acha.ndiaye', '1acha.ndiaye']);
  });

  test('a minor with no parent is refused; the rest of the batch goes on', async () => {
    const result = await createMultipleUsers(asAdmin({
      users: [{firstName: 'Alpha', lastName: 'Barry', userType: 'student', isAdultStudent: false}, teacherRow()],
    }));
    expect(result.errors).toEqual([expect.objectContaining({index: 0, error: 'A minor student needs a parent or guardian.'})]);
    expect(result.successful).toBe(1);
  });

  test("a child the parent already has is reported as existing, not created again", async () => {
    store.users.set('kid', {user_type: 'student', first_name: 'Alpha', last_name: 'Barry', guardian_ids: ['p1'], student_code: 'alpha.barry', is_active: true});
    const result = await createMultipleUsers(asAdmin({
      users: [{firstName: 'alpha', lastName: 'BARRY', userType: 'student', isAdultStudent: false, guardianIds: ['p1']}, teacherRow()],
    }));
    expect(result.results[0]).toMatchObject({index: 0, existing: true, result: {studentId: 'kid', studentCode: 'alpha.barry'}});
    expect(mockAuth.createUser).toHaveBeenCalledTimes(1);
  });

  test('a non-admin or a signed-out caller is refused before anything is created', async () => {
    store.users.set('t1', {user_type: 'teacher'});
    await expect(createMultipleUsers(asAdmin({users: [teacherRow(), teacherRow()]}, 't1'))).rejects.toMatchObject({code: 'permission-denied'});
    await expect(createMultipleUsers({data: {users: [teacherRow()]}})).rejects.toMatchObject({code: 'unauthenticated'});
    expect(mockAuth.createUser).not.toHaveBeenCalled();
  });

  test(`more than ${MAX_BATCH_USERS} rows is refused`, async () => {
    const users = Array.from({length: MAX_BATCH_USERS + 1}, (_, i) => teacherRow({email: `t${i}@example.org`}));
    await expect(createMultipleUsers(asAdmin({users}))).rejects.toMatchObject({code: 'invalid-argument'});
    expect(mockAuth.createUser).not.toHaveBeenCalled();
  });

  test('an empty or missing users array is refused', async () => {
    await expect(createMultipleUsers(asAdmin({users: []}))).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(createMultipleUsers(asAdmin({}))).rejects.toMatchObject({code: 'invalid-argument'});
  });
});

describe('createUserWithEmail', () => {
  test('saves the hourly rate of a teacher', async () => {
    const result = await createUserWithEmail(asAdmin(teacherRow({hourlyRate: 4})));
    expect(result).toMatchObject({success: true, emailSent: true});
    expect(store.users.get(result.uid)).toMatchObject({hourly_rate: 4, user_type: 'teacher'});
  });

  test('no rate typed: no hourly_rate field', async () => {
    const result = await createUserWithEmail(asAdmin(teacherRow({hourlyRate: ''})));
    expect(store.users.get(result.uid)).not.toHaveProperty('hourly_rate');
  });

  test('a parent never gets a rate, and gets a family code', async () => {
    const result = await createUserWithEmail(asAdmin(teacherRow({userType: 'parent', title: 'Parent', hourlyRate: 9})));
    expect(store.users.get(result.uid)).not.toHaveProperty('hourly_rate');
    expect(store.users.get(result.uid).kiosque_code).toMatch(/^[A-Z0-9]{6}$/);
  });

  test('a rate that is not a number is refused before any account is made', async () => {
    await expect(createUserWithEmail(asAdmin(teacherRow({hourlyRate: 'abc'})))).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(createUserWithEmail(asAdmin(teacherRow({hourlyRate: -1})))).rejects.toMatchObject({code: 'invalid-argument'});
    expect(mockAuth.createUser).not.toHaveBeenCalled();
  });

  test('a teacher caller is refused', async () => {
    store.users.set('t1', {user_type: 'teacher'});
    await expect(createUserWithEmail(asAdmin(teacherRow({userType: 'admin'}), 't1'))).rejects.toMatchObject({code: 'permission-denied'});
  });
});

describe('createStudentAccount', () => {
  test('the Student ID keeps only a-z and 0-9 of each name, ten at most', () => {
    expect(generateStudentCode('Aïcha', 'Bâ')).toBe('acha.b');
    expect(generateStudentCode("N'Diaye", 'Mary Ann')).toBe('ndiaye.maryann');
    expect(generateStudentCode('Abdoul-Aziz', 'Diallo')).toBe('abdoulaziz.diallo');
    expect(generateStudentCode('Mohamedabdoulaye', 'X')).toBe('mohamedabd.x');
  });

  test('a name with no Latin letters is refused with a reason, before any account is made', async () => {
    await expect(createStudentAccount(asAdmin({firstName: 'محمد', lastName: 'Diallo', isAdultStudent: true}))).rejects.toMatchObject({
      code: 'invalid-argument',
      message: expect.stringContaining('Latin letters'),
    });
    expect(mockAuth.createUser).not.toHaveBeenCalled();
  });

  test('a non-admin caller is refused', async () => {
    store.users.set('s1', {user_type: 'student'});
    await expect(createStudentAccount(asAdmin({firstName: 'A', lastName: 'B', isAdultStudent: true}, 's1'))).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('an adult student: no guardian, nobody emailed, and the result says so', async () => {
    const result = await createStudentAccount(asAdmin({firstName: 'Oumar', lastName: 'Diallo', isAdultStudent: true, email: 'oumar@example.org'}));
    expect(result).toMatchObject({studentCode: 'oumar.diallo', emailsToGuardians: 0, emailsSent: 0});
    expect(mockStudentMail).toEqual([]);
    expect(result).not.toHaveProperty('tempPassword');
  });
});
