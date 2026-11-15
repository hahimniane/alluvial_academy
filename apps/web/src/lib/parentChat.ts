/**
 * Pure rules behind the parent chat (inventory C-400…C-484): conversation ids,
 * presence, list rows and previews, search, who a parent may message, the
 * relationship banner, message times, deletion windows and mentions. No
 * Firebase imports; each rule mirrors the Dart it is named after:
 *
 *   lib/features/chat/services/chat_service.dart
 *   lib/features/chat/services/chat_permission_service.dart
 *   lib/features/chat/widgets/chat_user_list_item.dart, message_bubble.dart
 *   lib/features/chat/models/chat_user.dart, chat_message.dart
 *   lib/core/utils/presence_utils.dart
 */
import { leaderTitle } from "./leaderTitle.ts";

type Data = Record<string, unknown>;

export const ADMIN_SUPPORT_ID = "admin_support";

const str = (v: unknown) => (v == null ? "" : String(v));
const map = (v: unknown): Data => (v && typeof v === "object" && !Array.isArray(v) ? (v as Data) : {});
const list = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);

function toDate(value: unknown): Date | null {
  if (value && typeof value === "object" && typeof (value as { toDate?: unknown }).toDate === "function") {
    const d = (value as { toDate: () => Date }).toDate();
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

// ─── Ids ───────────────────────────────────────────────────────────────────

/** 1:1 chat id = the two uids sorted and joined by `_`. */
export const directChatId = (a: string, b: string) => [a, b].sort().join("_");
/** The member's Admin Support thread id. */
export const supportChatId = (uid: string) => [uid, ADMIN_SUPPORT_ID].sort().join("_");

// ─── People ────────────────────────────────────────────────────────────────

export type ChatPerson = {
  id: string;
  name: string;
  email: string;
  phone: string;
  profilePicture: string | null;
  role: string | null;
  jobTitle: string | null;
  isAdminTeacher: boolean;
  isOnline: boolean;
  lastSeen: Date | null;
};

/** PresenceUtils.resolvePresence: online = flag AND seen in the last 2 minutes. */
export function resolvePresence(data: Data, now: Date) {
  const lastSeen = toDate(data.last_seen) ?? toDate(data.last_login);
  const recent = lastSeen !== null && now.getTime() - lastSeen.getTime() <= 2 * 60_000;
  const flag = data.is_online;
  const isOnline = typeof flag === "boolean" ? flag && (recent || lastSeen === null) : recent;
  return { isOnline, lastSeen };
}

/** ChatService._createIndividualChatUser. */
export function personFromDoc(id: string, data: Data, now: Date): ChatPerson {
  const presence = resolvePresence(data, now);
  const role = data.user_type == null ? null : str(data.user_type);
  return {
    id,
    name: `${str(data.first_name ?? "")} ${str(data.last_name ?? "")}`.trim(),
    email: str(data.email ?? data["e-mail"] ?? ""),
    phone: str(data.phone_number ?? data.phoneNumber ?? data.mobile_phone ?? data.mobilePhone ?? data.phone ?? ""),
    profilePicture: (data.profile_picture_url ?? data.profile_picture) ? str(data.profile_picture_url ?? data.profile_picture) : null,
    role,
    jobTitle: data.title == null ? null : str(data.title),
    isAdminTeacher: data.is_admin_teacher === true,
    isOnline: presence.isOnline,
    lastSeen: presence.lastSeen,
  };
}

/** ChatUser.displayName: the name, else the e-mail. */
export const displayName = (p: { name: string; email: string }) => (p.name ? p.name : p.email);

/** ChatUser.initials. */
export function initials(p: { name: string; email: string }) {
  if (!p.name) return p.email ? p.email[0].toUpperCase() : "?";
  const parts = p.name.trim().split(" ");
  if (parts.length >= 2 && parts[0] && parts[1]) return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
  return parts[0][0].toUpperCase();
}

/** The chip under a name: leader title, else the role label. */
export function roleLabel(role: string | null, jobTitle: string | null) {
  const title = leaderTitle(role, jobTitle);
  if (title) return title;
  switch ((role ?? "").toLowerCase()) {
    case "admin":
      return "Administrator";
    case "teacher":
      return "Teacher";
    case "student":
      return "Student";
    case "parent":
      return "Parent";
    case "group":
      return "Group Chat";
    default:
      return role ?? "";
  }
}

export function roleColor(role: string | null) {
  switch ((role ?? "").toLowerCase()) {
    case "admin":
      return "#DC2626";
    case "teacher":
      return "#0386FF";
    case "student":
      return "#059669";
    case "parent":
      return "#F59E0B";
    default:
      return "#6B7280";
  }
}

/** ChatPermissionService._isPrivilegedAdmin. */
export function isPrivilegedAdmin(data: Data) {
  const role = str(data.user_type).toLowerCase();
  return role === "admin" || role === "super_admin" || role === "ceo" || role === "founder" || (role === "teacher" && data.is_admin_teacher === true);
}

// ─── List rows ─────────────────────────────────────────────────────────────

export type ChatMessage = {
  id: string;
  senderId: string;
  senderName: string;
  senderPicture: string | null;
  content: string;
  timestamp: Date | null;
  isRead: boolean;
  type: string;
  metadata: Data;
  reactions: Record<string, string>;
  isEdited: boolean;
  deletedForEveryone: boolean;
  deletedBy: string;
  deletedByName: string;
  deletedByAdmin: boolean;
  hiddenFor: Record<string, unknown>;
};

/** ChatMessage.fromMap (the fields the parent screens use). */
export function parseMessage(id: string, data: Data): ChatMessage {
  return {
    id,
    senderId: str(data.sender_id ?? data.senderId ?? ""),
    senderName: str(data.sender_name ?? data.senderName ?? ""),
    senderPicture: data.sender_profile_picture ? str(data.sender_profile_picture) : null,
    content: str(data.content ?? ""),
    timestamp: toDate(data.timestamp),
    isRead: data.is_read === true,
    type: str(data.message_type ?? data.messageType ?? "text") || "text",
    metadata: map(data.metadata),
    reactions: Object.fromEntries(Object.entries(map(data.reactions)).map(([k, v]) => [k, str(v)])),
    isEdited: data.is_edited === true,
    deletedForEveryone: data.deleted_for_everyone === true || data.message_type === "deleted",
    deletedBy: str(data.deleted_by ?? ""),
    deletedByName: str(data.deleted_by_name ?? ""),
    deletedByAdmin: data.deleted_by_admin === true,
    hiddenFor: map(data.deleted_for_users),
  };
}

export const hiddenForMe = (m: Pick<ChatMessage, "hiddenFor">, uid: string) => uid in m.hiddenFor;

/** `_recentMessagePreview` / `deletedPreviewText`. */
export function previewText(m: Pick<ChatMessage, "content" | "deletedForEveryone" | "deletedBy" | "deletedByName" | "deletedByAdmin">, uid: string) {
  if (!m.deletedForEveryone) return m.content;
  if (m.deletedBy === uid) return "You deleted this message";
  if (m.deletedByAdmin && m.deletedByName) return `This message was deleted by admin ${m.deletedByName}`;
  return "This message was deleted";
}

/** Unread rule for a parent (`isIncomingFor`): not read, not mine, not hidden for me. */
export const countsUnread = (m: ChatMessage, uid: string) => !m.isRead && m.senderId !== uid && !hiddenForMe(m, uid);

export type ChatRow = {
  chatId: string;
  kind: "direct" | "group" | "support";
  otherId: string | null;
  title: string;
  email: string;
  phone: string;
  picture: string | null;
  role: string | null;
  jobTitle: string | null;
  isOnline: boolean;
  lastSeen: Date | null;
  preview: string;
  time: Date | null;
  unread: number;
  memberCount: number;
  groupDescription: string;
  participants: string[];
};

export type ChatDoc = { id: string; data: Data };

/** What `_processChatSnapshot` needs for one chat besides its document. */
export type ChatExtras = { unread: number; lastVisible: ChatMessage | null; other: ChatPerson | null };

/** Whether a chat appears in Recent at all (it needs a `last_message` map). */
export const hasRecentMessage = (data: Data) => !!data.last_message && typeof data.last_message === "object";

/** `_extractVisibleLastMessage`: the stored last message unless hidden for me. */
export function visibleStoredLast(data: Data, uid: string): ChatMessage | null {
  if (!hasRecentMessage(data)) return null;
  const m = parseMessage("last", map(data.last_message));
  return hiddenForMe(m, uid) ? null : m;
}

/** One Recent row (or null when Flutter drops it). */
export function buildRow(chat: ChatDoc, uid: string, extras: ChatExtras): ChatRow | null {
  const participants = list(chat.data.participants);
  const last = extras.lastVisible;
  if (!last) return null;
  const time = last.timestamp ?? toDate(chat.data.created_at);
  const preview = previewText(last, uid);
  if (chat.data.chat_type === "group") {
    return {
      chatId: chat.id,
      kind: "group",
      otherId: null,
      title: str(chat.data.group_name ?? "") || "Unnamed Group",
      email: str(chat.data.group_description ?? ""),
      phone: "",
      picture: null,
      role: "group",
      jobTitle: null,
      isOnline: false,
      lastSeen: null,
      preview,
      time,
      unread: extras.unread,
      memberCount: participants.length,
      groupDescription: str(chat.data.group_description ?? ""),
      participants,
    };
  }
  if (participants.includes(ADMIN_SUPPORT_ID)) {
    return {
      chatId: chat.id,
      kind: "support",
      otherId: ADMIN_SUPPORT_ID,
      title: "Admin Support",
      email: "",
      phone: "",
      picture: null,
      role: "admin",
      jobTitle: null,
      isOnline: false,
      lastSeen: null,
      preview,
      time,
      unread: extras.unread,
      memberCount: 0,
      groupDescription: "",
      participants,
    };
  }
  const other = extras.other;
  if (!other) return null;
  return {
    chatId: chat.id,
    kind: "direct",
    otherId: other.id,
    title: displayName(other),
    email: other.email,
    phone: other.phone,
    picture: other.profilePicture,
    role: other.role,
    jobTitle: other.jobTitle,
    isOnline: other.isOnline,
    lastSeen: other.lastSeen,
    preview,
    time,
    unread: extras.unread,
    memberCount: 0,
    groupDescription: "",
    participants,
  };
}

export const sortRows = (rows: ChatRow[]) => [...rows].sort((a, b) => (b.time?.getTime() ?? 0) - (a.time?.getTime() ?? 0));

/** `_formatLastMessageTime`: now / Nm / Nh / Nd / D/M. */
export function listTime(time: Date, now: Date) {
  const minutes = Math.floor((now.getTime() - time.getTime()) / 60_000);
  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d`;
  return `${time.getDate()}/${time.getMonth() + 1}`;
}

/** `_formatLastSeen` (shown as "Last sent …", as Flutter words it). */
export function lastSeenText(time: Date, now: Date) {
  const minutes = Math.floor((now.getTime() - time.getTime()) / 60_000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hr ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} days ago`;
  return `on ${time.getDate()}/${time.getMonth() + 1}`;
}

export const unreadLabel = (n: number) => (n > 99 ? "99+" : String(n));

// ─── Search (C-411, app_search.dart) ───────────────────────────────────────

const normalize = (s: string) => s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/\s+/g, " ").trim();

/** Name contains, e-mail contains, id contains, or a phone match for ≥ 7 digits. */
export function matchesSearch(row: { title: string; email: string; id: string; phone: string }, query: string) {
  const q = normalize(query);
  if (!q) return true;
  if (normalize(row.title).includes(q)) return true;
  if (row.email.toLowerCase().includes(q)) return true;
  if (row.id.toLowerCase().includes(q)) return true;
  const digits = query.replace(/\D/g, "");
  if (digits.length >= 7) {
    const phone = row.phone.replace(/\D/g, "");
    if (phone && (phone.includes(digits) || digits.includes(phone.slice(-9)))) return true;
  }
  return false;
}

/** The Admin Support card stays when the query is part of "admin support". */
export const supportCardMatches = (query: string) => "admin support".includes(query.trim().toLowerCase());

// ─── Who a parent may message (C-416, C-419) ───────────────────────────────

/**
 * `canMessage(parent, other)`: a privileged admin always; a teacher with an
 * active teaching relationship to one of the parent's children; otherwise no.
 * `otherHasWritten` is the conversation's inbound unlock (ChatScreen).
 */
export function parentCanMessage(other: Data | null, teachesMyChild: boolean, otherHasWritten: boolean) {
  if (otherHasWritten) return true;
  if (!other) return false;
  if (isPrivilegedAdmin(other)) return true;
  if (str(other.user_type).toLowerCase() === "teacher") return teachesMyChild;
  return false;
}

/**
 * The strip above the composer (`getRelationshipContext`). Flutter shows the
 * teacher-side wording "Parent of your student" to the parent; the parent's
 * own wording is used instead ("Your child's teacher").
 */
export function relationshipBanner(other: Data | null, teachesMyChild: boolean, otherHasWritten: boolean): string | null {
  if (!other) return null;
  const role = str(other.user_type).toLowerCase();
  if (role === "admin" || role === "super_admin") return "Administrator";
  if (role === "teacher" && teachesMyChild) return "Your child's teacher";
  if (otherHasWritten) {
    if (isPrivilegedAdmin(other)) return "Administrator";
    if (role === "teacher") return "Staff / coach";
    return "Conversation";
  }
  return null;
}

/** `hasActiveTeachingRelationship`: a non-cancelled class ending in the last 30 days or later. */
export function teachesActively(shifts: Array<{ teacherId: string; status: string; shiftEnd: Date | null }>, teacherId: string, now: Date) {
  const cutoff = now.getTime() - 30 * 86_400_000;
  return shifts.some((s) => s.teacherId === teacherId && s.status !== "cancelled" && s.shiftEnd !== null && s.shiftEnd.getTime() > cutoff);
}

/** Teachers of the parent's children for the Contacts tab (C-414). */
export function activeTeacherIds(shifts: Array<{ teacherId: string; status: string; shiftEnd: Date | null }>, now: Date) {
  const cutoff = now.getTime() - 30 * 86_400_000;
  const ids = new Set<string>();
  for (const s of shifts) if (s.teacherId && s.status !== "cancelled" && s.shiftEnd && s.shiftEnd.getTime() > cutoff) ids.add(s.teacherId);
  return [...ids];
}

/** Children for chat: `children_ids`, and only when empty the guardian_ids students. */
export const chatChildrenIds = (childrenIds: string[], guardianStudents: string[]) => (childrenIds.length ? childrenIds : guardianStudents);

// ─── Messages ──────────────────────────────────────────────────────────────

/** Bubble time: "HH:mm" today, "Yesterday HH:mm", else "D/M HH:mm" (24 h). */
export function bubbleTime(t: Date, now: Date) {
  const hm = `${String(t.getHours()).padStart(2, "0")}:${String(t.getMinutes()).padStart(2, "0")}`;
  const day = new Date(t.getFullYear(), t.getMonth(), t.getDate()).getTime();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  if (day === today) return hm;
  if (day === new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1).getTime()) return `Yesterday ${hm}`;
  return `${t.getDate()}/${t.getMonth() + 1} ${hm}`;
}

/** Delete for everyone: own, not system, not already deleted, sent within 2 days. */
export function canDeleteForEveryone(m: ChatMessage, uid: string, now: Date) {
  if (m.senderId !== uid || m.type === "system" || m.deletedForEveryone || !m.timestamp) return false;
  return now.getTime() - m.timestamp.getTime() <= 2 * 86_400_000;
}

/** Edit: own, text, not deleted. */
export const canEdit = (m: ChatMessage, uid: string) => m.senderId === uid && m.type === "text" && !m.deletedForEveryone;

export const QUICK_REACTIONS = ["👍", "❤️", "😂", "🎉", "😮", "😢"] as const;

/** One reaction per person: the same emoji again removes it, another replaces it. */
export function nextReaction(current: string | undefined, chosen: string): string | null {
  return current === chosen ? null : chosen;
}

/** Reaction chips: emoji → count, in first-seen order. */
export function reactionCounts(reactions: Record<string, string>) {
  const counts = new Map<string, number>();
  for (const emoji of Object.values(reactions)) if (emoji) counts.set(emoji, (counts.get(emoji) ?? 0) + 1);
  return [...counts.entries()];
}

/** Mention tokens (`@Name`, `@All`) split out of message text for styling. */
export function splitMentions(text: string): Array<{ text: string; mention: boolean }> {
  const out: Array<{ text: string; mention: boolean }> = [];
  const re = /@(\w[\w\s]*?)(?=\s@|\s[^@]|$)/g;
  let last = 0;
  for (const m of text.matchAll(re)) {
    const start = m.index ?? 0;
    if (start > last) out.push({ text: text.slice(last, start), mention: false });
    out.push({ text: m[0], mention: true });
    last = start + m[0].length;
  }
  if (last < text.length) out.push({ text: text.slice(last), mention: false });
  return out;
}

/** Document picker whitelist (C-437). */
export const DOCUMENT_EXTENSIONS = [".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".zip", ".rar"];

/** `{epochMs}_{name}` with characters a Storage path should not carry replaced. */
export function storageFileName(now: number, name: string, prefix = "") {
  const safe = name.replace(/[^\w.\-]+/g, "_").slice(-120) || "file";
  return `${prefix}${now}_${safe}`;
}

/** Human file size for the document card. */
export function fileSize(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

/** Google Maps link for a pinned location (web). */
export const mapsLink = (lat: number, lng: number) => `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
