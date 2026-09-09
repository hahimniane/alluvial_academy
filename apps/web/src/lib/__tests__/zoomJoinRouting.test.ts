import assert from "node:assert/strict";
import { test } from "node:test";
import { buildDesktopZoomUrl, desktopZoomDisplayName, prefersDesktopZoomApp } from "../zoomJoinRouting.ts";

const DESKTOP = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36";
const PHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1";

const teacher = {
  meetingNumber: "812 3456 7890",
  password: "pass1",
  displayName: "Chernor Jalloh",
  routingDisplayName: "Chernor | Elias Kouyateh",
  routingMode: "hub",
  userRole: "teacher",
  autoJoinBreakoutRoom: true,
};

test("a teacher on a desktop browser is sent to the Zoom app", () => {
  assert.equal(prefersDesktopZoomApp(teacher, DESKTOP), true);
});

test("students and parents always stay on the site", () => {
  for (const role of ["student", "parent", "circle_member", ""]) {
    assert.equal(prefersDesktopZoomApp({ ...teacher, userRole: role }, DESKTOP), false);
  }
});

test("admins and admin-teachers host too", () => {
  for (const role of ["admin", "super_admin", "admin_teacher", "TEACHER"]) {
    assert.equal(prefersDesktopZoomApp({ ...teacher, userRole: role }, DESKTOP), true);
  }
});

test("a teacher on a phone stays in the browser", () => {
  assert.equal(prefersDesktopZoomApp(teacher, PHONE), false);
});

test("a teacher whose class is not hub-routed stays in the browser", () => {
  assert.equal(prefersDesktopZoomApp({ ...teacher, routingMode: "direct" }, DESKTOP), false);
  assert.equal(prefersDesktopZoomApp({ ...teacher, autoJoinBreakoutRoom: false }, DESKTOP), false);
  assert.equal(prefersDesktopZoomApp({ ...teacher, routingDisplayName: "  " }, DESKTOP), false);
});

test("the Zoom app link carries the meeting, password and routed name", () => {
  const url = buildDesktopZoomUrl(teacher);
  assert.ok(url.startsWith("zoommtg://zoom.us/join?"));
  const q = new URLSearchParams(url.split("?")[1]);
  assert.equal(q.get("confno"), "81234567890", "spaces stripped from the meeting number");
  assert.equal(q.get("pwd"), "pass1");
  assert.equal(q.get("uname"), "Chernor | Elias Kouyateh");
  assert.equal(q.get("action"), "join");
});

test("no meeting number means no desktop link, so the browser join is used", () => {
  assert.equal(buildDesktopZoomUrl({ ...teacher, meetingNumber: "" }), "");
});

test("the display name falls back the way Flutter does", () => {
  assert.equal(desktopZoomDisplayName({ routingDisplayName: "A", nativeDisplayName: "B", displayName: "C" }), "A");
  assert.equal(desktopZoomDisplayName({ nativeDisplayName: "B", displayName: "C" }), "B");
  assert.equal(desktopZoomDisplayName({ displayName: "C" }), "C");
  assert.equal(desktopZoomDisplayName({}), "Participant");
});
