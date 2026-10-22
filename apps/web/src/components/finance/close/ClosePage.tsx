"use client";

import Link from "next/link";
import { doc, onSnapshot } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useState } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { db, functions } from "@/lib/firebase";
import { canClose, closeChecklist } from "@/lib/finance/closeChecks";
import { financeHref } from "@/lib/finance/links";
import { describeLogEntry, parseMonthRecord, type MonthRecord } from "@/lib/finance/monthRecord";
import { currentMonth, monthName } from "@/lib/finance/months";
import type { MonthSummary } from "@/lib/finance/summary";
import { errorMessage, fetchMonthSummary, forgetSummaries } from "@/lib/finance/summaryClient";

export function FinanceClose() {
  const { month, user } = useFinance();
  const name = monthName(month);
  const ended = month < currentMonth();

  const [summary, setSummary] = useState<MonthSummary | null>(null);
  const [record, setRecord] = useState<MonthRecord | null>(null);
  const [loadError, setLoadError] = useState("");
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState("");
  const [reason, setReason] = useState("");

  const load = useCallback(() => {
    setLoadError("");
    fetchMonthSummary(month, { fresh: true })
      .then(setSummary)
      .catch((err) => setLoadError(errorMessage(err)));
  }, [month]);

  useEffect(() => {
    setSummary(null);
    setRecord(null);
    setActionError("");
    setReason("");
    load();
    return onSnapshot(
      doc(db, "finance_months", month),
      (snap) => setRecord(parseMonthRecord(snap.exists() ? snap.data() : null)),
      (err) => setLoadError(errorMessage(err)),
    );
  }, [month, load]);

  const closed = record?.status === "closed";
  const checks = summary ? closeChecklist(summary, ended) : [];

  const run = async (callable: "closeFinanceMonth" | "reopenFinanceMonth", data: Record<string, string>) => {
    setBusy(true);
    setActionError("");
    try {
      await httpsCallable(functions, callable)(data);
      forgetSummaries();
      setReason("");
      load();
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <section aria-labelledby="fin-close-title" className="flex flex-col gap-3">
      <h2 id="fin-close-title" className="m-0 text-2xl font-extrabold">Close {name}</h2>
      <p className="m-0 text-slate-600">Closing locks the month&apos;s numbers for reports. An owner can reopen it, and the reason is kept.</p>

      {loadError ? (
        <div role="alert" className="flex flex-wrap items-center gap-3 rounded-xl border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-900">
          <span className="flex-1">{loadError}</span>
          <button type="button" onClick={load} className="h-11 rounded-lg border border-red-400 bg-white px-4 font-bold text-red-800">
            Try again
          </button>
        </div>
      ) : null}

      <div className="flex flex-col gap-2.5 rounded-xl border border-slate-200 bg-white p-4">
        {!summary || !record ? (
          <p className="m-0 text-sm text-slate-600">{loadError ? "" : "Loading…"}</p>
        ) : (
          <>
            <ul className="m-0 flex list-none flex-col gap-2.5 p-0">
              {checks.map((c) => (
                <li key={c.id} className="flex items-center gap-2.5 rounded-[10px] bg-slate-50 px-3 py-2.5">
                  <span
                    aria-hidden="true"
                    className={`inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[13px] font-extrabold ${c.ok ? "bg-green-100 text-green-900" : "bg-amber-100 text-amber-900"}`}
                  >
                    {c.ok ? "✓" : "!"}
                  </span>
                  <span className="flex-1">
                    <span className="sr-only">{c.ok ? "Done: " : "To do: "}</span>
                    {c.text}
                  </span>
                  {c.href && !closed ? (
                    <Link
                      href={financeHref(c.href, month)}
                      className="inline-flex h-11 items-center rounded-lg border border-slate-300 bg-white px-3 font-semibold text-inherit no-underline hover:bg-slate-50"
                    >
                      Fix
                    </Link>
                  ) : null}
                </li>
              ))}
            </ul>

            {closed ? (
              <>
                <div role="status" className="rounded-[10px] bg-green-100 p-3 font-semibold text-green-950">
                  {name} is closed.
                </div>
                <label className="flex flex-col gap-1 text-xs font-semibold text-slate-700">
                  Reason for reopening
                  <input
                    type="text"
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                    maxLength={300}
                    placeholder="e.g. A teacher's penalty was entered by mistake"
                    className="h-11 rounded-lg border border-slate-300 px-2.5 text-sm font-normal"
                  />
                </label>
                <div>
                  <button
                    type="button"
                    disabled={busy || !reason.trim()}
                    onClick={() => run("reopenFinanceMonth", { month, reason: reason.trim() })}
                    className="h-11 rounded-lg border border-red-700 bg-white px-4 font-bold text-red-700 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Reopen {name}
                  </button>
                </div>
              </>
            ) : (
              <>
                <div>
                  <button
                    type="button"
                    disabled={busy || !canClose(checks)}
                    onClick={() => run("closeFinanceMonth", { month })}
                    className="h-11 rounded-lg bg-[#0386FF] px-4 font-bold text-white disabled:cursor-not-allowed disabled:bg-slate-300 disabled:text-slate-600"
                  >
                    Close {name}
                  </button>
                </div>
                {!canClose(checks) ? <p className="m-0 text-[13px] text-slate-600">Finish the items above to close the month.</p> : null}
              </>
            )}
            {actionError ? (
              <p role="alert" className="m-0 rounded-[10px] border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-900">{actionError}</p>
            ) : null}
          </>
        )}
      </div>

      {record && record.log.length > 0 ? (
        <section aria-labelledby="fin-close-history" className="rounded-xl border border-slate-200 bg-white p-4">
          <h3 id="fin-close-history" className="m-0 mb-2 text-base font-bold">History</h3>
          <ul className="m-0 list-none p-0">
            {[...record.log].reverse().map((entry, i) => (
              <li key={i} className="py-1 text-[13px] text-slate-700">{describeLogEntry(entry, month, user?.uid)}</li>
            ))}
          </ul>
        </section>
      ) : null}
    </section>
  );
}
