import test from "node:test";
import assert from "node:assert/strict";
import {
  addButtonLabel,
  addHint,
  buildExpenseTable,
  defaultExpenseDate,
  deletedExpenses,
  emptyAddForm,
  parseMoneyInput,
  readConfirmation,
  readExpense,
  readRecurringCost,
  recurringRows,
  recurringStatus,
  statusLabel,
  validateAddForm,
  type Confirmation,
  type RecurringCost,
  type StaffSummary,
} from "../finance/expenses.ts";
import { money } from "../finance/model.ts";

const stamp = (iso: string) => ({ toDate: () => new Date(iso) });

const cost = (over: Partial<RecurringCost> = {}): RecurringCost => ({
  id: "zoom",
  name: "Zoom",
  category: "software",
  amount: 150,
  dayOfMonth: 14,
  startMonth: "2026-08",
  endMonth: null,
  ...over,
});

const confirmation = (over: Partial<Confirmation> = {}): Confirmation => ({
  id: "2026-10_zoom",
  costId: "zoom",
  month: "2026-10",
  amount: 149.9,
  source: "manual",
  byName: "Hashim",
  ...over,
});

test("reads a stored recurring cost and rejects one without a start month", () => {
  const read = readRecurringCost("z", { name: " Zoom ", category: "software", amount: "150", day_of_month: 14, start_month: "2026-08", end_month: null });
  assert.deepEqual(read, { id: "z", name: "Zoom", category: "software", amount: 150, dayOfMonth: 14, startMonth: "2026-08", endMonth: null });
  assert.equal(readRecurringCost("z", { name: "x" }), null);
  assert.equal(readRecurringCost("z", { name: "x", start_month: "2026-08", category: "teacher_pay" })?.category, "other");
});

test("reads a confirmation and ignores a malformed one", () => {
  assert.equal(readConfirmation("a", { cost_id: "zoom", month: "2026-10", amount: 12.345, source: "bank" })?.amount, 12.35);
  assert.equal(readConfirmation("a", { month: "2026-10" }), null);
});

test("reads old expense rows: month from the date, vendor as the name, legacy category", () => {
  const legacy = readExpense("e1", { vendor: "Zoom", category: "r_and_d", amount: 50, expense_date: stamp("2026-09-01T04:00:00Z") });
  assert.equal(legacy.month, "2026-09");
  assert.equal(legacy.name, "Zoom");
  assert.equal(legacy.category, "other");
  assert.equal(readExpense("e2", { category: "teacher_payment", amount: 9, month: "2026-09" }).category, null);
  // 02:00 UTC on Oct 1 is still September in New York.
  assert.equal(readExpense("e3", { expense_date: stamp("2026-10-01T02:00:00Z") }).month, "2026-09");
});

test("reads a soft-deleted row with who, when and why", () => {
  const e = readExpense("e1", { month: "2026-10", name: "Flyers", category: "marketing", amount: 25, deleted: true, deleted_at: stamp("2026-10-20T15:00:00Z"), deleted_by_name: "Hashim", delete_reason: "Entered twice" });
  assert.equal(e.deleted, true);
  assert.equal(e.deletedByName, "Hashim");
  assert.equal(e.deleteReason, "Entered twice");
});

test("recurring status: confirmed, due once the day has come, upcoming before it", () => {
  const today = "2026-10-21";
  assert.equal(recurringStatus(cost(), "2026-10", confirmation(), today), "confirmed");
  assert.equal(recurringStatus(cost(), "2026-10", undefined, today), "due");
  assert.equal(recurringStatus(cost({ dayOfMonth: 25 }), "2026-10", undefined, today), "upcoming");
  assert.equal(recurringStatus(cost(), "2026-09", undefined, today), "due");
  assert.equal(recurringStatus(cost(), "2026-11", undefined, today), "upcoming");
});

test("recurring rows keep a stopped cost only through its last month", () => {
  const costs = [cost({ endMonth: "2026-09" }), cost({ id: "ads", name: "Ads", startMonth: "2026-10" })];
  assert.deepEqual(recurringRows(costs, [], "2026-09", "2026-10-21").map((r) => r.cost.id), ["zoom"]);
  assert.deepEqual(recurringRows(costs, [], "2026-10", "2026-10-21").map((r) => r.cost.id), ["ads"]);
});

test("status label reads Confirmed $X, Due or Upcoming", () => {
  const [confirmed] = recurringRows([cost()], [confirmation()], "2026-10", "2026-10-21");
  assert.equal(statusLabel(confirmed, money), "Confirmed $149.90");
  const [due] = recurringRows([cost()], [], "2026-10", "2026-10-21");
  assert.equal(statusLabel(due, money), "Due — confirm amount");
  const [upcoming] = recurringRows([cost({ dayOfMonth: 28 })], [], "2026-10", "2026-10-21");
  assert.equal(statusLabel(upcoming, money), "Upcoming");
});

const staff: StaffSummary = { teacherPay: 1000, teacherPayFinal: false, teacherCount: 12, adminPay: 400, adminCount: 2, transferFees: 11, final: false };

test("the month table lists pay, recurring, payout fees and one-offs, and totals them", () => {
  const expenses = [
    readExpense("a", { month: "2026-10", name: "Flyers", category: "marketing", amount: 25, expense_date: stamp("2026-10-12T12:00:00Z") }),
    readExpense("b", { month: "2026-10", name: "Wire fee", category: "transfer_fees", amount: 5, expense_date: stamp("2026-10-03T12:00:00Z") }),
    readExpense("c", { month: "2026-10", name: "Mistake", category: "other", amount: 999, deleted: true }),
    readExpense("d", { month: "2026-09", name: "Last month", category: "other", amount: 77 }),
    readExpense("e", { month: "2026-10", name: "Old pay", category: "leadership_cost", amount: 300 }),
  ];
  const table = buildExpenseTable({ month: "2026-10", today: "2026-10-21", staff, costs: [cost()], confirmations: [], expenses });
  assert.deepEqual(table.rows.map((r) => [r.category, r.name, r.amount]), [
    ["Teacher pay", "12 teachers", 1000],
    ["Administrator pay", "2 administrators", 400],
    ["Software & subscriptions", "Zoom", 150],
    ["Transfer fees", "Staff payouts", 6],
    ["Transfer fees", "Wire fee", 5],
    ["Marketing", "Flyers", 25],
  ]);
  assert.equal(table.total, 1586);
  assert.equal(table.hasEstimate, true);
  assert.equal(table.rows.find((r) => r.name === "Flyers")?.expenseId, "a");
  assert.equal(table.rows.find((r) => r.name === "Zoom")?.expenseId, undefined);
  assert.match(table.rows.find((r) => r.name === "Zoom")?.note ?? "", /not confirmed/);
});

test("a confirmed recurring cost counts its real amount and is not an estimate", () => {
  const final: StaffSummary = { ...staff, teacherPayFinal: true, final: true };
  const table = buildExpenseTable({ month: "2026-10", today: "2026-10-21", staff: final, costs: [cost()], confirmations: [confirmation()], expenses: [] });
  const zoom = table.rows.find((r) => r.name === "Zoom");
  assert.equal(zoom?.amount, 149.9);
  assert.doesNotMatch(zoom?.note ?? "", /not confirmed/);
  assert.equal(table.hasEstimate, false);
});

test("without a staff summary the table still lists recurring and one-off rows", () => {
  const table = buildExpenseTable({ month: "2026-10", today: "2026-10-21", staff: null, costs: [cost()], confirmations: [], expenses: [] });
  assert.deepEqual(table.rows.map((r) => r.name), ["Zoom"]);
  assert.equal(table.total, 150);
});

test("deleted list is the month's soft-deleted rows, newest deletion first", () => {
  const expenses = [
    readExpense("a", { month: "2026-10", name: "A", category: "other", amount: 1, deleted: true, deleted_at: stamp("2026-10-10T10:00:00Z") }),
    readExpense("b", { month: "2026-10", name: "B", category: "other", amount: 1, deleted: true, deleted_at: stamp("2026-10-20T10:00:00Z") }),
    readExpense("c", { month: "2026-09", name: "C", category: "other", amount: 1, deleted: true }),
    readExpense("d", { month: "2026-10", name: "D", category: "other", amount: 1 }),
  ];
  assert.deepEqual(deletedExpenses(expenses, "2026-10").map((e) => e.id), ["b", "a"]);
});

test("amount input accepts money-looking text and refuses the rest", () => {
  assert.equal(parseMoneyInput("$1,200.505"), 1200.51);
  assert.equal(parseMoneyInput(""), null);
  assert.equal(parseMoneyInput("0"), null);
  assert.equal(parseMoneyInput("0", true), 0);
  assert.equal(parseMoneyInput("-5"), null);
  assert.equal(parseMoneyInput("abc"), null);
});

test("the add form validates and builds the callable payload", () => {
  const form = { ...emptyAddForm("2026-10", "2026-10-21"), name: "  Printed   flyers ", amount: "25" };
  assert.deepEqual(validateAddForm(form, "2026-10"), {
    payload: { month: "2026-10", kind: "one_time", category: "marketing", name: "Printed flyers", amount: 25, date: "2026-10-21" },
  });
  assert.deepEqual(validateAddForm({ ...form, freq: "monthly", day: "14" }, "2026-10"), {
    payload: { month: "2026-10", kind: "recurring", category: "marketing", name: "Printed flyers", amount: 25, day_of_month: 14 },
  });
  assert.deepEqual(validateAddForm({ ...form, name: "" }, "2026-10"), { error: "Add what it was for and an amount." });
  assert.deepEqual(validateAddForm({ ...form, amount: "0" }, "2026-10"), { error: "Add what it was for and an amount." });
  assert.deepEqual(validateAddForm({ ...form, date: "2026-11-02" }, "2026-10"), { error: "Pick a date in October." });
  assert.deepEqual(validateAddForm({ ...form, freq: "monthly", day: "31" }, "2026-10"), { error: "Billed on day is a number from 1 to 28." });
});

test("the form defaults, button label and hint follow how often", () => {
  assert.equal(defaultExpenseDate("2026-10", "2026-10-21"), "2026-10-21");
  assert.equal(defaultExpenseDate("2026-09", "2026-10-21"), "2026-09-01");
  assert.equal(emptyAddForm("2026-10", "2026-10-31").day, "28");
  assert.equal(addButtonLabel("once"), "Add expense");
  assert.equal(addButtonLabel("monthly"), "Add monthly cost");
  assert.equal(addHint("once", "2026-10"), "Counts once, in October.");
  assert.equal(addHint("monthly", "2026-10"), "Counts as paid for October now, then shows up every month to confirm with the real bill.");
});
