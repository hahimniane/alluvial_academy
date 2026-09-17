/**
 * One class's drop-outs, from stored events to the numbers kept forever.
 */
const { buildClassSummary, toMs } = require('../services/presence/class_report');
const { CAUSE_PLATFORM, CAUSE_INDIVIDUAL } = require('../services/presence/transitions');

const stamp = (iso) => ({ toDate: () => new Date(iso) });
const CLASS_START = '2026-09-16T13:30:00Z';
const CLASS_END = '2026-09-16T14:30:00Z';

const shift = {
  teacher_id: 'teacher_1',
  teacher_name: 'habibu barry',
  custom_name: 'Quran 1:1',
  shift_start: stamp(CLASS_START),
  shift_end: stamp(CLASS_END),
};

const event = (type, uid, iso, extra = {}) => ({
  type, uid, shift_id: 'shift_a', at: stamp(iso),
  role: uid.startsWith('teacher') ? 'teacher' : 'student',
  name: uid, cause: type === 'departed' ? CAUSE_INDIVIDUAL : null, ...extra,
});

describe('buildClassSummary', () => {
  test('counts a teacher\'s drops, time lost and worst absence', () => {
    const summary = buildClassSummary({
      shiftId: 'shift_a',
      shiftData: shift,
      eventDocs: [
        event('departed', 'teacher_1', '2026-09-16T13:40:00Z'),
        event('arrived', 'teacher_1', '2026-09-16T13:42:00Z'), // 120s
        event('departed', 'teacher_1', '2026-09-16T14:00:00Z'),
        event('arrived', 'teacher_1', '2026-09-16T14:05:00Z'), // 300s
      ],
    });

    expect(summary).toMatchObject({
      shift_id: 'shift_a',
      teacher_id: 'teacher_1',
      teacher_name: 'habibu barry',
      teacher_drops: 2,
      teacher_seconds_lost: 420,
      teacher_longest_absence_seconds: 300,
    });
  });

  test('a teacher who walks out loses the rest of the lesson, not an unknown amount', () => {
    const summary = buildClassSummary({
      shiftId: 'shift_a',
      shiftData: shift,
      eventDocs: [event('departed', 'teacher_1', '2026-09-16T14:00:00Z')],
    });
    // 14:00 to the 14:30 end of class.
    expect(summary.teacher_seconds_lost).toBe(1800);
    expect(summary.people[0].counted.neverReturned).toBe(1);
  });

  test('our own faults are recorded but stay out of the teacher\'s number', () => {
    const summary = buildClassSummary({
      shiftId: 'shift_a',
      shiftData: shift,
      eventDocs: [
        event('departed', 'teacher_1', '2026-09-16T13:45:00Z', {
          cause: CAUSE_PLATFORM, cause_detail: 'hub_handover',
        }),
        event('arrived', 'teacher_1', '2026-09-16T13:52:00Z'),
      ],
    });
    expect(summary.teacher_drops).toBe(0);
    expect(summary.people[0].byCause[CAUSE_PLATFORM].drops).toBe(1);
  });

  test('students are summarised alongside the teacher', () => {
    const summary = buildClassSummary({
      shiftId: 'shift_a',
      shiftData: shift,
      eventDocs: [
        event('departed', 'student_1', '2026-09-16T13:40:00Z'),
        event('arrived', 'student_1', '2026-09-16T13:45:00Z'),
      ],
    });
    expect(summary.teacher_drops).toBe(0);
    expect(summary.people.map((p) => [p.uid, p.counted.drops])).toEqual([['student_1', 1]]);
  });

  test('a class the bot never reported produces nothing, not a clean sheet', () => {
    // No events means we know nothing about that class. Writing a summary of
    // zero drops would claim it went perfectly, which we cannot say.
    expect(buildClassSummary({ shiftId: 'shift_a', shiftData: shift, eventDocs: [] })).toBeNull();
  });

  test('malformed events are skipped rather than poisoning the class', () => {
    const summary = buildClassSummary({
      shiftId: 'shift_a',
      shiftData: shift,
      eventDocs: [
        { type: 'departed' },                       // no uid, no time
        { type: 'nonsense', uid: 'x', at: stamp(CLASS_START) },
        event('departed', 'teacher_1', '2026-09-16T13:40:00Z'),
        event('arrived', 'teacher_1', '2026-09-16T13:41:00Z'),
      ],
    });
    expect(summary.events_considered).toBe(2);
    expect(summary.teacher_drops).toBe(1);
  });

  test('a class with events but no drops worth reporting is still a real summary', () => {
    // Distinct from the no-events case: here the bot did watch, and the answer
    // is genuinely "nothing happened".
    const summary = buildClassSummary({
      shiftId: 'shift_a',
      shiftData: shift,
      eventDocs: [
        event('departed', 'teacher_1', '2026-09-16T13:40:00Z'),
        event('arrived', 'teacher_1', '2026-09-16T13:40:05Z'), // 5s, below the floor
      ],
    });
    expect(summary).not.toBeNull();
    expect(summary.teacher_drops).toBe(0);
    expect(summary.people).toEqual([]);
  });
});

describe('toMs', () => {
  test('reads Firestore timestamps, Dates, numbers and ISO strings alike', () => {
    const when = new Date('2026-09-16T13:30:00Z');
    expect(toMs(stamp(CLASS_START))).toBe(when.getTime());
    expect(toMs(when)).toBe(when.getTime());
    expect(toMs(when.getTime())).toBe(when.getTime());
    expect(toMs(CLASS_START)).toBe(when.getTime());
  });

  test('refuses nonsense instead of inventing a time', () => {
    expect(toMs(null)).toBeNull();
    expect(toMs('not a date')).toBeNull();
    expect(toMs({})).toBeNull();
  });
});
