/**
 * Parity test: the JS aggregator must produce the same numbers as the Dart
 * aggregator for the same inputs. The fixtures here are the Jest twins of the
 * cases in test/core/utils/shift_session_aggregator_test.dart.
 *
 * Tolerance is 1e-6 so any algorithmic divergence (operator order, rounding)
 * shows up immediately.
 */

const {computeSession, workedMinutesCeil} = require('../utils/shiftSessionAggregator');

const ts = (d) => ({toDate: () => d});

const baseShift = () => ({
  shift_start: ts(new Date('2026-04-17T09:00:00Z')),
  shift_end: ts(new Date('2026-04-17T10:00:00Z')),
  hourly_rate: 60.0,
});

const closeTo = (actual, expected, eps = 1e-6) => {
  expect(Math.abs(actual - expected)).toBeLessThanOrEqual(eps);
};

describe('shiftSessionAggregator clock segments', () => {
  test('touching clock-out then clock-in segments sum to scheduled hour', () => {
    const r = computeSession(baseShift(), [
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:00:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T09:47:00Z')),
        status: 'approved',
      },
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:47:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T10:00:00Z')),
        status: 'approved',
      },
    ]);
    closeTo(r.workedHours, 1.0);
    closeTo(r.realPay, 60.0);
  });

  test('one-minute gap: minutes add, not max of one row', () => {
    const r = computeSession(baseShift(), [
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:00:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T09:47:00Z')),
        status: 'approved',
      },
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:48:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T10:00:00Z')),
        status: 'approved',
      },
    ]);
    closeTo(r.workedHours, 59 / 60);
  });

  test('heavy overlap: duplicate-style rows reduce to one survivor', () => {
    const r = computeSession(baseShift(), [
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:00:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T10:00:00Z')),
        status: 'approved',
      },
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:05:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T09:55:00Z')),
        status: 'approved',
      },
    ]);
    closeTo(r.workedHours, 1.0);
  });

  test('non-overlapping segments cap at scheduled', () => {
    const r = computeSession(baseShift(), [
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:00:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T09:50:00Z')),
        status: 'approved',
      },
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:50:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T10:20:00Z')),
        status: 'approved',
      },
    ]);
    closeTo(r.workedHours, 1.0);
    closeTo(r.realPay, 60.0);
  });
});

describe('shiftSessionAggregator pay buckets', () => {
  test('paid status accumulates into payPaid', () => {
    const r = computeSession(baseShift(), [
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:00:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T10:00:00Z')),
        status: 'paid',
      },
    ]);
    closeTo(r.payPaid, 60.0);
    closeTo(r.payApproved, 0.0);
    closeTo(r.payPending, 0.0);
    closeTo(r.payPaid + r.payApproved + r.payPending, r.realPay);
  });

  test('approved status accumulates into payApproved', () => {
    const r = computeSession(baseShift(), [
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:00:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T10:00:00Z')),
        status: 'approved',
      },
    ]);
    closeTo(r.payApproved, 60.0);
    closeTo(r.payPaid, 0.0);
    closeTo(r.payPending, 0.0);
  });

  test('pending status accumulates into payPending', () => {
    const r = computeSession(baseShift(), [
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:00:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T10:00:00Z')),
        status: 'pending',
      },
    ]);
    closeTo(r.payPending, 60.0);
    closeTo(r.payPaid, 0.0);
    closeTo(r.payApproved, 0.0);
  });

  test('proportional cap-down when realPay exceeds scheduled * rate', () => {
    const r = computeSession(baseShift(), [
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:00:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T09:30:00Z')),
        status: 'paid',
        payment_amount: 60.0,
      },
      {
        clock_in_timestamp: ts(new Date('2026-04-17T09:30:00Z')),
        clock_out_timestamp: ts(new Date('2026-04-17T10:00:00Z')),
        status: 'pending',
        payment_amount: 60.0,
      },
    ]);
    closeTo(r.realPay, 60.0);
    closeTo(r.payPaid + r.payApproved + r.payPending, 60.0);
    closeTo(r.payPaid, 30.0);
    closeTo(r.payPending, 30.0);
  });

  test('form-only path puts pay into payPending', () => {
    const shift = {
      shift_start: ts(new Date('2026-04-17T09:00:00Z')),
      shift_end: ts(new Date('2026-04-17T10:00:00Z')),
      hourly_rate: 60.0,
      form_completed: true,
    };
    const r = computeSession(shift, [], [{durationHours: 1.0}]);
    closeTo(r.workedHours, 1.0);
    closeTo(r.realPay, 60.0);
    closeTo(r.payPending, 60.0);
    closeTo(r.payPaid, 0.0);
    closeTo(r.payApproved, 0.0);
  });

  test('form-only pending without attestation yields zero economics', () => {
    const shift = {
      shift_start: ts(new Date('2026-04-17T09:00:00Z')),
      shift_end: ts(new Date('2026-04-17T10:00:00Z')),
      hourly_rate: 60.0,
    };
    const r = computeSession(shift, [], [
      {durationHours: 1.0, makeupApprovalStatus: 'pending', responses: {}},
    ]);
    closeTo(r.workedHours, 0.0);
    closeTo(r.realPay, 0.0);
  });

  test('form-only rejected yields zero economics', () => {
    const shift = {
      shift_start: ts(new Date('2026-04-17T09:00:00Z')),
      shift_end: ts(new Date('2026-04-17T10:00:00Z')),
      hourly_rate: 60.0,
    };
    const attested = {
      durationHours: 1.0,
      makeupApprovalStatus: 'rejected',
      responses: {
        makeup_occurred_at: '2026-04-18',
        makeup_start_time: '10:00',
        makeup_end_time: '11:00',
        makeup_delivery_mode: 'zoom',
        makeup_zoom_host: 'host',
        makeup_students_present: 'A, B',
      },
    };
    const r = computeSession(shift, [], [attested]);
    closeTo(r.workedHours, 0.0);
    closeTo(r.realPay, 0.0);
  });

  test('form-only pending with full attestation pays (online, no location)', () => {
    const shift = {
      shift_start: ts(new Date('2026-04-17T09:00:00Z')),
      shift_end: ts(new Date('2026-04-17T10:00:00Z')),
      hourly_rate: 60.0,
    };
    const attested = {
      durationHours: 1.0,
      makeupApprovalStatus: 'pending',
      responses: {
        makeup_occurred_at: '2026-04-18',
        makeup_start_time: '10:00',
        makeup_end_time: '11:00',
        makeup_delivery_mode: 'livekit',
        makeup_zoom_host: 'teacher',
        makeup_students_present: 'A, B',
      },
    };
    const r = computeSession(shift, [], [attested]);
    closeTo(r.workedHours, 1.0);
    closeTo(r.realPay, 60.0);
  });

  test('form-only pending other mode requires detail', () => {
    const shift = {
      shift_start: ts(new Date('2026-04-17T09:00:00Z')),
      shift_end: ts(new Date('2026-04-17T10:00:00Z')),
      hourly_rate: 60.0,
    };
    const bad = {
      durationHours: 1.0,
      makeupApprovalStatus: 'pending',
      responses: {
        makeup_occurred_at: '2026-04-18',
        makeup_start_time: '10:00',
        makeup_end_time: '11:00',
        makeup_delivery_mode: 'other',
        makeup_students_present: 'A',
      },
    };
    const r0 = computeSession(shift, [], [bad]);
    closeTo(r0.workedHours, 0.0);
    const ok = {
      durationHours: 1.0,
      makeupApprovalStatus: 'pending',
      responses: {
        makeup_occurred_at: '2026-04-18',
        makeup_start_time: '10:00',
        makeup_end_time: '11:00',
        makeup_delivery_mode: 'other',
        makeup_other_detail: 'Meet link',
        makeup_students_present: 'A',
      },
    };
    const r1 = computeSession(shift, [], [ok]);
    closeTo(r1.workedHours, 1.0);
  });
});

describe('workedMinutesCeil', () => {
  test('rounds up partial minute', () => {
    expect(workedMinutesCeil({workedHours: 30.5 / 60})).toBe(31);
  });
  test('exact minute boundary stays exact', () => {
    expect(workedMinutesCeil({workedHours: 1.0})).toBe(60);
  });
  test('zero hours yields zero minutes', () => {
    expect(workedMinutesCeil({workedHours: 0})).toBe(0);
  });
});
