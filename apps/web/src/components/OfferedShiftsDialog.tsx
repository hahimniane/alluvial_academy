"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeftRight, CheckCircle2, History, Loader2, RefreshCw, Undo2, UserCheck, X } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { PersonSelectDialog, type PersonOption } from "@/components/PersonSelect";
import {
  type OpenOffer,
  type TradeAction,
  type TradeEvent,
  assignCandidates,
  idsNeedingNames,
  offeredByLabel,
  timeAgo,
  tradeSentence,
} from "@/lib/adminShiftTrades";
import { assignOfferedShift, loadTradeHistory, loadUserNames, setShiftOffer } from "@/lib/adminShiftTradesClient";
import { type StaffMember, formatInZone } from "@/lib/shifts";
import { safeTimezone, timezoneAbbreviation } from "@/lib/timezones";

/**
 * Every class teachers (or an admin) put up for trade, and what became of
 * each one. An admin gives an offered class to the right teacher or takes the
 * offer back here; the History tab is the record of who offered, claimed,
 * assigned and took back what.
 */

type Tab = "open" | "history";

const ACTION_STYLE: Record<TradeAction, { icon: LucideIcon; bg: string; fg: string }> = {
  offered: { icon: ArrowLeftRight, bg: "#EDE9FE", fg: "#6D28D9" },
  claimed: { icon: UserCheck, bg: "#D1FAE5", fg: "#047857" },
  assigned: { icon: UserCheck, bg: "#DBEAFE", fg: "#1D4ED8" },
  withdrawn: { icon: Undo2, bg: "#F1F5F9", fg: "#64748B" },
};

export function OfferedShiftsDialog({
  offers,
  offersError,
  staff,
  dutyHolderIds,
  adminTimezone,
  onRefresh,
  onChanged,
  onClose,
}: {
  /** Open offers, owned by the Shifts screen (its toolbar counts them); null while loading. */
  offers: OpenOffer[] | null;
  offersError: string;
  staff: StaffMember[];
  /** Teachers who already hold a leadership duty — they may take another. */
  dutyHolderIds: ReadonlySet<string>;
  adminTimezone: string;
  onRefresh: () => Promise<void>;
  /** A class was assigned or its offer taken back: reload it and the offers. */
  onChanged: (shiftId: string) => Promise<void>;
  onClose: () => void;
}) {
  const zone = safeTimezone(adminTimezone);
  const [tab, setTab] = useState<Tab>("open");
  const [history, setHistory] = useState<TradeEvent[] | null>(null);
  const [historyError, setHistoryError] = useState("");
  const [extraNames, setExtraNames] = useState<Map<string, string>>(() => new Map());
  const [now, setNow] = useState(() => new Date());
  const [refreshing, setRefreshing] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [rowError, setRowError] = useState<{ id: string; text: string } | null>(null);
  const [picking, setPicking] = useState<OpenOffer | null>(null);
  const [confirming, setConfirming] = useState<{ offerId: string; teacher: StaffMember } | null>(null);
  const [toast, setToast] = useState("");
  const mounted = useRef(true);
  const historyShown = useRef(false);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const loadHistory = useCallback(() => {
    historyShown.current = true;
    return loadTradeHistory()
      .then((rows) => {
        if (!mounted.current) return;
        setHistory(rows);
        setHistoryError("");
        setNow(new Date());
      })
      .catch(() => {
        if (!mounted.current) return;
        setHistory((prev) => prev ?? []);
        setHistoryError("Could not load the trade history.");
      });
  }, []);

  // The history is only read once somebody looks at it.
  useEffect(() => {
    if (tab === "history") void loadHistory();
  }, [tab, loadHistory]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(""), 4000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  // Staff are already loaded by the Shifts screen; only the odd person the
  // rows know by id alone (an admin outside the staff list) is read on top.
  const nameById = useMemo(() => {
    const names = new Map(staff.map((member) => [member.id, member.displayName]));
    for (const [id, name] of extraNames) if (!names.has(id)) names.set(id, name);
    return names;
  }, [staff, extraNames]);

  useEffect(() => {
    const missing = idsNeedingNames(offers ?? [], history ?? [], nameById);
    if (missing.length === 0) return;
    let active = true;
    void loadUserNames(missing).then((names) => {
      if (active) setExtraNames((prev) => new Map([...prev, ...names]));
    });
    return () => {
      active = false;
    };
  }, [offers, history, nameById]);

  const timeIn = (date: Date) => new Intl.DateTimeFormat("en-US", { timeZone: zone, hour: "numeric", minute: "2-digit" }).format(date);
  const formatWhen = (date: Date) => formatInZone(date, zone);

  const refresh = async () => {
    setRefreshing(true);
    await Promise.all([onRefresh(), historyShown.current ? loadHistory() : Promise.resolve()]);
    if (!mounted.current) return;
    setNow(new Date());
    setRefreshing(false);
  };

  const run = async (offer: OpenOffer, action: () => Promise<void>, done: string) => {
    setBusyId(offer.id);
    setRowError(null);
    try {
      await action();
      await onChanged(offer.id);
      if (!mounted.current) return;
      setConfirming(null);
      setToast(done);
      // The trade record is written by the server a moment after the change.
      window.setTimeout(() => {
        if (mounted.current && historyShown.current) void loadHistory();
      }, 3000);
    } catch (error) {
      if (!mounted.current) return;
      setRowError({ id: offer.id, text: error instanceof Error && error.message ? error.message : "Could not update this class." });
      // A refusal often means the offer changed under us (somebody claimed it).
      void onRefresh();
    } finally {
      if (mounted.current) setBusyId(null);
    }
  };

  const pickerPeople: PersonOption[] = useMemo(
    () =>
      picking
        ? assignCandidates(staff, picking, dutyHolderIds).map((member) => ({
            id: member.id,
            name: member.displayName,
            email: member.email,
          }))
        : [],
    [picking, staff, dutyHolderIds],
  );

  // A refusal for a class that has since left the list still needs saying.
  const orphanError = rowError && !(offers ?? []).some((offer) => offer.id === rowError.id) ? rowError.text : "";

  return (
    <div className="fixed inset-0 z-[70] grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex h-[min(720px,90vh)] w-full max-w-2xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EDE9FE] text-[#6D28D9]">
            <ArrowLeftRight size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#1F2937]">Offered Classes</h2>
            <p className="text-xs text-[#64748B]">Times shown in {timezoneAbbreviation(zone)} ({zone})</p>
          </div>
          <button
            type="button"
            onClick={() => void refresh()}
            disabled={refreshing}
            aria-label="Refresh"
            className="grid h-9 w-9 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9] disabled:opacity-60"
          >
            <RefreshCw size={16} className={refreshing ? "animate-spin" : ""} />
          </button>
          <button type="button" onClick={onClose} aria-label="Close" className="grid h-9 w-9 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </header>

        <div className="flex items-center border-b border-[#E2E8F0] px-4">
          {(
            [
              { id: "open", label: offers === null ? "Open offers" : `Open offers (${offers.length})` },
              { id: "history", label: "History" },
            ] as { id: Tab; label: string }[]
          ).map((entry) => (
            <button
              key={entry.id}
              type="button"
              onClick={() => setTab(entry.id)}
              className={`relative -mb-px border-b-2 px-3 py-3 text-sm font-semibold ${
                tab === entry.id ? "border-[#0386FF] text-[#0386FF]" : "border-transparent text-[#64748B]"
              }`}
            >
              {entry.label}
            </button>
          ))}
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-4">
          {tab === "open" ? (
            <>
              {offersError ? <ErrorBanner text={offersError} /> : null}
              {orphanError ? <ErrorBanner text={orphanError} /> : null}
              {offers === null ? (
                <LoadingRow text="Loading offered classes…" />
              ) : offers.length === 0 ? (
                offersError ? null : (
                  <EmptyState
                    icon={ArrowLeftRight}
                    title="No classes are on offer."
                    hint="A class shows here when its teacher or an admin offers it to others."
                  />
                )
              ) : (
                <ul className="grid gap-3">
                  {offers.map((offer) => {
                    const busy = busyId === offer.id;
                    const confirmingThis = confirming?.offerId === offer.id ? confirming : null;
                    const ago = timeAgo(offer.offeredAt, now);
                    const kind = offer.duty ? "duty" : "class";
                    return (
                      <li key={offer.id} className="rounded-xl border border-[#E2E8F0] p-4">
                        <div className="flex items-start justify-between gap-3">
                          <p className="min-w-0 text-[15px] font-bold text-[#1E293B]">{offer.name}</p>
                          <span
                            className={`shrink-0 rounded-md px-2 py-0.5 text-[11px] font-semibold ${
                              offer.duty ? "bg-[#FEF3C7] text-[#92400E]" : "bg-[#DBEAFE] text-[#1D4ED8]"
                            }`}
                          >
                            {offer.duty ? "Duty" : "Class"}
                          </span>
                        </div>
                        <p className="mt-2 rounded-lg bg-[#F1F5F9] px-2.5 py-2 text-[13px] font-semibold text-[#1E293B]">
                          {formatWhen(offer.start)} – {timeIn(offer.end)} {timezoneAbbreviation(zone, offer.start)}
                        </p>
                        <dl className="mt-2 grid gap-x-4 gap-y-1 text-[13px] text-[#475569] sm:grid-cols-2">
                          <div className="flex gap-1.5">
                            <dt className="text-[#94A3B8]">Teacher</dt>
                            <dd className="min-w-0 truncate font-semibold text-[#334155]">{offer.teacherName}</dd>
                          </div>
                          <div className="flex gap-1.5">
                            <dt className="shrink-0 text-[#94A3B8]">Offered by</dt>
                            <dd className="min-w-0 truncate font-semibold text-[#334155]">
                              {offeredByLabel(offer, nameById)}
                              {ago ? <span className="font-normal text-[#94A3B8]"> · {ago}</span> : null}
                            </dd>
                          </div>
                        </dl>

                        {rowError?.id === offer.id ? (
                          <p className="mt-3 rounded-lg border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-[13px] font-semibold text-[#991B1B]">
                            {rowError.text}
                          </p>
                        ) : null}

                        {confirmingThis ? (
                          <div className="mt-3 rounded-lg bg-[#EFF6FF] px-3 py-2.5">
                            <p className="text-[13px] text-[#1E3A8A]">
                              Give this {kind} to <strong>{confirmingThis.teacher.displayName}</strong>? It moves to their schedule
                              and they are paid for it.
                            </p>
                            <div className="mt-2 flex flex-wrap gap-2">
                              <button
                                type="button"
                                disabled={busy}
                                onClick={() =>
                                  void run(
                                    offer,
                                    () => assignOfferedShift(offer.id, confirmingThis.teacher.id),
                                    `Assigned to ${confirmingThis.teacher.displayName}.`,
                                  )
                                }
                                className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-[#0386FF] px-3 text-xs font-semibold text-white disabled:opacity-60"
                              >
                                {busy ? <Loader2 size={14} className="animate-spin" /> : <UserCheck size={14} />} Assign
                              </button>
                              <button
                                type="button"
                                disabled={busy}
                                onClick={() => {
                                  setConfirming(null);
                                  setPicking(offer);
                                }}
                                className="h-9 rounded-lg px-3 text-xs font-semibold text-[#0386FF] disabled:opacity-60"
                              >
                                Pick someone else
                              </button>
                              <button
                                type="button"
                                disabled={busy}
                                onClick={() => setConfirming(null)}
                                className="h-9 rounded-lg px-3 text-xs font-semibold text-[#64748B] disabled:opacity-60"
                              >
                                Cancel
                              </button>
                            </div>
                          </div>
                        ) : (
                          <div className="mt-3 flex flex-wrap gap-2">
                            <button
                              type="button"
                              disabled={busy}
                              onClick={() => {
                                setRowError(null);
                                setPicking(offer);
                              }}
                              className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-[#0386FF] px-3 text-xs font-semibold text-white disabled:opacity-60"
                            >
                              <UserCheck size={14} /> Assign to…
                            </button>
                            <button
                              type="button"
                              disabled={busy}
                              onClick={() => void run(offer, () => setShiftOffer(offer.id, false), "Offer taken back.")}
                              className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-[#E2E8F0] px-3 text-xs font-semibold text-[#475569] hover:bg-[#F8FAFC] disabled:opacity-60"
                            >
                              {busy ? <Loader2 size={14} className="animate-spin" /> : <Undo2 size={14} />} Take offer back
                            </button>
                          </div>
                        )}
                      </li>
                    );
                  })}
                </ul>
              )}
            </>
          ) : (
            <>
              {historyError ? <ErrorBanner text={historyError} /> : null}
              {history === null ? (
                <LoadingRow text="Loading history…" />
              ) : history.length === 0 ? (
                historyError ? null : (
                  <EmptyState
                    icon={History}
                    title="No trades to show."
                    hint="Each offer, claim, assignment and offer taken back is listed here."
                  />
                )
              ) : (
                <ul className="grid gap-1">
                  {history.map((event) => {
                    const style = ACTION_STYLE[event.action];
                    const Icon = style.icon;
                    const ago = timeAgo(event.createdAt, now);
                    return (
                      <li key={event.id} className="flex items-start gap-3 rounded-lg px-1 py-2">
                        <span
                          className="mt-0.5 grid h-7 w-7 shrink-0 place-items-center rounded-full"
                          style={{ backgroundColor: style.bg, color: style.fg }}
                        >
                          <Icon size={14} />
                        </span>
                        <div className="min-w-0 flex-1">
                          <p className="text-sm font-medium text-[#1E293B]">{tradeSentence(event, { nameById, formatWhen })}</p>
                          {event.createdAt ? (
                            <p className="mt-0.5 text-xs text-[#94A3B8]">
                              {ago} · {formatWhen(event.createdAt)}
                            </p>
                          ) : null}
                        </div>
                      </li>
                    );
                  })}
                </ul>
              )}
            </>
          )}
        </div>
        {toast ? (
          <p className="flex items-center gap-2 border-t border-[#BBF7D0] bg-[#F0FDF4] px-6 py-2.5 text-sm font-semibold text-[#166534]">
            <CheckCircle2 size={15} /> {toast}
          </p>
        ) : null}
      </div>

      {picking ? (
        <PersonSelectDialog
          title={picking.duty ? "Assign duty to a leader" : "Assign class to a teacher"}
          people={pickerPeople}
          selectedIds={[]}
          onConfirm={(ids) => {
            const teacher = staff.find((member) => member.id === ids[0]);
            if (teacher) setConfirming({ offerId: picking.id, teacher });
            setPicking(null);
          }}
          onClose={() => setPicking(null)}
        />
      ) : null}
    </div>
  );
}

function ErrorBanner({ text }: { text: string }) {
  return <p className="mb-3 rounded-lg border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#991B1B]">{text}</p>;
}

function LoadingRow({ text }: { text: string }) {
  return (
    <div className="flex items-center justify-center gap-2 py-10 text-sm text-[#64748B]">
      <Loader2 size={16} className="animate-spin" /> {text}
    </div>
  );
}

function EmptyState({ icon: Icon, title, hint }: { icon: LucideIcon; title: string; hint: string }) {
  return (
    <div className="flex flex-col items-center gap-2 py-10 text-center text-[#64748B]">
      <Icon size={36} className="text-[#94A3B8]" />
      <p className="text-sm font-semibold">{title}</p>
      <p className="max-w-sm text-xs text-[#94A3B8]">{hint}</p>
    </div>
  );
}
