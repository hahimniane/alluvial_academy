/**
 * Pure logic for the Staff pay page: what a row owes, what has been paid, how a
 * batch fee is split, administrator terms and pauses. The money rules live in
 * docs/finance/SPEC.md; the callables in functions/handlers/finance_staff.js
 * enforce them again on the server.
 */

import { toCsv } from "./csv.ts";
import { money, r2 } from "./model.ts";
import { monthLabel, monthName } from "./months.ts";

export type SummaryTeacher = {
  uid: string;
  name: string;
  hours: number;
  gross: number;
  penalties: number;
  net: number;
  final: boolean;
};

export type SummaryAdmin = {
  uid: string;
  name: string;
  role_title?: string;
  fixed: number;
  pct: number;
  share: number;
  total: number;
  paused: { reason: string; auto?: boolean } | null;
};

/** The part of getFinanceMonthSummary this page reads. */
export type StaffSummary = {
  month: string;
  status?: "open" | "closed";
  final?: boolean;
  teacher_pay?: number;
  teacher_pay_final?: boolean;
  admin_pay?: number;
  admin_base?: number;
  penalties?: number;
  teachers: SummaryTeacher[];
  admins: SummaryAdmin[];
};

export type PayoutHistoryEntry = {
  action: "payment" | "void";
  amount_paid?: number;
  method?: string;
  date_paid?: string;
  transfer_fee?: number;
  reference?: string;
  note?: string;
  voided?: boolean;
  reason?: string;
};

export type Payout = {
  user_id: string;
  name?: string;
  role: "teacher" | "admin";
  month: string;
  amount_due: number;
  amount_paid: number;
  date_paid: string;
  method: string;
  transfer_fee: number;
  reference: string;
  note: string;
  voided: boolean;
  void_reason?: string;
  history: PayoutHistoryEntry[];
};

export type PayTerm = { from_month: string; fixed: number; pct: number; note?: string; set_by_name?: string };
export type PayPause = {
  from_month: string;
  until_month: string | null;
  reason: string;
  auto?: boolean;
  resumed_reason?: string;
};
export type AdminTerms = { uid: string; name?: string; role_title?: string; terms: PayTerm[]; pauses: PayPause[] };

export const PAY_METHODS = ["Mobile money", "Bank transfer", "Western Union", "Cash", "Other"] as const;

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

const SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** "2026-10-03" -> "Oct 3". */
export function shortDate(ymd: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(ymd || "");
  if (!m) return ymd || "";
  return `${SHORT[Number(m[2]) - 1]} ${Number(m[3])}`;
}

/** Today in New York as yyyy-MM-dd. */
export function todayNy(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
}

// ---------------------------------------------------------------------------
// Payouts
// ---------------------------------------------------------------------------

export type PayState = "unpaid" | "partial" | "paid";

/** What a person's payout looks like against what they are owed. A voided payout is unpaid. */
export function payState(due: number, payout: Payout | null | undefined): PayState {
  if (!payout || payout.voided || !(payout.amount_paid > 0)) return "unpaid";
  return payout.amount_paid + 0.004 >= due ? "paid" : "partial";
}

export function amountLeft(due: number, payout: Payout | null | undefined): number {
  const paid = payout && !payout.voided ? payout.amount_paid : 0;
  return r2(Math.max(0, due - paid));
}

/** The Payment column: "Unpaid", "Paid Oct 3 · Mobile money · fee $3.00 · ref X", "Paid $150.00 of $206.40 · $56.40 left". */
export function payLabel(due: number, payout: Payout | null | undefined): string {
  const state = payState(due, payout);
  if (state === "unpaid" || !payout) return "Unpaid";
  const parts: string[] = [];
  if (state === "partial") {
    parts.push(`Paid ${money(payout.amount_paid)} of ${money(due)} · ${money(amountLeft(due, payout))} left`);
  } else {
    parts.push(`Paid ${shortDate(payout.date_paid)}`);
  }
  if (state === "partial") parts.push(shortDate(payout.date_paid));
  if (payout.method) parts.push(payout.method);
  if (payout.transfer_fee > 0) parts.push(`fee ${money(payout.transfer_fee)}`);
  if (payout.reference) parts.push(`ref ${payout.reference}`);
  return parts.join(" · ");
}

/** Share a batch fee evenly in cents; the first people take the odd cents. */
export function splitFee(total: number, count: number): number[] {
  if (!(total > 0) || count <= 0) return Array.from({ length: Math.max(0, count) }, () => 0);
  const cents = Math.round(total * 100);
  const base = Math.floor(cents / count);
  const extra = cents - base * count;
  return Array.from({ length: count }, (_, i) => (base + (i < extra ? 1 : 0)) / 100);
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

export type PayableRow = {
  uid: string;
  name: string;
  role: "teacher" | "admin";
  due: number;
  payout: Payout | null;
  /** Final pay, not paused, not already paid in full. */
  payable: boolean;
  /** Why it cannot be selected, for a tooltip. */
  blocked: string;
};

export function teacherRows(summary: StaffSummary, payouts: Map<string, Payout>): PayableRow[] {
  return summary.teachers.map((t) => {
    const payout = payouts.get(t.uid) ?? null;
    const state = payState(t.net, payout);
    const blocked = !t.final ? "Estimate until the audit is approved" : state === "paid" ? "Already paid" : "";
    return { uid: t.uid, name: t.name, role: "teacher", due: t.net, payout, payable: !blocked, blocked };
  });
}

export function adminRows(summary: StaffSummary, payouts: Map<string, Payout>): PayableRow[] {
  return summary.admins.map((a) => {
    const payout = payouts.get(a.uid) ?? null;
    const state = payState(a.total, payout);
    const blocked = a.paused ? "Pay is paused" : state === "paid" ? "Already paid" : a.total <= 0 ? "Nothing to pay" : "";
    return { uid: a.uid, name: a.name, role: "admin", due: a.total, payout, payable: !blocked, blocked };
  });
}

export type StaffCard = { label: string; value: string; sub: string; tone?: "bad" };

export function staffCards(summary: StaffSummary, teachers: PayableRow[], admins: PayableRow[]): StaffCard[] {
  const teacherPay = summary.teacher_pay ?? r2(summary.teachers.reduce((s, t) => s + t.net, 0));
  const teacherFinal = summary.teacher_pay_final ?? (summary.teachers.length > 0 && summary.teachers.every((t) => t.final));
  const penalties = summary.penalties ?? r2(summary.teachers.reduce((s, t) => s + t.penalties, 0));
  const cut = summary.teachers.filter((t) => t.penalties > 0).length;
  const adminPay = summary.admin_pay ?? r2(summary.admins.reduce((s, a) => s + a.total, 0));
  const activeAdmins = admins.filter((a) => !summary.admins.find((x) => x.uid === a.uid)?.paused);
  const everyone = [...teachers, ...activeAdmins];
  const paid = everyone.filter((r) => payState(r.due, r.payout) === "paid").length;
  const fees = r2([...teachers, ...admins].reduce((s, r) => s + (r.payout && !r.payout.voided ? r.payout.transfer_fee : 0), 0));
  return [
    { label: "Teacher pay", value: money(teacherPay), sub: `${summary.teachers.length} teachers · ${teacherFinal ? "final" : "estimate"}` },
    { label: "Penalties (all teachers)", value: `−${money(penalties)}`, sub: `${cut} ${cut === 1 ? "teacher" : "teachers"} had money cut`, tone: "bad" },
    { label: "Administrator pay", value: money(adminPay), sub: summary.final ? "Final" : "Estimate until the month is final" },
    { label: "Paid so far", value: `${paid} of ${everyone.length}`, sub: `Transfer fees ${money(fees)}` },
  ];
}

// ---------------------------------------------------------------------------
// Administrator terms and pauses
// ---------------------------------------------------------------------------

export function termInForce(terms: PayTerm[] | undefined, month: string): PayTerm | null {
  let best: PayTerm | null = null;
  for (const t of terms ?? []) {
    if (t.from_month > month) continue;
    if (!best || t.from_month >= best.from_month) best = t;
  }
  return best;
}

export function pauseForMonth(pauses: PayPause[] | undefined, month: string): PayPause | null {
  for (const p of pauses ?? []) {
    if (p.from_month > month) continue;
    if (p.until_month && p.until_month <= month) continue;
    return p;
  }
  return null;
}

export function openPause(pauses: PayPause[] | undefined): PayPause | null {
  const open = (pauses ?? []).filter((p) => !p.until_month);
  return open.length ? open[open.length - 1] : null;
}

/** "Paused since Oct · Account deactivated Oct 22 (automatic)" */
export function pausedLabel(pause: PayPause): string {
  return `Paused since ${monthName(pause.from_month)} · ${pause.reason}${pause.auto ? " (automatic)" : ""}`;
}

/** Live preview in the Edit pay dialog. */
export function previewText(fixed: number, pct: number, base: number, month: string): string {
  const b = Math.max(0, base);
  const f = Number.isFinite(fixed) ? Math.max(0, fixed) : 0;
  const p = Number.isFinite(pct) ? Math.min(100, Math.max(0, pct)) : 0;
  const head = `For ${monthName(month)}: ${money(f)}`;
  const body = p ? ` + ${p}% of ${money(b)} = ${money(r2(f + (b * p) / 100))}` : " (fixed only)";
  return `${head}${body}. The same terms carry into every month after, until you change them.`;
}

export function termHistoryLines(terms: PayTerm[], pauses: PayPause[]): string[] {
  const lines: Array<{ key: string; text: string }> = [];
  for (const t of terms) {
    lines.push({
      key: t.from_month + "a",
      text: `From ${monthLabel(t.from_month)}: ${money(t.fixed)} fixed${t.pct ? ` + ${t.pct}% share` : ", no share"}${t.note ? ` · ${t.note}` : ""}`,
    });
  }
  for (const p of pauses) {
    lines.push({
      key: p.from_month + "b",
      text: `Paused from ${monthLabel(p.from_month)}${p.until_month ? ` until ${monthLabel(p.until_month)}` : ""} · ${p.reason}${p.auto ? " (automatic)" : ""}${p.resumed_reason ? ` · resumed: ${p.resumed_reason}` : ""}`,
    });
  }
  return lines.sort((a, b) => (a.key < b.key ? -1 : 1)).map((l) => l.text).reverse();
}

/** Months a person can still change terms or pauses from: open months only. */
export function openMonthOptions(months: string[], closed: Set<string>): string[] {
  return months.filter((m) => !closed.has(m));
}

// ---------------------------------------------------------------------------
// CSV
// ---------------------------------------------------------------------------

export function staffCsv(month: string, teachers: PayableRow[], admins: PayableRow[], summary: StaffSummary): string {
  const header = ["Type", "Name", "Month", "Owed", "Paid", "Left", "Status", "Date paid", "Method", "Transfer fee", "Reference", "Note"];
  const out: Array<Array<string | number>> = [];
  const add = (type: string, r: PayableRow, status: string) => {
    const live = r.payout && !r.payout.voided ? r.payout : null;
    out.push([
      type,
      r.name,
      month,
      r.due.toFixed(2),
      (live?.amount_paid ?? 0).toFixed(2),
      amountLeft(r.due, r.payout).toFixed(2),
      status,
      live?.date_paid ?? "",
      live?.method ?? "",
      (live?.transfer_fee ?? 0).toFixed(2),
      live?.reference ?? "",
      live?.note ?? "",
    ]);
  };
  for (const r of teachers) {
    const final = summary.teachers.find((t) => t.uid === r.uid)?.final;
    add("Teacher", r, final ? payState(r.due, r.payout) : "estimate");
  }
  for (const r of admins) {
    const paused = Boolean(summary.admins.find((a) => a.uid === r.uid)?.paused);
    add("Administrator", r, paused ? "paused" : payState(r.due, r.payout));
  }
  return toCsv(header, out);
}
