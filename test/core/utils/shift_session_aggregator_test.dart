import 'package:alluwalacademyadmin/core/utils/shift_session_aggregator.dart';
import 'package:alluwalacademyadmin/core/services/teacher_metrics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalShiftIdForGrouping', () {
    test('tpl_tpl_ collapses to tpl_ prefix', () {
      expect(
        ShiftSessionAggregator.canonicalShiftIdForGrouping('tpl_tpl_abc123'),
        'tpl_abc123',
      );
    });
    test('tpl_ and plain ids unchanged', () {
      expect(
        ShiftSessionAggregator.canonicalShiftIdForGrouping('tpl_xyz'),
        'tpl_xyz',
      );
      expect(
        ShiftSessionAggregator.canonicalShiftIdForGrouping('someId'),
        'someId',
      );
    });
  });

  group('ShiftSessionAggregator clock segments', () {
    late Map<String, dynamic> shift;

    setUp(() {
      final start = DateTime(2026, 4, 17, 9, 0);
      final end = DateTime(2026, 4, 17, 10, 0);
      shift = {
        'shift_start': Timestamp.fromDate(start),
        'shift_end': Timestamp.fromDate(end),
        'hourly_rate': 60.0,
      };
    });

    test(
        'touching clock-out then clock-in: both segments sum to scheduled hour',
        () {
      final ts1 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 47)),
        'status': 'approved',
      };
      final ts2 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 47)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'approved',
      };
      final r = ShiftSessionAggregator.computeSession(shift, [ts1, ts2], []);
      expect(r.workedHours, closeTo(1.0, 1e-6));
      expect(r.realPay, closeTo(60.0, 1e-6));
    });

    test('one-minute gap between segments: minutes add, not max of one row',
        () {
      final ts1 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 47)),
        'status': 'approved',
      };
      final ts2 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 48)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'approved',
      };
      final r = ShiftSessionAggregator.computeSession(shift, [ts1, ts2], []);
      expect(r.workedHours, closeTo(59 / 60.0, 1e-6));
    });

    test(
        'heavy overlap: one group keeps single survivor (duplicate-style rows)',
        () {
      final ts1 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'approved',
      };
      final ts2 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 5)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 55)),
        'status': 'approved',
      };
      final r = ShiftSessionAggregator.computeSession(shift, [ts1, ts2], []);
      expect(r.workedHours, closeTo(1.0, 1e-6));
    });

    test('non-overlapping segments are capped to scheduled shift duration', () {
      final ts1 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 50)),
        'status': 'approved',
      };
      final ts2 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 50)),
        'clock_out_timestamp':
            Timestamp.fromDate(DateTime(2026, 4, 17, 10, 20)),
        'status': 'approved',
      };
      final r = ShiftSessionAggregator.computeSession(shift, [ts1, ts2], []);
      expect(r.workedHours, closeTo(1.0, 1e-6));
      expect(r.realPay, closeTo(60.0, 1e-6));
    });
  });

  group('ShiftSessionAggregator pay buckets', () {
    late Map<String, dynamic> shift;

    setUp(() {
      final start = DateTime(2026, 4, 17, 9, 0);
      final end = DateTime(2026, 4, 17, 10, 0);
      shift = {
        'shift_start': Timestamp.fromDate(start),
        'shift_end': Timestamp.fromDate(end),
        'hourly_rate': 60.0,
      };
    });

    test('paid status accumulates into payPaid', () {
      final ts = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'paid',
      };
      final r = ShiftSessionAggregator.computeSession(shift, [ts], []);
      expect(r.payPaid, closeTo(60.0, 1e-6));
      expect(r.payApproved, closeTo(0.0, 1e-6));
      expect(r.payPending, closeTo(0.0, 1e-6));
      expect(
          r.payPaid + r.payApproved + r.payPending, closeTo(r.realPay, 1e-6));
    });

    test('approved status accumulates into payApproved', () {
      final ts = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'approved',
      };
      final r = ShiftSessionAggregator.computeSession(shift, [ts], []);
      expect(r.payApproved, closeTo(60.0, 1e-6));
      expect(r.payPaid, closeTo(0.0, 1e-6));
      expect(r.payPending, closeTo(0.0, 1e-6));
    });

    test('pending status accumulates into payPending', () {
      final ts = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'pending',
      };
      final r = ShiftSessionAggregator.computeSession(shift, [ts], []);
      expect(r.payPending, closeTo(60.0, 1e-6));
      expect(r.payPaid, closeTo(0.0, 1e-6));
      expect(r.payApproved, closeTo(0.0, 1e-6));
    });

    test('proportional cap-down when realPay exceeds scheduled * rate', () {
      final ts1 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 30)),
        'status': 'paid',
        'payment_amount': 60.0,
      };
      final ts2 = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 30)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'pending',
        'payment_amount': 60.0,
      };
      final r = ShiftSessionAggregator.computeSession(shift, [ts1, ts2], []);
      expect(r.realPay, closeTo(60.0, 1e-6));
      expect(r.payPaid + r.payApproved + r.payPending, closeTo(60.0, 1e-6));
      expect(r.payPaid, closeTo(30.0, 1e-6));
      expect(r.payPending, closeTo(30.0, 1e-6));
    });

    test('form-only path puts pay into payPending', () {
      final formShift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'shift_end': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'hourly_rate': 60.0,
        'form_completed': true,
      };
      final form = <String, dynamic>{
        'durationHours': 1.0,
      };
      final r = ShiftSessionAggregator.computeSession(formShift, [], [form]);
      expect(r.workedHours, closeTo(1.0, 1e-6));
      expect(r.realPay, closeTo(60.0, 1e-6));
      expect(r.payPending, closeTo(60.0, 1e-6));
      expect(r.payPaid, closeTo(0.0, 1e-6));
      expect(r.payApproved, closeTo(0.0, 1e-6));
    });
  });

  group('ShiftSessionAggregator.workedMinutesCeil', () {
    test('rounds up partial minute', () {
      const r = ShiftSessionResult(
        workedHours: 0.508333, // 30 minutes 30 seconds
        realPay: 0.0,
        payPaid: 0.0,
        payApproved: 0.0,
        payPending: 0.0,
        hasPunchedTimesheets: true,
        hasForm: false,
      );
      expect(ShiftSessionAggregator.workedMinutesCeil(r), 31);
    });

    test('exact minute boundary stays exact', () {
      const r = ShiftSessionResult(
        workedHours: 1.0,
        realPay: 0.0,
        payPaid: 0.0,
        payApproved: 0.0,
        payPending: 0.0,
        hasPunchedTimesheets: true,
        hasForm: false,
      );
      expect(ShiftSessionAggregator.workedMinutesCeil(r), 60);
    });

    test('zero hours yields zero minutes', () {
      const r = ShiftSessionResult.empty;
      expect(ShiftSessionAggregator.workedMinutesCeil(r), 0);
    });
  });

  group('TeacherMetricsService monthly pay parity', () {
    test('missing shift rate uses subject rate in the shared monthly engine',
        () {
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'shift_end': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'subject': 'Quran',
      };
      final ts = <String, dynamic>{
        'shift_id': 'shift-a',
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'approved',
      };

      final live = TeacherMetricsService.computeMonthlyPayForTeacher(
        shifts: [MapEntry('shift-a', shift)],
        timesheets: [ts],
        forms: const [],
        subjectHourlyRatesByName: const {'quran': 5.0},
      );
      final audit = TeacherMetricsService.computeMonthlyPayForTeacher(
        shifts: [MapEntry('shift-a', shift)],
        timesheets: [ts],
        forms: const [],
        subjectHourlyRatesByName: const {'quran': 5.0},
      );

      expect(live.payProjected, closeTo(5.0, 1e-6));
      expect(live.payProjected, closeTo(audit.totalFinalPay, 1e-6));
    });

    test('manual shift adjustment is the only gross divergence', () {
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'shift_end': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'hourly_rate': 5.0,
      };
      final ts = <String, dynamic>{
        'shift_id': 'shift-a',
        'clock_in_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'clock_out_timestamp': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'status': 'approved',
      };

      final live = TeacherMetricsService.computeMonthlyPayForTeacher(
        shifts: [MapEntry('shift-a', shift)],
        timesheets: [ts],
        forms: const [],
      );
      final adjustedAudit = TeacherMetricsService.computeMonthlyPayForTeacher(
        shifts: [MapEntry('shift-a', shift)],
        timesheets: [ts],
        forms: const [],
        shiftPaymentAdjustments: const {'shift-a': -1.0},
      );

      expect(live.payProjected, closeTo(5.0, 1e-6));
      expect(adjustedAudit.totalFinalPay, closeTo(4.0, 1e-6));
    });
  });

  group('makeup form-only gate', () {
    test('pending without attestation is zero economics', () {
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'shift_end': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'hourly_rate': 60.0,
      };
      final form = <String, dynamic>{
        'durationHours': 1.0,
        'makeupApprovalStatus': 'pending',
        'responses': <String, dynamic>{},
      };
      final r = ShiftSessionAggregator.computeSession(shift, [], [form]);
      expect(r.workedHours, 0.0);
      expect(r.realPay, 0.0);
    });

    test('pending with attestation pays', () {
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'shift_end': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'hourly_rate': 60.0,
      };
      final form = <String, dynamic>{
        'durationHours': 1.0,
        'makeupApprovalStatus': 'pending',
        'responses': <String, dynamic>{
          'makeup_occurred_at': '2026-04-18',
          'makeup_start_time': '10',
          'makeup_end_time': '11',
          'makeup_delivery_mode': 'zoom',
          'makeup_zoom_host': 'teacher@example.com',
          'makeup_students_present': 'x',
        },
      };
      final r = ShiftSessionAggregator.computeSession(shift, [], [form]);
      expect(r.workedHours, closeTo(1.0, 1e-6));
      expect(r.realPay, closeTo(60.0, 1e-6));
    });

    test('pending with other mode requires detail', () {
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'shift_end': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'hourly_rate': 60.0,
      };
      final formBad = <String, dynamic>{
        'durationHours': 1.0,
        'makeupApprovalStatus': 'pending',
        'responses': <String, dynamic>{
          'makeup_occurred_at': '2026-04-18',
          'makeup_start_time': '10',
          'makeup_end_time': '11',
          'makeup_delivery_mode': 'other',
          'makeup_students_present': 'x',
        },
      };
      final bad = ShiftSessionAggregator.computeSession(shift, [], [formBad]);
      expect(bad.workedHours, 0.0);

      final formOk = <String, dynamic>{
        'durationHours': 1.0,
        'makeupApprovalStatus': 'pending',
        'responses': <String, dynamic>{
          'makeup_occurred_at': '2026-04-18',
          'makeup_start_time': '10',
          'makeup_end_time': '11',
          'makeup_delivery_mode': 'other',
          'makeup_other_detail': 'Google Meet',
          'makeup_students_present': 'x',
        },
      };
      final ok = ShiftSessionAggregator.computeSession(shift, [], [formOk]);
      expect(ok.workedHours, closeTo(1.0, 1e-6));
    });

    test('legacy in_person attestation with location still pays', () {
      final shift = <String, dynamic>{
        'shift_start': Timestamp.fromDate(DateTime(2026, 4, 17, 9, 0)),
        'shift_end': Timestamp.fromDate(DateTime(2026, 4, 17, 10, 0)),
        'hourly_rate': 60.0,
      };
      final form = <String, dynamic>{
        'durationHours': 1.0,
        'makeupApprovalStatus': 'pending',
        'responses': <String, dynamic>{
          'makeup_occurred_at': '2026-04-18',
          'makeup_location': 'Room A',
          'makeup_start_time': '10',
          'makeup_end_time': '11',
          'makeup_delivery_mode': 'in_person',
          'makeup_students_present': 'x',
        },
      };
      final r = ShiftSessionAggregator.computeSession(shift, [], [form]);
      expect(r.workedHours, closeTo(1.0, 1e-6));
    });
  });
}
