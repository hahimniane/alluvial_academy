import { signOut, type User } from "firebase/auth";
import { collection, doc, getDoc, getDocs, limit, query, serverTimestamp, updateDoc, where, type DocumentReference } from "firebase/firestore";
import { auth, db } from "@/lib/firebase";

/**
 * What the Flutter app does right after a successful sign-in
 * (AuthService.handleSuccessfulLogin): refuse an archived account and record
 * the login time. The Next sign-in pages skipped both, so archived people got
 * in there and people who only used them showed "Never logged in".
 */

export const ARCHIVED_MESSAGE = "Your account has been archived. Please contact an administrator for assistance.";

/** UserRoleService.isUserActive: `is_active` as stored, active when missing or not a boolean. */
export const isArchivedProfile = (data: Record<string, unknown> | undefined | null) => !!data && data.is_active === false;

/** The user's profile: their uid document, else the one whose `e-mail` is their address (Flutter's fallback). */
async function findProfile(user: User): Promise<{ ref: DocumentReference; data: Record<string, unknown> } | null> {
  const byUid = await getDoc(doc(db, "users", user.uid));
  if (byUid.exists()) return { ref: byUid.ref, data: byUid.data() };
  const email = (user.email ?? "").trim().toLowerCase();
  if (!email) return null;
  const byEmail = await getDocs(query(collection(db, "users"), where("e-mail", "==", email), limit(1)));
  const first = byEmail.docs[0];
  return first ? { ref: first.ref, data: first.data() } : null;
}

/**
 * Throws an Error carrying ARCHIVED_MESSAGE (code `user-deactivated`) after
 * signing the person out when their account is archived. A read error lets
 * them through, as Flutter does ("default to active on error").
 */
export const NOT_REGISTERED_MESSAGE =
  "No account found with this email. Please contact an administrator to create your account.";

/**
 * Google sign-in creates a Firebase account for any Google address, so — as
 * Flutter's AuthService.signInWithGoogle does — someone with no profile under
 * their uid or e-mail is signed straight back out. A read error lets them
 * through, like afterSignIn.
 */
export async function requireRegistered(user: User): Promise<void> {
  let profile: Awaited<ReturnType<typeof findProfile>> = null;
  try {
    profile = await findProfile(user);
  } catch {
    return;
  }
  if (profile) return;
  await signOut(auth).catch(() => undefined);
  throw Object.assign(new Error(NOT_REGISTERED_MESSAGE), { code: "user-not-registered" });
}

export async function afterSignIn(user: User): Promise<void> {
  let profile: Awaited<ReturnType<typeof findProfile>> = null;
  try {
    profile = await findProfile(user);
  } catch {
    return;
  }
  if (!profile) return;
  if (isArchivedProfile(profile.data)) {
    await signOut(auth).catch(() => undefined);
    throw Object.assign(new Error(ARCHIVED_MESSAGE), { code: "user-deactivated" });
  }
  await updateDoc(profile.ref, { last_login: serverTimestamp() }).catch(() => undefined);
}
