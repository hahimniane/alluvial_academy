/**
 * Bulk actions on the admin Users page (F4): which of the selected people an
 * action applies to, why the others are skipped, running one person at a time
 * with a result for each, and the summary. Pure, except `runBulk`, which only
 * calls the function it is given.
 *
 * The signed-in admin is always skipped for actions that change an account.
 */

import { displayNameOf, isStudentType, isViewerRow, type UserRow } from "./adminUsers.ts";

export type BulkKind = "archive" | "restore" | "resetPassword" | "aiTutorOn" | "aiTutorOff" | "export";

export const BULK_LABELS: Record<BulkKind, string> = {
  archive: "Archive",
  restore: "Restore",
  resetPassword: "Reset passwords",
  aiTutorOn: "AI Tutor on",
  aiTutorOff: "AI Tutor off",
  export: "Export",
};

export type Skipped = { id: string; name: string; reason: string };

export type BulkPlan<T extends UserRow = UserRow> = { kind: BulkKind; targets: T[]; skipped: Skipped[] };

const SELF = "That's you";

/** Why this person is left out of the action, or null when it applies to them. */
export function skipReason(kind: BulkKind, row: UserRow, viewerUid: string): string | null {
  if (kind === "export") return null;
  if (isViewerRow(row, viewerUid)) return SELF;
  const type = row.userType.trim().toLowerCase();
  switch (kind) {
    case "archive":
      return row.isActive ? null : "Already archived";
    case "restore":
      return row.isActive ? "Not archived" : null;
    case "resetPassword":
      return isStudentType(row) ? null : "Not a student";
    case "aiTutorOn":
    case "aiTutorOff": {
      if (!(isStudentType(row) || type === "teacher")) return "AI Tutor is for students and teachers";
      if (!row.isActive) return "Archived";
      const on = kind === "aiTutorOn";
      return row.aiTutorEnabled === on ? `AI Tutor already ${on ? "on" : "off"}` : null;
    }
  }
}

/** Splits the selection (in the order given) into the people the action applies to and the skipped ones. */
export function planBulk<T extends UserRow>(kind: BulkKind, selected: readonly T[], viewerUid: string): BulkPlan<T> {
  const targets: T[] = [];
  const skipped: Skipped[] = [];
  for (const row of selected) {
    const reason = skipReason(kind, row, viewerUid);
    if (reason) skipped.push({ id: row.id, name: displayNameOf(row), reason });
    else targets.push(row);
  }
  return { kind, targets, skipped };
}

export type BulkResult<V = unknown> = { id: string; name: string; ok: true; value: V } | { id: string; name: string; ok: false; error: string };

/**
 * Runs `work` for each target, one after another (never two at once), and
 * keeps going after a failure. `onProgress` is told after each person.
 * `shouldStop` is checked between people.
 */
export async function runBulk<T extends UserRow, V>(
  targets: readonly T[],
  work: (row: T) => Promise<V>,
  describeError: (error: unknown) => string,
  onProgress?: (done: number, total: number, last: BulkResult<V>) => void,
  shouldStop?: () => boolean,
): Promise<BulkResult<V>[]> {
  const results: BulkResult<V>[] = [];
  for (const row of targets) {
    if (shouldStop?.()) break;
    const name = displayNameOf(row);
    let result: BulkResult<V>;
    try {
      result = { id: row.id, name, ok: true, value: await work(row) };
    } catch (error) {
      result = { id: row.id, name, ok: false, error: describeError(error) };
    }
    results.push(result);
    onProgress?.(results.length, targets.length, result);
  }
  return results;
}

const people = (n: number) => (n === 1 ? "1 person" : `${n} people`);

/** "Archive 4 people?" and what is left out, for the confirm dialog. */
export function confirmText(plan: BulkPlan): { title: string; skippedLine: string } {
  const n = plan.targets.length;
  const titles: Record<BulkKind, string> = {
    archive: `Archive ${people(n)}?`,
    restore: `Restore ${people(n)}?`,
    resetPassword: `Reset ${n === 1 ? "1 student's password" : `${n} students' passwords`}?`,
    aiTutorOn: `Turn AI Tutor on for ${people(n)}?`,
    aiTutorOff: `Turn AI Tutor off for ${people(n)}?`,
    export: `Export ${people(n)}?`,
  };
  const s = plan.skipped.length;
  return { title: titles[plan.kind], skippedLine: s === 0 ? "" : `${people(s)} ${s === 1 ? "is" : "are"} left out:` };
}

/** The line at the top of the results. */
export function resultSummary(kind: BulkKind, results: readonly BulkResult[], skipped: number, stoppedEarly: boolean): string {
  const ok = results.filter((r) => r.ok).length;
  const bad = results.length - ok;
  const verb: Record<BulkKind, string> = {
    archive: "archived",
    restore: "restored",
    resetPassword: "given a new password",
    aiTutorOn: "turned AI Tutor on",
    aiTutorOff: "turned AI Tutor off",
    export: "exported",
  };
  const parts = [`${people(ok)} ${verb[kind]}.`];
  if (bad > 0) parts.push(`${bad} failed.`);
  if (skipped > 0) parts.push(`${skipped} left out.`);
  if (stoppedEarly) parts.push("Stopped before the end.");
  return parts.join(" ");
}

/** The selection kept to the people still shown (a filter change never leaves hidden people selected). */
export function pruneSelection(selected: ReadonlySet<string>, shownIds: readonly string[]): Set<string> {
  const shown = new Set(shownIds);
  const next = new Set<string>();
  for (const id of selected) if (shown.has(id)) next.add(id);
  return next.size === selected.size ? (selected as Set<string>) : next;
}

/** Header checkbox: all shown selected, some, or none. */
export function selectAllState(selected: ReadonlySet<string>, shownIds: readonly string[]): "all" | "some" | "none" {
  if (shownIds.length === 0) return "none";
  let n = 0;
  for (const id of shownIds) if (selected.has(id)) n += 1;
  if (n === 0) return "none";
  return n === shownIds.length ? "all" : "some";
}
