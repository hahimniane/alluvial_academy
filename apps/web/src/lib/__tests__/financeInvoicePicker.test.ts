import { test } from "node:test";
import assert from "node:assert/strict";
import { invoiceMonthOptions, looksLikeStudentCode, matchFamilies } from "../finance/invoicePicker.ts";

test("months: two ahead, this month and twelve back; closed months listed but flagged", () => {
  const opts = invoiceMonthOptions("2026-11", new Set(["2026-10"]));
  assert.equal(opts.length, 15);
  assert.equal(opts[0].month, "2027-01");
  assert.equal(opts[2].month, "2026-11");
  assert.ok(opts.some((o) => o.month === "2026-09" && !o.closed), "September can be billed");
  assert.ok(opts.some((o) => o.month === "2026-08"));
  assert.equal(opts.find((o) => o.month === "2026-10")?.closed, true);
  assert.equal(opts[opts.length - 1].month, "2025-11");
});

const fam = (id: string, name: string, email: string, phone: string, code = "") => ({ id, name, email, phone, code });
const users = [
  fam("a", "Sadou Diallo", "dllsaadou@gmail.com", "5565996298767"),
  fam("b", "Mariama Barry", "m.barry@example.com", "16465551234"),
  fam("c", "Adult Student", "adult@example.com", "", "ibrahima.sow"),
];

test("search: name, email, phone with or without country code, Student ID, child's Student ID", () => {
  assert.deepEqual(matchFamilies(users, "sadou").map((u) => u.id), ["a"]);
  assert.deepEqual(matchFamilies(users, "m.barry@").map((u) => u.id), ["b"]);
  assert.deepEqual(matchFamilies(users, "+55 65996298767").map((u) => u.id), ["a"]);
  assert.deepEqual(matchFamilies(users, "65996298767").map((u) => u.id), ["a"]);
  assert.deepEqual(matchFamilies(users, "(646) 555-1234").map((u) => u.id), ["b"]);
  assert.deepEqual(matchFamilies(users, "Ibrahima.Sow").map((u) => u.id), ["c"]);
  assert.deepEqual(matchFamilies(users, "3boubacar.diallo", new Set(["a"])).map((u) => u.id), ["a"]);
  assert.deepEqual(matchFamilies(users, "12"), [], "too few digits is not a phone search");
  assert.deepEqual(matchFamilies(users, ""), []);
});

test("Student ID lookups only for code-shaped text", () => {
  assert.equal(looksLikeStudentCode("3boubacar.diallo"), true);
  assert.equal(looksLikeStudentCode("amadou.diallo"), true);
  assert.equal(looksLikeStudentCode("Sadou Diallo"), false);
  assert.equal(looksLikeStudentCode("6599629"), false);
});
