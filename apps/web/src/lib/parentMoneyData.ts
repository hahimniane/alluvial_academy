"use client";

/**
 * Firestore reads and callables behind the parent money pages, query for query
 * as InvoiceService / PaymentService / InvoiceDataService make them (inventory
 * B). Every read is allowed by the invoices/payments rules only for the
 * invoice's parent_id / student_id / payer_id, so no extra scoping is needed.
 */
import { collection, doc, getDoc, limit, onSnapshot, orderBy, query, where, type QueryConstraint } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";
import { parseInvoice, parsePayment, type ParentInvoice, type ParentPayment } from "@/lib/parentHome";
import { INVOICE_LIST_LIMIT, checkoutAnswer, payFailureFromError, type DecisionActor, type InvoiceChip, type PayFailure } from "@/lib/parentMoney";

type Unsubscribe = () => void;

/**
 * B-003…B-005: parent_id (status filter in the query, due date desc, 100) +
 * student_id (no order, no limit; an error reads as empty). Emits once both
 * answered.
 */
export function watchInvoiceList(
  uid: string,
  chip: InvoiceChip,
  onData: (byParent: ParentInvoice[], byStudent: ParentInvoice[]) => void,
  onError: () => void,
): Unsubscribe {
  let byParent: ParentInvoice[] | null = null;
  let byStudent: ParentInvoice[] | null = null;
  const emit = () => {
    if (byParent && byStudent) onData(byParent, byStudent);
  };
  const clauses: QueryConstraint[] = [where("parent_id", "==", uid)];
  if (chip !== "all") clauses.push(where("status", "==", chip));
  clauses.push(orderBy("due_date", "desc"), limit(INVOICE_LIST_LIMIT));
  const stopParent = onSnapshot(
    query(collection(db, "invoices"), ...clauses),
    (snap) => {
      byParent = snap.docs.map((d) => parseInvoice(d.id, d.data()));
      emit();
    },
    () => onError(),
  );
  const stopStudent = onSnapshot(
    query(collection(db, "invoices"), where("student_id", "==", uid)),
    (snap) => {
      byStudent = snap.docs.map((d) => parseInvoice(d.id, d.data()));
      emit();
    },
    () => {
      byStudent = [];
      emit();
    },
  );
  return () => {
    stopParent();
    stopStudent();
  };
}

/** One invoice, live (`watchInvoice`). `null` = missing or refused. */
export function watchInvoice(invoiceId: string, onData: (invoice: ParentInvoice | null) => void, onError: () => void): Unsubscribe {
  return onSnapshot(
    doc(db, "invoices", invoiceId),
    (snap) => onData(snap.exists() ? parseInvoice(snap.id, snap.data()) : null),
    (error) => ((error as { code?: string }).code === "permission-denied" ? onData(null) : onError()),
  );
}

/** B-043: payments for one invoice where parent_id is the signed-in parent, live. */
export function watchInvoicePayments(invoiceId: string, uid: string, onData: (payments: ParentPayment[]) => void, onError: () => void): Unsubscribe {
  return onSnapshot(
    query(collection(db, "payments"), where("invoice_id", "==", invoiceId), where("parent_id", "==", uid)),
    (snap) => onData(snap.docs.map((d) => parsePayment(d.id, d.data()))),
    () => onError(),
  );
}

/** B-093: payment history, parent_id, newest first, 100, live. */
export function watchPaymentHistory(uid: string, onData: (payments: ParentPayment[]) => void, onError: () => void): Unsubscribe {
  return onSnapshot(
    query(collection(db, "payments"), where("parent_id", "==", uid), orderBy("created_at", "desc"), limit(100)),
    (snap) => onData(snap.docs.map((d) => parsePayment(d.id, d.data()))),
    () => onError(),
  );
}

/** One payment (`PaymentService.getPaymentStatus`). */
export async function fetchPayment(paymentId: string): Promise<ParentPayment | null> {
  const snap = await getDoc(doc(db, "payments", paymentId));
  return snap.exists() ? parsePayment(snap.id, snap.data()) : null;
}

/** `users/{uid}` data, or null when missing or unreadable. Cached for the page. */
const userCache = new Map<string, Promise<Record<string, unknown> | null>>();
export function fetchUserData(uid: string): Promise<Record<string, unknown> | null> {
  if (!uid) return Promise.resolve(null);
  let pending = userCache.get(uid);
  if (!pending) {
    pending = getDoc(doc(db, "users", uid))
      .then((snap) => (snap.exists() ? (snap.data() as Record<string, unknown>) : null))
      .catch(() => null);
    userCache.set(uid, pending);
  }
  return pending;
}

/** DecisionAuditService._resolveActor for the invoice's creator. */
export async function resolveCreator(invoice: ParentInvoice): Promise<DecisionActor> {
  let { createdByName: name, createdByEmail: email } = invoice;
  let role = "";
  if (invoice.createdByUid) {
    const data = await fetchUserData(invoice.createdByUid);
    if (data) {
      const stored = String(data.name ?? data.displayName ?? data.display_name ?? "").trim();
      const full = `${String(data.first_name ?? data.firstName ?? "").trim()} ${String(data.last_name ?? data.lastName ?? "").trim()}`.trim();
      name = name || stored || full;
      email = email || String(data["e-mail"] ?? data.email ?? "").trim();
      role = String(data.user_type ?? data.userType ?? data.role ?? "").trim();
    }
  }
  return { uid: invoice.createdByUid, name, email, role };
}

/**
 * B-063: `createPaymentSession` for the whole remaining balance. `returnTo:
 * 'parent'` asks the server to send Stripe back to /parent/pay/return/.
 */
export async function startCheckout(invoiceId: string): Promise<{ ok: true; paymentId: string; checkoutUrl: string } | { ok: false; failure: PayFailure }> {
  try {
    const result = await httpsCallable(functions, "createPaymentSession")({ invoiceId, returnTo: "parent" });
    const answer = checkoutAnswer(result.data);
    return answer ? { ok: true, ...answer } : { ok: false, failure: "generic" };
  } catch (error) {
    return { ok: false, failure: payFailureFromError(error) };
  }
}

/** A-056 / B-096: does the invoice behind a payment exist (and may the parent read it)? */
export async function invoiceReadable(invoiceId: string): Promise<"found" | "missing" | "refused"> {
  try {
    const snap = await getDoc(doc(db, "invoices", invoiceId));
    return snap.exists() ? "found" : "missing";
  } catch {
    return "refused";
  }
}
