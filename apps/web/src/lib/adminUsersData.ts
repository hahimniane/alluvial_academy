import { collection, doc, getDoc, onSnapshot, query, Timestamp, where, type Unsubscribe } from "firebase/firestore";
import { db } from "@/lib/firebase";
import {
  ADMIN_USERS_CUTOVER_DOC,
  adminUsersCutoverAllows,
  mapUserDoc,
  mapWeekShift,
  sameRow,
  type UserRow,
  type WeekShift,
} from "@/lib/adminUsers";

/**
 * Firestore reads for the admin Users page. Two listeners, both bounded:
 *  - the whole `users` collection, live (as the Flutter screen does); each
 *    document is mapped to named fields as it arrives and the page is only
 *    told about it when a field it shows changed, so the presence heartbeat
 *    every signed-in Flutter user writes each minute costs one document read
 *    and no re-render;
 *  - this week's classes (`teaching_shifts`, Monday to Monday), live, for the
 *    Teacher / Weekly Hours columns. The current week is never archived, so
 *    the live collection alone is complete here.
 * Parent links and First class come from the users documents themselves; no
 * per-row reads.
 */

export function listenUsers(onRows: (rows: UserRow[]) => void, onError: (error: Error) => void): Unsubscribe {
  const byId = new Map<string, UserRow>();
  let order: string[] = [];
  let fromServer = false;
  return onSnapshot(
    collection(db, "users"),
    { includeMetadataChanges: true },
    (snap) => {
      // The first answer can come from the local cache, which holds only the
      // few user documents this page already read (the admin's own profile):
      // showing it would flash "Users 0 / Admins 1" and "No users yet" until
      // the server answers. Wait for the server's first full list; after
      // that, every update is applied as it comes (offline included).
      let first = false;
      if (!fromServer) {
        if (snap.metadata.fromCache) return;
        fromServer = true;
        first = true;
      }
      let changed = false;
      // docChanges() is relative to the last snapshot delivered, including a
      // skipped cached one, so the first server answer is read in full.
      const changes = first ? snap.docs.map((doc) => ({ type: "added" as const, doc })) : snap.docChanges();
      for (const change of changes) {
        const id = change.doc.id;
        if (change.type === "removed") {
          if (byId.delete(id)) changed = true;
          continue;
        }
        const next = mapUserDoc(id, change.doc.data());
        const prev = byId.get(id);
        if (!prev || !sameRow(prev, next)) {
          byId.set(id, next);
          changed = true;
        }
      }
      if (!changed && order.length === byId.size) return;
      order = snap.docs.map((d) => d.id);
      onRows(order.map((id) => byId.get(id)).filter((r): r is UserRow => !!r));
    },
    (error) => onError(error),
  );
}

export function listenWeekShifts(
  week: { start: Date; end: Date },
  onShifts: (shifts: WeekShift[]) => void,
  onError: (error: Error) => void,
): Unsubscribe {
  const q = query(
    collection(db, "teaching_shifts"),
    where("shift_start", ">=", Timestamp.fromDate(week.start)),
    where("shift_start", "<", Timestamp.fromDate(week.end)),
  );
  return onSnapshot(
    q,
    (snap) => onShifts(snap.docs.map((d) => mapWeekShift(d.data()))),
    (error) => onError(error),
  );
}

/** Whether this admin gets the Next.js Users page. Throws on a read error so the caller can offer a retry. */
export async function adminUsesWebUsersPage(uid: string): Promise<boolean> {
  const snap = await getDoc(doc(db, ADMIN_USERS_CUTOVER_DOC.collection, ADMIN_USERS_CUTOVER_DOC.id));
  return adminUsersCutoverAllows(snap.exists() ? snap.data() : null, uid);
}
