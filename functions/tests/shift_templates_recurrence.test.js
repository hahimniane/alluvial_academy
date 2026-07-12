const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const shiftTemplates = require('../handlers/shift_templates');

describe('shift_templates helpers', () => {
  const t = shiftTemplates.__test;

  beforeAll(() => {
    admin.firestore.Timestamp = {
      fromDate: (date) => global.createMockTimestamp(date),
      now: () => global.createMockTimestamp(new Date()),
    };
  });

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

  test('template-generated teaching shifts default to Zoom', () => {
    const shiftStartUtc = DateTime.fromISO('2026-01-05T15:00:00Z');
    const shiftEndUtc = DateTime.fromISO('2026-01-05T16:00:00Z');

    const data = t._buildGeneratedShiftData({
      templateId: 'template_123',
      shiftId: 'generated_shift_123',
      shiftStartUtc,
      shiftEndUtc,
      template: {
        teacher_id: 'teacher_1',
        teacher_name: 'Teacher One',
        student_ids: ['student_1'],
        student_names: ['Student One'],
        admin_timezone: 'America/New_York',
        teacher_timezone: 'America/New_York',
        subject: 'quranStudies',
        category: 'teaching',
      },
    });

    expect(t._defaultVideoProviderForCategory('teaching')).toBe('zoom');
    expect(data.video_provider).toBe('zoom');
    expect(data.livekit_room_name).toBeNull();
    expect(data.generated_from_template).toBe(true);
  });

  test('template-generated non-teaching shifts default away from Zoom', () => {
    const data = t._buildGeneratedShiftData({
      templateId: 'template_456',
      shiftId: 'generated_shift_456',
      shiftStartUtc: DateTime.fromISO('2026-01-06T15:00:00Z'),
      shiftEndUtc: DateTime.fromISO('2026-01-06T16:00:00Z'),
      template: {
        teacher_id: 'teacher_1',
        teacher_name: 'Teacher One',
        category: 'meeting',
      },
    });

    expect(t._defaultVideoProviderForCategory('meeting')).toBe('realtimekit');
    expect(data.video_provider).toBe('realtimekit');
  });
});
