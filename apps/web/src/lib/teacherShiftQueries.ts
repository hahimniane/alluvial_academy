import { collection, getDocs, limit as fsLimit, orderBy, query, Timestamp, where, type QueryDocumentSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";

/**
 * Load a teacher's shifts for a window of time.
 *
 * Every teacher screen used to ask for `where(teacher_id == uid) limit(N)` with
 * no ordering. Firestore answers that with an arbitrary N — ordered by document
 * id, which here is `tpl_<template>_<epoch>` and so groups by template rather
 * than by date. A teacher with more shifts than the cap got a scattered subset
 * that could leave out today entirely: Chernor Ahmadu Jalloh had 314 shifts and
 * both of his classes on 8 Sep 2026 fell outside the 200 the page asked for, so
 * My Shifts told him "No Shifts Today" while his phone showed the class running.
 *
 * Asking for a date range and ordering by it means the answer is always the
 * shifts the screen is actually about. Both spellings of the teacher field are
 * queried because the collection carries both, and each has an index paired
 * with shift_start already.
 */
export type ShiftWindow = { daysBack: number; daysForward: number; cap?: number };

export async function fetchTeacherShiftDocs(
  uid: string,
  { daysBack, daysForward, cap = 500 }: ShiftWindow,
): Promise<QueryDocumentSnapshot[]> {
  const day = 24 * 60 * 60 * 1000;
  const now = Date.now();
  const from = Timestamp.fromMillis(now - daysBack * day);
  const to = Timestamp.fromMillis(now + daysForward * day);

  const snapshots = await Promise.all(
    ["teacher_id", "teacherId"].map((field) =>
      getDocs(
        query(
          collection(db, "teaching_shifts"),
          where(field, "==", uid),
          where("shift_start", ">=", from),
          where("shift_start", "<=", to),
          orderBy("shift_start", "asc"),
          fsLimit(cap),
        ),
      ).catch(() => null),
    ),
  );

  const byId = new Map<string, QueryDocumentSnapshot>();
  for (const snap of snapshots) {
    for (const entry of snap?.docs ?? []) byId.set(entry.id, entry);
  }
  return [...byId.values()];
}
