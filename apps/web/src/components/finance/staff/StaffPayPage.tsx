"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { money, money0 } from "@/lib/finance/model";
import { monthLabel } from "@/lib/finance/months";
import { downloadCsv } from "@/lib/finance/csv";
import {
  adminRows,
  openPause,
  payLabel,
  payoutKey,
  payState,
  pauseScheduledAfter,
  pausedLabel,
  scheduledPauseLabel,
  staffCards,
  staffCsv,
  teacherRows,
  type PayableRow,
} from "@/lib/finance/staff";
import { AdminPayDialog, PauseDialog } from "./AdminDialogs";
import { PayDialog, VoidDialog } from "./PayDialog";
import { Badge, BTN, BTN_PRIMARY, BTN_SM, CARD, StatCard, Toast } from "./staffUi";
import { useStaffData } from "./useStaffData";

type Dialog =
  | { kind: "pay"; rows: PayableRow[] }
  | { kind: "void"; row: PayableRow }
  | { kind: "admin"; uid: string | null }
  | { kind: "pause"; mode: "pause" | "resume"; uid: string; name: string; cancelFrom?: string }
  | null;

const TH = "px-3 py-2.5 font-semibold";
const TD = "px-3 py-2.5 align-top";

export function StaffPayPage() {
  const { month } = useFinance();
  const { data, error, loading, reload } = useStaffData(month);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [dialog, setDialog] = useState<Dialog>(null);
  const [toast, setToast] = useState("");
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => setSelected(new Set()), [month]);
  useEffect(() => () => void (toastTimer.current && clearTimeout(toastTimer.current)), []);

  const flash = (message: string) => {
    setToast(message);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(""), 4000);
  };
  const done = (message: string) => {
    setDialog(null);
    setSelected(new Set());
    flash(message);
    reload();
  };

  const teachers = useMemo(() => (data ? teacherRows(data.summary, data.payouts) : []), [data]);
  const admins = useMemo(() => (data ? adminRows(data.summary, data.payouts) : []), [data]);
  const payable = useMemo(() => [...teachers, ...admins].filter((r) => r.payable), [teachers, admins]);
  const picked = payable.filter((r) => selected.has(payoutKey(r.role, r.uid)));

  if (loading && !data) return <p className="p-2 text-sm text-slate-600">Loading staff pay…</p>;
  if (error && !data) {
    return (
      <section className={`${CARD} p-5`}>
        <h2 className="text-lg font-extrabold">Staff pay</h2>
        <p role="alert" className="mt-2 text-sm text-red-800">{error}</p>
        <button type="button" className={`${BTN} mt-3`} onClick={reload}>
          Try again
        </button>
      </section>
    );
  }
  if (!data) return null;

  const { summary, payouts, usualMethod, terms, deactivated, closedMonths } = data;
  const closed = summary.status === "closed";
  const cards = staffCards(summary, teachers, admins);
  const teacherFinalAll = summary.teachers.length > 0 && summary.teachers.every((t) => t.final);
  const toggle = (uid: string) =>
    setSelected((s) => {
      const next = new Set(s);
      if (next.has(uid)) next.delete(uid);
      else next.add(uid);
      return next;
    });

  const paymentCell = (row: PayableRow) => {
    const state = payState(row.due, row.payout);
    return (
      <div className="flex flex-col items-start gap-1">
        <span className={`font-semibold ${state === "unpaid" ? "text-amber-800" : "text-green-700"}`}>{payLabel(row.due, row.payout)}</span>
        {state !== "unpaid" ? (
          <button type="button" className="text-xs font-semibold text-[#024E96] underline disabled:opacity-50" disabled={closed} onClick={() => setDialog({ kind: "void", row })}>
            Void
          </button>
        ) : null}
        {row.payout?.voided ? <span className="text-xs text-slate-600">Earlier payment voided: {row.payout.void_reason}</span> : null}
      </div>
    );
  };

  // A fully paid row has nothing left to pay; Void is in the Payment column.
  const payButton = (row: PayableRow) =>
    payState(row.due, row.payout) === "paid" ? null : (
    <button
      type="button"
      className={BTN_SM}
      disabled={!row.payable || closed}
      title={row.blocked || undefined}
      aria-label={`Pay ${row.name}`}
      onClick={() => setDialog({ kind: "pay", rows: [row] })}
    >
      {payState(row.due, row.payout) === "partial" ? "Pay the rest" : "Pay"}
    </button>
    );

  const checkbox = (row: PayableRow) => (
    <input
      type="checkbox"
      aria-label={`Select ${row.name}`}
      checked={selected.has(payoutKey(row.role, row.uid)) && row.payable}
      disabled={!row.payable || closed}
      title={row.blocked || undefined}
      onChange={() => toggle(payoutKey(row.role, row.uid))}
      className="h-5 w-5"
    />
  );

  const exportCsv = () => downloadCsv(`staff-pay-${month}.csv`, staffCsv(month, teachers, admins, summary));
  const editing = dialog?.kind === "admin" && dialog.uid ? summary.admins.find((a) => a.uid === dialog.uid) : null;

  return (
    <section className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-2xl font-extrabold">Staff pay · {monthLabel(month)}</h1>
        {closed ? <Badge tone="mute">Closed</Badge> : <Badge tone={summary.final ? "ok" : "warn"}>{summary.final ? "Final" : "In progress"}</Badge>}
        <div className="flex-1" />
        <button type="button" className={BTN} onClick={exportCsv}>
          Export to Excel
        </button>
      </div>
      <p className="text-sm text-slate-600">
        {teacherFinalAll
          ? `${monthLabel(month)} audits are approved, so teacher pay is final. Select everyone and mark them paid in one go.`
          : "Pay shown is an estimate from classes so far and becomes final when each audit is approved."}
      </p>
      {closed ? <p className="rounded-lg bg-slate-100 px-3 py-2 text-sm text-slate-700">This month is closed. Payments and pay changes are locked until it is reopened.</p> : null}
      {error ? <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">{error}</p> : null}

      <div className="grid grid-cols-2 gap-2.5 lg:grid-cols-4">
        {cards.map((c) => (
          <StatCard key={c.label} {...c} />
        ))}
      </div>

      <div className={`${CARD} flex flex-wrap items-center gap-2.5 p-3`}>
        <button type="button" className={BTN} disabled={payable.length === 0 || closed} onClick={() => setSelected(new Set(payable.map((r) => payoutKey(r.role, r.uid))))}>
          Select everyone ready to pay ({payable.length})
        </button>
        <button type="button" className={BTN_PRIMARY} disabled={picked.length === 0 || closed} onClick={() => setDialog({ kind: "pay", rows: picked })}>
          Mark {picked.length} as paid
        </button>
        <span className="text-xs text-slate-600">Only final pay can be marked paid. Estimates become final when the audit is approved.</span>
      </div>

      <div className={`${CARD} relative overflow-x-auto`}>
        <table className="w-full min-w-[960px] border-collapse text-[13px]">
          <caption className="sr-only">Teacher pay for {monthLabel(month)}</caption>
          <thead>
            <tr className="bg-slate-50 text-left text-slate-700">
              <th className={`${TH} w-10`}>
                <span className="sr-only">Select</span>
              </th>
              <th className={TH}>Teacher</th>
              <th className={`${TH} text-right`}>Hours</th>
              <th className={`${TH} text-right`}>Earned</th>
              <th className={TH}>Penalties</th>
              <th className={`${TH} text-right`}>Pay</th>
              <th className={TH}>Audit</th>
              <th className={TH}>Payment</th>
              <th className={TH}>
                <span className="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {summary.teachers.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-3 py-6 text-center text-slate-600">
                  No teacher audits for {monthLabel(month)} yet.
                </td>
              </tr>
            ) : null}
            {summary.teachers.map((t, i) => {
              const row = teachers[i];
              return (
                <tr key={t.uid} className="border-t border-slate-200">
                  <td className={TD}>{checkbox(row)}</td>
                  <td className={`${TD} font-semibold`}>{t.name}</td>
                  <td className={`${TD} text-right`}>
                    {t.hours} h{t.hours > 0 ? ` × ${money0(t.gross / t.hours)}` : ""}
                  </td>
                  <td className={`${TD} text-right`}>{money(t.gross)}</td>
                  <td className={TD}>{t.penalties > 0 ? <span className="font-bold text-red-700">−{money(t.penalties)}</span> : <span className="text-slate-500">—</span>}</td>
                  <td className={`${TD} text-right font-extrabold`}>{money(t.net)}</td>
                  <td className={TD}>
                    <Badge tone={t.final ? "info" : "warn"}>{t.final ? "Final" : "Estimate"}</Badge>
                  </td>
                  <td className={TD}>{paymentCell(row)}</td>
                  <td className={TD}>{payButton(row)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="mt-2 flex flex-wrap items-center gap-2.5">
        <h2 className="flex-1 text-base font-bold">Administrators</h2>
        <button type="button" className={BTN} disabled={closed} onClick={() => setDialog({ kind: "admin", uid: null })}>
          Add administrator
        </button>
      </div>
      <p className="text-sm text-slate-600">
        Fixed pay, plus a share of what is left after all other costs ({money(Math.max(0, summary.admin_base ?? 0))} for {monthLabel(month)}) for those who have one.
        {summary.final ? "" : " The share is an estimate until every cost for the month is confirmed."}
      </p>
      <div className={`${CARD} relative overflow-x-auto`}>
        <table className="w-full min-w-[980px] border-collapse text-[13px]">
          <caption className="sr-only">Administrator pay for {monthLabel(month)}</caption>
          <thead>
            <tr className="bg-slate-50 text-left text-slate-700">
              <th className={`${TH} w-10`}>
                <span className="sr-only">Select</span>
              </th>
              <th className={TH}>Name</th>
              <th className={TH}>Role</th>
              <th className={`${TH} text-right`}>Fixed</th>
              <th className={`${TH} text-right`}>Profit share</th>
              <th className={`${TH} text-right`}>Pay</th>
              <th className={TH}>Status</th>
              <th className={TH}>Payment</th>
              <th className={TH}>
                <span className="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {summary.admins.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-3 py-6 text-center text-slate-600">
                  No administrators have pay set up. Use Add administrator.
                </td>
              </tr>
            ) : null}
            {summary.admins.map((a, i) => {
              const row = admins[i];
              const t = terms.get(a.uid);
              const open = openPause(t?.pauses);
              const paused = Boolean(a.paused);
              const scheduled = pauseScheduledAfter(open, month);
              // A paused person with a payment on record (older data) still shows it, so it can be voided.
              const hasLivePayout = Boolean(row.payout && !row.payout.voided && row.payout.amount_paid > 0);
              return (
                <tr key={a.uid} className="border-t border-slate-200">
                  <td className={TD}>{checkbox(row)}</td>
                  <td className={`${TD} font-semibold`}>{a.name}</td>
                  <td className={`${TD} text-slate-700`}>{a.role_title || t?.role_title || "Administrator"}</td>
                  <td className={`${TD} text-right`}>{paused ? "—" : money(a.fixed)}</td>
                  <td className={`${TD} text-right`}>{paused ? "—" : a.pct ? `${a.pct}% · ${money(a.share)}` : "None"}</td>
                  <td className={`${TD} text-right font-extrabold`}>{money(paused ? 0 : a.total)}</td>
                  <td className={TD}>{paused ? <Badge tone="mute">Paused</Badge> : <Badge tone={summary.final ? "info" : "warn"}>{summary.final ? "Final" : "Estimate"}</Badge>}</td>
                  <td className={TD}>
                    {paused ? (
                      <div className="flex flex-col items-start gap-1">
                        <span className="font-semibold text-slate-600">{open ? pausedLabel(open) : `Paused · ${a.paused?.reason ?? ""}`}</span>
                        {hasLivePayout ? paymentCell(row) : null}
                      </div>
                    ) : (
                      paymentCell(row)
                    )}
                  </td>
                  <td className={TD}>
                    <div className="flex flex-wrap gap-1.5">
                      {!paused ? payButton(row) : null}
                      <button type="button" className={BTN_SM} disabled={closed} onClick={() => setDialog({ kind: "admin", uid: a.uid })}>
                        Edit pay
                      </button>
                      {open && scheduled ? (
                        <button
                          type="button"
                          className={BTN_SM}
                          disabled={closed || closedMonths.has(open.from_month)}
                          title={closedMonths.has(open.from_month) ? `${monthLabel(open.from_month)} is closed` : undefined}
                          onClick={() => setDialog({ kind: "pause", mode: "resume", uid: a.uid, name: a.name, cancelFrom: open.from_month })}
                        >
                          Cancel pause
                        </button>
                      ) : open ? (
                        <button
                          type="button"
                          className="inline-flex min-h-9 items-center justify-center rounded-lg border border-green-700 bg-white px-3 text-sm font-bold text-green-700 hover:bg-green-50 disabled:opacity-50"
                          disabled={closed}
                          onClick={() => setDialog({ kind: "pause", mode: "resume", uid: a.uid, name: a.name })}
                        >
                          Resume pay
                        </button>
                      ) : (
                        <button type="button" className={BTN_SM} disabled={closed} onClick={() => setDialog({ kind: "pause", mode: "pause", uid: a.uid, name: a.name })}>
                          Pause pay
                        </button>
                      )}
                    </div>
                    {open && scheduled ? <div className="mt-1 text-[11px] font-bold text-slate-600">{scheduledPauseLabel(open)}</div> : null}
                    {deactivated.has(a.uid) ? <div className="mt-1 text-[11px] font-bold text-red-700">Account deactivated</div> : null}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {dialog?.kind === "pay" ? <PayDialog month={month} rows={dialog.rows} usualMethod={usualMethod} onClose={() => setDialog(null)} onDone={done} /> : null}
      {dialog?.kind === "void" ? <VoidDialog month={month} row={dialog.row} onClose={() => setDialog(null)} onDone={done} /> : null}
      {dialog?.kind === "admin" ? (
        <AdminPayDialog
          summary={summary}
          existing={editing ? { uid: editing.uid, name: editing.name, role_title: editing.role_title || terms.get(editing.uid)?.role_title || "Administrator" } : null}
          terms={dialog.uid ? (terms.get(dialog.uid) ?? null) : null}
          closedMonths={closedMonths}
          knownUids={new Set(terms.keys())}
          onClose={() => setDialog(null)}
          onDone={done}
        />
      ) : null}
      {dialog?.kind === "pause" ? (
        <PauseDialog mode={dialog.mode} uid={dialog.uid} name={dialog.name} cancelFrom={dialog.cancelFrom} summaryMonth={month} closedMonths={closedMonths} onClose={() => setDialog(null)} onDone={done} />
      ) : null}
      <Toast message={toast} />
    </section>
  );
}
