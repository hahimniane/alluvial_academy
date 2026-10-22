"use client";

import { useEffect, useRef, type ReactNode } from "react";
import type { BadgeTone } from "@/lib/finance/invoices";

/** Small shared pieces for the finance Invoices and New students screens. */

const TONES: Record<BadgeTone, string> = {
  ok: "bg-green-100 text-green-900",
  warn: "bg-amber-100 text-amber-900",
  bad: "bg-red-100 text-red-900",
  info: "bg-blue-100 text-blue-900",
  mute: "bg-slate-200 text-slate-900",
  purple: "bg-violet-100 text-violet-900",
};

export function Badge({ tone, children }: { tone: BadgeTone; children: ReactNode }) {
  return <span className={`inline-block whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-bold ${TONES[tone]}`}>{children}</span>;
}

export const inputClass = "h-10 w-full rounded-lg border border-slate-300 bg-white px-2.5 text-sm text-slate-900 disabled:bg-slate-100";
export const primaryButton =
  "inline-flex min-h-10 items-center justify-center rounded-lg bg-[#0386FF] px-4 text-sm font-bold text-white hover:bg-[#0277e6] disabled:cursor-not-allowed disabled:opacity-50";
export const outlineButton =
  "inline-flex min-h-10 items-center justify-center rounded-lg border border-slate-300 bg-white px-3.5 text-sm font-semibold text-slate-900 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50";
export const blueOutlineButton =
  "inline-flex min-h-10 items-center justify-center rounded-lg border border-[#0386FF] bg-white px-3.5 text-sm font-bold text-[#024E96] hover:bg-[#F0F7FF] disabled:cursor-not-allowed disabled:opacity-50";
export const dangerButton =
  "inline-flex min-h-10 items-center justify-center rounded-lg border border-red-700 bg-white px-3.5 text-sm font-bold text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50";

export function Field({ label, children, className = "" }: { label: string; children: ReactNode; className?: string }) {
  return (
    <label className={`flex flex-col gap-1 text-xs font-semibold text-slate-700 ${className}`}>
      {label}
      {children}
    </label>
  );
}

const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Modal dialog: labelled, Escape closes, focus moves in and comes back, Tab
 * stays inside, the page behind does not scroll.
 */
export function Modal({ label, onClose, maxWidth = "max-w-[640px]", children }: { label: string; onClose: () => void; maxWidth?: string; children: ReactNode }) {
  const panel = useRef<HTMLDivElement>(null);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    const node = panel.current;
    node?.focus();
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.stopPropagation();
        closeRef.current();
        return;
      }
      if (e.key !== "Tab" || !node) return;
      const items = Array.from(node.querySelectorAll<HTMLElement>(FOCUSABLE)).filter((el) => el.offsetParent !== null);
      if (items.length === 0) return;
      const first = items[0];
      const last = items[items.length - 1];
      if (e.shiftKey && (document.activeElement === first || document.activeElement === node)) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = overflow;
      previous?.focus?.();
    };
  }, []);

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-slate-900/45 px-3 py-6 sm:px-4 sm:py-10">
      <div ref={panel} role="dialog" aria-modal="true" aria-label={label} tabIndex={-1} className={`flex w-full ${maxWidth} flex-col gap-3.5 rounded-2xl bg-white p-4 shadow-xl outline-none sm:p-5`}>
        {children}
      </div>
    </div>
  );
}

export function CloseButton({ onClick }: { onClick: () => void }) {
  return (
    <button type="button" aria-label="Close" onClick={onClick} className="h-10 w-10 shrink-0 rounded-lg border border-slate-300 bg-white text-lg leading-none text-slate-900 hover:bg-slate-50">
      ×
    </button>
  );
}

export function Notice({ tone, children }: { tone: "error" | "info" | "ok"; children: ReactNode }) {
  const cls = tone === "error" ? "border-red-200 bg-red-50 text-red-900" : tone === "ok" ? "border-green-200 bg-green-50 text-green-900" : "border-blue-200 bg-blue-50 text-blue-900";
  return (
    <div role={tone === "error" ? "alert" : "status"} className={`rounded-lg border px-3 py-2 text-sm ${cls}`}>
      {children}
    </div>
  );
}
