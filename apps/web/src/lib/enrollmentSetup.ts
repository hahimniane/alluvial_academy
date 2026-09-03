/**
 * The three steps that turn a match into a class that can actually be taught:
 * the student gets a login, a parent is linked to it, and the classes reach the
 * calendar.
 *
 * Ported from `lib/features/enrollment_management/widgets/matched_enrollment_card.dart`
 * and `invite_parent_dialog.dart`. Both writes go through the same Cloud
 * Function callables the native app uses, so accounts are created one way only.
 */

import { doc, getDoc, serverTimestamp, setDoc } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "./firebase";
import { parentInviteProblem, splitStudentName, type ParentInvite } from "./enrollmentSetupRules";

export { parentInviteProblem, splitStudentName };
export type { ParentInvite };

const record = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};

const text = (value: unknown): string => (typeof value === "string" ? value.trim() : "");

export type CreatedStudent = { studentId: string; studentCode: string };

/**
 * Creates the student's login.
 *
 * A minor's account never takes the contact email — that address belongs to the
 * parent, and using it would make the child's login the parent's. Leaving the
 * email off makes the callable generate an alias from the student code.
 */
export async function createStudentAccount(enrollmentId: string): Promise<CreatedStudent> {
  const snapshot = await getDoc(doc(db, "enrollments", enrollmentId));
  if (!snapshot.exists()) throw new Error("Enrollment not found.");
  const data = snapshot.data() as Record<string, unknown>;

  const contact = record(data.contact);
  const student = record(data.student);
  const metadata = record(data.metadata);

  const names = splitStudentName(
    text(student.firstName),
    text(student.lastName),
    text(student.name) || text(data.studentName),
  );

  const isAdult = metadata.isAdult === true || data.isAdult === true;
  const studentEmail = isAdult ? text(contact.email) : "";
  const guardianId = text(contact.guardianId);

  const callable = httpsCallable<Record<string, unknown>, Record<string, unknown>>(
    functions,
    "createStudentAccount",
  );
  const result = await callable({
    firstName: names.firstName,
    lastName: names.lastName,
    isAdultStudent: isAdult,
    ...(studentEmail ? { email: studentEmail } : {}),
    phoneNumber: text(contact.phone),
    guardianIds: guardianId ? [guardianId] : [],
  });

  const studentId = text(result.data?.studentId);
  const studentCode = text(result.data?.studentCode);

  // Persist the uid so a later session can find the account without creating a
  // second one. A failure here must not lose the account that already exists.
  if (studentId) {
    try {
      await setDoc(
        doc(db, "enrollments", enrollmentId),
        { metadata: { studentUserId: studentId, studentAccountCreatedAt: serverTimestamp() } },
        { merge: true },
      );
    } catch {
      // The account is real either way; the card re-reads it on refresh.
    }
  }

  return { studentId, studentCode };
}

export type ParentInviteResult = { status: string; message: string };

/**
 * Links a parent to the student's account, inviting them if they have no login.
 *
 * Returns the callable's own status ('linked' when the parent already had an
 * account, 'invited' when one was sent), which is what the setup pill reads.
 */
export async function inviteParentForEnrollment(
  enrollmentId: string,
  studentUid: string,
  invite: ParentInvite,
): Promise<ParentInviteResult> {
  const problem = parentInviteProblem(invite);
  if (problem) throw new Error(problem);
  if (!studentUid) throw new Error("Create the student's account before inviting a parent.");

  const callable = httpsCallable<Record<string, unknown>, Record<string, unknown>>(
    functions,
    "inviteParentForEnrollment",
  );
  const result = await callable({
    enrollmentId,
    studentUid,
    email: invite.email.trim(),
    firstName: invite.firstName.trim(),
    lastName: invite.lastName.trim(),
    phone: invite.phone.trim(),
    ...(invite.countryCode.trim() ? { countryCode: invite.countryCode.trim() } : {}),
  });

  return {
    status: text(result.data?.status) || "invited",
    message: text(result.data?.message),
  };
}
