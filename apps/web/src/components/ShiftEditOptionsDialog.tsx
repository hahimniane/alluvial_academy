"use client";

import { useEffect, useState } from "react";
import { ChevronRight, Clock, Pencil, Repeat, SlidersHorizontal, UserSearch, X } from "lucide-react";
import { PersonPickerField, PersonSelectDialog, type PersonOption } from "@/components/PersonSelect";
import {
  type ShiftDoc,
  isRecurringShift,
  loadSeriesShifts,
  loadShiftsForStudent,
  loadStudentShiftsByTimeRange,
  seriesTemplateId,
} from "@/lib/shifts";

/**
 * Edit-scope router for a recurring shift, mirroring the Flutter
 * ShiftEditOptionsDialog: pick whether an edit touches just this occurrence or
 * the whole series (which also updates the template), every upcoming class for
 * one student, or a student's classes inside a time-of-day window. The last
 * two span several series, so they never touch templates.
 */

export type EditScope = "single" | "series" | "studentAll" | "studentTimeRange";

export function ShiftEditOptionsDialog({
  shift,
  studentCodeById,
  onPick,
  onClose,
}: {
  shift: ShiftDoc;
  studentCodeById?: Map<string, string>;
  onPick: (scope: EditScope, shifts: ShiftDoc[], heading?: string) => void;
  onClose: () => void;
}) {
  const [series, setSeries] = useState<ShiftDoc[] | null>(null);
  // Student-scoped sub-flows: pick a student on the shift, then (optionally) a
  // time window, then load the matching shifts.
  const [studentFlow, setStudentFlow] = useState<null | "all" | "range">(null);
  const [studentId, setStudentId] = useState("");
  const [rangeStart, setRangeStart] = useState("09:00");
  const [rangeEnd, setRangeEnd] = useState("10:00");
  const [busy, setBusy] = useState(false);
  const [flowError, setFlowError] = useState("");
  const [studentPickerOpen, setStudentPickerOpen] = useState(false);

  const runStudentFlow = async () => {
    if (!studentId) {
      setFlowError("Pick a student.");
      return;
    }
    setBusy(true);
    setFlowError("");
    try {
      const studentName = shift.studentNames[shift.studentIds.indexOf(studentId)] ?? "student";
      const shifts =
        studentFlow === "range"
          ? await loadStudentShiftsByTimeRange(studentId, rangeStart, rangeEnd)
          : await loadShiftsForStudent(studentId);
      const scheduled = shifts.filter((s) => s.status.toLowerCase() === "scheduled");
      if (scheduled.length === 0) {
        setFlowError("No upcoming scheduled shifts matched.");
        setBusy(false);
        return;
      }
      onPick(
        studentFlow === "range" ? "studentTimeRange" : "studentAll",
        scheduled,
        studentFlow === "range"
          ? `Edit ${studentName}'s classes ${rangeStart}–${rangeEnd}`
          : `Edit all classes for ${studentName}`,
      );
    } catch {
      setFlowError("Could not load that student's shifts.");
      setBusy(false);
    }
  };

  useEffect(() => {
    let mounted = true;
    if (!isRecurringShift(shift)) {
      setSeries([shift]);
      return;
    }
    loadSeriesShifts(seriesTemplateId(shift))
      .then((rows) => {
        if (mounted) setSeries(rows.length ? rows : [shift]);
      })
      .catch(() => {
        if (mounted) setSeries([shift]);
      });
    return () => {
      mounted = false;
    };
  }, [shift]);

  const seriesCount = series?.length ?? null;

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="max-h-[90vh] w-full max-w-md overflow-y-auto rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EAF5FF] text-[#0386FF]">
            <SlidersHorizontal size={18} />
          </span>
          <div className="min-w-0">
            <h2 className="text-lg font-bold text-[#0F172A]">Edit Options</h2>
            <p className="truncate text-xs text-[#94A3B8]">{shift.title}</p>
          </div>
          <button type="button" onClick={onClose} className="ml-auto rounded-lg p-1.5 text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </header>

        {studentFlow ? (
          <div className="space-y-3 px-5 py-4">
            <p className="text-sm font-bold text-[#111827]">
              {studentFlow === "range" ? "Which student and time window?" : "Which student?"}
            </p>
            <PersonPickerField
              label="Student"
              value={(() => {
                const i = shift.studentIds.indexOf(studentId);
                if (i < 0) return "";
                const code = studentCodeById?.get(studentId) ?? "";
                return `${shift.studentNames[i] ?? studentId}${code ? ` (${code})` : ""}`;
              })()}
              placeholder="Select student"
              onOpen={() => setStudentPickerOpen(true)}
            />
            {studentFlow === "range" ? (
              <div className="grid grid-cols-2 gap-3">
                <label className="text-xs font-bold uppercase tracking-wide text-[#64748B]">
                  Starts after
                  <input
                    type="time"
                    value={rangeStart}
                    onChange={(event) => setRangeStart(event.target.value)}
                    className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
                  />
                </label>
                <label className="text-xs font-bold uppercase tracking-wide text-[#64748B]">
                  Starts before
                  <input
                    type="time"
                    value={rangeEnd}
                    onChange={(event) => setRangeEnd(event.target.value)}
                    className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
                  />
                </label>
              </div>
            ) : null}
            {flowError ? (
              <p className="rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">
                {flowError}
              </p>
            ) : null}
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => { setStudentFlow(null); setFlowError(""); }}
                className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B]"
              >
                Back
              </button>
              <button
                type="button"
                onClick={() => void runStudentFlow()}
                disabled={busy}
                className="ml-auto rounded-xl bg-[#0386FF] px-5 py-2.5 text-sm font-bold text-white disabled:opacity-60"
              >
                {busy ? "Loading…" : "Continue"}
              </button>
            </div>
          </div>
        ) : (
        <div className="space-y-2 px-4 py-4">
          <OptionCard
            icon={Pencil}
            title="Edit This Shift Only"
            subtitle="Change just this occurrence"
            onClick={() => onPick("single", series ?? [shift])}
          />

          <OptionCard
            icon={Repeat}
            title={seriesCount != null ? `Edit every repeat (${seriesCount})` : "Edit every repeat"}
            subtitle="Apply the new time to every scheduled shift"
            badge="Changes every repeat"
            disabled={seriesCount != null && seriesCount <= 1}
            loading={series === null}
            onClick={() => series && onPick("series", series)}
          />

          <OptionCard
            icon={UserSearch}
            title="Edit All Shifts For A Student"
            subtitle="Bulk edit every upcoming class for one student"
            disabled={shift.studentIds.length === 0}
            onClick={() => {
              setStudentId(shift.studentIds[0] ?? "");
              setStudentFlow("all");
            }}
          />

          <OptionCard
            icon={Clock}
            title="Edit By Time Range"
            subtitle="A student's classes inside a time-of-day window"
            disabled={shift.studentIds.length === 0}
            onClick={() => {
              setStudentId(shift.studentIds[0] ?? "");
              setStudentFlow("range");
            }}
          />
        </div>
        )}

        <footer className="flex justify-end border-t border-[#E2E8F0] px-6 py-3">
          <button type="button" onClick={onClose} className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B]">
            Cancel
          </button>
        </footer>
      </div>

      {studentPickerOpen ? (
        <PersonSelectDialog
          title="Select Student"
          people={shift.studentIds.map((id, index): PersonOption => ({
            id,
            name: shift.studentNames[index] ?? id,
            email: "",
            code: studentCodeById?.get(id) ?? "",
            isStudent: true,
          }))}
          selectedIds={studentId ? [studentId] : []}
          onConfirm={(ids) => {
            setStudentId(ids[0] ?? "");
            setStudentPickerOpen(false);
          }}
          onClose={() => setStudentPickerOpen(false)}
        />
      ) : null}
    </div>
  );
}

function OptionCard({
  icon: Icon,
  title,
  subtitle,
  badge,
  disabled,
  loading,
  onClick,
}: {
  icon: typeof Pencil;
  title: string;
  subtitle: string;
  badge?: string;
  disabled?: boolean;
  loading?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled || loading}
      className={`flex w-full items-center gap-3 rounded-xl border px-3.5 py-3 text-left ${
        disabled || loading
          ? "cursor-not-allowed border-[#EEF2F7] bg-[#F8FAFC] opacity-60"
          : "border-[#E2E8F0] bg-white hover:border-[#0386FF] hover:bg-[#F8FBFF]"
      }`}
    >
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-[#EAF5FF] text-[#0386FF]">
        <Icon size={17} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex items-center gap-2">
          <span className="text-sm font-bold text-[#0F172A]">{title}</span>
          {badge ? (
            <span className="rounded-full bg-[#FEF3C7] px-2 py-0.5 text-[10px] font-bold text-[#B45309]">{badge}</span>
          ) : null}
        </span>
        <span className="block truncate text-xs text-[#64748B]">{loading ? "Loading the other repeats…" : subtitle}</span>
      </span>
      <ChevronRight size={16} className="shrink-0 text-[#CBD5E1]" />
    </button>
  );
}
