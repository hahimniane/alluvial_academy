# Finance (Next.js) — build spec

Agreed with the owner on 2026-10-21/22 after a design interview and a clickable
prototype (https://claude.ai/artifact/783PKy7AjxoTYY3DVPfhbM — the reference for
every screen, wording and flow). This file is the contract every finance branch
builds against. Where this file and the prototype disagree, this file wins.

## Who and where

- Every admin (`isCurrentUserAdmin`) sees and does everything. No finance sub-roles.
- Pages live under `apps/web/src/app/admin/finance/<page>/` and render inside
  `FinanceShell` (`apps/web/src/components/finance/FinanceShell.tsx`), which wraps
  `AdminDashboardShell`, shows the finance sub-menu and the month picker, and
  supports `?embed=1` (Flutter web shows these pages in an iframe, like Shifts).
- The old Flutter Invoices hub is replaced: Flutter web embeds `/admin/finance/`;
  the native admin app shows a read-only summary (totals + overdue invoices).
  Parent/adult-student invoice and payment screens in Flutter are unchanged.

## Routes (one owner each)

| Route | Screen |
|---|---|
| `/admin/finance/` | Overview: 1 / 3 / 5 / custom months, to-dos, 12-month chart, breakdown, period table, PDF |
| `/admin/finance/bank/` | Bank deposits + WhatsApp payment proofs (inactive until connected) |
| `/admin/finance/invoices/` | Invoice list, filters, detail, record payment, reminders, extend access, edit, cancel, monthly amount, new invoice |
| `/admin/finance/staff/` | Staff pay: teachers from audits, administrators (fixed + optional %), mark paid, pause |
| `/admin/finance/penalties/` | Penalties per teacher, filters |
| `/admin/finance/expenses/` | Recurring costs (confirm), one-off/recurring add, soft delete + restore |
| `/admin/finance/discounts/` | Discounts + family credits |
| `/admin/finance/students/` | New students & first invoices |
| `/admin/finance/close/` | Close / reopen month |
| `/admin/finance/settings/` | Switches: auto billing, parent messages; bank/WhatsApp connection status |

## Money rules (decided — do not change)

1. **A month's profit** = tuition billed for that month (net of discounts, excluding
   cancelled invoices) − that month's costs. Teacher pay counts in the month
   TAUGHT even though it is paid the next month. "Collected" is shown beside it.
2. **Teacher pay** comes from `teacher_audits/{uid}_{yyyy-MM}.paymentSummary`
   (`totalNetPayment`, `totalPenalties`). It is an **estimate** until the audit
   status is `ceoApproved` or `completed`, then **final**. Only final pay can be
   marked paid. Teacher hours/pay must read live + archived shifts through the
   existing shared readers if recomputed — never `teaching_shifts` alone.
3. **Administrators**: fixed monthly pay + an OPTIONAL per-person %. The % is of
   (billed − every other cost that month, before administrator pay), floored at
   0 — a losing month pays the fixed part only. Terms have a start month and
   history; changing them never rewrites a closed month. **Paused** pay (manual,
   or automatic when the account is deactivated) = $0 and cannot be marked paid.
4. **Expense categories**: `teacher_pay` and `admin_pay` (computed, never stored
   as expenses), `software`, `marketing`, `transfer_fees`, `other`. Roll-ups:
   Staff = teacher_pay + admin_pay; Administration = software + transfer_fees;
   Other = marketing + other. Legacy `finance_expenses.category` values map:
   `teacher_payment`→ignored for totals (pay comes from audits), `leadership_cost`→
   `admin_pay` (ignored likewise), `marketing_cost`→`marketing`, `r_and_d`→`other`,
   `other`→`other`.
5. **Recurring costs** appear each month as "due" and count only when confirmed
   with the real amount (unconfirmed ones count at their usual amount, flagged
   estimate). Adding a recurring cost counts it as paid for the current month.
6. **Transfer fees** are optional on staff payouts and are Alluwal's expense.
7. **The monthly amount is set on a family's first invoice** and every later
   monthly invoice uses it unchanged until staff change it (reason required,
   applies from the next invoice, history kept). No automatic recalculation.
8. **First invoice**: created when the student attends their first class,
   pro-rated by classes left that month (`monthly × left ÷ classesInFullMonth`),
   due 3 days later; staff are notified of the enrollment.
9. **Monthly billing**: one invoice per family per month (doc id
   `monthly_{parentId}_{yyyy-MM}` so a second one cannot exist), issued on the
   25th, due on the 1st, discounts applied, open family credit applied. It is
   **OFF** (`finance_settings/main.auto_billing_enabled == false`) until the owner
   approves the preview; while off, the existing `recurring_billing_plans`
   generator keeps running unchanged.
10. **Overdue** is computed (balance > 0 and today > due date), never read from
    `status == 'overdue'` alone.
11. **Credits**: unused classes after a pause/leave, or an invoice lowered below
    what was paid, become a family credit with no expiry, applied to the next
    invoice for any child of that family; admins can refund or cancel.
12. **Unpaid**: reminder 3 days before and on the due date (parent messages are
    **OFF** behind `finance_settings/main.parent_messages_enabled`), access
    suspended at the cutoff (existing `access_cutoff_date` flow), one-click extend.
13. **Edits** to invoices require a reason, keep `edit_history`, notify the
    parent (when messages are on), and a total below the paid amount creates a
    credit. Cancel only when nothing is paid. **Closed months are locked**: no
    edits, deletes, payouts or confirmations until an owner reopens with a reason.
14. **Deleting** expenses is a soft delete with a required reason
    (`deleted: true`, `deleted_at/by`, `delete_reason`), hidden from totals,
    restorable from a "Deleted" list. Recurring costs are stopped (end month),
    not deleted.
15. Bank deposits / WhatsApp proofs: a screenshot never marks an invoice paid;
    a bank deposit confirmed by an admin does. Everything is suggested, then
    confirmed by a person.

## Collections

All admin-only (read/write) unless noted. Timestamps are Firestore Timestamps.
Months are `yyyy-MM` strings in America/New_York.

- `finance_settings/main` — `{auto_billing_enabled:false, parent_messages_enabled:false, issue_day:25, due_day:1, first_invoice_due_days:3, reminder_days_before:3, plaid:{connected:false}, whatsapp:{connected:false}}`
- `finance_months/{yyyy-MM}` — `{status:'open'|'closed', closed_at, closed_by, closed_by_name, snapshot:{billed, collected, expenses, profit, ...}, log:[{action:'closed'|'reopened', at, by, by_name, reason}]}`
- `finance_expenses/{id}` (existing) — add `month`, `kind:'one_time'|'recurring'`, `recurring_cost_id`, `name`, `deleted`, `deleted_at`, `deleted_by`, `delete_reason`, `restored_at/by`.
- `finance_recurring_costs/{id}` — `{name, category, amount, day_of_month, start_month, end_month|null, created_at/by}`
- `finance_recurring_confirmations/{yyyy-MM}_{costId}` — `{cost_id, month, amount, confirmed_at, confirmed_by, source:'manual'|'bank'|'created', bank_transaction_id?}`
- `staff_payouts/{yyyy-MM}_{uid}` — `{user_id, name, role:'teacher'|'admin', month, amount_due, amount_paid, date_paid, method, transfer_fee, reference, receipt_path, note, recorded_at/by, voided, void_reason, history:[...]}`
- `admin_pay_terms/{uid}` — `{name, role_title, terms:[{from_month, fixed, pct, note, set_at, set_by}], pauses:[{from_month, until_month|null, reason, auto:boolean, at, by}]}`
- `family_billing/{parentId}` — `{monthly_amount, student_ids, set_on_invoice_id, set_at, history:[{from_month, old, new, reason, at, by}], active}`
  Optional fields the billing engine reads or writes:
  - `pending_first_invoice: {monthly_amount, classes_in_month, student_id?}` — staff set it at enrollment (with `student_ids` including the child). `monthly_amount` is the **new student's own** monthly price; `classes_in_month` is the number of classes in a full month. When that student's first class completes (a `teaching_shifts` status change into `completed`/`fullyCompleted`/`partiallyCompleted`), the `createFirstInvoiceOnFirstClass` trigger creates the same pro-rated first invoice as `createFirstInvoice` (classes left = the student's non-cancelled classes from that class to the month end, live + archived), writes `monthly_amount`/`set_on_invoice_id`/`set_at`, removes `pending_first_invoice`, and adds an `admin_notifications` entry. One first invoice per student (`invoices/first_{studentId}`); a student who already has an invoice is not billed again (`first_invoice_skipped` records why). For a family that already has a `monthly_amount`, the new student's price is added to it from the next invoice (a `history` entry is written).
  - `student_amounts: {studentId: amount}` — optional split of `monthly_amount` across children (used only while it adds up exactly; otherwise the amount is split evenly). Cleared by `setFamilyMonthlyAmount`.
  - `last_first_invoice`, `first_invoice_skipped`, `source:'backfill'` — written by the engine/backfill, informational.
  - `monthly_amount` is always the latest amount; `history[].old` is the amount before a change, so the amount for any past or future month is derivable.
  - Written only by callables/triggers; clients cannot write it (rules).
- Preview rows (`previewMonthlyBilling`): `{parent_id, parent_name, parent_email, students:[names], student_ids, monthly_amount, discount, credit, total, existing_invoice_id?, proposed}`; `totals:{families, to_create, monthly_amount, discount, credit, total, already_invoiced, already_invoiced_total}` — totals cover only families that would get a new invoice. Invoices created by the engine carry `kind`, `billing_month`, `credit_lines`, `discount_total`, `credit_applied`, `source:'family_billing'`; reminders are recorded as `reminders_sent.before` / `reminders_sent.due`.
- `family_credits/{id}` — `{parent_id, student_id?, amount, reason, source:'pause'|'leave'|'invoice_edit'|'manual', status:'open'|'used'|'refunded'|'cancelled', used_on_invoice_id, created_at/by, closed_at/by}`
- `invoices` (existing) — add `kind:'first_month'|'monthly'|'one_off'`, `billing_month`, `edit_history:[{at, by, by_name, reason, before:{total, due_date}, after:{...}}]`, `cancelled_at/by`, `cancel_reason` (status `'cancelled'`), `credit_lines`.
- `bank_transactions/{id}` — Plaid. `{date, amount, direction:'in'|'out', description, memo, payer_name, account_mask, match:{status:'suggested'|'confirmed'|'manual'|'ignored'|'none', level, allocations:[{invoice_id, amount}], recurring_cost_id, decided_at/by}, proof_id?}`
- `known_payers/{normalizedName}` — `{parent_id, name, learned_at/by}`
- `payment_proofs/{id}` — WhatsApp. `{from_phone, parent_id?, image_path, extracted:{amount, date, sender, confirmation}, status:'waiting_bank'|'matched'|'confirmed'|'unknown_sender'|'duplicate'|'not_payment', bank_transaction_id?, invoice_id?, replies:[...]}`

## Engineering rules

- Read with bounded, month-filtered queries (the old overview pulled ~3,200
  unfiltered docs). Aggregate on the server where a page would otherwise read
  hundreds of docs; cache nothing across months in the client.
- Money mutations that must be atomic (invoice edit/cancel, first invoice,
  monthly amount change, payouts, close/reopen, credits) go through callables in
  `functions/handlers/finance_*.js` using `verifyCallableCallerIsAdmin`, gen2
  `onCall({cors:true, invoker:'public'}, …)`, exported in `functions/index.js`.
  Every callable enforces the closed-month lock.
- Copy is plain and present tense; French via `apps/web/src/lib/translations/fr.ts`
  where pages use `t()`/`tr()`.
- Tests: pure logic in `apps/web/src/lib/finance/*.ts` with `apps/web/src/lib/__tests__/finance*.test.ts`
  (node --test style); callables in `functions/tests/finance_*.test.js` (jest, the repo's Firestore double).

## Callable interfaces (names are fixed so branches can build in parallel)

All take `request.data`, require an admin caller, and throw `failed-precondition`
with a plain message when the month is closed.

| Callable | Owner branch | Input → output |
|---|---|---|
| `getFinanceMonthSummary` | overview | `{month}` → `{month, status, final:boolean, billed, collected, owed, discounts, credit_open, penalties, teacher_pay, teacher_pay_final:boolean, admin_pay, admin_base, software, marketing, transfer_fees, other, expenses, profit, invoice_count, families_owing, recurring_pending, recurring_due, unpaid_teachers, unpaid_admins, overdue_invoices, first_invoices_this_week, teachers:[{uid,name,hours,gross,penalties,net,final}], admins:[{uid,name,role_title,fixed,pct,share,total,paused:{reason,auto}|null}]}` |
| `closeFinanceMonth` / `reopenFinanceMonth` | overview | `{month}` / `{month, reason}` → `{ok}` |
| `updateFinanceSettings` | overview | `{patch}` → `{settings}` |
| `recordStaffPayouts` | staff | `{month, entries:[{uid, role, amount_paid, method, date_paid, transfer_fee?, reference?, note?}]}` → `{ok, count}` (only final pay; never paused admins) |
| `voidStaffPayout` | staff | `{month, uid, reason}` → `{ok}` |
| `setAdminPayTerms` | staff | `{uid, name?, role_title?, from_month, fixed, pct, note}` → `{ok}` |
| `pauseAdminPay` / `resumeAdminPay` | staff | `{uid, from_month, reason}` → `{ok}` |
| `addFinanceExpense` | expenses | `{month, kind:'one_time'|'recurring', category, name, amount, date?, day_of_month?}` → `{id}` |
| `deleteFinanceExpense` / `restoreFinanceExpense` | expenses | `{id, reason}` / `{id}` → `{ok}` |
| `confirmRecurringCost` / `stopRecurringCost` | expenses | `{month, cost_id, amount, source?}` / `{cost_id, last_month}` → `{ok}` |
| `resolveFamilyCredit` | expenses | `{credit_id, action:'refund'|'cancel', reason}` → `{ok}` |
| `editInvoice` | invoices | `{invoice_id, lines:[{description, amount, student_id?}], discount, due_date:'yyyy-MM-dd', reason}` → `{invoice, credit_id?}` |
| `cancelInvoice` | invoices | `{invoice_id, reason}` → `{ok}` |
| `createFirstInvoice` | billing | `{parent_id, student_id, monthly_amount, classes_in_month, classes_left, first_class_date:'yyyy-MM-dd'}` → `{invoice_id}` (also writes `family_billing`) |
| `setFamilyMonthlyAmount` | billing | `{parent_id, monthly_amount, reason}` → `{ok}` (applies from the next invoice) |
| `previewMonthlyBilling` | billing | `{month}` → `{rows:[{parent_id, parent_name, students, monthly_amount, discount, credit, total, existing_invoice_id?}], totals}` |
| `linkBankAccount` / `syncBankTransactions` / `decideBankMatch` | bank | Plaid link token + exchange; sync; `{transaction_id, action:'confirm'|'reject'|'manual'|'ignore', allocations?, remember_payer?}` |
| `decidePaymentProof` | bank | `{proof_id, action:'confirm'|'link_family', parent_id?}` → `{ok}` |

Existing callables stay: `createInvoice` (one-off charges; add a duplicate
guard for monthly tuition), `recordManualPayment`, `extendStudentAccessCutoff`,
`getInvoicePaymentLink`.
