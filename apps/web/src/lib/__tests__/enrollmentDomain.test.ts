import test from "node:test";
import assert from "node:assert/strict";
import {
  CLASS_TYPES,
  TIME_BLOCKS,
  blockById,
  blockRangeLabel,
  formatMinutes,
  hoursMatchSessions,
  normalizeBlock,
  normalizeClassType,
  pricingTrackFor,
  programScheduleIsComplete,
  sessionFitsBlock,
  slotsFor,
  trackById,
  weeklyHoursFor,
} from "../enrollmentDomain.ts";

test("tracks include Adlam as its own track, priced as tutoring for now", () => {
  assert.equal(trackById("adlam")?.title, "Adlam");
  assert.equal(trackById("islamic")?.title, "Religious Studies");
  // The label used to read "Religious Studies & AdLam"; Adlam has left it.
  assert.ok(!trackById("islamic")?.title.toLowerCase().includes("adlam"));
  assert.equal(pricingTrackFor("adlam"), "tutoring");
  assert.equal(pricingTrackFor("islamic"), "islamic");
});

test("the five blocks tile the whole day with no gap and no overlap", () => {
  const ordered = [...TIME_BLOCKS].sort((a, b) => a.startMinutes - b.startMinutes);
  assert.equal(ordered[0].startMinutes, 0);
  assert.equal(ordered[ordered.length - 1].endMinutes, 1440);
  for (let i = 1; i < ordered.length; i++) {
    assert.equal(ordered[i].startMinutes, ordered[i - 1].endMinutes,
      `${ordered[i - 1].id} must end exactly where ${ordered[i].id} begins`);
  }
});

test("legacy class types migrate as specified", () => {
  assert.equal(normalizeClassType("Group"), "With Other Students");
  // 'Both' has no successor; the narrower reading is the safe one.
  assert.equal(normalizeClassType("Both"), "One-on-One");
  assert.equal(normalizeClassType("One-on-One"), "One-on-One");
  assert.equal(normalizeClassType("Exclusive Family Class"), "Exclusive Family Class");
  assert.equal(normalizeClassType(""), "One-on-One");
  assert.equal(normalizeClassType(undefined), "One-on-One");
});

test("'Flexible' is dropped rather than guessed at", () => {
  assert.equal(normalizeBlock("Flexible"), null);
  assert.equal(normalizeBlock(""), null);
  assert.equal(normalizeBlock("Evening"), "Evening");
  assert.equal(normalizeBlock("Night"), "Night");
});

test("only 'With Other Students' takes the timetable out of the family's hands", () => {
  const asks = CLASS_TYPES.filter((t) => t.familyPicksTimes).map((t) => t.value);
  assert.deepEqual(asks, ["One-on-One", "Exclusive Family Class"]);
});

test("teacher slots slide by 30 minutes — the original bug", () => {
  // Evening is 4:00 PM – 8:59 PM. A 2-hour session must offer every half-hour
  // start, not just the non-overlapping 4–6 and 6–8.
  const evening = blockById("Evening")!;
  const slots = slotsFor(evening, 120, 30);
  assert.deepEqual(slots, [
    "4:00 PM - 6:00 PM",
    "4:30 PM - 6:30 PM",
    "5:00 PM - 7:00 PM",
    "5:30 PM - 7:30 PM",
    "6:00 PM - 8:00 PM",
    "6:30 PM - 8:30 PM",
    "7:00 PM - 9:00 PM",
  ]);
  // Stepping by a whole session is what used to hide the rest.
  assert.deepEqual(slotsFor(evening, 120, 120), ["4:00 PM - 6:00 PM", "6:00 PM - 8:00 PM"]);
});

test("a 60-minute session in the evening gives all nine windows", () => {
  assert.equal(slotsFor(blockById("Evening"), 60, 30).length, 9);
});

test("a session that cannot fit its block yields nothing", () => {
  // Late night is only 5 hours; a 2-hour session fits, a 6-hour one cannot.
  assert.ok(sessionFitsBlock(blockById("Late night"), 120));
  assert.equal(slotsFor(blockById("Late night"), 360, 30).length, 0);
  assert.equal(sessionFitsBlock(blockById("Late night"), 360), false);
  // Night is 9:00 PM – 11:59 PM: 3 hours, so a 2-hour session fits but only just.
  assert.ok(sessionFitsBlock(blockById("Night"), 120));
  assert.equal(sessionFitsBlock(blockById("Night"), 180), true);
  assert.equal(sessionFitsBlock(blockById("Night"), 210), false);
});

test("slots never cross midnight", () => {
  for (const block of TIME_BLOCKS) {
    for (const slot of slotsFor(block, 60, 30)) {
      assert.ok(!slot.includes("undefined"), slot);
    }
  }
  // Night ends at 1440, so the last slot ends at 11:59 PM at the latest.
  const nightSlots = slotsFor(blockById("Night"), 60, 30);
  assert.equal(nightSlots[nightSlots.length - 1], "11:00 PM - 12:00 AM");
});

test("bad input produces no slots rather than throwing", () => {
  assert.deepEqual(slotsFor(null, 60), []);
  assert.deepEqual(slotsFor(blockById("Evening"), 0), []);
  assert.deepEqual(slotsFor(blockById("Evening"), -30), []);
  assert.deepEqual(slotsFor(blockById("Evening"), 60, 0), []);
});

test("hours and sessions are reconciled, not silently corrected", () => {
  assert.equal(weeklyHoursFor(3, 60), 3);
  assert.equal(weeklyHoursFor(2, 90), 3);
  assert.equal(weeklyHoursFor(3, 30), 1.5);
  assert.ok(hoursMatchSessions(3, 3, 60));
  // The handoff's own example: 3 × 1 hour is 3 hrs, but the family asked for 2.
  assert.equal(hoursMatchSessions(2, 3, 60), false);
});

test("formatting matches the design copy", () => {
  assert.equal(formatMinutes(0), "12:00 AM");
  assert.equal(formatMinutes(720), "12:00 PM");
  assert.equal(formatMinutes(960), "4:00 PM");
  assert.equal(blockRangeLabel(blockById("Evening")!), "4:00 PM – 8:59 PM");
  assert.equal(blockRangeLabel(blockById("Night")!), "9:00 PM – 11:59 PM");
});

test("a program is only schedulable with days, a block, and a session that fits", () => {
  const base = {
    subject: "Religious Studies (Quran, Arabic, etc...)",
    level: "Beginner",
    classType: "One-on-One" as const,
    sessionMinutes: 60,
    sessionsPerWeek: 2,
    hoursPerWeek: 2,
    days: ["Mon", "Wed"],
    block: "Evening" as const,
  };
  assert.equal(programScheduleIsComplete(base), true);
  assert.equal(programScheduleIsComplete({ ...base, days: [] }), false);
  assert.equal(programScheduleIsComplete({ ...base, block: null }), false);
  // 4 hours cannot fit inside the 3-hour Night block.
  assert.equal(programScheduleIsComplete({ ...base, block: "Night", sessionMinutes: 240 }), false);
});
