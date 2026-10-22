/**
 * Penalties taken from teachers' pay, read from `teacher_audits`.
 *
 * Where penalties live (checked against production audits, Oct 2026):
 *   - coach/admin lines: `paymentSummary.coachAdjustmentLines[]` with
 *     `type: 'penalty'`, `amount`, free-text `reason`, `createdAt`, and (new)
 *     `penalty_reason` (a code from PENALTY_REASONS) + `penalty_note`;
 *   - automatic penalties: `paymentSummary.totalPenalties` (0 on every audit
 *     today). It has no line items, so it counts as one "Other" entry.
 * Entries from before the reason codes carry no `penalty_reason`: they count as
 * `other` and their old text is shown as the note.
 *
 * Pure functions only (filters, trend, history), unit-tested in
 * src/lib/__tests__/finance_staff_penalties.test.ts.
 */

import { toCsv } from "./csv.ts";
import { addMonths, monthLabel, monthShort } from "./months.ts";

export type PenaltyReasonCode =
  | "late_clock_in"
  | "missed_class"
  | "late_class_report"
  | "left_class_early"
  | "no_camera_or_setup"
  | "conduct"
  | "other";

/** Code to label. The audit branch imports this same list. */
export const PENALTY_REASONS: Record<PenaltyReasonCode, string> = {
  late_clock_in: "Late clock-in",
  missed_class: "Missed a class without notice",
  late_class_report: "Late class report",
  left_class_early: "Left class early",
  no_camera_or_setup: "Camera/setup not as required",
  conduct: "Conduct",
  other: "Other",
};

export const PENALTY_REASON_CODES = Object.keys(PENALTY_REASONS) as PenaltyReasonCode[];

export function normalizeReasonCode(raw: unknown): PenaltyReasonCode {
  const code = typeof raw === "string" ? raw.trim() : "";
  return (PENALTY_REASON_CODES as string[]).includes(code) ? (code as PenaltyReasonCode) : "other";
}

export function penaltyReasonLabel(code: PenaltyReasonCode): string {
  return PENALTY_REASONS[code];
}

export type PenaltyEntry = {
  uid: string;
  name: string;
  /** Month taught (audit month), yyyy-MM. */
  month: string;
  amount: number;
  reason: PenaltyReasonCode;
  note: string;
  /** When the line was entered, yyyy-MM-dd (empty for automatic penalties). */
  enteredOn: string;
  enteredBy: string;
};

export type AuditSlice = {
  id: string;
  data: Record<string, unknown>;
};

type Row = Record<string, unknown>;
const rec = (v: unknown): Row => (v && typeof v === "object" && !Array.isArray(v) ? (v as Row) : {});
const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : 0);
const str = (v: unknown): string => (typeof v === "string" ? v.trim() : "");

function isoDay(value: unknown): string {
  const v = value as { toDate?: () => Date } | string | Date | null | undefined;
  let d: Date | null = null;
  if (v && typeof v === "object" && "toDate" in v && typeof v.toDate === "function") d = v.toDate();
  else if (v instanceof Date) d = v;
  else if (typeof v === "string") d = new Date(v);
  if (!d || Number.isNaN(d.getTime())) return "";
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" }).format(d);
}

export type AuditSummary = {
  uid: string;
  name: string;
  month: string;
  gross: number;
  entries: PenaltyEntry[];
};

/** One audit document -> its gross pay and every penalty on it. */
export function summarizeAudit(audit: AuditSlice): AuditSummary | null {
  const d = audit.data;
  const month = str(d.yearMonth);
  const uid = str(d.userId) || str(d.oderId) || audit.id.replace(/_\d{4}-\d{2}$/, "");
  if (!month || !uid) return null;
  const name = str(d.teacherName) || "Teacher";
  const ps = rec(d.paymentSummary);
  const entries: PenaltyEntry[] = [];

  const lines = Array.isArray(ps.coachAdjustmentLines) ? ps.coachAdjustmentLines : [];
  for (const raw of lines) {
    const line = rec(raw);
    if (str(line.type) !== "penalty") continue;
    const amount = Math.abs(num(line.amount));
    if (amount <= 0) continue;
    entries.push({
      uid,
      name,
      month,
      amount,
      reason: normalizeReasonCode(line.penalty_reason),
      note: str(line.penalty_note) || str(line.reason),
      enteredOn: isoDay(line.createdAt),
      enteredBy: str(line.createdByName),
    });
  }
  const automatic = num(ps.totalPenalties);
  if (automatic > 0) {
    entries.push({ uid, name, month, amount: automatic, reason: "other", note: "Automatic penalties", enteredOn: "", enteredBy: "" });
  }
  return { uid, name, month, gross: num(ps.totalGrossPayment), entries };
}

/** The months to read: from the earlier of January and five months back, to `month`. */
export function auditMonthsToRead(month: string): string[] {
  const year = month.slice(0, 4);
  const start = `${year}-01`;
  const back = addMonths(month, -5);
  const first = back < start ? back : start;
  const out: string[] = [];
  for (let m = first; m <= month; m = addMonths(m, 1)) out.push(m);
  return out;
}

/** Firestore `in` takes up to 30 values; stay well under it. */
export function chunk<T>(items: T[], size = 10): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

export type PenaltyPeriod = "month" | "last3" | "ytd";
export type PenaltyShow = "with" | "all" | "none";
export type PenaltyChip = "all" | "repeat" | "month" | "rising" | "over5";
export type PenaltySort = "period" | "ytd" | "month" | "times" | "pct" | "recent" | "name";
export type Trend = "Rising" | "Falling" | "Steady";

export type PenaltyFilters = {
  q: string;
  period: PenaltyPeriod;
  /** "all" or a PenaltyReasonCode. */
  reason: string;
  show: PenaltyShow;
  min: string;
  max: string;
  minTimes: string;
  sort: PenaltySort;
  chip: PenaltyChip;
};

export const DEFAULT_FILTERS: PenaltyFilters = {
  q: "",
  period: "ytd",
  reason: "all",
  show: "with",
  min: "",
  max: "",
  minTimes: "",
  sort: "period",
  chip: "all",
};

export type TeacherPenaltyRow = {
  uid: string;
  name: string;
  /** Selected month. */
  monthTotal: number;
  /** Year so far, up to the selected month. */
  ytd: number;
  ytdCount: number;
  /** In the chosen period and reason. */
  periodTotal: number;
  periodCount: number;
  periodEntries: PenaltyEntry[];
  /** Newest first. */
  history: PenaltyEntry[];
  trend: Trend;
  /** Penalties as a percent of gross pay this year. */
  pctLost: number;
  /** Month of the newest penalty ("2026-05"), or "". */
  lastMonth: string;
};

const byNewest = (a: PenaltyEntry, b: PenaltyEntry) =>
  a.month < b.month ? 1 : a.month > b.month ? -1 : a.enteredOn < b.enteredOn ? 1 : a.enteredOn > b.enteredOn ? -1 : 0;

export function periodStart(month: string, period: PenaltyPeriod): string {
  if (period === "month") return month;
  if (period === "last3") {
    const start = addMonths(month, -2);
    const yearStart = `${month.slice(0, 4)}-01`;
    return start < yearStart ? yearStart : start;
  }
  return `${month.slice(0, 4)}-01`;
}

export function periodLabel(month: string, period: PenaltyPeriod): string {
  if (period === "month") return monthLabel(month);
  if (period === "last3") return `${monthShort(periodStart(month, "last3"))} – ${monthShort(month)}`;
  return `${month.slice(0, 4)} so far`;
}

/** Last three months against the three before. */
export function trendOf(entries: PenaltyEntry[], month: string): Trend {
  const recentFrom = addMonths(month, -2);
  const beforeFrom = addMonths(month, -5);
  let recent = 0;
  let before = 0;
  for (const e of entries) {
    if (e.month > month) continue;
    if (e.month >= recentFrom) recent += e.amount;
    else if (e.month >= beforeFrom) before += e.amount;
  }
  return recent > before ? "Rising" : recent < before ? "Falling" : "Steady";
}

const r2 = (n: number) => Math.round(n * 100) / 100;

/** Every teacher seen in the audits, with their numbers for the selected month. */
export function buildTeacherRows(audits: AuditSummary[], month: string, filters: Pick<PenaltyFilters, "period" | "reason">): TeacherPenaltyRow[] {
  const year = month.slice(0, 4);
  const from = periodStart(month, filters.period);
  const people = new Map<string, { name: string; nameMonth: string; audits: AuditSummary[] }>();
  for (const a of audits) {
    if (a.month > month) continue;
    const p = people.get(a.uid) ?? { name: a.name, nameMonth: a.month, audits: [] };
    p.audits.push(a);
    // The newest audit's name wins.
    if (a.month >= p.nameMonth) {
      p.name = a.name;
      p.nameMonth = a.month;
    }
    people.set(a.uid, p);
  }
  const rows: TeacherPenaltyRow[] = [];
  for (const [uid, p] of people) {
    const all = p.audits.flatMap((a) => a.entries);
    const thisYear = all.filter((e) => e.month.startsWith(year));
    const inPeriod = thisYear.filter((e) => e.month >= from && (filters.reason === "all" || e.reason === filters.reason));
    const gross = p.audits.filter((a) => a.month.startsWith(year)).reduce((s, a) => s + a.gross, 0);
    const ytd = thisYear.reduce((s, e) => s + e.amount, 0);
    const history = [...thisYear].sort(byNewest);
    rows.push({
      uid,
      name: p.name,
      monthTotal: r2(thisYear.filter((e) => e.month === month).reduce((s, e) => s + e.amount, 0)),
      ytd: r2(ytd),
      ytdCount: thisYear.length,
      periodTotal: r2(inPeriod.reduce((s, e) => s + e.amount, 0)),
      periodCount: inPeriod.length,
      periodEntries: inPeriod,
      history,
      trend: trendOf(all, month),
      pctLost: gross > 0 ? (ytd / gross) * 100 : 0,
      lastMonth: history[0]?.month ?? "",
    });
  }
  return rows;
}

const chipTests: Record<PenaltyChip, (r: TeacherPenaltyRow) => boolean> = {
  all: () => true,
  repeat: (r) => r.ytdCount >= 3,
  month: (r) => r.monthTotal > 0,
  rising: (r) => r.trend === "Rising",
  over5: (r) => r.pctLost >= 5,
};

export const CHIP_LABELS: Record<PenaltyChip, string> = {
  all: "All",
  repeat: "Repeat (3+ this year)",
  month: "Penalty this month",
  rising: "Rising",
  over5: "Over 5% of earnings",
};

const sorters: Record<PenaltySort, (a: TeacherPenaltyRow, b: TeacherPenaltyRow) => number> = {
  period: (a, b) => b.periodTotal - a.periodTotal || b.ytd - a.ytd,
  ytd: (a, b) => b.ytd - a.ytd,
  month: (a, b) => b.monthTotal - a.monthTotal || b.ytd - a.ytd,
  times: (a, b) => b.periodCount - a.periodCount || b.periodTotal - a.periodTotal,
  pct: (a, b) => b.pctLost - a.pctLost,
  recent: (a, b) => (a.lastMonth < b.lastMonth ? 1 : a.lastMonth > b.lastMonth ? -1 : 0),
  name: (a, b) => a.name.localeCompare(b.name),
};

function parseNum(v: string): number | null {
  if (v.trim() === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

/** Everything but the chip (the chip counts are shown for this set). */
export function baseRows(rows: TeacherPenaltyRow[], f: PenaltyFilters): TeacherPenaltyRow[] {
  const q = f.q.trim().toLowerCase();
  const min = parseNum(f.min);
  const max = parseNum(f.max);
  const times = parseNum(f.minTimes);
  return rows.filter((r) => {
    if (q && !r.name.toLowerCase().includes(q)) return false;
    if (f.show === "with" && !(r.periodTotal > 0)) return false;
    if (f.show === "none" && r.ytd > 0) return false;
    if (min !== null && r.periodTotal < min) return false;
    if (max !== null && r.periodTotal > max) return false;
    if (times !== null && r.periodCount < times) return false;
    return true;
  });
}

export function chipCounts(base: TeacherPenaltyRow[]): Record<PenaltyChip, number> {
  const out = {} as Record<PenaltyChip, number>;
  (Object.keys(chipTests) as PenaltyChip[]).forEach((c) => {
    out[c] = base.filter(chipTests[c]).length;
  });
  return out;
}

export function applyFilters(rows: TeacherPenaltyRow[], f: PenaltyFilters): TeacherPenaltyRow[] {
  return baseRows(rows, f).filter(chipTests[f.chip]).sort(sorters[f.sort]);
}

export type ReasonSlice = { code: PenaltyReasonCode; label: string; amount: number; count: number };

/** Amount and count by reason code over the visible teachers' period entries, biggest first. */
export function reasonBreakdown(rows: TeacherPenaltyRow[]): ReasonSlice[] {
  const by = new Map<PenaltyReasonCode, ReasonSlice>();
  for (const r of rows) {
    for (const e of r.periodEntries) {
      const s = by.get(e.reason) ?? { code: e.reason, label: PENALTY_REASONS[e.reason], amount: 0, count: 0 };
      s.amount = r2(s.amount + e.amount);
      s.count += 1;
      by.set(e.reason, s);
    }
  }
  return [...by.values()].sort((a, b) => b.amount - a.amount || b.count - a.count);
}

/** "Late clock-in ×2, Conduct" for the Reasons column. */
export function reasonsText(entries: PenaltyEntry[]): string {
  const counts = new Map<PenaltyReasonCode, number>();
  for (const e of entries) counts.set(e.reason, (counts.get(e.reason) ?? 0) + 1);
  return [...counts.entries()].map(([code, n]) => PENALTY_REASONS[code] + (n > 1 ? ` ×${n}` : "")).join(", ");
}

export type PenaltyCards = {
  monthTotal: number;
  monthTeachers: number;
  ytdTotal: number;
  ytdCount: number;
  teachersWithAny: number;
  teachersTotal: number;
  teachersRepeat: number;
  topReason: PenaltyReasonCode | null;
  topReasonCount: number;
};

export function penaltyCards(rows: TeacherPenaltyRow[]): PenaltyCards {
  const counts = new Map<PenaltyReasonCode, number>();
  for (const r of rows) for (const e of r.history) counts.set(e.reason, (counts.get(e.reason) ?? 0) + 1);
  let top: PenaltyReasonCode | null = null;
  for (const [code, n] of counts) if (top === null || n > (counts.get(top) ?? 0)) top = code;
  return {
    monthTotal: r2(rows.reduce((s, r) => s + r.monthTotal, 0)),
    monthTeachers: rows.filter((r) => r.monthTotal > 0).length,
    ytdTotal: r2(rows.reduce((s, r) => s + r.ytd, 0)),
    ytdCount: rows.reduce((s, r) => s + r.ytdCount, 0),
    teachersWithAny: rows.filter((r) => r.ytd > 0).length,
    teachersTotal: rows.length,
    teachersRepeat: rows.filter((r) => r.ytdCount >= 3).length,
    topReason: top,
    topReasonCount: top ? (counts.get(top) ?? 0) : 0,
  };
}

/** "May 2026 — Late clock-in · −$20.00 · note (set Jul 12 by Chernor)" */
export function historyLine(e: PenaltyEntry, money: (n: number) => string): string {
  const parts = [`${monthLabel(e.month)} — ${PENALTY_REASONS[e.reason]} · −${money(e.amount)}`];
  if (e.note && e.note !== PENALTY_REASONS[e.reason]) parts.push(e.note);
  const set = e.enteredOn ? `set ${monthShort(e.enteredOn.slice(0, 7)).split(" ")[0]} ${Number(e.enteredOn.slice(8, 10))}` : "";
  const by = e.enteredBy ? `by ${e.enteredBy}` : "";
  const meta = [set, by].filter(Boolean).join(" ");
  return parts.join(" · ") + (meta ? ` (${meta})` : "");
}

// ---------------------------------------------------------------------------
// CSV
// ---------------------------------------------------------------------------

export function penaltiesCsv(rows: TeacherPenaltyRow[], month: string, period: PenaltyPeriod): string {
  const label = periodLabel(month, period);
  return toCsv(
    ["Teacher", monthLabel(month), label, "Times", "Reasons", `% of ${month.slice(0, 4)} earnings`, "Trend", "Last one"],
    rows.map((r) => [
      r.name,
      r.monthTotal.toFixed(2),
      r.periodTotal.toFixed(2),
      r.periodCount,
      reasonsText(r.periodEntries),
      r.pctLost.toFixed(1),
      r.trend,
      r.lastMonth ? monthLabel(r.lastMonth) : "",
    ])
  );
}
