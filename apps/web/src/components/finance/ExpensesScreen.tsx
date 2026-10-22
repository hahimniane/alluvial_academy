"use client";

import { httpsCallable } from "firebase/functions";
import { collection, getDocs, limit, query, where } from "firebase/firestore";
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { db, functions } from "@/lib/firebase";
import { downloadWorkbook } from "@/lib/xlsx";
import {
  addButtonLabel,
  addHint,
  buildExpenseTable,
  deletedExpenses,
  emptyAddForm,
  exportRows,
  monthDayLabel,
  parseMoneyInput,
  readConfirmation,
  readExpense,
  readRecurringCost,
  recurringRows,
  shortDay,
  statusLabel,
  validateAddForm,
  type AddForm,
  type Confirmation,
  type RecurringCost,
  type StaffSummary,
  type StoredExpense,
} from "@/lib/finance/expenses";
import { CATEGORY_LABEL, FIN, money, type ExpenseCategory } from "@/lib/finance/model";
import { monthLabel, monthName } from "@/lib/finance/months";

/**
 * Expenses for the selected month: recurring costs to confirm, the add form,
 * the month's expense table and the deleted list. All writes go through the
 * finance callables (deleting is soft, recurring costs stop instead of being
 * deleted). Plain buttons, no <form>: form submits are unreliable inside the
 * Flutter iframe.
 */

type MonthSummary = {
  status?: string;
  final?: boolean;
  teacher_pay?: number;
  teacher_pay_final?: boolean;
  admin_pay?: number;
  transfer_fees?: number;
  teachers?: unknown[];
  admins?: unknown[];
};

/** The order the add form lists the entered categories in. */
const CATEGORY_ORDER: ExpenseCategory[] = ["marketing", "software", "transfer_fees", "other"];

const BADGE = {
  ok: "bg-emerald-100 text-emerald-900",
  warn: "bg-amber-100 text-amber-900",
  mute: "bg-slate-100 text-slate-700",
} as const;

const card = "rounded-xl border border-slate-200 bg-white p-4";
const fieldLabel = "flex flex-col gap-1 text-xs font-semibold text-slate-700";
const input = "h-10 rounded-lg border border-slate-300 bg-white px-2.5 text-sm font-normal text-slate-900 disabled:bg-slate-100";
const primaryButton = "h-10 rounded-lg bg-[#0386FF] px-3 text-sm font-bold text-white disabled:opacity-50";
const quietButton = "h-10 rounded-lg border border-slate-300 bg-white px-3 text-sm font-semibold text-slate-900 disabled:opacity-50";
const dangerButton = "h-10 rounded-lg bg-red-700 px-3 text-sm font-bold text-white disabled:opacity-50";

function todayInNewYork(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
}

/** A plain sentence for a failed callable; the server's own message when it wrote one for people. */
function messageOf(error: unknown): string {
  const e = error as { code?: string; message?: string };
  if ((e?.code === "functions/failed-precondition" || e?.code === "functions/invalid-argument" || e?.code === "functions/not-found") && e.message) {
    return e.message;
  }
  return "Something went wrong. Try again.";
}

function staffFrom(summary: MonthSummary | null): StaffSummary | null {
  if (!summary) return null;
  return {
    teacherPay: Number(summary.teacher_pay) || 0,
    teacherPayFinal: summary.teacher_pay_final === true,
    teacherCount: Array.isArray(summary.teachers) ? summary.teachers.length : 0,
    adminPay: Number(summary.admin_pay) || 0,
    adminCount: Array.isArray(summary.admins) ? summary.admins.length : 0,
    transferFees: Number(summary.transfer_fees) || 0,
    final: summary.final === true,
  };
}

function monthEdges(month: string): { from: Date; to: Date } {
  const [y, m] = month.split("-").map(Number);
  const day = 24 * 60 * 60 * 1000;
  // A day either side, so a date near midnight in New York is never missed;
  // rows are then kept by their own month.
  return { from: new Date(Date.UTC(y, m - 1, 1) - day), to: new Date(Date.UTC(y, m, 1) + day) };
}

export function ExpensesScreen() {
  const { month } = useFinance();
  const today = useMemo(todayInNewYork, []);
  const name = monthName(month);

  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [costs, setCosts] = useState<RecurringCost[]>([]);
  const [confirmations, setConfirmations] = useState<Confirmation[]>([]);
  const [expenses, setExpenses] = useState<StoredExpense[]>([]);
  const [summary, setSummary] = useState<MonthSummary | null>(null);
  const [summaryFailed, setSummaryFailed] = useState(false);

  const [busy, setBusy] = useState("");
  const [notice, setNotice] = useState("");
  const [problem, setProblem] = useState("");

  const [form, setForm] = useState<AddForm>(() => emptyAddForm(month, today));
  const [formError, setFormError] = useState("");
  const [amounts, setAmounts] = useState<Record<string, string>>({});
  const [stopAsk, setStopAsk] = useState("");
  const [deleteAsk, setDeleteAsk] = useState("");
  const [deleteReason, setDeleteReason] = useState("");

  const sequence = useRef(0);

  const load = useCallback(async () => {
    const mine = ++sequence.current;
    setLoading(true);
    setLoadError("");
    const { from, to } = monthEdges(month);
    const [costSnap, confirmationSnap, expenseSnap, summaryResult] = await Promise.allSettled([
      getDocs(query(collection(db, FIN.recurringCosts), limit(300))),
      getDocs(query(collection(db, FIN.recurringConfirmations), where("month", "==", month), limit(300))),
      getDocs(query(collection(db, FIN.expenses), where("expense_date", ">=", from), where("expense_date", "<", to), limit(500))),
      httpsCallable(functions, "getFinanceMonthSummary")({ month }),
    ]);
    if (mine !== sequence.current) return;

    if (costSnap.status === "rejected" || confirmationSnap.status === "rejected" || expenseSnap.status === "rejected") {
      setLoadError("Expenses could not load. Check your connection and try again.");
    }
    if (costSnap.status === "fulfilled") {
      setCosts(costSnap.value.docs.map((d) => readRecurringCost(d.id, d.data())).filter((c): c is RecurringCost => c !== null));
    }
    if (confirmationSnap.status === "fulfilled") {
      setConfirmations(confirmationSnap.value.docs.map((d) => readConfirmation(d.id, d.data())).filter((c): c is Confirmation => c !== null));
    }
    if (expenseSnap.status === "fulfilled") {
      setExpenses(expenseSnap.value.docs.map((d) => readExpense(d.id, d.data())));
    }
    if (summaryResult.status === "fulfilled") {
      setSummary(summaryResult.value.data as MonthSummary);
      setSummaryFailed(false);
    } else {
      setSummary(null);
      setSummaryFailed(true);
    }
    setLoading(false);
  }, [month]);

  useEffect(() => {
    setForm(emptyAddForm(month, today));
    setFormError("");
    setStopAsk("");
    setDeleteAsk("");
    setDeleteReason("");
    setNotice("");
    setProblem("");
    void load();
  }, [month, today, load]);

  const closed = summary?.status === "closed";
  const staff = useMemo(() => staffFrom(summary), [summary]);
  const recurring = useMemo(() => recurringRows(costs, confirmations, month, today), [costs, confirmations, month, today]);
  const table = useMemo(
    () => buildExpenseTable({ month, today, staff, costs, confirmations, expenses }),
    [month, today, staff, costs, confirmations, expenses],
  );
  const deleted = useMemo(() => deletedExpenses(expenses, month), [expenses, month]);

  async function run(key: string, work: () => Promise<unknown>, done: string): Promise<boolean> {
    setBusy(key);
    setProblem("");
    setNotice("");
    try {
      await work();
      await load();
      setNotice(done);
      return true;
    } catch (error) {
      setProblem(messageOf(error));
      return false;
    } finally {
      setBusy("");
    }
  }

  const call = (callable: string, data: Record<string, unknown>) => httpsCallable(functions, callable)(data);

  async function addExpense() {
    const result = validateAddForm(form, month);
    if ("error" in result) {
      setFormError(result.error);
      return;
    }
    setFormError("");
    const monthly = result.payload.kind === "recurring";
    const ok = await run(
      "add",
      () => call("addFinanceExpense", result.payload),
      monthly ? `${result.payload.name} added as a monthly cost from ${name}` : `Expense added to ${name}`,
    );
    if (ok) setForm(emptyAddForm(month, today));
  }

  async function confirmCost(cost: RecurringCost) {
    const raw = amounts[cost.id] ?? cost.amount.toFixed(2);
    const amount = parseMoneyInput(raw, true);
    if (amount === null) {
      setProblem("Enter the amount on the bill.");
      return;
    }
    await run(`confirm_${cost.id}`, () => call("confirmRecurringCost", { month, cost_id: cost.id, amount, source: "manual" }), `${cost.name} confirmed at ${money(amount)}`);
  }

  async function stopCost(cost: RecurringCost) {
    const ok = await run(`stop_${cost.id}`, () => call("stopRecurringCost", { cost_id: cost.id, last_month: month }), `${cost.name} stops after ${name}`);
    if (ok) setStopAsk("");
  }

  async function deleteExpense(id: string, label: string) {
    const reason = deleteReason.trim();
    if (!reason) {
      setProblem("Say why you are deleting it.");
      return;
    }
    const ok = await run(`delete_${id}`, () => call("deleteFinanceExpense", { id, reason }), `${label} deleted`);
    if (ok) {
      setDeleteAsk("");
      setDeleteReason("");
    }
  }

  async function restoreExpense(expense: StoredExpense) {
    await run(`restore_${expense.id}`, () => call("restoreFinanceExpense", { id: expense.id }), `${expense.name} restored`);
  }

  function exportExcel() {
    downloadWorkbook(
      [{ name: "Expenses", headers: ["Category", "Item", "Date", "Amount"], rows: exportRows(table.rows, table.total) }],
      `expenses-${month}.xlsx`,
    );
  }

  return (
    <section className="flex flex-col gap-3" aria-busy={loading}>
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="m-0 text-2xl font-extrabold">Expenses · {monthLabel(month)}</h2>
        <div className="flex-1" />
        <button type="button" className={quietButton} onClick={exportExcel} disabled={loading}>
          Export to Excel
        </button>
      </div>

      {closed ? (
        <p role="status" className="m-0 rounded-lg bg-slate-200 px-3 py-2 text-sm font-semibold text-slate-900">
          {name} is closed. Reopen it to change it.
        </p>
      ) : null}
      {loadError ? (
        <p role="alert" className="m-0 rounded-lg bg-red-50 px-3 py-2 text-sm font-semibold text-red-800">
          {loadError}
        </p>
      ) : null}
      {problem ? (
        <p role="alert" className="m-0 rounded-lg bg-red-50 px-3 py-2 text-sm font-semibold text-red-800">
          {problem}
        </p>
      ) : null}
      <p role="status" aria-live="polite" className={notice ? "m-0 rounded-lg bg-emerald-50 px-3 py-2 text-sm font-semibold text-emerald-900" : "sr-only"}>
        {notice}
      </p>

      <div className={`${card} flex flex-col gap-2.5`}>
        <h3 className="m-0 text-base font-bold">Recurring costs</h3>
        <p className="m-0 text-[13px] text-slate-600">Each one appears every month. Confirm it with the amount on the bill and it counts as an expense.</p>
        {loading && recurring.length === 0 ? <p className="m-0 text-sm text-slate-600">Loading…</p> : null}
        {!loading && recurring.length === 0 ? <p className="m-0 text-sm text-slate-600">No recurring costs in {name}.</p> : null}
        <ul className="m-0 flex list-none flex-col gap-2.5 p-0">
          {recurring.map((row) => {
            const { cost } = row;
            const asking = stopAsk === cost.id;
            const badge = row.status === "confirmed" ? BADGE.ok : row.status === "due" ? BADGE.warn : BADGE.mute;
            return (
              <li key={cost.id} className="flex flex-wrap items-center gap-2.5 rounded-[10px] border border-slate-200 px-3 py-2.5">
                <div className="min-w-0 flex-[1_1_220px]">
                  <div className="font-semibold">{cost.name}</div>
                  <div className="text-xs text-slate-600">
                    {CATEGORY_LABEL[cost.category]} · every month · due {monthDayLabel(month, cost.dayOfMonth)} · usually {money(cost.amount)}
                  </div>
                </div>
                <span className={`rounded-full px-2 py-0.5 text-xs font-bold ${badge}`}>{statusLabel(row, money)}</span>
                {!closed && !asking ? (
                  <button type="button" className={quietButton} onClick={() => setStopAsk(cost.id)} disabled={Boolean(busy)}>
                    Stop after this month
                  </button>
                ) : null}
                {!closed && asking ? (
                  <div className="flex basis-full flex-wrap items-center gap-1.5">
                    <span className="text-[13px] text-red-900">
                      Stop {cost.name} after {name}? It stays in {name} and earlier months.
                    </span>
                    <button type="button" className={dangerButton} onClick={() => void stopCost(cost)} disabled={Boolean(busy)}>
                      Yes, stop it
                    </button>
                    <button type="button" className={quietButton} onClick={() => setStopAsk("")}>
                      Keep
                    </button>
                  </div>
                ) : null}
                {!closed && row.status !== "confirmed" ? (
                  <>
                    <label className="flex items-center gap-1.5 text-xs font-semibold">
                      Amount on the bill ($)
                      <input
                        type="text"
                        inputMode="decimal"
                        className={`${input} w-28`}
                        value={amounts[cost.id] ?? cost.amount.toFixed(2)}
                        onChange={(e) => setAmounts((prev) => ({ ...prev, [cost.id]: e.target.value }))}
                      />
                    </label>
                    <button type="button" className={primaryButton} onClick={() => void confirmCost(cost)} disabled={Boolean(busy)}>
                      {busy === `confirm_${cost.id}` ? "Confirming…" : "Confirm"}
                    </button>
                  </>
                ) : null}
              </li>
            );
          })}
        </ul>
      </div>

      <div className="flex flex-wrap items-start gap-4">
        <fieldset disabled={closed || Boolean(busy)} className={`${card} m-0 flex min-w-0 flex-[1_1_300px] flex-col gap-2.5`}>
          <legend className="sr-only">Add an expense</legend>
          <h3 className="m-0 text-base font-bold" aria-hidden="true">
            Add an expense
          </h3>
          <label className={fieldLabel}>
            How often
            <select className={input} value={form.freq} onChange={(e) => setForm({ ...form, freq: e.target.value === "monthly" ? "monthly" : "once" })}>
              <option value="once">One time</option>
              <option value="monthly">Every month (recurring)</option>
            </select>
          </label>
          <label className={fieldLabel}>
            Category
            <select className={input} value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value as ExpenseCategory })}>
              {CATEGORY_ORDER.map((c) => (
                <option key={c} value={c}>
                  {CATEGORY_LABEL[c]}
                </option>
              ))}
            </select>
          </label>
          <label className={fieldLabel}>
            What was it for
            <input
              type="text"
              className={input}
              value={form.name}
              maxLength={120}
              placeholder="e.g. Printed flyers for the mosque"
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
          </label>
          <div className="grid grid-cols-2 gap-2.5">
            <label className={fieldLabel}>
              Amount ($)
              <input type="text" inputMode="decimal" className={input} value={form.amount} placeholder="0.00" onChange={(e) => setForm({ ...form, amount: e.target.value })} />
            </label>
            {form.freq === "once" ? (
              <label className={fieldLabel}>
                Date
                <input type="date" className={input} value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} />
              </label>
            ) : (
              <label className={fieldLabel}>
                Billed on day
                <input type="number" min={1} max={28} className={input} value={form.day} onChange={(e) => setForm({ ...form, day: e.target.value })} />
              </label>
            )}
          </div>
          <p className="m-0 text-xs text-slate-600">{addHint(form.freq, month)}</p>
          {formError ? (
            <p role="alert" className="m-0 text-[13px] font-semibold text-red-700">
              {formError}
            </p>
          ) : null}
          <button type="button" className={primaryButton} onClick={() => void addExpense()}>
            {busy === "add" ? "Adding…" : addButtonLabel(form.freq)}
          </button>
          {closed ? <p className="m-0 text-xs text-slate-600">{name} is closed. Reopen it to change it.</p> : null}
        </fieldset>

        <div className="min-w-0 flex-[2_1_420px] relative overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full min-w-[520px] border-collapse text-[13px]">
            <caption className="sr-only">Expenses for {monthLabel(month)}</caption>
            <thead>
              <tr className="bg-slate-50 text-left text-slate-700">
                <th scope="col" className="px-3 py-2.5">Category</th>
                <th scope="col" className="px-3 py-2.5">Item</th>
                <th scope="col" className="px-3 py-2.5">Date</th>
                <th scope="col" className="px-3 py-2.5 text-right">Amount</th>
                <th scope="col" className="px-3 py-2.5"><span className="sr-only">Actions</span></th>
              </tr>
            </thead>
            <tbody>
              {table.rows.map((row) => {
                const asking = deleteAsk === row.expenseId && Boolean(row.expenseId);
                return (
                  <TableRow
                    key={row.key}
                    category={row.category}
                    name={row.name}
                    note={row.note}
                    date={row.date}
                    amount={money(row.amount)}
                    action={
                      row.expenseId && !closed && !asking ? (
                        <button
                          type="button"
                          aria-label={`Delete ${row.name}`}
                          className="h-9 rounded-lg border border-slate-300 bg-white px-2.5 text-sm font-semibold text-red-700"
                          onClick={() => {
                            setDeleteAsk(row.expenseId ?? "");
                            setDeleteReason("");
                          }}
                          disabled={Boolean(busy)}
                        >
                          Delete
                        </button>
                      ) : null
                    }
                    below={
                      asking && row.expenseId ? (
                        <div className="flex flex-wrap items-center gap-1.5">
                          <label className="flex min-w-0 flex-[1_1_220px] flex-col gap-1 text-xs font-semibold text-slate-700">
                            Why are you deleting {row.name}?
                            <input
                              type="text"
                              className={input}
                              value={deleteReason}
                              maxLength={300}
                              placeholder="e.g. Entered twice"
                              onChange={(e) => setDeleteReason(e.target.value)}
                            />
                          </label>
                          <button
                            type="button"
                            className={`${dangerButton} self-end`}
                            onClick={() => void deleteExpense(row.expenseId ?? "", row.name)}
                            disabled={Boolean(busy) || !deleteReason.trim()}
                          >
                            Yes, delete
                          </button>
                          <button type="button" className={`${quietButton} self-end`} onClick={() => setDeleteAsk("")}>
                            Keep
                          </button>
                        </div>
                      ) : null
                    }
                  />
                );
              })}
              {!loading && table.rows.length === 0 ? (
                <tr className="border-t border-slate-200">
                  <td colSpan={5} className="px-3 py-3 text-slate-600">
                    No expenses in {name} yet.
                  </td>
                </tr>
              ) : null}
              <tr className="border-t-2 border-slate-300 bg-slate-50">
                <th scope="row" colSpan={3} className="px-3 py-2.5 text-left font-extrabold">
                  Total expenses{table.hasEstimate ? " (includes estimates)" : ""}
                </th>
                <td className="px-3 py-2.5 text-right font-extrabold">{money(table.total)}</td>
                <td />
              </tr>
            </tbody>
          </table>
          {summaryFailed ? (
            <p role="alert" className="m-0 border-t border-slate-200 px-3 py-2 text-xs font-semibold text-amber-900">
              Teacher pay and administrator pay could not load, so they are not in this total.
            </p>
          ) : null}
        </div>
      </div>

      {deleted.length > 0 ? (
        <div className={`${card} flex flex-col gap-2.5`}>
          <h3 className="m-0 text-base font-bold">Deleted expenses</h3>
          <p className="m-0 text-[13px] text-slate-600">Deleted expenses are not in the total. Restore one to count it again.</p>
          <ul className="m-0 flex list-none flex-col gap-2 p-0">
            {deleted.map((expense) => (
              <li key={expense.id} className="flex flex-wrap items-center gap-2.5 rounded-[10px] border border-slate-200 px-3 py-2.5">
                <div className="min-w-0 flex-[1_1_240px]">
                  <div className="font-semibold">
                    {expense.name} · {expense.category ? CATEGORY_LABEL[expense.category] : ""} · {money(expense.amount)}
                  </div>
                  <div className="text-xs text-slate-600">
                    Deleted {shortDay(expense.deletedAt)}
                    {expense.deletedByName ? ` by ${expense.deletedByName}` : ""} · {expense.deleteReason || "No reason recorded"}
                  </div>
                </div>
                {!closed ? (
                  <button type="button" aria-label={`Restore ${expense.name}`} className={quietButton} onClick={() => void restoreExpense(expense)} disabled={Boolean(busy)}>
                    {busy === `restore_${expense.id}` ? "Restoring…" : "Restore"}
                  </button>
                ) : null}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}

function TableRow(props: {
  category: string;
  name: string;
  note: string;
  date: string;
  amount: string;
  action: ReactNode;
  below: ReactNode;
}) {
  return (
    <>
      <tr className="border-t border-slate-200">
        <td className="px-3 py-2.5 text-slate-700">{props.category}</td>
        <td className="px-3 py-2.5 font-semibold">
          {props.name} <span className="font-normal text-slate-600">{props.note}</span>
        </td>
        <td className="px-3 py-2.5">{props.date}</td>
        <td className="px-3 py-2.5 text-right font-bold">{props.amount}</td>
        <td className="whitespace-nowrap px-3 py-2.5">{props.action}</td>
      </tr>
      {props.below ? (
        <tr className="bg-slate-50">
          <td colSpan={5} className="px-3 py-2.5">
            {props.below}
          </td>
        </tr>
      ) : null}
    </>
  );
}
