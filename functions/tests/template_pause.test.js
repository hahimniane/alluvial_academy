'use strict';

/**
 * Timed pause on a recurring template: an admin pauses a series for a period
 * (a student travels, a Ramadan break) and it must resume BY ITSELF the day
 * after the window ends — no cron, no second admin action. The template stays
 * active the whole time; the generator just skips the paused days.
 */

const {DateTime} = require('luxon');
const {__test__} = require('../handlers/shift_templates');
const {_isDayPaused} = __test__;

const ZONE = 'America/New_York';
const day = (iso) => DateTime.fromISO(iso, {zone: ZONE}).startOf('day');
const at = (iso) => new Date(Date.parse(iso));

describe('_isDayPaused', () => {
  test('no pause fields means never paused', () => {
    expect(_isDayPaused({day: day('2026-09-10'), template: {}, adminTimezone: ZONE})).toBe(false);
  });

  test('days inside the window are paused, including both endpoints', () => {
    const template = {pause_start: at('2026-09-07T04:00:00Z'), pause_end: at('2026-09-20T04:00:00Z')};
    expect(_isDayPaused({day: day('2026-09-07'), template, adminTimezone: ZONE})).toBe(true);
    expect(_isDayPaused({day: day('2026-09-14'), template, adminTimezone: ZONE})).toBe(true);
    expect(_isDayPaused({day: day('2026-09-20'), template, adminTimezone: ZONE})).toBe(true);
  });

  test('the day before and the day after the window generate normally', () => {
    const template = {pause_start: at('2026-09-07T04:00:00Z'), pause_end: at('2026-09-20T04:00:00Z')};
    expect(_isDayPaused({day: day('2026-09-06'), template, adminTimezone: ZONE})).toBe(false);
    // This is the auto-resume: nothing runs, the window simply no longer covers today.
    expect(_isDayPaused({day: day('2026-09-21'), template, adminTimezone: ZONE})).toBe(false);
  });

  test('an open-ended pause (start only) covers everything from that day on', () => {
    const template = {pause_start: at('2026-09-07T04:00:00Z'), pause_end: null};
    expect(_isDayPaused({day: day('2026-09-06'), template, adminTimezone: ZONE})).toBe(false);
    expect(_isDayPaused({day: day('2026-12-25'), template, adminTimezone: ZONE})).toBe(true);
  });

  test('a pause that only sets an end date covers every day up to it', () => {
    const template = {pause_start: null, pause_end: at('2026-09-20T04:00:00Z')};
    expect(_isDayPaused({day: day('2026-09-20'), template, adminTimezone: ZONE})).toBe(true);
    expect(_isDayPaused({day: day('2026-09-21'), template, adminTimezone: ZONE})).toBe(false);
  });

  test('window edges are read in the admin timezone, not UTC', () => {
    // 2026-09-20T23:30 New York is already 2026-09-21 in UTC; the pause must
    // still end on the 20th as the admin sees it.
    const template = {pause_start: at('2026-09-20T04:00:00Z'), pause_end: at('2026-09-21T03:30:00Z')};
    expect(_isDayPaused({day: day('2026-09-20'), template, adminTimezone: ZONE})).toBe(true);
    expect(_isDayPaused({day: day('2026-09-21'), template, adminTimezone: ZONE})).toBe(false);
  });
});
