import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TeacherAuditFull.teacherUidFromStoredAudit', () {
    test('prefers userId when both fields exist', () {
      expect(
        TeacherAuditFull.teacherUidFromStoredAudit(
          {'userId': 'uidA', 'oderId': 'uidB'},
          'ignored_id',
        ),
        'uidA',
      );
    });

    test('falls back to oderId when userId missing', () {
      expect(
        TeacherAuditFull.teacherUidFromStoredAudit(
          {'oderId': 'coachDocOnly'},
          'x_2026-01',
        ),
        'coachDocOnly',
      );
    });

    test('parses uid from standard doc id when both fields missing', () {
      expect(
        TeacherAuditFull.teacherUidFromStoredAudit(
          const {},
          'abc123xyz_2026-05',
        ),
        'abc123xyz',
      );
    });
  });
}
