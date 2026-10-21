import { addDoc, collection, getDocs, query, serverTimestamp, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";
import { parseMakeupRequest, type MakeupRequest } from "@/lib/makeupRequests";

const COLLECTION = "reschedule_requests";

/** Files a teacher's request; fields come from buildMakeupRequestFields. */
export async function submitMakeupRequest(fields: Record<string, unknown>): Promise<string> {
  const ref = await addDoc(collection(db, COLLECTION), {
    ...fields,
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
  });
  return ref.id;
}

/** A teacher's own requests (the rules only show a teacher their own). */
export async function loadTeacherMakeupRequests(uid: string): Promise<MakeupRequest[]> {
  const snap = await getDocs(query(collection(db, COLLECTION), where("teacher_id", "==", uid)));
  return snap.docs.map((d) => parseMakeupRequest(d.id, d.data() as Record<string, unknown>));
}

export async function loadPendingMakeupRequests(): Promise<MakeupRequest[]> {
  const snap = await getDocs(query(collection(db, COLLECTION), where("status", "==", "pending")));
  return snap.docs
    .map((d) => parseMakeupRequest(d.id, d.data() as Record<string, unknown>))
    .sort((a, b) => (a.proposedStart?.getTime() ?? 0) - (b.proposedStart?.getTime() ?? 0));
}

export type MakeupReview =
  | { requestId: string; decision: "approve"; startTime?: Date }
  | { requestId: string; decision: "decline"; reason: string };

/** Same callable the Flutter admin screen uses; the server builds the makeup from the original class. */
export async function reviewMakeupRequest(review: MakeupReview): Promise<{ createdShiftId?: string }> {
  const call = httpsCallable(functions, "reviewRescheduleRequest");
  const payload =
    review.decision === "approve"
      ? { requestId: review.requestId, decision: "approve", ...(review.startTime ? { startTime: review.startTime.toISOString() } : {}) }
      : { requestId: review.requestId, decision: "decline", reason: review.reason };
  const result = await call(payload);
  const data = (result.data ?? {}) as { createdShiftId?: string };
  return { createdShiftId: data.createdShiftId };
}
