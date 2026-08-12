import type { User } from "firebase/auth";
import { getCurrentUserRecord, isAdultStudentRecord, rolesForUserRecord } from "@/lib/userRoles";

export type StudentSummary = {
  displayName: string;
  firstName: string;
  initials: string;
  /** Profile photo download URL; initials render only when this is absent. */
  photoUrl?: string;
};

export type StudentSession = {
  uid: string;
  isStudent: boolean;
  isAdultStudent: boolean;
  accessSuspended: boolean;
  summary: StudentSummary;
};

/**
 * Resolved once per page load and reused by every student tab.
 *
 * Each tab used to run its own auth + Firestore role lookup on mount, so moving
 * between tabs flashed "Checking student access" while that round trip
 * completed — every single time. The pages are client components inside one
 * SPA, so caching the answer at module scope means the check happens on first
 * load and subsequent navigations render immediately.
 *
 * Keyed by uid so switching accounts cannot serve a stale session, and the
 * in-flight promise is shared so two tabs mounting together issue one lookup.
 */
let cached: StudentSession | null = null;
let inflight: { uid: string; promise: Promise<StudentSession> } | null = null;

const STORAGE_KEY = "alluwal-student-session-v1";

/**
 * The uid Firebase itself has persisted, read synchronously.
 *
 * Firebase restores auth from IndexedDB asynchronously, but it also mirrors the
 * signed-in user into localStorage. Reading that lets us tell "signed in, still
 * restoring" apart from "signed out" without waiting — so a reload does not have
 * to show an access screen to someone who is plainly signed in.
 */
function persistedAuthUid(): string | null {
  if (typeof window === "undefined") return null;
  try {
    const key = Object.keys(window.localStorage).find((entry) => entry.startsWith("firebase:authUser:"));
    if (!key) return null;
    const raw = window.localStorage.getItem(key);
    const uid = raw ? (JSON.parse(raw) as { uid?: string }).uid : null;
    return typeof uid === "string" && uid ? uid : null;
  } catch {
    return null;
  }
}

/** True when Firebase has a session on this device, even if not yet restored. */
export function hasPersistedAuth() {
  return persistedAuthUid() !== null;
}

function readPersisted(uid: string): StudentSession | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as StudentSession;
    return parsed && parsed.uid === uid ? parsed : null;
  } catch {
    return null;
  }
}

function writePersisted(session: StudentSession) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  } catch {}
}

/** Synchronous read for initial state — null before the first resolve. */
export function cachedStudentSession(uid?: string): StudentSession | null {
  if (cached) {
    if (uid && cached.uid !== uid) return null;
    return cached;
  }
  // Cold load: reuse the last resolved session, but only for the uid Firebase
  // still has persisted. Verification still runs; this just avoids blocking the
  // first paint on a Firestore round trip.
  const authUid = uid ?? persistedAuthUid();
  if (!authUid) return null;
  const stored = readPersisted(authUid);
  if (stored) cached = stored;
  return stored;
}

export async function resolveStudentSession(user: User): Promise<StudentSession> {
  if (cached && cached.uid === user.uid) return cached;
  if (inflight && inflight.uid === user.uid) return inflight.promise;

  const promise = (async () => {
    const record = await getCurrentUserRecord(user);
    const roles = record ? rolesForUserRecord(record) : new Set<string>();
    const name =
      [stringValue(record?.first_name), stringValue(record?.last_name)].filter(Boolean).join(" ") ||
      user.displayName?.trim() ||
      user.email?.replace(/@.*/, "") ||
      "Student";

    const session: StudentSession = {
      uid: user.uid,
      isStudent: roles.has("student"),
      isAdultStudent: isAdultStudentRecord(record),
      accessSuspended: record?.access_suspended === true || record?.accessSuspended === true,
      summary: {
        displayName: name,
        firstName: name.split(/\s+/)[0] || "Student",
        initials: initialsFromName(name),
        photoUrl: stringValue(record?.profile_picture_url ?? record?.profilePictureUrl) || undefined,
      },
    };
    cached = session;
    writePersisted(session);
    inflight = null;
    return session;
  })();

  inflight = { uid: user.uid, promise };
  return promise;
}

/** Keeps the cached session's photo in step after an upload on the profile page. */
export function updateStudentSessionPhoto(photoUrl: string) {
  if (!cached) return;
  cached = { ...cached, summary: { ...cached.summary, photoUrl: photoUrl || undefined } };
  writePersisted(cached);
}

/** Called on sign-out so the next account starts clean. */
export function clearStudentSession() {
  cached = null;
  inflight = null;
  if (typeof window !== "undefined") {
    try {
      window.localStorage.removeItem(STORAGE_KEY);
    } catch {}
  }
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "ST";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}
