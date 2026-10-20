jest.mock('firebase-functions/v2/https', () => {
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {onCall: (_opts, fn) => fn, HttpsError};
});

jest.mock('firebase-admin', () => ({
  apps: [],
  initializeApp: jest.fn(),
  firestore: Object.assign(jest.fn(), {
    Timestamp: {fromDate: (date) => ({toDate: () => date, _ms: date.getTime()})},
  }),
}));

const {buildClassContacts, normalizePhone, getClassContacts} = require('../handlers/class_contacts');

const NOW = new Date('2026-10-20T12:00:00Z');
const day = (n) => ({toDate: () => new Date(NOW.getTime() + n * 86400000), _ms: NOW.getTime() + n * 86400000});

const fieldMs = (v) => (v && typeof v._ms === 'number' ? v._ms : v);

const buildDb = ({users = {}, shifts = []}) => {
  const matches = (data, [field, op, value]) => {
    const actual = data[field];
    if (op === '==') return actual === value;
    if (op === 'array-contains') return Array.isArray(actual) && actual.includes(value);
    if (op === '>=') return fieldMs(actual) >= fieldMs(value);
    if (op === '<=') return fieldMs(actual) <= fieldMs(value);
    throw new Error(`unsupported op ${op}`);
  };
  const query = (rows, filters) => ({
    where: (field, op, value) => query(rows, [...filters, [field, op, value]]),
    get: async () => ({
      docs: rows
        .filter(([, data]) => filters.every((f) => matches(data, f)))
        .map(([id, data]) => ({id, data: () => data})),
    }),
  });
  return {
    collection: (name) => {
      const rows = name === 'users'
        ? Object.entries(users)
        : shifts.map((s, i) => [`shift${i}`, s]);
      return Object.assign(query(rows, []), {
        doc: (id) => ({
          get: async () => ({exists: id in users, data: () => users[id]}),
        }),
      });
    },
  };
};

const users = {
  t1: {user_type: 'teacher', first_name: 'Amina', last_name: 'Diallo', phone_number: '+224 621 00 00 01', 'e-mail': 't1@x'},
  t2: {user_type: 'teacher', first_name: 'Bilal', last_name: 'Sow', phone_number: '7037000000', country_code: '+234'},
  t3: {user_type: 'teacher', first_name: 'No', last_name: 'Phone'},
  s1: {user_type: 'student', first_name: 'Fatou', last_name: 'Bah', guardian_ids: ['p1', 'p2'], phone_number: '+15550000099', address: 'x'},
  s2: {user_type: 'student', first_name: 'Omar', last_name: 'Barry', guardian_ids: [], phone_number: '6175550100', is_adult_student: true},
  s3: {user_type: 'student', first_name: 'Zeyna', last_name: 'Ly', guardian_ids: ['p1']},
  s4: {user_type: 'student', first_name: 'Old', last_name: 'Student', guardian_ids: ['p1']},
  s5: {user_type: 'student', first_name: 'Gone', last_name: 'Student', guardian_ids: ['p1'], is_active: false},
  p1: {user_type: 'parent', first_name: 'Mariama', last_name: 'Bah', phone_number: '07981234567', country_code: '+44', email: 'p1@x'},
  p2: {user_type: 'parent', first_name: 'Ibrahima', last_name: 'Bah'},
  adm: {user_type: 'admin', first_name: 'Ad', last_name: 'Min', phone_number: '+10000000000'},
};

const shifts = [
  {teacher_id: 't1', student_ids: ['s1', 's2'], shift_start: day(1), status: 'scheduled'},
  {teacher_id: 't1', student_ids: ['s1'], shift_start: day(-10), status: 'fullyCompleted'},
  {teacher_id: 't1', student_ids: ['s3'], shift_start: day(-90), status: 'fullyCompleted'},
  {teacher_id: 't1', student_ids: ['s5'], shift_start: day(2), status: 'scheduled'},
  {teacher_id: 't2', student_ids: ['s1', 's3'], shift_start: day(3), status: 'scheduled'},
  {teacher_id: 't3', student_ids: ['s3'], shift_start: day(3), status: 'scheduled'},
  {teacher_id: 't2', student_ids: ['s4'], shift_start: day(4), status: 'cancelled'},
];

const run = (uid) => buildClassContacts({db: buildDb({users, shifts}), uid, now: NOW});

describe('normalizePhone', () => {
  test('keeps international numbers and builds a tel value', () => {
    expect(normalizePhone({phone_number: '+224  621 00 00 01'})).toEqual({phone: '+224 621 00 00 01', tel: '+224621000001'});
  });
  test('joins a national number to its country code, dropping the trunk 0', () => {
    expect(normalizePhone({phone_number: '07981234567', country_code: '+44'})).toEqual({phone: '+44 7981234567', tel: '+447981234567'});
  });
  test('does not double a country code already typed into the number', () => {
    expect(normalizePhone({phone_number: '2246210000011', country_code: '+224'}).tel).toBe('+2246210000011');
  });
  test('treats a long number without a country as international', () => {
    expect(normalizePhone({phone_number: '16465550100'}).tel).toBe('+16465550100');
    expect(normalizePhone({phone_number: '(917) 555-0100'})).toEqual({phone: '(917) 555-0100', tel: '9175550100'});
  });
  test('ignores blanks and fragments', () => {
    expect(normalizePhone({phone_number: ''})).toBeNull();
    expect(normalizePhone({phone_number: '12'})).toBeNull();
    expect(normalizePhone({})).toBeNull();
  });
});

describe('buildClassContacts', () => {
  test('a teacher gets each current student with their parents who have a phone', async () => {
    const result = await run('t1');
    expect(result.children).toEqual([]);
    expect(result.teachers).toEqual([]);
    expect(result.students).toEqual([
      {studentName: 'Fatou Bah', contacts: [{name: 'Mariama Bah', relationship: 'parent', phone: '+44 7981234567', tel: '+447981234567'}]},
      {studentName: 'Omar Barry', contacts: [{name: 'Omar Barry', relationship: 'student', phone: '6175550100', tel: '6175550100'}]},
    ]);
  });

  test("a teacher with no phone of their own still sees their students' parents", async () => {
    const result = await run('t3');
    expect(result.students).toEqual([
      {studentName: 'Zeyna Ly', contacts: [{name: 'Mariama Bah', relationship: 'parent', phone: '+44 7981234567', tel: '+447981234567'}]},
    ]);
  });

  test('a parent gets the teachers of each child, deduped, skipping cancelled and phoneless', async () => {
    const result = await run('p1');
    expect(result.students).toEqual([]);
    expect(result.children).toEqual([
      {studentName: 'Fatou Bah', contacts: [
        {name: 'Amina Diallo', relationship: 'teacher', phone: '+224 621 00 00 01', tel: '+224621000001'},
        {name: 'Bilal Sow', relationship: 'teacher', phone: '+234 7037000000', tel: '+2347037000000'},
      ]},
      {studentName: 'Old Student', contacts: []},
      {studentName: 'Zeyna Ly', contacts: [
        {name: 'Bilal Sow', relationship: 'teacher', phone: '+234 7037000000', tel: '+2347037000000'},
      ]},
    ]);
  });

  test('a student gets their own teachers', async () => {
    const result = await run('s1');
    expect(result.teachers.map((t) => t.name)).toEqual(['Amina Diallo', 'Bilal Sow']);
    expect(result.students).toEqual([]);
  });

  test('returned contacts carry only name, relationship and phone', async () => {
    const result = await run('t1');
    result.students.forEach((group) => {
      expect(Object.keys(group).sort()).toEqual(['contacts', 'studentName']);
      group.contacts.forEach((c) => expect(Object.keys(c).sort()).toEqual(['name', 'phone', 'relationship', 'tel']));
    });
  });

  test('admins and unknown callers get nothing', async () => {
    const empty = {students: [], children: [], teachers: []};
    expect(await run('adm')).toEqual(empty);
    expect(await run('nobody')).toEqual(empty);
    expect(await run('')).toEqual(empty);
  });

  test('the callable requires a signed-in caller', async () => {
    await expect(getClassContacts({data: {}})).rejects.toMatchObject({code: 'unauthenticated'});
  });
});
