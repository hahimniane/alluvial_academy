/**
 * Shared finance vocabulary: collection names, categories and the settings
 * document. Every finance page and callable uses these names; see
 * docs/finance/SPEC.md for what each collection holds.
 */

export const FIN = {
  settings: "finance_settings",
  months: "finance_months",
  expenses: "finance_expenses",
  recurringCosts: "finance_recurring_costs",
  recurringConfirmations: "finance_recurring_confirmations",
  staffPayouts: "staff_payouts",
  adminPayTerms: "admin_pay_terms",
  familyBilling: "family_billing",
  familyCredits: "family_credits",
  bankTransactions: "bank_transactions",
  knownPayers: "known_payers",
  paymentProofs: "payment_proofs",
  invoices: "invoices",
  payments: "payments",
  audits: "teacher_audits",
} as const;

export type ExpenseCategory = "teacher_pay" | "admin_pay" | "software" | "marketing" | "transfer_fees" | "other";

export const CATEGORY_LABEL: Record<ExpenseCategory, string> = {
  teacher_pay: "Teacher pay",
  admin_pay: "Administrator pay",
  software: "Software & subscriptions",
  marketing: "Marketing",
  transfer_fees: "Transfer fees",
  other: "Other",
};

export type RollupGroup = "Staff" | "Administration" | "Other";

export const CATEGORY_GROUP: Record<ExpenseCategory, RollupGroup> = {
  teacher_pay: "Staff",
  admin_pay: "Staff",
  software: "Administration",
  transfer_fees: "Administration",
  marketing: "Other",
  other: "Other",
};

/** Stored (entered) categories; teacher and administrator pay are computed. */
export const ENTERED_CATEGORIES: ExpenseCategory[] = ["software", "marketing", "transfer_fees", "other"];

/**
 * Old `finance_expenses.category` values written by the Flutter screen.
 * `null` means the row must not count toward totals (pay comes from audits
 * and Staff pay instead).
 */
export function normalizeLegacyCategory(raw: unknown): ExpenseCategory | null {
  switch (String(raw ?? "").trim()) {
    case "software":
      return "software";
    case "marketing":
    case "marketing_cost":
      return "marketing";
    case "transfer_fees":
      return "transfer_fees";
    case "teacher_payment":
    case "teacher_pay":
    case "leadership_cost":
    case "admin_pay":
      return null;
    default:
      return "other";
  }
}

export type FinanceSettings = {
  auto_billing_enabled: boolean;
  parent_messages_enabled: boolean;
  issue_day: number;
  due_day: number;
  first_invoice_due_days: number;
  reminder_days_before: number;
  plaid: { connected: boolean };
  whatsapp: { connected: boolean };
};

export const DEFAULT_SETTINGS: FinanceSettings = {
  auto_billing_enabled: false,
  parent_messages_enabled: false,
  issue_day: 25,
  due_day: 1,
  first_invoice_due_days: 3,
  reminder_days_before: 3,
  plaid: { connected: false },
  whatsapp: { connected: false },
};

export function money(n: number): string {
  const s = Math.abs(n).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return (n < -0.004 ? "−$" : "$") + s;
}

export function money0(n: number): string {
  const s = Math.round(Math.abs(n)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return (n < -0.5 ? "−$" : "$") + s;
}

export function r2(n: number): number {
  return Math.round(n * 100) / 100;
}
