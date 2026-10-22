"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { auth } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";
import { currentMonth, monthFromParam, monthLabel, recentMonths } from "@/lib/finance/months";

/**
 * Frame for every finance page. Finance only renders inside the Flutter web
 * app's content area (same-origin iframe, `?embed=1`), like Shifts, so admins
 * keep their real Flutter sidebar; a direct visit goes to the Flutter app.
 * The finance sub-menu and the month picker live here so every page shares
 * them. The selected month is the `month` search param (yyyy-MM).
 */

type Access = "checking" | "signedOut" | "allowed" | "denied";

type FinanceContextValue = {
  user: User | null;
  month: string;
  setMonth: (month: string) => void;
};

const FinanceContext = createContext<FinanceContextValue | null>(null);

export function useFinance(): FinanceContextValue {
  const value = useContext(FinanceContext);
  if (!value) throw new Error("useFinance must be used inside FinanceShell");
  return value;
}

export const FINANCE_NAV: ReadonlyArray<{ href: string; label: string }> = [
  { href: "/admin/finance/", label: "Overview" },
  { href: "/admin/finance/bank/", label: "Bank deposits" },
  { href: "/admin/finance/invoices/", label: "Invoices" },
  { href: "/admin/finance/staff/", label: "Staff pay" },
  { href: "/admin/finance/penalties/", label: "Penalties" },
  { href: "/admin/finance/expenses/", label: "Expenses" },
  { href: "/admin/finance/discounts/", label: "Discounts & credits" },
  { href: "/admin/finance/students/", label: "New students" },
  { href: "/admin/finance/close/", label: "Close month" },
  { href: "/admin/finance/settings/", label: "Settings" },
];

export function FinanceShell({ children, badges }: { children: ReactNode; badges?: Record<string, number> }) {
  const pathname = usePathname() || "";
  const router = useRouter();
  const params = useSearchParams();
  const [embedded, setEmbedded] = useState(false);
  const [access, setAccess] = useState<Access>("checking");
  const [user, setUser] = useState<User | null>(null);

  const month = monthFromParam(params?.get("month"));
  const months = useMemo(() => recentMonths(13, currentMonth()), []);

  useEffect(() => {
    const inFlutterFrame = window.self !== window.top || new URLSearchParams(window.location.search).has("embed");
    if (inFlutterFrame) setEmbedded(true);
    else window.location.replace("/app/");
  }, []);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (next) => {
      if (!mounted) return;
      setUser(next);
      if (!next) {
        setAccess("signedOut");
        return;
      }
      const ok = await isCurrentUserAdmin(next).catch(() => false);
      if (mounted) setAccess(ok ? "allowed" : "denied");
    });
  }, []);

  const query = (m: string) => {
    const q = new URLSearchParams(params?.toString() || "");
    q.set("month", m);
    q.set("embed", "1");
    return q.toString();
  };
  const setMonth = (m: string) => router.replace(`${pathname}?${query(m)}`);

  if (!embedded) return null;
  if (access === "checking") return <p className="p-6 text-sm text-slate-600">Loading…</p>;
  if (access !== "allowed") {
    return (
      <main className="p-6">
        <h1 className="text-lg font-bold text-slate-900">Finance</h1>
        <p className="mt-2 text-sm text-slate-600">{access === "signedOut" ? "Sign in to see finance." : "Finance is for administrators."}</p>
      </main>
    );
  }

  return (
    <FinanceContext.Provider value={{ user, month, setMonth }}>
      <div className="min-h-screen bg-[#F1F5F9] font-sans text-[#0F172A]">
        <div className="flex flex-wrap items-center gap-3 border-b border-slate-200 bg-white px-4 py-3">
          <h1 className="text-base font-extrabold">Finance</h1>
          <div className="flex-1" />
          <label className="flex items-center gap-2 text-sm font-semibold">
            Month
            <select
              value={month}
              onChange={(e) => setMonth(e.target.value)}
              className="h-9 rounded-lg border border-slate-300 bg-white px-2 text-sm"
            >
              {months.map((m) => (
                <option key={m} value={m}>
                  {monthLabel(m)}
                </option>
              ))}
            </select>
          </label>
        </div>
        <div className="mx-auto flex max-w-[1480px] flex-wrap items-start gap-5 p-4">
          <nav aria-label="Finance sections" className="flex w-full max-w-[260px] flex-[1_1_220px] flex-col gap-0.5 rounded-xl border border-slate-200 bg-white p-2">
            {FINANCE_NAV.map((item) => {
              const active = item.href === "/admin/finance/" ? pathname === "/admin/finance" || pathname === "/admin/finance/" : pathname.startsWith(item.href.replace(/\/$/, ""));
              const badge = badges?.[item.href] ?? 0;
              return (
                <Link
                  key={item.href}
                  href={`${item.href}?${query(month)}`}
                  className={`flex min-h-11 items-center justify-between gap-2 rounded-lg px-3 text-sm ${active ? "bg-[#E0F0FF] font-bold text-[#024E96]" : "font-medium text-slate-800 hover:bg-slate-50"}`}
                >
                  <span>{item.label}</span>
                  {badge > 0 ? (
                    <span className="inline-flex h-[22px] min-w-[22px] items-center justify-center rounded-full bg-amber-100 px-1.5 text-xs font-bold text-amber-900">{badge}</span>
                  ) : null}
                </Link>
              );
            })}
          </nav>
          <main className="flex min-w-0 flex-[999_1_560px] flex-col gap-4">{children}</main>
        </div>
      </div>
    </FinanceContext.Provider>
  );
}

/** Shown by a page that is not built yet. */
export function FinancePlaceholder({ title }: { title: string }) {
  return (
    <section className="rounded-xl border border-slate-200 bg-white p-6">
      <h2 className="text-xl font-extrabold">{title}</h2>
    </section>
  );
}
