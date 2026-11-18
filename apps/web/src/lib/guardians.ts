/**
 * Guardians (S8): who is linked to whom, the link pickers and the messages,
 * ported from lib/features/user_management/services/guardian_service.dart and
 * widgets/manage_guardians_dialog.dart with the owner's decisions:
 *  - a student who already has a guardian can get another one (Q11);
 *  - linking goes through the server, like unlinking (Q12);
 *  - both spellings on both sides count: the student's guardian_ids /
 *    guardianIds (and the legacy single guardian_id / parent_id / parentId)
 *    and the parent's children_ids / childrenIds. A pair listed on one side
 *    only is shown, marked, and can be fixed (U-149).
 * Pure; the calls are in editUserData.ts.
 */

import { displayNameOf, isStudentType, matchesUserSearch, phoneDisplay, type UserRow } from "./adminUsers.ts";

/** Where the link is written: on both documents, only on the student's, or only on the parent's. */
export type LinkSide = "both" | "student" | "parent";

export type LinkedPerson = { id: string; row: UserRow | undefined; side: LinkSide; name: string };

const byName = (a: LinkedPerson, b: LinkedPerson) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()) || (a.id < b.id ? -1 : 1);

const nameOf = (row: UserRow | undefined, id: string) => (row ? displayNameOf(row) : id);

/** child id → accounts whose children_ids / childrenIds name them. */
export function parentsByChild(rows: readonly UserRow[]): Map<string, string[]> {
  const out = new Map<string, string[]>();
  for (const r of rows) {
    for (const child of r.childrenIds) {
      const list = out.get(child) ?? [];
      if (!list.includes(r.id)) list.push(r.id);
      out.set(child, list);
    }
  }
  return out;
}

/** A student's guardians: the student's own lists, plus every account whose children list names the student. */
export function guardiansOfStudent(
  student: UserRow,
  rows: readonly UserRow[],
  byId: Map<string, UserRow>,
  index: Map<string, string[]> = parentsByChild(rows),
): LinkedPerson[] {
  const fromStudent = new Set(student.linkedGuardianIds);
  const fromParents = new Set((index.get(student.id) ?? []).filter((id) => id !== student.id));
  const ids = [...new Set([...fromStudent, ...fromParents])];
  return ids
    .map((id) => {
      const row = byId.get(id);
      const side: LinkSide = fromStudent.has(id) && (fromParents.has(id) || !row) ? "both" : fromStudent.has(id) ? "student" : "parent";
      return { id, row, side, name: nameOf(row, id) };
    })
    .sort(byName);
}

/** A parent's students: the parent's children lists, plus every student whose guardian lists name the parent. */
export function studentsOfParent(parent: UserRow, rows: readonly UserRow[], byId: Map<string, UserRow>): LinkedPerson[] {
  const fromParent = new Set(parent.childrenIds);
  const fromStudents = new Set(rows.filter((r) => r.id !== parent.id && r.linkedGuardianIds.includes(parent.id)).map((r) => r.id));
  const ids = [...new Set([...fromParent, ...fromStudents])];
  return ids
    .map((id) => {
      const row = byId.get(id);
      const side: LinkSide = fromParent.has(id) && (fromStudents.has(id) || !row) ? "both" : fromParent.has(id) ? "parent" : "student";
      return { id, row, side, name: nameOf(row, id) };
    })
    .sort(byName);
}

/** The server links only a parent account (user_type parent or guardian), not a secondary-role parent. */
export const isParentAccount = (row: UserRow) => {
  const t = row.userType.trim().toLowerCase();
  return t === "parent" || t === "guardian";
};

export const sideNote = (side: LinkSide, viewedFrom: "student" | "parent"): string => {
  if (side === "both") return "";
  const own = side === viewedFrom;
  return own ? "Linked on this account only" : "Linked on their account only";
};

export type LinkCandidate = { row: UserRow; name: string; detail: string; partial: boolean };

const sortCandidates = (a: LinkCandidate, b: LinkCandidate) =>
  Number(!a.row.isActive) - Number(!b.row.isActive) || a.name.toLowerCase().localeCompare(b.name.toLowerCase()) || (a.row.id < b.row.id ? -1 : 1);

const contactLine = (row: UserRow) => [row.email.trim(), phoneDisplay(row)].filter(Boolean).join(" · ");

/** Parents who can be linked to this student: every parent account not already linked on both sides. */
export function guardianCandidates(student: UserRow, rows: readonly UserRow[], byId: Map<string, UserRow>, query: string): LinkCandidate[] {
  const linked = new Map(guardiansOfStudent(student, rows, byId).map((g) => [g.id, g.side]));
  const q = query.trim();
  return rows
    .filter((r) => r.id !== student.id && isParentAccount(r) && linked.get(r.id) !== "both")
    .filter((r) => !q || matchesUserSearch(r, q))
    .map((r) => ({ row: r, name: displayNameOf(r), detail: contactLine(r), partial: linked.has(r.id) }))
    .sort(sortCandidates);
}

/** Students who can be linked to this parent: every student not already linked on both sides, guardian or not (Q11). */
export function studentCandidates(parent: UserRow, rows: readonly UserRow[], byId: Map<string, UserRow>, query: string): LinkCandidate[] {
  const linked = new Map(studentsOfParent(parent, rows, byId).map((s) => [s.id, s.side]));
  const q = query.trim();
  const index = parentsByChild(rows);
  return rows
    .filter((r) => r.id !== parent.id && isStudentType(r) && linked.get(r.id) !== "both")
    .filter((r) => !q || matchesUserSearch(r, q))
    .map((r) => {
      const guardians = guardiansOfStudent(r, rows, byId, index).map((g) => g.name);
      const parts = [r.studentCode ? `Student ID ${r.studentCode}` : "", guardians.length ? `Guardian: ${guardians.join(", ")}` : "No guardian"];
      return { row: r, name: displayNameOf(r), detail: parts.filter(Boolean).join(" · "), partial: linked.has(r.id) };
    })
    .sort(sortCandidates);
}

/** Subtitle of a linked student (U-145): email · Student ID · Adult student. */
export const studentLine = (row: UserRow) =>
  [row.email.trim(), row.studentCode ? `Student ID: ${row.studentCode}` : "", row.isAdultStudent ? "Adult student" : ""].filter(Boolean).join(" · ");

/** Subtitle of a linked guardian (U-135): email · phone. */
export const guardianLine = (row: UserRow) => contactLine(row);

// ─── Messages ──────────────────────────────────────────────────────────────

export type LinkResult = { alreadyLinked: boolean; repaired: boolean };

export function linkMessage(result: LinkResult, student: string, parent: string): string {
  if (result.alreadyLinked) return `${student} is already linked to ${parent}.`;
  if (result.repaired) return `Fixed the link between ${student} and ${parent}.`;
  return `Linked ${student} to ${parent}.`;
}

/** The server's refusal to leave a minor without a guardian (details.reason, or "minor" in the message as Flutter checks). */
export function isLastGuardianOfMinor(error: unknown): boolean {
  const details = (error as { details?: unknown })?.details;
  if (details && typeof details === "object" && (details as { reason?: unknown }).reason === "last_guardian_minor") return true;
  return /minor/i.test(String((error as { message?: unknown })?.message ?? ""));
}

export const UNLINK_REASON_MAX = 200;
export const UNLINK_SUCCESS = "Guardian unlinked from this student.";
export const UNLINK_STUDENT_SUCCESS = "Student unlinked from this parent.";
export const MINOR_BLOCKED =
  "This is the only guardian of a minor student. Link another guardian first, or mark the student as an adult, before unlinking.";

export const unlinkBody = (guardian: string, student: string) =>
  `${guardian} will no longer be linked to ${student}. They lose access to this student's classes, chat and invoices. Neither account is deleted.`;

export const adultOverrideBody = (student: string, guardian: string) =>
  `${student} has no other valid linked parent. Only continue if an admin has confirmed this student should manage their own account as an adult after removing ${guardian}.`;

export const linkBody = (guardian: string, student: string) =>
  `${guardian} will see ${student}'s classes, chat and invoices. No email is sent.`;
