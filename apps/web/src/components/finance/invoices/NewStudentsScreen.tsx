"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { DEFAULT_SETTINGS, money } from "@/lib/finance/model";
import {
  formatDay,
  formatMoment,
  mergeNewStudents,
  newStudentStatus,
  nextMonthlyInvoice,
  workedExample,
  type NewStudentRow,
} from "@/lib/finance/invoices";
import {
  errorMessage,
  loadFinanceSettings,
  loadFirstInvoices,
  loadGuardians,
  loadMonthlyAmounts,
  loadNames,
  loadRecentEnrollments,
  loadTeachersForStudents,
  type FinanceSettingsView,
} from "./data";
import { Badge, Notice } from "./ui";

export function NewStudentsScreen() {
  const { month } = useFinance();
  const [rows, setRows] = useState<NewStudentRow[]>([]);
  const [names, setNames] = useState<Map<string, string>>(new Map());
  const [monthly, setMonthly] = useState<Map<string, number>>(new Map());
  const [settings, setSettings] = useState<FinanceSettingsView>({ ...DEFAULT_SETTINGS, zelle_address: "" });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const now = useMemo(() => new Date(), []);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const [first, enrollments, s] = await Promise.all([loadFirstInvoices(), loadRecentEnrollments(now), loadFinanceSettings()]);
        // Enrollments that carry no parent id: use the student's guardian.
        const needParent = enrollments.filter((e) => !e.parentId).map((e) => e.studentId);
        const guardians = needParent.length ? await loadGuardians(needParent) : new Map<string, string>();
        const withParents = enrollments.map((e) => (e.parentId ? e : { ...e, parentId: guardians.get(e.studentId) ?? "" }));

        const students = [...first.flatMap((i) => i.studentIds), ...withParents.map((e) => e.studentId)];
        const teacherMap = await loadTeachersForStudents(students.slice(0, 80));
        const teacherByStudent = new Map<string, string>();
        teacherMap.byStudent.forEach((ids, student) => teacherByStudent.set(student, teacherMap.teacherNames.get(ids[0]) ?? ""));

        const merged = mergeNewStudents(first, withParents, teacherByStudent).slice(0, 40);
        const ids = merged.flatMap((r) => [r.parentId, ...r.studentIds]);
        const [resolved, amounts] = await Promise.all([loadNames(ids, new Map()), loadMonthlyAmounts(merged.map((r) => r.parentId)).catch(() => new Map<string, number>())]);
        if (!alive) return;
        setRows(merged);
        setNames(resolved);
        setMonthly(amounts);
        setSettings(s);
      } catch (e) {
        if (alive) setError(errorMessage(e, "Could not load new students."));
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [now]);

  const link = (invoiceId: string) => `/admin/finance/invoices/?invoice=${encodeURIComponent(invoiceId)}&month=${month}&embed=1`;
  const studentLabel = (r: NewStudentRow) => r.studentIds.map((s) => names.get(s)).filter(Boolean).join(", ") || "Student";
  const familyLabel = (r: NewStudentRow) => names.get(r.parentId) || "Unknown family";

  const newest = rows.find((r) => r.invoice);
  const example = newest?.invoice ? workedExample(newest.invoice, monthly.get(newest.parentId) ?? null) : null;
  const next = nextMonthlyInvoice(now, settings.issue_day, settings.due_day);

  const exampleStart = newest?.startKey ?? null;
  const startedLabel = exampleStart ? `Started ${formatDay(exampleStart)}` : "";
  const exampleInvoice = newest?.invoice ?? null;

  return (
    <section aria-labelledby="new-students-title" className="flex flex-col gap-3">
      <h2 id="new-students-title" className="text-2xl font-extrabold">
        New students &amp; first invoices
      </h2>
      <p className="text-slate-600">
        Staff enter the monthly price at enrollment. On the first class the system bills the classes left that month, due {settings.first_invoice_due_days} days later, and staff get a notification. Monthly billing starts the next month.
      </p>
      {error ? <Notice tone="error">{error}</Notice> : null}

      {example && newest && exampleInvoice ? (
        <div className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-base font-bold">{studentLabel(newest)}</h3>
            {startedLabel ? <Badge tone="purple">{startedLabel}</Badge> : null}
          </div>
          <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2 lg:grid-cols-4">
            <ExampleTile label="Monthly price" value={example.monthly !== null ? money(example.monthly) : "Not set"} sub={example.classesInMonth ? `${example.classesInMonth} classes a month` : "Set on the first invoice"} />
            <ExampleTile
              label={`Classes left in ${exampleStart ? monthName(exampleStart) : "the month"}`}
              value={example.classesLeft !== null && example.classesInMonth !== null ? `${example.classesLeft} of ${example.classesInMonth}` : "—"}
              sub={exampleStart ? `First class ${formatDay(exampleStart)}` : ""}
            />
            <ExampleTile
              label="First invoice"
              value={money(example.firstAmount)}
              sub={[
                example.monthly !== null && example.classesLeft !== null && example.classesInMonth !== null ? `${money(example.monthly)} × ${example.classesLeft} ÷ ${example.classesInMonth}` : "",
                example.dueKey ? `due ${formatDay(example.dueKey)}` : "",
              ]
                .filter(Boolean)
                .join(" · ")}
            />
            <ExampleTile label={`From ${monthName(`${next.month}-01`)}`} value={example.monthly !== null ? money(example.monthly) : "—"} sub={`Issued ${formatDay(next.issueKey)} · due ${formatDay(next.dueKey)}`} />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Link href={link(exampleInvoice.id)} className="inline-flex min-h-10 items-center rounded-lg bg-[#0386FF] px-4 text-sm font-bold text-white hover:bg-[#0277e6]">
              Open first invoice
            </Link>
            {exampleInvoice.issuedAt ? (
              <span className="text-xs text-slate-600">
                First invoice {exampleInvoice.number} went to {familyLabel(newest)} on {formatMoment(exampleInvoice.issuedAt)}.
              </span>
            ) : null}
          </div>
        </div>
      ) : null}

      <h3 className="mt-1.5 text-base font-bold">Recently enrolled and attending</h3>
      {loading ? (
        <p className="rounded-xl border border-slate-200 bg-white p-6 text-center text-slate-600">Loading…</p>
      ) : rows.length === 0 ? (
        <p className="rounded-xl border border-slate-200 bg-white p-6 text-center text-slate-600">No new students in the last 60 days.</p>
      ) : (
        <>
          <div className="relative hidden overflow-x-auto rounded-xl border border-slate-200 bg-white md:block">
            <table className="w-full min-w-[720px] border-collapse text-[13px]">
              <thead>
                <tr className="bg-slate-50 text-left text-slate-700">
                  <th className="px-3 py-2.5">Student</th>
                  <th className="px-3 py-2.5">Family</th>
                  <th className="px-3 py-2.5">First class</th>
                  <th className="px-3 py-2.5">Teacher</th>
                  <th className="px-3 py-2.5">First invoice</th>
                  <th className="px-3 py-2.5">Monthly</th>
                  <th className="px-3 py-2.5">Status</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => {
                  const st = newStudentStatus(r, now);
                  return (
                    <tr key={r.key} className="border-t border-slate-200">
                      <td className="px-3 py-2.5 font-semibold">{studentLabel(r)}</td>
                      <td className="px-3 py-2.5">{familyLabel(r)}</td>
                      <td className="px-3 py-2.5">{r.startKey ? formatDay(r.startKey) : ""}</td>
                      <td className="px-3 py-2.5">{r.teacherName || "To be matched"}</td>
                      <td className="px-3 py-2.5">
                        {r.invoice ? (
                          <Link href={link(r.invoice.id)} className="font-semibold text-[#024E96] underline">
                            {invoiceSummary(r)}
                          </Link>
                        ) : (
                          "—"
                        )}
                      </td>
                      <td className="px-3 py-2.5">{monthly.has(r.parentId) ? money(monthly.get(r.parentId) ?? 0) : "—"}</td>
                      <td className="px-3 py-2.5">
                        <Badge tone={st.tone}>{st.label}</Badge>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <ul className="flex flex-col gap-2 md:hidden">
            {rows.map((r) => {
              const st = newStudentStatus(r, now);
              return (
                <li key={r.key} className="flex flex-col gap-1 rounded-xl border border-slate-200 bg-white p-3 text-[13px]">
                  <div className="flex items-start gap-2">
                    <div className="min-w-0 flex-1">
                      <div className="font-bold">{studentLabel(r)}</div>
                      <div>{familyLabel(r)}</div>
                    </div>
                    <Badge tone={st.tone}>{st.label}</Badge>
                  </div>
                  <div className="text-slate-700">
                    {r.startKey ? `First class ${formatDay(r.startKey)}` : ""}
                    {r.teacherName ? ` · ${r.teacherName}` : ""}
                    {monthly.has(r.parentId) ? ` · ${money(monthly.get(r.parentId) ?? 0)} a month` : ""}
                  </div>
                  {r.invoice ? (
                    <Link href={link(r.invoice.id)} className="font-semibold text-[#024E96] underline">
                      {invoiceSummary(r)}
                    </Link>
                  ) : null}
                </li>
              );
            })}
          </ul>
        </>
      )}
    </section>
  );
}

function monthName(dayKey: string): string {
  const names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  return names[Number(dayKey.slice(5, 7)) - 1] ?? "";
}

function invoiceSummary(r: NewStudentRow): string {
  const inv = r.invoice;
  if (!inv) return "";
  const parts = [inv.number, money(inv.total)];
  if (inv.classesLeft !== null && inv.classesInMonth !== null) parts.push(`(${inv.classesLeft} of ${inv.classesInMonth})`);
  if (inv.dueKey) parts.push(`due ${formatDay(inv.dueKey)}`);
  return parts.join(" · ");
}

function ExampleTile({ label, value, sub }: { label: string; value: string; sub: string }) {
  return (
    <div className="rounded-xl bg-slate-50 p-3">
      <div className="text-xs text-slate-600">{label}</div>
      <div className="text-lg font-extrabold">{value}</div>
      {sub ? <div className="text-xs text-slate-600">{sub}</div> : null}
    </div>
  );
}
