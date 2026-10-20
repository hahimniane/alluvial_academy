import assert from "node:assert/strict";
import { test } from "node:test";
import { parseClassContacts, telHref } from "../classContacts.ts";

test("keeps well-formed groups and contacts", () => {
  const parsed = parseClassContacts({
    students: [{ studentName: "Fatou Bah", contacts: [{ name: "Mariama Bah", relationship: "parent", phone: "+44 7981234567", tel: "+447981234567" }] }],
    teachers: [{ name: "Amina Diallo", relationship: "teacher", phone: "+224 621 00 00 01", tel: "+224621000001" }],
  });
  assert.equal(parsed.students.length, 1);
  assert.equal(parsed.students[0].contacts[0].tel, "+447981234567");
  assert.deepEqual(parsed.children, []);
  assert.equal(telHref(parsed.teachers[0]), "tel:+224621000001");
});

test("drops contacts without a dialable number or a known relationship", () => {
  const parsed = parseClassContacts({
    teachers: [
      { name: "No number", relationship: "teacher", phone: "", tel: "" },
      { name: "Odd", relationship: "cousin", phone: "+1 555 0100 99", tel: "+15550100099" },
      { name: "Script", relationship: "teacher", phone: "x", tel: "javascript:alert(1)" },
      null,
    ],
  });
  assert.deepEqual(parsed.teachers, []);
});

test("a student whose parents have no phone stays listed with no contacts", () => {
  const parsed = parseClassContacts({ students: [{ studentName: "Zeyna Ly", contacts: [] }] });
  assert.deepEqual(parsed.students, [{ studentName: "Zeyna Ly", contacts: [] }]);
});

test("anything unexpected parses to empty", () => {
  assert.deepEqual(parseClassContacts(null), { students: [], children: [], teachers: [] });
  assert.deepEqual(parseClassContacts({ students: "x" }), { students: [], children: [], teachers: [] });
});
