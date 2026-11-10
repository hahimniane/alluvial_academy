/**
 * A leader's job title to show under their name in chat, mirroring the
 * Flutter app (ChatUser.leaderTitleFor). Only admin user types show a title,
 * and only one that says more than the role itself ("Admin" /
 * "Administrator", any case). Returns null when the role label should show.
 */
const LEADER_ROLES = new Set(["admin", "super_admin", "ceo", "founder"]);

export function leaderTitle(role: unknown, title: unknown): string | null {
  const normalizedRole = typeof role === "string" ? role.trim().toLowerCase() : "";
  if (!LEADER_ROLES.has(normalizedRole)) return null;
  const trimmed = typeof title === "string" ? title.trim() : "";
  if (!trimmed) return null;
  const lower = trimmed.toLowerCase();
  if (lower === "admin" || lower === "administrator") return null;
  return trimmed;
}
