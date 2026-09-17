'use strict';

/**
 * One class's drop-outs, worked out from the events the bot's reports produced.
 *
 * Kept separate from Firestore so the arithmetic can be tested directly: the
 * part worth being sure about is not the reading and writing, it is whether a
 * teacher's number is fair.
 */

const { buildAbsences } = require('./transitions');
const { summariseAbsences, DEFAULT_MIN_ABSENCE_SECONDS } = require('./summary');

/** Firestore timestamps, ISO strings and Dates all mean the same thing here. */
const toMs = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number') return value;
  if (typeof value.toDate === 'function') {
    const date = value.toDate();
    return date instanceof Date && Number.isFinite(date.getTime()) ? date.getTime() : null;
  }
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed.getTime() : null;
};

/** A stored event doc, in the shape the absence builder wants. */
const _eventFromDoc = (data = {}) => {
  const atMs = toMs(data.at);
  if (!Number.isFinite(atMs)) return null;
  const uid = String(data.uid || '').trim();
  if (!uid) return null;
  const type = String(data.type || '').trim();
  if (type !== 'arrived' && type !== 'departed') return null;
  return {
    type,
    uid,
    shiftId: String(data.shift_id || '').trim(),
    name: data.name || null,
    role: data.role || null,
    cause: data.cause || null,
    detail: data.cause_detail || null,
    atMs,
  };
};

/** The students a class was with, by name, in the order the shift lists them. */
const _studentNames = (shiftData = {}) => {
  const raw = shiftData.student_names || shiftData.studentNames;
  if (!Array.isArray(raw)) return [];
  const names = [];
  for (const value of raw) {
    const name = String(value || '').trim();
    if (name && !names.includes(name)) names.push(name);
  }
  return names;
};

/**
 * Everyone's drop-outs for one class.
 *
 * Absences are closed at the end of the class rather than left open, so
 * somebody who walked out at the half hour is recorded as having lost the rest
 * of the lesson and not as an absence of unknown length.
 *
 * Returns null when the class produced no events at all. That is different from
 * a class where nobody dropped: no events means the bot never reported this
 * class, so we know nothing — and writing a clean summary would claim otherwise.
 */
function buildClassSummary({
  shiftId,
  shiftData = {},
  eventDocs = [],
  minSeconds = DEFAULT_MIN_ABSENCE_SECONDS,
}) {
  const events = eventDocs.map(_eventFromDoc).filter(Boolean);
  if (events.length === 0) return null;

  const classEnd = toMs(shiftData.shift_end || shiftData.shiftEnd);
  const absences = buildAbsences(events, { classEnd });
  const people = summariseAbsences(absences, { minSeconds });

  const teacherId = String(shiftData.teacher_id || shiftData.teacherId || '').trim() || null;
  const teacher = people.find((person) => person.uid === teacherId) || null;

  return {
    shift_id: shiftId,
    teacher_id: teacherId,
    teacher_name: shiftData.teacher_name || shiftData.teacherName || null,
    class_name: shiftData.custom_name || shiftData.class_name || null,
    shift_start: shiftData.shift_start || shiftData.shiftStart || null,
    shift_end: shiftData.shift_end || shiftData.shiftEnd || null,
    // Who the class was with, copied rather than referenced: a teacher may
    // question a figure long after the shift has been archived out from under
    // it, and "which student was this?" has to still have an answer then.
    students: _studentNames(shiftData),
    // The same instant as shift_start, as a number, so a period can order and
    // trim its classes without reopening every Firestore timestamp.
    shift_start_ms: toMs(shiftData.shift_start || shiftData.shiftStart),
    min_absence_seconds: minSeconds,
    events_considered: events.length,
    people,
    // Lifted out so a week's worth can be totalled without opening every class.
    teacher_drops: teacher ? teacher.counted.drops : 0,
    teacher_seconds_lost: teacher ? teacher.counted.secondsLost : 0,
    teacher_longest_absence_seconds: teacher ? teacher.counted.longestSeconds : 0,
  };
}

module.exports = { buildClassSummary, toMs };
