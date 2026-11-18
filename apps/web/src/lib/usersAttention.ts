/**
 * "Needs attention" on the admin Users page (F1): who is missing something an
 * admin should fix. Pure, so the counts can be tested and compared with a
 * direct database count.
 *
 * Everything is derived from the Users page's one live users list, except
 * "no upcoming class", which needs one bounded read of the classes (see
 * usersExtrasData.loadUpcomingStudentIds) and is left out until it arrives.
 *
 * Only active accounts are listed (an archived person needs nothing), and an
 * account folded into another one (`merged_into`) is ignored.
 */

import { displayNameOf, isNeverLoggedIn, isStudentType, type UserRow } from "./adminUsers.ts";
import { guardiansOfStudent, parentsByChild } from "./guardians.ts";
import { storedPhoneForms } from "./phoneNumbers.ts";
import { normalizeEmail, personNameKeys, type MatchReason } from "./userDuplicates.ts";

const DAY_MS = 24 * 60 * 60 * 1000;

/** Days after the account was added before "never logged in" counts. */
export const NEVER_LOGGED_IN_DAYS = 7;

/** The school's own student sign-in addresses: unique by construction, never a duplicate signal. */
const STUDENT_ALIAS_DOMAIN = "@alluwaleducationhub.org";

export type DuplicateOther = { id: string; name: string; reasons: MatchReason[] };

export type AttentionReason =
  /** A minor with no guardian linked on either side; `dangling` when the only links point at accounts that no longer exist. */
  | { kind: "noGuardian"; dangling: boolean }
  /** A teacher whose own hourly rate is missing (`zero` false) or $0 (`zero` true). */
  | { kind: "noRate"; zero: boolean }
  /** A student with no weekly schedule and no class in the look-ahead window. */
  | { kind: "noUpcomingClass" }
  /** Never signed in, `days` after the account was added (at least NEVER_LOGGED_IN_DAYS). */
  | { kind: "neverLoggedIn"; days: number }
  /** Shares a name, email or phone with someone who is not their own family. */
  | { kind: "duplicate"; others: DuplicateOther[] };

export type AttentionKind = AttentionReason["kind"];

export const ATTENTION_KINDS: readonly AttentionKind[] = ["noGuardian", "noRate", "noUpcomingClass", "neverLoggedIn", "duplicate"];

export const ATTENTION_LABELS: Record<AttentionKind, string> = {
  noGuardian: "No guardian",
  noRate: "No hourly rate",
  noUpcomingClass: "No upcoming class",
  neverLoggedIn: "Never logged in",
  duplicate: "Possible duplicate",
};

export type AttentionInput = {
  rows: readonly UserRow[];
  /**
   * Students with a class coming up (an active weekly schedule, or a class in
   * the look-ahead window). null while that read is pending or failed: the
   * "no upcoming class" reason is then left out, never guessed.
   */
  upcomingStudentIds: ReadonlySet<string> | null;
  now: Date;
};

const isActivePerson = (row: UserRow) => row.isActive && !row.mergedInto;
const isTeacher = (row: UserRow) => row.userType.trim().toLowerCase() === "teacher";

/** Who is linked to whom, both sides (the panel's guardian rule), for the duplicate family exclusion. */
function familyOf(rows: readonly UserRow[], byId: Map<string, UserRow>, childIndex: Map<string, string[]>) {
  /** person id → ids of their own guardians / children / siblings. */
  const family = new Map<string, Set<string>>();
  const link = (a: string, b: string) => {
    if (a === b) return;
    (family.get(a) ?? family.set(a, new Set()).get(a)!).add(b);
    (family.get(b) ?? family.set(b, new Set()).get(b)!).add(a);
  };
  const childrenOf = new Map<string, string[]>();
  for (const row of rows) {
    if (!isStudentType(row)) continue;
    for (const g of guardiansOfStudent(row, rows, byId, childIndex)) {
      link(row.id, g.id);
      const list = childrenOf.get(g.id) ?? [];
      list.push(row.id);
      childrenOf.set(g.id, list);
    }
  }
  // Brothers and sisters share a guardian's phone and email all the time.
  for (const kids of childrenOf.values()) for (const a of kids) for (const b of kids) link(a, b);
  return family;
}

const emailKeys = (row: UserRow): string[] =>
  [...new Set([normalizeEmail(row.email), normalizeEmail(row.otherEmail)])].filter((e) => e && e.includes("@") && !e.endsWith(STUDENT_ALIAS_DOMAIN));

/**
 * Possible duplicates: the same normalised name (either order), the same email
 * (either field) or the same phone (any stored shape), between two active
 * accounts that are not each other's guardian, child or sibling.
 */
export function findPossibleDuplicates(rows: readonly UserRow[], byId: Map<string, UserRow> = new Map(rows.map((r) => [r.id, r]))): Map<string, DuplicateOther[]> {
  const people = rows.filter(isActivePerson);
  const childIndex = parentsByChild(rows);
  const family = familyOf(rows, byId, childIndex);
  const buckets: Record<MatchReason, Map<string, string[]>> = { name: new Map(), email: new Map(), phone: new Map() };
  const put = (reason: MatchReason, key: string, id: string) => {
    if (!key) return;
    const list = buckets[reason].get(key);
    if (!list) buckets[reason].set(key, [id]);
    else if (!list.includes(id)) list.push(id);
  };
  for (const p of people) {
    for (const key of personNameKeys(p.firstName, p.lastName)) put("name", key, p.id);
    for (const key of emailKeys(p)) put("email", key, p.id);
    for (const key of storedPhoneForms(p.phone, p.countryCode)) put("phone", key, p.id);
  }
  const pairs = new Map<string, Map<string, Set<MatchReason>>>();
  for (const reason of ["email", "phone", "name"] as MatchReason[]) {
    for (const ids of buckets[reason].values()) {
      if (ids.length < 2) continue;
      for (const a of ids) {
        for (const b of ids) {
          if (a === b || family.get(a)?.has(b)) continue;
          const mine = pairs.get(a) ?? pairs.set(a, new Map()).get(a)!;
          (mine.get(b) ?? mine.set(b, new Set()).get(b)!).add(reason);
        }
      }
    }
  }
  const out = new Map<string, DuplicateOther[]>();
  for (const [id, others] of pairs) {
    out.set(
      id,
      [...others]
        .map(([otherId, reasons]) => {
          const other = byId.get(otherId);
          return {
            id: otherId,
            name: other ? displayNameOf(other) : otherId,
            reasons: (["email", "phone", "name"] as MatchReason[]).filter((r) => reasons.has(r)),
          };
        })
        .sort((x, y) => x.name.localeCompare(y.name) || (x.id < y.id ? -1 : 1)),
    );
  }
  return out;
}

/** Every active person who needs something, with every reason that applies. */
export function needsAttention({ rows, upcomingStudentIds, now }: AttentionInput): Map<string, AttentionReason[]> {
  const byId = new Map(rows.map((r) => [r.id, r]));
  const childIndex = parentsByChild(rows);
  const duplicates = findPossibleDuplicates(rows, byId);
  const out = new Map<string, AttentionReason[]>();
  for (const row of rows) {
    if (!isActivePerson(row)) continue;
    const reasons: AttentionReason[] = [];
    const student = isStudentType(row);
    if (student && !row.isAdultStudent) {
      const guardians = guardiansOfStudent(row, rows, byId, childIndex);
      const real = guardians.filter((g) => g.row);
      if (real.length === 0) reasons.push({ kind: "noGuardian", dangling: guardians.length > 0 });
    }
    if (isTeacher(row) && !(row.hourlyRate !== null && row.hourlyRate > 0)) {
      reasons.push({ kind: "noRate", zero: row.hourlyRate !== null });
    }
    if (student && upcomingStudentIds && !upcomingStudentIds.has(row.id)) reasons.push({ kind: "noUpcomingClass" });
    if (isNeverLoggedIn(row) && row.dateAdded) {
      const days = Math.floor((now.getTime() - row.dateAdded.getTime()) / DAY_MS);
      if (days >= NEVER_LOGGED_IN_DAYS) reasons.push({ kind: "neverLoggedIn", days });
    }
    const dup = duplicates.get(row.id);
    if (dup && dup.length > 0) reasons.push({ kind: "duplicate", others: dup });
    if (reasons.length > 0) out.set(row.id, reasons);
  }
  return out;
}

export type AttentionCounts = Record<AttentionKind, number> & { people: number };

/** People per reason (a person with two reasons counts in both) and people in total. */
export function attentionCounts(map: ReadonlyMap<string, readonly AttentionReason[]>): AttentionCounts {
  const counts: AttentionCounts = { noGuardian: 0, noRate: 0, noUpcomingClass: 0, neverLoggedIn: 0, duplicate: 0, people: map.size };
  for (const reasons of map.values()) for (const kind of new Set(reasons.map((r) => r.kind))) counts[kind] += 1;
  return counts;
}

/** The rows of the tab: optionally one reason only, most reasons first, then name. */
export function attentionList<T extends UserRow>(
  rows: readonly T[],
  map: ReadonlyMap<string, readonly AttentionReason[]>,
  only: AttentionKind | null,
): { row: T; reasons: readonly AttentionReason[] }[] {
  const out: { row: T; reasons: readonly AttentionReason[] }[] = [];
  for (const row of rows) {
    const reasons = map.get(row.id);
    if (!reasons) continue;
    if (only && !reasons.some((r) => r.kind === only)) continue;
    out.push({ row, reasons });
  }
  return out.sort(
    (a, b) =>
      b.reasons.length - a.reasons.length ||
      displayNameOf(a.row).toLocaleLowerCase().localeCompare(displayNameOf(b.row).toLocaleLowerCase()) ||
      (a.row.id < b.row.id ? -1 : 1),
  );
}

const reasonWords = (reasons: readonly MatchReason[]) =>
  reasons.map((r) => (r === "email" ? "email" : r === "phone" ? "phone" : "name")).join(" and ");

/** One line saying why, for the row. */
export function reasonText(reason: AttentionReason): string {
  switch (reason.kind) {
    case "noGuardian":
      return reason.dangling ? "Minor whose linked parent account no longer exists" : "Minor with no parent or guardian linked";
    case "noRate":
      return reason.zero ? "Hourly rate is $0. Set it in System Settings → Wage Management" : "No hourly rate. Set it in System Settings → Wage Management";
    case "noUpcomingClass":
      return "No weekly schedule and no class in the next 14 days";
    case "neverLoggedIn":
      return `Never logged in, added ${reason.days} days ago`;
    case "duplicate": {
      const [first, ...rest] = reason.others;
      if (!first) return "Possible duplicate";
      const more = rest.length > 0 ? ` and ${rest.length} more` : "";
      return `Same ${reasonWords(first.reasons)} as ${first.name}${more}`;
    }
  }
}
