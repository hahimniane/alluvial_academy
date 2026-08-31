'use strict';

/**
 * Duplicate-timesheet protection: the rule that decides which of a teacher's
 * entries on one shift get paid. Shapes below mirror real production incidents
 * (Jul-Aug 2026) where a stalled connection flushed dozens of queued clock-in
 * attempts at once and every copy was auto-clocked-out with full pay.
 */

const {__test__} = require('../handlers/shifts');
const {partitionEntriesForPayment, isStampedeDuplicate, findClaimConflict} = __test__;

const SHIFT_END = Date.parse('2026-07-30T15:30:00Z');

const entry = (id, teacherId, clockIn, clockOut = null) => ({
  id,
  teacherId,
  clockInMs: Date.parse(clockIn),
  clockOutMs: clockOut ? Date.parse(clockOut) : null,
});

describe('duplicate timesheet detection', () => {
  test('a single open entry is payable', () => {
    const {keptIds, duplicateIds} = partitionEntriesForPayment(
      [entry('a', 't1', '2026-07-30T14:32:14.137Z')], SHIFT_END);
    expect([...keptIds]).toEqual(['a']);
    expect(duplicateIds.size).toBe(0);
  });

  test('a stampede of identical clock-ins keeps exactly one entry', () => {
    // Real incident shape: 32 entries, clock-ins 1ms apart, all open.
    const entries = Array.from({length: 32}, (_, i) =>
      entry(`d${String(i).padStart(2, '0')}`, 't1',
        new Date(Date.parse('2026-07-30T14:32:14.137Z') + i).toISOString()));
    const {keptIds, duplicateIds} = partitionEntriesForPayment(entries, SHIFT_END);
    expect(keptIds.size).toBe(1);
    expect(duplicateIds.size).toBe(31);
    // The earliest clock-in wins.
    expect(keptIds.has('d00')).toBe(true);
  });

  test('open duplicates are still caught after the kept entry was closed manually', () => {
    // Teacher clocked out at 15:10; the 3 stragglers from the same stampede
    // are still open and must not be paid.
    const entries = [
      entry('kept', 't1', '2026-07-30T14:32:14.137Z', '2026-07-30T15:10:00Z'),
      entry('d1', 't1', '2026-07-30T14:32:14.140Z'),
      entry('d2', 't1', '2026-07-30T14:32:14.171Z'),
      entry('d3', 't1', '2026-07-30T14:32:14.203Z'),
    ];
    const {keptIds, duplicateIds} = partitionEntriesForPayment(entries, SHIFT_END);
    expect([...keptIds]).toEqual(['kept']);
    expect(duplicateIds).toEqual(new Set(['d1', 'd2', 'd3']));
  });

  test('a genuine re-clock-in after clocking out is NOT a duplicate', () => {
    // Real legit shape (Ahmed Korka Bah): 59min session closed at 19:00,
    // then a second short session at 19:01.
    const entries = [
      entry('s1', 't1', '2026-07-30T14:03:00Z', '2026-07-30T15:02:00Z'),
      entry('s2', 't1', '2026-07-30T15:03:00Z'),
    ];
    const {keptIds, duplicateIds} = partitionEntriesForPayment(entries, SHIFT_END);
    expect(keptIds).toEqual(new Set(['s1', 's2']));
    expect(duplicateIds.size).toBe(0);
  });

  test('a second clock-in while the first is still open is a duplicate', () => {
    // While an entry is open its window extends to shift end, so nothing else
    // can legitimately start inside it.
    const entries = [
      entry('open', 't1', '2026-07-30T14:32:00Z'),
      entry('late', 't1', '2026-07-30T15:00:00Z'),
    ];
    const {duplicateIds} = partitionEntriesForPayment(entries, SHIFT_END);
    expect(duplicateIds).toEqual(new Set(['late']));
  });

  test('different teachers on the same shift never collide', () => {
    const entries = [
      entry('a', 't1', '2026-07-30T14:32:14.137Z'),
      entry('b', 't2', '2026-07-30T14:32:14.137Z'),
    ];
    const {keptIds, duplicateIds} = partitionEntriesForPayment(entries, SHIFT_END);
    expect(keptIds).toEqual(new Set(['a', 'b']));
    expect(duplicateIds.size).toBe(0);
  });

  test('identical timestamps break ties deterministically by id', () => {
    const entries = [
      entry('bbb', 't1', '2026-07-30T14:32:14.137Z'),
      entry('aaa', 't1', '2026-07-30T14:32:14.137Z'),
    ];
    const {keptIds} = partitionEntriesForPayment(entries, SHIFT_END);
    expect([...keptIds]).toEqual(['aaa']);
  });

  test('an open copy created within a minute of the kept entry is deleted, not kept as rejected', () => {
    const kept = entry('kept', 't1', '2026-07-30T14:32:14.137Z');
    const stampede = entry('dup', 't1', '2026-07-30T14:32:14.171Z');
    expect(isStampedeDuplicate(stampede, kept)).toBe(true);
  });

  test('a closed duplicate or a slow overlap is rejected for review instead of deleted', () => {
    const kept = entry('kept', 't1', '2026-07-30T14:32:14.137Z');
    // Closed copy: keep the evidence, mark rejected.
    expect(isStampedeDuplicate(
      entry('closed', 't1', '2026-07-30T14:32:14.171Z', '2026-07-30T15:30:00Z'), kept)).toBe(false);
    // Open but 5 minutes later: not the machine signature — needs review.
    expect(isStampedeDuplicate(
      entry('slow', 't1', '2026-07-30T14:37:20Z'), kept)).toBe(false);
    // No kept sibling at all: never classify as stampede.
    expect(isStampedeDuplicate(entry('alone', 't1', '2026-07-30T14:32:14.171Z'), undefined)).toBe(false);
  });

  test('entries without a clock-in are ignored, not rejected', () => {
    const entries = [
      {id: 'broken', teacherId: 't1', clockInMs: NaN, clockOutMs: null},
      entry('ok', 't1', '2026-07-30T14:32:14.137Z'),
    ];
    const {keptIds, duplicateIds} = partitionEntriesForPayment(entries, SHIFT_END);
    expect(keptIds).toEqual(new Set(['ok']));
    expect(duplicateIds.size).toBe(0);
  });
});

describe('shift-trade claim conflicts', () => {
  const T = (h, m = 0) => Date.parse(`2026-08-26T${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:00Z`);
  const mine = (id, sh, eh, status = 'scheduled', name = 'My class') =>
    ({id, startMs: T(sh), endMs: T(eh), status, name});

  test('claiming a shift over my existing class is refused', () => {
    const c = findClaimConflict(T(14), T(15), [mine('a', 14, 15)], 'claimed');
    expect(c).toEqual({id: 'a', name: 'My class'});
  });

  test('partial overlap also blocks (30 minutes into my class)', () => {
    expect(findClaimConflict(T(14, 30), T(15, 30), [mine('a', 14, 15)], 'x')).not.toBeNull();
  });

  test('back-to-back classes are fine', () => {
    expect(findClaimConflict(T(15), T(16), [mine('a', 14, 15)], 'x')).toBeNull();
  });

  test('cancelled and deleted shifts never block a claim', () => {
    expect(findClaimConflict(T(14), T(15), [
      mine('a', 14, 15, 'cancelled'), mine('b', 14, 15, 'deleted'),
    ], 'x')).toBeNull();
  });

  test('the shift being claimed never conflicts with itself', () => {
    expect(findClaimConflict(T(14), T(15), [mine('self', 14, 15)], 'self')).toBeNull();
  });

  test('shifts with broken times are skipped instead of blocking', () => {
    expect(findClaimConflict(T(14), T(15),
      [{id: 'bad', startMs: NaN, endMs: NaN, status: 'scheduled', name: ''}], 'x')).toBeNull();
  });
});

describe('reschedule window sanity', () => {
  const {_resolveRescheduleWindow} = __test__;
  const resolve = (start, end) => _resolveRescheduleWindow({
    newStartTime: start, newEndTime: end,
    newStartLocal: null, newEndLocal: null,
    timezone: 'UTC', fallbackTimezone: 'UTC',
  });

  test('a normal one-hour reschedule resolves', () => {
    const w = resolve('2026-08-24T22:00:00Z', '2026-08-24T23:00:00Z');
    expect(w.durationMinutes).toBe(60);
  });

  test('the 25-hour end-date mistake is refused with a date hint', () => {
    // Real incident: teacher moved the start to a new day but the end picker
    // stayed on the old date, producing a 25h shift that blocked scheduling.
    expect(() => resolve('2026-08-24T22:00:00Z', '2026-08-25T23:00:00Z'))
      .toThrow(/end date matches the start date/);
  });

  test('a legit cross-midnight class still works', () => {
    const w = resolve('2026-08-24T23:30:00Z', '2026-08-25T00:30:00Z');
    expect(w.durationMinutes).toBe(60);
  });
});
