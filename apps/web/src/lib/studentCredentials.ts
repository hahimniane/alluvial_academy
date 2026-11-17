import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

/**
 * A student's stored login password, read only when an admin presses Show.
 *
 * It lives in `student_credentials/{uid}` (admins and the student's own
 * guardians may read it; only Cloud Functions write it). Accounts made before
 * that store still carry it on the user document until the migration moves
 * it, so the user document's legacy field is the fallback. This is the only
 * web file that names that field, and it never writes it.
 */

const LEGACY_FIELD = "temp_password";

const nonBlank = (value: unknown): string => (typeof value === "string" && value.trim() ? value : "");

/** The store's password when it has one, else the legacy copy, else "". */
export function pickStudentPassword(credential: Record<string, unknown> | undefined, userData: Record<string, unknown> | undefined): string {
  return nonBlank(credential?.password) || nonBlank(userData?.[LEGACY_FIELD]);
}

/** Throws on a read error (no permission, offline) so the panel can say so. */
export async function readStudentPassword(studentId: string): Promise<string> {
  const credential = await getDoc(doc(db, "student_credentials", studentId));
  const stored = nonBlank(credential.data()?.password);
  if (stored) return stored;
  const user = await getDoc(doc(db, "users", studentId));
  return pickStudentPassword(undefined, user.data());
}
