import test from "node:test";
import assert from "node:assert/strict";
import { mapUserDoc, type UserRow } from "../adminUsers.ts";
import {
  MINOR_BLOCKED,
  guardianCandidates,
  guardiansOfStudent,
  isLastGuardianOfMinor,
  isParentAccount,
  linkMessage,
  sideNote,
  studentCandidates,
  studentLine,
  studentsOfParent,
} from "../guardians.ts";

const docs: [string, Record<string, unknown>][] = [
  ["s1", { user_type: "student", first_name: "Aminata", last_name: "Barry", guardian_ids: ["p1"], guardianIds: ["p2"], student_code: "aminata.barry" }],
  // One-sided: p3 lists s2, s2 lists nobody.
  ["s2", { user_type: "student", first_name: "Bilal", last_name: "Sow", is_adult_student: true }],
  // Legacy single field.
  ["s3", { user_type: "student", first_name: "Chérif", last_name: "Bah", parent_id: "p1" }],
  ["s4", { user_type: "student", first_name: "Dalanda", last_name: "Diallo", guardian_ids: ["ghost"] }],
  ["p1", { user_type: "parent", first_name: "Mariama", last_name: "Barry", children_ids: ["s1"], "e-mail": "m@example.org", phone_number: "3475550187", country_code: "+1" }],
  ["p2", { user_type: "parent", first_name: "Omar", last_name: "Barry", childrenIds: ["s1"] }],
  ["p3", { user_type: "parent", first_name: "Awa", last_name: "Sow", children_ids: ["s2"], is_active: false }],
  ["p4", { user_type: "Guardian", first_name: "Zoé", last_name: "Camara" }],
  ["t1", { user_type: "teacher", first_name: "Ibrahima", last_name: "Camara", secondary_roles: ["parent"] }],
];
const rows: UserRow[] = docs.map(([id, d]) => mapUserDoc(id, d));
const byId = new Map(rows.map((r) => [r.id, r]));
const get = (id: string) => byId.get(id)!;
const pick = <T extends { id: string; side: string }>(list: T[]) => list.map((x) => `${x.id}:${x.side}`);

test("a student's guardians: both spellings, the parent side and legacy single fields", () => {
  assert.deepEqual(pick(guardiansOfStudent(get("s1"), rows, byId)), ["p1:both", "p2:both"]);
  assert.deepEqual(pick(guardiansOfStudent(get("s2"), rows, byId)), ["p3:parent"]);
  assert.deepEqual(pick(guardiansOfStudent(get("s3"), rows, byId)), ["p1:student"]);
  // A guardian id with no account is listed by its id (it can still be unlinked).
  const ghost = guardiansOfStudent(get("s4"), rows, byId);
  assert.deepEqual(pick(ghost), ["ghost:both"]);
  assert.equal(ghost[0].name, "ghost");
  assert.equal(ghost[0].row, undefined);
});

test("a parent's students: the union of both sides (children_ids disagreeing with guardian_ids)", () => {
  assert.deepEqual(pick(studentsOfParent(get("p1"), rows, byId)), ["s1:both", "s3:student"]);
  assert.deepEqual(pick(studentsOfParent(get("p2"), rows, byId)), ["s1:both"]);
  assert.deepEqual(pick(studentsOfParent(get("p3"), rows, byId)), ["s2:parent"]);
  assert.equal(sideNote("parent", "parent"), "Linked on this account only");
  assert.equal(sideNote("student", "parent"), "Linked on their account only");
  assert.equal(sideNote("both", "student"), "");
});

test("guardian candidates: parent accounts not linked on both sides; a second guardian is allowed (Q11)", () => {
  const ids = guardianCandidates(get("s1"), rows, byId, "").map((c) => c.row.id);
  assert.deepEqual(ids, ["p4", "p3"]); // active first, then name; p1/p2 already linked; teacher with secondary parent excluded
  const forS3 = guardianCandidates(get("s3"), rows, byId, "");
  assert.equal(forS3.find((c) => c.row.id === "p1")?.partial, true);
  assert.deepEqual(guardianCandidates(get("s1"), rows, byId, "zoé").map((c) => c.row.id), ["p4"]);
  assert.equal(guardianCandidates(get("s2"), rows, byId, "").find((c) => c.row.id === "p1")?.detail, "m@example.org · +1 3475550187");
});

test("student candidates: every student, guardian or not, with their guardians shown", () => {
  const list = studentCandidates(get("p2"), rows, byId, "");
  assert.deepEqual(list.map((c) => c.row.id), ["s2", "s3", "s4"]);
  assert.equal(list[0].detail, "Student ID s2 · Guardian: Awa Sow");
  assert.equal(list[2].detail, "Student ID s4 · Guardian: ghost");
  assert.deepEqual(studentCandidates(get("p1"), rows, byId, "bilal").map((c) => c.row.id), ["s2"]);
  assert.equal(studentCandidates(get("p1"), rows, byId, "").find((c) => c.row.id === "s3")?.partial, true);
});

test("parent accounts and lines", () => {
  assert.equal(isParentAccount(get("p4")), true);
  assert.equal(isParentAccount(get("t1")), false);
  assert.equal(studentLine(get("s2")), "Student ID: s2 · Adult student");
  assert.equal(studentLine(get("s1")), "Student ID: aminata.barry");
});

test("messages", () => {
  assert.equal(linkMessage({ alreadyLinked: false, repaired: false }, "Aminata", "Awa"), "Linked Aminata to Awa.");
  assert.equal(linkMessage({ alreadyLinked: true, repaired: false }, "Aminata", "Awa"), "Aminata is already linked to Awa.");
  assert.equal(linkMessage({ alreadyLinked: false, repaired: true }, "Aminata", "Awa"), "Fixed the link between Aminata and Awa.");
  assert.equal(isLastGuardianOfMinor({ code: "functions/failed-precondition", details: { reason: "last_guardian_minor" } }), true);
  assert.equal(isLastGuardianOfMinor({ message: "Cannot unlink the only guardian of a minor student." }), true);
  assert.equal(isLastGuardianOfMinor({ message: "This parent is not linked to this student" }), false);
  assert.match(MINOR_BLOCKED, /only guardian of a minor/);
});
