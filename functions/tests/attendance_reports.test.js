const admin = require('firebase-admin');
const { __test__ } = require('../handlers/attendance');

describe('attendance analytics helpers', () => {
  beforeAll(() => {
    admin.firestore.Timestamp = {
      fromDate: (date) => global.createMockTimestamp(date),
    };
    admin.firestore.FieldValue = {
      serverTimestamp: () => ({ __type: 'serverTimestamp' }),
    };
  });

  test('computeParticipantPresenceMetrics clips windows to shift and detects early joins', () => {
    const shiftStart = new Date('2026-02-24T10:00:00.000Z');
    const shiftEnd = new Date('2026-02-24T11:00:00.000Z');
    const now = new Date('2026-02-24T12:00:00.000Z');

    const sessionData = {
      presence_windows: [
        {
          join_at: new Date('2026-02-24T09:55:00.000Z'),
          leave_at: new Date('2026-02-24T10:20:00.000Z'),
        },
        {
          join_at: new Date('2026-02-24T10:30:00.000Z'),
          leave_at: new Date('2026-02-24T11:05:00.000Z'),
        },
      ],
    };

    const metrics = __test__.computeParticipantPresenceMetrics({
      sessionData,
      shiftStart,
      shiftEnd,
      now,
      lateGraceMinutes: 5,
    });

    expect(metrics.joinCount).toBe(2);
    expect(metrics.joinsBeforeStartCount).toBe(1);
    expect(metrics.totalPresenceSeconds).toBe(50 * 60);
    expect(metrics.firstJoinOffsetMinutes).toBe(-5);
  });

  test('calculateOverlapSeconds computes overlap across multiple windows', () => {
    const studentWindows = [
      {
        start: new Date('2026-02-24T10:00:00.000Z'),
        end: new Date('2026-02-24T10:20:00.000Z'),
      },
      {
        start: new Date('2026-02-24T10:30:00.000Z'),
        end: new Date('2026-02-24T11:00:00.000Z'),
      },
    ];
    const teacherWindows = [
      {
        start: new Date('2026-02-24T10:10:00.000Z'),
        end: new Date('2026-02-24T10:50:00.000Z'),
      },
    ];

    const overlapSeconds = __test__.calculateOverlapSeconds(
      studentWindows,
      teacherWindows,
    );

    expect(overlapSeconds).toBe(30 * 60);
  });

  test('computeStudentAttendanceReport tracks late, absent, and teacher-absent classes', () => {
    const periodStart = new Date('2026-02-23T00:00:00.000Z');
    const periodEnd = new Date('2026-03-02T00:00:00.000Z');

    const shifts = [
      {
        id: 'shift_1',
        teacherId: 'teacher_1',
        studentIds: ['student_1'],
        shiftStart: new Date('2026-02-24T10:00:00.000Z'),
        shiftEnd: new Date('2026-02-24T11:00:00.000Z'),
        status: 'scheduled',
        subjectName: 'Quran',
      },
      {
        id: 'shift_2',
        teacherId: 'teacher_1',
        studentIds: ['student_1'],
        shiftStart: new Date('2026-02-25T10:00:00.000Z'),
        shiftEnd: new Date('2026-02-25T11:00:00.000Z'),
        status: 'scheduled',
        subjectName: 'Quran',
      },
    ];

    const participantMetricsByShift = new Map();
    participantMetricsByShift.set(
      'shift_1',
      new Map([
        [
          'student_1',
          __test__.computeParticipantPresenceMetrics({
            sessionData: {
              presence_windows: [
                {
                  join_at: new Date('2026-02-24T10:10:00.000Z'),
                  leave_at: new Date('2026-02-24T10:40:00.000Z'),
                },
              ],
            },
            shiftStart: new Date('2026-02-24T10:00:00.000Z'),
            shiftEnd: new Date('2026-02-24T11:00:00.000Z'),
            lateGraceMinutes: 5,
          }),
        ],
      ]),
    );
    participantMetricsByShift.set('shift_2', new Map());

    const report = __test__.computeStudentAttendanceReport({
      studentId: 'student_1',
      periodType: 'weekly',
      periodStart,
      periodEnd,
      shifts,
      participantMetricsByShift,
      lateGraceMinutes: 5,
    });

    expect(report.metrics.scheduled_classes).toBe(2);
    expect(report.metrics.attended_classes).toBe(1);
    expect(report.metrics.absent_classes).toBe(1);
    expect(report.metrics.late_classes).toBe(1);
    expect(report.metrics.student_present_teacher_absent_classes).toBe(1);
    expect(report.rates.attendance_rate).toBeCloseTo(0.5, 5);
    expect(report.rates.late_rate).toBeCloseTo(1.0, 5);
  });

  test('missingStateForShift detects teacher, student, and both no-shows', () => {
    const shift = {
      id: 'shift_1',
      teacherId: 'teacher_1',
      studentIds: ['student_1', 'student_2'],
      shiftStart: new Date('2026-02-24T10:00:00.000Z'),
      shiftEnd: new Date('2026-02-24T11:00:00.000Z'),
      status: 'scheduled',
    };
    const teacherPresent = __test__.computeParticipantPresenceMetrics({
      sessionData: {
        presence_windows: [
          {
            join_at: new Date('2026-02-24T10:00:00.000Z'),
            leave_at: null,
          },
        ],
      },
      shiftStart: shift.shiftStart,
      shiftEnd: shift.shiftEnd,
    });
    const studentPresent = __test__.computeParticipantPresenceMetrics({
      sessionData: {
        presence_windows: [
          {
            join_at: new Date('2026-02-24T10:01:00.000Z'),
            leave_at: null,
          },
        ],
      },
      shiftStart: shift.shiftStart,
      shiftEnd: shift.shiftEnd,
    });

    expect(__test__.missingStateForShift({
      shift,
      metricsForShift: new Map([
        ['teacher_1', teacherPresent],
        ['student_1', studentPresent],
      ]),
    })).toBeNull();
    expect(__test__.missingStateForShift({
      shift,
      metricsForShift: new Map([['student_1', studentPresent]]),
    })).toBe('teacher');
    expect(__test__.missingStateForShift({
      shift,
      metricsForShift: new Map([['teacher_1', teacherPresent]]),
    })).toBe('students');
    expect(__test__.missingStateForShift({
      shift,
      metricsForShift: new Map(),
    })).toBe('both');
  });

  test('buildClassAttendanceAlertData matches the no-show admin screen schema', () => {
    const shift = {
      id: 'shift_1',
      teacherId: 'teacher_1',
      teacherName: 'Teacher One',
      studentIds: ['student_1'],
      studentNames: ['Student One'],
      shiftStart: new Date('2026-02-24T10:00:00.000Z'),
      shiftEnd: new Date('2026-02-24T11:00:00.000Z'),
      subjectName: 'Quran',
      className: 'Teacher One - Quran - Student One',
      videoProvider: 'zoom',
    };

    const alert = __test__.buildClassAttendanceAlertData({
      shift,
      missing: 'both',
      now: new Date('2026-02-24T10:06:00.000Z'),
    });

    expect(alert.shift_id).toBe('shift_1');
    expect(alert.class_name).toBe('Teacher One - Quran - Student One');
    expect(alert.teacher_id).toBe('teacher_1');
    expect(alert.student_ids).toEqual(['student_1']);
    expect(alert.missing).toBe('both');
    expect(alert.provider).toBe('zoom');
    expect(alert.minutes_since_start).toBe(6);
    expect(alert.status).toBe('pending');
    expect(alert.first_detected_at.toDate().toISOString())
      .toBe('2026-02-24T10:06:00.000Z');
  });
});
