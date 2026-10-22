"use client";

import { money0 } from "@/lib/finance/model";
import { monthShort } from "@/lib/finance/months";
import { barHeight, isEstimate, marginPercent, otherCosts, sumMonths } from "@/lib/finance/overview";
import type { MonthSummary } from "@/lib/finance/summary";

const cell = "px-3 py-2.5 text-right";
const profitClass = (n: number) => (n >= 0 ? "text-green-700" : "text-red-700");

/** Profit bars and the month-by-month table with Total and Average rows. */
export function MonthTable({ rows }: { rows: MonthSummary[] }) {
  if (rows.length === 0) return null;
  const totals = sumMonths(rows);
  const n = rows.length;
  const maxProfit = Math.max(1, ...rows.map((r) => Math.abs(r.profit)));
  return (
    <section aria-labelledby="fin-month-by-month" className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4">
      <h2 id="fin-month-by-month" className="m-0 text-base font-bold">Month by month</h2>
      <div aria-hidden="true" className="flex h-[130px] items-end gap-2.5 overflow-x-auto">
        {rows.map((r) => (
          <div key={r.month} className="flex min-w-14 flex-[1_1_60px] flex-col items-center gap-1">
            <span className="text-[11px] font-bold">{money0(r.profit)}</span>
            <div
              className="w-7 rounded-t"
              style={{
                height: barHeight(Math.abs(r.profit), maxProfit, 90) || 4,
                background: r.profit >= 0 ? (isEstimate(r) ? "#86EFAC" : "#16A34A") : "#DC2626",
              }}
            />
            <span className="text-xs font-semibold">{monthShort(r.month)}</span>
          </div>
        ))}
      </div>
      <div className="relative overflow-x-auto">
        <table className="w-full min-w-[820px] border-collapse text-[13px]">
          <caption className="sr-only">Billed, costs and profit for each month</caption>
          <thead>
            <tr className="bg-slate-50 text-right text-slate-700">
              <th scope="col" className="px-3 py-2.5 text-left">Month</th>
              <th scope="col" className={cell}>Billed</th>
              <th scope="col" className={cell}>Collected</th>
              <th scope="col" className={cell}>Teacher pay</th>
              <th scope="col" className={cell}>Administrator pay</th>
              <th scope="col" className={cell}>Other costs</th>
              <th scope="col" className={cell}>Expenses</th>
              <th scope="col" className={cell}>Profit</th>
              <th scope="col" className={cell}>Margin</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.month} className="border-t border-slate-200 text-right">
                <th scope="row" className="px-3 py-2.5 text-left font-semibold">
                  {monthShort(r.month)}
                  {isEstimate(r) ? " (est.)" : ""}
                </th>
                <td className={cell}>{money0(r.billed)}</td>
                <td className={cell}>{money0(r.collected)}</td>
                <td className={cell}>{money0(r.teacher_pay)}</td>
                <td className={cell}>{money0(r.admin_pay)}</td>
                <td className={cell}>{money0(otherCosts(r))}</td>
                <td className={cell}>{money0(r.expenses)}</td>
                <td className={`${cell} font-extrabold ${profitClass(r.profit)}`}>{money0(r.profit)}</td>
                <td className={cell}>{marginPercent(r.profit, r.billed)}%</td>
              </tr>
            ))}
            <tr className="border-t-2 border-slate-300 bg-slate-50 text-right font-extrabold">
              <th scope="row" className="px-3 py-2.5 text-left">Total</th>
              <td className={cell}>{money0(totals.billed)}</td>
              <td className={cell}>{money0(totals.collected)}</td>
              <td className={cell}>{money0(totals.teacher_pay)}</td>
              <td className={cell}>{money0(totals.admin_pay)}</td>
              <td className={cell}>{money0(totals.otherCosts)}</td>
              <td className={cell}>{money0(totals.expenses)}</td>
              <td className={cell}>{money0(totals.profit)}</td>
              <td className={cell}>{marginPercent(totals.profit, totals.billed)}%</td>
            </tr>
            <tr className="text-right text-slate-700">
              <th scope="row" className="px-3 py-2.5 text-left font-semibold">Average a month</th>
              <td className={cell}>{money0(totals.billed / n)}</td>
              <td className={cell}>{money0(totals.collected / n)}</td>
              <td className={cell}>{money0(totals.teacher_pay / n)}</td>
              <td className={cell}>{money0(totals.admin_pay / n)}</td>
              <td className={cell}>{money0(totals.otherCosts / n)}</td>
              <td className={cell}>{money0(totals.expenses / n)}</td>
              <td className={`${cell} font-bold`}>{money0(totals.profit / n)}</td>
              <td className={cell} />
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  );
}
