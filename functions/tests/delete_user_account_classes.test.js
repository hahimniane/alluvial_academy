/**
 * Tests for deleteUserAccount optional class cleanup.
 *
 * Safety requirement:
 * - "Also delete classes" touches UPCOMING classes only; past and running
 *   classes, timesheets and class reports are kept (owner decision D3).
 * - When deleting a student, do NOT delete shifts that also contain other students.
 *   Instead, remove the student from the shift.
 * - When deleting a teacher, delete only shifts where that teacher is the assigned teacher.
 * - The target is found by document id; an admin can never delete themselves.
 */

const HOUR = 60 * 60 * 1000;
const future = (h = 48) => new Date(Date.now() + h * HOUR);
const past = (h = 48) => new Date(Date.now() - h * HOUR);

// Made-up passwords built at run time (fixtures, not credentials).
const pw = (word) => `${word}-fixture`;

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

  collection(name) {
    return new CollectionRef(`${this.path}/${name}`);
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

  set(ref, data, options) {
    this.ops.push({ type: 'set', ref, data, options });
  }

  async commit() {
    for (const op of this.ops) {
      const collection = store[op.ref.collectionName];
      if (!collection) {
        store[op.ref.collectionName] = new Map();
      }
      const targetCollection = store[op.ref.collectionName];

      if (op.type === 'delete') {
        targetCollection.delete(op.ref.id);
        continue;
      }

      if (op.type === 'update') {
        const current = targetCollection.get(op.ref.id);
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

        targetCollection.set(op.ref.id, next);
        continue;
      }

      if (op.type === 'set') {
        const current = op.options?.merge
          ? targetCollection.get(op.ref.id) || {}
          : {};
        const next = {...current};
        for (const [key, value] of Object.entries(op.data || {})) {
          next[key] = value && value.__op === 'serverTimestamp'
            ? new Date()
            : value;
        }
        targetCollection.set(op.ref.id, next);
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
      shift_start: future(),
    });

    store.teaching_shifts.set('shift_group', {
      teacher_id: 'teacher_uid',
      student_ids: [studentUid, 'other_student_uid'],
      student_names: ['Student X', 'Other Student'],
      status: 'scheduled',
      shift_start: future(),
    });

    store.teaching_shifts.set('shift_other', {
      teacher_id: 'teacher_uid',
      student_ids: ['other_student_uid'],
      student_names: ['Other Student'],
      status: 'scheduled',
      shift_start: future(),
    });

    store.teaching_shifts.set('shift_past_solo', {
      teacher_id: 'teacher_uid',
      student_ids: [studentUid],
      student_names: ['Student X'],
      status: 'completed',
      shift_start: past(),
    });

    store.teaching_shifts.set('shift_past_group', {
      teacher_id: 'teacher_uid',
      student_ids: [studentUid, 'other_student_uid'],
      student_names: ['Student X', 'Other Student'],
      status: 'completed',
      shift_start: past(),
    });

    store.timesheet_entries.set('ts1', { shift_id: 'shift_solo', userId: 'teacher_uid' });
    store.timesheet_entries.set('ts2', { shift_id: 'shift_group', userId: 'teacher_uid' });
    store.timesheet_entries.set('ts3', { shift_id: 'shift_other', userId: 'teacher_uid' });

    store.timesheet_entries.set('ts4', { shift_id: 'shift_past_solo', userId: studentUid });
    store.form_responses.set('fr1', { shift_id: 'shift_solo' });
    store.form_responses.set('fr2', { shift_id: 'shift_group' });
    store.form_responses.set('fr3', { shift_id: 'shift_past_solo' });
    store.student_credentials = new Map([[studentUid, { password: pw('tiger') }]]);

    const res = await userHandlers.deleteUserAccount(
      { data: { userId: studentUid, deleteClasses: true } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );

    expect(res.success).toBe(true);
    expect(res.upcomingClassesDeleted).toBe(1);
    expect(res.upcomingClassesUpdated).toBe(1);
    expect(res.classesKept).toBe(2);

    // Upcoming solo shift deleted; upcoming group + other remain
    expect(store.teaching_shifts.has('shift_solo')).toBe(false);
    expect(store.teaching_shifts.has('shift_group')).toBe(true);
    expect(store.teaching_shifts.has('shift_other')).toBe(true);

    // Upcoming group shift should no longer include the deleted student
    const group = store.teaching_shifts.get('shift_group');
    expect(group.student_ids).toEqual(['other_student_uid']);
    expect(group.student_names).toEqual(['Other Student']);

    // Past classes are untouched, the student stays on them
    expect(store.teaching_shifts.has('shift_past_solo')).toBe(true);
    expect(store.teaching_shifts.get('shift_past_group').student_ids).toEqual([studentUid, 'other_student_uid']);

    // Every timesheet and class report is kept
    for (const id of ['ts1', 'ts2', 'ts3', 'ts4']) expect(store.timesheet_entries.has(id)).toBe(true);
    for (const id of ['fr1', 'fr2', 'fr3']) expect(store.form_responses.has(id)).toBe(true);

    // The account and its stored password are gone
    expect(store.users.has(studentUid)).toBe(false);
    expect(store.student_credentials.has(studentUid)).toBe(false);
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
      shift_start: future(),
    });

    store.teaching_shifts.set('shift_teacher_2', {
      teacher_id: teacherUid,
      student_ids: ['student_b'],
      student_names: ['Student B'],
      status: 'completed',
      shift_start: past(),
    });

    store.teaching_shifts.set('shift_teacher_running', {
      teacher_id: teacherUid,
      student_ids: ['student_b'],
      status: 'active',
      shift_start: past(0.25),
    });

    store.teaching_shifts.set('shift_teacher_no_start', {
      teacherId: teacherUid,
      student_ids: ['student_b'],
      status: 'scheduled',
    });

    store.teaching_shifts.set('shift_other_teacher', {
      teacher_id: 'other_teacher_uid',
      original_teacher_id: teacherUid,
      student_ids: ['student_c'],
      student_names: ['Student C'],
      status: 'scheduled',
      shift_start: future(),
    });

    store.timesheet_entries.set('ts1', { shift_id: 'shift_teacher_2', teacher_id: teacherUid, userId: teacherUid });
    store.timesheet_entries.set('ts2', { shift_id: 'shift_other_teacher', userId: 'other_teacher_uid' });
    store.form_responses.set('fr1', { shift_id: 'shift_teacher_2' });

    const res = await userHandlers.deleteUserAccount(
      { data: { userId: teacherUid, deleteClasses: true } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );

    expect(res.success).toBe(true);
    expect(res.upcomingClassesDeleted).toBe(1);
    expect(res.classesKept).toBe(3);

    // Only the teacher's upcoming shift is deleted
    expect(store.teaching_shifts.has('shift_teacher_1')).toBe(false);
    expect(store.teaching_shifts.has('shift_teacher_2')).toBe(true);
    expect(store.teaching_shifts.has('shift_teacher_running')).toBe(true);
    expect(store.teaching_shifts.has('shift_teacher_no_start')).toBe(true);
    expect(store.teaching_shifts.has('shift_other_teacher')).toBe(true);

    // Pay history and class reports kept
    expect(store.timesheet_entries.has('ts1')).toBe(true);
    expect(store.timesheet_entries.has('ts2')).toBe(true);
    expect(store.form_responses.has('fr1')).toBe(true);
  });

  test('without the option no class is touched', async () => {
    const adminUid = 'admin_uid';
    store.users.set(adminUid, { uid: adminUid, user_type: 'admin', 'e-mail': 'admin@test.com' });
    store.users.set('teacher_uid', { uid: 'teacher_uid', user_type: 'teacher', is_active: false, 'e-mail': 't@example.com' });
    store.teaching_shifts.set('up', { teacher_id: 'teacher_uid', shift_start: future() });

    const res = await userHandlers.deleteUserAccount(
      { data: { userId: 'teacher_uid' } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );
    expect(res.success).toBe(true);
    expect(res.upcomingClassesDeleted).toBe(0);
    expect(store.teaching_shifts.has('up')).toBe(true);
  });

  test('finds the target by document id, never the first doc sharing its email', async () => {
    const adminUid = 'admin_uid';
    store.users.set(adminUid, { uid: adminUid, user_type: 'admin', 'e-mail': 'admin@test.com' });
    // A parent and their child created with the parent's address.
    store.users.set('parent_uid', { uid: 'parent_uid', user_type: 'parent', is_active: true, 'e-mail': 'family@example.com', children_ids: [] });
    store.users.set('child_uid', { uid: 'child_uid', user_type: 'student', is_active: false, 'e-mail': 'family@example.com', guardian_ids: [] });
    mockAuthApi.deleteUser = jest.fn((uid) => (uid === 'child_uid'
      ? Promise.reject(Object.assign(new Error('no auth user'), { code: 'auth/user-not-found' }))
      : Promise.resolve()));
    mockAuthApi.getUserByEmail = jest.fn(() => Promise.resolve({ uid: 'parent_uid' }));

    const res = await userHandlers.deleteUserAccount(
      { data: { userId: 'child_uid', email: 'family@example.com' } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );
    expect(res.success).toBe(true);
    expect(store.users.has('child_uid')).toBe(false);
    expect(store.users.has('parent_uid')).toBe(true);
    // The parent's sign-in account, found by the shared email, is left alone.
    expect(mockAuthApi.deleteUser).not.toHaveBeenCalledWith('parent_uid');
    expect(res.deletedFromAuth).toBe(false);
  });

  test('refuses to delete the caller themselves', async () => {
    const adminUid = 'admin_uid';
    store.users.set(adminUid, { uid: adminUid, user_type: 'admin', is_active: false, 'e-mail': 'admin@test.com' });
    await expect(userHandlers.deleteUserAccount(
      { data: { userId: adminUid } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    )).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(store.users.has(adminUid)).toBe(true);
  });

  test('refuses an active user and a non-admin caller', async () => {
    store.users.set('admin_uid', { uid: 'admin_uid', user_type: 'admin' });
    store.users.set('teacher_uid', { uid: 'teacher_uid', user_type: 'teacher', is_active: true });
    store.users.set('other_teacher', { uid: 'other_teacher', user_type: 'teacher', is_active: false });
    await expect(userHandlers.deleteUserAccount(
      { data: { userId: 'teacher_uid' } },
      { auth: { uid: 'admin_uid', token: {} } }
    )).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(userHandlers.deleteUserAccount(
      { data: { userId: 'other_teacher' } },
      { auth: { uid: 'teacher_uid', token: {} } }
    )).rejects.toMatchObject({ code: 'permission-denied' });
    expect(store.users.has('other_teacher')).toBe(true);
  });

  test('a missing target is not-found', async () => {
    store.users.set('admin_uid', { uid: 'admin_uid', user_type: 'admin' });
    await expect(userHandlers.deleteUserAccount(
      { data: { userId: 'nobody' } },
      { auth: { uid: 'admin_uid', token: {} } }
    )).rejects.toMatchObject({ code: 'not-found' });
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

  test('family links: deleting a parent clears every student that names them, either spelling, either side', async () => {
    const adminUid = 'admin_uid';
    store.users.set(adminUid, { uid: adminUid, user_type: 'admin', 'e-mail': 'admin@test.com' });
    const parentUid = 'parent_uid';
    // The parent's own list names only kid_a; kid_b and kid_c link one-sidedly from their side.
    store.users.set(parentUid, { uid: parentUid, user_type: 'parent', is_active: false, 'e-mail': 'p@example.com', children_ids: ['kid_a'] });
    store.users.set('kid_a', { uid: 'kid_a', user_type: 'student', guardian_ids: [parentUid, 'other_parent'] });
    store.users.set('kid_b', { uid: 'kid_b', user_type: 'student', guardianIds: [parentUid] });
    store.users.set('kid_c', { uid: 'kid_c', user_type: 'student', guardian_ids: [parentUid], parent_id: parentUid });
    store.users.set('kid_d', { uid: 'kid_d', user_type: 'student', guardian_ids: ['other_parent'] });

    const res = await userHandlers.deleteUserAccount(
      { data: { userId: parentUid } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );

    expect(res.success).toBe(true);
    expect(store.users.get('kid_a').guardian_ids).toEqual(['other_parent']);
    expect(store.users.get('kid_b').guardianIds).toEqual([]);
    expect(store.users.get('kid_c').guardian_ids).toEqual([]);
    expect(store.users.get('kid_c').parent_id).toBeUndefined();
    expect(store.users.get('kid_d').guardian_ids).toEqual(['other_parent']);
    expect(store.users.get('kid_d').updated_at).toBeUndefined();
  });

  test('family links: deleting a student clears every parent that lists them, either spelling', async () => {
    const adminUid = 'admin_uid';
    store.users.set(adminUid, { uid: adminUid, user_type: 'admin', 'e-mail': 'admin@test.com' });
    const kid = 'kid_uid';
    store.users.set(kid, { uid: kid, user_type: 'Student', is_active: false, 'e-mail': 'kid@example.com', guardianIds: ['par_1'] });
    store.users.set('par_1', { uid: 'par_1', user_type: 'parent', childrenIds: [kid, 'sibling'] });
    store.users.set('par_2', { uid: 'par_2', user_type: 'parent', children_ids: [kid] });
    store.users.set('par_3', { uid: 'par_3', user_type: 'parent', children_ids: ['sibling'] });

    const res = await userHandlers.deleteUserAccount(
      { data: { userId: kid } },
      { auth: { uid: adminUid, token: { email: 'admin@test.com' } } }
    );

    expect(res.success).toBe(true);
    expect(store.users.get('par_1').childrenIds).toEqual(['sibling']);
    expect(store.users.get('par_2').children_ids).toEqual([]);
    expect(store.users.get('par_3').children_ids).toEqual(['sibling']);
    expect(store.users.get('par_3').updated_at).toBeUndefined();
  });
});
