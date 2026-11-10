import { test } from "node:test";
import assert from "node:assert/strict";
import { decisionCounts, normalizeReviewStatus, reviewStatusLabel } from "../formReview.ts";

test("normalizes stored decisions", () => {
  assert.equal(normalizeReviewStatus("Accepted"), "accepted");
  assert.equal(normalizeReviewStatus(" in review "), "in review");
  assert.equal(normalizeReviewStatus("neutral"), "");
  assert.equal(normalizeReviewStatus(undefined), "");
});

test("labels match the app", () => {
  assert.equal(reviewStatusLabel("rejected"), "Rejected");
  assert.equal(reviewStatusLabel(""), "Not reviewed");
});

test("counts accepted, rejected and awaiting", () => {
  assert.deepEqual(decisionCounts(["accepted", "rejected", "seen", "", "accepted"]), { accepted: 2, rejected: 1, awaiting: 2 });
});
