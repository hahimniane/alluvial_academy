import assert from "node:assert/strict";
import { test } from "node:test";
import {
  allocationText,
  chatFor,
  doneText,
  formatPhone,
  invoiceOption,
  levelLabel,
  proofView,
  shortDate,
  signedUsd,
  splitTransactions,
  usd,
  waitingKind,
  whoText,
  type BankTxn,
  type Proof,
} from "../finance/bank.ts";

const txn = (id: string, date: string, amount: number, direction: "in" | "out", match: BankTxn["match"], extra: Partial<BankTxn> = {}): BankTxn => ({
  id, date, month: date.slice(0, 7), amount, direction, description: id, match, ...extra,
});

const D = [
  txn("d1", "2026-10-20", 160, "in", { status: "suggested", level: "exact", allocations: [{ invoice_id: "i1", amount: 160, number: "INV-2026-0101", family: "Seydou Sow", month: "2026-10" }] }),
  txn("d5", "2026-10-16", 75, "in", { status: "none", level: "none" }),
  txn("d6", "2026-10-14", 149.9, "out", { status: "suggested", level: "likely", recurring_cost_id: "c1", recurring_cost_name: "Zoom (3 licences)" }),
  txn("d7", "2026-10-12", 612.4, "in", { status: "ignored", level: "auto", why: "Card payments, already recorded from Stripe" }),
  txn("d8", "2026-10-05", 36, "out", { status: "confirmed", level: "auto", why: "Matched to Google Workspace for this month" }),
  txn("d9", "2026-10-03", 20, "out", { status: "none", level: "none", why: "Not matched to a recurring cost" }),
  txn("old", "2026-09-28", 90, "in", { status: "none", level: "none" }),
  txn("gone", "2026-10-02", 50, "in", { status: "none" }, { removed: true }),
];

test("waiting items span months; totals and tables are for the chosen month", () => {
  const s = splitTransactions([...D, D[0]], "2026-10");
  assert.deepEqual(s.waiting.map((t) => t.id), ["d1", "d5", "d6", "old"]);
  assert.equal(s.depositCount, 3); // d1, d5, d7 (the removed one and September's are out)
  assert.equal(Math.round(s.moneyIn * 100) / 100, 847.4);
  assert.deepEqual(s.done.map((t) => t.id), ["d7", "d8"]);
  assert.deepEqual(s.other.map((t) => t.id), ["d9"]);
});

test("a charge is a recurring-cost question; a deposit with a suggestion is an invoice one", () => {
  assert.equal(waitingKind(D[0]), "invoice");
  assert.equal(waitingKind(D[1]), "unmatched");
  assert.equal(waitingKind(D[2]), "recurring");
});

test("levels read the way the prototype does", () => {
  assert.deepEqual(levelLabel({ status: "suggested", level: "exact" }), { text: "Exact match", tone: "ok" });
  assert.equal(levelLabel({ status: "suggested", level: "likely", new_payer: true }).text, "Likely — new payer");
  assert.equal(levelLabel({ status: "suggested", level: "split" }).text, "Likely — split");
});

test("money and dates", () => {
  assert.equal(usd(1234.5), "$1,234.50");
  assert.equal(signedUsd(D[2]), "−$149.90");
  assert.equal(signedUsd(D[0]), "+$160.00");
  assert.equal(shortDate("2026-10-05"), "Oct 5");
});

test("allocation and matched text", () => {
  assert.equal(allocationText(D[0].match.allocations![0]), "INV-2026-0101 · Seydou Sow · October · $160.00");
  assert.equal(doneText(D[3]), "Card payments, already recorded from Stripe");
  assert.equal(doneText(txn("m", "2026-10-01", 10, "in", { status: "ignored", level: "none" })), "Marked as not tuition (other income)");
  assert.equal(
    doneText(txn("c", "2026-10-20", 320, "in", { status: "confirmed", level: "split", allocations: [{ invoice_id: "a", amount: 160, number: "INV-1" }, { invoice_id: "b", amount: 160, number: "INV-2" }] })),
    "Matched to INV-1 ($160.00) + INV-2 ($160.00)",
  );
  assert.equal(doneText(txn("h", "2026-10-20", 75, "in", { status: "manual", allocations: [{ invoice_id: "a", amount: 75, number: "INV-9" }] })), "Matched by hand to INV-9 ($75.00)");
  assert.equal(doneText(txn("z", "2026-10-14", 149.9, "out", { status: "confirmed", recurring_cost_name: "Zoom" })), "Used as October’s Zoom amount");
});

const proof = (status: Proof["status"], extra: Partial<Proof> = {}): Proof => ({
  id: "p", from_phone: "+16465550143", extracted: { amount: 160, sender: "Seydou Sow" }, status, replies: [], ...extra,
});

test("a matched proof can be confirmed, a waiting one cannot", () => {
  const matched = proofView(proof("matched"), D[0], "INV-2026-0101 (October, $160.00)");
  assert.equal(matched.canConfirm, true);
  assert.equal(matched.status, "Matches the bank deposit of Oct 20");
  assert.match(matched.detail, /\+\$160\.00 from/);
  const waiting = proofView(proof("waiting_bank"));
  assert.equal(waiting.canConfirm, false);
  assert.match(waiting.detail, /Nothing has reached the bank yet/);
});

test("only an unknown sender can be linked to a family", () => {
  assert.equal(proofView(proof("unknown_sender")).canLink, true);
  assert.equal(proofView(proof("matched")).canLink, false);
  assert.equal(proofView(proof("duplicate")).tone, "mute");
  assert.equal(proofView(proof("confirmed")).tone, "ok");
});

test("the chat shows the picture, then only what was really sent", () => {
  assert.deepEqual(chatFor(proof("waiting_bank")).map((b) => [b.mine, b.kind]), [[false, "image"]]);
  const sent = chatFor(proof("waiting_bank", { replies: [{ at: "2026-10-20T20:14:00Z", text: "Thanks, Seydou." }] }));
  assert.equal(sent.length, 2);
  assert.equal(sent[1].mine, true);
  assert.equal(sent[1].text, "Thanks, Seydou.");
});

test("who sent it and phone display", () => {
  assert.equal(whoText(proof("matched", { parent_name: "Seydou Sow" })), "Seydou Sow (parent)");
  assert.equal(whoText(proof("unknown_sender")), "Unknown number");
  assert.equal(formatPhone("+16465550143"), "+1 (646) 555-0143");
  assert.equal(formatPhone("+224621550188"), "+224621550188");
});

test("manual-match options name the invoice, family, month and balance", () => {
  assert.deepEqual(invoiceOption({ id: "i", number: "INV-1", month: "2026-09", balance: 160, family: "Conde" }), { id: "i", label: "INV-1 · Conde · September 2026 · owes $160.00" });
});
