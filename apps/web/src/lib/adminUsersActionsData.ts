import {
  collection,
  deleteField,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  Timestamp,
  updateDoc,
  where,
  type Unsubscribe,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { auth, db, functions } from "@/lib/firebase";
import { archiveFields, decisionDocId, restoreFields, type Decision, type ZoomShift } from "@/lib/adminUsersActions";

/**
 * Writes and calls behind the Users side-panel actions. Every write goes to
 * users/{documentId} — never a lookup by email (U-053).
 */

const userRef = (id: string) => doc(db, "users", id);

function viewer(): { uid: string; email: string } {
  const user = auth.currentUser;
  if (!user) throw Object.assign(new Error("Not signed in"), { code: "unauthenticated" });
  return { uid: user.uid, email: user.email ?? "" };
}

/** AI Tutor / Tontine (U-041, U-042). */
export async function setUserSwitch(id: string, field: "ai_tutor_enabled" | "tontine_enabled", on: boolean): Promise<void> {
  viewer();
  await updateDoc(userRef(id), { [field]: on, updated_at: serverTimestamp() });
}

/** Make admin-teacher / Remove admin access (U-046, U-047). Promoting re-checks that the person is still a teacher. */
export async function setAdminTeacher(id: string, on: boolean): Promise<void> {
  viewer();
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(userRef(id));
    if (!snap.exists()) throw Object.assign(new Error("This account no longer exists"), { code: "not-found" });
    if (on && String(snap.get("user_type") ?? "").toLowerCase() !== "teacher") {
      throw new Error("only teachers can be made admin-teachers");
    }
    tx.update(userRef(id), { is_admin_teacher: on, updated_at: serverTimestamp() });
  });
}

export async function archiveUser(id: string): Promise<void> {
  await updateDoc(userRef(id), archiveFields(viewer(), serverTimestamp()));
}

export async function restoreUser(id: string): Promise<void> {
  await updateDoc(userRef(id), restoreFields(viewer(), serverTimestamp(), deleteField()));
}

/** The teacher's classes from now on (U-044), for the "only some students" list. Uses the teacher_id + shift_start index. */
export async function loadTeacherUpcomingShifts(teacherId: string): Promise<ZoomShift[]> {
  const snap = await getDocs(
    query(collection(db, "teaching_shifts"), where("teacher_id", "==", teacherId), where("shift_start", ">=", Timestamp.now())),
  );
  return snap.docs.map((d) => {
    const data = d.data();
    const start = data.shift_start instanceof Timestamp ? data.shift_start.toDate() : null;
    const list = (v: unknown) => (Array.isArray(v) ? v.map((x) => (x === null || x === undefined ? "" : String(x))) : []);
    return {
      studentIds: list(data.student_ids),
      studentNames: list(data.student_names),
      category: String(data.category ?? data.shift_category ?? "teaching"),
      start,
    };
  });
}

export async function setTeacherZoom(input: { teacherId: string; enabled: boolean; zoomHostAccount?: string; studentIds?: string[] }): Promise<{ updatedShiftCount: number }> {
  const call = httpsCallable<typeof input, { updatedShiftCount?: number }>(functions, "setTeacherZoomEnabled");
  const res = await call(input);
  return { updatedShiftCount: Number(res.data?.updatedShiftCount ?? 0) };
}

export type ResetResult = { newPassword: string; studentCode: string; emailSent: boolean; emailedTo: string[] };

export async function resetStudentPassword(studentId: string, customPassword: string): Promise<ResetResult> {
  const payload: Record<string, unknown> = { studentId, sendEmailToParent: true };
  if (customPassword) payload.customPassword = customPassword;
  const call = httpsCallable<Record<string, unknown>, Partial<ResetResult>>(functions, "resetStudentPassword");
  const res = await call(payload);
  const data = res.data ?? {};
  return {
    newPassword: String(data.newPassword ?? ""),
    studentCode: String(data.studentCode ?? ""),
    emailSent: data.emailSent === true,
    emailedTo: Array.isArray(data.emailedTo) ? data.emailedTo.map(String) : [],
  };
}

export type DeleteResult = { upcomingClassesDeleted: number; upcomingClassesUpdated: number };

/** U-051 with D3: archive first when still active, then delete by document id. */
export async function deleteUser(id: string, stillActive: boolean, deleteClasses: boolean): Promise<DeleteResult> {
  if (stillActive) await archiveUser(id);
  const call = httpsCallable<{ userId: string; deleteClasses: boolean }, Partial<DeleteResult> & { success?: boolean }>(functions, "deleteUserAccount");
  let res;
  try {
    res = await call({ userId: id, deleteClasses });
    if (res.data?.success !== true) throw new Error("the server did not confirm the deletion");
  } catch (e) {
    // The archive step already happened; the message says so.
    if (stillActive && e && typeof e === "object") Object.assign(e, { archivedFirst: true });
    throw e;
  }
  return {
    upcomingClassesDeleted: Number(res.data.upcomingClassesDeleted ?? 0),
    upcomingClassesUpdated: Number(res.data.upcomingClassesUpdated ?? 0),
  };
}

/** The last few recorded decisions about this person (DecisionAuditService.watchEntityHistory). */
export function listenDecisions(userId: string, count: number, onEvents: (events: Decision[]) => void, onError: (e: Error) => void): Unsubscribe {
  return onSnapshot(
    query(collection(db, "decision_audits", decisionDocId("user", userId), "events"), orderBy("recorded_at", "desc"), limit(count)),
    (snap) =>
      onEvents(
        snap.docs.map((d) => {
          const data = d.data();
          const at = data.recorded_at ?? data.recordedAt;
          return {
            id: d.id,
            action: String(data.action ?? ""),
            actorUid: String(data.actor_uid ?? data.actorUid ?? ""),
            actorName: String(data.actor_name ?? data.actorName ?? ""),
            actorKind: String(data.actor_kind ?? data.actorKind ?? ""),
            at: at instanceof Timestamp ? at.toDate() : null,
            legacy: false,
          };
        }),
      ),
    (e) => onError(e),
  );
}
