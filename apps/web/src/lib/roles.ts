/**
 * Every role an account can act as besides student, the way the Flutter app
 * works it out (UserRoleService.getAvailableRoles): the primary user_type,
 * teacher for any admin, admin for a teacher flagged is_admin_teacher, plus
 * secondary_roles.
 */
export function otherRolesOf(data: Record<string, unknown> | undefined): string[] {
  return allRolesOf(data).filter((role) => role !== "student");
}

/**
 * Every role the account holds, in the order the Flutter role switcher lists
 * them (UserRoleService.getAvailableRoles builds a Set in this order).
 */
export function allRolesOf(data: Record<string, unknown> | undefined): string[] {
  if (!data) return [];
  const primary = String(data.user_type ?? data.role ?? "").trim().toLowerCase();
  const roles = new Set<string>();
  if (primary) roles.add(primary);
  if (primary === "admin" || primary === "super_admin") roles.add("teacher");
  if (primary === "teacher" && data.is_admin_teacher === true) roles.add("admin");
  for (const r of Array.isArray(data.secondary_roles) ? data.secondary_roles : []) {
    const t = String(r ?? "").trim().toLowerCase();
    if (t) roles.add(t);
  }
  return [...roles];
}

/**
 * The role the Flutter app opens as (UserRoleService.getActiveRole): the role
 * saved by its switcher when the account still holds it, otherwise user_type.
 */
export function activeRoleOf(data: Record<string, unknown> | undefined, storedRole: string | null): string {
  if (!data) return "";
  const stored = (storedRole ?? "").trim();
  if (stored && allRolesOf(data).includes(stored)) return stored.toLowerCase();
  return String(data.user_type ?? "").trim().toLowerCase();
}

export const ROLE_LABELS: Record<string, string> = { admin: "Admin", super_admin: "Admin", teacher: "Teacher", parent: "Parent", circle_member: "Circle member" };
