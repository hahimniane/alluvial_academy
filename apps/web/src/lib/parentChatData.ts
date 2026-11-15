"use client";

/**
 * Firestore and Storage access for the parent chat, write for write as
 * ChatService / ChatPermissionService do it (inventory C-404…C-469), so a
 * message sent here reads the same in the Flutter apps and fires the same
 * push trigger. Where a Flutter action fails today the plan says make it work:
 * Clear chat clears the parent's own view, Leave Group writes its notice as
 * the parent, Forward to Admin Support uses the real thread id, and editing an
 * older message no longer rewrites the list preview.
 */
import {
  addDoc,
  arrayRemove,
  arrayUnion,
  collection,
  deleteField,
  doc,
  documentId,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  type DocumentReference,
} from "firebase/firestore";
import { getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { db, storage } from "@/lib/firebase";
import {
  ADMIN_SUPPORT_ID,
  activeTeacherIds,
  buildRow,
  chatChildrenIds,
  countsUnread,
  hasRecentMessage,
  hiddenForMe,
  parseMessage,
  personFromDoc,
  sortRows,
  storageFileName,
  supportChatId,
  visibleStoredLast,
  type ChatMessage,
  type ChatPerson,
  type ChatRow,
} from "@/lib/parentChat";

type Data = Record<string, unknown>;
type Unsubscribe = () => void;

const chunks = <T,>(items: T[], size: number) => Array.from({ length: Math.ceil(items.length / size) }, (_, i) => items.slice(i * size, i * size + size));

/** `users` docs by id, 30 per `in` query (Flutter's contacts query was not batched — B-3). */
export async function fetchUsers(ids: string[]): Promise<Map<string, Data>> {
  const out = new Map<string, Data>();
  const unique = [...new Set(ids.filter(Boolean))];
  await Promise.all(
    chunks(unique, 30).map(async (part) => {
      const snap = await getDocs(query(collection(db, "users"), where(documentId(), "in", part)));
      snap.docs.forEach((d) => out.set(d.id, d.data()));
    }),
  );
  return out;
}

async function unreadFor(chatId: string, uid: string) {
  const snap = await getDocs(query(collection(db, "chats", chatId, "messages"), where("is_read", "==", false)));
  return snap.docs.map((d) => parseMessage(d.id, d.data())).filter((m) => countsUnread(m, uid)).length;
}

async function lastVisibleFor(chatId: string, data: Data, uid: string): Promise<ChatMessage | null> {
  const stored = visibleStoredLast(data, uid);
  if (stored) return stored;
  const snap = await getDocs(query(collection(db, "chats", chatId, "messages"), orderBy("timestamp", "desc"), limit(20)));
  for (const d of snap.docs) {
    const m = parseMessage(d.id, d.data());
    if (!hiddenForMe(m, uid)) return m;
  }
  return null;
}

/** C-404: live Recent list (participants contains me, has a last message), newest first. */
export function watchRecent(uid: string, onRows: (rows: ChatRow[]) => void, onError: (denied: boolean) => void): Unsubscribe {
  let revision = 0;
  return onSnapshot(
    query(collection(db, "chats"), where("participants", "array-contains", uid)),
    async (snap) => {
      const run = ++revision;
      try {
        const docs = snap.docs.filter((d) => hasRecentMessage(d.data())).map((d) => ({ id: d.id, data: d.data() as Data }));
        const others = docs
          .filter((d) => d.data.chat_type !== "group" && !(d.data.participants as string[] | undefined)?.includes(ADMIN_SUPPORT_ID))
          .map((d) => ((d.data.participants as string[] | undefined) ?? []).find((p) => p !== uid) ?? "");
        const users = await fetchUsers(others);
        const now = new Date();
        const rows = await Promise.all(
          docs.map(async (d) => {
            const [unread, lastVisible] = await Promise.all([unreadFor(d.id, uid).catch(() => 0), lastVisibleFor(d.id, d.data, uid).catch(() => null)]);
            const otherId = ((d.data.participants as string[] | undefined) ?? []).find((p) => p !== uid) ?? "";
            const otherData = users.get(otherId);
            return buildRow(d, uid, { unread, lastVisible, other: otherData ? personFromDoc(otherId, otherData, now) : null });
          }),
        );
        if (run === revision) onRows(sortRows(rows.filter((r): r is ChatRow => r !== null)));
      } catch {
        if (run === revision) onRows([]);
      }
    },
    (error) => onError(String((error as { code?: string }).code ?? "").includes("permission-denied")),
  );
}

// ─── Contacts (C-412…C-415) ────────────────────────────────────────────────

export type ParentContacts = { admins: ChatPerson[]; teachers: ChatPerson[] };

/** The parent's chat children and every class of theirs (shared by contacts and canMessage). */
export type ChildShift = { teacherId: string; status: string; shiftEnd: Date | null };

let childShiftsCache: { uid: string; promise: Promise<ChildShift[]> } | null = null;
export function loadChildShifts(uid: string): Promise<ChildShift[]> {
  if (childShiftsCache?.uid === uid) return childShiftsCache.promise;
  const promise = (async () => {
    const me = await getDoc(doc(db, "users", uid));
    const childrenIds = ((me.data()?.children_ids as unknown[]) ?? []).map(String).filter(Boolean);
    let guardianStudents: string[] = [];
    if (!childrenIds.length) {
      const snap = await getDocs(query(collection(db, "users"), where("user_type", "==", "student"), where("guardian_ids", "array-contains", uid)));
      guardianStudents = snap.docs.map((d) => d.id);
    }
    const children = chatChildrenIds(childrenIds, guardianStudents);
    const shifts: ChildShift[] = [];
    await Promise.all(
      children.map(async (childId) => {
        const snap = await getDocs(query(collection(db, "teaching_shifts"), where("student_ids", "array-contains", childId)));
        snap.docs.forEach((d) => {
          const data = d.data();
          const end = data.shift_end && typeof data.shift_end.toDate === "function" ? (data.shift_end.toDate() as Date) : null;
          shifts.push({ teacherId: String(data.teacher_id ?? ""), status: String(data.status ?? ""), shiftEnd: end });
        });
      }),
    );
    return shifts;
  })();
  childShiftsCache = { uid, promise };
  promise.catch(() => {
    if (childShiftsCache?.promise === promise) childShiftsCache = null;
  });
  return promise;
}

export function resetChatCaches() {
  childShiftsCache = null;
}

/** Administrators (admin, super_admin, ceo, founder, admin-teachers) + the children's teachers. */
export async function loadContacts(uid: string): Promise<ParentContacts> {
  const now = new Date();
  const [byType, adminTeachers, shifts] = await Promise.all([
    getDocs(query(collection(db, "users"), where("user_type", "in", ["admin", "super_admin", "ceo", "founder"]))),
    getDocs(query(collection(db, "users"), where("is_admin_teacher", "==", true))),
    loadChildShifts(uid),
  ]);
  const admins = new Map<string, ChatPerson>();
  [...byType.docs, ...adminTeachers.docs].forEach((d) => {
    if (d.id !== uid) admins.set(d.id, personFromDoc(d.id, d.data(), now));
  });
  const teacherIds = activeTeacherIds(shifts, now);
  const users = await fetchUsers(teacherIds);
  const teachers = teacherIds.filter((id) => users.has(id) && id !== uid).map((id) => personFromDoc(id, users.get(id)!, now));
  return { admins: [...admins.values()], teachers };
}

/** C-412: create (or repair) the parent's Admin Support thread. */
export async function ensureSupportChat(uid: string) {
  const id = supportChatId(uid);
  const chatRef = doc(db, "chats", id);
  const snap = await getDoc(chatRef);
  const participants = [uid, ADMIN_SUPPORT_ID];
  if (!snap.exists()) {
    await setDoc(chatRef, { participants, chat_type: "admin_support", created_at: serverTimestamp(), updated_at: serverTimestamp() });
  } else {
    const data = snap.data();
    const stored = ((data.participants as unknown[]) ?? []).map(String);
    if (!stored.includes(uid) || !stored.includes(ADMIN_SUPPORT_ID) || data.chat_type !== "admin_support") {
      await updateDoc(chatRef, { participants, chat_type: "admin_support" });
    }
  }
  return id;
}

// ─── A conversation ────────────────────────────────────────────────────────

/** C-420: newest 50, live. */
export function watchMessages(chatId: string, onData: (messages: ChatMessage[]) => void, onError: () => void): Unsubscribe {
  return onSnapshot(
    query(collection(db, "chats", chatId, "messages"), orderBy("timestamp", "desc"), limit(50)),
    (snap) => onData(snap.docs.map((d) => parseMessage(d.id, d.data()))),
    () => onError(),
  );
}

/** One chat document, live (group name, members, admins). */
export function watchChat(chatId: string, onData: (data: Data | null) => void): Unsubscribe {
  return onSnapshot(
    doc(db, "chats", chatId),
    (snap) => onData(snap.exists() ? snap.data() : null),
    () => onData(null),
  );
}

/** C-422: mark incoming unread messages read and stamp last_read_by. */
export async function markRead(chatId: string, uid: string) {
  const snap = await getDocs(query(collection(db, "chats", chatId, "messages"), where("is_read", "==", false)));
  const refs = snap.docs.filter((d) => countsUnread(parseMessage(d.id, d.data()), uid)).map((d) => d.ref);
  for (const part of chunks(refs, 450)) {
    const batch = writeBatch(db);
    part.forEach((r) => batch.update(r, { is_read: true }));
    await batch.commit();
  }
  await updateDoc(doc(db, "chats", chatId), { [`last_read_by.${uid}`]: serverTimestamp() }).catch(() => undefined);
}

/** C-416 inbound unlock: has the other person written in this thread? */
export async function otherHasWritten(chatId: string, otherId: string) {
  const snap = await getDocs(query(collection(db, "chats", chatId, "messages"), where("sender_id", "==", otherId), limit(1))).catch(() => null);
  return !!snap && !snap.empty;
}

export async function fetchUser(uid: string): Promise<Data | null> {
  const snap = await getDoc(doc(db, "users", uid)).catch(() => null);
  return snap?.exists() ? snap.data() : null;
}

export type Target = { chatId: string; kind: "direct" | "group" | "support"; participants: string[] };

/** ChatService.sendMessage: create or update the chat, then add the message. */
export async function sendMessage(target: Target, uid: string, content: string, type = "text", metadata: Data | null = null) {
  const me = (await fetchUser(uid)) ?? {};
  const name = `${String(me.first_name ?? "")} ${String(me.last_name ?? "")}`.trim() || String(me.email ?? me["e-mail"] ?? "") || "Unknown";
  const message = {
    sender_id: uid,
    sender_name: name,
    sender_profile_picture: me.profile_picture_url ?? me.profile_picture ?? null,
    content,
    timestamp: serverTimestamp(),
    is_read: false,
    message_type: type,
    metadata: metadata ?? {},
  };
  const chatRef = doc(db, "chats", target.chatId);
  const existing = await getDoc(chatRef);
  if (!existing.exists()) {
    const chatType = target.kind === "support" ? "admin_support" : target.kind === "group" ? "group" : "individual";
    await setDoc(chatRef, { participants: target.participants, chat_type: chatType, created_at: serverTimestamp(), updated_at: serverTimestamp(), last_message: message });
  } else {
    await updateDoc(chatRef, { updated_at: serverTimestamp(), last_message: message });
  }
  await addDoc(collection(db, "chats", target.chatId, "messages"), message);
}

/** C-433 / C-434 / C-437: upload to the sender's own folder and send the message. */
export async function sendFile(target: Target, uid: string, file: File, kind: "image" | "video" | "file", caption = "") {
  const folder = kind === "image" ? "chat_images" : kind === "video" ? "chat_videos" : "chat_files";
  const name = storageFileName(Date.now(), file.name || kind, kind === "video" ? "video_" : "");
  const storageRef = ref(storage, `${folder}/${uid}/${name}`);
  const ext = (file.name.split(".").pop() ?? "").toLowerCase();
  const contentType = kind === "file" ? undefined : file.type || `${kind}/${ext || (kind === "image" ? "jpeg" : "mp4")}`;
  await uploadBytes(storageRef, file, contentType ? { contentType } : undefined);
  const url = await getDownloadURL(storageRef);
  const metadata: Data = { file_url: url, file_name: file.name || name, file_size: file.size };
  if (kind !== "file") metadata.mime_type = contentType;
  if (caption.trim()) metadata.caption = caption.trim();
  const content = kind === "file" ? `📎 ${file.name}` : caption.trim() || (kind === "image" ? "📷 Photo" : "🎥 Video");
  await sendMessage(target, uid, content, kind, metadata);
}

/** C-438: a pinned location. */
export async function sendLocation(target: Target, uid: string, lat: number, lng: number, name: string, subtitle: string) {
  await sendMessage(target, uid, name, "location", { latitude: lat, longitude: lng, location_name: name, location_subtitle: subtitle });
}

const messageRef = (chatId: string, id: string): DocumentReference => doc(db, "chats", chatId, "messages", id);

/** C-427: one reaction per person; null removes it. */
export async function setReaction(chatId: string, messageId: string, uid: string, emoji: string | null) {
  await updateDoc(messageRef(chatId, messageId), { [`reactions.${uid}`]: emoji ?? deleteField() });
}

/**
 * C-430: edit own text. The list preview is patched only when the edited
 * message IS the chat's last message (Flutter patches it whenever the last
 * message is the editor's — B-5).
 */
export async function editMessage(chatId: string, message: ChatMessage, content: string) {
  await updateDoc(messageRef(chatId, message.id), { content, is_edited: true, edited_at: serverTimestamp() });
  const chat = await getDoc(doc(db, "chats", chatId));
  const last = chat.data()?.last_message as Data | undefined;
  const lastTime = last?.timestamp && typeof (last.timestamp as { toMillis?: () => number }).toMillis === "function" ? (last.timestamp as { toMillis: () => number }).toMillis() : null;
  if (last && last.sender_id === message.senderId && lastTime !== null && message.timestamp && lastTime === message.timestamp.getTime() && last.content === message.content) {
    await updateDoc(doc(db, "chats", chatId), { "last_message.content": content }).catch(() => undefined);
  }
}

/** Does the chat's stored `last_message` copy describe this message? */
function isStoredLast(last: Data | undefined, message: { senderId: string; content: string; timestamp: Date | null }) {
  const ts = last?.timestamp as { toMillis?: () => number } | undefined;
  const millis = ts && typeof ts.toMillis === "function" ? ts.toMillis() : null;
  return !!last && last.sender_id === message.senderId && millis !== null && !!message.timestamp && millis === message.timestamp.getTime() && last.content === message.content;
}

/**
 * C-431: delete for me (and undo). When the message is the chat's last one,
 * its stored copy is marked too, so the Recent preview falls back to the
 * newest message still visible (C-409) — Flutter never marks the copy, so
 * there the preview keeps showing a message the parent removed.
 */
export async function hideForMe(chatId: string, message: ChatMessage, uid: string, hidden: boolean) {
  await updateDoc(messageRef(chatId, message.id), { [`deleted_for_users.${uid}`]: hidden ? true : deleteField() });
  const chatRef = doc(db, "chats", chatId);
  const chat = await getDoc(chatRef).catch(() => null);
  const update: Data = { [`visibility_updated_at.${uid}`]: serverTimestamp() };
  if (isStoredLast(chat?.data()?.last_message as Data | undefined, message)) update[`last_message.deleted_for_users.${uid}`] = hidden ? true : deleteField();
  await updateDoc(chatRef, update).catch(() => undefined);
}

/** C-431: delete for everyone, then recompute the chat's last message. */
export async function deleteForEveryone(chatId: string, messageId: string, uid: string, name: string) {
  await updateDoc(messageRef(chatId, messageId), {
    content: "",
    message_type: "deleted",
    metadata: {},
    reactions: {},
    is_edited: false,
    edited_at: deleteField(),
    deleted_for_everyone: true,
    deleted_by: uid,
    deleted_by_name: name,
    deleted_by_admin: false,
    deleted_at: serverTimestamp(),
  });
  const newest = await getDocs(query(collection(db, "chats", chatId, "messages"), orderBy("timestamp", "desc"), limit(1)));
  const top = newest.docs[0];
  await updateDoc(doc(db, "chats", chatId), { last_message: top ? top.data() : deleteField(), updated_at: serverTimestamp() });
}

/** C-429: forward a message (same content, type and metadata; files are not re-uploaded). */
export async function forwardMessage(target: Target, uid: string, message: ChatMessage, originalSender: string) {
  await sendMessage(target, uid, message.content, message.type, { ...message.metadata, forwarded: true, original_sender: originalSender });
}

/**
 * C-440 Clear chat. Flutter hard-deletes every message for both sides and
 * fails whenever the other person wrote anything (B-4). Here it removes every
 * message from the parent's own view (the same "delete for me" mark).
 */
export async function clearForMe(chatId: string, uid: string) {
  const snap = await getDocs(collection(db, "chats", chatId, "messages"));
  for (const part of chunks(snap.docs, 450)) {
    const batch = writeBatch(db);
    part.forEach((d) => batch.update(d.ref, { [`deleted_for_users.${uid}`]: true }));
    await batch.commit();
  }
  const chatRef = doc(db, "chats", chatId);
  const chat = await getDoc(chatRef).catch(() => null);
  const update: Data = { [`visibility_updated_at.${uid}`]: serverTimestamp() };
  if (chat?.data()?.last_message) update[`last_message.deleted_for_users.${uid}`] = true;
  await updateDoc(chatRef, update).catch(() => undefined);
}

/** C-440 Block / Unblock: the array on the parent's own user document. */
export async function setBlocked(uid: string, otherId: string, blocked: boolean) {
  await updateDoc(doc(db, "users", uid), { blocked_users: blocked ? arrayUnion(otherId) : arrayRemove(otherId) });
}

/**
 * C-453 Leave Group. Flutter writes the "X left" notice as sender "system",
 * which the rules refuse, so the leave errors out half done (B-7). Here the
 * notice is written as the parent (a system-type message), which the rules
 * allow, before the parent leaves; a sole admin hands admin to the next member.
 */
export async function leaveGroup(chatId: string, uid: string, name: string) {
  const chatRef = doc(db, "chats", chatId);
  const snap = await getDoc(chatRef);
  const data = snap.data() ?? {};
  const participants = ((data.participants as unknown[]) ?? []).map(String);
  const admins = ((data.admin_ids as unknown[]) ?? []).map(String);
  const notice = { sender_id: uid, sender_name: "", content: `${name} left`, timestamp: serverTimestamp(), is_read: false, message_type: "system", metadata: {} };
  await addDoc(collection(db, "chats", chatId, "messages"), notice);
  const update: Data = { participants: arrayRemove(uid), admin_ids: arrayRemove(uid), updated_at: serverTimestamp(), last_message: notice };
  const others = participants.filter((p) => p !== uid);
  if (admins.length === 1 && admins[0] === uid && others.length) {
    await updateDoc(chatRef, { admin_ids: arrayUnion(others[0]) });
  }
  await updateDoc(chatRef, update);
}

/** Group members (C-450…C-452). */
export async function groupMembers(ids: string[]): Promise<ChatPerson[]> {
  const users = await fetchUsers(ids);
  const now = new Date();
  return ids.filter((id) => users.has(id)).map((id) => personFromDoc(id, users.get(id)!, now));
}
