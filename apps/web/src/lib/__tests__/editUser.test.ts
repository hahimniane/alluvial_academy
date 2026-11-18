import test from "node:test";
import assert from "node:assert/strict";
import { mapUserDoc } from "../adminUsers.ts";
import {
  buildEditPatch,
  changedFields,
  conflictNotice,
  conflictingFields,
  editProblems,
  editValuesOf,
  formValues,
  formatDayTime,
  pickMainRole,
  reviewRoleChange,
  roleLabelOf,
  secondaryChoices,
  touch,
  withSecondary,
  type Draft,
} from "../editUser.ts";

const NOW = "NOW";
const row = (data: Record<string, unknown>, id = "u1") => mapUserDoc(id, data);

test("values come from the row; nothing touched means nothing changed", () => {
  const live = editValuesOf(row({ first_name: "Aminata", last_name: "Barry", user_type: "student", secondary_roles: ["teacher"] }));
  assert.equal(live.firstName, "Aminata");
  assert.deepEqual(live.secondaryRoles, ["teacher"]);
  assert.deepEqual(changedFields(live, {}), []);
});

test("putting a field back turns Unsaved changes off again (U-122)", () => {
  const live = editValuesOf(row({ first_name: "Aminata", last_name: "Barry" }));
  let d: Draft = touch({}, live, "firstName", "Aminatou");
  assert.deepEqual(changedFields(live, d), ["firstName"]);
  d = touch(d, live, "firstName", "Aminata");
  assert.deepEqual(changedFields(live, d), []);
  // Spaces at either end are not a change.
  d = touch(d, live, "firstName", " Aminata ");
  assert.deepEqual(changedFields(live, d), []);
  // A switch flipped twice is no change.
  d = touch(touch(d, live, "tontineEnabled", true), live, "tontineEnabled", false);
  assert.deepEqual(changedFields(live, d), []);
});

test("accents and apostrophes are written exactly as typed, trimmed only", () => {
  const live = editValuesOf(row({ first_name: "Mamadou", last_name: "Diallo" }));
  const d = touch(touch({}, live, "firstName", "  N'Famara "), live, "lastName", "Condé-Sow");
  const built = buildEditPatch({ first_name: "Mamadou", last_name: "Diallo" }, d, NOW);
  assert.deepEqual(built?.patch, { first_name: "N'Famara", last_name: "Condé-Sow", updated_at: NOW });
});

test("only changed fields are written; an old document is not stamped with title / secondary_roles", () => {
  const stored = { first_name: "Ibrahima", last_name: "Camara", user_type: "teacher", phone_number: 6465550110 };
  const live = editValuesOf(row(stored));
  assert.equal(live.phone, "6465550110");
  const d = touch({}, live, "lastName", "Kamara");
  const built = buildEditPatch(stored, d, NOW)!;
  assert.deepEqual(built.patch, { last_name: "Kamara", updated_at: NOW });
  assert.deepEqual(built.fields, ["lastName"]);
});

test("a concurrent change to another field is kept, and the same value saved elsewhere means nothing to write", () => {
  const opened = { first_name: "Awa", last_name: "Bah", phone_number: "111", user_type: "parent" };
  const live = editValuesOf(row(opened));
  const d = touch({}, live, "firstName", "Awa Kadi");
  // Another tab changed the phone meanwhile; this save never writes phone_number.
  const later = { ...opened, phone_number: "222" };
  assert.deepEqual(buildEditPatch(later, d, NOW)?.patch, { first_name: "Awa Kadi", updated_at: NOW });
  // Another tab already saved the very same first name.
  assert.equal(buildEditPatch({ ...opened, first_name: "Awa Kadi" }, d, NOW), null);
});

test("a field both changed: this save wins, and the page names it", () => {
  const live0 = editValuesOf(row({ phone_number: "111" }));
  const d = touch({}, live0, "phone", "333");
  const live1 = editValuesOf(row({ phone_number: "222" }));
  assert.deepEqual(conflictingFields(live1, d), ["phone"]);
  assert.match(conflictNotice(["phone"]), /Someone else changed Phone/);
  assert.deepEqual(buildEditPatch({ phone_number: "222" }, d, NOW)?.patch, { phone_number: "333", updated_at: NOW });
  // Not a conflict when the other change matches what was typed.
  assert.deepEqual(conflictingFields(editValuesOf(row({ phone_number: "333" })), d), []);
  // Untouched fields follow the saved value live.
  assert.equal(formValues(live1, d).phone, "333");
  assert.equal(formValues(live1, {}).phone, "222");
});

test("Also works as applies additions and removals to the stored list", () => {
  const stored = { user_type: "teacher", secondary_roles: ["parent"] };
  const live = editValuesOf(row(stored));
  let d = touch({}, live, "secondaryRoles", withSecondary(live.secondaryRoles, "student", true));
  d = touch(d, live, "secondaryRoles", withSecondary(formValues(live, d).secondaryRoles, "parent", false));
  // Meanwhile someone added "admin" and an unknown "leader".
  const later = { ...stored, secondary_roles: ["parent", "admin", "leader"] };
  assert.deepEqual(buildEditPatch(later, d, NOW)?.patch, { secondary_roles: ["admin", "leader", "student"], updated_at: NOW });
  // Same set in another order is no change.
  assert.deepEqual(changedFields(editValuesOf(row({ secondary_roles: ["b", "a"] })), touch({}, editValuesOf(row({ secondary_roles: ["b", "a"] })), "secondaryRoles", ["A", "b"])), []);
});

test("picking a main role takes it off Also works as, in the form and in the write", () => {
  const stored = { user_type: "teacher", secondary_roles: ["parent", "admin"] };
  const live = editValuesOf(row(stored));
  const picked = pickMainRole(live, "parent");
  assert.deepEqual(picked, { userType: "parent", secondaryRoles: ["admin"] });
  const d = touch(touch({}, live, "userType", picked.userType), live, "secondaryRoles", picked.secondaryRoles);
  assert.deepEqual(buildEditPatch(stored, d, NOW)?.patch, { secondary_roles: ["admin"], user_type: "parent", updated_at: NOW });
  // The new main role added elsewhere to the stored list is dropped too.
  const d2 = touch({}, editValuesOf(row({ user_type: "teacher" })), "userType", "parent");
  assert.deepEqual(buildEditPatch({ user_type: "teacher", secondary_roles: ["parent"] }, d2, NOW)?.patch, { user_type: "parent", secondary_roles: [], updated_at: NOW });
});

test("a role / userType field that mirrors the old type moves with it; an admin role field never keeps a demoted admin an admin", () => {
  const live = editValuesOf(row({ user_type: "admin" }));
  const d = touch({}, live, "userType", "teacher");
  assert.deepEqual(buildEditPatch({ user_type: "admin", role: "Admin", userType: "admin" }, d, NOW)?.patch, {
    user_type: "teacher",
    role: "teacher",
    userType: "teacher",
    updated_at: NOW,
  });
  const d2 = touch({}, editValuesOf(row({ user_type: "teacher" })), "userType", "parent");
  assert.deepEqual(buildEditPatch({ user_type: "teacher", role: "admin" }, d2, NOW)?.patch, { user_type: "parent", role: "parent", updated_at: NOW });
  // An unrelated role field is left alone.
  assert.deepEqual(buildEditPatch({ user_type: "teacher", role: "coordinator" }, d2, NOW)?.patch, { user_type: "parent", updated_at: NOW });
});

test("checks: a name can't be emptied, untouched odd values never block a save", () => {
  const live = editValuesOf(row({ first_name: "Awa", last_name: "" }));
  assert.deepEqual(editProblems(live, []), {});
  const d = touch({}, live, "firstName", "   ");
  assert.deepEqual(editProblems(formValues(live, d), changedFields(live, d)), { firstName: "First name is required" });
  const d2 = touch(touch({}, live, "countryCode", "+1x"), live, "phone", "12");
  assert.deepEqual(Object.keys(editProblems(formValues(live, d2), changedFields(live, d2))).sort(), ["countryCode", "phone"]);
  const d3 = touch(touch({}, live, "countryCode", "+224"), live, "phone", "621 12 34 56");
  assert.deepEqual(editProblems(formValues(live, d3), changedFields(live, d3)), {});
  // Clearing a phone is allowed.
  const d4 = touch({}, editValuesOf(row({ phone_number: "111" })), "phone", "");
  assert.deepEqual(editProblems(formValues(editValuesOf(row({ phone_number: "111" })), d4), ["phone"]), {});
});

test("roles: labels, choices and what a change means", () => {
  assert.equal(roleLabelOf("super_admin"), "Super admin");
  assert.equal(roleLabelOf(""), "No type");
  assert.equal(roleLabelOf("Teacher"), "Teacher");
  assert.deepEqual(secondaryChoices("student"), ["teacher", "parent", "admin"]);
  assert.deepEqual(secondaryChoices("super_admin"), ["student", "teacher", "parent"]);
  const me = { id: "me", isAdminTeacher: false };
  assert.equal(reviewRoleChange(me, "admin", "teacher", "me").refusal, "You can't remove your own admin access.");
  assert.equal(reviewRoleChange(me, "super_admin", "admin", "me").refusal, null);
  assert.equal(reviewRoleChange({ id: "me", isAdminTeacher: true }, "admin", "teacher", "me").refusal, null);
  const demote = reviewRoleChange({ id: "x", isAdminTeacher: false }, "admin", "teacher", "me");
  assert.match(demote.lines.join(" "), /lose admin access/);
  assert.match(reviewRoleChange({ id: "x", isAdminTeacher: false }, "teacher", "admin", "me").lines.join(" "), /full admin access/);
  assert.match(reviewRoleChange({ id: "x", isAdminTeacher: true }, "teacher", "parent", "me").lines.join(" "), /keep admin access/);
  assert.match(reviewRoleChange({ id: "x", isAdminTeacher: false }, "student", "teacher", "me").lines[0], /^Student → Teacher\./);
});

test("an untouched super admin is never written as admin (U-115)", () => {
  const stored = { user_type: "super_admin", first_name: "A" };
  const live = editValuesOf(row(stored));
  const d = touch({}, live, "firstName", "B");
  assert.deepEqual(buildEditPatch(stored, d, NOW)?.patch, { first_name: "B", updated_at: NOW });
});

test("decision time format", () => {
  assert.match(formatDayTime(new Date(2026, 8, 4, 15, 12)), /^Sep 4, 2026, 3:12\s?PM$/);
});
