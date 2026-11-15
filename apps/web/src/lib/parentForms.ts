/**
 * Pure rules behind the parent Forms page (Flutter ParentFormsScreen →
 * TeacherFormsScreen(parentOnly) → FormScreen). No Firebase here, so each rule
 * is unit-tested against the Flutter behaviour it mirrors (inventory B-123…B-142).
 */
import { audienceIncludes, parseFormAudience } from "./formAudience.ts";

type Data = Record<string, unknown>;

export type FormFrequency = "perSession" | "weekly" | "monthly" | "onDemand";
export type FormCategory = "teaching" | "studentAssessment" | "feedback" | "administrative" | "other";

export type ParentFormField = {
  id: string;
  label: string;
  type: string;
  placeholder: string;
  required: boolean;
  order: number;
  options: string[];
  conditionalLogic?: unknown;
};

export type ParentFormTemplate = {
  id: string;
  name: string;
  description: string;
  frequency: FormFrequency;
  category: FormCategory;
  version: number;
  updatedAt: number;
  isActive: boolean;
  allowedRoles: string[] | null;
  fields: ParentFormField[];
  /** Fields an auto-fill rule fills and the user may not edit (hidden from the count). */
  hiddenAutoFill: string[];
  /** Built into the app rather than stored in form_templates. */
  builtIn?: boolean;
};

const FREQUENCIES: FormFrequency[] = ["perSession", "weekly", "monthly", "onDemand"];
const CATEGORIES: FormCategory[] = ["teaching", "studentAssessment", "feedback", "administrative", "other"];

/** FormFieldDefinition.fromMap + FormTemplate.fromFirestore. */
export function templateFromDoc(id: string, data: Data): ParentFormTemplate {
  const raw = data.fields;
  let fields: ParentFormField[] = [];
  if (Array.isArray(raw)) {
    fields = raw.map((item, index) => fieldFromMap(stringOf((item as Data)?.id) || `field_${index}`, (item as Data) ?? {}));
  } else if (raw && typeof raw === "object") {
    fields = Object.entries(raw as Data).map(([key, item]) => fieldFromMap(key, (item as Data) ?? {}));
  }
  fields = stableSort(fields, (a, b) => a.order - b.order);

  const rules = Array.isArray(data.autoFillRules) ? data.autoFillRules : data.autoFillRules && typeof data.autoFillRules === "object" ? Object.values(data.autoFillRules as Data) : [];
  const hiddenAutoFill = rules
    .filter((rule): rule is Data => Boolean(rule) && typeof rule === "object")
    .filter((rule) => rule.editable !== true)
    .map((rule) => stringOf(rule.fieldId));

  const frequency = FREQUENCIES.find((value) => value === data.frequency) ?? "perSession";
  const category = CATEGORIES.find((value) => value === data.category) ?? "other";
  return {
    id,
    name: typeof data.name === "string" ? data.name : "Untitled",
    description: typeof data.description === "string" ? data.description : "",
    frequency,
    category,
    version: typeof data.version === "number" && Number.isInteger(data.version) ? data.version : 1,
    updatedAt: millisOf(data.updatedAt),
    isActive: typeof data.isActive === "boolean" ? data.isActive : true,
    allowedRoles: parseFormAudience(data),
    fields,
    hiddenAutoFill,
  };
}

function fieldFromMap(id: string, map: Data): ParentFormField {
  const field: ParentFormField = {
    id,
    label: typeof map.label === "string" ? map.label : "",
    type: typeof map.type === "string" ? map.type : "text",
    placeholder: typeof map.placeholder === "string" ? map.placeholder : "",
    required: map.required === true,
    order: typeof map.order === "number" && Number.isInteger(map.order) ? map.order : 0,
    options: Array.isArray(map.options) ? map.options.filter((option): option is string => typeof option === "string") : [],
  };
  if (map.conditionalLogic && typeof map.conditionalLogic === "object") field.conditionalLogic = map.conditionalLogic;
  return field;
}

// ─── Which forms a parent sees (ParentFormAccessPolicy) ───────────────────

function normalizeName(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

/** The built-in parent forms, shown whatever audience they carry. */
export function isBuiltInParentForm(template: { id: string; name: string }) {
  const id = template.id.trim().toLowerCase();
  const name = normalizeName(template.name);
  return (
    id === "parent_feedback" ||
    id === "parent_student_excuse" ||
    name.includes("parent guardian feedback") ||
    name.includes("student absence excuse request") ||
    name.includes("demande d excuse d absence de l eleve") ||
    name.includes("feedback for leaders") ||
    name.includes("commentaires pour les dirigeants")
  );
}

export function parentMaySee(template: ParentFormTemplate) {
  if (!template.isActive) return false;
  if (isBuiltInParentForm(template)) return true;
  return audienceIncludes(template.allowedRoles, "parent");
}

/**
 * TeacherFormsScreen._loadTemplates for a parent: the newest active copy of
 * each form name (higher version, then later update; names compared trimmed,
 * lower-case, spaces collapsed), then the parent policy, grouped by display
 * category. Then the built-in excuse form is always added, and the built-in
 * parent feedback form only when no visible form looks like a feedback form.
 */
export function parentFormSections(templates: ParentFormTemplate[], builtIns: { excuse: ParentFormTemplate; feedback: ParentFormTemplate }) {
  const latest = new Map<string, ParentFormTemplate>();
  for (const template of templates) {
    if (!template.isActive) continue;
    const key = template.name.trim().toLowerCase().replace(/\s+/g, " ");
    const existing = latest.get(key);
    if (!existing || template.version > existing.version || (template.version === existing.version && template.updatedAt > existing.updatedAt)) {
      latest.set(key, template);
    }
  }
  const byCategory = new Map<FormCategory, ParentFormTemplate[]>();
  const add = (category: FormCategory, template: ParentFormTemplate) => {
    const list = byCategory.get(category) ?? [];
    list.push(template);
    byCategory.set(category, list);
  };
  for (const template of latest.values()) {
    if (!parentMaySee(template)) continue;
    add(displayCategory(template), template);
  }
  add(builtIns.excuse.category, builtIns.excuse);
  const hasFeedback = [...byCategory.values()].flat().some((template) => template.name.toLowerCase().includes("feedback") || template.id === "parent_feedback");
  if (!hasFeedback) add("studentAssessment", builtIns.feedback);
  return byCategory;
}

/** When the form list cannot be loaded the parent still gets the two built-ins (B-129). */
export function fallbackSections(builtIns: { excuse: ParentFormTemplate; feedback: ParentFormTemplate }) {
  return new Map<FormCategory, ParentFormTemplate[]>([
    ["administrative", [builtIns.excuse]],
    ["studentAssessment", [builtIns.feedback]],
  ]);
}

/** "Other" forms with a daily/weekly/monthly frequency show under Teaching. */
export function displayCategory(template: Pick<ParentFormTemplate, "frequency" | "category">): FormCategory {
  if (template.category === "other" && template.frequency !== "onDemand") return "teaching";
  return template.category;
}

export const CATEGORY_ORDER: readonly FormCategory[] = ["teaching", "feedback", "studentAssessment", "administrative", "other"];

/** FormCategory.displayName (English in both languages, shown upper-case). */
export function categoryTitle(category: FormCategory) {
  switch (category) {
    case "teaching":
      return "Teaching Reports";
    case "studentAssessment":
      return "Student Assessment";
    case "feedback":
      return "Feedback & Complaints";
    case "administrative":
      return "Administrative";
    default:
      return "Other Forms";
  }
}

export const CATEGORY_COLORS: Readonly<Record<FormCategory, string>> = {
  teaching: "#10B981",
  studentAssessment: "#3B82F6",
  feedback: "#8B5CF6",
  administrative: "#F59E0B",
  other: "#64748B",
};

export function frequencyLabel(frequency: FormFrequency) {
  switch (frequency) {
    case "perSession":
      return "Daily";
    case "weekly":
      return "Weekly";
    case "monthly":
      return "Monthly";
    default:
      return "Anytime";
  }
}

/** The lock badge text (Flutter shows it on Teaching cards only). */
export function availabilityLabel(frequency: FormFrequency) {
  if (frequency === "weekly") return "Sun-Tue";
  if (frequency === "monthly") return "End/Start";
  return "Locked";
}

/** FormFrequencyAvailability.isAvailableToday. */
export function availableToday(frequency: FormFrequency, now: Date) {
  if (frequency === "weekly") {
    const day = now.getDay();
    return day === 0 || day === 1 || day === 2;
  }
  if (frequency === "monthly") {
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    const day = now.getDate();
    return day >= daysInMonth - 2 || day <= 3;
  }
  return true;
}

/** Cards inside a section: Teaching by frequency, the rest A→Z by name (code-unit order, as Dart). */
export function sortSection(category: FormCategory, templates: ParentFormTemplate[]) {
  if (category === "teaching") {
    const rank: Record<FormFrequency, number> = { perSession: 0, weekly: 1, monthly: 2, onDemand: 3 };
    return stableSort(templates, (a, b) => rank[a.frequency] - rank[b.frequency]);
  }
  return stableSort(templates, (a, b) => (a.name === b.name ? 0 : a.name < b.name ? -1 : 1));
}

/** Search: name, description, section title or frequency word (B-132). */
export function matchesFormSearch(template: ParentFormTemplate, category: FormCategory, query: string) {
  const q = query.toLowerCase().trim();
  if (!q) return true;
  return [template.name, template.description, categoryTitle(category), frequencyLabel(template.frequency)].some((value) => value.toLowerCase().trim().includes(q));
}

/** "<n> items": every field except auto-filled ones the user may not edit. */
export function visibleFieldCount(template: ParentFormTemplate) {
  const hidden = new Set(template.hiddenAutoFill);
  return template.fields.filter((field) => !hidden.has(field.id)).length;
}

// ─── Built-in forms ────────────────────────────────────────────────────────

/** The absence excuse form, in the parent's language (ParentFormsScreen). */
export function excuseTemplate(text: {
  title: string;
  description: string;
  studentName: string;
  classOrTeacher: string;
  absenceDate: string;
  reason: string;
  reasons: string[];
  details: string;
  preferredContact: string;
  contacts: string[];
}): ParentFormTemplate {
  return {
    id: "parent_student_excuse",
    name: text.title,
    description: text.description,
    frequency: "onDemand",
    category: "administrative",
    version: 1,
    updatedAt: 0,
    isActive: true,
    allowedRoles: ["parent"],
    builtIn: true,
    hiddenAutoFill: [],
    fields: [
      builtInField("student_name", text.studentName, "text", 1, true),
      builtInField("class_or_teacher", text.classOrTeacher, "text", 2, false),
      builtInField("absence_date", text.absenceDate, "date", 3, true),
      builtInField("reason", text.reason, "dropdown", 4, true, text.reasons),
      builtInField("details", text.details, "long_text", 5, true),
      builtInField("preferred_contact", text.preferredContact, "dropdown", 6, false, text.contacts),
    ],
  };
}

/** FormTemplateService.defaultParentFeedback — English only, as in the app. */
export const PARENT_FEEDBACK_TEMPLATE: ParentFormTemplate = {
  id: "parent_feedback",
  name: "Parent/Guardian Feedback",
  description: "Collect feedback from parents about their child's teacher",
  frequency: "onDemand",
  category: "studentAssessment",
  version: 1,
  updatedAt: 0,
  isActive: true,
  allowedRoles: null,
  builtIn: true,
  hiddenAutoFill: [],
  fields: [
    builtInField("teacher_name", "Teacher Name", "text", 1, true),
    builtInField("child_name", "Child's Name", "text", 2, true),
    builtInField("overall_satisfaction", "Overall Satisfaction with Teacher", "radio", 3, true, ["Very Satisfied", "Satisfied", "Neutral", "Dissatisfied", "Very Dissatisfied"]),
    builtInField("communication_quality", "Quality of Communication", "radio", 4, true, ["Excellent", "Good", "Average", "Poor"]),
    builtInField("child_progress", "Is your child making progress?", "radio", 5, true, ["Significant progress", "Some progress", "Little progress", "No progress"]),
    builtInField("punctuality", "Teacher Punctuality", "radio", 6, true, ["Always on time", "Usually on time", "Sometimes late", "Often late"]),
    builtInField("recommendation", "Would you recommend this teacher?", "radio", 7, true, ["Definitely yes", "Probably yes", "Not sure", "Probably no", "Definitely no"]),
    { ...builtInField("comments", "Additional Comments", "long_text", 8, false), placeholder: "Any other feedback or suggestions..." },
  ],
};

function builtInField(id: string, label: string, type: string, order: number, required: boolean, options: string[] = []): ParentFormField {
  return { id, label, type, placeholder: "", required, order, options };
}

// ─── Filling in a form (FormScreen) ────────────────────────────────────────

/** Display-only blocks: they show content and are never part of the answers. */
export function isDisplayBlock(type: string) {
  return type === "heading" || type === "section" || type === "image" || type === "video";
}

/** The browser gives yyyy-MM-dd; the app stores d/M/yyyy with no leading zeros. */
export function storedDate(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value.trim());
  if (!match) return value;
  return `${Number(match[3])}/${Number(match[2])}/${Number(match[1])}`;
}

/** The message the app shows for an unanswered required question. */
export function requiredMessage(field: Pick<ParentFormField, "type" | "label" | "options">) {
  // A label that is itself an instruction ("Please explain the absence") would read
  // "Please enter Please explain…", so it gets a plain sentence instead.
  if (/^please\b/i.test(field.label.trim()) && field.type !== "date") return field.options.length > 0 || field.type === "multi_select" ? "Please choose an answer" : "Please fill in this question";
  switch (field.type) {
    case "dropdown":
    case "select":
      return `Please select a ${field.label}`;
    case "multi_select":
      return `Please select at least one option for ${field.label}`;
    case "date":
      return "Please select a date";
    case "radio":
      return field.options.length > 0 ? `Please select an option for ${field.label}` : null;
    case "boolean":
    case "yes_no":
    case "yesNo":
      return null;
    default:
      return `Please enter ${field.label}`;
  }
}

/** Format checks the app runs on a non-empty answer. */
export function formatMessage(type: string, value: string) {
  const text = value.trim();
  if (!text) return null;
  if (type === "email" && !/^[^@]+@[^@]+\.[^@]+$/.test(text)) return "Please enter a valid email address";
  if (type === "phone" && !/^\+?[\d\s-]+$/.test(text)) return "Please enter a valid phone number";
  if (type === "number" && !Number.isFinite(Number(text))) return "Please enter a valid number";
  return null;
}

function formTypeFor(frequency: FormFrequency) {
  if (frequency === "perSession") return "daily";
  return frequency;
}

/**
 * The form_responses document a parent's submission writes (B-138), apart from
 * the answers and server timestamps. All four owner fields carry the parent's
 * uid — My Submissions and the admin review screens look the row up by them.
 * No role field: the app writes none.
 */
export function parentSubmissionData({
  form,
  uid,
  email,
  firstName,
  lastName,
  now,
  sessionId,
}: {
  form: Pick<ParentFormTemplate, "id" | "name" | "frequency">;
  uid: string;
  email: string | null;
  firstName: string;
  lastName: string;
  now: Date;
  sessionId: string;
}) {
  return {
    formId: form.id,
    formName: form.name,
    formTitle: form.name,
    formType: formTypeFor(form.frequency),
    templateId: form.id,
    frequency: form.frequency,
    userId: uid,
    submittedBy: uid,
    teacherId: uid,
    teacher_id: uid,
    userEmail: email,
    firstName,
    lastName,
    userFirstName: firstName,
    userLastName: lastName,
    status: "completed",
    yearMonth: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`,
    reportingContext: {
      appSessionId: sessionId,
      platform: "web",
      clientTimestamp: now.toISOString(),
      recentBreadcrumbs: [] as string[],
    },
  };
}

/** Labels and order for the answers of a built-in form, which form_templates does not hold. */
export function builtInLayout(template: ParentFormTemplate) {
  return {
    labels: Object.fromEntries(template.fields.map((field) => [field.id, field.label])),
    order: Object.fromEntries(template.fields.map((field) => [field.id, field.order])),
  };
}

// ─── helpers ───────────────────────────────────────────────────────────────

function stringOf(value: unknown) {
  return typeof value === "string" ? value : "";
}

function millisOf(value: unknown) {
  if (value && typeof value === "object" && "toMillis" in value && typeof (value as { toMillis: unknown }).toMillis === "function") {
    return (value as { toMillis: () => number }).toMillis();
  }
  // FormTemplate.fromFirestore uses "now" for a missing updatedAt.
  return Date.now();
}

function stableSort<T>(list: T[], compare: (a: T, b: T) => number) {
  return list
    .map((item, index) => ({ item, index }))
    .sort((a, b) => compare(a.item, b.item) || a.index - b.index)
    .map((entry) => entry.item);
}
