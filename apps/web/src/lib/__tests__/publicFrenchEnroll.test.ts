import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { FR_PUBLIC_ENROLL } from "../translations/public/enroll.ts";
import { FR_PUBLIC_SHARED } from "../translations/public/shared.ts";
import { CLASS_TYPES, DAYS, SESSION_MINUTES, TIME_BLOCKS, sessionLabel } from "../enrollmentDomain.ts";

/**
 * /enroll and /programs in French. Every string the two pages hand to `t()`
 * must have a French entry, including the ones that reach it through a
 * variable (a subject, a level, a day). And the enrollment that gets stored
 * must not pass through `t()` at all: French is for the screen only.
 */

const DICTIONARY: Record<string, string> = { ...FR_PUBLIC_SHARED, ...FR_PUBLIC_ENROLL };

const read = (file: string) => readFileSync(new URL(`../../components/${file}`, import.meta.url), "utf8");
const SOURCES: Record<string, string> = {
  "ProgramsOverview.tsx": read("ProgramsOverview.tsx"),
  "ProgramCatalog.tsx": read("ProgramCatalog.tsx"),
  "EnrollLoadingFallbacks.tsx": read("EnrollLoadingFallbacks.tsx"),
};
const overview = SOURCES["ProgramsOverview.tsx"];
const catalog = SOURCES["ProgramCatalog.tsx"];

/** String literals passed straight to t(): "…", '…' and `…` without ${}. */
const T_CALL = /(?<![\w.])t\(\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|`((?:[^`\\$]|\\.)*)`)\s*[,)]/g;

function literalKeys(source: string): string[] {
  const keys: string[] = [];
  for (const match of source.matchAll(T_CALL)) {
    if (match[1] !== undefined) keys.push(JSON.parse(`"${match[1]}"`) as string);
    else keys.push((match[2] ?? match[3] ?? "").replace(/\\(.)/g, "$1"));
  }
  return keys;
}

const quoted = (list: string) => [...list.matchAll(/"([^"]+)"/g)].map((match) => match[1]);

function missing(keys: readonly string[]): string[] {
  return [...new Set(keys)].filter((key) => !(key in DICTIONARY));
}

test("every literal passed to t() has a French entry", () => {
  for (const [file, source] of Object.entries(SOURCES)) {
    const keys = literalKeys(source);
    assert.ok(keys.length > 0, `${file}: no t() call found`);
    assert.deepEqual(missing(keys), [], `${file}: keys with no French`);
  }
  assert.ok(literalKeys(overview).length >= 120, "the enrollment form's text is still extracted");
  assert.ok(literalKeys(catalog).length >= 12, "the catalog's text is still extracted");
});

/* ---- text that reaches t() through a variable: the enrollment form ---- */

const STEP_TITLES = ["Who's enrolling", "Student details", "Program & pricing", "Schedule", "Contact & review"];
const ROLE_TEXT = [
  "Student",
  "I'm signing up for myself.",
  "Parent",
  "I'm enrolling one or more children.",
  "Guardian",
  "I'm responsible for a learner's enrollment.",
];
const TRACK_TITLES = ["Religious Studies", "Adlam", "Tutoring & Literacy", "Group Classes"];
const GENDERS = ["Male", "Female"];
const LEVELS = ["Beginner", "Intermediate", "Advanced", "Elementary School", "Middle School", "High School", "University"];
/** What classTypeReviewLabel() returns for each stored class type. */
const CLASS_TYPE_REVIEW_LABELS = ["1-on-1", "Exclusive Family Class", "With Other Students"];
const SUBJECT_SHORT_LABELS = [
  "Religious Studies",
  "Group Classes",
  "AfroLanguages",
  "English",
  "French",
  "Adlam",
  "Entrepreneurship",
  "Coding",
  "Tutoring",
  "Adult Literacy",
];
const CONTACT_LANGUAGES = ["English", "French", "Arabic", "Other"];
const AFRICAN_LANGUAGES = ["Pular", "Mandingo", "Swahili", "Wolof", "Hausa", "Yoruba", "Adlam", "Amharic", "Other"];
const WEEK_DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

test("the lists above still match the form's own arrays", () => {
  const array = (name: string) => quoted(overview.match(new RegExp(`const ${name} = \\[([^\\]]+)\\]`))?.[1] ?? "");
  assert.deepEqual(array("days"), WEEK_DAYS);
  assert.deepEqual([...DAYS], WEEK_DAYS);
  assert.deepEqual(array("languages"), CONTACT_LANGUAGES);
  assert.deepEqual(array("africanLanguages"), AFRICAN_LANGUAGES);
  assert.deepEqual([...overview.matchAll(/shortLabel: "([^"]+)"/g)].map((m) => m[1]), SUBJECT_SHORT_LABELS);
  assert.deepEqual([...overview.matchAll(/\{ title: "([^"]+)", icon: \w+ \}/g)].map((m) => m[1]), STEP_TITLES);
  assert.deepEqual([...overview.matchAll(/\{ id: "[^"]+", title: "([^"]+)", icon: \w+ \}/g)].map((m) => m[1]), TRACK_TITLES);
  assert.deepEqual(
    [...overview.matchAll(/\{ value: "[^"]+", title: "([^"]+)", subtitle: "([^"]+)", icon: \w+ \}/g)].flatMap((m) => [m[1], m[2]]),
    ROLE_TEXT,
  );
  assert.deepEqual([...overview.matchAll(/\{ value: "([^"]+)", icon: \w+ \}/g)].map((m) => m[1]), GENDERS);
  assert.deepEqual(
    [...overview.matchAll(/return \[("[^\]]+")\];/g)].flatMap((m) => quoted(m[1])).sort(),
    [...LEVELS].sort(),
  );
  for (const type of CLASS_TYPES) {
    const shown = type.value === "One-on-One" ? "1-on-1" : type.value;
    assert.ok(CLASS_TYPE_REVIEW_LABELS.includes(shown), `class type ${type.value}`);
  }
});

test("the enrollment form's option text has a French entry", () => {
  const keys = [
    ...STEP_TITLES,
    ...ROLE_TEXT,
    ...TRACK_TITLES,
    ...GENDERS,
    ...LEVELS,
    ...CLASS_TYPE_REVIEW_LABELS,
    ...WEEK_DAYS,
    ...CLASS_TYPES.flatMap((type) => [type.label, type.hint]),
    ...TIME_BLOCKS.map((block) => block.label),
    ...SESSION_MINUTES.map((minutes) => sessionLabel(minutes)),
    ...SUBJECT_SHORT_LABELS.map((label) => `${label}|subject`),
    ...CONTACT_LANGUAGES.map((language) => `${language}|language`),
    ...AFRICAN_LANGUAGES.map((language) => `${language}|language`),
  ];
  assert.deepEqual(missing(keys), []);
});

/* -------- text that reaches t() through a variable: the catalog -------- */

test("every catalog category and program has a French entry", () => {
  // Read from the catalog itself, so a program added there cannot be missed.
  const categories = [...catalog.matchAll(/\n    title: "([^"]+)",\n    description: "([^"]+)",/g)];
  const items = [...catalog.matchAll(/\bitem\("[^"]+", "([^"]+)", "([^"]+)", "([^"]+)",/g)];
  assert.equal(categories.length, [...catalog.matchAll(/\n    enrollSubject: "/g)].length);
  assert.equal(items.length, [...catalog.matchAll(/\bitem\("/g)].length);
  assert.ok(categories.length >= 6 && items.length >= 35);

  const keys = [
    ...categories.flatMap((match) => [match[1], match[2]]),
    ...items.flatMap((match) => [`${match[1]}|program`, match[2], match[3]]),
  ];
  assert.deepEqual(missing(keys), []);
});

/* ------------------------------------------------- dictionary hygiene -- */

test("no French value is empty and every {placeholder} survives", () => {
  for (const [key, french] of Object.entries(FR_PUBLIC_ENROLL)) {
    assert.ok(french.trim().length > 0, `empty French for "${key}"`);
    for (const placeholder of key.match(/\{\w+\}/g) ?? []) {
      assert.ok(french.includes(placeholder), `"${key}" lost ${placeholder}`);
    }
    for (const placeholder of french.match(/\{\w+\}/g) ?? []) {
      assert.ok(key.includes(placeholder), `"${key}" gained ${placeholder}`);
    }
  }
});

test("names that share an English word with the language switch keep their own key", () => {
  // "English" belongs to the switch; a subject or language named English must
  // not overwrite it once the dictionaries are merged.
  for (const key of Object.keys(FR_PUBLIC_SHARED)) {
    assert.ok(!(key in FR_PUBLIC_ENROLL), `"${key}" would override the shared dictionary`);
  }
});

/* ------------------------------------------- what gets stored is English -- */

function between(source: string, start: string, end: string): string {
  const from = source.indexOf(start);
  const to = source.indexOf(end, from);
  assert.ok(from >= 0 && to > from, `could not find the block starting at "${start}"`);
  return source.slice(from, to);
}

test("the stored enrollment and its draft never pass through t()", () => {
  const submitted = between(overview, "await submitEnrollment({", 'trackEvent("enrollment_submitted"');
  const draft = between(overview, "const payload: EnrollmentDraftPayload = {", "if (!draftHasSignal(payload))");
  for (const block of [submitted, draft]) {
    assert.doesNotMatch(block, /(?<![\w.])t\(/);
    assert.doesNotMatch(block, /DisplayName\(/);
  }
  // The values those payloads read are set from the English constants.
  assert.match(overview, /onClick=\{\(\) => setRole\(value\)\}/);
  assert.match(overview, /onClick=\{\(\) => onChange\(selected \? "" : optionValue\)\}/);
  assert.match(overview, /onClick=\{\(\) => onChange\(selected \? "" : block\.id\)\}/);
  assert.match(overview, /onClick=\{\(\) => onToggle\(item\)\}/);
  assert.match(overview, /<option key=\{option\.value\} value=\{option\.value\}>\{option\.label\}<\/option>/);
  assert.match(overview, /options=\{levels\.map\(\(value\) => \(\{ value, label: t\(value\) \}\)\)\}/);
  assert.match(overview, /sessionDuration: sessionLabel\(program\.sessionMinutes\),/);
});
