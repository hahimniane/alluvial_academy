import 'package:alluwalacademyadmin/core/services/teacher_metrics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TeacherMetricsService.billableHoursForShiftClock', () {
    test('caps to scheduled duration when clock span is longer', () {
      final start = DateTime(2026, 4, 17, 10, 0);
      final end = DateTime(2026, 4, 17, 11, 0);
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(start),
        'shift_end': Timestamp.fromDate(end),
      };
      final clockIn = DateTime(2026, 4, 17, 9, 0);
      final clockOut = DateTime(2026, 4, 17, 12, 0);
      final h = TeacherMetricsService.billableHoursForShiftClock(
        shift: shift,
        clockIn: clockIn,
        clockOut: clockOut,
      );
      expect(h, closeTo(1.0, 1e-9));
    });

    test('uses clock span inside the window', () {
      final start = DateTime(2026, 4, 17, 10, 0);
      final end = DateTime(2026, 4, 17, 12, 0);
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(start),
        'shift_end': Timestamp.fromDate(end),
      };
      final clockIn = DateTime(2026, 4, 17, 10, 30);
      final clockOut = DateTime(2026, 4, 17, 11, 30);
      final h = TeacherMetricsService.billableHoursForShiftClock(
        shift: shift,
        clockIn: clockIn,
        clockOut: clockOut,
      );
      expect(h, closeTo(1.0, 1e-9));
    });
  });
}
