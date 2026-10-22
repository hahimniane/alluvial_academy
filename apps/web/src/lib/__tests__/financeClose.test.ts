import test from "node:test";
import assert from "node:assert/strict";
import { canClose, closeChecklist, lastDay } from "../finance/closeChecks.ts";
import { financeHref } from "../finance/links.ts";
import { isFinanceMonth, monthFromParam } from "../finance/months.ts";
import { NUMERIC_SETTINGS, ordinal, parseNumericSetting } from "../finance/settings.ts";
import type { MonthSummary } from "../finance/summary.ts";

function summary(over: Partial<MonthSummary> = {}): MonthSummary {
  return {
    month: "2026-09", status: "open", final: true, billed: 0, collected: 0, owed: 0, discounts: 0, credit_open: 0,
    penalties: 0, teacher_pay: 0, teacher_pay_final: true, admin_pay: 0, admin_base: 0, software: 0, marketing: 0,
    transfer_fees: 0, other: 0, expenses: 0, profit: 0, invoice_count: 0, families_owing: 0, recurring_pending: 0,
    recurring_due: 0, unpaid_teachers: 0, unpaid_admins: 0, overdue_invoices: 0, first_invoices_this_week: 0,
    teachers: [], admins: [], ...over,
  };
}

test("last day of a month, leap years included", () => {
  assert.equal(lastDay("2026-10"), 31);
  assert.equal(lastDay("2026-09"), 30);
  assert.equal(lastDay("2026-02"), 28);
  assert.equal(lastDay("2028-02"), 29);
});

test("everything done: all four checks pass and the month can be closed", () => {
  const checks = closeChecklist(summary(), true);
  assert.deepEqual(checks.map((c) => c.id), ["ended", "audits", "recurring", "paid"]);
  assert.ok(checks.every((c) => c.ok && c.href === null));
  assert.equal(canClose(checks), true);
  assert.deepEqual(checks.map((c) => c.text), [
    "September has ended", "All teacher audits approved", "All recurring costs confirmed", "Everyone is paid",
  ]);
});

test("what is left is named, with the page that fixes it", () => {
  const checks = closeChecklist(summary({ teacher_pay_final: false, recurring_pending: 2, unpaid_teachers: 2, unpaid_admins: 1 }), true);
  assert.equal(canClose(checks), false);
  assert.deepEqual(checks.filter((c) => !c.ok).map((c) => [c.text, c.href]), [
    ["Teacher audits are still in progress", "/admin/finance/staff/?month=2026-09"],
    ["2 recurring costs still to confirm", "/admin/finance/expenses/?month=2026-09"],
    ["3 staff still to pay", "/admin/finance/staff/?month=2026-09"],
  ]);
});

test("nothing final to pay is not 'everyone is paid'", () => {
  const unfinished = closeChecklist(summary({ final: false, teacher_pay_final: false }), true);
  const paid = unfinished.find((c) => c.id === "paid")!;
  assert.equal(paid.text, "Pay is still an estimate");
  assert.equal(paid.ok, false);
  assert.equal(paid.href, "/admin/finance/staff/?month=2026-09");
  assert.equal(canClose(unfinished), false);
  // A closed month shows its stored figures: it was final when closed.
  assert.equal(closeChecklist(summary({ final: true, status: "closed" }), true).find((c) => c.id === "paid")!.text, "Everyone is paid");
  // People still to pay take precedence over the estimate wording.
  assert.equal(closeChecklist(summary({ final: false, unpaid_teachers: 1 }), true).find((c) => c.id === "paid")!.text, "1 staff still to pay");
});

test("an administrator paid a different amount than is due must be adjusted before closing", () => {
  const checks = closeChecklist(summary({ admin_payout_mismatches: 2 }), true);
  const adjust = checks.find((c) => c.id === "adjust")!;
  assert.equal(adjust.text, "Adjust 2 administrator payments");
  assert.equal(adjust.ok, false);
  assert.equal(adjust.href, "/admin/finance/staff/?month=2026-09");
  assert.equal(canClose(checks), false);
  assert.equal(closeChecklist(summary({ admin_payout_mismatches: 1 }), true).find((c) => c.id === "adjust")!.text, "Adjust 1 administrator payment");
  assert.equal(closeChecklist(summary(), true).some((c) => c.id === "adjust"), false);
});

test("a month that has not ended says when it does and cannot be closed", () => {
  const checks = closeChecklist(summary({ month: "2026-10" }), false);
  assert.equal(checks[0].ok, false);
  assert.equal(checks[0].text, "October ends on October 31");
  assert.equal(canClose(checks), false);
});

test("finance links keep the month and stay embedded", () => {
  assert.equal(financeHref("/admin/finance/close/", "2026-09"), "/admin/finance/close/?month=2026-09&embed=1");
  assert.equal(financeHref("/admin/finance/staff/?month=2026-08", "2026-10"), "/admin/finance/staff/?month=2026-08&embed=1");
  assert.equal(financeHref("/admin/finance/invoices/?status=overdue", "2026-10"), "/admin/finance/invoices/?status=overdue&month=2026-10&embed=1");
});

test("settings numbers: whole numbers inside the server's range", () => {
  assert.deepEqual(parseNumericSetting("issue_day", "25"), { ok: true, value: 25 });
  assert.deepEqual(parseNumericSetting("issue_day", " 7 "), { ok: true, value: 7 });
  assert.deepEqual(parseNumericSetting("first_invoice_due_days", "0"), { ok: true, value: 0 });
  for (const bad of ["", "0", "29", "2.5", "-1", "abc", "1e1"]) {
    assert.equal(parseNumericSetting("issue_day", bad).ok, false, bad);
  }
  assert.equal(parseNumericSetting("reminder_days_before", "15").ok, false);
  assert.equal(parseNumericSetting("reminder_days_before", "14").ok, true);
});

test("the ranges listed for the page are the ones the server enforces", () => {
  const ranges = Object.fromEntries(NUMERIC_SETTINGS.map((s) => [s.key, [s.min, s.max]]));
  assert.deepEqual(ranges, {
    issue_day: [1, 28], due_day: [1, 28], first_invoice_due_days: [0, 30], reminder_days_before: [0, 14],
  });
});

test("ordinals", () => {
  assert.deepEqual([1, 2, 3, 4, 11, 12, 13, 21, 22, 25, 28].map(ordinal), [
    "1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "25th", "28th",
  ]);
});

test("a month in the URL must be a real month, else the current one is used (the server answers anything else with a 400)", () => {
  const now = new Date("2026-10-22T16:00:00Z");
  assert.equal(monthFromParam("2026-09", now), "2026-09");
  for (const bad of [null, undefined, "", "undefined", "2026-13", "2026-00", "2026-9", "26-09", "2026-09-01"]) {
    assert.equal(monthFromParam(bad, now), "2026-10", String(bad));
  }
  assert.equal(isFinanceMonth("2026-12"), true);
  assert.equal(isFinanceMonth("2026-1"), false);
});
