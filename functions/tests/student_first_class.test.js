const {createFakeFirestore, FakeTimestamp} = require('./helpers/fake_firestore');
const {
  firstClassCandidate,
  isAttendedClass,
  isEarlier,
  recordFirstClass,
} = require('../handlers/student_first_class');

const ts = (iso) => FakeTimestamp.fromDate(new Date(iso));
const shift = (over = {}) => ({
  status: 'completed',
  shift_start: ts('2026-09-08T14:00:00Z'),
  student_ids: ['s1'],
  ...over,
});

describe('isAttendedClass', () => {
  test('completed, fully and partially completed teaching classes count', () => {
    expect(isAttendedClass(shift())).toBe(true);
    expect(isAttendedClass(shift({status: 'fullyCompleted'}))).toBe(true);
    expect(isAttendedClass(shift({status: 'partiallyCompleted'}))).toBe(true);
  });

  test('scheduled, missed, cancelled and active classes do not', () => {
    for (const status of ['scheduled', 'missed', 'cancelled', 'active', '']) {
      expect(isAttendedClass(shift({status}))).toBe(false);
    }
  });

  test('non-teaching categories and classes without a start do not', () => {
    expect(isAttendedClass(shift({category: 'leadership'}))).toBe(false);
    expect(isAttendedClass(shift({shift_category: 'meeting'}))).toBe(false);
    expect(isAttendedClass(shift({category: 'Teaching'}))).toBe(true);
    expect(isAttendedClass(shift({shift_start: null}))).toBe(false);
    expect(isAttendedClass(null)).toBe(false);
  });
});

describe('firstClassCandidate', () => {
  test('a class that becomes completed proposes every student on it', () => {
    const c = firstClassCandidate(shift({status: 'scheduled', student_ids: ['s1', 's2']}), shift({student_ids: ['s1', ' s2 ', '', 's1']}));
    expect(c.students).toEqual(['s1', 's2']);
    expect(c.start.toISOString()).toBe('2026-09-08T14:00:00.000Z');
  });

  test('a new document created already completed counts', () => {
    expect(firstClassCandidate(null, shift()).students).toEqual(['s1']);
  });

  test('an unrelated edit of a completed class proposes nothing', () => {
    expect(firstClassCandidate(shift(), shift({notes: 'x'}))).toBeNull();
  });

  test('a student added to a completed class is proposed alone', () => {
    expect(firstClassCandidate(shift(), shift({student_ids: ['s1', 's3']})).students).toEqual(['s3']);
  });

  test('moving a completed class proposes all its students again', () => {
    const c = firstClassCandidate(shift(), shift({shift_start: ts('2026-09-01T14:00:00Z'), student_ids: ['s1', 's3']}));
    expect(c.students).toEqual(['s1', 's3']);
  });

  test('deleting or un-completing a class proposes nothing', () => {
    expect(firstClassCandidate(shift(), null)).toBeNull();
    expect(firstClassCandidate(shift(), shift({status: 'missed'}))).toBeNull();
    expect(firstClassCandidate(null, shift({student_ids: []}))).toBeNull();
  });
});

describe('isEarlier', () => {
  const start = new Date('2026-09-08T14:00:00Z');
  test('missing or later stored dates are replaced, earlier or equal ones kept', () => {
    expect(isEarlier(undefined, start)).toBe(true);
    expect(isEarlier(ts('2026-10-01T00:00:00Z'), start)).toBe(true);
    expect(isEarlier(ts('2026-09-01T00:00:00Z'), start)).toBe(false);
    expect(isEarlier(ts('2026-09-08T14:00:00Z'), start)).toBe(false);
    expect(isEarlier('not a date', start)).toBe(true);
  });
});

describe('recordFirstClass', () => {
  const seed = () =>
    createFakeFirestore({
      users: {
        s1: {user_type: 'student', first_name: 'A'},
        s2: {user_type: 'student', first_class_at: ts('2026-08-01T10:00:00Z'), first_class_shift_id: 'old'},
        s3: {user_type: 'student', first_class_at: ts('2026-12-01T10:00:00Z')},
        p1: {user_type: 'parent'},
      },
    });

  test('sets missing dates, moves later ones earlier, leaves earlier ones and non-students alone', async () => {
    const db = seed();
    const candidate = {students: ['s1', 's2', 's3', 'p1', 'ghost'], start: new Date('2026-09-08T14:00:00Z')};
    const results = await recordFirstClass({db, Timestamp: FakeTimestamp, shiftId: 'sh1', candidate});
    expect(results.map((r) => r.outcome)).toEqual(['updated', 'unchanged', 'updated', 'not_student', 'no_user']);

    const s1 = (await db.collection('users').doc('s1').get()).data();
    expect(s1.first_class_at.toDate().toISOString()).toBe('2026-09-08T14:00:00.000Z');
    expect(s1.first_class_shift_id).toBe('sh1');
    expect(s1.first_name).toBe('A');

    const s2 = (await db.collection('users').doc('s2').get()).data();
    expect(s2.first_class_shift_id).toBe('old');

    const s3 = (await db.collection('users').doc('s3').get()).data();
    expect(s3.first_class_at.toDate().toISOString()).toBe('2026-09-08T14:00:00.000Z');

    expect((await db.collection('users').doc('ghost').get()).exists).toBe(false);
    expect((await db.collection('users').doc('p1').get()).data().first_class_at).toBeUndefined();
  });
});
