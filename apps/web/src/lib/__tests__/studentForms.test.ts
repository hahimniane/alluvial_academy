import { test } from "node:test";
import assert from "node:assert/strict";
import { latestStudentForms, studentSubmissionData } from "../studentForms.ts";

test("keeps the newest copy of each form, sorted by name", () => {
  const forms = latestStudentForms([
    { id: "old", name: "Complaint Form", version: 1, updatedAt: 10 },
    { id: "new", name: "complaint form ", version: 2, updatedAt: 5 },
    { id: "b", name: "Bayana Attendance", version: 1, updatedAt: 1 },
    { id: "b2", name: "Bayana Attendance", version: 1, updatedAt: 9 },
  ]);
  assert.deepEqual(forms.map((form) => form.id), ["b2", "new"]);
});

test("a submission is owned by the student and filed under the month", () => {
  const data = studentSubmissionData({
    form: { id: "tpl1", name: "Bayana Attendance", frequency: "onDemand" },
    uid: "stu1",
    email: "s@example.org",
    firstName: "Aisha",
    displayName: "Aisha Bah",
    now: new Date(2026, 10, 13),
  });
  assert.equal(data.userId, "stu1");
  assert.equal(data.submittedBy, "stu1");
  assert.equal(data.templateId, "tpl1");
  assert.equal(data.formType, "onDemand");
  assert.equal(data.yearMonth, "2026-11");
  assert.equal(data.lastName, "Bah");
  assert.equal(data.userRole, "student");
});
