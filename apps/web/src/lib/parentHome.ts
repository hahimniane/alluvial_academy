/**
 * Pure rules behind the parent home page and the child page: how classes,
 * invoices, payments, tasks and attendance reports are read, and every figure
 * the Flutter screens compute from them. No Firebase imports, so each rule is
 * unit-tested against the Dart it mirrors:
 *
 *   lib/features/parent/screens/parent_dashboard_screen.dart   (family blocks)
 *   lib/features/parent/services/parent_service.dart           (money summary)
 *   lib/features/parent/widgets/*                               (cards, tabs)
 *
 * Dates and money are always formatted in US English, as Flutter does today
 * (no Intl.defaultLocale is set there, whatever the app language).
 */

type Data = Record<string, unknown>;

const DAY_MS = 86_400_000;

// ─── Value readers ─────────────────────────────────────────────────────────

/** A Firestore Timestamp (duck-typed, so this file needs no Firebase import). */
function timestampDate(value: unknown): Date | null {
  if (value && typeof value === "object" && typeof (value as { toDate?: unknown }).toDate === "function") {
    const date = (value as { toDate: () => Date }).toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }
  return null;
}

/** Invoice/Payment `_parseDateTime`: Timestamp, Date or an ISO string. */
function anyDate(value: unknown): Date | null {
  const ts = timestampDate(value);
  if (ts) return ts;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function toNumber(value: unknown): number | null {
  if (value == null) return null;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  const parsed = Number.parseFloat(String(value));
  return Number.isFinite(parsed) ? parsed : null;
}

function str(value: unknown): string {
  return value == null ? "" : String(value);
}

function strList(value: unknown): string[] {
  return Array.isArray(value) ? value.map((entry) => String(entry)) : [];
}

// ─── Classes (TeachingShift) ───────────────────────────────────────────────

export type ShiftStatus = "scheduled" | "active" | "completed" | "partiallyCompleted" | "fullyCompleted" | "missed" | "cancelled";
const SHIFT_STATUSES: readonly ShiftStatus[] = ["scheduled", "active", "completed", "partiallyCompleted", "fullyCompleted", "missed", "cancelled"];

const LEGACY_SUBJECTS = ["quranStudies", "hadithStudies", "fiqh", "arabicLanguage", "islamicHistory", "aqeedah", "tafseer", "seerah", "other"] as const;
type LegacySubject = (typeof LEGACY_SUBJECTS)[number];

const LEGACY_SUBJECT_LABELS: Record<LegacySubject, string> = {
  quranStudies: "Quran Studies",
  hadithStudies: "Hadith Studies",
  fiqh: "Islamic Jurisprudence (Fiqh)",
  arabicLanguage: "Arabic Language",
  islamicHistory: "Islamic History",
  aqeedah: "Islamic Creed (Aqeedah)",
  tafseer: "Quran Interpretation (Tafseer)",
  seerah: "Prophet's Biography (Seerah)",
  other: "Other Subject",
};

export type ParentShift = {
  id: string;
  status: ShiftStatus;
  category: string;
  shiftStart: Date;
  shiftEnd: Date;
  studentIds: string[];
  studentNames: string[];
  teacherName: string;
  /** Legacy enum name (`IslamicSubject.name`), defaulted as Flutter does. */
  subject: LegacySubject;
  subjectDisplayName: string | null;
  clockInTime: Date | null;
  clockOutTime: Date | null;
  notes: string | null;
  teacherId: string;
  subjectId: string | null;
  livekitRoomName: string | null;
  zoomMeetingId: string | null;
  hubMeetingId: string | null;
  breakoutRoomName: string | null;
  breakoutRoomKey: string | null;
  /** TeachingShift.videoProvider: non-teaching or student-less → realtimekit, else the stored value, default zoom. */
  videoProvider: "zoom" | "realtimekit" | "livekit";
};

function optionalString(value: unknown): string | null {
  return value == null ? null : String(value);
}

/**
 * TeachingShift.fromFirestore. Flutter throws on a class without Timestamp
 * `shift_start`, `shift_end` or `created_at`; here that class is skipped
 * (returns null), which is what the live class stream already does.
 */
export function parseShift(id: string, data: Data): ParentShift | null {
  const shiftStart = timestampDate(data.shift_start);
  const shiftEnd = timestampDate(data.shift_end);
  const createdAt = timestampDate(data.created_at);
  if (!shiftStart || !shiftEnd || !createdAt) return null;
  const rawCategory = str(data.shift_category ?? data.shiftCategory ?? "teaching");
  const category = ["teaching", "leadership", "meeting", "training"].includes(rawCategory) ? rawCategory : "teaching";
  const rawSubject = str(data.subject);
  const subject = (LEGACY_SUBJECTS as readonly string[]).includes(rawSubject)
    ? (rawSubject as LegacySubject)
    : category === "teaching"
      ? "quranStudies"
      : "other";
  const rawStatus = str(data.status);
  const display = data.subject_display_name;
  return {
    id,
    status: (SHIFT_STATUSES as readonly string[]).includes(rawStatus) ? (rawStatus as ShiftStatus) : "scheduled",
    category,
    shiftStart,
    shiftEnd,
    studentIds: strList(data.student_ids),
    studentNames: strList(data.student_names),
    teacherName: str(data.teacher_name),
    subject,
    subjectDisplayName: display == null ? null : String(display),
    clockInTime: timestampDate(data.clock_in_time),
    clockOutTime: timestampDate(data.clock_out_time),
    notes: data.notes == null ? null : String(data.notes),
    teacherId: str(data.teacher_id ?? ""),
    subjectId: optionalString(data.subject_id),
    livekitRoomName: optionalString(data.livekit_room_name),
    zoomMeetingId: optionalString(data.zoom_meeting_id ?? data.zoomMeetingId),
    hubMeetingId: optionalString(data.hubMeetingId ?? data.hub_meeting_id ?? data.hubMeetingID),
    breakoutRoomName: optionalString(data.breakoutRoomName ?? data.breakout_room_name),
    breakoutRoomKey: optionalString(data.breakoutRoomKey ?? data.breakout_room_key),
    videoProvider: videoProviderOf(category, strList(data.student_ids).length > 0, data.video_provider ?? data.videoProvider),
  };
}

function videoProviderOf(category: string, hasStudents: boolean, raw: unknown): ParentShift["videoProvider"] {
  if (category !== "teaching" || !hasStudents) return "realtimekit";
  const value = raw == null ? "" : String(raw).trim().toLowerCase();
  if (value === "realtimekit" || value === "zoom" || value === "livekit") return value;
  return "zoom";
}

export const isTeaching = (shift: ParentShift) => shift.category === "teaching";

export function isCompletedStatus(status: ShiftStatus) {
  return status === "completed" || status === "fullyCompleted" || status === "partiallyCompleted";
}

/** Subject key used by the progress figures: display name, else the enum name. */
export function progressSubject(shift: ParentShift) {
  const display = (shift.subjectDisplayName ?? "").trim();
  return display || shift.subject;
}

/**
 * Subject shown on a class card, the details sheet and Recent Activity. Flutter
 * prints the raw enum ("IslamicSubject.quranStudies") when a class has no
 * display name; the readable name (`effectiveSubjectDisplayName`) is shown
 * instead (plan default: no junk text).
 */
export function subjectLabel(shift: ParentShift) {
  if (shift.subjectDisplayName && shift.subjectDisplayName.length > 0) return shift.subjectDisplayName;
  return LEGACY_SUBJECT_LABELS[shift.subject];
}

/** Local calendar-day difference (immune to the DST hour). */
function dayDiff(from: Date, to: Date) {
  const a = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate());
  const b = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate());
  return Math.round((b - a) / DAY_MS);
}

function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function addDays(date: Date, days: number) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

function hoursOf(shift: ParentShift) {
  const minutes = Math.trunc((shift.shiftEnd.getTime() - shift.shiftStart.getTime()) / 60_000);
  return minutes / 60;
}

/** ParentService.getStudentShiftsHistory filter: start < end, and strictly after `start` when given. */
export function historyWindow(shifts: ParentShift[], end: Date, start: Date | null) {
  return shifts
    .filter((shift) => shift.shiftStart.getTime() < end.getTime())
    .filter((shift) => !start || shift.shiftStart.getTime() > start.getTime())
    .sort((a, b) => b.shiftStart.getTime() - a.shiftStart.getTime());
}

// ─── Attention level (On Track / Watch / Needs Support) ────────────────────

export type AttentionLevel = "needsSupport" | "watch" | "onTrack";
const ATTENTION_ORDER: Record<AttentionLevel, number> = { needsSupport: 0, watch: 1, onTrack: 2 };

export function attentionLevel(rate: number, tracked: number): AttentionLevel {
  if (tracked === 0) return "watch";
  if (rate >= 0.8) return "onTrack";
  if (rate >= 0.6) return "watch";
  return "needsSupport";
}

export const ATTENTION_LABEL: Record<AttentionLevel, string> = { needsSupport: "Needs Support", watch: "Watch", onTrack: "On Track" };
export const ATTENTION_COLOR: Record<AttentionLevel, string> = { needsSupport: "#DC2626", watch: "#D97706", onTrack: "#15803D" };

// ─── Family Progress (A-040…A-045) ─────────────────────────────────────────

export type ChildProgress = {
  id: string;
  name: string;
  attendanceRate: number;
  completedClasses: number;
  missedClasses: number;
  cancelledClasses: number;
  totalTrackedClasses: number;
  classesLast7Days: number;
  recentClasses: number;
  previousClasses: number;
  learningHoursLast30Days: number;
  weeklyClassCounts: number[];
  subjectBreakdown: Map<string, number>;
  primarySubject: string;
  attentionLevel: AttentionLevel;
};

export function childDisplayName(name: string | null | undefined) {
  const trimmed = (name ?? "").trim();
  return trimmed || "Student";
}

/** `_buildChildProgressSnapshot`: `shifts` = the child's classes of the last 30 days (D3). */
export function childProgress(child: { id: string; name: string }, shifts: ParentShift[], now: Date): ChildProgress {
  const today = startOfDay(now);
  const weekStart = addDays(today, -6);
  const recentStart = now.getTime() - 7 * DAY_MS;
  const previousStart = now.getTime() - 14 * DAY_MS;
  const weekly = [0, 0, 0, 0, 0, 0, 0];
  let completed = 0;
  let missed = 0;
  let cancelled = 0;
  let recent = 0;
  let previous = 0;
  let hours = 0;
  const subjects = new Map<string, number>();

  for (const shift of shifts) {
    const day = startOfDay(shift.shiftStart);
    const index = dayDiff(weekStart, day);
    if (index >= 0 && index < 7 && day.getTime() <= today.getTime()) weekly[index] += 1;

    const start = shift.shiftStart.getTime();
    if (start > recentStart) recent += 1;
    else if (start > previousStart) previous += 1;

    if (isCompletedStatus(shift.status)) {
      completed += 1;
      const h = hoursOf(shift);
      hours += h > 0 ? h : 0;
      const raw = (shift.subjectDisplayName ?? shift.subject).trim();
      const subject = raw || "General";
      subjects.set(subject, (subjects.get(subject) ?? 0) + 1);
    } else if (shift.status === "missed") {
      missed += 1;
    } else if (shift.status === "cancelled") {
      cancelled += 1;
    }
  }

  const tracked = completed + missed + cancelled;
  const rate = tracked > 0 ? completed / tracked : 0;
  const ranked = [...subjects.entries()].sort((a, b) => b[1] - a[1]);
  return {
    id: child.id,
    name: childDisplayName(child.name),
    attendanceRate: rate,
    completedClasses: completed,
    missedClasses: missed,
    cancelledClasses: cancelled,
    totalTrackedClasses: tracked,
    classesLast7Days: recent,
    recentClasses: recent,
    previousClasses: previous,
    learningHoursLast30Days: hours,
    weeklyClassCounts: weekly,
    subjectBreakdown: subjects,
    primarySubject: ranked.length ? ranked[0][0] : "No completed classes",
    attentionLevel: attentionLevel(rate, tracked),
  };
}

export type FamilyProgress = {
  children: ChildProgress[];
  dayLabels: Date[];
  classesByDay: number[];
  topSubjects: Array<[string, number]>;
  averageAttendanceRate: number;
  totalLearningHours: number;
  classesThisWeek: number;
  needsSupportChildren: number;
};

/** `_buildParentProgressOverview`. */
export function familyProgress(children: ChildProgress[], now: Date): FamilyProgress {
  const weekStart = addDays(startOfDay(now), -6);
  const dayLabels = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
  const sorted = [...children].sort((a, b) => {
    const level = ATTENTION_ORDER[a.attentionLevel] - ATTENTION_ORDER[b.attentionLevel];
    return level !== 0 ? level : a.attendanceRate - b.attendanceRate;
  });
  const classesByDay = [0, 0, 0, 0, 0, 0, 0];
  const subjectTotals = new Map<string, number>();
  let attendance = 0;
  let contributors = 0;
  let hours = 0;
  let week = 0;
  for (const child of sorted) {
    child.weeklyClassCounts.slice(0, 7).forEach((count, i) => (classesByDay[i] += count));
    hours += child.learningHoursLast30Days;
    week += child.classesLast7Days;
    if (child.totalTrackedClasses > 0) {
      attendance += child.attendanceRate;
      contributors += 1;
    }
    child.subjectBreakdown.forEach((count, subject) => subjectTotals.set(subject, (subjectTotals.get(subject) ?? 0) + count));
  }
  return {
    children: sorted,
    dayLabels,
    classesByDay,
    topSubjects: [...subjectTotals.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4),
    averageAttendanceRate: contributors > 0 ? attendance / contributors : 0,
    totalLearningHours: hours,
    classesThisWeek: week,
    needsSupportChildren: sorted.filter((child) => child.attentionLevel === "needsSupport").length,
  };
}

/** Bar height in the 112 px Weekly Activity chart. */
export function weeklyBarHeight(value: number, max: number) {
  if (max === 0) return 8;
  return 10 + (value / max) * 60;
}

/** "{n} classes" — Flutter prints "1 classes"; the singular is fixed. */
export function classesCountLabel(n: number) {
  return `${n} ${n === 1 ? "class" : "classes"}`;
}

/** "+2 class activity vs previous week" / "Stable …". `stable` differs between the family card and the child tab. */
export function trendLabel(delta: number, stable: string) {
  if (delta === 0) return stable;
  return delta > 0 ? `+${delta} class activity vs previous week` : `${delta} class activity vs previous week`;
}

export function trendColor(delta: number, flat: string) {
  return delta > 0 ? "#16A34A" : delta < 0 ? "#DC2626" : flat;
}

// ─── Attendance Analytics (A-046…A-049, server report D5) ──────────────────

export type AttendancePeriod = "weekly" | "monthly";

export type ChildAnalytics = {
  id: string;
  name: string;
  hasReport: boolean;
  scheduledClasses: number;
  attendedClasses: number;
  absentClasses: number;
  lateClasses: number;
  onTimeClasses: number;
  teacherAbsentClasses: number;
  joinsBeforeStartEvents: number;
  attendanceRate: number;
  punctualityRate: number;
  lateRate: number;
  averageJoinOffsetMinutes: number;
  totalPresenceMinutes: number;
  totalOverlapMinutes: number;
};

function asMap(value: unknown): Data {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Data) : {};
}

/** Dart `_asInt`: int, num rounded, or a parsable string; otherwise 0. */
function asInt(value: unknown): number {
  if (typeof value === "number") return Number.isFinite(value) ? Math.round(value) : 0;
  if (typeof value === "string") {
    const trimmed = value.trim();
    return /^[-+]?\d+$/.test(trimmed) ? Number.parseInt(trimmed, 10) : 0;
  }
  return 0;
}

/** Dart `_asDouble`: num or a parsable string; otherwise null. */
function asDouble(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return null;
    const parsed = Number(trimmed);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

const clamp01 = (value: number) => Math.min(1, Math.max(0, value));

export function emptyChildAnalytics(id: string, name: string): ChildAnalytics {
  return {
    id,
    name,
    hasReport: false,
    scheduledClasses: 0,
    attendedClasses: 0,
    absentClasses: 0,
    lateClasses: 0,
    onTimeClasses: 0,
    teacherAbsentClasses: 0,
    joinsBeforeStartEvents: 0,
    attendanceRate: 0,
    punctualityRate: 0,
    lateRate: 0,
    averageJoinOffsetMinutes: 0,
    totalPresenceMinutes: 0,
    totalOverlapMinutes: 0,
  };
}

/** `_buildChildAttendanceAnalyticsSnapshot`; `report` = the callable's `report` (null when it failed). */
export function childAnalytics(child: { id: string; name: string }, report: Data | null): ChildAnalytics {
  const id = child.id.trim();
  const name = childDisplayName(child.name);
  if (!id || !report) return emptyChildAnalytics(id, name);
  const metrics = asMap(report.metrics);
  const rates = asMap(report.rates);
  const averages = asMap(report.averages);
  const scheduled = asInt(metrics.scheduled_classes);
  const attended = asInt(metrics.attended_classes);
  const late = asInt(metrics.late_classes);
  const onTime = asInt(metrics.on_time_classes);
  return {
    id,
    name,
    hasReport: true,
    scheduledClasses: scheduled,
    attendedClasses: attended,
    absentClasses: asInt(metrics.absent_classes),
    lateClasses: late,
    onTimeClasses: onTime,
    teacherAbsentClasses: asInt(metrics.student_present_teacher_absent_classes),
    joinsBeforeStartEvents: asInt(metrics.total_joins_before_start_events),
    attendanceRate: clamp01(asDouble(rates.attendance_rate) ?? (scheduled > 0 ? attended / scheduled : 0)),
    punctualityRate: clamp01(asDouble(rates.punctuality_rate) ?? (attended > 0 ? onTime / attended : 0)),
    lateRate: clamp01(asDouble(rates.late_rate) ?? (attended > 0 ? late / attended : 0)),
    averageJoinOffsetMinutes: asDouble(averages.average_join_offset_minutes) ?? 0,
    totalPresenceMinutes: asDouble(metrics.total_student_presence_minutes) ?? 0,
    totalOverlapMinutes: asDouble(metrics.total_teacher_overlap_minutes) ?? 0,
  };
}

export type FamilyAnalytics = {
  children: ChildAnalytics[];
  averageAttendanceRate: number;
  averagePunctualityRate: number;
  totalLateClasses: number;
  totalTeacherAbsentIncidents: number;
  totalPresenceMinutes: number;
};

/** `_buildParentAttendanceAnalyticsOverview`. */
export function familyAnalytics(children: ChildAnalytics[]): FamilyAnalytics {
  const sorted = [...children].sort((a, b) => {
    const rate = a.attendanceRate - b.attendanceRate;
    return rate !== 0 ? rate : b.scheduledClasses - a.scheduledClasses;
  });
  let attendance = 0;
  let punctuality = 0;
  let contributors = 0;
  let late = 0;
  let teacherAbsent = 0;
  let presence = 0;
  for (const child of sorted) {
    late += child.lateClasses;
    teacherAbsent += child.teacherAbsentClasses;
    presence += child.totalPresenceMinutes;
    if (child.scheduledClasses > 0) {
      attendance += child.attendanceRate;
      punctuality += child.punctualityRate;
      contributors += 1;
    }
  }
  return {
    children: sorted,
    averageAttendanceRate: contributors > 0 ? attendance / contributors : 0,
    averagePunctualityRate: contributors > 0 ? punctuality / contributors : 0,
    totalLateClasses: late,
    totalTeacherAbsentIncidents: teacherAbsent,
    totalPresenceMinutes: presence,
  };
}

export type JoinOffset = { kind: "none" } | { kind: "onTime" } | { kind: "early" | "late"; minutes: string };

/** `_formatJoinOffset`: negative = early. */
export function joinOffset(minutes: number): JoinOffset {
  if (!Number.isFinite(minutes)) return { kind: "none" };
  if (minutes === 0) return { kind: "onTime" };
  return { kind: minutes < 0 ? "early" : "late", minutes: Math.abs(minutes).toFixed(1) };
}

/** Dart `(x * 100).round()` for a 0..1 rate. */
export function percent(rate: number) {
  return Math.round(rate * 100);
}

// ─── Invoices (Invoice model + InvoiceCard) ────────────────────────────────

export type InvoiceStatus = "pending" | "paid" | "overdue" | "cancelled";

export type ParentInvoice = {
  id: string;
  invoiceNumber: string;
  parentId: string;
  studentId: string;
  status: InvoiceStatus;
  totalAmount: number;
  paidAmount: number;
  currency: string;
  dueDate: Date;
  issuedDate: Date;
  period: string | null;
  periodStart: string | null;
  periodEnd: string | null;
  accessCutoffDate: Date | null;
  lastPaymentAt: Date | null;
  items: InvoiceItem[];
  createdByUid: string;
  createdByName: string;
  createdByEmail: string;
  createdAt: Date | null;
};

export type InvoiceItem = { description: string; quantity: number; unitPrice: number; total: number };

function parseItems(value: unknown): InvoiceItem[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((entry): entry is Data => !!entry && typeof entry === "object" && !Array.isArray(entry))
    .map((item) => {
      const qty = toNumber(item.quantity);
      return {
        description: str(item.description ?? ""),
        quantity: qty === null ? 1 : Math.trunc(qty),
        unitPrice: toNumber(item.unit_price ?? item.unitPrice) ?? 0,
        total: toNumber(item.total) ?? 0,
      };
    });
}

/** Invoice.fromMap. Missing due date = 30 days from now, as Flutter defaults it. */
export function parseInvoice(id: string, data: Data, now: Date = new Date()): ParentInvoice {
  const rawStatus = str(data.status).trim();
  const periodRaw = str(data.period ?? data.billing_period ?? data.billingPeriod).trim();
  const periodStart = data.period_start ?? data.periodStart;
  const periodEnd = data.period_end ?? data.periodEnd;
  return {
    id,
    invoiceNumber: str(data.invoice_number ?? data.invoiceNumber),
    parentId: str(data.parent_id ?? data.parentId),
    studentId: str(data.student_id ?? data.studentId),
    status: (["pending", "paid", "overdue", "cancelled"] as const).find((s) => s === rawStatus) ?? "pending",
    totalAmount: toNumber(data.total_amount ?? data.totalAmount) ?? 0,
    paidAmount: toNumber(data.paid_amount ?? data.paidAmount) ?? 0,
    currency: str(data.currency ?? "USD") || "USD",
    issuedDate: anyDate(data.issued_date ?? data.issuedDate) ?? now,
    dueDate: anyDate(data.due_date ?? data.dueDate) ?? new Date(now.getTime() + 30 * DAY_MS),
    period: periodRaw || null,
    periodStart: periodStart == null ? null : String(periodStart),
    periodEnd: periodEnd == null ? null : String(periodEnd),
    accessCutoffDate: anyDate(data.access_cutoff_date ?? data.accessCutoffDate),
    lastPaymentAt: anyDate(data.last_payment_at ?? data.lastPaymentAt),
    items: parseItems(data.items),
    createdByUid: str(data.created_by ?? data.createdBy ?? ""),
    createdByName: str(data.created_by_name ?? data.createdByName ?? ""),
    createdByEmail: str(data.created_by_email ?? data.createdByEmail ?? ""),
    createdAt: anyDate(data.created_at ?? data.createdAt),
  };
}

export const invoiceFullyPaid = (inv: ParentInvoice) => inv.totalAmount <= 0 || inv.paidAmount >= inv.totalAmount;
export const invoiceRemaining = (inv: ParentInvoice) => Math.max(0, inv.totalAmount - inv.paidAmount);
export const invoiceOverdue = (inv: ParentInvoice, now: Date) =>
  !invoiceFullyPaid(inv) && now.getTime() > inv.dueDate.getTime() && inv.status !== "cancelled";
export const invoicePayable = (inv: ParentInvoice) => !invoiceFullyPaid(inv) && inv.status !== "cancelled";
export const effectiveCutoff = (inv: ParentInvoice) => inv.accessCutoffDate ?? new Date(inv.dueDate.getTime() + DAY_MS);

export function invoiceBadge(inv: ParentInvoice, now: Date): { label: string; color: string } {
  if (invoiceOverdue(inv, now)) return { label: "OVERDUE", color: "#DC2626" };
  switch (inv.status) {
    case "paid":
      return { label: "PAID", color: "#059669" };
    case "cancelled":
      return { label: "CANCELLED", color: "#6B7280" };
    case "overdue":
      return { label: "OVERDUE", color: "#D97706" };
    default:
      return { label: "PENDING", color: "#D97706" };
  }
}

function periodLabel(value: string | null, compact: boolean): string | null {
  const match = /(\d{4})-(\d{2})/.exec((value ?? "").trim());
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (month < 1 || month > 12) return null;
  return new Date(year, month - 1, 1).toLocaleDateString("en-US", { month: compact ? "short" : "long", year: "numeric" });
}

/** Invoice.displayBillingPeriod. */
export function billingPeriod(inv: ParentInvoice): string | null {
  const start = periodLabel(inv.periodStart, true);
  const end = periodLabel(inv.periodEnd, true);
  if (start && end) return start === end ? start : `${start} - ${end}`;
  const p = inv.period;
  if (!p) return null;
  if (p.includes("..")) {
    const parts = p.split("..");
    const a = periodLabel(parts[0] ?? null, true);
    const b = periodLabel(parts.length > 1 ? parts[parts.length - 1] : null, true);
    if (a && b) return `${a} - ${b}`;
  }
  return periodLabel(p, false) ?? p;
}

/** `_DueDateChip`: "Nov 5", or "{n} day(s) overdue" counted from today's midnight. */
export function dueChipLabel(inv: ParentInvoice, now: Date) {
  if (!invoiceOverdue(inv, now)) return formatMonthDay(inv.dueDate);
  const days = Math.trunc((startOfDay(now).getTime() - inv.dueDate.getTime()) / DAY_MS);
  return `${days} day${days === 1 ? "" : "s"} overdue`;
}

export type CutoffBadge = { label: string; tone: "red" | "orange" | "amber"; locked: boolean } | null;

/** `_AccessCutoffBadge` (only for unpaid, non-cancelled invoices). */
export function cutoffBadge(inv: ParentInvoice, now: Date): CutoffBadge {
  if (!invoicePayable(inv)) return null;
  const daysLeft = Math.trunc((effectiveCutoff(inv).getTime() - now.getTime()) / DAY_MS);
  const isPast = daysLeft < 0;
  if (!isPast && daysLeft > 14) return null;
  if (isPast || daysLeft === 0) {
    const ago = -daysLeft;
    return { label: isPast ? `Access suspended ${ago} day${ago === 1 ? "" : "s"} ago` : "Access suspended today", tone: "red", locked: true };
  }
  if (daysLeft <= 3) {
    return { label: daysLeft === 1 ? "Access cut off tomorrow" : `Access cut off in ${daysLeft} days`, tone: "orange", locked: false };
  }
  return { label: `Access cut off in ${daysLeft} days`, tone: "amber", locked: false };
}

// ─── Payments ──────────────────────────────────────────────────────────────

export type PaymentStatus = "pending" | "processing" | "completed" | "failed";

export type ParentPayment = { id: string; invoiceId: string; amount: number; status: PaymentStatus; createdAt: Date | null; completedAt: Date | null };

export function parsePayment(id: string, data: Data): ParentPayment {
  const raw = str(data.status).trim();
  return {
    id,
    invoiceId: str(data.invoice_id ?? data.invoiceId),
    amount: toNumber(data.amount) ?? 0,
    status: (["pending", "processing", "completed", "failed"] as const).find((s) => s === raw) ?? "pending",
    createdAt: anyDate(data.created_at ?? data.createdAt),
    completedAt: anyDate(data.completed_at ?? data.completedAt),
  };
}

export const PAYMENT_DOT: Record<PaymentStatus, string> = { completed: "#16A34A", failed: "#DC2626", processing: "#2563EB", pending: "#F59E0B" };

/** "COMPLETED • Nov 5, 2026" (date omitted when missing). */
export function paymentSubtitle(payment: ParentPayment) {
  const created = payment.createdAt ? formatMediumDate(payment.createdAt) : "";
  return `${payment.status.toUpperCase()}${created ? ` • ${created}` : ""}`;
}

// ─── Money summary (A-035, ParentService._computeFinancialSummary) ─────────

export function financialSummary(invoices: ParentInvoice[], payments: ParentPayment[], now: Date) {
  const paidByInvoice = new Map<string, number>();
  for (const payment of payments) {
    if (payment.status !== "completed") continue;
    const invoiceId = payment.invoiceId.trim();
    if (!invoiceId) continue;
    paidByInvoice.set(invoiceId, (paidByInvoice.get(invoiceId) ?? 0) + payment.amount);
  }
  let outstanding = 0;
  let overdue = 0;
  for (const invoice of invoices) {
    const completed = paidByInvoice.get(invoice.id) ?? 0;
    const paid = completed > invoice.paidAmount ? completed : invoice.paidAmount;
    const remaining = invoice.totalAmount - paid;
    if (invoice.status === "cancelled" || remaining <= 0) continue;
    outstanding += remaining;
    if (invoice.dueDate.getTime() < now.getTime()) overdue += remaining;
  }
  return { outstanding, overdue };
}

/** Recent Invoices (D10): parent_id top 5 + student_id, de-duplicated, latest due date first, 5. */
export function mergeRecentInvoices(byParent: ParentInvoice[], byStudent: ParentInvoice[], limit = 5) {
  const merged = new Map<string, ParentInvoice>();
  for (const invoice of [...byParent, ...byStudent]) merged.set(invoice.id, invoice);
  return [...merged.values()].sort((a, b) => b.dueDate.getTime() - a.dueDate.getTime()).slice(0, limit);
}

// ─── Class card (ParentPresenceCard) ───────────────────────────────────────

export const isClockedIn = (shift: ParentShift) => shift.clockInTime !== null && shift.clockOutTime === null && shift.status === "active";
export const isLive = (shift: ParentShift) => shift.status === "active" || isClockedIn(shift);
export const hasVideoCall = (shift: ParentShift) => isTeaching(shift) && shift.studentIds.length > 0;

/** ClassVideoService.canJoinClass: 10 minutes before the start to 10 minutes after the end. */
export function inJoinWindow(shift: ParentShift, now: Date) {
  if (!hasVideoCall(shift)) return false;
  const t = now.getTime();
  return t >= shift.shiftStart.getTime() - 10 * 60_000 && t <= shift.shiftEnd.getTime() + 10 * 60_000;
}

/** The card offers Join when the class is live or inside the join window. */
export const canJoin = (shift: ParentShift, now: Date) => isLive(shift) || inJoinWindow(shift, now);

export type CardStatus = { label: string; color: string; icon: "play" | "check" | "cancel" | "warning" | "schedule" };

export function cardStatus(shift: ParentShift, now: Date): CardStatus {
  switch (shift.status) {
    case "active":
      return { label: "In Progress", color: "#10B981", icon: "play" };
    case "completed":
    case "partiallyCompleted":
    case "fullyCompleted":
      return { label: "Completed", color: "#6B7280", icon: "check" };
    case "cancelled":
      return { label: "Cancelled", color: "#EF4444", icon: "cancel" };
    case "missed":
      return { label: "Missed", color: "#F59E0B", icon: "warning" };
    default:
      if (isClockedIn(shift)) return { label: "In Progress", color: "#10B981", icon: "play" };
      if (shift.shiftStart.getTime() < now.getTime()) return { label: "Missed", color: "#F59E0B", icon: "warning" };
      return { label: "Scheduled", color: "#3B82F6", icon: "schedule" };
  }
}

/** Readable status for the details sheet (Flutter prints the raw name in capitals). */
export const STATUS_WORDS: Record<ShiftStatus, string> = {
  scheduled: "Scheduled",
  active: "In progress",
  completed: "Completed",
  partiallyCompleted: "Partially completed",
  fullyCompleted: "Fully completed",
  missed: "Missed",
  cancelled: "Cancelled",
};

/** `_formatDuration`: "1h 5m", "12m", "Just joined". */
export function presenceDuration(ms: number) {
  const minutes = Math.floor(ms / 60_000);
  const hours = Math.floor(minutes / 60);
  if (hours > 0) return `${hours}h ${minutes % 60}m`;
  if (minutes > 0) return `${minutes}m`;
  return "Just joined";
}

export type PresenceParticipant = { identity: string; name: string; role: string | null; joinedAt: Date | null; isPublisher: boolean };
export type RoomPresence = { participantCount: number; participants: PresenceParticipant[] };

/** ClassRoomPresenceResult.fromMap; a failed call is an empty room, as in Flutter. */
export function parsePresence(raw: unknown): RoomPresence {
  const data = asMap(raw);
  const list = Array.isArray(data.participants) ? data.participants : [];
  const participants = list.map((entry) => {
    const p = asMap(entry);
    const iso = p.joinedAtIso == null ? null : String(p.joinedAtIso);
    const joined = iso ? new Date(iso) : null;
    return {
      identity: str(p.identity),
      name: str(p.name),
      role: p.role == null ? null : String(p.role),
      joinedAt: joined && !Number.isNaN(joined.getTime()) ? joined : null,
      isPublisher: p.isPublisher === true,
    };
  });
  return { participantCount: asInt(data.participantCount), participants };
}

export const EMPTY_PRESENCE: RoomPresence = { participantCount: 0, participants: [] };

// ─── Attendance calendar (A-072) ───────────────────────────────────────────

const CALENDAR_PRIORITY: Partial<Record<ShiftStatus, number>> = {
  completed: 4,
  fullyCompleted: 4,
  partiallyCompleted: 4,
  missed: 3,
  cancelled: 2,
  scheduled: 1,
};

export const CALENDAR_TINT: Partial<Record<ShiftStatus, string>> = {
  completed: "#D1FAE5",
  fullyCompleted: "#D1FAE5",
  partiallyCompleted: "#D1FAE5",
  missed: "#FEE2E2",
  cancelled: "#F3F4F6",
  scheduled: "#DBEAFE",
};

export type CalendarCell = { day: number; status: ShiftStatus | null; isToday: boolean } | null;

/** AttendanceCalendar: Monday-first weeks of `month`, each day's most significant status. */
export function calendarWeeks(shifts: ParentShift[], month: Date, now: Date): CalendarCell[][] {
  const year = month.getFullYear();
  const m = month.getMonth();
  const daysInMonth = new Date(year, m + 1, 0).getDate();
  const firstWeekday = ((new Date(year, m, 1).getDay() + 6) % 7) + 1; // 1 = Monday … 7 = Sunday
  const statusByDay = new Map<number, ShiftStatus>();
  for (const shift of shifts) {
    if (shift.shiftStart.getFullYear() !== year || shift.shiftStart.getMonth() !== m) continue;
    const day = shift.shiftStart.getDate();
    const current = statusByDay.get(day);
    if (current === undefined || (CALENDAR_PRIORITY[shift.status] ?? 0) > (CALENDAR_PRIORITY[current] ?? 0)) statusByDay.set(day, shift.status);
  }
  const weeks: CalendarCell[][] = [];
  const weekCount = Math.ceil((daysInMonth + firstWeekday - 1) / 7);
  for (let w = 0; w < weekCount; w += 1) {
    const row: CalendarCell[] = [];
    for (let d = 0; d < 7; d += 1) {
      const day = w * 7 + d - (firstWeekday - 1) + 1;
      if (day < 1 || day > daysInMonth) row.push(null);
      else
        row.push({
          day,
          status: statusByDay.get(day) ?? null,
          isToday: day === now.getDate() && year === now.getFullYear() && m === now.getMonth(),
        });
    }
    weeks.push(row);
  }
  return weeks;
}

// ─── Tasks (A-075…A-079) ───────────────────────────────────────────────────

export type TaskStatus = "todo" | "inProgress" | "done";
export type TaskPriority = "low" | "medium" | "high";

export type ParentTask = {
  id: string;
  title: string;
  description: string;
  createdBy: string;
  dueDate: Date;
  priority: TaskPriority;
  status: TaskStatus;
  createdAt: Date;
  completedAt: Date | null;
  attachmentCount: number;
};

/**
 * Task.fromFirestore. Status and priority are stored as "TaskStatus.done" /
 * "TaskPriority.high". Flutter fails the whole list on a task without a due
 * date; that one task is skipped instead (returns null).
 */
export function parseTask(id: string, data: Data, now: Date = new Date()): ParentTask | null {
  const dueDate = timestampDate(data.dueDate);
  if (!dueDate) return null;
  const status = (["todo", "inProgress", "done"] as const).find((s) => `TaskStatus.${s}` === data.status) ?? "todo";
  const priority = (["low", "medium", "high"] as const).find((p) => `TaskPriority.${p}` === data.priority) ?? "medium";
  return {
    id,
    title: str(data.title ?? ""),
    description: str(data.description ?? ""),
    createdBy: str(data.createdBy ?? ""),
    dueDate,
    priority,
    status,
    createdAt: timestampDate(data.createdAt) ?? now,
    completedAt: timestampDate(data.completedAt),
    attachmentCount: Array.isArray(data.attachments) ? data.attachments.length : 0,
  };
}

export const sortTasks = (tasks: ParentTask[]) => [...tasks].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

export type TaskFilter = "all" | "pending" | "completed" | "overdue";

export function taskMatches(task: ParentTask, filter: TaskFilter, now: Date) {
  switch (filter) {
    case "pending":
      return task.status !== "done" && task.dueDate.getTime() >= now.getTime();
    case "completed":
      return task.status === "done";
    case "overdue":
      return task.status !== "done" && task.dueDate.getTime() < now.getTime();
    default:
      return true;
  }
}

export function taskCounters(tasks: ParentTask[], now: Date) {
  return {
    total: tasks.length,
    completed: tasks.filter((t) => taskMatches(t, "completed", now)).length,
    pending: tasks.filter((t) => taskMatches(t, "pending", now)).length,
    overdue: tasks.filter((t) => taskMatches(t, "overdue", now)).length,
  };
}

export const taskIsOverdue = (task: ParentTask, now: Date) => task.dueDate.getTime() < now.getTime() && task.status !== "done";

export const TASK_PRIORITY_BADGE: Record<TaskPriority, { label: string; bg: string; fg: string }> = {
  high: { label: "High", bg: "#FEE2E2", fg: "#DC2626" },
  medium: { label: "Med", bg: "#FEF3C7", fg: "#D97706" },
  low: { label: "Low", bg: "#DBEAFE", fg: "#2563EB" },
};

export const TASK_STATUS_BADGE: Record<TaskStatus, { label: string; bg: string; fg: string }> = {
  done: { label: "Done", bg: "#D1FAE5", fg: "#065F46" },
  inProgress: { label: "In Progress", bg: "#DBEAFE", fg: "#1E40AF" },
  todo: { label: "To Do", bg: "#F3F4F6", fg: "#374151" },
};

// ─── Child page: Overview (A-060…A-063) ────────────────────────────────────

/** Quick stats: every past class (D3, no start), 30-day class-status rate, tasks done/total. */
export function quickStats(pastShifts: ParentShift[], tasks: ParentTask[], now: Date) {
  const monthStart = new Date(now.getTime() - 30 * DAY_MS);
  const recent = historyWindow(pastShifts, now, monthStart);
  let completed = 0;
  let tracked = 0;
  for (const shift of recent) {
    if (isCompletedStatus(shift.status)) {
      completed += 1;
      tracked += 1;
    } else if (shift.status === "missed" || shift.status === "cancelled") {
      tracked += 1;
    }
  }
  return {
    totalClasses: historyWindow(pastShifts, now, null).length,
    attendanceRate: tracked > 0 ? completed / tracked : 0,
    completedTasks: tasks.filter((t) => t.status === "done").length,
    totalTasks: tasks.length,
  };
}

/**
 * Recent Activity. "Last class completed" looks for status `completed` only:
 * Flutter's `contains('completed')` test never matches fullyCompleted or
 * partiallyCompleted, and the same classes are left out here.
 */
export function recentActivity(tasks: ParentTask[], pastShifts: ParentShift[]) {
  const doneTasks = tasks
    .filter((t) => t.status === "done")
    .sort((a, b) => {
      if (!a.completedAt && !b.completedAt) return 0;
      if (!a.completedAt) return 1;
      if (!b.completedAt) return -1;
      return b.completedAt.getTime() - a.completedAt.getTime();
    });
  const classes = pastShifts.filter((s) => s.status === "completed").sort((a, b) => b.shiftStart.getTime() - a.shiftStart.getTime());
  return { lastTask: doneTasks[0] ?? null, lastClass: classes[0] ?? null };
}

/** Today's classes: start inside local today, teaching only, earliest first. */
export function todayClasses(shifts: ParentShift[], now: Date) {
  const start = startOfDay(now).getTime();
  const end = addDays(startOfDay(now), 1).getTime();
  return shifts
    .filter((s) => isTeaching(s) && s.shiftStart.getTime() >= start && s.shiftStart.getTime() < end)
    .sort((a, b) => a.shiftStart.getTime() - b.shiftStart.getTime());
}

/** Upcoming preview: start in [now, now + 7 days), teaching only, earliest first, first 5. */
export function upcomingPreview(shifts: ParentShift[], now: Date) {
  const t = now.getTime();
  return shifts
    .filter((s) => isTeaching(s) && s.shiftStart.getTime() >= t && s.shiftStart.getTime() < t + 7 * DAY_MS)
    .sort((a, b) => a.shiftStart.getTime() - b.shiftStart.getTime())
    .slice(0, 5);
}

/** Classes tab Upcoming list: the live teaching classes that have not ended. */
export function upcomingList(liveShifts: ParentShift[], now: Date) {
  return liveShifts.filter((s) => s.shiftEnd.getTime() > now.getTime()).sort((a, b) => a.shiftStart.getTime() - b.shiftStart.getTime());
}

// ─── Child page: Progress tab (A-080…A-085) ────────────────────────────────

export type SubjectProgress = { name: string; totalClasses: number; completedClasses: number; missedClasses: number; cancelledClasses: number; totalHours: number };

export type ChildProgressMetrics = {
  attendanceRate: number;
  completedClasses: number;
  missedClasses: number;
  cancelledClasses: number;
  totalTrackedClasses: number;
  classesLast7Days: number;
  classesPrevious7Days: number;
  uniqueSubjectsLast30Days: number;
  totalHoursLast30Days: number;
  weeklyCounts: number[];
  weekDays: Date[];
  subjectStats: SubjectProgress[];
  attentionLevel: AttentionLevel;
};

/** StudentProgressTab._buildMetrics over the live class stream (D4). */
export function childProgressMetrics(shifts: ParentShift[], now: Date): ChildProgressMetrics {
  const today = startOfDay(now);
  const weekStart = addDays(today, -6);
  const monthStart = now.getTime() - 30 * DAY_MS;
  const sevenAgo = now.getTime() - 7 * DAY_MS;
  const fourteenAgo = now.getTime() - 14 * DAY_MS;
  let completed = 0;
  let missed = 0;
  let cancelled = 0;
  let last7 = 0;
  let previous7 = 0;
  let hours = 0;
  const weekly = [0, 0, 0, 0, 0, 0, 0];
  const uniqueSubjects = new Set<string>();
  const bySubject = new Map<string, SubjectProgress>();

  for (const shift of shifts) {
    if (shift.shiftStart.getTime() >= now.getTime()) continue;
    const name = progressSubject(shift);
    const done = isCompletedStatus(shift.status);
    const acc = bySubject.get(name) ?? { name, totalClasses: 0, completedClasses: 0, missedClasses: 0, cancelledClasses: 0, totalHours: 0 };
    bySubject.set(name, acc);
    acc.totalClasses += 1;
    if (done) {
      const h = hoursOf(shift);
      acc.completedClasses += 1;
      acc.totalHours += h > 0 ? h : 0;
    } else if (shift.status === "missed") acc.missedClasses += 1;
    else if (shift.status === "cancelled") acc.cancelledClasses += 1;

    if (shift.shiftStart.getTime() <= monthStart) continue;
    uniqueSubjects.add(name);
    const day = startOfDay(shift.shiftStart);
    const index = dayDiff(weekStart, day);
    if (index >= 0 && index < 7 && day.getTime() <= today.getTime()) weekly[index] += 1;
    if (shift.shiftStart.getTime() > sevenAgo) last7 += 1;
    else if (shift.shiftStart.getTime() > fourteenAgo) previous7 += 1;
    if (done) {
      const h = hoursOf(shift);
      completed += 1;
      hours += h > 0 ? h : 0;
    } else if (shift.status === "missed") missed += 1;
    else if (shift.status === "cancelled") cancelled += 1;
  }

  const tracked = completed + missed + cancelled;
  const rate = tracked > 0 ? completed / tracked : 0;
  return {
    attendanceRate: rate,
    completedClasses: completed,
    missedClasses: missed,
    cancelledClasses: cancelled,
    totalTrackedClasses: tracked,
    classesLast7Days: last7,
    classesPrevious7Days: previous7,
    uniqueSubjectsLast30Days: uniqueSubjects.size,
    totalHoursLast30Days: hours,
    weeklyCounts: weekly,
    weekDays: Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)),
    subjectStats: [...bySubject.values()].sort((a, b) => b.totalClasses - a.totalClasses),
    attentionLevel: attentionLevel(rate, tracked),
  };
}

export function completionColor(rate: number) {
  if (rate >= 0.8) return "#16A34A";
  if (rate >= 0.6) return "#D97706";
  return "#DC2626";
}

// ─── Formatting (always US English, as in Flutter) ─────────────────────────

const fmt = (date: Date, options: Intl.DateTimeFormatOptions) => date.toLocaleString("en-US", options);

/** "h:mm a" → "3:05 PM". */
export const formatTime = (d: Date) => fmt(d, { hour: "numeric", minute: "2-digit" });
/** "EEEE, MMM d, yyyy" → "Monday, Nov 5, 2026". */
export const formatCardDate = (d: Date) => fmt(d, { weekday: "long", month: "short", day: "numeric", year: "numeric" });
/** "MMM dd, yyyy" → "Nov 05, 2026". */
export const formatPaddedDate = (d: Date) => fmt(d, { month: "short", day: "2-digit", year: "numeric" });
/** yMMMd → "Nov 5, 2026". */
export const formatMediumDate = (d: Date) => fmt(d, { month: "short", day: "numeric", year: "numeric" });
/** "MMM d" → "Nov 5". */
export const formatMonthDay = (d: Date) => fmt(d, { month: "short", day: "numeric" });
/** "EEE" → "Mon". */
export const formatWeekday = (d: Date) => fmt(d, { weekday: "short" });
/** "MMMM yyyy" → "November 2026". */
export const formatMonthYear = (d: Date) => fmt(d, { month: "long", year: "numeric" });
/** "EEEE, MMMM d, yyyy • h:mm a". */
export const formatSheetDate = (d: Date) => `${fmt(d, { weekday: "long", month: "long", day: "numeric", year: "numeric" })} • ${formatTime(d)}`;
/** "MMM dd, yyyy • h:mm a". */
export const formatActivityDate = (d: Date) => `${formatPaddedDate(d)} • ${formatTime(d)}`;

/** NumberFormat.simpleCurrency(): "$1,234.50". */
export function formatUsd(amount: number) {
  return amount.toLocaleString("en-US", { style: "currency", currency: "USD" });
}

/** NumberFormat.simpleCurrency(name: currency); an unknown code falls back to dollars. */
export function formatMoney(amount: number, currency: string) {
  try {
    return amount.toLocaleString("en-US", { style: "currency", currency: currency || "USD" });
  } catch {
    return formatUsd(amount);
  }
}
