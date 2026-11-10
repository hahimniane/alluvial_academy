import { test } from "node:test";
import assert from "node:assert/strict";
import { classroomErrorText, JOIN_FAILED_TEXT, SLOW_CONNECTION_TEXT } from "../classroomErrorText.ts";

function fbError(code: string, message: string) {
  return Object.assign(new Error(message), { code });
}

test("browser timeout becomes the slow-connection sentence", () => {
  assert.equal(classroomErrorText(fbError("functions/deadline-exceeded", "deadline-exceeded")), SLOW_CONNECTION_TEXT);
  assert.equal(classroomErrorText(fbError("functions/unavailable", "unavailable")), SLOW_CONNECTION_TEXT);
  assert.equal(classroomErrorText(new TypeError("Failed to fetch")), SLOW_CONNECTION_TEXT);
});

test("bare internal or empty falls back", () => {
  assert.equal(classroomErrorText(fbError("functions/internal", "internal")), JOIN_FAILED_TEXT);
  assert.equal(classroomErrorText(new Error("")), JOIN_FAILED_TEXT);
});

test("a message the server wrote is kept", () => {
  assert.equal(classroomErrorText(fbError("functions/failed-precondition", "This class has ended.")), "This class has ended.");
  assert.equal(classroomErrorText(new Error("Zoom class is unavailable.")), "Zoom class is unavailable.");
});
