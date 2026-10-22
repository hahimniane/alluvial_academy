"use client";

import { httpsCallable } from "firebase/functions";
import { collection, doc, getDoc, getDocs, limit, orderBy, query, where } from "firebase/firestore";
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { db, functions } from "@/lib/firebase";
import {
  buildActiveDiscounts,
  buildBases,
  creditStatusLabel,
  creditsOwed,
  discountsCostPerMonth,
  discountsYearToDate,
  fullName,
  readCredit,
  readHolder,
  sortCredits,
  yearSoFarSub,
  type CreditRow,
  type DiscountHolder,
} from "@/lib/finance/discounts";
import { FIN, money } from "@/lib/finance/model";
import { monthLabel, monthName } from "@/lib/finance/months";

/**
 * Discounts & credits: what discounts cost, the discounts active in the
 * selected month (read from users[].discount through the existing discount
 * helpers) and the credit owed to families, which staff can refund or cancel
 * with a reason. Credits are only changed through `resolveFamilyCredit`.
 */

const card = "rounded-xl border border-slate-200 bg-white";
const quietButton = "h-9 rounded-lg border border-slate-300 bg-white px-2.5 text-sm font-semibold text-slate-900 disabled:opacity-50";
const dangerButton = "h-9 rounded-lg bg-red-700 px-3 text-sm font-bold text-white disabled:opacity-50";
const input = "h-10 rounded-lg border border-slate-300 bg-white px-2.5 text-sm text-slate-900";

type Plan = { parentId: string; items: { studentId: string; total: number }[] };
type FamilyBilling = { parentId: string; monthlyAmount: number; studentIds: string[] };

function messageOf(error: unknown): string {
  const e = error as { code?: string; message?: string };
  if ((e?.code === "functions/failed-precondition" || e?.code === "functions/invalid-argument" || e?.code === "functions/not-found") && e.message) {
    return e.message;
  }
  return "Something went wrong. Try again.";
}

const strings = (value: unknown): string[] => (Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : []);

/** Display names for user ids, read once each. A missing user shows as "—". */
async function loadNames(ids: string[]): Promise<Map<string, string>> {
  const unique = [...new Set(ids.filter(Boolean))];
  const entries = await Promise.all(
    unique.map(async (id) => {
      try {
        const snap = await getDoc(doc(db, "users", id));
        return [id, snap.exists() ? fullName(snap.data() as Record<string, unknown>, "—") : "—"] as const;
      } catch {
        return [id, "—"] as const;
      }
    }),
  );
  return new Map(entries);
}

export function DiscountsScreen() {
  const { month } = useFinance();
  const name = monthName(month);

  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [holders, setHolders] = useState<DiscountHolder[]>([]);
  const [plans, setPlans] = useState<Plan[]>([]);
  const [familyBilling, setFamilyBilling] = useState<FamilyBilling[]>([]);
  const [names, setNames] = useState<Map<string, string>>(new Map());
  const [credits, setCredits] = useState<CreditRow[]>([]);
  const [byMonth, setByMonth] = useState<Record<string, number> | null>(null);

  const [asking, setAsking] = useState<{ id: string; action: "refund" | "cancel" } | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState("");
  const [notice, setNotice] = useState("");
  const [problem, setProblem] = useState("");

  const sequence = useRef(0);

  const load = useCallback(async () => {
    const mine = ++sequence.current;
    setLoading(true);
    setLoadError("");
    const [holderSnap, planSnap, creditSnap, totals] = await Promise.allSettled([
      getDocs(query(collection(db, "users"), where("discount", "!=", null), limit(500))),
      getDocs(query(collection(db, "recurring_billing_plans"), where("status", "==", "active"), limit(1000))),
      getDocs(query(collection(db, FIN.familyCredits), orderBy("created_at", "desc"), limit(300))),
      httpsCallable(functions, "getFinanceDiscountTotals")({ through_month: month }),
    ]);
    if (mine !== sequence.current) return;

    if (holderSnap.status === "rejected" || creditSnap.status === "rejected") {
      setLoadError("Discounts could not load. Check your connection and try again.");
    }

    const nextHolders =
      holderSnap.status === "fulfilled" ? holderSnap.value.docs.map((d) => readHolder(d.id, d.data())).filter((h): h is DiscountHolder => h !== null) : [];
    const nextPlans: Plan[] =
      planSnap.status === "fulfilled"
        ? planSnap.value.docs.map((d) => {
            const data = d.data() as Record<string, unknown>;
            const items = Array.isArray(data.base_items) ? (data.base_items as Record<string, unknown>[]) : [];
            return {
              parentId: String(data.parent_id ?? ""),
              items: items.map((item) => ({ studentId: String(item.student_id ?? ""), total: Number(item.total) || 0 })),
            };
          })
        : [];
    const nextCredits = creditSnap.status === "fulfilled" ? creditSnap.value.docs.map((d) => readCredit(d.id, d.data())) : [];

    // Family names, and a family's monthly amount when billing has set one.
    const parentIds = [...new Set(nextHolders.flatMap((h) => (h.discount.scope === "family" ? [h.id] : h.parentIds)))];
    const creditIds = nextCredits.flatMap((c) => [c.parentId, c.studentId]);
    const [nextNames, billing] = await Promise.all([
      loadNames([...parentIds, ...creditIds]),
      Promise.all(
        parentIds.map(async (parentId): Promise<FamilyBilling | null> => {
          try {
            const snap = await getDoc(doc(db, FIN.familyBilling, parentId));
            if (!snap.exists()) return null;
            const data = snap.data() as Record<string, unknown>;
            if (data.active === false) return null;
            return { parentId, monthlyAmount: Number(data.monthly_amount) || 0, studentIds: strings(data.student_ids) };
          } catch {
            return null;
          }
        }),
      ),
    ]);
    if (mine !== sequence.current) return;

    setHolders(nextHolders);
    setPlans(nextPlans);
    setFamilyBilling(billing.filter((b): b is FamilyBilling => b !== null));
    setNames(nextNames);
    setCredits(nextCredits);
    setByMonth(totals.status === "fulfilled" ? ((totals.value.data as { by_month?: Record<string, number> }).by_month ?? null) : null);
    setLoading(false);
  }, [month]);

  useEffect(() => {
    setAsking(null);
    setReason("");
    setNotice("");
    setProblem("");
    void load();
  }, [load]);

  const rows = useMemo(
    () => buildActiveDiscounts({ month, holders, parentNames: names, bases: buildBases(plans, familyBilling) }),
    [month, holders, names, plans, familyBilling],
  );
  const cost = useMemo(() => discountsCostPerMonth(rows), [rows]);
  const owed = useMemo(() => creditsOwed(credits), [credits]);
  const sortedCredits = useMemo(() => sortCredits(credits), [credits]);

  const cards = [
    {
      label: `${name} discounts`,
      value: byMonth ? money(byMonth[month] ?? 0) : "—",
      sub: byMonth ? `On ${name} invoices` : "Could not load",
    },
    {
      label: `${month.slice(0, 4)} so far`,
      value: byMonth ? money(discountsYearToDate(byMonth, month)) : "—",
      sub: yearSoFarSub(month),
    },
    {
      label: "Active discounts cost",
      value: `${money(cost.total)} / month`,
      sub: `${cost.families} ${cost.families === 1 ? "family" : "families"}${cost.unknown > 0 ? ` · ${cost.unknown} without a known monthly amount` : ""}`,
    },
    {
      label: "Credit owed to families",
      value: money(owed.total),
      sub: owed.total > 0 ? `${owed.families} ${owed.families === 1 ? "family" : "families"} · taken off the next invoice` : "Nothing owed",
    },
  ];

  async function resolve(credit: CreditRow, action: "refund" | "cancel") {
    const why = reason.trim();
    if (!why) {
      setProblem("Say why.");
      return;
    }
    setBusy(credit.id);
    setProblem("");
    setNotice("");
    try {
      await httpsCallable(functions, "resolveFamilyCredit")({ credit_id: credit.id, action, reason: why });
      const family = names.get(credit.parentId) ?? "the family";
      setNotice(action === "refund" ? `${money(credit.amount)} refunded to ${family}` : `Credit cancelled for ${family}`);
      setAsking(null);
      setReason("");
      await load();
    } catch (error) {
      setProblem(messageOf(error));
    } finally {
      setBusy("");
    }
  }

  return (
    <section className="flex flex-col gap-3" aria-busy={loading}>
      <h2 className="m-0 text-2xl font-extrabold">Discounts &amp; credits</h2>

      {loadError ? (
        <p role="alert" className="m-0 rounded-lg bg-red-50 px-3 py-2 text-sm font-semibold text-red-800">
          {loadError}
        </p>
      ) : null}
      {problem ? (
        <p role="alert" className="m-0 rounded-lg bg-red-50 px-3 py-2 text-sm font-semibold text-red-800">
          {problem}
        </p>
      ) : null}
      <p role="status" aria-live="polite" className={notice ? "m-0 rounded-lg bg-emerald-50 px-3 py-2 text-sm font-semibold text-emerald-900" : "sr-only"}>
        {notice}
      </p>

      <div className="grid grid-cols-2 gap-2.5 lg:grid-cols-4">
        {cards.map((c) => (
          <div key={c.label} className={`${card} p-3`}>
            <div className="text-xs font-semibold text-slate-600">{c.label}</div>
            <div className="text-xl font-extrabold">{c.value}</div>
            <div className="text-xs text-slate-600">{c.sub}</div>
          </div>
        ))}
      </div>

      <h3 className="mb-0 mt-1.5 text-base font-bold">Active discounts · {monthLabel(month)}</h3>
      <div className={`${card} relative overflow-x-auto`}>
        <table className="w-full min-w-[620px] border-collapse text-[13px]">
          <caption className="sr-only">Active discounts in {monthLabel(month)}</caption>
          <thead>
            <tr className="bg-slate-50 text-left text-slate-700">
              <th scope="col" className="px-3 py-2.5">Family</th>
              <th scope="col" className="px-3 py-2.5">Applies to</th>
              <th scope="col" className="px-3 py-2.5">Reason</th>
              <th scope="col" className="px-3 py-2.5">Discount</th>
              <th scope="col" className="px-3 py-2.5 text-right">Per month</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.key} className="border-t border-slate-200">
                <td className="px-3 py-2.5 font-semibold">{r.family}</td>
                <td className="px-3 py-2.5">{r.appliesTo}</td>
                <td className="px-3 py-2.5 text-slate-700">{r.reason || "—"}</td>
                <td className="px-3 py-2.5">{r.kind}</td>
                <td className="px-3 py-2.5 text-right font-bold">{r.perMonth === null ? "—" : money(r.perMonth)}</td>
              </tr>
            ))}
            {!loading && rows.length === 0 ? (
              <tr className="border-t border-slate-200">
                <td colSpan={5} className="px-3 py-3 text-slate-600">
                  No active discounts in {name}.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>

      <h3 className="mb-0 mt-1.5 text-base font-bold">Credit owed to families</h3>
      <p className="m-0 text-[13px] text-slate-600">
        Unused classes from a pause or a student leaving. The credit has no end date and is taken off the family&apos;s next invoice, for this child or a sibling.
      </p>
      <div className={`${card} relative overflow-x-auto`}>
        <table className="w-full min-w-[760px] border-collapse text-[13px]">
          <caption className="sr-only">Family credits</caption>
          <thead>
            <tr className="bg-slate-50 text-left text-slate-700">
              <th scope="col" className="px-3 py-2.5">Family</th>
              <th scope="col" className="px-3 py-2.5">Student</th>
              <th scope="col" className="px-3 py-2.5">Why</th>
              <th scope="col" className="px-3 py-2.5 text-right">Credit</th>
              <th scope="col" className="px-3 py-2.5">Status</th>
              <th scope="col" className="px-3 py-2.5"><span className="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            {sortedCredits.map((c) => {
              const family = names.get(c.parentId) ?? "—";
              const open = c.status === "open";
              const asked = asking?.id === c.id ? asking.action : null;
              return (
                <CreditRowView
                  key={c.id}
                  family={family}
                  student={c.studentId ? names.get(c.studentId) ?? "—" : "—"}
                  why={c.reason || "—"}
                  amount={money(c.amount)}
                  status={creditStatusLabel(c.status)}
                  statusClass={open ? "bg-blue-100 text-blue-900" : "bg-slate-100 text-slate-700"}
                  actions={
                    open && !asked ? (
                      <div className="flex gap-1.5">
                        <button
                          type="button"
                          className={quietButton}
                          aria-label={`Refund ${money(c.amount)} to ${family}`}
                          onClick={() => {
                            setAsking({ id: c.id, action: "refund" });
                            setReason("");
                            setProblem("");
                          }}
                          disabled={Boolean(busy)}
                        >
                          Refund
                        </button>
                        <button
                          type="button"
                          className={quietButton}
                          aria-label={`Cancel the credit for ${family}`}
                          onClick={() => {
                            setAsking({ id: c.id, action: "cancel" });
                            setReason("");
                            setProblem("");
                          }}
                          disabled={Boolean(busy)}
                        >
                          Cancel credit
                        </button>
                      </div>
                    ) : null
                  }
                  below={
                    asked ? (
                      <div className="flex flex-wrap items-end gap-1.5">
                        <label className="flex min-w-0 flex-[1_1_240px] flex-col gap-1 text-xs font-semibold text-slate-700">
                          {asked === "refund" ? `Why are you refunding ${money(c.amount)} to ${family}?` : `Why are you cancelling the credit for ${family}?`}
                          <input type="text" className={input} value={reason} maxLength={300} onChange={(e) => setReason(e.target.value)} />
                        </label>
                        <button type="button" className={dangerButton} onClick={() => void resolve(c, asked)} disabled={Boolean(busy) || !reason.trim()}>
                          {busy === c.id ? "Saving…" : asked === "refund" ? "Yes, refund" : "Yes, cancel credit"}
                        </button>
                        <button type="button" className={quietButton} onClick={() => setAsking(null)}>
                          Keep
                        </button>
                      </div>
                    ) : null
                  }
                />
              );
            })}
            {!loading && sortedCredits.length === 0 ? (
              <tr className="border-t border-slate-200">
                <td colSpan={6} className="px-3 py-3 text-slate-600">
                  No family credits.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function CreditRowView(props: {
  family: string;
  student: string;
  why: string;
  amount: string;
  status: string;
  statusClass: string;
  actions: ReactNode;
  below: ReactNode;
}) {
  return (
    <>
      <tr className="border-t border-slate-200">
        <td className="px-3 py-2.5 font-semibold">{props.family}</td>
        <td className="px-3 py-2.5">{props.student}</td>
        <td className="px-3 py-2.5 text-slate-700">{props.why}</td>
        <td className="px-3 py-2.5 text-right font-bold">{props.amount}</td>
        <td className="px-3 py-2.5">
          <span className={`rounded-full px-2 py-0.5 text-xs font-bold ${props.statusClass}`}>{props.status}</span>
        </td>
        <td className="px-3 py-2.5">{props.actions}</td>
      </tr>
      {props.below ? (
        <tr className="bg-slate-50">
          <td colSpan={6} className="px-3 py-2.5">
            {props.below}
          </td>
        </tr>
      ) : null}
    </>
  );
}
