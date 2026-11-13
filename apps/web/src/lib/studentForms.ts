/**
 * Pure helpers behind the student Forms page: which copy of a form to show,
 * and the document a submission writes.
 */
export type StudentFormSource = {
  id: string;
  name: string;
  version: number;
  updatedAt: number;
};

/**
 * One entry per form name, keeping the newest copy (highest version, then most
 * recently updated), sorted by name. Editing a form in the builder can leave
 * older copies behind; a student sees only the current one.
 */
export function latestStudentForms<T extends StudentFormSource>(forms: T[]): T[] {
  const byName = new Map<string, T>();
  for (const form of forms) {
    const key = form.name.trim().toLowerCase();
    const existing = byName.get(key);
    const newer =
      !existing ||
      form.version > existing.version ||
      (form.version === existing.version && form.updatedAt > existing.updatedAt);
    if (newer) byName.set(key, form);
  }
  return [...byName.values()].sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
}

function formTypeFor(frequency: string) {
  if (frequency === "weekly") return "weekly";
  if (frequency === "monthly") return "monthly";
  if (frequency === "perSession") return "daily";
  return "onDemand";
}

/**
 * The form_responses fields a student submission carries, apart from the
 * answers and server timestamps. Same shape the app writes (FormScreen), so
 * admins find it in All Submissions exactly like any other response.
 */
export function studentSubmissionData({
  form,
  uid,
  email,
  firstName,
  displayName,
  now,
}: {
  form: { id: string; name: string; frequency: string };
  uid: string;
  email: string;
  firstName: string;
  displayName: string;
  now: Date;
}) {
  const first = firstName.trim();
  const full = displayName.trim();
  const last = first && full.toLowerCase().startsWith(first.toLowerCase()) ? full.slice(first.length).trim() : "";
  return {
    formId: form.id,
    formName: form.name,
    formTitle: form.name,
    formType: formTypeFor(form.frequency),
    frequency: form.frequency,
    templateId: form.id,
    userId: uid,
    submittedBy: uid,
    teacherId: uid,
    teacher_id: uid,
    userRole: "student",
    userEmail: email,
    firstName: first,
    lastName: last,
    userFirstName: first,
    userLastName: last,
    status: "completed",
    yearMonth: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`,
    reportingContext: {},
  };
}
