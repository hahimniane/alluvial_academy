import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';

void main() {
  group('auditStatusFromName', () {
    test('parses known statuses', () {
      expect(auditStatusFromName('coachSubmitted'), AuditStatus.coachSubmitted);
      expect(auditStatusFromName('completed'), AuditStatus.completed);
      expect(auditStatusFromName('pending'), AuditStatus.pending);
    });

    test('returns null for unknown or empty', () {
      expect(auditStatusFromName(null), isNull);
      expect(auditStatusFromName(''), isNull);
      expect(auditStatusFromName('not_a_real_status'), isNull);
    });
  });

  group('TeacherDispute map roundtrip', () {
    test('preserves auditStatusBeforeDispute', () {
      final d = TeacherDispute(
        teacherId: 't1',
        disputedAt: DateTime.utc(2026, 3, 1),
        field: 'hours_taught',
        reason: 'Reason text here minimum length ok',
        suggestedValue: '12',
        status: 'pending',
        adminResponse: '',
        auditStatusBeforeDispute: 'completed',
      );
      final m = d.toMap();
      final back = TeacherDispute.fromMap(m);
      expect(back.auditStatusBeforeDispute, 'completed');
      expect(back.field, 'hours_taught');
    });
  });
}
