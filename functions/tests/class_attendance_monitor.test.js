const {
  __test__: { evaluateClassAttendance, _alertMessage, _normalizeIds, GRACE_MINUTES },
} = require('../handlers/class_attendance_monitor');

describe('class attendance monitor', () => {
  const teacherId = 'teacher-1';
  const studentIds = ['student-1', 'student-2'];

  test('within grace period never flags a problem', () => {
    const verdict = evaluateClassAttendance({
      teacherId,
      studentIds,
      present: [],
      minutesSinceStart: GRACE_MINUTES - 1,
    });
    expect(verdict).toEqual({ problem: false, missing: null, withinGrace: true });
  });

  test('teacher and at least one student present is OK', () => {
    const verdict = evaluateClassAttendance({
      teacherId,
      studentIds,
      present: [teacherId, 'student-2'],
      minutesSinceStart: 6,
    });
    expect(verdict.problem).toBe(false);
    expect(verdict.missing).toBeNull();
  });

  test('teacher missing flags "teacher"', () => {
    const verdict = evaluateClassAttendance({
      teacherId,
      studentIds,
      present: ['student-1'],
      minutesSinceStart: 6,
    });
    expect(verdict).toMatchObject({ problem: true, missing: 'teacher' });
  });

  test('no students flags "students"', () => {
    const verdict = evaluateClassAttendance({
      teacherId,
      studentIds,
      present: [teacherId],
      minutesSinceStart: 7,
    });
    expect(verdict).toMatchObject({ problem: true, missing: 'students' });
  });

  test('nobody present flags "both"', () => {
    const verdict = evaluateClassAttendance({
      teacherId,
      studentIds,
      present: [],
      minutesSinceStart: 10,
    });
    expect(verdict).toMatchObject({ problem: true, missing: 'both' });
  });

  test('whitespace/duplicate ids are normalized for matching', () => {
    const verdict = evaluateClassAttendance({
      teacherId: ' teacher-1 ',
      studentIds: ['student-1', 'student-1'],
      present: ['teacher-1', 'student-1'],
      minutesSinceStart: 6,
    });
    expect(verdict.problem).toBe(false);
  });

  test('alert message varies by who is missing', () => {
    expect(_alertMessage('teacher', 'Quran 101', 5).title).toMatch(/Teacher/i);
    expect(_alertMessage('students', 'Quran 101', 5).title).toMatch(/students/i);
    expect(_alertMessage('both', 'Quran 101', 5).title).toMatch(/unattended/i);
  });

  test('_normalizeIds dedupes and trims', () => {
    expect(_normalizeIds([' a ', 'a', 'b', '', null, 3])).toEqual(['a', 'b', '3']);
  });
});
