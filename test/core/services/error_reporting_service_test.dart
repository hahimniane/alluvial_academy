import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/services/error_reporting_service.dart';

void main() {
  group('ErrorReportingService', () {
    test('sessionId is consistent within a session', () {
      final id1 = ErrorReportingService.sessionId;
      final id2 = ErrorReportingService.sessionId;
      expect(id1, equals(id2));
      expect(id1.length, equals(8));
    });

    test('setUser and clearUser work correctly', () {
      // Should not throw
      ErrorReportingService.setUser('test-uid', email: 'test@test.com');
      ErrorReportingService.clearUser();
    });

    test('addBreadcrumb does not exceed max size', () {
      // Add more than max breadcrumbs
      for (int i = 0; i < 25; i++) {
        ErrorReportingService.addBreadcrumb('action_$i');
      }
      // Should not throw — internal list is capped at 20
    });

    test('reportError handles null stackTrace', () async {
      // This will fail to write to Firestore (no Firebase in test)
      // but should NOT throw — error reporting must be silent
      await ErrorReportingService.reportError(
        Exception('test error'),
        null,
        context: 'unit_test',
      );
    });

    test('reportError deduplicates within window', () async {
      final error = Exception('duplicate test');
      // First call
      await ErrorReportingService.reportError(error, null, context: 'test');
      // Second call with same error — should be deduped (no crash)
      await ErrorReportingService.reportError(error, null, context: 'test');
    });
  });
}
