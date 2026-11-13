/**
 * Who a form is for, read from however the form stores it. Mirrors
 * FormAudience in lib/features/forms/utils/form_audience.dart: "Who can see
 * this" writes `allowedRoles` as a list of role keys, but older documents carry
 * the audience as a map, a comma-separated string, under `audience` /
 * `targetRoles` / `roles`, or as a legacy `permissions.role`.
 */
type Data = Record<string, unknown>;

const AUDIENCE_KEYS = ["allowedRoles", "audience", "targetRoles", "roles"] as const;

function roleList(value: unknown): string[] | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "string") {
    return value
      .split(/[,;|]/)
      .map((part) => part.trim())
      .filter(Boolean);
  }
  if (Array.isArray(value)) {
    return value.map((item) => String(item ?? "").trim()).filter(Boolean);
  }
  if (typeof value === "object") {
    const entries = Object.entries(value as Data);
    // {parent: true, teacher: false} names roles by key; {0: "parent"} by value.
    if (entries.every(([, flag]) => typeof flag === "boolean")) {
      return entries
        .filter(([, flag]) => flag === true)
        .map(([key]) => key.trim())
        .filter(Boolean);
    }
    return entries.map(([, item]) => String(item ?? "").trim()).filter(Boolean);
  }
  return null;
}

/** The roles a form names, as stored, or null when it carries no audience. */
export function parseFormAudience(data: Data): string[] | null {
  for (const key of AUDIENCE_KEYS) {
    const roles = roleList(data[key]);
    if (roles && roles.length > 0) return roles;
  }
  const permissions = data.permissions;
  if (permissions && typeof permissions === "object" && !Array.isArray(permissions)) {
    const perms = permissions as Data;
    if (String(perms.type ?? "").trim().toLowerCase() !== "public") {
      const roles = roleList(perms.roles) ?? roleList(perms.role);
      if (roles && roles.length > 0) return roles;
    }
  }
  for (const key of AUDIENCE_KEYS) {
    const roles = roleList(data[key]);
    if (roles) return roles;
  }
  return null;
}

/** A role key in its canonical singular, lower-case form. */
export function normalizeAudienceRole(role: string): string {
  const normalized = role.trim().toLowerCase();
  if (["tutor", "tutors", "teachers", "instructor", "instructors"].includes(normalized)) return "teacher";
  if (["admins", "administrator", "administrators", "super_admin"].includes(normalized)) return "admin";
  if (normalized === "coaches") return "coach";
  if (normalized === "students") return "student";
  if (["parents", "guardian", "guardians", "parent/guardian", "parents/guardians"].includes(normalized)) return "parent";
  return normalized;
}

export function audienceIncludes(roles: string[] | null | undefined, role: string): boolean {
  if (!roles || roles.length === 0) return false;
  const wanted = normalizeAudienceRole(role);
  return roles.some((item) => normalizeAudienceRole(item) === wanted);
}

/**
 * Whether a student sees this form: it is active and its audience includes
 * students. A form nobody aimed at students stays hidden from them.
 */
export function studentCanSeeForm(data: Data): boolean {
  if (data.isActive === false) return false;
  return audienceIncludes(parseFormAudience(data), "student");
}
