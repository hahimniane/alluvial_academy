import test from "node:test";
import assert from "node:assert/strict";
import {
  coversPeriod,
  discountAmountFor,
  discountLabel,
  draftToDiscount,
  discountToDraft,
  emptyDiscountDraft,
  formatStartDate,
  fromDateInput,
  validateDiscount,
  type DiscountDraft,
  type StudentDiscount,
} from "../studentDiscount.ts";

const draft = (over: Partial<DiscountDraft> = {}): DiscountDraft => ({
  ...emptyDiscountDraft(new Date("2026-08-15T00:00:00Z")),
  value: "20",
  ...over,
});

const discount = (over: Partial<StudentDiscount> = {}): StudentDiscount => ({
  mode: "percent",
  value: 20,
  duration: "months",
  months: 3,
  startDate: fromDateInput("2026-08-15"),
  reason: "Sibling discount",
  ...over,
});

test("validation rejects what the spec forbids", () => {
  assert.equal(validateDiscount(draft()), null);
  assert.match(validateDiscount(draft({ value: "" }))!, /amount/);
  assert.match(validateDiscount(draft({ value: "0" }))!, /more than zero/);
  assert.match(validateDiscount(draft({ value: "-5" }))!, /more than zero/);
  assert.match(validateDiscount(draft({ value: "101" }))!, /100%/);
  // A fixed discount above 100 is a real amount, not an error.
  assert.equal(validateDiscount(draft({ mode: "fixed", value: "150" })), null);
  assert.match(validateDiscount(draft({ months: "0" }))!, /whole number/);
  assert.match(validateDiscount(draft({ months: "2.5" }))!, /whole number/);
  assert.match(validateDiscount(draft({ reason: "  " }))!, /reason/);
  assert.match(validateDiscount(draft({ startDate: "" }))!, /date/);
});

test("months are not required for an ongoing discount", () => {
  assert.equal(validateDiscount(draft({ duration: "ongoing", months: "" })), null);
  const built = draftToDiscount(draft({ duration: "ongoing", months: "" }));
  assert.equal("months" in built, false, "ongoing discounts carry no month count");
});

test("a draft survives a round trip", () => {
  const original = discount({ note: "Approved by admin" });
  const rebuilt = draftToDiscount(discountToDraft(original));
  assert.deepEqual(rebuilt, original);
});

test("an empty note is dropped rather than stored blank", () => {
  const built = draftToDiscount(draft({ note: "   " }));
  assert.equal("note" in built, false);
});

test("periods are month-granular, so the start day never widens the window", () => {
  // Real billing periods are the 1st of a month. Comparing days here let a
  // discount starting Aug 15 reach a fourth month.
  const d = discount({ startDate: fromDateInput("2026-08-15"), months: 3 });
  assert.equal(coversPeriod(d, fromDateInput("2026-08-01")), true);
  assert.equal(coversPeriod(d, fromDateInput("2026-09-01")), true);
  assert.equal(coversPeriod(d, fromDateInput("2026-10-01")), true);
  assert.equal(coversPeriod(d, fromDateInput("2026-11-01")), false);
  assert.equal(coversPeriod(d, fromDateInput("2026-07-01")), false);
});

test("the window runs from the start date, for the number of months given", () => {
  const d = discount({ months: 3 });
  // Month 1 is the start month, even for a period that begins earlier in it.
  assert.equal(coversPeriod(d, fromDateInput("2026-08-01")), true);
  assert.equal(coversPeriod(d, fromDateInput("2026-08-15")), true);
  assert.equal(coversPeriod(d, fromDateInput("2026-09-15")), true);
  assert.equal(coversPeriod(d, fromDateInput("2026-10-15")), true);
  assert.equal(coversPeriod(d, fromDateInput("2026-11-15")), false, "the fourth month is past a 3-month window");
});

test("periods before the start month are never discounted", () => {
  const d = discount();
  assert.equal(coversPeriod(d, fromDateInput("2026-07-31")), false);
  assert.equal(coversPeriod(d, fromDateInput("2026-01-01")), false);
});

test("an ongoing discount has no end", () => {
  const d = discount({ duration: "ongoing", months: undefined });
  assert.equal(coversPeriod(d, fromDateInput("2026-08-15")), true);
  assert.equal(coversPeriod(d, fromDateInput("2031-08-15")), true);
  assert.equal(coversPeriod(d, fromDateInput("2026-07-01")), false);
});

test("a window crossing a year boundary counts months, not calendar years", () => {
  const d = discount({ startDate: fromDateInput("2026-11-15"), months: 4 });
  assert.equal(coversPeriod(d, fromDateInput("2026-12-15")), true);
  assert.equal(coversPeriod(d, fromDateInput("2027-01-15")), true);
  assert.equal(coversPeriod(d, fromDateInput("2027-02-15")), true);
  assert.equal(coversPeriod(d, fromDateInput("2027-03-15")), false);
});

test("percent and fixed both come off the monthly total", () => {
  assert.equal(discountAmountFor(discount({ mode: "percent", value: 20 }), 100), 20);
  assert.equal(discountAmountFor(discount({ mode: "fixed", value: 30 }), 100), 30);
  assert.equal(discountAmountFor(discount({ mode: "percent", value: 100 }), 87.5), 87.5);
});

test("a discount never exceeds the total or turns into credit", () => {
  assert.equal(discountAmountFor(discount({ mode: "fixed", value: 30 }), 20), 20);
  assert.equal(discountAmountFor(discount({ mode: "fixed", value: 30 }), 0), 0);
  assert.equal(discountAmountFor(discount({ mode: "fixed", value: 30 }), -5), 0);
});

test("percentages land on whole cents", () => {
  // 33% of 19.99 is 6.5967 — it must not reach an invoice as 6.596700000000001.
  const amount = discountAmountFor(discount({ mode: "percent", value: 33 }), 19.99);
  assert.equal(amount, 6.6);
  assert.equal(Number.isInteger(Math.round(amount * 100)), true);
  assert.equal(discountAmountFor(discount({ mode: "percent", value: 10 }), 0.05), 0.01);
});

test("labels read the way the design writes them", () => {
  assert.equal(discountLabel(discount({ mode: "percent", value: 20, months: 3 })), "20% off · first 3 months");
  assert.equal(discountLabel(discount({ mode: "fixed", value: 30, months: 1 })), "$30 off · first 1 month");
  assert.equal(discountLabel(discount({ duration: "ongoing" })), "20% off · ongoing");
  assert.equal(discountLabel(discount({ mode: "fixed", value: 12.5, duration: "ongoing" })), "$12.50 off · ongoing");
  assert.equal(formatStartDate(fromDateInput("2026-08-15")), "Aug 15, 2026");
});

test("a date input round-trips without shifting a day", () => {
  assert.equal(discountToDraft(discount({ startDate: fromDateInput("2026-01-01") })).startDate, "2026-01-01");
  assert.equal(discountToDraft(discount({ startDate: fromDateInput("2026-12-31") })).startDate, "2026-12-31");
});
