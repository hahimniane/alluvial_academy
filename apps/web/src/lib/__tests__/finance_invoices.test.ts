import test from "node:test";
import assert from "node:assert/strict";
import {
  DEFAULT_FILTERS,
  addDays,
  buildRow,
  buildTimeline,
  chipCounts,
  creditNote,
  daysBetween,
  draftFromInvoice,
  dueDayKey,
  editPayload,
  evaluateDraft,
  extendAccessTarget,
  filterAndSort,
  findMonthlyClash,
  firstInvoicePreview,
  formatDay,
  historyText,
  invoiceState,
  mergeNewStudents,
  newStudentStatus,
  nextMonthlyInvoice,
  normalizeInvoice,
  notifyLine,
  previewLine,
  toneFor,
  totalsOf,
  workedExample,
  type Invoice,
  type InvoiceFilters,
  type InvoiceRow,
} from "../finance/invoices.ts";

// Thursday Oct 22 2026, 11am in New York
const NOW = new Date("2026-10-22T15:00:00Z");
const money = (n: number) => (n < 0 ? "−$" : "$") + Math.abs(n).toFixed(2);

const utc = (day: string) => new Date(`${day}T00:00:00Z`);

function inv(id: string, over: Record<string, unknown> = {}): Invoice {
  return normalizeInvoice(id, {
    invoice_number: `INV-${id}`,
    parent_id: "p1",
    student_ids: ["s1"],
    status: "pending",
    total_amount: 100,
    paid_amount: 0,
    period: "2026-10",
    due_date: utc("2026-10-25"),
    issued_date: new Date("2026-09-25T16:00:00Z"),
    items: [{ description: "Tuition - Amina", quantity: 1, unit_price: 100, total: 100, student_id: "s1" }],
    ...over,
  });
}

const names = new Map([
  ["p1", "Mariama Camara"],
  ["p2", "Seydou Sow"],
  ["p3", "Hawa Jalloh"],
  ["s1", "Amina Camara"],
  ["s2", "Oumar Sow"],
  ["s3", "Fatou Jalloh"],
]);
const teachers = new Map<string, readonly string[]>([
  ["s1", ["t1"]],
  ["s2", ["t2"]],
  ["s3", ["t1", "t2"]],
]);

function rows(invoices: Invoice[], credit: string[] = []): InvoiceRow[] {
  return invoices.map((i) => buildRow(i, { now: NOW, names, teachersByStudent: teachers, creditParents: new Set(credit) }));
}

/* ----------------------------------------------------------------- dates -- */

test("due day: midnight UTC is that date, local noon is read in New York", () => {
  assert.equal(dueDayKey(utc("2026-10-25")), "2026-10-25");
  assert.equal(dueDayKey(new Date("2026-10-25T16:00:00Z")), "2026-10-25");
  assert.equal(dueDayKey({ toDate: () => utc("2026-10-25") }), "2026-10-25");
  assert.equal(dueDayKey(null), null);
});

test("day arithmetic and labels", () => {
  assert.equal(daysBetween("2026-10-20", "2026-10-22"), 2);
  assert.equal(addDays("2026-10-30", 3), "2026-11-02");
  assert.equal(formatDay("2026-10-05"), "Oct 5");
  assert.equal(formatDay(null), "");
});

/* ----------------------------------------------------------- normalise -- */

test("normalizeInvoice reads totals, billing month, discount lines and kind", () => {
  const i = normalizeInvoice("a", {
    invoice_number: "INV-2026-9",
    parent_id: "p1",
    student_id: "s1",
    kind: "first_month",
    billing_month: "2026-11",
    period: "2026-10",
    total_amount: 90,
    paid_amount: 10,
    due_date: utc("2026-11-01"),
    items: [
      { description: "Tuition - A", total: 100, student_id: "s1" },
      { description: "Discount — 10% off", total: -10, is_discount: true, student_id: "s1" },
    ],
    classes_left: 3,
    classes_in_month: 8,
    first_class_date: "2026-10-20",
  });
  assert.equal(i.billingMonth, "2026-11");
  assert.equal(i.kind, "first_month");
  assert.equal(i.studentIds[0], "s1");
  assert.equal(i.subtotal, 100);
  assert.equal(i.discount, 10);
  assert.equal(i.lines.length, 1);
  assert.equal(i.discountLines[0].amount, 10);
  assert.equal(i.classesLeft, 3);
  assert.equal(i.firstClassKey, "2026-10-20");
});

test("billing month falls back to the period, then the issued month", () => {
  assert.equal(inv("a", { period: "2026-06 to 2026-08" }).billingMonth, "2026-06");
  assert.equal(inv("b", { period: undefined, issued_date: new Date("2026-09-30T23:30:00Z") }).billingMonth, "2026-09");
});

/* ---------------------------------------------------------------- status -- */

test("status is computed: paid, partly paid, overdue, unpaid, cancelled", () => {
  assert.equal(invoiceState(inv("a", { paid_amount: 100, status: "paid" }), NOW).label, "Paid");
  assert.equal(invoiceState(inv("b"), NOW).label, "Unpaid · due Oct 25");
  assert.equal(invoiceState(inv("c", { due_date: utc("2026-10-20") }), NOW).label, "Overdue · 2d");
  assert.equal(invoiceState(inv("d", { paid_amount: 40 }), NOW).label, "Partly paid");
  assert.equal(invoiceState(inv("e", { paid_amount: 40, due_date: utc("2026-10-12") }), NOW).label, "Partly paid · 10d overdue");
  assert.equal(invoiceState(inv("f", { status: "cancelled" }), NOW).label, "Cancelled");
});

test("a stored status of overdue proves nothing, and due today is not overdue", () => {
  assert.equal(invoiceState(inv("a", { status: "overdue", paid_amount: 100, due_date: utc("2026-09-01") }), NOW).kind, "paid");
  assert.equal(invoiceState(inv("b", { status: "pending", due_date: utc("2026-10-22") }), NOW).late, false);
  assert.equal(invoiceState(inv("c", { status: "pending", due_date: utc("2026-10-21") }), NOW).late, true);
});

test("badge tones", () => {
  assert.equal(toneFor(invoiceState(inv("a", { paid_amount: 100 }), NOW)), "ok");
  assert.equal(toneFor(invoiceState(inv("b"), NOW)), "warn");
  assert.equal(toneFor(invoiceState(inv("c", { due_date: utc("2026-10-01") }), NOW)), "bad");
  assert.equal(toneFor(invoiceState(inv("d", { status: "cancelled" }), NOW)), "mute");
});

/* ---------------------------------------------------------------- filters -- */

const set = () =>
  rows(
    [
      inv("1", { parent_id: "p1", student_ids: ["s1"], total_amount: 160, due_date: utc("2026-10-25") }), // unpaid
      inv("2", { parent_id: "p2", student_ids: ["s2"], total_amount: 100, due_date: utc("2026-10-10") }), // overdue 12d
      inv("3", { parent_id: "p3", student_ids: ["s3"], total_amount: 80, paid_amount: 30, due_date: utc("2026-09-20") }), // partly, overdue 32d
      inv("4", { parent_id: "p1", student_ids: ["s1"], total_amount: 60, paid_amount: 60, status: "paid", due_date: utc("2026-10-01"), kind: "first_month" }), // paid first
      inv("5", {
        parent_id: "p2",
        student_ids: ["s2"],
        total_amount: 90,
        status: "cancelled",
        due_date: utc("2026-10-02"),
        items: [
          { description: "Tuition", total: 100, student_id: "s2" },
          { description: "Discount", total: -10, is_discount: true },
        ],
      }),
      inv("6", { parent_id: "p3", student_ids: ["s3"], total_amount: 50, period: "2026-09", due_date: utc("2026-09-05") }), // overdue 47d, other month
    ],
    ["p2"],
  );

const withF = (patch: Partial<InvoiceFilters>) => ({ ...DEFAULT_FILTERS, ...patch });

test("chips and their counts are taken on everything except the chip", () => {
  const out = filterAndSort(set(), withF({}));
  assert.deepEqual(out.counts, { all: 6, unpaid: 4, overdue: 3, partly: 1, paid: 1, cancelled: 1 });
  const overdue = filterAndSort(set(), withF({ status: "overdue" }));
  assert.deepEqual(overdue.rows.map((r) => r.inv.id).sort(), ["2", "3", "6"]);
  // counts do not change when a chip is picked
  assert.deepEqual(overdue.counts, out.counts);
  assert.deepEqual(filterAndSort(set(), withF({ status: "partly" })).rows.map((r) => r.inv.id), ["3"]);
  assert.deepEqual(filterAndSort(set(), withF({ status: "cancelled" })).rows.map((r) => r.inv.id), ["5"]);
});

test("month filter uses the billing month", () => {
  assert.deepEqual(filterAndSort(set(), withF({ month: "2026-09" })).rows.map((r) => r.inv.id), ["6"]);
  assert.equal(filterAndSort(set(), withF({ month: "2026-10" })).rows.length, 5);
});

test("search matches family, student and invoice number", () => {
  assert.deepEqual(filterAndSort(set(), withF({ q: "sow" })).rows.map((r) => r.inv.id).sort(), ["2", "5"]);
  assert.deepEqual(filterAndSort(set(), withF({ q: "fatou" })).rows.map((r) => r.inv.id).sort(), ["3", "6"]);
  assert.deepEqual(filterAndSort(set(), withF({ q: "inv-4" })).rows.map((r) => r.inv.id), ["4"]);
  assert.equal(filterAndSort(set(), withF({ q: "nobody" })).rows.length, 0);
});

test("teacher filter", () => {
  assert.deepEqual(filterAndSort(set(), withF({ teacher: "t2" })).rows.map((r) => r.inv.id).sort(), ["2", "3", "5", "6"]);
  assert.deepEqual(filterAndSort(set(), withF({ teacher: "t1" })).rows.map((r) => r.inv.id).sort(), ["1", "3", "4", "6"]);
});

test("days overdue buckets", () => {
  assert.deepEqual(filterAndSort(set(), withF({ overdue: "1-15" })).rows.map((r) => r.inv.id), ["2"]);
  assert.deepEqual(filterAndSort(set(), withF({ overdue: "16-30" })).rows.map((r) => r.inv.id), []);
  assert.deepEqual(filterAndSort(set(), withF({ overdue: "30+" })).rows.map((r) => r.inv.id).sort(), ["3", "6"]);
});

test("amount range, discount, family credit and first-month filters", () => {
  assert.deepEqual(filterAndSort(set(), withF({ min: "90", max: "120" })).rows.map((r) => r.inv.id).sort(), ["2", "5"]);
  assert.deepEqual(filterAndSort(set(), withF({ min: "150" })).rows.map((r) => r.inv.id), ["1"]);
  assert.deepEqual(filterAndSort(set(), withF({ hasDiscount: true })).rows.map((r) => r.inv.id), ["5"]);
  assert.deepEqual(filterAndSort(set(), withF({ familyCredit: true })).rows.map((r) => r.inv.id).sort(), ["2", "5"]);
  assert.deepEqual(filterAndSort(set(), withF({ firstOnly: true })).rows.map((r) => r.inv.id), ["4"]);
});

test("sorts: due, amount, days overdue, family, newest", () => {
  const ids = (sort: InvoiceFilters["sort"]) => filterAndSort(set(), withF({ sort })).rows.map((r) => r.inv.id);
  assert.deepEqual(ids("due"), ["6", "3", "4", "5", "2", "1"]);
  assert.deepEqual(ids("amount"), ["1", "2", "5", "3", "4", "6"]);
  assert.deepEqual(ids("overdue").slice(0, 3), ["6", "3", "2"]);
  assert.deepEqual(ids("family").slice(0, 2), ["6", "3"]); // Hawa Jalloh first, earlier due first
  const newer = rows([inv("old", { issued_date: new Date("2026-08-01T00:00:00Z") }), inv("new", { issued_date: new Date("2026-10-20T00:00:00Z") })]);
  assert.deepEqual(filterAndSort(newer, withF({ sort: "newest" })).rows.map((r) => r.inv.id), ["new", "old"]);
});

test("totals follow the filtered rows and skip cancelled money", () => {
  const all = filterAndSort(set(), withF({}));
  assert.equal(all.totals.count, 6);
  // billed 160+100+80+60+50 (cancelled 90 not counted)
  assert.equal(all.totals.billed, 450);
  assert.equal(all.totals.collected, 90);
  assert.equal(all.totals.owed, 360);
  const overdue = filterAndSort(set(), withF({ status: "overdue" })).totals;
  assert.deepEqual(overdue, { count: 3, billed: 230, collected: 30, owed: 200 });
  assert.deepEqual(totalsOf([]), { count: 0, billed: 0, collected: 0, owed: 0 });
});

test("chipCounts on an empty set", () => {
  assert.deepEqual(chipCounts([]), { all: 0, unpaid: 0, overdue: 0, partly: 0, paid: 0, cancelled: 0 });
});

/* -------------------------------------------------------- monthly clash -- */

test("monthly tuition clash: same parent and billing month, not cancelled", () => {
  const list = [
    inv("a", { parent_id: "p1", kind: "monthly", billing_month: "2026-11", period: undefined }),
    inv("b", { parent_id: "p2", kind: "monthly", billing_month: "2026-11", period: undefined }),
    inv("c", { parent_id: "p1", kind: "one_off", billing_month: "2026-12", period: undefined }),
  ];
  assert.equal(findMonthlyClash(list, "p1", "2026-11")?.id, "a");
  assert.equal(findMonthlyClash(list, "p1", "2026-12"), null);
  assert.equal(findMonthlyClash(list, "p3", "2026-11"), null);
  const cancelled = [inv("x", { parent_id: "p1", kind: "monthly", status: "cancelled", billing_month: "2026-11", period: undefined })];
  assert.equal(findMonthlyClash(cancelled, "p1", "2026-11"), null);
  const first = [inv("f", { parent_id: "p1", kind: "first_month", billing_month: "2026-10", period: undefined })];
  assert.equal(findMonthlyClash(first, "p1", "2026-10")?.id, "f");
  const generated = [inv("recurring_plan_2026-11", { parent_id: "p1", period: "2026-11" })];
  assert.equal(findMonthlyClash(generated, "p1", "2026-11")?.id, "recurring_plan_2026-11");
});

/* ------------------------------------------------------------ edit draft -- */

test("an untouched draft is valid but unchanged", () => {
  const i = inv("a");
  const ev = evaluateDraft(i, draftFromInvoice(i));
  assert.equal(ev.changed, false);
  assert.equal(ev.canSave, false);
  assert.equal(ev.hint, "Add a reason for the change.");
  assert.equal(ev.newTotal, 100);
});

test("save needs a change and a reason", () => {
  const i = inv("a");
  const d = draftFromInvoice(i);
  d.lines[0].amount = "80";
  assert.equal(evaluateDraft(i, d).canSave, false);
  assert.equal(evaluateDraft(i, d).hint, "Add a reason for the change.");
  d.reason = "  Schedule changed ";
  const ev = evaluateDraft(i, d);
  assert.equal(ev.canSave, true);
  assert.equal(ev.newTotal, 80);
  assert.deepEqual(editPayload(i, d), {
    invoice_id: "a",
    lines: [{ description: "Tuition - Amina", amount: 80, student_id: "s1" }],
    discount: 0,
    due_date: "2026-10-25",
    reason: "Schedule changed",
  });
  // only the reason typed, nothing changed
  const same = draftFromInvoice(i);
  same.reason = "x";
  assert.equal(evaluateDraft(i, same).hint, "Nothing has changed yet.");
});

test("a changed due date alone is a change", () => {
  const i = inv("a");
  const d = draftFromInvoice(i);
  d.due = "2026-10-30";
  d.reason = "Family asked for time";
  assert.equal(evaluateDraft(i, d).canSave, true);
});

test("draft blockers", () => {
  const i = inv("a");
  const base = () => ({ ...draftFromInvoice(i), reason: "r" });
  const lineBlank = base();
  lineBlank.lines[0].description = " ";
  assert.equal(evaluateDraft(i, lineBlank).hint, "Every line needs a description and an amount.");
  const amountBlank = base();
  amountBlank.lines[0].amount = "";
  assert.equal(evaluateDraft(i, amountBlank).canSave, false);
  const negative = base();
  negative.lines[0].amount = "-5";
  assert.match(evaluateDraft(i, negative).hint, /cannot be negative/);
  const noLines = { ...base(), lines: [] };
  assert.equal(evaluateDraft(i, noLines).hint, "An invoice needs at least one line.");
  const bigDiscount = base();
  bigDiscount.discount = "150";
  assert.match(evaluateDraft(i, bigDiscount).hint, /more than the lines/);
  const noDate = base();
  noDate.due = "";
  assert.equal(evaluateDraft(i, noDate).hint, "Pick a due date.");
});

test("a discount lowers the total; lowering below paid gives a credit", () => {
  const i = inv("a", { paid_amount: 100, status: "paid" });
  const d = draftFromInvoice(i);
  d.lines[0].amount = "70";
  d.discount = "10";
  d.reason = "Schedule changed";
  const ev = evaluateDraft(i, d);
  assert.equal(ev.newTotal, 60);
  assert.equal(ev.creditBack, 40);
  assert.equal(ev.leftToPay, 0);
  assert.equal(ev.canCancel, false);
  assert.equal(previewLine(i, ev, money), "Total $100.00 → $60.00 · already paid $100.00 · nothing left to pay");
  assert.equal(
    creditNote("Camara", ev, money),
    "$40.00 was paid above the new total. It becomes credit for the Camara family and comes off their next invoice.",
  );
});

test("an editable draft keeps the existing discount; cancel is offered only when nothing is paid", () => {
  const withDiscount = inv("a", {
    total_amount: 90,
    items: [
      { description: "Tuition - A", total: 100, student_id: "s1" },
      { description: "Discount — 10% off", total: -10, is_discount: true },
    ],
  });
  const d = draftFromInvoice(withDiscount);
  assert.equal(d.discount, "10");
  assert.equal(d.lines.length, 1);
  assert.equal(evaluateDraft(withDiscount, d).newTotal, 90);
  assert.equal(evaluateDraft(withDiscount, d).canCancel, true);
  assert.equal(evaluateDraft(inv("p", { paid_amount: 5 }), draftFromInvoice(inv("p", { paid_amount: 5 }))).canCancel, false);
});

test("who is told depends on the parent-messages switch", () => {
  assert.equal(notifyLine("Mariama Camara", "INV-1", 80, true, money), "When you save, Mariama Camara gets a message: “Your invoice INV-1 was updated. New total $80.00.”");
  assert.match(notifyLine("Mariama Camara", "INV-1", 80, false, money), /Parent messages are off/);
});

/* --------------------------------------------------------- history/timeline -- */

test("history reads edits and cancellations", () => {
  const i = normalizeInvoice("a", {
    edit_history: [
      {
        at: new Date("2026-10-21T16:00:00Z"),
        by_name: "Hawa Admin",
        reason: "Schedule changed",
        before: { total_amount: 100, due_date: utc("2026-10-25") },
        after: { total_amount: 60, due_date: utc("2026-10-30") },
        credit_amount: 40,
      },
      { at: new Date("2026-10-22T16:00:00Z"), by_name: "Hawa Admin", action: "cancelled", reason: "Enrolled twice", before: {}, after: { status: "cancelled" } },
    ],
  });
  assert.equal(historyText(i.editHistory[0], money), "Oct 21 — edited by Hawa Admin: total $100.00 → $60.00, due Oct 25 → Oct 30, $40.00 became family credit · “Schedule changed”");
  assert.equal(historyText(i.editHistory[1], money), "Oct 22 — cancelled by Hawa Admin · “Enrolled twice”");
});

test("timeline: issued, payments, recorded reminders, access", () => {
  const i = inv("a", {
    due_date: utc("2026-10-12"),
    issued_date: new Date("2026-10-01T16:00:00Z"),
    access_cutoff_date: utc("2026-10-13"),
    reminders: [{ at: new Date("2026-10-09T16:00:00Z"), kind: "before_due", by_name: "System" }],
  });
  const t = buildTimeline(i, [{ amount: 30, at: new Date("2026-10-05T16:00:00Z"), method: "Zelle" }], "Mariama Camara", money, NOW);
  assert.deepEqual(t.entries, [
    "Oct 1 — invoice sent to Mariama Camara",
    "Oct 5 — $30.00 received by Zelle",
    "Oct 9 — reminder sent (3 days before due)",
  ]);
  assert.deepEqual(t.access, { text: "Class access suspended since Oct 13", tone: "bad" });

  const extended = inv("b", {
    due_date: utc("2026-10-12"),
    access_cutoff_date: utc("2026-10-31"),
    access_extended_at: new Date("2026-10-20T16:00:00Z"),
  });
  assert.deepEqual(buildTimeline(extended, [], "x", money, NOW).access, { text: "Class access extended to Oct 31", tone: "info" });
  assert.equal(buildTimeline(inv("c"), [], "x", money, NOW).access, null);
});

test("extend access moves to the end of the month", () => {
  assert.deepEqual(extendAccessTarget(NOW), { key: "2026-10-31", label: "Oct 31" });
  assert.equal(extendAccessTarget(new Date("2026-02-10T15:00:00Z")).key, "2026-02-28");
  // on the last day it moves on to the next month
  assert.equal(extendAccessTarget(new Date("2026-10-31T15:00:00Z")).key, "2026-11-30");
});

test("next monthly invoice: issued on the issue day, due on the due day of the following month", () => {
  assert.deepEqual(nextMonthlyInvoice(NOW, 25, 1), { issueKey: "2026-10-25", dueKey: "2026-11-01", month: "2026-11" });
  assert.deepEqual(nextMonthlyInvoice(new Date("2026-10-26T15:00:00Z"), 25, 1), { issueKey: "2026-11-25", dueKey: "2026-12-01", month: "2026-12" });
  assert.deepEqual(nextMonthlyInvoice(new Date("2026-12-28T15:00:00Z"), 25, 1), { issueKey: "2027-01-25", dueKey: "2027-02-01", month: "2027-02" });
  assert.deepEqual(nextMonthlyInvoice(new Date("2026-12-10T15:00:00Z"), 25, 1), { issueKey: "2026-12-25", dueKey: "2027-01-01", month: "2027-01" });
});

/* ----------------------------------------------------------- first invoice -- */

test("first invoice is monthly × left ÷ classes in a full month, due 3 days after the first class", () => {
  const ctx = { studentName: "Zainab Camara", dueDays: 3, issueDay: 25, dueDay: 1 };
  const p = firstInvoicePreview({ monthly: "80", perMonth: "8", left: "3", start: "2026-10-20" }, ctx, money);
  assert.equal(p.ok, true);
  assert.equal(p.amount, 30);
  assert.equal(p.dueKey, "2026-10-23");
  assert.equal(
    p.text,
    "Zainab Camara starts Oct 20: 3 of 8 classes left this month, so the first invoice is $80.00 × 3 ÷ 8 = $30.00, due Oct 23. After that $80.00 every month: the next invoice is issued on the 25th and due on the 1st.",
  );
  assert.equal(firstInvoicePreview({ monthly: "85", perMonth: "8", left: "5", start: "2026-10-20" }, ctx, money).amount, 53.13);
});

test("first invoice input is checked", () => {
  const ctx = { studentName: "Z", dueDays: 3, issueDay: 25, dueDay: 1 };
  const ok = { monthly: "80", perMonth: "8", left: "3", start: "2026-10-20" };
  assert.equal(firstInvoicePreview({ ...ok, monthly: "" }, ctx, money).ok, false);
  assert.equal(firstInvoicePreview({ ...ok, monthly: "0" }, ctx, money).ok, false);
  assert.equal(firstInvoicePreview({ ...ok, left: "9" }, ctx, money).ok, false);
  assert.equal(firstInvoicePreview({ ...ok, left: "0" }, ctx, money).ok, false);
  assert.equal(firstInvoicePreview({ ...ok, perMonth: "7.5" }, ctx, money).ok, false);
  assert.equal(firstInvoicePreview({ ...ok, start: "" }, ctx, money).ok, false);
  assert.equal(firstInvoicePreview(ok, { ...ctx, studentName: "" }, money).ok, false);
});

/* ------------------------------------------------------------ new students -- */

test("new students: first invoices newest first, then enrollments without one", () => {
  const first1 = inv("f1", { kind: "first_month", student_ids: ["s1"], issued_date: new Date("2026-10-20T16:00:00Z"), first_class_date: "2026-10-20", classes_left: 3, classes_in_month: 8, total_amount: 30 });
  const first2 = inv("f2", { kind: "first_month", student_ids: ["s2"], issued_date: new Date("2026-09-28T16:00:00Z") });
  const cancelled = inv("f3", { kind: "first_month", student_ids: ["s9"], status: "cancelled", issued_date: new Date("2026-10-21T16:00:00Z") });
  const monthly = inv("m1", { kind: "monthly", student_ids: ["s8"] });
  const enrollments = [
    { id: "e1", studentId: "s1", parentId: "p1", studentName: "Amina", teacherName: "T", matchedAt: new Date("2026-10-01T16:00:00Z") }, // covered by f1
    { id: "e2", studentId: "s3", parentId: "p3", studentName: "Fatou", teacherName: "Mr Bah", matchedAt: new Date("2026-10-15T16:00:00Z") },
    { id: "e3", studentId: "", parentId: "p3", studentName: "No account", teacherName: "", matchedAt: new Date("2026-10-16T16:00:00Z") },
  ];
  const out = mergeNewStudents([first2, monthly, first1, cancelled], enrollments, new Map([["s1", "Ms Diallo"]]));
  assert.deepEqual(out.map((r) => r.key), ["f1", "enrollment_e2", "f2"]);
  assert.equal(out[0].startKey, "2026-10-20");
  assert.equal(out[0].teacherName, "Ms Diallo");
  assert.equal(out[1].invoice, null);
  assert.equal(out[1].teacherName, "Mr Bah");
});

test("new student status and worked example", () => {
  const paid = inv("a", { kind: "first_month", paid_amount: 100, status: "paid" });
  const late = inv("b", { kind: "first_month", due_date: utc("2026-10-10") });
  const waiting = inv("c", { kind: "first_month" });
  const row = (i: Invoice | null) => ({ key: "k", studentIds: [], parentId: "", startKey: null, teacherName: "", invoice: i, sortAt: 0 });
  assert.equal(newStudentStatus(row(paid), NOW).label, "Paid");
  assert.equal(newStudentStatus(row(late), NOW).label, "Overdue");
  assert.equal(newStudentStatus(row(waiting), NOW).label, "Waiting for payment");
  assert.equal(newStudentStatus(row(null), NOW).label, "No first invoice yet");
  const ex = workedExample(normalizeInvoice("a", { total_amount: 30, classes_left: 3, classes_in_month: 8, due_date: utc("2026-10-23") }), 80);
  assert.deepEqual(ex, { monthly: 80, classesInMonth: 8, classesLeft: 3, firstAmount: 30, dueKey: "2026-10-23" });
});
