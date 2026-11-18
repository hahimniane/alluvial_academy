import {
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  Timestamp,
  where,
  type QueryConstraint,
  type Unsubscribe,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";
import { mapPanelShift, mergeShifts, monthStartOf, type PanelShift } from "@/lib/panelFacts";
import { MAX_SAVED_FILTERS, SAVED_FILTERS_COLLECTION, parseSavedFilters, type SavedFilter } from "@/lib/savedFilters";

/**
 * Reads and calls for the Users page extras (slice E). Every query here is
 * bounded (a limit, or a short date window) and uses an existing index; none
 * runs per row of the list.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

/** How far ahead "has an upcoming class" looks; the generator makes classes up to 10 days ahead. */
export const UPCOMING_WINDOW_DAYS = 14;

/**
 * Students with a class coming up, for "Needs attention": every student of an
 * active weekly schedule (shift_templates.is_active), plus every student of a
 * class that is not cancelled in the next UPCOMING_WINDOW_DAYS. Two reads,
 * bounded by the number of active schedules and by the window. The same rule
 * the server uses (functions/utils/upcoming_classes.js); looking forward only,
 * the live classes are the whole truth (the archive holds old classes).
 */
export async function loadUpcomingStudentIds(now: Date): Promise<Set<string>> {
  const ids = new Set<string>();
  const add = (list: unknown) => {
    if (Array.isArray(list)) for (const v of list) if (typeof v === "string" && v.trim()) ids.add(v.trim());
  };
  const [templates, shifts] = await Promise.all([
    getDocs(query(collection(db, "shift_templates"), where("is_active", "==", true))),
    getDocs(
      query(
        collection(db, "teaching_shifts"),
        where("shift_start", ">=", Timestamp.fromDate(now)),
        where("shift_start", "<", Timestamp.fromDate(new Date(now.getTime() + UPCOMING_WINDOW_DAYS * DAY_MS))),
      ),
    ),
  ]);
  for (const d of templates.docs) add(d.get("student_ids"));
  for (const d of shifts.docs) {
    const status = String(d.get("status") ?? "").toLowerCase();
    if (status === "cancelled") continue;
    add(d.get("student_ids"));
  }
  return ids;
}

// ─── Side panel facts ──────────────────────────────────────────────────────

export const INVOICE_READ_LIMIT = 200;

/** Invoices of a parent (parent_id) or of a student (student_id, or listed in student_ids). */
export async function loadInvoicesFor(personId: string, kind: "parent" | "student"): Promise<{ docs: { id: string; data: Record<string, unknown> }[]; capped: boolean }> {
  const read = (field: string, op: "==" | "array-contains") =>
    getDocs(query(collection(db, "invoices"), where(field, op, personId), limit(INVOICE_READ_LIMIT)));
  const snaps = kind === "parent" ? [await read("parent_id", "==")] : await Promise.all([read("student_id", "=="), read("student_ids", "array-contains")]);
  return {
    docs: snaps.flatMap((s) => s.docs.map((d) => ({ id: d.id, data: d.data() }))),
    capped: snaps.some((s) => s.size >= INVOICE_READ_LIMIT),
  };
}

/** This month's classes of a student so far, from the live and the archived collections (rule: money and attendance read both). */
export async function loadStudentMonthShifts(studentId: string, now: Date): Promise<PanelShift[]> {
  const range: QueryConstraint[] = [
    where("student_ids", "array-contains", studentId),
    where("shift_start", ">=", Timestamp.fromDate(monthStartOf(now))),
    where("shift_start", "<=", Timestamp.fromDate(now)),
    limit(300),
  ];
  const [live, archived] = await Promise.all([
    getDocs(query(collection(db, "teaching_shifts"), ...range)),
    getDocs(query(collection(db, "teaching_shifts_archive"), ...range)),
  ]);
  const map = (docs: typeof live.docs) => docs.map((d) => mapPanelShift(d.id, d.data())).filter((s): s is PanelShift => !!s);
  return mergeShifts(map(live.docs), map(archived.docs));
}

/** The next few classes of a student or a teacher, from a few hours ago (a class in progress counts). */
export async function loadUpcomingShifts(personId: string, kind: "student" | "teacher", now: Date): Promise<PanelShift[]> {
  const from = Timestamp.fromDate(new Date(now.getTime() - 6 * 60 * 60 * 1000));
  const who = kind === "student" ? where("student_ids", "array-contains", personId) : where("teacher_id", "==", personId);
  const snap = await getDocs(query(collection(db, "teaching_shifts"), who, where("shift_start", ">=", from), orderBy("shift_start"), limit(10)));
  return snap.docs.map((d) => mapPanelShift(d.id, d.data())).filter((s): s is PanelShift => !!s);
}

// ─── Saved filters ─────────────────────────────────────────────────────────

const savedRef = (uid: string) => doc(db, SAVED_FILTERS_COLLECTION, uid);

export function listenSavedFilters(uid: string, onList: (list: SavedFilter[]) => void, onError: (e: Error) => void): Unsubscribe {
  return onSnapshot(
    savedRef(uid),
    (snap) => onList(parseSavedFilters(snap.exists() ? snap.data() : null)),
    (e) => onError(e),
  );
}

/**
 * Changes the admin's list in a transaction on the stored copy, so two
 * devices editing at once never drop each other's filters. `change` returns
 * the new list, or a refusal text.
 */
export async function changeSavedFilters(uid: string, change: (current: SavedFilter[]) => SavedFilter[] | string): Promise<void> {
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(savedRef(uid));
    const current = parseSavedFilters(snap.exists() ? snap.data() : null);
    const next = change(current);
    if (typeof next === "string") throw Object.assign(new Error(next), { code: "refused" });
    if (next.length > MAX_SAVED_FILTERS) throw Object.assign(new Error(`You can keep up to ${MAX_SAVED_FILTERS} saved filters.`), { code: "refused" });
    tx.set(savedRef(uid), { filters: next, updated_at: serverTimestamp() });
  });
}

// ─── Login details email ───────────────────────────────────────────────────

export type EmailResult = { sentTo: string[]; failed: string[]; noEmail: string[] };

export async function emailLoginDetails(studentId: string, guardianIds?: string[]): Promise<EmailResult> {
  const call = httpsCallable<{ studentId: string; guardianIds?: string[] }, Partial<EmailResult>>(functions, "sendStudentLoginDetails");
  const res = await call(guardianIds ? { studentId, guardianIds } : { studentId });
  const list = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);
  return { sentTo: list(res.data?.sentTo), failed: list(res.data?.failed), noEmail: list(res.data?.noEmail) };
}
