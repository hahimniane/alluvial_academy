/**
 * The side panel's extra facts (F5): amount owed, attendance this month, next
 * class and a teacher's local time. Pure; usersExtrasData.ts reads the
 * documents only when a panel opens.
 *
 * Owed uses the Finance page's own invoice rules (lib/finance/invoices.ts
 * normalizeInvoice + invoiceState): cancelled invoices owe nothing, a partly
 * paid invoice owes total − paid, late means owed and past its due day.
 *
 * Attendance uses the formula of the parent's Progress tab (parentHome.ts
 * childProgress, Flutter `_buildChildProgressSnapshot`): attended classes
 * (completed, partly or fully completed) out of attended + missed +
 * cancelled; classes not yet marked do not count. It reads the classes of the
 * month from the live and the archived collections.
 */

import { invoiceState, normalizeInvoice } from "./finance/invoices.ts";

type Data = Record<string, unknown>;

// ─── Amount owed ───────────────────────────────────────────────────────────

export type Owed = {
  /** Currency → amount still owed (rounded to cents), only currencies with something owed. */
  owed: Map<string, number>;
  /** Currency → part of it past its due day. */
  late: Map<string, number>;
  openInvoices: number;
  partlyPaid: number;
  /** The invoices read hit the read limit: the total may be short. */
  capped: boolean;
};

const r2 = (n: number) => Math.round(n * 100) / 100;

/** Merges invoice documents read by parent id and by student id (deduplicated by id). */
export function owedFromInvoices(docs: readonly { id: string; data: Data }[], now: Date, capped = false): Owed {
  const seen = new Set<string>();
  const owed = new Map<string, number>();
  const late = new Map<string, number>();
  let openInvoices = 0;
  let partlyPaid = 0;
  for (const { id, data } of docs) {
    if (seen.has(id)) continue;
    seen.add(id);
    const inv = normalizeInvoice(id, data);
    const state = invoiceState(inv, now);
    if (state.owed <= 0) continue;
    openInvoices += 1;
    if (state.kind === "partly") partlyPaid += 1;
    const cur = inv.currency.toUpperCase();
    owed.set(cur, r2((owed.get(cur) ?? 0) + state.owed));
    if (state.late) late.set(cur, r2((late.get(cur) ?? 0) + state.owed));
  }
  return { owed, late, openInvoices, partlyPaid, capped };
}

export function money(amount: number, currency: string): string {
  try {
    return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(amount);
  } catch {
    return `${amount.toFixed(2)} ${currency}`;
  }
}

/** "$120.00" or "$120.00 + 40,000 GNF"; "Nothing owed" when clear. */
export function owedText(o: Owed): string {
  if (o.owed.size === 0) return "Nothing owed";
  return [...o.owed].map(([cur, amount]) => money(amount, cur)).join(" + ");
}

export function owedDetail(o: Owed): string {
  if (o.owed.size === 0) return o.capped ? "From the most recent invoices" : "";
  const parts = [`${o.openInvoices} unpaid ${o.openInvoices === 1 ? "invoice" : "invoices"}`];
  if (o.partlyPaid > 0) parts.push(`${o.partlyPaid} partly paid`);
  if (o.late.size > 0) parts.push(`${[...o.late].map(([c, a]) => money(a, c)).join(" + ")} overdue`);
  if (o.capped) parts.push("most recent invoices only");
  return parts.join(" · ");
}

// ─── Classes ───────────────────────────────────────────────────────────────

export type PanelShift = {
  id: string;
  start: Date;
  end: Date;
  status: string;
  teaching: boolean;
  subject: string;
  teacherName: string;
  studentNames: string[];
};

const toDate = (value: unknown): Date | null => {
  if (value && typeof value === "object" && typeof (value as { toDate?: unknown }).toDate === "function") {
    const d = (value as { toDate: () => Date }).toDate();
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  return null;
};

const str = (v: unknown) => (v === null || v === undefined ? "" : String(v)).trim();

export function mapPanelShift(id: string, data: Data): PanelShift | null {
  const start = toDate(data.shift_start);
  const end = toDate(data.shift_end);
  if (!start || !end) return null;
  const category = str(data.shift_category ?? data.category ?? "teaching").toLowerCase() || "teaching";
  return {
    id,
    start,
    end,
    status: str(data.status),
    teaching: category === "teaching",
    subject: str(data.subject_display_name) || str(data.subject_name) || str(data.subject),
    teacherName: str(data.teacher_name),
    studentNames: Array.isArray(data.student_names) ? data.student_names.map(str).filter(Boolean) : [],
  };
}

/** Live + archived copies of one class are the same class: keep the live one. */
export function mergeShifts(live: readonly PanelShift[], archived: readonly PanelShift[]): PanelShift[] {
  const byId = new Map<string, PanelShift>();
  for (const s of archived) byId.set(s.id, s);
  for (const s of live) byId.set(s.id, s);
  return [...byId.values()].sort((a, b) => a.start.getTime() - b.start.getTime());
}

const ATTENDED = new Set(["completed", "fullyCompleted", "partiallyCompleted"]);

export type MonthAttendance = { attended: number; missed: number; cancelled: number; tracked: number; rate: number | null };

/** The first instant of `now`'s month, in the viewer's time zone. */
export const monthStartOf = (now: Date) => new Date(now.getFullYear(), now.getMonth(), 1);

/** Teaching classes that started this month up to now, by status. */
export function monthAttendance(shifts: readonly PanelShift[], now: Date): MonthAttendance {
  const from = monthStartOf(now).getTime();
  let attended = 0;
  let missed = 0;
  let cancelled = 0;
  for (const s of shifts) {
    if (!s.teaching) continue;
    const t = s.start.getTime();
    if (t < from || t > now.getTime()) continue;
    if (ATTENDED.has(s.status)) attended += 1;
    else if (s.status === "missed") missed += 1;
    else if (s.status === "cancelled") cancelled += 1;
  }
  const tracked = attended + missed + cancelled;
  return { attended, missed, cancelled, tracked, rate: tracked > 0 ? attended / tracked : null };
}

export function attendanceText(a: MonthAttendance): string {
  if (a.tracked === 0) return "No classes marked yet this month";
  return `${a.attended} of ${a.tracked} classes · ${Math.round((a.rate ?? 0) * 100)}%`;
}

export function attendanceDetail(a: MonthAttendance): string {
  const parts: string[] = [];
  if (a.missed > 0) parts.push(`${a.missed} missed`);
  if (a.cancelled > 0) parts.push(`${a.cancelled} cancelled`);
  return parts.join(" · ");
}

/** The class happening now, else the next one; teaching or not, never a cancelled one. */
export function nextClass(shifts: readonly PanelShift[], now: Date): { shift: PanelShift; now: boolean } | null {
  const t = now.getTime();
  const candidates = shifts
    .filter((s) => s.status !== "cancelled" && s.end.getTime() > t)
    .sort((a, b) => a.start.getTime() - b.start.getTime());
  const first = candidates[0];
  return first ? { shift: first, now: first.start.getTime() <= t } : null;
}

const DAY_TIME = new Intl.DateTimeFormat("en-US", { weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });

export function nextClassText(next: { shift: PanelShift; now: boolean } | null, viewerTz?: string): string {
  if (!next) return "No upcoming class";
  const when = viewerTz
    ? new Intl.DateTimeFormat("en-US", { weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: viewerTz }).format(next.shift.start)
    : DAY_TIME.format(next.shift.start);
  return next.now ? `In class now (started ${when})` : when;
}

export function nextClassDetail(next: { shift: PanelShift; now: boolean } | null, forTeacher: boolean): string {
  if (!next) return "";
  const s = next.shift;
  const who = forTeacher ? s.studentNames.join(", ") : s.teacherName;
  return [s.subject, who].filter(Boolean).join(" · ");
}

// ─── Local time ────────────────────────────────────────────────────────────

/** Whether the browser knows this IANA zone. */
export function isValidTimeZone(zone: string): boolean {
  if (!zone) return false;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: zone }).format(0);
    return true;
  } catch {
    return false;
  }
}

/** Minutes the zone is ahead of UTC at that instant (DST included). */
export function zoneOffsetMinutes(zone: string, at: Date): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: zone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(at);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? "0");
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour") % 24, get("minute"), get("second"));
  return Math.round((asUtc - Math.floor(at.getTime() / 1000) * 1000) / 60_000);
}

const offsetLabel = (minutes: number) => {
  const sign = minutes < 0 ? "−" : "+";
  const abs = Math.abs(minutes);
  const h = Math.floor(abs / 60);
  const m = abs % 60;
  return `UTC${sign}${h}${m ? `:${String(m).padStart(2, "0")}` : ""}`;
};

const hoursWord = (minutes: number) => {
  const h = Math.abs(minutes) / 60;
  const text = Number.isInteger(h) ? String(h) : h.toFixed(1).replace(/\.0$/, "");
  return `${text} ${h === 1 ? "hour" : "hours"}`;
};

export type LocalTime = { time: string; zone: string; offset: string; relative: string } | { invalid: string } | null;

/** "3:42 PM Tue" in the person's zone, its UTC offset, and how far it is from the viewer. */
export function localTime(zone: string, now: Date, viewerZone: string): LocalTime {
  const z = zone.trim();
  if (!z) return null;
  if (!isValidTimeZone(z)) return { invalid: z };
  const time = new Intl.DateTimeFormat("en-US", { timeZone: z, weekday: "short", hour: "numeric", minute: "2-digit" }).format(now);
  const theirs = zoneOffsetMinutes(z, now);
  const mine = isValidTimeZone(viewerZone) ? zoneOffsetMinutes(viewerZone, now) : -now.getTimezoneOffset();
  const diff = theirs - mine;
  const relative = diff === 0 ? "Same time as you" : `${hoursWord(diff)} ${diff > 0 ? "ahead of" : "behind"} you`;
  return { time, zone: z, offset: offsetLabel(theirs), relative };
}
