import test from "node:test";
import assert from "node:assert/strict";
import { convertTimeSlot, parseTimeString, zoneAbbreviation } from "../timeZoneConvert.ts";

test("a New York window is shown in the teacher's own hours", () => {
  // Conakry is GMT+0 all year; New York is UTC-4 in September.
  assert.equal(convertTimeSlot("10:00 AM - 11:00 AM", "America/New_York", "Africa/Conakry"), "2:00 PM - 3:00 PM");
  // Casablanca is UTC+1 in September.
  assert.equal(convertTimeSlot("6:00 PM - 7:30 PM", "America/New_York", "Africa/Casablanca"), "11:00 PM - 12:30 AM");
});

test("nothing is touched when there is nothing to convert", () => {
  assert.equal(convertTimeSlot("10:00 AM - 11:00 AM", "America/New_York", "America/New_York"), "10:00 AM - 11:00 AM");
  assert.equal(convertTimeSlot("10:00 AM - 11:00 AM", "", "Africa/Conakry"), "10:00 AM - 11:00 AM");
  assert.equal(convertTimeSlot("whenever", "America/New_York", "Africa/Conakry"), "whenever");
  assert.equal(convertTimeSlot("", "America/New_York", "Africa/Conakry"), "");
});

test("an unknown zone leaves the slot alone rather than throwing", () => {
  assert.equal(convertTimeSlot("10:00 AM - 11:00 AM", "Not/AZone", "Africa/Conakry"), "10:00 AM - 11:00 AM");
});

test("time strings parse the shapes the app writes", () => {
  assert.deepEqual(parseTimeString("12:00 AM"), { hour: 0, minute: 0 });
  assert.deepEqual(parseTimeString("12:00 PM"), { hour: 12, minute: 0 });
  assert.deepEqual(parseTimeString("9:30 pm"), { hour: 21, minute: 30 });
  assert.deepEqual(parseTimeString("14:15"), { hour: 14, minute: 15 });
  assert.equal(parseTimeString("half past"), null);
});

test("zone abbreviation is readable and never throws", () => {
  assert.equal(typeof zoneAbbreviation("America/New_York"), "string");
  assert.equal(zoneAbbreviation("Not/AZone"), "Not/AZone");
  assert.equal(zoneAbbreviation(""), "");
});
