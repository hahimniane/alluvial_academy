import assert from "node:assert/strict";
import { test } from "node:test";
import { classGroupKey, groupClasses, historyGroups, joinCheck, joinErrorKind, upcomingGroups, zoomInfoUsable, zoomMeetingUrl } from "../parentClasses.ts";
import { parseShift, type ParentShift } from "../parentHome.ts";
import { PARENT_ROUTES, PARENT_WEB_SCREENS, activeParentItemId, isPushedParentPage } from "../parentWeb.ts";

const ts = (d: Date) => ({ toDate: () => d });
const NOW = new Date(2026, 10, 18, 10, 0, 0);
const at = (minutes: number) => new Date(NOW.getTime() + minutes * 60_000);

function shift(id: string, startMin: number, extra: Record<string, unknown> = {}, length = 60): ParentShift {
  const parsed = parseShift(id, {
    shift_start: ts(at(startMin)),
    shift_end: ts(at(startMin + length)),
    created_at: ts(at(-10_000)),
    student_ids: ["c1"],
    teacher_id: "t1",
    status: "scheduled",
    ...extra,
  });
  assert.ok(parsed);
  return parsed;
}

test("video provider follows TeachingShift: teaching with students defaults to zoom", () => {
  assert.equal(shift("a", 0).videoProvider, "zoom");
  assert.equal(shift("b", 0, { video_provider: " RealtimeKit " }).videoProvider, "realtimekit");
  assert.equal(shift("c", 0, { video_provider: "other" }).videoProvider, "zoom");
  assert.equal(shift("d", 0, { student_ids: [] }).videoProvider, "realtimekit");
  assert.equal(shift("e", 0, { shift_category: "leadership" }).videoProvider, "realtimekit");
});

test("group key: livekit room, then zoom meeting + room, then hub + room, then teacher/subject/time", () => {
  assert.equal(classGroupKey(shift("a", 0, { livekit_room_name: " r1 ", zoom_meeting_id: "z" })), "livekit:r1");
  assert.equal(classGroupKey(shift("b", 0, { zoom_meeting_id: "z1", breakout_room_name: "Room 3" })), "zoom:z1:Room 3");
  assert.equal(classGroupKey(shift("c", 0, { zoom_meeting_id: "z1", breakoutRoomKey: "k9", breakout_room_name: "Room 3" })), "zoom:z1:k9");
  assert.equal(classGroupKey(shift("d", 0, { hubMeetingId: "h1", breakout_room_key: "k2" })), "hub:h1:k2");
  const fb = shift("e", 0, { subject_display_name: "Arabic" });
  assert.equal(classGroupKey(fb), `fallback:t1:arabic:${fb.shiftStart.getTime()}:${fb.shiftEnd.getTime()}`);
  assert.match(classGroupKey(shift("f", 0, { subject_id: "s-1", subject_display_name: "Arabic" })), /^fallback:t1:s-1:/);
  assert.match(classGroupKey(shift("g", 0)), /^fallback:t1:quranStudies:/);
});

test("siblings in the same room share one card, names in child order; a joinable copy wins", () => {
  const later = shift("x1", 120, { zoom_meeting_id: "z", breakout_room_name: "R" });
  const joinable = shift("x2", 5, { zoom_meeting_id: "z", breakout_room_name: "R" });
  const other = shift("y", 300, { zoom_meeting_id: "z", breakout_room_name: "S" });
  const groups = groupClasses(
    [
      { childId: "c1", childName: "Amadou", shifts: [later, other] },
      { childId: "c2", childName: "  ", shifts: [joinable] },
    ],
    NOW,
  );
  assert.equal(groups.length, 2);
  assert.deepEqual(groups[0].childNames, ["Amadou", "c2"]);
  assert.equal(groups[0].shift.id, "x2", "the joinable class replaces the kept one");
  assert.deepEqual(groups[1].childIds, ["c1"]);
});

test("Upcoming: live first, then joinable, then start; History newest first; cancelled kept", () => {
  const groups = groupClasses(
    [
      {
        childId: "c1",
        childName: "A",
        shifts: [
          shift("later", 180),
          shift("soon", 5),
          shift("live", -30, { status: "active" }),
          shift("cancelled", 60, { status: "cancelled" }),
          shift("done1", -300, { status: "completed" }),
          shift("done2", -120, { status: "missed" }),
        ],
      },
    ],
    NOW,
  );
  assert.deepEqual(upcomingGroups(groups, NOW).map((g) => g.shift.id), ["live", "soon", "cancelled", "later"]);
  assert.deepEqual(historyGroups(groups, NOW).map((g) => g.shift.id), ["done2", "done1"]);
});

test("join checks: no video, opens in N minutes, ended, ok", () => {
  assert.deepEqual(joinCheck(shift("a", 0, { student_ids: [] }), NOW), { kind: "noVideo" });
  assert.deepEqual(joinCheck(shift("b", 25), NOW), { kind: "opensIn", minutes: 15 });
  assert.deepEqual(joinCheck(shift("c", 10), NOW), { kind: "ok" });
  assert.deepEqual(joinCheck(shift("d", -69), NOW), { kind: "ok" });
  assert.deepEqual(joinCheck(shift("e", -75, { status: "active" }), NOW), { kind: "ended" }, "live but past the window: the check refuses, as in Flutter");
});

test("the Zoom answer must carry a meeting number, signature and SDK key", () => {
  assert.equal(zoomInfoUsable({ success: true, meetingNumber: "1", signature: "s", sdkKey: "k" }), true);
  assert.equal(zoomInfoUsable({ success: true, meetingNumber: "1", signature: "s" }), false);
  assert.equal(zoomInfoUsable({ success: false, meetingNumber: "1", signature: "s", sdkKey: "k" }), false);
  assert.equal(zoomInfoUsable(null), false);
});

test("meeting page: Flutter's isolated /app/ copy with the same hash parameters", () => {
  const url = zoomMeetingUrl(
    { success: true, meetingNumber: "123", signature: "sig", sdkKey: "key", password: "pw", displayName: "Zz Parent", breakoutRoomName: " Room 1 ", autoJoinBreakoutRoom: true, classEndsAtIso: "2026-11-18T11:00:00Z" },
    {
      uid: "u1",
      returnUrl: "https://alluwaleducationhub.org/parent/classes/",
      cacheBust: "42",
      texts: { connecting: "Connecting to class", loadError: "L", joinError: "J", initError: "I", left: "Leave Class", leaveMeeting: "Leave Meeting", routingStillConnecting: "R", routingHelp: "H", classEndingSoon: "This class ends in {minutes} min", classEnded: "E" },
    },
  );
  assert.ok(url.startsWith("/app/zoom_meeting.html?join=42#"));
  const params = new URLSearchParams(url.split("#")[1]);
  assert.equal(params.get("customerKey"), "u1", "falls back to the uid");
  assert.equal(params.get("embedded"), "0");
  assert.equal(params.get("returnUrl"), "https://alluwaleducationhub.org/parent/classes/");
  assert.equal(params.get("classEndsAt"), "2026-11-18T11:00:00.000Z");
  assert.equal(params.get("classEndingSoonText"), "This class ends in {minutes} min");
  assert.equal(params.get("breakoutRoomName"), "Room 1");
  assert.equal(params.get("autoJoinBreakoutRoom"), "1");
  assert.equal(params.has("presenceToken"), false, "no presence parameters, as Flutter web");
  assert.equal(params.has("breakoutRoomKey"), false);
  assert.ok(url.includes("displayName=Zz%20Parent"), "spaces encoded as %20 like Uri.encodeComponent");
});

test("join errors: server sentences kept, bare codes become plain sentences", () => {
  assert.deepEqual(joinErrorKind({ code: "functions/permission-denied", message: "You are not allowed to join this class" }), { kind: "server", message: "You are not allowed to join this class" });
  assert.deepEqual(joinErrorKind({ code: "functions/deadline-exceeded", message: "deadline-exceeded" }), { kind: "slow" });
  assert.deepEqual(joinErrorKind({ code: "functions/unavailable", message: "" }), { kind: "slow" });
  assert.deepEqual(joinErrorKind({ code: "functions/internal", message: "internal" }), { kind: "failed" });
});

test("classes in the shell, the join page pushed over it", () => {
  assert.equal(PARENT_WEB_SCREENS.has("classes"), true);
  assert.equal(activeParentItemId("/parent/classes/"), "classes");
  assert.equal(isPushedParentPage("/parent/classes/"), false);
  assert.equal(isPushedParentPage("/parent/classroom/"), true);
  assert.equal(PARENT_ROUTES.classroom("a b"), "/parent/classroom/?shiftId=a%20b");
});
