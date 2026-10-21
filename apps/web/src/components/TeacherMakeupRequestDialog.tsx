"use client";

import { useMemo, useState } from "react";
import { RefreshCw, X } from "lucide-react";
import { tr } from "@/lib/i18n";
import {
  MAKEUP_REASONS,
  buildMakeupRequestFields,
  makeupDurationMinutes,
  type MakeupSourceShift,
} from "@/lib/makeupRequests";
import { submitMakeupRequest } from "@/lib/makeupRequestsClient";

export type BusyWindow = { id: string; start: Date | null; end: Date | null; status: string };

function pad(value: number) {
  return String(value).padStart(2, "0");
}

function dateInputValue(date: Date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function timeInputValue(date: Date) {
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** Mirrors the Flutter RescheduleRequestDialog: date, start time, reason and a note. */
export function TeacherMakeupRequestDialog({
  shift,
  teacherShifts,
  onClose,
  onSubmitted,
}: {
  shift: MakeupSourceShift;
  teacherShifts: BusyWindow[];
  onClose: () => void;
  onSubmitted: (message: string) => void;
}) {
  const today = useMemo(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }, []);
  const [day, setDay] = useState(() => dateInputValue(new Date(today.getTime() + 24 * 3600e3)));
  const [time, setTime] = useState(() => (shift.start ? timeInputValue(shift.start) : "09:00"));
  const [reason, setReason] = useState("power_outage");
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const minutes = makeupDurationMinutes(shift);
  const lastDay = dateInputValue(new Date(today.getTime() + 60 * 24 * 3600e3));
  const studentsText = shift.studentNames.join(", ") || tr("None");

  const submit = async () => {
    setError("");
    const start = new Date(`${day}T${time}`);
    if (!day || !time || Number.isNaN(start.getTime())) {
      setError(tr("Pick a date and a start time."));
      return;
    }
    const end = new Date(start.getTime() + minutes * 60_000);
    const clash = teacherShifts.some((other) => {
      if (other.id === shift.id || !other.start || !other.end) return false;
      const status = other.status.toLowerCase();
      if (status === "cancelled" || status === "deleted") return false;
      return start < other.end && end > other.start;
    });
    if (clash) {
      setError(tr("You already have another class scheduled at this time."));
      return;
    }
    setSaving(true);
    try {
      await submitMakeupRequest(buildMakeupRequestFields({ shift, proposedStart: start, reasonCategory: reason, notes }));
      onSubmitted(tr("Makeup class requested! Admin will review and schedule it."));
      onClose();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : tr("Could not submit this request."));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[60] grid place-items-center bg-black/45 px-4" role="dialog" aria-modal="true">
      <section className="max-h-[92vh] w-full max-w-[440px] overflow-y-auto rounded-2xl bg-white p-5 shadow-xl">
        <div className="flex items-start gap-3">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-[#0386FF]/10 text-[#0386FF]">
            <RefreshCw size={20} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-[17px] font-bold text-[#1E293B]">{tr("Request Makeup Class")}</h2>
            <p className="text-xs text-[#64748B]">{tr("Propose a date and time for this missed class.")}</p>
          </div>
          <button type="button" onClick={onClose} aria-label={tr("Close")} className="grid h-8 w-8 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={17} />
          </button>
        </div>

        <div className="mt-4 rounded-xl border border-[#E2E8F0] bg-[#F8FAFC] p-3">
          <p className="text-sm font-semibold text-[#1E293B]">{shift.subjectDisplayName || shift.subject}</p>
          <p className="mt-0.5 text-xs text-[#64748B]">{studentsText}</p>
          <p className="mt-1 text-[11px] font-medium text-[#0386FF]">{tr("Duration: {minutes} min", { minutes })}</p>
        </div>

        <label className="mt-4 block text-[13px] font-semibold text-[#374151]" htmlFor="makeup-day">{tr("Proposed Date")}</label>
        <input
          id="makeup-day"
          type="date"
          value={day}
          min={dateInputValue(today)}
          max={lastDay}
          onChange={(event) => setDay(event.target.value)}
          className="mt-1.5 h-11 w-full rounded-lg border border-[#E2E8F0] px-3 text-sm outline-none focus:border-[#0386FF]"
        />

        <label className="mt-3.5 block text-[13px] font-semibold text-[#374151]" htmlFor="makeup-time">{tr("Proposed Start Time")}</label>
        <input
          id="makeup-time"
          type="time"
          value={time}
          onChange={(event) => setTime(event.target.value)}
          className="mt-1.5 h-11 w-full rounded-lg border border-[#E2E8F0] px-3 text-sm outline-none focus:border-[#0386FF]"
        />

        <label className="mt-3.5 block text-[13px] font-semibold text-[#374151]" htmlFor="makeup-reason">{tr("Reason for Makeup")}</label>
        <select
          id="makeup-reason"
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          className="mt-1.5 h-11 w-full rounded-lg border border-[#E2E8F0] bg-white px-3 text-sm outline-none focus:border-[#0386FF]"
        >
          {MAKEUP_REASONS.map((option) => (
            <option key={option.value} value={option.value}>{tr(option.label)}</option>
          ))}
        </select>

        <label className="mt-3.5 block text-[13px] font-semibold text-[#374151]" htmlFor="makeup-notes">{tr("Additional Notes (Optional)")}</label>
        <textarea
          id="makeup-notes"
          value={notes}
          onChange={(event) => setNotes(event.target.value)}
          rows={2}
          placeholder={tr("Add any notes for the admin...")}
          className="mt-1.5 w-full rounded-lg border border-[#E2E8F0] p-2.5 text-sm outline-none focus:border-[#0386FF]"
        />

        {error ? <p className="mt-3 rounded-lg border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-xs font-medium text-[#991B1B]">{error}</p> : null}

        <button
          type="button"
          onClick={submit}
          disabled={saving}
          className="mt-4 w-full rounded-lg bg-[#0386FF] py-3 text-sm font-semibold text-white disabled:bg-[#93C5FD]"
        >
          {saving ? tr("Submitting...") : tr("Submit Request")}
        </button>
      </section>
    </div>
  );
}
