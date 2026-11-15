"use client";

import { AlertCircle, Loader2, type LucideIcon } from "lucide-react";
import type { ReactNode } from "react";

/**
 * Small pieces every parent screen repeats in Flutter: `_emptyCard`,
 * `_errorCard`, the section heading and the centred spinner.
 */

export function ParentEmptyCard({ icon: Icon, title, subtitle }: { icon: LucideIcon; title: string; subtitle: string }) {
  return (
    <div className="flex items-center gap-3 rounded-2xl border border-[#E5E7EB] bg-white p-4">
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] text-[#6B7280]">
        <Icon size={24} />
      </span>
      <div className="min-w-0">
        <p className="text-[13px] font-extrabold text-[#111827]">{title}</p>
        <p className="mt-0.5 text-xs font-medium text-[#6B7280]">{subtitle}</p>
      </div>
    </div>
  );
}

export function ParentErrorCard({ message, onRetry, retryLabel }: { message: string; onRetry?: () => void; retryLabel?: string }) {
  return (
    <div role="alert" className="flex items-center gap-2.5 rounded-2xl border border-[#FECACA] bg-[#FEF2F2] p-4">
      <AlertCircle size={24} className="shrink-0 text-[#DC2626]" />
      <p className="min-w-0 flex-1 text-xs font-semibold text-[#7F1D1D]">{message}</p>
      {onRetry ? (
        <button type="button" onClick={onRetry} className="min-h-9 shrink-0 rounded-lg px-3 text-xs font-bold text-[#B91C1C] hover:bg-[#FEE2E2]">
          {retryLabel}
        </button>
      ) : null}
    </div>
  );
}

export function ParentSectionHeader({ children, action }: { children: ReactNode; action?: ReactNode }) {
  return (
    <div className="flex min-h-10 items-center gap-2">
      <h2 className="min-w-0 flex-1 text-base font-extrabold text-[#111827]">{children}</h2>
      {action}
    </div>
  );
}

/** Flutter's centred CircularProgressIndicator (36 px, brand blue). */
export function ParentSpinner({ padding = 12, label }: { padding?: number; label: string }) {
  return (
    <div className="flex justify-center" style={{ padding }} role="status" aria-label={label}>
      <Loader2 size={36} className="animate-spin text-[#0386FF]" />
    </div>
  );
}

/** White card with the soft 0 6 12 shadow most Flutter parent cards use. */
export const cardShadow = "shadow-[0_6px_12px_rgba(0,0,0,0.04)]";

/** Hex colour + alpha, for Flutter's `color.withOpacity(x)`. */
export function alpha(hex: string, value: number) {
  const n = Number.parseInt(hex.replace("#", ""), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${value})`;
}
