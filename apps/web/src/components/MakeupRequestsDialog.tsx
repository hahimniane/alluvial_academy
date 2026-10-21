"use client";

import { useCallback, useEffect, useState } from "react";
import { CalendarSync, Check, CheckCircle2, Loader2, Pencil, X } from "lucide-react";
import { makeupReasonLabel, type MakeupRequest } from "@/lib/makeupRequests";
import { loadPendingMakeupRequests, reviewMakeupRequest } from "@/lib/makeupRequestsClient";
import { instantForWallTime } from "@/lib/timeZoneConvert";
import { safeTimezone, timezoneAbbreviation } from "@/lib/timezones";

/**
 * Teachers' makeup requests for missed classes — the web twin of the Flutter
 * RescheduleRequestsScreen. Approving schedules the makeup through
 * reviewRescheduleRequest, which takes the class itself from the missed shift.
 */

function errorText(error: unknown, fallback: string) {
  if (error && typeof error === "object" && "message" in error) {
    const message = String((error as { message?: unknown }).message ?? "").trim();
    if (message) return message;
  }
  return fallback;
}

function wallParts(date: Date, zone: string) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(date);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "00";
  return { day: `${get("year")}-${get("month")}-${get("day")}`, time: `${get("hour") === "24" ? "00" : get("hour")}:${get("minute")}` };
}

export function MakeupRequestsDialog({
  adminTimezone,
  onClose,
  onChanged,
}: {
  adminTimezone: string;
  onClose: () => void;
  onChanged: () => void;
}) {
  const zone = safeTimezone(adminTimezone);
  const [requests, setRequests] = useState<MakeupRequest[] | null>(null);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [editing, setEditing] = useState<{ id: string; day: string; time: string } | null>(null);
  const [declining, setDeclining] = useState<{ id: string; reason: string } | null>(null);

  const refresh = useCallback(() => {
    loadPendingMakeupRequests()
      .then((rows) => {
        setRequests(rows);
        setError("");
      })
      .catch((nextError) => {
        setRequests([]);
        setError(errorText(nextError, "Could not load makeup requests."));
      });
  }, []);
  useEffect(refresh, [refresh]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(""), 4000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const formatWhen = (start: Date | null, end: Date | null) => {
    if (!start) return "No time given";
    const day = new Intl.DateTimeFormat("en-US", { timeZone: zone, weekday: "short", month: "short", day: "numeric", year: "numeric" }).format(start);
    const time = (date: Date) => new Intl.DateTimeFormat("en-US", { timeZone: zone, hour: "numeric", minute: "2-digit" }).format(date);
    return `${day} • ${time(start)}${end ? ` – ${time(end)}` : ""} ${timezoneAbbreviation(zone, start)}`;
  };

  const run = async (id: string, action: () => Promise<unknown>, done: string) => {
    setBusyId(id);
    setError("");
    try {
      await action();
      setToast(done);
      setEditing(null);
      setDeclining(null);
      refresh();
      onChanged();
    } catch (nextError) {
      setError(errorText(nextError, "Could not update this request."));
    } finally {
      setBusyId(null);
    }
  };

  const approve = (request: MakeupRequest, startTime?: Date) =>
    run(request.id, () => reviewMakeupRequest({ requestId: request.id, decision: "approve", startTime }), "Makeup class approved and scheduled!");

  const approveEdited = (request: MakeupRequest) => {
    if (!editing) return;
    const [y, m, d] = editing.day.split("-").map(Number);
    const [hh, mm] = editing.time.split(":").map(Number);
    if (![y, m, d, hh, mm].every(Number.isFinite)) {
      setError("Pick a date and a start time.");
      return;
    }
    void approve(request, instantForWallTime(y, m, d, hh, mm, zone));
  };

  return (
    <div className="fixed inset-0 z-[70] grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex max-h-[90vh] w-full max-w-2xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EAF5FF] text-[#0386FF]">
            <CalendarSync size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#1F2937]">Makeup Requests</h2>
            <p className="text-xs text-[#64748B]">Times shown in {timezoneAbbreviation(zone)} ({zone})</p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close" className="grid h-9 w-9 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-6 py-4">
          {error ? <p className="mb-3 rounded-lg border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#991B1B]">{error}</p> : null}
          {requests === null ? (
            <div className="flex items-center justify-center gap-2 py-10 text-sm text-[#64748B]">
              <Loader2 size={16} className="animate-spin" /> Loading requests…
            </div>
          ) : requests.length === 0 ? (
            <div className="flex flex-col items-center gap-2 py-10 text-[#64748B]">
              <CheckCircle2 size={40} className="text-[#10B981]" />
              <p className="text-sm font-semibold">No makeup requests waiting.</p>
            </div>
          ) : (
            <ul className="grid gap-3">
              {requests.map((request) => {
                const busy = busyId === request.id;
                const isEditing = editing?.id === request.id;
                const isDeclining = declining?.id === request.id;
                return (
                  <li key={request.id} className="rounded-xl border border-[#E2E8F0] p-4">
                    <div className="flex items-start justify-between gap-3">
                      <p className="text-[15px] font-bold text-[#1E293B]">{request.teacherName || "Teacher"}</p>
                      <span className="shrink-0 rounded-md bg-[#FEF3C7] px-2 py-0.5 text-[11px] font-semibold text-[#92400E]">
                        {makeupReasonLabel(request.reasonCategory)}
                      </span>
                    </div>
                    <p className="mt-1 text-[13px] text-[#475569]">
                      {[request.subject, request.studentNames.join(", ")].filter(Boolean).join(" • ")}
                    </p>
                    <p className="mt-2 rounded-lg bg-[#F1F5F9] px-2.5 py-2 text-[13px] font-semibold text-[#1E293B]">
                      {formatWhen(request.proposedStart, request.proposedEnd)}
                    </p>
                    {request.notes ? <p className="mt-2 text-xs italic text-[#64748B]">{request.notes}</p> : null}

                    {isEditing ? (
                      <div className="mt-3 flex flex-wrap items-end gap-2">
                        <label className="text-xs font-semibold text-[#374151]">
                          Date
                          <input
                            type="date"
                            value={editing.day}
                            onChange={(event) => setEditing({ ...editing, day: event.target.value })}
                            className="mt-1 block h-9 rounded-lg border border-[#E2E8F0] px-2 text-sm"
                          />
                        </label>
                        <label className="text-xs font-semibold text-[#374151]">
                          Start ({timezoneAbbreviation(zone)})
                          <input
                            type="time"
                            value={editing.time}
                            onChange={(event) => setEditing({ ...editing, time: event.target.value })}
                            className="mt-1 block h-9 rounded-lg border border-[#E2E8F0] px-2 text-sm"
                          />
                        </label>
                        <button type="button" disabled={busy} onClick={() => approveEdited(request)} className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-[#10B981] px-3 text-xs font-semibold text-white disabled:opacity-60">
                          {busy ? <Loader2 size={14} className="animate-spin" /> : <Check size={14} />} Approve at this time
                        </button>
                        <button type="button" disabled={busy} onClick={() => setEditing(null)} className="h-9 rounded-lg px-3 text-xs font-semibold text-[#64748B]">
                          Cancel
                        </button>
                      </div>
                    ) : isDeclining ? (
                      <div className="mt-3 grid gap-2">
                        <label className="text-xs font-semibold text-[#374151]">
                          Decline Reason
                          <textarea
                            value={declining.reason}
                            onChange={(event) => setDeclining({ ...declining, reason: event.target.value })}
                            rows={2}
                            placeholder="Explain why this request is declined..."
                            className="mt-1 block w-full rounded-lg border border-[#E2E8F0] p-2 text-sm"
                          />
                        </label>
                        <div className="flex gap-2">
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => run(request.id, () => reviewMakeupRequest({ requestId: request.id, decision: "decline", reason: declining.reason.trim() }), "Makeup request declined.")}
                            className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-[#DC2626] px-3 text-xs font-semibold text-white disabled:opacity-60"
                          >
                            {busy ? <Loader2 size={14} className="animate-spin" /> : <X size={14} />} Decline
                          </button>
                          <button type="button" disabled={busy} onClick={() => setDeclining(null)} className="h-9 rounded-lg px-3 text-xs font-semibold text-[#64748B]">
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <div className="mt-3 flex flex-wrap gap-2">
                        <button type="button" disabled={busy} onClick={() => void approve(request)} className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-[#10B981] px-3 text-xs font-semibold text-white disabled:opacity-60">
                          {busy ? <Loader2 size={14} className="animate-spin" /> : <Check size={14} />} Approve &amp; Schedule
                        </button>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => {
                            const base = request.proposedStart ?? new Date();
                            setDeclining(null);
                            setEditing({ id: request.id, ...wallParts(base, zone) });
                          }}
                          className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-[#BFDBFE] px-3 text-xs font-semibold text-[#0386FF] disabled:opacity-60"
                        >
                          <Pencil size={14} /> Edit Time &amp; Approve
                        </button>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => {
                            setEditing(null);
                            setDeclining({ id: request.id, reason: "" });
                          }}
                          className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-[#FECACA] px-3 text-xs font-semibold text-[#DC2626] disabled:opacity-60"
                        >
                          <X size={14} /> Decline
                        </button>
                      </div>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </div>
        {toast ? <p className="border-t border-[#BBF7D0] bg-[#F0FDF4] px-6 py-2.5 text-sm font-semibold text-[#166534]">{toast}</p> : null}
      </div>
    </div>
  );
}
