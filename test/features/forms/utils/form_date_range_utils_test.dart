import 'package:alluwalacademyadmin/features/forms/utils/form_date_range_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('form date range utils', () {
    test('same-day range expands to full day', () {
      final range = DateTimeRange(
        start: DateTime(2026, 3, 7),
        end: DateTime(2026, 3, 7),
      );

      final start = rangeStartTimestamp(range)!.toDate();
      final end = rangeEndTimestamp(range)!.toDate();

      expect(start, DateTime(2026, 3, 7, 0, 0, 0));
      expect(end.year, 2026);
      expect(end.month, 3);
      expect(end.day, 7);
      expect(end.hour, 23);
      expect(end.minute, 59);
      expect(end.second, 59);
    });

    test('multi-day range keeps inclusive end of last day', () {
      final range = DateTimeRange(
        start: DateTime(2026, 3, 7),
        end: DateTime(2026, 3, 9),
      );

      final end = rangeEndTimestamp(range)!.toDate();
      expect(end.year, 2026);
      expect(end.month, 3);
      expect(end.day, 9);
      expect(end.hour, 23);
      expect(end.minute, 59);
    });
  });
}
