import assert from "node:assert/strict";
import { test } from "node:test";
import { otherRolesOf } from "../roles.ts";

test("an admin who is also a student can go back to admin or teacher", () => {
  assert.deepEqual(otherRolesOf({ user_type: "admin", secondary_roles: ["student"] }), ["admin", "teacher"]);
});

test("a plain student has nowhere else to go", () => {
  assert.deepEqual(otherRolesOf({ user_type: "student" }), []);
  assert.deepEqual(otherRolesOf(undefined), []);
});

test("a teacher flagged admin-teacher gets admin; secondary roles are trimmed and lower-cased", () => {
  assert.deepEqual(otherRolesOf({ user_type: "teacher", is_admin_teacher: true, secondary_roles: [" Parent ", "student"] }), ["teacher", "admin", "parent"]);
});
