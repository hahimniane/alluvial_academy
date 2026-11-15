"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Banknote, ChevronRight, Loader2 } from "lucide-react";
import { useParentSession } from "@/components/ParentArea";
import { ParentAppBar, alpha, cardShadow } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import { formatUsd, paymentSubtitle, type ParentPayment } from "@/lib/parentHome";
import { HISTORY_COLOR } from "@/lib/parentMoney";
import { invoiceReadable, watchPaymentHistory } from "@/lib/parentMoneyData";
import { parentMoneyText } from "@/lib/parentMoneyText";
import { PARENT_ROUTES } from "@/lib/parentWeb";

type Load = { state: "loading" } | { state: "error" } | { state: "ready"; list: ParentPayment[] };

/**
 * Payment History (B-092…B-098): every payment record of the parent, newest
 * first, live, up to 100 — attempts included, as today. A row opens the
 * invoice behind it; a missing invoice says so; a refused read does nothing.
 */
export default function ParentPaymentsPage() {
  const session = useParentSession();
  const router = useRouter();
  const fr = useLocale() === "fr";
  const text = parentMoneyText(fr);
  const [data, setData] = useState<Load>({ state: "loading" });
  const [toast, setToast] = useState<string | null>(null);

  useEffect(
    () =>
      watchPaymentHistory(
        session.uid,
        (list) => setData({ state: "ready", list }),
        () => setData({ state: "error" }),
      ),
    [session.uid],
  );

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 4000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const open = async (payment: ParentPayment) => {
    const invoiceId = payment.invoiceId.trim();
    if (!invoiceId) return;
    const result = await invoiceReadable(invoiceId);
    if (result === "found") router.push(PARENT_ROUTES.invoice(invoiceId));
    else if (result === "missing") setToast(text.invoiceMissingForPayment);
  };

  return (
    <div className="flex min-h-full flex-col bg-[#F8FAFC]">
      <ParentAppBar title={text.paymentHistory} />
      <div className="flex-1">
        {data.state === "loading" ? (
          <div className="grid place-items-center py-16" role="status" aria-label={text.loading}>
            <Loader2 size={36} className="animate-spin text-[#0386FF]" />
          </div>
        ) : data.state === "error" ? (
          <p className="p-6 text-center font-semibold text-[#6B7280]" role="alert">
            {text.historyLoadFailed}
          </p>
        ) : data.list.length === 0 ? (
          <p className="p-6 text-center font-semibold text-[#6B7280]">{text.noPaymentsYet}</p>
        ) : (
          <ul className="grid gap-3 px-4 pt-3 pb-6">
            {data.list.map((payment) => {
              const color = HISTORY_COLOR[payment.status];
              return (
                <li key={payment.id}>
                  <button
                    type="button"
                    onClick={() => void open(payment)}
                    className={`flex min-h-[72px] w-full items-center gap-4 rounded-2xl border border-[#E5E7EB] bg-white px-4 py-2 text-left hover:bg-[#F9FAFB] ${cardShadow}`}
                  >
                    <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl" style={{ color, backgroundColor: alpha(color, 0.12) }}>
                      <Banknote size={24} />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block text-[13px] font-black text-[#111827]">{formatUsd(payment.amount)}</span>
                      <span className="block text-xs font-medium text-[#6B7280]">{paymentSubtitle(payment)}</span>
                    </span>
                    <ChevronRight size={24} className="shrink-0 text-[#9CA3AF]" />
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>
      {toast ? (
        <div role="status" className="fixed bottom-6 left-1/2 z-[120] -translate-x-1/2 rounded-xl bg-[#323232] px-4 py-3 text-sm font-medium text-white shadow-xl">
          {toast}
        </div>
      ) : null}
    </div>
  );
}
