import assert from "node:assert/strict";
import { test } from "node:test";
import { chooseClassReportTemplate, classReportWindowStart, isCancelledShiftStatus, isClassReportEligible } from "../classReport.ts";

const now = new Date("2026-10-16T15:00:00Z");
const hours = (n: number) => n * 60 * 60 * 1000;
const days = (n: number) => n * 24 * hours(1);
const classAt = (startMsAgo: number, status: string, lengthMs = hours(1)) => ({
  start: new Date(now.getTime() - startMsAgo),
  end: new Date(now.getTime() - startMsAgo + lengthMs),
  status,
});

test("an ended class is reportable whatever non-cancelled status it was left in", () => {
  for (const status of ["scheduled", "active", "completed", "fully_completed", "partiallyCompleted", "missed", ""]) {
    assert.equal(isClassReportEligible(classAt(hours(3), status), now), true, status);
  }
});

test("cancelled, deleted and voided classes are refused", () => {
  for (const status of ["cancelled", "Canceled", "cancelled_by_admin", "deleted", "void", "voided"]) {
    assert.equal(isCancelledShiftStatus(status), true, status);
    assert.equal(isClassReportEligible(classAt(hours(3), status), now), false, status);
  }
});

test("a class that has not ended is refused unless it was already closed", () => {
  assert.equal(isClassReportEligible(classAt(hours(0.5), "active"), now), false);
  assert.equal(isClassReportEligible(classAt(hours(0.5), "scheduled"), now), false);
  assert.equal(isClassReportEligible(classAt(hours(0.5), "completed"), now), true);
  assert.equal(isClassReportEligible(classAt(-hours(2), "completed"), now), false);
});

test("the window is the last 60 days: 59 days ago is in, 61 days ago is out", () => {
  assert.equal(isClassReportEligible(classAt(days(59), "scheduled"), now), true);
  assert.equal(isClassReportEligible(classAt(days(61), "completed"), now), false);
  assert.equal(classReportWindowStart(now).toISOString(), "2026-08-17T15:00:00.000Z");
});

test("a class from last calendar month is still reportable", () => {
  const early = new Date("2026-10-01T10:00:00Z");
  const lastMonth = { start: new Date("2026-09-29T10:00:00Z"), end: new Date("2026-09-29T11:00:00Z"), status: "scheduled" };
  assert.equal(isClassReportEligible(lastMonth, early), true);
});

test("missing times are refused", () => {
  assert.equal(isClassReportEligible({ start: null, end: new Date(), status: "completed" }, now), false);
});

const template = (id: string, name: string, extra: Partial<{ frequency: string; isActive: boolean; version: number; updatedAt: Date }> = {}) => ({
  id,
  name,
  frequency: "perSession",
  isActive: true,
  version: 1,
  updatedAt: new Date("2026-01-01"),
  ...extra,
});

test("the configured dailyTemplateId wins while it is active", () => {
  const templates = [template("aaa", "Daily Class Report"), template("daily_class_report", "Class Readiness Form")];
  assert.equal(chooseClassReportTemplate(templates, "daily_class_report")?.id, "daily_class_report");
});

test("an inactive or non per-class configured template is skipped", () => {
  const templates = [
    template("configured", "Old report", { isActive: false }),
    template("weekly", "Weekly Summary", { frequency: "weekly" }),
    template("zzz", "Another per-class form"),
    template("named", "Daily Class Report"),
  ];
  assert.equal(chooseClassReportTemplate(templates, "configured")?.id, "named");
  assert.equal(chooseClassReportTemplate(templates, "weekly")?.id, "named");
});

test("without a daily class report, the newest active per-class template is used, not the first by id", () => {
  const templates = [
    template("aaa", "Session notes", { version: 1 }),
    template("zzz", "Session notes v2", { version: 3 }),
    template("inactive", "Daily Class Report", { isActive: false }),
    template("monthly", "Monthly Review", { frequency: "monthly" }),
  ];
  assert.equal(chooseClassReportTemplate(templates, "")?.id, "zzz");
  assert.equal(chooseClassReportTemplate([...templates].reverse(), null)?.id, "zzz");
});

test("no active per-class template means no class report template", () => {
  assert.equal(chooseClassReportTemplate([template("w", "Weekly", { frequency: "weekly" })], "w"), null);
});
