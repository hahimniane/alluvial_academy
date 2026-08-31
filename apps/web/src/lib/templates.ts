import { Timestamp, collection, doc, getDocs, query, serverTimestamp, updateDoc, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";
import type { StaffMember } from "@/lib/shifts";

/**
 * Recurring shift templates, ported from the Flutter TemplateManagementDialog
 * + ShiftService template helpers. A template is the rule the nightly
 * generator follows; deactivating one stops future shifts being created
 * without touching the ones already on the calendar.
 */

export type TemplateRecord = {
  id: string;
  teacherId: string;
  teacherName: string;
  studentIds: string[];
  studentNames: string[];
  subjectDisplayName: string;
  startTime: string; // HH:mm
  endTime: string;
  durationMinutes: number;
  /** ISO weekdays (1 = Mon … 7 = Sun) this template generates on. */
  weekdays: number[];
  recurrenceType: string;
  isActive: boolean;
  deactivatedReason: string;
  adminTimezone: string;
  /** Timed pause window (yyyy-mm-dd, admin timezone); "" when not set. */
  pauseStart: string;
  pauseEnd: string;
};

/** yyyy-mm-dd for a Firestore timestamp, read in the given timezone. */
function dayKeyInZone(value: unknown, zone: string): string {
  const date =
    value && typeof value === "object" && "toDate" in (value as Record<string, unknown>)
      ? (value as { toDate: () => Date }).toDate()
      : value instanceof Date
        ? value
        : null;
  if (!date || Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("en-CA", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" }).format(
    date,
  );
}

const str = (v: unknown) => (typeof v === "string" ? v : v == null ? "" : String(v));
const strArr = (v: unknown) => (Array.isArray(v) ? v.map(str).filter(Boolean) : []);

/** enhanced_recurrence.selectedWeekdays, tolerating string/number entries. */
function parseWeekdays(recurrence: unknown): number[] {
  if (!recurrence || typeof recurrence !== "object") return [];
  const raw = (recurrence as Record<string, unknown>).selectedWeekdays;
  if (!Array.isArray(raw)) return [];
  return raw
    .map((v) => (typeof v === "number" ? v : Number(v)))
    .filter((n) => Number.isInteger(n) && n >= 1 && n <= 7)
    .sort((a, b) => a - b);
}

export async function loadTemplates(options: { teacherId?: string | null; activeOnly?: boolean } = {}): Promise<
  TemplateRecord[]
> {
  const { teacherId, activeOnly = false } = options;
  const constraints = [
    ...(teacherId ? [where("teacher_id", "==", teacherId)] : []),
    ...(activeOnly ? [where("is_active", "==", true)] : []),
  ];
  const snap = await getDocs(
    constraints.length ? query(collection(db, "shift_templates"), ...constraints) : collection(db, "shift_templates"),
  );
  const rows: TemplateRecord[] = [];
  snap.forEach((docSnap) => {
    const d = docSnap.data() as Record<string, unknown>;
    rows.push({
      id: docSnap.id,
      teacherId: str(d.teacher_id),
      teacherName: str(d.teacher_name) || "Unassigned",
      studentIds: strArr(d.student_ids),
      studentNames: strArr(d.student_names),
      subjectDisplayName: str(d.subject_display_name) || str(d.subject),
      startTime: str(d.start_time),
      endTime: str(d.end_time),
      durationMinutes: typeof d.duration_minutes === "number" ? d.duration_minutes : 0,
      weekdays: parseWeekdays(d.enhanced_recurrence),
      recurrenceType: str(d.recurrence) || "weekly",
      isActive: d.is_active !== false,
      deactivatedReason: str(d.deactivated_reason),
      adminTimezone: str(d.admin_timezone) || "America/New_York",
      pauseStart: dayKeyInZone(d.pause_start, str(d.admin_timezone) || "America/New_York"),
      pauseEnd: dayKeyInZone(d.pause_end, str(d.admin_timezone) || "America/New_York"),
    });
  });
  return rows.sort(
    (a, b) => a.teacherName.localeCompare(b.teacherName) || a.startTime.localeCompare(b.startTime),
  );
}

/** One template by id — used when editing a series from its shift. */
export async function loadTemplate(templateId: string): Promise<TemplateRecord | null> {
  const all = await loadTemplates();
  return all.find((t) => t.id === templateId) ?? null;
}

const callTemplate = (payload: Record<string, unknown>) =>
  httpsCallable(functions, "updateShiftTemplate")(payload);

/** Stops future generation; shifts already on the calendar stay put. */
export async function deactivateTemplate(templateId: string, reason = "admin_deactivated"): Promise<void> {
  await callTemplate({ templateId, is_active: false, deactivated_reason: reason });
}

export async function reactivateTemplate(templateId: string): Promise<void> {
  await callTemplate({ templateId, is_active: true, deactivated_reason: null });
}

/** Move a whole recurring series to another teacher. */
export async function reassignTemplate(templateId: string, teacher: StaffMember): Promise<void> {
  await callTemplate({
    templateId,
    teacher_id: teacher.id,
    teacher_name: teacher.displayName,
    teacher_timezone: teacher.timezone,
  });
}

/**
 * Change which weekdays a template generates on, and optionally its time.
 * duration_minutes must accompany a time change or the generator rebuilds the
 * occurrences with the wrong length (cross-midnight wraps to the next day).
 */
export async function updateTemplateDays(
  templateId: string,
  weekdays: number[],
  startTime?: string,
  endTime?: string,
): Promise<void> {
  if (weekdays.length === 0) throw new Error("Pick at least one day.");
  const payload: Record<string, unknown> = {
    templateId,
    enhanced_recurrence: { selectedWeekdays: [...weekdays].sort((a, b) => a - b) },
  };
  if (startTime && endTime) {
    const [sh, sm] = startTime.split(":").map(Number);
    const [eh, em] = endTime.split(":").map(Number);
    let duration = eh * 60 + em - (sh * 60 + sm);
    if (duration <= 0) duration += 24 * 60;
    if (duration > 12 * 60) throw new Error("That window is longer than 12 hours — check the times.");
    payload.start_time = startTime;
    payload.end_time = endTime;
    payload.duration_minutes = duration;
  }
  await callTemplate(payload);
}

/**
 * Pause a series for a period. The template stays ACTIVE — the generator skips
 * days inside the window and starts producing again by itself the day after
 * `endDay`, so nobody has to remember to switch it back on. Shifts already on
 * the calendar inside the window are removed when the pause is saved.
 * Dates are yyyy-mm-dd read in the template's own timezone; an empty `endDay`
 * pauses open-endedly until the admin clears it.
 */
export async function pauseTemplateForPeriod(
  templateId: string,
  startDay: string,
  endDay: string,
  timezone: string,
): Promise<void> {
  if (!startDay) throw new Error("Pick the first day of the pause.");
  if (endDay && endDay < startDay) throw new Error("The pause has to end on or after it starts.");
  await callTemplate({
    templateId,
    pause_start: dayStartIso(startDay, timezone),
    pause_end: endDay ? dayStartIso(endDay, timezone) : null,
  });
}

/** Clear a pause so generation resumes right away. */
export async function clearTemplatePause(templateId: string): Promise<void> {
  await callTemplate({ templateId, pause_start: null, pause_end: null });
}

/** Midday UTC-safe instant for a calendar day in `zone` (avoids DST edges). */
function dayStartIso(day: string, zone: string): string {
  const [y, m, d] = day.split("-").map(Number);
  // Noon in the target zone is unambiguous in every timezone/DST combination,
  // and the server compares by calendar day anyway.
  const guess = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
  const seen = new Intl.DateTimeFormat("en-CA", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" }).format(guess);
  if (seen === day) return guess.toISOString();
  // Shift by the difference when noon UTC lands on a neighbouring day.
  const diff = seen < day ? 1 : -1;
  return new Date(guess.getTime() + diff * 24 * 3600e3).toISOString();
}


/* --------------------------- one-off shifts in a pause -------------------- */

export type PausableShift = {
  id: string;
  start: Date;
  title: string;
  status: string;
};

/** Midnight boundaries for a yyyy-mm-dd range, read in `zone`. */
function windowBounds(startDay: string, endDay: string, zone: string): { from: Date; to: Date } {
  const from = new Date(dayStartIso(startDay, zone));
  from.setUTCHours(from.getUTCHours() - 18); // generous lower edge; filtered by day key below
  const to = new Date(dayStartIso(endDay || startDay, zone));
  to.setUTCHours(to.getUTCHours() + 18);
  return { from, to };
}

/**
 * Classes inside a pause window that a template will NOT regenerate — the
 * one-off shifts an admin created by hand. A break means the student has no
 * class at all that period, so these must be paused too; regenerating the
 * template alone would leave them sitting on the calendar.
 */
export async function findOneOffShiftsInPauseWindow(
  teacherId: string,
  studentIds: string[],
  startDay: string,
  endDay: string,
  zone: string,
): Promise<PausableShift[]> {
  if (!teacherId || !startDay) return [];
  const { from, to } = windowBounds(startDay, endDay, zone);
  const snap = await getDocs(
    query(
      collection(db, "teaching_shifts"),
      where("teacher_id", "==", teacherId),
      where("shift_start", ">=", Timestamp.fromDate(from)),
      where("shift_start", "<=", Timestamp.fromDate(to)),
    ),
  );
  const lastDay = endDay || startDay;
  const rows: PausableShift[] = [];
  snap.forEach((docSnap) => {
    const d = docSnap.data() as Record<string, unknown>;
    // Template-generated shifts are handled by regeneration; only hand-made ones here.
    if (str(d.template_id)) return;
    if (str(d.status).toLowerCase() !== "scheduled") return;
    const start = (d.shift_start as { toDate?: () => Date })?.toDate?.();
    if (!start) return;
    // Never reach into the past: a class that already started is a record.
    if (start <= new Date()) return;
    const dayKey = new Intl.DateTimeFormat("en-CA", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" }).format(start);
    if (dayKey < startDay || dayKey > lastDay) return;
    // Only classes this series' students actually attend.
    if (studentIds.length) {
      const ids = strArr(d.student_ids);
      if (!ids.some((id) => studentIds.includes(id))) return;
    }
    rows.push({
      id: docSnap.id,
      start,
      title: str(d.custom_name) || str(d.auto_generated_name) || str(d.subject_display_name) || "Class",
      status: str(d.status),
    });
  });
  return rows.sort((a, b) => a.start.getTime() - b.start.getTime());
}

/**
 * Cancel one-off classes for the pause. Cancelled (not deleted) so the class
 * still shows in history as "off", never counts as missed, is never paid — and
 * can be put back when the pause is lifted.
 */
export async function cancelShiftsForPause(
  shiftIds: string[],
  templateId: string,
  adminName: string,
): Promise<number> {
  let done = 0;
  for (const shiftId of shiftIds) {
    await updateDoc(doc(db, "teaching_shifts", shiftId), {
      status: "cancelled",
      pre_pause_status: "scheduled",
      paused_by_template: templateId,
      paused_at: serverTimestamp(),
      paused_by_name: adminName,
      cancellation_reason: "Paused for a scheduled break",
      last_modified: serverTimestamp(),
    });
    done += 1;
  }
  return done;
}

/** Put back the one-off classes a pause cancelled. */
export async function restoreShiftsFromPause(templateId: string): Promise<number> {
  const snap = await getDocs(
    query(collection(db, "teaching_shifts"), where("paused_by_template", "==", templateId)),
  );
  let restored = 0;
  for (const docSnap of snap.docs) {
    const d = docSnap.data() as Record<string, unknown>;
    if (str(d.status).toLowerCase() !== "cancelled") continue;
    await updateDoc(docSnap.ref, {
      status: str(d.pre_pause_status) || "scheduled",
      paused_by_template: null,
      pre_pause_status: null,
      cancellation_reason: null,
      last_modified: serverTimestamp(),
    });
    restored += 1;
  }
  return restored;
}
