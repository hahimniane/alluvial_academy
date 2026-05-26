import 'package:alluwalacademyadmin/features/audit/services/admin_submissions_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminSubmissionsExportService (export helpers)', () {
    test('sanitizeExcelSheetName is case-insensitive vs existing sheets', () {
      final second = AdminSubmissionsExportService.debugSanitizeExcelSheetName(
        'DAILY REPORT',
        ['Daily Report'],
      );
      expect(second, isNot('DAILY REPORT'));
      expect(second.contains('_1'), isTrue);
    });

    test('sanitizeExcelSheetName strips forbidden characters', () {
      final name = AdminSubmissionsExportService.debugSanitizeExcelSheetName(
        r'a/b:c*d?[x]\y',
        [],
      );
      expect(name.contains('/'), isFalse);
      expect(name.contains(':'), isFalse);
      expect(name.contains('?'), isFalse);
      expect(name.contains('*'), isFalse);
      expect(name.contains('['), isFalse);
      expect(name.contains(']'), isFalse);
    });

    test('resolveShiftId includes linkedShiftId fields', () {
      expect(
        AdminSubmissionsExportService.debugResolveShiftIdForExport({
          'linkedShiftId': 'shift_123',
        }),
        'shift_123',
      );
      expect(
        AdminSubmissionsExportService.debugResolveShiftIdForExport({
          'linked_shift_id': 'shift_456',
        }),
        'shift_456',
      );
      expect(
        AdminSubmissionsExportService.debugResolveShiftIdForExport({
          'shiftId': 'a',
          'linkedShiftId': 'b',
        }),
        'a',
      );
    });

    test('formatSubmissionValue flattens nested maps', () {
      final s = AdminSubmissionsExportService.debugFormatSubmissionValue({
        'a': 1,
        'b': {'c': 2},
      });
      expect(s.contains('a: 1'), isTrue);
      expect(s.contains('c: 2'), isTrue);
      expect(s.contains(' | '), isTrue);
    });

    test('formatSubmissionValue formats list elements recursively', () {
      final s = AdminSubmissionsExportService.debugFormatSubmissionValue([
        'x',
        {'y': true},
      ]);
      expect(s.contains('x'), isTrue);
      expect(s.contains('y: Yes'), isTrue);
    });
  });
}
