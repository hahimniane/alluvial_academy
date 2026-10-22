"use client";

import Link from "next/link";
import { financeHref } from "@/lib/finance/links";
import { monthName } from "@/lib/finance/months";
import { bannerText, type Todo, type TodoTone } from "@/lib/finance/overview";
import type { MonthSummary } from "@/lib/finance/summary";

const DOT: Record<TodoTone, string> = {
  warn: "#B45309",
  bad: "#B91C1C",
  info: "#0386FF",
  mute: "#64748B",
  first: "#6D28D9",
};

/** What needs doing, each line linking to the page where it is done. */
export function TodoPanel({ todos, monthLabel, month, loading }: { todos: Todo[]; monthLabel: string; month: string; loading: boolean }) {
  return (
    <section aria-labelledby="fin-todo" className="flex min-w-0 flex-[1_1_300px] flex-col gap-2.5 rounded-xl border border-slate-200 bg-white p-4">
      <h2 id="fin-todo" className="m-0 text-base font-bold">To do</h2>
      {todos.length === 0 ? (
        <p className="m-0 font-semibold text-green-800">{loading ? "Checking…" : `Nothing left for ${monthLabel}.`}</p>
      ) : (
        <ul className="m-0 flex list-none flex-col gap-2 p-0">
          {todos.map((t) => (
            <li key={t.id}>
              <Link
                href={financeHref(t.href, month)}
                className="flex min-h-11 items-center gap-2.5 rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px] text-inherit no-underline hover:border-slate-300"
              >
                <span aria-hidden="true" className="h-2 w-2 shrink-0 rounded-full" style={{ background: DOT[t.tone] }} />
                <span className="flex-1">{t.text}</span>
                <span className="font-bold text-[#0369C9]">Open</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

/** Shown above the overview while the most recent finished month is still open. */
export function CloseBanner({ row }: { row: MonthSummary }) {
  const name = monthName(row.month);
  return (
    <section aria-label={`${name} is not closed`} className="flex flex-wrap items-center gap-3 rounded-xl border border-amber-500 bg-amber-50 px-4 py-3.5">
      <p className="m-0 min-w-0 flex-[1_1_320px] text-amber-950">
        <strong>{name} isn&apos;t closed yet.</strong> {bannerText(row)}
      </p>
      <Link
        href={financeHref("/admin/finance/close/", row.month)}
        className="inline-flex h-11 items-center rounded-lg bg-amber-700 px-4 font-bold text-white no-underline hover:bg-amber-800"
      >
        Finish {name}
      </Link>
    </section>
  );
}
