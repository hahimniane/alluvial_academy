import type { User } from "firebase/auth";
import { collection, getDocs, getDocsFromServer, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { getCurrentUserRecord } from "@/lib/userRoles";
import { activeRoleOf, allRolesOf } from "@/lib/roles";
import { parentUsesWebArea, resetParentCutoverCache, storedActiveRole } from "@/lib/parentCutover";
import {
  needsGuardianIdsFallback,
  parentDisplayName,
  parentGreeting,
  resolveParentChildren,
  type ParentChild,
} from "@/lib/parentWeb";

/**
 * The signed-in parent, resolved once per page load and shared by every
 * parent screen (the same pattern as studentSession.ts, with its own cache key
 * so a browser shared by a parent and a student never mixes the two).
 */
export type ParentSession = {
  uid: string;
  /** The account holds the parent role (user_type or secondary_roles). */
  isParent: boolean;
  /** The role Flutter would open as: the switcher's saved role if still held, else user_type. */
  activeRole: string;
  /** Every role the account holds, in RoleSwitcher order. */
  roles: string[];
  /** settings/parent_web_cutover places this parent on the web area. */
  onWeb: boolean;
  displayName: string;
  greeting: string;
  language: string;
};

export type ParentSessionResult =
  | { status: "ok"; session: ParentSession }
  | { status: "noRecord" }
  | { status: "error"; message: string };

let cached: ParentSession | null = null;
let inflight: { uid: string; promise: Promise<ParentSessionResult> } | null = null;

export function cachedParentSession(uid?: string): ParentSession | null {
  if (!cached) return null;
  if (uid && cached.uid !== uid) return null;
  return cached;
}

export async function resolveParentSession(user: User): Promise<ParentSessionResult> {
  if (cached && cached.uid === user.uid) return { status: "ok", session: cached };
  if (inflight && inflight.uid === user.uid) return inflight.promise;

  const promise = (async (): Promise<ParentSessionResult> => {
    try {
      const record = await getCurrentUserRecord(user);
      if (!record) return { status: "noRecord" };
      const roles = allRolesOf(record);
      const isParent = roles.includes("parent");
      const session: ParentSession = {
        uid: user.uid,
        isParent,
        activeRole: activeRoleOf(record, storedActiveRole()),
        roles,
        onWeb: isParent ? await parentUsesWebArea(user.uid) : false,
        displayName: parentDisplayName(record),
        greeting: parentGreeting(record),
        language: typeof record.language_preference === "string" ? record.language_preference : "",
      };
      cached = session;
      return { status: "ok", session };
    } catch (error) {
      return { status: "error", message: error instanceof Error ? error.message : String(error) };
    } finally {
      inflight = null;
    }
  })();
  inflight = { uid: user.uid, promise };
  return promise;
}

/** Drop the cached parent so the next account cannot inherit it. */
export function clearParentSession() {
  cached = null;
  inflight = null;
  resetParentCutoverCache();
}

/**
 * The parent's children — ParentService.getParentChildren, query for query:
 * students whose `guardian_ids` holds the parent, and only when that finds
 * nobody, students whose `guardianIds` does. One-shot. A failure is thrown,
 * as Flutter rethrows it.
 */
export async function fetchParentChildren(parentId: string, options: { fromServer?: boolean } = {}): Promise<ParentChild[]> {
  const read = options.fromServer ? getDocsFromServer : getDocs;
  const byField = async (field: "guardian_ids" | "guardianIds") => {
    const snap = await read(
      query(collection(db, "users"), where("user_type", "==", "student"), where(field, "array-contains", parentId)),
    );
    return snap.docs.map((entry) => ({ id: entry.id, data: entry.data() as Record<string, unknown> }));
  };
  const primary = await byField("guardian_ids");
  const fallback = needsGuardianIdsFallback(primary.length) ? await byField("guardianIds") : null;
  return resolveParentChildren(primary, fallback);
}
