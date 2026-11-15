/**
 * Daily memorization count in `quran_memorization/{uid}`, shared with the
 * Flutter reader (lib/features/quran_reader/services/memorization_service.dart):
 *
 *   daily_log: { "YYYY-MM-DD": count }   // a nested map
 *
 * Earlier web builds wrote the count with `setDoc(..., { "daily_log.<day>": … }, { merge: true })`.
 * `setDoc` does not read dots as a path, so that created a top-level field
 * literally named `daily_log.<day>` that neither reader looks at. These
 * helpers read both shapes and plan folding the stray fields back into the map.
 *
 * Pure helpers only; the Firestore calls live in QuranReaderPage.
 */

export const STRAY_DAILY_LOG_PREFIX = "daily_log.";

const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

function toCount(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}

/** Top-level `daily_log.<day>` fields left by the old web write, keyed by day. */
export function strayDailyLogFields(data: Record<string, unknown>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const [key, value] of Object.entries(data)) {
    if (!key.startsWith(STRAY_DAILY_LOG_PREFIX)) continue;
    const day = key.slice(STRAY_DAILY_LOG_PREFIX.length);
    if (!DAY_KEY.test(day)) continue;
    out[day] = toCount(value);
  }
  return out;
}

/** The day → count log as both apps should see it: the map plus any stray fields. */
export function readDailyLog(data: Record<string, unknown>): Record<string, number> {
  const log: Record<string, number> = {};
  const map = data.daily_log;
  if (map && typeof map === "object" && !Array.isArray(map)) {
    for (const [day, value] of Object.entries(map as Record<string, unknown>)) log[day] = toCount(value);
  }
  for (const [day, count] of Object.entries(strayDailyLogFields(data))) log[day] = (log[day] ?? 0) + count;
  return log;
}

/**
 * What to write to move stray fields into `daily_log`: the merged totals for
 * the affected days, and the stray field names to delete. Null when there is
 * nothing to fold. Run it inside a transaction on a fresh read so two tabs
 * cannot add the same stray count twice.
 */
export function planDailyLogRepair(
  data: Record<string, unknown>,
): { dailyLog: Record<string, number>; strayFields: string[] } | null {
  const stray = strayDailyLogFields(data);
  const days = Object.keys(stray);
  if (days.length === 0) return null;
  const merged = readDailyLog(data);
  const dailyLog: Record<string, number> = {};
  for (const day of days) dailyLog[day] = merged[day] ?? 0;
  return { dailyLog, strayFields: days.map((day) => `${STRAY_DAILY_LOG_PREFIX}${day}`) };
}
