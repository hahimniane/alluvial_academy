/**
 * Conditional questions ("show only if").
 *
 * A question can carry `conditionalLogic`:
 *   { dependsOnFieldId, condition, expectedValue, expectedValues, isVisible }
 * The Flutter form (lib/features/forms/screens/form_screen.dart,
 * `_shouldShowField` / `_getCurrentFieldValue`) is the reference, and this
 * mirrors it rule for rule so a form behaves the same on both:
 *
 * - no logic, or no `dependsOnFieldId` / `condition` -> always shown;
 * - the question it depends on is read by its current answer, whether or not
 *   that question is itself shown (a chain follows each link's live answer);
 * - text answers are trimmed and an empty one counts as no answer; Yes/No
 *   questions answer `true` / `false`; checkbox questions answer the list of
 *   ticked options (an emptied list stays an empty list);
 * - `equals` / `not_equals` compare like Dart `==`, so a list never equals
 *   anything;
 * - `isVisible: false` turns "show when met" into "hide when met";
 * - logic Flutter cannot evaluate (a malformed shape) hides the question,
 *   because Flutter's evaluation throws and skips it.
 */

export type ConditionAnswer = string | boolean | unknown[] | Record<string, unknown> | null;

type FieldLike = {
  id: string;
  type: string;
  options?: readonly string[];
  conditionalLogic?: unknown;
};

const YES_NO_TYPES = new Set(["boolean", "yes_no", "yesNo"]);

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

/** Dart `==` for the values a form holds: strings and booleans by value, lists by identity. */
function dartEquals(a: unknown, b: unknown) {
  return a === b;
}

function listContains(list: unknown[], value: unknown) {
  return list.some((item) => dartEquals(item, value));
}

function dartIsNotEmpty(value: unknown): boolean | "error" {
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === "string") return value.length > 0;
  if (isPlainObject(value)) return Object.keys(value).length > 0;
  return "error";
}

/** The answer a question gives to the questions that depend on it, as Flutter stores it. */
export function conditionAnswer(field: FieldLike | undefined, value: unknown): ConditionAnswer {
  if (value === undefined || value === null) return null;
  const type = field?.type ?? "";
  const yesNo = YES_NO_TYPES.has(type) || (type === "radio" && (field?.options?.length ?? 0) === 0);
  if (yesNo) {
    if (value === "Yes" || value === true) return true;
    if (value === "No" || value === false) return false;
    return null;
  }
  if (Array.isArray(value)) return value;
  if (typeof value === "string") {
    if (type === "radio") return value;
    const text = value.trim();
    return text ? text : null;
  }
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return String(value);
  if (isPlainObject(value)) return value;
  return null;
}

/**
 * Whether a question with this `conditionalLogic` is shown, given a way to read
 * the current answer of any question by id.
 */
export function isConditionallyVisible(logic: unknown, answerOf: (fieldId: string) => ConditionAnswer): boolean {
  if (logic === undefined || logic === null) return true;
  if (!isPlainObject(logic)) return false;

  const dependsOnFieldId = logic.dependsOnFieldId;
  const condition = logic.condition;
  const expectedValue = logic.expectedValue === undefined ? null : logic.expectedValue;
  const expectedValues = logic.expectedValues === undefined ? null : logic.expectedValues;
  const isVisible = logic.isVisible === undefined || logic.isVisible === null ? true : logic.isVisible;

  if (dependsOnFieldId === null || dependsOnFieldId === undefined || condition === null || condition === undefined) return true;
  if (typeof dependsOnFieldId !== "string") return false;

  const dependentValue = answerOf(dependsOnFieldId);
  let met = false;
  switch (condition) {
    case "equals":
      met = dartEquals(dependentValue, expectedValue);
      break;
    case "not_equals":
      met = !dartEquals(dependentValue, expectedValue);
      break;
    case "contains": {
      const hasExpectedValues = expectedValues === null ? false : dartIsNotEmpty(expectedValues);
      if (hasExpectedValues === "error") return false;
      if (hasExpectedValues) {
        if (!Array.isArray(expectedValues)) return false;
        if (Array.isArray(dependentValue)) met = expectedValues.some((expected) => listContains(dependentValue, expected));
      } else if (Array.isArray(dependentValue)) {
        met = listContains(dependentValue, expectedValue);
      } else if (typeof dependentValue === "string") {
        met = dependentValue.includes(expectedValue === null ? "" : String(expectedValue));
      }
      break;
    }
    case "contains_all":
    case "contains_exactly": {
      const hasExpectedValues = expectedValues === null ? false : dartIsNotEmpty(expectedValues);
      if (hasExpectedValues === "error") return false;
      if (hasExpectedValues) {
        if (!Array.isArray(expectedValues)) return false;
        if (Array.isArray(dependentValue)) {
          if (condition === "contains_all") {
            met = expectedValues.every((expected) => listContains(dependentValue, expected));
          } else {
            const dependentSet = new Set(dependentValue);
            const expectedSet = new Set(expectedValues);
            met = dependentSet.size === expectedSet.size && [...expectedSet].every((expected) => dependentSet.has(expected));
          }
        }
      }
      break;
    }
    case "is_empty":
      met = dependentValue === null || dependentValue === "" || (Array.isArray(dependentValue) && dependentValue.length === 0);
      break;
    case "is_not_empty":
      met = dependentValue !== null && dependentValue !== "" && !(Array.isArray(dependentValue) && dependentValue.length === 0);
      break;
    default:
      met = false;
  }

  if (typeof isVisible !== "boolean") return false;
  return isVisible ? met : !met;
}

/** Ids of the questions currently shown, given the answers so far. */
export function visibleFieldIds(fields: readonly FieldLike[], values: Readonly<Record<string, unknown>>): Set<string> {
  const byId = new Map(fields.map((field) => [field.id, field]));
  const answerOf = (fieldId: string) => conditionAnswer(byId.get(fieldId), values[fieldId]);
  const visible = new Set<string>();
  for (const field of fields) {
    if (isConditionallyVisible(field.conditionalLogic, answerOf)) visible.add(field.id);
  }
  return visible;
}

/** An answer that counts as "not answered" for a required question. */
export function isEmptyAnswer(value: unknown) {
  if (Array.isArray(value)) return value.length === 0;
  if (isPlainObject(value)) return false;
  return !String(value ?? "").trim();
}

/** Required questions that are shown and still unanswered. A hidden question never blocks a submission. */
export function missingRequiredFieldIds(fields: readonly (FieldLike & { required: boolean })[], values: Readonly<Record<string, unknown>>): string[] {
  const shown = visibleFieldIds(fields, values);
  return fields.filter((field) => field.required && shown.has(field.id) && isEmptyAnswer(values[field.id])).map((field) => field.id);
}
