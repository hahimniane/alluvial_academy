import test from "node:test";
import assert from "node:assert/strict";
import { canClose, closeChecklist, lastDay } from "../finance/closeChecks.ts";
import { financeHref } from "../finance/links.ts";
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
