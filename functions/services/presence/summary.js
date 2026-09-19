'use strict';

/**
 * Turning a class's absences into the numbers a person reads.
 *
 * Three figures, because a count on its own misleads in both directions: five
 * forty-second blips look worse than one twenty-five minute collapse, and it is
 * the collapse that ruined the lesson. So each person gets how often they went,
 * how much teaching time they lost, and the longest single absence — which is
 * what separates "irritating connection" from "gone for half the class".
 *
 * Only absences we could not trace to ourselves count toward anybody. The rest
 * are kept, labelled, because they are how we find our own next bug.
 */

const {
  CAUSE_INDIVIDUAL,
  CAUSE_PLATFORM,
  CAUSE_SIMULTANEOUS,
} = require('./transitions');

/**
 * Absences shorter than this are not worth a conversation. Applied here at read
 * time rather than when recording, so the line can be moved once real numbers
 * show where routing noise ends and genuine drops begin.
 */
const DEFAULT_MIN_ABSENCE_SECONDS = 30;

const _emptyTally = () => ({ drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 });

/**
 * Whether an absence is long enough to report.
 *
 * An absence with no known duration is one that never ended — the person left
 * and did not come back. That is the most serious kind, so it always counts;
 * measuring it against a minimum would silently drop the worst cases.
 */
const _isReportable = (absence, minSeconds) =>
  absence.seconds === null || absence.seconds >= minSeconds;

const _add = (tally, absence) => {
  tally.drops += 1;
  if (Number.isFinite(absence.seconds)) {
    tally.secondsLost += absence.seconds;
    tally.longestSeconds = Math.max(tally.longestSeconds, absence.seconds);
  }
  if (absence.returned === false) tally.neverReturned += 1;
};

/**
 * Per person, for one class.
 *
 * `counted` is the number that belongs to that person: individual absences
 * only. `byCause` keeps the whole picture, so an admin looking at a bad week
 * can see at a glance whether it was the teacher's line or our hub.
 */
function summariseAbsences(absences, { minSeconds = DEFAULT_MIN_ABSENCE_SECONDS } = {}) {
  const byUid = new Map();

  for (const absence of absences) {
    if (!_isReportable(absence, minSeconds)) continue;
    const uid = String(absence.uid || '').trim();
    if (!uid) continue;

    if (!byUid.has(uid)) {
      byUid.set(uid, {
        uid,
        role: absence.role || null,
        name: absence.name || null,
        counted: _emptyTally(),
        byCause: {
          [CAUSE_INDIVIDUAL]: _emptyTally(),
          [CAUSE_SIMULTANEOUS]: _emptyTally(),
          [CAUSE_PLATFORM]: _emptyTally(),
        },
        spells: [],
      });
    }
    const entry = byUid.get(uid);
    entry.role = entry.role || absence.role || null;
    entry.name = entry.name || absence.name || null;

    const cause = absence.cause || CAUSE_INDIVIDUAL;
    if (entry.byCause[cause]) _add(entry.byCause[cause], absence);
    if (cause === CAUSE_INDIVIDUAL) _add(entry.counted, absence);

    // The clock times behind the count. A total a teacher cannot check is a
    // total they cannot disagree with, and the raw events are deleted with the
    // class after sixty days — so each spell is kept here, where the summary
    // lives for good. Ours are kept alongside theirs and stay labelled.
    entry.spells.push({
      from: absence.startedAtMs ?? null,
      to: absence.endedAtMs ?? null,
      seconds: Number.isFinite(absence.seconds) ? absence.seconds : null,
      returned: absence.returned !== false,
      cause,
    });
  }

  return [...byUid.values()].sort((a, b) => b.counted.drops - a.counted.drops);
}

/**
 * How many classes a period keeps the detail of, per person.
 *
 * Enough to answer any argument worth having, bounded because a Firestore
 * document is not allowed to grow forever. The totals are never trimmed — only
 * the oldest supporting detail is, and the raw events outlive that anyway.
 */
const MAX_OCCASIONS_KEPT = 60;

/**
 * The record of one class in which somebody dropped out.
 *
 * This is what a teacher is shown when they say the number is wrong: the day,
 * the class, the student it was with, and the clock times they were gone.
 */
const _occasionFrom = (summary, person) => ({
  shiftId: summary.shift_id || null,
  className: summary.class_name || null,
  students: Array.isArray(summary.students) ? summary.students : [],
  // The hours the class was meant to run, so a drop can be read against it.
  startedAt: summary.shift_start_ms ?? null,
  endedAt: summary.shift_end_ms ?? null,
  drops: person.counted.drops,
  secondsLost: person.counted.secondsLost,
  longestSeconds: person.counted.longestSeconds,
  neverReturned: person.counted.neverReturned,
  spells: Array.isArray(person.spells) ? person.spells : [],
});

/** Roll per-class summaries into a week or a month, per person. */
function rollUp(classSummaries) {
  const byUid = new Map();

  for (const summary of classSummaries) {
    for (const person of summary.people || []) {
      const uid = String(person.uid || '').trim();
      if (!uid) continue;
      if (!byUid.has(uid)) {
        byUid.set(uid, {
          uid,
          role: person.role || null,
          name: person.name || null,
          classes: 0,
          classesWithADrop: 0,
          counted: _emptyTally(),
          byCause: {
            [CAUSE_INDIVIDUAL]: _emptyTally(),
            [CAUSE_SIMULTANEOUS]: _emptyTally(),
            [CAUSE_PLATFORM]: _emptyTally(),
          },
          occasions: [],
        });
      }
      const entry = byUid.get(uid);
      entry.role = entry.role || person.role || null;
      entry.name = entry.name || person.name || null;
      entry.classes += 1;
      if (person.counted.drops > 0) {
        entry.classesWithADrop += 1;
        entry.occasions.push(_occasionFrom(summary, person));
      }

      const merge = (into, from) => {
        into.drops += from.drops;
        into.secondsLost += from.secondsLost;
        into.neverReturned += from.neverReturned;
        into.longestSeconds = Math.max(into.longestSeconds, from.longestSeconds);
      };
      merge(entry.counted, person.counted);
      for (const cause of Object.keys(entry.byCause)) {
        if (person.byCause && person.byCause[cause]) merge(entry.byCause[cause], person.byCause[cause]);
      }
    }
  }

  // Most recent class first: an argument is nearly always about a recent one.
  for (const entry of byUid.values()) {
    entry.occasions.sort((a, b) => (b.startedAt ?? 0) - (a.startedAt ?? 0));
    entry.occasions = entry.occasions.slice(0, MAX_OCCASIONS_KEPT);
  }

  return [...byUid.values()].sort((a, b) => b.counted.drops - a.counted.drops);
}

module.exports = {
  DEFAULT_MIN_ABSENCE_SECONDS,
  summariseAbsences,
  rollUp,
};
