"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { money, r2 } from "@/lib/finance/model";
import { monthLabel } from "@/lib/finance/months";
import {
  buildTimeline,
  creditNote,
  draftFromInvoice,
  editPayload,
  evaluateDraft,
  extendAccessTarget,
  formatDay,
  formatMoment,
  historyText,
  invoiceState,
  nextMonthlyInvoice,
  notifyLine,
  previewLine,
  toneFor,
  type EditDraft,
  type Invoice,
  type PaymentLite,
} from "@/lib/finance/invoices";
import {
  callCancelInvoice,
  callEditInvoice,
  callExtendAccess,
  callGetPaymentLink,
  callRecordPayment,
  callSendReminder,
  callSetMonthlyAmount,
  callStopPaymentLink,
  errorMessage,
  loadFamilyBilling,
  loadInvoiceById,
  loadInvoicePayments,
  loadMonthClosed,
  loadNames,
  loadPhone,
  type FamilyBilling,
  type FinanceSettingsView,
} from "./data";
import { Badge, CloseButton, Field, Modal, Notice, blueOutlineButton, dangerButton, inputClass, outlineButton, primaryButton } from "./ui";

const PAY_METHODS: ReadonlyArray<{ value: string; label: string }> = [
  { value: "zelle", label: "Zelle" },
  { value: "cash", label: "Cash" },
  { value: "cash_app", label: "Cash App" },
  { value: "bank_transfer", label: "Bank transfer" },
  { value: "check", label: "Check" },
  { value: "moneygram", label: "MoneyGram" },
  { value: "western_union", label: "Western Union" },
  { value: "other", label: "Other" },
];

type Props = {
  invoiceId: string;
  initial: Invoice | null;
  settings: FinanceSettingsView;
  now: Date;
  onClose: () => void;
  onChanged: (invoice: Invoice) => void;
};

type Message = { tone: "error" | "ok" | "info"; text: string } | null;

export function InvoiceDetail({ invoiceId, initial, settings, now, onClose, onChanged }: Props) {
  const [inv, setInv] = useState<Invoice | null>(initial);
  const [loadError, setLoadError] = useState("");
  const [names, setNames] = useState<Map<string, string>>(new Map());
  const [payments, setPayments] = useState<PaymentLite[]>([]);
  const [billing, setBilling] = useState<FamilyBilling | null>(null);
  const [billingReady, setBillingReady] = useState(false);
  const [setOnNumber, setSetOnNumber] = useState("");
  const [closed, setClosed] = useState(false);
  const [message, setMessage] = useState<Message>(null);
  const [busy, setBusy] = useState("");

  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<EditDraft | null>(null);
  const [newLine, setNewLine] = useState({ description: "", amount: "" });
  const [confirmCancel, setConfirmCancel] = useState(false);

  const [payAmount, setPayAmount] = useState("");
  const [payMethod, setPayMethod] = useState("zelle");

  const [payLink, setPayLink] = useState("");
  const [copied, setCopied] = useState(false);
  const [parentPhone, setParentPhone] = useState("");

  const [planOpen, setPlanOpen] = useState(false);
  const [plan, setPlan] = useState({ amount: "", reason: "" });

  const studentKey = inv?.studentIds.join(",") ?? "";
  const month = inv?.billingMonth ?? null;

  const refresh = useCallback(async () => {
    const fresh = await loadInvoiceById(invoiceId);
    if (!fresh) {
      setLoadError("This invoice no longer exists.");
      return null;
    }
    setInv(fresh);
    onChanged(fresh);
    setPayments(await loadInvoicePayments(invoiceId).catch(() => []));
    return fresh;
  }, [invoiceId, onChanged]);

  // First load: the invoice, its payments, the month lock.
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const fresh = await loadInvoiceById(invoiceId);
        if (!alive) return;
        if (!fresh) {
          setLoadError("This invoice no longer exists.");
          return;
        }
        setInv(fresh);
        const [pay, isClosed] = await Promise.all([loadInvoicePayments(invoiceId).catch(() => []), loadMonthClosed(fresh.billingMonth)]);
        if (!alive) return;
        setPayments(pay);
        setClosed(isClosed);
      } catch (error) {
        if (alive) setLoadError(errorMessage(error, "Could not load this invoice."));
      }
    })();
    return () => {
      alive = false;
    };
  }, [invoiceId]);

  // Names and the family's monthly amount, once the family is known.
  useEffect(() => {
    if (!inv?.parentId) return;
    let alive = true;
    (async () => {
      const map = await loadNames([inv.parentId, ...inv.studentIds]).catch(() => new Map<string, string>());
      if (alive) setNames(new Map(map));
      const phone = await loadPhone(inv.parentId).catch(() => "");
      if (alive) setParentPhone(phone);
      try {
        const b = await loadFamilyBilling(inv.parentId);
        if (!alive) return;
        setBilling(b);
        if (b?.setOnInvoiceId) {
          if (b.setOnInvoiceId === inv.id) setSetOnNumber(inv.number);
          else {
            const source = await loadInvoiceById(b.setOnInvoiceId).catch(() => null);
            if (alive) setSetOnNumber(source?.number ?? "");
          }
        }
      } catch {
        if (alive) setBilling(null);
      } finally {
        if (alive) setBillingReady(true);
      }
    })();
    return () => {
      alive = false;
    };
  }, [inv?.parentId, inv?.id, inv?.number, studentKey]); // eslint-disable-line react-hooks/exhaustive-deps

  const state = useMemo(() => (inv ? invoiceState(inv, now) : null), [inv, now]);

  useEffect(() => {
    if (state && state.owed > 0) setPayAmount(state.owed.toFixed(2));
  }, [state?.owed]); // eslint-disable-line react-hooks/exhaustive-deps

  if (loadError && !inv) {
    return (
      <Modal label="Invoice" onClose={onClose}>
        <div className="flex items-center gap-2">
          <h2 className="flex-1 text-lg font-extrabold">Invoice</h2>
          <CloseButton onClick={onClose} />
        </div>
        <Notice tone="error">{loadError}</Notice>
      </Modal>
    );
  }
  if (!inv || !state) {
    return (
      <Modal label="Invoice" onClose={onClose}>
        <div className="flex items-center gap-2">
          <h2 className="flex-1 text-lg font-extrabold">Loading invoice…</h2>
          <CloseButton onClick={onClose} />
        </div>
      </Modal>
    );
  }

  const parentName = names.get(inv.parentId) || "the family";
  const studentLine = inv.studentIds.map((s) => names.get(s)).filter(Boolean).join(", ");
  const cancelled = state.kind === "cancelled";
  const canEdit = !closed && !cancelled;
  const lockedNote = closed ? `${month ? monthLabel(month) : "This month"} is closed. Reopen it to edit this invoice.` : cancelled ? "This invoice was cancelled." : "";
  const timeline = buildTimeline(inv, payments, parentName, money, now, settings.parent_messages_enabled);
  const history = inv.editHistory.map((h) => historyText(h, money));
  const extendTarget = extendAccessTarget(now);
  const next = nextMonthlyInvoice(now, settings.issue_day, settings.due_day);
  const zelle = settings.zelle_address
    ? `Paying by Zelle? Send to ${settings.zelle_address} and write ${inv.number} in the memo.`
    : `Paying by Zelle? Write ${inv.number} in the memo.`;

  const run = async (name: string, work: () => Promise<void>) => {
    setBusy(name);
    setMessage(null);
    try {
      await work();
    } catch (error) {
      setMessage({ tone: "error", text: errorMessage(error) });
    } finally {
      setBusy("");
    }
  };

  /* ----- payment / reminder / access ----- */
  const payNumber = Number(payAmount);
  const payValid = Number.isFinite(payNumber) && payNumber > 0 && payNumber <= state.owed + 0.005;
  const recordPayment = () =>
    run("pay", async () => {
      await callRecordPayment({ invoiceId: inv.id, amount: r2(payNumber), paymentMethod: payMethod });
      await refresh();
      setMessage({ tone: "ok", text: `${money(r2(payNumber))} recorded.` });
    });
  const sendReminder = () =>
    run("remind", async () => {
      const out = await callSendReminder({ invoice_id: inv.id });
      await refresh();
      setMessage({ tone: out.sent ? "ok" : "info", text: out.sent ? `Reminder sent to ${parentName}.` : `The reminder could not be delivered to ${parentName}. It is recorded in the history.` });
    });
  const extendAccess = () =>
    run("extend", async () => {
      await callExtendAccess({ parentId: inv.parentId, scope: "parent", extendTo: `${extendTarget.key}T12:00:00.000Z` });
      await refresh();
      setMessage({ tone: "ok", text: `Class access is extended to ${extendTarget.label}.` });
    });

  /* ----- payment link ----- */
  const getPayLink = () =>
    run("link", async () => {
      const out = await callGetPaymentLink({ invoiceId: inv.id });
      setPayLink(out.url);
      setCopied(false);
      if (out.reactivated) setMessage({ tone: "info", text: "This invoice's payment link had been stopped. It works again." });
    });
  const copyPayLink = async () => {
    try {
      await navigator.clipboard.writeText(payLink);
      setCopied(true);
    } catch {
      setMessage({ tone: "error", text: "Could not copy. Select the link and copy it by hand." });
    }
  };
  const stopPayLink = () =>
    run("stoplink", async () => {
      await callStopPaymentLink({ invoiceId: inv.id });
      setPayLink("");
      setMessage({ tone: "ok", text: `The payment link for ${inv.number} no longer works.` });
    });
  const waDigits = parentPhone.replace(/\D/g, "");
  const waText = `Assalamu alaikum ${parentName}. Here is the link to pay invoice ${inv.number} (${money(state.owed)}): ${payLink}`;
  const waHref = waDigits.length >= 8 ? `https://wa.me/${waDigits}?text=${encodeURIComponent(waText)}` : `https://wa.me/?text=${encodeURIComponent(waText)}`;

  /* ----- edit ----- */
  const startEdit = () => {
    setDraft(draftFromInvoice(inv));
    setNewLine({ description: "", amount: "" });
    setConfirmCancel(false);
    setEditing(true);
    setMessage(null);
  };
  const stopEdit = () => {
    setEditing(false);
    setDraft(null);
    setConfirmCancel(false);
  };
  const evaluation = draft ? evaluateDraft(inv, draft) : null;
  const setDraftLine = (index: number, patch: Partial<EditDraft["lines"][number]>) =>
    setDraft((d) => (d ? { ...d, lines: d.lines.map((l, i) => (i === index ? { ...l, ...patch } : l)) } : d));
  const addLine = () => {
    const amount = Number(newLine.amount);
    if (!newLine.description.trim() || newLine.amount.trim() === "" || !Number.isFinite(amount)) {
      setMessage({ tone: "error", text: "Add a description and an amount for the new line." });
      return;
    }
    setMessage(null);
    setDraft((d) => (d ? { ...d, lines: [...d.lines, { description: newLine.description.trim(), amount: String(amount), studentId: "" }] } : d));
    setNewLine({ description: "", amount: "" });
  };
  const save = () => {
    if (!draft || !evaluation?.canSave) return;
    return run("save", async () => {
      const out = await callEditInvoice(editPayload(inv, draft));
      stopEdit();
      await refresh();
      setMessage({ tone: "ok", text: out.credit_id ? `Saved. ${money(evaluation.creditBack)} became credit for the ${parentName} family.` : "Saved. The change is in the history." });
    });
  };
  const cancelInvoice = () => {
    if (!draft) return;
    return run("cancel", async () => {
      await callCancelInvoice({ invoice_id: inv.id, reason: draft.reason.trim() });
      stopEdit();
      await refresh();
      setMessage({ tone: "ok", text: `${inv.number} is cancelled.` });
    });
  };

  /* ----- monthly amount ----- */
  const planNumber = Number(plan.amount);
  const planValid = plan.amount.trim() !== "" && Number.isFinite(planNumber) && planNumber > 0 && !!plan.reason.trim() && (!billing || Math.abs(planNumber - billing.monthlyAmount) > 0.004);
  const openPlan = () => {
    setPlan({ amount: billing ? billing.monthlyAmount.toFixed(2) : "", reason: "" });
    setPlanOpen(true);
    setMessage(null);
  };
  const savePlan = () =>
    run("plan", async () => {
      await callSetMonthlyAmount({ parent_id: inv.parentId, monthly_amount: r2(planNumber), reason: plan.reason.trim() });
      setBilling(await loadFamilyBilling(inv.parentId));
      setPlanOpen(false);
      setMessage({ tone: "ok", text: `Monthly amount for ${parentName} is now ${money(r2(planNumber))}.` });
    });

  const planSource = !billing
    ? "The monthly amount is set on a family's first invoice."
    : billing.setOnInvoiceId
      ? `Set on the first invoice ${setOnNumber || ""}${billing.setAt ? ` (${formatMoment(billing.setAt)})` : ""}`.replace(/\s+/g, " ").trim()
      : billing.setAt
        ? `Set ${formatMoment(billing.setAt)}`
        : "Set when the family enrolled";

  return (
    <Modal label={`Invoice ${inv.number}`} onClose={onClose}>
      <div className="flex items-start gap-2.5">
        <div className="min-w-0 flex-1">
          <h2 className="text-xl font-extrabold">{inv.number}</h2>
          <p className="text-[13px] text-slate-600">
            {parentName}
            {month ? ` · for ${monthLabel(month)}` : ""}
            {inv.issuedAt ? ` · issued ${formatMoment(inv.issuedAt)}` : ""}
            {inv.dueKey ? ` · due ${formatDay(inv.dueKey)}` : ""}
          </p>
          {studentLine ? <p className="text-[13px] text-slate-600">{studentLine}</p> : null}
        </div>
        <Badge tone={toneFor(state)}>{state.label}</Badge>
        <CloseButton onClick={onClose} />
      </div>

      {message ? <Notice tone={message.tone}>{message.text}</Notice> : null}

      {!editing ? (
        <>
          <div className="overflow-hidden rounded-lg border border-slate-200">
            {inv.lines.map((l, i) => (
              <div key={`l${i}`} className="flex gap-3 border-b border-slate-200 px-3 py-2.5 text-[13px]">
                <span className="flex-1">{l.description}</span>
                <span className="font-semibold">{money(l.amount)}</span>
              </div>
            ))}
            {inv.discountLines.map((l, i) => (
              <div key={`d${i}`} className="flex gap-3 border-b border-slate-200 px-3 py-2.5 text-[13px] text-green-700">
                <span className="flex-1">{l.description || "Discount"}</span>
                <span className="font-semibold">−{money(l.amount)}</span>
              </div>
            ))}
            <div className="flex bg-slate-50 px-3 py-2.5 font-extrabold">
              <span className="flex-1">Total</span>
              <span>{money(inv.total)}</span>
            </div>
            <div className="flex px-3 py-2.5 text-[13px]">
              <span className="flex-1">Paid</span>
              <span>{money(state.paid)}</span>
            </div>
            <div className="flex px-3 py-2.5 text-[13px] font-extrabold">
              <span className="flex-1">Still owed</span>
              <span>{money(state.owed)}</span>
            </div>
          </div>
          <p className="text-xs text-slate-600">{zelle}</p>
          <div className="flex flex-wrap items-center gap-2">
            {canEdit ? (
              <button type="button" className={blueOutlineButton} onClick={startEdit}>
                Edit invoice
              </button>
            ) : (
              <span className="text-[13px] text-slate-600">{lockedNote}</span>
            )}
          </div>
        </>
      ) : draft && evaluation ? (
        <div className="flex flex-col gap-2.5 rounded-lg border border-blue-300 bg-[#F8FBFF] p-3.5">
          <div className="font-extrabold">Edit invoice</div>
          {draft.lines.map((l, i) => (
            <div key={i} className="flex flex-wrap items-end gap-2">
              <Field label="Line" className="min-w-[200px] flex-[1_1_240px]">
                <input className={inputClass} type="text" value={l.description} onChange={(e) => setDraftLine(i, { description: e.target.value })} />
              </Field>
              <Field label="Amount ($)" className="w-28">
                <input className={inputClass} type="number" inputMode="decimal" step="0.01" min="0" value={l.amount} onChange={(e) => setDraftLine(i, { amount: e.target.value })} />
              </Field>
              <button type="button" className={outlineButton} aria-label={`Remove line ${l.description || i + 1}`} onClick={() => setDraft((d) => (d ? { ...d, lines: d.lines.filter((_, k) => k !== i) } : d))}>
                Remove
              </button>
            </div>
          ))}
          <div className="flex flex-wrap items-end gap-2 border-t border-dashed border-slate-300 pt-2">
            <Field label="New line" className="min-w-[200px] flex-[1_1_240px]">
              <input className={inputClass} type="text" value={newLine.description} placeholder="e.g. Extra class Oct 18, Arabic workbook" onChange={(e) => setNewLine((n) => ({ ...n, description: e.target.value }))} />
            </Field>
            <Field label="Amount ($)" className="w-28">
              <input className={inputClass} type="number" inputMode="decimal" step="0.01" min="0" value={newLine.amount} placeholder="0.00" onChange={(e) => setNewLine((n) => ({ ...n, amount: e.target.value }))} />
            </Field>
            <button type="button" className={blueOutlineButton} onClick={addLine}>
              Add line
            </button>
          </div>
          <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
            <Field label="Discount ($)">
              <input className={inputClass} type="number" inputMode="decimal" step="0.01" min="0" value={draft.discount} onChange={(e) => setDraft({ ...draft, discount: e.target.value })} />
            </Field>
            <Field label="Due date">
              <input className={inputClass} type="date" value={draft.due} onChange={(e) => setDraft({ ...draft, due: e.target.value })} />
            </Field>
          </div>
          <Field label="Reason for the change (required)">
            <input className={inputClass} type="text" value={draft.reason} placeholder="e.g. Schedule changed to 3 classes a week from Oct 15" onChange={(e) => setDraft({ ...draft, reason: e.target.value })} />
          </Field>
          <div className="rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-[13px] font-bold">{previewLine(inv, evaluation, money)}</div>
          {evaluation.creditBack > 0 ? <div className="rounded-lg bg-blue-100 px-3 py-2.5 text-[13px] text-blue-900">{creditNote(parentName, evaluation, money)}</div> : null}
          <div className="text-xs text-slate-600">{notifyLine(parentName, inv.number, evaluation.newTotal, settings.parent_messages_enabled, money)}</div>
          {evaluation.hint ? <div className="text-xs font-semibold text-amber-800">{evaluation.hint}</div> : null}
          {confirmCancel ? (
            <div className="flex flex-col gap-2 rounded-lg border border-red-300 bg-red-50 p-3 text-[13px] text-red-900">
              <span>
                Cancel {inv.number}? Nobody will be asked to pay it, and its payment link stops working. Reason: “{draft.reason.trim()}”.
              </span>
              <div className="flex flex-wrap gap-2">
                <button type="button" className={dangerButton} disabled={busy !== ""} onClick={cancelInvoice}>
                  {busy === "cancel" ? "Cancelling…" : "Yes, cancel invoice"}
                </button>
                <button type="button" className={outlineButton} onClick={() => setConfirmCancel(false)}>
                  Keep the invoice
                </button>
              </div>
            </div>
          ) : null}
          <div className="flex flex-wrap gap-2">
            <button type="button" className={primaryButton} disabled={!evaluation.canSave || busy !== ""} onClick={save}>
              {busy === "save" ? "Saving…" : "Save changes"}
            </button>
            <button type="button" className={outlineButton} onClick={stopEdit}>
              Discard
            </button>
            <div className="flex-1" />
            {evaluation.canCancel ? (
              <button type="button" className={dangerButton} disabled={!draft.reason.trim() || busy !== ""} onClick={() => setConfirmCancel(true)}>
                Cancel invoice
              </button>
            ) : null}
          </div>
          {evaluation.canCancel && !draft.reason.trim() ? <div className="text-xs text-slate-600">Add a reason above to cancel this invoice.</div> : null}
        </div>
      ) : null}

      {/* Monthly amount */}
      {!editing ? (
        <div className="flex flex-col gap-2 rounded-lg border border-slate-200 bg-slate-50 p-3">
          <div className="flex flex-col items-start gap-2 sm:flex-row sm:items-center">
            <div className="min-w-0 flex-1">
              <div className="text-xs font-semibold text-slate-600">Monthly amount for this family</div>
              <div className="text-lg font-extrabold">{billing ? `${money(billing.monthlyAmount)} a month` : billingReady ? "Not set yet" : "…"}</div>
              {billingReady ? (
                <div className="text-xs text-slate-600">
                  {planSource}
                  {billing ? ` · Next invoice: issued ${formatDay(next.issueKey)} · due ${formatDay(next.dueKey)} · ${money(billing.monthlyAmount)}` : ""}
                </div>
              ) : null}
            </div>
            {!planOpen && billingReady ? (
              <button type="button" className={`${outlineButton} shrink-0`} onClick={openPlan}>
                {billing ? "Change monthly amount" : "Set monthly amount"}
              </button>
            ) : null}
          </div>
          {planOpen ? (
            <>
              <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
                <Field label="New monthly amount ($)">
                  <input className={inputClass} type="number" inputMode="decimal" step="0.01" min="0" value={plan.amount} onChange={(e) => setPlan({ ...plan, amount: e.target.value })} />
                </Field>
                <Field label="Reason (required)">
                  <input className={inputClass} type="text" value={plan.reason} placeholder="e.g. Now 3 classes a week" onChange={(e) => setPlan({ ...plan, reason: e.target.value })} />
                </Field>
              </div>
              {Number.isFinite(planNumber) && plan.amount.trim() !== "" ? (
                <div className="text-[13px] text-slate-700">
                  {`From the ${monthLabel(next.month)} invoice (issued ${formatDay(next.issueKey)}): ${billing ? `${money(billing.monthlyAmount)} → ` : ""}${money(planNumber)} a month. Invoices already sent stay as they are.`}
                </div>
              ) : null}
              <div className="flex gap-2">
                <button type="button" className={primaryButton} disabled={!planValid || busy !== ""} onClick={savePlan}>
                  {busy === "plan" ? "Saving…" : "Save monthly amount"}
                </button>
                <button type="button" className={outlineButton} onClick={() => setPlanOpen(false)}>
                  Cancel
                </button>
              </div>
            </>
          ) : null}
          {billing && billing.history.length > 0 ? (
            <ul className="flex flex-col gap-0.5 text-xs text-slate-700">
              {billing.history.map((h, i) => (
                <li key={i}>
                  • {formatMoment(h.at)} — {h.oldAmount !== null ? `${money(h.oldAmount)} → ` : ""}
                  {money(h.newAmount)} a month{h.fromMonth ? ` from ${monthLabel(h.fromMonth)}` : ""}
                  {h.reason ? ` · “${h.reason}”` : ""}
                </li>
              ))}
            </ul>
          ) : null}
        </div>
      ) : null}

      {history.length > 0 ? (
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-bold">Change history</div>
          <ul className="flex flex-col gap-1 text-[13px] text-slate-700">
            {history.map((t, i) => (
              <li key={i}>• {t}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="flex flex-col gap-1.5">
        <div className="text-[13px] font-bold">Reminders &amp; access</div>
        <ul className="flex flex-col gap-1 text-[13px] text-slate-700">
          {timeline.entries.map((t, i) => (
            <li key={i}>• {t}</li>
          ))}
        </ul>
        {timeline.access ? <div className={`text-[13px] font-bold ${timeline.access.tone === "bad" ? "text-red-700" : "text-blue-800"}`}>{timeline.access.text}</div> : null}
      </div>

      {!editing && !cancelled && state.owed > 0.004 ? (
        <div className="flex flex-col gap-2 rounded-lg border border-slate-200 p-3">
          <div className="text-[13px] font-bold">Payment link</div>
          <div className="text-xs text-slate-600">
            The parent opens the link and pays {money(state.owed)} by card. The invoice is marked paid as soon as the payment goes through. The link keeps working until the invoice is paid or you stop it.
          </div>
          {payLink ? (
            <>
              <input className={`${inputClass} font-mono text-xs`} readOnly value={payLink} aria-label="Payment link" onFocus={(e) => e.currentTarget.select()} />
              <div className="flex flex-wrap gap-2">
                <button type="button" className={primaryButton} onClick={copyPayLink}>
                  {copied ? "Copied" : "Copy link"}
                </button>
                <a className={outlineButton} href={waHref} target="_blank" rel="noopener noreferrer">
                  {waDigits.length >= 8 ? `Send on WhatsApp to ${parentPhone}` : "Send on WhatsApp"}
                </a>
                <div className="flex-1" />
                <button type="button" className={outlineButton} disabled={busy !== ""} onClick={stopPayLink}>
                  {busy === "stoplink" ? "Stopping…" : "Stop link"}
                </button>
              </div>
            </>
          ) : (
            <div>
              <button type="button" className={blueOutlineButton} disabled={busy !== ""} onClick={getPayLink}>
                {busy === "link" ? "Getting link…" : "Get payment link"}
              </button>
            </div>
          )}
        </div>
      ) : null}

      {!editing && !cancelled && state.owed > 0.004 ? (
        <div className="flex flex-wrap items-end gap-2.5 border-t border-slate-200 pt-2">
          <Field label="Payment received ($)" className="w-32">
            <input className={inputClass} type="number" inputMode="decimal" step="0.01" min="0" value={payAmount} onChange={(e) => setPayAmount(e.target.value)} />
          </Field>
          <Field label="How" className="w-44">
            <select className={inputClass} value={payMethod} onChange={(e) => setPayMethod(e.target.value)}>
              {PAY_METHODS.map((m) => (
                <option key={m.value} value={m.value}>
                  {m.label}
                </option>
              ))}
            </select>
          </Field>
          <button type="button" className={primaryButton} disabled={!payValid || busy !== ""} onClick={recordPayment}>
            {busy === "pay" ? "Recording…" : "Record payment"}
          </button>
          {settings.parent_messages_enabled ? (
            <button type="button" className={outlineButton} disabled={busy !== ""} onClick={sendReminder}>
              {busy === "remind" ? "Sending…" : "Send reminder now"}
            </button>
          ) : null}
          {state.late ? (
            <button type="button" className={outlineButton} disabled={busy !== ""} onClick={extendAccess}>
              {busy === "extend" ? "Extending…" : `Extend access to ${extendTarget.label}`}
            </button>
          ) : null}
        </div>
      ) : null}
      {!editing && !cancelled && state.owed > 0.004 && payAmount.trim() !== "" && !payValid ? <div className="text-xs font-semibold text-amber-800">The payment must be more than $0 and no more than {money(state.owed)}.</div> : null}
    </Modal>
  );
}
