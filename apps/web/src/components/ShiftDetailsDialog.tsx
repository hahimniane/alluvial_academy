"use client";

import { useEffect, useState } from "react";
import {
  CalendarClock,
  Clock3,
  DollarSign,
  Globe2,
  Loader2,
  NotebookPen,
  Pencil,
  Trash2,
  UserRound,
  Users,
  X,
} from "lucide-react";
import {
  type ShiftDoc,
  type ShiftTimesheetSummary,
  formatInZone,
  loadShiftTimesheets,
} from "@/lib/shifts";

/**
 * Read-first shift view, modeled on the Flutter ShiftDetailsDialog: status
 * banner, schedule in both timezones, participants, pay, timesheets, and the
 * edit/delete actions. Recurring occurrences offer "just this" vs
 * "this and future" deletion, exactly like the Flutter grid.
 */

const STATUS_STYLE: Record<string, { bg: string; fg: string; label?: string }> = {
  scheduled: { bg: "#DBEAFE", fg: "#1D4ED8" },
  active: { bg: "#FEF3C7", fg: "#B45309" },
  completed: { bg: "#D1FAE5", fg: "#047857" },
  fullycompleted: { bg: "#D1FAE5", fg: "#047857", label: "fully completed" },
  partiallycompleted: { bg: "#FEF3C7", fg: "#B45309", label: "partially completed" },
  missed: { bg: "#FEE2E2", fg: "#B91C1C" },
  cancelled: { bg: "#F3F4F6", fg: "#6B7280" },
};

type Props = {
  shift: ShiftDoc;
  /** studentId -> student code, so names can be disambiguated. */
  studentCodeById?: Map<string, string>;
  onEdit: () => void;
  onRequestDelete: () => void;
  onClose: () => void;
};

export function ShiftDetailsDialog({ shift, studentCodeById, onEdit, onRequestDelete, onClose }: Props) {
  // Past classes are settled history — viewable and deletable, never editable.
  const editable = shift.end.getTime() >= Date.now();
  const [timesheets, setTimesheets] = useState<ShiftTimesheetSummary[] | null>(null);

  useEffect(() => {
    let mounted = true;
    loadShiftTimesheets(shift.id)
      .then((rows) => {
        if (mounted) setTimesheets(rows);
      })
      .catch(() => {
        if (mounted) setTimesheets([]);
      });
    return () => {
      mounted = false;
    };
  }, [shift.id]);

  const statusKey = shift.status.toLowerCase().replace(/[^a-z]/g, "");
  const status = STATUS_STYLE[statusKey] ?? STATUS_STYLE.scheduled;
  const sameZone = shift.adminTimezone === shift.teacherTimezone;

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex max-h-[92vh] w-full max-w-xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EAF5FF] text-[#0386FF]">
            <CalendarClock size={18} />
          </span>
          <div className="min-w-0">
            <h2 className="truncate text-lg font-bold text-[#0F172A]">{shift.title}</h2>
            <span
              className="inline-block rounded-full px-2 py-0.5 text-[11px] font-bold capitalize"
              style={{ backgroundColor: status.bg, color: status.fg }}
            >
              {status.label ?? shift.status}
            </span>
          </div>
          <button type="button" onClick={onClose} className="ml-auto rounded-lg p-1.5 text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 space-y-4 overflow-y-auto px-6 py-5 text-sm text-[#334155]">
          <Row icon={Clock3} label="Schedule">
            <p className="font-semibold">
              {formatInZone(shift.start, shift.adminTimezone)} – {formatInZone(shift.end, shift.adminTimezone)}
            </p>
            <p className="text-xs text-[#94A3B8]">{shift.adminTimezone.replace("_", " ")} (admin)</p>
            {!sameZone ? (
              <p className="mt-1 text-xs text-[#64748B]">
                <Globe2 size={12} className="mr-1 inline" />
                Teacher time: {formatInZone(shift.start, shift.teacherTimezone)} –{" "}
                {formatInZone(shift.end, shift.teacherTimezone)} ({shift.teacherTimezone.replace("_", " ")})
              </p>
            ) : null}
          </Row>

          <Row icon={UserRound} label="Teacher">
            <p className="font-semibold">{shift.teacherName}</p>
          </Row>

          {shift.category === "teaching" ? (
            <Row icon={Users} label={`Students (${shift.studentNames.length})`}>
              {shift.studentNames.length === 0 ? (
                <p>No students assigned</p>
              ) : (
                <ul className="space-y-0.5">
                  {shift.studentNames.map((name, index) => {
                    // Names repeat across families, so always pair one with its id.
                    const code = studentCodeById?.get(shift.studentIds[index] ?? "") ?? "";
                    return (
                      <li key={`${name}-${index}`}>
                        {name}
                        {code ? <span className="text-[#94A3B8]"> · ID: {code}</span> : null}
                      </li>
                    );
                  })}
                </ul>
              )}
              <p className="mt-0.5 text-xs text-[#94A3B8]">{shift.subjectDisplayName || shift.subject}</p>
            </Row>
          ) : (
            <Row icon={Users} label="Type">
              <p className="capitalize">{shift.leaderRole || shift.category}</p>
            </Row>
          )}

          <Row icon={DollarSign} label="Hourly rate">
            <p className="font-semibold">${shift.hourlyRate.toFixed(2)}</p>
          </Row>

          {shift.notes ? (
            <Row icon={NotebookPen} label="Notes">
              <p className="whitespace-pre-wrap">{shift.notes}</p>
            </Row>
          ) : null}

          <div>
            <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">Timesheets</p>
            {timesheets === null ? (
              <p className="flex items-center gap-2 text-xs text-[#94A3B8]">
                <Loader2 size={13} className="animate-spin" /> Loading…
              </p>
            ) : timesheets.length === 0 ? (
              <p className="text-xs text-[#94A3B8]">No timesheet entries yet.</p>
            ) : (
              <ul className="space-y-1">
                {timesheets.map((entry) => (
                  <li key={entry.id} className="flex items-center gap-2 rounded-lg bg-[#F8FAFC] px-3 py-2 text-xs">
                    <span className="font-semibold capitalize">{entry.status}</span>
                    <span className="text-[#64748B]">{entry.totalHours}</span>
                    <span className="ml-auto font-bold text-[#0F172A]">${entry.pay.toFixed(2)}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>

          {shift.createdByName ? (
            <p className="text-xs text-[#94A3B8]">Created by {shift.createdByName}</p>
          ) : null}
        </div>

        <footer className="flex items-center gap-2 border-t border-[#E2E8F0] px-6 py-4">
          <button
            type="button"
            onClick={onRequestDelete}
            className="inline-flex items-center gap-1.5 rounded-xl px-3 py-2 text-sm font-bold text-[#DC2626] hover:bg-[#FEF2F2]"
          >
            <Trash2 size={15} />
            Delete
          </button>
          <div className="ml-auto flex items-center gap-2">
            <button type="button" onClick={onClose} className="rounded-xl px-4 py-2.5 text-sm font-semibold text-[#64748B]">
              Close
            </button>
            {editable ? (
              <button
                type="button"
                onClick={onEdit}
                className="inline-flex items-center gap-1.5 rounded-xl bg-[#0386FF] px-5 py-2.5 text-sm font-bold text-white"
              >
                <Pencil size={15} />
                Edit Shift
              </button>
            ) : (
              <span className="text-xs font-semibold text-[#94A3B8]">Past shift — read-only</span>
            )}
          </div>
        </footer>
      </div>
    </div>
  );
}

function Row({ icon: Icon, label, children }: { icon: typeof Clock3; label: string; children: React.ReactNode }) {
  return (
    <div className="flex gap-3">
      <span className="mt-0.5 grid h-7 w-7 shrink-0 place-items-center rounded-lg bg-[#F1F5F9] text-[#64748B]">
        <Icon size={14} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="text-xs font-bold uppercase tracking-wide text-[#64748B]">{label}</p>
        <div className="mt-0.5">{children}</div>
      </div>
    </div>
  );
}
