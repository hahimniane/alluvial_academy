"use client";

import { collection, doc, getDoc, getDocs, query, where } from "firebase/firestore";
import { useCallback, useEffect, useState } from "react";
import { db } from "@/lib/firebase";
import { addMonths } from "@/lib/finance/months";
import type { AdminTerms, Payout, StaffSummary } from "@/lib/finance/staff";
import { callFinance } from "./staffUi";

export type StaffData = {
  summary: StaffSummary;
  /** This month's payouts by uid (voided ones included, so the page can show them). */
  payouts: Map<string, Payout>;
  /** Method used for each person last month, for "usual method". */
  usualMethod: Map<string, string>;
  terms: Map<string, AdminTerms>;
  /** users/{uid}.is_active === false for these administrators. */
  deactivated: Set<string>;
  closedMonths: Set<string>;
};

async function loadPayouts(month: string): Promise<Payout[]> {
  const snap = await getDocs(query(collection(db, "staff_payouts"), where("month", "==", month)));
  return snap.docs.map((d) => d.data() as Payout);
}

export function useStaffData(month: string) {
  const [data, setData] = useState<StaffData | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let live = true;
    setLoading(true);
    setError("");
    (async () => {
      try {
        const [summary, payouts, previous, termsSnap, closedSnap] = await Promise.all([
          callFinance<StaffSummary>("getFinanceMonthSummary", { month }),
          loadPayouts(month),
          loadPayouts(addMonths(month, -1)),
          getDocs(collection(db, "admin_pay_terms")),
          getDocs(query(collection(db, "finance_months"), where("status", "==", "closed"))),
        ]);
        const terms = new Map<string, AdminTerms>();
        termsSnap.docs.forEach((d) => {
          const x = d.data() as Partial<AdminTerms>;
          terms.set(d.id, { uid: d.id, name: x.name, role_title: x.role_title, terms: x.terms ?? [], pauses: x.pauses ?? [] });
        });
        const deactivated = new Set<string>();
        await Promise.all(
          summary.admins.map(async (a) => {
            const u = await getDoc(doc(db, "users", a.uid)).catch(() => null);
            if (u?.exists() && u.data().is_active === false) deactivated.add(a.uid);
          })
        );
        if (!live) return;
        const usualMethod = new Map<string, string>();
        previous.filter((p) => !p.voided && p.method).forEach((p) => usualMethod.set(p.user_id, p.method));
        setData({
          summary,
          payouts: new Map(payouts.map((p) => [p.user_id, p])),
          usualMethod,
          terms,
          deactivated,
          closedMonths: new Set(closedSnap.docs.map((d) => d.id)),
        });
      } catch (e) {
        if (live) setError(e instanceof Error ? e.message : "Staff pay could not be loaded.");
      } finally {
        if (live) setLoading(false);
      }
    })();
    return () => {
      live = false;
    };
  }, [month, tick]);

  const reload = useCallback(() => setTick((t) => t + 1), []);
  return { data, error, loading, reload };
}
