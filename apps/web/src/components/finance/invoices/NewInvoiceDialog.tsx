"use client";

import { useEffect, useMemo, useState } from "react";
import { money, r2 } from "@/lib/finance/model";
import { addMonths, monthLabel } from "@/lib/finance/months";
import { addDays, dayKeyNY, findMonthlyClash, firstInvoicePreview, formatDay, monthOfDate, type Invoice } from "@/lib/finance/invoices";
import {
  callCreateFirstInvoice,
  callCreateInvoice,
  errorMessage,
  loadBillableUsers,
  loadChildren,
  loadFamilyBilling,
  loadFamilyInvoices,
  type Billable,
  type Child,
  type FamilyBilling,
  type FinanceSettingsView,
} from "./data";
import { CloseButton, Field, Modal, Notice, outlineButton, primaryButton, inputClass } from "./ui";

type Kind = "first" | "tuition" | "oneoff";

type Props = {
  settings: FinanceSettingsView;
  now: Date;
  onClose: () => void;
  /** Open an existing invoice (the "Already billed" link). */
  onOpen: (invoiceId: string) => void;
  onCreated: (invoiceId: string) => void;
};

const pad = (n: number) => String(n).padStart(2, "0");

export function NewInvoiceDialog({ settings, now, onClose, onOpen, onCreated }: Props) {
  const today = dayKeyNY(now);
  const thisMonth = monthOfDate(now);

  const [kind, setKind] = useState<Kind>("first");
  const [users, setUsers] = useState<Billable[] | null>(null);
  const [search, setSearch] = useState("");
  const [parent, setParent] = useState<Billable | null>(null);
  const [children, setChildren] = useState<Child[]>([]);
  const [familyInvoices, setFamilyInvoices] = useState<Invoice[]>([]);
  const [billing, setBilling] = useState<FamilyBilling | null>(null);
  const [loadingFamily, setLoadingFamily] = useState(false);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  // first invoice
  const [studentId, setStudentId] = useState("");
  const [first, setFirst] = useState({ monthly: "", perMonth: "8", left: "", start: today });

  // monthly tuition
  const [tuitionMonth, setTuitionMonth] = useState(addMonths(thisMonth, 1));
  const [amounts, setAmounts] = useState<Record<string, string>>({});
  const [tuitionDue, setTuitionDue] = useState("");

  // one-off
  const [oneOff, setOneOff] = useState({ studentId: "", description: "", amount: "", due: addDays(today, 7) });

  useEffect(() => {
    let alive = true;
    loadBillableUsers()
      .then((list) => alive && setUsers(list))
      .catch((error) => alive && setMessage(errorMessage(error, "Could not load families.")));
    return () => {
      alive = false;
    };
  }, []);

  // The due date follows the month picked, until someone types one.
  useEffect(() => {
    setTuitionDue(`${tuitionMonth}-${pad(settings.due_day)}`);
  }, [tuitionMonth, settings.due_day]);

  const matches = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!users || !term) return [];
    return users.filter((u) => `${u.name} ${u.email}`.toLowerCase().includes(term)).slice(0, 8);
  }, [users, search]);

  const pickParent = async (u: Billable) => {
    setParent(u);
    setSearch("");
    setMessage("");
    setLoadingFamily(true);
    try {
      const [kids, invoices, b] = await Promise.all([loadChildren(u), loadFamilyInvoices(u.id), loadFamilyBilling(u.id).catch(() => null)]);
      setChildren(kids);
      setFamilyInvoices(invoices);
      setBilling(b);
      setStudentId(kids[0]?.id ?? "");
      setOneOff((o) => ({ ...o, studentId: kids[0]?.id ?? "" }));
      setAmounts(kids.length === 1 && b ? { [kids[0].id]: b.monthlyAmount.toFixed(2) } : {});
      setFirst((f) => ({ ...f, monthly: b ? b.monthlyAmount.toFixed(2) : "" }));
    } catch (error) {
      setMessage(errorMessage(error, "Could not load this family."));
    } finally {
      setLoadingFamily(false);
    }
  };

  const clearParent = () => {
    setParent(null);
    setChildren([]);
    setFamilyInvoices([]);
    setBilling(null);
    setMessage("");
  };

  const studentName = children.find((c) => c.id === studentId)?.name ?? "";
  const preview = firstInvoicePreview(first, { studentName, dueDays: settings.first_invoice_due_days, issueDay: settings.issue_day, dueDay: settings.due_day }, money);
  const clash = parent && kind === "tuition" ? findMonthlyClash(familyInvoices, parent.id, tuitionMonth) : null;
  const firstClash = parent && kind === "first" && preview.ok ? findMonthlyClash(familyInvoices, parent.id, first.start.slice(0, 7)) : null;

  const tuitionLines = children
    .map((c) => ({ child: c, amount: Number(amounts[c.id] ?? "") }))
    .filter((l) => (amounts[l.child.id] ?? "").trim() !== "" && Number.isFinite(l.amount) && l.amount >= 0);
  const tuitionTotal = r2(tuitionLines.reduce((s, l) => s + l.amount, 0));
  const tuitionOk = !!parent && !clash && tuitionLines.some((l) => l.amount > 0) && /^\d{4}-\d{2}-\d{2}$/.test(tuitionDue);
  const oneOffAmount = Number(oneOff.amount);
  const oneOffOk = !!parent && !!oneOff.studentId && !!oneOff.description.trim() && oneOff.amount.trim() !== "" && Number.isFinite(oneOffAmount) && oneOffAmount > 0 && /^\d{4}-\d{2}-\d{2}$/.test(oneOff.due);

  const submit = async (work: () => Promise<string>) => {
    setBusy(true);
    setMessage("");
    try {
      onCreated(await work());
    } catch (error) {
      setMessage(errorMessage(error));
    } finally {
      setBusy(false);
    }
  };

  const createFirst = () =>
    submit(async () => {
      const out = await callCreateFirstInvoice({
        parent_id: parent!.id,
        student_id: studentId,
        monthly_amount: r2(preview.monthly),
        classes_in_month: preview.perMonth,
        classes_left: preview.left,
        first_class_date: first.start,
      });
      return out.invoice_id;
    });

  const createTuition = () =>
    submit(async () => {
      const label = monthLabel(tuitionMonth);
      const out = await callCreateInvoice({
        parentId: parent!.userType === "parent" ? parent!.id : tuitionLines[0].child.id,
        studentId: tuitionLines[0].child.id,
        currency: "USD",
        kind: "monthly",
        period: tuitionMonth,
        billingMonth: tuitionMonth,
        dueDate: `${tuitionDue}T12:00:00.000Z`,
        items: tuitionLines.map((l) => ({
          description: `Tuition - ${l.child.name} · ${label}`,
          quantity: 1,
          unit_price: r2(l.amount),
          total: r2(l.amount),
          // Without the student the backend cannot apply that child's discount.
          student_id: l.child.id,
        })),
      });
      return out.invoiceId;
    });

  const createOneOff = () =>
    submit(async () => {
      const out = await callCreateInvoice({
        parentId: parent!.userType === "parent" ? parent!.id : oneOff.studentId,
        studentId: oneOff.studentId,
        currency: "USD",
        kind: "one_off",
        billingMonth: thisMonth,
        dueDate: `${oneOff.due}T12:00:00.000Z`,
        items: [
          {
            description: oneOff.description.trim(),
            quantity: 1,
            unit_price: r2(oneOffAmount),
            total: r2(oneOffAmount),
            student_id: oneOff.studentId,
          },
        ],
      });
      return out.invoiceId;
    });

  const monthOptions = [addMonths(thisMonth, -1), thisMonth, addMonths(thisMonth, 1), addMonths(thisMonth, 2)];

  return (
    <Modal label="New invoice" onClose={onClose} maxWidth="max-w-[560px]">
      <div className="flex items-center gap-2">
        <h2 className="flex-1 text-lg font-extrabold">New invoice</h2>
        <CloseButton onClick={onClose} />
      </div>

      <Field label="Type">
        <select
          className={inputClass}
          value={kind}
          onChange={(e) => {
            setKind(e.target.value as Kind);
            setMessage("");
          }}
        >
          <option value="first">First invoice for a new student (sets the monthly amount)</option>
          <option value="tuition">Monthly tuition</option>
          <option value="oneoff">One-off charge (books, exam fee…)</option>
        </select>
      </Field>

      {/* Family */}
      {parent ? (
        <div className="flex flex-wrap items-center gap-2 rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm">
          <span className="font-bold">{parent.name}</span>
          {parent.email ? <span className="text-slate-600">{parent.email}</span> : null}
          <span className="flex-1" />
          <button type="button" className="text-sm font-semibold text-[#024E96] underline" onClick={clearParent}>
            Change
          </button>
        </div>
      ) : (
        <div className="flex flex-col gap-1.5">
          <Field label="Parent">
            <input className={inputClass} type="text" value={search} placeholder={users ? "Search by name or email" : "Loading families…"} disabled={!users} onChange={(e) => setSearch(e.target.value)} />
          </Field>
          {matches.length > 0 ? (
            <ul className="flex flex-col overflow-hidden rounded-lg border border-slate-200">
              {matches.map((u) => (
                <li key={u.id} className="border-b border-slate-200 last:border-b-0">
                  <button type="button" className="flex min-h-11 w-full flex-col items-start px-3 py-1.5 text-left text-sm hover:bg-slate-50" onClick={() => pickParent(u)}>
                    <span className="font-semibold">{u.name}</span>
                    <span className="text-xs text-slate-600">
                      {u.email}
                      {u.userType === "student" ? " · adult student" : ""}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          ) : search.trim() && users ? (
            <p className="text-xs text-slate-600">No family matches “{search.trim()}”.</p>
          ) : null}
        </div>
      )}
      {loadingFamily ? <p className="text-sm text-slate-600">Loading the family…</p> : null}
      {parent && !loadingFamily && children.length === 0 ? <Notice tone="info">No student is linked to {parent.name} yet.</Notice> : null}

      {parent && children.length > 0 && kind === "first" ? (
        <>
          <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
            <Field label="Student">
              <select className={inputClass} value={studentId} onChange={(e) => setStudentId(e.target.value)}>
                {children.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Monthly amount ($)">
              <input className={inputClass} type="number" inputMode="decimal" step="0.01" min="0" value={first.monthly} placeholder="e.g. 80" onChange={(e) => setFirst({ ...first, monthly: e.target.value })} />
            </Field>
            <Field label="Classes in a full month">
              <input className={inputClass} type="number" inputMode="numeric" min="1" value={first.perMonth} onChange={(e) => setFirst({ ...first, perMonth: e.target.value })} />
            </Field>
            <Field label="Classes left this month">
              <input className={inputClass} type="number" inputMode="numeric" min="1" value={first.left} onChange={(e) => setFirst({ ...first, left: e.target.value })} />
            </Field>
            <Field label="First class" className="sm:col-span-2">
              <input className={inputClass} type="date" value={first.start} onChange={(e) => setFirst({ ...first, start: e.target.value })} />
            </Field>
          </div>
          {billing ? <p className="text-xs text-slate-600">This family&apos;s monthly amount is {money(billing.monthlyAmount)} today. The amount above replaces it for the invoices after this one.</p> : null}
          <div className="rounded-lg bg-slate-50 p-3 text-[13px] text-slate-700">{preview.text}</div>
          {firstClash ? (
            <Notice tone="info">
              {firstClash.number} already bills this family for {monthLabel(first.start.slice(0, 7))}.{" "}
              <button type="button" className="font-semibold underline" onClick={() => onOpen(firstClash.id)}>
                Open {firstClash.number}
              </button>
            </Notice>
          ) : null}
          <p className="text-xs text-slate-600">The monthly amount stays the same every month until staff change it on any of the family&apos;s invoices.</p>
          <button type="button" className={primaryButton} disabled={!preview.ok || !studentId || busy} onClick={createFirst}>
            {busy ? "Creating…" : "Create first invoice"}
          </button>
        </>
      ) : null}

      {parent && children.length > 0 && kind === "tuition" ? (
        <>
          <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
            <Field label="For month">
              <select className={inputClass} value={tuitionMonth} onChange={(e) => setTuitionMonth(e.target.value)}>
                {monthOptions.map((m) => (
                  <option key={m} value={m}>
                    {monthLabel(m)}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Due date">
              <input className={inputClass} type="date" value={tuitionDue} onChange={(e) => setTuitionDue(e.target.value)} />
            </Field>
          </div>
          {clash ? (
            <div className="flex flex-col gap-2 rounded-lg bg-red-50 p-3 text-[13px] text-red-900">
              <div>
                <strong>Already billed.</strong> {parent.name} already has {clash.number} for {monthLabel(tuitionMonth)} ({money(clash.total)}). A family gets one tuition invoice per month.
              </div>
              <button type="button" className={outlineButton} onClick={() => onOpen(clash.id)}>
                Open {clash.number}
              </button>
            </div>
          ) : (
            <>
              {children.map((c) => (
                <Field key={c.id} label={`${c.name} ($)`}>
                  <input
                    className={inputClass}
                    type="number"
                    inputMode="decimal"
                    step="0.01"
                    min="0"
                    value={amounts[c.id] ?? ""}
                    placeholder="Leave empty to leave this student off"
                    onChange={(e) => setAmounts({ ...amounts, [c.id]: e.target.value })}
                  />
                </Field>
              ))}
              {billing ? <p className="text-xs text-slate-600">The family&apos;s monthly amount is {money(billing.monthlyAmount)}.</p> : null}
              <div className="rounded-lg bg-slate-50 p-3 text-[13px] text-slate-700">
                {tuitionLines.length
                  ? `${monthLabel(tuitionMonth)} tuition for ${tuitionLines.map((l) => l.child.name.split(" ")[0]).join(", ")}: ${money(tuitionTotal)} before discounts, due ${formatDay(tuitionDue)}.`
                  : "Enter an amount for at least one student."}
              </div>
              <button type="button" className={primaryButton} disabled={!tuitionOk || busy} onClick={createTuition}>
                {busy ? "Creating…" : "Create invoice"}
              </button>
            </>
          )}
        </>
      ) : null}

      {parent && children.length > 0 && kind === "oneoff" ? (
        <>
          <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
            <Field label="Student">
              <select className={inputClass} value={oneOff.studentId} onChange={(e) => setOneOff({ ...oneOff, studentId: e.target.value })}>
                {children.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Due date">
              <input className={inputClass} type="date" value={oneOff.due} onChange={(e) => setOneOff({ ...oneOff, due: e.target.value })} />
            </Field>
            <Field label="Description">
              <input className={inputClass} type="text" value={oneOff.description} placeholder="Arabic workbook" onChange={(e) => setOneOff({ ...oneOff, description: e.target.value })} />
            </Field>
            <Field label="Amount ($)">
              <input className={inputClass} type="number" inputMode="decimal" step="0.01" min="0" value={oneOff.amount} placeholder="0.00" onChange={(e) => setOneOff({ ...oneOff, amount: e.target.value })} />
            </Field>
          </div>
          <div className="rounded-lg bg-slate-50 p-3 text-[13px] text-slate-700">
            One-off charge for {parent.name}
            {oneOff.description.trim() ? `: ${oneOff.description.trim()}` : ""}
            {Number.isFinite(oneOffAmount) && oneOff.amount.trim() ? ` — ${money(oneOffAmount)}` : ""}.
          </div>
          <button type="button" className={primaryButton} disabled={!oneOffOk || busy} onClick={createOneOff}>
            {busy ? "Creating…" : "Create invoice"}
          </button>
        </>
      ) : null}

      {message ? <Notice tone="error">{message}</Notice> : null}
    </Modal>
  );
}
