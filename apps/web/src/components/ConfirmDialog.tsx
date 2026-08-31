"use client";

import { useEffect, useRef } from "react";
import { AlertTriangle } from "lucide-react";
import { useT } from "@/lib/i18n";

/**
 * Confirmation before an action that is hard to take back.
 *
 * The Flutter app puts an AlertDialog in front of signing out, deleting a
 * message, blocking someone and so on; the web dashboard needs the same pause.
 * This is a real dialog rather than window.confirm so it can be styled, carry
 * the destructive colour, and be dismissed with Escape or a click outside.
 */
export type ConfirmRequest = {
  title: string;
  body: string;
  confirmLabel: string;
  destructive?: boolean;
  onConfirm: () => void;
};

export function ConfirmDialog({ request, onClose }: { request: ConfirmRequest | null; onClose: () => void }) {
  const t = useT();
  const confirmRef = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    if (!request) return;
    // Focus the confirm button so the dialog is reachable by keyboard, and let
    // Escape dismiss it the way a native dialog would.
    confirmRef.current?.focus();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [request, onClose]);

  if (!request) return null;
  const destructive = request.destructive !== false;

  return (
    <div className="fixed inset-0 z-[100] grid place-items-center p-4" role="dialog" aria-modal="true" aria-labelledby="confirm-title">
      <button type="button" aria-label={t("Cancel")} onClick={onClose} className="absolute inset-0 cursor-default bg-black/45" />
      <section className="relative w-full max-w-sm rounded-2xl bg-white p-6 shadow-2xl">
        <div className="flex items-start gap-3">
          <span
            className={`grid h-10 w-10 shrink-0 place-items-center rounded-xl ${
              destructive ? "bg-[#FEE2E2] text-[#DC2626]" : "bg-[#DBEAFE] text-[#2563EB]"
            }`}
          >
            <AlertTriangle size={20} />
          </span>
          <div className="min-w-0">
            <h2 id="confirm-title" className="text-base font-black text-[#0F172A]">
              {request.title}
            </h2>
            <p className="mt-1 text-sm leading-6 text-[#475569]">{request.body}</p>
          </div>
        </div>
        <div className="mt-5 flex justify-end gap-2">
          <button
            type="button"
            onClick={onClose}
            className="inline-flex min-h-10 items-center rounded-xl border border-[#E2E8F0] px-4 text-sm font-bold text-[#334155] hover:bg-[#F1F5F9]"
          >
            {t("Cancel")}
          </button>
          <button
            ref={confirmRef}
            type="button"
            onClick={() => {
              request.onConfirm();
              onClose();
            }}
            className={`inline-flex min-h-10 items-center rounded-xl px-4 text-sm font-black text-white ${
              destructive ? "bg-[#DC2626] hover:bg-[#B91C1C]" : "bg-[#2563EB] hover:bg-[#1D4ED8]"
            }`}
          >
            {request.confirmLabel}
          </button>
        </div>
      </section>
    </div>
  );
}
