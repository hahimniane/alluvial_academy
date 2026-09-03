import test from "node:test";
import assert from "node:assert/strict";
import { isoWeekdaysFor, nextDateOn, shiftPrefillFor, slotToTimes, toTimeInput } from "../matchSchedule.ts";
import { minutesFromDurationLabel, shiftSubjectSlugForTrack } from "../enrollmentDomain.ts";

const SUBJECTS = [
  { id: "islamicId", name: "islamic" },
  { id: "afroId", name: "afrolingual" },
  { id: "englishId", name: "english" },
  { id: "adultId", name: "adult_class" },
];

test("family day names become ISO weekdays, deduplicated and sorted", () => {
  assert.deepEqual(isoWeekdaysFor(["Sat", "Mon", "Mon", "Sunday"]), [1, 6, 7]);
  assert.deepEqual(isoWeekdaysFor(["Funday"]), [], "an unknown day is dropped, not guessed");
});

test("ranked slot times become time-input values", () => {
  assert.equal(toTimeInput("4:00 PM"), "16:00");
  assert.equal(toTimeInput("12:00 AM"), "00:00");
  assert.equal(toTimeInput("12:30 PM"), "12:30");
  assert.equal(toTimeInput("whenever"), null);
  assert.deepEqual(slotToTimes("4:00 PM - 5:00 PM"), { start: "16:00", end: "17:00" });
  assert.deepEqual(slotToTimes("4:00 PM – 5:30 PM"), { start: "16:00", end: "17:30" });
  assert.equal(slotToTimes("evening"), null);
});

test("the next date lands on one of the family's days, strictly in the future", () => {
  const thu = new Date(2026, 8, 3, 9); // Thu 3 Sep 2026
  const next = nextDateOn([2], thu); // Tuesday
  assert.equal(next?.getDay(), 2);
  assert.equal(next?.getDate(), 8);
  // Same weekday as today still means next week, never today.
  assert.equal(nextDateOn([4], thu)?.getDate(), 10);
  assert.equal(nextDateOn([], thu), null);
});

test("the prefill carries the match: teacher, student, subject, first ranked slot, weekly days", () => {
  const p = shiftPrefillFor(
    {
      teacherId: "t1", teacherName: "ZZ Test Teacher", rankedSlots: ["4:00 PM - 5:00 PM", "4:30 PM - 5:30 PM"],
      days: ["Tue", "Thu"], sessionMinutes: 60, familyTimeZone: "America/New_York", trackId: "islamic",
      programTitle: "Religious Studies (Quran, Arabic, etc...)",
    },
    ["s1"], SUBJECTS, new Date(2026, 8, 3, 9),
  );
  assert.equal(p.staffId, "t1");
  assert.deepEqual(p.studentIds, ["s1"]);
  assert.equal(p.subjectId, "islamicId");
  assert.equal(p.startStr, "16:00");
  assert.equal(p.endStr, "17:00");
  assert.equal(p.recurrenceType, "weekly");
  assert.deepEqual(p.weeklyDays, [2, 4]);
  assert.equal(p.date?.getDate(), 8, "next Tuesday");
  assert.match(p.notes ?? "", /Religious Studies/);
});

test("a slot with only a start time gets the session length as its end", () => {
  const p = shiftPrefillFor(
    { teacherId: "t1", teacherName: "", rankedSlots: ["5:00 AM"], days: ["Sat"], sessionMinutes: 90, familyTimeZone: "", trackId: "adlam", programTitle: "" },
    ["s1"], SUBJECTS,
  );
  assert.equal(p.startStr, "05:00");
  assert.equal(p.endStr, "06:30");
  assert.equal(p.subjectId, "afroId", "Adlam files under the African-languages subject for now");
});

test("no ranked slot and no days still yields a usable prefill rather than throwing", () => {
  const p = shiftPrefillFor(
    { teacherId: "", teacherName: "", rankedSlots: [], days: [], sessionMinutes: 60, familyTimeZone: "", trackId: "tutoring", programTitle: "" },
    ["s1"], SUBJECTS,
  );
  assert.equal(p.staffId, null);
  assert.equal(p.date, null);
  assert.equal(p.startStr, undefined);
  assert.equal(p.recurrenceType, "none");
  assert.equal(p.subjectId, "englishId");
});

test("an exclusive family class books one shift carrying every child", () => {
  const p = shiftPrefillFor(
    { teacherId: "t1", teacherName: "T", rankedSlots: ["4:00 PM - 5:00 PM"], days: ["Tue"], sessionMinutes: 60, familyTimeZone: "America/New_York", trackId: "adlam", programTitle: "Adlam" },
    ["s1", "s2"], SUBJECTS, new Date(2026, 8, 3, 9),
  );
  assert.deepEqual(p.studentIds, ["s1", "s2"], "both children on the same shift");
  assert.equal(p.startStr, "16:00");
  assert.equal(p.recurrenceType, "weekly");
});

test("legacy duration labels read as minutes", () => {
  assert.equal(minutesFromDurationLabel("1 hr"), 60);
  assert.equal(minutesFromDurationLabel("90 mins"), 90);
  assert.equal(minutesFromDurationLabel("1.5 hours"), 90);
  assert.equal(minutesFromDurationLabel("2 hours"), 120);
  assert.equal(minutesFromDurationLabel(""), 60);
});

test("every track maps to a shift subject", () => {
  for (const track of ["islamic", "adlam", "tutoring", "group"]) {
    assert.ok(SUBJECTS.some((s) => s.name === shiftSubjectSlugForTrack(track)), track);
  }
});
