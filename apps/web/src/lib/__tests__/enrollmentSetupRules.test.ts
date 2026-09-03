import test from "node:test";
import assert from "node:assert/strict";
import { parentInviteProblem, splitStudentName } from "../enrollmentSetupRules.ts";

test("stored first and last names win over splitting", () => {
  assert.deepEqual(splitStudentName("Amina", "Diallo", "Someone Else"), {
    firstName: "Amina",
    lastName: "Diallo",
  });
});

test("a full name is split when a part is missing", () => {
  assert.deepEqual(splitStudentName("", "", "Amina Diallo"), { firstName: "Amina", lastName: "Diallo" });
  assert.deepEqual(splitStudentName("Amina", "", "Amina Bah Diallo"), {
    firstName: "Amina",
    lastName: "Bah Diallo",
  });
  // Extra whitespace must not become part of a name.
  assert.deepEqual(splitStudentName("", "", "  Musa   Kante  "), { firstName: "Musa", lastName: "Kante" });
});

test("a one-word name still produces both fields", () => {
  assert.deepEqual(splitStudentName("", "", "Amina"), { firstName: "Amina", lastName: "Unknown" });
  assert.deepEqual(splitStudentName("", "", ""), { firstName: "Student", lastName: "Unknown" });
});

test("an invite needs a plausible email", () => {
  const base = { email: "", firstName: "", lastName: "", phone: "", countryCode: "" };
  assert.match(parentInviteProblem(base)!, /email/);
  assert.match(parentInviteProblem({ ...base, email: "   " })!, /email/);
  assert.match(parentInviteProblem({ ...base, email: "not-an-email" })!, /valid/);
  assert.equal(parentInviteProblem({ ...base, email: "parent@example.com" }), null);
});
