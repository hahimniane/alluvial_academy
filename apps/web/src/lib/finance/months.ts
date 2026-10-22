/**
 * Month helpers for finance. A finance month is a `yyyy-MM` string in New York
 * time (Alluwal's books run on US Eastern time, like the clock-in cutoff).
 */

const NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

export function monthOf(date: Date, timeZone = "America/New_York"): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit" }).formatToParts(date);
  const y = parts.find((p) => p.type === "year")?.value ?? "1970";
  const m = parts.find((p) => p.type === "month")?.value ?? "01";
  return `${y}-${m}`;
}

/** A real finance month, yyyy-MM with a month from 01 to 12. */
export function isFinanceMonth(value: unknown): value is string {
  return typeof value === "string" && /^\d{4}-(0[1-9]|1[0-2])$/.test(value);
}

/** The month asked for in the URL, or the current one when it is missing or not a month (the server answers a bad month with a 400). */
export function monthFromParam(value: string | null | undefined, now: Date = new Date()): string {
  return isFinanceMonth(value) ? value : currentMonth(now);
}

export function currentMonth(now: Date = new Date()): string {
  return monthOf(now);
}

export function addMonths(month: string, delta: number): string {
  const [y, m] = month.split("-").map(Number);
  const idx = y * 12 + (m - 1) + delta;
  const ny = Math.floor(idx / 12);
  const nm = (idx % 12) + 1;
  return `${ny}-${String(nm).padStart(2, "0")}`;
}

/** The `count` months ending with `end`, oldest first. */
export function recentMonths(count: number, end: string): string[] {
  const out: string[] = [];
  for (let i = count - 1; i >= 0; i--) out.push(addMonths(end, -i));
  return out;
}

/** Inclusive list from `from` to `to` (swapped if reversed). */
export function monthRange(from: string, to: string): string[] {
  const [a, b] = from <= to ? [from, to] : [to, from];
  const out: string[] = [];
  for (let m = a; m <= b; m = addMonths(m, 1)) out.push(m);
  return out;
}

export function monthLabel(month: string): string {
  const [y, m] = month.split("-").map(Number);
  return `${NAMES[m - 1]} ${y}`;
}

export function monthName(month: string): string {
  return NAMES[Number(month.split("-")[1]) - 1];
}

export function monthShort(month: string): string {
  const [y, m] = month.split("-");
  return `${NAMES[Number(m) - 1].slice(0, 3)} ${y.slice(2)}`;
}
