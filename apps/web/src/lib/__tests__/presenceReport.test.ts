import assert from "node:assert/strict";
import { test } from "node:test";
import {
  describeConnection,
  formatDuration,
  platformDrops,
  standingOf,
  tallyOf,
  type PresenceReport,
} from "../presenceReport.ts";

const t = (en: string, vars?: Record<string, string | number>) =>
  en.replace(/\{(\w+)\}/g, (_m, key) => String(vars?.[key] ?? `{${key}}`));

const report = (overrides: Partial<PresenceReport> = {}): PresenceReport => ({
  uid: "teacher_1",
  role: "teacher",
  name: "habibu barry",
  classes: 10,
  classes_with_a_drop: 2,
  counted: { drops: 3, secondsLost: 260, longestSeconds: 200, neverReturned: 0 },
  ...overrides,
});

test("a duration reads the way a person would say it", () => {
  assert.equal(formatDuration(45), "45s");
  assert.equal(formatDuration(60), "1m");
  assert.equal(formatDuration(260), "4m 20s");
  assert.equal(formatDuration(3600), "1h");
  assert.equal(formatDuration(3900), "1h 5m");
  assert.equal(formatDuration(0), "0s");
});

test("a short drop keeps its seconds rather than rounding to nothing", () => {
  // "0m" for a forty-second drop reads as though nothing happened.
  assert.equal(formatDuration(40), "40s");
});

test("a missing or malformed report reads as zero, not as a crash", () => {
  assert.deepEqual(tallyOf(null), { drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 });
  assert.deepEqual(tallyOf(undefined), { drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 });
  assert.equal(tallyOf({ counted: "nonsense" } as unknown as PresenceReport).drops, 0);
});

test("a clean period is steady", () => {
  assert.equal(standingOf(report({ counted: { drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 } })), "steady");
});

test("the occasional drop is unsettled, not struggling", () => {
  assert.equal(standingOf(report({ classes: 10, counted: { drops: 3, secondsLost: 260, longestSeconds: 200, neverReturned: 0 } })), "unsettled");
});

test("dropping repeatedly in every class is struggling", () => {
  assert.equal(standingOf(report({ classes: 4, counted: { drops: 9, secondsLost: 900, longestSeconds: 400, neverReturned: 0 } })), "struggling");
});

test("a class somebody never came back to is struggling however few there are", () => {
  // The worst kind of absence, and it must not be averaged away by a good week.
  assert.equal(standingOf(report({ classes: 40, counted: { drops: 1, secondsLost: 1800, longestSeconds: 1800, neverReturned: 1 } })), "struggling");
});

test("the sentence says what happened, without accusing anyone", () => {
  const line = describeConnection(report(), t);
  assert.equal(line, "You dropped out 3 times across 2 of 10 classes, losing 4m 20s of lesson time.");
});

test("a clean period says so plainly", () => {
  const line = describeConnection(report({ counted: { drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 } }), t);
  assert.equal(line, "Your connection held for every class this period.");
});

test("no classes means nothing to say, not a reassurance nobody asked for", () => {
  assert.equal(describeConnection(report({ classes: 0 }), t), null);
  assert.equal(describeConnection(null, t), null);
});

test("our own faults are counted separately from theirs", () => {
  const withOurs = report({
    by_cause: {
      individual: { drops: 3, secondsLost: 260, longestSeconds: 200, neverReturned: 0 },
      platform: { drops: 2, secondsLost: 400, longestSeconds: 300, neverReturned: 0 },
      simultaneous: { drops: 1, secondsLost: 90, longestSeconds: 90, neverReturned: 0 },
    },
  });
  assert.equal(platformDrops(withOurs), 3);
  // And they never leak into what the teacher is shown as theirs.
  assert.equal(tallyOf(withOurs).drops, 3);
});

test("a report with no cause breakdown reports no platform drops", () => {
  assert.equal(platformDrops(report()), 0);
  assert.equal(platformDrops(null), 0);
});

// --- the evidence a teacher is shown when they say a number is wrong --------

const { occasionsOf, describeStudents, formatOccasionDate, formatSpellTime } =
  await import("../presenceReport.ts");

test("a report with no breakdown yields no classes rather than throwing", () => {
  assert.deepEqual(occasionsOf(null), []);
  assert.deepEqual(occasionsOf({ occasions: undefined } as unknown as PresenceReport), []);
  assert.deepEqual(occasionsOf({ occasions: "nope" } as unknown as PresenceReport), []);
});

test("a class keeps its day, its name and the student it was with", () => {
  const [occasion] = occasionsOf({
    occasions: [{
      shiftId: "shift_mon",
      className: "Quran — Monday",
      students: ["Amadou Diallo", ""],
      startedAt: 1789659779000,
      drops: 2,
      secondsLost: 205,
      longestSeconds: 148,
      neverReturned: 1,
      spells: [{ from: 1789660351324, to: null, seconds: null, returned: false, cause: "individual" }],
    }],
  } as unknown as PresenceReport);

  assert.equal(occasion.className, "Quran — Monday");
  assert.deepEqual(occasion.students, ["Amadou Diallo"]);
  assert.equal(occasion.drops, 2);
  assert.equal(occasion.spells.length, 1);
});

test("a malformed class does not take the rest of the list down with it", () => {
  const occasions = occasionsOf({
    occasions: [null, { shiftId: "ok", drops: 1 }],
  } as unknown as PresenceReport);
  assert.equal(occasions.length, 1);
  assert.equal(occasions[0].shiftId, "ok");
  assert.deepEqual(occasions[0].students, []);
  assert.deepEqual(occasions[0].spells, []);
});

test("students read the way a person would say them", () => {
  assert.equal(describeStudents([]), "");
  assert.equal(describeStudents(["Amadou"]), "Amadou");
  assert.equal(describeStudents(["Amadou", "Fatou"]), "Amadou and Fatou");
  assert.equal(describeStudents(["Amadou", "Fatou", "Ibrahim", "Mariam"]), "Amadou, Fatou and 2 more");
});

test("a missing time prints nothing rather than 1 Jan 1970", () => {
  assert.equal(formatOccasionDate(null), "");
  assert.equal(formatSpellTime(null), "");
  assert.notEqual(formatOccasionDate(1789659779000, "en-GB"), "");
});
