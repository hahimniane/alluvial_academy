import { doc, runTransaction, serverTimestamp } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { auth, db, functions } from "@/lib/firebase";
import { buildEditPatch, type Draft, type EditField } from "@/lib/editUser";
import type { LinkResult } from "@/lib/guardians";

/**
 * Writes behind Edit user and the guardian sections. The user document is
 * always users/{documentId} (never found by email).
 */

function signedIn() {
  if (!auth.currentUser) throw Object.assign(new Error("Not signed in"), { code: "unauthenticated" });
}

/**
 * Saves the fields the admin changed. Read and written in one transaction, so
 * the patch is computed against the document as it is at that moment: fields
 * the admin did not change are never written, and a role someone else added
 * to "Also works as" meanwhile is kept. On a field both changed, this save
 * wins (last write).
 */
export async function saveUserEdits(id: string, draft: Draft): Promise<{ saved: boolean; fields: EditField[] }> {
  signedIn();
  const ref = doc(db, "users", id);
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw Object.assign(new Error("This account no longer exists"), { code: "not-found" });
    const built = buildEditPatch(snap.data(), draft, serverTimestamp());
    if (!built) return { saved: false, fields: [] };
    tx.update(ref, built.patch);
    return { saved: true, fields: built.fields };
  });
}

export async function linkGuardian(studentUid: string, parentUid: string): Promise<LinkResult & { guardianCount: number }> {
  signedIn();
  const call = httpsCallable<{ studentUid: string; parentUid: string }, Partial<LinkResult> & { guardianCount?: number; success?: boolean }>(
    functions,
    "linkGuardianToStudent",
  );
  const res = await call({ studentUid, parentUid });
  if (res.data?.success !== true) throw new Error("the server did not confirm the link");
  return { alreadyLinked: res.data.alreadyLinked === true, repaired: res.data.repaired === true, guardianCount: Number(res.data.guardianCount ?? 0) };
}

export async function unlinkGuardian(input: {
  studentUid: string;
  parentUid: string;
  reason: string;
  convertStudentToAdult: boolean;
}): Promise<{ convertedStudentToAdult: boolean; remainingGuardianCount: number }> {
  signedIn();
  const payload: Record<string, unknown> = { studentUid: input.studentUid, parentUid: input.parentUid };
  const reason = input.reason.trim();
  if (reason) payload.reason = reason;
  if (input.convertStudentToAdult) payload.convertStudentToAdult = true;
  const call = httpsCallable<Record<string, unknown>, { success?: boolean; convertedStudentToAdult?: boolean; remainingGuardianCount?: number }>(
    functions,
    "unlinkGuardianFromStudent",
  );
  const res = await call(payload);
  if (res.data?.success !== true) throw new Error("the server did not confirm the unlink");
  return { convertedStudentToAdult: res.data.convertedStudentToAdult === true, remainingGuardianCount: Number(res.data.remainingGuardianCount ?? 0) };
}
