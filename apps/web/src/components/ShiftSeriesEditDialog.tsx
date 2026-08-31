"use client";

import { useEffect, useMemo, useState } from "react";
import type { User } from "firebase/auth";
import { ChevronDown, RefreshCcw, X } from "lucide-react";
import { ActionButton, type ProgressReporter } from "@/components/ActionButton";
import { PersonPickerField, PersonSelectDialog, type PersonOption } from "@/components/PersonSelect";
import { TimezoneSelectorDialog } from "@/components/TimezoneSelectorDialog";
import { formatTimezoneForDisplay } from "@/lib/timezones";
import { loadTemplate, updateTemplateDays } from "@/lib/templates";
import {
  type ShiftDoc,
  type StaffMember,
  type StudentOption,
  type SubjectOption,
  formatInZone,
  updateSeriesGuarded,
} from "@/lib/shifts";

/**
 * "Edit every repeat" — a port of the Flutter BulkEditShiftDialog: pick which
 * occurrences to touch, then switch on only the fields you want to change
 * (time+timezone, teacher, students, subject, notes). Everything left off is
 * untouched. Completed/active occurrences are never modified, and the whole
 * edit is validated before a single write lands.
 */

type Props = {
  shift: ShiftDoc;
  seriesShifts: ShiftDoc[];
  staff: StaffMember[];
  students: StudentOption[];
  subjects: SubjectOption[];
  admin: User;
  adminName: string;
  /** false for student-scoped bulk edits (they span several series). */
  updateTemplate?: boolean;
  /** Heading shown instead of "Edit every repeat". */
  heading?: string;
  onClose: () => void;
  onSaved: (message: string) => void;
};

const WEEKDAY_CHIPS: { iso: number; label: string }[] = [
  { iso: 1, label: "Mon" },
  { iso: 2, label: "Tue" },
  { iso: 3, label: "Wed" },
  { iso: 4, label: "Thu" },
  { iso: 5, label: "Fri" },
  { iso: 6, label: "Sat" },
  { iso: 7, label: "Sun" },
];

function timeInputValue(date: Date, zone: string): string {
  return new Intl.DateTimeFormat("en-GB", { timeZone: zone, hour12: false, hour: "2-digit", minute: "2-digit" }).format(
    date,
  );
}

export function ShiftSeriesEditDialog({
  shift,
  seriesShifts,
  staff,
  students,
  subjects,
  admin,
  adminName,
  updateTemplate = true,
  heading,
  onClose,
  onSaved,
}: Props) {
  const zone = shift.adminTimezone;

  // Only scheduled occurrences can be changed; the rest are shown as locked
  // so the admin can see why the count differs.
  const editable = useMemo(
    () =>
      [...seriesShifts]
        .filter((s) => s.status.toLowerCase() === "scheduled")
        .sort((a, b) => a.start.getTime() - b.start.getTime()),
    [seriesShifts],
  );
  const lockedCount = seriesShifts.length - editable.length;

  const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set(editable.map((s) => s.id)));

  const [changeTime, setChangeTime] = useState(false);
  const [timezone, setTimezone] = useState(zone);
  const [zonePickerOpen, setZonePickerOpen] = useState(false);
  const [teacherPickerOpen, setTeacherPickerOpen] = useState(false);
  const [studentPickerOpen, setStudentPickerOpen] = useState(false);
  const [startStr, setStartStr] = useState(() => timeInputValue(shift.start, zone));
  const [endStr, setEndStr] = useState(() => timeInputValue(shift.end, zone));

  const [changeTeacher, setChangeTeacher] = useState(false);
  const [teacherId, setTeacherId] = useState(shift.teacherId);

  const [changeStudents, setChangeStudents] = useState(false);
  const [studentIds, setStudentIds] = useState<string[]>(shift.studentIds);

  const [changeSubject, setChangeSubject] = useState(false);
  const [subjectId, setSubjectId] = useState(shift.subjectId ?? "");

  // Which weekdays the series repeats on — the pattern itself. Lives here so
  // one dialog covers everything about a repeating class.
  const [changeDays, setChangeDays] = useState(false);
  const [weekdays, setWeekdays] = useState<number[] | null>(null);
  const [originalWeekdays, setOriginalWeekdays] = useState<number[]>([]);

  const [changeNotes, setChangeNotes] = useState(false);
  const [notes, setNotes] = useState(shift.notes);

  useEffect(() => {
    if (!updateTemplate || !shift.templateId) return;
    let alive = true;
    loadTemplate(shift.templateId)
      .then((tpl) => {
        if (!alive || !tpl) return;
        setWeekdays(tpl.weekdays);
        setOriginalWeekdays(tpl.weekdays);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [shift.templateId, updateTemplate]);

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const staffOptions: PersonOption[] = useMemo(
    () => staff.map((m) => ({ id: m.id, name: m.displayName, email: m.email })),
    [staff],
  );
  const studentOptions: PersonOption[] = useMemo(
    () => students.map((s) => ({ id: s.id, name: s.displayName, email: s.email, code: s.studentCode, isStudent: true })),
    [students],
  );

  const mixedTimezones = useMemo(
    () => new Set(editable.filter((s) => selectedIds.has(s.id)).map((s) => s.adminTimezone)).size > 1,
    [editable, selectedIds],
  );

  const changeCount = [changeTime, changeDays, changeTeacher, changeStudents, changeSubject, changeNotes].filter(Boolean).length;

  const submit = async (report?: ProgressReporter) => {
    setError("");
    if (selectedIds.size === 0) {
      setError("Pick at least one shift to update.");
      return;
    }
    if (changeCount === 0) {
      setError("Turn on at least one change to apply.");
      return;
    }
    const onlyDays = changeDays && !changeTime && !changeTeacher && !changeStudents && !changeSubject && !changeNotes;
    const newTeacher = changeTeacher ? (staff.find((m) => m.id === teacherId) ?? null) : null;
    if (changeTeacher && !newTeacher) {
      setError("Pick a teacher.");
      return;
    }
    const newSubject = changeSubject ? (subjects.find((s) => s.id === subjectId) ?? null) : null;
    if (changeSubject && !newSubject) {
      setError("Pick a subject.");
      return;
    }
    setSaving(true);
    try {
      if (changeDays && weekdays && shift.templateId) {
        if (weekdays.length === 0) {
          setError("Pick at least one day.");
          setSaving(false);
          return;
        }
        await updateTemplateDays(shift.templateId, weekdays, changeTime ? startStr : undefined, changeTime ? endStr : undefined);
      }
      // A pure pattern change is done by the template write above — the
      // occurrence pass would have nothing to apply and would reject.
      if (onlyDays) {
        onSaved("Days updated — upcoming classes rebuilt on the new pattern.");
        return;
      }
      const result = await updateSeriesGuarded({
        onProgress: report,
        templateId: shift.templateId ?? shift.id,
        seriesShifts,
        shiftIds: [...selectedIds],
        timezone,
        changeTime,
        newStartHm: startStr,
        newEndHm: endStr,
        newTeacher,
        newStudents: changeStudents ? students.filter((s) => studentIds.includes(s.id)) : null,
        newSubject,
        notes: changeNotes ? notes : null,
        updateTemplate,
        admin,
        adminName,
      });
      const n = result.updated;
      const base = `Updated ${n} shift${n === 1 ? "" : "s"}`;
      onSaved(
        result.templateUpdated
          ? `${base} and the repeat pattern.`
          : result.templateSkippedReason
            ? `${base}. ${result.templateSkippedReason}`
            : `${base}.`,
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not update the series.");
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[60] grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex max-h-[92vh] w-full max-w-2xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EAF5FF] text-[#0386FF]">
            <RefreshCcw size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#0F172A]">{heading ?? "Edit every repeat"}</h2>
            <p className="truncate text-xs text-[#64748B]">{shift.title}</p>
          </div>
          <button type="button" onClick={onClose} className="grid h-8 w-8 place-items-center rounded-full text-[#334155] hover:bg-[#F1F5F9]" aria-label="Close">
            <X size={18} />
          </button>
        </header>

        <div className="min-h-0 flex-1 space-y-4 overflow-y-auto px-6 py-5">
          {/* Which occurrences */}
          <section className="rounded-xl border border-[#E2E8F0]">
            <div className="flex items-center gap-3 border-b border-[#E2E8F0] px-3.5 py-2.5">
              <label className="flex items-center gap-2 text-sm font-bold text-[#111827]">
                <input
                  type="checkbox"
                  checked={selectedIds.size === editable.length && editable.length > 0}
                  onChange={(event) =>
                    setSelectedIds(event.target.checked ? new Set(editable.map((s) => s.id)) : new Set())
                  }
                />
                Shifts to update
              </label>
              <span className="ml-auto text-xs font-semibold text-[#0386FF]">{selectedIds.size} selected</span>
            </div>
            <div className="max-h-44 overflow-y-auto px-1.5 py-1.5">
              {editable.map((occurrence) => (
                <label
                  key={occurrence.id}
                  className="flex cursor-pointer items-center gap-2.5 rounded-lg px-2 py-1.5 text-sm hover:bg-[#F8FAFC]"
                >
                  <input
                    type="checkbox"
                    checked={selectedIds.has(occurrence.id)}
                    onChange={(event) =>
                      setSelectedIds((prev) => {
                        const next = new Set(prev);
                        if (event.target.checked) next.add(occurrence.id);
                        else next.delete(occurrence.id);
                        return next;
                      })
                    }
                  />
                  <span className="text-[#334155]">{formatInZone(occurrence.start, timezone)}</span>
                </label>
              ))}
              {editable.length === 0 ? (
                <p className="px-2 py-3 text-sm text-[#64748B]">No scheduled occurrences left to edit.</p>
              ) : null}
            </div>
            {lockedCount > 0 ? (
              <p className="border-t border-[#E2E8F0] px-3.5 py-2 text-xs text-[#64748B]">
                {lockedCount} completed or active shift{lockedCount === 1 ? " is" : "s are"} not editable — their
                recorded times stay as they are.
              </p>
            ) : null}
          </section>

          <p className="text-sm font-bold text-[#111827]">Changes to apply</p>

          {/* Time */}
          <ToggleSection
            title="Shift time"
            subtitle="Set a new start and end time"
            on={changeTime}
            onToggle={setChangeTime}
          >
            {mixedTimezones ? (
              <p className="mb-2 rounded-lg border border-[#FDE68A] bg-[#FFFBEB] px-3 py-2 text-xs font-semibold text-[#92400E]">
                The selected shifts use different timezones — they will all be set using the timezone below.
              </p>
            ) : null}
            <button
              type="button"
              onClick={() => setZonePickerOpen(true)}
              className="mb-3 flex w-full items-center gap-2 rounded-xl border border-[#D1D5DB] px-3 py-2 text-left text-sm"
            >
              <span className="min-w-0 flex-1 truncate text-[#111827]">{formatTimezoneForDisplay(timezone)}</span>
              <ChevronDown size={16} className="shrink-0 text-[#6B7280]" />
            </button>
            <div className="grid grid-cols-2 gap-3">
              <label className="text-xs font-bold uppercase tracking-wide text-[#64748B]">
                Start
                <input
                  type="time"
                  value={startStr}
                  onChange={(event) => setStartStr(event.target.value)}
                  className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
                />
              </label>
              <label className="text-xs font-bold uppercase tracking-wide text-[#64748B]">
                End
                <input
                  type="time"
                  value={endStr}
                  onChange={(event) => setEndStr(event.target.value)}
                  className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
                />
              </label>
            </div>
          </ToggleSection>

          {/* Repeats on — only for a real series, and always whole-series */}
          {updateTemplate && weekdays !== null ? (
            <ToggleSection
              title="Repeats on"
              subtitle="Which days of the week this class runs"
              on={changeDays}
              onToggle={setChangeDays}
            >
              <div className="flex flex-wrap items-center gap-2">
                {WEEKDAY_CHIPS.map((day) => {
                  const on = weekdays.includes(day.iso);
                  return (
                    <button
                      key={day.iso}
                      type="button"
                      onClick={() =>
                        setWeekdays((prev) =>
                          (prev ?? []).includes(day.iso)
                            ? (prev ?? []).filter((d) => d !== day.iso)
                            : [...(prev ?? []), day.iso].sort((a, b) => a - b),
                        )
                      }
                      className={`rounded-full px-3 py-1.5 text-xs font-bold ${
                        on ? "bg-[#0386FF] text-white" : "bg-[#F1F5F9] text-[#475569]"
                      }`}
                    >
                      {day.label}
                    </button>
                  );
                })}
              </div>
              <p className="mt-2 text-xs text-[#92400E]">
                Changing the days rebuilds the whole series&apos; upcoming classes — it always applies to every
                occurrence, not just the ones ticked above.
              </p>
            </ToggleSection>
          ) : null}

          {/* Teacher */}
          <ToggleSection
            title="Teacher"
            subtitle="Change the assigned teacher for all selected"
            on={changeTeacher}
            onToggle={setChangeTeacher}
          >
            <PersonPickerField
              value={
                staff.find((m) => m.id === teacherId)
                  ? `${staff.find((m) => m.id === teacherId)!.displayName} · ${staff.find((m) => m.id === teacherId)!.email}`
                  : ""
              }
              placeholder="Select teacher"
              onOpen={() => setTeacherPickerOpen(true)}
            />
          </ToggleSection>

          {/* Students */}
          <ToggleSection
            title="Students"
            subtitle="Replace the student list for all selected"
            on={changeStudents}
            onToggle={setChangeStudents}
          >
            <PersonPickerField
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
          </ToggleSection>

          {/* Subject */}
          <ToggleSection
            title="Subject"
            subtitle="Change the subject for all selected"
            on={changeSubject}
            onToggle={setChangeSubject}
          >
            <select
              value={subjectId}
              onChange={(event) => setSubjectId(event.target.value)}
              className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2.5 text-sm"
            >
              <option value="">Select subject…</option>
              {subjects.map((option) => (
                <option key={option.id} value={option.id}>
                  {option.displayName}
                </option>
              ))}
            </select>
          </ToggleSection>

          {/* Notes */}
          <ToggleSection
            title="Notes"
            subtitle="Set notes for all selected shifts"
            on={changeNotes}
            onToggle={setChangeNotes}
          >
            <textarea
              value={notes}
              onChange={(event) => setNotes(event.target.value)}
              rows={2}
              placeholder="Enter notes"
              className="w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm"
            />
          </ToggleSection>

          <p className="rounded-xl border border-[#FDE68A] bg-[#FFFBEB] px-3.5 py-2.5 text-xs font-semibold text-[#92400E]">
            {!updateTemplate
              ? `This updates ${selectedIds.size} scheduled shift${selectedIds.size === 1 ? "" : "s"}. Recurring templates are not changed, so future generated shifts keep their current details.`
              : changeTime && selectedIds.size !== editable.length
                ? `This updates only the ${selectedIds.size} shift${selectedIds.size === 1 ? "" : "s"} you picked. Because you are moving the time on part of the series, the repeat pattern keeps its old time — shifts generated later will still use it.`
                : `This updates ${selectedIds.size} scheduled shift${selectedIds.size === 1 ? "" : "s"} and the repeat pattern, so future generated shifts use the new details too.`}
          </p>

          {error ? (
            <p className="rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3.5 py-2.5 text-sm font-semibold text-[#B91C1C]">
              {error}
            </p>
          ) : null}
        </div>

        <footer className="flex items-center gap-3 border-t border-[#E2E8F0] px-6 py-4">
          <span className="text-xs text-[#64748B]">
            {changeCount} change{changeCount === 1 ? "" : "s"} selected
          </span>
          <div className="ml-auto flex items-center gap-2">
            <button type="button" onClick={onClose} className="rounded-xl px-4 py-2.5 text-sm font-semibold text-[#64748B]">
              Cancel
            </button>
            <ActionButton
              variant="primary"
              disabled={saving}
              label="Apply to all repeats"
              busyLabel="Updating…"
              onAction={(report) => submit(report)}
            />
          </div>
        </footer>
      </div>

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

      {zonePickerOpen ? (
        <TimezoneSelectorDialog
          initialTimezone={timezone}
          onSelect={(picked) => {
            setTimezone(picked);
            setZonePickerOpen(false);
          }}
          onClose={() => setZonePickerOpen(false)}
        />
      ) : null}
    </div>
  );
}

/** Opt-in section: the body only applies when its switch is on. */
function ToggleSection({
  title,
  subtitle,
  on,
  onToggle,
  children,
}: {
  title: string;
  subtitle: string;
  on: boolean;
  onToggle: (next: boolean) => void;
  children: React.ReactNode;
}) {
  return (
    <section className={`rounded-xl border px-3.5 py-3 ${on ? "border-[#BFDBFE] bg-[#F8FBFF]" : "border-[#E2E8F0]"}`}>
      <label className="flex cursor-pointer items-start gap-3">
        <input type="checkbox" checked={on} onChange={(event) => onToggle(event.target.checked)} className="mt-1" />
        <span className="min-w-0 flex-1">
          <span className="block text-sm font-bold text-[#111827]">{title}</span>
          <span className="block text-xs text-[#64748B]">{subtitle}</span>
        </span>
      </label>
      {on ? <div className="mt-3">{children}</div> : null}
    </section>
  );
}
