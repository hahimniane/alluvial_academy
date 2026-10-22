/**
 * Pure logic behind the finance Expenses page: reading stored rows, the
 * recurring-cost status, the month's expense table and the add form.
 * Rules come from docs/finance/SPEC.md (4, 5, 14). Nothing here touches
 * Firebase, so it runs under `node --test`.
 */

import { CATEGORY_LABEL, ENTERED_CATEGORIES, normalizeLegacyCategory, r2, type ExpenseCategory } from "./model.ts";
import { monthName, monthOf } from "./months.ts";

/* -------------------------------------------------------------- reading -- */

type Raw = Record<string, unknown>;

const record = (value: unknown): Raw => (value && typeof value === "object" ? (value as Raw) : {});
const text = (value: unknown): string => (typeof value === "string" ? value.trim() : "");
const num = (value: unknown): number => {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
};

/** A Firestore Timestamp, Date, ISO string or null, as a Date or null. */
export function toDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === "object" && "toDate" in (value as Raw) && typeof (value as Raw).toDate === "function") {
    const converted = ((value as unknown) as { toDate: () => Date }).toDate();
    return Number.isNaN(converted.getTime()) ? null : converted;
  }
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

const MONTH = /^\d{4}-(0[1-9]|1[0-2])$/;
export const isMonth = (value: unknown): value is string => typeof value === "string" && MONTH.test(value);

export type RecurringCost = {
  id: string;
  name: string;
  category: ExpenseCategory;
  amount: number;
  dayOfMonth: number;
  startMonth: string;
  endMonth: string | null;
};

export type Confirmation = {
  id: string;
  costId: string;
  month: string;
  amount: number;
  source: string;
  byName: string;
};

export type StoredExpense = {
  id: string;
  /** `yyyy-MM`, from `month` or (older rows) the expense date; null when neither exists. */
  month: string | null;
  /** Null for old pay rows that must not count (teacher and leadership pay). */
  category: ExpenseCategory | null;
  name: string;
  amount: number;
  date: Date | null;
  kind: "one_time" | "recurring";
  deleted: boolean;
  deletedAt: Date | null;
  deletedByName: string;
  deleteReason: string;
};

export function readRecurringCost(id: string, raw: unknown): RecurringCost | null {
  const data = record(raw);
  const startMonth = data.start_month;
  if (!isMonth(startMonth)) return null;
  const category = ENTERED_CATEGORIES.includes(data.category as ExpenseCategory) ? (data.category as ExpenseCategory) : "other";
  const day = Math.round(num(data.day_of_month));
  return {
    id,
    name: text(data.name) || "Recurring cost",
    category,
    amount: r2(num(data.amount)),
    dayOfMonth: day >= 1 && day <= 28 ? day : 1,
    startMonth,
    endMonth: isMonth(data.end_month) ? data.end_month : null,
  };
}

export function readConfirmation(id: string, raw: unknown): Confirmation | null {
  const data = record(raw);
  if (!isMonth(data.month) || !text(data.cost_id)) return null;
  return {
    id,
    costId: text(data.cost_id),
    month: data.month,
    amount: r2(num(data.amount)),
    source: text(data.source) || "manual",
    byName: text(data.confirmed_by_name),
  };
}

export function readExpense(id: string, raw: unknown): StoredExpense {
  const data = record(raw);
  const date = toDate(data.expense_date);
  const month = isMonth(data.month) ? data.month : date ? monthOf(date) : null;
  return {
    id,
    month,
    category: normalizeLegacyCategory(data.category),
    name: text(data.name) || text(data.vendor) || text(data.category_label) || "Expense",
    amount: r2(num(data.amount)),
    date,
    kind: data.kind === "recurring" ? "recurring" : "one_time",
    deleted: data.deleted === true,
    deletedAt: toDate(data.deleted_at),
    deletedByName: text(data.deleted_by_name) || text(data.deleted_by),
    deleteReason: text(data.delete_reason),
  };
}

/* ------------------------------------------------------------ recurring -- */

export function recurringInMonth(cost: RecurringCost, month: string): boolean {
  if (month < cost.startMonth) return false;
  if (cost.endMonth && month > cost.endMonth) return false;
  return true;
}

export type RecurringStatus = "confirmed" | "due" | "upcoming";

/**
 * Confirmed once the real amount is recorded. Otherwise due when the billed-on
 * day has come (or the month is over), upcoming before that.
 * `today` is `yyyy-MM-dd` on the books' clock.
 */
export function recurringStatus(cost: RecurringCost, month: string, confirmation: Confirmation | undefined, today: string): RecurringStatus {
  if (confirmation) return "confirmed";
  const current = today.slice(0, 7);
  if (month < current) return "due";
  if (month > current) return "upcoming";
  return cost.dayOfMonth <= Number(today.slice(8, 10)) ? "due" : "upcoming";
}

export type RecurringRow = {
  cost: RecurringCost;
  status: RecurringStatus;
  confirmation: Confirmation | undefined;
  /** What it counts for this month: the confirmed amount, else the usual amount. */
  counted: number;
  estimate: boolean;
};

export function recurringRows(costs: RecurringCost[], confirmations: Confirmation[], month: string, today: string): RecurringRow[] {
  const confirmed = new Map<string, Confirmation>();
  for (const c of confirmations) if (c.month === month) confirmed.set(c.costId, c);
  return costs
    .filter((cost) => recurringInMonth(cost, month))
    .map((cost) => {
      const confirmation = confirmed.get(cost.id);
      return {
        cost,
        status: recurringStatus(cost, month, confirmation, today),
        confirmation,
        counted: confirmation ? confirmation.amount : cost.amount,
        estimate: !confirmation,
      };
    })
    .sort((a, b) => a.cost.dayOfMonth - b.cost.dayOfMonth || a.cost.name.localeCompare(b.cost.name));
}

export function statusLabel(row: RecurringRow, money: (n: number) => string): string {
  if (row.status === "confirmed") return `Confirmed ${money(row.counted)}`;
  return row.status === "due" ? "Due — confirm amount" : "Upcoming";
}

/** "Oct 14" for a day of a `yyyy-MM` month. */
export function monthDayLabel(month: string, day: number): string {
  return `${monthName(month).slice(0, 3)} ${day}`;
}

/* ---------------------------------------------------------------- table -- */

/** What the finance month summary says about pay and fees (all optional). */
export type StaffSummary = {
  teacherPay: number;
  teacherPayFinal: boolean;
  teacherCount: number;
  adminPay: number;
  adminCount: number;
  /** All transfer fees for the month, including any one-off rows entered here. */
  transferFees: number;
  final: boolean;
};

export type TableRow = {
  key: string;
  category: string;
  name: string;
  note: string;
  date: string;
  amount: number;
  /** Set on one-time rows an admin can delete. */
  expenseId?: string;
};

const dayFormat = new Intl.DateTimeFormat("en-US", { timeZone: "America/New_York", month: "short", day: "numeric" });
export const shortDay = (date: Date | null): string => (date ? dayFormat.format(date) : "—");

const plural = (n: number, one: string, many: string): string => `${n} ${n === 1 ? one : many}`;

export function buildExpenseTable(input: {
  month: string;
  today: string;
  staff: StaffSummary | null;
  costs: RecurringCost[];
  confirmations: Confirmation[];
  expenses: StoredExpense[];
}): { rows: TableRow[]; total: number; hasEstimate: boolean } {
  const { month, today, staff, costs, confirmations, expenses } = input;
  const rows: TableRow[] = [];
  let hasEstimate = false;

  if (staff) {
    rows.push({
      key: "teacher_pay",
      category: CATEGORY_LABEL.teacher_pay,
      name: plural(staff.teacherCount, "teacher", "teachers"),
      note: staff.teacherPayFinal ? "(final)" : "(estimate)",
      date: "—",
      amount: r2(staff.teacherPay),
    });
    rows.push({
      key: "admin_pay",
      category: CATEGORY_LABEL.admin_pay,
      name: plural(staff.adminCount, "administrator", "administrators"),
      note: staff.final ? "" : "(estimate)",
      date: "—",
      amount: r2(staff.adminPay),
    });
    if (!staff.teacherPayFinal || !staff.final) hasEstimate = true;
  }

  for (const row of recurringRows(costs, confirmations, month, today)) {
    if (row.estimate) hasEstimate = true;
    rows.push({
      key: `recurring_${row.cost.id}`,
      category: CATEGORY_LABEL[row.cost.category],
      name: row.cost.name,
      note: `${row.estimate ? "(not confirmed — using usual amount) " : ""}· every month`,
      date: monthDayLabel(month, row.cost.dayOfMonth),
      amount: row.counted,
    });
  }

  const live = expenses
    .filter((e) => !e.deleted && e.month === month && e.category !== null)
    .sort((a, b) => (a.date?.getTime() ?? 0) - (b.date?.getTime() ?? 0));

  if (staff) {
    const enteredFees = live.filter((e) => e.category === "transfer_fees").reduce((sum, e) => sum + e.amount, 0);
    const payoutFees = r2(Math.max(0, staff.transferFees - enteredFees));
    if (payoutFees > 0) {
      rows.push({ key: "payout_fees", category: CATEGORY_LABEL.transfer_fees, name: "Staff payouts", note: "", date: "—", amount: payoutFees });
    }
  }

  for (const e of live) {
    rows.push({
      key: `expense_${e.id}`,
      category: CATEGORY_LABEL[e.category as ExpenseCategory],
      name: e.name,
      note: "· one time",
      date: shortDay(e.date),
      amount: e.amount,
      expenseId: e.id,
    });
  }

  return { rows, total: r2(rows.reduce((sum, row) => sum + row.amount, 0)), hasEstimate };
}

/** Soft-deleted expenses of a month, newest deletion first. */
export function deletedExpenses(expenses: StoredExpense[], month: string): StoredExpense[] {
  return expenses
    .filter((e) => e.deleted && e.month === month)
    .sort((a, b) => (b.deletedAt?.getTime() ?? 0) - (a.deletedAt?.getTime() ?? 0));
}

/* ----------------------------------------------------------- add form -- */

export type AddFreq = "once" | "monthly";

export type AddForm = {
  freq: AddFreq;
  category: ExpenseCategory;
  name: string;
  amount: string;
  /** `yyyy-MM-dd`, used when freq is once. */
  date: string;
  /** 1 to 28, used when freq is monthly. */
  day: string;
};

/** Date a new one-time expense starts with: today inside the month, else its first day. */
export function defaultExpenseDate(month: string, today: string): string {
  return today.slice(0, 7) === month ? today : `${month}-01`;
}

export function emptyAddForm(month: string, today: string): AddForm {
  const day = today.slice(0, 7) === month ? String(Math.min(28, Number(today.slice(8, 10)))) : "1";
  return { freq: "once", category: "marketing", name: "", amount: "", date: defaultExpenseDate(month, today), day };
}

/** An amount typed by a person, in dollars rounded to cents; null when unusable. */
export function parseMoneyInput(raw: string, allowZero = false): number | null {
  const cleaned = raw.replace(/[$,\s]/g, "");
  if (!cleaned) return null;
  const n = Number(cleaned);
  if (!Number.isFinite(n) || n < 0 || n > 1_000_000) return null;
  const cents = r2(n);
  return cents === 0 && !allowZero ? null : cents;
}

export type AddPayload = {
  month: string;
  kind: "one_time" | "recurring";
  category: ExpenseCategory;
  name: string;
  amount: number;
  date?: string;
  day_of_month?: number;
};

/** The first problem with the form, or the callable payload. */
export function validateAddForm(form: AddForm, month: string): { error: string } | { payload: AddPayload } {
  const name = form.name.replace(/\s+/g, " ").trim();
  const amount = parseMoneyInput(form.amount);
  if (!name || amount === null) return { error: "Add what it was for and an amount." };
  if (form.freq === "monthly") {
    const day = Number(form.day);
    if (!Number.isInteger(day) || day < 1 || day > 28) return { error: "Billed on day is a number from 1 to 28." };
    return { payload: { month, kind: "recurring", category: form.category, name, amount, day_of_month: day } };
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(form.date) || form.date.slice(0, 7) !== month) {
    return { error: `Pick a date in ${monthName(month)}.` };
  }
  return { payload: { month, kind: "one_time", category: form.category, name, amount, date: form.date } };
}

export const addButtonLabel = (freq: AddFreq): string => (freq === "monthly" ? "Add monthly cost" : "Add expense");

export function addHint(freq: AddFreq, month: string): string {
  return freq === "monthly"
    ? `Counts as paid for ${monthName(month)} now, then shows up every month to confirm with the real bill.`
    : `Counts once, in ${monthName(month)}.`;
}

/* --------------------------------------------------------------- export -- */

export function exportRows(rows: TableRow[], total: number): (string | number)[][] {
  return [...rows.map((r) => [r.category, `${r.name} ${r.note}`.trim(), r.date, r.amount]), ["Total expenses", "", "", total]];
}
