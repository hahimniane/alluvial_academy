import { doc, serverTimestamp, setDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

const DRAFT_ID_KEY = "alluwal_enrollment_draft_id";

export type EnrollmentDraftStudent = {
  name: string;
  age: string;
  gender: string;
  subject: string;
  level: string;
  classType: string;
  hoursPerWeek: number;
  preferredDays: string[];
  preferredTimeSlots: string[];
};

export type EnrollmentDraftPayload = {
  step: number;
  stepTitle: string;
  role: string;
  preferredLanguage: string;
  timeZone: string;
  students: EnrollmentDraftStudent[];
  contact: {
    email: string;
    phoneNumber: string;
    whatsAppNumber: string;
    parentName: string;
    city: string;
    countryName: string;
  };
};

export function draftHasReachableContact(payload: EnrollmentDraftPayload) {
  return Boolean(
    payload.contact.email.trim() ||
      payload.contact.phoneNumber.trim() ||
      payload.contact.whatsAppNumber.trim(),
  );
}

export function draftHasSignal(payload: EnrollmentDraftPayload) {
  return draftHasReachableContact(payload) || payload.students.some((student) => student.name.trim());
}

export async function saveEnrollmentDraft(payload: EnrollmentDraftPayload) {
  if (typeof window === "undefined") return;
  try {
    let id = window.localStorage.getItem(DRAFT_ID_KEY);
    const isNew = !id;
    if (!id) {
      id = crypto.randomUUID();
      window.localStorage.setItem(DRAFT_ID_KEY, id);
    }
    await setDoc(
      doc(db, "enrollment_drafts", id),
      {
        ...payload,
        status: "in_progress",
        source: "web_enroll_form",
        hasContact: draftHasReachableContact(payload),
        updatedAt: serverTimestamp(),
        ...(isNew ? { createdAt: serverTimestamp() } : {}),
      },
      { merge: true },
    );
  } catch {
    // Draft capture is best-effort and must never interrupt the applicant.
  }
}

export async function completeEnrollmentDraft() {
  if (typeof window === "undefined") return;
  try {
    const id = window.localStorage.getItem(DRAFT_ID_KEY);
    if (!id) return;
    await setDoc(
      doc(db, "enrollment_drafts", id),
      { status: "completed", completedAt: serverTimestamp(), updatedAt: serverTimestamp() },
      { merge: true },
    );
    window.localStorage.removeItem(DRAFT_ID_KEY);
  } catch {
    // Best-effort; the enrollment itself already succeeded.
  }
}
