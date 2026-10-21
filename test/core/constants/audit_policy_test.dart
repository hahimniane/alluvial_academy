import 'package:alluwalacademyadmin/core/constants/audit_policy.dart';
import 'package:alluwalacademyadmin/core/utils/shift_session_aggregator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditPolicyConstants cutoff (midnight New York, 2026-11-01)', () {
    test('cutoff instant is 04:00 UTC (EDT)', () {
      expect(AuditPolicyConstants.strictClockPolicyCutoffUtc.toUtc(),
          DateTime.utc(2026, 11, 1, 4));
    });

    test('Oct 31 evening in New York keeps the old rules', () {
      // Oct 31 8 PM ET and 11:30 PM ET.
      expect(
          AuditPolicyConstants.isShiftAfterStrictPolicy(
              DateTime.utc(2026, 11, 1, 0)),
          isFalse);
      expect(
          AuditPolicyConstants.isShiftAfterStrictPolicy(
              DateTime.utc(2026, 11, 1, 3, 30)),
          isFalse);
    });

    test('Nov 1 from midnight in New York is strict', () {
      expect(
          AuditPolicyConstants.isShiftAfterStrictPolicy(
              DateTime.utc(2026, 11, 1, 4)),
          isTrue);
      expect(
          AuditPolicyConstants.isShiftAfterStrictPolicy(
              DateTime.utc(2026, 11, 1, 4, 30)),
          isTrue);
    });

    test('yearMonth helper', () {
      expect(AuditPolicyConstants.isYearMonthAfterStrictPolicy('2026-10'),
          isFalse);
      expect(AuditPolicyConstants.isYearMonthAfterStrictPolicy('2026-11'),
          isTrue);
      expect(AuditPolicyConstants.isYearMonthAfterStrictPolicy(null), isFalse);
    });
  });

  group('ShiftSessionAggregator at the cutoff', () {
    Map<String, dynamic> attestedForm(String day) => <String, dynamic>{
          'durationHours': 1.0,
          'makeupApprovalStatus': 'approved',
          'responses': <String, dynamic>{
            'makeup_occurred_at': day,
            'makeup_start_time': '09:00',
            'makeup_end_time': '10:00',
            'makeup_delivery_mode': 'zoom',
            'makeup_zoom_host': 'teacher',
            'makeup_students_present': 'Student A',
          },
        };

    test('a class at Oct 31 11:30 PM ET keeps the form-only rules', () {
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 3, 30)),
        'shift_end': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 4, 30)),
        'hourly_rate': 60.0,
      };
      final r = ShiftSessionAggregator.computeSession(
          shift, [], [attestedForm('2026-10-31')]);
      expect(r.workedHours, closeTo(1.0, 1e-6));
    });

    test('a class at Nov 1 12:30 AM ET pays nothing on a form alone', () {
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 4, 30)),
        'shift_end': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 5, 30)),
        'hourly_rate': 60.0,
      };
      final r = ShiftSessionAggregator.computeSession(
          shift, [], [attestedForm('2026-11-01')]);
      expect(r.workedHours, closeTo(0.0, 1e-6));
      expect(r.realPay, closeTo(0.0, 1e-6));
      expect(r.hasForm, isTrue);
    });
  });
}
