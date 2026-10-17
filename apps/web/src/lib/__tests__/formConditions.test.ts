import assert from "node:assert/strict";
import { test } from "node:test";
import { conditionAnswer, isConditionallyVisible, missingRequiredFieldIds, visibleFieldIds } from "../formConditions.ts";

const logic = (condition: string, extra: Record<string, unknown> = {}) => ({
  dependsOnFieldId: "parent",
  condition,
  expectedValue: null,
  expectedValues: null,
  isVisible: true,
  ...extra,
});
const answer = (value: unknown) => () => value as never;

test("no logic, or logic with no dependency, always shows the question", () => {
  assert.equal(isConditionallyVisible(undefined, answer(null)), true);
  assert.equal(isConditionallyVisible(null, answer(null)), true);
  assert.equal(isConditionallyVisible({ dependsOnFieldId: null, condition: null, isVisible: true }, answer(null)), true);
  assert.equal(isConditionallyVisible({ dependsOnFieldId: "parent", condition: null }, answer(null)), true);
});

test("equals / not_equals compare the parent answer", () => {
  assert.equal(isConditionallyVisible(logic("equals", { expectedValue: "A Teacher" }), answer("A Teacher")), true);
  assert.equal(isConditionallyVisible(logic("equals", { expectedValue: "A Teacher" }), answer("A student")), false);
  assert.equal(isConditionallyVisible(logic("not_equals", { expectedValue: "A student" }), answer("A leader")), true);
  assert.equal(isConditionallyVisible(logic("not_equals", { expectedValue: "A student" }), answer(null)), true);
  assert.equal(isConditionallyVisible(logic("equals", { expectedValue: true }), answer(true)), true);
});

test("a list answer never equals anything, as in Dart", () => {
  assert.equal(isConditionallyVisible(logic("equals", { expectedValue: ["a"] }), answer(["a"])), false);
  assert.equal(isConditionallyVisible(logic("not_equals", { expectedValue: "a" }), answer(["a"])), true);
});

test("contains on a text answer is a substring check; on a list it is membership", () => {
  assert.equal(isConditionallyVisible(logic("contains", { expectedValue: "Teacher" }), answer("A Teacher")), true);
  assert.equal(isConditionallyVisible(logic("contains", { expectedValue: "Leader" }), answer("A Teacher")), false);
  assert.equal(isConditionallyVisible(logic("contains", { expectedValue: "b" }), answer(["a", "b"])), true);
  assert.equal(isConditionallyVisible(logic("contains", { expectedValue: "b" }), answer(null)), false);
});

test("multi-select contains / contains_all / contains_exactly use expectedValues", () => {
  const ticked = answer(["Quran", "Arabic"]);
  assert.equal(isConditionallyVisible(logic("contains", { expectedValues: ["Arabic", "French"] }), ticked), true);
  assert.equal(isConditionallyVisible(logic("contains", { expectedValues: ["French"] }), ticked), false);
  assert.equal(isConditionallyVisible(logic("contains_all", { expectedValues: ["Arabic", "Quran"] }), ticked), true);
  assert.equal(isConditionallyVisible(logic("contains_all", { expectedValues: ["Arabic", "French"] }), ticked), false);
  assert.equal(isConditionallyVisible(logic("contains_exactly", { expectedValues: ["Arabic", "Quran"] }), ticked), true);
  assert.equal(isConditionallyVisible(logic("contains_exactly", { expectedValues: ["Arabic"] }), ticked), false);
  assert.equal(isConditionallyVisible(logic("contains", { expectedValues: ["Arabic"] }), answer("Arabic")), false);
  assert.equal(isConditionallyVisible(logic("contains_all", { expectedValues: [] }), ticked), false);
});

test("is_empty / is_not_empty treat null, empty text and an empty list as empty", () => {
  for (const empty of [null, "", []]) {
    assert.equal(isConditionallyVisible(logic("is_empty"), answer(empty)), true);
    assert.equal(isConditionallyVisible(logic("is_not_empty"), answer(empty)), false);
  }
  assert.equal(isConditionallyVisible(logic("is_not_empty"), answer(false)), true);
});

test("isVisible false hides the question when the condition is met", () => {
  assert.equal(isConditionallyVisible(logic("equals", { expectedValue: "x", isVisible: false }), answer("x")), false);
  assert.equal(isConditionallyVisible(logic("equals", { expectedValue: "x", isVisible: false }), answer("y")), true);
});

test("an unknown condition or a malformed shape hides the question", () => {
  assert.equal(isConditionallyVisible(logic("greater_than", { expectedValue: 1 }), answer("2")), false);
  assert.equal(isConditionallyVisible("broken", answer(null)), false);
  assert.equal(isConditionallyVisible(logic("equals", { isVisible: "yes" }), answer(null)), false);
  assert.equal(isConditionallyVisible(logic("contains", { expectedValues: "Arabic" }), answer(["Arabic"])), false);
});

test("answers are read the way the Flutter form stores them", () => {
  assert.equal(conditionAnswer({ id: "t", type: "text" }, "  hi  "), "hi");
  assert.equal(conditionAnswer({ id: "t", type: "text" }, "   "), null);
  assert.equal(conditionAnswer({ id: "b", type: "yes_no" }, "Yes"), true);
  assert.equal(conditionAnswer({ id: "b", type: "radio", options: [] }, "No"), false);
  assert.equal(conditionAnswer({ id: "r", type: "radio", options: ["A"] }, "A"), "A");
  assert.deepEqual(conditionAnswer({ id: "m", type: "multi_select" }, []), []);
  assert.equal(conditionAnswer({ id: "m", type: "multi_select" }, undefined), null);
});

const fields = [
  { id: "role", type: "dropdown", options: ["A student", "A Teacher"] },
  { id: "teacher_docs", type: "text", conditionalLogic: { dependsOnFieldId: "role", condition: "equals", expectedValue: "A Teacher", isVisible: true } },
  { id: "doc_details", type: "text", conditionalLogic: { dependsOnFieldId: "teacher_docs", condition: "is_not_empty", isVisible: true } },
  { id: "subjects", type: "multi_select", options: ["Quran", "Arabic"] },
  { id: "arabic_level", type: "radio", options: ["Low", "High"], conditionalLogic: { dependsOnFieldId: "subjects", condition: "contains", expectedValues: ["Arabic"], isVisible: true } },
];

test("visibleFieldIds applies each question's condition to the live answers", () => {
  assert.deepEqual([...visibleFieldIds(fields, {})].sort(), ["role", "subjects"]);
  assert.deepEqual([...visibleFieldIds(fields, { role: "A Teacher", subjects: ["Arabic"] })].sort(), ["arabic_level", "role", "subjects", "teacher_docs"]);
});

test("a chain follows each link's live answer, like the Flutter form", () => {
  const values = { role: "A Teacher", teacher_docs: "ID card" };
  assert.equal(visibleFieldIds(fields, values).has("doc_details"), true);
  const switched = { role: "A student", teacher_docs: "ID card" };
  const visible = visibleFieldIds(fields, switched);
  assert.equal(visible.has("teacher_docs"), false);
  assert.equal(visible.has("doc_details"), true);
});

test("a hidden required question does not block submission", () => {
  const withRequired = fields.map((field) => ({ ...field, required: field.id !== "doc_details" }));
  assert.deepEqual(missingRequiredFieldIds(withRequired, { role: "A student", subjects: ["Quran"] }), []);
  assert.deepEqual(missingRequiredFieldIds(withRequired, { role: "A Teacher", subjects: ["Quran"] }), ["teacher_docs"]);
  assert.deepEqual(missingRequiredFieldIds(withRequired, { role: "A Teacher", subjects: ["Arabic"], teacher_docs: "ID" }), ["arabic_level"]);
});
