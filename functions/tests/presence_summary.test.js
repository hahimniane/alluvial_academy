/**
 * The numbers a teacher and an admin actually read.
 *
 * The cases worth pinning are the ones where a wrong answer is unfair: our own
 * faults leaking into somebody's score, and the worst kind of absence — the one
 * they never came back from — being quietly filtered out for being unmeasured.
 */
const {
  CAUSE_INDIVIDUAL,
  CAUSE_PLATFORM,
  CAUSE_SIMULTANEOUS,
} = require('../services/presence/transitions');
const { summariseAbsences, rollUp } = require('../services/presence/summary');

const absence = (overrides = {}) => ({
  shiftId: 'shift_a',
  uid: 'teacher_1',
  name: 'habibu barry',
  role: 'teacher',
  cause: CAUSE_INDIVIDUAL,
  seconds: 60,
  returned: true,
  startedAtMs: 0,
  endedAtMs: 60000,
  ...overrides,
});

describe('summariseAbsences', () => {
  test('counts drops, time lost, and the longest single absence', () => {
    const [person] = summariseAbsences([
      absence({ seconds: 45 }),
      absence({ seconds: 600 }),
      absence({ seconds: 90 }),
    ]);
    expect(person.counted).toMatchObject({ drops: 3, secondsLost: 735, longestSeconds: 600 });
  });

  test('our own faults never reach a teacher\'s number', () => {
    // The hub handover that ended habibu barry's lesson on 2026-09-12 was ours.
    // It is kept and labelled, but it is not his drop-out.
    const [person] = summariseAbsences([
      absence({ cause: CAUSE_PLATFORM, seconds: 300, detail: 'hub_handover' }),
      absence({ cause: CAUSE_SIMULTANEOUS, seconds: 200 }),
      absence({ cause: CAUSE_INDIVIDUAL, seconds: 120 }),
    ]);
    expect(person.counted).toMatchObject({ drops: 1, secondsLost: 120 });
    expect(person.byCause[CAUSE_PLATFORM].drops).toBe(1);
    expect(person.byCause[CAUSE_SIMULTANEOUS].drops).toBe(1);
  });

  test('a blink below the floor is not a drop-out', () => {
    const summary = summariseAbsences([absence({ seconds: 8 })], { minSeconds: 30 });
    expect(summary).toEqual([]);
  });

  test('the floor can be moved without recollecting anything', () => {
    const absences = [absence({ seconds: 45 }), absence({ seconds: 20 })];
    expect(summariseAbsences(absences, { minSeconds: 30 })[0].counted.drops).toBe(1);
    expect(summariseAbsences(absences, { minSeconds: 15 })[0].counted.drops).toBe(2);
  });

  test('somebody who never came back always counts, even unmeasured', () => {
    // This is the most serious absence there is. Measuring it against a minimum
    // would silently discard exactly the cases that matter most.
    const [person] = summariseAbsences(
      [absence({ seconds: null, returned: false })],
      { minSeconds: 600 },
    );
    expect(person.counted.drops).toBe(1);
    expect(person.counted.neverReturned).toBe(1);
    expect(person.counted.secondsLost).toBe(0);
  });

  test('people are kept apart, worst first', () => {
    const summary = summariseAbsences([
      absence({ uid: 'student_1', role: 'student', name: 'Amadou', seconds: 40 }),
      absence({ uid: 'teacher_1', seconds: 40 }),
      absence({ uid: 'teacher_1', seconds: 40 }),
    ]);
    expect(summary.map((p) => [p.uid, p.counted.drops])).toEqual([
      ['teacher_1', 2],
      ['student_1', 1],
    ]);
  });

  test('a clean class produces nothing', () => {
    expect(summariseAbsences([])).toEqual([]);
  });
});

describe('rollUp', () => {
  const classSummary = (people) => ({ people });
  const personSummary = (overrides = {}) => ({
    uid: 'teacher_1',
    role: 'teacher',
    name: 'habibu barry',
    counted: { drops: 2, secondsLost: 300, longestSeconds: 200, neverReturned: 0 },
    byCause: {
      [CAUSE_INDIVIDUAL]: { drops: 2, secondsLost: 300, longestSeconds: 200, neverReturned: 0 },
      [CAUSE_SIMULTANEOUS]: { drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 },
      [CAUSE_PLATFORM]: { drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 },
    },
    ...overrides,
  });

  test('adds up a week and keeps the worst single absence', () => {
    const [person] = rollUp([
      classSummary([personSummary()]),
      classSummary([personSummary({
        counted: { drops: 1, secondsLost: 900, longestSeconds: 900, neverReturned: 1 },
      })]),
    ]);
    expect(person.counted).toMatchObject({
      drops: 3, secondsLost: 1200, longestSeconds: 900, neverReturned: 1,
    });
  });

  test('counts how many classes were affected, not just drops', () => {
    // Ten drops in one class is a bad lesson; ten across ten classes is a bad
    // connection. The distinction is the whole point of a support tool.
    const clean = personSummary({
      counted: { drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 },
    });
    const [person] = rollUp([
      classSummary([personSummary()]),
      classSummary([clean]),
      classSummary([clean]),
    ]);
    expect(person.classes).toBe(3);
    expect(person.classesWithADrop).toBe(1);
  });

  test('a period with no classes rolls up to nothing', () => {
    expect(rollUp([])).toEqual([]);
  });
});

describe('the evidence behind a teacher\'s number', () => {
  const { summariseAbsences, rollUp } = require('../services/presence/summary');

  const absence = (over) => ({
    shiftId: 'shift_mon', uid: 'teacher_1', name: 'Aicha Diallo', role: 'teacher',
    cause: 'individual', startedAtMs: Date.UTC(2026, 8, 14, 9, 5),
    endedAtMs: Date.UTC(2026, 8, 14, 9, 7), seconds: 120, returned: true, ...over,
  });

  test('each absence keeps the clock times it is claiming', () => {
    const [person] = summariseAbsences([absence()]);
    expect(person.spells).toEqual([{
      from: Date.UTC(2026, 8, 14, 9, 5),
      to: Date.UTC(2026, 8, 14, 9, 7),
      seconds: 120,
      returned: true,
      cause: 'individual',
      studentsWaiting: [],
      roomWasEmpty: false,
    }]);
  });

  test('an absence nobody returned from says so, with no end time invented', () => {
    const [person] = summariseAbsences([absence({ endedAtMs: null, seconds: null, returned: false })]);
    expect(person.spells[0].returned).toBe(false);
    expect(person.spells[0].to).toBeNull();
    expect(person.spells[0].seconds).toBeNull();
  });

  test('our own interruptions stay in the record, labelled as ours', () => {
    const [person] = summariseAbsences([absence({ cause: 'platform' })]);
    expect(person.counted.drops).toBe(0);
    expect(person.spells.map((s) => s.cause)).toEqual(['platform']);
  });

  const classSummary = (over) => ({
    shift_id: 'shift_mon',
    class_name: 'Quran — Monday',
    students: ['Amadou Diallo'],
    shift_start_ms: Date.UTC(2026, 8, 14, 9, 0),
    shift_end_ms: Date.UTC(2026, 8, 14, 10, 0),
    people: summariseAbsences([absence()]),
    ...over,
  });

  test('a period says which class, which day and which student', () => {
    const [person] = rollUp([classSummary()]);
    expect(person.occasions).toHaveLength(1);
    expect(person.occasions[0]).toMatchObject({
      shiftId: 'shift_mon',
      className: 'Quran — Monday',
      students: ['Amadou Diallo'],
      startedAt: Date.UTC(2026, 8, 14, 9, 0),
      endedAt: Date.UTC(2026, 8, 14, 10, 0),
      drops: 1,
    });
    expect(person.occasions[0].spells).toHaveLength(1);
  });

  test('a class nobody dropped out of is not listed as an occasion', () => {
    const clean = classSummary({
      shift_id: 'shift_tue',
      people: summariseAbsences([absence({ cause: 'platform' })]),
    });
    const [person] = rollUp([classSummary(), clean]);
    expect(person.classes).toBe(2);
    expect(person.occasions.map((o) => o.shiftId)).toEqual(['shift_mon']);
  });

  test('the most recent class comes first', () => {
    const older = classSummary({ shift_id: 'older', shift_start_ms: Date.UTC(2026, 8, 12, 9, 0) });
    const newer = classSummary({ shift_id: 'newer', shift_start_ms: Date.UTC(2026, 8, 16, 9, 0) });
    const [person] = rollUp([older, newer]);
    expect(person.occasions.map((o) => o.shiftId)).toEqual(['newer', 'older']);
  });

  test('a busy month keeps the totals whole and only trims the oldest detail', () => {
    const many = Array.from({ length: 80 }, (_, i) => classSummary({
      shift_id: `shift_${i}`,
      shift_start_ms: Date.UTC(2026, 8, 1, 9, 0) + i * 86400000,
    }));
    const [person] = rollUp(many);
    expect(person.counted.drops).toBe(80);
    expect(person.occasions).toHaveLength(60);
    expect(person.occasions[0].shiftId).toBe('shift_79');
  });
});

describe('what an administrator needs to judge a drop-out', () => {
  const { rollUp } = require('../services/presence/summary');

  const classWith = (over) => ({
    shift_id: 's1', class_name: 'Quran', students: ['Amadou'],
    shift_start_ms: Date.UTC(2026, 8, 18, 21, 0),
    shift_end_ms: Date.UTC(2026, 8, 18, 22, 0),
    people: [{
      uid: 't1', role: 'teacher', name: 'Aicha',
      counted: { drops: 1, secondsLost: 60, longestSeconds: 60, neverReturned: 0 },
      byCause: {},
      spells: [{
        from: Date.UTC(2026, 8, 18, 21, 10), to: null, seconds: 60,
        returned: true, cause: 'individual',
        studentsWaiting: ['Amadou'], roomWasEmpty: false,
      }],
    }],
    ...over,
  });

  test('whether a student was left waiting reaches the period', () => {
    const [person] = rollUp([classWith()]);
    expect(person.occasions[0].spells[0].studentsWaiting).toEqual(['Amadou']);
    expect(person.occasions[0].spells[0].roomWasEmpty).toBe(false);
  });

  test('an unreviewed class says so rather than pretending to be settled', () => {
    const [person] = rollUp([classWith()]);
    expect(person.occasions[0].review).toBeNull();
  });

  test("a reviewed class carries the reviewer's verdict", () => {
    const review = { status: 'reviewed', reviewed_by: 'admin_1', review_note: 'Router replaced' };
    const [person] = rollUp([classWith({ review })]);
    expect(person.occasions[0].review).toEqual(review);
  });
});
