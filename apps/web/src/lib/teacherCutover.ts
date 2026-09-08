import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

/**
 * Whether teachers belong on this console rather than the Flutter dashboard.
 *
 * The same `settings/teacher_web_cutover` document the Flutter app reads, so
 * both clients agree and one edit still moves everyone either way without a
 * deploy. Mirrors `lib/core/services/teacher_web_cutover.dart`.
 *
 * Fails **open** here, which is the opposite of the Flutter side and
 * deliberate: Flutter defaults to keeping a teacher where they already are,
 * while this app is the teacher console, so an unreadable document should leave
 * them here rather than throw them back to an app they were moved off.
 */
const DOC = { collection: "settings", id: "teacher_web_cutover" };

let cached: boolean | null = null;

export async function teacherUsesWebConsole(teacherId: string): Promise<boolean> {
  if (cached !== null) return cached;
  try {
    const snap = await getDoc(doc(db, DOC.collection, DOC.id));
    const data = snap.data();
    if (!data) return remember(true);
    const mode = String(data.mode ?? "off").toLowerCase();
    if (mode === "all") return remember(true);
    if (mode !== "allowlist") return remember(false);
    const ids = data.teacherIds;
    return remember(Array.isArray(ids) && ids.map(String).includes(teacherId));
  } catch {
    return remember(true);
  }
}

function remember(value: boolean) {
  cached = value;
  return value;
}

/** Forget the cached answer (used when the signed-in person changes). */
export function resetTeacherCutoverCache() {
  cached = null;
}
