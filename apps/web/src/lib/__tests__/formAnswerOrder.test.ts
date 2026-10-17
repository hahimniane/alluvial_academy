import assert from "node:assert/strict";
import { test } from "node:test";
import { buildFieldLayout, orderResponseEntries, storedOrder } from "../formAnswerOrder.ts";

test("map-shaped fields are ranked by their stored order, not by key order", () => {
  const layout = buildFieldLayout({
    zeta: { label: "Third", order: 3 },
    alpha: { label: "Second", order: 2 },
    mid: { label: "First", order: 1 },
  });
  assert.deepEqual(layout.order, { mid: 0, alpha: 1, zeta: 2 });
  assert.deepEqual(layout.labels, { zeta: "Third", alpha: "Second", mid: "First" });
});

test("order 0 is a real order, not a missing one", () => {
  assert.equal(storedOrder(0), 0);
  assert.equal(storedOrder("2"), 2);
  assert.equal(storedOrder(undefined), null);
  assert.equal(storedOrder("abc"), null);
  const layout = buildFieldLayout({ b: { label: "B", order: 1 }, a: { label: "A", order: 0 } });
  assert.deepEqual(layout.order, { a: 0, b: 1 });
});

test("list-shaped fields without an order keep their list position", () => {
  const layout = buildFieldLayout([
    { id: "q1", label: "One" },
    { id: "q2", question: "Two" },
    { label: "Three" },
  ]);
  assert.deepEqual(layout.order, { q1: 0, q2: 1, field_2: 2 });
  assert.equal(layout.labels.q2, "Two");
});

test("answers are shown in question order; unknown answers go last in stored order", () => {
  const order = buildFieldLayout({
    q_late: { label: "Late", order: 5 },
    q_early: { label: "Early", order: 1 },
    q_mid: { label: "Mid", order: 3 },
  }).order;
  const responses = { orphan_b: "x", q_late: "c", orphan_a: "y", q_early: "a", q_mid: "b" };
  assert.deepEqual(
    orderResponseEntries(responses, order).map(([id]) => id),
    ["q_early", "q_mid", "q_late", "orphan_b", "orphan_a"],
  );
});

test("equal orders fall back to the stored position, so the result is stable", () => {
  const layout = buildFieldLayout([
    { id: "first", label: "First", order: 1 },
    { id: "second", label: "Second", order: 1 },
  ]);
  assert.deepEqual(layout.order, { first: 0, second: 1 });
});
