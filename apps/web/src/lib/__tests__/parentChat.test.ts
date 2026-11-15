import assert from "node:assert/strict";
import { test } from "node:test";
import {
  activeTeacherIds,
  bubbleTime,
  buildRow,
  canDeleteForEveryone,
  canEdit,
  chatChildrenIds,
  countsUnread,
  directChatId,
  displayName,
  initials,
  isPrivilegedAdmin,
  listTime,
  lastSeenText,
  matchesSearch,
  nextReaction,
  parentCanMessage,
  parseMessage,
  personFromDoc,
  previewText,
  reactionCounts,
  relationshipBanner,
  resolvePresence,
  roleLabel,
  sortRows,
  splitMentions,
  storageFileName,
  supportCardMatches,
  supportChatId,
  teachesActively,
  unreadLabel,
  visibleStoredLast,
} from "../parentChat.ts";
import { PARENT_ROUTES, PARENT_WEB_SCREENS, isPushedParentPage } from "../parentWeb.ts";

const ts = (d: Date) => ({ toDate: () => d });
const NOW = new Date(2026, 10, 18, 10, 0, 0);
const minsAgo = (m: number) => new Date(NOW.getTime() - m * 60_000);

test("ids: sorted pairs and the support thread", () => {
  assert.equal(directChatId("zeta", "alpha"), "alpha_zeta");
  assert.equal(supportChatId("p1"), "admin_support_p1");
  assert.equal(supportChatId("zz"), "admin_support_zz");
});

test("presence: online flag counts only when seen in the last 2 minutes", () => {
  assert.equal(resolvePresence({ is_online: true, last_seen: ts(minsAgo(1)) }, NOW).isOnline, true);
  assert.equal(resolvePresence({ is_online: true, last_seen: ts(minsAgo(5)) }, NOW).isOnline, false);
  assert.equal(resolvePresence({ is_online: true }, NOW).isOnline, true);
  assert.equal(resolvePresence({ last_login: ts(minsAgo(1)) }, NOW).isOnline, true);
  assert.equal(resolvePresence({ is_online: false, last_seen: ts(minsAgo(1)) }, NOW).isOnline, false);
});

test("people: name or e-mail, initials, role chip with leader titles", () => {
  const p = personFromDoc("u", { first_name: "Fatou", last_name: "Diallo", "e-mail": "f@x.org", user_type: "admin", title: "Head of Studies", profile_picture: "https://p" }, NOW);
  assert.equal(displayName(p), "Fatou Diallo");
  assert.equal(initials(p), "FD");
  assert.equal(p.profilePicture, "https://p");
  assert.equal(roleLabel(p.role, p.jobTitle), "Head of Studies");
  assert.equal(roleLabel("admin", "Administrator"), "Administrator");
  assert.equal(roleLabel("teacher", "Coach"), "Teacher");
  assert.equal(displayName({ name: "", email: "a@b.c" }), "a@b.c");
  assert.equal(initials({ name: "", email: "a@b.c" }), "A");
  assert.equal(isPrivilegedAdmin({ user_type: "founder" }), true);
  assert.equal(isPrivilegedAdmin({ user_type: "teacher", is_admin_teacher: true }), true);
  assert.equal(isPrivilegedAdmin({ user_type: "teacher" }), false);
});

test("previews: deleted variants and the hidden-for-me fallback", () => {
  const base = { content: "hello", deletedForEveryone: false, deletedBy: "", deletedByName: "", deletedByAdmin: false };
  assert.equal(previewText(base, "me"), "hello");
  assert.equal(previewText({ ...base, deletedForEveryone: true, deletedBy: "me" }, "me"), "You deleted this message");
  assert.equal(previewText({ ...base, deletedForEveryone: true, deletedBy: "a", deletedByAdmin: true, deletedByName: "Awa" }, "me"), "This message was deleted by admin Awa");
  assert.equal(previewText({ ...base, deletedForEveryone: true, deletedBy: "a" }, "me"), "This message was deleted");
  assert.equal(visibleStoredLast({ last_message: { content: "x", deleted_for_users: { me: true } } }, "me"), null);
  assert.equal(visibleStoredLast({ last_message: { content: "x" } }, "me")?.content, "x");
  assert.equal(visibleStoredLast({}, "me"), null);
});

test("rows: groups, support, 1:1 (dropped when the other user is gone), newest first", () => {
  const last = parseMessage("l", { content: "hi", timestamp: ts(minsAgo(3)) });
  const group = buildRow({ id: "g", data: { chat_type: "group", group_name: "", group_description: "Parents", participants: ["me", "a", "b"] } }, "me", { unread: 2, lastVisible: last, other: null });
  assert.equal(group?.title, "Unnamed Group");
  assert.equal(group?.memberCount, 3);
  const support = buildRow({ id: "admin_support_me", data: { participants: ["me", "admin_support"] } }, "me", { unread: 0, lastVisible: last, other: null });
  assert.equal(support?.title, "Admin Support");
  assert.equal(support?.role, "admin");
  assert.equal(buildRow({ id: "a_me", data: { participants: ["me", "a"] } }, "me", { unread: 0, lastVisible: last, other: null }), null);
  assert.equal(buildRow({ id: "a_me", data: { participants: ["me", "a"] } }, "me", { unread: 0, lastVisible: null, other: personFromDoc("a", {}, NOW) }), null);
  const older = { ...group!, chatId: "old", time: minsAgo(60) };
  assert.deepEqual(sortRows([older, group!]).map((r) => r.chatId), ["g", "old"]);
});

test("unread: not read, not mine, not hidden for me; 99+", () => {
  assert.equal(countsUnread(parseMessage("a", { sender_id: "x", is_read: false }), "me"), true);
  assert.equal(countsUnread(parseMessage("b", { sender_id: "me", is_read: false }), "me"), false);
  assert.equal(countsUnread(parseMessage("c", { sender_id: "x", is_read: false, deleted_for_users: { me: true } }), "me"), false);
  assert.equal(countsUnread(parseMessage("d", { sender_id: "x", is_read: true }), "me"), false);
  assert.equal(unreadLabel(120), "99+");
});

test("list time and last seen wording", () => {
  assert.equal(listTime(new Date(NOW.getTime() - 20_000), NOW), "now");
  assert.equal(listTime(minsAgo(5), NOW), "5m");
  assert.equal(listTime(minsAgo(180), NOW), "3h");
  assert.equal(listTime(minsAgo(60 * 24 * 3), NOW), "3d");
  assert.equal(listTime(new Date(2026, 9, 2), NOW), "2/10");
  assert.equal(lastSeenText(minsAgo(12), NOW), "12 min ago");
  assert.equal(lastSeenText(minsAgo(60 * 24 * 10), NOW), "on 8/11");
});

test("search: name, e-mail, id, phone (7+ digits); support card", () => {
  const row = { title: "Aïcha Bah", email: "aicha@x.org", id: "uid123", phone: "+1 (646) 555-0199" };
  assert.equal(matchesSearch(row, "aicha"), true);
  assert.equal(matchesSearch(row, "X.ORG"), true);
  assert.equal(matchesSearch(row, "uid1"), true);
  assert.equal(matchesSearch(row, "6465550199"), true);
  assert.equal(matchesSearch(row, "555"), false);
  assert.equal(supportCardMatches("supp"), true);
  assert.equal(supportCardMatches("teacher"), false);
});

test("who a parent may message: admins, teachers of their children, or after the other wrote", () => {
  assert.equal(parentCanMessage({ user_type: "ceo" }, false, false), true);
  assert.equal(parentCanMessage({ user_type: "teacher" }, true, false), true);
  assert.equal(parentCanMessage({ user_type: "teacher" }, false, false), false);
  assert.equal(parentCanMessage({ user_type: "parent" }, false, false), false);
  assert.equal(parentCanMessage({ user_type: "student" }, false, true), true, "inbound unlock");
  assert.equal(relationshipBanner({ user_type: "admin" }, false, false), "Administrator");
  assert.equal(relationshipBanner({ user_type: "teacher" }, true, false), "Your child's teacher");
  assert.equal(relationshipBanner({ user_type: "teacher" }, false, true), "Staff / coach");
  assert.equal(relationshipBanner({ user_type: "teacher" }, false, false), null);
});

test("teaching relationship: not cancelled, ending in the last 30 days or later; children_ids first", () => {
  const shifts = [
    { teacherId: "t1", status: "completed", shiftEnd: minsAgo(60 * 24 * 10) },
    { teacherId: "t2", status: "cancelled", shiftEnd: minsAgo(-60) },
    { teacherId: "t3", status: "scheduled", shiftEnd: minsAgo(60 * 24 * 40) },
    { teacherId: "t4", status: "scheduled", shiftEnd: null },
  ];
  assert.deepEqual(activeTeacherIds(shifts, NOW), ["t1"]);
  assert.equal(teachesActively(shifts, "t1", NOW), true);
  assert.equal(teachesActively(shifts, "t2", NOW), false);
  assert.deepEqual(chatChildrenIds(["c1"], ["c2"]), ["c1"]);
  assert.deepEqual(chatChildrenIds([], ["c2"]), ["c2"]);
});

test("bubble times, edit and the 2-day delete window", () => {
  assert.equal(bubbleTime(new Date(2026, 10, 18, 9, 5), NOW), "09:05");
  assert.equal(bubbleTime(new Date(2026, 10, 17, 21, 30), NOW), "Yesterday 21:30");
  assert.equal(bubbleTime(new Date(2026, 10, 3, 8, 0), NOW), "3/11 08:00");
  const mine = parseMessage("m", { sender_id: "me", message_type: "text", timestamp: ts(minsAgo(60)) });
  assert.equal(canDeleteForEveryone(mine, "me", NOW), true);
  assert.equal(canDeleteForEveryone({ ...mine, timestamp: minsAgo(60 * 49) }, "me", NOW), false);
  assert.equal(canDeleteForEveryone({ ...mine, senderId: "x" }, "me", NOW), false);
  assert.equal(canEdit(mine, "me"), true);
  assert.equal(canEdit({ ...mine, type: "image" }, "me"), false);
});

test("reactions toggle, chips count; mentions split; storage names", () => {
  assert.equal(nextReaction("👍", "👍"), null);
  assert.equal(nextReaction("👍", "❤️"), "❤️");
  assert.deepEqual(reactionCounts({ a: "👍", b: "❤️", c: "👍" }), [["👍", 2], ["❤️", 1]]);
  assert.deepEqual(splitMentions("Hi @All please"), [{ text: "Hi ", mention: false }, { text: "@All", mention: true }, { text: " please", mention: false }]);
  assert.equal(storageFileName(5, "my file (1).pdf"), "5_my_file_1_.pdf");
  assert.equal(storageFileName(5, "clip.mp4", "video_"), "video_5_clip.mp4");
});

test("chat page in the shell, conversations pushed over it", () => {
  assert.equal(PARENT_WEB_SCREENS.has("chat"), true);
  assert.equal(isPushedParentPage("/parent/chat/"), false);
  assert.equal(isPushedParentPage("/parent/chat/conversation/"), true);
  assert.equal(PARENT_ROUTES.conversation({ id: "a_b", kind: "direct", with: "b" }), "/parent/chat/conversation/?id=a_b&kind=direct&with=b");
});
