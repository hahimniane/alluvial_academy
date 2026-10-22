"use client";

import { money0 } from "@/lib/finance/model";
import { barHeight, type YearPoint } from "@/lib/finance/overview";

const FULL = 160;

/** Billed and expenses for the last twelve months, with profit under each month. */
export function YearChart({ points, loading }: { points: YearPoint[]; loading: boolean }) {
  const max = Math.max(1, ...points.flatMap((p) => [p.billed, p.expenses]));
  return (
    <section aria-labelledby="fin-year" className="min-w-0 flex-[2_1_420px] rounded-xl border border-slate-200 bg-white p-4">
      <h2 id="fin-year" className="m-0 mb-1 text-base font-bold">Last 12 months</h2>
      <div className="mb-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-slate-600">
        <span className="inline-flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-sm bg-[#0386FF]" />Billed</span>
        <span className="inline-flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-sm bg-[#F59E0B]" />Expenses</span>
        <span>Profit under each month. Lighter bars are estimates.</span>
      </div>
      {points.length === 0 ? (
        <p className="m-0 py-10 text-center text-sm text-slate-600">{loading ? "Loading…" : "No months to show."}</p>
      ) : (
        <div className="relative overflow-x-auto">
          <ol className="m-0 grid list-none items-end gap-2 p-0" style={{ gridTemplateColumns: `repeat(${points.length}, minmax(44px, 1fr))`, minWidth: points.length * 52 }}>
            {points.map((p) => (
              <li
                key={p.month}
                aria-label={`${p.short}: billed ${money0(p.billed)}, expenses ${money0(p.expenses)}, profit ${money0(p.profit)}${p.estimate ? ", estimate" : ""}`}
                className="flex flex-col items-center gap-1"
              >
                <div aria-hidden="true" className="flex items-end gap-[3px]" style={{ height: FULL + 10 }}>
                  <div className="w-3.5 rounded-t-[3px]" style={{ height: barHeight(p.billed, max, FULL), background: p.estimate ? "#93C5FD" : "#0386FF" }} />
                  <div className="w-3.5 rounded-t-[3px]" style={{ height: barHeight(p.expenses, max, FULL), background: p.estimate ? "#FCD34D" : "#F59E0B" }} />
                </div>
                <div aria-hidden="true" className="text-xs font-semibold">{p.short}</div>
                <div aria-hidden="true" className={`text-[11px] font-bold ${p.profit >= 0 ? "text-green-700" : "text-red-700"}`}>{money0(p.profit)}</div>
              </li>
            ))}
          </ol>
        </div>
      )}
    </section>
  );
}
