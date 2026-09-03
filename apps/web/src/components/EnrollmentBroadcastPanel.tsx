"use client";

import { useEffect, useState } from "react";
import { CheckCircle2, History, Radio, Undo2, UserRound, X } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import {
  confirmTeacherMatch,
  declineTeacherResponse,
  loadTeacherResponses,
  type TeacherResponse,
} from "@/lib/jobBoardAdmin";

export type BroadcastSnapshot = {
  days: string[];
  timeSlots: string[];
  timeOfDayPreference: string;
  timezoneRef: string;
  adminNotesForTeachers: string;
  targetTeacherNames: string[];
};

export type ActionEntry = {
  action: string;
  status: string;
  adminName: string;
  adminEmail: string;
  teacherName: string;
  timestamp: Date | null;
};

/**
 * What teachers were told, and what they said back.
 *
 * Shown while a request is live. Confirming here is the step that turns a
 * response into a match, so both the snapshot and the responses have to be on
 * the same screen — the decision is "does this teacher's availability actually
 * cover what we asked for".
 */
export function BroadcastPanel({
  jobId,
  snapshot,
  onChanged,
}: {
  jobId: string;
  snapshot: BroadcastSnapshot | null;
  onChanged: () => void;
}) {
  const [responses, setResponses] = useState<TeacherResponse[] | null>(null);
  const [error, setError] = useState("");
  const [decliningId, setDecliningId] = useState<string | null>(null);
  const [declineNote, setDeclineNote] = useState("");

  useEffect(() => {
    let alive = true;
    setResponses(null);
    setError("");
    loadTeacherResponses(jobId)
      .then((rows) => alive && setResponses(rows))
      .catch((issue) => alive && setError(issue instanceof Error ? issue.message : "Could not load responses."));
    return () => {
      alive = false;
    };
  }, [jobId]);

  return (
    <div className="mt-3 rounded-xl border border-[#BFDBFE] bg-[#F8FAFF] p-3">
      {snapshot ? (
        <section>
          <div className="flex items-center gap-1.5">
            <Radio size={14} className="text-[#1D4ED8]" />
            <p className="text-[11px] font-bold text-[#1D4ED8]">What teachers were sent</p>
          </div>
          <dl className="mt-1.5 grid gap-0.5 text-[11px] text-[#334155]">
            <SnapshotRow label="Days" value={snapshot.days.join(", ")} />
            <SnapshotRow label="Times" value={snapshot.timeSlots.join(", ")} />
            <SnapshotRow label="Window" value={snapshot.timeOfDayPreference} />
            <SnapshotRow label="Timezone" value={snapshot.timezoneRef} />
            <SnapshotRow label="Admin note" value={snapshot.adminNotesForTeachers} />
            <SnapshotRow
              label="Sent to"
              value={snapshot.targetTeacherNames.length ? snapshot.targetTeacherNames.join(", ") : "All teachers"}
            />
          </dl>
        </section>
      ) : (
        <p className="text-[11px] text-[#64748B]">
          This request was broadcast before we started recording what was sent, so there is no snapshot to show.
        </p>
      )}

      <section className="mt-3 border-t border-[#DBEAFE] pt-3">
        <p className="text-[11px] font-bold text-[#1D4ED8]">Teacher responses</p>

        {error ? <p className="mt-1 text-[11px] font-semibold text-[#DC2626]">{error}</p> : null}
        {responses === null && !error ? (
          <p className="mt-1 text-[11px] text-[#64748B]">Loading responses…</p>
        ) : null}
        {responses?.length === 0 ? (
          <p className="mt-1 text-[11px] text-[#64748B]">No teacher responses yet.</p>
        ) : null}

        <div className="mt-1.5 grid gap-2">
          {(responses ?? []).map((response) => (
            <article
              key={response.teacherId}
              className={`rounded-lg border bg-white p-2.5 ${
                response.adminRejected ? "border-[#E2E8F0] opacity-60" : "border-[#BFDBFE]"
              }`}
            >
              <div className="flex flex-wrap items-center gap-2">
                <UserRound size={15} className="text-[#64748B]" />
                <span className="text-xs font-bold text-[#1E293B]">{response.teacherName}</span>
                <span
                  className={`rounded px-1.5 py-0.5 text-[10px] font-bold ${
                    response.availabilityStatus === "available"
                      ? "bg-[#D1FAE5] text-[#065F46]"
                      : "bg-[#FEF3C7] text-[#92400E]"
                  }`}
                >
                  {response.availabilityStatus === "available" ? "Available" : "Partially available"}
                </span>
                {response.adminRejected ? (
                  <span className="rounded bg-[#F1F5F9] px-1.5 py-0.5 text-[10px] font-bold text-[#64748B]">Declined</span>
                ) : null}
                {response.teacherTimezone ? (
                  <span className="text-[10px] text-[#64748B]">{response.teacherTimezone}</span>
                ) : null}
              </div>

              {response.rankedSlots.length > 0 ? (
                <ol className="mt-1.5 grid gap-0.5">
                  {response.rankedSlots.map((slot, index) => (
                    <li key={slot} className="text-[11px] text-[#334155]">
                      <span className="font-bold text-[#047857]">{index + 1}.</span> {slot}
                    </li>
                  ))}
                </ol>
              ) : null}

              {response.comment ? (
                <p className="mt-1.5 whitespace-pre-wrap text-[11px] leading-4 text-[#475569]">{response.comment}</p>
              ) : null}
              {response.adminRejectedNote ? (
                <p className="mt-1 text-[10px] italic text-[#64748B]">Declined: {response.adminRejectedNote}</p>
              ) : null}

              {!response.adminRejected ? (
                decliningId === response.teacherId ? (
                  <div className="mt-2 grid gap-1.5">
                    <label className="sr-only" htmlFor={`decline-${response.teacherId}`}>Reason</label>
                    <input
                      id={`decline-${response.teacherId}`}
                      value={declineNote}
                      onChange={(event) => setDeclineNote(event.target.value)}
                      placeholder="Why are you declining? (optional)"
                      className="h-8 rounded border border-[#E2E8F0] px-2 text-[11px]"
                    />
                    <div className="flex items-center gap-2">
                      <ActionButton
                        label="Confirm decline"
                        busyLabel="Declining…"
                        variant="danger"
                        onAction={async () => {
                          await declineTeacherResponse(jobId, response.teacherId, declineNote);
                          setDecliningId(null);
                          setDeclineNote("");
                          setResponses(await loadTeacherResponses(jobId));
                        }}
                      />
                      <button
                        type="button"
                        onClick={() => setDecliningId(null)}
                        className="text-[11px] font-semibold text-[#475569]"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="mt-2 flex items-center gap-2">
                    <ActionButton
                      label="Confirm match"
                      busyLabel="Confirming…"
                      icon={<CheckCircle2 size={15} />}
                      onAction={async () => {
                        await confirmTeacherMatch(jobId, response.teacherId);
                        onChanged();
                      }}
                    />
                    <button
                      type="button"
                      onClick={() => {
                        setDecliningId(response.teacherId);
                        setDeclineNote("");
                      }}
                      className="inline-flex items-center gap-1 text-[11px] font-semibold text-[#DC2626]"
                    >
                      <X size={13} />
                      Decline
                    </button>
                  </div>
                )
              ) : null}
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}

function SnapshotRow({ label, value }: { label: string; value: string }) {
  if (!value) return null;
  return (
    <div className="flex gap-1.5">
      <dt className="shrink-0 font-semibold text-[#64748B]">{label}:</dt>
      <dd className="min-w-0">{value}</dd>
    </div>
  );
}

/** Who did what, in the order it happened. */
export function ActivityHistory({ entries }: { entries: ActionEntry[] }) {
  const [open, setOpen] = useState(false);
  if (entries.length === 0) return null;
  const ordered = [...entries].sort((a, b) => (a.timestamp?.getTime() ?? 0) - (b.timestamp?.getTime() ?? 0));

  return (
    <div className="mt-3 border-t border-black/10 pt-2.5">
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-expanded={open}
        className="inline-flex items-center gap-1.5 text-[11px] font-bold text-[#475569]"
      >
        <History size={14} />
        Activity history ({ordered.length})
      </button>
      {open ? (
        <ol className="mt-1.5 grid gap-1">
          {ordered.map((entry, index) => (
            <li key={index} className="flex flex-wrap items-baseline gap-x-1.5 text-[11px] text-[#475569]">
              <span className="font-semibold text-[#1E293B]">{describeAction(entry)}</span>
              <span className="text-[#64748B]">
                {entry.adminName || entry.adminEmail || "System"}
                {entry.timestamp ? ` · ${entry.timestamp.toLocaleString()}` : ""}
              </span>
            </li>
          ))}
        </ol>
      ) : null}
    </div>
  );
}

/** Plain words for the stored action names. */
function describeAction(entry: ActionEntry): string {
  switch (entry.action) {
    case "broadcasted":
      return "Sent to teachers";
    case "unbroadcasted":
      return "Taken off the job board";
    case "admin_confirmed_match":
      return entry.teacherName ? `Matched with ${entry.teacherName}` : "Match confirmed";
    case "discount_added":
      return "Discount added";
    case "discount_changed":
      return "Discount changed";
    case "discount_removed":
      return "Discount removed";
    case "job_board_reopened_after_full_availability":
      return "Reopened for teachers";
    default:
      // Unknown actions still have to say something true.
      return entry.action.replace(/_/g, " ").replace(/^./, (c) => c.toUpperCase());
  }
}

export { describeAction };
