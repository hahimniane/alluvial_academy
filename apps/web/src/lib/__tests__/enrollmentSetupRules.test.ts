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

test("the monthly amount needs an amount above $0 and 1 to 62 classes", async () => {
  const { monthlyAmountProblem } = await import("../enrollmentSetupRules.ts");
  assert.equal(monthlyAmountProblem("80", "8"), null);
  assert.equal(monthlyAmountProblem("82.5", "62"), null);
  assert.equal(monthlyAmountProblem("", "8"), "Enter the monthly amount.");
  assert.equal(monthlyAmountProblem("0", "8"), "Enter the monthly amount.");
  assert.equal(monthlyAmountProblem("-5", "8"), "Enter the monthly amount.");
  assert.equal(monthlyAmountProblem("abc", "8"), "Enter the monthly amount.");
  assert.equal(monthlyAmountProblem("80", ""), "Enter how many classes a full month has.");
  assert.equal(monthlyAmountProblem("80", "0"), "Enter how many classes a full month has.");
  assert.equal(monthlyAmountProblem("80", "63"), "Enter how many classes a full month has.");
  assert.equal(monthlyAmountProblem("80", "7.5"), "Enter how many classes a full month has.");
});

test("dollars drop a whole-number .00", async () => {
  const { dollars } = await import("../enrollmentSetupRules.ts");
  assert.equal(dollars(80), "$80");
  assert.equal(dollars(82.5), "$82.50");
});
