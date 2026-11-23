"use client";

import { useState } from "react";
import { addDays, dayKeyNY, formatDay } from "@/lib/finance/invoices";
import { outlineButton, primaryButton, inputClass } from "./ui";

/**
 * "Extend access…" with a date picker. The suggested date is the end of the
 * month; staff can pick any day from tomorrow on.
 */
export function ExtendAccessControl({
  now,
  suggestedKey,
  busy,
  disabled,
  compact,
  onExtend,
}: {
  now: Date;
  suggestedKey: string;
  busy: boolean;
  disabled: boolean;
  compact?: boolean;
  onExtend: (dayKey: string, label: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [day, setDay] = useState(suggestedKey);
  const tomorrow = addDays(dayKeyNY(now), 1);
  const valid = /^\d{4}-\d{2}-\d{2}$/.test(day) && day >= tomorrow;
  const size = compact ? " !min-h-8 !px-2.5" : "";

  if (!open) {
    return (
      <button
        type="button"
        className={`${outlineButton}${size}`}
        disabled={disabled}
        onClick={() => {
          setDay(suggestedKey);
          setOpen(true);
        }}
      >
        {busy ? "Extending…" : "Extend access…"}
      </button>
    );
  }
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      <label className="flex items-center gap-1.5 text-xs font-semibold text-slate-700">
        Until
        <input className={`${inputClass} !min-h-8 !w-auto !py-1`} type="date" min={tomorrow} value={day} onChange={(e) => setDay(e.target.value)} aria-label="Extend access until" />
      </label>
      <button
        type="button"
        className={`${primaryButton}${size}`}
        disabled={!valid || disabled}
        onClick={() => {
          setOpen(false);
          onExtend(day, formatDay(day));
        }}
      >
        Extend
      </button>
      <button type="button" className={`${outlineButton}${size}`} onClick={() => setOpen(false)}>
        Cancel
      </button>
      {!valid ? <span className="w-full text-xs font-semibold text-amber-800">Pick a day from {formatDay(tomorrow)} on.</span> : null}
    </div>
  );
}
