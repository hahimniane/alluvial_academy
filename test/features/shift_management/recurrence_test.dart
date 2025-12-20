import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Recurrence Generation Tests', () {
    test('Should handle cross-midnight shifts correctly', () {
      // Setup: Shift from 23:00 to 01:00 (next day)
      // Duration is 2 hours
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final start = today.add(const Duration(hours: 23));
      final end = today.add(const Duration(hours: 25)); // 01:00 next day

      // Verify initial duration is positive
      expect(end.difference(start).inHours, 2);
      expect(end.isAfter(start), true);

      // Simulate the bug condition:
      // If we naively create a new shift on the next day using only time components
      // and forcing them to the same day, we get negative duration.

      final nextDay = today.add(const Duration(days: 1));

      // BUGGY LOGIC SIMULATION (What we think is happening):
      // final badEnd = DateTime(nextDay.year, nextDay.month, nextDay.day, end.hour, end.minute);
      // expect(badEnd.difference(start).inHours, -22); // This would be the bug

      // CORRECT LOGIC (What we want to implement):
      final duration = end.difference(start);
      final newStart = DateTime(
          nextDay.year, nextDay.month, nextDay.day, start.hour, start.minute);
      final newEnd = newStart.add(duration);

      expect(newEnd.difference(newStart).inHours, 2);
      expect(
          newEnd.day, nextDay.day + 1); // Should end on the day AFTER nextDay
      expect(newEnd.hour, 1);
    });
  });
}
