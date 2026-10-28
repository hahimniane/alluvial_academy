"use client";

import { useMemo, useState } from "react";
import { money } from "@/lib/finance/model";
import { monthLabel } from "@/lib/finance/months";
import { extendAccessTarget, formatDay, invoiceState, toneFor, type CutOffStudent } from "@/lib/finance/invoices";
import { callExtendAccess, errorMessage } from "./data";
import { Badge, Field, Notice, inputClass, outlineButton } from "./ui";

/**
 * Students who cannot join classes because of unpaid invoices, each with every
 * invoice that keeps them out - from any month - so staff see the whole
 * picture for a family before they call, extend access or send a link.
 */
export function CutOffPanel({
  rows,
  names,
  phones,
  now,
  loading,
  error,
  onOpenInvoice,
  onChanged,
}: {
  rows: CutOffStudent[];
  names: Map<string, string>;
  phones: Map<string, string>;
  now: Date;
  loading: boolean;
  error: string;
  onOpenInvoice: (invoiceId: string) => void;
  onChanged: () => void;
}) {
  const [q, setQ] = useState("");
  const [busyParent, setBusyParent] = useState("");
  const [message, setMessage] = useState<{ tone: "ok" | "error"; text: string } | null>(null);
  const extendTarget = extendAccessTarget(now);

  const view = useMemo(() => {
    const needle = q.trim().toLowerCase();
    const digits = needle.replace(/\D/g, "");
    if (!needle) return rows;
    return rows.filter((r) => {
      const family = names.get(r.parentId) ?? "";
      const phone = (phones.get(r.parentId) ?? "").replace(/\D/g, "");
      return (
        r.name.toLowerCase().includes(needle) ||
        family.toLowerCase().includes(needle) ||
        (digits.length >= 3 && phone.includes(digits)) ||
        r.invoices.some((h) => h.inv.number.toLowerCase().includes(needle))
      );
    });
  }, [rows, q, names, phones]);

  // An invoice for the whole family keeps every child out; count its money once.
  const owedTotal = [...new Map(view.flatMap((r) => r.invoices.map((h) => [h.inv.id, h.owed] as const))).values()].reduce((sum, v) => sum + v, 0);
  const families = new Set(view.filter((r) => r.invoices.length).map((r) => r.parentId)).size;
  const multi = view.filter((r) => r.invoices.length > 1).length;

  const extend = async (parentId: string) => {
    setBusyParent(parentId);
    setMessage(null);
    try {
      const result = await callExtendAccess({ parentId, scope: "parent", extendTo: `${extendTarget.key}T12:00:00.000Z` });
      setMessage({
        tone: "ok",
        text: `${names.get(parentId) || "The family"}'s class access is extended to ${extendTarget.label}${result.updatedInvoices > 1 ? ` on ${result.updatedInvoices} invoices` : ""}.`,
      });
      onChanged();
    } catch (e) {
      setMessage({ tone: "error", text: errorMessage(e, "Could not extend class access.") });
    } finally {
      setBusyParent("");
    }
  };

  if (error) return <Notice tone="error">{error}</Notice>;
  if (loading) return <p className="rounded-xl border border-slate-200 bg-white p-6 text-center text-slate-600">Loading cut-off students…</p>;

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-end gap-3 rounded-xl border border-slate-200 bg-white p-3.5">
        <div className="min-w-0 flex-1">
          <div className="text-lg font-extrabold">
            {view.length} {view.length === 1 ? "student" : "students"} cut off from classes
          </div>
          <div className="text-[13px] text-slate-600">
            {money(owedTotal)} owed by {families} {families === 1 ? "family" : "families"}{multi ? ` · ${multi} students blocked by more than one invoice` : ""}. A student is cut off the day after an invoice is due until it is paid or access is extended.
          </div>
        </div>
        <Field label="Search" className="w-full sm:w-72">
          <input className={inputClass} type="text" value={q} placeholder="Student, family, WhatsApp or invoice #" onChange={(e) => setQ(e.target.value)} />
        </Field>
      </div>

      {message ? <Notice tone={message.tone}>{message.text}</Notice> : null}

      {view.length === 0 ? (
        <p className="rounded-xl border border-slate-200 bg-white p-6 text-center text-slate-600">{rows.length ? "No cut-off student matches this search." : "No student is cut off from classes."}</p>
      ) : (
        <ul className="flex flex-col gap-2.5">
          {view.map((r) => {
            const family = names.get(r.parentId) || "";
            const phone = phones.get(r.parentId) || "";
            return (
              <li key={r.studentId} className="flex flex-col gap-2 rounded-xl border border-slate-200 bg-white p-3.5">
                <div className="flex flex-wrap items-start gap-2">
                  <div className="min-w-0 flex-1">
                    <div className="font-extrabold">{r.name}</div>
                    <div className="text-[13px] text-slate-600">
                      {family ? `Family: ${family}` : "No family on file"}
                      {phone ? ` · ${phone}` : ""}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-extrabold text-red-700">{money(r.owed)}</div>
                    <div className="text-xs text-slate-600">{r.sinceKey ? `Cut off since ${formatDay(r.sinceKey)}` : "No unpaid invoice found"}</div>
                  </div>
                </div>

                {r.invoices.length ? (
                  <div className="overflow-hidden rounded-lg border border-slate-200">
                    {r.invoices.map(({ inv, owed, cutoffKey }) => {
                      const state = invoiceState(inv, now);
                      return (
                        <div key={inv.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 border-b border-slate-200 px-3 py-2 text-[13px] last:border-b-0">
                          <span className="font-semibold">{inv.number}</span>
                          <span className="text-slate-600">{inv.billingMonth ? monthLabel(inv.billingMonth) : inv.dueKey ? `due ${formatDay(inv.dueKey)}` : ""}</span>
                          <Badge tone={toneFor(state)}>{state.label}</Badge>
                          <span className="text-slate-600">blocking since {formatDay(cutoffKey)}</span>
                          <span className="flex-1" />
                          <span className="font-semibold">{money(owed)}</span>
                          <button type="button" className="text-[13px] font-semibold text-[#0386FF] hover:underline" onClick={() => onOpenInvoice(inv.id)}>
                            Open
                          </button>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <p className="text-[13px] text-amber-800">The app has this student cut off, but no unpaid invoice past its date was found. Check the family&apos;s invoices.</p>
                )}

                {r.invoices.length ? (
                  <div className="flex flex-wrap gap-2">
                    <button type="button" className={outlineButton} disabled={busyParent !== ""} onClick={() => extend(r.parentId)}>
                      {busyParent === r.parentId ? "Extending…" : `Extend access to ${extendTarget.label}`}
                    </button>
                    <span className="self-center text-xs text-slate-600">Open an invoice to record a payment or send its payment link.</span>
                  </div>
                ) : null}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
