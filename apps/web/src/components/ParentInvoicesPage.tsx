"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { Loader2, Search } from "lucide-react";
import { useParentSession } from "@/components/ParentArea";
import { ParentInvoiceCard } from "@/components/ParentInvoiceCard";
import { ParentAppBar, useNow } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import { invoicePayable, type ParentInvoice } from "@/lib/parentHome";
import { INVOICE_CHIPS, chipFromParam, listStudentName, mergeInvoiceList, searchInvoices, type InvoiceChip } from "@/lib/parentMoney";
import { fetchUserData, watchInvoiceList } from "@/lib/parentMoneyData";
import { parentMoneyText } from "@/lib/parentMoneyText";
import { PARENT_ROUTES } from "@/lib/parentWeb";

type Load = { state: "loading" } | { state: "error" } | { state: "ready"; list: ParentInvoice[] };

/**
 * Invoices (ParentInvoicesScreen, B-001…B-017): search by number, five status
 * chips that filter on the stored status, the parent's and their own-as-student
 * invoices merged (latest due first, 100), each card with the child's name.
 * `?status=pending` pre-selects a chip, as the dashboard's Pay Now and the
 * suspension banner do.
 */
export default function ParentInvoicesPage() {
  const session = useParentSession();
  const router = useRouter();
  const params = useSearchParams();
  const fr = useLocale() === "fr";
  const text = parentMoneyText(fr);
  const now = useNow();
  const [chip, setChip] = useState<InvoiceChip>(() => chipFromParam(params?.get("status")));
  const [search, setSearch] = useState("");
  const [data, setData] = useState<Load>({ state: "loading" });
  const [names, setNames] = useState<Record<string, string>>({});

  useEffect(() => {
    setData({ state: "loading" });
    return watchInvoiceList(
      session.uid,
      chip,
      (byParent, byStudent) => setData({ state: "ready", list: mergeInvoiceList(byParent, byStudent, chip) }),
      () => setData({ state: "error" }),
    );
  }, [session.uid, chip]);

  // B-012: each card's child name (raw id when the name is missing), cached.
  useEffect(() => {
    if (data.state !== "ready") return;
    const missing = [...new Set(data.list.map((i) => i.studentId))].filter((id) => !(id in names));
    if (missing.length === 0) return;
    let active = true;
    void Promise.all(missing.map(async (id) => [id, id ? listStudentName(await fetchUserData(id), id) : ""] as const)).then((pairs) => {
      if (active) setNames((current) => ({ ...current, ...Object.fromEntries(pairs) }));
    });
    return () => {
      active = false;
    };
  }, [data, names]);

  const shown = useMemo(() => (data.state === "ready" ? searchInvoices(data.list, search) : []), [data, search]);
  const chipLabel: Record<InvoiceChip, string> = { all: text.all, pending: text.pending, paid: text.paid, overdue: text.overdue, cancelled: text.cancelled };

  return (
    <div className="flex min-h-full flex-col bg-[#F8FAFC]">
      <ParentAppBar title={text.invoices} />
      <div className="px-4 pt-3 pb-2">
        <label className="flex h-12 items-center gap-3 rounded-[14px] border border-[#E5E7EB] bg-white px-3.5 focus-within:border-[#0386FF]">
          <Search size={22} className="shrink-0 text-[#49454F]" />
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder={text.searchHint}
            aria-label={text.searchHint}
            className="min-w-0 flex-1 bg-transparent text-base text-[#111827] outline-none placeholder:text-[#6B7280]"
          />
        </label>
        <div className="mt-2.5 overflow-x-auto pb-1">
        <div className="mx-auto flex w-max gap-2" role="group" aria-label={text.invoices}>
          {INVOICE_CHIPS.map((key) => (
            <button
              key={key}
              type="button"
              aria-pressed={chip === key}
              onClick={() => setChip(key)}
              className={`shrink-0 rounded-full border px-3 py-2 text-xs font-bold ${chip === key ? "border-[#0386FF] bg-[#0386FF] text-white" : "border-[#E5E7EB] bg-white text-[#111827] hover:bg-[#F9FAFB]"}`}
            >
              {chipLabel[key]}
            </button>
          ))}
        </div>
        </div>
      </div>
      <div className="flex-1 px-4 pt-2 pb-4">
        {data.state === "loading" ? (
          <div className="grid place-items-center py-16" role="status" aria-label={text.loading}>
            <Loader2 size={36} className="animate-spin text-[#0386FF]" />
          </div>
        ) : data.state === "error" ? (
          <p className="p-6 text-center font-semibold text-[#6B7280]" role="alert">
            {text.invoicesLoadFailed}
          </p>
        ) : shown.length === 0 ? (
          <p className="p-6 text-center font-semibold text-[#6B7280]">{text.noInvoicesFound}</p>
        ) : (
          <div className="grid gap-3">
            {shown.map((invoice) => (
              <ParentInvoiceCard
                key={invoice.id}
                invoice={invoice}
                now={now}
                studentName={names[invoice.studentId]}
                payLabel={fr ? "Payez maintenant" : "Pay Now"}
                onOpen={() => router.push(PARENT_ROUTES.invoice(invoice.id))}
                onPay={invoicePayable(invoice) ? () => router.push(PARENT_ROUTES.pay(invoice.id)) : null}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
