import test from "node:test";
import assert from "node:assert/strict";
import {
  DEFAULT_FILTERS,
  PENALTY_REASONS,
  applyFilters,
  auditMonthsToRead,
  baseRows,
  buildTeacherRows,
  chipCounts,
  chunk,
  historyLine,
  normalizeReasonCode,
  penaltiesCsv,
  penaltyCards,
  periodLabel,
  periodStart,
  reasonBreakdown,
  reasonsText,
  summarizeAudit,
  trendOf,
  type AuditSummary,
  type PenaltyEntry,
} from "../finance/penalties.ts";
import { money } from "../finance/model.ts";

const line = (amount: number, over: Record<string, unknown> = {}) => ({
  type: "penalty",
  amount,
  reason: "old free text",
  createdAt: new Date("2026-07-12T16:00:00Z"),
  createdByName: "Chernor",
  ...over,
});

const audit = (uid: string, name: string, month: string, gross: number, lines: unknown[] = [], totalPenalties = 0) => ({
  id: `${uid}_${month}`,
  data: { userId: uid, teacherName: name, yearMonth: month, paymentSummary: { totalGrossPayment: gross, totalPenalties, coachAdjustmentLines: lines } },
});

const sum = (...a: ReturnType<typeof audit>[]): AuditSummary[] => a.map((x) => summarizeAudit(x)!);

test("reason codes: known codes stay, anything else is Other", () => {
  assert.equal(normalizeReasonCode("late_clock_in"), "late_clock_in");
  assert.equal(normalizeReasonCode("whatever"), "other");
  assert.equal(normalizeReasonCode(undefined), "other");
  assert.equal(PENALTY_REASONS.no_camera_or_setup, "Camera/setup not as required");
  assert.equal(Object.keys(PENALTY_REASONS).length, 7);
});

test("an old penalty line (no code) becomes Other and keeps its text as the note", () => {
  const s = summarizeAudit(audit("t1", "Aisha", "2026-05", 80, [line(20)]))!;
  assert.equal(s.entries.length, 1);
  assert.equal(s.entries[0].reason, "other");
  assert.equal(s.entries[0].note, "old free text");
  assert.equal(s.entries[0].enteredOn, "2026-07-12");
  assert.equal(s.gross, 80);
});

test("a coded line uses its code and penalty_note; bonuses and zero lines are ignored", () => {
  const s = summarizeAudit(
    audit("t1", "Aisha", "2026-05", 80, [
      line(5, { penalty_reason: "late_clock_in", penalty_note: "3 late days" }),
      line(10, { type: "bonus" }),
      line(0),
    ])
  )!;
  assert.equal(s.entries.length, 1);
  assert.deepEqual([s.entries[0].reason, s.entries[0].note, s.entries[0].amount], ["late_clock_in", "3 late days", 5]);
});

test("automatic totalPenalties counts as one Other entry", () => {
  const s = summarizeAudit(audit("t1", "Aisha", "2026-05", 80, [], 4))!;
  assert.deepEqual(s.entries.map((e) => [e.amount, e.reason]), [[4, "other"]]);
});

test("uid falls back to oderId then the document id", () => {
  assert.equal(summarizeAudit({ id: "abc_2026-05", data: { yearMonth: "2026-05", paymentSummary: {} } })!.uid, "abc");
  assert.equal(summarizeAudit({ id: "x", data: { oderId: "o1", yearMonth: "2026-05" } })!.uid, "o1");
  assert.equal(summarizeAudit({ id: "x", data: {} }), null);
});

test("months to read cover the year and the six-month trend window", () => {
  assert.equal(auditMonthsToRead("2026-10")[0], "2026-01");
  assert.equal(auditMonthsToRead("2026-10").length, 10);
  assert.deepEqual(auditMonthsToRead("2026-02"), ["2025-09", "2025-10", "2025-11", "2025-12", "2026-01", "2026-02"]);
  assert.deepEqual(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
});

test("periods", () => {
  assert.equal(periodStart("2026-10", "month"), "2026-10");
  assert.equal(periodStart("2026-10", "last3"), "2026-08");
  assert.equal(periodStart("2026-02", "last3"), "2026-01");
  assert.equal(periodStart("2026-10", "ytd"), "2026-01");
  assert.equal(periodLabel("2026-10", "ytd"), "2026 so far");
  assert.equal(periodLabel("2026-10", "last3"), "Aug 26 – Oct 26");
});

const data = () =>
  sum(
    audit("a", "Aisha", "2026-05", 100, [line(20, { penalty_reason: "late_clock_in" })]),
    audit("a", "Aisha", "2026-08", 100, [line(5, { penalty_reason: "late_clock_in" }), line(10, { penalty_reason: "conduct" })]),
    audit("a", "Aisha", "2026-10", 100, [line(30, { penalty_reason: "missed_class" })]),
    audit("b", "Bilal", "2026-10", 200, []),
    audit("b", "Bilal", "2026-09", 200, []),
    audit("c", "Cheick", "2026-03", 50, [line(3)]),
    audit("c", "Cheick", "2026-10", 50, [])
  );

test("teacher rows: month, year, period, count, % of earnings", () => {
  const rows = buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" });
  assert.equal(rows.length, 3);
  const a = rows.find((r) => r.uid === "a")!;
  assert.equal(a.monthTotal, 30);
  assert.equal(a.ytd, 65);
  assert.equal(a.ytdCount, 4);
  assert.equal(a.periodTotal, 65);
  assert.equal(a.pctLost, (65 / 300) * 100);
  assert.equal(a.lastMonth, "2026-10");
  assert.equal(a.history[0].month, "2026-10");
  const b = rows.find((r) => r.uid === "b")!;
  assert.deepEqual([b.ytd, b.pctLost, b.lastMonth], [0, 0, ""]);
});

test("rows ignore audits after the selected month and count only the selected year", () => {
  const rows = buildTeacherRows(data(), "2026-06", { period: "ytd", reason: "all" });
  const a = rows.find((r) => r.uid === "a")!;
  assert.equal(a.ytd, 20);
  assert.equal(rows.find((r) => r.uid === "b"), undefined);
});

test("period and reason filters narrow the period numbers, not the year", () => {
  const month = buildTeacherRows(data(), "2026-10", { period: "month", reason: "all" }).find((r) => r.uid === "a")!;
  assert.deepEqual([month.periodTotal, month.periodCount, month.ytd], [30, 1, 65]);
  const last3 = buildTeacherRows(data(), "2026-10", { period: "last3", reason: "all" }).find((r) => r.uid === "a")!;
  assert.deepEqual([last3.periodTotal, last3.periodCount], [45, 3]);
  const late = buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "late_clock_in" }).find((r) => r.uid === "a")!;
  assert.deepEqual([late.periodTotal, late.periodCount], [25, 2]);
});

test("trend compares the last three months with the three before", () => {
  const e = (month: string, amount: number): PenaltyEntry => ({ uid: "a", name: "A", month, amount, reason: "other", note: "", enteredOn: "", enteredBy: "" });
  assert.equal(trendOf([e("2026-10", 10), e("2026-06", 5)], "2026-10"), "Rising");
  assert.equal(trendOf([e("2026-10", 5), e("2026-07", 10)], "2026-10"), "Falling");
  assert.equal(trendOf([e("2026-09", 5), e("2026-06", 5)], "2026-10"), "Steady");
  assert.equal(trendOf([], "2026-10"), "Steady");
  // Months after the selected one and older than six months are ignored.
  assert.equal(trendOf([e("2026-11", 99), e("2026-03", 99)], "2026-10"), "Steady");
  // The window crosses the year boundary.
  assert.equal(trendOf([e("2026-01", 8), e("2025-11", 3)], "2026-02"), "Rising");
});

test("show: with / all / none", () => {
  const rows = buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" });
  assert.deepEqual(baseRows(rows, { ...DEFAULT_FILTERS, show: "with" }).map((r) => r.uid).sort(), ["a", "c"]);
  assert.equal(baseRows(rows, { ...DEFAULT_FILTERS, show: "all" }).length, 3);
  assert.deepEqual(baseRows(rows, { ...DEFAULT_FILTERS, show: "none" }).map((r) => r.uid), ["b"]);
});

test("search, amount from/to, at least N times", () => {
  const rows = buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" });
  const f = { ...DEFAULT_FILTERS, show: "all" as const };
  assert.deepEqual(baseRows(rows, { ...f, q: "  ais" }).map((r) => r.uid), ["a"]);
  assert.deepEqual(baseRows(rows, { ...f, min: "10" }).map((r) => r.uid), ["a"]);
  assert.deepEqual(baseRows(rows, { ...f, max: "10" }).map((r) => r.uid).sort(), ["b", "c"]);
  assert.deepEqual(baseRows(rows, { ...f, minTimes: "2" }).map((r) => r.uid), ["a"]);
  assert.equal(baseRows(rows, { ...f, min: "abc" }).length, 3);
});

test("chips and their counts", () => {
  const rows = buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" });
  const f = { ...DEFAULT_FILTERS, show: "all" as const };
  const counts = chipCounts(baseRows(rows, f));
  assert.equal(counts.all, 3);
  assert.equal(counts.repeat, 1); // Aisha has 4
  assert.equal(counts.month, 1);
  assert.equal(counts.rising, 1);
  assert.equal(counts.over5, 1); // 65/300 = 21.7%
  assert.deepEqual(applyFilters(rows, { ...f, chip: "repeat" }).map((r) => r.uid), ["a"]);
});

test("sorting", () => {
  const rows = buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" });
  const f = { ...DEFAULT_FILTERS, show: "all" as const };
  assert.deepEqual(applyFilters(rows, { ...f, sort: "period" }).map((r) => r.uid), ["a", "c", "b"]);
  assert.deepEqual(applyFilters(rows, { ...f, sort: "name" }).map((r) => r.uid), ["a", "b", "c"]);
  assert.deepEqual(applyFilters(rows, { ...f, sort: "times" })[0].uid, "a");
  assert.deepEqual(applyFilters(rows, { ...f, sort: "pct" })[0].uid, "a");
  assert.deepEqual(applyFilters(rows, { ...f, sort: "recent" })[0].uid, "a");
});

test("reason breakdown over what is on screen, biggest first", () => {
  const rows = applyFilters(buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" }), DEFAULT_FILTERS);
  const slices = reasonBreakdown(rows);
  assert.deepEqual(slices.map((s) => [s.code, s.amount, s.count]), [
    ["missed_class", 30, 1],
    ["late_clock_in", 25, 2],
    ["conduct", 10, 1],
    ["other", 3, 1],
  ]);
  assert.equal(slices[0].label, "Missed a class without notice");
});

test("reasons text and history line", () => {
  const a = buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" }).find((r) => r.uid === "a")!;
  assert.equal(reasonsText(a.periodEntries), "Late clock-in ×2, Conduct, Missed a class without notice");
  const old = summarizeAudit(audit("c", "Cheick", "2026-03", 50, [line(3)]))!.entries[0];
  assert.equal(historyLine(old, money), "March 2026 — Other · −$3.00 · old free text (set Jul 12 by Chernor)");
});

test("cards", () => {
  const cards = penaltyCards(buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" }));
  assert.deepEqual(
    [cards.monthTotal, cards.monthTeachers, cards.ytdTotal, cards.ytdCount, cards.teachersWithAny, cards.teachersTotal, cards.teachersRepeat, cards.topReason, cards.topReasonCount],
    [30, 1, 68, 5, 2, 3, 1, "late_clock_in", 2]
  );
});

test("CSV export: header, escaped cells, no formulas from typed text", () => {
  const rows = applyFilters(buildTeacherRows(data(), "2026-10", { period: "ytd", reason: "all" }), DEFAULT_FILTERS);
  const csv = penaltiesCsv(rows, "2026-10", "ytd");
  const lines = csv.replace("﻿", "").trim().split("\r\n");
  assert.equal(lines[0], "Teacher,October 2026,2026 so far,Times,Reasons,% of 2026 earnings,Trend,Last one");
  assert.match(lines[1], /^Aisha,30\.00,65\.00,4,"Late clock-in ×2, Conduct, Missed a class without notice",21\.7,/);
  const evil = summarizeAudit(audit("e", "=HYPERLINK(1)", "2026-10", 10, [line(1)]))!;
  const evilCsv = penaltiesCsv(buildTeacherRows([evil], "2026-10", { period: "ytd", reason: "all" }), "2026-10", "ytd");
  assert.ok(evilCsv.includes("'=HYPERLINK(1)"));
});
