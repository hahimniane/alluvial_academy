import test from "node:test";
import assert from "node:assert/strict";
import { buildRow, filterAndSort, DEFAULT_FILTERS, normalizeInvoice } from "../finance/invoices.ts";
import { INVOICE_EXPORT_HEADERS, invoiceExportFileName, invoiceExportRows } from "../finance/invoiceExport.ts";

const NOW = new Date("2026-11-20T15:00:00Z");
const names = new Map([
  ["p1", "Aissatou Bah"],
  ["s1", "Mariama Bah"],
  ["s2", "Ibrahima Bah"],
  ["p2", "Omar Sow"],
  ["s3", "Fatou Sow"],
]);
const phones = new Map([["p1", "+19737037497"]]);

const make = (id: string, data: Record<string, unknown>) =>
  buildRow(normalizeInvoice(id, data), { now: NOW, names, phones, teachersByStudent: new Map(), creditParents: new Set() });

const overdue = make("a", {
  invoice_number: "INV-2026-501",
  parent_id: "p1",
  student_ids: ["s1", "s2"],
  kind: "monthly",
  billing_month: "2026-11",
  issued_date: new Date("2026-10-25T16:00:00Z"),
  due_date: new Date("2026-11-05T00:00:00Z"),
  total_amount: 136,
  paid_amount: 36,
  status: "partial",
});
const paid = make("b", {
  invoice_number: "INV-2026-502",
  parent_id: "p2",
  student_ids: ["s3"],
  kind: "first_month",
  billing_month: "2026-11",
  issued_date: new Date("2026-11-10T16:00:00Z"),
  due_date: new Date("2026-11-17T00:00:00Z"),
  total_amount: 40,
  paid_amount: 40,
  status: "paid",
});

test("one row per invoice with every header filled in order", () => {
  const out = invoiceExportRows([overdue, paid]);
  assert.equal(out.length, 2);
  assert.equal(out[0].length, INVOICE_EXPORT_HEADERS.length);
  assert.deepEqual(out[0], [
    "INV-2026-501",
    "Aissatou Bah",
    "+19737037497",
    "Mariama Bah, Ibrahima Bah",
    "Monthly",
    "2026-11",
    "2026-10-25",
    "2026-11-05",
    136,
    36,
    100,
    "Partly paid, overdue",
    15,
  ]);
  assert.deepEqual(out[1], ["INV-2026-502", "Omar Sow", "", "Fatou Sow", "First month", "2026-11", "2026-11-10", "2026-11-17", 40, 40, 0, "Paid", 0]);
});

test("money stays numeric so Excel can sum and sort it", () => {
  const [row] = invoiceExportRows([overdue]);
  for (const index of [8, 9, 10, 12]) assert.equal(typeof row[index], "number");
});

test("cancelled invoices export with no balance", () => {
  const cancelled = make("c", { invoice_number: "INV-9", parent_id: "p2", total_amount: 50, paid_amount: 0, status: "cancelled", billing_month: "2026-10" });
  const [row] = invoiceExportRows([cancelled]);
  assert.equal(row[10], 0);
  assert.equal(row[11], "Cancelled");
});

test("exports follow the screen's filter and sort", () => {
  const view = filterAndSort([overdue, paid], { ...DEFAULT_FILTERS, month: "2026-11", status: "paid" });
  const out = invoiceExportRows(view.rows);
  assert.deepEqual(out.map((r) => r[0]), ["INV-2026-502"]);
});

test("file name says the month and status filter", () => {
  assert.equal(invoiceExportFileName("2026-11", "all"), "invoices-2026-11.xlsx");
  assert.equal(invoiceExportFileName("2026-11", "overdue"), "invoices-2026-11-overdue.xlsx");
  assert.equal(invoiceExportFileName("all", "all"), "invoices-recent.xlsx");
});
