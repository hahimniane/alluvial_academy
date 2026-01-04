/**
 * Tests for deleteUserAccount optional class cleanup.
 *
 * Safety requirement:
 * - When deleting a student, do NOT delete shifts that also contain other students.
 *   Instead, remove the student from the shift.
 * - When deleting a teacher, delete only shifts where that teacher is the assigned teacher.
 */

let store;
let mockDb;
let mockAuthApi;

class DocRef {
  constructor(collectionName, id) {
    this.collectionName = collectionName;
    this.id = id;
  }

  get path() {
    return `${this.collectionName}/${this.id}`;
  }

  async get() {
    const data = store[this.collectionName]?.get(this.id);
    return new DocSnap(this, data);
  }
}

class DocSnap {
  constructor(ref, data) {
    this.ref = ref;
    this.id = ref.id;
    this.exists = data !== undefined;
    this._data = data;
  }

  data() {
    return this._data;
  }
}

class QuerySnap {
  constructor(docs) {
    this.docs = docs;
    this.size = docs.length;
    this.empty = docs.length === 0;
  }
}

class Query {
  constructor(collectionName, filters = [], limitCount = null) {
    this.collectionName = collectionName;
    this.filters = filters;
    this.limitCount = limitCount;
  }

  where(field, op, value) {
    return new Query(this.collectionName, [...this.filters, { field, op, value }], this.limitCount);
  }

  limit(n) {
    return new Query(this.collectionName, this.filters, n);
  }

  async get() {
    const docsMap = store[this.collectionName] || new Map();
    const results = [];

    for (const [id, data] of docsMap.entries()) {
      let matches = true;
      for (const f of this.filters) {
        const actual = data?.[f.field];
        if (f.op === '==') {
          matches = actual === f.value;
        } else if (f.op === 'array-contains') {
          matches = Array.isArray(actual) && actual.includes(f.value);
        } else {
          throw new Error(`Unsupported op in test mock: ${f.op}`);
        }
        if (!matches) break;
      }

      if (matches) {
        results.push(new DocSnap(new DocRef(this.collectionName, id), data));
      }
    }

    if (this.limitCount != null) {
      return new QuerySnap(results.slice(0, this.limitCount));
    }
    return new QuerySnap(results);
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
    return new Query(this.name).where(field, op, value);
  }

  async get() {
    return new Query(this.name).get();
  }
}

class WriteBatch {
  constructor() {
    this.ops = [];
  }

  delete(ref) {
    this.ops.push({ type: 'delete', ref });
  }

  update(ref, data) {
    this.ops.push({ type: 'update', ref, data });
  }

  async commit() {
    for (const op of this.ops) {
      const collection = store[op.ref.collectionName];
      if (!collection) continue;

      if (op.type === 'delete') {
        collection.delete(op.ref.id);
        continue;
      }

      if (op.type === 'update') {
        const current = collection.get(op.ref.id);
        if (current === undefined) {
          throw new Error(`Cannot update missing doc in test mock: ${op.ref.path}`);
        }

        const next = { ...current };
        for (const [key, value] of Object.entries(op.data || {})) {
          if (value && value.__op === 'serverTimestamp') {
            next[key] = new Date();
          } else if (value && value.__op === 'delete') {
            delete next[key];
          } else if (value && value.__op === 'arrayRemove') {
            const existing = Array.isArray(next[key]) ? next[key] : [];
            next[key] = existing.filter((v) => !value.values.includes(v));
          } else if (value && value.__op === 'arrayUnion') {
            const existing = Array.isArray(next[key]) ? next[key] : [];
            const merged = [...existing];
            for (const v of value.values) {
              if (!merged.includes(v)) merged.push(v);
            }
            next[key] = merged;
          } else {
            next[key] = value;
          }
        }

        collection.set(op.ref.id, next);
      }
    }

    this.ops = [];
  }
}

const resetStore = () => {
  store = {
    users: new Map(),
    students: new Map(),
    teaching_shifts: new Map(),
    timesheet_entries: new Map(),
    form_responses: new Map(),
    form_submissions: new Map(),
    form_drafts: new Map(),
    tasks: new Map(),
  };
};

jest.mock('firebase-admin', () => {
  const firestoreFn = jest.fn(() => mockDb);
  firestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => ({ __op: 'serverTimestamp' })),
    delete: jest.fn(() => ({ __op: 'delete' })),
    arrayRemove: jest.fn((...values) => ({ __op: 'arrayRemove', values })),
    arrayUnion: jest.fn((...values) => ({ __op: 'arrayUnion', values })),
  };

  return {
    apps: [],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
    auth: jest.fn(() => mockAuthApi),
  };
});

const userHandlers = require('../handlers/users');

describe('deleteUserAccount class cleanup', () => {
  beforeEach(() => {
    resetStore();
    mockDb = {
      collection: (name) => new CollectionRef(name),
      batch: () => new WriteBatch(),
    };
    mockAuthApi = {
      deleteUser: jest.fn(() => Promise.resolve()),
      getUserByEmail: jest.fn(() => Promise.reject(new Error('not-found'))),
    };
  });

  test('student: deletes solo shifts and detaches from group shifts (no other student shifts deleted)', async () => {
    const adminUid = 'admin_uid';
    store.users.set(adminUid, { uid: adminUid, user_type: 'admin', 'e-mail': 'admin@test.com' });

    const studentUid = 'student_uid';
    store.users.set(studentUid, {
      uid: studentUid,
      user_type: 'student',
      is_active: false,
      first_name: 'Student',
      last_name: 'X',
      'e-mail': 'student@example.com',
      guardian_ids: [],
    });

    store.teaching_shifts.set('shift_solo', {
      teacher_id: 'teacher_uid',
      student_ids: [studentUid],
      student_names: ['Student X'],
      status: 'scheduled',
    });

    store.teaching_shifts.set('shift_group', {
      teacher_id: 'teacher_uid',
      student_ids: [studentUid, 'other_student_uid'],
      student_names: ['Student X', 'Other Student'],
      status: 'scheduled',
    });

    store.teaching_shifts.set('shift_other', {
      teacher_id: 'teacher_uid',
      student_ids: ['other_student_uid'],
      student_names: ['Other Student'],
      status: 'scheduled',
    });

    store.timesheet_entries.set('ts1', { shift_id: 'shift_solo', userId: 'teacher_uid' });
    store.timesheet_entries.set('ts2', { shift_id: 'shift_group', userId: 'teacher_uid' });
    store.timesheet_entries.set('ts3', { shift_id: 'shift_other', userId: 'teacher_uid' });

    store.form_responses.set('fr1', { shift_id: 'shift_solo' });
    store.form_responses.set('fr2', { shift_id: 'shift_group' });

    const res = await userHandlers.deleteUserAccount(
      { data: { email: 'student@example.com', adminEmail: 'admin@test.com', deleteClasses: true } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );

    expect(res.success).toBe(true);

    // Solo shift deleted, group + other remain
    expect(store.teaching_shifts.has('shift_solo')).toBe(false);
    expect(store.teaching_shifts.has('shift_group')).toBe(true);
    expect(store.teaching_shifts.has('shift_other')).toBe(true);

    // Group shift should no longer include the deleted student
    const group = store.teaching_shifts.get('shift_group');
    expect(group.student_ids).toEqual(['other_student_uid']);
    expect(group.student_names).toEqual(['Other Student']);

    // Related data for deleted shift should be removed
    expect(store.timesheet_entries.has('ts1')).toBe(false);
    expect(store.form_responses.has('fr1')).toBe(false);

    // Other shift-related data should remain
    expect(store.timesheet_entries.has('ts2')).toBe(true);
    expect(store.timesheet_entries.has('ts3')).toBe(true);
    expect(store.form_responses.has('fr2')).toBe(true);
  });

  test('teacher: deletes only shifts where teacher is assigned (does not touch other teachers)', async () => {
    const adminUid = 'admin_uid';
    store.users.set(adminUid, { uid: adminUid, user_type: 'admin', 'e-mail': 'admin@test.com' });

    const teacherUid = 'teacher_uid';
    store.users.set(teacherUid, {
      uid: teacherUid,
      user_type: 'teacher',
      is_active: false,
      first_name: 'Teacher',
      last_name: 'Y',
      'e-mail': 'teacher@example.com',
    });

    store.teaching_shifts.set('shift_teacher_1', {
      teacher_id: teacherUid,
      student_ids: ['student_a'],
      student_names: ['Student A'],
      status: 'scheduled',
    });

    store.teaching_shifts.set('shift_teacher_2', {
      teacher_id: teacherUid,
      student_ids: ['student_b'],
      student_names: ['Student B'],
      status: 'completed',
    });

    store.teaching_shifts.set('shift_other_teacher', {
      teacher_id: 'other_teacher_uid',
      original_teacher_id: teacherUid,
      student_ids: ['student_c'],
      student_names: ['Student C'],
      status: 'scheduled',
    });

    store.timesheet_entries.set('ts1', { shift_id: 'shift_teacher_1', userId: teacherUid });
    store.timesheet_entries.set('ts2', { shift_id: 'shift_other_teacher', userId: 'other_teacher_uid' });

    const res = await userHandlers.deleteUserAccount(
      { data: { email: 'teacher@example.com', adminEmail: 'admin@test.com', deleteClasses: true } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );

    expect(res.success).toBe(true);

    // Only the teacher's shifts deleted
    expect(store.teaching_shifts.has('shift_teacher_1')).toBe(false);
    expect(store.teaching_shifts.has('shift_teacher_2')).toBe(false);
    expect(store.teaching_shifts.has('shift_other_teacher')).toBe(true);

    // Related data for deleted shifts removed; unrelated remains
    expect(store.timesheet_entries.has('ts1')).toBe(false);
    expect(store.timesheet_entries.has('ts2')).toBe(true);
  });

  test('admin auth: trims role values (e.g. "Admin ")', async () => {
    const adminUid = 'admin_uid';
    store.users.set(adminUid, { uid: adminUid, user_type: 'Admin ', 'e-mail': 'admin@test.com' });

    const victimUid = 'victim_uid';
    store.users.set(victimUid, {
      uid: victimUid,
      user_type: 'parent',
      is_active: false,
      first_name: 'Victim',
      last_name: 'User',
      'e-mail': 'victim@example.com',
      children_ids: [],
    });

    const res = await userHandlers.deleteUserAccount(
      { data: { email: 'victim@example.com', adminEmail: 'admin@test.com' } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );

    expect(res.success).toBe(true);
    expect(store.users.has(victimUid)).toBe(false);
  });

  test('admin auth: allows token-claim admin even when caller user doc missing', async () => {
    const adminUid = 'admin_uid_missing_doc';

    const victimUid = 'victim_uid';
    store.users.set(victimUid, {
      uid: victimUid,
      user_type: 'teacher',
      is_active: false,
      first_name: 'Victim',
      last_name: 'Teacher',
      'e-mail': 'victim.teacher@example.com',
    });

    const res = await userHandlers.deleteUserAccount(
      { data: { email: 'victim.teacher@example.com' } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com', role: 'admin' } } }
    );

    expect(res.success).toBe(true);
    expect(store.users.has(victimUid)).toBe(false);
  });
});
