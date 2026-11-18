/**
 * Edit user (S7), ported from lib/features/user_management/screens/edit_user_screen.dart
 * with the design's fixes:
 *  - the document is the one the row came from (users/{documentId}), never a
 *    lookup by email (U-123, U-124);
 *  - only the fields the admin changed are written, so another admin's change
 *    to a different field is never overwritten, and an older document no
 *    longer logs a false "Changed user role" just for being saved (U-108, U-126);
 *  - "Unsaved changes" turns off again when a field is put back (U-122);
 *  - a name cannot be emptied, "   " included (U-113).
 * Pure so it can be tested without Firestore; editUserData.ts does the write.
 */

import { isViewerRow, typeInfo, type UserRow } from "./adminUsers.ts";

type Data = Record<string, unknown>;

// ─── Values ────────────────────────────────────────────────────────────────

export type EditValues = {
  firstName: string;
  lastName: string;
  title: string;
  countryCode: string;
  phone: string;
  /** `user_type` as stored ("student", "teacher", "parent", "admin", or something else such as "super_admin"). */
  userType: string;
  secondaryRoles: string[];
  aiTutorEnabled: boolean;
  tontineEnabled: boolean;
};

export type EditField = keyof EditValues;

export const EDIT_FIELDS: readonly EditField[] = [
  "firstName",
  "lastName",
  "title",
  "countryCode",
  "phone",
  "userType",
  "secondaryRoles",
  "aiTutorEnabled",
  "tontineEnabled",
];

export const FIELD_LABELS: Record<EditField, string> = {
  firstName: "First name",
  lastName: "Last name",
  title: "Job title",
  countryCode: "Country code",
  phone: "Phone",
  userType: "Main role",
  secondaryRoles: "Also works as",
  aiTutorEnabled: "AI Tutor",
  tontineEnabled: "Tontine",
};

/** The Firestore field each value is stored in. */
const STORED_KEY: Record<EditField, string> = {
  firstName: "first_name",
  lastName: "last_name",
  title: "title",
  countryCode: "country_code",
  phone: "phone_number",
  userType: "user_type",
  secondaryRoles: "secondary_roles",
  aiTutorEnabled: "ai_tutor_enabled",
  tontineEnabled: "tontine_enabled",
};

export function editValuesOf(row: UserRow): EditValues {
  return {
    firstName: row.firstName,
    lastName: row.lastName,
    title: row.title,
    countryCode: row.countryCode,
    phone: row.phone,
    userType: row.userType,
    secondaryRoles: [...row.secondaryRoles],
    aiTutorEnabled: row.aiTutorEnabled,
    tontineEnabled: row.tontineEnabled,
  };
}

const text = (value: unknown): string => {
  if (typeof value === "string") return value;
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  return "";
};

const roleKey = (role: string) => role.trim().toLowerCase();
const roleSet = (roles: readonly string[]) => new Set(roles.map(roleKey).filter(Boolean));

/** Values from a stored document, read the way the list reads them. */
export function editValuesOfDoc(data: Data): EditValues {
  return {
    firstName: text(data.first_name),
    lastName: text(data.last_name),
    title: text(data.title),
    countryCode: text(data.country_code),
    phone: text(data.phone_number),
    userType: text(data.user_type),
    secondaryRoles: Array.isArray(data.secondary_roles) ? data.secondary_roles.map((v) => String(v ?? "").trim()).filter(Boolean) : [],
    aiTutorEnabled: data.ai_tutor_enabled === true,
    tontineEnabled: data.tontine_enabled === true,
  };
}

/** Same value for the person: text ignores spaces at either end, roles ignore case and order. */
export function sameValue<F extends EditField>(field: F, a: EditValues[F], b: EditValues[F]): boolean {
  if (field === "secondaryRoles") {
    const x = roleSet(a as string[]);
    const y = roleSet(b as string[]);
    return x.size === y.size && [...x].every((r) => y.has(r));
  }
  if (field === "userType") return roleKey(a as string) === roleKey(b as string);
  if (typeof a === "string" && typeof b === "string") return a.trim() === b.trim();
  return a === b;
}

// ─── Draft: what the admin touched ─────────────────────────────────────────

/** For each field the admin changed: what they typed, and what was saved when they started (to spot someone else's change). */
export type Draft = { [F in EditField]?: { value: EditValues[F]; seen: EditValues[F] } };

export function formValues(live: EditValues, draft: Draft): EditValues {
  const out = { ...live, secondaryRoles: [...live.secondaryRoles] };
  for (const field of EDIT_FIELDS) {
    const entry = draft[field];
    if (entry) (out as Record<EditField, unknown>)[field] = entry.value;
  }
  return out;
}

/** Records a change. Putting a field back to what is saved removes it, so "Unsaved changes" turns off again. */
export function touch<F extends EditField>(draft: Draft, live: EditValues, field: F, value: EditValues[F]): Draft {
  const next: Draft = { ...draft };
  if (sameValue(field, value, live[field])) {
    delete next[field];
    return next;
  }
  const seen = (draft[field]?.seen ?? live[field]) as EditValues[F];
  (next as Record<EditField, unknown>)[field] = { value, seen };
  return next;
}

/** Fields whose typed value differs from what is saved now. */
export function changedFields(live: EditValues, draft: Draft): EditField[] {
  return EDIT_FIELDS.filter((f) => {
    const entry = draft[f];
    return !!entry && !sameValue(f, entry.value as never, live[f] as never);
  });
}

/** Changed fields that someone else also changed (to something else) since the admin started typing. */
export function conflictingFields(live: EditValues, draft: Draft): EditField[] {
  return changedFields(live, draft).filter((f) => {
    const entry = draft[f]!;
    return !sameValue(f, entry.seen as never, live[f] as never);
  });
}

// ─── Checks ────────────────────────────────────────────────────────────────

export type EditProblems = Partial<Record<"firstName" | "lastName" | "countryCode" | "phone", string>>;

/**
 * Only what the admin changed is checked: a name cannot be emptied, and a
 * changed phone or country code must look like one. Untouched values are
 * never blocked, even odd stored ones (Flutter blocked any save of a person
 * with no last name).
 */
export function editProblems(values: EditValues, changed: readonly EditField[]): EditProblems {
  const out: EditProblems = {};
  const has = (f: EditField) => changed.includes(f);
  if (has("firstName") && values.firstName.trim() === "") out.firstName = "First name is required";
  if (has("lastName") && values.lastName.trim() === "") out.lastName = "Last name is required";
  if (has("countryCode")) {
    const cc = values.countryCode.trim();
    if (cc && !/^\+?\d{1,4}$/.test(cc)) out.countryCode = "Use digits, e.g. +1 or +224";
  }
  if (has("phone")) {
    const phone = values.phone.trim();
    const digits = phone.replace(/\D/g, "");
    if (phone && (!/^[\d\s()+.-]+$/.test(phone) || digits.length < 4 || digits.length > 15)) out.phone = "Enter a phone number (4 to 15 digits)";
  }
  return out;
}

// ─── Roles ─────────────────────────────────────────────────────────────────

export type MainRole = "student" | "teacher" | "parent" | "admin";

export const MAIN_ROLES: readonly { value: MainRole; label: string }[] = [
  { value: "student", label: "Student" },
  { value: "teacher", label: "Teacher" },
  { value: "parent", label: "Parent" },
  { value: "admin", label: "Admin" },
];

export const mainRoleOf = (userType: string): MainRole | null => {
  const t = roleKey(userType);
  return t === "student" || t === "teacher" || t === "parent" || t === "admin" ? t : null;
};

export const isAdminType = (userType: string) => {
  const t = roleKey(userType);
  return t === "admin" || t === "super_admin";
};

/** The role as people read it ("Super admin", "No type", ...). */
export const roleLabelOf = (userType: string): string => {
  const main = mainRoleOf(userType);
  if (main) return MAIN_ROLES.find((r) => r.value === main)!.label;
  return typeInfo({ userType, isAdultStudent: false } as UserRow).label;
};

/** "Also works as" choices: the four roles except the main one (Admin also hidden for a super admin). */
export function secondaryChoices(userType: string): MainRole[] {
  const main = mainRoleOf(userType);
  return MAIN_ROLES.map((r) => r.value).filter((r) => r !== main && !(r === "admin" && isAdminType(userType)));
}

export const hasSecondary = (roles: readonly string[], role: string) => roleSet(roles).has(roleKey(role));

export function withSecondary(roles: readonly string[], role: MainRole, on: boolean): string[] {
  const without = roles.filter((r) => roleKey(r) !== role);
  return on ? [...without, role] : without;
}

/** Picking a main role also takes it off "Also works as" (Flutter rule). */
export function pickMainRole(values: EditValues, role: MainRole): Pick<EditValues, "userType" | "secondaryRoles"> {
  return { userType: role, secondaryRoles: values.secondaryRoles.filter((r) => roleKey(r) !== role) };
}

export type RoleChangeReview = { refusal: string | null; lines: string[] };

/** What a main-role change means, shown before it is saved; the admin's own admin access cannot be removed here. */
export function reviewRoleChange(row: Pick<UserRow, "id" | "isAdminTeacher"> & { uid?: string }, from: string, to: string, viewerUid: string): RoleChangeReview {
  const fromAdmin = isAdminType(from);
  const toAdmin = isAdminType(to);
  if (fromAdmin && !toAdmin && !row.isAdminTeacher && isViewerRow(row, viewerUid)) {
    return { refusal: "You can't remove your own admin access.", lines: [] };
  }
  const lines = [`${roleLabelOf(from)} → ${roleLabelOf(to)}. The main role decides which dashboard they see first.`];
  if (toAdmin && !fromAdmin) lines.push("They get full admin access, including this Users page.");
  if (fromAdmin && !toAdmin) {
    lines.push(
      row.isAdminTeacher
        ? "They stay an admin-teacher, so they keep admin access. Use Remove admin access to end it."
        : "They lose admin access, including this Users page.",
    );
  }
  if (!fromAdmin && !toAdmin && row.isAdminTeacher) lines.push("They stay an admin-teacher, so they keep admin access.");
  return { refusal: null, lines };
}

// ─── The write ─────────────────────────────────────────────────────────────

const ADMIN_LIKE = new Set(["admin", "super_admin", "superadmin", "administrator"]);

/**
 * The update for users/{id}, against the document as it is at save time.
 * Writes only the fields the admin changed that still differ from what is
 * stored. "Also works as" applies the admin's additions and removals to the
 * stored list, so a role someone else added meanwhile is kept. A main-role
 * change also moves a `role` / `userType` field that mirrored the old type
 * (or would keep an admin an admin). Returns null when nothing differs.
 */
export function buildEditPatch<T>(stored: Data, draft: Draft, now: T): { patch: Record<string, unknown>; fields: EditField[] } | null {
  const current = editValuesOfDoc(stored);
  const patch: Record<string, unknown> = {};
  const fields: EditField[] = [];
  const nextType = draft.userType ? draft.userType.value : current.userType;

  for (const field of EDIT_FIELDS) {
    const entry = draft[field];
    if (!entry) continue;
    if (field === "secondaryRoles") {
      const typed = roleSet(entry.value as string[]);
      const seen = roleSet(entry.seen as string[]);
      const added = [...typed].filter((r) => !seen.has(r));
      const removed = new Set([...seen].filter((r) => !typed.has(r)));
      const main = roleKey(nextType);
      const kept = current.secondaryRoles.filter((r) => !removed.has(roleKey(r)) && roleKey(r) !== main);
      const keptKeys = roleSet(kept);
      const next = [...kept, ...added.filter((r) => !keptKeys.has(r) && r !== main)];
      if (!sameValue("secondaryRoles", next, current.secondaryRoles)) {
        patch.secondary_roles = next;
        fields.push(field);
      }
      continue;
    }
    if (sameValue(field, entry.value as never, current[field] as never)) continue;
    const value = typeof entry.value === "string" ? entry.value.trim() : entry.value;
    patch[STORED_KEY[field]] = field === "userType" ? roleKey(value as string) : value;
    fields.push(field);
  }

  // A main role picked while that role is still in the stored "Also works as" list (added elsewhere): drop it there too.
  if (patch.user_type !== undefined && patch.secondary_roles === undefined) {
    const main = roleKey(String(patch.user_type));
    if (current.secondaryRoles.some((r) => roleKey(r) === main)) {
      patch.secondary_roles = current.secondaryRoles.filter((r) => roleKey(r) !== main);
      if (!fields.includes("secondaryRoles")) fields.push("secondaryRoles");
    }
  }

  if (patch.user_type !== undefined) {
    const oldType = roleKey(current.userType);
    const newType = String(patch.user_type);
    for (const key of ["role", "userType"]) {
      const v = stored[key];
      if (typeof v !== "string") continue;
      const k = roleKey(v);
      if (k === oldType || (ADMIN_LIKE.has(k) && !ADMIN_LIKE.has(newType))) patch[key] = newType;
    }
  }

  if (fields.length === 0) return null;
  patch.updated_at = now;
  return { patch, fields };
}

// ─── Messages ──────────────────────────────────────────────────────────────

export const listFields = (fields: readonly EditField[]) => {
  const names = fields.map((f) => FIELD_LABELS[f]);
  if (names.length <= 1) return names[0] ?? "";
  return `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
};

export const conflictNotice = (fields: readonly EditField[]) =>
  `Someone else changed ${listFields(fields)} while you were editing. Saving keeps what you typed there; fields you didn't change stay as they are now.`;

export const SAVED_MESSAGE = "User updated successfully.";
export const NOTHING_TO_SAVE = "Nothing to save: these values are already saved.";

const DATE_TIME_FMT = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" });

/** Decision history time: "Sep 4, 2026, 3:12 PM". */
export const formatDayTime = (date: Date) => DATE_TIME_FMT.format(date);
