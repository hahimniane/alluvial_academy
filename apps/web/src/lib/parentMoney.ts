/**
 * Pure rules behind the parent money pages (inventory B): the invoices list,
 * invoice details, the pay page, payment history and the "decision history"
 * row. No Firebase imports, so each rule is unit-tested against the Dart:
 *
 *   lib/features/parent/screens/parent_invoices_screen.dart
 *   lib/features/parent/screens/invoice_detail_screen.dart
 *   lib/features/parent/widgets/beautiful_invoice_widget.dart
 *   lib/features/parent/screens/payment_screen.dart
 *   lib/features/parent/screens/payment_history_screen.dart
 *   lib/core/widgets/decision_history_card.dart
 */
import { invoiceFullyPaid, invoiceOverdue, type InvoiceStatus, type ParentInvoice, type ParentPayment } from "./parentHome.ts";

// ─── Invoices list (B-003…B-011) ───────────────────────────────────────────

export const INVOICE_LIST_LIMIT = 100;

/** The chip filters on the STORED status, as Flutter's query does (B-006, B-007). */
export type InvoiceChip = "all" | InvoiceStatus;
export const INVOICE_CHIPS: readonly InvoiceChip[] = ["all", "pending", "paid", "overdue", "cancelled"];

export function chipFromParam(value: string | null | undefined): InvoiceChip {
  const v = (value ?? "").trim().toLowerCase();
  return (INVOICE_CHIPS as readonly string[]).includes(v) ? (v as InvoiceChip) : "all";
}

/**
 * InvoiceService.getParentInvoices: the parent_id results (already filtered by
 * status in the query) and the student_id results, merged by id, filtered by
 * the chip again, latest due date first, first 100.
 */
export function mergeInvoiceList(byParent: ParentInvoice[], byStudent: ParentInvoice[], chip: InvoiceChip, limit = INVOICE_LIST_LIMIT) {
  const merged = new Map<string, ParentInvoice>();
  for (const invoice of [...byParent, ...byStudent]) {
    if (chip !== "all" && invoice.status !== chip) continue;
    merged.set(invoice.id, invoice);
  }
  return [...merged.values()].sort((a, b) => b.dueDate.getTime() - a.dueDate.getTime()).slice(0, limit);
}

/** The search box matches the invoice number only, case-insensitive (B-008). */
export function searchInvoices(list: ParentInvoice[], query: string) {
  const q = query.trim().toLowerCase();
  if (!q) return list;
  return list.filter((invoice) => invoice.invoiceNumber.toLowerCase().includes(q));
}

/** Student name on a list card: first + last, else the raw id (B-012). */
export function listStudentName(data: Record<string, unknown> | null, studentId: string) {
  if (!data) return studentId;
  const name = `${String(data.first_name ?? "").trim()} ${String(data.last_name ?? "").trim()}`.trim();
  return name || studentId;
}

/** InvoiceDataService name lookups: first + last, or null when missing/empty. */
export function personName(data: Record<string, unknown> | null) {
  if (!data) return null;
  const name = `${String(data.first_name ?? "").trim()} ${String(data.last_name ?? "").trim()}`.trim();
  return name || null;
}

// ─── Invoice details (B-029…B-044) ─────────────────────────────────────────

/** The pill under the buttons: OVERDUE when late, else the stored status in capitals. */
export function detailStatus(invoice: ParentInvoice, now: Date) {
  const overdue = invoiceOverdue(invoice, now);
  const label = overdue ? "OVERDUE" : invoice.status.toUpperCase();
  const color = overdue ? "#DC2626" : invoice.status === "paid" ? "#16A34A" : invoice.status === "cancelled" ? "#6B7280" : "#F59E0B";
  return { label, color };
}

/** The badge on the invoice sheet: red when late, else by stored status. */
export function sheetStatus(invoice: ParentInvoice, now: Date) {
  const overdue = invoiceOverdue(invoice, now);
  const label = overdue ? "OVERDUE" : invoice.status.toUpperCase();
  const byStatus: Record<InvoiceStatus, string> = { paid: "#059669", overdue: "#DC2626", cancelled: "#6B7280", pending: "#D97706" };
  return { label, color: overdue ? "#DC2626" : byStatus[invoice.status] };
}

/** "Amount Due" colour on the sheet: green settled, red late, blue otherwise. */
export function amountDueColor(invoice: ParentInvoice, now: Date) {
  if (invoiceFullyPaid(invoice)) return "#059669";
  return invoiceOverdue(invoice, now) ? "#DC2626" : "#1A56DB";
}

/** The "Pay Invoice" button: disabled when settled or cancelled; reads "Paid" when settled. */
export function detailPayButton(invoice: ParentInvoice) {
  const paid = invoiceFullyPaid(invoice);
  return { enabled: !paid && invoice.status !== "cancelled", paid };
}

/** Payments for one invoice, newest first (missing dates last). */
export function sortPaymentsNewestFirst(payments: ParentPayment[]) {
  return [...payments].sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0));
}

/** `Invoice_<number or id>.pdf` with every run of other characters replaced by `_`. */
export function invoicePdfFileName(invoice: Pick<ParentInvoice, "invoiceNumber" | "id">) {
  const base = invoice.invoiceNumber || invoice.id;
  return `Invoice_${base.replace(/[^\w-]+/g, "_")}.pdf`;
}

// ─── Decision history (B-042) ──────────────────────────────────────────────

export type DecisionActor = { uid: string; name: string; email: string; role: string };

/** `_decisionActorDisplayName`: system, a readable name, or "unknown". */
export function decisionActorName(actor: DecisionActor): { kind: "system" | "person" | "unknown"; name: string } {
  const technical = `${actor.uid} ${actor.email} ${actor.name}`.toLowerCase();
  const system =
    actor.uid.trim() === "" ||
    technical.includes("gserviceaccount.com") ||
    technical.includes("firebase-adminsdk") ||
    technical.includes("compute@developer");
  if (system) return { kind: "system", name: "" };
  const name = actor.name.trim();
  const phone = /^\+?[0-9][0-9 ()-]{6,}$/.test(name);
  const email = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(name);
  if (name && !phone && !email) return { kind: "person", name };
  return { kind: "unknown", name: "" };
}

/** The tooltip: email · role · uid, service accounts left out. */
export function decisionTechnicalDetails(actor: DecisionActor) {
  const parts = [
    actor.email.trim() && !actor.email.toLowerCase().includes("gserviceaccount.com") ? actor.email.trim() : "",
    actor.role.trim(),
    actor.uid.trim() && !actor.uid.toLowerCase().includes("gserviceaccount.com") ? actor.uid.trim() : "",
  ].filter(Boolean);
  return parts;
}

// ─── Pay page (B-058…B-072) ────────────────────────────────────────────────

/** The pay page badge: PAID by amount, else OVERDUE when late, else PENDING (never CANCELLED). */
export function payBadge(invoice: ParentInvoice, now: Date) {
  if (invoiceFullyPaid(invoice)) return { label: "PAID", color: "#059669" };
  if (invoiceOverdue(invoice, now)) return { label: "OVERDUE", color: "#DC2626" };
  return { label: "PENDING", color: "#D97706" };
}

export type PayFailure = "signIn" | "notYourInvoice" | "invoiceNotFound" | "invoiceCancelled" | "alreadyPaid" | "checkoutOpen" | "status" | "generic";

/** `_functionsErrorMessage`: the callable's error code → a plain message kind. */
export function payFailureFromError(error: unknown): PayFailure {
  const raw = error as { code?: unknown; message?: unknown } | null;
  const code = String(raw?.code ?? "").replace(/^functions\//, "");
  const message = String(raw?.message ?? "").toLowerCase();
  switch (code) {
    case "unauthenticated":
      return "signIn";
    case "permission-denied":
      return "notYourInvoice";
    case "not-found":
      return "invoiceNotFound";
    case "failed-precondition":
      if (message.includes("cancel")) return "invoiceCancelled";
      if (message.includes("already paid")) return "alreadyPaid";
      return "generic";
    default:
      return "generic";
  }
}

/**
 * `_payWithStripeCheckout` accepts the answer only when `success` is true and
 * it carries a payment id and an absolute checkout address with a host.
 */
export function checkoutAnswer(data: unknown): { paymentId: string; checkoutUrl: string } | null {
  const record = data && typeof data === "object" ? (data as Record<string, unknown>) : {};
  if (record.success !== true) return null;
  const paymentId = String(record.paymentId ?? "").trim();
  const checkoutUrl = String(record.checkoutUrl ?? "").trim();
  if (!paymentId) return null;
  try {
    const url = new URL(checkoutUrl);
    if (!url.protocol || !url.host) return null;
  } catch {
    return null;
  }
  return { paymentId, checkoutUrl };
}

/** The pay button: disabled when paid (by amount or by this payment), cancelled, or starting. */
export function payButtonState(invoice: ParentInvoice, payment: ParentPayment | null, starting: boolean) {
  const paid = invoiceFullyPaid(invoice) || payment?.status === "completed";
  return { paid, enabled: !paid && invoice.status !== "cancelled" && !starting };
}

/** Polling after a return from Stripe: every 2 s, at most 15 times (Flutter's phone flow). */
export const PAYMENT_POLL_MS = 2_000;
export const PAYMENT_POLL_TRIES = 15;
export const paymentIsFinal = (payment: ParentPayment | null) => payment?.status === "completed" || payment?.status === "failed";

/** "Nov 13, 2026 4:05 PM" (yMMMd + jm). */
export function formatDateTime(date: Date) {
  return `${date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })} ${date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}`;
}

/** The return page reads `result` from Stripe's redirect. */
export function returnResult(value: string | null | undefined): "success" | "cancel" {
  return value === "success" ? "success" : "cancel";
}

/** Payment history status colours (B-095); processing is blue. */
export const HISTORY_COLOR = { completed: "#16A34A", processing: "#2563EB", failed: "#DC2626", pending: "#F59E0B" } as const;
