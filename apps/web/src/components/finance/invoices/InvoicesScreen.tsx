"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { DEFAULT_SETTINGS, money } from "@/lib/finance/model";
import { currentMonth, monthLabel, monthName, recentMonths } from "@/lib/finance/months";
import {
  DEFAULT_FILTERS,
  STATUS_CHIPS,
  buildRow,
  filterAndSort,
  formatDay,
  teacherOptions,
  toneFor,
  type Invoice,
  type InvoiceFilters,
  type InvoiceRow,
  type OverdueBucket,
  type SortKey,
  type StatusChip,
} from "@/lib/finance/invoices";
import {
  MONTH_QUERY_LIMIT,
  RECENT_MONTHS,
  RECENT_QUERY_LIMIT,
  errorMessage,
  loadFinanceSettings,
  loadInvoicesForMonth,
  loadNames,
  loadOpenCreditParents,
  loadRecentInvoices,
  loadTeachersForStudents,
  type FinanceSettingsView,
} from "./data";
import { InvoiceDetail } from "./InvoiceDetail";
import { NewInvoiceDialog } from "./NewInvoiceDialog";
import { Badge, Field, Notice, inputClass, outlineButton, primaryButton } from "./ui";

const forLabel = (m: string) => `${monthName(m).slice(0, 3)} ${m.slice(0, 4)}`;

const STATUS_IDS = new Set<string>(STATUS_CHIPS.map((c) => c.id));

export function InvoicesScreen() {
  const { month } = useFinance();
  const params = useSearchParams();
  const pathname = usePathname() || "";
  const router = useRouter();

  const forAll = params?.get("for") === "all";
  const openId = params?.get("invoice") || "";
  const initialStatus = params?.get("status") || "all";

  const [filters, setFilters] = useState<InvoiceFilters>({ ...DEFAULT_FILTERS, status: (STATUS_IDS.has(initialStatus) ? initialStatus : "all") as StatusChip });
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [truncated, setTruncated] = useState(false);
  const [names, setNames] = useState<Map<string, string>>(new Map());
  const [creditParents, setCreditParents] = useState<Set<string>>(new Set());
  const [teachersByStudent, setTeachersByStudent] = useState<Map<string, string[]>>(new Map());
  const [teacherNames, setTeacherNames] = useState<Map<string, string>>(new Map());
  const [teachersLoading, setTeachersLoading] = useState(false);
  const [settings, setSettings] = useState<FinanceSettingsView>({ ...DEFAULT_SETTINGS, zelle_address: "" });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [creating, setCreating] = useState(false);
  const [now, setNow] = useState(() => new Date());

  const navigate = useCallback(
    (patch: Record<string, string | null>) => {
      const q = new URLSearchParams(params?.toString() || "");
      for (const [k, v] of Object.entries(patch)) {
        if (v === null || v === "") q.delete(k);
        else q.set(k, v);
      }
      q.set("embed", "1");
      router.replace(`${pathname}?${q.toString()}`);
    },
    [params, pathname, router],
  );

  useEffect(() => {
    let alive = true;
    loadFinanceSettings().then((s) => alive && setSettings(s));
    loadOpenCreditParents()
      .then((s) => alive && setCreditParents(s))
      .catch(() => undefined);
    return () => {
      alive = false;
    };
  }, []);

  // Invoices for the chosen month (or the last six months), then their names.
  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError("");
    (async () => {
      try {
        const at = new Date();
        const result = forAll ? await loadRecentInvoices(at) : await loadInvoicesForMonth(month);
        const ids = result.invoices.flatMap((i) => [i.parentId, ...i.studentIds]);
        const resolved = await loadNames(ids, new Map());
        if (!alive) return;
        setNow(at);
        setInvoices(result.invoices);
        setTruncated(result.truncated);
        setNames(resolved);
        setLoading(false);

        const students = result.invoices.flatMap((i) => i.studentIds);
        setTeachersLoading(true);
        await loadTeachersForStudents(students, (byStudent, tn) => {
          if (!alive) return;
          setTeachersByStudent(new Map(byStudent));
          setTeacherNames(new Map(tn));
        });
        if (alive) setTeachersLoading(false);
      } catch (e) {
        if (!alive) return;
        setError(errorMessage(e, "Could not load invoices."));
        setLoading(false);
        setTeachersLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [month, forAll, reloadKey]);

  const rows: InvoiceRow[] = useMemo(
    () => invoices.map((inv) => buildRow(inv, { now, names, teachersByStudent, creditParents })),
    [invoices, now, names, teachersByStudent, creditParents],
  );

  const effective: InvoiceFilters = useMemo(() => ({ ...filters, month: forAll ? "all" : month }), [filters, forAll, month]);
  const view = useMemo(() => filterAndSort(rows, effective), [rows, effective]);
  const teachers = useMemo(() => teacherOptions(rows, teacherNames), [rows, teacherNames]);

  const setFilter = <K extends keyof InvoiceFilters>(key: K, value: InvoiceFilters[K]) => setFilters((f) => ({ ...f, [key]: value }));

  const onChanged = useCallback((inv: Invoice) => {
    setInvoices((list) => (list.some((i) => i.id === inv.id) ? list.map((i) => (i.id === inv.id ? inv : i)) : list));
  }, []);

  const open = (id: string) => navigate({ invoice: id });
  const close = () => navigate({ invoice: null });

  const months = useMemo(() => recentMonths(13, currentMonth()).reverse(), []);
  const monthValue = forAll ? "all" : month;
  const onMonth = (value: string) => {
    if (value === "all") navigate({ for: "all" });
    else navigate({ for: null, month: value });
  };

  const sortLabel: Record<SortKey, string> = { due: "Due date", amount: "Amount (high to low)", overdue: "Days overdue", family: "Family name", newest: "Newest" };
  const bucketLabel: Record<OverdueBucket, string> = { any: "Any", "1-15": "1–15 days", "16-30": "16–30 days", "30+": "Over 30 days" };

  const scopeNote = forAll
    ? `Showing invoices issued in the last ${RECENT_MONTHS} months${truncated ? ` (the latest ${RECENT_QUERY_LIMIT} only — pick a month to see the rest)` : ""}.`
    : truncated
      ? `Showing the first ${MONTH_QUERY_LIMIT} invoices for ${monthLabel(month)}.`
      : "";

  const totals = [
    { label: "Invoices", value: String(view.totals.count) },
    { label: "Billed", value: money(view.totals.billed) },
    { label: "Collected", value: money(view.totals.collected) },
    { label: "Still owed", value: money(view.totals.owed) },
  ];

  return (
    <>
      <section aria-labelledby="invoices-title" className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <h2 id="invoices-title" className="text-2xl font-extrabold">
            Invoices
          </h2>
          <div className="flex-1" />
          <button type="button" className={primaryButton} onClick={() => setCreating(true)}>
            New invoice
          </button>
        </div>
        <p className="text-slate-600">
          Monthly tuition is one invoice per family, issued on the {settings.issue_day}th and due on the {settings.due_day === 1 ? "1st" : `${settings.due_day}th`}.
        </p>

        <div className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-3.5">
          <div className="flex flex-wrap gap-1.5" role="group" aria-label="Filter by status">
            {STATUS_CHIPS.map((c) => {
              const on = filters.status === c.id;
              return (
                <button
                  key={c.id}
                  type="button"
                  aria-pressed={on}
                  onClick={() => setFilter("status", c.id)}
                  className={`min-h-9 rounded-full border px-3 text-[13px] font-semibold ${on ? "border-[#0386FF] bg-[#0386FF] text-white" : "border-slate-300 bg-white text-slate-800 hover:bg-slate-50"}`}
                >
                  {c.label} <span className="opacity-80">{view.counts[c.id]}</span>
                </button>
              );
            })}
          </div>
          <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2 lg:grid-cols-4">
            <Field label="Search">
              <input className={inputClass} type="text" value={filters.q} placeholder="Family, student or invoice #" onChange={(e) => setFilter("q", e.target.value)} />
            </Field>
            <Field label="Invoice for">
              <select className={inputClass} value={monthValue} onChange={(e) => onMonth(e.target.value)}>
                <option value="all">All months</option>
                {months.map((m) => (
                  <option key={m} value={m}>
                    {monthLabel(m)}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Teacher">
              <select className={inputClass} value={filters.teacher} onChange={(e) => setFilter("teacher", e.target.value)}>
                <option value="all">{teachersLoading && teachers.length === 0 ? "Loading teachers…" : "All teachers"}</option>
                {teachers.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Days overdue">
              <select className={inputClass} value={filters.overdue} onChange={(e) => setFilter("overdue", e.target.value as OverdueBucket)}>
                {(Object.keys(bucketLabel) as OverdueBucket[]).map((b) => (
                  <option key={b} value={b}>
                    {bucketLabel[b]}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Amount from ($)">
              <input className={inputClass} type="number" inputMode="decimal" min="0" value={filters.min} placeholder="0" onChange={(e) => setFilter("min", e.target.value)} />
            </Field>
            <Field label="Amount to ($)">
              <input className={inputClass} type="number" inputMode="decimal" min="0" value={filters.max} placeholder="Any" onChange={(e) => setFilter("max", e.target.value)} />
            </Field>
            <Field label="Sort by">
              <select className={inputClass} value={filters.sort} onChange={(e) => setFilter("sort", e.target.value as SortKey)}>
                {(Object.keys(sortLabel) as SortKey[]).map((s) => (
                  <option key={s} value={s}>
                    {sortLabel[s]}
                  </option>
                ))}
              </select>
            </Field>
            <div className="flex flex-col gap-1.5 text-[13px]">
              <label className="flex min-h-8 items-center gap-2">
                <input type="checkbox" checked={filters.hasDiscount} onChange={(e) => setFilter("hasDiscount", e.target.checked)} /> Has a discount
              </label>
              <label className="flex min-h-8 items-center gap-2">
                <input type="checkbox" checked={filters.familyCredit} onChange={(e) => setFilter("familyCredit", e.target.checked)} /> Family has credit
              </label>
              <label className="flex min-h-8 items-center gap-2">
                <input type="checkbox" checked={filters.firstOnly} onChange={(e) => setFilter("firstOnly", e.target.checked)} /> First-month only
              </label>
            </div>
          </div>
        </div>

        {scopeNote ? <p className="text-xs text-slate-600">{scopeNote}</p> : null}
        {error ? <Notice tone="error">{error}</Notice> : null}

        <div className="grid grid-cols-2 gap-2.5 lg:grid-cols-4">
          {totals.map((t) => (
            <div key={t.label} className="rounded-xl border border-slate-200 bg-white p-3">
              <div className="text-xs font-semibold text-slate-600">{t.label}</div>
              <div className="text-lg font-extrabold">{loading ? "…" : t.value}</div>
            </div>
          ))}
        </div>

        {loading ? (
          <p className="rounded-xl border border-slate-200 bg-white p-6 text-center text-slate-600">Loading invoices…</p>
        ) : view.rows.length === 0 ? (
          <p className="rounded-xl border border-slate-200 bg-white p-6 text-center text-slate-600">No invoices match these filters.</p>
        ) : (
          <>
            <div className="relative hidden overflow-x-auto rounded-xl border border-slate-200 bg-white md:block">
              <table className="w-full min-w-[900px] border-collapse text-[13px]">
                <thead>
                  <tr className="bg-slate-50 text-left text-slate-700">
                    <th className="px-3 py-2.5">Invoice</th>
                    <th className="px-3 py-2.5">Family</th>
                    <th className="px-3 py-2.5">Students</th>
                    <th className="px-3 py-2.5">For</th>
                    <th className="px-3 py-2.5 text-right">Total</th>
                    <th className="px-3 py-2.5 text-right">Paid</th>
                    <th className="px-3 py-2.5 text-right">Owed</th>
                    <th className="px-3 py-2.5">Status</th>
                    <th className="px-3 py-2.5">Due</th>
                    <th className="px-3 py-2.5">
                      <span className="sr-only">Open</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {view.rows.map((r) => (
                    <tr key={r.inv.id} className="border-t border-slate-200">
                      <td className="px-3 py-2.5 font-semibold">
                        {r.inv.number}
                        {r.inv.kind === "first_month" ? <div className="text-[11px] font-bold text-violet-700">FIRST MONTH</div> : null}
                      </td>
                      <td className="px-3 py-2.5">{r.familyName}</td>
                      <td className="px-3 py-2.5 text-slate-700">{r.studentNames.map((n) => n.split(" ")[0]).join(", ")}</td>
                      <td className="whitespace-nowrap px-3 py-2.5">{r.inv.billingMonth ? forLabel(r.inv.billingMonth) : ""}</td>
                      <td className="px-3 py-2.5 text-right">{money(r.inv.total)}</td>
                      <td className="px-3 py-2.5 text-right">{money(r.state.paid)}</td>
                      <td className="px-3 py-2.5 text-right font-bold">{money(r.state.owed)}</td>
                      <td className="px-3 py-2.5">
                        <Badge tone={toneFor(r.state)}>{r.state.label}</Badge>
                      </td>
                      <td className="whitespace-nowrap px-3 py-2.5">{formatDay(r.inv.dueKey)}</td>
                      <td className="px-3 py-2.5">
                        <button type="button" className={`${outlineButton} !min-h-9`} aria-label={`Open ${r.inv.number}`} onClick={() => open(r.inv.id)}>
                          Open
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <ul className="flex flex-col gap-2 md:hidden">
              {view.rows.map((r) => (
                <li key={r.inv.id} className="flex flex-col gap-1.5 rounded-xl border border-slate-200 bg-white p-3 text-[13px]">
                  <div className="flex items-start gap-2">
                    <div className="min-w-0 flex-1">
                      <div className="font-bold">{r.inv.number}</div>
                      <div>{r.familyName}</div>
                      <div className="text-slate-600">{r.studentNames.map((n) => n.split(" ")[0]).join(", ")}</div>
                    </div>
                    <Badge tone={toneFor(r.state)}>{r.state.label}</Badge>
                  </div>
                  <div className="flex flex-wrap gap-x-4 gap-y-0.5 text-slate-700">
                    {r.inv.billingMonth ? <span>For {forLabel(r.inv.billingMonth)}</span> : null}
                    <span>Total {money(r.inv.total)}</span>
                    <span>Paid {money(r.state.paid)}</span>
                    <span className="font-bold">Owed {money(r.state.owed)}</span>
                    <span>Due {formatDay(r.inv.dueKey)}</span>
                    {r.inv.kind === "first_month" ? <span className="font-bold text-violet-700">First month</span> : null}
                  </div>
                  <button type="button" className={outlineButton} aria-label={`Open ${r.inv.number}`} onClick={() => open(r.inv.id)}>
                    Open
                  </button>
                </li>
              ))}
            </ul>
          </>
        )}
      </section>

      {openId ? <InvoiceDetail key={openId} invoiceId={openId} initial={invoices.find((i) => i.id === openId) ?? null} settings={settings} now={now} onClose={close} onChanged={onChanged} /> : null}

      {creating ? (
        <NewInvoiceDialog
          settings={settings}
          now={now}
          onClose={() => setCreating(false)}
          onOpen={(id) => {
            setCreating(false);
            open(id);
          }}
          onCreated={(id) => {
            setCreating(false);
            setReloadKey((k) => k + 1);
            open(id);
          }}
        />
      ) : null}
    </>
  );
}
