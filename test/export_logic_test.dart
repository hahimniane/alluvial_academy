import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('Export Logic Tests', () {
    test('Weekly and Monthly Aggregation Logic', () {
      // Mock Data
      final entries = [
        {
          'teacher': 'Teacher A',
          'date': DateTime(2025, 11, 3), // Monday
          'amount': 100.0
        },
        {
          'teacher': 'Teacher A',
          'date': DateTime(2025, 11, 4), // Tuesday
          'amount': 50.0
        },
        {
          'teacher': 'Teacher B',
          'date': DateTime(2025, 11, 3), // Monday
          'amount': 200.0
        },
        {
          'teacher': 'Teacher A',
          'date': DateTime(2025, 12, 1), // December
          'amount': 300.0
        },
      ];

      // Aggregation Maps
      final Map<String, double> weeklyEarnings = {};
      final Map<String, double> monthlyEarnings = {};

      for (var entry in entries) {
        final teacher = entry['teacher'] as String;
        final date = entry['date'] as DateTime;
        final amount = entry['amount'] as double;

        // Week Start (Monday)
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final weekStartKey = DateFormat('yyyy-MM-dd').format(weekStart);
        final weeklyKey = '$teacher|$weekStartKey';

        // Month Start
        final monthStart = DateTime(date.year, date.month, 1);
        final monthStartKey = DateFormat('yyyy-MM-dd').format(monthStart);
        final monthlyKey = '$teacher|$monthStartKey';

        weeklyEarnings[weeklyKey] = (weeklyEarnings[weeklyKey] ?? 0.0) + amount;
        monthlyEarnings[monthlyKey] =
            (monthlyEarnings[monthlyKey] ?? 0.0) + amount;
      }

      // Verify Weekly Aggregation
      // Teacher A, Week of Nov 3: 100 + 50 = 150
      expect(weeklyEarnings['Teacher A|2025-11-03'], 150.0);
      // Teacher B, Week of Nov 3: 200
      expect(weeklyEarnings['Teacher B|2025-11-03'], 200.0);
      // Teacher A, Week of Dec 1 (Dec 1 is Monday in 2025): 300
      expect(weeklyEarnings['Teacher A|2025-12-01'], 300.0);

      // Verify Monthly Aggregation
      // Teacher A, Nov: 150
      expect(monthlyEarnings['Teacher A|2025-11-01'], 150.0);
      // Teacher B, Nov: 200
      expect(monthlyEarnings['Teacher B|2025-11-01'], 200.0);
      // Teacher A, Dec: 300
      expect(monthlyEarnings['Teacher A|2025-12-01'], 300.0);
    });

    test('Hour Parsing Logic', () {
      double parseHours(String timeString) {
        try {
          if (timeString.isEmpty) return 0.0;
          final sanitized = timeString
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'(hours|hour|hrs|hr)'), '')
              .trim();
          if (sanitized.isEmpty) return 0.0;
          if (!sanitized.contains(':')) {
            return double.tryParse(sanitized) ?? 0.0;
          }
          final parts = sanitized.split(':');
          if (parts.length != 2) return 0.0;
          final hours = int.tryParse(parts[0].trim()) ?? 0;
          final minutes = int.tryParse(parts[1].trim()) ?? 0;
          return hours + (minutes / 60.0);
        } catch (e) {
          return 0.0;
        }
      }

      expect(parseHours('01:30'), 1.5);
      expect(parseHours('2.5'), 2.5);
      expect(parseHours('3 hours'), 3.0);
      expect(parseHours(''), 0.0);
      expect(parseHours('invalid'), 0.0);
    });
  });
}
