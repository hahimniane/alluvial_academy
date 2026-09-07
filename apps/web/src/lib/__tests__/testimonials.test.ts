import test from "node:test";
import assert from "node:assert/strict";
import {
  DEFAULT_TESTIMONIALS,
  initialsOf,
  normalizeTestimonial,
  publishedTestimonials,
  toCategory,
} from "../testimonials.ts";

test("only published quotes with words and a name are shown, in order", () => {
  const rows = publishedTestimonials([
    { id: "b", quote: "Second", name: "B", sortOrder: 2 },
    { id: "hidden", quote: "Hidden", name: "H", active: false },
    { id: "blank", quote: "   ", name: "Nobody" },
    { id: "a", quote: "First", name: "A", sortOrder: 1, category: "parent" },
  ]);
  assert.deepEqual(rows.map((r) => r.id), ["a", "b"]);
  assert.equal(rows[0].category, "parent");
});

test("the built-in quotes fill in until something is published", () => {
  assert.equal(publishedTestimonials(null), DEFAULT_TESTIMONIALS);
  assert.equal(publishedTestimonials([{ id: "x", quote: "q", name: "n", active: false }]), DEFAULT_TESTIMONIALS);
});

test("unknown categories become community, and fields are trimmed", () => {
  assert.equal(toCategory("Parent"), "parent");
  assert.equal(toCategory("alumni"), "other");
  const row = normalizeTestimonial("id", { quote: "  hi  ", name: " Amina ", sortOrder: "3" });
  assert.equal(row.quote, "hi");
  assert.equal(row.name, "Amina");
  assert.equal(row.sortOrder, 3);
  assert.equal(row.active, true);
});

test("initials come from the first two words", () => {
  assert.equal(initialsOf("Zainab Sall"), "ZS");
  assert.equal(initialsOf("  amina "), "A");
  assert.equal(initialsOf(""), "");
});
