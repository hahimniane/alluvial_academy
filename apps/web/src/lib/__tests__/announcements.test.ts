import assert from "node:assert/strict";
import { test } from "node:test";
import { activeAnnouncements, audienceOf, isActiveAnnouncement, nextUnseenPinned, parseAnnouncement, type Announcement } from "../announcements.ts";

const NOW = new Date("2026-11-26T12:00:00Z");
const day = (offset: number) => new Date(NOW.getTime() + offset * 86_400_000);
const ts = (date: Date) => ({ toDate: () => date });

function item(id: string, extra: Partial<Announcement> = {}): Announcement {
  return {
    id,
    title: `Title ${id}`,
    body: "",
    audience: ["teacher", "student", "parent", "admin"],
    pinned: false,
    expiresAt: null,
    createdAt: day(-1),
    createdByName: "",
    status: "published",
    ...extra,
  };
}

test("parses a document, keeping line breaks in the body", () => {
  const parsed = parseAnnouncement("a1", {
    title: "  Bayana update ",
    body: "Line one\nLine two\n",
    audience: ["Parent", "teacher", "circle_member", "parent"],
    pinned: true,
    expires_at: ts(day(3)),
    created_at: ts(day(-2)),
    created_by_name: "Office",
    status: "published",
  });
  assert.ok(parsed);
  assert.equal(parsed.title, "Bayana update");
  assert.equal(parsed.body, "Line one\nLine two");
  assert.deepEqual(parsed.audience, ["teacher", "parent"]);
  assert.equal(parsed.pinned, true);
  assert.equal(parsed.expiresAt?.getTime(), day(3).getTime());
  assert.equal(parsed.createdByName, "Office");
});

test("drops a document without a title and treats unknown status as archived", () => {
  assert.equal(parseAnnouncement("x", { body: "no title" }), null);
  assert.equal(parseAnnouncement("y", { title: "t", status: "draft" })?.status, "archived");
  assert.deepEqual(audienceOf("teacher"), []);
});

test("expired and archived announcements are not active", () => {
  assert.equal(isActiveAnnouncement(item("open"), NOW), true);
  assert.equal(isActiveAnnouncement(item("future", { expiresAt: day(1) }), NOW), true);
  assert.equal(isActiveAnnouncement(item("past", { expiresAt: day(-1) }), NOW), false);
  assert.equal(isActiveAnnouncement(item("now", { expiresAt: NOW }), NOW), false);
  assert.equal(isActiveAnnouncement(item("gone", { status: "archived" }), NOW), false);
});

test("lists pinned first, then newest first, for the given role only", () => {
  const list = activeAnnouncements(
    [
      item("old", { createdAt: day(-5) }),
      item("new", { createdAt: day(-1) }),
      item("pinnedOld", { pinned: true, createdAt: day(-9) }),
      item("pinnedNew", { pinned: true, createdAt: day(-3) }),
      item("parentsOnly", { audience: ["parent"], createdAt: day(0) }),
      item("expired", { expiresAt: day(-1) }),
      item("undated", { createdAt: null }),
    ],
    "teacher",
    NOW,
  );
  assert.deepEqual(
    list.map((entry) => entry.id),
    ["pinnedNew", "pinnedOld", "new", "old", "undated"],
  );
});

test("pops up the newest unseen pinned announcement", () => {
  const list = activeAnnouncements(
    [item("plain"), item("p1", { pinned: true, createdAt: day(-4) }), item("p2", { pinned: true, createdAt: day(-2) })],
    "student",
    NOW,
  );
  assert.equal(nextUnseenPinned(list, new Set())?.id, "p2");
  assert.equal(nextUnseenPinned(list, new Set(["p2"]))?.id, "p1");
  assert.equal(nextUnseenPinned(list, new Set(["p1", "p2"])), null);
});
