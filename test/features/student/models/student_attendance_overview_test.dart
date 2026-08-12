import 'package:alluwalacademyadmin/features/student/models/student_attendance_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses student attendance overview totals and rows', () {
    final overview = StudentAttendanceOverview.fromMap({
      'period_type': 'weekly',
      'period_start': '2026-07-06T00:00:00.000Z',
      'period_end': '2026-07-13T00:00:00.000Z',
      'totals': {
        'total_presence_minutes': 105,
        'scheduled_classes': 4,
        'attended_classes': 3,
        'absent_classes': 1,
        'late_classes': 1,
        'attendance_rate': 0.75,
      },
      'students': [
        {
          'student_id': 'student_1',
          'student_name': 'Amina Bah',
          'student_email': 'amina@example.com',
          'student_phone': '+224 622 123 456',
          'total_presence_minutes': 75,
          'total_teacher_overlap_minutes': 60,
          'scheduled_classes': 2,
          'attended_classes': 2,
          'absent_classes': 0,
          'late_classes': 1,
          'attendance_rate': 1,
          'punctuality_rate': 0.5,
        },
      ],
    });

    expect(overview.periodType, 'weekly');
    expect(overview.periodStart, DateTime.utc(2026, 7, 6));
    expect(overview.periodEnd, DateTime.utc(2026, 7, 13));
    expect(overview.totals.totalPresenceMinutes, 105);
    expect(overview.totals.attendanceRate, 0.75);
    expect(overview.students, hasLength(1));
    expect(overview.students.single.studentName, 'Amina Bah');
    expect(overview.students.single.studentPhone, '+224 622 123 456');
    expect(overview.students.single.totalPresenceMinutes, 75);
    expect(overview.students.single.lateClasses, 1);
  });
}
