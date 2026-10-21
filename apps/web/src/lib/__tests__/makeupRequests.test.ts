import assert from "node:assert/strict";
import { test } from "node:test";
import {
  buildMakeupRequestFields,
  canRequestMakeup,
  isShiftAfterStrictPolicy,
  latestRequestByShift,
  makeupDurationMinutes,
  parseMakeupRequest,
  type MakeupSourceShift,
} from "../makeupRequests.ts";

const shift = (over: Partial<MakeupSourceShift> = {}): MakeupSourceShift => ({
  id: "shift_1",
  teacherId: "teacher_1",
  teacherName: "Mariama Bah",
  subject: "quranStudies",
  subjectId: "subj_quran",
  subjectDisplayName: "Quran",
  studentIds: ["student_1"],
  studentNames: ["Amina Diallo"],
  teacherTimezone: "Africa/Conakry",
  start: new Date("2026-11-05T14:00:00Z"),
  end: new Date("2026-11-05T14:45:00Z"),
  ...over,
});

test("the cutoff is midnight in New York on 2026-11-01, not midnight UTC", () => {
  assert.equal(isShiftAfterStrictPolicy(new Date("2026-11-01T00:00:00Z")), false); // Oct 31 8 PM ET
  assert.equal(isShiftAfterStrictPolicy(new Date("2026-11-01T03:30:00Z")), false); // Oct 31 11:30 PM ET
  assert.equal(isShiftAfterStrictPolicy(new Date("2026-11-01T04:00:00Z")), true); // Nov 1 midnight ET
  assert.equal(isShiftAfterStrictPolicy(new Date("2026-11-01T04:30:00Z")), true); // Nov 1 12:30 AM ET
  assert.equal(isShiftAfterStrictPolicy(null), false);
});

test("a request keeps the missed class's length and only the keys the rules allow", () => {
  const fields = buildMakeupRequestFields({
    shift: shift(),
    proposedStart: new Date("2026-11-12T16:00:00Z"),
    reasonCategory: "internet",
    notes: "  Power cut  ",
  });
  assert.equal(makeupDurationMinutes(shift()), 45);
  assert.equal((fields.proposed_end as Date).toISOString(), "2026-11-12T16:45:00.000Z");
  assert.equal(fields.status, "pending");
  assert.equal(fields.teacher_id, "teacher_1");
  assert.equal(fields.original_shift_id, "shift_1");
  assert.equal(fields.subject, "Quran");
  assert.equal(fields.notes, "Power cut");
  const allowed = new Set([
    "teacher_id", "teacher_name", "original_shift_id", "subject", "subject_id", "subject_display_name",
    "student_ids", "student_names", "proposed_start", "proposed_end", "proposed_timezone",
    "reason_category", "notes", "status", "created_at", "updated_at",
  ]);
  for (const key of Object.keys(fields)) assert.ok(allowed.has(key), `${key} is not writable by a teacher`);
  assert.equal("hourly_rate" in fields, false);
});

test("an unknown reason is filed as other, and a class with no length gets an hour", () => {
  const fields = buildMakeupRequestFields({
    shift: shift({ end: null }),
    proposedStart: new Date("2026-11-12T16:00:00Z"),
    reasonCategory: "made_up",
    notes: "",
  });
  assert.equal(fields.reason_category, "other");
  assert.equal((fields.proposed_end as Date).toISOString(), "2026-11-12T17:00:00.000Z");
});

test("the newest request per class wins, and a declined one can be filed again", () => {
  const older = parseMakeupRequest("a", { original_shift_id: "shift_1", status: "declined", decline_reason: "Busy", created_at: new Date("2026-11-06T10:00:00Z") });
  const newer = parseMakeupRequest("b", { original_shift_id: "shift_1", status: "pending", created_at: new Date("2026-11-07T10:00:00Z") });
  const latest = latestRequestByShift([newer, older]);
  assert.equal(latest.get("shift_1")?.id, "b");

  const start = new Date("2026-11-05T14:00:00Z");
  assert.equal(canRequestMakeup("missed", start, undefined), true);
  assert.equal(canRequestMakeup("missed", start, older), true);
  assert.equal(canRequestMakeup("missed", start, newer), false);
  assert.equal(canRequestMakeup("completed", start, undefined), false);
  assert.equal(canRequestMakeup("missed", new Date("2026-10-20T14:00:00Z"), undefined), false);
});

test("parses a stored request defensively", () => {
  const parsed = parseMakeupRequest("r", {
    teacher_id: "t",
    status: "weird",
    student_names: ["A", 3],
    proposed_start: { seconds: 1794499200 },
  });
  assert.equal(parsed.status, "pending");
  assert.deepEqual(parsed.studentNames, ["A"]);
  assert.equal(parsed.proposedStart?.toISOString(), new Date(1794499200 * 1000).toISOString());
  assert.equal(parsed.reasonCategory, "other");
});
