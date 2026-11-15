"use client";

/**
 * Firestore reads and writes behind the parent Forms pages: the same
 * collection, document shape and Storage folder the app uses.
 */
import { addDoc, collection, doc, getDoc, getDocs, serverTimestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { PARENT_FEEDBACK_TEMPLATE, excuseTemplate, parentSubmissionData, templateFromDoc, type ParentFormTemplate } from "@/lib/parentForms";
import type { ParentFormsText } from "@/lib/parentFormsText";

export function parentBuiltIns(text: ParentFormsText) {
  return {
    excuse: excuseTemplate({
      title: text.excuseTitle,
      description: text.excuseDescription,
      studentName: text.excuseStudentName,
      classOrTeacher: text.excuseClassOrTeacher,
      absenceDate: text.excuseAbsenceDate,
      reason: text.excuseReason,
      reasons: text.excuseReasons,
      details: text.excuseDetails,
      preferredContact: text.excusePreferredContact,
      contacts: text.excuseContacts,
    }),
    feedback: PARENT_FEEDBACK_TEMPLATE,
  };
}

/** Every form template (FormTemplateService.getAllTemplates, read from the server). */
export async function loadFormTemplates(): Promise<ParentFormTemplate[]> {
  const snap = await getDocs(collection(db, "form_templates"));
  return snap.docs.map((entry) => templateFromDoc(entry.id, entry.data() as Record<string, unknown>));
}

/** One form by id: a built-in one, or the stored template. Null when it does not exist. */
export async function loadFormTemplate(id: string, builtIns: ReturnType<typeof parentBuiltIns>): Promise<ParentFormTemplate | null> {
  if (id === builtIns.excuse.id) return builtIns.excuse;
  if (id === builtIns.feedback.id) {
    // A stored parent_feedback template takes the place of the built-in one.
    const stored = await getDoc(doc(db, "form_templates", id));
    return stored.exists() ? templateFromDoc(stored.id, stored.data() as Record<string, unknown>) : builtIns.feedback;
  }
  const snap = await getDoc(doc(db, "form_templates", id));
  return snap.exists() ? templateFromDoc(snap.id, snap.data() as Record<string, unknown>) : null;
}

let sessionId = "";
function appSessionId() {
  if (!sessionId) sessionId = `web_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
  return sessionId;
}

/**
 * Writes the form_responses document (FormScreen._submitForm). Names come from
 * the parent's own user document, as in the app. The write gives up after 30
 * seconds, like the app's.
 */
export async function submitParentForm({
  form,
  uid,
  email,
  responses,
}: {
  form: ParentFormTemplate;
  uid: string;
  email: string | null;
  responses: Record<string, unknown>;
}) {
  let firstName = "";
  let lastName = "";
  try {
    const user = await getDoc(doc(db, "users", uid));
    const data = (user.data() ?? {}) as Record<string, unknown>;
    firstName = String(data.first_name ?? data.firstName ?? "");
    lastName = String(data.last_name ?? data.lastName ?? "");
  } catch {
    // The app submits without the names when the profile cannot be read.
  }
  const write = addDoc(collection(db, "form_responses"), {
    ...parentSubmissionData({ form, uid, email, firstName, lastName, now: new Date(), sessionId: appSessionId() }),
    responses,
    submittedAt: serverTimestamp(),
    lastUpdated: serverTimestamp(),
  });
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error("unavailable: the submission timed out")), 30_000);
  });
  try {
    return await Promise.race([write, timeout]);
  } finally {
    clearTimeout(timer);
  }
}
