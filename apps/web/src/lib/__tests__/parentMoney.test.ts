import assert from "node:assert/strict";
import { test } from "node:test";
import { invoicePdfBytes, invoicePdfContent, wrapText } from "../invoicePdf.ts";
import { parseInvoice, parsePayment } from "../parentHome.ts";
import {
  amountDueColor,
  checkoutAnswer,
  chipFromParam,
  decisionActorName,
  decisionTechnicalDetails,
  detailPayButton,
  detailStatus,
  formatDateTime,
  invoicePdfFileName,
  listStudentName,
  mergeInvoiceList,
  payBadge,
  payButtonState,
  payFailureFromError,
  paymentIsFinal,
  personName,
  returnResult,
  searchInvoices,
  sheetStatus,
  sortPaymentsNewestFirst,
} from "../parentMoney.ts";
import { PARENT_ROUTES, PARENT_WEB_SCREENS, activeParentItemId, isPushedParentPage } from "../parentWeb.ts";

const ts = (d: Date) => ({ toDate: () => d });
const NOW = new Date(2026, 10, 18, 10, 0, 0);
const daysAgo = (d: number) => new Date(NOW.getTime() - d * 86_400_000);
const inv = (id: string, data: Record<string, unknown>) => parseInvoice(id, { due_date: ts(daysAgo(-5)), total_amount: 100, ...data }, NOW);

// ─── List ───

test("the chip filters on the stored status, merges both owner fields, latest due first, 100 at most", () => {
  const byParent = [inv("a", { status: "pending", due_date: ts(daysAgo(1)) }), inv("b", { status: "paid", due_date: ts(daysAgo(9)) })];
  const byStudent = [inv("a", { status: "pending", due_date: ts(daysAgo(1)) }), inv("c", { status: "pending", due_date: ts(daysAgo(-3)) }), inv("d", { status: "overdue" })];
  assert.deepEqual(mergeInvoiceList(byParent, byStudent, "all").map((i) => i.id), ["d", "c", "a", "b"]);
  assert.deepEqual(mergeInvoiceList(byParent, byStudent, "pending").map((i) => i.id), ["c", "a"]);
  // A late unpaid invoice stored as pending stays under Pending, not Overdue (B-007).
  assert.deepEqual(mergeInvoiceList([inv("late", { status: "pending", due_date: ts(daysAgo(30)) })], [], "overdue"), []);
  const many = Array.from({ length: 130 }, (_, i) => inv(`x${i}`, { due_date: ts(daysAgo(i)) }));
  assert.equal(mergeInvoiceList(many, [], "all").length, 100);
});

test("chips from the URL, search by number only, list names fall back to the id", () => {
  assert.equal(chipFromParam("pending"), "pending");
  assert.equal(chipFromParam("PAID"), "paid");
  assert.equal(chipFromParam("bogus"), "all");
  assert.equal(chipFromParam(null), "all");
  const list = [inv("1", { invoice_number: "INV-2026-0142" }), inv("2", { invoice_number: "INV-2026-0007" })];
  assert.deepEqual(searchInvoices(list, " 0142 ").map((i) => i.id), ["1"]);
  assert.deepEqual(searchInvoices(list, "inv").map((i) => i.id), ["1", "2"]);
  assert.equal(listStudentName({ first_name: "Awa", last_name: " Bah " }, "s1"), "Awa Bah");
  assert.equal(listStudentName({ first_name: "" }, "s1"), "s1");
  assert.equal(listStudentName(null, "s1"), "s1");
  assert.equal(personName({ first_name: "", last_name: "" }), null);
});

// ─── Details ───

test("detail and sheet badges, Amount Due colour and the Pay Invoice button", () => {
  const late = inv("l", { status: "pending", due_date: ts(daysAgo(2)) });
  assert.deepEqual(detailStatus(late, NOW), { label: "OVERDUE", color: "#DC2626" });
  assert.deepEqual(sheetStatus(late, NOW), { label: "OVERDUE", color: "#DC2626" });
  assert.equal(amountDueColor(late, NOW), "#DC2626");
  const storedOverdueNotLate = inv("o", { status: "overdue" });
  assert.deepEqual(detailStatus(storedOverdueNotLate, NOW), { label: "OVERDUE", color: "#F59E0B" });
  assert.deepEqual(sheetStatus(storedOverdueNotLate, NOW), { label: "OVERDUE", color: "#DC2626" });
  const paid = inv("p", { status: "paid", paid_amount: 100 });
  assert.deepEqual(detailStatus(paid, NOW), { label: "PAID", color: "#16A34A" });
  assert.equal(amountDueColor(paid, NOW), "#059669");
  assert.deepEqual(detailPayButton(paid), { enabled: false, paid: true });
  assert.deepEqual(detailPayButton(inv("c", { status: "cancelled" })), { enabled: false, paid: false });
  assert.equal(amountDueColor(inv("n", {}), NOW), "#1A56DB");
});

test("payments newest first and the PDF file name", () => {
  const p = [parsePayment("a", { created_at: ts(daysAgo(3)) }), parsePayment("b", {}), parsePayment("c", { created_at: ts(daysAgo(1)) })];
  assert.deepEqual(sortPaymentsNewestFirst(p).map((x) => x.id), ["c", "a", "b"]);
  assert.equal(invoicePdfFileName({ invoiceNumber: "INV/2026 #4", id: "x" }), "Invoice_INV_2026_4.pdf");
  assert.equal(invoicePdfFileName({ invoiceNumber: "", id: "doc-1" }), "Invoice_doc-1.pdf");
});

test("decision history: system, readable name or unknown, and the technical details", () => {
  assert.equal(decisionActorName({ uid: "", name: "Fatou", email: "", role: "" }).kind, "system");
  assert.equal(decisionActorName({ uid: "u1", name: "x@firebase-adminsdk.iam", email: "", role: "" }).kind, "system");
  assert.deepEqual(decisionActorName({ uid: "u1", name: "Fatou Diallo", email: "f@x.org", role: "admin" }), { kind: "person", name: "Fatou Diallo" });
  assert.equal(decisionActorName({ uid: "u1", name: "+1 646 338 1286", email: "", role: "" }).kind, "unknown");
  assert.equal(decisionActorName({ uid: "u1", name: "f@x.org", email: "", role: "" }).kind, "unknown");
  assert.deepEqual(decisionTechnicalDetails({ uid: "u1", name: "", email: "f@x.org", role: "admin" }), ["f@x.org", "admin", "u1"]);
});

// ─── Pay ───

test("pay page badge never says CANCELLED; button disabled when paid, cancelled or starting", () => {
  assert.equal(payBadge(inv("c", { status: "cancelled", due_date: ts(daysAgo(3)) }), NOW).label, "PENDING", "isOverdue excludes cancelled");
  assert.equal(payBadge(inv("c2", { status: "cancelled" }), NOW).label, "PENDING");
  assert.equal(payBadge(inv("p", { paid_amount: 100 }), NOW).label, "PAID");
  assert.equal(payBadge(inv("z", { total_amount: 0 }), NOW).label, "PAID");
  const open = inv("o", {});
  assert.deepEqual(payButtonState(open, null, false), { paid: false, enabled: true });
  assert.deepEqual(payButtonState(open, null, true), { paid: false, enabled: false });
  assert.deepEqual(payButtonState(open, parsePayment("x", { status: "completed" }), false), { paid: true, enabled: false });
  assert.deepEqual(payButtonState(inv("c", { status: "cancelled" }), null, false), { paid: false, enabled: false });
});

test("server errors map to the same plain messages as Flutter", () => {
  assert.equal(payFailureFromError({ code: "functions/unauthenticated" }), "signIn");
  assert.equal(payFailureFromError({ code: "functions/permission-denied" }), "notYourInvoice");
  assert.equal(payFailureFromError({ code: "functions/not-found" }), "invoiceNotFound");
  assert.equal(payFailureFromError({ code: "functions/failed-precondition", message: "This invoice was cancelled." }), "invoiceCancelled");
  assert.equal(payFailureFromError({ code: "functions/failed-precondition", message: "Invoice is already paid" }), "alreadyPaid");
  assert.equal(payFailureFromError({ code: "functions/failed-precondition", message: "Stripe is configured but …" }), "generic");
  assert.equal(payFailureFromError({ code: "functions/internal", message: "Amount must be at least $0.50" }), "generic");
  assert.equal(payFailureFromError(new Error("network")), "generic");
});

test("the checkout answer needs success, a payment id and an absolute address", () => {
  assert.deepEqual(checkoutAnswer({ success: true, paymentId: "p1", checkoutUrl: "https://checkout.stripe.com/c/x" }), { paymentId: "p1", checkoutUrl: "https://checkout.stripe.com/c/x" });
  assert.equal(checkoutAnswer({ success: true, paymentId: "", checkoutUrl: "https://checkout.stripe.com" }), null);
  assert.equal(checkoutAnswer({ success: true, paymentId: "p1", checkoutUrl: "/relative" }), null);
  assert.equal(checkoutAnswer({ success: false, paymentId: "p1", checkoutUrl: "https://x" }), null);
  assert.equal(checkoutAnswer(null), null);
});

test("return page helpers", () => {
  assert.equal(returnResult("success"), "success");
  assert.equal(returnResult("cancel"), "cancel");
  assert.equal(returnResult(null), "cancel");
  assert.equal(paymentIsFinal(parsePayment("a", { status: "completed" })), true);
  assert.equal(paymentIsFinal(parsePayment("b", { status: "processing" })), false);
  assert.equal(paymentIsFinal(null), false);
  assert.equal(formatDateTime(new Date(2026, 10, 13, 16, 5)), "Nov 13, 2026 4:05 PM");
});

// ─── PDF ───

test("PDF rows follow Flutter: Payment Date = issue date, cut-off and period only when present", () => {
  const base = inv("i1", { invoice_number: "INV-1", issued_date: ts(new Date(2026, 10, 1)), due_date: ts(new Date(2026, 10, 15)), items: [{ description: "Quran — November", quantity: 2, unit_price: 30, total: 60 }], paid_amount: 10 });
  const content = invoicePdfContent({ invoice: base, parentName: "Aïcha Diallo", studentName: null });
  assert.match(content, /\(Payment Date\) Tj/);
  assert.match(content, /\(November 1, 2026\) Tj/);
  assert.match(content, /\(November 15, 2026\) Tj/);
  assert.doesNotMatch(content, /Access cutoff/);
  assert.doesNotMatch(content, /\(Billing period\) Tj/);
  assert.match(content, /\(From: Aïcha Diallo {2}\| {2}Student:\) Tj/);
  assert.match(content, /Billing period: November 2026/, "payer box falls back to the issue month");
  assert.match(content, /\(Quran - November\) Tj/);
  assert.match(content, /\(\$60\.00\) Tj/);
  assert.match(content, /\(Remaining Balance\) Tj/);
  assert.match(content, /\(\$90\.00\) Tj/);
  assert.match(content, /Received by: Muhammed Barry/);

  const withAll = inv("i2", { access_cutoff_date: ts(new Date(2026, 10, 20)), period: "2026-11" });
  const second = invoicePdfContent({ invoice: withAll, parentName: null, studentName: null });
  assert.match(second, /\(Access cutoff\) Tj/);
  assert.match(second, /\(November 2026\) Tj/);
  assert.doesNotMatch(second, /From:/, "no payer box when neither name was found");
  assert.match(second, /No items on this invoice/);
});

test("the PDF file is well formed and keeps accented letters as single bytes", () => {
  const bytes = invoicePdfBytes({ invoice: inv("i", { invoice_number: "N" }), parentName: "Aïcha", studentName: "Ibrahima" });
  const text = String.fromCharCode(...bytes);
  assert.ok(text.startsWith("%PDF-1.4\n"));
  assert.ok(text.trimEnd().endsWith("%%EOF"));
  assert.match(text, /\/Encoding \/WinAnsiEncoding/);
  assert.ok(bytes.includes(0xef), "ï written as one Latin-1 byte");
  const xref = Number(/startxref\n(\d+)/.exec(text)?.[1]);
  assert.equal(text.slice(xref, xref + 4), "xref");
  for (const match of text.matchAll(/(\d{10}) 00000 n/g)) {
    const offset = Number(match[1]);
    assert.match(text.slice(offset, offset + 12), /^\d+ 0 obj/);
  }
  assert.deepEqual(wrapText("aaaa bbbb cccc", 9), ["aaaa bbbb", "cccc"]);
});

// ─── Routes ───

test("money pages: invoices and payments in the shell, detail and pay pushed over it", () => {
  assert.equal(PARENT_WEB_SCREENS.has("invoices"), true);
  assert.equal(PARENT_WEB_SCREENS.has("payments"), true);
  assert.equal(isPushedParentPage("/parent/invoices/"), false);
  assert.equal(isPushedParentPage("/parent/invoices/detail/"), true);
  assert.equal(isPushedParentPage("/parent/pay/"), true);
  assert.equal(isPushedParentPage("/parent/pay/return/"), true);
  assert.equal(activeParentItemId("/parent/invoices/"), "invoices");
  assert.equal(activeParentItemId("/parent/payments/"), "payments");
  assert.equal(PARENT_ROUTES.pay("a/b"), "/parent/pay/?invoiceId=a%2Fb");
});
