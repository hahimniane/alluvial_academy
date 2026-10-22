/**
 * The close-month checklist, worked out from the month summary.
 */

import { monthName } from "./months.ts";
import type { MonthSummary } from "./summary.ts";

export type CloseCheck = {
  id: "ended" | "audits" | "recurring" | "paid" | "adjust";
  ok: boolean;
  text: string;
  /** Where to fix it; null when nothing can be done there. */
  href: string | null;
};

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;

/** Last day of a yyyy-MM month as a day number (28-31). */
export function lastDay(month: string): number {
  const [y, m] = month.split("-").map(Number);
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

export function closeChecklist(summary: MonthSummary, ended: boolean): CloseCheck[] {
  const name = monthName(summary.month);
  const people = summary.unpaid_teachers + summary.unpaid_admins;
  const staffHref = `/admin/finance/staff/?month=${summary.month}`;
  const estimate = people === 0 && !summary.final && summary.status !== "closed";
  const mismatched = summary.admin_payout_mismatches ?? 0;
  const checks: CloseCheck[] = [
    {
      id: "ended",
      ok: ended,
      text: ended ? `${name} has ended` : `${name} ends on ${name} ${lastDay(summary.month)}`,
      href: null,
    },
    {
      id: "audits",
      ok: summary.teacher_pay_final,
      text: summary.teacher_pay_final ? "All teacher audits approved" : "Teacher audits are still in progress",
      href: summary.teacher_pay_final ? null : `/admin/finance/staff/?month=${summary.month}`,
    },
    {
      id: "recurring",
      ok: summary.recurring_pending === 0,
      text:
        summary.recurring_pending === 0
          ? "All recurring costs confirmed"
          : `${plural(summary.recurring_pending, "recurring cost", "recurring costs")} still to confirm`,
      href: summary.recurring_pending === 0 ? null : `/admin/finance/expenses/?month=${summary.month}`,
    },
    {
      id: "paid",
      ok: people === 0 && !estimate,
      // Nothing final to pay yet is not "everyone is paid": the pay is still an estimate.
      text: people > 0 ? `${people} staff still to pay` : estimate ? "Pay is still an estimate" : "Everyone is paid",
      href: people === 0 && !estimate ? null : staffHref,
    },
  ];
  if (mismatched > 0) {
    checks.push({
      id: "adjust",
      ok: false,
      text: `Adjust ${plural(mismatched, "administrator payment", "administrator payments")}`,
      href: staffHref,
    });
  }
  return checks;
}

export function canClose(checks: CloseCheck[]): boolean {
  return checks.every((c) => c.ok);
}
