"use client";

import { useState } from "react";

import { CalendarRange, Clock, GraduationCap, User, UserCircle } from "lucide-react";
import { PersonPickerField, PersonSelectDialog, type PersonOption } from "@/components/PersonSelect";
import { SearchableSelect } from "@/components/SearchableSelect";
import type { ShiftDoc, StaffMember, StudentOption, SubjectOption } from "@/lib/shifts";

/**
 * Advanced filter panel, ported field-for-field from the Flutter
 * ShiftFilterPanel: Teacher, Student, Subject, Date Range, Start Time, End
 * Time, plus a status chip row and Clear All / Apply. It filters the loaded
 * week client-side, exactly like the Flutter screen.
 */

export type ShiftFilters = {
  teacherId: string | null;
  studentId: string | null;
  subjectId: string | null;
  dateFrom: string; // yyyy-mm-dd
  dateTo: string;
  timeStart: string; // HH:mm
  timeEnd: string;
  status: string | null;
};

export const EMPTY_FILTERS: ShiftFilters = {
  teacherId: null,
  studentId: null,
  subjectId: null,
  dateFrom: "",
  dateTo: "",
  timeStart: "",
  timeEnd: "",
  status: null,
};

const STATUS_CHIPS: { value: string | null; label: string }[] = [
  { value: null, label: "All" },
  { value: "scheduled", label: "Scheduled" },
  { value: "active", label: "Active" },
  { value: "partiallyCompleted", label: "Partial" },
  { value: "fullyCompleted", label: "Full" },
  { value: "missed", label: "Missed" },
  { value: "cancelled", label: "Cancelled" },
];

export function activeFilterCount(f: ShiftFilters): number {
  let n = 0;
  if (f.teacherId) n++;
  if (f.studentId) n++;
  if (f.subjectId) n++;
  if (f.dateFrom || f.dateTo) n++;
  if (f.timeStart) n++;
  if (f.timeEnd) n++;
  if (f.status) n++;
  return n;
}

/** Apply the filters to a shift list (student match is by name membership). */
export function applyFilters(
  shifts: ShiftDoc[],
  f: ShiftFilters,
  students: StudentOption[],
): ShiftDoc[] {
  const studentName = f.studentId ? students.find((s) => s.id === f.studentId)?.displayName ?? "" : "";
  const minutesOf = (hm: string) => {
    const [h, m] = hm.split(":").map(Number);
    return h * 60 + m;
  };
  return shifts.filter((shift) => {
    if (f.teacherId && shift.teacherId !== f.teacherId) return false;
    if (studentName && !shift.studentNames.includes(studentName)) return false;
    if (f.subjectId && shift.subjectId !== f.subjectId) return false;
    if (f.status && shift.status !== f.status) return false;
    if (f.dateFrom && shift.start < new Date(`${f.dateFrom}T00:00:00`)) return false;
    if (f.dateTo && shift.start > new Date(`${f.dateTo}T23:59:59`)) return false;
    if (f.timeStart || f.timeEnd) {
      const startMin = shift.start.getHours() * 60 + shift.start.getMinutes();
      if (f.timeStart && startMin < minutesOf(f.timeStart)) return false;
      if (f.timeEnd) {
        const endMin = shift.end.getHours() * 60 + shift.end.getMinutes();
        if (endMin > minutesOf(f.timeEnd)) return false;
      }
    }
    return true;
  });
}

export function ShiftFilterPanel({
  filters,
  onChange,
  onClear,
  staff,
  students,
  subjects,
  resultCount,
}: {
  filters: ShiftFilters;
  onChange: (next: ShiftFilters) => void;
  onClear: () => void;
  staff: StaffMember[];
  students: StudentOption[];
  subjects: SubjectOption[];
  resultCount: number;
}) {
  const [pickerFor, setPickerFor] = useState<null | "teacher" | "student">(null);
  const set = <K extends keyof ShiftFilters>(key: K, value: ShiftFilters[K]) => onChange({ ...filters, [key]: value });

  return (
    <div className="border-b border-[#E2E8F0] bg-[#F8FAFC] px-3 py-2.5">
      <p className="text-[13px] font-semibold text-[#111827]">Filters</p>
      <div className="mt-2.5 flex flex-wrap gap-3">
        <FieldShell icon={User} label="Teacher">
          <PersonPickerField
            value={staff.find((m) => m.id === filters.teacherId)?.displayName ?? ""}
            placeholder="All"
            onOpen={() => setPickerFor("teacher")}
          />
        </FieldShell>
        <FieldShell icon={UserCircle} label="Student">
          <PersonPickerField
            value={(() => {
              const s = students.find((x) => x.id === filters.studentId);
              if (!s) return "";
              return `${s.displayName}${s.studentCode ? ` (${s.studentCode})` : ""}`;
            })()}
            placeholder="All"
            onOpen={() => setPickerFor("student")}
          />
        </FieldShell>
        <FieldShell icon={GraduationCap} label="Subject">
          <SearchableSelect
            options={subjects.map((subject) => ({ value: subject.id, label: subject.displayName }))}
            value={filters.subjectId}
            onChange={(v) => set("subjectId", v)}
          />
        </FieldShell>
        <DateField icon={CalendarRange} label="From" value={filters.dateFrom} onChange={(v) => set("dateFrom", v)} />
        <DateField icon={CalendarRange} label="To" value={filters.dateTo} onChange={(v) => set("dateTo", v)} />
        <TimeField icon={Clock} label="Start after" value={filters.timeStart} onChange={(v) => set("timeStart", v)} />
        <TimeField icon={Clock} label="End before" value={filters.timeEnd} onChange={(v) => set("timeEnd", v)} />
      </div>

      <p className="mt-3 text-xs font-semibold text-[#374151]">Status</p>
      <div className="mt-2 flex flex-wrap gap-2">
        {STATUS_CHIPS.map((chip) => {
          const selected = filters.status === chip.value;
          return (
            <button
              key={chip.label}
              type="button"
              onClick={() => set("status", chip.value)}
              className={`rounded-full border px-3 py-1 text-xs font-semibold ${
                selected ? "border-[#0386FF] bg-[#0386FF] text-white" : "border-[#E2E8F0] bg-white text-[#475569]"
              }`}
            >
              {chip.label}
            </button>
          );
        })}
      </div>

      <div className="mt-3.5 flex items-center">
        <button type="button" onClick={onClear} className="text-sm font-semibold text-[#6B7280] hover:text-[#374151]">
          Clear All
        </button>
        <span className="ml-3 rounded-full bg-[#0386FF]/10 px-2.5 py-1 text-xs font-semibold text-[#0386FF]">
          {resultCount} results
        </span>
      </div>
      {pickerFor ? (
        <PersonSelectDialog
          title={pickerFor === "teacher" ? "Select Teacher" : "Select Student"}
          people={
            pickerFor === "teacher"
              ? staff.map((m): PersonOption => ({ id: m.id, name: m.displayName, email: m.email }))
              : students.map((x): PersonOption => ({ id: x.id, name: x.displayName, email: x.email, code: x.studentCode, isStudent: true }))
          }
          selectedIds={
            pickerFor === "teacher" ? (filters.teacherId ? [filters.teacherId] : []) : filters.studentId ? [filters.studentId] : []
          }
          clearLabel={pickerFor === "teacher" ? "All teachers" : "All students"}
          onConfirm={(ids) => {
            set(pickerFor === "teacher" ? "teacherId" : "studentId", ids[0] ?? null);
            setPickerFor(null);
          }}
          onClose={() => setPickerFor(null)}
        />
      ) : null}
    </div>
  );
}

function FieldShell({ icon: Icon, label, children }: { icon: typeof User; label: string; children: React.ReactNode }) {
  return (
    <label className="flex min-w-[150px] flex-col gap-1">
      <span className="flex items-center gap-1 text-[11px] font-semibold uppercase tracking-wide text-[#64748B]">
        <Icon size={12} />
        {label}
      </span>
      {children}
    </label>
  );
}

function DateField({ icon, label, value, onChange }: { icon: typeof User; label: string; value: string; onChange: (v: string) => void }) {
  return (
    <FieldShell icon={icon} label={label}>
      <input type="date" value={value} onChange={(event) => onChange(event.target.value)} className="rounded-lg border border-[#E2E8F0] bg-white px-2.5 py-1.5 text-sm" />
    </FieldShell>
  );
}

function TimeField({ icon, label, value, onChange }: { icon: typeof User; label: string; value: string; onChange: (v: string) => void }) {
  return (
    <FieldShell icon={icon} label={label}>
      <input type="time" value={value} onChange={(event) => onChange(event.target.value)} className="rounded-lg border border-[#E2E8F0] bg-white px-2.5 py-1.5 text-sm" />
    </FieldShell>
  );
}
