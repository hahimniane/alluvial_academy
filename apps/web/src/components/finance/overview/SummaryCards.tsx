"use client";

import { money0 } from "@/lib/finance/model";
import { monthName } from "@/lib/finance/months";
import { isEstimate, marginPercent, sumMonths, type Insights } from "@/lib/finance/overview";
import type { MonthSummary } from "@/lib/finance/summary";

type Card = { label: string; value: string; sub: string; tone?: "good" | "bad" | "plain" };

const toneClass = (tone?: Card["tone"]) => (tone === "bad" ? "text-red-700" : tone === "good" ? "text-green-700" : "");

/** The five headline numbers for the period. Shows dashes until every month has loaded. */
export function TopCards({ months, rows, complete }: { months: string[]; rows: MonthSummary[]; complete: boolean }) {
  const n = months.length;
  const single = n === 1;
  let cards: Card[];
  if (!complete || rows.length === 0) {
    cards = ["Billed", "Collected", "Still owed", "Expenses", "Profit"].map((label) => ({ label, value: "—", sub: "Loading…" }));
  } else {
    const t = sumMonths(rows);
    const estimate = rows.some(isEstimate);
    const row = rows[0];
    cards = [
      { label: "Billed", value: money0(t.billed), sub: single ? `${row.invoice_count} invoices for ${monthName(row.month)}` : `Avg ${money0(t.billed / n)} a month` },
      { label: "Collected", value: money0(t.collected), sub: `${t.billed > 0 ? Math.round((t.collected / t.billed) * 100) : 0}% of billed` },
      {
        label: "Still owed",
        value: money0(t.owed),
        sub: single ? `${row.families_owing} families` : `Across ${n} months`,
        tone: t.owed > 0 ? "bad" : "plain",
      },
      { label: "Expenses", value: money0(t.expenses), sub: single ? (estimate ? "Includes estimates" : "Final") : `Avg ${money0(t.expenses / n)} a month` },
      {
        label: estimate ? "Profit (estimate)" : "Profit",
        value: money0(t.profit),
        sub: single ? "Billed − expenses" : `${marginPercent(t.profit, t.billed)}% margin · avg ${money0(t.profit / n)}`,
        tone: t.profit >= 0 ? "good" : "bad",
      },
    ];
  }
  return (
    <ul className="grid list-none grid-cols-2 gap-3 p-0 sm:grid-cols-3 xl:grid-cols-5">
      {cards.map((c) => (
        <li key={c.label} className="min-w-0 rounded-xl border border-slate-200 bg-white p-3.5">
          <div className="text-xs font-semibold text-slate-600">{c.label}</div>
          <div className={`mt-1.5 text-[22px] font-extrabold ${toneClass(c.tone)}`}>{c.value}</div>
          <div className="mt-1 text-xs text-slate-600">{c.sub}</div>
        </li>
      ))}
    </ul>
  );
}

/** Best and weakest month, average profit and the change against the months before. */
export function InsightCards({ insights, count }: { insights: Insights | null; count: number }) {
  if (!insights) return null;
  const v = insights.versusPrevious;
  const cards = [
    { label: "Best month", value: monthName(insights.best.month), sub: `${money0(insights.best.profit)} profit` },
    { label: "Weakest month", value: monthName(insights.weakest.month), sub: `${money0(insights.weakest.profit)} profit` },
    { label: "Average profit", value: `${money0(insights.averageProfit)} / month`, sub: `${insights.margin}% margin` },
    {
      label: `Compared with the ${count} months before`,
      value: v ? `${v.change >= 0 ? "+" : "−"}${money0(Math.abs(v.change))}` : "—",
      sub: v
        ? v.percent === null
          ? `Profit was ${money0(v.previousProfit)}`
          : `${v.percent}% profit vs ${money0(v.previousProfit)}`
        : "Not enough history",
    },
  ];
  return (
    <ul className="grid list-none grid-cols-2 gap-3 p-0 xl:grid-cols-4">
      {cards.map((c) => (
        <li key={c.label} className="min-w-0 rounded-xl border border-slate-200 bg-white p-3">
          <div className="text-xs font-semibold text-slate-600">{c.label}</div>
          <div className="mt-1 text-lg font-extrabold">{c.value}</div>
          <div className="text-xs text-slate-600">{c.sub}</div>
        </li>
      ))}
    </ul>
  );
}
