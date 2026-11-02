/**
 * Moving classes earlier/later (the daylight-saving fix):
 * - a weekly schedule gets its new clock time and its upcoming classes are
 *   rebuilt there; single classes move in place;
 * - a class pushed over midnight moves to the next weekday;
 * - a move that would put a teacher in two classes at once is refused;
 * - a recorded move can be undone.
 */
jest.mock('firebase-functions', () => {
  class MockHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {https: {HttpsError: MockHttpsError}};
});

const admin = require('firebase-admin');
const {createFakeFirestore, installOnAdmin, FakeTimestamp} = require('./helpers/fake_firestore');
const move = require('../utils/class_time_move');
const templates = require('../handlers/shift_templates');
const {moveClassTimes} = require('../handlers/move_classes');

const ts = (iso) => FakeTimestamp.fromDate(new Date(iso));
const NOW = new Date('2026-11-02T12:00:00Z'); // Mon 7:00 AM in New York

const template = (over) => ({
  teacher_id: 't1',
  teacher_name: 'Mama Diallo',
  student_ids: ['s1'],
  student_names: ['Nafisatou Bah'],
  subject: 'islamic',
  subject_id: 'islamic',
  hourly_rate: 4,
  category: 'teaching',
  admin_timezone: 'America/New_York',
  teacher_timezone: 'America/New_York',
  start_time: '18:00',
  end_time: '19:00',
  duration_minutes: 60,
  enhanced_recurrence: {type: 'weekly', selectedWeekdays: [1, 3]},
  is_active: true,
  max_days_ahead: 10,
  ...over,
});

const seed = () => ({
  users: {admin_1: {user_type: 'admin', first_name: 'Hawa', last_name: 'Admin'}},
  shift_templates: {
    T1: template(),
    T2: template({student_ids: ['s2'], student_names: ['Abibatu Bah'], start_time: '23:30', end_time: '00:30', enhanced_recurrence: {type: 'weekly', selectedWeekdays: [6]}}),
  },
  teaching_shifts: {
    O1: {
      teacher_id: 't1', teacher_name: 'Mama Diallo', student_ids: ['s1'], student_names: ['Nafisatou Bah'],
      status: 'scheduled', admin_timezone: 'America/New_York', auto_generated_name: 'Extra class',
      shift_start: ts('2026-11-05T15:00:00Z'), shift_end: ts('2026-11-05T16:00:00Z'),
    },
  },
});

let db;
const call = (data) => moveClassTimes({auth: {uid: 'admin_1'}, data});
const shiftsOf = (templateId) => Object.entries(db.store.teaching_shifts)
  .filter(([, s]) => s.template_id === templateId)
  .map(([id, s]) => ({id, start: s.shift_start.toDate().toISOString()}))
  .sort((a, b) => (a.start < b.start ? -1 : 1));

beforeEach(async () => {
  jest.useFakeTimers({now: NOW, doNotFake: ['nextTick', 'setImmediate', 'setTimeout', 'setInterval', 'queueMicrotask']});
  db = createFakeFirestore(seed(), {now: () => new Date()});
  installOnAdmin(admin, db);
  for (const id of ['T1', 'T2']) {
    await templates._generateShiftsForTemplate({templateId: id, template: db.store.shift_templates[id]});
  }
});
afterEach(() => jest.useRealTimers());

describe('clock helpers', () => {
  test('moves a time and reports a crossed midnight', () => {
    expect(move.shiftClock('18:00', -60)).toEqual({time: '17:00', dayShift: 0});
    expect(move.shiftClock('23:30', 60)).toEqual({time: '00:30', dayShift: 1});
    expect(move.shiftClock('00:30', -60)).toEqual({time: '23:30', dayShift: -1});
    expect(move.rotateWeekday(7, 1)).toBe(1);
    expect(move.rotateWeekday(1, -1)).toBe(7);
  });

  test('a schedule pushed past midnight lands on the next weekday', () => {
    const {patch} = move.movedTemplatePatch(template({start_time: '23:30', end_time: '00:30', enhanced_recurrence: {type: 'weekly', selectedWeekdays: [6, 7]}}), 60, 'America/New_York');
    expect(patch.start_time).toBe('00:30');
    expect(patch.end_time).toBe('01:30');
    expect(patch.enhanced_recurrence.selectedWeekdays).toEqual([1, 7]);
  });

  test('per-day times move with the schedule', () => {
    const {patch} = move.movedTemplatePatch(template({
      enhanced_recurrence: {type: 'weekly', selectedWeekdays: [1], weekdayTimeSlots: [{weekday: 1, start_hour: 18, start_minute: 0, end_hour: 19, end_minute: 30}]},
    }), -60, 'America/New_York');
    expect(patch.enhanced_recurrence.weekdayTimeSlots[0]).toMatchObject({weekday: 1, start_hour: 17, start_minute: 0, end_hour: 18, end_minute: 30});
  });
});

describe('moveClassTimes', () => {
  test('only admins can move classes', async () => {
    db.store.users.t1 = {user_type: 'teacher'};
    await expect(moveClassTimes({auth: {uid: 't1'}, data: {teacher_id: 't1', minutes: -60}})).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('preview lists every schedule and single class, changing nothing', async () => {
    const before = JSON.stringify(db.store);
    const plan = await call({action: 'preview', teacher_id: 't1', minutes: -60});
    expect(plan.schedules.map((s) => [s.id, s.before, s.after])).toEqual([
      ['T1', 'Mon, Wed · 6:00 PM–7:00 PM', 'Mon, Wed · 5:00 PM–6:00 PM'],
      ['T2', 'Sat · 11:30 PM–12:30 AM', 'Sat · 10:30 PM–11:30 PM'],
    ]);
    expect(plan.singles).toHaveLength(1);
    expect(plan.teacherConflicts).toEqual([]);
    expect(JSON.stringify(db.store)).toBe(before);
  });

  test('apply moves the schedule, rebuilds its classes and moves single classes in place', async () => {
    expect(shiftsOf('T1')[0].start).toBe('2026-11-02T23:00:00.000Z'); // Mon 6 PM EST
    const result = await call({action: 'apply', teacher_id: 't1', minutes: -60});
    expect(result.schedules).toBe(2);

    expect(db.store.shift_templates.T1.start_time).toBe('17:00');
    expect(db.store.shift_templates.T1.end_time).toBe('18:00');
    const t1 = shiftsOf('T1');
    expect(t1[0].start).toBe('2026-11-02T22:00:00.000Z'); // Mon 5 PM EST
    expect(t1.every((s) => !s.start.endsWith('T23:00:00.000Z'))).toBe(true);
    // No date was skipped on the schedule.
    expect(db.store.shift_templates.T1.enhanced_recurrence.excludedDates).toBeUndefined();

    expect(db.store.teaching_shifts.O1.shift_start.toDate().toISOString()).toBe('2026-11-05T14:00:00.000Z');
    expect(db.store.teaching_shifts.O1.admin_modified).toBe(true);

    const {moves} = await call({action: 'list'});
    expect(moves).toHaveLength(1);
    expect(moves[0]).toMatchObject({label: 'Mama Diallo', minutes: -60, schedules: 2, singles: 1});
  });

  test('a student-only move pushed past midnight changes the weekday', async () => {
    await call({action: 'apply', student_id: 's2', minutes: 60});
    expect(db.store.shift_templates.T2.start_time).toBe('00:30');
    expect(db.store.shift_templates.T2.enhanced_recurrence.selectedWeekdays).toEqual([7]);
    expect(db.store.shift_templates.T1.start_time).toBe('18:00'); // the other student's class is untouched
  });

  test('a move that double-books the teacher is refused', async () => {
    db.store.teaching_shifts.OTHER = {
      teacher_id: 't1', teacher_name: 'Mama Diallo', student_ids: ['s9'], student_names: ['Someone Else'],
      status: 'scheduled', admin_timezone: 'America/New_York', auto_generated_name: 'Other class',
      shift_start: ts('2026-11-04T22:00:00Z'), shift_end: ts('2026-11-04T23:00:00Z'), // Wed 5 PM EST
    };
    const plan = await call({action: 'preview', student_id: 's1', minutes: -60});
    expect(plan.teacherConflicts.length).toBeGreaterThan(0);
    await expect(call({action: 'apply', student_id: 's1', minutes: -60})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.store.shift_templates.T1.start_time).toBe('18:00');
  });

  test('unticked schedules stay where they are', async () => {
    await call({action: 'apply', teacher_id: 't1', minutes: -60, template_ids: ['T2'], shift_ids: []});
    expect(db.store.shift_templates.T1.start_time).toBe('18:00');
    expect(db.store.shift_templates.T2.start_time).toBe('22:30');
    expect(db.store.teaching_shifts.O1.shift_start.toDate().toISOString()).toBe('2026-11-05T15:00:00.000Z');
  });

  test('undo puts everything back', async () => {
    const {moveId} = await call({action: 'apply', teacher_id: 't1', minutes: -60});
    await call({action: 'undo', move_id: moveId});
    expect(db.store.shift_templates.T1.start_time).toBe('18:00');
    expect(shiftsOf('T1')[0].start).toBe('2026-11-02T23:00:00.000Z');
    expect(db.store.teaching_shifts.O1.shift_start.toDate().toISOString()).toBe('2026-11-05T15:00:00.000Z');
    await expect(call({action: 'undo', move_id: moveId})).rejects.toMatchObject({code: 'failed-precondition'});
  });
});

describe('first class of a schedule', () => {
  test('moves with its schedule and is not listed as a single class', async () => {
    db.store.teaching_shifts.T1 = {
      teacher_id: 't1', teacher_name: 'Mama Diallo', student_ids: ['s1'], student_names: ['Nafisatou Bah'],
      status: 'scheduled', admin_timezone: 'America/New_York', auto_generated_name: 'First class',
      shift_start: ts('2026-11-09T23:00:00Z'), shift_end: ts('2026-11-10T00:00:00Z'),
    };
    const plan = await call({action: 'preview', teacher_id: 't1', minutes: -60});
    expect(plan.singles.map((s) => s.id)).toEqual(['O1']);
    const ticked = await call({action: 'preview', teacher_id: 't1', minutes: -60, template_ids: ['T2'], shift_ids: ['O1']});
    expect(ticked.schedules.find((s) => s.id === 'T1').selected).toBe(false);

    const {moveId} = await call({action: 'apply', teacher_id: 't1', minutes: -60, template_ids: ['T1'], shift_ids: []});
    expect(db.store.teaching_shifts.T1.shift_start.toDate().toISOString()).toBe('2026-11-09T22:00:00.000Z');
    expect(db.store.teaching_shifts.O1.shift_start.toDate().toISOString()).toBe('2026-11-05T15:00:00.000Z');
    await call({action: 'undo', move_id: moveId});
    expect(db.store.teaching_shifts.T1.shift_start.toDate().toISOString()).toBe('2026-11-09T23:00:00.000Z');
  });
});
