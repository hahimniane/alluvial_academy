/**
 * Pure helpers for moving a set of classes earlier or later by a fixed number
 * of minutes (the daylight-saving fix): the new clock times of a weekly
 * schedule, and which moved classes would land on top of another class.
 */
const {DateTime} = require('luxon');

const DAY_MINUTES = 24 * 60;
const WEEKDAY_SHORT = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/** "HH:mm" + minutes → the new "HH:mm" and how many days it crossed (-1, 0, +1). */
const shiftClock = (hhmm, minutes) => {
  const match = String(hhmm || '').trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const total = Number(match[1]) * 60 + Number(match[2]) + minutes;
  const dayShift = Math.floor(total / DAY_MINUTES);
  const inDay = ((total % DAY_MINUTES) + DAY_MINUTES) % DAY_MINUTES;
  const time = `${String(Math.floor(inDay / 60)).padStart(2, '0')}:${String(inDay % 60).padStart(2, '0')}`;
  return {time, dayShift};
};

/** ISO weekday (1 = Mon … 7 = Sun) moved by whole days. */
const rotateWeekday = (weekday, days) => ((((Number(weekday) - 1 + days) % 7) + 7) % 7) + 1;

const toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

/**
 * The fields to write on a weekly schedule so every class it makes starts
 * `minutes` later (negative = earlier) on the schedule's own clock. A class
 * pushed over midnight moves to the neighbouring weekday, and so do its
 * per-day slots, skipped weekdays and skipped dates.
 */
const movedTemplatePatch = (template, minutes, zone) => {
  const start = shiftClock(template.start_time, minutes);
  if (!start) throw new Error(`Schedule has no start time (${template.start_time})`);
  const end = shiftClock(template.end_time, minutes);
  const recurrence = {...(template.enhanced_recurrence || {type: 'weekly'})};
  const slots = Array.isArray(recurrence.weekdayTimeSlots) ? recurrence.weekdayTimeSlots : [];

  const slotShift = new Map();
  if (slots.length) {
    recurrence.weekdayTimeSlots = slots.map((slot) => {
      const s = shiftClock(`${slot.start_hour}:${String(slot.start_minute).padStart(2, '0')}`, minutes);
      const e = shiftClock(`${slot.end_hour}:${String(slot.end_minute).padStart(2, '0')}`, minutes);
      slotShift.set(Number(slot.weekday), s.dayShift);
      const [sh, sm] = s.time.split(':').map(Number);
      const [eh, em] = e.time.split(':').map(Number);
      return {...slot, weekday: rotateWeekday(slot.weekday, s.dayShift), start_hour: sh, start_minute: sm, end_hour: eh, end_minute: em};
    });
  }
  const dayShiftFor = (weekday) => (slotShift.has(Number(weekday)) ? slotShift.get(Number(weekday)) : start.dayShift);

  if (Array.isArray(recurrence.selectedWeekdays)) {
    recurrence.selectedWeekdays = [...new Set(recurrence.selectedWeekdays.map((w) => rotateWeekday(w, dayShiftFor(w))))].sort((a, b) => a - b);
  }
  if (Array.isArray(recurrence.excludedWeekdays) && start.dayShift) {
    recurrence.excludedWeekdays = recurrence.excludedWeekdays.map((w) => rotateWeekday(w, start.dayShift));
  }
  if (Array.isArray(recurrence.excludedDates) && start.dayShift) {
    recurrence.excludedDates = recurrence.excludedDates
      .map((d) => toDate(d))
      .filter(Boolean)
      .map((d) => DateTime.fromJSDate(d, {zone}).plus({days: start.dayShift}).startOf('day').toJSDate());
  }

  const patch = {start_time: start.time, enhanced_recurrence: recurrence};
  if (end) patch.end_time = end.time;
  const baseStart = toDate(template.base_shift_start);
  const baseEnd = toDate(template.base_shift_end);
  if (baseStart) patch.base_shift_start = new Date(baseStart.getTime() + minutes * 60000);
  if (baseEnd) patch.base_shift_end = new Date(baseEnd.getTime() + minutes * 60000);
  return {patch, dayShift: start.dayShift};
};

/** "Sat, Sun · 7:00–8:30 AM" for a weekly schedule. */
const describeSchedule = (template) => {
  const recurrence = template.enhanced_recurrence || {};
  const days = (recurrence.selectedWeekdays || []).map(Number).sort((a, b) => a - b).map((w) => WEEKDAY_SHORT[w]).filter(Boolean);
  const label = (hhmm) => {
    const c = shiftClock(hhmm, 0);
    if (!c) return '';
    const [h, m] = c.time.split(':').map(Number);
    return `${((h + 11) % 12) + 1}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`;
  };
  const type = String(recurrence.type || 'weekly').toLowerCase();
  const dayLabel = days.length ? days.join(', ') : type === 'daily' ? 'Every day' : type;
  return `${dayLabel} · ${label(template.start_time)}${template.end_time ? `–${label(template.end_time)}` : ''}`;
};

/**
 * Moved classes that would overlap a class that is NOT moving, for the same
 * person. `moved` and `others` are [{id, start: Date, end: Date, ...}].
 */
const findOverlaps = (moved, others) => {
  const out = [];
  for (const m of moved) {
    for (const o of others) {
      if (o.id === m.id) continue;
      if (m.start < o.end && m.end > o.start) out.push({moved: m, other: o});
    }
  }
  return out;
};

module.exports = {shiftClock, rotateWeekday, movedTemplatePatch, describeSchedule, findOverlaps, toDate};
