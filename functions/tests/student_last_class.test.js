const {createFakeFirestore, FakeTimestamp} = require('./helpers/fake_firestore');
const {
  presentStudent,
  lastClassCandidate,
  isLater,
  recordLastClass,
} = require('../handlers/student_last_class');

const ts = (iso) => FakeTimestamp.fromDate(new Date(iso));
const session = (over = {}) => ({
  shift_id: 'sh1',
  user_id: 's1',
  student_ids: ['s1', 's2'],
  shift_start: ts('2026-11-20T14:00:00Z'),
  join_count: 1,
  total_presence_seconds: 1800,
  first_joined_at: ts('2026-11-20T14:01:00Z'),
  ...over,
});
const notJoined = {join_count: 0, total_presence_seconds: 0, first_joined_at: null};

describe('presentStudent', () => {
  test('a student who joined, stayed, or has a first-join time is present', () => {
    expect(presentStudent(session())).toEqual({studentId: 's1', start: new Date('2026-11-20T14:00:00Z')});
    expect(presentStudent(session({...notJoined, join_count: 2}))).not.toBeNull();
    expect(presentStudent(session({...notJoined, total_presence_seconds: 5}))).not.toBeNull();
    expect(presentStudent(session({...notJoined, first_joined_at: ts('2026-11-20T14:01:00Z')}))).not.toBeNull();
  });

  test('no join, a teacher record, a missing start or no record is not', () => {
    expect(presentStudent(session(notJoined))).toBeNull();
    expect(presentStudent(session({user_id: 't1'}))).toBeNull();
    expect(presentStudent(session({shift_start: null}))).toBeNull();
    expect(presentStudent(null)).toBeNull();
  });
});

describe('lastClassCandidate', () => {
  test('the first write that shows the student joined proposes the class', () => {
    expect(lastClassCandidate(session(notJoined), session()).studentId).toBe('s1');
    expect(lastClassCandidate(null, session()).studentId).toBe('s1');
  });

  test('later presence updates for the same class propose nothing', () => {
    expect(lastClassCandidate(session(), session({total_presence_seconds: 2400, join_count: 2}))).toBeNull();
  });

  test('a class moved to another time proposes it again', () => {
    expect(lastClassCandidate(session(), session({shift_start: ts('2026-11-21T14:00:00Z')})).start.toISOString())
      .toBe('2026-11-21T14:00:00.000Z');
  });

  test('a deleted record or one without a join proposes nothing', () => {
    expect(lastClassCandidate(session(), null)).toBeNull();
    expect(lastClassCandidate(null, session(notJoined))).toBeNull();
  });
});

describe('isLater', () => {
  const start = new Date('2026-11-20T14:00:00Z');
  test('missing or earlier stored dates are replaced, later or equal ones kept', () => {
    expect(isLater(undefined, start)).toBe(true);
    expect(isLater(ts('2026-11-01T00:00:00Z'), start)).toBe(true);
    expect(isLater(ts('2026-11-22T00:00:00Z'), start)).toBe(false);
    expect(isLater(ts('2026-11-20T14:00:00Z'), start)).toBe(false);
  });
});

describe('recordLastClass', () => {
  const seed = () =>
    createFakeFirestore({
      users: {
        s1: {user_type: 'student', first_name: 'A'},
        s2: {user_type: 'student', last_class_at: ts('2026-11-22T10:00:00Z'), last_class_shift_id: 'newer'},
        s3: {user_type: 'student', last_class_at: ts('2026-10-01T10:00:00Z')},
        p1: {user_type: 'parent'},
      },
    });
  const start = new Date('2026-11-20T14:00:00Z');

  test('sets a missing date, moves an older one later, keeps a newer one, skips others', async () => {
    const db = seed();
    const run = (studentId) => recordLastClass({db, Timestamp: FakeTimestamp, shiftId: 'sh1', candidate: {studentId, start}});
    expect(await run('s1')).toBe('updated');
    expect(await run('s2')).toBe('unchanged');
    expect(await run('s3')).toBe('updated');
    expect(await run('p1')).toBe('not_student');
    expect(await run('ghost')).toBe('no_user');

    const s1 = (await db.collection('users').doc('s1').get()).data();
    expect(s1.last_class_at.toDate().toISOString()).toBe('2026-11-20T14:00:00.000Z');
    expect(s1.last_class_shift_id).toBe('sh1');
    expect(s1.first_name).toBe('A');
    expect((await db.collection('users').doc('s2').get()).data().last_class_shift_id).toBe('newer');
    expect((await db.collection('users').doc('s3').get()).data().last_class_shift_id).toBe('sh1');
    expect((await db.collection('users').doc('p1').get()).data().last_class_at).toBeUndefined();
  });
});
