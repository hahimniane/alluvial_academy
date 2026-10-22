"use client";

/**
 * Firestore reads and callables for the finance Invoices and New students
 * screens. Reads are bounded: one month by billing month / period, or the last
 * six months by issued date with a limit; names come in `in` chunks of 30; the
 * teacher of each student is one limited query per student, cached for the
 * session. All writes go through callables.
 */

import { collection, documentId, doc, getDoc, getDocs, limit, orderBy, query, Timestamp, where, type DocumentData, type QueryDocumentSnapshot } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";
import { DEFAULT_SETTINGS, FIN, type FinanceSettings } from "@/lib/finance/model";
import { normalizeInvoice, toDate, type EnrollmentLite, type Invoice, type PaymentLite } from "@/lib/finance/invoices";

export const MONTH_QUERY_LIMIT = 500;
export const RECENT_QUERY_LIMIT = 600;
export const RECENT_MONTHS = 6;

const str = (v: unknown): string => (v === null || v === undefined ? "" : String(v).trim());

function chunk<T>(items: readonly T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

const toInvoice = (d: QueryDocumentSnapshot<DocumentData>) => normalizeInvoice(d.id, d.data());

/** Invoices billed for one month (billing_month, or the legacy period). */
export async function loadInvoicesForMonth(month: string): Promise<{ invoices: Invoice[]; truncated: boolean }> {
  const col = collection(db, FIN.invoices);
  const [byBilling, byPeriod] = await Promise.all([
    getDocs(query(col, where("billing_month", "==", month), limit(MONTH_QUERY_LIMIT))),
    getDocs(query(col, where("period", ">=", month), where("period", "<=", `${month}`), limit(MONTH_QUERY_LIMIT))),
  ]);
  const byId = new Map<string, Invoice>();
  for (const d of [...byBilling.docs, ...byPeriod.docs]) byId.set(d.id, toInvoice(d));
  const invoices = [...byId.values()].filter((i) => i.billingMonth === month);
  return { invoices, truncated: byBilling.size >= MONTH_QUERY_LIMIT || byPeriod.size >= MONTH_QUERY_LIMIT };
}

/** The last six months of invoices by issue date (the "all months" view). */
export async function loadRecentInvoices(now: Date = new Date()): Promise<{ invoices: Invoice[]; truncated: boolean }> {
  const since = new Date(now);
  since.setMonth(since.getMonth() - RECENT_MONTHS);
  const snap = await getDocs(query(collection(db, FIN.invoices), where("issued_date", ">=", Timestamp.fromDate(since)), orderBy("issued_date", "desc"), limit(RECENT_QUERY_LIMIT)));
  return { invoices: snap.docs.map(toInvoice), truncated: snap.size >= RECENT_QUERY_LIMIT };
}

export async function loadInvoiceById(id: string): Promise<Invoice | null> {
  const snap = await getDoc(doc(db, FIN.invoices, id));
  return snap.exists() ? normalizeInvoice(snap.id, snap.data()) : null;
}

/** Every invoice of one family (small), for the duplicate check. */
export async function loadFamilyInvoices(parentId: string): Promise<Invoice[]> {
  const snap = await getDocs(query(collection(db, FIN.invoices), where("parent_id", "==", parentId), limit(300)));
  return snap.docs.map(toInvoice);
}

export function displayName(data: DocumentData): string {
  const first = str(data.first_name ?? data.firstName);
  const last = str(data.last_name ?? data.lastName);
  const full = [first, last].filter(Boolean).join(" ");
  if (full) return full;
  const email = str(data["e-mail"] ?? data.email);
  return email ? email.split("@")[0] : "";
}

/** id -> display name, in `in` chunks of 30 (never one read per row). */
export async function loadNames(ids: readonly string[], into: Map<string, string> = new Map()): Promise<Map<string, string>> {
  const missing = [...new Set(ids.filter(Boolean))].filter((id) => !into.has(id));
  await Promise.all(
    chunk(missing, 30).map(async (part) => {
      const snap = await getDocs(query(collection(db, "users"), where(documentId(), "in", part)));
      for (const d of snap.docs) into.set(d.id, displayName(d.data()));
    }),
  );
  return into;
}

/** Parents who have an open family credit (for the "Family has credit" filter). */
export async function loadOpenCreditParents(): Promise<Set<string>> {
  const snap = await getDocs(query(collection(db, FIN.familyCredits), where("status", "==", "open"), limit(500)));
  return new Set(snap.docs.map((d) => str(d.data().parent_id)).filter(Boolean));
}

export type FinanceSettingsView = FinanceSettings & { zelle_address: string };

export async function loadFinanceSettings(): Promise<FinanceSettingsView> {
  try {
    const snap = await getDoc(doc(db, FIN.settings, "main"));
    const data = snap.exists() ? snap.data() : {};
    return {
      ...DEFAULT_SETTINGS,
      ...(data as Partial<FinanceSettings>),
      parent_messages_enabled: data.parent_messages_enabled === true,
      zelle_address: str(data.zelle_address),
    };
  } catch {
    return { ...DEFAULT_SETTINGS, zelle_address: "" };
  }
}

export async function loadMonthClosed(month: string | null): Promise<boolean> {
  if (!month) return false;
  try {
    const snap = await getDoc(doc(db, FIN.months, month));
    return snap.exists() && snap.data().status === "closed";
  } catch {
    return false;
  }
}

/** Completed payments on one invoice, oldest first. */
export async function loadInvoicePayments(invoiceId: string): Promise<PaymentLite[]> {
  const snap = await getDocs(query(collection(db, FIN.payments), where("invoice_id", "==", invoiceId), limit(100)));
  const out: PaymentLite[] = [];
  for (const d of snap.docs) {
    const p = d.data();
    const applied = Number(p.applied_amount);
    const completed = str(p.status).toLowerCase() === "completed";
    if (!completed && !(Number.isFinite(applied) && applied > 0)) continue;
    const amount = Number.isFinite(applied) && applied > 0 ? applied : Number(p.amount) || 0;
    out.push({ amount, at: toDate(p.received_at ?? p.completed_at ?? p.created_at), method: methodLabel(str(p.payment_method)) });
  }
  return out.sort((a, b) => (a.at?.getTime() ?? 0) - (b.at?.getTime() ?? 0));
}

function methodLabel(method: string): string {
  switch (method.toLowerCase()) {
    case "stripe":
      return "card";
    case "bank_transfer":
      return "bank transfer";
    case "cash_app":
      return "Cash App";
    case "western_union":
      return "Western Union";
    case "moneygram":
      return "MoneyGram";
    case "zelle":
      return "Zelle";
    case "":
      return "";
    default:
      return method.replace(/_/g, " ");
  }
}

export type FamilyBilling = {
  monthlyAmount: number;
  setOnInvoiceId: string;
  setAt: Date | null;
  history: { fromMonth: string; oldAmount: number | null; newAmount: number; reason: string; at: Date | null }[];
};

export async function loadFamilyBilling(parentId: string): Promise<FamilyBilling | null> {
  if (!parentId) return null;
  const snap = await getDoc(doc(db, FIN.familyBilling, parentId));
  if (!snap.exists()) return null;
  const d = snap.data();
  const history = (Array.isArray(d.history) ? d.history : []).map((h: Record<string, unknown>) => ({
    fromMonth: str(h.from_month),
    oldAmount: h.old === null || h.old === undefined ? null : Number(h.old),
    newAmount: Number(h.new) || 0,
    reason: str(h.reason),
    at: toDate(h.at as never),
  }));
  return { monthlyAmount: Number(d.monthly_amount) || 0, setOnInvoiceId: str(d.set_on_invoice_id), setAt: toDate(d.set_at), history };
}

/** monthly_amount of many families at once (New students screen). */
export async function loadMonthlyAmounts(parentIds: readonly string[]): Promise<Map<string, number>> {
  const out = new Map<string, number>();
  await Promise.all(
    chunk([...new Set(parentIds.filter(Boolean))], 30).map(async (part) => {
      const snap = await getDocs(query(collection(db, FIN.familyBilling), where(documentId(), "in", part)));
      for (const d of snap.docs) out.set(d.id, Number(d.data().monthly_amount) || 0);
    }),
  );
  return out;
}

/* ---------------------------------------------------------------- teachers -- */

const teacherCache = new Map<string, { id: string; name: string } | null>();
const TEACHER_WINDOW_DAYS = 45;
const MAX_TEACHER_LOOKUPS = 400;

/**
 * Who teaches each student: the earliest class from 45 days ago on (uses the
 * existing student_ids + shift_start index). One limited query per student,
 * eight at a time, cached for the session. `onProgress` fires after each batch
 * so the Teacher filter fills in while the list is already usable.
 */
export async function loadTeachersForStudents(
  studentIds: readonly string[],
  onProgress?: (byStudent: Map<string, string[]>, teacherNames: Map<string, string>) => void,
): Promise<{ byStudent: Map<string, string[]>; teacherNames: Map<string, string> }> {
  const ids = [...new Set(studentIds.filter(Boolean))].slice(0, MAX_TEACHER_LOOKUPS);
  const since = Timestamp.fromDate(new Date(Date.now() - TEACHER_WINDOW_DAYS * 24 * 60 * 60 * 1000));
  const snapshot = () => {
    const byStudent = new Map<string, string[]>();
    const teacherNames = new Map<string, string>();
    for (const id of ids) {
      const t = teacherCache.get(id);
      if (!t) continue;
      byStudent.set(id, [t.id]);
      teacherNames.set(t.id, t.name);
    }
    return { byStudent, teacherNames };
  };
  const todo = ids.filter((id) => !teacherCache.has(id));
  for (const part of chunk(todo, 8)) {
    await Promise.all(
      part.map(async (studentId) => {
        try {
          const snap = await getDocs(query(collection(db, "teaching_shifts"), where("student_ids", "array-contains", studentId), where("shift_start", ">=", since), orderBy("shift_start", "asc"), limit(1)));
          const d = snap.docs[0]?.data();
          const teacherId = str(d?.teacher_id ?? d?.teacherId);
          teacherCache.set(studentId, teacherId ? { id: teacherId, name: str(d?.teacher_name) || "Teacher" } : null);
        } catch {
          teacherCache.set(studentId, null);
        }
      }),
    );
    const progress = snapshot();
    onProgress?.(progress.byStudent, progress.teacherNames);
  }
  return snapshot();
}

/* ------------------------------------------------------------ pickers (new) -- */

export type Billable = { id: string; name: string; email: string; userType: "parent" | "student"; childrenIds: string[] };

export async function loadBillableUsers(): Promise<Billable[]> {
  const [parents, adults] = await Promise.all([
    getDocs(query(collection(db, "users"), where("user_type", "==", "parent"), limit(500))),
    getDocs(query(collection(db, "users"), where("user_type", "==", "student"), where("is_adult_student", "==", true), limit(500))),
  ]);
  const out: Billable[] = [];
  for (const d of [...parents.docs, ...adults.docs]) {
    const data = d.data();
    out.push({
      id: d.id,
      name: displayName(data) || d.id,
      email: str(data["e-mail"] ?? data.email),
      userType: str(data.user_type) === "student" ? "student" : "parent",
      childrenIds: (Array.isArray(data.children_ids) ? data.children_ids : Array.isArray(data.childrenIds) ? data.childrenIds : []).map(str).filter(Boolean),
    });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

export type Child = { id: string; name: string };

export async function loadChildren(user: Billable): Promise<Child[]> {
  if (user.userType === "student") return [{ id: user.id, name: user.name }];
  const names = await loadNames(user.childrenIds);
  return user.childrenIds.filter((id) => names.has(id)).map((id) => ({ id, name: names.get(id) || id }));
}

/* ------------------------------------------------------------ new students -- */

export async function loadFirstInvoices(): Promise<Invoice[]> {
  const snap = await getDocs(query(collection(db, FIN.invoices), where("kind", "==", "first_month"), orderBy("issued_date", "desc"), limit(60)));
  return snap.docs.map(toInvoice);
}

/** Matched enrollments of the last 60 days that already have a student account. */
export async function loadRecentEnrollments(now: Date = new Date()): Promise<EnrollmentLite[]> {
  const since = Timestamp.fromDate(new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000));
  const snap = await getDocs(query(collection(db, "enrollments"), where("metadata.matchedAt", ">=", since), orderBy("metadata.matchedAt", "desc"), limit(200)));
  const out: EnrollmentLite[] = [];
  for (const d of snap.docs) {
    const data = d.data();
    const meta = (data.metadata ?? {}) as Record<string, unknown>;
    if (str(meta.status) !== "matched") continue;
    const studentId = str(meta.studentUserId);
    if (!studentId) continue;
    const student = (data.student ?? {}) as Record<string, unknown>;
    out.push({
      id: d.id,
      studentId,
      parentId: str(meta.parentUserId),
      studentName: str(data.studentName) || str(student.name),
      teacherName: str(meta.matchedTeacherName),
      matchedAt: toDate(meta.matchedAt as never),
    });
  }
  return out;
}

/** Guardian of each student, for enrollments that carry no parent id yet. */
export async function loadGuardians(studentIds: readonly string[]): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  await Promise.all(
    chunk([...new Set(studentIds.filter(Boolean))], 30).map(async (part) => {
      const snap = await getDocs(query(collection(db, "users"), where(documentId(), "in", part)));
      for (const d of snap.docs) {
        const g = d.data().guardian_ids;
        const first = Array.isArray(g) ? str(g[0]) : "";
        if (first) out.set(d.id, first);
      }
    }),
  );
  return out;
}

/* ---------------------------------------------------------------- callables -- */

async function call<T>(name: string, data: Record<string, unknown>): Promise<T> {
  const result = await httpsCallable(functions, name)(data);
  return result.data as T;
}

export const callEditInvoice = (data: Record<string, unknown>) => call<{ invoice: Record<string, unknown>; credit_id?: string }>("editInvoice", data);
export const callCancelInvoice = (data: { invoice_id: string; reason: string }) => call<{ ok: boolean }>("cancelInvoice", data);
export const callSendReminder = (data: { invoice_id: string }) => call<{ ok: boolean; sent: boolean }>("sendInvoiceReminder", data);
export const callRecordPayment = (data: { invoiceId: string; amount: number; paymentMethod: string }) => call<{ success: boolean }>("recordManualPayment", data);
export const callExtendAccess = (data: { parentId: string; scope: "parent"; extendTo: string }) => call<{ success: boolean; updatedInvoices: number }>("extendStudentAccessCutoff", data);
export const callSetMonthlyAmount = (data: { parent_id: string; monthly_amount: number; reason: string }) => call<{ ok: boolean }>("setFamilyMonthlyAmount", data);
export const callCreateFirstInvoice = (data: { parent_id: string; student_id: string; monthly_amount: number; classes_in_month: number; classes_left: number; first_class_date: string }) =>
  call<{ invoice_id: string }>("createFirstInvoice", data);
export const callCreateInvoice = (data: Record<string, unknown>) => call<{ success: boolean; invoiceId: string; invoiceNumber: string }>("createInvoice", data);

export function errorMessage(error: unknown, fallback = "Something went wrong. Try again."): string {
  if (error && typeof error === "object" && "message" in error) {
    const message = String((error as { message?: unknown }).message ?? "").trim();
    if (message && message !== "internal") return message.replace(/^functions\//, "");
  }
  return fallback;
}
