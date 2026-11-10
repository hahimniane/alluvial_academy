import assert from "node:assert/strict";
import { test } from "node:test";
import { leaderTitle } from "../leaderTitle.ts";

test("a leader with a real job title shows it", () => {
  assert.equal(leaderTitle("admin", "  Head of Admissions "), "Head of Admissions");
  assert.equal(leaderTitle("super_admin", "Director"), "Director");
});

test("a generic or missing title falls back to the role label", () => {
  assert.equal(leaderTitle("admin", "Admin"), null);
  assert.equal(leaderTitle("admin", "ADMINISTRATOR"), null);
  assert.equal(leaderTitle("admin", ""), null);
  assert.equal(leaderTitle("admin", undefined), null);
});

test("non-leaders never show a title", () => {
  assert.equal(leaderTitle("teacher", "Head Teacher"), null);
  assert.equal(leaderTitle("parent", "Admin"), null);
  assert.equal(leaderTitle(undefined, "Director"), null);
});
