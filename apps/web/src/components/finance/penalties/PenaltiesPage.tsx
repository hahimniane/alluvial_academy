"use client";

import { Fragment, useMemo, useState } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { downloadCsv } from "@/lib/finance/csv";
import { money } from "@/lib/finance/model";
import { monthLabel, monthShort } from "@/lib/finance/months";
import {
  CHIP_LABELS,
  DEFAULT_FILTERS,
  PENALTY_REASONS,
  PENALTY_REASON_CODES,
  applyFilters,
  baseRows,
  buildTeacherRows,
  chipCounts,
  historyLine,
  penaltiesCsv,
  penaltyCards,
  periodLabel,
  reasonBreakdown,
  reasonsText,
  type PenaltyChip,
  type PenaltyFilters,
} from "@/lib/finance/penalties";
import { Badge, BTN, BTN_SM, CARD, Field, INPUT, StatCard } from "@/components/finance/staff/staffUi";
import { usePenaltyAudits } from "./usePenaltyAudits";

const TH = "px-3 py-2.5 font-semibold";
const TD = "px-3 py-2.5 align-top";
const CHIPS = Object.keys(CHIP_LABELS) as PenaltyChip[];

export function PenaltiesPage() {
  const { month } = useFinance();
  const { audits, error } = usePenaltyAudits(month);
  const [filters, setFilters] = useState<PenaltyFilters>(DEFAULT_FILTERS);
  const [open, setOpen] = useState<string | null>(null);
  const set = <K extends keyof PenaltyFilters>(key: K, value: PenaltyFilters[K]) => setFilters((f) => ({ ...f, [key]: value }));

  const all = useMemo(() => (audits ? buildTeacherRows(audits, month, filters) : []), [audits, month, filters]);
  const base = useMemo(() => baseRows(all, filters), [all, filters]);
  const counts = useMemo(() => chipCounts(base), [base]);
  const rows = useMemo(() => applyFilters(all, filters), [all, filters]);
  const cards = useMemo(() => penaltyCards(all), [all]);
  const slices = useMemo(() => reasonBreakdown(rows), [rows]);

  if (error) return <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">{error}</p>;
  if (!audits) return <p className="p-2 text-sm text-slate-600">Loading penalties…</p>;

  const year = month.slice(0, 4);
  const label = periodLabel(month, filters.period);
  const periodTotal = rows.reduce((s, r) => s + r.periodTotal, 0);
  const periodTimes = rows.reduce((s, r) => s + r.periodCount, 0);
  const maxSlice = Math.max(1, ...slices.map((s) => s.amount));
  const summary = `${rows.length} ${rows.length === 1 ? "teacher" : "teachers"} · −${money(periodTotal)} · ${periodTimes} ${periodTimes === 1 ? "penalty" : "penalties"} · ${label}`;

  return (
    <section className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-2xl font-extrabold">Penalties · {monthLabel(month)}</h1>
        <div className="flex-1" />
        <button type="button" className={BTN} onClick={() => downloadCsv(`penalties-${month}.csv`, penaltiesCsv(rows, month, filters.period))}>
          Export to Excel
        </button>
      </div>
      <p className="text-sm text-slate-600">Money taken off teachers’ pay in their audits. Change the month at the top to see another month; the year total always counts from January.</p>

      <div className="grid grid-cols-2 gap-2.5 lg:grid-cols-4">
        <StatCard label={`${monthLabel(month).split(" ")[0]} penalties`} value={`−${money(cards.monthTotal)}`} sub={`${cards.monthTeachers} ${cards.monthTeachers === 1 ? "teacher" : "teachers"}`} />
        <StatCard label={`${year} so far (Jan – ${monthShort(month).split(" ")[0]})`} value={`−${money(cards.ytdTotal)}`} sub={`${cards.ytdCount} ${cards.ytdCount === 1 ? "penalty" : "penalties"}`} />
        <StatCard label="Teachers with any penalty this year" value={`${cards.teachersWithAny} of ${cards.teachersTotal}`} sub={`${cards.teachersRepeat} with 3 or more`} />
        <StatCard
          label="Most common reason"
          value={cards.topReason ? PENALTY_REASONS[cards.topReason] : "—"}
          sub={cards.topReason ? `${cards.topReasonCount} times this year` : "No penalties this year"}
        />
      </div>

      <div className={`${CARD} flex flex-col gap-3 p-3.5`}>
        <div className="flex flex-wrap gap-1.5" role="group" aria-label="Quick filters">
          {CHIPS.map((c) => {
            const on = filters.chip === c;
            return (
              <button
                key={c}
                type="button"
                aria-pressed={on}
                onClick={() => set("chip", c)}
                className={`min-h-9 rounded-full border px-3 text-[13px] font-semibold ${on ? "border-[#0386FF] bg-[#0386FF] text-white" : "border-slate-300 bg-white text-slate-800"}`}
              >
                {c === "month" ? `Penalty in ${monthLabel(month).split(" ")[0]}` : CHIP_LABELS[c]} <span className="opacity-80">{counts[c]}</span>
              </button>
            );
          })}
        </div>
        <div className="grid gap-2.5 sm:grid-cols-2 lg:grid-cols-4">
          <Field label="Search">
            <input className={INPUT} type="search" value={filters.q} onChange={(e) => set("q", e.target.value)} placeholder="Teacher name" />
          </Field>
          <Field label="Period">
            <select className={INPUT} value={filters.period} onChange={(e) => set("period", e.target.value as PenaltyFilters["period"])}>
              <option value="month">{monthLabel(month)} only</option>
              <option value="last3">Last 3 months</option>
              <option value="ytd">{year} so far</option>
            </select>
          </Field>
          <Field label="Reason">
            <select className={INPUT} value={filters.reason} onChange={(e) => set("reason", e.target.value)}>
              <option value="all">All reasons</option>
              {PENALTY_REASON_CODES.map((code) => (
                <option key={code} value={code}>
                  {PENALTY_REASONS[code]}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Show">
            <select className={INPUT} value={filters.show} onChange={(e) => set("show", e.target.value as PenaltyFilters["show"])}>
              <option value="with">Teachers with penalties in the period</option>
              <option value="all">All teachers</option>
              <option value="none">Teachers with none this year</option>
            </select>
          </Field>
          <Field label="Amount from ($)">
            <input className={INPUT} type="number" inputMode="decimal" min="0" value={filters.min} onChange={(e) => set("min", e.target.value)} placeholder="0" />
          </Field>
          <Field label="Amount to ($)">
            <input className={INPUT} type="number" inputMode="decimal" min="0" value={filters.max} onChange={(e) => set("max", e.target.value)} placeholder="Any" />
          </Field>
          <Field label="At least this many times">
            <input className={INPUT} type="number" inputMode="numeric" min="0" value={filters.minTimes} onChange={(e) => set("minTimes", e.target.value)} placeholder="Any" />
          </Field>
          <Field label="Sort by">
            <select className={INPUT} value={filters.sort} onChange={(e) => set("sort", e.target.value as PenaltyFilters["sort"])}>
              <option value="period">Amount in the period</option>
              <option value="ytd">{year} total</option>
              <option value="month">{monthLabel(month).split(" ")[0]} amount</option>
              <option value="times">Number of times</option>
              <option value="pct">% of earnings lost</option>
              <option value="recent">Most recent</option>
              <option value="name">Name</option>
            </select>
          </Field>
        </div>
        <div className="flex flex-wrap items-center gap-2.5">
          <span className="font-bold" aria-live="polite">
            {summary}
          </span>
          <div className="flex-1" />
          <button type="button" className={BTN_SM} onClick={() => setFilters(DEFAULT_FILTERS)}>
            Clear filters
          </button>
        </div>
        {slices.length === 0 ? <span className="text-sm text-slate-600">No penalties match these filters.</span> : null}
        <div className="grid gap-x-4 gap-y-2 sm:grid-cols-2">
          {slices.map((s) => (
            <div key={s.code} className="flex flex-col gap-1">
              <div className="flex text-xs">
                <span className="flex-1 font-semibold">
                  {s.label} <span className="font-normal text-slate-500">×{s.count}</span>
                </span>
                <span className="font-bold text-red-700">−{money(s.amount)}</span>
              </div>
              <div className="h-1.5 overflow-hidden rounded-full bg-slate-100" role="presentation">
                <div className="h-1.5 rounded-full bg-red-600" style={{ width: `${Math.round((s.amount / maxSlice) * 100)}%` }} />
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className={`${CARD} relative overflow-x-auto`}>
        <table className="w-full min-w-[1040px] border-collapse text-[13px]">
          <caption className="sr-only">Penalties by teacher</caption>
          <thead>
            <tr className="bg-slate-50 text-left text-slate-700">
              <th className={TH}>Teacher</th>
              <th className={`${TH} text-right`}>{monthLabel(month)}</th>
              <th className={`${TH} text-right`}>{label}</th>
              <th className={`${TH} text-right`}>Times</th>
              <th className={TH}>Reasons in the period</th>
              <th className={`${TH} text-right`}>% of {year} earnings</th>
              <th className={TH}>Trend</th>
              <th className={TH}>Last one</th>
              <th className={TH}>
                <span className="sr-only">History</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-3 py-6 text-center text-slate-600">
                  No teachers match these filters.
                </td>
              </tr>
            ) : null}
            {rows.map((r) => {
              const isOpen = open === r.uid;
              return (
                <Fragment key={r.uid}>
                  <tr className="border-t border-slate-200">
                    <td className={`${TD} font-semibold`}>{r.name}</td>
                    <td className={`${TD} text-right ${r.monthTotal ? "font-bold text-red-700" : "text-slate-500"}`}>{r.monthTotal ? `−${money(r.monthTotal)}` : "—"}</td>
                    <td className={`${TD} text-right ${r.periodTotal ? "font-extrabold" : "text-slate-500"}`}>{r.periodTotal ? `−${money(r.periodTotal)}` : "—"}</td>
                    <td className={`${TD} text-right`}>{r.periodCount}</td>
                    <td className={`${TD} text-slate-700`}>{reasonsText(r.periodEntries)}</td>
                    <td className={`${TD} text-right ${r.pctLost >= 5 ? "font-bold text-red-700" : r.pctLost >= 2 ? "font-semibold text-amber-800" : "text-slate-700"}`}>
                      {r.pctLost ? `${r.pctLost.toFixed(1)}%` : "0%"}
                    </td>
                    <td className={TD}>
                      <Badge tone={r.trend === "Rising" ? "bad" : r.trend === "Falling" ? "ok" : "mute"}>{r.trend}</Badge>
                    </td>
                    <td className={TD}>{r.lastMonth ? monthLabel(r.lastMonth) : "—"}</td>
                    <td className={TD}>
                      {r.history.length > 0 ? (
                        <button type="button" className={BTN_SM} aria-expanded={isOpen} onClick={() => setOpen(isOpen ? null : r.uid)}>
                          {isOpen ? "Hide" : "History"}
                        </button>
                      ) : null}
                    </td>
                  </tr>
                  {isOpen ? (
                    <tr className="bg-slate-50">
                      <td colSpan={9} className="px-4 py-2.5">
                        <div className="mb-1 font-bold">
                          {r.name} · every penalty in {year}
                        </div>
                        {r.history.map((e, i) => (
                          <div key={i} className="py-0.5 text-slate-700">
                            {historyLine(e, money)}
                          </div>
                        ))}
                      </td>
                    </tr>
                  ) : null}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}
