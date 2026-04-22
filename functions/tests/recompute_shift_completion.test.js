/**
 * Unit tests for shift completion aggregation (rejected exclusion, caps, tolerance).
 */

const {
  aggregateWorkedAndClockPresence,
  deriveCompletionStatusFromAggregate,
} = require('../services/shifts/recompute_shift_completion');

const ts = (d) => ({toDate: () => d});

const doc = (data) => ({data: () => data});

describe('recompute_shift_completion', () => {
  const shiftStart = new Date('2026-04-13T23:00:00.000Z');
  const shiftEnd = new Date('2026-04-14T00:00:00.000Z');

  test('excludes rejected timesheets from worked minutes', () => {
    const timesheetDocs = [
      doc({
        status: 'rejected',
        clock_in_timestamp: ts(new Date('2026-04-13T23:00:00.000Z')),
        clock_out_timestamp: ts(new Date('2026-04-14T00:00:00.000Z')),
      }),
      doc({
        status: 'approved',
        clock_in_timestamp: ts(new Date('2026-04-13T23:30:00.000Z')),
        clock_out_timestamp: ts(new Date('2026-04-13T23:45:00.000Z')),
      }),
    ];
    const {workedMinutes, neverClockedIn} = aggregateWorkedAndClockPresence({
      shiftStart,
      shiftEnd,
      timesheetDocs,
      shiftData: {},
    });
    expect(neverClockedIn).toBe(false);
    expect(workedMinutes).toBe(15);
  });

  test('full scheduled duration yields fullyCompleted with 1-minute tolerance', () => {
    const timesheetDocs = [
      doc({
        clock_in_timestamp: ts(new Date('2026-04-13T23:00:00.000Z')),
        clock_out_timestamp: ts(new Date('2026-04-13T23:59:00.000Z')),
      }),
    ];
    const agg = aggregateWorkedAndClockPresence({
      shiftStart,
      shiftEnd,
      timesheetDocs,
      shiftData: {},
    });
    const {newStatus, completionState} = deriveCompletionStatusFromAggregate({
      workedMinutes: agg.workedMinutes,
      scheduledMinutes: agg.scheduledMinutes,
      neverClockedIn: agg.neverClockedIn,
      toleranceMinutes: 1,
    });
    expect(agg.scheduledMinutes).toBe(60);
    expect(newStatus).toBe('fullyCompleted');
    expect(completionState).toBe('full');
  });

  test('partial work yields partiallyCompleted', () => {
    const timesheetDocs = [
      doc({
        clock_in_timestamp: ts(new Date('2026-04-13T23:00:00.000Z')),
        clock_out_timestamp: ts(new Date('2026-04-13T23:20:00.000Z')),
      }),
    ];
    const agg = aggregateWorkedAndClockPresence({
      shiftStart,
      shiftEnd,
      timesheetDocs,
      shiftData: {},
    });
    const {newStatus} = deriveCompletionStatusFromAggregate({
      workedMinutes: agg.workedMinutes,
      scheduledMinutes: agg.scheduledMinutes,
      neverClockedIn: agg.neverClockedIn,
      toleranceMinutes: 1,
    });
    expect(newStatus).toBe('partiallyCompleted');
  });

  test('caps worked time to shift window (overnight-ish window)', () => {
    const timesheetDocs = [
      doc({
        clock_in_timestamp: ts(new Date('2026-04-13T22:00:00.000Z')),
        clock_out_timestamp: ts(new Date('2026-04-14T02:00:00.000Z')),
      }),
    ];
    const {workedMinutes} = aggregateWorkedAndClockPresence({
      shiftStart,
      shiftEnd,
      timesheetDocs,
      shiftData: {},
    });
    expect(workedMinutes).toBe(60);
  });

  test('uses shift clock_in_time when no non-rejected timesheets', () => {
    const shiftData = {
      clock_in_time: ts(new Date('2026-04-13T23:10:00.000Z')),
      clock_out_time: ts(new Date('2026-04-13T23:50:00.000Z')),
    };
    const {workedMinutes, neverClockedIn} = aggregateWorkedAndClockPresence({
      shiftStart,
      shiftEnd,
      timesheetDocs: [],
      shiftData,
    });
    expect(neverClockedIn).toBe(false);
    expect(workedMinutes).toBe(40);
  });

  test('missed when never clocked in', () => {
    const agg = aggregateWorkedAndClockPresence({
      shiftStart,
      shiftEnd,
      timesheetDocs: [],
      shiftData: {},
    });
    const {newStatus, completionState} = deriveCompletionStatusFromAggregate({
      workedMinutes: agg.workedMinutes,
      scheduledMinutes: agg.scheduledMinutes,
      neverClockedIn: agg.neverClockedIn,
      toleranceMinutes: 1,
    });
    expect(newStatus).toBe('missed');
    expect(completionState).toBe('none');
  });
});
