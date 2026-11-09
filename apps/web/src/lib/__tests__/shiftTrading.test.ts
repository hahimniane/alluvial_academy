import test from "node:test";
import assert from "node:assert/strict";
import { canClaimShift, canOfferShift } from "../shiftTrading.ts";

const now = new Date("2026-11-10T12:00:00Z");
const later = new Date("2026-11-11T12:00:00Z");
const earlier = new Date("2026-11-09T12:00:00Z");

test("an upcoming scheduled class can be offered", () => {
  assert.equal(canOfferShift({ isPublished: false, status: "scheduled", start: later }, now), true);
});

test("a class that started, is not scheduled, or is already offered cannot be offered", () => {
  assert.equal(canOfferShift({ isPublished: false, status: "scheduled", start: earlier }, now), false);
  assert.equal(canOfferShift({ isPublished: false, status: "cancelled", start: later }, now), false);
  assert.equal(canOfferShift({ isPublished: true, status: "scheduled", start: later }, now), false);
  assert.equal(canOfferShift({ isPublished: false, status: "scheduled", start: null }, now), false);
});

test("another teacher can claim an offered upcoming class", () => {
  assert.equal(canClaimShift({ isPublished: true, status: "scheduled", start: later, teacherId: "a" }, "b", now), true);
});

test("a teacher cannot claim their own, a started, or an unoffered class", () => {
  assert.equal(canClaimShift({ isPublished: true, status: "scheduled", start: later, teacherId: "a" }, "a", now), false);
  assert.equal(canClaimShift({ isPublished: true, status: "scheduled", start: earlier, teacherId: "a" }, "b", now), false);
  assert.equal(canClaimShift({ isPublished: false, status: "scheduled", start: later, teacherId: "a" }, "b", now), false);
});
