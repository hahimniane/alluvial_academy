import { addDoc, collection, serverTimestamp } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, firebaseApp, functions } from "@/lib/firebase";
import type { PublicSitePlanPricing } from "@/lib/publicSiteCms";

export type ContactInput = {
  name: string;
  email: string;
  message: string;
};

export type TeacherApplicationInput = {
  firstName: string;
  lastName: string;
  email: string;
  currentLocation: string;
  gender: string;
  phoneNumber: string;
  countryCode: string;
  nationality: string;
  currentStatus: string;
  currentStatusOther?: string;
  teachingPrograms: string[];
  teachingProgramOther?: string;
  englishSubjects?: string;
  languages: string[];
  timeDiscipline: string;
  scheduleBalance: string;
  tajwidLevel?: string;
  quranMemorization?: string;
  arabicProficiency?: string;
  interestReason: string;
  electricityAccess: string;
  teachingComfort: string;
  studentInteractionGuarantee: string;
  availabilityStart: string;
  availabilityStartOther?: string;
  teachingDevice: string;
  internetAccess: string;
  scenarioNonParticipatingStudent?: string;
  feedbackOnForm?: string;
};

export type LeadershipApplicationInput = {
  firstName: string;
  lastName: string;
  email: string;
  currentLocation: string;
  gender: string;
  phoneNumber: string;
  countryCode: string;
  nationality: string;
  currentStatus: string;
  currentStatusOther?: string;
  interestReason: string;
  relevantExperience: string;
  availabilityStart: string;
  availabilityStartOther?: string;
};

export type EnrollmentStudentInput = {
  name: string;
  age: string;
  gender: string;
  subject: string;
  specificLanguage?: string;
  level: string;
  classType: string;
  sessionDuration: string;
  hoursPerWeek: number;
  timeOfDayPreference: string;
  preferredDays: string[];
  preferredTimeSlots: string[];
  trackId: string;
};

export type EnrollmentInput = {
  role: string;
  parentName?: string;
  guardianId?: string;
  students: EnrollmentStudentInput[];
  email: string;
  phoneNumber: string;
  countryCode: string;
  countryName: string;
  city: string;
  whatsAppNumber?: string;
  preferredLanguage: string;
  timeZone: string;
  schedulingNotes?: string;
  pricingPlanId?: string;
  pricingPlanLabel?: string;
  trackId?: string;
  hoursPerWeek?: number;
  pricingPlans?: Record<string, PublicSitePlanPricing>;
};

export async function submitContactMessage(input: ContactInput) {
  const projectId = firebaseApp.options.projectId;
  const apiKey = firebaseApp.options.apiKey;
  if (!projectId || !apiKey) throw new Error("Firebase configuration is missing.");

  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/contact_messages?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        fields: {
          name: { stringValue: input.name.trim() },
          email: { stringValue: input.email.trim() },
          message: { stringValue: input.message.trim() },
          submittedAt: { timestampValue: new Date().toISOString() },
          status: { stringValue: "new" },
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error("Could not submit contact message.");
  }
}

export async function submitTeacherApplication(input: TeacherApplicationInput) {
  const englishSubjects = (input.englishSubjects ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  const payload: Record<string, unknown> = {
    first_name: input.firstName.trim(),
    last_name: input.lastName.trim(),
    email: input.email.trim(),
    current_location: input.currentLocation.trim(),
    gender: input.gender,
    phone_number: input.phoneNumber.trim(),
    country_code: input.countryCode.trim(),
    nationality: input.nationality.trim(),
    current_status: input.currentStatus,
    ...(input.currentStatusOther?.trim() ? { current_status_other: input.currentStatusOther.trim() } : {}),
    teaching_programs: input.teachingPrograms,
    ...(input.teachingProgramOther?.trim() ? { teaching_program_other: input.teachingProgramOther.trim() } : {}),
    ...(englishSubjects.length > 0 ? { english_subjects: englishSubjects } : {}),
    languages: input.languages,
    time_discipline: input.timeDiscipline,
    schedule_balance: input.scheduleBalance,
    ...(input.tajwidLevel ? { tajwid_level: input.tajwidLevel } : {}),
    ...(input.quranMemorization ? { quran_memorization: input.quranMemorization } : {}),
    ...(input.arabicProficiency ? { arabic_proficiency: input.arabicProficiency } : {}),
    interest_reason: input.interestReason.trim(),
    electricity_access: input.electricityAccess,
    teaching_comfort: input.teachingComfort,
    student_interaction_guarantee: input.studentInteractionGuarantee,
    availability_start: input.availabilityStart,
    ...(input.availabilityStartOther?.trim() ? { availability_start_other: input.availabilityStartOther.trim() } : {}),
    teaching_device: input.teachingDevice,
    internet_access: input.internetAccess,
    ...(input.scenarioNonParticipatingStudent?.trim()
      ? { scenario_non_participating_student: input.scenarioNonParticipatingStudent.trim() }
      : {}),
    ...(input.feedbackOnForm?.trim() ? { feedback_on_form: input.feedbackOnForm.trim() } : {}),
    country_of_origin: input.currentLocation.trim(),
    country_of_residence: input.currentLocation.trim(),
    submitted_at: serverTimestamp(),
    status: "pending",
  };

  await addDoc(collection(db, "teacher_applications"), payload);
}

export async function submitLeadershipApplication(input: LeadershipApplicationInput) {
  const payload = {
    first_name: input.firstName.trim(),
    last_name: input.lastName.trim(),
    firstName: input.firstName.trim(),
    lastName: input.lastName.trim(),
    email: input.email.trim(),
    current_location: input.currentLocation.trim(),
    currentLocation: input.currentLocation.trim(),
    gender: input.gender,
    phone_number: input.phoneNumber.trim(),
    phoneNumber: input.phoneNumber.trim(),
    country_code: input.countryCode.trim(),
    countryCode: input.countryCode.trim(),
    nationality: input.nationality.trim(),
    current_status: input.currentStatus,
    currentStatus: input.currentStatus,
    ...(input.currentStatusOther?.trim()
      ? {
          current_status_other: input.currentStatusOther.trim(),
          currentStatusOther: input.currentStatusOther.trim(),
        }
      : {}),
    interest_reason: input.interestReason.trim(),
    interestReason: input.interestReason.trim(),
    ...(input.relevantExperience.trim()
      ? {
          relevant_experience: input.relevantExperience.trim(),
          relevantExperience: input.relevantExperience.trim(),
        }
      : {}),
    availability_start: input.availabilityStart,
    availabilityStart: input.availabilityStart,
    ...(input.availabilityStartOther?.trim()
      ? {
          availability_start_other: input.availabilityStartOther.trim(),
          availabilityStartOther: input.availabilityStartOther.trim(),
        }
      : {}),
    submitted_at: serverTimestamp(),
    submittedAt: serverTimestamp(),
    status: "pending",
  };

  await addDoc(collection(db, "leadership_applications"), payload);
}

export async function checkParentIdentity(identifier: string) {
  const callable = httpsCallable(functions, "findUserByEmailOrCode");
  const result = await callable({ identifier: identifier.trim() });
  return result.data as {
    found?: boolean;
    userId?: string;
    firstName?: string;
    lastName?: string;
    email?: string;
    phone?: string;
    error?: string;
    errorMessage?: string;
  };
}

export async function submitEnrollment(input: EnrollmentInput) {
  if (input.students.length > 1) {
    const parentLinkId = crypto.randomUUID();
    await Promise.all(input.students.map((student, index) =>
      addEnrollmentDoc(input, student, {
        parentLinkId,
        studentIndex: index,
        totalStudents: input.students.length,
      }),
    ));
    return;
  }

  await addEnrollmentDoc(input, input.students[0]);
}

async function addEnrollmentDoc(
  input: EnrollmentInput,
  student: EnrollmentStudentInput,
  multi?: { parentLinkId: string; studentIndex: number; totalStudents: number },
) {
  const splitName = splitFullName(student.name);
  const isAdult = Number.parseInt(student.age, 10) >= 18;
  const now = serverTimestamp();
  const pricingSnapshot = buildPricingSnapshotV2(student.trackId, student.hoursPerWeek, input.pricingPlans);
  const pricingMap = extractPricingMap(pricingSnapshot);

  await addDoc(collection(db, "enrollments"), {
    subject: student.subject,
    programTitle: programTitleForSubject(student.subject),
    specificLanguage: student.specificLanguage || null,
    gradeLevel: student.level,
    contact: {
      email: input.email.trim(),
      phone: input.phoneNumber.trim(),
      country: { code: input.countryCode.trim(), name: input.countryName.trim() },
      ...(input.parentName?.trim() ? { parentName: input.parentName.trim() } : {}),
      city: input.city.trim(),
      ...(input.whatsAppNumber?.trim() ? { whatsApp: input.whatsAppNumber.trim() } : {}),
      ...(input.guardianId ? { guardianId: input.guardianId } : {}),
    },
    preferences: {
      days: student.preferredDays,
      timeSlots: student.preferredTimeSlots,
      timeZone: input.timeZone,
      preferredLanguage: input.preferredLanguage,
      timeOfDayPreference: student.timeOfDayPreference,
      ...(input.schedulingNotes?.trim() ? { schedulingNotes: input.schedulingNotes.trim() } : {}),
    },
    student: {
      name: student.name.trim(),
      ...(splitName.firstName ? { firstName: splitName.firstName } : {}),
      ...(splitName.lastName ? { lastName: splitName.lastName } : {}),
      age: student.age.trim(),
      ...(student.gender ? { gender: student.gender } : {}),
    },
    program: {
      role: input.role,
      classType: student.classType,
      sessionDuration: student.sessionDuration,
      hoursPerWeek: student.hoursPerWeek,
    },
    ...(pricingMap ? { pricing: pricingMap } : {}),
    metadata: {
      status: "pending",
      submittedAt: now,
      requiresApproval: true,
      source: "web_landing_page",
      isAdult,
      ...(input.pricingPlanId ? { pricingPlanId: input.pricingPlanId } : {}),
      ...(input.pricingPlanLabel ? { pricingPlanLabel: input.pricingPlanLabel } : {}),
      trackId: student.trackId,
      ...(pricingSnapshot ? { pricingSnapshot } : {}),
      ...(multi
        ? {
            parentLinkId: multi.parentLinkId,
            studentIndex: multi.studentIndex,
            totalStudents: multi.totalStudents,
          }
        : {}),
    },
    studentName: student.name.trim(),
    studentAge: student.age.trim(),
  });
}

function buildPricingSnapshotV2(
  trackId: string | undefined,
  hoursPerWeek: number | undefined,
  pricingPlans?: Record<string, PublicSitePlanPricing>,
) {
  if (!trackId || !hoursPerWeek || hoursPerWeek <= 0) return null;
  const plan = pricingPlans?.[trackId];
  const threshold =
    trackId === "islamic"
      ? numberValue(plan?.islamicDiscountThreshold, 4)
      : trackId === "tutoring"
        ? numberValue(plan?.tutoringDiscountThreshold, 4)
        : 4;
  const discountApplied = trackId !== "group" && hoursPerWeek > threshold;
  let hourlyRateUsd: number;
  let baseHourlyRateUsd: number;
  let monthlyEstimateUsd: number;

  if (trackId === "islamic") {
    baseHourlyRateUsd = numberValue(plan?.islamicBaseUsd ?? plan?.islamicHrUnder5Usd, 8.5);
    const discount = numberValue(plan?.islamicDiscountUsd ?? plan?.islamicHr5PlusUsd, 6.99);
    hourlyRateUsd = discountApplied ? discount : baseHourlyRateUsd;
    monthlyEstimateUsd = Math.round(hoursPerWeek * hourlyRateUsd * 4);
  } else if (trackId === "tutoring") {
    baseHourlyRateUsd = numberValue(plan?.tutoringBaseUsd ?? plan?.tutoringHrUnder4Usd, 11.99);
    const discount = numberValue(plan?.tutoringDiscountUsd ?? plan?.tutoringHr4PlusUsd, 9.99);
    hourlyRateUsd = discountApplied ? discount : baseHourlyRateUsd;
    monthlyEstimateUsd = Math.round(hoursPerWeek * hourlyRateUsd * 4);
  } else if (trackId === "group") {
    hourlyRateUsd = numberValue(plan?.groupHourlyUsd ?? plan?.hourlyUsd, 2.5);
    baseHourlyRateUsd = hourlyRateUsd;
    monthlyEstimateUsd = roundMoney(hoursPerWeek * hourlyRateUsd * 4.33);
  } else {
    return null;
  }

  return {
    version: 2,
    trackId,
    hoursPerWeek,
    hourlyRateUsd: roundMoney(hourlyRateUsd),
    baseHourlyRateUsd: roundMoney(baseHourlyRateUsd),
    discountApplied,
    monthlyEstimateUsd,
  };
}

function numberValue(value: unknown, fallback: number) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function extractPricingMap(snapshot: ReturnType<typeof buildPricingSnapshotV2>) {
  if (!snapshot) return null;
  return {
    trackId: snapshot.trackId,
    hoursPerWeek: snapshot.hoursPerWeek,
    hourlyRate: snapshot.hourlyRateUsd,
    discountApplied: snapshot.discountApplied,
    monthlyEstimate: snapshot.monthlyEstimateUsd,
  };
}

function roundMoney(value: number) {
  return Number(value.toFixed(2));
}

function splitFullName(raw: string) {
  const parts = raw.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { firstName: "", lastName: "" };
  if (parts.length === 1) return { firstName: parts[0], lastName: "" };
  return { firstName: parts[0], lastName: parts.slice(1).join(" ") };
}

function programTitleForSubject(subject: string) {
  if (subject.includes("Islamic")) return "Islamic Studies";
  if (subject.includes("AfroLanguages")) return "AfroLanguages & AdLam";
  if (subject.includes("After School")) return "After School Tutoring";
  if (subject.includes("Adult Literacy")) return "Adult Literacy";
  return subject;
}
