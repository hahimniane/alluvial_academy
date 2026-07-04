import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/no_show/models/no_show_report.dart';
import 'package:alluwalacademyadmin/features/no_show/services/no_show_service.dart';

NoShowReport _report({
  required String id,
  required String teacherId,
  required String teacherName,
  required bool isTeacherNoShow,
  String status = 'pending',
  DateTime? when,
}) {
  return NoShowReport.fromMap(id, {
    'shiftId': 's_$id',
    'shiftName': '$teacherName - Islamic',
    'isTeacherNoShow': isTeacherNoShow,
    'reportedBy': 'reporter_$id',
    'reporterName': 'Reporter $id',
    'teacherId': teacherId,
    'teacherName': teacherName,
    'studentNames': ['Student A', 'Student B'],
    'status': status,
    'hasDiagnostics': false,
    'timestamp': (when ?? DateTime(2026, 6, 1)).toIso8601String(),
  });
}

void main() {
  group('NoShowReport.fromMap', () {
    test('parses fields and derives helpers', () {
      final r = _report(
        id: '1',
        teacherId: 't1',
        teacherName: 'Mama Diallo',
        isTeacherNoShow: true,
        status: 'reviewed',
      );
      expect(r.id, '1');
      expect(r.shiftName, 'Mama Diallo - Islamic');
      expect(r.isTeacherNoShow, isTrue);
      expect(r.isReviewed, isTrue);
      expect(r.teacherKey, 't1');
      expect(r.studentNames, ['Student A', 'Student B']);
    });

    test('defaults status to pending and falls back teacherKey to name', () {
      final r = NoShowReport.fromMap('x', {
        'shiftName': 'Class',
        'teacherName': 'Habibu',
      });
      expect(r.status, 'pending');
      expect(r.isReviewed, isFalse);
      expect(r.teacherKey, 'Habibu');
      expect(r.isTeacherNoShow, isFalse);
      expect(r.isStudentNoShow, isTrue);
    });

    test('normalizes scheduled attendance alerts', () {
      final r = NoShowReport.fromAttendanceAlertMap('alert_1', {
        'shift_id': 'shift_1',
        'class_name': 'Ibrahim Bah - Quran - Saidou Barry',
        'teacher_id': 'teacher_1',
        'missing': 'both',
        'first_detected_at': '2026-07-01T22:06:22.443Z',
      });

      expect(r.sourceCollection, NoShowReport.attendanceAlertCollection);
      expect(r.shiftId, 'shift_1');
      expect(r.shiftName, 'Ibrahim Bah - Quran - Saidou Barry');
      expect(r.teacherName, 'Ibrahim Bah');
      expect(r.studentNames, ['Saidou Barry']);
      expect(r.isTeacherNoShow, isTrue);
      expect(r.isStudentNoShow, isTrue);
      expect(r.isReviewed, isFalse);
    });

    test('parses review metadata and copyWith updates it', () {
      final r = NoShowReport.fromAttendanceAlertMap('alert_2', {
        'shift_id': 'shift_2',
        'class_name': 'Billing Zoom Test',
        'missing': 'both',
        'status': 'reviewed',
        'reviewed_by': 'admin_1',
        'reviewed_by_name': 'Admin User',
        'reviewed_by_email': 'admin@example.com',
        'review_actions': ['contacted_teacher', 'rescheduled_class'],
        'review_action_labels': ['Contacted teacher', 'Rescheduled class'],
        'review_note': 'Teacher confirmed a connection issue.',
      });

      expect(r.isReviewed, isTrue);
      expect(r.reviewedBy, 'admin_1');
      expect(r.reviewedByName, 'Admin User');
      expect(r.reviewedByEmail, 'admin@example.com');
      expect(r.reviewActions, ['contacted_teacher', 'rescheduled_class']);
      expect(r.reviewActionLabels, ['Contacted teacher', 'Rescheduled class']);
      expect(r.reviewNote, 'Teacher confirmed a connection issue.');

      final updated = r.copyWith(
        reviewedByName: 'Second Reviewer',
        reviewActions: ['false_alarm'],
        reviewActionLabels: ['False alarm/no action needed'],
        reviewNote: 'Attendance was manually verified.',
      );

      expect(updated.reviewedByName, 'Second Reviewer');
      expect(updated.reviewActions, ['false_alarm']);
      expect(updated.reviewActionLabels, ['False alarm/no action needed']);
      expect(updated.reviewNote, 'Attendance was manually verified.');
    });
  });

  group('computeTeacherPatterns', () {
    test('aggregates per teacher and ranks by teacher no-shows', () {
      final reports = [
        _report(
            id: '1', teacherId: 't1', teacherName: 'A', isTeacherNoShow: true),
        _report(
            id: '2', teacherId: 't1', teacherName: 'A', isTeacherNoShow: true),
        _report(
            id: '3', teacherId: 't1', teacherName: 'A', isTeacherNoShow: false),
        _report(
            id: '4',
            teacherId: 't2',
            teacherName: 'B',
            isTeacherNoShow: true,
            status: 'reviewed'),
        _report(
            id: '5', teacherId: 't2', teacherName: 'B', isTeacherNoShow: false),
      ];

      final patterns = NoShowService.computeTeacherPatterns(reports);

      expect(patterns.length, 2);
      // A has 2 teacher no-shows, B has 1 -> A ranks first.
      expect(patterns.first.teacherKey, 't1');
      expect(patterns.first.total, 3);
      expect(patterns.first.teacherNoShows, 2);
      expect(patterns.first.studentNoShows, 1);
      expect(patterns.first.pending, 3);

      final b = patterns[1];
      expect(b.teacherKey, 't2');
      expect(b.teacherNoShows, 1);
      expect(b.pending, 1); // one of B's two is reviewed
    });

    test('tracks the latest occurrence per teacher', () {
      final reports = [
        _report(
            id: '1',
            teacherId: 't1',
            teacherName: 'A',
            isTeacherNoShow: true,
            when: DateTime(2026, 1, 1)),
        _report(
            id: '2',
            teacherId: 't1',
            teacherName: 'A',
            isTeacherNoShow: true,
            when: DateTime(2026, 3, 15)),
      ];
      final patterns = NoShowService.computeTeacherPatterns(reports);
      expect(patterns.single.lastOccurred, DateTime(2026, 3, 15));
    });

    test('counts both-missing alerts in teacher and student buckets', () {
      final reports = [
        NoShowReport.fromAttendanceAlertMap('1', {
          'teacher_id': 't1',
          'class_name': 'A - Quran - Student A',
          'missing': 'both',
        }),
      ];

      final patterns = NoShowService.computeTeacherPatterns(reports);
      expect(patterns.single.teacherNoShows, 1);
      expect(patterns.single.studentNoShows, 1);
    });

    test('ignores reports with no teacher key', () {
      final reports = [
        NoShowReport.fromMap('z', {'shiftName': 'C', 'isTeacherNoShow': true}),
      ];
      expect(NoShowService.computeTeacherPatterns(reports), isEmpty);
    });
  });
}
