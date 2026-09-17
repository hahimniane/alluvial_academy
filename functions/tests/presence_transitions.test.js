/**
 * Turning the bot's room reports into drop-outs.
 *
 * The cases that matter here are the ones where getting it wrong blames a
 * teacher for something we did, or records an outage as everybody quitting.
 */
const {
  CAUSE_PLATFORM,
  CAUSE_SIMULTANEOUS,
  CAUSE_INDIVIDUAL,
  diffLiveParticipants,
  classifyDepartures,
  buildAbsences,
} = require('../services/presence/transitions');

const person = (uid, role, name) => ({ routingUid: uid, role, name });

describe('diffLiveParticipants', () => {
  test('sees who arrived and who left', () => {
    const before = { shift_a: [person('teacher_1', 'teacher'), person('student_1', 'student')] };
    const after = { shift_a: [person('teacher_1', 'teacher'), person('student_2', 'student')] };

    const { arrivals, departures } = diffLiveParticipants(before, after);
    expect(arrivals.map((a) => a.uid)).toEqual(['student_2']);
    expect(departures.map((d) => d.uid)).toEqual(['student_1']);
    expect(departures[0]).toMatchObject({ shiftId: 'shift_a', role: 'student' });
  });

  test('a class the bot stopped reporting is not everybody leaving', () => {
    // The hub going quiet is an outage, not thirty people quitting at once.
    // Recording it as departures would invent drop-outs for every class at once.
    const before = { shift_a: [person('teacher_1', 'teacher')], shift_b: [person('teacher_2', 'teacher')] };
    const after = { shift_a: [person('teacher_1', 'teacher')] };

    const { departures } = diffLiveParticipants(before, after);
    expect(departures).toEqual([]);
  });

  test('the first sight of a class produces no departures', () => {
    const { arrivals, departures } = diffLiveParticipants({}, { shift_a: [person('teacher_1', 'teacher')] });
    expect(arrivals).toEqual([]);
    expect(departures).toEqual([]);
  });

  test('closing a hub deliberately IS everyone leaving', () => {
    // The opposite of the case above, and the distinction has to be explicit:
    // silence means we do not know, a close-out means we ended it.
    const before = { shift_a: [person('teacher_1', 'teacher')], shift_b: [person('teacher_2', 'teacher')] };
    const { departures } = diffLiveParticipants(before, {}, { everyoneIsLeaving: true });
    expect(departures.map((d) => d.uid).sort()).toEqual(['teacher_1', 'teacher_2']);
  });

  test('rubbish in does not throw', () => {
    expect(diffLiveParticipants(null, undefined)).toEqual({ arrivals: [], departures: [] });
    expect(diffLiveParticipants({ shift_a: 'nope' }, { shift_a: [null, {}] }))
      .toEqual({ arrivals: [], departures: [] });
  });
});

describe('classifyDepartures', () => {
  const gone = (uid, shiftId = 'shift_a') => ({ shiftId, uid, name: uid, role: 'teacher' });

  test('somebody the bot was moving is our doing, not theirs', () => {
    // The bot names who it is about to move before it moves them, so this is
    // known rather than guessed.
    const [result] = classifyDepartures([gone('teacher_1')], { routedUids: ['teacher_1'] });
    expect(result.cause).toBe(CAUSE_PLATFORM);
    expect(result.detail).toBe('bot_moved_them');
  });

  test('a known platform moment covers everyone in it', () => {
    const results = classifyDepartures(
      [gone('teacher_1'), gone('student_1', 'shift_b')],
      { platformEvent: 'hub_handover' },
    );
    expect(results.map((r) => r.cause)).toEqual([CAUSE_PLATFORM, CAUSE_PLATFORM]);
    expect(results[0].detail).toBe('hub_handover');
  });

  test('a whole room vanishing together is not several bad connections', () => {
    const results = classifyDepartures([
      gone('teacher_1'),
      gone('student_1'),
      gone('student_2'),
    ]);
    expect(results.every((r) => r.cause === CAUSE_SIMULTANEOUS)).toBe(true);
    expect(results[0].detail).toBe('3_left_together');
  });

  test('one person leaving a room that carries on is an individual drop', () => {
    const [result] = classifyDepartures([gone('teacher_1')]);
    expect(result.cause).toBe(CAUSE_INDIVIDUAL);
    expect(result.peersGoneTogether).toBe(0);
  });

  test('two people leaving DIFFERENT rooms are two individual drops', () => {
    // Simultaneity only means anything within one room. Two classes losing one
    // person each at the same moment is two networks, not one of our faults.
    const results = classifyDepartures([gone('teacher_1', 'shift_a'), gone('teacher_2', 'shift_b')]);
    expect(results.map((r) => r.cause)).toEqual([CAUSE_INDIVIDUAL, CAUSE_INDIVIDUAL]);
  });
});

describe('buildAbsences', () => {
  const at = (seconds) => new Date('2026-09-16T14:00:00Z').getTime() + seconds * 1000;
  const event = (type, uid, seconds, extra = {}) => ({
    type, uid, shiftId: 'shift_a', role: 'teacher', name: uid,
    atMs: at(seconds), cause: CAUSE_INDIVIDUAL, ...extra,
  });

  test('a departure and the arrival that ends it become one absence', () => {
    const absences = buildAbsences([
      event('departed', 'teacher_1', 0),
      event('arrived', 'teacher_1', 45),
    ]);
    expect(absences).toHaveLength(1);
    expect(absences[0]).toMatchObject({ uid: 'teacher_1', seconds: 45, returned: true });
  });

  test('somebody who never came back is closed at the end of the class', () => {
    const absences = buildAbsences(
      [event('departed', 'teacher_1', 600)],
      { classEnd: at(1800) },
    );
    expect(absences[0]).toMatchObject({ returned: false, seconds: 1200 });
  });

  test('an unfinished absence with no class end has no invented duration', () => {
    // Guessing here would report a live absence as a short one.
    const absences = buildAbsences([event('departed', 'teacher_1', 600)]);
    expect(absences[0]).toMatchObject({ returned: false, seconds: null });
  });

  test('several drops in one class are counted separately', () => {
    const absences = buildAbsences([
      event('departed', 'teacher_1', 0),
      event('arrived', 'teacher_1', 30),
      event('departed', 'teacher_1', 300),
      event('arrived', 'teacher_1', 420),
      event('departed', 'teacher_1', 900),
      event('arrived', 'teacher_1', 930),
    ]);
    expect(absences.map((a) => a.seconds)).toEqual([30, 120, 30]);
  });

  test('a repeated departure with no arrival between does not double count', () => {
    const absences = buildAbsences([
      event('departed', 'teacher_1', 0),
      event('departed', 'teacher_1', 6),
      event('arrived', 'teacher_1', 60),
    ]);
    expect(absences).toHaveLength(1);
    expect(absences[0].seconds).toBe(60);
  });

  test('the cause is taken from the departure, not the return', () => {
    const absences = buildAbsences([
      event('departed', 'teacher_1', 0, { cause: CAUSE_PLATFORM, detail: 'bot_moved_them' }),
      event('arrived', 'teacher_1', 8),
    ]);
    expect(absences[0]).toMatchObject({ cause: CAUSE_PLATFORM, detail: 'bot_moved_them' });
  });

  test('two people in one class keep their own absences', () => {
    const absences = buildAbsences([
      event('departed', 'teacher_1', 0),
      event('departed', 'student_1', 10),
      event('arrived', 'teacher_1', 60),
      event('arrived', 'student_1', 120),
    ]);
    expect(absences.map((a) => [a.uid, a.seconds])).toEqual([
      ['teacher_1', 60],
      ['student_1', 110],
    ]);
  });

  test('events arriving out of order are sorted before pairing', () => {
    const absences = buildAbsences([
      event('arrived', 'teacher_1', 45),
      event('departed', 'teacher_1', 0),
    ]);
    expect(absences[0].seconds).toBe(45);
  });
});
