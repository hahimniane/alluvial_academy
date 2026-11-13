import { test } from "node:test";
import assert from "node:assert/strict";
import { audienceIncludes, parseFormAudience, studentCanSeeForm } from "../formAudience.ts";

test("reads the audience from every stored shape", () => {
  assert.deepEqual(parseFormAudience({ allowedRoles: ["student", "parent"] }), ["student", "parent"]);
  assert.deepEqual(parseFormAudience({ audience: "Students, Parents" }), ["Students", "Parents"]);
  assert.deepEqual(parseFormAudience({ targetRoles: { student: true, teacher: false } }), ["student"]);
  assert.deepEqual(parseFormAudience({ permissions: { type: "restricted", role: "student" } }), ["student"]);
  assert.equal(parseFormAudience({ permissions: { type: "public", role: "student" } }), null);
  assert.equal(parseFormAudience({}), null);
});

test("role names are matched in any spelling", () => {
  assert.equal(audienceIncludes(["Students"], "student"), true);
  assert.equal(audienceIncludes(["teacher", "admin"], "student"), false);
  assert.equal(audienceIncludes(null, "student"), false);
});

test("a student sees only active forms aimed at students", () => {
  assert.equal(studentCanSeeForm({ allowedRoles: ["student", "parent"], isActive: true }), true);
  assert.equal(studentCanSeeForm({ allowedRoles: ["student"], isActive: false }), false);
  assert.equal(studentCanSeeForm({ allowedRoles: ["teacher"] }), false);
  // No audience at all: hidden, never shown by default.
  assert.equal(studentCanSeeForm({ name: "Daily class report" }), false);
});
