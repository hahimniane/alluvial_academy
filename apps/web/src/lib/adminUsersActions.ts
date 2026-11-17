/**
 * Rules for the admin Users side-panel actions (slice B), ported from the
 * Flutter screen (user_management_screen.dart, user_role_service.dart) with
 * the owner's decisions applied. Pure so they can be tested without Firebase;
 * adminUsersActionsData.ts does the writes and calls.
 */

import { displayNameOf, isStudentType, type UserRow } from "./adminUsers.ts";

// ─── Which actions a person gets ───────────────────────────────────────────

export type PanelActions = {
  aiTutor: boolean;
  tontine: boolean;
  zoom: boolean;
  makeAdminTeacher: boolean;
  removeAdminAccess: boolean;
  archive: boolean;
  restore: boolean;
  delete: boolean;
  /** Login section: Show / Hide password + Reset password. */
  studentLogin: boolean;
};

/**
 * U-034 / U-035 with the design's fixes: Make admin-teacher only for ACTIVE
 * teachers (Flutter also offered it on archived ones); access switches for
 * active people only; the Login section for every student, archived too.
 */
export function panelActions(row: UserRow): PanelActions {
  const type = row.userType.toLowerCase();
  const teacher = type === "teacher";
  return {
    aiTutor: row.isActive && (isStudentType(row) || teacher),
    tontine: row.isActive,
    zoom: row.isActive && teacher,
    makeAdminTeacher: row.isActive && teacher && !row.isAdminTeacher,
    removeAdminAccess: row.isAdminTeacher,
    archive: row.isActive,
    restore: !row.isActive,
    delete: true,
    studentLogin: isStudentType(row),
  };
}

/** Actions that would lock the signed-in admin out are refused before any dialog. */
export function selfGuard(row: UserRow, viewerUid: string, action: "archive" | "delete" | "removeAdminAccess"): string | null {
  if (!viewerUid || row.id !== viewerUid) return null;
  if (action === "delete") return "You can't delete your own account.";
  if (action === "archive") return "You can't archive your own account.";
  return "You can't remove your own admin access.";
}

export const firstNameOf = (row: UserRow) => row.firstName.trim() || displayNameOf(row);

// ─── Messages ──────────────────────────────────────────────────────────────

export const switchToast = (label: string, on: boolean, row: UserRow) => `${label} turned ${on ? "on" : "off"} for ${firstNameOf(row)}`;

/** A readable reason from a Firebase / callable error, for the end of a message. */
export function errorReason(error: unknown): string {
  const code = String((error as { code?: unknown })?.code ?? "").replace(/^functions\//, "").replace(/^firestore\//, "");
  const message = String((error as { message?: unknown })?.message ?? "").trim();
  if (code === "permission-denied") return "you don't have permission to do that";
  if (code === "unauthenticated") return "your session ended, sign in again";
  if (code === "unavailable" || code === "deadline-exceeded" || /network|offline|failed to fetch/i.test(message)) {
    return "you appear to be offline, try again when connected";
  }
  if (code === "not-found") return "this account no longer exists";
  if (message && message.toLowerCase() !== code && !/^internal$/i.test(message)) return message;
  return "something went wrong, try again";
}

export const failed = (what: string, error: unknown) => `${what}: ${errorReason(error)}.`;

export function zoomResultMessage(name: string, enabled: boolean, updatedShiftCount: number): string {
  const n = Math.max(0, Math.floor(updatedShiftCount || 0));
  const classes = n === 0 ? "No upcoming classes needed changing." : n === 1 ? "1 upcoming class updated." : `${n} upcoming classes updated.`;
  return `Zoom turned ${enabled ? "on" : "off"} for ${name}. ${classes}`;
}

/** deleteUserAccount reasons, in the admin's words. */
export function deleteErrorMessage(error: unknown, name: string): string {
  const message = String((error as { message?: unknown })?.message ?? "");
  const archived = (error as { archivedFirst?: unknown })?.archivedFirst === true ? " They are archived now; you can restore them." : "";
  if (/own account/i.test(message)) return "You can't delete your own account.";
  if (/must be (deactivated|archived)/i.test(message)) return `${name} must be archived before they can be deleted.`;
  return `${name} could not be deleted: ${errorReason(error)}.${archived}`;
}

export function deleteSuccessMessage(name: string, result: { upcomingClassesDeleted?: number; upcomingClassesUpdated?: number } | null | undefined, deleteClasses: boolean): string {
  const base = `${name} was permanently deleted.`;
  if (!deleteClasses) return base;
  const deleted = Math.max(0, result?.upcomingClassesDeleted ?? 0);
  const left = Math.max(0, result?.upcomingClassesUpdated ?? 0);
  const plural = (n: number) => (n === 1 ? "class" : "classes");
  const parts = [base];
  if (deleted > 0) parts.push(`${deleted} upcoming ${plural(deleted)} deleted.`);
  if (left > 0) parts.push(`Taken off ${left} upcoming group ${plural(left)}.`);
  if (parts.length === 1) parts.push("There were no upcoming classes.");
  return parts.join(" ");
}

export const DELETE_CONFIRM_WORD = "DELETE";
export const deleteConfirmed = (typed: string) => typed.trim() === DELETE_CONFIRM_WORD;

// ─── Reset password (U-038) ────────────────────────────────────────────────

/** The same limits the server enforces; empty = let the server make one. */
export function resetPasswordProblem(password: string): string | null {
  if (password === "") return null;
  if (password.trim() === "") return "Password cannot be only spaces";
  if (password !== password.trim()) return "Password cannot start or end with spaces";
  if (password.length < 6) return "Password must be at least 6 characters";
  if (password.length > 128) return "Password must be 128 characters or less";
  return null;
}

export const joinNames = (names: readonly string[]): string => {
  const list = names.map((n) => n.trim()).filter(Boolean);
  if (list.length <= 1) return list[0] ?? "";
  return `${list.slice(0, -1).join(", ")} and ${list[list.length - 1]}`;
};

// ─── Zoom (U-043, U-044) ───────────────────────────────────────────────────

/** Flutter's two licensed accounts (`_zoomHostAccountOptions`); kept as they are (no Zoom changes). */
export const ZOOM_HOST_ACCOUNTS = ["support@alluwaleducationhub.org", "billing@alluwaleducationhub.org"] as const;

/** Pre-selects the teacher's current host (Flutter always picked the first). */
export function zoomHostDefaults(currentHost: string): { selected: string; custom: string } {
  const current = currentHost.trim();
  const match = ZOOM_HOST_ACCOUNTS.find((a) => a.toLowerCase() === current.toLowerCase());
  if (match) return { selected: match, custom: "" };
  if (current) return { selected: "", custom: current };
  return { selected: ZOOM_HOST_ACCOUNTS[0], custom: "" };
}

/** Typed host wins over the radios, as in Flutter. */
export const chosenZoomHost = (selected: string, custom: string) => custom.trim() || selected;

export type ZoomShift = { studentIds: string[]; studentNames: string[]; category: string; start: Date | null };

/** _loadTeacherStudents: students of the teacher's upcoming teaching classes, name from the class, else the id. */
export function upcomingStudents(shifts: readonly ZoomShift[], now: Date): { id: string; name: string }[] {
  const names = new Map<string, string>();
  for (const shift of shifts) {
    if (shift.category.toLowerCase() !== "teaching") continue;
    if (!shift.start || shift.start.getTime() < now.getTime()) continue;
    shift.studentIds.forEach((raw, i) => {
      const id = raw.trim();
      if (!id) return;
      const name = (shift.studentNames[i] ?? "").trim();
      if (!names.has(id) || (name && names.get(id) === id)) names.set(id, name || id);
    });
  }
  return [...names].map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name));
}

// ─── Archive / restore writes (U-048, U-049) ───────────────────────────────

export function archiveFields<T>(viewer: { uid: string; email: string }, now: T) {
  return {
    is_active: false,
    deactivated_at: now,
    deactivated_by_uid: viewer.uid,
    deactivated_by_email: viewer.email.trim().toLowerCase(),
    updated_at: now,
  };
}

export function restoreFields<T>(viewer: { uid: string; email: string }, now: T, remove: T) {
  return {
    is_active: true,
    activated_at: now,
    activated_by_uid: viewer.uid,
    activated_by_email: viewer.email.trim().toLowerCase(),
    updated_at: now,
    deactivated_at: remove,
    deactivated_by_uid: remove,
    deactivated_by_email: remove,
  };
}

// ─── Recent decisions (DecisionHistoryCard) ────────────────────────────────

export type Decision = { id: string; action: string; actorUid: string; actorName: string; actorKind?: string; at: Date | null; legacy: boolean };

const ACTION_LABELS: Record<string, string> = {
  "user.created": "Created user",
  "user.archived": "Archived user",
  "user.restored": "Restored user",
  "user.deleted": "Permanently deleted user",
  "user.role_changed": "Changed user role",
  "user.guardian_links_changed": "Changed parent or guardian links",
};

export const decisionLabel = (action: string) =>
  ACTION_LABELS[action] ?? (action.replace(/^[a-z]+\./, "").replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase()) || "Decision");

/** DecisionAuditService.documentId. */
export const decisionDocId = (entityType: string, entityId: string) =>
  `${entityType.trim().replace(/[^a-zA-Z0-9_-]/g, "_")}__${entityId.trim().replace(/\//g, "_")}`;

/** EditUserScreen's fallbacks: what the user document itself says happened. */
export function fallbackDecisions(row: UserRow): Decision[] {
  const out: Decision[] = [];
  if (row.createdByUid) out.push({ id: "legacy_user.created", action: "user.created", actorUid: row.createdByUid, actorName: "", at: row.dateAdded, legacy: true });
  if (row.deactivatedByUid) out.push({ id: "legacy_user.archived", action: "user.archived", actorUid: row.deactivatedByUid, actorName: "", at: row.deactivatedAt, legacy: true });
  if (row.activatedByUid) out.push({ id: "legacy_user.restored", action: "user.restored", actorUid: row.activatedByUid, actorName: "", at: row.activatedAt, legacy: true });
  return out;
}

/** _mergeEvents: recorded events, plus fallbacks whose action was never recorded; newest first. */
export function mergeDecisions(recorded: readonly Decision[], fallbacks: readonly Decision[], limit: number): Decision[] {
  const seen = new Set(recorded.map((d) => d.action));
  return [...recorded, ...fallbacks.filter((f) => !seen.has(f.action))]
    .sort((a, b) => (b.at?.getTime() ?? 0) - (a.at?.getTime() ?? 0))
    .slice(0, limit);
}

/** _decisionActorDisplayName: a person's name, never a raw email/phone/service account. */
export function decisionActor(name: string, uid: string, kind = ""): string {
  const technical = `${uid} ${name}`.toLowerCase();
  if (kind.toLowerCase() === "system" || /gserviceaccount\.com|firebase-adminsdk|compute@developer/.test(technical)) return "System";
  const n = name.trim();
  if (n && !/^\+?[0-9][0-9 ()-]{6,}$/.test(n) && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(n)) return n;
  return "";
}
