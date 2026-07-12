import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/dashboard/models/job_opportunity.dart';

JobOpportunity _job({List<String>? targetTeacherIds}) {
  return JobOpportunity(
    id: 'job1',
    enrollmentId: 'enr1',
    studentName: 'Student',
    studentAge: '10',
    subject: 'quran',
    gradeLevel: 'Beginner',
    days: const ['Monday'],
    timeSlots: const ['5:00 PM - 6:00 PM'],
    timeZone: 'UTC',
    status: 'open',
    createdAt: DateTime(2026, 7, 1),
    targetTeacherIds: targetTeacherIds,
  );
}

void main() {
  group('JobOpportunity.isVisibleToTeacher', () {
    test('job without targeting is visible to every teacher', () {
      expect(_job().isVisibleToTeacher('teacherA'), isTrue);
      expect(_job(targetTeacherIds: []).isVisibleToTeacher('teacherA'), isTrue);
    });

    test('targeted job is visible only to targeted teachers', () {
      final job = _job(targetTeacherIds: ['teacherA', 'teacherB']);
      expect(job.isVisibleToTeacher('teacherA'), isTrue);
      expect(job.isVisibleToTeacher('teacherB'), isTrue);
      expect(job.isVisibleToTeacher('teacherC'), isFalse);
    });
  });

  group('JobOpportunity.toMap targeting fields', () {
    test('omits targeting fields when not set', () {
      final map = _job().toMap();
      expect(map.containsKey('targetTeacherIds'), isFalse);
      expect(map.containsKey('targetTeacherNames'), isFalse);
    });

    test('includes targetTeacherIds when set', () {
      final map = _job(targetTeacherIds: ['teacherA']).toMap();
      expect(map['targetTeacherIds'], ['teacherA']);
    });
  });
}
