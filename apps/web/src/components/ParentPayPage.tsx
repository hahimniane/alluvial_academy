"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { AlertCircle, CheckCircle2, CreditCard, Loader2, RefreshCw, XCircle } from "lucide-react";
import { ParentAppBar, alpha, useNow } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import { formatMoney, invoiceFullyPaid, invoiceRemaining, type ParentInvoice, type ParentPayment } from "@/lib/parentHome";
import { PAYMENT_POLL_MS, PAYMENT_POLL_TRIES, formatDateTime, payBadge, payButtonState, paymentIsFinal, returnResult, type PayFailure } from "@/lib/parentMoney";
import { fetchPayment, startCheckout, watchInvoice } from "@/lib/parentMoneyData";
import { parentMoneyText, type ParentMoneyText } from "@/lib/parentMoneyText";
import { PARENT_ROUTES } from "@/lib/parentWeb";

type Load = { state: "loading" } | { state: "error" } | { state: "missing" } | { state: "ready"; invoice: ParentInvoice };

function useLiveInvoice(invoiceId: string): Load {
  const [load, setLoad] = useState<Load>({ state: "loading" });
  useEffect(() => {
    if (!invoiceId) {
      setLoad({ state: "missing" });
      return;
    }
    return watchInvoice(
      invoiceId,
      (invoice) => setLoad(invoice ? { state: "ready", invoice } : { state: "missing" }),
      () => setLoad({ state: "error" }),
    );
  }, [invoiceId]);
  return load;
}

const failureText = (text: ParentMoneyText, failure: PayFailure) =>
  ({
    signIn: text.errSignIn,
    notYourInvoice: text.errNotYours,
    invoiceNotFound: text.errNotFound,
    invoiceCancelled: text.errCancelled,
    alreadyPaid: text.errAlreadyPaid,
    checkoutOpen: text.errCheckoutOpen,
    status: text.errStatus,
    generic: text.errGeneric,
  })[failure];

/**
 * Pay Invoice (PaymentScreen, web branch, B-058…B-072): the live invoice box,
 * one button for the whole remaining balance, Stripe Checkout in the same tab,
 * and the plain error messages mapped from the server's error code.
 */
export default function ParentPayPage() {
  const invoiceId = useSearchParams()?.get("invoiceId") ?? "";
  const fr = useLocale() === "fr";
  const text = parentMoneyText(fr);
  const now = useNow();
  const load = useLiveInvoice(invoiceId);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const pay = async () => {
    setError(null);
    setStarting(true);
    const result = await startCheckout(invoiceId);
    if (!result.ok) {
      setError(failureText(text, result.failure));
      setStarting(false);
      return;
    }
    try {
      window.location.assign(result.checkoutUrl);
    } catch {
      setError(text.errCheckoutOpen);
      setStarting(false);
    }
  };

  return (
    <div className="flex min-h-full flex-col bg-[#F8FAFC]">
      <ParentAppBar title={text.payInvoice} backHref={invoiceId ? PARENT_ROUTES.invoice(invoiceId) : PARENT_ROUTES.invoices} backLabel={text.back} />
      {load.state === "loading" ? (
        <div className="grid flex-1 place-items-center py-16" role="status" aria-label={text.loading}>
          <Loader2 size={36} className="animate-spin text-[#0386FF]" />
        </div>
      ) : load.state !== "ready" ? (
        <p className="p-6 text-center font-semibold text-[#6B7280]" role="alert">
          {load.state === "missing" ? text.errNotFound : text.invoiceLoadFailed}
        </p>
      ) : (
        <div className="grid gap-3.5 p-4">
          <InvoiceSummary invoice={load.invoice} now={now} />
          {error ? <ErrorBox message={error} /> : null}
          {invoiceFullyPaid(load.invoice) ? <SuccessBanner /> : null}
          <PayButton invoice={load.invoice} payment={null} starting={starting} text={text} onPay={() => void pay()} />
        </div>
      )}
    </div>
  );
}

/**
 * Where Stripe sends the parent back (`/parent/pay/return/?invoiceId&paymentId
 * &result`). Flutter on the web has none — parents land on the public home page
 * (B-064); the plan's default is a parent page saying what happened. It shows
 * the live invoice and, like Flutter's phone flow, re-reads the payment every
 * 2 s (15 tries) with a Check Payment Status button until it is final.
 */
export function ParentPayReturnPage() {
  const params = useSearchParams();
  const invoiceId = params?.get("invoiceId") ?? "";
  const paymentId = params?.get("paymentId") ?? "";
  const result = returnResult(params?.get("result"));
  const fr = useLocale() === "fr";
  const text = parentMoneyText(fr);
  const now = useNow();
  const load = useLiveInvoice(invoiceId);
  const [payment, setPayment] = useState<ParentPayment | null>(null);
  const [statusError, setStatusError] = useState(false);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const tries = useRef(0);

  const check = useCallback(
    async (silent: boolean) => {
      if (!paymentId) return;
      try {
        const value = await fetchPayment(paymentId);
        setPayment(value);
        if (!silent) setStatusError(false);
      } catch {
        if (!silent) setStatusError(true);
      }
    },
    [paymentId],
  );

  useEffect(() => {
    if (result !== "success" || !paymentId) return;
    void check(true);
    const timer = window.setInterval(() => {
      tries.current += 1;
      if (tries.current >= PAYMENT_POLL_TRIES) window.clearInterval(timer);
      void check(true);
    }, PAYMENT_POLL_MS);
    return () => window.clearInterval(timer);
  }, [result, paymentId, check]);

  const payAgain = async () => {
    setError(null);
    setStarting(true);
    const outcome = await startCheckout(invoiceId);
    if (!outcome.ok) {
      setError(failureText(text, outcome.failure));
      setStarting(false);
      return;
    }
    window.location.assign(outcome.checkoutUrl);
  };

  const invoice = load.state === "ready" ? load.invoice : null;
  const paid = invoice ? invoiceFullyPaid(invoice) || payment?.status === "completed" : false;
  const state: "paid" | "pending" | "cancel" = result === "cancel" ? "cancel" : paid ? "paid" : "pending";
  const banner = {
    paid: { title: text.returnPaidTitle, body: text.returnPaidBody, color: "#059669", bg: "#F0FDF4", border: "#BBF7D0", Icon: CheckCircle2 },
    pending: { title: text.returnPendingTitle, body: text.returnPendingBody, color: "#2563EB", bg: "#EFF6FF", border: "#BFDBFE", Icon: Loader2 },
    cancel: { title: text.returnCancelTitle, body: text.returnCancelBody, color: "#B45309", bg: "#FFFBEB", border: "#FDE68A", Icon: XCircle },
  }[state];

  return (
    <div className="flex min-h-full flex-col bg-[#F8FAFC]">
      <ParentAppBar title={text.payInvoice} backHref={invoiceId ? PARENT_ROUTES.invoice(invoiceId) : PARENT_ROUTES.invoices} backLabel={text.back} />
      <div className="grid gap-3.5 p-4">
        <section className="flex items-start gap-3 rounded-[14px] border p-4" style={{ backgroundColor: banner.bg, borderColor: banner.border }} role="status">
          <banner.Icon size={22} className={`mt-0.5 shrink-0 ${state === "pending" ? "animate-spin" : ""}`} style={{ color: banner.color }} />
          <div className="min-w-0">
            <h2 className="text-[15px] font-extrabold" style={{ color: banner.color }}>
              {banner.title}
            </h2>
            <p className="mt-1 text-[13px] font-medium text-[#374151]">{banner.body}</p>
          </div>
        </section>
        {invoice ? <InvoiceSummary invoice={invoice} now={now} /> : load.state === "loading" ? null : <p className="p-2 text-center font-semibold text-[#6B7280]">{text.errNotFound}</p>}
        {payment && result === "success" ? <PaymentStatusCard payment={payment} currency={invoice?.currency ?? "USD"} /> : null}
        {statusError ? <ErrorBox message={text.errStatus} /> : null}
        {error ? <ErrorBox message={error} /> : null}
        {result === "success" && paymentId && !paymentIsFinal(payment) ? (
          <button
            type="button"
            onClick={() => void check(false)}
            className="flex min-h-12 items-center justify-center gap-2 rounded-xl border border-[#E5E7EB] bg-white py-3 text-sm font-semibold text-[#374151] hover:bg-[#F9FAFB]"
          >
            <RefreshCw size={18} />
            {text.checkStatus}
          </button>
        ) : null}
        {state === "cancel" && invoice ? <PayButton invoice={invoice} payment={null} starting={starting} text={text} label={text.tryAgain} onPay={() => void payAgain()} /> : null}
        <div className="flex flex-wrap justify-center gap-2 pt-1">
          {invoiceId ? (
            <Link href={PARENT_ROUTES.invoice(invoiceId)} className="rounded-lg px-3 py-2 text-sm font-bold text-[#0386FF] hover:bg-[#0386FF]/10">
              {text.viewInvoice}
            </Link>
          ) : null}
          <Link href={PARENT_ROUTES.invoices} className="rounded-lg px-3 py-2 text-sm font-bold text-[#0386FF] hover:bg-[#0386FF]/10">
            {text.backToInvoices}
          </Link>
        </div>
      </div>
    </div>
  );
}

// ─── Pieces shared by both pages (PaymentScreen sub-widgets) ───────────────

function InvoiceSummary({ invoice, now }: { invoice: ParentInvoice; now: Date }) {
  const paid = invoiceFullyPaid(invoice);
  const badge = payBadge(invoice, now);
  const money = (n: number) => formatMoney(n, invoice.currency);
  const remaining = invoiceRemaining(invoice);
  return (
    <section className="rounded-2xl border bg-white p-5 shadow-[0_4px_10px_rgba(0,0,0,0.04)]" style={{ borderColor: paid ? "#BBF7D0" : "#E5E7EB" }}>
      <div className="flex items-center gap-2">
        <p className="min-w-0 flex-1 truncate text-base font-extrabold text-[#111827]">{invoice.invoiceNumber || invoice.id}</p>
        <span className="shrink-0 rounded-[20px] border px-2.5 py-[5px] text-[11px] font-extrabold tracking-[0.5px]" style={{ color: badge.color, backgroundColor: alpha(badge.color, 0.1), borderColor: alpha(badge.color, 0.3) }}>
          {badge.label}
        </span>
      </div>
      <div className="mt-4 grid gap-2">
        <Row label="Total" value={money(invoice.totalAmount)} />
        <Row label="Paid" value={money(invoice.paidAmount)} color={invoice.paidAmount > 0 ? "#059669" : undefined} />
      </div>
      <hr className="my-3 border-[#E5E7EB]" />
      <Row label="Remaining" value={money(remaining)} strong color={remaining === 0 ? "#059669" : "#111827"} />
    </section>
  );
}

function Row({ label, value, strong = false, color = "#111827" }: { label: string; value: string; strong?: boolean; color?: string }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-[13px] font-medium text-[#6B7280]">{label}</span>
      <span className={`text-sm ${strong ? "font-black" : "font-bold"}`} style={{ color }}>
        {value}
      </span>
    </div>
  );
}

function ErrorBox({ message }: { message: string }) {
  return (
    <div className="flex items-center gap-2.5 rounded-[14px] border border-[#FECACA] bg-[#FEF2F2] p-3.5" role="alert">
      <AlertCircle size={24} className="shrink-0 text-[#DC2626]" />
      <p className="text-xs font-semibold text-[#7F1D1D]">{message}</p>
    </div>
  );
}

function SuccessBanner() {
  return (
    <div className="flex items-center gap-3 rounded-[14px] border border-[#BBF7D0] bg-[#F0FDF4] p-4">
      <CheckCircle2 size={22} className="shrink-0 text-[#059669]" />
      <p className="text-[13px] font-bold text-[#14532D]">Payment received — invoice is now fully paid.</p>
    </div>
  );
}

function PayButton({
  invoice,
  payment,
  starting,
  text,
  label,
  onPay,
}: {
  invoice: ParentInvoice;
  payment: ParentPayment | null;
  starting: boolean;
  text: ParentMoneyText;
  label?: string;
  onPay: () => void;
}) {
  const state = payButtonState(invoice, payment, starting);
  return (
    <button
      type="button"
      disabled={!state.enabled}
      onClick={onPay}
      className="flex h-[52px] w-full items-center justify-center gap-2 rounded-[14px] text-[15px] font-extrabold text-white disabled:bg-[#E5E7EB] disabled:text-[#9CA3AF]"
      style={state.enabled ? { backgroundColor: state.paid ? "#059669" : "#0386FF" } : undefined}
    >
      {starting ? <Loader2 size={18} className="animate-spin" /> : state.paid ? <CheckCircle2 size={20} /> : <CreditCard size={20} />}
      {state.paid ? text.alreadyPaid : (label ?? text.continueCheckout)}
    </button>
  );
}

const PAYMENT_STATUS_DOT = { completed: "#059669", failed: "#DC2626", processing: "#2563EB", pending: "#F59E0B" } as const;

function PaymentStatusCard({ payment, currency }: { payment: ParentPayment; currency: string }) {
  const done = payment.status === "completed";
  const color = PAYMENT_STATUS_DOT[payment.status];
  return (
    <section className="rounded-2xl border p-4 transition-colors" style={{ backgroundColor: done ? "#F0FDF4" : "#FFFFFF", borderColor: done ? "#BBF7D0" : "#E5E7EB" }}>
      <p className="flex items-center gap-2 text-[13px] font-extrabold" style={{ color }}>
        <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: color }} />
        Payment {payment.status.toUpperCase()}
      </p>
      <div className="mt-2.5 grid gap-1.5">
        {payment.amount > 0 ? <KeyValue k="Amount" v={formatMoney(payment.amount, currency)} strong /> : null}
        {payment.createdAt ? <KeyValue k="Created" v={formatDateTime(payment.createdAt)} /> : null}
        {payment.completedAt ? <KeyValue k="Completed" v={formatDateTime(payment.completedAt)} /> : null}
      </div>
    </section>
  );
}

function KeyValue({ k, v, strong = false }: { k: string; v: string; strong?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-xs font-semibold text-[#6B7280]">{k}</span>
      <span className={`text-[13px] text-[#111827] ${strong ? "font-black" : "font-bold"}`}>{v}</span>
    </div>
  );
}
