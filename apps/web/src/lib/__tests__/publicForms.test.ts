import assert from "node:assert/strict";
import { test } from "node:test";
import { cleanSubmitterName, cleanSubmitterPhone, isFileField, memberFillPath, publicAnswers, publicSubmitError } from "../publicForms.ts";

test("names: 2 to 100 characters once trimmed, inner spaces collapsed", () => {
  assert.equal(cleanSubmitterName("  Sample   Parent "), "Sample Parent");
  assert.equal(cleanSubmitterName("A"), null);
  assert.equal(cleanSubmitterName("   "), null);
  assert.equal(cleanSubmitterName("x".repeat(100)), "x".repeat(100));
  assert.equal(cleanSubmitterName("x".repeat(101)), null);
});

test("phones: 6 to 25 characters of digits, spaces, dashes and a leading +", () => {
  assert.equal(cleanSubmitterPhone(" +224 620-00-00-00 "), "+224 620-00-00-00");
  assert.equal(cleanSubmitterPhone("620000"), "620000");
  assert.equal(cleanSubmitterPhone("12345"), null);
  assert.equal(cleanSubmitterPhone("+224 abc 0000"), null);
  assert.equal(cleanSubmitterPhone("224+6200000"), null);
  assert.equal(cleanSubmitterPhone("- - - - - -"), null);
  assert.equal(cleanSubmitterPhone("1".repeat(26)), null);
});

test("file questions are recognised under every stored type name", () => {
  for (const type of ["image_upload", "imageUpload", "signature"]) assert.equal(isFileField(type), true);
  for (const type of ["text", "image", "dropdown"]) assert.equal(isFileField(type), false);
});

test("answers: shown questions only, no display blocks or files, stored like a signed-in submission", () => {
  const fields = [
    { id: "h", type: "heading", options: [] },
    { id: "name", type: "text", options: [] },
    { id: "empty", type: "long_text", options: [] },
    { id: "yes", type: "yes_no", options: [] },
    { id: "radioYesNo", type: "radio", options: [] },
    { id: "pick", type: "radio", options: ["A", "B"] },
    { id: "many", type: "multi_select", options: ["x", "y"] },
    { id: "day", type: "date", options: [] },
    { id: "photo", type: "image_upload", options: [] },
    { id: "hidden", type: "text", options: [] },
  ];
  const shown = new Set(fields.map((f) => f.id).filter((id) => id !== "hidden"));
  const values = { h: "x", name: "Sample Child", yes: "No", radioYesNo: "Yes", pick: "B", many: ["x", "y"], day: "2026-03-07", photo: "file", hidden: "secret" };
  assert.deepEqual(publicAnswers(fields, shown, values), {
    name: "Sample Child",
    empty: "",
    yes: false,
    radioYesNo: true,
    pick: "B",
    many: ["x", "y"],
    day: "7/3/2026",
  });
});

test("signed-in members go to their own role's page when it lists the form", () => {
  const parentForm = { id: "f1", title: "Trip consent", audience: ["parent"], category: "other", frequency: "onDemand" };
  assert.equal(memberFillPath("/parent/", parentForm), "/parent/forms/fill/?id=f1");
  assert.equal(memberFillPath("/student/", parentForm), null);
  assert.equal(memberFillPath("/teacher/", parentForm), null);
  assert.equal(memberFillPath("/app/", parentForm), null);

  assert.equal(memberFillPath("/student/", { ...parentForm, audience: ["Students", "parents"] }), "/student/forms/?id=f1");
  assert.equal(memberFillPath("/teacher/", { ...parentForm, audience: ["teachers"] }), "/teacher/submit-form/?form=f1");
  // No audience: the teacher page goes by category / frequency.
  assert.equal(memberFillPath("/teacher/", { ...parentForm, audience: [], category: "feedback" }), "/teacher/submit-form/?form=f1");
  assert.equal(memberFillPath("/teacher/", { ...parentForm, audience: [], category: "other", frequency: "weekly" }), "/teacher/submit-form/?form=f1");
  assert.equal(memberFillPath("/teacher/", { ...parentForm, audience: [], category: "other", frequency: "onDemand" }), null);
  // Built-in parent forms show to parents whatever their audience.
  assert.equal(memberFillPath("/parent/", { id: "parent_feedback", title: "Parent/Guardian Feedback", audience: [] }), "/parent/forms/fill/?id=parent_feedback");
  assert.equal(memberFillPath("/parent/", { id: "a/b", title: "", audience: ["parent"] }), "/parent/forms/fill/?id=a%2Fb");
  assert.equal(memberFillPath("/parent/", { title: "x", audience: ["parent"] }), null);
});

test("send errors read by callable code", () => {
  assert.match(publicSubmitError({ code: "functions/resource-exhausted" }), /Try again tomorrow/);
  assert.equal(publicSubmitError({ code: "functions/failed-precondition" }), "This form is no longer available.");
  assert.match(publicSubmitError({ code: "functions/invalid-argument" }), /Check them/);
  assert.match(publicSubmitError(new Error("offline")), /connection/);
  assert.match(publicSubmitError(null), /connection/);
});
