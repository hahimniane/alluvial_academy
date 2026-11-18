"use client";

import { useMemo, useState } from "react";
import { RefreshCw } from "lucide-react";
import { displayNameOf, isStudentType, type ListRow } from "@/lib/adminUsers";
import {
  ATTENTION_KINDS,
  ATTENTION_LABELS,
  attentionCounts,
  attentionList,
  reasonText,
  type AttentionKind,
  type AttentionReason,
} from "@/lib/usersAttention";
import { Avatar, Chip, Spinner, TypePill } from "./ui";

export type UpcomingState = { state: "loading" } | { state: "ready"; at: Date } | { state: "error" };

const TONE: Record<AttentionKind, string> = {
  noGuardian: "#B45309",
  noRate: "#B91C1C",
  noUpcomingClass: "#1D4ED8",
  neverLoggedIn: "#B45309",
  duplicate: "#6D28D9",
};

/** The Needs attention tab (F1): who needs something, why, and the way to fix it. */
export function NeedsAttention({
  rows,
  map,
  upcoming,
  onRetryUpcoming,
  onSelect,
  onEdit,
  onSendLogin,
}: {
  rows: readonly ListRow[];
  map: ReadonlyMap<string, readonly AttentionReason[]>;
  upcoming: UpcomingState;
  onRetryUpcoming: () => void;
  onSelect: (id: string) => void;
  onEdit: (id: string) => void;
  onSendLogin: (id: string) => void;
}) {
  const [only, setOnly] = useState<AttentionKind | null>(null);
  const counts = useMemo(() => attentionCounts(map), [map]);
  const list = useMemo(() => attentionList(rows, map, only), [rows, map, only]);

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-1.5" role="group" aria-label="Reason">
        <Chip on={only === null} onClick={() => setOnly(null)}>
          Everyone · {counts.people}
        </Chip>
        {ATTENTION_KINDS.map((k) => (
          <Chip key={k} on={only === k} onClick={() => setOnly(only === k ? null : k)}>
            {ATTENTION_LABELS[k]} · {k === "noUpcomingClass" && upcoming.state !== "ready" ? "…" : counts[k]}
          </Chip>
        ))}
      </div>
      {upcoming.state === "loading" ? (
        <p className="m-0 text-xs text-[#64748B]" role="status">
          Checking upcoming classes…
        </p>
      ) : upcoming.state === "error" ? (
        <p className="m-0 flex flex-wrap items-center gap-2 text-xs font-semibold text-[#B91C1C]" role="alert">
          Upcoming classes could not be checked, so students without one are not listed.
          <button type="button" onClick={onRetryUpcoming} className="font-semibold text-[#0369D9] underline">
            Try again
          </button>
        </p>
      ) : (
        <p className="m-0 flex flex-wrap items-center gap-2 text-xs text-[#64748B]">
          Classes checked at {upcoming.at.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}.
          <button type="button" onClick={onRetryUpcoming} className="inline-flex items-center gap-1 font-semibold text-[#0369D9]">
            <RefreshCw size={12} aria-hidden="true" /> Check again
          </button>
        </p>
      )}

      <div className="overflow-hidden rounded-[14px] border border-[#E2E8F0] bg-white">
        {list.length === 0 ? (
          upcoming.state === "loading" && only === "noUpcomingClass" ? (
            <Spinner label="Checking upcoming classes…" />
          ) : (
            <div className="px-6 py-12 text-center font-semibold text-[#334155]">{only ? `No one with “${ATTENTION_LABELS[only]}”` : "Nothing needs attention"}</div>
          )
        ) : (
          <ul className="m-0 list-none p-0">
            {list.map(({ row, reasons }) => (
              <li key={row.id} className="flex flex-col gap-2 border-t border-[#F1F5F9] px-4 py-3 first:border-t-0 md:flex-row md:items-start">
                <button type="button" onClick={() => onSelect(row.id)} className="flex min-h-10 min-w-0 items-center gap-2.5 text-left md:w-[300px] md:flex-none">
                  <Avatar row={row} size={36} />
                  <span className="flex min-w-0 flex-col">
                    <span className="truncate font-semibold">{displayNameOf(row)}</span>
                    <span className="flex">
                      <TypePill row={row} />
                    </span>
                  </span>
                </button>
                <ul className="m-0 flex min-w-0 flex-1 list-none flex-col gap-1.5 p-0">
                  {reasons.map((r) => (
                    <li key={r.kind} className="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-[13px]">
                      <span className="font-semibold" style={{ color: TONE[r.kind] }}>
                        {ATTENTION_LABELS[r.kind]}
                      </span>
                      <span className="min-w-0 text-[#475569]">{reasonText(r)}</span>
                      <Fix reason={r} row={row} onSelect={onSelect} onEdit={onEdit} onSendLogin={onSendLogin} />
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>
        )}
        <div className="border-t border-[#F1F5F9] px-4 py-3 text-xs text-[#64748B]">
          Showing {list.length} {list.length === 1 ? "person" : "people"}. Active accounts only.
        </div>
      </div>
    </div>
  );
}

const LINK = "font-semibold text-[#0369D9] hover:text-[#024E96] hover:underline";

function Fix({
  reason,
  row,
  onSelect,
  onEdit,
  onSendLogin,
}: {
  reason: AttentionReason;
  row: ListRow;
  onSelect: (id: string) => void;
  onEdit: (id: string) => void;
  onSendLogin: (id: string) => void;
}) {
  switch (reason.kind) {
    case "noGuardian":
      return (
        <button type="button" className={LINK} onClick={() => onEdit(row.id)}>
          Link a guardian
        </button>
      );
    case "neverLoggedIn":
      return isStudentType(row) ? (
        <button type="button" className={LINK} onClick={() => onSendLogin(row.id)}>
          Send login details
        </button>
      ) : (
        <button type="button" className={LINK} onClick={() => onSelect(row.id)}>
          Open
        </button>
      );
    case "duplicate":
      return (
        <span className="flex flex-wrap gap-x-2.5">
          {reason.others.slice(0, 3).map((o) => (
            <button key={o.id} type="button" className={LINK} onClick={() => onSelect(o.id)}>
              Open {o.name}
            </button>
          ))}
        </span>
      );
    default:
      return (
        <button type="button" className={LINK} onClick={() => onSelect(row.id)}>
          Open
        </button>
      );
  }
}
