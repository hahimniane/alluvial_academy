import test from "node:test";
import assert from "node:assert/strict";
import { PENALTY_REASON_LIST as PENALTY_REASONS, penaltyReasonLabel } from "../finance/penalties.ts";
import { readPenaltyEntries, readPenaltyReason } from "../finance/penaltyEntries.ts";

test("the reason list matches the finance spec", () => {
  assert.deepEqual(PENALTY_REASONS.map((r) => r.code), ["late_clock_in", "missed_class", "late_class_report", "left_class_early", "no_camera_or_setup", "conduct", "other"]);
});

test("labels fall back to Other", () => {
  assert.equal(penaltyReasonLabel("late_clock_in"), "Late clock-in");
  assert.equal(penaltyReasonLabel("nonsense"), "Other");
  assert.equal(penaltyReasonLabel(undefined), "Other");
});

test("an old entry reads as other with its text as the note", () => {
  assert.deepEqual(readPenaltyReason(undefined, undefined, "For missing class work"), { reason: "other", note: "For missing class work" });
  assert.deepEqual(readPenaltyReason(undefined, undefined, "—"), { reason: "other", note: "" });
  assert.deepEqual(readPenaltyReason("bogus", "n", "x"), { reason: "other", note: "n" });
});

test("a coded entry keeps its code and note", () => {
  assert.deepEqual(readPenaltyReason("conduct", "rude", "Conduct — rude"), { reason: "conduct", note: "rude" });
});

test("reads coach penalty lines, form penalty and a negative adjustment, skipping bonuses", () => {
  const entries = readPenaltyEntries({
    coachAdjustmentLines: [
      { type: "penalty", amount: 10, reason: "Late clock-in — 5 times", penalty_reason: "late_clock_in", penalty_note: "5 times" },
      { type: "penalty", amount: 4, reason: "for no quiz" },
      { type: "bonus", amount: 3, reason: "Kahoot" },
    ],
    formPenaltyTotal: 6,
    formPenaltyReason: "late_class_report",
    formPenaltyNote: "three missing",
    adminAdjustment: -2,
    adjustmentReason: "rounding",
  });
  assert.equal(entries.length, 4);
  assert.deepEqual(entries.map((e) => [e.source, e.amount, e.reason]), [
    ["coach_line", 10, "late_clock_in"],
    ["coach_line", 4, "other"],
    ["form_penalty", 6, "late_class_report"],
    ["admin_adjustment", 2, "other"],
  ]);
  assert.equal(entries[1].note, "for no quiz");
  assert.equal(entries[3].note, "rounding");
});

test("an audit with no penalties reads as empty", () => {
  assert.deepEqual(readPenaltyEntries(undefined), []);
  assert.deepEqual(readPenaltyEntries({ adminAdjustment: 5, coachAdjustmentLines: [{ type: "bonus", amount: 1 }] }), []);
});
