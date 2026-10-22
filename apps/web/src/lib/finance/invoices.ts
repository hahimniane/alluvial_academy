/**
 * Pure logic for the finance Invoices and New students screens: reading an
 * invoice document, its computed status, the list filters / sorts / totals,
 * the Edit invoice draft, the duplicate check for monthly tuition, and the
 * first-invoice maths.
 *
 * No Firestore here, so every rule is covered by node --test
 * (src/lib/__tests__/finance_invoices.test.ts). The server mirror of the date
 * and overdue rules is functions/utils/finance_invoice_math.js; keep the two
 * in step. Spec: docs/finance/SPEC.md (rules 7-13).
 */

import { r2 } from "./model.ts";

/* ------------------------------------------------------------------ dates -- */

const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const DAY_MS = 24 * 60 * 60 * 1000;
const BOOKS_TIME_ZONE = "America/New_York";

export type Dateish = Date | { toDate: () => Date } | { seconds: number } | string | number | null | undefined;

export function toDate(value: Dateish): Date | null {
  if (value === null || value === undefined || value === "") return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === "object" && "toDate" in value && typeof value.toDate === "function") return toDate(value.toDate());
  if (typeof value === "object" && "seconds" in value) return new Date(Number(value.seconds) * 1000);
  const d = new Date(value as string | number);
  return Number.isNaN(d.getTime()) ? null : d;
}

function partsIn(date: Date, timeZone: string): { y: string; m: string; d: string } {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(date);
  const pick = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  return { y: pick("year"), m: pick("month"), d: pick("day") };
}

/** yyyy-MM-dd of an instant in New York time ("today" when given now). */
export function dayKeyNY(date: Date): string {
  const { y, m, d } = partsIn(date, BOOKS_TIME_ZONE);
  return `${y}-${m}-${d}`;
}

export function monthOfDate(date: Date): string {
  return dayKeyNY(date).slice(0, 7);
}

/**
 * The calendar day an invoice is due. A stored value at exactly 00:00:00 UTC
 * (what the generators write) means that UTC date; anything else (the old form
 * wrote local noon) is read in New York time. Neither slips a day.
 */
export function dueDayKey(value: Dateish): string | null {
  const date = toDate(value);
  if (!date) return null;
  if (date.getUTCHours() === 0 && date.getUTCMinutes() === 0 && date.getUTCSeconds() === 0) {
    return date.toISOString().slice(0, 10);
  }
  return dayKeyNY(date);
}

export function isDayKey(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
}

function dayNumber(key: string): number {
  const [y, m, d] = key.split("-").map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / DAY_MS);
}

/** Whole days from `fromKey` to `toKey`; positive when `toKey` is later. */
export function daysBetween(fromKey: string, toKey: string): number {
  return dayNumber(toKey) - dayNumber(fromKey);
}

export function addDays(key: string, days: number): string {
  return new Date((dayNumber(key) + days) * DAY_MS).toISOString().slice(0, 10);
}

/** "Oct 25" */
export function formatDay(key: string | null): string {
  if (!key || !isDayKey(key)) return "";
  const [, m, d] = key.split("-").map(Number);
  return `${MONTH_NAMES[m - 1]} ${d}`;
}

/** "Oct 25, 2026" */
export function formatDayYear(key: string | null): string {
  if (!key || !isDayKey(key)) return "";
  return `${formatDay(key)}, ${key.slice(0, 4)}`;
}

/** "Oct 25" for a moment, in New York time. */
export function formatMoment(date: Date | null): string {
  return date ? formatDay(dayKeyNY(date)) : "";
}

/* ---------------------------------------------------------------- invoice -- */

export type InvoiceKind = "first_month" | "monthly" | "one_off" | "";

export type InvoiceLine = {
  description: string;
  amount: number;
  studentId: string;
};

export type HistoryEntry = {
  at: Date | null;
  byName: string;
  reason: string;
  action: "edit" | "cancelled";
  beforeTotal: number | null;
  afterTotal: number | null;
  beforeDue: string | null;
  afterDue: string | null;
  creditAmount: number;
};

export type ReminderEntry = { at: Date | null; kind: string; byName: string };

export type Invoice = {
  id: string;
  number: string;
  parentId: string;
  studentIds: string[];
  kind: InvoiceKind;
  billingMonth: string | null;
  issuedAt: Date | null;
  dueKey: string | null;
  accessCutoff: Date | null;
  accessExtendedAt: Date | null;
  /** Stored status, lower case. Overdue is computed, never read from here. */
  status: string;
  total: number;
  paid: number;
  currency: string;
  /** Billable lines (discount lines excluded). */
  lines: InvoiceLine[];
  /** Discount lines as positive amounts. */
  discountLines: InvoiceLine[];
  discount: number;
  subtotal: number;
  payLinkStatus: string;
  cancelledAt: Date | null;
  cancelReason: string;
  editHistory: HistoryEntry[];
  reminders: ReminderEntry[];
  firstClassKey: string | null;
  classesInMonth: number | null;
  classesLeft: number | null;
};

type Rec = Record<string, unknown>;
const rec = (v: unknown): Rec => (v && typeof v === "object" && !Array.isArray(v) ? (v as Rec) : {});
const str = (v: unknown): string => (v === null || v === undefined ? "" : String(v).trim());
const num = (v: unknown): number => {
  if (v === null || v === undefined || v === "") return 0;
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};
const numOrNull = (v: unknown): number | null => {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

const MONTH_RE = /^(\d{4})-(\d{2})/;

/** billing_month, else the period's first month, else the month it was issued. */
export function billingMonthOf(data: Rec): string | null {
  const direct = str(data.billing_month);
  if (MONTH_RE.test(direct)) return direct.slice(0, 7);
  const period = str(data.period) || str(data.period_start);
  const match = period.match(MONTH_RE);
  if (match) return `${match[1]}-${match[2]}`;
  const issued = toDate((data.issued_date ?? data.created_at) as Dateish);
  return issued ? monthOfDate(issued) : null;
}

function readLines(items: unknown): { lines: InvoiceLine[]; discountLines: InvoiceLine[] } {
  const lines: InvoiceLine[] = [];
  const discountLines: InvoiceLine[] = [];
  for (const raw of Array.isArray(items) ? items : []) {
    const item = rec(raw);
    const quantity = numOrNull(item.quantity) ?? 1;
    const total = numOrNull(item.total) ?? r2(quantity * num(item.unit_price ?? item.unitPrice));
    const line: InvoiceLine = { description: str(item.description), amount: r2(total), studentId: str(item.student_id ?? item.studentId) };
    if (item.is_discount === true || total < 0) discountLines.push({ ...line, amount: r2(Math.abs(total)) });
    else lines.push(line);
  }
  return { lines, discountLines };
}

function readHistory(raw: unknown): HistoryEntry[] {
  const out: HistoryEntry[] = [];
  for (const entry of Array.isArray(raw) ? raw : []) {
    const e = rec(entry);
    const before = rec(e.before);
    const after = rec(e.after);
    const action = str(e.action) === "cancelled" ? "cancelled" : "edit";
    out.push({
      at: toDate(e.at as Dateish),
      byName: str(e.by_name) || "an administrator",
      reason: str(e.reason),
      action,
      beforeTotal: numOrNull(before.total_amount ?? before.total),
      afterTotal: numOrNull(after.total_amount ?? after.total),
      beforeDue: dueDayKey(before.due_date as Dateish),
      afterDue: dueDayKey(after.due_date as Dateish),
      creditAmount: num(e.credit_amount),
    });
  }
  return out;
}

export function normalizeInvoice(id: string, data: Rec): Invoice {
  const { lines, discountLines } = readLines(data.items);
  const discount = r2(discountLines.reduce((s, l) => s + l.amount, 0));
  const subtotal = r2(lines.reduce((s, l) => s + l.amount, 0));
  const studentIds = Array.isArray(data.student_ids) ? (data.student_ids as unknown[]).map(str).filter(Boolean) : [];
  const single = str(data.student_id ?? data.studentId);
  if (!studentIds.length && single) studentIds.push(single);
  const kindRaw = str(data.kind);
  const kind: InvoiceKind = kindRaw === "first_month" || kindRaw === "monthly" || kindRaw === "one_off" ? kindRaw : "";
  const firstMonth = rec(data.first_month);
  const classesLeft = numOrNull(data.classes_left ?? firstMonth.classes_left);
  const classesInMonth = numOrNull(data.classes_in_month ?? firstMonth.classes_in_month);
  const firstClass = str(data.first_class_date ?? firstMonth.first_class_date);
  return {
    id,
    number: str(data.invoice_number ?? data.invoiceNumber) || id,
    parentId: str(data.parent_id ?? data.parentId),
    studentIds,
    kind,
    billingMonth: billingMonthOf(data),
    issuedAt: toDate((data.issued_date ?? data.created_at) as Dateish),
    dueKey: dueDayKey((data.due_date ?? data.dueDate) as Dateish),
    accessCutoff: toDate((data.access_cutoff_date ?? data.accessCutoffDate) as Dateish),
    accessExtendedAt: toDate(data.access_extended_at as Dateish),
    status: str(data.status).toLowerCase(),
    total: r2(num(data.total_amount ?? data.totalAmount)),
    paid: r2(num(data.paid_amount ?? data.paidAmount)),
    currency: str(data.currency) || "USD",
    lines,
    discountLines,
    discount,
    subtotal,
    payLinkStatus: str(data.pay_link_status).toLowerCase(),
    cancelledAt: toDate(data.cancelled_at as Dateish),
    cancelReason: str(data.cancel_reason ?? data.cancellation_reason),
    editHistory: readHistory(data.edit_history),
    reminders: (Array.isArray(data.reminders) ? data.reminders : []).map((r) => {
      const e = rec(r);
      return { at: toDate(e.at as Dateish), kind: str(e.kind), byName: str(e.by_name) };
    }),
    firstClassKey: isDayKey(firstClass) ? firstClass : null,
    classesInMonth,
    classesLeft,
  };
}

/* ----------------------------------------------------------------- status -- */

export type StatusKind = "paid" | "partly" | "overdue" | "unpaid" | "cancelled";

export type InvoiceState = {
  kind: StatusKind;
  label: string;
  paid: number;
  owed: number;
  /** Owed money and the due day has passed. */
  late: boolean;
  days: number;
};

export function invoiceState(inv: Invoice, now: Date = new Date()): InvoiceState {
  if (inv.status === "cancelled") return { kind: "cancelled", label: "Cancelled", paid: inv.paid, owed: 0, late: false, days: 0 };
  const owed = Math.max(0, r2(inv.total - inv.paid));
  const today = dayKeyNY(now);
  const late = owed > 0.004 && !!inv.dueKey && today > inv.dueKey;
  const days = late && inv.dueKey ? daysBetween(inv.dueKey, today) : 0;
  if (owed <= 0.004) return { kind: "paid", label: "Paid", paid: inv.paid, owed: 0, late: false, days: 0 };
  if (inv.paid > 0) {
    return { kind: "partly", label: late ? `Partly paid · ${days}d overdue` : "Partly paid", paid: inv.paid, owed, late, days };
  }
  if (late) return { kind: "overdue", label: `Overdue · ${days}d`, paid: inv.paid, owed, late, days };
  return { kind: "unpaid", label: `Unpaid · due ${formatDay(inv.dueKey)}`.trim(), paid: inv.paid, owed, late: false, days: 0 };
}

export type BadgeTone = "ok" | "warn" | "bad" | "info" | "mute" | "purple";

export function toneFor(state: InvoiceState): BadgeTone {
  switch (state.kind) {
    case "paid":
      return "ok";
    case "cancelled":
      return "mute";
    case "overdue":
      return "bad";
    case "partly":
      return state.late ? "bad" : "warn";
    default:
      return "warn";
  }
}

/* ------------------------------------------------------- list rows/filters -- */

export type InvoiceRow = {
  inv: Invoice;
  state: InvoiceState;
  familyName: string;
  studentNames: string[];
  teacherIds: string[];
  familyHasCredit: boolean;
};

export function buildRow(
  inv: Invoice,
  ctx: { now: Date; names: ReadonlyMap<string, string>; teachersByStudent: ReadonlyMap<string, readonly string[]>; creditParents: ReadonlySet<string> },
): InvoiceRow {
  const teacherIds = new Set<string>();
  for (const s of inv.studentIds) for (const t of ctx.teachersByStudent.get(s) ?? []) teacherIds.add(t);
  return {
    inv,
    state: invoiceState(inv, ctx.now),
    familyName: ctx.names.get(inv.parentId) || "Unknown family",
    studentNames: inv.studentIds.map((s) => ctx.names.get(s) || "").filter(Boolean),
    teacherIds: [...teacherIds],
    familyHasCredit: ctx.creditParents.has(inv.parentId),
  };
}

export type StatusChip = "all" | "unpaid" | "overdue" | "partly" | "paid" | "cancelled";
export type OverdueBucket = "any" | "1-15" | "16-30" | "30+";
export type SortKey = "due" | "amount" | "overdue" | "family" | "newest";

export type InvoiceFilters = {
  status: StatusChip;
  /** "all" or yyyy-MM (the billing month). */
  month: string;
  q: string;
  /** "all" or a teacher id. */
  teacher: string;
  overdue: OverdueBucket;
  min: string;
  max: string;
  hasDiscount: boolean;
  familyCredit: boolean;
  firstOnly: boolean;
  sort: SortKey;
};

export const DEFAULT_FILTERS: InvoiceFilters = {
  status: "all",
  month: "all",
  q: "",
  teacher: "all",
  overdue: "any",
  min: "",
  max: "",
  hasDiscount: false,
  familyCredit: false,
  firstOnly: false,
  sort: "due",
};

export const STATUS_CHIPS: ReadonlyArray<{ id: StatusChip; label: string }> = [
  { id: "all", label: "All" },
  { id: "unpaid", label: "Unpaid" },
  { id: "overdue", label: "Overdue" },
  { id: "partly", label: "Partly paid" },
  { id: "paid", label: "Paid" },
  { id: "cancelled", label: "Cancelled" },
];

/** Unpaid = anything still owed (so it includes overdue and partly paid). */
export function matchesChip(row: InvoiceRow, chip: StatusChip): boolean {
  switch (chip) {
    case "all":
      return true;
    case "unpaid":
      return row.state.owed > 0.004 && row.state.kind !== "cancelled";
    case "overdue":
      return row.state.late;
    case "partly":
      return row.state.kind === "partly";
    case "paid":
      return row.state.kind === "paid";
    case "cancelled":
      return row.state.kind === "cancelled";
  }
}

export function inOverdueBucket(row: InvoiceRow, bucket: OverdueBucket): boolean {
  if (bucket === "any") return true;
  if (!row.state.late) return false;
  const d = row.state.days;
  if (bucket === "1-15") return d >= 1 && d <= 15;
  if (bucket === "16-30") return d >= 16 && d <= 30;
  return d > 30;
}

function parseAmount(v: string): number | null {
  const t = v.trim();
  if (!t) return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

/** Every filter except the status chip (the chip counts are taken on this set). */
export function applyBaseFilters(rows: readonly InvoiceRow[], f: InvoiceFilters): InvoiceRow[] {
  const q = f.q.trim().toLowerCase();
  const min = parseAmount(f.min);
  const max = parseAmount(f.max);
  return rows.filter((r) => {
    const inv = r.inv;
    if (f.month !== "all" && inv.billingMonth !== f.month) return false;
    if (q) {
      const hay = `${inv.number} ${r.familyName} ${r.studentNames.join(" ")}`.toLowerCase();
      if (!hay.includes(q)) return false;
    }
    if (f.teacher !== "all" && !r.teacherIds.includes(f.teacher)) return false;
    if (!inOverdueBucket(r, f.overdue)) return false;
    if (min !== null && inv.total < min) return false;
    if (max !== null && inv.total > max) return false;
    if (f.hasDiscount && !(inv.discount > 0)) return false;
    if (f.familyCredit && !r.familyHasCredit) return false;
    if (f.firstOnly && inv.kind !== "first_month") return false;
    return true;
  });
}

export function chipCounts(base: readonly InvoiceRow[]): Record<StatusChip, number> {
  const out = { all: 0, unpaid: 0, overdue: 0, partly: 0, paid: 0, cancelled: 0 } as Record<StatusChip, number>;
  for (const chip of STATUS_CHIPS) out[chip.id] = base.filter((r) => matchesChip(r, chip.id)).length;
  return out;
}

const time = (d: Date | null) => (d ? d.getTime() : 0);

export function sortRows(rows: readonly InvoiceRow[], sort: SortKey): InvoiceRow[] {
  const copy = rows.slice();
  const byDue = (a: InvoiceRow, b: InvoiceRow) => (a.inv.dueKey ?? "9999-12-31").localeCompare(b.inv.dueKey ?? "9999-12-31");
  switch (sort) {
    case "due":
      return copy.sort(byDue);
    case "amount":
      return copy.sort((a, b) => b.inv.total - a.inv.total || byDue(a, b));
    case "overdue":
      return copy.sort((a, b) => b.state.days - a.state.days || byDue(a, b));
    case "family":
      return copy.sort((a, b) => a.familyName.localeCompare(b.familyName) || byDue(a, b));
    case "newest":
      return copy.sort((a, b) => time(b.inv.issuedAt) - time(a.inv.issuedAt));
  }
}

export type InvoiceTotals = { count: number; billed: number; collected: number; owed: number };

/** Cancelled invoices are listed but add no money (spec rule 1). */
export function totalsOf(rows: readonly InvoiceRow[]): InvoiceTotals {
  let billed = 0;
  let collected = 0;
  let owed = 0;
  for (const r of rows) {
    if (r.state.kind === "cancelled") continue;
    billed += r.inv.total;
    collected += r.inv.paid;
    owed += r.state.owed;
  }
  return { count: rows.length, billed: r2(billed), collected: r2(collected), owed: r2(owed) };
}

export function filterAndSort(rows: readonly InvoiceRow[], f: InvoiceFilters) {
  const base = applyBaseFilters(rows, f);
  const counts = chipCounts(base);
  const shown = sortRows(
    base.filter((r) => matchesChip(r, f.status)),
    f.sort,
  );
  return { base, counts, rows: shown, totals: totalsOf(shown) };
}

/** Distinct teachers across the loaded rows, for the Teacher filter. */
export function teacherOptions(rows: readonly InvoiceRow[], teacherNames: ReadonlyMap<string, string>): { id: string; name: string }[] {
  const ids = new Set<string>();
  for (const r of rows) for (const t of r.teacherIds) ids.add(t);
  return [...ids].map((id) => ({ id, name: teacherNames.get(id) || "Unknown teacher" })).sort((a, b) => a.name.localeCompare(b.name));
}

/* ------------------------------------------------- monthly duplicate guard -- */

/**
 * The existing non-cancelled monthly / first-month invoice (or one from the
 * scheduled generator, which predates `kind`) that already bills this family
 * for `month`. Mirrors the server guard in createInvoice.
 */
export function findMonthlyClash(invoices: readonly Invoice[], parentId: string, month: string): Invoice | null {
  for (const inv of invoices) {
    if (inv.parentId !== parentId || inv.status === "cancelled") continue;
    const monthly = inv.kind === "monthly" || inv.kind === "first_month" || (inv.kind === "" && inv.id.startsWith("recurring_"));
    if (!monthly) continue;
    if (inv.billingMonth === month) return inv;
  }
  return null;
}

/* ------------------------------------------------------------ edit invoice -- */

export type EditLineDraft = { description: string; amount: string; studentId: string };

export type EditDraft = {
  lines: EditLineDraft[];
  discount: string;
  /** yyyy-MM-dd */
  due: string;
  reason: string;
};

export function draftFromInvoice(inv: Invoice): EditDraft {
  return {
    lines: inv.lines.map((l) => ({ description: l.description, amount: String(l.amount), studentId: l.studentId })),
    discount: String(inv.discount || 0),
    due: inv.dueKey ?? "",
    reason: "",
  };
}

export type EditPayloadLine = { description: string; amount: number; student_id?: string };

export type EditEvaluation = {
  /** Lines parsed from the draft; null when any line is incomplete. */
  lines: EditPayloadLine[] | null;
  discount: number;
  newTotal: number;
  /** Money paid above the new total (becomes a family credit). */
  creditBack: number;
  leftToPay: number;
  changed: boolean;
  /** Why Save is disabled, in plain words; empty when it is enabled. */
  hint: string;
  canSave: boolean;
  /** Cancel is offered only when nothing is paid. */
  canCancel: boolean;
};

function parseLineAmount(v: string): number | null {
  const t = v.trim();
  if (!t) return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

export function evaluateDraft(inv: Invoice, draft: EditDraft): EditEvaluation {
  const parsed: EditPayloadLine[] = [];
  let bad = false;
  let negative = false;
  for (const l of draft.lines) {
    const amount = parseLineAmount(l.amount);
    if (!l.description.trim() || amount === null) {
      bad = true;
      continue;
    }
    if (amount < 0) negative = true;
    parsed.push({ description: l.description.trim(), amount: r2(amount), ...(l.studentId ? { student_id: l.studentId } : {}) });
  }
  const subtotal = r2(parsed.reduce((s, l) => s + l.amount, 0));
  const discountText = draft.discount.trim();
  const discountNum = discountText === "" ? 0 : Number(discountText);
  const discountBad = !Number.isFinite(discountNum) || discountNum < 0;
  const discount = discountBad ? 0 : r2(discountNum);
  const newTotal = r2(subtotal - discount);
  const creditBack = inv.paid > newTotal + 0.004 ? r2(inv.paid - newTotal) : 0;
  const leftToPay = Math.max(0, r2(newTotal - inv.paid));
  const noLines = draft.lines.length === 0;
  const reasonMissing = !draft.reason.trim();
  const dueBad = !isDayKey(draft.due);
  const overDiscount = newTotal < 0;

  const sameLines =
    !bad &&
    parsed.length === inv.lines.length &&
    parsed.every((l, i) => l.description === inv.lines[i].description && l.amount === inv.lines[i].amount);
  const changed = !(sameLines && discount === inv.discount && draft.due === (inv.dueKey ?? ""));

  let hint = "";
  if (noLines) hint = "An invoice needs at least one line.";
  else if (bad) hint = "Every line needs a description and an amount.";
  else if (negative) hint = "A line cannot be negative. Use the discount box to take money off.";
  else if (discountBad) hint = "The discount must be zero or more.";
  else if (overDiscount) hint = "The discount is more than the lines add up to.";
  else if (dueBad) hint = "Pick a due date.";
  else if (reasonMissing) hint = "Add a reason for the change.";
  else if (!changed) hint = "Nothing has changed yet.";

  return {
    lines: bad ? null : parsed,
    discount,
    newTotal,
    creditBack,
    leftToPay,
    changed,
    hint,
    canSave: hint === "",
    canCancel: inv.paid <= 0.004,
  };
}

/** The `editInvoice` request body for a draft that can be saved. */
export function editPayload(inv: Invoice, draft: EditDraft): { invoice_id: string; lines: EditPayloadLine[]; discount: number; due_date: string; reason: string } {
  const ev = evaluateDraft(inv, draft);
  return { invoice_id: inv.id, lines: ev.lines ?? [], discount: ev.discount, due_date: draft.due, reason: draft.reason.trim() };
}

export function previewLine(inv: Invoice, ev: EditEvaluation, money: (n: number) => string): string {
  const left = ev.creditBack > 0 ? "nothing left to pay" : `left to pay ${money(ev.leftToPay)}`;
  return `Total ${money(inv.total)} → ${money(ev.newTotal)} · already paid ${money(inv.paid)} · ${left}`;
}

export function creditNote(family: string, ev: EditEvaluation, money: (n: number) => string): string {
  return `${money(ev.creditBack)} was paid above the new total. It becomes credit for the ${family} family and comes off their next invoice.`;
}

export function notifyLine(parent: string, number: string, newTotal: number, messagesOn: boolean, money: (n: number) => string): string {
  if (!messagesOn) return "Parent messages are off, so nobody is notified. The change is saved in the history.";
  return `When you save, ${parent} gets a message: “Your invoice ${number} was updated. New total ${money(newTotal)}.”`;
}

/* ------------------------------------------------------------ history text -- */

export function historyText(h: HistoryEntry, money: (n: number) => string): string {
  const when = formatMoment(h.at);
  const who = `by ${h.byName}`;
  if (h.action === "cancelled") return `${when} — cancelled ${who}${h.reason ? ` · “${h.reason}”` : ""}`;
  const parts: string[] = [];
  if (h.beforeTotal !== null && h.afterTotal !== null) parts.push(`total ${money(h.beforeTotal)} → ${money(h.afterTotal)}`);
  if (h.beforeDue && h.afterDue && h.beforeDue !== h.afterDue) parts.push(`due ${formatDay(h.beforeDue)} → ${formatDay(h.afterDue)}`);
  if (h.creditAmount > 0) parts.push(`${money(h.creditAmount)} became family credit`);
  const detail = parts.length ? `: ${parts.join(", ")}` : "";
  return `${when} — edited ${who}${detail}${h.reason ? ` · “${h.reason}”` : ""}`;
}

/* ---------------------------------------------------------- reminders/access -- */

export type TimelineEntry = { at: number; text: string };

export type PaymentLite = { amount: number; at: Date | null; method: string };

/**
 * Issued, payments, reminders and access, oldest first. Reminders are shown
 * only when they were recorded on the invoice.
 */
export function buildTimeline(
  inv: Invoice,
  payments: readonly PaymentLite[],
  parentName: string,
  money: (n: number) => string,
  now: Date = new Date(),
): { entries: string[]; access: { text: string; tone: "bad" | "info" } | null } {
  const entries: TimelineEntry[] = [];
  if (inv.issuedAt) entries.push({ at: inv.issuedAt.getTime(), text: `${formatMoment(inv.issuedAt)} — invoice sent to ${parentName}` });
  for (const p of payments) {
    const method = p.method ? ` by ${p.method}` : "";
    entries.push({ at: time(p.at), text: `${formatMoment(p.at)} — ${money(p.amount)} received${method}` });
  }
  for (const r of inv.reminders) {
    const label = r.kind === "manual" ? "reminder sent" : r.kind === "before_due" ? "reminder sent (3 days before due)" : r.kind === "due_date" ? "reminder sent (due date)" : "reminder sent";
    entries.push({ at: time(r.at), text: `${formatMoment(r.at)} — ${label}` });
  }
  entries.sort((a, b) => a.at - b.at);

  let access: { text: string; tone: "bad" | "info" } | null = null;
  const state = invoiceState(inv, now);
  if (state.late) {
    const cutoff = inv.accessCutoff;
    if (inv.accessExtendedAt && cutoff && cutoff.getTime() > now.getTime()) {
      access = { text: `Class access extended to ${formatDay(dueDayKey(cutoff))}`, tone: "info" };
    } else if (cutoff) {
      access = { text: `Class access suspended since ${formatDay(dueDayKey(cutoff))}`, tone: "bad" };
    } else if (inv.dueKey) {
      access = { text: `Class access suspended since ${formatDay(addDays(inv.dueKey, 1))}`, tone: "bad" };
    }
  }
  return { entries: entries.map((e) => e.text), access };
}

/** The date "Extend access" moves the cutoff to: the end of the current month. */
export function extendAccessTarget(now: Date = new Date()): { key: string; label: string } {
  const today = dayKeyNY(now);
  const [y, m] = today.split("-").map(Number);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const key = `${today.slice(0, 7)}-${String(last).padStart(2, "0")}`;
  return { key, label: formatDay(key) };
}

/* ------------------------------------------------------------ first invoice -- */

export type FirstInvoiceInput = { monthly: string; perMonth: string; left: string; start: string };

export type FirstInvoicePreview = {
  ok: boolean;
  monthly: number;
  perMonth: number;
  left: number;
  amount: number;
  dueKey: string;
  text: string;
};

export function firstInvoicePreview(
  input: FirstInvoiceInput,
  ctx: { studentName: string; dueDays: number; issueDay: number; dueDay: number },
  money: (n: number) => string,
): FirstInvoicePreview {
  const monthly = Number(input.monthly);
  const perMonth = Number(input.perMonth);
  const left = Number(input.left);
  const okNumbers =
    input.monthly.trim() !== "" &&
    Number.isFinite(monthly) &&
    monthly > 0 &&
    Number.isInteger(perMonth) &&
    perMonth > 0 &&
    Number.isInteger(left) &&
    left >= 1 &&
    left <= perMonth;
  const ok = okNumbers && isDayKey(input.start) && !!ctx.studentName;
  const amount = okNumbers ? r2((monthly * left) / perMonth) : 0;
  const dueKey = isDayKey(input.start) ? addDays(input.start, ctx.dueDays) : "";
  const text = ok
    ? `${ctx.studentName} starts ${formatDay(input.start)}: ${left} of ${perMonth} classes left this month, so the first invoice is ${money(monthly)} × ${left} ÷ ${perMonth} = ${money(amount)}, due ${formatDay(dueKey)}. After that ${money(monthly)} every month: the next invoice is issued on the ${ordinal(ctx.issueDay)} and due on the ${ordinal(ctx.dueDay)}.`
    : "Pick the parent and the student, then fill in the monthly amount and the classes.";
  return { ok, monthly, perMonth, left, amount, dueKey, text };
}

export function ordinal(n: number): string {
  const v = n % 100;
  if (v >= 11 && v <= 13) return `${n}th`;
  switch (n % 10) {
    case 1:
      return `${n}st`;
    case 2:
      return `${n}nd`;
    case 3:
      return `${n}rd`;
    default:
      return `${n}th`;
  }
}

/* ------------------------------------------------------------- new students -- */

export type EnrollmentLite = {
  id: string;
  studentId: string;
  parentId: string;
  studentName: string;
  teacherName: string;
  matchedAt: Date | null;
};

export type NewStudentRow = {
  key: string;
  studentIds: string[];
  parentId: string;
  /** yyyy-MM-dd of the first class (or the day the first invoice went out). */
  startKey: string | null;
  teacherName: string;
  invoice: Invoice | null;
  sortAt: number;
};

/**
 * First-month invoices (newest first) plus matched enrollments with a student
 * account that have no first invoice yet.
 */
export function mergeNewStudents(firstInvoices: readonly Invoice[], enrollments: readonly EnrollmentLite[], teachersByStudent: ReadonlyMap<string, string> = new Map()): NewStudentRow[] {
  const rows: NewStudentRow[] = [];
  const covered = new Set<string>();
  for (const inv of firstInvoices) {
    if (inv.status === "cancelled" || inv.kind !== "first_month") continue;
    inv.studentIds.forEach((s) => covered.add(s));
    rows.push({
      key: inv.id,
      studentIds: inv.studentIds,
      parentId: inv.parentId,
      startKey: inv.firstClassKey ?? (inv.issuedAt ? dayKeyNY(inv.issuedAt) : null),
      teacherName: inv.studentIds.map((s) => teachersByStudent.get(s) || "").find(Boolean) || "",
      invoice: inv,
      sortAt: time(inv.issuedAt),
    });
  }
  for (const e of enrollments) {
    if (!e.studentId || covered.has(e.studentId)) continue;
    covered.add(e.studentId);
    rows.push({
      key: `enrollment_${e.id}`,
      studentIds: [e.studentId],
      parentId: e.parentId,
      startKey: e.matchedAt ? dayKeyNY(e.matchedAt) : null,
      teacherName: e.teacherName,
      invoice: null,
      sortAt: time(e.matchedAt),
    });
  }
  return rows.sort((a, b) => b.sortAt - a.sortAt);
}

export type WorkedExample = {
  monthly: number | null;
  classesInMonth: number | null;
  classesLeft: number | null;
  firstAmount: number;
  dueKey: string | null;
};

/** The numbers behind the newest first invoice, for the worked example card. */
export function workedExample(inv: Invoice, monthlyFromBilling: number | null): WorkedExample {
  return {
    monthly: monthlyFromBilling,
    classesInMonth: inv.classesInMonth,
    classesLeft: inv.classesLeft,
    firstAmount: inv.total,
    dueKey: inv.dueKey,
  };
}

export type NewStudentStatus = { label: string; tone: BadgeTone };

export function newStudentStatus(row: NewStudentRow, now: Date = new Date()): NewStudentStatus {
  if (!row.invoice) return { label: "No first invoice yet", tone: "info" };
  const state = invoiceState(row.invoice, now);
  if (state.kind === "paid") return { label: "Paid", tone: "ok" };
  if (state.late) return { label: "Overdue", tone: "bad" };
  return { label: "Waiting for payment", tone: "warn" };
}
