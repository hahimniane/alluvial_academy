/**
 * Form links (/form/?id=<templateId>): the pure rules behind the page. No
 * Firebase here, so each rule is unit-tested. The callables in
 * functions/handlers/public_forms.js apply the same limits on the server.
 */
import { audienceIncludes } from "./formAudience.ts";
import { isBuiltInParentForm, isDisplayBlock, storedDate } from "./parentForms.ts";

/** What getPublicForm tells the page about a form. */
export type PublicFormInfo = {
  found: boolean;
  available: boolean;
  id?: string;
  title?: string;
  description?: string;
  category?: string;
  frequency?: string;
  audience?: string[];
  fields?: unknown;
};

export const PUBLIC_FORM_LIMITS = { nameMin: 2, nameMax: 100, phoneMin: 6, phoneMax: 25, phoneDigitsMin: 6, answerMax: 5000 } as const;

const FILE_TYPES = new Set(["image_upload", "imageUpload", "signature", "file", "file_upload", "fileUpload"]);
const YES_NO_TYPES = new Set(["boolean", "yes_no", "yesNo"]);

/** Questions that take a file: shown on a form link, but not answerable there. */
export function isFileField(type: string) {
  return FILE_TYPES.has(type);
}

/** The full name as stored: trimmed, inner spaces collapsed. Null when it is too short or too long. */
export function cleanSubmitterName(value: string): string | null {
  const name = value.trim().replace(/\s+/g, " ");
  return name.length >= PUBLIC_FORM_LIMITS.nameMin && name.length <= PUBLIC_FORM_LIMITS.nameMax ? name : null;
}

/** A phone / WhatsApp number: digits, spaces, dashes and a leading +. Null when it is not one. */
export function cleanSubmitterPhone(value: string): string | null {
  const phone = value.trim().replace(/\s+/g, " ");
  const digits = phone.replace(/\D/g, "");
  if (phone.length < PUBLIC_FORM_LIMITS.phoneMin || phone.length > PUBLIC_FORM_LIMITS.phoneMax) return null;
  if (!/^\+?[\d\s-]+$/.test(phone) || digits.length < PUBLIC_FORM_LIMITS.phoneDigitsMin) return null;
  return phone;
}

type FieldLike = { id: string; type: string; options: readonly string[] };

/**
 * The answers sent from a form link, as a signed-in submission stores them:
 * only questions on screen, never display blocks or file questions; an
 * unanswered question as ""; Yes/No as true / false; dates as d/M/yyyy.
 */
export function publicAnswers(fields: readonly FieldLike[], shown: ReadonlySet<string>, values: Readonly<Record<string, unknown>>) {
  const out: Record<string, string | boolean | string[]> = {};
  for (const field of fields) {
    if (!shown.has(field.id) || isDisplayBlock(field.type) || isFileField(field.type)) continue;
    const value = values[field.id];
    const yesNo = YES_NO_TYPES.has(field.type) || (field.type === "radio" && field.options.length === 0);
    if (Array.isArray(value)) out[field.id] = value.map(String);
    else if (typeof value !== "string" || value === "") out[field.id] = "";
    else if (yesNo) out[field.id] = value === "Yes";
    else out[field.id] = field.type === "date" ? storedDate(value) : value;
  }
  return out;
}

const TEACHER_CATEGORIES = new Set(["teaching", "feedback", "administrative", "studentAssessment"]);
const TEACHER_FREQUENCIES = new Set(["perSession", "weekly", "monthly"]);

/**
 * Where a signed-in member fills in a linked form: their own role's form page,
 * when that page lists the form. Null when it does not (the form link then
 * serves them like a visitor, or tells them it is not for their account).
 * `dashboardPath` is what dashboardPathForUser gives.
 */
export function memberFillPath(dashboardPath: string, form: Pick<PublicFormInfo, "id" | "title" | "audience" | "category" | "frequency">): string | null {
  const id = form.id ?? "";
  if (!id) return null;
  const audience = form.audience ?? [];
  const encoded = encodeURIComponent(id);
  if (dashboardPath === "/parent/") {
    const forParents = isBuiltInParentForm({ id, name: form.title ?? "" }) || audienceIncludes(audience, "parent");
    return forParents ? `/parent/forms/fill/?id=${encoded}` : null;
  }
  if (dashboardPath === "/student/") {
    return audienceIncludes(audience, "student") ? `/student/forms/?id=${encoded}` : null;
  }
  if (dashboardPath === "/teacher/") {
    // The teacher Submit Form page's rule: the audience when there is one, the category or frequency otherwise.
    const forTeachers = audience.length > 0 ? audienceIncludes(audience, "teacher") : TEACHER_CATEGORIES.has(form.category ?? "") || TEACHER_FREQUENCIES.has(form.frequency ?? "");
    return forTeachers ? `/teacher/submit-form/?form=${encoded}` : null;
  }
  return null;
}

/** The message for a failed send, keyed by the callable's error code. */
export function publicSubmitError(error: unknown) {
  const code = String((error as { code?: unknown } | null)?.code ?? "");
  if (code.endsWith("resource-exhausted")) return "This number has sent this form the most times allowed today. Try again tomorrow.";
  if (code.endsWith("failed-precondition") || code.endsWith("not-found")) return "This form is no longer available.";
  if (code.endsWith("invalid-argument")) return "Some answers could not be sent. Check them and try again.";
  return "Could not send your answers. Check your connection and try again.";
}
