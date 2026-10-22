"use client";

import Link from "next/link";
import { money, money0 } from "@/lib/finance/model";
import { financeHref } from "@/lib/finance/links";
import { rollups, type BreakdownRow } from "@/lib/finance/overview";

/** Where the money went: one bar per cost line, and the three roll-ups. */
export function Breakdown({ rows, count }: { rows: BreakdownRow[]; count: number }) {
  const groups = rollups(rows);
  return (
    <section aria-labelledby="fin-breakdown" className="min-w-0 flex-[2_1_420px] rounded-xl border border-slate-200 bg-white p-4">
      <h2 id="fin-breakdown" className="m-0 mb-3 text-base font-bold">Where the money went</h2>
      <ul className="m-0 flex list-none flex-col gap-2.5 p-0">
        {rows.map((r) => (
          <li key={r.category} className="flex flex-col gap-1">
            <div className="flex items-baseline gap-2 text-[13px]">
              <span className="flex-1 font-semibold">
                {r.label} <span className="font-normal text-slate-600">· {r.group}</span>
              </span>
              <span className="font-bold">{money(r.amount)}</span>
              <span className="w-[72px] text-right text-slate-600">{r.estimate ? "estimate" : count > 1 ? `${r.share}%` : ""}</span>
            </div>
            <div aria-hidden="true" className="h-2 overflow-hidden rounded-full bg-slate-100">
              <div className="h-2 rounded-full bg-[#0386FF]" style={{ width: `${r.bar}%` }} />
            </div>
          </li>
        ))}
      </ul>
      <ul className="m-0 mt-3.5 grid list-none grid-cols-3 gap-2 p-0">
        {groups.map((g) => (
          <li key={g.group} className="rounded-[10px] bg-slate-50 p-2.5">
            <div className="text-xs text-slate-600">{g.group}</div>
            <div className="text-base font-extrabold">{money0(g.amount)}</div>
          </li>
        ))}
      </ul>
    </section>
  );
}

export type SmallCard = { label: string; value: string; sub: string; href: string };

/** Penalties, discounts and credit: small figures that each lead to their page. */
export function SmallCards({ cards, month }: { cards: SmallCard[]; month: string }) {
  return (
    <ul className="m-0 grid min-w-0 flex-[1_1_300px] list-none grid-cols-1 gap-3 p-0">
      {cards.map((c) => (
        <li key={c.label}>
          <Link
            href={financeHref(c.href, month)}
            className="block min-h-11 rounded-xl border border-slate-200 bg-white p-3.5 text-left text-inherit no-underline hover:border-slate-300"
          >
            <div className="text-xs font-semibold text-slate-600">{c.label}</div>
            <div className="mt-1 text-xl font-extrabold">{c.value}</div>
            <div className="mt-0.5 text-xs text-slate-600">{c.sub}</div>
          </Link>
        </li>
      ))}
    </ul>
  );
}
