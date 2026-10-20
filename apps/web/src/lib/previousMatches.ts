/**
 * Earlier teachers of an application.
 *
 * When a teacher stops teaching a student, the admin puts the student back on
 * the job board. The match that ended is kept on the application as
 * `metadata.previousMatches` (written by the `republishEnrollmentJob`
 * callable), so the card can say who taught the student before, until when,
 * and why it ended.
 */

export type PreviousMatch = {
  teacherId: string;
  teacherName: string;
  matchedAt: Date | null;
  unmatchedAt: Date | null;
  reason: string;
  byName: string;
};

/** The longest reason the callable keeps. */
export const REPUBLISH_REASON_MAX = 300;

const record = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};

const text = (value: unknown): string => (typeof value === "string" ? value.trim() : "");

/** A Firestore Timestamp, a Date, or the `{seconds}` shape of a raw read. */
export const toDate = (value: unknown): Date | null => {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  const data = record(value);
  if (typeof data.toDate === "function") {
    const date = (data.toDate as () => unknown)();
    return date instanceof Date ? date : null;
  }
  const seconds = typeof data.seconds === "number" ? data.seconds : typeof data._seconds === "number" ? data._seconds : null;
  return seconds === null ? null : new Date(seconds * 1000);
};

/** Oldest first, as they happened. Entries with no teacher at all are dropped. */
export const readPreviousMatches = (raw: unknown): PreviousMatch[] => {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => {
      const entry = record(item);
      return {
        teacherId: text(entry.teacherId),
        teacherName: text(entry.teacherName),
        matchedAt: toDate(entry.matchedAt),
        unmatchedAt: toDate(entry.unmatchedAt),
        reason: text(entry.reason),
        byName: text(entry.byName),
      };
    })
    .filter((entry) => entry.teacherId || entry.teacherName)
    .sort((a, b) => (a.unmatchedAt?.getTime() ?? 0) - (b.unmatchedAt?.getTime() ?? 0));
};

const formatDay = (date: Date, timeZone?: string) =>
  date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric", ...(timeZone ? { timeZone } : {}) });

/** "Previously matched with Mariama Bah · Oct 20, 2026 · Teacher left" */
export const previousMatchLine = (match: PreviousMatch, timeZone?: string): string =>
  [
    `Previously matched with ${match.teacherName || "a teacher"}`,
    match.unmatchedAt ? formatDay(match.unmatchedAt, timeZone) : "",
    match.reason,
  ]
    .filter(Boolean)
    .join(" · ");

/** The confirm dialog's sentence, so the card and the tests say the same thing. */
export const republishConfirmBody = (studentName: string): string =>
  `Teachers will see ${studentName || "this student"} on the job board again. Their account, parent and current classes stay as they are.`;

/** Collapses whitespace and caps the length, exactly as the callable stores it. */
export const normalizeRepublishReason = (raw: string): string =>
  raw.trim().replace(/\s+/g, " ").slice(0, REPUBLISH_REASON_MAX);
