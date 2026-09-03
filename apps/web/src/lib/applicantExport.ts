/**
 * Column layouts for the Excel export.
 *
 * Kept apart from the screen so the columns can be read and tested without a
 * Firestore connection or a rendered page.
 */

import { blockById, blockRangeLabel } from "./enrollmentDomain.ts";
import { daysWaiting, setupFor, type SetupState } from "./applicantTriage.ts";
import { formatStartDate, type StudentDiscount } from "./studentDiscount.ts";
import type { CellValue, Sheet } from "./xlsx.ts";

export type ExportApplicant = {
  id: string;
  status: string;
  submittedAt: Date | null;
  studentName: string;
  age: string;
  gender: string;
  isAdult: boolean;
  gradeLevel: string;
  programTitle: string;
  classType: string;
  sessionDuration: string;
  hoursPerWeek: number | null;
  sessionsPerWeek: number | null;
  days: string[];
  block: string;
  timeZone: string;
  preferredLanguage: string;
  schedulingNotes: string;
  parentName: string;
  email: string;
  phone: string;
  whatsApp: string;
  city: string;
  country: string;
  teacherName: string;
  teacherTimeZone: string;
  matchedAt: Date | null;
  studentUserId: string;
  parentLinked: boolean;
  discount: StudentDiscount | null;
};

export type ExportDraft = {
  id: string;
  updatedAt: Date | null;
  step: number;
  stepTitle: string;
  role: string;
  studentNames: string[];
  subjects: string[];
  parentName: string;
  email: string;
  phone: string;
  whatsApp: string;
  city: string;
  timeZone: string;
};

export type ExportTeacher = {
  id: string;
  fullName: string;
  email: string;
  phoneNumber: string;
  currentLocation: string;
  gender: string;
  nationality: string;
  currentStatus: string;
  teachingPrograms: string[];
  englishSubjects: string[];
  languages: string[];
  timeDiscipline: string;
  scheduleBalance: string;
  tajwidLevel: string;
  quranMemorization: string;
  arabicProficiency: string;
  interestReason: string;
  electricityAccess: string;
  teachingComfort: string;
  availabilityStart: string;
  teachingDevice: string;
  internetAccess: string;
  status: string;
  submittedAt: Date | null;
};

/** ISO-ish and sortable, which a spreadsheet locale cannot reinterpret. */
export const exportDate = (date: Date | null): string =>
  date ? date.toISOString().slice(0, 16).replace("T", " ") : "";

const yesNo = (value: boolean): string => (value ? "Yes" : "No");

const windowLabel = (block: string): string => {
  const found = blockById(block);
  return found ? `${found.label} (${blockRangeLabel(found)})` : "";
};

export const STUDENT_COLUMNS = [
  "Application ID", "Status", "Submitted", "Student Name", "Age", "Gender", "Adult Student",
  "Grade / Level", "Program", "Class Type", "Session Duration", "Hours / Week", "Sessions / Week",
  "Preferred Days", "Requested Window", "Time Zone", "Preferred Language", "Scheduling Notes",
  "Parent / Guardian", "Email", "Phone", "WhatsApp", "City", "Country", "Matched Teacher",
  "Teacher Time Zone", "Account Created", "Schedule Finalized", "Parent Account", "Days Since Match",
  "Enrollment Start", "Discount Type", "Discount Value", "Discount Duration", "Discount Starts",
  "Discount Reason", "Discount Note",
] as const;

export const studentRow = (
  applicant: ExportApplicant,
  hasSchedule: boolean,
  now?: Date,
): CellValue[] => {
  const setup: SetupState = setupFor(applicant, hasSchedule);
  const waited = daysWaiting(applicant.matchedAt, now);
  const discount = applicant.discount;
  return [
    applicant.id,
    applicant.status,
    exportDate(applicant.submittedAt),
    applicant.studentName,
    applicant.age,
    applicant.gender,
    yesNo(applicant.isAdult),
    applicant.gradeLevel,
    applicant.programTitle,
    applicant.classType,
    applicant.sessionDuration,
    applicant.hoursPerWeek,
    applicant.sessionsPerWeek,
    applicant.days.join(", "),
    windowLabel(applicant.block),
    applicant.timeZone,
    applicant.preferredLanguage,
    applicant.schedulingNotes,
    applicant.parentName,
    applicant.email,
    applicant.phone,
    applicant.whatsApp,
    applicant.city,
    applicant.country,
    applicant.teacherName,
    applicant.teacherTimeZone,
    yesNo(setup.hasAccount),
    yesNo(setup.hasSchedule),
    yesNo(setup.hasParent),
    waited,
    // Nothing records an enrollment start date; the discount is the only place
    // one is ever stated, so it is reported rather than invented.
    discount ? formatStartDate(discount.startDate) : "",
    discount ? (discount.mode === "percent" ? "Percentage" : "Fixed amount") : "",
    discount ? discount.value : null,
    discount ? (discount.duration === "ongoing" ? "Ongoing" : `${discount.months} months`) : "",
    discount ? formatStartDate(discount.startDate) : "",
    discount?.reason ?? "",
    discount?.note ?? "",
  ];
};

export const DRAFT_COLUMNS = [
  "Draft ID", "Last Active", "Stopped At", "Step", "Role", "Student Name(s)", "Program(s)",
  "Parent / Guardian", "Email", "Phone", "WhatsApp", "City", "Time Zone",
] as const;

export const draftRow = (draft: ExportDraft): CellValue[] => [
  draft.id,
  exportDate(draft.updatedAt),
  draft.stepTitle,
  draft.step,
  draft.role,
  draft.studentNames.join(", "),
  draft.subjects.join(", "),
  draft.parentName,
  draft.email,
  draft.phone,
  draft.whatsApp,
  draft.city,
  draft.timeZone,
];

export const TEACHER_COLUMNS = [
  "Application ID", "Name", "Email", "Phone", "Location", "Gender", "Nationality", "Current Status",
  "Teaching Programs", "English Subjects", "Languages", "Time Discipline", "Schedule Balance",
  "Tajwid Level", "Quran Memorization", "Arabic Proficiency", "Interest Reason", "Electricity Access",
  "Teaching Comfort", "Availability Start", "Teaching Device", "Internet Access", "Status", "Submitted",
] as const;

export const teacherRow = (teacher: ExportTeacher): CellValue[] => [
  teacher.id,
  teacher.fullName,
  teacher.email,
  teacher.phoneNumber,
  teacher.currentLocation,
  teacher.gender,
  teacher.nationality,
  teacher.currentStatus,
  teacher.teachingPrograms.join(", "),
  teacher.englishSubjects.join(", "),
  teacher.languages.join(", "),
  teacher.timeDiscipline,
  teacher.scheduleBalance,
  teacher.tajwidLevel,
  teacher.quranMemorization,
  teacher.arabicProficiency,
  teacher.interestReason,
  teacher.electricityAccess,
  teacher.teachingComfort,
  teacher.availabilityStart,
  teacher.teachingDevice,
  teacher.internetAccess,
  teacher.status,
  exportDate(teacher.submittedAt),
];

/* ---------------------------------------------------------------- sheets -- */

export const studentSheet = (
  applicants: ExportApplicant[],
  scheduled: Set<string>,
  now?: Date,
): Sheet => ({
  name: "Student Applications",
  headers: [...STUDENT_COLUMNS],
  rows: applicants.map((a) => studentRow(a, scheduled.has(a.studentUserId), now)),
});

export const draftSheet = (drafts: ExportDraft[]): Sheet => ({
  name: "Unfinished Drafts",
  headers: [...DRAFT_COLUMNS],
  rows: drafts.map(draftRow),
});

export const teacherSheet = (teachers: ExportTeacher[]): Sheet => ({
  name: "Teacher Applications",
  headers: [...TEACHER_COLUMNS],
  rows: teachers.map(teacherRow),
});

export const exportFileName = (label: string): string =>
  `${label}_${new Date().toISOString().slice(0, 10).replaceAll("-", "")}.xlsx`;
