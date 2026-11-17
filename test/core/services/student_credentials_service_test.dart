import 'package:alluwalacademyadmin/core/services/student_credentials_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Made-up values for the tests (not credentials).
const _stored = 'tiger4827';
const _legacy = 'old123';

void main() {
  group('StudentCredentialsService.pickPassword', () {
    test('the credential store wins over the legacy user-doc copy', () {
      expect(
        StudentCredentialsService.pickPassword(
          {'password': _stored},
          {'temp_password': _legacy},
        ),
        _stored,
      );
    });

    test('falls back to the legacy copy until it is migrated', () {
      expect(
        StudentCredentialsService.pickPassword(null, {'temp_password': _legacy}),
        _legacy,
      );
      expect(
        StudentCredentialsService.pickPassword(
          {'password': '  '},
          {'temp_password': _legacy},
        ),
        _legacy,
      );
    });

    test('nothing stored reads as empty, and non-text values are ignored', () {
      expect(StudentCredentialsService.pickPassword(null, const {}), '');
      expect(
        StudentCredentialsService.pickPassword(
          {'password': 42},
          {'temp_password': true},
        ),
        '',
      );
    });
  });
}
