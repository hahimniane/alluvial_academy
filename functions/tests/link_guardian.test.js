/**
 * linkGuardianToStudent: the server-side link (admin Users page, Q12).
 *
 * - Admins and admin-teachers only.
 * - Writes both sides, both spellings when the legacy field exists.
 * - A second guardian is allowed; an existing link is not duplicated.
 * - A one-sided link is repaired.
 * - Writes a guardian_link_history row (none when nothing changed).
 * - Unlink then removes both sides again.
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
}));

jest.mock('../services/email/transporter', () => ({
  createTransporter: jest.fn(() => Promise.resolve({ sendMail: jest.fn() })),
}));

let mockStore;

// --- FieldValue sentinels ---
const FieldValue = {
  serverTimestamp: () => ({ __op: 'serverTimestamp' }),
  delete: () => ({ __op: 'delete' }),
  arrayRemove: (...els) => ({ __op: 'arrayRemove', elements: els }),
  arrayUnion: (...els) => ({ __op: 'arrayUnion', elements: els }),
};

const isSentinel = (v) => v && typeof v === 'object' && typeof v.__op === 'string';
const isPlainObject = (v) =>
  v && typeof v === 'object' && !Array.isArray(v) && !isSentinel(v);

// Apply a Firestore-style merge of `update` into `base`, honoring sentinels.
function applyMerge(base, update) {
  const out = { ...(base || {}) };
  for (const [key, value] of Object.entries(update)) {
    if (isSentinel(value)) {
      if (value.__op === 'delete') {
        delete out[key];
      } else if (value.__op === 'serverTimestamp') {
        out[key] = 1234567890;
      } else if (value.__op === 'arrayRemove') {
        const arr = Array.isArray(out[key]) ? out[key] : [];
        out[key] = arr.filter((x) => !value.elements.includes(x));
      } else if (value.__op === 'arrayUnion') {
        const arr = Array.isArray(out[key]) ? out[key] : [];
        out[key] = [...arr, ...value.elements.filter((x) => !arr.includes(x))];
      }
    } else if (isPlainObject(value)) {
      out[key] = applyMerge(out[key] || {}, value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

function getPath(data, path) {
  return path.split('.').reduce((acc, k) => (acc == null ? acc : acc[k]), data);
}

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
    return new DocSnap(this.id, mockStore[this.collectionName].get(this.id));
  }
  _applySet(data, options) {
    const merge = !!(options && options.merge);
    const current = mockStore[this.collectionName].get(this.id);
    if (!merge || current === undefined) {
      mockStore[this.collectionName].set(this.id, applyMerge({}, data));
    } else {
      mockStore[this.collectionName].set(this.id, applyMerge(current, data));
    }
  }
  async set(data, options) {
    this._applySet(data, options);
  }
  _applyUpdate(data) {
    const current = mockStore[this.collectionName].get(this.id);
    if (current === undefined) throw Object.assign(new Error('NOT_FOUND'), { code: 5 });
    // update() replaces each named field; sentinels still apply.
    const out = { ...current };
    for (const [key, value] of Object.entries(data)) {
      Object.assign(out, applyMerge({ [key]: current[key] }, { [key]: value }));
      if (isPlainObject(value)) out[key] = applyMerge({}, value);
    }
    mockStore[this.collectionName].set(this.id, out);
  }
  async update(data) {
    this._applyUpdate(data);
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
  }
  limit() {
    return this;
  }
  async get() {
    const docs = [];
    for (const [id, data] of mockStore[this.collectionName].entries()) {
      if (getPath(data, this.field) === this.value) {
        docs.push(Object.assign(new DocSnap(id, data), {
          ref: new DocRef(this.collectionName, id),
        }));
      }
    }
    return new QuerySnap(docs);
  }
}

class CollectionRef {
  constructor(name) {
    this.name = name;
  }
  doc(id) {
    return new DocRef(this.name, id || `auto_${Math.random().toString(36).slice(2)}`);
  }
  where(field, op, value) {
    return new Query(this.name, field, value);
  }
  async add(data) {
    const id = `auto_${Math.random().toString(36).slice(2)}`;
    mockStore[this.name].set(id, applyMerge({}, data));
    return new DocRef(this.name, id);
  }
}

function makeBatch() {
  const ops = [];
  return {
    set(ref, data, options) {
      ops.push(() => ref._applySet(data, options));
    },
    async commit() {
      ops.forEach((op) => op());
    },
  };
}

const mockFirestore = {
  collection: (name) => {
    if (!mockStore[name]) mockStore[name] = new Map();
    return new CollectionRef(name);
  },
  batch: makeBatch,
  async runTransaction(fn) {
    const writes = [];
    const tx = {
      get: (ref) => ref.get(),
      update: (ref, data) => writes.push(() => ref._applyUpdate(data)),
    };
    const result = await fn(tx);
    writes.forEach((w) => w());
    return result;
  },
};

jest.mock('firebase-admin', () => {
  const firestoreFn = jest.fn(() => mockFirestore);
  firestoreFn.FieldValue = FieldValue;
  return {
    apps: [],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
    auth: jest.fn(() => ({})),
  };
});

const { linkGuardianToStudent, unlinkGuardianFromStudent } = require('../handlers/enrollments');

const call = (fn, uid, data) => fn({ auth: { uid }, data });
const history = () => Array.from(mockStore.guardian_link_history.values());

describe('linkGuardianToStudent', () => {
  beforeEach(() => {
    mockStore = {
      users: new Map(),
      enrollments: new Map(),
      guardian_link_history: new Map(),
    };
    mockStore.users.set('admin_uid', { user_type: 'admin' });
    mockStore.users.set('admin_teacher_uid', { user_type: 'teacher', is_admin_teacher: true });
    mockStore.users.set('teacher_uid', { user_type: 'teacher' });
    mockStore.users.set('parent_self', { user_type: 'parent', children_ids: [] });
    mockStore.users.set('student_1', {
      user_type: 'student',
      first_name: "N'Famara",
      last_name: 'Condé',
      guardian_ids: ['parent_1'],
    });
    mockStore.users.set('parent_1', { user_type: 'parent', first_name: 'Omar', children_ids: ['student_1'] });
    mockStore.users.set('parent_2', { user_type: 'parent', first_name: 'Awa', last_name: 'Bah' });
  });

  test('links a second guardian on both sides and records it', async () => {
    const result = await call(linkGuardianToStudent, 'admin_uid', { studentUid: 'student_1', parentUid: 'parent_2' });
    expect(result).toMatchObject({ success: true, alreadyLinked: false, repaired: false, guardianCount: 2 });
    expect(mockStore.users.get('student_1').guardian_ids).toEqual(['parent_1', 'parent_2']);
    expect(mockStore.users.get('student_1').guardianIds).toBeUndefined();
    expect(mockStore.users.get('parent_2').children_ids).toEqual(['student_1']);
    expect(mockStore.users.get('parent_2').childrenIds).toBeUndefined();
    expect(history()).toHaveLength(1);
    expect(history()[0]).toMatchObject({
      action: 'link',
      studentUid: 'student_1',
      parentUid: 'parent_2',
      performedBy: 'admin_uid',
      repairedOneSidedLink: false,
      studentName: "N'Famara Condé",
      parentName: 'Awa Bah',
    });
  });

  test('a pair linked on both sides is left alone (no duplicate, no history row)', async () => {
    const before = JSON.stringify(mockStore.users.get('student_1'));
    const result = await call(linkGuardianToStudent, 'admin_uid', { studentUid: 'student_1', parentUid: 'parent_1' });
    expect(result).toMatchObject({ success: true, alreadyLinked: true, repaired: false, guardianCount: 1 });
    expect(JSON.stringify(mockStore.users.get('student_1'))).toBe(before);
    expect(mockStore.users.get('parent_1').children_ids).toEqual(['student_1']);
    expect(history()).toHaveLength(0);
  });

  test('repairs a link the parent has but the student does not', async () => {
    mockStore.users.set('student_2', { user_type: 'student', guardian_ids: [] });
    mockStore.users.set('parent_3', { user_type: 'parent', children_ids: ['student_2'], childrenIds: ['student_2'] });
    const result = await call(linkGuardianToStudent, 'admin_uid', { studentUid: 'student_2', parentUid: 'parent_3' });
    expect(result).toMatchObject({ alreadyLinked: false, repaired: true });
    expect(mockStore.users.get('student_2').guardian_ids).toEqual(['parent_3']);
    expect(mockStore.users.get('parent_3').children_ids).toEqual(['student_2']);
    expect(mockStore.users.get('parent_3').childrenIds).toEqual(['student_2']);
    expect(history()[0]).toMatchObject({ action: 'link', repairedOneSidedLink: true });
  });

  test('repairs a link the student has but the parent does not, legacy spellings too', async () => {
    mockStore.users.set('student_3', { user_type: 'student', guardianIds: ['parent_4'] });
    mockStore.users.set('parent_4', { user_type: 'parent', childrenIds: [] });
    const result = await call(linkGuardianToStudent, 'admin_uid', { studentUid: 'student_3', parentUid: 'parent_4' });
    expect(result).toMatchObject({ alreadyLinked: false, repaired: true });
    expect(mockStore.users.get('student_3')).toMatchObject({ guardian_ids: ['parent_4'], guardianIds: ['parent_4'] });
    expect(mockStore.users.get('parent_4')).toMatchObject({ children_ids: ['student_3'], childrenIds: ['student_3'] });
  });

  test('admin-teachers can link', async () => {
    const result = await call(linkGuardianToStudent, 'admin_teacher_uid', { studentUid: 'student_1', parentUid: 'parent_2' });
    expect(result.success).toBe(true);
    expect(history()[0].performedBy).toBe('admin_teacher_uid');
  });

  test('teachers, parents and signed-out callers are refused and nothing changes', async () => {
    await expect(call(linkGuardianToStudent, 'teacher_uid', { studentUid: 'student_1', parentUid: 'parent_2' })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(call(linkGuardianToStudent, 'parent_self', { studentUid: 'student_1', parentUid: 'parent_self' })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(linkGuardianToStudent({ data: { studentUid: 'student_1', parentUid: 'parent_2' } })).rejects.toMatchObject({ code: 'unauthenticated' });
    expect(mockStore.users.get('student_1').guardian_ids).toEqual(['parent_1']);
    expect(history()).toHaveLength(0);
  });

  test('refuses wrong account types and missing accounts', async () => {
    mockStore.users.set('teacher_2', { user_type: 'teacher', secondary_roles: ['parent'] });
    await expect(call(linkGuardianToStudent, 'admin_uid', { studentUid: 'student_1', parentUid: 'teacher_2' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(call(linkGuardianToStudent, 'admin_uid', { studentUid: 'parent_2', parentUid: 'parent_1' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(call(linkGuardianToStudent, 'admin_uid', { studentUid: 'ghost', parentUid: 'parent_1' })).rejects.toMatchObject({ code: 'not-found' });
    await expect(call(linkGuardianToStudent, 'admin_uid', { studentUid: 'student_1', parentUid: 'ghost' })).rejects.toMatchObject({ code: 'not-found' });
    await expect(call(linkGuardianToStudent, 'admin_uid', { studentUid: 'student_1', parentUid: 'student_1' })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(call(linkGuardianToStudent, 'admin_uid', { studentUid: '', parentUid: 'parent_1' })).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  test('link then unlink leaves both sides clean', async () => {
    await call(linkGuardianToStudent, 'admin_uid', { studentUid: 'student_1', parentUid: 'parent_2' });
    await call(unlinkGuardianFromStudent, 'admin_teacher_uid', { studentUid: 'student_1', parentUid: 'parent_2' });
    expect(mockStore.users.get('student_1').guardian_ids).toEqual(['parent_1']);
    expect(mockStore.users.get('parent_2').children_ids).toEqual([]);
    expect(history().map((h) => h.action)).toEqual(['link', 'unlink']);
  });
});
