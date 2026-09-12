import assert from "node:assert/strict";
import { test } from "node:test";
import { formatCountdown, readClassroomReconnect, secondsUntil } from "../classroomReconnect.ts";

const reconnectError = (details: unknown) => ({
  code: "functions/unavailable",
  message: "Your class is reconnecting. Please tap Join again in a moment.",
  details,
});

test("a hub coming back is recognised, with the time it published", () => {
  const backAt = new Date(Date.now() + 90_000);
  const result = readClassroomReconnect(reconnectError({
    reason: "classroom_reconnecting",
    expectedBackAtIso: backAt.toISOString(),
  }));
  assert.ok(result);
  assert.equal(result.expectedBackAt?.toISOString(), backAt.toISOString());
});

test("a hub coming back with no known time still counts as reconnecting", () => {
  // The difference that matters: waiting is right, but there is nothing to
  // count down to, so the caller must not invent a number.
  const result = readClassroomReconnect(reconnectError({
    reason: "classroom_reconnecting",
    expectedBackAtIso: null,
  }));
  assert.ok(result);
  assert.equal(result.expectedBackAt, null);
});

test("a time that has already passed is not offered as a countdown", () => {
  const result = readClassroomReconnect(reconnectError({
    reason: "classroom_reconnecting",
    expectedBackAtIso: new Date(Date.now() - 1000).toISOString(),
  }));
  assert.ok(result);
  assert.equal(result.expectedBackAt, null);
});

test("an unparseable time is ignored rather than shown as Invalid Date", () => {
  const result = readClassroomReconnect(reconnectError({
    reason: "classroom_reconnecting",
    expectedBackAtIso: "not-a-date",
  }));
  assert.ok(result);
  assert.equal(result.expectedBackAt, null);
});

test("a full classroom is not a reconnect, because waiting will not fix it", () => {
  assert.equal(readClassroomReconnect({
    code: "functions/resource-exhausted",
    message: "This Zoom hub is full and this teacher has no single Zoom host account configured.",
  }), null);
});

test("an ordinary failure is not a reconnect", () => {
  assert.equal(readClassroomReconnect(new Error("Shift not found")), null);
  assert.equal(readClassroomReconnect({ code: "functions/unavailable" }), null);
  assert.equal(readClassroomReconnect({
    code: "functions/unavailable",
    details: { reason: "something_else" },
  }), null);
  assert.equal(readClassroomReconnect(null), null);
});

test("seconds remaining never goes negative, and is null without a target", () => {
  const now = Date.now();
  assert.equal(secondsUntil(new Date(now + 61_000), now), 61);
  assert.equal(secondsUntil(new Date(now - 5_000), now), 0);
  assert.equal(secondsUntil(null, now), null);
});

test("the countdown reads as minutes and seconds", () => {
  assert.equal(formatCountdown(175), "2:55");
  assert.equal(formatCountdown(60), "1:00");
  assert.equal(formatCountdown(9), "0:09");
  assert.equal(formatCountdown(0), "0:00");
});
