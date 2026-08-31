import {
  Timestamp,
  addDoc,
  collection,
  deleteDoc,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  startAfter,
  updateDoc,
  where,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import type { User } from "firebase/auth";
import { db, functions } from "@/lib/firebase";
import { safeTimezone } from "@/lib/timezones";

/**
 * Admin shift scheduling: data access + the business rules that keep the
 * schedule honest. These mirror the Flutter ShiftService rules exactly:
 *  - a teacher can never hold two overlapping shifts,
 *  - Zoom teaching classes are capped at 3 hours,
 *  - the scheduled window is the pay window, so times are validated hard.
 */

export type ShiftCategory = "teaching" | "leadership" | "meeting" | "training";

export type ShiftDoc = {
  id: string;
  teacherId: string;
  teacherName: string;
  studentIds: string[];
  studentNames: string[];
  title: string;
  subject: string;
  subjectId: string | null;
  subjectDisplayName: string;
  category: ShiftCategory;
  leaderRole: string | null;
  start: Date;
  end: Date;
  status: string;
  hourlyRate: number;
  notes: string;
  adminTimezone: string;
  teacherTimezone: string;
  templateId: string | null;
  /** "none" for one-off shifts, otherwise daily/weekly/monthly/yearly. */
  recurrence: string;
  isPublished: boolean;
  createdByName: string;
  customName: string;
};

/** True when a shift belongs to a recurring series (base shift or instance). */
export function isRecurringShift(shift: ShiftDoc): boolean {
  return Boolean(shift.templateId) || (shift.recurrence !== "" && shift.recurrence !== "none");
}

/** The template id for a series shift — its own id when it is the base shift. */
export function seriesTemplateId(shift: ShiftDoc): string {
  return shift.templateId ?? shift.id;
}

export type StaffMember = {
  id: string;
  displayName: string;
  email: string;
  initials: string;
  group: "teacher" | "leader";
  timezone: string;
};

export type StudentOption = {
  id: string;
  displayName: string;
  /** Human-facing student code (login/kiosk id) shown in pickers. */
  studentCode: string;
  email: string;
  /** IANA timezone from the student's profile; "" when unset. */
  timezone: string;
};

export type SubjectOption = {
  id: string;
  name: string;
  displayName: string;
  defaultWage: number | null;
};

export const ZOOM_MAX_CLASS_MINUTES = 180;

/* ------------------------------ normalizers ------------------------------ */

const str = (v: unknown) => (typeof v === "string" ? v : v == null ? "" : String(v));
const strArr = (v: unknown) => (Array.isArray(v) ? v.map((x) => str(x)).filter(Boolean) : []);
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : null);

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === "string") {
    const parsed = new Date(v);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

export function normalizeShift(id: string, data: Record<string, unknown>): ShiftDoc | null {
  const start = toDate(data.shift_start);
  const end = toDate(data.shift_end);
  if (!start || !end) return null;
  const subjectDisplayName = str(data.subject_display_name);
  const category = (str(data.shift_category) || "teaching") as ShiftCategory;
  return {
    id,
    teacherId: str(data.teacher_id),
    teacherName: str(data.teacher_name) || "Unassigned",
    studentIds: strArr(data.student_ids),
    studentNames: strArr(data.student_names),
    title: str(data.custom_name) || str(data.auto_generated_name) || subjectDisplayName || "Shift",
    subject: str(data.subject),
    subjectId: str(data.subject_id) || null,
    subjectDisplayName,
    category,
    leaderRole: str(data.leader_role) || null,
    start,
    end,
    status: str(data.status) || "scheduled",
    hourlyRate: num(data.hourly_rate) ?? 0,
    notes: str(data.notes),
    adminTimezone: safeTimezone(str(data.admin_timezone)),
    teacherTimezone: safeTimezone(str(data.teacher_timezone)),
    templateId: str(data.template_id) || null,
    recurrence: str(data.recurrence) || "none",
    isPublished: data.is_published === true,
    createdByName: str(data.created_by_name),
    customName: str(data.custom_name),
  };
}

/* ------------------------------- timezones ------------------------------- */

export const COMMON_TIMEZONES = [
  "America/New_York",
  "America/Chicago",
  "America/Denver",
  "America/Los_Angeles",
  "Europe/London",
  "Europe/Paris",
  "Africa/Conakry",
  "Africa/Monrovia",
  "Africa/Dakar",
  "Asia/Riyadh",
  "Asia/Dubai",
];

/** Offset of `zone` from UTC at `utcDate`, in minutes. */
function zoneOffsetMinutes(utcDate: Date, zone: string): number {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: zone,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts = dtf.formatToParts(utcDate);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? "0");
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour") % 24, get("minute"), get("second"));
  return Math.round((asUtc - utcDate.getTime()) / 60000);
}

/** Interpret a wall-clock date+time in an IANA timezone and return the UTC instant. */
export function zonedTimeToUtc(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  zone: string,
): Date {
  const naiveUtc = Date.UTC(year, month - 1, day, hour, minute);
  // Two-pass offset resolution handles DST transitions.
  let offset = zoneOffsetMinutes(new Date(naiveUtc), zone);
  offset = zoneOffsetMinutes(new Date(naiveUtc - offset * 60000), zone);
  return new Date(naiveUtc - offset * 60000);
}

export function formatInZone(date: Date, zone: string): string {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: safeTimezone(zone),
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

/* ------------------------------ business rules ---------------------------- */

/** True when [aStart,aEnd) and [bStart,bEnd) overlap. */
export function windowsOverlap(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date): boolean {
  return aStart < bEnd && aEnd > bStart;
}

const NON_BLOCKING_STATUSES = new Set(["cancelled", "deleted"]);

/**
 * The one scheduling invariant: a teacher can never hold two overlapping
 * shifts. Returns the first conflicting shift, or null. Cancelled shifts
 * never block (a cancelled class frees its slot).
 */
export async function findTeacherConflict(
  teacherId: string,
  start: Date,
  end: Date,
  exclude?: string | Set<string>,
): Promise<ShiftDoc | null> {
  const excluded = typeof exclude === "string" ? new Set([exclude]) : (exclude ?? new Set<string>());
  const rangeStart = new Date(start.getTime() - 24 * 3600e3);
  const rangeEnd = new Date(start.getTime() + 48 * 3600e3);
  const snap = await getDocs(
    query(
      collection(db, "teaching_shifts"),
      where("teacher_id", "==", teacherId),
      where("shift_start", ">=", Timestamp.fromDate(rangeStart)),
      where("shift_start", "<", Timestamp.fromDate(rangeEnd)),
    ),
  );
  for (const docSnap of snap.docs) {
    if (excluded.has(docSnap.id)) continue;
    const shift = normalizeShift(docSnap.id, docSnap.data() as Record<string, unknown>);
    if (!shift) continue;
    if (NON_BLOCKING_STATUSES.has(shift.status.toLowerCase())) continue;
    if (windowsOverlap(start, end, shift.start, shift.end)) return shift;
  }
  return null;
}

/** Zoom teaching classes are capped at 3 hours; every window must be sane. */
export function shiftWindowError(start: Date, end: Date, category: ShiftCategory, hasStudents: boolean): string | null {
  if (end <= start) return "End time must be after start time.";
  const minutes = Math.round((end.getTime() - start.getTime()) / 60000);
  if (category === "teaching" && hasStudents && minutes > ZOOM_MAX_CLASS_MINUTES) {
    return `Zoom classes must be 3 hours or shorter (this one is ${Math.round(minutes / 60)}h ${minutes % 60}m). Split it into shorter classes.`;
  }
  if (minutes > 12 * 60) {
    return `That window is ${Math.round(minutes / 60)} hours long — check that the end date matches the start date.`;
  }
  return null;
}

/**
 * For a weekly series with chosen weekdays, move the base shift forward to the
 * first date matching a selected weekday (Flutter parity). ISO weekdays are
 * 1=Mon … 7=Sun; that is how the create dialog and the template store them.
 */
function snapToFirstWeekday(input: CreateShiftInput): { start: Date; end: Date } {
  if (input.recurrenceType !== "weekly" || input.weeklyDays.length === 0) {
    return { start: input.start, end: input.end };
  }
  const durationMs = input.end.getTime() - input.start.getTime();
  const isoWeekday = (d: Date) => ((d.getDay() + 6) % 7) + 1; // Sun(0)->7, Mon(1)->1
  for (let offset = 0; offset < 7; offset++) {
    const candidate = new Date(input.start.getTime() + offset * 24 * 3600e3);
    if (input.weeklyDays.includes(isoWeekday(candidate))) {
      return { start: candidate, end: new Date(candidate.getTime() + durationMs) };
    }
  }
  return { start: input.start, end: input.end };
}

/** Teacher - Subject - Student names, the same shape the Flutter app writes. */
export function autoShiftName(teacherName: string, subjectDisplayName: string, studentNames: string[]): string {
  const base = `${teacherName} - ${subjectDisplayName || "Class"}`;
  if (studentNames.length === 0) return base;
  if (studentNames.length <= 3) return `${base} - ${studentNames.join(", ")}`;
  return `${base} - ${studentNames.slice(0, 2).join(", ")} +${studentNames.length - 2} more`;
}

/* --------------------------------- queries -------------------------------- */

export type ShiftCounts = { all: number; today: number; upcoming: number; active: number };

/**
 * The stat chips and tab badges count the FULL shift history, exactly like
 * the Flutter screen: Total = every shift ever, Today = starts today,
 * Upcoming = future shifts still scheduled, Active = running right now.
 * Server-side count() aggregation — the grid itself stays week-windowed.
 */
export async function loadShiftCounts(): Promise<ShiftCounts> {
  const coll = collection(db, "teaching_shifts");
  const now = new Date();
  const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const dayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  const [all, today, upcoming, active] = await Promise.all([
    getCountFromServer(coll),
    getCountFromServer(query(
      coll,
      where("shift_start", ">=", Timestamp.fromDate(dayStart)),
      where("shift_start", "<", Timestamp.fromDate(dayEnd)),
    )),
    getCountFromServer(query(
      coll,
      where("status", "==", "scheduled"),
      where("shift_start", ">", Timestamp.fromDate(now)),
    )),
    getCountFromServer(query(coll, where("status", "==", "active"))),
  ]);
  return {
    all: all.data().count,
    today: today.data().count,
    upcoming: upcoming.data().count,
    active: active.data().count,
  };
}

/**
 * Background full-history hydration, mirroring the Flutter screen: after the
 * current week paints, the rest of the collection streams in ordered pages so
 * search/list/tabs cover everything. Reports progress after every page for the
 * "Loading full history" chip. `signal.aborted` stops the walk (unmount).
 */
export async function loadAllShiftsPaged(
  onPage: (batch: ShiftDoc[], loadedSoFar: number) => void,
  signal?: { aborted: boolean },
): Promise<void> {
  const pageSize = 500;
  let cursor: Timestamp | null = null;
  let loaded = 0;
  for (;;) {
    if (signal?.aborted) return;
    const constraints = [
      orderBy("shift_start"),
      ...(cursor ? [startAfter(cursor)] : []),
      limit(pageSize),
    ];
    const snap = await getDocs(query(collection(db, "teaching_shifts"), ...constraints));
    if (snap.empty) return;
    const batch = snap.docs
      .map((d) => normalizeShift(d.id, d.data() as Record<string, unknown>))
      .filter((s): s is ShiftDoc => s !== null);
    loaded += snap.docs.length;
    if (!signal?.aborted) onPage(batch, loaded);
    if (snap.docs.length < pageSize) return;
    cursor = snap.docs[snap.docs.length - 1].get("shift_start") as Timestamp;
  }
}

export async function loadWeekShifts(weekStart: Date): Promise<ShiftDoc[]> {
  const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 3600e3);
  const snap = await getDocs(
    query(
      collection(db, "teaching_shifts"),
      where("shift_start", ">=", Timestamp.fromDate(weekStart)),
      where("shift_start", "<", Timestamp.fromDate(weekEnd)),
      orderBy("shift_start"),
    ),
  );
  return snap.docs
    .map((d) => normalizeShift(d.id, d.data() as Record<string, unknown>))
    .filter((s): s is ShiftDoc => s !== null);
}

export async function loadStaff(): Promise<StaffMember[]> {
  const snap = await getDocs(query(collection(db, "users"), where("user_type", "in", ["teacher", "admin", "super_admin"])));
  const members: StaffMember[] = [];
  snap.forEach((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    if (data.is_active === false) return;
    const userType = str(data.user_type).toLowerCase();
    const isAdminTeacher = data.is_admin_teacher === true;
    const group: StaffMember["group"] = userType === "teacher" && !isAdminTeacher ? "teacher" : "leader";
    const first = str(data.first_name);
    const last = str(data.last_name);
    const email = str(data["e-mail"]) || str(data.email);
    const displayName = [first, last].filter(Boolean).join(" ") || email || docSnap.id;
    members.push({
      id: docSnap.id,
      displayName,
      email,
      initials: displayName
        .split(/\s+/)
        .slice(0, 2)
        .map((part) => part[0]?.toUpperCase() ?? "")
        .join(""),
      group,
      timezone: str(data.timezone) || "America/New_York",
    });
  });
  return members.sort((a, b) => a.displayName.localeCompare(b.displayName));
}

export async function loadStudents(): Promise<StudentOption[]> {
  const snap = await getDocs(query(collection(db, "users"), where("user_type", "==", "student")));
  const students: StudentOption[] = [];
  snap.forEach((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    if (data.is_active === false) return;
    const email = str(data["e-mail"]) || str(data.email);
    const displayName = [str(data.first_name), str(data.last_name)].filter(Boolean).join(" ") || email || docSnap.id;
    students.push({
      id: docSnap.id,
      displayName,
      studentCode: str(data.student_code) || str(data.kiosk_code),
      email,
      timezone: str(data.timezone),
    });
  });
  return students.sort((a, b) => a.displayName.localeCompare(b.displayName));
}

export async function loadSubjects(): Promise<SubjectOption[]> {
  const snap = await getDocs(collection(db, "subjects"));
  const subjects: SubjectOption[] = [];
  snap.forEach((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    if (data.isActive === false || data.is_active === false) return;
    const name = str(data.name) || docSnap.id;
    subjects.push({
      id: docSnap.id,
      name,
      displayName: str(data.displayName) || str(data.display_name) || name,
      defaultWage: num(data.defaultWage),
    });
  });
  return subjects.sort((a, b) => a.displayName.localeCompare(b.displayName));
}

/* --------------------------------- writes -------------------------------- */

export type CreateShiftInput = {
  teacher: StaffMember;
  category: ShiftCategory;
  leaderRole: string | null;
  subject: SubjectOption | null;
  students: StudentOption[];
  start: Date;
  end: Date;
  timezone: string;
  hourlyRate: number;
  notes: string;
  customName: string;
  recurrenceType: "none" | "daily" | "weekly" | "monthly" | "yearly";
  /** Weekly recurrence: ISO weekday numbers 1 (Mon) … 7 (Sun). */
  weeklyDays: number[];
  recurrenceEndDate: Date | null;
  admin: User;
  adminName: string;
};

export type SavedShiftOutcome =
  | { kind: "single"; shiftId: string }
  | { kind: "template"; templateId: string }
  | { kind: "multi"; shiftIds: string[] }
  | { kind: "templates"; templateIds: string[] };

/**
 * A weekly series whose days don't share one time (Mon 9–10 PM AND Wed 8–9 PM,
 * every week). A template carries a single start/end, so each distinct time
 * becomes its own weekly template — every one a real repeating series that
 * generates forward exactly like a normal one. All-or-nothing: if a later
 * group fails its guardrails, the earlier ones are torn down completely
 * (instances deleted, template deactivated) so no half-built schedule sticks.
 */
export async function createWeeklySeriesPerDayTimes(
  baseInput: CreateShiftInput,
  groups: Array<{ days: number[]; start: Date; end: Date }>,
  onProgress?: (done: number, total: number) => void,
): Promise<SavedShiftOutcome> {
  const templateIds: string[] = [];
  try {
    for (const group of groups) {
      onProgress?.(templateIds.length, groups.length);
      const outcome = await createShift({
        ...baseInput,
        start: group.start,
        end: group.end,
        recurrenceType: "weekly",
        weeklyDays: group.days,
      });
      if (outcome.kind === "template") templateIds.push(outcome.templateId);
      else if (outcome.kind === "single") templateIds.push(outcome.shiftId);
    }
  } catch (error) {
    for (const templateId of templateIds) {
      await rollbackSeries(templateId).catch(() => {});
    }
    throw error;
  }
  return { kind: "templates", templateIds };
}

/** Remove a just-created series completely (used only for rollback). */
async function rollbackSeries(templateId: string): Promise<void> {
  const snap = await getDocs(
    query(collection(db, "teaching_shifts"), where("template_id", "==", templateId)),
  );
  for (const docSnap of snap.docs) await deleteDoc(docSnap.ref).catch(() => {});
  await deleteDoc(doc(db, "teaching_shifts", templateId)).catch(() => {});
  const call = httpsCallable(functions, "updateShiftTemplate");
  await call({ templateId, is_active: false, deactivated_reason: "create_rolled_back" }).catch(() => {});
}

/**
 * "One time on selected days": independent one-off shifts (e.g. just this
 * Monday and this Wednesday, possibly at different times) — no template, no
 * repetition. All-or-nothing: every window passes the same guardrails as a
 * single create (conflict check, 3h/12h caps); if any creation fails, the
 * ones already created are rolled back so a half-created set never lingers.
 */
export async function createOneTimeShiftsOnDays(
  baseInput: CreateShiftInput,
  occurrences: Array<{ start: Date; end: Date }>,
  onProgress?: (done: number, total: number) => void,
): Promise<SavedShiftOutcome> {
  const created: string[] = [];
  try {
    for (const occurrence of occurrences) {
      onProgress?.(created.length, occurrences.length);
      const outcome = await createShift({
        ...baseInput,
        start: occurrence.start,
        end: occurrence.end,
        recurrenceType: "none",
        weeklyDays: [],
        recurrenceEndDate: null,
      });
      if (outcome.kind === "single") created.push(outcome.shiftId);
    }
  } catch (error) {
    for (const shiftId of created) {
      await deleteDoc(doc(db, "teaching_shifts", shiftId)).catch(() => {});
    }
    throw error;
  }
  return { kind: "multi", shiftIds: created };
}

/**
 * Create a one-off shift, or a weekly repeat pattern (the server then
 * generates the instances and skips any that would conflict).
 */
export async function createShift(input: CreateShiftInput): Promise<SavedShiftOutcome> {
  const hasStudents = input.students.length > 0;

  // For a weekly series, snap the base shift forward to the first selected
  // weekday so the anchor sits on a real occurrence — the Flutter app does
  // the same. One-off and other recurrences keep the chosen date.
  const { start, end } = snapToFirstWeekday(input);

  const windowError = shiftWindowError(start, end, input.category, hasStudents);
  if (windowError) throw new Error(windowError);
  if (input.category === "teaching" && !hasStudents) {
    throw new Error("Pick at least one student for a teaching shift.");
  }

  const conflict = await findTeacherConflict(input.teacher.id, start, end);
  if (conflict) {
    throw new Error(
      `${input.teacher.displayName} already has "${conflict.title}" ` +
        `${formatInZone(conflict.start, input.timezone)} – ` +
        `${formatInZone(conflict.end, input.timezone)}. Pick a non-overlapping time.`,
    );
  }

  const isTeaching = input.category === "teaching";
  const subjectDisplayName = input.subject?.displayName ?? "";
  const autoName = isTeaching
    ? autoShiftName(input.teacher.displayName, subjectDisplayName, input.students.map((s) => s.displayName))
    : `${input.teacher.displayName} - ${input.leaderRole || input.category}`;
  const videoProvider = isTeaching && hasStudents ? "zoom" : "realtimekit";

  // Zoom hub capacity preflight — same callable the Flutter admin uses.
  if (videoProvider === "zoom") {
    try {
      const validate = httpsCallable(functions, "validateZoomShiftCapacity");
      const res = (await validate({
        shiftStart: start.toISOString(),
        shiftEnd: end.toISOString(),
        adminTimezone: input.timezone,
      })) as { data?: { allowed?: boolean; message?: string } };
      if (res.data && res.data.allowed === false) {
        throw new Error(res.data.message || "Zoom capacity is full for that time.");
      }
    } catch (err) {
      // Decide on the ERROR CODE, never on wording. A capacity refusal is
      // thrown as failed-precondition and its message is written by the
      // guardrail ("...unsafe for hub routing"), so keyword matching used to
      // both miss real refusals and mistake a sign-in problem for a full hub.
      const code = String((err as { code?: unknown })?.code ?? "");
      const message = err instanceof Error ? err.message : "";
      if (/failed-precondition|resource-exhausted/.test(code)) {
        // A real guardrail said no — show exactly what it said.
        throw err instanceof Error ? err : new Error(message || "Zoom capacity is full for that time.");
      }
      if (/permission-denied|unauthenticated/.test(code)) {
        throw new Error(
          "Your session is not recognised as an administrator, so the Zoom check could not run. " +
            "Sign out and back in, then try again.",
        );
      }
      // Anything else (offline, unavailable, function missing in dev) must not
      // block scheduling — the server still enforces capacity on write.
    }
  }

  const recurring = input.recurrenceType !== "none";

  // The base shift is always created first — for a one-off it IS the shift,
  // and for a recurring series it anchors the template (its id becomes the
  // template id, exactly as the Flutter app does).
  const docData: Record<string, unknown> = {
    teacher_id: input.teacher.id,
    teacher_name: input.teacher.displayName,
    student_ids: input.students.map((s) => s.id),
    student_names: input.students.map((s) => s.displayName),
    shift_start: Timestamp.fromDate(start),
    shift_end: Timestamp.fromDate(end),
    admin_timezone: input.timezone,
    teacher_timezone: input.teacher.timezone,
    auto_generated_name: autoName,
    custom_name: input.customName || null,
    hourly_rate: input.hourlyRate,
    status: "scheduled",
    shift_category: input.category,
    leader_role: input.leaderRole,
    video_provider: videoProvider,
    recurrence: recurring ? input.recurrenceType : "none",
    notes: input.notes || null,
    is_published: false,
    created_by_admin_id: input.admin.uid,
    created_by_name: input.adminName,
    created_by_email: input.admin.email ?? "",
    created_at: serverTimestamp(),
    last_modified: serverTimestamp(),
  };
  if (isTeaching) {
    docData.subject = input.subject?.name ?? null;
    docData.subject_id = input.subject?.id ?? null;
    docData.subject_display_name = subjectDisplayName || null;
  }

  const ref = await addDoc(collection(db, "teaching_shifts"), docData);
  await scheduleLifecycle(ref.id, input.teacher.id, start, end, input.timezone, input.teacher.timezone);

  if (!recurring) return { kind: "single", shiftId: ref.id };

  // Register the repeat pattern against the base shift; the server
  // generates the future occurrences (skipping the base, which already exists).
  const startHm = wallClock(start, input.timezone);
  const endHm = wallClock(end, input.timezone);
  const durationMinutes = Math.round((end.getTime() - start.getTime()) / 60000);
  const weekdays =
    input.recurrenceType === "weekly"
      ? input.weeklyDays.length > 0
        ? input.weeklyDays
        : [((start.getDay() + 6) % 7) + 1]
      : [];
  const monthDays = input.recurrenceType === "monthly" ? [start.getDate()] : [];
  const months = input.recurrenceType === "yearly" ? [start.getMonth() + 1] : [];
  try {
    const call = httpsCallable(functions, "createShiftTemplate");
    await call({
      base_shift_id: ref.id,
      teacher_id: input.teacher.id,
      teacher_name: input.teacher.displayName,
      student_ids: input.students.map((s) => s.id),
      student_names: input.students.map((s) => s.displayName),
      start_time: startHm,
      end_time: endHm,
      duration_minutes: durationMinutes,
      admin_timezone: input.timezone,
      teacher_timezone: input.teacher.timezone,
      recurrence: input.recurrenceType,
      enhanced_recurrence: {
        type: input.recurrenceType,
        endDate: input.recurrenceEndDate ? input.recurrenceEndDate.toISOString() : null,
        excludedDates: [],
        excludedWeekdays: [],
        selectedWeekdays: weekdays,
        selectedMonthDays: monthDays,
        selectedMonths: months,
        useDifferentTimesPerDay: false,
      },
      recurrence_end_date: input.recurrenceEndDate ? input.recurrenceEndDate.toISOString() : null,
      subject: input.subject?.name ?? null,
      subject_id: input.subject?.id ?? null,
      subject_display_name: subjectDisplayName || null,
      hourly_rate: input.hourlyRate,
      auto_generated_name: autoName,
      custom_name: input.customName || null,
      notes: input.notes || null,
      category: input.category,
      leader_role: input.leaderRole,
      video_provider: videoProvider,
      created_by_admin_id: input.admin.uid,
      created_by_name: input.adminName,
      created_by_email: input.admin.email ?? "",
      base_shift_start: start.toISOString(),
      base_shift_end: end.toISOString(),
      max_days_ahead: 70,
    });
  } catch (err) {
    // If template registration fails, don't leave an orphan base shift.
    try {
      await deleteDoc(doc(db, "teaching_shifts", ref.id));
    } catch {
      /* best effort */
    }
    throw err instanceof Error ? err : new Error("Could not create the recurring series.");
  }
  return { kind: "template", templateId: ref.id };
}

export type EditShiftInput = {
  shift: ShiftDoc;
  newTeacher: StaffMember | null;
  newStart: Date;
  newEnd: Date;
  notes: string;
  /** Teaching-shift content edits; null means "leave unchanged". */
  newStudents: StudentOption[] | null;
  newSubject: SubjectOption | null;
  newHourlyRate: number | null;
  newCustomName: string | null;
};

/** Edit time / teacher / roster / subject / rate with the same guards every other path has. */
export async function updateShiftGuarded(input: EditShiftInput): Promise<void> {
  const { shift } = input;
  const teacherId = input.newTeacher?.id ?? shift.teacherId;
  const teacherName = input.newTeacher?.displayName ?? shift.teacherName;

  const movesTeacherOrTime =
    teacherId !== shift.teacherId ||
    input.newStart.getTime() !== shift.start.getTime() ||
    input.newEnd.getTime() !== shift.end.getTime();

  if (movesTeacherOrTime) {
    const windowError = shiftWindowError(input.newStart, input.newEnd, shift.category, shift.studentIds.length > 0);
    if (windowError) throw new Error(windowError);
    const conflict = await findTeacherConflict(teacherId, input.newStart, input.newEnd, shift.id);
    if (conflict) {
      throw new Error(
        `${teacherName} already has "${conflict.title}" ` +
          `${formatInZone(conflict.start, shift.adminTimezone)} – ` +
          `${formatInZone(conflict.end, shift.adminTimezone)}. Pick a different teacher or time.`,
      );
    }
  }

  const timeChanged =
    input.newStart.getTime() !== shift.start.getTime() || input.newEnd.getTime() !== shift.end.getTime();

  const update: Record<string, unknown> = {
    teacher_id: teacherId,
    teacher_name: teacherName,
    shift_start: Timestamp.fromDate(input.newStart),
    shift_end: Timestamp.fromDate(input.newEnd),
    notes: input.notes || null,
    admin_modified: true,
    admin_modified_at: serverTimestamp(),
    last_modified: serverTimestamp(),
  };
  if (input.newTeacher) {
    update.teacher_timezone = input.newTeacher.timezone;
  }
  if (input.newStudents) {
    update.student_ids = input.newStudents.map((s) => s.id);
    update.student_names = input.newStudents.map((s) => s.displayName);
  }
  if (input.newSubject && shift.category === "teaching") {
    update.subject = input.newSubject.name;
    update.subject_id = input.newSubject.id;
    update.subject_display_name = input.newSubject.displayName;
  }
  if (input.newHourlyRate !== null && Number.isFinite(input.newHourlyRate)) {
    update.hourly_rate = input.newHourlyRate;
  }
  if (input.newCustomName !== null) {
    update.custom_name = input.newCustomName || null;
  }
  // Keep the auto name honest when the people or subject changed.
  if (shift.category === "teaching" && (input.newTeacher || input.newStudents || input.newSubject)) {
    const subjectLabel = input.newSubject?.displayName ?? shift.subjectDisplayName;
    const studentNames = input.newStudents?.map((s) => s.displayName) ?? shift.studentNames;
    update.auto_generated_name = autoShiftName(teacherName, subjectLabel, studentNames);
  }
  await updateDoc(doc(db, "teaching_shifts", shift.id), update);

  // A moved occurrence of a repeat pattern must be excluded from the
  // nightly generator, or it recreates the old slot.
  if (timeChanged && shift.templateId) {
    await excludeTemplateDate(shift.templateId, shift.start, shift.adminTimezone);
  }
  if (movesTeacherOrTime) {
    await scheduleLifecycle(
      shift.id,
      teacherId,
      input.newStart,
      input.newEnd,
      shift.adminTimezone,
      input.newTeacher?.timezone ?? shift.adminTimezone,
    );
  }
}

export async function deleteShiftGuarded(shift: ShiftDoc): Promise<void> {
  // Deleting a generated occurrence without excluding its date lets the
  // nightly generator recreate it.
  if (shift.templateId) {
    await excludeTemplateDate(shift.templateId, shift.start, shift.adminTimezone);
  }
  await deleteDoc(doc(db, "teaching_shifts", shift.id));
}

/**
 * Delete this occurrence and every future one in its series, then deactivate
 * the template so the nightly generator stops producing new occurrences —
 * the same behavior as the Flutter "this and future" delete.
 * Returns how many shifts were removed.
 */
/**
 * A shift may only be removed by a series delete when it has not started yet.
 * The past is a record — a class that already happened (or is happening right
 * now) keeps its attendance and pay history even if it was missed or
 * cancelled. Deleting forward must never reach backwards.
 */
function isDeletableFutureOccurrence(start: Date, status: string, now: Date): boolean {
  if (start <= now) return false; // already started or over
  const s = status.toLowerCase();
  return s === "scheduled" || s === "missed" || s === "cancelled";
}

/**
 * "Delete this & future": stop the series and remove its UPCOMING classes.
 * Anything already started, finished, missed or cancelled stays exactly as it
 * is — including the clicked shift itself when it is in the past.
 */
export async function deleteShiftSeriesForward(
  shift: ShiftDoc,
  onProgress?: (done: number, total: number) => void,
): Promise<number> {
  // The series base shift is the template anchor: its doc id IS the template
  // id and it carries no template_id of its own, so resolve through the
  // helper — otherwise deleting "this & future" from the base would remove
  // one shift and leave the whole series generating.
  const templateId = seriesTemplateId(shift);
  const now = new Date();
  // Read from the clicked shift forward, then keep only what is still upcoming.
  const snap = await getDocs(
    query(
      collection(db, "teaching_shifts"),
      where("template_id", "==", templateId),
      where("shift_start", ">=", Timestamp.fromDate(shift.start)),
    ),
  );
  const doomed = snap.docs.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const start = (data.shift_start as { toDate?: () => Date })?.toDate?.();
    return Boolean(start) && isDeletableFutureOccurrence(start!, String(data.status ?? ""), now);
  });
  let removed = 0;
  for (const docSnap of doomed) {
    onProgress?.(removed, doomed.length);
    await deleteDoc(docSnap.ref);
    removed += 1;
  }
  // The clicked occurrence itself: the base shift (no template_id field) or
  // an occurrence that predates template_id backfills.
  if (
    !snap.docs.some((d) => d.id === shift.id) &&
    isDeletableFutureOccurrence(shift.start, shift.status, now)
  ) {
    await deleteDoc(doc(db, "teaching_shifts", shift.id));
    removed += 1;
  }
  // Stopping generation is the point of the action, even when nothing upcoming
  // was left to delete.
  const call = httpsCallable(functions, "updateShiftTemplate");
  await call({
    templateId,
    is_active: false,
    deactivated_reason: "this_and_future_deleted",
  });
  return removed;
}

/** How many upcoming classes a "this & future" delete would actually remove. */
export async function countDeletableFutureOccurrences(shift: ShiftDoc): Promise<number> {
  const templateId = seriesTemplateId(shift);
  const now = new Date();
  const snap = await getDocs(
    query(
      collection(db, "teaching_shifts"),
      where("template_id", "==", templateId),
      where("shift_start", ">=", Timestamp.fromDate(shift.start)),
    ),
  );
  let count = 0;
  snap.forEach((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const start = (data.shift_start as { toDate?: () => Date })?.toDate?.();
    if (start && isDeletableFutureOccurrence(start, String(data.status ?? ""), now)) count += 1;
  });
  if (!snap.docs.some((d) => d.id === shift.id) && isDeletableFutureOccurrence(shift.start, shift.status, now)) {
    count += 1;
  }
  return count;
}

/** One shift, fresh from the server; null when it no longer exists. */
export async function loadShiftById(shiftId: string): Promise<ShiftDoc | null> {
  const snap = await getDoc(doc(db, "teaching_shifts", shiftId));
  if (!snap.exists()) return null;
  return normalizeShift(snap.id, snap.data() as Record<string, unknown>);
}

/* ------------------------------ series editing ---------------------------- */

/** All scheduled occurrences of a recurring series (grouped by template_id). */
export async function loadSeriesShifts(templateId: string): Promise<ShiftDoc[]> {
  const snap = await getDocs(query(collection(db, "teaching_shifts"), where("template_id", "==", templateId)));
  const shifts = snap.docs
    .map((d) => normalizeShift(d.id, d.data() as Record<string, unknown>))
    .filter((s): s is ShiftDoc => s !== null);
  // The base shift's id equals the template id and may not carry template_id.
  if (!shifts.some((s) => s.id === templateId)) {
    const base = await getDoc(doc(db, "teaching_shifts", templateId));
    if (base.exists()) {
      const b = normalizeShift(base.id, base.data() as Record<string, unknown>);
      if (b) shifts.push(b);
    }
  }
  return shifts.sort((a, b) => a.start.getTime() - b.start.getTime());
}

/** Date-in-zone of `instant`, recombined with a new HH:mm, as a UTC instant. */
function applyTimeInZone(instant: Date, hm: string, zone: string): Date {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? "0");
  const [hh, mm] = hm.split(":").map(Number);
  return zonedTimeToUtc(get("year"), get("month"), get("day"), hh, mm, zone);
}

export type SeriesEditInput = {
  templateId: string;
  seriesShifts: ShiftDoc[];
  /** Which occurrences to apply to (Flutter lets the admin pick a subset). */
  shiftIds: string[];
  timezone: string;
  /** Each field is opt-in: null/false means "leave this alone". */
  changeTime: boolean;
  newStartHm: string; // HH:mm in `timezone`
  newEndHm: string;
  newTeacher: StaffMember | null;
  newStudents: StudentOption[] | null;
  newSubject: SubjectOption | null;
  notes: string | null; // null = leave each shift's notes unchanged
  /** Series mode mirrors changes onto the template; student-scoped bulk edits
   *  span many series, so they only touch the individual shifts. */
  updateTemplate: boolean;
  /** Called as each class is written, so the button can show "3 of 19". */
  onProgress?: (done: number, total: number) => void;
  admin: User;
  adminName: string;
};

/**
 * "Edit every repeat": apply a new start/end time to every scheduled
 * occurrence (keeping each one's own date) and update the template so future
 * generated shifts inherit the new time — the same two-step the Flutter
 * bulk-edit does with updateSeriesTemplate.
 * Returns how many occurrences were updated.
 */
export type SeriesEditResult = {
  updated: number;
  templateUpdated: boolean;
  /** Set when the template was deliberately skipped, with the reason. */
  templateSkippedReason?: string;
};

export async function updateSeriesGuarded(input: SeriesEditInput): Promise<SeriesEditResult> {
  // Only scheduled occurrences the admin actually selected are touched;
  // completed/active shifts keep their recorded data (Flutter parity).
  const chosen = new Set(input.shiftIds);
  const targets = input.seriesShifts.filter(
    (s) => chosen.has(s.id) && s.status.toLowerCase() === "scheduled",
  );
  if (targets.length === 0) throw new Error("Pick at least one scheduled shift to update.");
  const allEditable = input.seriesShifts.filter((s) => s.status.toLowerCase() === "scheduled");
  const isFullSelection = targets.length === allEditable.length;

  const changingSomething =
    input.changeTime ||
    input.newTeacher !== null ||
    input.newStudents !== null ||
    input.newSubject !== null ||
    input.notes !== null;
  if (!changingSomething) throw new Error("Turn on at least one change to apply.");

  let durationMin = 0;
  if (input.changeTime) {
    const [sh, sm] = input.newStartHm.split(":").map(Number);
    const [eh, em] = input.newEndHm.split(":").map(Number);
    durationMin = eh * 60 + em - (sh * 60 + sm);
    if (!Number.isFinite(durationMin) || durationMin <= 0) {
      throw new Error("End time must be after start time.");
    }
    if (durationMin > 12 * 60) {
      throw new Error(`That window is ${Math.round(durationMin / 60)} hours long — check the times.`);
    }
  }

  // Plan every resulting window first, then validate the whole plan BEFORE
  // writing anything, so one conflict aborts the edit instead of leaving the
  // series half-changed.
  const planned = targets.map((shift) => {
    if (!input.changeTime) return { shift, newStart: shift.start, newEnd: shift.end };
    const newStart = applyTimeInZone(shift.start, input.newStartHm, input.timezone);
    return { shift, newStart, newEnd: new Date(newStart.getTime() + durationMin * 60000) };
  });

  const effectiveTeacherId = input.newTeacher?.id ?? input.seriesShifts[0]?.teacherId ?? "";
  const effectiveTeacherName = input.newTeacher?.displayName ?? input.seriesShifts[0]?.teacherName ?? "";
  const seriesIds = new Set(input.seriesShifts.map((s) => s.id));
  const studentsAfter = input.newStudents ?? null;
  const category = input.seriesShifts[0]?.category ?? "teaching";
  const hasStudents =
    studentsAfter !== null ? studentsAfter.length > 0 : (input.seriesShifts[0]?.studentIds.length ?? 0) > 0;

  // Re-validate when the window moved OR the teacher changed (a new teacher
  // must be free at every one of these times).
  const mustRevalidate = input.changeTime || input.newTeacher !== null;
  if (mustRevalidate) {
    for (const { shift, newStart, newEnd } of planned) {
      const windowError = shiftWindowError(newStart, newEnd, category, hasStudents);
      if (windowError) throw new Error(windowError);
      const conflict = await findTeacherConflict(effectiveTeacherId, newStart, newEnd, seriesIds);
      if (conflict) {
        throw new Error(
          `Can't apply: ${effectiveTeacherName} already has "${conflict.title}" ` +
            `${formatInZone(conflict.start, input.timezone)}. Pick a different time or teacher.`,
        );
      }
      void shift;
    }
  }
  if (category === "teaching" && studentsAfter !== null && studentsAfter.length === 0) {
    throw new Error("A teaching shift needs at least one student.");
  }

  const subjectAfter = input.newSubject;
  let updated = 0;
  for (const { shift, newStart, newEnd } of planned) {
    input.onProgress?.(updated, planned.length);
    const patch: Record<string, unknown> = {
      admin_modified: true,
      admin_modified_at: serverTimestamp(),
      last_modified: serverTimestamp(),
    };
    if (input.changeTime) {
      patch.shift_start = Timestamp.fromDate(newStart);
      patch.shift_end = Timestamp.fromDate(newEnd);
      patch.admin_timezone = input.timezone;
    }
    if (input.newTeacher) {
      patch.teacher_id = input.newTeacher.id;
      patch.teacher_name = input.newTeacher.displayName;
      patch.teacher_timezone = input.newTeacher.timezone;
      patch.reassigned_by = input.adminName;
      patch.reassigned_at = serverTimestamp();
    }
    if (studentsAfter) {
      patch.student_ids = studentsAfter.map((s) => s.id);
      patch.student_names = studentsAfter.map((s) => s.displayName);
    }
    if (subjectAfter) {
      patch.subject = subjectAfter.name;
      patch.subject_id = subjectAfter.id;
      patch.subject_display_name = subjectAfter.displayName;
    }
    if (input.notes !== null) patch.notes = input.notes || null;

    // The auto name embeds teacher/subject/students, so recompute it whenever
    // any of those changed — otherwise chips keep showing the old people.
    if (input.newTeacher || studentsAfter || subjectAfter) {
      const teacherName = input.newTeacher?.displayName ?? shift.teacherName;
      const subjectName = subjectAfter?.displayName ?? shift.subjectDisplayName;
      const studentNames = studentsAfter ? studentsAfter.map((s) => s.displayName) : shift.studentNames;
      patch.auto_generated_name =
        shift.category === "teaching"
          ? autoShiftName(teacherName, subjectName, studentNames)
          : `${teacherName} - ${shift.leaderRole || shift.category}`;
    }

    await updateDoc(doc(db, "teaching_shifts", shift.id), patch);
    updated += 1;
  }

  // Mirror the same changes onto the template so future generated shifts
  // inherit them (series mode only).
  // A template write with a NEW TIME makes the server delete and regenerate
  // every future occurrence — which would also overwrite occurrences the admin
  // deliberately left unselected. So when only a subset is chosen and the time
  // is moving, the per-shift edits stand and the template is left alone.
  if (!input.updateTemplate) return { updated, templateUpdated: false };
  if (input.changeTime && !isFullSelection) {
    return {
      updated,
      templateUpdated: false,
      templateSkippedReason:
        "Only the shifts you picked were moved. The repeat pattern kept its old time, so shifts generated later still use it.",
    };
  }
  try {
    const call = httpsCallable(functions, "updateShiftTemplate");
    const templatePatch: Record<string, unknown> = { templateId: input.templateId };
    if (input.changeTime) {
      templatePatch.start_time = input.newStartHm;
      templatePatch.end_time = input.newEndHm;
      templatePatch.duration_minutes = durationMin;
      templatePatch.admin_timezone = input.timezone;
    }
    if (input.newTeacher) {
      templatePatch.teacher_id = input.newTeacher.id;
      templatePatch.teacher_name = input.newTeacher.displayName;
      templatePatch.teacher_timezone = input.newTeacher.timezone;
    }
    if (studentsAfter) {
      templatePatch.student_ids = studentsAfter.map((s) => s.id);
      templatePatch.student_names = studentsAfter.map((s) => s.displayName);
    }
    if (subjectAfter) {
      templatePatch.subject = subjectAfter.name;
      templatePatch.subject_id = subjectAfter.id;
      templatePatch.subject_display_name = subjectAfter.displayName;
    }
    if (input.notes !== null) templatePatch.notes = input.notes || null;
    // Regenerated occurrences take their name from the template, so the
    // template's auto name must move with the teacher/subject/students.
    if (input.newTeacher || studentsAfter || subjectAfter) {
      const first = input.seriesShifts[0];
      const teacherName = input.newTeacher?.displayName ?? first?.teacherName ?? "";
      const subjectName = subjectAfter?.displayName ?? first?.subjectDisplayName ?? "";
      const studentNames = studentsAfter ? studentsAfter.map((s) => s.displayName) : (first?.studentNames ?? []);
      templatePatch.auto_generated_name =
        category === "teaching"
          ? autoShiftName(teacherName, subjectName, studentNames)
          : `${teacherName} - ${first?.leaderRole || category}`;
    }
    await call(templatePatch);
  } catch (err) {
    throw new Error(
      `Occurrences were updated, but the template did not — future shifts may keep the old details. ${
        err instanceof Error ? err.message : ""
      }`,
    );
  }
  return { updated, templateUpdated: true };
}

/**
 * Every upcoming shift a student is enrolled in — the source list for the
 * Flutter "Edit all shifts for a student" bulk mode. Past shifts are excluded
 * because they are settled history.
 */
export async function loadShiftsForStudent(studentId: string): Promise<ShiftDoc[]> {
  const snap = await getDocs(
    query(
      collection(db, "teaching_shifts"),
      where("student_ids", "array-contains", studentId),
      where("shift_start", ">=", Timestamp.fromDate(new Date())),
    ),
  );
  return snap.docs
    .map((d) => normalizeShift(d.id, d.data() as Record<string, unknown>))
    .filter((s): s is ShiftDoc => s !== null)
    .sort((a, b) => a.start.getTime() - b.start.getTime());
}

/**
 * A student's upcoming shifts whose wall-clock start falls inside a
 * time-of-day window ("every class this student has between 4 and 6 PM"),
 * matching Flutter's getStudentShiftsByTimeRange.
 */
export async function loadStudentShiftsByTimeRange(
  studentId: string,
  startHm: string,
  endHm: string,
): Promise<ShiftDoc[]> {
  const [sh, sm] = startHm.split(":").map(Number);
  const [eh, em] = endHm.split(":").map(Number);
  const fromMinutes = sh * 60 + sm;
  const toMinutes = eh * 60 + em;
  const all = await loadShiftsForStudent(studentId);
  return all.filter((shift) => {
    const hm = new Intl.DateTimeFormat("en-GB", {
      timeZone: safeTimezone(shift.adminTimezone),
      hour12: false,
      hour: "2-digit",
      minute: "2-digit",
    }).format(shift.start);
    const [h, m] = hm.split(":").map(Number);
    const minutes = h * 60 + m;
    return minutes >= fromMinutes && minutes <= toMinutes;
  });
}

export type ShiftTimesheetSummary = {
  id: string;
  status: string;
  totalHours: string;
  pay: number;
  clockIn: Date | null;
  clockOut: Date | null;
};

/** Timesheet entries recorded against one shift, for the details view. */
export async function loadShiftTimesheets(shiftId: string): Promise<ShiftTimesheetSummary[]> {
  const snap = await getDocs(query(collection(db, "timesheet_entries"), where("shift_id", "==", shiftId)));
  return snap.docs.map((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    return {
      id: docSnap.id,
      status: str(data.status) || "pending",
      totalHours: str(data.total_hours) || "00:00",
      pay: num(data.total_pay) ?? num(data.payment_amount) ?? 0,
      clockIn: toDate(data.clock_in_timestamp),
      clockOut: toDate(data.clock_out_timestamp),
    };
  });
}

/* -------------------------------- callables ------------------------------- */

async function scheduleLifecycle(
  shiftId: string,
  teacherId: string,
  start: Date,
  end: Date,
  adminTimezone: string,
  teacherTimezone: string,
): Promise<void> {
  try {
    const call = httpsCallable(functions, "scheduleShiftLifecycle");
    await call({
      shiftId,
      teacherId,
      shiftStart: start.toISOString(),
      shiftEnd: end.toISOString(),
      status: "scheduled",
      cancel: false,
      adminTimezone,
      teacherTimezone,
    });
  } catch {
    // Lifecycle scheduling is best-effort here (same as Flutter's quick edit):
    // the nightly sweepers reconcile shifts whose tasks were not scheduled.
  }
}

async function excludeTemplateDate(templateId: string, occurrenceStart: Date, adminTimezone: string): Promise<void> {
  try {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: adminTimezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(occurrenceStart);
    const call = httpsCallable(functions, "excludeShiftTemplateDate");
    await call({ templateId, date: parts, admin_timezone: adminTimezone });
  } catch (err) {
    throw new Error(
      "Could not exclude this date from the recurring series — the change was not fully applied. " +
        (err instanceof Error ? err.message : ""),
    );
  }
}

/** Wall-clock HH:mm of a UTC instant in a zone (for template payloads). */
function wallClock(date: Date, zone: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: zone,
    hour12: false,
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

/* --------------------------------- lookups -------------------------------- */

export async function loadAdminProfile(user: User): Promise<{ name: string; timezone: string }> {
  try {
    const snap = await getDoc(doc(db, "users", user.uid));
    if (snap.exists()) {
      const data = snap.data() as Record<string, unknown>;
      const name = [str(data.first_name), str(data.last_name)].filter(Boolean).join(" ");
      return {
        name: name || user.displayName || user.email || "Admin",
        timezone: str(data.timezone) || "America/New_York",
      };
    }
  } catch {
    /* fall through to defaults */
  }
  return { name: user.displayName || user.email || "Admin", timezone: "America/New_York" };
}
