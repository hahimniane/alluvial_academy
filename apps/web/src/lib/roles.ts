/**
 * Every role an account can act as besides student, the way the Flutter app
 * works it out (UserRoleService.getAvailableRoles): the primary user_type,
 * teacher for any admin, admin for a teacher flagged is_admin_teacher, plus
 * secondary_roles.
 */
export function otherRolesOf(data: Record<string, unknown> | undefined): string[] {
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
  roles.delete("student");
  return [...roles];
}

export const ROLE_LABELS: Record<string, string> = { admin: "Admin", super_admin: "Admin", teacher: "Teacher", parent: "Parent", circle_member: "Circle member" };
