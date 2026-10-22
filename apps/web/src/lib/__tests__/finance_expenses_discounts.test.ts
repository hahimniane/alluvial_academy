import test from "node:test";
import assert from "node:assert/strict";
import {
  buildActiveDiscounts,
  buildBases,
  creditStatusLabel,
  creditsOwed,
  discountsCostPerMonth,
  discountsYearToDate,
  periodStartOf,
  readCredit,
  readHolder,
  sortCredits,
  yearSoFarSub,
} from "../finance/discounts.ts";

const stamp = (iso: string) => ({ toDate: () => new Date(iso) });

const student = (id: string, discount: Record<string, unknown>, parent = "p1") =>
  readHolder(id, { user_type: "student", first_name: id, last_name: "Diallo", parent_ids: [parent], discount: { startDate: stamp("2026-08-15T00:00:00Z"), reason: "Sibling discount", ...discount } })!;

const family = (id: string, discount: Record<string, unknown>, kids = ["s1", "s2"]) =>
  readHolder(id, { user_type: "parent", first_name: "Fatou", last_name: "Diallo", children_ids: kids, discount: { startDate: stamp("2026-08-15T00:00:00Z"), reason: "Referral", scope: "family", ...discount } })!;

test("reads a discount holder and ignores one without a usable discount", () => {
  assert.equal(readHolder("x", { user_type: "student", discount: { mode: "percent" } }), null);
  assert.equal(readHolder("x", { user_type: "student" }), null);
  const h = student("s1", { mode: "fixed", value: 10, duration: "ongoing" });
  assert.equal(h.name, "s1 Diallo");
  assert.deepEqual(h.parentIds, ["p1"]);
});

test("bases come from active plans; a family monthly amount wins and splits across students", () => {
  const bases = buildBases(
    [{ parentId: "p1", items: [{ studentId: "s1", total: 100 }, { studentId: "s2", total: 50 }] }],
    [],
  );
  assert.equal(bases.byStudent.get("s1"), 100);
  assert.equal(bases.byFamily.get("p1"), 150);

  const withFamily = buildBases(
    [{ parentId: "p1", items: [{ studentId: "s1", total: 100 }] }],
    [{ parentId: "p1", monthlyAmount: 90, studentIds: ["s1", "s2"] }],
  );
  assert.equal(withFamily.byFamily.get("p1"), 90);
  assert.equal(withFamily.byStudent.get("s1"), 45);
});

test("student percent and fixed discounts price against the student's monthly amount", () => {
  const bases = buildBases([{ parentId: "p1", items: [{ studentId: "s1", total: 80 }, { studentId: "s2", total: 60 }] }], []);
  const rows = buildActiveDiscounts({
    month: "2026-10",
    holders: [
      student("s1", { mode: "percent", value: 25, duration: "ongoing" }),
      student("s2", { mode: "fixed", value: 100, duration: "ongoing" }),
    ],
    parentNames: new Map([["p1", "Fatou Diallo"]]),
    bases,
  });
  assert.deepEqual(rows.map((r) => [r.family, r.appliesTo, r.perMonth]), [
    ["Fatou Diallo", "s1 Diallo", 20],
    ["Fatou Diallo", "s2 Diallo", 60],
  ]);
  assert.equal(rows[0].kind, "25% off · ongoing");
});

test("a family discount comes off once, after the students' own discounts", () => {
  const bases = buildBases([{ parentId: "p1", items: [{ studentId: "s1", total: 100 }, { studentId: "s2", total: 100 }] }], []);
  const rows = buildActiveDiscounts({
    month: "2026-10",
    holders: [student("s1", { mode: "fixed", value: 20, duration: "ongoing" }), family("p1", { mode: "percent", value: 10, duration: "ongoing" })],
    parentNames: new Map([["p1", "Fatou Diallo"]]),
    bases,
  });
  const fam = rows.find((r) => r.appliesTo.startsWith("Whole family"));
  assert.equal(fam?.appliesTo, "Whole family (2 children)");
  assert.equal(fam?.perMonth, 18);
});

test("only discounts covering the month are active; a window ends after its months", () => {
  const bases = buildBases([{ parentId: "p1", items: [{ studentId: "s1", total: 100 }] }], []);
  const holders = [student("s1", { mode: "percent", value: 10, duration: "months", months: 2 })];
  const parentNames = new Map([["p1", "Fatou Diallo"]]);
  assert.equal(buildActiveDiscounts({ month: "2026-07", holders, parentNames, bases }).length, 0);
  assert.equal(buildActiveDiscounts({ month: "2026-08", holders, parentNames, bases }).length, 1);
  assert.equal(buildActiveDiscounts({ month: "2026-09", holders, parentNames, bases }).length, 1);
  assert.equal(buildActiveDiscounts({ month: "2026-10", holders, parentNames, bases }).length, 0);
});

test("a family discount on a child, or a student discount on a parent, is not listed", () => {
  const bases = buildBases([], []);
  const odd = [
    readHolder("s9", { user_type: "student", discount: { mode: "fixed", value: 5, duration: "ongoing", scope: "family", startDate: stamp("2026-08-01T00:00:00Z"), reason: "x" } })!,
    readHolder("p9", { user_type: "parent", discount: { mode: "fixed", value: 5, duration: "ongoing", startDate: stamp("2026-08-01T00:00:00Z"), reason: "x" } })!,
  ];
  assert.equal(buildActiveDiscounts({ month: "2026-10", holders: odd, parentNames: new Map(), bases }).length, 0);
});

test("with no known monthly amount a fixed discount shows its value and a percentage shows nothing", () => {
  const rows = buildActiveDiscounts({
    month: "2026-10",
    holders: [student("s1", { mode: "fixed", value: 10, duration: "ongoing" }), student("s2", { mode: "percent", value: 10, duration: "ongoing" })],
    parentNames: new Map(),
    bases: buildBases([], []),
  });
  assert.deepEqual(rows.map((r) => r.perMonth), [10, null]);
  assert.deepEqual(discountsCostPerMonth(rows), { total: 10, families: 1, unknown: 1 });
});

test("period start is the first of the month in UTC", () => {
  assert.equal(periodStartOf("2026-10").toISOString(), "2026-10-01T00:00:00.000Z");
});

test("credits: read, label, sort open first, total what is owed", () => {
  const credits = [
    readCredit("c1", { parent_id: "p1", amount: 40, reason: "Left Oct 15", status: "open", created_at: stamp("2026-10-15T10:00:00Z") }),
    readCredit("c2", { parent_id: "p2", amount: 10, status: "used", created_at: stamp("2026-10-18T10:00:00Z") }),
    readCredit("c3", { parent_id: "p1", amount: 2.5, status: "open", created_at: stamp("2026-10-19T10:00:00Z") }),
    readCredit("c4", { parent_id: "p3", amount: 5 }),
  ];
  assert.deepEqual(sortCredits(credits).map((c) => c.id), ["c3", "c1", "c4", "c2"]);
  assert.deepEqual(creditsOwed(credits), { total: 47.5, families: 2 });
  assert.equal(creditStatusLabel("open"), "Waiting for next invoice");
  assert.equal(creditStatusLabel("refunded"), "Refunded");
  assert.equal(creditStatusLabel("cancelled"), "Cancelled");
});

test("year to date adds the months up to the selected one", () => {
  const byMonth = { "2026-01": 10, "2026-08": 20, "2026-09": 5.5, "2026-10": 4.5, "2026-11": 100 };
  assert.equal(discountsYearToDate(byMonth, "2026-10"), 40);
  assert.equal(discountsYearToDate(byMonth, "2026-08"), 30);
  assert.equal(yearSoFarSub("2026-10"), "Jan – Oct");
  assert.equal(yearSoFarSub("2026-01"), "January");
});
