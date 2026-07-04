/**
 * unlinkGuardianFromStudent severs the two-sided parent/student link.
 *
 * Expected behavior:
 * - Admin-only.
 * - Removes parentUid from the student's guardian_ids (and legacy guardianIds).
 * - Removes studentUid from the parent's children_ids.
 * - Marks the matching enrollment as 'unlinked'.
 * - Writes a guardian_link_history audit entry.
 * - Rejects when the pair is not actually linked.
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

const { unlinkGuardianFromStudent } = require('../handlers/enrollments');

describe('unlinkGuardianFromStudent', () => {
  beforeEach(() => {
    mockStore = {
      users: new Map(),
      enrollments: new Map(),
      guardian_link_history: new Map(),
    };

    mockStore.users.set('admin_uid', { user_type: 'admin' });
    mockStore.users.set('student_1', {
      user_type: 'student',
      first_name: 'Aisha',
      last_name: 'Diallo',
      guardian_ids: ['parent_1', 'parent_2'],
      guardianIds: ['parent_1'],
    });
    mockStore.users.set('parent_1', {
      user_type: 'parent',
      first_name: 'Omar',
      last_name: 'Diallo',
      children_ids: ['student_1', 'student_9'],
    });
    mockStore.users.set('parent_2', {
      user_type: 'parent',
      children_ids: ['student_1'],
    });
    mockStore.enrollments.set('enr_1', {
      contact: { guardianId: 'parent_1' },
      metadata: { parentUserId: 'parent_1', studentUserId: 'student_1' },
    });
  });

  test('unlinks parent from student on both sides + enrollment + audit', async () => {
    const result = await unlinkGuardianFromStudent({
      auth: { uid: 'admin_uid' },
      data: { studentUid: 'student_1', parentUid: 'parent_1', reason: 'Wrong family' },
    });

    expect(result.success).toBe(true);
    expect(result.enrollmentsTouched).toBe(1);
    expect(result.remainingGuardianCount).toBe(1);

    const student = mockStore.users.get('student_1');
    expect(student.guardian_ids).toEqual(['parent_2']);
    expect(student.guardianIds).toEqual([]);

    const parent = mockStore.users.get('parent_1');
    expect(parent.children_ids).toEqual(['student_9']);

    const enrollment = mockStore.enrollments.get('enr_1');
    expect(enrollment.metadata.parentInviteStatus).toBe('unlinked');
    expect(enrollment.contact.guardianId).toBeUndefined();

    const audits = Array.from(mockStore.guardian_link_history.values());
    expect(audits).toHaveLength(1);
    expect(audits[0]).toMatchObject({
      action: 'unlink',
      studentUid: 'student_1',
      parentUid: 'parent_1',
      reason: 'Wrong family',
      performedBy: 'admin_uid',
    });
  });

  test('rejects a non-admin caller', async () => {
    mockStore.users.set('teacher_uid', { user_type: 'teacher' });
    await expect(
      unlinkGuardianFromStudent({
        auth: { uid: 'teacher_uid' },
        data: { studentUid: 'student_1', parentUid: 'parent_1' },
      }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  test('rejects when the pair is not linked', async () => {
    await expect(
      unlinkGuardianFromStudent({
        auth: { uid: 'admin_uid' },
        data: { studentUid: 'student_1', parentUid: 'parent_unrelated' },
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  test('blocks unlinking the only guardian of a minor student', async () => {
    mockStore.users.set('minor_1', {
      user_type: 'student',
      first_name: 'Bilal',
      last_name: 'Sow',
      guardian_ids: ['parent_1'],
    });

    await expect(
      unlinkGuardianFromStudent({
        auth: { uid: 'admin_uid' },
        data: { studentUid: 'minor_1', parentUid: 'parent_1' },
      }),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      details: { reason: 'last_guardian_minor' },
    });

    // The link must be untouched after a blocked attempt.
    expect(mockStore.users.get('minor_1').guardian_ids).toEqual(['parent_1']);
  });

  test('allows unlinking the only guardian of an adult student', async () => {
    mockStore.users.set('adult_1', {
      user_type: 'student',
      is_adult_student: true,
      first_name: 'Fatima',
      last_name: 'Ba',
      guardian_ids: ['parent_1'],
    });

    const result = await unlinkGuardianFromStudent({
      auth: { uid: 'admin_uid' },
      data: { studentUid: 'adult_1', parentUid: 'parent_1' },
    });

    expect(result.success).toBe(true);
    expect(result.remainingGuardianCount).toBe(0);
    expect(mockStore.users.get('adult_1').guardian_ids).toEqual([]);
  });
});
