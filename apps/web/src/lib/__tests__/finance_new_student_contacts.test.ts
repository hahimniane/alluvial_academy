import test from "node:test";
import assert from "node:assert/strict";
import { readFamilyBillingLite, rowMonthlyAmount, studentCodeOf } from "../finance/newStudentContacts.ts";

test("the Student ID is the student_code, else the kiosk code", () => {
  assert.equal(studentCodeOf({ student_code: " 1famata.momo " }), "1famata.momo");
  assert.equal(studentCodeOf({ studentCode: "A7Q4-MZ2N" }), "A7Q4-MZ2N");
  assert.equal(studentCodeOf({ kiosk_code: "K-77" }), "K-77");
  assert.equal(studentCodeOf({ student_code: "A1", kiosk_code: "K-77" }), "A1");
  assert.equal(studentCodeOf({}), "");
});

test("a family_billing doc reads its monthly amount and waiting first invoices", () => {
  const lite = readFamilyBillingLite({
    monthly_amount: 0,
    pending_first_invoices: { s1: { monthly_amount: 80, student_id: "s1" }, s2: { monthly_amount: 0 }, s3: "junk" },
  });
  assert.deepEqual(lite, { monthly: 0, pending: { s1: 80 } });
  assert.deepEqual(readFamilyBillingLite({ monthly_amount: 120 }), { monthly: 120, pending: {} });
});

test("the row shows the billed amount first, then the amount entered at registration", () => {
  assert.equal(rowMonthlyAmount({ monthly: 120, pending: { s1: 80 } }, ["s1"]), 120);
  assert.equal(rowMonthlyAmount({ monthly: 0, pending: { s1: 80 } }, ["s1"]), 80);
  assert.equal(rowMonthlyAmount({ monthly: 0, pending: { s1: 80.5, s2: 40 } }, ["s1", "s2"]), 120.5);
});

test("nothing set shows no amount rather than $0", () => {
  assert.equal(rowMonthlyAmount(undefined, ["s1"]), null);
  assert.equal(rowMonthlyAmount({ monthly: 0, pending: {} }, ["s1"]), null);
  assert.equal(rowMonthlyAmount({ monthly: 0, pending: { s9: 50 } }, ["s1"]), null);
});
