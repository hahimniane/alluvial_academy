/**
 * Reading `finance_months/{month}`: whether the month is closed and the log of
 * who closed and reopened it.
 */

import type { MonthLogEntry } from "./summary.ts";
import { monthName } from "./months.ts";

export type MonthRecord = {
  status: "open" | "closed";
  log: MonthLogEntry[];
};

type TimeLike = { toDate?: () => Date; seconds?: number; _seconds?: number } | Date | null | undefined;

function toDate(value: TimeLike): Date | null {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  const seconds = typeof value.seconds === "number" ? value.seconds : value._seconds;
  return typeof seconds === "number" ? new Date(seconds * 1000) : null;
}

const str = (v: unknown) => (typeof v === "string" ? v : "");

/** A month with no record is open. */
export function parseMonthRecord(data: Record<string, unknown> | undefined | null): MonthRecord {
  const rawLog = Array.isArray(data?.log) ? (data!.log as Record<string, unknown>[]) : [];
  const log: MonthLogEntry[] = rawLog
    .filter((e) => e && (e.action === "closed" || e.action === "reopened"))
    .map((e) => ({
      action: e.action as "closed" | "reopened",
      at: toDate(e.at as TimeLike),
      by: str(e.by),
      by_name: str(e.by_name),
      reason: str(e.reason),
    }));
  // Entries are appended in order, but sort so a clock-skewed one cannot jumble the history.
  log.sort((a, b) => (a.at?.getTime() ?? 0) - (b.at?.getTime() ?? 0));
  return { status: data?.status === "closed" ? "closed" : "open", log };
}

export function formatLogDate(date: Date | null): string {
  if (!date) return "";
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "America/New_York" }).format(date);
}

/** "Oct 21, 2026 — Hawa Bah closed October" or "… reopened September: “reason”". */
export function describeLogEntry(entry: MonthLogEntry, month: string, currentUid?: string): string {
  const who = currentUid && entry.by === currentUid ? "you" : entry.by_name || "An administrator";
  const date = formatLogDate(entry.at);
  const what = entry.action === "closed" ? `${monthName(month)} closed by ${who}` : `${monthName(month)} reopened by ${who}: “${entry.reason}”`;
  return date ? `${date} — ${what}` : what;
}
