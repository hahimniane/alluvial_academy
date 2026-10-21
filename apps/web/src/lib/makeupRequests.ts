/**
 * Makeup requests for missed classes (`reschedule_requests`), shared by the
 * teacher console and the admin shifts page. Mirrors the Flutter
 * RescheduleRequestDialog / RescheduleRequestsScreen: a teacher files a
 * pending request for one of their missed classes, and an admin approves or
 * declines it through the reviewRescheduleRequest callable, which builds the
 * makeup class from the original shift.
 *
 * Pure helpers only; the Firestore and callable calls live with the screens.
 */

/** 2026-11-01 00:00 America/New_York (still EDT). Mirrors functions/utils/auditPolicyConstants.js. */
export const STRICT_CLOCK_POLICY_CUTOFF_MS = Date.parse("2026-11-01T00:00:00-04:00");

/** From the cutoff a missed class is made up through a request rather than a form. */
export function isShiftAfterStrictPolicy(shiftStart: Date | null | undefined): boolean {
  if (!shiftStart || Number.isNaN(shiftStart.getTime())) return false;
  return shiftStart.getTime() >= STRICT_CLOCK_POLICY_CUTOFF_MS;
}

/** Same keys and order as the Flutter dialog. Labels are English source text for tr(). */
export const MAKEUP_REASONS: ReadonlyArray<{ value: string; label: string }> = [
  { value: "power_outage", label: "Power Outage" },
  { value: "internet", label: "Internet / Connection Issue" },
  { value: "illness", label: "Illness / Medical" },
  { value: "student_absent", label: "Student Absent / Unavailable" },
  { value: "personal", label: "Personal / Family Emergency" },
  { value: "other", label: "Other" },
];

export function makeupReasonLabel(value: string): string {
  return MAKEUP_REASONS.find((reason) => reason.value === value)?.label ?? "Other";
}

export type MakeupRequestStatus = "pending" | "approved" | "declined";

export type MakeupRequest = {
  id: string;
  teacherId: string;
  teacherName: string;
  originalShiftId: string;
  subject: string;
  studentNames: string[];
  proposedStart: Date | null;
  proposedEnd: Date | null;
  reasonCategory: string;
  notes: string;
  status: MakeupRequestStatus;
  declineReason: string;
  approvedStart: Date | null;
  createdShiftId: string;
  createdAt: Date | null;
};

/** The missed class a request is filed for, as the teacher console knows it. */
export type MakeupSourceShift = {
  id: string;
  teacherId: string;
  teacherName: string;
  subject: string;
  subjectId: string;
  subjectDisplayName: string;
  studentIds: string[];
  studentNames: string[];
  teacherTimezone: string;
  start: Date | null;
  end: Date | null;
};

const DEFAULT_MINUTES = 60;

/** The makeup keeps the missed class's length (60 minutes if it had none). */
export function makeupDurationMinutes(shift: Pick<MakeupSourceShift, "start" | "end">): number {
  if (!shift.start || !shift.end) return DEFAULT_MINUTES;
  const minutes = Math.round((shift.end.getTime() - shift.start.getTime()) / 60_000);
  return minutes > 0 ? minutes : DEFAULT_MINUTES;
}

/**
 * The request document, minus the timestamp wrapper and server timestamps.
 * Its keys are exactly the ones firestore.rules lets a teacher write.
 */
export function buildMakeupRequestFields(input: {
  shift: MakeupSourceShift;
  proposedStart: Date;
  reasonCategory: string;
  notes: string;
}) {
  const { shift } = input;
  const proposedEnd = new Date(input.proposedStart.getTime() + makeupDurationMinutes(shift) * 60_000);
  const reason = MAKEUP_REASONS.some((r) => r.value === input.reasonCategory) ? input.reasonCategory : "other";
  const fields: Record<string, unknown> = {
    teacher_id: shift.teacherId,
    teacher_name: shift.teacherName,
    original_shift_id: shift.id,
    subject: shift.subjectDisplayName || shift.subject,
    student_ids: shift.studentIds,
    student_names: shift.studentNames,
    proposed_start: input.proposedStart,
    proposed_end: proposedEnd,
    proposed_timezone: shift.teacherTimezone || "UTC",
    reason_category: reason,
    notes: input.notes.trim(),
    status: "pending",
  };
  if (shift.subjectId) fields.subject_id = shift.subjectId;
  if (shift.subjectDisplayName) fields.subject_display_name = shift.subjectDisplayName;
  return fields;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function date(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  const withToDate = value as { toDate?: () => Date };
  if (typeof withToDate.toDate === "function") return withToDate.toDate();
  const withSeconds = value as { seconds?: number };
  if (typeof withSeconds.seconds === "number") return new Date(withSeconds.seconds * 1000);
  return null;
}

export function parseMakeupRequest(id: string, data: Record<string, unknown>): MakeupRequest {
  const status = text(data.status);
  return {
    id,
    teacherId: text(data.teacher_id),
    teacherName: text(data.teacher_name),
    originalShiftId: text(data.original_shift_id),
    subject: text(data.subject_display_name) || text(data.subject),
    studentNames: strings(data.student_names),
    proposedStart: date(data.proposed_start),
    proposedEnd: date(data.proposed_end),
    reasonCategory: text(data.reason_category) || "other",
    notes: text(data.notes),
    status: status === "approved" || status === "declined" ? status : "pending",
    declineReason: text(data.decline_reason),
    approvedStart: date(data.approved_start),
    createdShiftId: text(data.created_shift_id),
    createdAt: date(data.created_at),
  };
}

/** The newest request per missed class; a request still waiting on its server timestamp counts as newest. */
export function latestRequestByShift(requests: MakeupRequest[]): Map<string, MakeupRequest> {
  const rank = (request: MakeupRequest) => request.createdAt?.getTime() ?? Number.MAX_SAFE_INTEGER;
  const byShift = new Map<string, MakeupRequest>();
  for (const request of requests) {
    if (!request.originalShiftId) continue;
    const current = byShift.get(request.originalShiftId);
    if (!current || rank(request) > rank(current)) byShift.set(request.originalShiftId, request);
  }
  return byShift;
}

/** Whether the teacher may file a request for this class now. */
export function canRequestMakeup(status: string, start: Date | null, latest: MakeupRequest | undefined): boolean {
  if (status.toLowerCase() !== "missed") return false;
  if (!isShiftAfterStrictPolicy(start)) return false;
  return !latest || latest.status === "declined";
}
