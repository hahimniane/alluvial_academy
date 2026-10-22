"use client";

import { useMemo, useState } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { money, money0 } from "@/lib/finance/model";
import { addMonths, currentMonth, monthLabel, monthName, recentMonths } from "@/lib/finance/months";
import {
  breakdownRows,
  buildInsights,
  buildTodos,
  findCloseBannerMonth,
  isEstimate,
  periodMonths,
  periodTitle,
  previousMonths,
  sumMonths,
  yearSeries,
  type PeriodKind,
} from "@/lib/finance/overview";
import type { MonthSummary } from "@/lib/finance/summary";
import { Breakdown, SmallCards, type SmallCard } from "./Breakdown";
import { MonthTable } from "./MonthTable";
import { PeriodControls } from "./PeriodControls";
import { PeriodReport } from "./PeriodReport";
import { InsightCards, TopCards } from "./SummaryCards";
import { CloseBanner, TodoPanel } from "./TodoPanel";
import { useMonthSummaries } from "./useMonthSummaries";
import { YearChart } from "./YearChart";

const CHART_MONTHS = 12;
const CUSTOM_CHOICES = 36;

function stateChip(row: MonthSummary, ended: boolean): { label: string; className: string } {
  if (row.status === "closed") return { label: "Closed", className: "bg-green-100 text-green-900" };
  if (row.final) return { label: "Final", className: "bg-blue-100 text-blue-900" };
  return { label: ended ? "Waiting on costs" : "In progress · estimates", className: "bg-amber-100 text-amber-900" };
}

export function FinanceOverview() {
  const { month } = useFinance();
  const today = useMemo(() => currentMonth(), []);
  const [kind, setKind] = useState<PeriodKind>("1");
  const [from, setFrom] = useState(() => addMonths(today, -4));
  const [to, setTo] = useState(today);

  const months = useMemo(() => periodMonths(kind, month, from, to), [kind, month, from, to]);
  const before = useMemo(() => (months.length > 1 ? previousMonths(months) : []), [months]);
  const chart = useMemo(() => recentMonths(CHART_MONTHS, today), [today]);
  const choices = useMemo(() => recentMonths(CUSTOM_CHOICES, today), [today]);
  const wanted = useMemo(() => [...new Set([...months, today, ...chart, ...before])], [months, today, chart, before]);

  const { rows, errors, reload, loading, loaded, total } = useMonthSummaries(wanted);

  const periodRows = months.map((m) => rows.get(m)).filter((r): r is MonthSummary => Boolean(r));
  const complete = periodRows.length === months.length;
  const previousRows = before.map((m) => rows.get(m)).filter((r): r is MonthSummary => Boolean(r));
  const failed = wanted.filter((m) => errors.has(m));

  const title = periodTitle(months);
  const multi = months.length > 1;
  const selected = rows.get(month) ?? null;
  const selectedEnded = month < today;
  const banner = findCloseBannerMonth(
    chart.map((m) => rows.get(m)).filter((r): r is MonthSummary => Boolean(r)),
    today,
  );
  const globals = rows.get(today) ?? selected ?? periodRows[periodRows.length - 1] ?? null;

  const insights = multi && complete ? buildInsights(periodRows, previousRows.length === before.length ? previousRows : null) : null;
  const parts = complete ? breakdownRows(periodRows) : [];
  const totals = complete ? sumMonths(periodRows) : null;
  const todos = buildTodos({ selected, selectedEnded, banner, global: globals });
  const series = yearSeries(chart, rows);

  const smallCards: SmallCard[] = totals
    ? [
        {
          label: "Penalties taken from teachers",
          value: money(totals.penalties),
          sub: multi ? `${months.length} months · see by teacher` : `${periodRows[0].teachers.filter((t) => t.penalties > 0).length} teachers · ${monthName(months[0])}`,
          href: "/admin/finance/penalties/",
        },
        {
          label: "Discounts given",
          value: money(totals.discounts),
          sub: multi ? `Avg ${money0(totals.discounts / months.length)} a month` : `On ${monthName(months[0])} invoices`,
          href: "/admin/finance/discounts/",
        },
        {
          label: "Credit owed to families",
          value: money(globals?.credit_open ?? 0),
          sub: "Open today",
          href: "/admin/finance/discounts/",
        },
      ]
    : [];

  const chip = !multi && periodRows[0] ? stateChip(periodRows[0], selectedEnded) : null;
  const generatedOn = new Intl.DateTimeFormat("en-US", { dateStyle: "long", timeZone: "America/New_York" }).format(new Date());

  return (
    <div className="flex flex-col gap-4">
      {banner ? <CloseBanner row={banner} /> : null}

      <section aria-labelledby="fin-overview-title" className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center gap-3">
          <h2 id="fin-overview-title" className="m-0 text-2xl font-extrabold">{title}</h2>
          {chip ? <span className={`rounded-full px-2.5 py-0.5 text-xs font-bold ${chip.className}`}>{chip.label}</span> : null}
          <div className="flex-1" />
          <button
            type="button"
            onClick={() => window.print()}
            disabled={!complete}
            className="h-11 rounded-lg border border-slate-300 bg-white px-3.5 font-semibold hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {multi ? `Report for these ${months.length} months (PDF)` : "Monthly report (PDF)"}
          </button>
        </div>

        <PeriodControls kind={kind} onKind={setKind} from={from} to={to} onFrom={setFrom} onTo={setTo} choices={choices} endMonth={month} />

        <p role="status" aria-live="polite" className="m-0 text-xs text-slate-600">
          {failed.length > 0 ? null : loading ? `Loading ${loaded} of ${total} months…` : ""}
        </p>
        {failed.length > 0 ? (
          <div role="alert" className="flex flex-wrap items-center gap-3 rounded-xl border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-900">
            <span className="flex-1">
              Could not load {failed.map(monthLabel).join(", ")}. {errors.get(failed[0])}
            </span>
            <button type="button" onClick={reload} className="h-11 rounded-lg border border-red-400 bg-white px-4 font-bold text-red-800">
              Try again
            </button>
          </div>
        ) : null}

        <TopCards months={months} rows={periodRows} complete={complete} />
        {multi ? <InsightCards insights={insights} count={months.length} /> : null}
        {multi && complete ? <MonthTable rows={periodRows} /> : null}

        <div className="flex flex-wrap items-start gap-4">
          <YearChart points={series} loading={loading} />
          <TodoPanel todos={todos} monthLabel={monthLabel(month)} month={month} loading={loading && !selected} />
        </div>

        {complete ? (
          <div className="flex flex-wrap items-start gap-4">
            <Breakdown rows={parts} count={months.length} />
            <SmallCards cards={smallCards} month={month} />
          </div>
        ) : null}
        {complete && periodRows.some(isEstimate) ? (
          <p className="m-0 text-xs text-slate-600">Months marked estimate include pay that is not approved yet or costs that are not confirmed.</p>
        ) : null}
      </section>

      {complete ? <PeriodReport title={title} rows={periodRows} generatedOn={generatedOn} /> : null}
    </div>
  );
}
