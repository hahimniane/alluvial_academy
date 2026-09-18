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
  reportIsBlind,
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

  test('a room that empties IS a departure, even though its class vanishes from the report', () => {
    // The bot lists a class only while somebody is inside its room, so an
    // emptied room disappears from the report entirely. Read from the new
    // report alone this looks like nothing happening — which is how a real
    // teacher dropping out of a real class recorded nothing at all.
    const before = { shift_a: [person('teacher_1', 'teacher')], shift_b: [person('teacher_2', 'teacher')] };
    const after = { shift_a: [person('teacher_1', 'teacher')] };

    const { departures } = diffLiveParticipants(before, after);
    expect(departures.map((d) => [d.shiftId, d.uid])).toEqual([['shift_b', 'teacher_2']]);
  });

  test('the last person leaving a room is recorded', () => {
    const { departures } = diffLiveParticipants(
      { shift_a: [person('teacher_1', 'teacher')] },
      {},
    );
    expect(departures.map((d) => d.uid)).toEqual(['teacher_1']);
  });

  test('the first sight of a class is an arrival, not a departure', () => {
    const { arrivals, departures } = diffLiveParticipants({}, { shift_a: [person('teacher_1', 'teacher')] });
    expect(arrivals.map((a) => a.uid)).toEqual(['teacher_1']);
    expect(departures).toEqual([]);
  });

  test('closing a hub takes everyone in it with them', () => {
    const before = { shift_a: [person('teacher_1', 'teacher')], shift_b: [person('teacher_2', 'teacher')] };
    const { departures } = diffLiveParticipants(before, {});
    expect(departures.map((d) => d.uid).sort()).toEqual(['teacher_1', 'teacher_2']);
  });

  test('somebody who joined by raw Zoom link is still tracked', () => {
    // Joining through the app carries a routing id; opening the Zoom link
    // directly carries none, and every id field arrives empty. An earlier
    // version skipped those people entirely — excluding exactly the ones most
    // likely to be having trouble getting in.
    //
    // They are known by their name rather than their Zoom participant id: Zoom
    // mints a new id per connection, so keying on it would turn one person's
    // reconnection into two strangers and record no absence between them.
    const guest = {
      identity: '', routingUid: '', routing_uid: '',
      zoomUserId: 16786432, name: 'Smoke Test Teacher', role: 'participant',
    };
    const { arrivals } = diffLiveParticipants({}, { shift_a: [guest] });
    expect(arrivals.map((a) => a.uid)).toEqual(['name:Smoke Test Teacher']);

    const { departures } = diffLiveParticipants({ shift_a: [guest] }, {});
    expect(departures.map((d) => [d.uid, d.name]))
      .toEqual([['name:Smoke Test Teacher', 'Smoke Test Teacher']]);
  });

  test('a participant with only a name is tracked by it rather than dropped', () => {
    const nameOnly = { name: 'Amadou Diallo', role: 'student' };
    const { departures } = diffLiveParticipants({ shift_a: [nameOnly] }, {});
    expect(departures.map((d) => d.uid)).toEqual(['name:Amadou Diallo']);
  });

  test('a routing id is preferred over Zoom\'s own, so one person is not two', () => {
    const withBoth = { routingUid: 'teacher_1', zoomUserId: 999, name: 'habibu barry' };
    const { departures } = diffLiveParticipants({ shift_a: [withBoth] }, {});
    expect(departures.map((d) => d.uid)).toEqual(['teacher_1']);
  });

  test('rubbish in does not throw', () => {
    expect(diffLiveParticipants(null, undefined)).toEqual({ arrivals: [], departures: [] });
    // An entry with nothing identifying at all is still skipped.
    expect(diffLiveParticipants({ shift_a: 'nope' }, { shift_a: [null, {}] }))
      .toEqual({ arrivals: [], departures: [] });
  });
});

describe('reportIsBlind', () => {
  test('a bot that cannot see its rooms is not reporting an empty hub', () => {
    // The dangerous one: believed literally, this is every person in every
    // class leaving in the same second.
    expect(reportIsBlind({ stats: { liveRoomCount: 0 }, expectedRooms: 30 })).toBe(true);
  });

  test('a hub that genuinely has no rooms is not blind', () => {
    expect(reportIsBlind({ stats: { liveRoomCount: 0 }, expectedRooms: 0 })).toBe(false);
  });

  test('a bot reading its rooms is believed', () => {
    expect(reportIsBlind({ stats: { liveRoomCount: 30 }, expectedRooms: 30 })).toBe(false);
  });

  test('a report with no room count at all is believed rather than refused', () => {
    // Refusing on missing data would quietly stop recording anything.
    expect(reportIsBlind({ stats: {}, expectedRooms: 30 })).toBe(false);
    expect(reportIsBlind({})).toBe(false);
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

describe('a person whose Zoom id changes when they reconnect', () => {
  const { diffLiveParticipants } = require('../services/presence/transitions');

  // A teacher handed to the desktop Zoom app sends no customerKey, so the bot
  // reports empty ids and only a name. Zoom issues a new participant id on
  // every connection, so the id alone cannot join their return to their leaving.
  const report = (zoomUserId) => ({
    shift_a: [{
      identity: '', routingUid: '', routing_uid: '',
      zoomUserId, name: 'Aicha Diallo', role: 'teacher', source: 'zoom_hub_bot',
    }],
  });
  const empty = { shift_a: [] };

  test('their return is the same person, not a stranger arriving', () => {
    const { arrivals } = diffLiveParticipants(report(16784384), report(16786432));
    expect(arrivals).toHaveLength(0);
  });

  test('the departure and the return carry one identity', () => {
    const gone = diffLiveParticipants(report(16784384), empty);
    const back = diffLiveParticipants(empty, report(16786432));
    expect(gone.departures).toHaveLength(1);
    expect(back.arrivals).toHaveLength(1);
    expect(gone.departures[0].uid).toBe(back.arrivals[0].uid);
  });

  test('a routing id, when there is one, still wins over the name', () => {
    const withRouting = (uid) => ({ shift_a: [{ routingUid: uid, name: 'Aicha Diallo' }] });
    const { arrivals, departures } = diffLiveParticipants(withRouting('zh_a'), withRouting('zh_b'));
    expect(arrivals.map((a) => a.uid)).toEqual(['zh_b']);
    expect(departures.map((d) => d.uid)).toEqual(['zh_a']);
  });

  test('somebody with no name at all is still seen by their Zoom id', () => {
    const nameless = { shift_a: [{ zoomUserId: 555, name: '' }] };
    const { departures } = diffLiveParticipants(nameless, empty);
    expect(departures.map((d) => d.uid)).toEqual(['zoom:555']);
  });
});

describe('one teacher across several classes is one person', () => {
  const { diffLiveParticipants } = require('../services/presence/transitions');

  // The routing id is zh_<hash(uid:shiftId)> — minted per class. Keying on it
  // split a teacher's week into a row per lesson, each reading "1 class".
  const inClass = (shiftId, routingUid) => ({
    [shiftId]: [{
      identity: 'kjVbNRUjJoZRw3NTd3jIbREdYUu2',
      routingUid,
      zoomUserId: 16784384,
      name: 'habibu barry',
      role: 'teacher',
    }],
  });

  test('the account id is used, not the per-class routing id', () => {
    const { departures } = diffLiveParticipants(inClass('shift_a', 'zh_MwIKYvQ7PU0GQOTwWvaMmvCH'), {});
    expect(departures.map((d) => d.uid)).toEqual(['kjVbNRUjJoZRw3NTd3jIbREdYUu2']);
  });

  test('the same teacher in a different class keeps the same identity', () => {
    const monday = diffLiveParticipants(inClass('shift_a', 'zh_MwIKYvQ7PU0GQOTwWvaMmvCH'), {});
    const tuesday = diffLiveParticipants(inClass('shift_b', 'zh_oe-EK2gyxkS5HnQLVYuqz0uk'), {});
    expect(monday.departures[0].uid).toBe(tuesday.departures[0].uid);
  });

  test('the routing id still names somebody the members could not', () => {
    const guest = { identity: '', routingUid: 'zh_someclasskey', name: 'Visitor' };
    const { departures } = diffLiveParticipants({ shift_a: [guest] }, {});
    expect(departures.map((d) => d.uid)).toEqual(['zh_someclasskey']);
  });
});
