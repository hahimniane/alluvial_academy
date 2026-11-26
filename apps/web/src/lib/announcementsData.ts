import { collection, doc, getDoc, getDocs, limit, orderBy, query, serverTimestamp, setDoc, where } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { parseAnnouncement, type Announcement, type AnnouncementRole } from "@/lib/announcements";

const FETCH_LIMIT = 20;

/**
 * Published announcements addressed to `role`, newest first. The audience and
 * status filters are what the Firestore rule checks, so the query is allowed.
 */
export async function fetchAnnouncements(role: AnnouncementRole): Promise<Announcement[]> {
  const snap = await getDocs(
    query(
      collection(db, "announcements"),
      where("audience", "array-contains", role),
      where("status", "==", "published"),
      orderBy("created_at", "desc"),
      limit(FETCH_LIMIT),
    ),
  );
  return snap.docs.map((entry) => parseAnnouncement(entry.id, entry.data())).filter((item): item is Announcement => item !== null);
}

/** Which of `ids` this user has already seen (users/{uid}/announcement_reads). */
export async function fetchSeenAnnouncementIds(uid: string, ids: string[]): Promise<Set<string>> {
  const seen = new Set<string>();
  await Promise.all(
    ids.map(async (id) => {
      try {
        const snap = await getDoc(doc(db, "users", uid, "announcement_reads", id));
        if (snap.exists()) seen.add(id);
      } catch {
        // Unknown counts as seen, so a failed read never repeats the pop-up.
        seen.add(id);
      }
    }),
  );
  return seen;
}

export async function markAnnouncementSeen(uid: string, id: string): Promise<void> {
  await setDoc(doc(db, "users", uid, "announcement_reads", id), { read_at: serverTimestamp() });
}
