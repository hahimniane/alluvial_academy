"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { AlertCircle, CalendarDays, CircleUser, CreditCard, FileText, Info, ListChecks, Loader2, Mail, Phone, Settings, User, UserCog } from "lucide-react";
import { useParentSession } from "@/components/ParentArea";
import { ParentAppBar, alpha, useNow } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import { COMPANY_INFO, invoicePdfBytes } from "@/lib/invoicePdf";
import { billingPeriod, formatMoney, invoiceOverdue, invoiceRemaining, PAYMENT_DOT, paymentSubtitle, type ParentInvoice, type ParentPayment } from "@/lib/parentHome";
import {
  amountDueColor,
  decisionActorName,
  decisionTechnicalDetails,
  detailPayButton,
  detailStatus,
  invoicePdfFileName,
  personName,
  sheetStatus,
  sortPaymentsNewestFirst,
  type DecisionActor,
} from "@/lib/parentMoney";
import { fetchUserData, resolveCreator, watchInvoice, watchInvoicePayments } from "@/lib/parentMoneyData";
import { parentMoneyText, type ParentMoneyText } from "@/lib/parentMoneyText";
import { PARENT_ROUTES } from "@/lib/parentWeb";

type Load<T> = { state: "loading" } | { state: "error" } | { state: "missing" } | { state: "ready"; value: T };

/**
 * Invoice Details (InvoiceDetailScreen + BeautifulInvoiceWidget, B-029…B-057).
 * Pushed over the shell. Unlike Flutter the invoice is live, so the totals,
 * status and Pay button follow a payment without reopening the page.
 */
export default function ParentInvoiceDetailPage() {
  const session = useParentSession();
  const router = useRouter();
  const id = useSearchParams()?.get("id") ?? "";
  const fr = useLocale() === "fr";
  const text = parentMoneyText(fr);
  const now = useNow();
  const [invoice, setInvoice] = useState<Load<ParentInvoice>>({ state: "loading" });
  const [names, setNames] = useState<{ parent: string | null; student: string | null } | null>(null);
  const [printing, setPrinting] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  useEffect(() => {
    if (!id) {
      setInvoice({ state: "missing" });
      return;
    }
    return watchInvoice(
      id,
      (value) => setInvoice(value ? { state: "ready", value } : { state: "missing" }),
      () => setInvoice({ state: "error" }),
    );
  }, [id]);

  // BILLED TO names, with Flutter's 15-second cap.
  const parentId = invoice.state === "ready" ? invoice.value.parentId : null;
  const studentId = invoice.state === "ready" ? invoice.value.studentId : null;
  useEffect(() => {
    if (parentId === null || studentId === null) return;
    let active = true;
    const timeout = new Promise<[null, null]>((resolve) => window.setTimeout(() => resolve([null, null]), 15_000));
    void Promise.race([Promise.all([fetchUserData(parentId).then(personName), fetchUserData(studentId).then(personName)]), timeout]).then(([parent, student]) => {
      if (active) setNames({ parent, student });
    });
    return () => {
      active = false;
    };
  }, [parentId, studentId]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 4000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const printPdf = async (value: ParentInvoice) => {
    setPrinting(true);
    try {
      const [parent, student] = await Promise.all([fetchUserData(value.parentId).then(personName), fetchUserData(value.studentId).then(personName)]);
      const bytes = invoicePdfBytes({ invoice: value, parentName: parent, studentName: student });
      openPrintDialog(bytes, invoicePdfFileName(value));
    } catch {
      setToast(text.pdfFailed);
    } finally {
      setPrinting(false);
    }
  };

  return (
    <div className="flex min-h-full flex-col bg-[#F8FAFC]">
      <ParentAppBar title={text.invoiceDetails} backHref={PARENT_ROUTES.invoices} backLabel={text.back} />
      {invoice.state === "loading" ? (
        <div className="grid flex-1 place-items-center py-16" role="status" aria-label={text.loading}>
          <Loader2 size={36} className="animate-spin text-[#0386FF]" />
        </div>
      ) : invoice.state !== "ready" ? (
        <p className="p-6 text-center font-semibold text-[#6B7280]" role="alert">
          {invoice.state === "missing" ? text.invoiceNotFound : text.invoiceLoadFailed}
        </p>
      ) : (
        <InvoiceDetailBody
          invoice={invoice.value}
          uid={session.uid}
          now={now}
          names={names}
          text={text}
          fr={fr}
          printing={printing}
          onPay={() => router.push(PARENT_ROUTES.pay(invoice.value.id))}
          onPrint={() => void printPdf(invoice.value)}
        />
      )}
      {printing ? (
        <div className="fixed inset-0 z-[110] grid place-items-center bg-black/40" role="status" aria-label={text.loading}>
          <Loader2 size={36} className="animate-spin text-white" />
        </div>
      ) : null}
      {toast ? (
        <div role="alert" className="fixed bottom-6 left-1/2 z-[120] -translate-x-1/2 rounded-xl bg-[#F44336] px-4 py-3 text-sm font-medium text-white shadow-xl">
          {toast}
        </div>
      ) : null}
    </div>
  );
}

/**
 * B-046: on the web Flutter hands the PDF to the browser's print dialog, where
 * the parent prints or saves it. A hidden frame does the same; if the browser
 * will not print from a frame, the PDF opens in a new tab instead.
 */
function openPrintDialog(bytes: Uint8Array, fileName: string) {
  const blob = new Blob([bytes as BlobPart], { type: "application/pdf" });
  const url = URL.createObjectURL(blob);
  const frame = document.createElement("iframe");
  frame.style.position = "fixed";
  frame.style.width = "0";
  frame.style.height = "0";
  frame.style.border = "0";
  frame.title = fileName;
  frame.src = url;
  frame.onload = () => {
    try {
      frame.contentWindow?.focus();
      frame.contentWindow?.print();
    } catch {
      window.open(url, "_blank", "noopener");
    }
    window.setTimeout(() => {
      frame.remove();
      URL.revokeObjectURL(url);
    }, 60_000);
  };
  document.body.appendChild(frame);
}

function InvoiceDetailBody({
  invoice,
  uid,
  now,
  names,
  text,
  fr,
  printing,
  onPay,
  onPrint,
}: {
  invoice: ParentInvoice;
  uid: string;
  now: Date;
  names: { parent: string | null; student: string | null } | null;
  text: ParentMoneyText;
  fr: boolean;
  printing: boolean;
  onPay: () => void;
  onPrint: () => void;
}) {
  const status = detailStatus(invoice, now);
  const pay = detailPayButton(invoice);
  return (
    <div className="pt-4 pb-8">
      <div className="flex gap-3 px-4">
        <button
          type="button"
          disabled={!pay.enabled}
          onClick={onPay}
          className="flex min-h-12 flex-1 items-center justify-center gap-2 rounded-xl bg-[#0386FF] px-3 py-3 text-sm font-extrabold text-white hover:bg-[#0276E0] disabled:bg-[#E5E7EB] disabled:text-[#9CA3AF]"
        >
          <CreditCard size={18} />
          {pay.paid ? text.paid : text.payInvoice}
        </button>
        <button
          type="button"
          onClick={onPrint}
          disabled={printing}
          className="flex min-h-12 flex-1 items-center justify-center gap-2 rounded-xl border border-[#E5E7EB] bg-transparent px-3 py-3 text-sm font-bold text-[#111827] hover:bg-black/[0.03]"
        >
          <FileText size={18} />
          {text.downloadPdf}
        </button>
      </div>
      <div className="mt-4 px-4">
        <span className="inline-block rounded-full px-3 py-2 text-xs font-extrabold tracking-[0.3px]" style={{ color: status.color, backgroundColor: alpha(status.color, 0.12) }}>
          {status.label}
        </span>
      </div>
      <div className="mt-4">
        <InvoiceSheet invoice={invoice} now={now} names={names} text={text} />
      </div>
      <div className="mt-[18px] px-4">
        <DecisionHistory invoice={invoice} text={text} fr={fr} />
      </div>
      <div className="mt-[18px] px-4">
        <h2 className="text-[15px] font-extrabold text-[#111827]">{text.payments}</h2>
        <div className="mt-2.5">
          <InvoicePayments invoice={invoice} uid={uid} text={text} />
        </div>
      </div>
    </div>
  );
}

// ─── The invoice sheet (BeautifulInvoiceWidget) ────────────────────────────

function InvoiceSheet({ invoice, now, names, text }: { invoice: ParentInvoice; now: Date; names: { parent: string | null; student: string | null } | null; text: ParentMoneyText }) {
  const number = invoice.invoiceNumber || invoice.id;
  const badge = sheetStatus(invoice, now);
  const period = billingPeriod(invoice);
  const overdue = invoiceOverdue(invoice, now);
  const dueColor = amountDueColor(invoice, now);
  const money = (n: number) => formatMoney(n, invoice.currency);
  const shortDate = (d: Date) => d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  const meta: Array<[string, string, string]> = [
    ["Invoice #", number, "#111827"],
    [text.issueDate, shortDate(invoice.issuedDate), "#111827"],
    [text.dueDate, shortDate(invoice.dueDate), overdue ? "#DC2626" : "#111827"],
  ];
  return (
    <div className="@container">
      <div className="px-3.5 py-3 @min-[560px]:px-6">
      <article className="overflow-hidden rounded-2xl border border-[#E5E7EB] bg-white shadow-[0_6px_20px_rgba(0,0,0,0.06)]">
        <div className="h-[5px] bg-gradient-to-r from-[#1A56DB] to-[#0EA5E9]" />
        <div className="px-5 pt-6 pb-5 @min-[560px]:px-8 @min-[560px]:pt-8 @min-[560px]:pb-7">
          <div className="flex items-start gap-3.5">
            <span className="grid h-16 w-16 shrink-0 place-items-center overflow-hidden rounded-[14px] border-[1.5px] border-[#BFDBFE] bg-white p-1.5 shadow-[0_3px_10px_rgba(26,86,219,0.08)]">
              <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="" className="h-full w-full object-contain" />
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-base font-extrabold tracking-[-0.2px] text-[#111827]">{COMPANY_INFO.name}</p>
              <p className="mt-0.5 text-xs text-[#6B7280]">{COMPANY_INFO.email}</p>
            </div>
            <div className="flex shrink-0 flex-col items-end">
              <p className="text-[22px] font-black tracking-[1.5px] text-[#1A56DB]">INVOICE</p>
              <span
                className="mt-1 rounded-[20px] border px-2.5 py-1 text-[11px] font-extrabold tracking-[0.8px]"
                style={{ color: badge.color, backgroundColor: alpha(badge.color, 0.1), borderColor: alpha(badge.color, 0.35) }}
              >
                {badge.label}
              </span>
            </div>
          </div>

          <hr className="mt-7 border-[#E5E7EB]" />
          <div className="mt-6 grid gap-5 @min-[560px]:grid-cols-2 @min-[560px]:gap-6">
            <div>
              <SectionLabel>FROM</SectionLabel>
              <p className="mt-2.5 text-sm font-bold text-[#111827]">{COMPANY_INFO.name}</p>
              <p className="mt-1 text-[13px] leading-normal text-[#6B7280]">{COMPANY_INFO.fullAddress}</p>
              <p className="mt-1.5 flex items-center gap-[5px] text-xs text-[#6B7280]">
                <Phone size={13} className="text-[#9CA3AF]" />
                {COMPANY_INFO.phone}
              </p>
              <p className="mt-[3px] flex items-center gap-[5px] text-xs text-[#6B7280]">
                <Mail size={13} className="text-[#9CA3AF]" />
                {COMPANY_INFO.email}
              </p>
            </div>
            <div>
              <SectionLabel>BILLED TO</SectionLabel>
              {names === null ? (
                <div className="mt-2.5" aria-label={text.loading}>
                  <span className="block h-3.5 w-[120px] rounded-[7px] bg-[#E5E7EB]" />
                  <span className="mt-1.5 block h-3.5 w-20 rounded-[7px] bg-[#E5E7EB]" />
                </div>
              ) : (
                <>
                  <p className="mt-2.5 text-sm font-bold text-[#111827]">{names.parent ?? text.parentFallback}</p>
                  {names.student ? (
                    <p className="mt-1 flex items-center gap-[5px] text-[13px] text-[#6B7280]">
                      <User size={14} />
                      {names.student}
                    </p>
                  ) : null}
                </>
              )}
              {period ? (
                <p className="mt-1.5 flex items-center gap-[5px] text-[13px] font-semibold text-[#1A56DB]">
                  <CalendarDays size={14} />
                  {period}
                </p>
              ) : null}
            </div>
          </div>

          <hr className="mt-6 border-[#E5E7EB]" />
          <div className="mt-[22px] rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-4 @min-[560px]:flex @min-[560px]:px-5 @min-[560px]:py-4">
            {meta.map(([label, value, color], i) => (
              <div key={label} className={`flex items-center justify-between @min-[560px]:block @min-[560px]:min-w-0 @min-[560px]:flex-1 ${i > 0 ? "mt-2.5 border-t border-[#E5E7EB] pt-2.5 @min-[560px]:mt-0 @min-[560px]:ml-4 @min-[560px]:border-t-0 @min-[560px]:border-l @min-[560px]:pt-0 @min-[560px]:pl-4" : ""}`}>
                <p className="text-xs font-medium text-[#6B7280] @min-[560px]:text-[11px] @min-[560px]:tracking-[0.3px]">{label}</p>
                <p className="text-[13px] font-bold @min-[560px]:mt-1 @min-[560px]:truncate @min-[560px]:text-sm" style={{ color }}>
                  {value}
                </p>
              </div>
            ))}
          </div>

          <div className="mt-7">
            {invoice.items.length === 0 ? (
              <p className="rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] py-6 text-center text-sm text-[#6B7280]">{text.noItems}</p>
            ) : (
              <div className="overflow-hidden rounded-xl border border-[#E5E7EB]">
                <table className="w-full table-fixed border-collapse">
                  <colgroup>
                    <col className="w-[60%] @min-[560px]:w-[44%]" />
                    <col className="hidden w-[11%] @min-[560px]:table-column" />
                    <col className="hidden w-[22%] @min-[560px]:table-column" />
                    <col className="w-[40%] @min-[560px]:w-[23%]" />
                  </colgroup>
                  <thead>
                    <tr className="bg-[#1A56DB] text-left text-xs font-extrabold tracking-[0.4px] text-white">
                      <th className="border border-[#E5E7EB] px-3.5 py-[11px]">{text.description}</th>
                      <th className="hidden border border-[#E5E7EB] px-3.5 py-[11px] text-center @min-[560px]:table-cell">{text.qty}</th>
                      <th className="hidden border border-[#E5E7EB] px-3.5 py-[11px] text-right @min-[560px]:table-cell">{text.price}</th>
                      <th className="border border-[#E5E7EB] px-3.5 py-[11px] text-right">{text.total}</th>
                    </tr>
                  </thead>
                  <tbody className="text-[13px] text-[#111827]">
                    {invoice.items.map((item, i) => (
                      <tr key={i} className={i % 2 === 1 ? "bg-[#F9FAFB]" : "bg-white"}>
                        <td className="border border-[#E5E7EB] px-3.5 py-[11px] font-medium break-words">{item.description}</td>
                        <td className="hidden border border-[#E5E7EB] px-3.5 py-[11px] text-center font-medium @min-[560px]:table-cell">{item.quantity}</td>
                        <td className="hidden border border-[#E5E7EB] px-3.5 py-[11px] text-right font-medium @min-[560px]:table-cell">{money(item.unitPrice)}</td>
                        <td className="border border-[#E5E7EB] px-3.5 py-[11px] text-right font-bold">{money(item.total)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <div className="mt-6 flex justify-end">
            <div className="w-full max-w-[320px] min-w-[240px] rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-[18px]">
              <SummaryLine label={text.subtotal} value={money(invoice.totalAmount)} />
              {invoice.paidAmount > 0 ? (
                <div className="mt-2.5">
                  <SummaryLine label={text.paidToward} value={`− ${money(invoice.paidAmount)}`} color="#059669" />
                </div>
              ) : null}
              <div className="mt-3.5 flex items-center justify-between gap-2 rounded-[10px] border px-3.5 py-3" style={{ color: dueColor, backgroundColor: alpha(dueColor, 0.08), borderColor: alpha(dueColor, 0.25) }}>
                <span className="text-sm font-extrabold">{text.amountDue}</span>
                <span className="text-xl font-black tracking-[-0.5px]">{money(invoiceRemaining(invoice))}</span>
              </div>
            </div>
          </div>

          <hr className="mt-6 border-[#E5E7EB]" />
          <div className="mt-5 flex items-center gap-2.5">
            <span className="grid h-9 w-9 shrink-0 place-items-center overflow-hidden rounded-lg border border-[#BFDBFE] bg-[#EFF6FF] p-1">
              <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="" className="h-full w-full object-contain" />
            </span>
            <p className="min-w-0 flex-1 text-[11px] font-semibold text-[#6B7280]">{COMPANY_INFO.name}</p>
            <div className="flex flex-col items-end">
              <p className="text-[11px] font-medium text-[#6B7280]">{text.signature}</p>
              <span className="mt-1 h-px w-[140px] bg-[#D1D5DB]" />
            </div>
          </div>
        </div>
      </article>
      </div>
    </div>
  );
}

function SectionLabel({ children }: { children: string }) {
  return <p className="text-[10px] font-extrabold tracking-[1.2px] text-[#1A56DB]">{children}</p>;
}

function SummaryLine({ label, value, color = "#111827" }: { label: string; value: string; color?: string }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-[13px] font-medium text-[#6B7280]">{label}</span>
      <span className="text-sm font-bold" style={{ color }}>
        {value}
      </span>
    </div>
  );
}

// ─── Decision history (B-042) ──────────────────────────────────────────────

/**
 * Parents cannot read decision_audits, so like Flutter they get the one row
 * built from the invoice's created_by fields — shown only when the invoice
 * records its creator.
 */
function DecisionHistory({ invoice, text, fr }: { invoice: ParentInvoice; text: ParentMoneyText; fr: boolean }) {
  const [actor, setActor] = useState<DecisionActor | null>(null);
  const show = invoice.createdByUid !== "" || invoice.createdByName !== "";
  useEffect(() => {
    if (!show) return;
    let active = true;
    void resolveCreator(invoice).then((value) => active && setActor(value));
    return () => {
      active = false;
    };
  }, [invoice, show]);
  if (!show || !actor) return null;
  const who = decisionActorName(actor);
  const name = who.kind === "system" ? text.systemAutomation : who.kind === "person" ? who.name : text.unknownPerson;
  const details = decisionTechnicalDetails(actor);
  const tooltip = details.length ? `${text.technicalDetails}: ${details.join(" · ")}` : text.technicalDetails;
  const date = invoice.createdAt
    ? `${invoice.createdAt.toLocaleDateString(fr ? "fr-FR" : "en-US", { month: "short", day: "numeric", year: "numeric" })} ${invoice.createdAt.toLocaleTimeString(fr ? "fr-FR" : "en-US", { hour: "numeric", minute: "2-digit" })}`
    : "";
  return (
    <section className="rounded-[14px] border border-[#E2E8F0] bg-white">
      <h2 className="flex items-center gap-2 px-4 pt-3.5 pb-2.5 text-sm font-bold text-[#0F172A]">
        <ListChecks size={19} className="text-[#4F46E5]" />
        {text.decisionHistory}
      </h2>
      <hr className="border-[#E0E0E0]" />
      <div className="flex items-start gap-2.5 px-3.5 py-[11px]">
        <span className="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-[#EEF2FF] text-[#4F46E5]">
          {who.kind === "system" ? <UserCog size={15} /> : <User size={15} />}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-[13px] font-bold text-[#1E293B]">{text.createdInvoice}</p>
          <p className="mt-1 flex items-center gap-1 text-xs text-[#475569]" title={tooltip}>
            {who.kind === "system" ? <Settings size={14} className="shrink-0 text-[#64748B]" /> : <CircleUser size={14} className="shrink-0 text-[#64748B]" />}
            <span className="truncate">{text.byActor.replace("{actor}", name)}</span>
          </p>
          {actor.role && who.kind !== "system" ? <p className="mt-px pl-[18px] text-[10px] text-[#94A3B8]">{actor.role}</p> : null}
        </div>
        {date ? <p className="ml-2 shrink-0 text-[10px] text-[#64748B]">{date}</p> : null}
      </div>
    </section>
  );
}

// ─── Payments for this invoice (B-043, B-044) ──────────────────────────────

function InvoicePayments({ invoice, uid, text }: { invoice: ParentInvoice; uid: string; text: ParentMoneyText }) {
  const [data, setData] = useState<Load<ParentPayment[]>>({ state: "loading" });
  useEffect(
    () =>
      watchInvoicePayments(
        invoice.id,
        uid,
        (list) => setData({ state: "ready", value: sortPaymentsNewestFirst(list) }),
        () => setData({ state: "error" }),
      ),
    [invoice.id, uid],
  );
  if (data.state === "loading") {
    return (
      <div className="flex justify-center p-3" role="status" aria-label={text.loading}>
        <Loader2 size={36} className="animate-spin text-[#0386FF]" />
      </div>
    );
  }
  if (data.state !== "ready") {
    return (
      <div className="flex items-center gap-2.5 rounded-2xl border border-[#FECACA] bg-[#FEF2F2] p-4" role="alert">
        <AlertCircle size={24} className="shrink-0 text-[#DC2626]" />
        <p className="font-semibold text-[#7F1D1D]">{text.paymentsLoadFailed}</p>
      </div>
    );
  }
  if (data.value.length === 0) {
    return (
      <div className="flex items-center gap-2.5 rounded-2xl border border-[#E5E7EB] bg-white p-4">
        <Info size={24} className="shrink-0 text-[#6B7280]" />
        <p className="font-semibold text-[#6B7280]">{text.noPaymentsForInvoice}</p>
      </div>
    );
  }
  return (
    <ul className="rounded-2xl border border-[#E5E7EB] bg-white">
      {data.value.map((payment) => (
        <li key={payment.id} className="flex min-h-[72px] items-center gap-4 px-4 py-2">
          <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: PAYMENT_DOT[payment.status] }} />
          <span className="min-w-0 flex-1">
            <span className="block text-[13px] font-extrabold text-[#111827]">{formatMoney(payment.amount, invoice.currency)}</span>
            <span className="block text-xs text-[#6B7280]">{paymentSubtitle(payment)}</span>
          </span>
        </li>
      ))}
    </ul>
  );
}

