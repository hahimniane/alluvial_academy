"use client";

import { onAuthStateChanged } from "firebase/auth";
import { collection, onSnapshot, query, Timestamp, where } from "firebase/firestore";
import { useEffect, useState } from "react";
import { CheckCircle2, Clock3, Loader2, XCircle } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";

type AccessState = "checking" | "signedOut" | "denied" | "allowed";

type PaymentRecord = {
  id: string;
  amount: number;
  status: string;
  method: string;
  invoiceNumber: string;
  createdAt: Date | null;
};

export default function StudentPaymentsPage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [payments, setPayments] = useState<PaymentRecord[]>([]);
  const [loading, setLoading] = useState(true);

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
   * Payments are matched on parent_id OR student_id.
   *
   * PaymentService.getPaymentHistory in the Flutter app queries parent_id only,
   * which shows an adult student "No payments yet" even when payments exist
   * against them — their own records are keyed by student_id. Firestore rules
   * for /payments already allow reading by parent_id, student_id or payer_id,
   * so both queries are permitted; this simply stops hiding a student's own
   * payment history from them.
   */
  useEffect(() => {
    const uid = auth.currentUser?.uid;
    if (access !== "allowed" || !uid) return;

    let byParent: PaymentRecord[] = [];
    let byStudent: PaymentRecord[] = [];
    let parentReady = false;
    let studentReady = false;

    const emit = () => {
      if (!parentReady || !studentReady) return;
      const merged = new Map<string, PaymentRecord>();
      [...byParent, ...byStudent].forEach((payment) => merged.set(payment.id, payment));
      setPayments([...merged.values()].sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0)));
      setLoading(false);
    };

    const watch = (field: "parent_id" | "student_id", assign: (rows: PaymentRecord[]) => void, done: () => void) =>
      onSnapshot(
        query(collection(db, "payments"), where(field, "==", uid)),
        (snap) => {
          assign(snap.docs.map((entry) => normalizePayment(entry.id, entry.data() as Record<string, unknown>)));
          done();
          emit();
        },
        () => {
          done();
          emit();
        },
      );

    const unsubParent = watch("parent_id", (rows) => { byParent = rows; }, () => { parentReady = true; });
    const unsubStudent = watch("student_id", (rows) => { byStudent = rows; }, () => { studentReady = true; });

    return () => {
      unsubParent();
      unsubStudent();
    };
  }, [access]);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  return (
    <StudentShell activeLabel="Payments" breadcrumb="Finance / Payments" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="mx-auto w-full max-w-[1180px] px-4 py-6 md:px-6">
        <h1 className="text-center text-2xl font-black text-[#0F172A]">Payment History</h1>

        {loading ? (
          <div className="grid min-h-[40vh] place-items-center text-[#64748B]">
            <span className="inline-flex items-center gap-2 text-sm font-bold">
              <Loader2 className="animate-spin" size={18} />
              Loading your payments…
            </span>
          </div>
        ) : payments.length === 0 ? (
          <p className="mt-10 text-center text-sm font-semibold text-[#94A3B8]">No payments yet.</p>
        ) : (
          <div className="mt-6 grid gap-3">
            {payments.map((payment) => (
              <PaymentRow key={payment.id} payment={payment} />
            ))}
          </div>
        )}
      </div>
    </StudentShell>
  );
}

function PaymentRow({ payment }: { payment: PaymentRecord }) {
  const status = payment.status.toLowerCase();
  const done = status === "completed" || status === "succeeded" || status === "paid";
  const failed = status === "failed" || status === "cancelled";
  const Icon = done ? CheckCircle2 : failed ? XCircle : Clock3;
  const tint = done ? "#16A34A" : failed ? "#DC2626" : "#F59E0B";

  return (
    <article className="flex items-center gap-4 rounded-2xl border border-black/5 bg-white px-4 py-3.5 shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl" style={{ backgroundColor: `${tint}1f`, color: tint }}>
        <Icon size={20} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-black text-[#0F172A]">
          {payment.invoiceNumber ? `Invoice ${payment.invoiceNumber}` : "Payment"}
        </p>
        <p className="mt-0.5 text-xs font-semibold text-[#64748B]">
          {payment.createdAt ? payment.createdAt.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) : "—"}
          {payment.method ? ` · ${payment.method}` : ""}
        </p>
      </div>
      <div className="shrink-0 text-right">
        <p className="text-base font-black text-[#0F172A]">${payment.amount.toFixed(2)}</p>
        <p className="text-[10px] font-black uppercase tracking-wide" style={{ color: tint }}>
          {status || "pending"}
        </p>
      </div>
    </article>
  );
}

function normalizePayment(id: string, data: Record<string, unknown>): PaymentRecord {
  return {
    id,
    amount: numberValue(data.amount),
    status: stringValue(data.status) || "pending",
    method: stringValue(data.payment_method ?? data.paymentMethod),
    invoiceNumber: stringValue(data.invoice_number ?? data.invoiceNumber),
    createdAt: dateValue(data.created_at ?? data.createdAt ?? data.completed_at),
  };
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
