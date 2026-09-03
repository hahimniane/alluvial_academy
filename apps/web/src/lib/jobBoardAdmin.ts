/**
 * Admin-side job board writes: broadcasting an enrollment to teachers, reading
 * what they answered, and confirming or declining a match.
 *
 * A direct port of `lib/features/dashboard/services/job_board_service.dart`.
 * The document shapes must stay identical — the Flutter teacher app, the
 * Next.js teacher job board and the Cloud Functions all read these same
 * documents, and the native admin app still writes them.
 */

import {
  Timestamp,
  addDoc,
  arrayUnion,
  collection,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import { auth, db } from "./firebase";

/** Set on a job auto-closed because a teacher said they were fully available. */
export const CLOSED_REASON_TEACHER_FULLY_AVAILABLE = "teacher_fully_available";

const record = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};

const text = (value: unknown): string => (typeof value === "string" ? value.trim() : "");

const list = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];

/** The admin's display name, matching how Flutter builds it. */
async function currentAdmin() {
  const user = auth.currentUser;
  if (!user) throw new Error("You must be signed in as an admin.");
  let name = user.email ?? "Admin";
  try {
    const snapshot = await getDoc(doc(db, "users", user.uid));
    if (snapshot.exists()) {
      const data = snapshot.data() as Record<string, unknown>;
      const full = `${text(data.first_name)} ${text(data.last_name)}`.trim();
      name = full || text(data["e-mail"]) || name;
    }
  } catch {
    // A missing or unreadable profile must not block the action itself.
  }
  return { uid: user.uid, email: user.email ?? "", name };
}

/* ------------------------------------------------------------- teachers -- */

export type TeacherOption = { id: string; name: string; email: string };

/**
 * Teachers eligible to receive a broadcast: primary teachers plus anyone
 * carrying teacher as a secondary role, minus deactivated accounts.
 */
export async function loadBroadcastTeachers(): Promise<TeacherOption[]> {
  const users = collection(db, "users");
  const [primary, secondary] = await Promise.all([
    getDocs(query(users, where("user_type", "==", "teacher"))),
    getDocs(query(users, where("secondary_roles", "array-contains", "teacher"))),
  ]);

  const found = new Map<string, TeacherOption>();
  for (const snapshot of [...primary.docs, ...secondary.docs]) {
    const data = snapshot.data() as Record<string, unknown>;
    if (data.is_active === false) continue;
    const name = `${text(data.first_name)} ${text(data.last_name)}`.trim();
    const email = text(data["e-mail"]) || text(data.email);
    found.set(snapshot.id, { id: snapshot.id, name: name || email || "Teacher", email });
  }
  return [...found.values()].sort((a, b) => a.name.localeCompare(b.name, "en", { sensitivity: "base" }));
}

/* ------------------------------------------------------------ broadcast -- */

export type BroadcastInput = {
  days: string[];
  timeSlots: string[];
  timeOfDay: string;
  timezoneRef: string;
  adminNotesForTeachers: string;
  targetTeacherIds: string[];
  targetTeacherNames: string[];
};

/**
 * Creates the job_board posting and moves the enrollment to `broadcasted`.
 *
 * The admin's edits to days, slots or time of day are recorded separately in
 * `metadata.adminScheduleEdits` — what the family asked for and what was sent
 * to teachers are different facts, and losing the first one makes a later
 * complaint impossible to answer.
 */
export async function broadcastEnrollment(enrollmentId: string, input: BroadcastInput): Promise<string> {
  const admin = await currentAdmin();

  const enrollmentRef = doc(db, "enrollments", enrollmentId);
  const snapshot = await getDoc(enrollmentRef);
  if (!snapshot.exists()) throw new Error("Enrollment not found.");
  const data = snapshot.data() as Record<string, unknown>;

  const contact = record(data.contact);
  const country = record(contact.country);
  const preferences = record(data.preferences);
  const metadata = record(data.metadata);
  const student = record(data.student);
  const program = record(data.program);

  const status = text(metadata.status) || "pending";
  if (status === "broadcasted" || status === "matched") {
    throw new Error(`Enrollment is already ${status}.`);
  }

  const originalDays = list(preferences.days ?? data.preferredDays);
  const originalSlots = list(preferences.timeSlots ?? data.preferredTimeSlots);
  const originalTimeOfDay = text(preferences.timeOfDayPreference ?? data.timeOfDayPreference);

  const studentTimezone = text(preferences.timeZone ?? data.timeZone) || "UTC";
  const timezoneRef = input.timezoneRef.trim() || studentTimezone;
  const notes = input.adminNotesForTeachers.trim();
  const hasTargets = input.targetTeacherIds.length > 0;
  const now = Timestamp.now();

  const broadcastSnapshot: Record<string, unknown> = {
    days: input.days,
    timeSlots: input.timeSlots,
    timeOfDayPreference: input.timeOfDay,
    timezoneRef,
    ...(notes ? { adminNotesForTeachers: notes } : {}),
    ...(hasTargets ? { targetTeacherIds: input.targetTeacherIds, targetTeacherNames: input.targetTeacherNames } : {}),
    broadcastedBy: admin.uid,
    broadcastedAt: now,
  };

  const jobData: Record<string, unknown> = {
    enrollmentId,
    studentName: text(student.name ?? data.studentName) || "Student",
    studentAge: text(student.age ?? data.studentAge) || "N/A",
    gender: text(student.gender ?? data.gender) || "Not specified",
    subject: text(data.subject) || "General",
    subject_display_name: text(data.programTitle ?? data.subject) || "General",
    specificLanguage: text(data.specificLanguage) || null,
    gradeLevel: text(data.gradeLevel),
    days: input.days,
    timeSlots: input.timeSlots,
    timeZone: studentTimezone,
    sessionDuration: text(program.sessionDuration ?? data.sessionDuration) || "60 minutes",
    // The window and session shape the teacher slot picker reads.
    block: text(data.block ?? preferences.timeOfDayPreference),
    sessionMinutes: Number(program.sessionMinutes) || null,
    sessionsPerWeek: Number(program.sessionsPerWeek) || null,
    timeOfDayPreference: input.timeOfDay,
    countryName: text(country.name ?? data.countryName),
    countryCode: text(country.code ?? data.countryCode),
    city: text(contact.city ?? data.city),
    classType: text(program.classType ?? data.classType),
    preferredLanguage: text(preferences.preferredLanguage ?? data.preferredLanguage),
    knowsZoom: student.knowsZoom ?? data.knowsZoom ?? null,
    isAdult: metadata.isAdult ?? data.isAdult ?? false,
    status: "open",
    createdAt: serverTimestamp(),
    parentEmail: text(contact.email) || null,
    parentName: text(contact.parentName) || null,
    parentLinkId: metadata.parentLinkId ?? null,
    studentIndex: metadata.studentIndex ?? null,
    totalStudents: metadata.totalStudents ?? null,
    broadcastSnapshot,
    scheduleTimezoneRef: timezoneRef,
    ...(notes ? { adminNotesForTeachers: notes } : {}),
    ...(hasTargets ? { targetTeacherIds: input.targetTeacherIds, targetTeacherNames: input.targetTeacherNames } : {}),
  };
  for (const key of Object.keys(jobData)) {
    if (jobData[key] === null || jobData[key] === undefined) delete jobData[key];
  }

  const jobRef = await addDoc(collection(db, "job_board"), jobData);

  const daysChanged = input.days.join(",") !== originalDays.join(",");
  const slotsChanged = input.timeSlots.join(",") !== originalSlots.join(",");
  const timeOfDayChanged = input.timeOfDay !== originalTimeOfDay;
  const scheduleEdits =
    daysChanged || slotsChanged || timeOfDayChanged
      ? {
          editedAt: Timestamp.now(),
          ...(daysChanged ? { originalDays, newDays: input.days } : {}),
          ...(slotsChanged ? { originalTimeSlots: originalSlots, newTimeSlots: input.timeSlots } : {}),
          ...(timeOfDayChanged ? { originalTimeOfDay, newTimeOfDay: input.timeOfDay } : {}),
        }
      : null;

  await updateDoc(enrollmentRef, {
    "metadata.status": "broadcasted",
    "metadata.broadcastedAt": serverTimestamp(),
    "metadata.jobId": jobRef.id,
    "metadata.broadcastedBy": admin.uid,
    "metadata.broadcastedByName": admin.name,
    "metadata.lastUpdated": serverTimestamp(),
    "metadata.updatedBy": admin.uid,
    "metadata.updatedByName": admin.name,
    "metadata.actionHistory": arrayUnion({
      action: "broadcasted",
      status: "broadcasted",
      adminId: admin.uid,
      adminName: admin.name,
      adminEmail: admin.email,
      jobId: jobRef.id,
      timestamp: Timestamp.now(),
    }),
    ...(scheduleEdits ? { "metadata.adminScheduleEdits": scheduleEdits } : {}),
    ...(notes ? { "metadata.adminNotesForTeachers": notes } : {}),
    "metadata.scheduleTimezoneRef": timezoneRef,
    "metadata.lastBroadcastSnapshot": broadcastSnapshot,
  });

  return jobRef.id;
}

/** Closes every job posting for this enrollment so teachers stop seeing it. */
export async function unbroadcastEnrollment(enrollmentId: string): Promise<number> {
  const admin = await currentAdmin();
  const jobs = await getDocs(query(collection(db, "job_board"), where("enrollmentId", "==", enrollmentId)));
  await Promise.all(jobs.docs.map((job) => updateDoc(job.ref, { status: "closed" })));

  await updateDoc(doc(db, "enrollments", enrollmentId), {
    "metadata.status": "contacted",
    "metadata.lastUpdated": serverTimestamp(),
    "metadata.updatedBy": admin.uid,
    "metadata.updatedByName": admin.name,
    "metadata.actionHistory": arrayUnion({
      action: "unbroadcasted",
      status: "contacted",
      adminId: admin.uid,
      adminName: admin.name,
      adminEmail: admin.email,
      timestamp: Timestamp.now(),
    }),
  });
  return jobs.size;
}

/* ------------------------------------------------------------ responses -- */

export type TeacherResponse = {
  teacherId: string;
  teacherName: string;
  teacherTimezone: string;
  availabilityStatus: string;
  comment: string;
  rankedSlots: string[];
  selectedTimes: Record<string, string>;
  adminRejected: boolean;
  adminRejectedNote: string;
  submittedAt: Date | null;
};

const dateOf = (value: unknown): Date | null => {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
};

export async function loadTeacherResponses(jobId: string): Promise<TeacherResponse[]> {
  const snapshot = await getDocs(collection(db, "job_board", jobId, "responses"));
  return snapshot.docs
    .map((responseDoc) => {
      const data = responseDoc.data() as Record<string, unknown>;
      const selected = record(data.selectedTimes ?? data.teacherSelectedTimes);
      return {
        teacherId: responseDoc.id,
        teacherName: text(data.teacherName) || "Teacher",
        teacherTimezone: text(data.teacherTimezone),
        availabilityStatus: text(data.availabilityStatus) || "available",
        comment: text(data.comment),
        // rankedSlots is the current field; availableAlternatives is what older
        // responses carry, and both mean the same thing.
        rankedSlots: list(data.rankedSlots).length ? list(data.rankedSlots) : list(data.availableAlternatives),
        selectedTimes: Object.fromEntries(
          Object.entries(selected).map(([day, time]) => [day, text(time)]),
        ),
        adminRejected: data.adminRejected === true,
        adminRejectedNote: text(data.adminRejectedNote),
        submittedAt: dateOf(data.submittedAt ?? data.updatedAt),
      };
    })
    .sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0));
}

/**
 * Confirms one teacher and moves the enrollment to `matched`.
 *
 * Transactional, and it re-reads the job inside the transaction: two admins
 * looking at the same broadcast must not both confirm a different teacher.
 */
export async function confirmTeacherMatch(jobId: string, teacherId: string): Promise<void> {
  const admin = await currentAdmin();
  const jobRef = doc(db, "job_board", jobId);
  const responseRef = doc(db, "job_board", jobId, "responses", teacherId);

  await runTransaction(db, async (tx) => {
    const jobSnap = await tx.get(jobRef);
    if (!jobSnap.exists()) throw new Error("Job not found.");
    const jobData = jobSnap.data() as Record<string, unknown>;
    const status = text(jobData.status);

    if (status === "accepted") throw new Error("Job already accepted.");
    if (status === "closed") {
      if (text(jobData.closedReason) !== CLOSED_REASON_TEACHER_FULLY_AVAILABLE) {
        throw new Error("Job is closed.");
      }
    } else if (status !== "open") {
      throw new Error("Job cannot be matched in its current state.");
    }

    const enrollmentId = text(jobData.enrollmentId);
    if (!enrollmentId) throw new Error("Missing enrollment id.");

    const responseSnap = await tx.get(responseRef);
    if (!responseSnap.exists()) throw new Error("Teacher has not submitted a response yet.");
    const response = responseSnap.data() as Record<string, unknown>;
    if (response.adminRejected === true) {
      throw new Error("This response was declined. The teacher must submit a new availability response.");
    }

    const teacherName = text(response.teacherName) || "Teacher";
    const availabilityStatus = text(response.availabilityStatus) || "available";
    const comment = text(response.comment);
    const alternatives = list(response.rankedSlots).length
      ? list(response.rankedSlots)
      : list(response.availableAlternatives);

    tx.update(jobRef, {
      status: "accepted",
      acceptedByTeacherId: teacherId,
      acceptedAt: serverTimestamp(),
      confirmedByAdminId: admin.uid,
      confirmedByAdminAt: serverTimestamp(),
      teacherResponseStatus: availabilityStatus,
      ...(comment ? { teacherResponseComment: comment } : {}),
      ...(alternatives.length ? { teacherResponseAlternatives: alternatives } : {}),
      closedReason: deleteField(),
      closedAt: deleteField(),
    });

    tx.update(doc(db, "enrollments", enrollmentId), {
      "metadata.status": "matched",
      "metadata.jobId": jobId,
      "metadata.matchedTeacherId": teacherId,
      "metadata.matchedTeacherName": teacherName,
      "metadata.matchedAt": serverTimestamp(),
      "metadata.matchedByAdminId": admin.uid,
      "metadata.latestTeacherResponseSummary": {
        teacherId,
        teacherName,
        availabilityStatus,
        ...(comment ? { comment } : {}),
        ...(alternatives.length ? { availableAlternatives: alternatives } : {}),
        updatedAt: Timestamp.now(),
      },
      "metadata.lastUpdated": serverTimestamp(),
      "metadata.actionHistory": arrayUnion({
        action: "admin_confirmed_match",
        status: "matched",
        jobId,
        teacherId,
        teacherName,
        adminId: admin.uid,
        adminEmail: admin.email,
        timestamp: Timestamp.now(),
      }),
    });
  });
}

/**
 * Declines one teacher's availability.
 *
 * If the posting had auto-closed because this same teacher said they were
 * fully available, it reopens so other teachers can answer.
 */
export async function declineTeacherResponse(jobId: string, teacherId: string, note: string): Promise<void> {
  const admin = await currentAdmin();
  const trimmed = note.trim();
  const jobRef = doc(db, "job_board", jobId);
  const responseRef = doc(db, "job_board", jobId, "responses", teacherId);

  await runTransaction(db, async (tx) => {
    const jobSnap = await tx.get(jobRef);
    tx.update(responseRef, {
      adminRejected: true,
      adminRejectedAt: serverTimestamp(),
      rejectedByAdminId: admin.uid,
      ...(trimmed ? { adminRejectedNote: trimmed } : {}),
    });
    if (!jobSnap.exists()) return;
    const jobData = jobSnap.data() as Record<string, unknown>;
    if (
      text(jobData.status) === "closed" &&
      text(jobData.closedReason) === CLOSED_REASON_TEACHER_FULLY_AVAILABLE &&
      text(jobData.lastResponseByTeacherId) === teacherId
    ) {
      tx.update(jobRef, { status: "open", closedReason: deleteField(), closedAt: deleteField() });
    }
  });
}
