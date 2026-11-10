/**
 * The Excel export of the Invoices list: one row per invoice, in the order and
 * with the filters the screen shows. Dates are yyyy-MM-dd and the month is
 * yyyy-MM so Excel sorts them as text in calendar order; money stays numeric.
 */

import { dayKeyNY, type InvoiceKind, type InvoiceRow, type StatusKind } from "./invoices.ts";

export const INVOICE_EXPORT_HEADERS = [
  "Invoice number",
  "Family",
  "Parent phone",
  "Students",
  "Type",
  "Month",
  "Issue date",
  "Due date",
  "Amount",
  "Paid",
  "Balance",
  "Status",
  "Days overdue",
];

const KIND_LABEL: Record<InvoiceKind, string> = {
  first_month: "First month",
  monthly: "Monthly",
  one_off: "One-off",
  "": "",
};

const STATUS_LABEL: Record<StatusKind, string> = {
  paid: "Paid",
  partly: "Partly paid",
  overdue: "Overdue",
  unpaid: "Unpaid",
  cancelled: "Cancelled",
};

export function invoiceExportRows(rows: readonly InvoiceRow[]): (string | number)[][] {
  return rows.map((r) => {
    const inv = r.inv;
    const status = r.state.kind === "partly" && r.state.late ? "Partly paid, overdue" : STATUS_LABEL[r.state.kind];
    return [
      inv.number,
      r.familyName,
      r.parentPhone,
      r.studentNames.join(", "),
      KIND_LABEL[inv.kind] ?? "",
      inv.billingMonth ?? "",
      inv.issuedAt ? dayKeyNY(inv.issuedAt) : "",
      inv.dueKey ?? "",
      inv.total,
      r.state.paid,
      r.state.owed,
      status,
      r.state.days,
    ];
  });
}

/** "invoices-2026-11.xlsx", or "invoices-recent.xlsx" for the all-months view. */
export function invoiceExportFileName(month: string | "all", status: string): string {
  const scope = month === "all" ? "recent" : month;
  const suffix = status && status !== "all" ? `-${status}` : "";
  return `invoices-${scope}${suffix}.xlsx`;
}
