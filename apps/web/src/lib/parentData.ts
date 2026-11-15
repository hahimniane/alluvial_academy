"use client";

/**
 * Firestore reads and callables behind the parent home and child pages, query
 * for query as the Flutter parent screens make them (inventory A, D-blocks).
 * The rules let any signed-in user list classes and any parent read every task
 * (R3, R5), so every read here is scoped to a child id the caller already
 * resolved from the parent's own children list.
 */
import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  where,
  Timestamp,
  type DocumentData,
  type QuerySnapshot,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";
import {
  parseInvoice,
  parsePayment,
  parsePresence,
  parseShift,
  parseTask,
  EMPTY_PRESENCE,
  type AttendancePeriod,
  type ParentInvoice,
  type ParentPayment,
  type ParentShift,
  type ParentTask,
  type RoomPresence,
} from "@/lib/parentHome";

type Unsubscribe = () => void;

function shiftsFrom(snap: QuerySnapshot<DocumentData>) {
  return snap.docs.map((entry) => parseShift(entry.id, entry.data())).filter((s): s is ParentShift => s !== null);
}

/**
 * D3 — ParentService.getStudentShiftsHistory: `student_ids` contains the child,
 * `shift_start < end`, and `>= start` only when a start is given. No category
 * filter. Errors read as "no classes", as in Flutter.
 */
export async function fetchShiftHistory(childId: string, end: Date, start: Date | null): Promise<ParentShift[]> {
  try {
    const clauses = [where("student_ids", "array-contains", childId), where("shift_start", "<", Timestamp.fromDate(end))];
    if (start) clauses.push(where("shift_start", ">=", Timestamp.fromDate(start)));
    const snap = await getDocs(query(collection(db, "teaching_shifts"), ...clauses));
    return shiftsFrom(snap);
  } catch {
    return [];
  }
}

/** ShiftService.getTodayShiftsForStudent: local midnight to midnight. Errors read as none. */
export async function fetchTodayShifts(childId: string, now: Date): Promise<ParentShift[]> {
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  try {
    const snap = await getDocs(
      query(
        collection(db, "teaching_shifts"),
        where("student_ids", "array-contains", childId),
        where("shift_start", ">=", Timestamp.fromDate(start)),
        where("shift_start", "<", Timestamp.fromDate(end)),
      ),
    );
    return shiftsFrom(snap);
  } catch {
    return [];
  }
}

/**
 * ShiftService.getUpcomingShiftsForStudent (7 days). If the composite index is
 * missing it falls back to every class of the child, filtered in memory.
 */
export async function fetchUpcomingShifts(childId: string, now: Date): Promise<ParentShift[]> {
  const limitDate = new Date(now.getTime() + 7 * 86_400_000);
  try {
    const snap = await getDocs(
      query(
        collection(db, "teaching_shifts"),
        where("student_ids", "array-contains", childId),
        where("shift_start", ">=", Timestamp.fromDate(now)),
        where("shift_start", "<", Timestamp.fromDate(limitDate)),
      ),
    );
    return shiftsFrom(snap);
  } catch (error) {
    const missingIndex = (error as { code?: string; message?: string }).code === "failed-precondition" && /index/i.test(String((error as Error).message));
    if (!missingIndex) return [];
    try {
      const snap = await getDocs(query(collection(db, "teaching_shifts"), where("student_ids", "array-contains", childId)));
      return shiftsFrom(snap).filter((s) => s.shiftStart.getTime() >= now.getTime() && s.shiftStart.getTime() < limitDate.getTime());
    } catch {
      return [];
    }
  }
}

/** D4 — ShiftService.getStudentShifts: live, teaching classes only, oldest first. */
export function watchChildShifts(childId: string, onData: (shifts: ParentShift[]) => void, onError: () => void): Unsubscribe {
  return onSnapshot(
    query(collection(db, "teaching_shifts"), where("student_ids", "array-contains", childId)),
    (snap) => onData(shiftsFrom(snap).filter((s) => s.category === "teaching").sort((a, b) => a.shiftStart.getTime() - b.shiftStart.getTime())),
    () => onError(),
  );
}

/** D7 — TaskService.getStudentTasks: live, newest created first (sorted by the caller). */
export function watchChildTasks(childId: string, onData: (tasks: ParentTask[]) => void, onError: () => void): Unsubscribe {
  return onSnapshot(
    query(collection(db, "tasks"), where("assignedTo", "array-contains", childId)),
    (snap) => onData(snap.docs.map((entry) => parseTask(entry.id, entry.data())).filter((t): t is ParentTask => t !== null)),
    () => onError(),
  );
}

/** "Assigned by": `users/{createdBy}` first + last name, cached per page. */
const nameCache = new Map<string, Promise<string | null>>();
export function fetchUserName(uid: string): Promise<string | null> {
  if (!uid) return Promise.resolve(null);
  let pending = nameCache.get(uid);
  if (!pending) {
    pending = getDoc(doc(db, "users", uid))
      .then((snap) => {
        if (!snap.exists()) return null;
        const data = snap.data();
        const name = `${data.first_name ?? ""} ${data.last_name ?? ""}`.trim();
        return name || null;
      })
      .catch(() => null);
    nameCache.set(uid, pending);
  }
  return pending;
}

/** D5 — getStudentAttendanceReport; the `report` envelope, or null on any failure. */
export async function fetchAttendanceReport(childId: string, periodType: AttendancePeriod, forceRefresh: boolean): Promise<Record<string, unknown> | null> {
  try {
    const result = await httpsCallable(functions, "getStudentAttendanceReport")({ studentId: childId, periodType, forceRefresh });
    const envelope = (result.data ?? {}) as Record<string, unknown>;
    const report = envelope.report;
    return report && typeof report === "object" ? (report as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

/** D8 — getRealtimeKitRoomPresence; a failed call is an empty room, as in Flutter. */
export async function fetchRoomPresence(shiftId: string): Promise<RoomPresence> {
  try {
    const result = await httpsCallable(functions, "getRealtimeKitRoomPresence")({ shiftId });
    return parsePresence(result.data);
  } catch {
    return EMPTY_PRESENCE;
  }
}

/** Suspension banner: students on `guardian_ids` with `access_suspended == true`, live. */
export function watchSuspendedChildren(parentId: string, onData: (names: string[]) => void): Unsubscribe {
  return onSnapshot(
    query(collection(db, "users"), where("guardian_ids", "array-contains", parentId), where("access_suspended", "==", true)),
    (snap) =>
      onData(
        snap.docs.map((entry) => {
          const data = entry.data();
          const name = `${String(data.first_name ?? "").trim()} ${String(data.last_name ?? "").trim()}`.trim();
          return name || entry.id;
        }),
      ),
    () => onData([]),
  );
}

/**
 * D6 — the money summary's two listeners: the parent's latest 200 invoices by
 * issue date and up to 500 payments. Emits only once both have answered.
 */
export function watchMoney(
  parentId: string,
  onData: (invoices: ParentInvoice[], payments: ParentPayment[]) => void,
  onError: () => void,
): Unsubscribe {
  let invoices: ParentInvoice[] | null = null;
  let payments: ParentPayment[] | null = null;
  const emit = () => {
    if (invoices && payments) onData(invoices, payments);
  };
  const stopInvoices = onSnapshot(
    query(collection(db, "invoices"), where("parent_id", "==", parentId), orderBy("issued_date", "desc"), limit(200)),
    (snap) => {
      invoices = snap.docs.map((entry) => parseInvoice(entry.id, entry.data()));
      emit();
    },
    () => onError(),
  );
  const stopPayments = onSnapshot(
    query(collection(db, "payments"), where("parent_id", "==", parentId), limit(500)),
    (snap) => {
      payments = snap.docs.map((entry) => parsePayment(entry.id, entry.data()));
      emit();
    },
    () => onError(),
  );
  return () => {
    stopInvoices();
    stopPayments();
  };
}

/**
 * D10 — InvoiceService.getParentInvoices(limit 5): parent_id by due date (5)
 * plus student_id (no limit). An error on the second reads as empty.
 */
export function watchRecentInvoices(
  parentId: string,
  onData: (byParent: ParentInvoice[], byStudent: ParentInvoice[]) => void,
  onError: () => void,
): Unsubscribe {
  let byParent: ParentInvoice[] | null = null;
  let byStudent: ParentInvoice[] | null = null;
  const emit = () => {
    if (byParent && byStudent) onData(byParent, byStudent);
  };
  const stopParent = onSnapshot(
    query(collection(db, "invoices"), where("parent_id", "==", parentId), orderBy("due_date", "desc"), limit(5)),
    (snap) => {
      byParent = snap.docs.map((entry) => parseInvoice(entry.id, entry.data()));
      emit();
    },
    () => onError(),
  );
  const stopStudent = onSnapshot(
    query(collection(db, "invoices"), where("student_id", "==", parentId)),
    (snap) => {
      byStudent = snap.docs.map((entry) => parseInvoice(entry.id, entry.data()));
      emit();
    },
    () => {
      byStudent = [];
      emit();
    },
  );
  return () => {
    stopParent();
    stopStudent();
  };
}

/** D11 — PaymentService.getPaymentHistory(limit 5): newest first. */
export function watchRecentPayments(parentId: string, onData: (payments: ParentPayment[]) => void, onError: () => void): Unsubscribe {
  return onSnapshot(
    query(collection(db, "payments"), where("parent_id", "==", parentId), orderBy("created_at", "desc"), limit(5)),
    (snap) => onData(snap.docs.map((entry) => parsePayment(entry.id, entry.data()))),
    () => onError(),
  );
}

/** A-056: does the invoice behind a payment exist (and may the parent read it)? */
export async function invoiceExists(invoiceId: string): Promise<"found" | "missing" | "refused"> {
  try {
    const snap = await getDoc(doc(db, "invoices", invoiceId));
    return snap.exists() ? "found" : "missing";
  } catch {
    return "refused";
  }
}
