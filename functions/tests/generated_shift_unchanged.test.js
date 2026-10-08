const {__test} = require('../handlers/shift_templates');

const ts = (ms) => ({toMillis: () => ms, toDate: () => new Date(ms)});

const generated = () => ({
  id: 'tpl_1_2026-10-08T15:00',
  teacher_id: 't1',
  student_ids: ['s1', 's2'],
  shift_start: ts(1_000),
  shift_end: ts(4_600_000),
  status: 'scheduled',
  hourly_rate: 20,
  subject_id: null,
  enhanced_recurrence: {type: 'weekly', days: [1, 3]},
  created_at: ts(999_999),      // stamped fresh on every generation
  last_modified: ts(999_999),   // stamped fresh on every generation
});

describe('_generatedShiftUnchanged', () => {
  const {_generatedShiftUnchanged} = __test;

  test('an identical stored shift is unchanged even though the generation timestamps differ', () => {
    const existing = {...generated(), created_at: ts(1), last_modified: ts(2)};
    expect(_generatedShiftUnchanged(existing, generated())).toBe(true);
  });

  test('fields the generator does not own never force a rewrite', () => {
    const existing = {...generated(), zoom_meeting_id: '123', hub_doc_id: 'zoom_hub_x', attendance: {present: 2}};
    expect(_generatedShiftUnchanged(existing, generated())).toBe(true);
  });

  test('timestamps compare by instant, not by object identity', () => {
    const existing = {...generated(), shift_end: {toDate: () => new Date(4_600_000)}};
    expect(_generatedShiftUnchanged(existing, generated())).toBe(true);
  });

  test('a stored null and a generated missing/undefined field are the same thing', () => {
    const g = generated(); delete g.subject_id;
    expect(_generatedShiftUnchanged({...generated(), subject_id: null}, g)).toBe(true);
  });

  test.each([
    ['a changed rate', {hourly_rate: 25}],
    ['a changed student list', {student_ids: ['s1']}],
    ['a moved end time', {shift_end: ts(4_700_000)}],
    ['a changed recurrence map', {enhanced_recurrence: {type: 'weekly', days: [1]}}],
  ])('%s is a real change', (_label, patch) => {
    expect(_generatedShiftUnchanged({...generated(), ...patch}, generated())).toBe(false);
  });

  test('no existing document is never "unchanged"', () => {
    expect(_generatedShiftUnchanged(null, generated())).toBe(false);
    expect(_generatedShiftUnchanged(undefined, generated())).toBe(false);
  });
});
