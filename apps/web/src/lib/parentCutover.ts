import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { PARENT_CUTOVER_DOC, parentCutoverAllows } from "@/lib/parentWeb";

/**
 * Whether this parent belongs on the Next.js parent area, read from
 * `settings/parent_web_cutover` — the document the Flutter app reads too
 * (lib/core/services/parent_web_cutover.dart), so one edit moves parents
 * either way without a deploy.
 *
 * Fails closed, like the Flutter side and unlike the teacher console: until
 * the switch names a parent, they stay on /app/. Errors are thrown rather than
 * read as "no", so the parent area can tell a parent who has not been moved
 * from one whose check failed, and never bounce someone between the two apps
 * on a bad connection.
 */
let cache: { uid: string; value: boolean } | null = null;

export async function parentUsesWebArea(uid: string): Promise<boolean> {
  if (cache && cache.uid === uid) return cache.value;
  const snap = await getDoc(doc(db, PARENT_CUTOVER_DOC.collection, PARENT_CUTOVER_DOC.id));
  const value = parentCutoverAllows(snap.exists() ? snap.data() : null, uid);
  cache = { uid, value };
  return value;
}

/** Never throws: an unreadable switch means "not moved". Used by the login redirect. */
export async function parentUsesWebAreaSafe(uid: string): Promise<boolean> {
  try {
    return await parentUsesWebArea(uid);
  } catch {
    return false;
  }
}

export function resetParentCutoverCache() {
  cache = null;
}

/** The role Flutter's switcher saved on this browser (SharedPreferences key, JSON-encoded). */
export function storedActiveRole(): string | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem("flutter.active_user_role");
    if (!raw) return null;
    const value = JSON.parse(raw);
    return typeof value === "string" ? value : null;
  } catch {
    return null;
  }
}
