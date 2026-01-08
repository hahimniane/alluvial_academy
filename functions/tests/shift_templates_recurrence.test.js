const {DateTime} = require('luxon');

const shiftTemplates = require('../handlers/shift_templates');

describe('shift_templates helpers', () => {
  const t = shiftTemplates.__test;

  test('_parseHHmm parses valid times', () => {
    expect(t._parseHHmm('09:05')).toEqual({hour: 9, minute: 5});
    expect(t._parseHHmm('9:05')).toEqual({hour: 9, minute: 5});
    expect(t._parseHHmm('23:59')).toEqual({hour: 23, minute: 59});
  });

  test('_parseHHmm rejects invalid times', () => {
    expect(() => t._parseHHmm('')).toThrow();
    expect(() => t._parseHHmm('24:00')).toThrow();
    expect(() => t._parseHHmm('09:60')).toThrow();
    expect(() => t._parseHHmm('9:5')).toThrow();
    expect(() => t._parseHHmm('09-05')).toThrow();
  });

  test('_normalizeTimezone falls back to UTC', () => {
    expect(t._normalizeTimezone('America/New_York')).toBe('America/New_York');
    expect(t._normalizeTimezone('Not/AZone')).toBe('UTC');
    expect(t._normalizeTimezone('')).toBe('UTC');
  });

  test('_matchesRecurrence respects weekly rules and exclusions', () => {
    const adminTimezone = 'America/New_York';
    const day = DateTime.fromISO('2026-01-05', {zone: adminTimezone}).startOf('day'); // Monday

    expect(
      t._matchesRecurrence({
        day,
        adminTimezone,
        recurrence: {type: 'weekly', selectedWeekdays: [1]},
      }),
    ).toBe(true);

    expect(
      t._matchesRecurrence({
        day,
        adminTimezone,
        recurrence: {type: 'weekly', selectedWeekdays: [2]},
      }),
    ).toBe(false);

    expect(
      t._matchesRecurrence({
        day,
        adminTimezone,
        recurrence: {type: 'weekly', selectedWeekdays: [1], excludedWeekdays: [1]},
      }),
    ).toBe(false);

    const excludedDate = DateTime.fromISO('2026-01-05', {zone: adminTimezone}).toJSDate();
    expect(
      t._matchesRecurrence({
        day,
        adminTimezone,
        recurrence: {type: 'weekly', selectedWeekdays: [1], excludedDates: [excludedDate]},
      }),
    ).toBe(false);
  });

  test('_matchesRecurrence supports daily/monthly/yearly and none', () => {
    const adminTimezone = 'Etc/UTC';
    const day = DateTime.fromISO('2026-02-10', {zone: adminTimezone}).startOf('day');

    expect(t._matchesRecurrence({day, adminTimezone, recurrence: {type: 'daily'}})).toBe(true);
    expect(
      t._matchesRecurrence({
        day,
        adminTimezone,
        recurrence: {type: 'monthly', selectedMonthDays: [10]},
      }),
    ).toBe(true);
    expect(
      t._matchesRecurrence({
        day,
        adminTimezone,
        recurrence: {type: 'yearly', selectedMonths: [2]},
      }),
    ).toBe(true);
    expect(t._matchesRecurrence({day, adminTimezone, recurrence: {type: 'none'}})).toBe(false);
  });

  test('_buildGeneratedShiftId is stable', () => {
    const templateId = 'template_123';
    const shiftStartUtc = DateTime.fromISO('2026-01-05T15:00:00Z');
    const expectedSeconds = Math.floor(shiftStartUtc.toSeconds());
    expect(t._buildGeneratedShiftId({templateId, shiftStartUtc})).toBe(
      `tpl_${templateId}_${expectedSeconds}`,
    );
  });
});

