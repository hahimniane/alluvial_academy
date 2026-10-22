"use client";

import { monthLabel } from "@/lib/finance/months";
import type { PeriodKind } from "@/lib/finance/overview";

const OPTIONS: ReadonlyArray<{ kind: PeriodKind; label: string }> = [
  { kind: "1", label: "1 month" },
  { kind: "3", label: "3 months" },
  { kind: "5", label: "5 months" },
  { kind: "custom", label: "Custom" },
];

type Props = {
  kind: PeriodKind;
  onKind: (kind: PeriodKind) => void;
  from: string;
  to: string;
  onFrom: (month: string) => void;
  onTo: (month: string) => void;
  /** Months offered in the custom pickers, oldest first. */
  choices: string[];
  /** The month picked at the top; 1, 3 and 5 months end with it. */
  endMonth: string;
};

const selectClass = "h-11 rounded-lg border border-slate-300 bg-white px-2 text-sm";

export function PeriodControls({ kind, onKind, from, to, onFrom, onTo, choices, endMonth }: Props) {
  return (
    <div className="flex flex-wrap items-end gap-3">
      <div className="flex flex-col gap-1">
        <span id="fin-period-label" className="text-xs font-semibold text-slate-700">Show</span>
        <div role="group" aria-labelledby="fin-period-label" className="inline-flex overflow-hidden rounded-[10px] border border-slate-300">
          {OPTIONS.map((o) => {
            const on = kind === o.kind;
            return (
              <button
                key={o.kind}
                type="button"
                aria-pressed={on}
                onClick={() => onKind(o.kind)}
                className={`h-11 min-w-11 px-3.5 text-sm font-bold ${on ? "bg-[#0386FF] text-white" : "bg-white text-slate-800 hover:bg-slate-50"}`}
              >
                {o.label}
              </button>
            );
          })}
        </div>
      </div>
      {kind === "custom" ? (
        <>
          <label className="flex flex-col gap-1 text-xs font-semibold text-slate-700">
            From
            <select value={from} onChange={(e) => onFrom(e.target.value)} className={selectClass}>
              {choices.map((m) => (
                <option key={m} value={m}>
                  {monthLabel(m)}
                </option>
              ))}
            </select>
          </label>
          <label className="flex flex-col gap-1 text-xs font-semibold text-slate-700">
            To
            <select value={to} onChange={(e) => onTo(e.target.value)} className={selectClass}>
              {choices.map((m) => (
                <option key={m} value={m}>
                  {monthLabel(m)}
                </option>
              ))}
            </select>
          </label>
        </>
      ) : (
        <span className="pb-3 text-xs text-slate-600">Ending with the month picked at the top ({monthLabel(endMonth)})</span>
      )}
    </div>
  );
}
