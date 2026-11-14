import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { FR_PUBLIC_HOME } from "../translations/public/home.ts";
import { FR_PUBLIC_SHARED } from "../translations/public/shared.ts";
import { TESTIMONIAL_CATEGORIES } from "../testimonials.ts";

/**
 * Every English string the home, about and contact pages (and the header and
 * footer around them) hand to t() must have a French entry. Without this a
 * string wrapped in t() but never translated shows up in English in the middle
 * of a French page and nobody notices.
 */

const read = (fromSrc: string) => readFileSync(fileURLToPath(new URL(`../../${fromSrc}`, import.meta.url)), "utf8");

const FILES = [
  "components/MarketingHome.tsx",
  "components/SiteHeader.tsx",
  "components/SiteFooter.tsx",
  "components/AboutContent.tsx",
  "components/ContactForm.tsx",
  "app/contact/page.tsx",
];

/**
 * Text kept in module constants (menu items, cards, the sample schedule) is
 * English in the array and translated where it is rendered, as t(item.label).
 * These are the fields rendered that way in each file.
 */
const CONSTANT_FIELDS: Record<string, string[]> = {
  "components/MarketingHome.tsx": ["title", "subtitle", "body", "label", "subject", "track"],
  "components/SiteHeader.tsx": ["label", "title", "subtitle"],
  "components/SiteFooter.tsx": ["label"],
  "components/AboutContent.tsx": ["title", "body"],
};

const unescape = (raw: string) => raw.replace(/\\(.)/g, "$1");

/** String literals given as the first argument of t( … ). */
function literalKeys(source: string): string[] {
  const keys: string[] = [];
  const call = /(?<![\w$.])t\(\s*(?:"((?:[^"\\\n]|\\.)*)"|'((?:[^'\\\n]|\\.)*)'|`((?:[^`\\]|\\.)*)`)/g;
  for (const match of source.matchAll(call)) {
    const backtick = match[3];
    if (backtick !== undefined && backtick.includes("${")) continue;
    keys.push(unescape(match[1] ?? match[2] ?? backtick ?? ""));
  }
  return keys;
}

const stringsIn = (block: string) => [...block.matchAll(/"((?:[^"\\\n]|\\.)*)"/g)].map((match) => unescape(match[1]));

function constantKeys(source: string, fields: string[]): string[] {
  const field = new RegExp(`\\b(?:${fields.join("|")}):\\s*"((?:[^"\\\\\\n]|\\\\.)*)"`, "g");
  return [...source.matchAll(field)].map((match) => unescape(match[1]));
}

/** The string arrays the home page translates item by item. */
function homeListKeys(source: string): string[] {
  const subjects = source.match(/const subjects = \[([\s\S]*?)\];/);
  assert.ok(subjects, "the subjects list is still in MarketingHome.tsx");
  const defaults = [...source.matchAll(/defaults:\s*\[([^\]]*)\]/g)].flatMap((match) => stringsIn(match[1]));
  assert.ok(defaults.length > 0, "the pricing cards still carry their default bullets");
  return [...stringsIn(subjects[1]), ...defaults];
}

/** Bullets of the pricing shown until an admin has published their own. */
function fallbackPricingBullets(): string[] {
  const source = read("lib/publicSiteCms.ts");
  const block = source.match(/export const fallbackPricing[\s\S]*?\n};/);
  assert.ok(block, "fallbackPricing is still in publicSiteCms.ts");
  return [...block[0].matchAll(/bullets:\s*\[([^\]]*)\]/g)].flatMap((match) => stringsIn(match[1]));
}

const display = (key: string) => (key.includes("|") ? key.slice(0, key.indexOf("|")) : key);
const placeholders = (text: string) => [...text.matchAll(/\{(\w+)\}/g)].map((match) => match[0]);
const french = (key: string): string | undefined => FR_PUBLIC_HOME[key] ?? FR_PUBLIC_SHARED[key];

function usedKeys(): Map<string, string> {
  const used = new Map<string, string>();
  for (const file of FILES) {
    const source = read(file);
    const keys = [...literalKeys(source), ...constantKeys(source, CONSTANT_FIELDS[file] ?? [])];
    if (file === "components/MarketingHome.tsx") keys.push(...homeListKeys(source));
    for (const key of keys) if (!used.has(key)) used.set(key, file);
  }
  for (const bullet of fallbackPricingBullets()) if (!used.has(bullet)) used.set(bullet, "lib/publicSiteCms.ts");
  for (const { label } of TESTIMONIAL_CATEGORIES) if (!used.has(label)) used.set(label, "lib/testimonials.ts");
  return used;
}

test("the extractor reads every quote style and skips interpolated templates", () => {
  const sample = [
    't("Double")',
    "t('Single')",
    "t(`Backtick`)",
    "t(`Hello ${name}`)",
    't("End|verb")',
    't("{count} left", { count })',
    'event.preventDefault("not a key")',
    "t(variable)",
  ].join("\n");
  assert.deepEqual(literalKeys(sample), ["Double", "Single", "Backtick", "End|verb", "{count} left"]);
  assert.equal(display("End|verb"), "End");
});

test("every component actually translates something", () => {
  for (const file of FILES) {
    assert.ok(literalKeys(read(file)).length > 0, `${file} has no t("…") call`);
  }
});

test("every string given to t() has a French translation", () => {
  const missing = [...usedKeys()]
    .filter(([key]) => french(key) === undefined)
    .map(([key, file]) => `${file}: "${display(key)}"${key.includes("|") ? ` (key "${key}")` : ""}`);
  assert.deepEqual(missing, []);
});

test("no French value is empty", () => {
  const empty = Object.entries(FR_PUBLIC_HOME)
    .filter(([, value]) => value.trim() === "")
    .map(([key]) => key);
  assert.deepEqual(empty, []);
  for (const key of usedKeys().keys()) assert.notEqual((french(key) ?? "x").trim(), "", `"${key}" is empty`);
});

test("every {placeholder} of a key is kept in its French", () => {
  const keys = new Set([...Object.keys(FR_PUBLIC_HOME), ...usedKeys().keys()]);
  const dropped: string[] = [];
  for (const key of keys) {
    const value = french(key);
    if (value === undefined) continue;
    for (const name of placeholders(key)) if (!value.includes(name)) dropped.push(`"${key}" lost ${name}`);
    for (const name of placeholders(value)) if (!key.includes(name)) dropped.push(`"${key}" gained ${name}`);
  }
  assert.deepEqual(dropped, []);
});
