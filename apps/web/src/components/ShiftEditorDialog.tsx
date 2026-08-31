"use client";

import { useEffect, useMemo, useState } from "react";
import type { User } from "firebase/auth";
import { ChevronDown, Clock3, Globe2, MapPin, Settings2, Video, X } from "lucide-react";
import { ActionButton, type ProgressReporter } from "@/components/ActionButton";
import { PersonPickerField, PersonSelectDialog, type PersonOption } from "@/components/PersonSelect";
import { SubjectManagerDialog } from "@/components/SubjectManagerDialog";
import { TimezoneSelectorDialog } from "@/components/TimezoneSelectorDialog";
import { formatTimezoneForDisplay, safeTimezone } from "@/lib/timezones";
import {
  type CreateShiftInput,
  type SavedShiftOutcome,
  createOneTimeShiftsOnDays,
  createWeeklySeriesPerDayTimes,
  type ShiftCategory,
  type ShiftDoc,
  type StaffMember,
  type StudentOption,
  type SubjectOption,
  createShift,
  formatInZone,
  updateShiftGuarded,
  zonedTimeToUtc,
} from "@/lib/shifts";

/** First calendar date (yyyy-mm-dd) on or after `dateStr` that falls on the ISO weekday. */
function firstDateOnOrAfter(dateStr: string, weekdayIso: number): string {
  const [y, m, d] = dateStr.split("-").map(Number);
  const base = new Date(Date.UTC(y, m - 1, d));
  const iso = ((base.getUTCDay() + 6) % 7) + 1;
  const target = new Date(base.getTime() + ((weekdayIso - iso + 7) % 7) * 24 * 3600e3);
  return `${target.getUTCFullYear()}-${String(target.getUTCMonth() + 1).padStart(2, "0")}-${String(target.getUTCDate()).padStart(2, "0")}`;
}

function timezoneAbbrev(date: Date, zone: string): string {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: safeTimezone(zone), timeZoneName: "short" }).formatToParts(date);
  return parts.find((p) => p.type === "timeZoneName")?.value ?? zone;
}

/**
 * Create + edit dialog for the admin schedule. Create supports one-off and
 * weekly recurring shifts; edit mirrors the Flutter quick-edit (move the
 * shift, reassign the teacher, notes) plus delete. Every save goes through
 * the guarded write paths in lib/shifts.ts.
 */

type Props = {
  mode: "create" | "edit";
  shift: ShiftDoc | null;
  prefill: { staffId: string | null; date: Date | null };
  staff: StaffMember[];
  students: StudentOption[];
  subjects: SubjectOption[];
  admin: User;
  adminName: string;
  adminTimezone: string;
  onClose: () => void;
  onSaved: (message: string, outcome?: SavedShiftOutcome) => void;
  /** Reload the subject list after the manager adds/edits/retires one. */
  onSubjectsChanged?: () => void;
};

type RecurrenceType = "none" | "daily" | "weekly" | "monthly" | "yearly";

const WEEKDAYS: { iso: number; label: string }[] = [
  { iso: 1, label: "Mon" },
  { iso: 2, label: "Tue" },
  { iso: 3, label: "Wed" },
  { iso: 4, label: "Thu" },
  { iso: 5, label: "Fri" },
  { iso: 6, label: "Sat" },
  { iso: 7, label: "Sun" },
];

const CATEGORIES: { id: ShiftCategory; label: string }[] = [
  { id: "teaching", label: "Teacher Class" },
  { id: "leadership", label: "Leader Duty" },
  { id: "meeting", label: "Meeting" },
  { id: "training", label: "Training" },
];

function dateInputValue(date: Date, zone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" }).format(
    date,
  );
}

function timeInputValue(date: Date, zone: string): string {
  return new Intl.DateTimeFormat("en-GB", { timeZone: zone, hour12: false, hour: "2-digit", minute: "2-digit" }).format(
    date,
  );
}

function combine(dateStr: string, timeStr: string, zone: string): Date | null {
  const [y, m, d] = dateStr.split("-").map(Number);
  const [hh, mm] = timeStr.split(":").map(Number);
  if (!y || !m || !d || Number.isNaN(hh) || Number.isNaN(mm)) return null;
  return zonedTimeToUtc(y, m, d, hh, mm, zone);
}

export function ShiftEditorDialog({
  mode,
  shift,
  prefill,
  staff,
  students,
  subjects,
  admin,
  adminName,
  adminTimezone,
  onClose,
  onSaved,
  onSubjectsChanged,
}: Props) {
  const isEdit = mode === "edit" && shift !== null;
  const zoneDefault = isEdit ? shift.adminTimezone : adminTimezone;

  const [category, setCategory] = useState<ShiftCategory>(isEdit ? shift.category : "teaching");
  const [timezone, setTimezone] = useState(zoneDefault);
  const [timezonePickerOpen, setTimezonePickerOpen] = useState(false);
  const [subjectManagerOpen, setSubjectManagerOpen] = useState(false);
  const [teacherPickerOpen, setTeacherPickerOpen] = useState(false);
  const [studentPickerOpen, setStudentPickerOpen] = useState(false);
  const [teacherId, setTeacherId] = useState(isEdit ? shift.teacherId : (prefill.staffId ?? ""));
  const [subjectId, setSubjectId] = useState(isEdit ? (shift.subjectId ?? "") : "");
  const [studentIds, setStudentIds] = useState<string[]>(isEdit ? shift.studentIds : []);
  const [leaderRole, setLeaderRole] = useState(isEdit ? (shift.leaderRole ?? "") : "");
  const [dateStr, setDateStr] = useState(() =>
    dateInputValue(isEdit ? shift.start : (prefill.date ?? new Date()), zoneDefault),
  );
  const [startStr, setStartStr] = useState(() => (isEdit ? timeInputValue(shift.start, zoneDefault) : "14:00"));
  const [endStr, setEndStr] = useState(() => (isEdit ? timeInputValue(shift.end, zoneDefault) : "15:00"));
  const [hourlyRate, setHourlyRate] = useState(isEdit ? String(shift.hourlyRate || "") : "");
  const [customName, setCustomName] = useState(isEdit ? shift.customName : "");
  const [useCustomName, setUseCustomName] = useState(isEdit ? Boolean(shift.customName) : false);
  const [notes, setNotes] = useState(isEdit ? shift.notes : "");
  // "onetime" = independent shifts on the selected weekdays of the coming
  // week only (no template); everything else matches the Flutter recurrence.
  const [recurrenceType, setRecurrenceType] = useState<RecurrenceType | "onetime">("none");
  const [weeklyDays, setWeeklyDays] = useState<number[]>([]);
  const [recurrenceEnd, setRecurrenceEnd] = useState("");
  const [useSeparateTimes, setUseSeparateTimes] = useState(false);
  const [perDayTimes, setPerDayTimes] = useState<Record<number, { start: string; end: string }>>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const teacher = useMemo(() => staff.find((member) => member.id === teacherId) ?? null, [staff, teacherId]);
  const subject = useMemo(() => subjects.find((option) => option.id === subjectId) ?? null, [subjects, subjectId]);

  // Live preview of the chosen window in the scheduling zone and the admin's zone.
  const conversionPreview = useMemo(() => {
    const start = combine(dateStr, startStr, timezone);
    let end = combine(dateStr, endStr, timezone);
    if (!start || !end) return null;
    if (end <= start) end = new Date(end.getTime() + 24 * 3600e3);
    return { start, end };
  }, [dateStr, startStr, endStr, timezone]);

  // Prefill the rate from the subject's default wage until the admin types one.
  useEffect(() => {
    if (!isEdit && subject?.defaultWage != null) {
      setHourlyRate((current) => (current === "" || Number(current) === 0 ? String(subject.defaultWage) : current));
    }
  }, [subject, isEdit]);

  const staffOptions: PersonOption[] = useMemo(
    () => staff.map((m) => ({ id: m.id, name: m.displayName, email: m.email })),
    [staff],
  );
  const studentOptions: PersonOption[] = useMemo(
    () => students.map((s) => ({ id: s.id, name: s.displayName, email: s.email, code: s.studentCode, isStudent: true })),
    [students],
  );

  const submit = async (report?: ProgressReporter) => {
    setError("");
    if (!teacher) {
      setError("Pick a teacher.");
      return;
    }
    const start = combine(dateStr, startStr, timezone);
    let end = combine(dateStr, endStr, timezone);
    if (!start || !end) {
      setError("Pick a valid date and time.");
      return;
    }
    if (end <= start) {
      // Cross-midnight classes (e.g. 11:30 PM – 12:30 AM) roll to the next day.
      end = new Date(end.getTime() + 24 * 3600e3);
    }

    setSaving(true);
    try {
      if (isEdit) {
        const pickedStudents = students.filter((option) => studentIds.includes(option.id));
        const studentsChanged =
          pickedStudents.length !== shift.studentIds.length ||
          pickedStudents.some((option) => !shift.studentIds.includes(option.id));
        await updateShiftGuarded({
          shift,
          newTeacher: teacher.id === shift.teacherId ? null : teacher,
          newStart: start,
          newEnd: end,
          notes,
          newStudents: studentsChanged ? pickedStudents : null,
          newSubject: subject && subject.id !== shift.subjectId ? subject : null,
          newHourlyRate: Number(hourlyRate) !== shift.hourlyRate ? Number(hourlyRate) || 0 : null,
          newCustomName: (useCustomName ? customName : "") !== shift.customName ? (useCustomName ? customName : "") : null,
        });
        onSaved("Shift updated.");
      } else if (recurrenceType === "weekly" && useSeparateTimes && weeklyDays.length > 0) {
        // Weekly series where the days don't share one time: one repeating
        // template per distinct time (Mon 9–10 PM every week AND Wed 8–9 PM
        // every week).
        const byTime = new Map<string, { days: number[]; start: string; end: string }>();
        for (const dayIso of [...weeklyDays].sort()) {
          const times = perDayTimes[dayIso] ?? { start: startStr, end: endStr };
          const key = `${times.start}-${times.end}`;
          const group = byTime.get(key);
          if (group) group.days.push(dayIso);
          else byTime.set(key, { days: [dayIso], start: times.start, end: times.end });
        }
        const groups: Array<{ days: number[]; start: Date; end: Date }> = [];
        for (const group of byTime.values()) {
          const groupStart = combine(dateStr, group.start, timezone);
          let groupEnd = combine(dateStr, group.end, timezone);
          if (!groupStart || !groupEnd) {
            setError("Pick a valid time for every selected day.");
            setSaving(false);
            return;
          }
          if (groupEnd <= groupStart) groupEnd = new Date(groupEnd.getTime() + 24 * 3600e3);
          groups.push({ days: group.days, start: groupStart, end: groupEnd });
        }
        const baseInput: CreateShiftInput = {
          teacher,
          category,
          leaderRole: category === "teaching" ? null : leaderRole || category,
          subject: category === "teaching" ? subject : null,
          students: category === "teaching" ? students.filter((option) => studentIds.includes(option.id)) : [],
          start,
          end,
          timezone,
          hourlyRate: Number(hourlyRate) || 0,
          notes,
          customName: useCustomName ? customName : "",
          recurrenceType: "weekly",
          weeklyDays,
          recurrenceEndDate: recurrenceEnd ? new Date(`${recurrenceEnd}T00:00:00Z`) : null,
          admin,
          adminName,
        };
        const outcome = await createWeeklySeriesPerDayTimes(baseInput, groups, report);
        onSaved(
          groups.length === 1
            ? "Repeating class created — it fills in up to 10 weeks ahead."
            : `Created ${groups.length} repeating classes (one per time) — they fill in up to 10 weeks ahead.`,
          outcome,
        );
      } else if (recurrenceType === "onetime") {
        if (weeklyDays.length === 0) {
          setError("Pick at least one day for the one-time shifts.");
          setSaving(false);
          return;
        }
        const baseInput: CreateShiftInput = {
          teacher,
          category,
          leaderRole: category === "teaching" ? null : leaderRole || category,
          subject: category === "teaching" ? subject : null,
          students: category === "teaching" ? students.filter((option) => studentIds.includes(option.id)) : [],
          start,
          end,
          timezone,
          hourlyRate: Number(hourlyRate) || 0,
          notes,
          customName: useCustomName ? customName : "",
          recurrenceType: "none",
          weeklyDays: [],
          recurrenceEndDate: null,
          admin,
          adminName,
        };
        const occurrences: Array<{ start: Date; end: Date }> = [];
        for (const dayIso of [...weeklyDays].sort()) {
          const dayDate = firstDateOnOrAfter(dateStr, dayIso);
          const times = useSeparateTimes ? (perDayTimes[dayIso] ?? { start: startStr, end: endStr }) : { start: startStr, end: endStr };
          const occStart = combine(dayDate, times.start, timezone);
          let occEnd = combine(dayDate, times.end, timezone);
          if (!occStart || !occEnd) {
            setError(`Pick a valid time for ${WEEKDAYS.find((d) => d.iso === dayIso)?.label ?? "each day"}.`);
            setSaving(false);
            return;
          }
          if (occEnd <= occStart) occEnd = new Date(occEnd.getTime() + 24 * 3600e3);
          occurrences.push({ start: occStart, end: occEnd });
        }
        const outcome = await createOneTimeShiftsOnDays(baseInput, occurrences, report);
        onSaved(`Created ${occurrences.length} one-time shift${occurrences.length === 1 ? "" : "s"}.`, outcome);
      } else {
        const input: CreateShiftInput = {
          teacher,
          category,
          leaderRole: category === "teaching" ? null : leaderRole || category,
          subject: category === "teaching" ? subject : null,
          students: category === "teaching" ? students.filter((option) => studentIds.includes(option.id)) : [],
          start,
          end,
          timezone,
          hourlyRate: Number(hourlyRate) || 0,
          notes,
          customName: useCustomName ? customName : "",
          recurrenceType,
          weeklyDays: recurrenceType === "weekly" ? weeklyDays : [],
          recurrenceEndDate: recurrenceEnd ? new Date(`${recurrenceEnd}T00:00:00Z`) : null,
          admin,
          adminName,
        };
        const outcome = await createShift(input);
        onSaved(
          outcome.kind === "template"
            ? "Repeating class created — it fills in up to 10 weeks ahead."
            : "Shift created.",
          outcome,
        );
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save the shift.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex max-h-[92vh] w-full max-w-2xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EAF5FF] text-[#0386FF]">
            <Clock3 size={18} />
          </span>
          <div>
            <h2 className="text-lg font-bold text-[#0F172A]">{isEdit ? "Edit Shift" : "Create New Shift"}</h2>
            <p className="text-xs text-[#94A3B8]">Configure Islamic Education Teaching Schedule</p>
          </div>
          <button type="button" onClick={onClose} className="ml-auto rounded-lg p-1.5 text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 space-y-5 overflow-y-auto px-6 py-5">
          {!isEdit ? (
            <Field label="Type">
              <div className="flex flex-wrap gap-2">
                {CATEGORIES.map((option) => (
                  <button
                    key={option.id}
                    type="button"
                    onClick={() => setCategory(option.id)}
                    className={`rounded-full px-3.5 py-1.5 text-sm font-semibold ${
                      category === option.id ? "bg-[#0386FF] text-white" : "bg-[#F1F5F9] text-[#475569]"
                    }`}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            </Field>
          ) : null}

          <PersonPickerField
            label={category === "teaching" ? "Teacher" : "Staff member"}
            value={teacher ? `${teacher.displayName}${teacher.email ? ` · ${teacher.email}` : ""}` : ""}
            placeholder="Select teacher"
            onOpen={() => setTeacherPickerOpen(true)}
          />

          {category === "teaching" ? (
            <>
              <div>
                <div className="mb-1 flex items-center gap-2">
                  <span className="text-xs font-bold uppercase tracking-wide text-[#64748B]">Subject</span>
                  <button
                    type="button"
                    onClick={() => setSubjectManagerOpen(true)}
                    className="ml-auto inline-flex items-center gap-1 text-xs font-bold text-[#0386FF] hover:underline"
                  >
                    <Settings2 size={12} />
                    Manage Subjects
                  </button>
                </div>
                <select
                  value={subjectId}
                  onChange={(event) => setSubjectId(event.target.value)}
                  className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2.5 text-sm"
                >
                  <option value="">Pick a subject…</option>
                  {subjects.map((option) => (
                    <option key={option.id} value={option.id}>
                      {option.displayName}
                    </option>
                  ))}
                </select>
              </div>
              <PersonPickerField
                label={`Students (${studentIds.length} selected)`}
                value={
                  studentIds.length === 0
                    ? ""
                    : students
                        .filter((s) => studentIds.includes(s.id))
                        .map((s) => `${s.displayName}${s.studentCode ? ` (${s.studentCode})` : ""}`)
                        .join(", ")
                }
                placeholder="Select students"
                onOpen={() => setStudentPickerOpen(true)}
              />
            </>
          ) : null}

          {!isEdit && category !== "teaching" ? (
            <Field label="Role / purpose">
              <input
                value={leaderRole}
                onChange={(event) => setLeaderRole(event.target.value)}
                placeholder="e.g. Supervisor, Staff meeting"
                className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2.5 text-sm"
              />
            </Field>
          ) : null}

          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <Field label="Date">
              <input
                type="date"
                value={dateStr}
                onChange={(event) => setDateStr(event.target.value)}
                className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm"
              />
            </Field>
            <Field label="Start">
              <input
                type="time"
                value={startStr}
                onChange={(event) => setStartStr(event.target.value)}
                className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm"
              />
            </Field>
            <Field label="End">
              <input
                type="time"
                value={endStr}
                onChange={(event) => setEndStr(event.target.value)}
                className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm"
              />
            </Field>
            <Field label="Timezone">
              <button
                type="button"
                onClick={() => setTimezonePickerOpen(true)}
                title="The timezone used for the start and end times"
                className="flex w-full items-center gap-2 rounded-xl border border-[#D1D5DB] bg-white px-3 py-2 text-left text-sm"
              >
                <span className="min-w-0 flex-1 truncate text-[#111827]">{formatTimezoneForDisplay(timezone)}</span>
                <ChevronDown size={16} className="shrink-0 text-[#6B7280]" />
              </button>
            </Field>
          </div>

          {/* Teacher-timezone hint with one-click adopt (Flutter parity) */}
          {teacher?.timezone && teacher.timezone !== timezone ? (
            <div className="flex items-center gap-2 rounded-md border border-[#10B981]/20 bg-[#10B981]/5 px-3 py-2">
              <MapPin size={14} className="shrink-0 text-[#10B981]" />
              <span className="min-w-0 flex-1 truncate text-xs font-semibold text-[#065F46]">
                Teacher timezone: {teacher.timezone}
              </span>
              <button
                type="button"
                onClick={() => setTimezone(teacher.timezone)}
                className="rounded px-2.5 py-1 text-xs font-bold text-[#10B981] hover:bg-[#10B981]/10"
              >
                Use
              </button>
            </div>
          ) : null}

          {teacherPickerOpen ? (
            <PersonSelectDialog
              title="Select Teacher"
              people={staffOptions}
              selectedIds={teacherId ? [teacherId] : []}
              onConfirm={(ids) => {
                setTeacherId(ids[0] ?? "");
                setTeacherPickerOpen(false);
              }}
              onClose={() => setTeacherPickerOpen(false)}
            />
          ) : null}

          {studentPickerOpen ? (
            <PersonSelectDialog
              title="Select Students"
              people={studentOptions}
              selectedIds={studentIds}
              multiSelect
              onConfirm={(ids) => {
                setStudentIds(ids);
                setStudentPickerOpen(false);
              }}
              onClose={() => setStudentPickerOpen(false)}
            />
          ) : null}

          {subjectManagerOpen ? (
            <SubjectManagerDialog
              onClose={() => setSubjectManagerOpen(false)}
              onChanged={() => onSubjectsChanged?.()}
            />
          ) : null}

          {timezonePickerOpen ? (
            <TimezoneSelectorDialog
              initialTimezone={timezone}
              onSelect={(zone) => {
                setTimezone(zone);
                setTimezonePickerOpen(false);
              }}
              onClose={() => setTimezonePickerOpen(false)}
            />
          ) : null}

          {/* Scheduling-in banner + time conversion preview (Flutter parity) */}
          <div className="rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-3.5 py-2.5 text-xs">
            <p className="flex items-center gap-1.5 font-semibold text-[#1D4ED8]">
              <Globe2 size={13} />
              Scheduling in {timezone.replace("_", " ")}
            </p>
            {conversionPreview ? (
              <div className="mt-1.5 space-y-0.5 text-[#334155]">
                <p>
                  <span className="font-semibold">Selected ({timezoneAbbrev(conversionPreview.start, timezone)}):</span>{" "}
                  {formatInZone(conversionPreview.start, timezone)} – {formatInZone(conversionPreview.end, timezone)}
                </p>
                {timezone !== adminTimezone ? (
                  <p className="text-[#0369A1]">
                    <span className="font-semibold">Your time ({timezoneAbbrev(conversionPreview.start, adminTimezone)}):</span>{" "}
                    {formatInZone(conversionPreview.start, adminTimezone)} – {formatInZone(conversionPreview.end, adminTimezone)}
                  </p>
                ) : null}
                {teacher?.timezone && teacher.timezone !== timezone && teacher.timezone !== adminTimezone ? (
                  <p className="font-semibold text-[#7C3AED]">
                    Teacher time ({timezoneAbbrev(conversionPreview.start, teacher.timezone)}):{" "}
                    {formatInZone(conversionPreview.start, teacher.timezone)} – {formatInZone(conversionPreview.end, teacher.timezone)}
                  </p>
                ) : null}
              </div>
            ) : null}
          </div>

          {!isEdit ? (
            <div>
              <p className="mb-2 text-base font-semibold text-[#374151]">Recurrence Settings</p>
              <Field label="Recurrence Type">
                <select
                  value={recurrenceType}
                  onChange={(event) => setRecurrenceType(event.target.value as RecurrenceType | "onetime")}
                  className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2.5 text-sm"
                >
                  <option value="none">No Recurrence</option>
                  <option value="onetime">One Time — Selected Days (no repeat)</option>
                  <option value="daily">Daily</option>
                  <option value="weekly">Weekly</option>
                  <option value="monthly">Monthly</option>
                  <option value="yearly">Yearly</option>
                </select>
              </Field>

              {recurrenceType === "weekly" || recurrenceType === "onetime" ? (
                <div className="mt-4">
                  <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">
                    {recurrenceType === "weekly" ? "Repeats on" : "Create shifts on"}
                  </p>
                  <div className="flex flex-wrap items-center gap-2">
                    {WEEKDAYS.map((day) => {
                      const selected = weeklyDays.includes(day.iso);
                      return (
                        <button
                          key={day.iso}
                          type="button"
                          onClick={() =>
                            setWeeklyDays((current) =>
                              selected ? current.filter((iso) => iso !== day.iso) : [...current, day.iso].sort(),
                            )
                          }
                          className={`rounded-full px-3 py-1.5 text-xs font-bold ${
                            selected ? "bg-[#0386FF] text-white" : "bg-[#F1F5F9] text-[#475569]"
                          }`}
                        >
                          {day.label}
                        </button>
                      );
                    })}
                  </div>
                </div>
              ) : null}

              {(recurrenceType === "onetime" || recurrenceType === "weekly") && weeklyDays.length > 0 ? (
                <div className="mt-4">
                  <p className="mb-2 text-xs text-[#64748B]">
                    {recurrenceType === "onetime"
                      ? `Each selected day becomes its own single shift on its next date on or after ${dateStr || "the chosen date"} — nothing repeats after that.`
                      : "Every selected day repeats weekly. Give days their own times when the schedule differs (for example Monday 9–10 PM and Wednesday 8–9 PM, every week)."}
                  </p>
                  <label className="flex items-center gap-2 text-sm font-semibold text-[#374151]">
                    <input
                      type="checkbox"
                      checked={useSeparateTimes}
                      onChange={(event) => setUseSeparateTimes(event.target.checked)}
                    />
                    Different times per day
                  </label>
                  {useSeparateTimes ? (
                    <div className="mt-3 space-y-2">
                      {[...weeklyDays].sort().map((dayIso) => {
                        const label = WEEKDAYS.find((d) => d.iso === dayIso)?.label ?? String(dayIso);
                        const times = perDayTimes[dayIso] ?? { start: startStr, end: endStr };
                        const setTimes = (patch: Partial<{ start: string; end: string }>) =>
                          setPerDayTimes((prev) => ({ ...prev, [dayIso]: { ...times, ...patch } }));
                        return (
                          <div key={dayIso} className="flex items-center gap-3">
                            <span className="w-10 text-xs font-bold text-[#475569]">{label}</span>
                            <input
                              type="time"
                              value={times.start}
                              onChange={(event) => setTimes({ start: event.target.value })}
                              className="rounded-xl border border-[#E2E8F0] px-3 py-1.5 text-sm"
                            />
                            <span className="text-xs text-[#94A3B8]">to</span>
                            <input
                              type="time"
                              value={times.end}
                              onChange={(event) => setTimes({ end: event.target.value })}
                              className="rounded-xl border border-[#E2E8F0] px-3 py-1.5 text-sm"
                            />
                          </div>
                        );
                      })}
                    </div>
                  ) : null}
                </div>
              ) : null}

              {recurrenceType !== "none" && recurrenceType !== "onetime" ? (
                <div className="mt-4">
                  <Field label="Stop repeating after (optional)">
                    <input
                      type="date"
                      value={recurrenceEnd}
                      onChange={(event) => setRecurrenceEnd(event.target.value)}
                      className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm sm:w-56"
                    />
                  </Field>
                </div>
              ) : null}
            </div>
          ) : null}

          <Field label="Hourly rate ($)">
            <input
              type="number"
              min="0"
              step="0.5"
              value={hourlyRate}
              onChange={(event) => setHourlyRate(event.target.value)}
              className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm sm:w-56"
            />
          </Field>

          {/* Use Custom Shift Name — checkbox reveals the field, like Flutter */}
          <div>
            <label className="flex cursor-pointer items-center gap-2 text-sm font-semibold text-[#374151]">
              <input type="checkbox" checked={useCustomName} onChange={(event) => setUseCustomName(event.target.checked)} />
              Use Custom Shift Name
            </label>
            {useCustomName ? (
              <input
                value={customName}
                onChange={(event) => setCustomName(event.target.value)}
                placeholder="Custom shift name"
                className="mt-2 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm"
              />
            ) : null}
          </div>

          <Field label="Notes (optional)">
            <textarea
              value={notes}
              onChange={(event) => setNotes(event.target.value)}
              rows={2}
              placeholder="Add Any Additional Notes Or Instructions"
              className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm"
            />
          </Field>

          {category === "teaching" ? (
            <div>
              <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">Video Provider</p>
              <div className="flex items-center gap-3 rounded-xl border border-[#E2E8F0] bg-[#F8FAFC] px-3.5 py-3">
                <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-[#E0EDFF] text-[#0386FF]">
                  <Video size={16} />
                </span>
                <div>
                  <p className="text-sm font-semibold text-[#0F172A]">Zoom</p>
                  <p className="text-xs text-[#94A3B8]">Classes with students are routed through the Zoom hub.</p>
                </div>
              </div>
            </div>
          ) : null}

          {error ? (
            <p className="rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3.5 py-2.5 text-sm font-semibold text-[#B91C1C]">
              {error}
            </p>
          ) : null}
        </div>

        <footer className="flex items-center gap-3 border-t border-[#E2E8F0] px-6 py-4">
          <div className="ml-auto flex items-center gap-2">
            <button type="button" onClick={onClose} className="rounded-xl px-4 py-2.5 text-sm font-semibold text-[#64748B]">
              Cancel
            </button>
            <ActionButton
              variant="primary"
              disabled={saving}
              busyLabel={isEdit ? "Saving…" : "Creating…"}
              label={
                isEdit
                  ? "Save changes"
                  : recurrenceType === "onetime" && weeklyDays.length > 0
                    ? `Create ${weeklyDays.length} shift${weeklyDays.length === 1 ? "" : "s"}`
                    : recurrenceType === "weekly" && weeklyDays.length > 0
                      ? "Create repeating class"
                      : "Create shift"
              }
              onAction={(report) => submit(report)}
            />
          </div>
        </footer>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">{label}</p>
      {children}
    </div>
  );
}
