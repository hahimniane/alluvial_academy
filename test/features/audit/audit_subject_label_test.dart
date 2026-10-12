import 'package:alluwalacademyadmin/features/audit/services/teacher_audit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auditSubjectLabel', () {
    test('prefers the display name over the raw subject', () {
      expect(
        auditSubjectLabel({'subject': 'other', 'subject_display_name': 'Tutoring'}),
        'Tutoring',
      );
    });

    test('falls back to the raw subject', () {
      expect(auditSubjectLabel({'subject': 'islamic'}), 'islamic');
    });

    test('a blank subject never becomes an empty map key', () {
      expect(auditSubjectLabel({'subject': ''}), 'Other');
      expect(auditSubjectLabel({'subject': '  ', 'subject_display_name': ''}), 'Other');
      expect(auditSubjectLabel({'subject': null}), 'Other');
      expect(auditSubjectLabel({}), 'Other');
    });

    test('trims surrounding whitespace', () {
      expect(auditSubjectLabel({'subject_display_name': ' Quran Studies '}), 'Quran Studies');
    });
  });
}
