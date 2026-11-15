import assert from "node:assert/strict";
import { test } from "node:test";
import {
  PARENT_FEEDBACK_TEMPLATE,
  availableToday,
  builtInLayout,
  categoryTitle,
  displayCategory,
  excuseTemplate,
  fallbackSections,
  formatMessage,
  isBuiltInParentForm,
  isDisplayBlock,
  matchesFormSearch,
  parentFormSections,
  parentMaySee,
  parentSubmissionData,
  requiredMessage,
  sortSection,
  storedDate,
  templateFromDoc,
  visibleFieldCount,
  type ParentFormTemplate,
} from "../parentForms.ts";
import { PARENT_ROUTES, PARENT_WEB_SCREENS, isPushedParentPage } from "../parentWeb.ts";

const ts = (ms: number) => ({ toMillis: () => ms });
const excuse = excuseTemplate({
  title: "Student Absence / Excuse Request",
  description: "d",
  studentName: "Child's full name",
  classOrTeacher: "Class or teacher (optional)",
  absenceDate: "Date of the missed class",
  reason: "Reason for the absence",
  reasons: ["Illness", "Appointment", "Family emergency", "Technical issue", "Other"],
  details: "Please explain the absence",
  preferredContact: "Preferred follow-up method (optional)",
  contacts: ["In-app chat", "Email", "Phone"],
});
const builtIns = { excuse, feedback: PARENT_FEEDBACK_TEMPLATE };
const make = (id: string, data: Record<string, unknown>) => templateFromDoc(id, { updatedAt: ts(1), frequency: "onDemand", ...data });

test("template parsing: list or map fields sorted by order, defaults as FormTemplate.fromFirestore", () => {
  const t = templateFromDoc("a", { fields: { q2: { label: "B", order: 2 }, q1: { label: "A", order: 1, type: "radio", options: ["x", 3, "y"] } } });
  assert.deepEqual(t.fields.map((f) => f.id), ["q1", "q2"]);
  assert.deepEqual(t.fields[0].options, ["x", "y"]);
  assert.equal(t.fields[1].type, "text");
  assert.equal(t.name, "Untitled");
  assert.equal(t.frequency, "perSession", "a missing frequency reads as per-session, as in the app");
  assert.equal(t.category, "other");
  assert.equal(t.isActive, true);
  const list = templateFromDoc("b", { fields: [{ label: "x" }, { id: "named", label: "y" }] });
  assert.deepEqual(list.fields.map((f) => f.id), ["field_0", "named"]);
});

test("who sees a form: active + audience includes parents, or a built-in parent form whatever its audience", () => {
  assert.equal(parentMaySee(make("1", { name: "Bayana", allowedRoles: ["student", "parent"] })), true);
  assert.equal(parentMaySee(make("2", { name: "Guardians only", audience: "Parents/Guardians" })), true);
  assert.equal(parentMaySee(make("3", { name: "Teachers", allowedRoles: ["teacher"] })), false);
  assert.equal(parentMaySee(make("4", { name: "No audience" })), false);
  assert.equal(parentMaySee(make("5", { name: "Parent / Guardian Feedback", allowedRoles: ["admin"] })), true);
  assert.equal(parentMaySee(make("6", { name: "Feedback for Leaders" })), true);
  assert.equal(parentMaySee(make("7", { name: "Bayana", allowedRoles: ["parent"], isActive: false })), false);
  assert.equal(isBuiltInParentForm({ id: "parent_student_excuse", name: "" }), true);
  // The app's name check strips accents to spaces, so the accented French name does not match.
  assert.equal(isBuiltInParentForm({ id: "x", name: "Demande d'excuse d'absence de l'élève" }), false);
});

test("sections: newest copy per name, excuse always added, built-in feedback only without a feedback form", () => {
  const sections = parentFormSections(
    [
      make("old", { name: "Bayana  Attendance", version: 1, allowedRoles: ["parent"], category: "other" }),
      make("new", { name: "bayana attendance", version: 2, allowedRoles: ["parent"], category: "other" }),
      make("t", { name: "Weekly", allowedRoles: ["teacher"], category: "teaching" }),
    ],
    builtIns,
  );
  assert.deepEqual(sections.get("other")?.map((t) => t.id), ["new"]);
  assert.deepEqual(sections.get("administrative")?.map((t) => t.id), ["parent_student_excuse"]);
  assert.deepEqual(sections.get("studentAssessment")?.map((t) => t.id), ["parent_feedback"]);
  const withFeedback = parentFormSections([make("f", { name: "Parents Feedback on Teachers", allowedRoles: ["parent"], category: "feedback", frequency: "monthly" })], builtIns);
  assert.equal(withFeedback.has("studentAssessment"), false);
  assert.deepEqual(withFeedback.get("feedback")?.map((t) => t.id), ["f"]);
  // Dedupe runs over every active form before the parent policy, as in the app.
  const hidden = parentFormSections([make("p", { name: "Same", version: 1, allowedRoles: ["parent"] }), make("q", { name: "Same", version: 2, allowedRoles: ["teacher"] })], builtIns);
  assert.equal([...hidden.values()].flat().some((t) => t.name === "Same"), false);
  assert.deepEqual([...fallbackSections(builtIns).keys()], ["administrative", "studentAssessment"]);
});

test("display category, titles, order and search", () => {
  assert.equal(displayCategory({ category: "other", frequency: "weekly" }), "teaching");
  assert.equal(displayCategory({ category: "other", frequency: "onDemand" }), "other");
  assert.equal(categoryTitle("feedback"), "Feedback & Complaints");
  const names = sortSection("other", [make("b", { name: "beta" }), make("a", { name: "Zeta" }), make("c", { name: "Alpha" })]).map((t) => t.name);
  assert.deepEqual(names, ["Alpha", "Zeta", "beta"], "code-unit order, as Dart compareTo");
  const form = make("x", { name: "Class Complain Form", description: "Tell us" });
  assert.equal(matchesFormSearch(form, "other", "complain"), true);
  assert.equal(matchesFormSearch(form, "other", "other forms"), true);
  assert.equal(matchesFormSearch(form, "other", "anytime"), true);
  assert.equal(matchesFormSearch(form, "other", "zzz"), false);
});

test("availability: weekly Sun–Tue, monthly last 3 / first 3 days, others always", () => {
  assert.equal(availableToday("weekly", new Date(2026, 10, 15)), true, "Sunday");
  assert.equal(availableToday("weekly", new Date(2026, 10, 18)), false, "Wednesday");
  assert.equal(availableToday("monthly", new Date(2026, 10, 28)), true);
  assert.equal(availableToday("monthly", new Date(2026, 11, 3)), true);
  assert.equal(availableToday("monthly", new Date(2026, 10, 15)), false);
  assert.equal(availableToday("onDemand", new Date(2026, 10, 15)), true);
});

test("item count leaves out locked auto-filled fields", () => {
  const t = templateFromDoc("a", { fields: [{ id: "a" }, { id: "b" }, { id: "c" }], autoFillRules: [{ fieldId: "a" }, { fieldId: "b", editable: true }] });
  assert.equal(visibleFieldCount(t), 2);
});

test("filling in: display blocks, d/M/yyyy dates, the app's messages", () => {
  assert.equal(isDisplayBlock("heading"), true);
  assert.equal(isDisplayBlock("video"), true);
  assert.equal(isDisplayBlock("text"), false);
  assert.equal(storedDate("2026-11-03"), "3/11/2026");
  assert.equal(storedDate(""), "");
  assert.equal(requiredMessage({ type: "text", label: "Name", options: [] }), "Please enter Name");
  assert.equal(requiredMessage({ type: "dropdown", label: "Reason", options: [] }), "Please select a Reason");
  assert.equal(requiredMessage({ type: "radio", label: "Rating", options: ["a"] }), "Please select an option for Rating");
  assert.equal(requiredMessage({ type: "multi_select", label: "Days", options: ["a"] }), "Please select at least one option for Days");
  assert.equal(requiredMessage({ type: "date", label: "When", options: [] }), "Please select a date");
  assert.equal(requiredMessage({ type: "long_text", label: "Please explain the absence", options: [] }), "Please fill in this question");
  assert.equal(formatMessage("email", "a@b"), "Please enter a valid email address");
  assert.equal(formatMessage("phone", "+1 646-555"), null);
  assert.equal(formatMessage("number", "abc"), "Please enter a valid number");
});

test("submission document: the app's fields, four owner fields, no role", () => {
  const data = parentSubmissionData({ form: excuse, uid: "p1", email: "p@x.org", firstName: "Awa", lastName: "Bah", now: new Date(2026, 10, 15, 10), sessionId: "s" });
  assert.equal(data.formId, "parent_student_excuse");
  assert.equal(data.templateId, "parent_student_excuse");
  assert.equal(data.formType, "onDemand");
  assert.equal(data.frequency, "onDemand");
  for (const key of ["userId", "submittedBy", "teacherId", "teacher_id"] as const) assert.equal(data[key], "p1");
  assert.equal(data.yearMonth, "2026-11");
  assert.equal(data.status, "completed");
  assert.equal("userRole" in data, false);
  assert.equal(data.reportingContext.platform, "web");
  assert.equal(parentSubmissionData({ form: { id: "m", name: "M", frequency: "monthly" }, uid: "p", email: null, firstName: "", lastName: "", now: new Date(), sessionId: "s" }).formType, "monthly");
});

test("built-in forms: excuse fields and labels for My Submissions", () => {
  assert.deepEqual(excuse.fields.map((f) => [f.id, f.type, f.required]), [
    ["student_name", "text", true],
    ["class_or_teacher", "text", false],
    ["absence_date", "date", true],
    ["reason", "dropdown", true],
    ["details", "long_text", true],
    ["preferred_contact", "dropdown", false],
  ]);
  assert.equal(builtInLayout(excuse).labels.student_name, "Child's full name");
  assert.equal(builtInLayout(PARENT_FEEDBACK_TEMPLATE).order.comments, 8);
  const unused: ParentFormTemplate = PARENT_FEEDBACK_TEMPLATE;
  assert.equal(unused.fields.length, 8);
});

test("forms, profile and settings are in the shell; filling in and submissions are full pages", () => {
  for (const id of ["forms", "profile", "settings"] as const) assert.equal(PARENT_WEB_SCREENS.has(id), true);
  assert.equal(isPushedParentPage(PARENT_ROUTES.forms), false);
  assert.equal(isPushedParentPage("/parent/forms/fill/"), true);
  assert.equal(isPushedParentPage(PARENT_ROUTES.formSubmissions), true);
  assert.equal(PARENT_ROUTES.formFill("a b"), "/parent/forms/fill/?id=a%20b");
});
