"use client";

import { useMemo, useState } from "react";
import { money, r2 } from "@/lib/finance/model";
import { monthLabel } from "@/lib/finance/months";
import { PAY_METHODS, amountLeft, shortDate, splitFee, todayNy, type PayableRow } from "@/lib/finance/staff";
import { BTN, BTN_PRIMARY, ErrorText, Field, INPUT, Modal, callFinance } from "./staffUi";

type Props = {
  month: string;
  rows: PayableRow[];
  usualMethod: Map<string, string>;
  onClose: () => void;
  onDone: (message: string) => void;
};

const USUAL = "usual";

/**
 * Marks one person (editable amount, reference, note) or a whole batch as paid.
 * A batch shares one date and method and splits an optional fee evenly.
 */
export function PayDialog({ month, rows, usualMethod, onClose, onDone }: Props) {
  const single = rows.length === 1 ? rows[0] : null;
  const knownUsual = rows.filter((r) => usualMethod.has(r.uid)).length;
  const [date, setDate] = useState(todayNy());
  const [method, setMethod] = useState<string>(single ? (usualMethod.get(single.uid) ?? PAY_METHODS[0]) : knownUsual > 0 ? USUAL : PAY_METHODS[0]);
  const [amount, setAmount] = useState(single ? amountLeft(single.due, single.payout).toFixed(2) : "");
  const [fee, setFee] = useState("");
  const [reference, setReference] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const total = useMemo(() => r2(rows.reduce((s, r) => s + amountLeft(r.due, r.payout), 0)), [rows]);
  const missingUsual = method === USUAL ? rows.filter((r) => !usualMethod.has(r.uid)) : [];
  const amountNum = Number(amount);
  const feeNum = fee.trim() === "" ? 0 : Number(fee);
  const feeBad = !Number.isFinite(feeNum) || feeNum < 0;
  const amountBad = single ? !(amountNum > 0) || !Number.isFinite(amountNum) : false;
  const left = single ? amountLeft(single.due, single.payout) : 0;

  const submit = async () => {
    setError("");
    if (feeBad) return setError("The transfer fee cannot be negative.");
    if (single && amountBad) return setError("Enter the amount paid.");
    if (missingUsual.length) return setError(`Choose how to send ${missingUsual.map((r) => r.name).join(", ")}.`);
    const fees = single ? [feeNum] : splitFee(feeNum, rows.length);
    const entries = rows.map((r, i) => ({
      uid: r.uid,
      role: r.role,
      amount_paid: single ? r2(amountNum) : amountLeft(r.due, r.payout),
      ...(r.role === "admin" ? { amount_due: r.due } : {}),
      method: method === USUAL ? (usualMethod.get(r.uid) as string) : method,
      date_paid: date,
      transfer_fee: fees[i],
      ...(single && reference.trim() ? { reference: reference.trim() } : {}),
      ...(single && note.trim() ? { note: note.trim() } : {}),
    }));
    setBusy(true);
    try {
      await callFinance("recordStaffPayouts", { month, entries });
      onDone(single ? `${single.name} marked paid · ${money(amountNum)}` : `${rows.length} marked paid · ${money(total)}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save.");
      setBusy(false);
    }
  };

  return (
    <Modal title={single ? `Pay ${single.name}` : `Mark ${rows.length} as paid`} onClose={onClose} wide>
      {single ? (
        <p className="text-sm text-slate-700">
          {monthLabel(month)}: owed <strong>{money(single.due)}</strong>
          {single.payout && !single.payout.voided ? `, already paid ${money(single.payout.amount_paid)}` : ""}. {left > 0 ? `${money(left)} left.` : ""}
        </p>
      ) : (
        <p className="text-sm text-slate-700">
          Total sent: <strong>{money(total)}</strong> for {monthLabel(month)}.
        </p>
      )}
      <div className="grid gap-3 sm:grid-cols-2">
        {single ? (
          <Field label="Amount paid ($)" hint={amountNum > 0 && amountNum + 0.004 < left ? `Part payment: ${money(r2(left - amountNum))} will still be owed.` : undefined}>
            <input className={INPUT} type="number" inputMode="decimal" min="0" step="0.01" value={amount} onChange={(e) => setAmount(e.target.value)} />
          </Field>
        ) : null}
        <Field label="Date paid">
          <input className={INPUT} type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </Field>
        <Field label="How it was sent">
          <select className={INPUT} value={method} onChange={(e) => setMethod(e.target.value)}>
            {!single && knownUsual > 0 ? <option value={USUAL}>Each person&apos;s usual method (same as last month)</option> : null}
            {PAY_METHODS.map((m) => (
              <option key={m} value={m}>
                {m}
              </option>
            ))}
          </select>
        </Field>
        <Field label={single ? "Transfer fee, optional ($)" : "Transfer fees for this batch, optional ($)"}>
          <input className={INPUT} type="number" inputMode="decimal" min="0" step="0.01" placeholder="0.00" value={fee} onChange={(e) => setFee(e.target.value)} />
        </Field>
      </div>
      {single ? (
        <>
          <Field label="Reference (transaction id), optional">
            <input className={INPUT} type="text" maxLength={120} value={reference} onChange={(e) => setReference(e.target.value)} />
          </Field>
          <Field label="Note, optional">
            <input className={INPUT} type="text" maxLength={300} value={note} onChange={(e) => setNote(e.target.value)} />
          </Field>
        </>
      ) : (
        <>
          {feeNum > 0 && !feeBad ? <p className="text-xs text-slate-600">{money(feeNum)} is shared evenly: about {money(splitFee(feeNum, rows.length)[0])} each.</p> : null}
          {missingUsual.length ? <p className="text-xs text-amber-800">No usual method yet for {missingUsual.map((r) => r.name).join(", ")}. Choose one method for everyone.</p> : null}
        </>
      )}
      <p className="text-xs text-slate-600">Fees are paid by Alluwal and count under Transfer fees. {single ? `Paid on ${shortDate(date)}.` : ""}</p>
      <ErrorText message={error} />
      <div className="flex gap-2">
        <button type="button" className={BTN_PRIMARY} disabled={busy} onClick={submit}>
          {busy ? "Saving…" : "Mark as paid"}
        </button>
        <button type="button" className={BTN} onClick={onClose}>
          Cancel
        </button>
      </div>
    </Modal>
  );
}

export function VoidDialog({ month, row, onClose, onDone }: { month: string; row: PayableRow; onClose: () => void; onDone: (m: string) => void }) {
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const submit = async () => {
    if (!reason.trim()) return setError("Say why this payment is being voided.");
    setBusy(true);
    try {
      await callFinance("voidStaffPayout", { month, uid: row.uid, reason: reason.trim() });
      onDone(`Payment to ${row.name} voided`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not void.");
      setBusy(false);
    }
  };
  return (
    <Modal title={`Void payment to ${row.name}`} onClose={onClose}>
      <p className="text-sm text-slate-700">
        This takes the {money(row.payout?.amount_paid ?? 0)} payment for {monthLabel(month)} back. It stays in the history, marked void, and {row.name} shows as unpaid again.
      </p>
      <Field label="Reason (required)">
        <input className={INPUT} type="text" maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. Sent to the wrong number" />
      </Field>
      <ErrorText message={error} />
      <div className="flex gap-2">
        <button type="button" className={BTN_PRIMARY} disabled={busy || !reason.trim()} onClick={submit}>
          {busy ? "Saving…" : "Void payment"}
        </button>
        <button type="button" className={BTN} onClick={onClose}>
          Keep it
        </button>
      </div>
    </Modal>
  );
}
