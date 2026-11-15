import assert from "node:assert/strict";
import { test } from "node:test";
import {
  attentionLevel,
  billingPeriod,
  calendarWeeks,
  canJoin,
  cardStatus,
  childAnalytics,
  childProgress,
  childProgressMetrics,
  classesCountLabel,
  cutoffBadge,
  dueChipLabel,
  familyAnalytics,
  familyProgress,
  financialSummary,
  formatActivityDate,
  formatCardDate,
  formatMediumDate,
  formatPaddedDate,
  formatTime,
  formatUsd,
  historyWindow,
  invoiceBadge,
  joinOffset,
  mergeRecentInvoices,
  parseInvoice,
  parsePayment,
  parsePresence,
  parseShift,
  parseTask,
  paymentSubtitle,
  presenceDuration,
  quickStats,
  recentActivity,
  subjectLabel,
  taskCounters,
  taskMatches,
  todayClasses,
  trendLabel,
  upcomingList,
  upcomingPreview,
  weeklyBarHeight,
  type ParentShift,
} from "../parentHome.ts";
import { activeParentItemId, isPushedParentPage, PARENT_ROUTES } from "../parentWeb.ts";

const ts = (d: Date) => ({ toDate: () => d });
// Wednesday 18 November 2026, 10:00 local.
const NOW = new Date(2026, 10, 18, 10, 0, 0);
const hoursAgo = (h: number) => new Date(NOW.getTime() - h * 3_600_000);
const daysAgo = (d: number, hour = 10) => new Date(NOW.getFullYear(), NOW.getMonth(), NOW.getDate() - d, hour);

function shift(id: string, start: Date, extra: Record<string, unknown> = {}, minutes = 60): ParentShift {
  const parsed = parseShift(id, {
    shift_start: ts(start),
    shift_end: ts(new Date(start.getTime() + minutes * 60_000)),
    created_at: ts(daysAgo(60)),
    student_ids: ["c1"],
    status: "scheduled",
    ...extra,
  });
  assert.ok(parsed);
  return parsed;
}

// ─── Parsing ───

test("a class is parsed with Flutter's defaults, and one without its timestamps is skipped", () => {
  const s = shift("a", daysAgo(1), { status: "weird", subject: "nope" });
  assert.equal(s.status, "scheduled");
  assert.equal(s.subject, "quranStudies");
  assert.equal(s.category, "teaching");
  assert.equal(parseShift("b", { shift_start: ts(NOW), shift_end: ts(NOW) }), null, "no created_at");
  assert.equal(parseShift("c", { shift_start: NOW, shift_end: ts(NOW), created_at: ts(NOW) }), null, "not a Timestamp");
  const leader = shift("d", NOW, { shift_category: "leadership" });
  assert.equal(leader.subject, "other");
});

test("subject labels: the card shows a readable name, never the raw enum", () => {
  assert.equal(subjectLabel(shift("a", NOW, { subject_display_name: "Arabic" })), "Arabic");
  assert.equal(subjectLabel(shift("b", NOW, { subject: "fiqh" })), "Islamic Jurisprudence (Fiqh)");
  assert.equal(subjectLabel(shift("c", NOW)), "Quran Studies");
});

test("history window: before `end`, strictly after `start` when given, newest first", () => {
  const list = [shift("old", daysAgo(40)), shift("edge", new Date(NOW.getTime() - 30 * 86_400_000)), shift("new", daysAgo(1)), shift("future", daysAgo(-1))];
  assert.deepEqual(historyWindow(list, NOW, null).map((s) => s.id), ["new", "edge", "old"]);
  assert.deepEqual(historyWindow(list, NOW, new Date(NOW.getTime() - 30 * 86_400_000)).map((s) => s.id), ["new"]);
});

// ─── Family Progress ───

test("child progress: class-status rate, 7-day bars, trend, hours and subjects", () => {
  const shifts = [
    shift("1", daysAgo(0, 8), { status: "completed", subject_display_name: "Arabic" }),
    shift("2", daysAgo(1), { status: "fullyCompleted", subject_display_name: "Arabic" }, 90),
    shift("3", daysAgo(2), { status: "missed" }),
    shift("4", daysAgo(9), { status: "cancelled" }),
    shift("5", daysAgo(10), { status: "partiallyCompleted", subject_display_name: "" }),
    shift("6", daysAgo(3), { status: "scheduled" }),
  ];
  const p = childProgress({ id: "c1", name: "  Amadou  " }, shifts, NOW);
  assert.equal(p.name, "Amadou");
  assert.equal(p.completedClasses, 3);
  assert.equal(p.missedClasses, 1);
  assert.equal(p.cancelledClasses, 1);
  assert.equal(p.totalTrackedClasses, 5);
  assert.equal(p.attendanceRate, 3 / 5);
  assert.equal(p.attentionLevel, "watch");
  assert.equal(p.learningHoursLast30Days, 1 + 1.5 + 1);
  assert.deepEqual(p.weeklyClassCounts, [0, 0, 0, 1, 1, 1, 1]);
  assert.equal(p.classesLast7Days, 4);
  assert.equal(p.previousClasses, 2);
  assert.equal(p.primarySubject, "Arabic");
  assert.deepEqual([...p.subjectBreakdown.entries()], [["Arabic", 2], ["General", 1]]);
});

test("attention levels and the empty child", () => {
  assert.equal(attentionLevel(0, 0), "watch");
  assert.equal(attentionLevel(0.8, 5), "onTrack");
  assert.equal(attentionLevel(0.6, 5), "watch");
  assert.equal(attentionLevel(0.59, 5), "needsSupport");
  const empty = childProgress({ id: "c", name: "" }, [], NOW);
  assert.equal(empty.name, "Student");
  assert.equal(empty.primarySubject, "No completed classes");
});

test("family progress: Needs Support first, average only over tracked children, top 4 subjects", () => {
  const good = childProgress({ id: "a", name: "A" }, [shift("1", daysAgo(1), { status: "completed", subject_display_name: "Quran" })], NOW);
  const bad = childProgress({ id: "b", name: "B" }, [shift("2", daysAgo(1), { status: "missed" })], NOW);
  const none = childProgress({ id: "c", name: "C" }, [], NOW);
  const f = familyProgress([good, none, bad], NOW);
  assert.deepEqual(f.children.map((c) => c.id), ["b", "c", "a"]);
  assert.equal(f.averageAttendanceRate, 0.5);
  assert.equal(f.needsSupportChildren, 1);
  assert.equal(f.classesThisWeek, 2);
  assert.deepEqual(f.topSubjects, [["Quran", 1]]);
  assert.equal(f.dayLabels[6].getDate(), 18);
  assert.equal(f.dayLabels[0].getDate(), 12);
});

test("weekly chart and copy helpers", () => {
  assert.equal(weeklyBarHeight(0, 0), 8);
  assert.equal(weeklyBarHeight(2, 4), 40);
  assert.equal(weeklyBarHeight(4, 4), 70);
  assert.equal(classesCountLabel(1), "1 class");
  assert.equal(classesCountLabel(3), "3 classes");
  assert.equal(trendLabel(0, "Stable vs previous week"), "Stable vs previous week");
  assert.equal(trendLabel(2, "x"), "+2 class activity vs previous week");
  assert.equal(trendLabel(-1, "x"), "-1 class activity vs previous week");
});

// ─── Attendance Analytics ───

test("child analytics: server rates win, otherwise derived, always clamped", () => {
  const a = childAnalytics(
    { id: "c1", name: "A" },
    { metrics: { scheduled_classes: 4, attended_classes: "3", late_classes: 1, on_time_classes: 2, total_student_presence_minutes: 90 }, rates: { attendance_rate: 1.4 }, averages: { average_join_offset_minutes: -2.5 } },
  );
  assert.equal(a.attendedClasses, 3);
  assert.equal(a.attendanceRate, 1);
  assert.equal(a.punctualityRate, 2 / 3);
  assert.equal(a.lateRate, 1 / 3);
  assert.equal(a.totalPresenceMinutes, 90);
  assert.equal(a.averageJoinOffsetMinutes, -2.5);
  const failed = childAnalytics({ id: "c2", name: "" }, null);
  assert.equal(failed.hasReport, false);
  assert.equal(failed.name, "Student");
  assert.equal(failed.attendanceRate, 0);
});

test("family analytics: lowest attendance first, averages over children with scheduled classes", () => {
  const a = childAnalytics({ id: "a", name: "A" }, { metrics: { scheduled_classes: 2, attended_classes: 2, late_classes: 1 }, rates: { punctuality_rate: 0.5 } });
  const b = childAnalytics({ id: "b", name: "B" }, { metrics: { scheduled_classes: 4, attended_classes: 1, student_present_teacher_absent_classes: 2 } });
  const c = childAnalytics({ id: "c", name: "C" }, null);
  const f = familyAnalytics([a, b, c]);
  assert.deepEqual(f.children.map((x) => x.id), ["c", "b", "a"]);
  assert.equal(f.averageAttendanceRate, (1 + 0.25) / 2);
  assert.equal(f.averagePunctualityRate, (0.5 + 0) / 2);
  assert.equal(f.totalLateClasses, 1);
  assert.equal(f.totalTeacherAbsentIncidents, 2);
});

test("join offset wording inputs", () => {
  assert.deepEqual(joinOffset(0), { kind: "onTime" });
  assert.deepEqual(joinOffset(-3.25), { kind: "early", minutes: "3.3" });
  assert.deepEqual(joinOffset(4), { kind: "late", minutes: "4.0" });
  assert.deepEqual(joinOffset(Number.NaN), { kind: "none" });
});

// ─── Money ───

test("money summary: the larger of completed payments and paid_amount; cancelled and settled skipped", () => {
  const invoices = [
    parseInvoice("i1", { total_amount: 100, paid_amount: 20, due_date: ts(daysAgo(3)) }),
    parseInvoice("i2", { total_amount: 50, due_date: ts(daysAgo(-5)) }),
    parseInvoice("i3", { total_amount: 70, status: "cancelled", due_date: ts(daysAgo(10)) }),
    parseInvoice("i4", { total_amount: 30, paid_amount: 30, due_date: ts(daysAgo(10)) }),
  ];
  const payments = [
    parsePayment("p1", { invoice_id: "i1", amount: 40, status: "completed" }),
    parsePayment("p2", { invoice_id: "i2", amount: 50, status: "failed" }),
    parsePayment("p3", { amount: 999, status: "completed" }),
  ];
  assert.deepEqual(financialSummary(invoices, payments, NOW), { outstanding: 60 + 50, overdue: 60 });
});

test("recent invoices merge both owner fields, de-duplicate, latest due first, five at most", () => {
  const mk = (id: string, d: number) => parseInvoice(id, { due_date: ts(daysAgo(d)) });
  const merged = mergeRecentInvoices([mk("a", 1), mk("b", 5)], [mk("b", 5), mk("c", 0), mk("d", 9), mk("e", 7), mk("f", 8)]);
  assert.deepEqual(merged.map((i) => i.id), ["c", "a", "b", "e", "f"]);
});

test("invoice card: badge, due chip, access cutoff and billing period", () => {
  const overdue = parseInvoice("i", { total_amount: 10, due_date: ts(daysAgo(2, 0)), status: "pending" });
  assert.deepEqual(invoiceBadge(overdue, NOW), { label: "OVERDUE", color: "#DC2626" });
  assert.equal(dueChipLabel(overdue, NOW), "2 days overdue");
  assert.equal(cutoffBadge(overdue, NOW)?.label, "Access suspended 1 day ago");
  const soon = parseInvoice("j", { total_amount: 10, due_date: ts(new Date(NOW.getTime() + 2 * 86_400_000)) });
  assert.equal(invoiceBadge(soon, NOW).label, "PENDING");
  assert.equal(dueChipLabel(soon, NOW), "Nov 20");
  assert.equal(cutoffBadge(soon, NOW)?.label, "Access cut off in 3 days");
  const far = parseInvoice("k", { total_amount: 10, due_date: ts(new Date(NOW.getTime() + 20 * 86_400_000)) });
  assert.equal(cutoffBadge(far, NOW), null);
  const paid = parseInvoice("l", { total_amount: 10, paid_amount: 10, status: "paid", due_date: ts(daysAgo(30)) });
  assert.equal(invoiceBadge(paid, NOW).label, "PAID");
  assert.equal(cutoffBadge(paid, NOW), null);
  assert.equal(billingPeriod(parseInvoice("m", { period: "2026-08" })), "August 2026");
  assert.equal(billingPeriod(parseInvoice("n", { period_start: "2026-08-01", period_end: "2026-10-31" })), "Aug 2026 - Oct 2026");
  assert.equal(billingPeriod(parseInvoice("o", { period: "2026-08..2026-09" })), "Aug 2026 - Sep 2026");
  assert.equal(billingPeriod(parseInvoice("p", {})), null);
});

test("payment rows: dollars and STATUS • date", () => {
  assert.equal(formatUsd(1234.5), "$1,234.50");
  assert.equal(paymentSubtitle(parsePayment("p", { status: "completed", created_at: ts(new Date(2026, 10, 5)) })), "COMPLETED • Nov 5, 2026");
  assert.equal(paymentSubtitle(parsePayment("q", { status: "odd" })), "PENDING");
});

// ─── Class card ───

test("card status: a scheduled class whose start passed is Missed; clocked in is In Progress", () => {
  assert.equal(cardStatus(shift("a", hoursAgo(-1)), NOW).label, "Scheduled");
  assert.equal(cardStatus(shift("b", hoursAgo(1)), NOW).label, "Missed");
  assert.equal(cardStatus(shift("c", hoursAgo(1), { status: "partiallyCompleted" }), NOW).label, "Completed");
  assert.equal(cardStatus(shift("d", hoursAgo(1), { status: "active" }), NOW).label, "In Progress");
  // A scheduled class with a clock-in is not "clocked in" (Flutter needs status active too).
  assert.equal(cardStatus(shift("e", hoursAgo(1), { clock_in_time: ts(hoursAgo(1)) }), NOW).label, "Missed");
});

test("join window: 10 minutes either side, teaching classes with students only; live always", () => {
  assert.equal(canJoin(shift("a", new Date(NOW.getTime() + 9 * 60_000)), NOW), true);
  assert.equal(canJoin(shift("b", new Date(NOW.getTime() + 11 * 60_000)), NOW), false);
  assert.equal(canJoin(shift("c", new Date(NOW.getTime() - 69 * 60_000)), NOW), true);
  assert.equal(canJoin(shift("d", new Date(NOW.getTime() - 71 * 60_000)), NOW), false);
  assert.equal(canJoin(shift("e", NOW, { student_ids: [] }), NOW), false);
  assert.equal(canJoin(shift("f", daysAgo(3), { status: "active" }), NOW), true);
});

test("presence: durations and a failed call reads as an empty room", () => {
  assert.equal(presenceDuration(30_000), "Just joined");
  assert.equal(presenceDuration(12 * 60_000), "12m");
  assert.equal(presenceDuration(65 * 60_000), "1h 5m");
  assert.deepEqual(parsePresence(null), { participantCount: 0, participants: [] });
  const p = parsePresence({ participantCount: 1, participants: [{ identity: "u1", name: "T", role: "teacher", joinedAtIso: "2026-11-18T09:00:00Z", isPublisher: true }] });
  assert.equal(p.participants[0].joinedAt?.toISOString(), "2026-11-18T09:00:00.000Z");
});

test("today, upcoming preview and the Classes tab list", () => {
  const list = [
    shift("past-today", daysAgo(0, 8)),
    shift("later-today", daysAgo(0, 20)),
    shift("tomorrow", daysAgo(-1)),
    shift("in-8-days", daysAgo(-8)),
    shift("leader", daysAgo(0, 21), { shift_category: "leadership" }),
    shift("live", hoursAgo(0.5), { status: "active" }),
  ];
  assert.deepEqual(todayClasses(list, NOW).map((s) => s.id), ["past-today", "live", "later-today"]);
  assert.deepEqual(upcomingPreview(list, NOW).map((s) => s.id), ["later-today", "tomorrow"]);
  assert.deepEqual(upcomingList(list.filter((s) => s.category === "teaching"), NOW).map((s) => s.id), ["live", "later-today", "tomorrow", "in-8-days"]);
});

// ─── Calendar ───

test("calendar: Monday-first weeks; completed beats missed beats cancelled beats scheduled", () => {
  const month = new Date(2026, 10, 1); // November 2026 starts on a Sunday.
  const list = [
    shift("a", new Date(2026, 10, 3, 9), { status: "missed" }),
    shift("b", new Date(2026, 10, 3, 11), { status: "completed" }),
    shift("c", new Date(2026, 10, 4, 9), { status: "cancelled" }),
    shift("d", new Date(2026, 10, 4, 11), { status: "scheduled" }),
    shift("e", new Date(2026, 9, 31, 9), { status: "completed" }),
  ];
  const weeks = calendarWeeks(list, month, NOW);
  assert.equal(weeks[0].slice(0, 6).every((c) => c === null), true);
  assert.equal(weeks[0][6]?.day, 1);
  const cell = (day: number) => weeks.flat().find((c) => c?.day === day);
  assert.equal(cell(3)?.status, "completed");
  assert.equal(cell(4)?.status, "cancelled");
  assert.equal(cell(18)?.isToday, true);
  assert.equal(weeks.length, 6);
});

// ─── Tasks ───

test("tasks: Flutter's stored enum strings; a task without a due date is skipped", () => {
  const t = parseTask("t", { title: "Read", dueDate: ts(daysAgo(1)), status: "TaskStatus.done", priority: "TaskPriority.high", attachments: [{}, {}] });
  assert.equal(t?.status, "done");
  assert.equal(t?.priority, "high");
  assert.equal(t?.attachmentCount, 2);
  assert.equal(parseTask("u", { title: "x", status: "done" }), null);
  assert.equal(parseTask("v", { dueDate: ts(NOW), status: "done" })?.status, "todo");
});

test("task counters and filters share one definition", () => {
  const tasks = [
    parseTask("a", { dueDate: ts(daysAgo(1)), status: "TaskStatus.done" })!,
    parseTask("b", { dueDate: ts(daysAgo(1)) })!,
    parseTask("c", { dueDate: ts(daysAgo(-1)), status: "TaskStatus.inProgress" })!,
    parseTask("d", { dueDate: ts(NOW) })!,
  ];
  assert.deepEqual(taskCounters(tasks, NOW), { total: 4, completed: 1, pending: 2, overdue: 1 });
  assert.deepEqual(tasks.filter((t) => taskMatches(t, "pending", NOW)).map((t) => t.id), ["c", "d"]);
});

// ─── Child Overview and Progress ───

test("quick stats and recent activity", () => {
  const past = [shift("a", daysAgo(2), { status: "completed" }), shift("b", daysAgo(3), { status: "fullyCompleted" }), shift("c", daysAgo(40), { status: "missed" })];
  const tasks = [parseTask("t", { dueDate: ts(NOW), status: "TaskStatus.done", completedAt: ts(daysAgo(1)) })!, parseTask("u", { dueDate: ts(NOW) })!];
  assert.deepEqual(quickStats(past, tasks, NOW), { totalClasses: 3, attendanceRate: 1, completedTasks: 1, totalTasks: 2 });
  const activity = recentActivity(tasks, past);
  assert.equal(activity.lastClass?.id, "a", "only status `completed` counts, as in Flutter");
  assert.equal(activity.lastTask?.id, "t");
  assert.equal(recentActivity([], [shift("x", daysAgo(1), { status: "fullyCompleted" })]).lastClass, null);
});

test("progress tab metrics: past classes only, 30-day figures, all-time subjects", () => {
  const list = [
    shift("1", daysAgo(1), { status: "completed", subject_display_name: "Arabic" }),
    shift("2", daysAgo(8), { status: "missed", subject_display_name: "Arabic" }),
    shift("3", daysAgo(45), { status: "completed", subject_display_name: "Quran" }, 120),
    shift("4", daysAgo(-1), { status: "scheduled" }),
  ];
  const m = childProgressMetrics(list, NOW);
  assert.equal(m.completedClasses, 1);
  assert.equal(m.missedClasses, 1);
  assert.equal(m.attendanceRate, 0.5);
  assert.equal(m.classesLast7Days, 1);
  assert.equal(m.classesPrevious7Days, 1);
  assert.equal(m.uniqueSubjectsLast30Days, 1);
  assert.deepEqual(
    m.subjectStats.map((s) => [s.name, s.totalClasses, s.completedClasses, s.totalHours]),
    [["Arabic", 2, 1, 1], ["Quran", 1, 1, 2]],
  );
});

// ─── Formatting and routes ───

test("dates are US English, as in Flutter", () => {
  const d = new Date(2026, 10, 5, 15, 5);
  assert.equal(formatTime(d), "3:05 PM");
  assert.equal(formatCardDate(d), "Thursday, Nov 5, 2026");
  assert.equal(formatPaddedDate(d), "Nov 05, 2026");
  assert.equal(formatMediumDate(d), "Nov 5, 2026");
  assert.equal(formatActivityDate(d), "Nov 05, 2026 • 3:05 PM");
});

test("the child page is pushed over the shell and highlights Dashboard", () => {
  assert.equal(isPushedParentPage("/parent/child/"), true);
  assert.equal(isPushedParentPage("/parent/child"), true);
  assert.equal(isPushedParentPage("/parent/"), false);
  assert.equal(activeParentItemId("/parent/child/"), "dashboard");
  assert.equal(PARENT_ROUTES.child("a b"), "/parent/child/?id=a%20b");
});
