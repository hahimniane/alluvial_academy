/**
 * Reading a "your classroom is coming back" refusal.
 *
 * When a hub's page freezes, the bot tears it down and holds the rejoin for a
 * fixed spell, so it can say when the classroom should be usable again. The
 * join callable passes that moment through on the refusal. Every other reason
 * for a missing classroom has no honest estimate, and the backend sends null
 * rather than a guess — so a null here means "wait, but we cannot say how
 * long", never "it is back".
 */

export type ClassroomReconnect = {
  /** When the classroom should be usable again, or null if not yet knowable. */
  expectedBackAt: Date | null;
};

type CallableErrorLike = {
  code?: unknown;
  details?: unknown;
};

/**
 * Returns reconnect information when this error is a hub that is coming back,
 * and null for every other failure — which the caller should keep showing as
 * an ordinary error, because retrying will not fix it.
 */
export function readClassroomReconnect(error: unknown): ClassroomReconnect | null {
  if (!error || typeof error !== "object") return null;
  const { code, details } = error as CallableErrorLike;
  // Callable errors arrive as "functions/unavailable".
  const isUnavailable = typeof code === "string" && code.endsWith("unavailable");
  if (!isUnavailable) return null;
  if (!details || typeof details !== "object") return null;
  const payload = details as { reason?: unknown; expectedBackAtIso?: unknown };
  if (payload.reason !== "classroom_reconnecting") return null;

  const iso = typeof payload.expectedBackAtIso === "string" ? payload.expectedBackAtIso : "";
  const expected = iso ? new Date(iso) : null;
  const usable = expected && Number.isFinite(expected.getTime()) && expected.getTime() > Date.now();
  return { expectedBackAt: usable ? expected : null };
}

/** Seconds remaining, floored at zero; null when there is nothing to count to. */
export function secondsUntil(target: Date | null, now: number): number | null {
  if (!target) return null;
  return Math.max(0, Math.ceil((target.getTime() - now) / 1000));
}

/** m:ss, for a wait that is always minutes rather than hours. */
export function formatCountdown(totalSeconds: number): string {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}
