/**
 * The month summary returned by the `getFinanceMonthSummary` callable
 * (docs/finance/SPEC.md). Types only; the network call is in summaryClient.ts.
 */

export type TeacherLine = {
  uid: string;
  name: string;
  hours: number;
  gross: number;
  penalties: number;
  net: number;
  final: boolean;
};

/** Leader pay from the leader audit: pay for the month + bonus − pay cut. */
export type LeaderLine = {
  uid: string;
  name: string;
  base: number;
  bonus: number;
  paycut: number;
  net: number;
  final: boolean;
};

export type AdminLine = {
  uid: string;
  name: string;
  role_title: string;
  fixed: number;
  pct: number;
  share: number;
  total: number;
  paused: { reason: string; auto: boolean } | null;
};

export type MonthSummary = {
  month: string;
  status: "open" | "closed";
  final: boolean;
  billed: number;
  collected: number;
  owed: number;
  discounts: number;
  credit_open: number;
  penalties: number;
  teacher_pay: number;
  teacher_pay_final: boolean;
  leader_pay?: number;
  leader_pay_final?: boolean;
  admin_pay: number;
  admin_base: number;
  software: number;
  marketing: number;
  transfer_fees: number;
  other: number;
  expenses: number;
  profit: number;
  invoice_count: number;
  families_owing: number;
  recurring_pending: number;
  recurring_due: number;
  unpaid_teachers: number;
  unpaid_admins: number;
  unpaid_leaders?: number;
  /** Administrator payouts that differ from what is due by more than a cent (0 until pay is final). */
  admin_payout_mismatches?: number;
  overdue_invoices: number;
  first_invoices_this_week: number;
  teachers: TeacherLine[];
  leaders?: LeaderLine[];
  admins: AdminLine[];
};

/** One entry of `finance_months/{month}.log`. */
export type MonthLogEntry = {
  action: "closed" | "reopened";
  at: Date | null;
  by: string;
  by_name: string;
  reason: string;
};
