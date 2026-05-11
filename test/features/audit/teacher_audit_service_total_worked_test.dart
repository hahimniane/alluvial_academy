import 'package:alluwalacademyadmin/core/services/teacher_metrics_service.dart';
import 'package:alluwalacademyadmin/features/audit/services/teacher_audit_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

ShiftMetrics _baseShiftMetrics({
  required Map<String, double> hoursBySubject,
}) {
  final total = hoursBySubject.values.fold<double>(0.0, (a, b) => a + b);
  return ShiftMetrics(
    scheduled: hoursBySubject.length,
    completed: hoursBySubject.length,
    missed: 0,
    cancelled: 0,
    hoursBySubject: Map<String, double>.from(hoursBySubject),
    totalHours: total,
    detailedShifts: const [],
    paymentsByShift: const [],
    hoursScheduledBySubject: Map<String, double>.from(hoursBySubject),
    totalScheduledHours: total,
    hoursWorkedBySubject: const {},
    totalWorkedHours: 0.0,
  );
}

void main() {
  group('TeacherAuditService worked-hours override', () {
    test(
        'totalWorkedHours equals sum(monthlyPay rows workedHours) for synthetic teacher',
        () {
      final timesheetOnlyStart = DateTime.utc(2026, 4, 17, 9, 0);
      final timesheetOnlyEnd = DateTime.utc(2026, 4, 17, 10, 0);
      final formOnlyStart = DateTime.utc(2026, 4, 18, 9, 0);
      final formOnlyEnd = DateTime.utc(2026, 4, 18, 10, 0);
      final mixedStart = DateTime.utc(2026, 4, 19, 9, 0);
      final mixedEnd = DateTime.utc(2026, 4, 19, 10, 30);

      final shifts = <MapEntry<String, Map<String, dynamic>>>[
        MapEntry('shift-ts', {
          'shift_start': Timestamp.fromDate(timesheetOnlyStart),
          'shift_end': Timestamp.fromDate(timesheetOnlyEnd),
          'subject': 'Quran',
          'hourly_rate': 10.0,
          'status': 'fullyCompleted',
        }),
        MapEntry('shift-form', {
          'shift_start': Timestamp.fromDate(formOnlyStart),
          'shift_end': Timestamp.fromDate(formOnlyEnd),
          'subject': 'Arabic',
          'hourly_rate': 8.0,
          'form_completed': true,
          'status': 'missed',
        }),
        MapEntry('shift-mixed', {
          'shift_start': Timestamp.fromDate(mixedStart),
          'shift_end': Timestamp.fromDate(mixedEnd),
          'subject': 'Quran',
          'hourly_rate': 10.0,
          'form_completed': true,
          'status': 'partiallyCompleted',
        }),
      ];

      final timesheets = <Map<String, dynamic>>[
        {
          'shift_id': 'shift-ts',
          'clock_in_timestamp': Timestamp.fromDate(timesheetOnlyStart),
          'clock_out_timestamp': Timestamp.fromDate(timesheetOnlyEnd),
          'status': 'approved',
        },
        {
          'shift_id': 'shift-mixed',
          'clock_in_timestamp': Timestamp.fromDate(mixedStart),
          'clock_out_timestamp':
              Timestamp.fromDate(mixedStart.add(const Duration(minutes: 45))),
          'status': 'approved',
        },
      ];

      final forms = <Map<String, dynamic>>[
        {
          'shiftId': 'shift-form',
          'durationHours': 1.0,
          'submittedAt': Timestamp.fromDate(formOnlyEnd),
        },
        {
          'shiftId': 'shift-mixed',
          'durationHours': 1.5,
          'submittedAt': Timestamp.fromDate(mixedEnd),
        },
      ];

      final monthlyPay = TeacherMetricsService.computeMonthlyPayForTeacher(
        shifts: shifts,
        timesheets: timesheets,
        forms: forms,
      );

      // Sanity: each shift contributes a row.
      expect(monthlyPay.rows.length, 3);

      final base = _baseShiftMetrics(hoursBySubject: {
        'Quran': 2.5, // scheduled total Quran hours
        'Arabic': 1.0,
      });

      final overridden = TeacherAuditService.debugWithWorkedHoursFromMonthlyPay(
          base, monthlyPay);

      final expectedTotal = monthlyPay.rows
          .fold<double>(0.0, (acc, row) => acc + row.workedHours);

      expect(overridden.totalWorkedHours, closeTo(expectedTotal, 1e-9));

      // Per-subject parity: sum rows per subject equals override map.
      final expectedBySubject = <String, double>{};
      for (final row in monthlyPay.rows) {
        expectedBySubject[row.subject] =
            (expectedBySubject[row.subject] ?? 0.0) + row.workedHours;
      }
      for (final entry in expectedBySubject.entries) {
        expect(
          overridden.hoursWorkedBySubject[entry.key],
          closeTo(entry.value, 1e-9),
          reason: 'subject ${entry.key} should match aggregator sum',
        );
      }

      // Scheduled fields are untouched: totalScheduledHours == base scheduled.
      expect(overridden.totalScheduledHours,
          closeTo(base.totalScheduledHours, 1e-9));
      expect(overridden.hoursScheduledBySubject, base.hoursScheduledBySubject);
    });

    test('empty monthlyPay yields zero worked hours', () {
      final monthlyPay = TeacherMetricsService.computeMonthlyPayForTeacher(
        shifts: const [],
        timesheets: const [],
        forms: const [],
      );
      final base = _baseShiftMetrics(hoursBySubject: const {'Quran': 1.0});
      final overridden = TeacherAuditService.debugWithWorkedHoursFromMonthlyPay(
          base, monthlyPay);
      expect(overridden.totalWorkedHours, 0.0);
      expect(overridden.hoursWorkedBySubject, isEmpty);
      // Scheduled fields preserved.
      expect(overridden.totalScheduledHours, 1.0);
    });
  });
}
