"use client";

import { AlertTriangle, Calendar, CalendarDays, CreditCard, Lock, LockKeyhole, User } from "lucide-react";
import { alpha } from "@/components/ParentUi";
import {
  billingPeriod,
  cutoffBadge,
  dueChipLabel,
  formatMoney,
  invoiceBadge,
  invoiceFullyPaid,
  invoiceOverdue,
  invoicePayable,
  invoiceRemaining,
  type ParentInvoice,
} from "@/lib/parentHome";

const ACCENT = "#1A56DB";

const CUTOFF_TONES = {
  red: { color: "#DC2626", bg: "#FEF2F2", border: "#FECACA" },
  orange: { color: "#DC2626", bg: "#FFF7ED", border: "#FED7AA" },
  amber: { color: "#D97706", bg: "#FFFBEB", border: "#FDE68A" },
} as const;

/**
 * InvoiceCard (A-054): status bar and badge, number, billing period, amount
 * due in the invoice's currency, due chip, access-cutoff strip and Pay Now.
 * The card opens the invoice; Pay Now opens the payment page.
 */
export function ParentInvoiceCard({
  invoice,
  now,
  studentName,
  payLabel,
  onOpen,
  onPay,
}: {
  invoice: ParentInvoice;
  now: Date;
  studentName?: string;
  payLabel: string;
  onOpen: () => void;
  onPay: (() => void) | null;
}) {
  const badge = invoiceBadge(invoice, now);
  const overdue = invoiceOverdue(invoice, now);
  const period = billingPeriod(invoice);
  const cutoff = cutoffBadge(invoice, now);
  const payable = invoicePayable(invoice) && onPay !== null;
  const paid = invoiceFullyPaid(invoice);
  const tone = cutoff ? CUTOFF_TONES[cutoff.tone] : null;

  return (
    <article
      onClick={(event) => {
        // Text stays selectable: a drag-selection is not a click on the card.
        if (window.getSelection()?.toString()) return;
        if ((event.target as HTMLElement).closest("button")) return;
        onOpen();
      }}
      className="flex cursor-pointer overflow-hidden rounded-2xl border border-[#E5E7EB] bg-white shadow-[0_4px_12px_rgba(0,0,0,0.05)]"
    >
      <span className="w-1 shrink-0" style={{ backgroundColor: badge.color }} />
      <div className="min-w-0 flex-1 p-3.5">
        <div className="flex items-center gap-2">
          <a
            href="#"
            onClick={(event) => {
              event.preventDefault();
              event.stopPropagation();
              onOpen();
            }}
            className="min-w-0 flex-1 truncate text-sm font-extrabold text-[#111827] outline-none focus-visible:underline"
          >
            {invoice.invoiceNumber || "Invoice"}
          </a>
          <span
            className="shrink-0 rounded-full border px-[9px] py-1 text-[10px] font-extrabold tracking-[0.6px]"
            style={{ color: badge.color, backgroundColor: alpha(badge.color, 0.1), borderColor: alpha(badge.color, 0.3) }}
          >
            {badge.label}
          </span>
        </div>

        {studentName && studentName.trim() ? (
          <p className="mt-[3px] flex items-center gap-1 text-xs font-medium text-[#6B7280]">
            <User size={13} className="text-[#9CA3AF]" />
            {studentName.trim()}
          </p>
        ) : null}

        {period ? (
          <p className="mt-[3px] flex items-center gap-1 text-xs font-semibold" style={{ color: ACCENT }}>
            <CalendarDays size={13} />
            {period}
          </p>
        ) : null}

        <div className="mt-3 flex items-end gap-2">
          <div className="min-w-0 flex-1">
            <p className="text-[10px] font-medium tracking-[0.3px] text-[#9CA3AF]">Amount due</p>
            <p className="mt-0.5 text-xl font-black tracking-[-0.5px]" style={{ color: paid ? "#059669" : "#111827" }}>
              {formatMoney(invoiceRemaining(invoice), invoice.currency)}
            </p>
          </div>
          <span
            className="inline-flex shrink-0 items-center gap-[5px] rounded-[10px] border px-2.5 py-1.5 text-[11px] font-bold"
            style={
              overdue
                ? { color: "#DC2626", backgroundColor: "#FEF2F2", borderColor: "#FECACA" }
                : { color: "#6B7280", backgroundColor: "#F9FAFB", borderColor: "#E5E7EB" }
            }
          >
            {overdue ? <AlertTriangle size={12} /> : <Calendar size={12} />}
            {dueChipLabel(invoice, now)}
          </span>
        </div>

        {cutoff && tone ? (
          <p
            className="mt-2 flex items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-[11px] font-bold"
            style={{ color: tone.color, backgroundColor: tone.bg, borderColor: tone.border }}
          >
            {cutoff.locked ? <Lock size={12} /> : <LockKeyhole size={12} />}
            {cutoff.label}
          </p>
        ) : null}

        {payable ? (
          <button
            type="button"
            onClick={(event) => {
              event.stopPropagation();
              onPay?.();
            }}
            className="mt-3 flex h-10 w-full items-center justify-center gap-2 rounded-[10px] text-[13px] font-bold text-white hover:opacity-95"
            style={{ backgroundColor: ACCENT }}
          >
            <CreditCard size={16} />
            {payLabel}
          </button>
        ) : null}
      </div>
    </article>
  );
}
