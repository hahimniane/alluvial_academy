import test from "node:test";
import assert from "node:assert/strict";
import {
  bannerText,
  barHeight,
  breakdownRows,
  buildInsights,
  buildTodos,
  findCloseBannerMonth,
  marginPercent,
  MAX_PERIOD_MONTHS,
  monthTodos,
  otherCosts,
  periodMonths,
  periodTitle,
  previousMonths,
  rollups,
  sumMonths,
  yearSeries,
} from "../finance/overview.ts";
import type { MonthSummary } from "../finance/summary.ts";

function row(month: string, over: Partial<MonthSummary> = {}): MonthSummary {
  return {
    month,
    status: "open",
    final: true,
    billed: 1000,
    collected: 800,
    owed: 200,
    discounts: 20,
    credit_open: 0,
    penalties: 5,
    teacher_pay: 400,
    teacher_pay_final: true,
    admin_pay: 100,
    admin_base: 300,
    software: 50,
    marketing: 30,
    transfer_fees: 10,
    other: 10,
    expenses: 600,
    profit: 400,
    invoice_count: 10,
    families_owing: 2,
    recurring_pending: 0,
    recurring_due: 0,
    unpaid_teachers: 0,
    unpaid_admins: 0,
    overdue_invoices: 0,
    first_invoices_this_week: 0,
    teachers: [],
    admins: [],
    ...over,
  };
}

test("periods: 1, 3 and 5 months end with the picked month; custom runs from to", () => {
  assert.deepEqual(periodMonths("1", "2026-10", "", ""), ["2026-10"]);
  assert.deepEqual(periodMonths("3", "2026-10", "", ""), ["2026-08", "2026-09", "2026-10"]);
  assert.deepEqual(periodMonths("5", "2026-02", "", ""), ["2025-10", "2025-11", "2025-12", "2026-01", "2026-02"]);
  assert.deepEqual(periodMonths("custom", "2026-10", "2026-06", "2026-08"), ["2026-06", "2026-07", "2026-08"]);
});

test("a custom period picked backwards still runs forward, and a very long one is cut to the latest months", () => {
  assert.deepEqual(periodMonths("custom", "2026-10", "2026-08", "2026-06"), ["2026-06", "2026-07", "2026-08"]);
  const long = periodMonths("custom", "2026-10", "2020-01", "2026-10");
  assert.equal(long.length, MAX_PERIOD_MONTHS);
  assert.equal(long[long.length - 1], "2026-10");
});

test("the previous period is the same number of months just before", () => {
  assert.deepEqual(previousMonths(["2026-08", "2026-09", "2026-10"]), ["2026-05", "2026-06", "2026-07"]);
  assert.deepEqual(previousMonths(["2026-10"]), ["2026-09"]);
  assert.deepEqual(previousMonths([]), []);
});

test("period titles", () => {
  assert.equal(periodTitle(["2026-10"]), "October 2026");
  assert.equal(periodTitle(["2026-06", "2026-07", "2026-10"]), "June – October 2026");
  assert.equal(periodTitle(["2025-11", "2026-03"]), "November 2025 – March 2026");
});

test("totals add up every month; other costs leave pay out", () => {
  const rows = [row("2026-08"), row("2026-09", { billed: 2000, expenses: 1500, profit: 500, software: 100 })];
  const t = sumMonths(rows);
  assert.equal(t.billed, 3000);
  assert.equal(t.expenses, 2100);
  assert.equal(t.profit, 900);
  assert.equal(t.software, 150);
  assert.equal(t.otherCosts, 150 + 60 + 20 + 20);
  assert.equal(otherCosts(rows[0]), 100);
});

test("margin is profit over billed and 0 when nothing was billed", () => {
  assert.equal(marginPercent(400, 1000), 40);
  assert.equal(marginPercent(-100, 1000), -10);
  assert.equal(marginPercent(50, 0), 0);
});

test("insights: best, weakest, average and the change against the months before", () => {
  const rows = [row("2026-08", { profit: 100 }), row("2026-09", { profit: 500 }), row("2026-10", { profit: -50 })];
  const before = [row("2026-05", { profit: 100 }), row("2026-06", { profit: 100 }), row("2026-07", { profit: 100 })];
  const i = buildInsights(rows, before);
  assert.ok(i);
  assert.equal(i.best.month, "2026-09");
  assert.equal(i.weakest.month, "2026-10");
  assert.equal(i.averageProfit, 550 / 3);
  assert.deepEqual(i.versusPrevious, { change: 250, percent: 83, previousProfit: 300 });
});

test("insights without enough history say so instead of guessing", () => {
  const rows = [row("2026-08"), row("2026-09")];
  assert.equal(buildInsights(rows, null)?.versusPrevious, null);
  assert.equal(buildInsights(rows, [row("2026-07")])?.versusPrevious, null);
  assert.equal(buildInsights([], null), null);
  const flat = buildInsights(rows, [row("2026-06", { profit: 0 }), row("2026-07", { profit: 0 })]);
  assert.equal(flat?.versusPrevious?.percent, null);
});

test("breakdown has the six lines with roll-ups: Staff, Administration, Other", () => {
  const rows = breakdownRows([row("2026-09")]);
  assert.deepEqual(rows.map((r) => r.label), [
    "Teacher pay", "Administrator pay", "Software & subscriptions", "Marketing", "Transfer fees", "Other",
  ]);
  assert.equal(rows[0].bar, 100);
  assert.equal(rows[0].share, Math.round((400 / 600) * 100));
  const groups = rollups(rows);
  assert.deepEqual(groups, [
    { group: "Staff", amount: 500 },
    { group: "Administration", amount: 60 },
    { group: "Other", amount: 40 },
  ]);
});

test("breakdown marks lines that are still estimates", () => {
  const open = row("2026-10", { final: false, teacher_pay_final: false, recurring_pending: 1 });
  const lines = Object.fromEntries(breakdownRows([open]).map((r) => [r.category, r.estimate]));
  assert.equal(lines.teacher_pay, true);
  assert.equal(lines.admin_pay, true);
  assert.equal(lines.software, true);
  assert.equal(lines.marketing, false);
  const closed = Object.fromEntries(breakdownRows([{ ...open, status: "closed" }]).map((r) => [r.category, r.estimate]));
  assert.equal(closed.teacher_pay, false);
});

test("to-dos for an ended month name what is left and where to do it", () => {
  const sep = row("2026-09", { teacher_pay_final: false, final: false, unpaid_teachers: 3, unpaid_admins: 1, recurring_pending: 2 });
  const todos = monthTodos(sep, { ended: true });
  assert.deepEqual(todos.map((t) => t.text), [
    "Teacher audits for September are not all approved",
    "3 teachers not paid for September",
    "1 administrator not paid for September",
    "2 recurring costs to confirm for September",
  ]);
  assert.equal(todos[1].href, "/admin/finance/staff/?month=2026-09");
  assert.equal(todos[3].href, "/admin/finance/expenses/?month=2026-09");
});

test("a month in progress only asks for the recurring costs that are due; a closed month asks for nothing", () => {
  const oct = row("2026-10", { final: false, teacher_pay_final: false, recurring_pending: 3, recurring_due: 1, unpaid_teachers: 4 });
  const todos = monthTodos(oct, { ended: false });
  assert.deepEqual(todos.map((t) => t.text), ["4 teachers not paid for October", "1 recurring cost to confirm for October"]);
  assert.deepEqual(monthTodos(row("2026-09", { status: "closed", unpaid_teachers: 9 }), { ended: true }), []);
});

test("the to-do list puts the month to close first, then the month shown, then school-wide items", () => {
  const sep = row("2026-09", { unpaid_teachers: 2, teacher_pay_final: true });
  const oct = row("2026-10", { final: false, teacher_pay_final: false, teacher_pay: 120, recurring_due: 2 });
  const todos = buildTodos({
    selected: oct,
    selectedEnded: false,
    banner: sep,
    global: { overdue_invoices: 7, first_invoices_this_week: 1 },
  });
  assert.deepEqual(todos.map((t) => t.id), [
    "2026-09:teachers", "2026-10:due", "2026-10:estimate", "overdue", "first",
  ]);
  assert.equal(todos[3].text, "7 invoices are overdue");
  assert.equal(todos[3].href, "/admin/finance/invoices/?status=overdue");
  assert.equal(todos[4].text, "1 first-month invoice created this week");
});

test("the same month is not listed twice, and nothing left gives an empty list", () => {
  const sep = row("2026-09", { unpaid_teachers: 2 });
  const todos = buildTodos({ selected: sep, selectedEnded: true, banner: sep, global: null });
  assert.equal(todos.length, 1);
  assert.deepEqual(buildTodos({ selected: row("2026-08"), selectedEnded: true, banner: null, global: { overdue_invoices: 0, first_invoices_this_week: 0 } }), []);
});

test("the banner is for the most recent ended month that is not closed", () => {
  const rows = [
    row("2026-07", { status: "closed" }),
    row("2026-08", { status: "closed" }),
    row("2026-09"),
    row("2026-10"),
  ];
  assert.equal(findCloseBannerMonth(rows, "2026-10")?.month, "2026-09");
  assert.equal(findCloseBannerMonth([row("2026-09", { status: "closed" }), row("2026-10")], "2026-10"), null);
  assert.equal(findCloseBannerMonth([row("2026-08"), row("2026-09", { status: "closed" })], "2026-10")?.month, "2026-08");
  assert.equal(findCloseBannerMonth([], "2026-10"), null);
});

test("banner text lists what is left, or says it can be closed", () => {
  assert.equal(
    bannerText(row("2026-09", { teacher_pay_final: false, unpaid_teachers: 2, unpaid_admins: 1, recurring_pending: 1 })),
    "teacher audits waiting for approval · 3 people still to pay · 1 cost to confirm.",
  );
  assert.equal(bannerText(row("2026-09", { unpaid_admins: 1 })), "1 person still to pay.");
  assert.equal(bannerText(row("2026-09")), "Everything is done. It can be closed.");
});

test("the year series skips months that have not loaded and flags estimates", () => {
  const map = new Map([
    ["2026-09", row("2026-09")],
    ["2026-10", row("2026-10", { final: false })],
  ]);
  const series = yearSeries(["2026-08", "2026-09", "2026-10"], map);
  assert.deepEqual(series.map((p) => [p.short, p.estimate]), [["Sep", false], ["Oct", true]]);
});

test("bar heights scale to the largest and never vanish", () => {
  assert.equal(barHeight(100, 100, 160), 160);
  assert.equal(barHeight(50, 100, 160), 80);
  assert.equal(barHeight(0.1, 100, 160), 3);
  assert.equal(barHeight(0, 100, 160), 0);
  assert.equal(barHeight(5, 0, 160), 0);
});
