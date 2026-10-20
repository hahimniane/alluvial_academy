import test from "node:test";
import assert from "node:assert/strict";
import {
  REPUBLISH_REASON_MAX,
  normalizeRepublishReason,
  previousMatchLine,
  readPreviousMatches,
  republishConfirmBody,
  toDate,
} from "../previousMatches.ts";

test("readPreviousMatches reads Timestamp-like, raw and Date values, oldest first", () => {
  const matches = readPreviousMatches([
    { teacherId: "t2", teacherName: "Ousmane Sow", unmatchedAt: { seconds: 1_790_000_000 }, reason: "Moved away" },
    {
      teacherId: "t1",
      teacherName: "Mariama Bah",
      matchedAt: { toDate: () => new Date("2026-06-01T12:00:00Z") },
      unmatchedAt: new Date("2026-08-01T12:00:00Z"),
      reason: " Teacher left ",
      byName: "Hawa Admin",
    },
  ]);
  assert.deepEqual(matches.map((m) => m.teacherName), ["Mariama Bah", "Ousmane Sow"]);
  assert.equal(matches[0].reason, "Teacher left");
  assert.equal(matches[0].matchedAt?.toISOString(), "2026-06-01T12:00:00.000Z");
  assert.equal(matches[1].unmatchedAt?.getTime(), 1_790_000_000_000);
});

test("readPreviousMatches ignores junk and entries with no teacher", () => {
  assert.deepEqual(readPreviousMatches(undefined), []);
  assert.deepEqual(readPreviousMatches("x"), []);
  assert.deepEqual(readPreviousMatches([null, 3, { reason: "no teacher" }]), []);
});

test("toDate handles the shapes Firestore hands back", () => {
  assert.equal(toDate(null), null);
  assert.equal(toDate(new Date("invalid")), null);
  assert.equal(toDate({ _seconds: 10 })?.getTime(), 10_000);
});

test("previousMatchLine reads as one plain sentence", () => {
  const [match] = readPreviousMatches([
    { teacherName: "Mariama Bah", unmatchedAt: new Date("2026-10-20T15:00:00Z"), reason: "Teacher left" },
  ]);
  assert.equal(previousMatchLine(match, "UTC"), "Previously matched with Mariama Bah · Oct 20, 2026 · Teacher left");

  const [bare] = readPreviousMatches([{ teacherId: "t9" }]);
  assert.equal(previousMatchLine(bare, "UTC"), "Previously matched with a teacher");
});

test("the confirm copy names the student and promises nothing changes for them", () => {
  assert.equal(
    republishConfirmBody("Amina"),
    "Teachers will see Amina on the job board again. Their account, parent and current classes stay as they are.",
  );
});

test("normalizeRepublishReason matches what the callable stores", () => {
  assert.equal(normalizeRepublishReason("  Teacher \n left "), "Teacher left");
  assert.equal(normalizeRepublishReason("x".repeat(400)).length, REPUBLISH_REASON_MAX);
});
