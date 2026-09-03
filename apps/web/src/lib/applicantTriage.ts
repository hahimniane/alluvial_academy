/**
 * Triage for the matched-applicants list: what setup a match still needs, and
 * how the list is searched, sorted and grouped.
 *
 * A match is not finished when a teacher accepts it. Three things have to
 * happen before anyone can teach, in this order, because each depends on the
 * one before it:
 *
 *   1. the student gets a login              (metadata.studentUserId)
 *   2. their classes get put on the calendar (a teaching_shift for that student)
 *   3. a parent is linked to the account     (parentInviteStatus / guardianId)
 *
 * Until this, the only way to know where a match had stalled was to open it.
 */

export type SetupStage = "needs-account" | "needs-schedule" | "needs-parent" | "ready";

export type SetupState = {
  hasAccount: boolean;
  hasSchedule: boolean;
  hasParent: boolean;
  stage: SetupStage;
  /** What to do next, as a sentence for the card. */
  nextAction: string;
};

export type TriageApplicant = {
  id: string;
  studentName: string;
  parentName: string;
  programTitle: string;
  teacherName: string;
  submittedAt: Date | null;
  matchedAt: Date | null;
  studentUserId: string;
  parentLinked: boolean;
};

const NEXT_ACTION: Record<SetupStage, string> = {
  "needs-account": "Next: create account",
  "needs-schedule": "Next: finalize schedule",
  "needs-parent": "Next: invite parent",
  ready: "Ready to teach",
};

/**
 * `hasSchedule` is passed in rather than read off the applicant: a
 * teaching_shift carries no enrollment id, so the only join available is the
 * student's uid, and that is one query for the whole list rather than one per
 * card.
 */
export const setupFor = (
  applicant: Pick<TriageApplicant, "studentUserId" | "parentLinked">,
  hasSchedule: boolean,
): SetupState => {
  const hasAccount = applicant.studentUserId.trim().length > 0;
  // No account means no student to put on a shift, so a schedule cannot be
  // trusted even if one were somehow reported.
  const scheduled = hasAccount && hasSchedule;
  const hasParent = applicant.parentLinked;

  const stage: SetupStage = !hasAccount
    ? "needs-account"
    : !scheduled
      ? "needs-schedule"
      : !hasParent
        ? "needs-parent"
        : "ready";

  return { hasAccount, hasSchedule: scheduled, hasParent, stage, nextAction: NEXT_ACTION[stage] };
};

/* ------------------------------------------------------------- searching -- */

export const matchesSearch = (applicant: TriageApplicant, query: string): boolean => {
  const needle = query.trim().toLowerCase();
  if (!needle) return true;
  return [applicant.studentName, applicant.parentName, applicant.teacherName, applicant.programTitle]
    .some((field) => field.toLowerCase().includes(needle));
};

/* -------------------------------------------------------------- sorting -- */

export type SortId =
  | "recently-matched"
  | "longest-waiting"
  | "student-az"
  | "teacher-az"
  | "newest"
  | "oldest";

export type SortOption = { id: SortId; label: string };

export const MATCHED_SORTS: readonly SortOption[] = [
  { id: "recently-matched", label: "Recently matched" },
  { id: "longest-waiting", label: "Longest waiting" },
  { id: "student-az", label: "Student A–Z" },
  { id: "teacher-az", label: "Teacher A–Z" },
] as const;

export const DEFAULT_SORTS: readonly SortOption[] = [
  { id: "newest", label: "Newest first" },
  { id: "oldest", label: "Oldest first" },
  { id: "student-az", label: "Student A–Z" },
] as const;

/** Missing dates sort last, whichever direction is asked for. */
const byDate = (a: Date | null, b: Date | null, newestFirst: boolean): number => {
  if (!a && !b) return 0;
  if (!a) return 1;
  if (!b) return -1;
  return newestFirst ? b.getTime() - a.getTime() : a.getTime() - b.getTime();
};

const byName = (a: string, b: string) => a.localeCompare(b, "en", { sensitivity: "base" });

export const sortApplicants = <T extends TriageApplicant>(applicants: T[], sort: SortId): T[] => {
  const sorted = [...applicants];
  switch (sort) {
    case "recently-matched":
      return sorted.sort((a, b) => byDate(a.matchedAt, b.matchedAt, true));
    case "longest-waiting":
      return sorted.sort((a, b) => byDate(a.matchedAt, b.matchedAt, false));
    case "student-az":
      return sorted.sort((a, b) => byName(a.studentName, b.studentName));
    case "teacher-az":
      return sorted.sort((a, b) => byName(a.teacherName, b.teacherName) || byName(a.studentName, b.studentName));
    case "newest":
      return sorted.sort((a, b) => byDate(a.submittedAt, b.submittedAt, true));
    case "oldest":
      return sorted.sort((a, b) => byDate(a.submittedAt, b.submittedAt, false));
    default:
      return sorted;
  }
};

/* ------------------------------------------------------------- grouping -- */

export type TeacherGroup<T> = { teacher: string; applicants: T[] };

/** Groups in the order the list already has, so the chosen sort still shows. */
export const groupByTeacher = <T extends TriageApplicant>(applicants: T[]): TeacherGroup<T>[] => {
  const groups = new Map<string, T[]>();
  for (const applicant of applicants) {
    const teacher = applicant.teacherName.trim() || "Unassigned";
    const bucket = groups.get(teacher);
    if (bucket) bucket.push(applicant);
    else groups.set(teacher, [applicant]);
  }
  return [...groups].map(([teacher, list]) => ({ teacher, applicants: list }));
};

/* --------------------------------------------------------------- stages -- */

export type StageFilter = SetupStage | "all";

export const STAGE_FILTERS: readonly { id: StageFilter; label: string }[] = [
  { id: "all", label: "All" },
  { id: "needs-account", label: "Needs account" },
  { id: "needs-schedule", label: "Needs schedule" },
  { id: "needs-parent", label: "Needs parent" },
  { id: "ready", label: "Ready to teach" },
] as const;

export const countByStage = (stages: SetupStage[]): Record<StageFilter, number> => {
  const counts: Record<StageFilter, number> = {
    all: stages.length,
    "needs-account": 0,
    "needs-schedule": 0,
    "needs-parent": 0,
    ready: 0,
  };
  for (const stage of stages) counts[stage] += 1;
  return counts;
};

/* ---------------------------------------------------------------- aging -- */

/** Whole days since the match. Null when the match has no date. */
export const daysWaiting = (matchedAt: Date | null, now: Date = new Date()): number | null => {
  if (!matchedAt) return null;
  const ms = now.getTime() - matchedAt.getTime();
  if (ms < 0) return 0;
  return Math.floor(ms / 86_400_000);
};

/** A match sitting unfinished for a week is the thing worth flagging. */
export const STALE_MATCH_DAYS = 7;

export const isStale = (matchedAt: Date | null, stage: SetupStage, now?: Date): boolean => {
  if (stage === "ready") return false;
  const days = daysWaiting(matchedAt, now);
  return days !== null && days >= STALE_MATCH_DAYS;
};
