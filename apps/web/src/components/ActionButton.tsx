"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Loader2 } from "lucide-react";

/**
 * Every button that writes something uses this.
 *
 * Two guarantees, both structural rather than remembered:
 *  1. It disables itself the moment it is clicked and stays disabled until the
 *     work finishes — a second click cannot start a second save. Creating a
 *     repeating class writes dozens of documents, so a double click used to
 *     mean a doubled schedule.
 *  2. Work that loops over many classes reports "3 of 19" as it goes, so an
 *     admin can see it is running and never wonders whether it worked.
 */

export type ProgressReporter = (done: number, total: number) => void;

type Variant = "primary" | "danger" | "ghost" | "subtle";

const VARIANT_CLASS: Record<Variant, string> = {
  primary: "bg-[#0386FF] text-white hover:bg-[#0271d6]",
  danger: "bg-[#DC2626] text-white hover:bg-[#b91c1c]",
  ghost: "text-[#DC2626] hover:bg-[#FEF2F2]",
  subtle: "border border-[#E2E8F0] text-[#334155] hover:bg-[#F8FAFC]",
};

export function ActionButton({
  label,
  busyLabel,
  onAction,
  variant = "primary",
  disabled,
  title,
  className = "",
  icon,
}: {
  label: string;
  /** Shown while running, e.g. "Creating…". Defaults to "Working…". */
  busyLabel?: string;
  onAction: (report: ProgressReporter) => Promise<void> | void;
  variant?: Variant;
  disabled?: boolean;
  title?: string;
  className?: string;
  icon?: React.ReactNode;
}) {
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null);
  const alive = useRef(true);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);

  const run = useCallback(async () => {
    if (busy) return; // belt and braces: the disabled attribute plus a guard
    setBusy(true);
    setProgress(null);
    try {
      await onAction((done, total) => {
        if (alive.current) setProgress({ done, total });
      });
    } finally {
      // The dialog often closes on success; only touch state if still mounted.
      if (alive.current) {
        setBusy(false);
        setProgress(null);
      }
    }
  }, [busy, onAction]);

  const text = busy
    ? progress && progress.total > 1
      ? `${busyLabel ?? "Working…"} ${progress.done} of ${progress.total}`
      : (busyLabel ?? "Working…")
    : label;

  return (
    <button
      type="button"
      onClick={() => void run()}
      disabled={busy || disabled}
      title={title}
      aria-busy={busy}
      className={`relative inline-flex items-center justify-center gap-2 overflow-hidden rounded-xl px-5 py-2.5 text-sm font-bold disabled:opacity-60 ${VARIANT_CLASS[variant]} ${className}`}
    >
      {busy ? <Loader2 size={15} className="animate-spin" /> : icon}
      {text}
      {busy && progress && progress.total > 1 ? (
        <span
          className="absolute bottom-0 left-0 h-0.5 bg-white/70 transition-[width] duration-200"
          style={{ width: `${Math.round((progress.done / progress.total) * 100)}%` }}
        />
      ) : null}
    </button>
  );
}
