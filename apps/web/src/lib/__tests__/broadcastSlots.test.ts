import test from "node:test";
import assert from "node:assert/strict";
import {
  broadcastProblem,
  formatSlot,
  parseSlot,
  parseSlotTime,
  slotProblem,
  sortSlots,
} from "../broadcastSlots.ts";

test("times parse the way the dialog writes them", () => {
  assert.equal(parseSlotTime("4:00 PM"), 16 * 60);
  assert.equal(parseSlotTime("12:00 AM"), 0);
  assert.equal(parseSlotTime("12:30 PM"), 12 * 60 + 30);
  assert.equal(parseSlotTime("9:05 am"), 9 * 60 + 5);
  assert.equal(parseSlotTime("garbage"), null);
  assert.equal(parseSlotTime("13:00 PM"), null);
  assert.equal(parseSlotTime("4:75 PM"), null);
});

test("a slot round-trips", () => {
  assert.deepEqual(parseSlot("4:00 PM - 5:30 PM"), { start: 960, end: 1050 });
  assert.equal(formatSlot(960, 1050), "4:00 PM - 5:30 PM");
  assert.equal(parseSlot("4:00 PM"), null);
});

test("an end at or before the start is refused", () => {
  assert.match(slotProblem(600, 600, [])!, /after/);
  assert.match(slotProblem(600, 540, [])!, /after/);
  assert.equal(slotProblem(600, 660, []), null);
});

test("an exact duplicate is refused", () => {
  assert.match(slotProblem(960, 1020, ["4:00 PM - 5:00 PM"])!, /already exists/);
});

test("overlapping slots are refused, not just duplicates", () => {
  // 4-6 already booked; 5-7 is a different string describing an impossible day.
  const existing = ["4:00 PM - 6:00 PM"];
  assert.match(slotProblem(1020, 1140, existing)!, /overlaps with "4:00 PM - 6:00 PM"/);
  assert.match(slotProblem(900, 1020, existing)!, /overlaps/);
  // Fully containing the existing slot is also an overlap.
  assert.match(slotProblem(900, 1200, existing)!, /overlaps/);
  // Touching end-to-start is fine: 6-7 after 4-6.
  assert.equal(slotProblem(1080, 1140, existing), null);
});

test("an unreadable existing slot is left alone rather than treated as free", () => {
  // It must not throw, and must not silently claim the time is available.
  assert.equal(slotProblem(960, 1020, ["whenever works"]), null);
});

test("incomplete input asks for the missing half", () => {
  assert.match(slotProblem(null, 1020, [])!, /Pick start and end/);
  assert.match(slotProblem(960, null, [])!, /Pick start and end/);
});

test("slots are ordered by start time", () => {
  assert.deepEqual(
    sortSlots(["6:00 PM - 7:00 PM", "9:00 AM - 10:00 AM", "1:00 PM - 2:00 PM"]),
    ["9:00 AM - 10:00 AM", "1:00 PM - 2:00 PM", "6:00 PM - 7:00 PM"],
  );
});

test("a broadcast needs both a day and a slot", () => {
  assert.match(broadcastProblem([], ["4:00 PM - 5:00 PM"])!, /at least one day/);
  assert.match(broadcastProblem(["Monday"], [])!, /Add a time slot, or choose the part of the day/);
  // A window is enough on its own: the teacher's picker builds the concrete
  // slots from it, and the new form never collects exact hours.
  assert.equal(broadcastProblem(["Monday"], [], "Afternoon"), null);
  assert.equal(broadcastProblem(["Monday"], ["4:00 PM - 5:00 PM"], ""), null);
  assert.match(broadcastProblem([], [], "Afternoon")!, /at least one day/);
  assert.equal(broadcastProblem(["Monday"], ["4:00 PM - 5:00 PM"]), null);
});
