/**
 * Pure logic for the finance overview: which months a period covers, the
 * totals, insights, breakdown, to-do list and the "month isn't closed" banner.
 * No React, no Firebase, so it can be tested on its own.
 */

import { CATEGORY_GROUP, CATEGORY_LABEL, type ExpenseCategory, type RollupGroup } from "./model.ts";
import { addMonths, monthLabel, monthName, monthRange, monthShort, recentMonths } from "./months.ts";
import type { MonthSummary } from "./summary.ts";

export type PeriodKind = "1" | "3" | "5" | "custom";

/** A custom period longer than this is cut short, to keep the number of month requests bounded. */
export const MAX_PERIOD_MONTHS = 24;

/** Months the period covers, oldest first. 1/3/5 end with `end`; custom runs from `from` to `to`. */
export function periodMonths(kind: PeriodKind, end: string, from: string, to: string): string[] {
  if (kind === "custom") {
    const all = monthRange(from, to);
    return all.length > MAX_PERIOD_MONTHS ? all.slice(all.length - MAX_PERIOD_MONTHS) : all;
  }
  return recentMonths(Number(kind), end);
}

/** The months just before the period, as many as the period has. */
export function previousMonths(months: string[]): string[] {
  if (months.length === 0) return [];
  return recentMonths(months.length, addMonths(months[0], -1));
}

/** "October 2026", "June – October 2026" or "November 2025 – March 2026". */
export function periodTitle(months: string[]): string {
  if (months.length === 0) return "";
  const first = months[0];
  const last = months[months.length - 1];
  if (months.length === 1) return monthLabel(first);
  if (first.slice(0, 4) === last.slice(0, 4)) return `${monthName(first)} – ${monthLabel(last)}`;
  return `${monthLabel(first)} – ${monthLabel(last)}`;
}

/** Costs other than pay: software, marketing, transfer fees and the rest. */
export function otherCosts(row: Pick<MonthSummary, "software" | "marketing" | "transfer_fees" | "other">): number {
  return row.software + row.marketing + row.transfer_fees + row.other;
}

export function marginPercent(profit: number, billed: number): number {
  return billed > 0 ? Math.round((profit / billed) * 100) : 0;
}

/** A month whose numbers can still move: not final, and not closed. */
export function isEstimate(row: Pick<MonthSummary, "final" | "status">): boolean {
  return row.status !== "closed" && !row.final;
}

export type Totals = {
  billed: number;
  collected: number;
  owed: number;
  discounts: number;
  penalties: number;
  teacher_pay: number;
  admin_pay: number;
  software: number;
  marketing: number;
  transfer_fees: number;
  other: number;
  otherCosts: number;
  expenses: number;
  profit: number;
};

export function sumMonths(rows: MonthSummary[]): Totals {
  const total = (pick: (r: MonthSummary) => number) => rows.reduce((sum, r) => sum + pick(r), 0);
  const software = total((r) => r.software);
  const marketing = total((r) => r.marketing);
  const transfer = total((r) => r.transfer_fees);
  const other = total((r) => r.other);
  return {
    billed: total((r) => r.billed),
    collected: total((r) => r.collected),
    owed: total((r) => r.owed),
    discounts: total((r) => r.discounts),
    penalties: total((r) => r.penalties),
    teacher_pay: total((r) => r.teacher_pay),
    admin_pay: total((r) => r.admin_pay),
    software,
    marketing,
    transfer_fees: transfer,
    other,
    otherCosts: software + marketing + transfer + other,
    expenses: total((r) => r.expenses),
    profit: total((r) => r.profit),
  };
}

export type Insights = {
  best: MonthSummary;
  weakest: MonthSummary;
  averageProfit: number;
  margin: number;
  /** Profit now against the same number of months just before; null without that history. */
  versusPrevious: { change: number; percent: number | null; previousProfit: number } | null;
};

export function buildInsights(rows: MonthSummary[], previous: MonthSummary[] | null): Insights | null {
  if (rows.length === 0) return null;
  const byProfit = [...rows].sort((a, b) => b.profit - a.profit);
  const totals = sumMonths(rows);
  let versus: Insights["versusPrevious"] = null;
  if (previous && previous.length === rows.length) {
    const previousProfit = sumMonths(previous).profit;
    versus = {
      change: totals.profit - previousProfit,
      percent: previousProfit !== 0 ? Math.round(((totals.profit - previousProfit) / Math.abs(previousProfit)) * 100) : null,
      previousProfit,
    };
  }
  return {
    best: byProfit[0],
    weakest: byProfit[byProfit.length - 1],
    averageProfit: totals.profit / rows.length,
    margin: marginPercent(totals.profit, totals.billed),
    versusPrevious: versus,
  };
}

export type BreakdownRow = {
  category: ExpenseCategory;
  label: string;
  group: RollupGroup;
  amount: number;
  /** Share of all expenses, 0-100. */
  share: number;
  /** Bar length relative to the largest row, 0-100. */
  bar: number;
  estimate: boolean;
};

export const BREAKDOWN_ORDER: ExpenseCategory[] = ["teacher_pay", "admin_pay", "software", "marketing", "transfer_fees", "other"];

export function breakdownRows(rows: MonthSummary[]): BreakdownRow[] {
  const totals = sumMonths(rows);
  const amounts: Record<ExpenseCategory, number> = {
    teacher_pay: totals.teacher_pay,
    admin_pay: totals.admin_pay,
    software: totals.software,
    marketing: totals.marketing,
    transfer_fees: totals.transfer_fees,
    other: totals.other,
  };
  const estimateFor: Record<ExpenseCategory, boolean> = {
    teacher_pay: rows.some((r) => r.status !== "closed" && !r.teacher_pay_final),
    admin_pay: rows.some(isEstimate),
    software: rows.some((r) => r.status !== "closed" && r.recurring_pending > 0),
    marketing: false,
    transfer_fees: false,
    other: false,
  };
  const max = Math.max(1, ...BREAKDOWN_ORDER.map((c) => amounts[c]));
  return BREAKDOWN_ORDER.map((category) => ({
    category,
    label: CATEGORY_LABEL[category],
    group: CATEGORY_GROUP[category],
    amount: amounts[category],
    share: totals.expenses > 0 ? Math.round((amounts[category] / totals.expenses) * 100) : 0,
    bar: Math.round((amounts[category] / max) * 100),
    estimate: estimateFor[category] && amounts[category] > 0,
  }));
}

export const ROLLUP_ORDER: RollupGroup[] = ["Staff", "Administration", "Other"];

export function rollups(rows: BreakdownRow[]): { group: RollupGroup; amount: number }[] {
  return ROLLUP_ORDER.map((group) => ({
    group,
    amount: rows.filter((r) => r.group === group).reduce((sum, r) => sum + r.amount, 0),
  }));
}

export type TodoTone = "warn" | "bad" | "info" | "mute" | "first";

export type Todo = { id: string; text: string; href: string; tone: TodoTone };

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;

/** What is left to do for one month, as plain sentences with the page to do it on. */
export function monthTodos(row: MonthSummary, opts: { ended: boolean }): Todo[] {
  const name = monthName(row.month);
  const out: Todo[] = [];
  const staff = `/admin/finance/staff/?month=${row.month}`;
  const expenses = `/admin/finance/expenses/?month=${row.month}`;
  if (row.status === "closed") return out;
  if (opts.ended && !row.teacher_pay_final) {
    out.push({ id: `${row.month}:audits`, text: `Teacher audits for ${name} are not all approved`, href: staff, tone: "warn" });
  }
  if (row.unpaid_teachers > 0) {
    out.push({ id: `${row.month}:teachers`, text: `${plural(row.unpaid_teachers, "teacher", "teachers")} not paid for ${name}`, href: staff, tone: "warn" });
  }
  if (row.unpaid_admins > 0) {
    out.push({ id: `${row.month}:admins`, text: `${plural(row.unpaid_admins, "administrator", "administrators")} not paid for ${name}`, href: staff, tone: "warn" });
  }
  if (opts.ended && row.recurring_pending > 0) {
    out.push({ id: `${row.month}:recurring`, text: `${plural(row.recurring_pending, "recurring cost", "recurring costs")} to confirm for ${name}`, href: expenses, tone: "warn" });
  } else if (!opts.ended && row.recurring_due > 0) {
    out.push({ id: `${row.month}:due`, text: `${plural(row.recurring_due, "recurring cost", "recurring costs")} to confirm for ${name}`, href: expenses, tone: "warn" });
  }
  return out;
}

/**
 * The to-do list: what is left for the month that needs closing, what is
 * left for the month being looked at, then the school-wide items.
 */
export function buildTodos(args: {
  selected: MonthSummary | null;
  selectedEnded: boolean;
  banner: MonthSummary | null;
  global: Pick<MonthSummary, "overdue_invoices" | "first_invoices_this_week"> | null;
}): Todo[] {
  const { selected, selectedEnded, banner, global } = args;
  const out: Todo[] = [];
  if (banner) out.push(...monthTodos(banner, { ended: true }));
  if (selected && (!banner || selected.month !== banner.month)) {
    out.push(...monthTodos(selected, { ended: selectedEnded }));
    if (!selectedEnded && selected.status !== "closed" && selected.teacher_pay > 0 && !selected.teacher_pay_final) {
      out.push({
        id: `${selected.month}:estimate`,
        text: `${monthName(selected.month)} audits are in progress. Teacher pay is an estimate until they are approved`,
        href: `/admin/finance/staff/?month=${selected.month}`,
        tone: "mute",
      });
    }
  }
  if (global && global.overdue_invoices > 0) {
    out.push({ id: "overdue", text: `${plural(global.overdue_invoices, "invoice is", "invoices are")} overdue`, href: "/admin/finance/invoices/?status=overdue", tone: "bad" });
  }
  if (global && global.first_invoices_this_week > 0) {
    out.push({
      id: "first",
      text: `${plural(global.first_invoices_this_week, "first-month invoice", "first-month invoices")} created this week`,
      href: "/admin/finance/students/",
      tone: "first",
    });
  }
  return out;
}

/** The most recent month that has ended and is not closed, among the months we know about. */
export function findCloseBannerMonth(rows: MonthSummary[], current: string): MonthSummary | null {
  const open = rows.filter((r) => r.month < current && r.status !== "closed");
  if (open.length === 0) return null;
  return open.reduce((latest, r) => (r.month > latest.month ? r : latest));
}

/** The sentence after "September isn't closed yet." */
export function bannerText(row: MonthSummary): string {
  const bits: string[] = [];
  if (!row.teacher_pay_final) bits.push("teacher audits waiting for approval");
  const people = row.unpaid_teachers + row.unpaid_admins;
  if (people > 0) bits.push(`${plural(people, "person", "people")} still to pay`);
  if (row.recurring_pending > 0) bits.push(`${plural(row.recurring_pending, "cost", "costs")} to confirm`);
  return bits.length > 0 ? `${bits.join(" · ")}.` : "Everything is done. It can be closed.";
}

export type YearPoint = {
  month: string;
  short: string;
  billed: number;
  expenses: number;
  profit: number;
  estimate: boolean;
};

/** Series for the 12-month chart; months not loaded yet are left out. */
export function yearSeries(months: string[], rows: Map<string, MonthSummary>): YearPoint[] {
  const out: YearPoint[] = [];
  for (const month of months) {
    const row = rows.get(month);
    if (!row) continue;
    out.push({ month, short: monthShort(month).split(" ")[0], billed: row.billed, expenses: row.expenses, profit: row.profit, estimate: isEstimate(row) });
  }
  return out;
}

/** Height in pixels for a bar, with a floor so a small value is still visible. */
export function barHeight(value: number, max: number, full: number): number {
  if (max <= 0 || value <= 0) return 0;
  return Math.max(3, Math.round((value / max) * full));
}
