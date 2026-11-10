/**
 * What to show when joining a class is refused. A message the server wrote is
 * kept. When the browser gave up on its own (a timeout, no network), Firebase
 * leaves only a bare code such as "deadline-exceeded", which tells a teacher
 * nothing, so it becomes a plain sentence instead. Returns English source text
 * for the caller to translate.
 */
export const SLOW_CONNECTION_TEXT =
  "Your connection is too slow to reach the class. Check your internet and try again.";
export const JOIN_FAILED_TEXT = "Unable to join this class.";

export function classroomErrorText(error: unknown): string {
  const rawCode = (error as { code?: unknown } | null)?.code;
  const code = typeof rawCode === "string" ? rawCode.toLowerCase().replace(/^functions\//, "") : "";
  const raw = error instanceof Error ? error.message : String(error ?? "");
  const message = raw.replace(/^Firebase:\s*/i, "").trim();
  const normalized = message.toLowerCase().replace(/_/g, "-");
  const networkFailure = normalized.includes("failed to fetch") || normalized.includes("cors");
  const bareCode = !message || normalized === code || normalized === "internal" || networkFailure;
  if (!bareCode) return message;
  if (
    networkFailure ||
    ["deadline-exceeded", "unavailable"].includes(code) ||
    ["deadline-exceeded", "unavailable"].includes(normalized)
  ) {
    return SLOW_CONNECTION_TEXT;
  }
  return JOIN_FAILED_TEXT;
}
