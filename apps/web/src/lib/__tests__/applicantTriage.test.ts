import test from "node:test";
import assert from "node:assert/strict";
import {
  STAGE_FILTERS,
  countByStage,
  daysWaiting,
  groupByTeacher,
  isStale,
  matchesSearch,
  setupFor,
  sortApplicants,
  type TriageApplicant,
} from "../applicantTriage.ts";

const applicant = (over: Partial<TriageApplicant> = {}): TriageApplicant => ({
  id: "e1",
  studentName: "Amina Diallo",
  parentName: "Fatou Diallo",
  programTitle: "Religious Studies",
  teacherName: "Mariama Bah",
  submittedAt: new Date("2026-08-01T10:00:00Z"),
  matchedAt: new Date("2026-08-20T10:00:00Z"),
  studentUserId: "uid-1",
  parentLinked: false,
  ...over,
});

test("setup advances only in order: account, then schedule, then parent", () => {
  const noAccount = setupFor({ studentUserId: "", parentLinked: false }, false);
  assert.equal(noAccount.stage, "needs-account");
  assert.equal(noAccount.nextAction, "Next: create account");

  const noSchedule = setupFor({ studentUserId: "uid-1", parentLinked: false }, false);
  assert.equal(noSchedule.stage, "needs-schedule");
  assert.equal(noSchedule.nextAction, "Next: finalize schedule");

  const noParent = setupFor({ studentUserId: "uid-1", parentLinked: false }, true);
  assert.equal(noParent.stage, "needs-parent");

  const ready = setupFor({ studentUserId: "uid-1", parentLinked: true }, true);
  assert.equal(ready.stage, "ready");
  assert.equal(ready.nextAction, "Ready to teach");
});

test("a schedule without an account is not counted as scheduled", () => {
  // There is no student uid to have been put on a shift, so the shift cannot
  // belong to this student.
  const state = setupFor({ studentUserId: "  ", parentLinked: true }, true);
  assert.equal(state.hasSchedule, false);
  assert.equal(state.stage, "needs-account");
});

test("a linked parent does not skip the earlier steps", () => {
  const state = setupFor({ studentUserId: "uid-1", parentLinked: true }, false);
  assert.equal(state.stage, "needs-schedule");
  assert.equal(state.hasParent, true);
});

test("search covers student, parent, teacher and program", () => {
  const a = applicant();
  assert.ok(matchesSearch(a, "amina"));
  assert.ok(matchesSearch(a, "FATOU"));
  assert.ok(matchesSearch(a, "bah"));
  assert.ok(matchesSearch(a, "religious"));
  assert.ok(matchesSearch(a, "   "), "blank search matches everything");
  assert.equal(matchesSearch(a, "chemistry"), false);
});

test("sorts order by the field they name", () => {
  const older = applicant({ id: "old", matchedAt: new Date("2026-08-01T00:00:00Z"), studentName: "Zainab" });
  const newer = applicant({ id: "new", matchedAt: new Date("2026-08-30T00:00:00Z"), studentName: "Adam" });
  assert.deepEqual(sortApplicants([older, newer], "recently-matched").map((a) => a.id), ["new", "old"]);
  assert.deepEqual(sortApplicants([newer, older], "longest-waiting").map((a) => a.id), ["old", "new"]);
  assert.deepEqual(sortApplicants([older, newer], "student-az").map((a) => a.id), ["new", "old"]);
});

test("undated rows sort last in both directions rather than jumping to the top", () => {
  const dated = applicant({ id: "dated" });
  const undated = applicant({ id: "undated", matchedAt: null });
  assert.deepEqual(sortApplicants([undated, dated], "recently-matched").map((a) => a.id), ["dated", "undated"]);
  assert.deepEqual(sortApplicants([undated, dated], "longest-waiting").map((a) => a.id), ["dated", "undated"]);
});

test("teacher A–Z breaks ties on student so the order is stable to read", () => {
  const rows = [
    applicant({ id: "b", teacherName: "Bah", studentName: "Zara" }),
    applicant({ id: "a", teacherName: "Bah", studentName: "Adam" }),
    applicant({ id: "c", teacherName: "Ahmed", studentName: "Musa" }),
  ];
  assert.deepEqual(sortApplicants(rows, "teacher-az").map((a) => a.id), ["c", "a", "b"]);
});

test("sorting does not mutate the list it was given", () => {
  const rows = [applicant({ id: "a", studentName: "Zara" }), applicant({ id: "b", studentName: "Adam" })];
  sortApplicants(rows, "student-az");
  assert.deepEqual(rows.map((a) => a.id), ["a", "b"]);
});

test("grouping keeps the sorted order and names the empty teacher", () => {
  const rows = [
    applicant({ id: "1", teacherName: "Bah" }),
    applicant({ id: "2", teacherName: "" }),
    applicant({ id: "3", teacherName: "Bah" }),
  ];
  const groups = groupByTeacher(rows);
  assert.deepEqual(groups.map((g) => g.teacher), ["Bah", "Unassigned"]);
  assert.deepEqual(groups[0].applicants.map((a) => a.id), ["1", "3"]);
});

test("stage counts add up to the total", () => {
  const counts = countByStage(["needs-account", "needs-account", "ready", "needs-parent"]);
  assert.equal(counts.all, 4);
  assert.equal(counts["needs-account"], 2);
  assert.equal(counts["needs-schedule"], 0);
  assert.equal(counts.ready, 1);
  const pills = STAGE_FILTERS.filter((f) => f.id !== "all");
  assert.equal(pills.reduce((sum, f) => sum + counts[f.id], 0), counts.all);
});

test("waiting time is whole days and never negative", () => {
  const now = new Date("2026-09-03T12:00:00Z");
  assert.equal(daysWaiting(new Date("2026-08-27T12:00:00Z"), now), 7);
  assert.equal(daysWaiting(new Date("2026-09-03T11:00:00Z"), now), 0);
  assert.equal(daysWaiting(null, now), null);
  // A clock skew must not render "-1 days".
  assert.equal(daysWaiting(new Date("2026-09-04T12:00:00Z"), now), 0);
});

test("only unfinished matches go stale", () => {
  const now = new Date("2026-09-03T12:00:00Z");
  const old = new Date("2026-08-20T12:00:00Z");
  assert.equal(isStale(old, "needs-account", now), true);
  assert.equal(isStale(old, "ready", now), false, "a finished match is not waiting on anything");
  assert.equal(isStale(new Date("2026-09-01T12:00:00Z"), "needs-account", now), false);
  assert.equal(isStale(null, "needs-account", now), false);
});
