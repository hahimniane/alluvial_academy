import test from "node:test";
import assert from "node:assert/strict";
import {
  adminRows,
  amountLeft,
  openPause,
  pauseForMonth,
  payLabel,
  payState,
  pausedLabel,
  previewText,
  shortDate,
  splitFee,
  staffCards,
  staffCsv,
  teacherRows,
  termInForce,
  termHistoryLines,
  type Payout,
  type StaffSummary,
} from "../finance/staff.ts";

const payout = (over: Partial<Payout> = {}): Payout => ({
  user_id: "t1",
  role: "teacher",
  month: "2026-09",
  amount_due: 206,
  amount_paid: 206,
  date_paid: "2026-10-03",
  method: "Mobile money",
  transfer_fee: 3,
  reference: "TX9",
  note: "",
  voided: false,
  history: [],
  ...over,
});

const summary = (): StaffSummary => ({
  month: "2026-09",
  final: true,
  admin_base: 1000,
  teachers: [
    { uid: "t1", name: "Aisha", hours: 20, gross: 210, penalties: 4, net: 206, final: true },
    { uid: "t2", name: "Omar", hours: 10, gross: 100, penalties: 0, net: 100, final: false },
  ],
  admins: [
    { uid: "a1", name: "Sajor", fixed: 300, pct: 5, share: 50, total: 350, paused: null },
    { uid: "a2", name: "Paused P", fixed: 0, pct: 0, share: 0, total: 0, paused: { reason: "Account deactivated Oct 3", auto: true } },
  ],
});

test("short dates", () => {
  assert.equal(shortDate("2026-10-03"), "Oct 3");
  assert.equal(shortDate("nope"), "nope");
});

test("pay state and labels", () => {
  assert.equal(payState(206, null), "unpaid");
  assert.equal(payState(206, payout({ voided: true })), "unpaid");
  assert.equal(payState(206, payout()), "paid");
  assert.equal(payState(206, payout({ amount_paid: 150 })), "partial");
  assert.equal(payLabel(206, null), "Unpaid");
  assert.equal(payLabel(206, payout()), "Paid Oct 3 · Mobile money · fee $3.00 · ref TX9");
  assert.equal(payLabel(206, payout({ amount_paid: 150, transfer_fee: 0, reference: "" })), "Paid $150.00 of $206.00 · $56.00 left · Oct 3 · Mobile money");
  assert.equal(amountLeft(206, payout({ amount_paid: 150 })), 56);
  assert.equal(amountLeft(206, payout({ voided: true })), 206);
});

test("a batch fee splits evenly to the cent", () => {
  assert.deepEqual(splitFee(10, 4), [2.5, 2.5, 2.5, 2.5]);
  assert.deepEqual(splitFee(1, 3), [0.34, 0.33, 0.33]);
  assert.equal(splitFee(1, 3).reduce((a, b) => a + b, 0).toFixed(2), "1.00");
  assert.deepEqual(splitFee(0, 2), [0, 0]);
  assert.deepEqual(splitFee(5, 0), []);
});

test("only final, unpaid teachers are payable; paused admins never are", () => {
  const s = summary();
  const none = new Map<string, Payout>();
  const t = teacherRows(s, none);
  assert.deepEqual(t.map((r) => r.payable), [true, false]);
  assert.match(t[1].blocked, /Estimate/);
  const a = adminRows(s, none);
  assert.deepEqual(a.map((r) => r.payable), [true, false]);
  assert.match(a[1].blocked, /paused/);
  const paid = teacherRows(s, new Map([["t1", payout()]]));
  assert.equal(paid[0].payable, false);
  const partial = teacherRows(s, new Map([["t1", payout({ amount_paid: 100 })]]));
  assert.equal(partial[0].payable, true);
});

test("summary cards", () => {
  const s = summary();
  const payouts = new Map([["t1", payout()]]);
  const t = teacherRows(s, payouts);
  const a = adminRows(s, payouts);
  const cards = staffCards(s, t, a);
  assert.equal(cards[0].value, "$306.00");
  assert.equal(cards[0].sub, "2 teachers · estimate");
  assert.equal(cards[1].value, "−$4.00");
  assert.equal(cards[1].sub, "1 teacher had money cut");
  assert.equal(cards[2].value, "$350.00");
  assert.equal(cards[3].value, "1 of 3"); // two teachers + one active admin
  assert.equal(cards[3].sub, "Transfer fees $3.00");
});

test("terms in force and pauses", () => {
  const terms = [{ from_month: "2026-01", fixed: 300, pct: 0 }, { from_month: "2026-06", fixed: 400, pct: 5 }];
  assert.equal(termInForce(terms, "2026-05")?.fixed, 300);
  assert.equal(termInForce(terms, "2026-10")?.fixed, 400);
  assert.equal(termInForce(terms, "2025-12"), null);
  const pauses = [{ from_month: "2026-03", until_month: "2026-05", reason: "Leave" }, { from_month: "2026-09", until_month: null, reason: "Account deactivated Sep 2", auto: true }];
  assert.equal(pauseForMonth(pauses, "2026-04")?.reason, "Leave");
  assert.equal(pauseForMonth(pauses, "2026-05"), null);
  assert.equal(openPause(pauses)?.from_month, "2026-09");
  assert.equal(pausedLabel(pauses[1]), "Paused since September · Account deactivated Sep 2 (automatic)");
});

test("preview text", () => {
  assert.equal(previewText(300, 5, 1000, "2026-10"), "For October: $300.00 + 5% of $1,000.00 = $350.00. The same terms carry into every month after, until you change them.");
  assert.match(previewText(300, 0, 1000, "2026-10"), /^For October: \$300\.00 \(fixed only\)\./);
  assert.match(previewText(300, 5, -400, "2026-10"), /5% of \$0\.00 = \$300\.00/);
});

test("pay history lines, newest first", () => {
  const lines = termHistoryLines(
    [{ from_month: "2026-01", fixed: 300, pct: 0, note: "Start" }, { from_month: "2026-06", fixed: 400, pct: 5, note: "Raise" }],
    [{ from_month: "2026-09", until_month: null, reason: "Leave" }]
  );
  assert.equal(lines.length, 3);
  assert.match(lines[0], /^Paused from September 2026/);
  assert.match(lines[2], /^From January 2026: \$300\.00 fixed, no share · Start/);
});

test("staff CSV", () => {
  const s = summary();
  const payouts = new Map([["t1", payout()]]);
  const csv = staffCsv("2026-09", teacherRows(s, payouts), adminRows(s, payouts), s).replace("﻿", "").trim().split("\r\n");
  assert.equal(csv[0], "Type,Name,Month,Owed,Paid,Left,Status,Date paid,Method,Transfer fee,Reference,Note");
  assert.equal(csv[1], "Teacher,Aisha,2026-09,206.00,206.00,0.00,paid,2026-10-03,Mobile money,3.00,TX9,");
  assert.match(csv[2], /^Teacher,Omar,2026-09,100\.00,0\.00,100\.00,estimate/);
  assert.match(csv[4], /^Administrator,Paused P,.*,paused,/);
});
