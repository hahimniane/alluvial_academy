"use client";

import { httpsCallable } from "firebase/functions";
import { useEffect, useRef, type ReactNode } from "react";
import { functions } from "@/lib/firebase";

/** Small building blocks shared by the finance pages. */

export const BTN = "inline-flex min-h-10 items-center justify-center rounded-lg border border-slate-300 bg-white px-3.5 text-sm font-semibold text-slate-900 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50";
export const BTN_SM = "inline-flex min-h-9 items-center justify-center rounded-lg border border-slate-300 bg-white px-3 text-sm font-semibold text-slate-900 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50";
export const BTN_PRIMARY = "inline-flex min-h-10 items-center justify-center rounded-lg bg-[#0386FF] px-4 text-sm font-bold text-white hover:bg-[#0274e0] disabled:cursor-not-allowed disabled:bg-slate-200 disabled:text-slate-500";
export const INPUT = "h-10 w-full rounded-lg border border-slate-300 bg-white px-2.5 text-sm";
export const CARD = "rounded-xl border border-slate-200 bg-white";

export const BADGE = {
  info: "bg-[#E0F0FF] text-[#024E96]",
  warn: "bg-amber-100 text-amber-900",
  ok: "bg-green-100 text-green-800",
  mute: "bg-slate-100 text-slate-600",
  bad: "bg-red-100 text-red-800",
} as const;

export function Badge({ tone, children }: { tone: keyof typeof BADGE; children: ReactNode }) {
  return <span className={`inline-block whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-bold ${BADGE[tone]}`}>{children}</span>;
}

export function Field({ label, children, hint }: { label: string; children: ReactNode; hint?: string }) {
  return (
    <label className="flex min-w-0 flex-col gap-1 text-xs font-semibold text-slate-700">
      {label}
      {children}
      {hint ? <span className="font-normal text-slate-500">{hint}</span> : null}
    </label>
  );
}

export function StatCard({ label, value, sub, tone }: { label: string; value: string; sub: string; tone?: "bad" }) {
  return (
    <div className={`${CARD} min-w-0 p-3`}>
      <div className="text-xs font-semibold text-slate-600">{label}</div>
      <div className={`text-lg font-extrabold ${tone === "bad" ? "text-red-700" : ""}`}>{value}</div>
      <div className="text-xs text-slate-600">{sub}</div>
    </div>
  );
}

/** A centred dialog: Escape closes it, focus moves into it, the page behind is dimmed. */
export function Modal({ title, onClose, children, wide }: { title: string; onClose: () => void; children: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    const first = ref.current?.querySelector<HTMLElement>("input,select,textarea,button:not([data-close])");
    (first ?? ref.current)?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("keydown", onKey);
      previous?.focus?.();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <div className="fixed inset-0 z-20 flex items-start justify-center overflow-y-auto bg-slate-900/45 px-4 py-10">
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        className={`flex w-full flex-col gap-3 rounded-2xl bg-white p-5 shadow-xl ${wide ? "max-w-xl" : "max-w-md"}`}
      >
        <div className="flex items-center gap-2">
          <h2 className="flex-1 text-lg font-extrabold">{title}</h2>
          <button type="button" data-close aria-label="Close" onClick={onClose} className="h-9 w-9 rounded-lg border border-slate-300 bg-white text-lg">
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function ErrorText({ message }: { message: string }) {
  return message ? (
    <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
      {message}
    </p>
  ) : null;
}

export function Toast({ message }: { message: string }) {
  return message ? (
    <div role="status" className="fixed bottom-6 left-1/2 z-30 max-w-[90%] -translate-x-1/2 rounded-xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white">
      {message}
    </div>
  ) : null;
}

/** Calls a finance callable and turns a failure into the plain sentence the server sent. */
export async function callFinance<T = { ok: boolean }>(name: string, data: unknown): Promise<T> {
  try {
    const res = await httpsCallable<unknown, T>(functions, name)(data);
    return res.data;
  } catch (e) {
    const message = e instanceof Error ? e.message : "";
    throw new Error(message && !/^internal$/i.test(message) ? message : "Something went wrong. Nothing was saved. Try again.");
  }
}
