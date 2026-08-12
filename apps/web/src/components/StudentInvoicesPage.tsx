"use client";

import { onAuthStateChanged } from "firebase/auth";
import { collection, doc, getDoc, onSnapshot, query, Timestamp, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useEffect, useMemo, useState } from "react";
import { CalendarDays, CreditCard, Loader2, Lock, Search, TriangleAlert, User } from "lucide-react";
import { auth, db, functions } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";
import { ConfirmDialog, type ConfirmRequest } from "@/components/ConfirmDialog";

type AccessState = "checking" | "signedOut" | "denied" | "allowed";
type StatusFilter = "all" | "pending" | "paid" | "overdue" | "cancelled";

const FILTERS: { id: StatusFilter; label: string }[] = [
  { id: "all", label: "All" },
  { id: "pending", label: "Pending" },
  { id: "paid", label: "Paid" },
  { id: "overdue", label: "Overdue" },
  { id: "cancelled", label: "Cancelled" },
];

type InvoiceRecord = {
  id: string;
  invoiceNumber: string;
  studentName: string;
  status: string;
  totalAmount: number;
  paidAmount: number;
  dueDate: Date | null;
  billingPeriod: string;
  accessSuspendedAt: Date | null;
  studentId: string;
};

export default function StudentInvoicesPage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [invoices, setInvoices] = useState<InvoiceRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<StatusFilter>("all");
  const [search, setSearch] = useState("");
  const [payingId, setPayingId] = useState("");
  const [payError, setPayError] = useState("");
  const [confirm, setConfirm] = useState<ConfirmRequest | null>(null);
  // Invoice docs carry no student_name; ParentInvoicesScreen resolves it from
  // student_id against /users, so the cards can show whose invoice it is.
  const [studentNames, setStudentNames] = useState<Record<string, string>>({});

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }
      const session = await resolveStudentSession(nextUser);
      if (!session.isStudent) {
        setAccess("denied");
        setLoading(false);
        return;
      }
      setSummary(session.summary);
      setIsAdultStudent(session.isAdultStudent);
      setAccess("allowed");
    });
  }, []);

  /**
   * An adult student's invoices can be keyed either way: parent_id when they
   * are their own payer, or student_id when the invoice was raised against the
   * student directly. InvoiceService.getParentInvoices merges both streams for
   * exactly this reason — querying only parent_id showed this account nothing
   * even though it has fifteen invoices.
   */
  useEffect(() => {
    const uid = auth.currentUser?.uid;
    if (access !== "allowed" || !uid) return;

    let byParent: InvoiceRecord[] = [];
    let byStudent: InvoiceRecord[] = [];
    let parentReady = false;
    let studentReady = false;

    const emit = () => {
      if (!parentReady || !studentReady) return;
      const merged = new Map<string, InvoiceRecord>();
      [...byParent, ...byStudent].forEach((invoice) => merged.set(invoice.id, invoice));
      setInvoices(
        [...merged.values()].sort((a, b) => (b.dueDate?.getTime() ?? 0) - (a.dueDate?.getTime() ?? 0)),
      );
      setLoading(false);
    };

    const unsubParent = onSnapshot(
      query(collection(db, "invoices"), where("parent_id", "==", uid)),
      (snap) => {
        byParent = snap.docs.map((entry) => normalizeInvoice(entry.id, entry.data() as Record<string, unknown>));
        parentReady = true;
        emit();
      },
      () => {
        parentReady = true;
        emit();
      },
    );

    const unsubStudent = onSnapshot(
      query(collection(db, "invoices"), where("student_id", "==", uid)),
      (snap) => {
        byStudent = snap.docs.map((entry) => normalizeInvoice(entry.id, entry.data() as Record<string, unknown>));
        studentReady = true;
        emit();
      },
      () => {
        studentReady = true;
        emit();
      },
    );

    return () => {
      unsubParent();
      unsubStudent();
    };
  }, [access]);

  useEffect(() => {
    const missing = [...new Set(invoices.map((invoice) => invoice.studentId))].filter(
      (studentId) => studentId && !studentNames[studentId],
    );
    if (missing.length === 0) return;
    let cancelled = false;
    void (async () => {
      const resolved: Record<string, string> = {};
      for (const studentId of missing) {
        const snap = await getDoc(doc(db, "users", studentId)).catch(() => null);
        if (!snap?.exists()) continue;
        const data = snap.data() as Record<string, unknown>;
        const name = [stringValue(data.first_name), stringValue(data.last_name)].filter(Boolean).join(" ");
        if (name) resolved[studentId] = name;
      }
      if (!cancelled && Object.keys(resolved).length > 0) {
        setStudentNames((current) => ({ ...current, ...resolved }));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [invoices, studentNames]);

  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();
    return invoices.filter((invoice) => {
      if (filter !== "all" && effectiveStatus(invoice) !== filter) return false;
      if (!term) return true;
      return [invoice.invoiceNumber, invoice.studentName].some((value) => value.toLowerCase().includes(term));
    });
  }, [filter, invoices, search]);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  async function payNow(invoice: InvoiceRecord) {
    setPayingId(invoice.id);
    setPayError("");
    try {
      // Exactly what _payWithStripeCheckout does on Flutter web: the callable
      // answers { success, paymentId, checkoutUrl } and the browser is sent to
      // Stripe. The native Stripe sheet is mobile-only, so web pays by Checkout.
      const result = await httpsCallable(functions, "createPaymentSession")({ invoiceId: invoice.id });
      const data = (result.data ?? {}) as Record<string, unknown>;
      if (data.success !== true) throw new Error(stringValue(data.error) || "Failed to create checkout session");
      const checkoutUrl = stringValue(data.checkoutUrl);
      if (!checkoutUrl || !/^https?:\/\//.test(checkoutUrl)) throw new Error("Invalid checkout response from server");
      window.location.assign(checkoutUrl);
    } catch (error) {
      setPayError(error instanceof Error ? error.message : "Could not start checkout.");
      setPayingId("");
    }
  }

  return (
    <StudentShell activeLabel="Invoices" breadcrumb="Finance / Invoices" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="mx-auto w-full max-w-[1180px] px-4 py-6 md:px-6">
        <h1 className="text-center text-2xl font-black text-[#0F172A]">Invoices</h1>

        <div className="relative mt-5">
          <Search aria-hidden="true" className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={18} />
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search invoice, parent, student, email, phone, or ID"
            aria-label="Search invoices"
            className="h-12 w-full rounded-2xl border border-[#E2E8F0] bg-white pl-12 pr-4 text-sm text-[#334155] outline-none focus:border-[#2563EB]"
          />
        </div>

        <div className="mt-4 flex flex-wrap justify-center gap-2">
          {FILTERS.map((entry) => (
            <button
              key={entry.id}
              type="button"
              onClick={() => setFilter(entry.id)}
              aria-pressed={filter === entry.id}
              className={`min-h-9 rounded-full px-4 text-xs font-bold transition ${
                filter === entry.id ? "bg-[#2563EB] text-white" : "border border-[#E2E8F0] bg-white text-[#475569] hover:bg-[#F1F5F9]"
              }`}
            >
              {entry.label}
            </button>
          ))}
        </div>

        {payError ? (
          <p className="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-bold text-red-700">{payError}</p>
        ) : null}

        {loading ? (
          <div className="grid min-h-[40vh] place-items-center text-[#64748B]">
            <span className="inline-flex items-center gap-2 text-sm font-bold">
              <Loader2 className="animate-spin" size={18} />
              Loading your invoices…
            </span>
          </div>
        ) : visible.length === 0 ? (
          <p className="mt-8 rounded-2xl border border-dashed border-[#CBD5E1] px-4 py-10 text-center text-sm font-semibold text-[#94A3B8]">
            No invoices to show.
          </p>
        ) : (
          <div className="mt-5 grid gap-4">
            {visible.map((invoice) => (
              <InvoiceCard
                key={invoice.id}
                invoice={{ ...invoice, studentName: invoice.studentName || studentNames[invoice.studentId] || "" }}
                paying={payingId === invoice.id}
                onPay={() =>
                  setConfirm({
                    title: "Continue to payment",
                    body: `You are about to pay $${Math.max(0, Number((invoice.totalAmount - invoice.paidAmount).toFixed(2))).toFixed(2)} for ${invoice.invoiceNumber}. You will be taken to Stripe to complete the payment.`,
                    confirmLabel: "Continue",
                    destructive: false,
                    onConfirm: () => void payNow(invoice),
                  })
                }
              />
            ))}
          </div>
        )}
        <ConfirmDialog request={confirm} onClose={() => setConfirm(null)} />
      </div>
    </StudentShell>
  );
}

function InvoiceCard({ invoice, paying, onPay }: { invoice: InvoiceRecord; paying: boolean; onPay: () => void }) {
  const status = effectiveStatus(invoice);
  const due = Math.max(0, Number((invoice.totalAmount - invoice.paidAmount).toFixed(2)));
  const overdueDays = status === "overdue" && invoice.dueDate ? daysSince(invoice.dueDate) : 0;
  const accent = status === "paid" ? "#16A34A" : status === "overdue" ? "#DC2626" : status === "cancelled" ? "#94A3B8" : "#F59E0B";
  const canPay = status !== "paid" && status !== "cancelled" && due > 0;

  return (
    <article className="overflow-hidden rounded-2xl border border-black/5 bg-white shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
      <div className="flex gap-4">
        <span aria-hidden="true" className="w-1.5 shrink-0" style={{ backgroundColor: accent }} />
        <div className="min-w-0 flex-1 py-4 pr-4">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <h2 className="truncate text-base font-black text-[#0F172A]">{invoice.invoiceNumber}</h2>
              {invoice.studentName ? (
                <p className="mt-1 flex items-center gap-1.5 text-xs font-semibold text-[#64748B]">
                  <User size={13} />
                  {invoice.studentName}
                </p>
              ) : null}
              {invoice.billingPeriod ? (
                <p className="mt-1 flex items-center gap-1.5 text-xs font-bold text-[#2563EB]">
                  <CalendarDays size={13} />
                  {invoice.billingPeriod}
                </p>
              ) : null}
            </div>
            <StatusBadge status={status} />
          </div>

          <div className="mt-3 flex flex-wrap items-end justify-between gap-3">
            <div>
              <p className="text-[11px] font-semibold text-[#94A3B8]">Amount due</p>
              <p className="text-2xl font-black" style={{ color: accent }}>
                ${due.toFixed(2)}
              </p>
            </div>
            {overdueDays > 0 ? (
              <span className="inline-flex items-center gap-1.5 rounded-lg bg-[#FEF2F2] px-2.5 py-1.5 text-[11px] font-bold text-[#B91C1C]">
                <TriangleAlert size={13} />
                {overdueDays} day{overdueDays === 1 ? "" : "s"} overdue
              </span>
            ) : invoice.dueDate ? (
              <span className="inline-flex items-center gap-1.5 rounded-lg border border-[#E2E8F0] px-2.5 py-1.5 text-[11px] font-semibold text-[#475569]">
                <CalendarDays size={13} />
                {invoice.dueDate.toLocaleDateString(undefined, { month: "short", day: "numeric" })}
              </span>
            ) : null}
          </div>

          {invoice.accessSuspendedAt && invoice.accessSuspendedAt.getTime() < Date.now() && due > 0 ? (
            <p className="mt-3 flex items-center gap-2 rounded-lg bg-[#FEF2F2] px-3 py-2 text-[11px] font-semibold text-[#B91C1C]">
              <Lock size={13} />
              Access suspended {daysSince(invoice.accessSuspendedAt)} day
              {daysSince(invoice.accessSuspendedAt) === 1 ? "" : "s"} ago
            </p>
          ) : null}

          {canPay ? (
            <button
              type="button"
              onClick={onPay}
              disabled={paying}
              className="mt-3 inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-xl bg-[#1D4ED8] text-sm font-black text-white disabled:opacity-70"
            >
              {paying ? <Loader2 className="animate-spin" size={16} /> : <CreditCard size={16} />}
              {paying ? "Starting checkout…" : "Pay Now"}
            </button>
          ) : null}
        </div>
      </div>
    </article>
  );
}

function StatusBadge({ status }: { status: string }) {
  const tone: Record<string, string> = {
    paid: "bg-[#DCFCE7] text-[#166534]",
    overdue: "bg-[#FEE2E2] text-[#B91C1C]",
    cancelled: "bg-[#F1F5F9] text-[#64748B]",
    pending: "bg-[#FEF3C7] text-[#92400E]",
  };
  return (
    <span className={`shrink-0 rounded-full px-2.5 py-1 text-[10px] font-black uppercase tracking-wide ${tone[status] ?? tone.pending}`}>
      {status}
    </span>
  );
}

/** Overdue is derived, exactly as the invoice cards in the app present it. */
function effectiveStatus(invoice: InvoiceRecord) {
  const status = invoice.status.toLowerCase();
  if (status === "paid" || status === "cancelled") return status;
  const due = invoice.totalAmount - invoice.paidAmount;
  if (due > 0 && invoice.dueDate && invoice.dueDate.getTime() < Date.now()) return "overdue";
  return status || "pending";
}

function normalizeInvoice(id: string, data: Record<string, unknown>): InvoiceRecord {
  return {
    id,
    invoiceNumber: stringValue(data.invoice_number ?? data.invoiceNumber) || id,
    studentName: stringValue(data.student_name ?? data.studentName),
    status: stringValue(data.status) || "pending",
    totalAmount: numberValue(data.total_amount ?? data.totalAmount),
    paidAmount: numberValue(data.paid_amount ?? data.paidAmount),
    dueDate: dateValue(data.due_date ?? data.dueDate),
    // `period` is stored as "2026-08"; the cards show it as "Aug 2026".
    billingPeriod: formatPeriod(stringValue(data.period)),
    // There is no access_suspended_at field — suspension is driven by
    // access_cutoff_date having passed while the invoice is still unpaid.
    accessSuspendedAt: dateValue(data.access_cutoff_date ?? data.accessCutoffDate),
    studentId: stringValue(data.student_id ?? data.studentId),
  };
}

/** "2026-08" -> "Aug 2026", matching the invoice cards in the app. */
function formatPeriod(period: string) {
  const match = /^(\d{4})-(\d{2})$/.exec(period);
  if (!match) return period;
  const date = new Date(Number(match[1]), Number(match[2]) - 1, 1);
  return date.toLocaleDateString(undefined, { month: "short", year: "numeric" });
}

function daysSince(value: Date) {
  return Math.max(0, Math.floor((Date.now() - value.getTime()) / 86400000));
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function numberValue(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "ST";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
