import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";

/** A weekly schedule the move would change. */
export type MoveSchedule = {
  id: string;
  selected: boolean;
  teacherName: string;
  studentNames: string[];
  title: string;
  zone: string;
  before: string;
  after: string;
  /** Pushed over midnight, so the class lands on a different weekday. */
  dayChanges: boolean;
  upcoming: number;
  tooSoon: number;
  next: string | null;
};

/** A class that is not part of a weekly schedule. */
export type MoveSingle = {
  id: string;
  selected: boolean;
  tooSoon: boolean;
  teacherName: string;
  studentNames: string[];
  title: string;
  before: string;
  after: string;
};

export type MoveCollision = { who: string; moved: string; other: string };

export type MovePlan = {
  minutes: number;
  schedules: MoveSchedule[];
  singles: MoveSingle[];
  movingCount: number;
  teacherConflicts: MoveCollision[];
  studentOverlaps: MoveCollision[];
};

export type MoveResult = {
  moveId?: string;
  label?: string;
  schedules: number;
  classesRebuilt: number;
  classesMovedInPlace: number;
  skippedConflicts: number;
};

export type MoveRecord = {
  id: string;
  label: string;
  minutes: number;
  byName: string;
  at: string | null;
  schedules: number;
  singles: number;
  undoneAt: string | null;
};

export type MoveScope = { teacherId: string | null; studentId: string | null; minutes: number };
export type MovePick = { templateIds: string[]; shiftIds: string[] };

const callMove = <T,>(data: Record<string, unknown>) =>
  httpsCallable(functions, "moveClassTimes")(data).then((res) => res.data as T);

const scopeData = (scope: MoveScope, pick: MovePick | null) => ({
  teacher_id: scope.teacherId,
  student_id: scope.studentId,
  minutes: scope.minutes,
  ...(pick ? { template_ids: pick.templateIds, shift_ids: pick.shiftIds } : {}),
});

export const previewMove = (scope: MoveScope, pick: MovePick | null) =>
  callMove<MovePlan>({ action: "preview", ...scopeData(scope, pick) });

export const applyMove = (scope: MoveScope, pick: MovePick) =>
  callMove<MoveResult>({ action: "apply", ...scopeData(scope, pick) });

export const listMoves = () => callMove<{ moves: MoveRecord[] }>({ action: "list" }).then((r) => r.moves);

export const undoMove = (moveId: string) => callMove<MoveResult>({ action: "undo", move_id: moveId });

/** "1 hour earlier", "30 minutes later", "1 hour 30 minutes earlier". */
export function describeMinutes(minutes: number): string {
  const abs = Math.abs(minutes);
  const h = Math.floor(abs / 60);
  const m = abs % 60;
  const parts = [h ? `${h} hour${h === 1 ? "" : "s"}` : "", m ? `${m} minutes` : ""].filter(Boolean);
  return `${parts.join(" ")} ${minutes < 0 ? "earlier" : "later"}`;
}

export function moveErrorMessage(err: unknown, fallback: string): string {
  const message = err instanceof Error ? err.message : "";
  return message && !/^internal$/i.test(message) ? message : fallback;
}
