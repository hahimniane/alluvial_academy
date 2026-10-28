import test from "node:test";
import assert from "node:assert/strict";
import { cutOffStudents, invoiceCutoffKey, isBlockingInvoice, normalizeInvoice, type Invoice } from "../finance/invoices.ts";

// Thursday Oct 22 2026, 11am in New York
const NOW = new Date("2026-10-22T15:00:00Z");
const utc = (day: string) => new Date(`${day}T16:00:00Z`);

function inv(id: string, over: Record<string, unknown> = {}): Invoice {
  return normalizeInvoice(id, {
    invoice_number: `INV-${id}`,
    parent_id: "p1",
    student_ids: ["s1"],
    status: "pending",
    total_amount: 100,
    paid_amount: 0,
    due_date: utc("2026-10-01"),
    issued_date: utc("2026-09-25"),
    ...over,
  });
}

test("an unpaid invoice blocks from the day after it was due, or from its own cutoff", () => {
  assert.equal(invoiceCutoffKey(inv("a")), "2026-10-02");
  assert.equal(invoiceCutoffKey(inv("b", { access_cutoff_date: utc("2026-10-31") })), "2026-10-31");
  assert.equal(isBlockingInvoice(inv("a"), NOW), true);
  assert.equal(isBlockingInvoice(inv("b", { access_cutoff_date: utc("2026-10-31") }), NOW), false, "an extension lifts the block");
  assert.equal(isBlockingInvoice(inv("c", { due_date: utc("2026-10-22") }), NOW), false, "due today does not block yet");
  assert.equal(isBlockingInvoice(inv("d", { status: "paid", paid_amount: 100 }), NOW), false);
  assert.equal(isBlockingInvoice(inv("e", { paid_amount: 100 }), NOW), false, "fully paid even if the status lags");
  assert.equal(isBlockingInvoice(inv("f", { status: "cancelled" }), NOW), false);
  assert.equal(isBlockingInvoice(inv("g", { paid_amount: 40 }), NOW), true, "partly paid still blocks");
});

test("a student cut off by several months sees every blocking invoice, oldest first, with the total owed", () => {
  const invoices = [
    inv("oct", { due_date: utc("2026-10-01"), billing_month: "2026-10" }),
    inv("aug", { due_date: utc("2026-08-01"), billing_month: "2026-08", paid_amount: 30 }),
    inv("sep", { due_date: utc("2026-09-01"), billing_month: "2026-09" }),
    inv("sibling", { student_ids: ["s2"] }),
    inv("paid", { status: "paid", paid_amount: 100 }),
  ];
  const [row] = cutOffStudents([{ id: "s1", name: "Amina", guardianIds: ["p1"] }], invoices, NOW);
  assert.deepEqual(row.invoices.map((h) => h.inv.id), ["aug", "sep", "oct"]);
  assert.equal(row.owed, 270);
  assert.equal(row.sinceKey, "2026-08-02");
  assert.equal(row.parentId, "p1");
});

test("an invoice with no students blocks the whole family it was sent to, including an adult billed directly", () => {
  const family = inv("fam", { student_ids: [], parent_id: "p1" });
  const adult = inv("self", { student_ids: [], parent_id: "adult1" });
  const rows = cutOffStudents(
    [
      { id: "s1", name: "Amina", guardianIds: ["p1"] },
      { id: "s9", name: "Other family", guardianIds: ["p9"] },
      { id: "adult1", name: "Serigne", guardianIds: [] },
    ],
    [family, adult],
    NOW,
  );
  const by = new Map(rows.map((r) => [r.studentId, r]));
  assert.deepEqual(by.get("s1")?.invoices.map((h) => h.inv.id), ["fam"]);
  assert.deepEqual(by.get("adult1")?.invoices.map((h) => h.inv.id), ["self"]);
  assert.deepEqual(by.get("s9")?.invoices, [], "flagged but nothing found is shown with no invoices");
  assert.equal(rows[rows.length - 1].studentId, "s9", "students with no invoice found sort last");
});

test("an older invoice that names its students only on its lines blocks only them", () => {
  const lined = inv("lined", { student_ids: [], items: [{ description: "Tuition", total: 100, student_id: "s1" }] });
  const rows = cutOffStudents(
    [
      { id: "s1", name: "Amina", guardianIds: ["p1"] },
      { id: "s2", name: "Omar", guardianIds: ["p1"] },
    ],
    [lined],
    NOW,
  );
  const by = new Map(rows.map((r) => [r.studentId, r]));
  assert.deepEqual(by.get("s1")?.invoices.map((h) => h.inv.id), ["lined"]);
  assert.deepEqual(by.get("s2")?.invoices, []);
});

test("an old invoice with only a single student_id still stops the whole family, as the server does", () => {
  const old = inv("old", { student_ids: undefined, student_id: "s1", items: [{ description: "Tuition", total: 100 }] });
  const rows = cutOffStudents(
    [
      { id: "s1", name: "Amina", guardianIds: ["p1"] },
      { id: "s2", name: "Omar", guardianIds: ["p1"] },
    ],
    [old],
    NOW,
  );
  for (const r of rows) assert.deepEqual(r.invoices.map((h) => h.inv.id), ["old"], r.name);
});
