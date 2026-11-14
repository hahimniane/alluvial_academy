import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { FR_PUBLIC_TEAM } from "../translations/public/team.ts";
import { FR_PUBLIC_SHARED } from "../translations/public/shared.ts";

const read = (relative: string) => readFileSync(new URL(relative, import.meta.url), "utf8");

const sources: Record<string, string> = {
  TeamDirectory: read("../../components/TeamDirectory.tsx"),
  ApplicationForms: read("../../components/ApplicationForms.tsx"),
  LoginRedirect: read("../../components/LoginRedirect.tsx"),
};

const known = (key: string) => key in FR_PUBLIC_TEAM || key in FR_PUBLIC_SHARED;
const unescape = (raw: string) => raw.replace(/\\(.)/g, (_, char: string) => (char === "n" ? "\n" : char));

/** Every `t(` call: its literal key, or the expression when it is not a literal. */
function tCalls(source: string) {
  const literals: string[] = [];
  const expressions: string[] = [];
  const call = /(?<![\w.$])t\(\s*/g;
  const literal = /^(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|`((?:[^`\\$]|\\.|\$(?!\{))*)`)/;
  for (let match = call.exec(source); match; match = call.exec(source)) {
    const rest = source.slice(match.index + match[0].length);
    const found = literal.exec(rest);
    if (found) literals.push(unescape(found[1] ?? found[2] ?? found[3]));
    else expressions.push(rest.slice(0, rest.search(/[),]/)).trim());
  }
  return { literals, expressions };
}

const placeholders = (text: string) => text.match(/\{\w+\}/g) ?? [];

/** Labels shown through a variable: `t(option.label)`, `t(label)`, `t(error)`, `t(theme.…)`. */
const optionLabels = [
  // currentStatusOptions, leadershipStatusOptions, genderOptions, availabilityOptions
  "University Student", "High School Student", "University Graduate", "Professional", "Other",
  "Male", "Female",
  "In One Week", "In Two Weeks", "In Three Weeks", "In a Month",
  // teachingPrograms
  "After School Tutoring (English track)",
  "Religious Studies (Quran, Arabic, Hadith, Fiqh)",
  "Adult Literacy (English/French reading and writing)",
  "AdLaM (Reading and Writing)",
  // options written beside their question
  "Yes", "No", "Average", "N/A",
  "100% - I am Hafiz", "About 50% or more", "About 35% or less", "I memorize less than Juzu Anma",
  "I Am Excellent", "I Am Intermediate", "I Am A Beginner",
  "100% - Sleep will never cause me to miss a class",
  "50% - Sleep and personal engagement might affect me",
  "<30% - Resisting sleep and planning ahead is hard",
  "Sorry, not at all - I am a day person",
  "100% - I am always on top of things",
  "50% - I often try to be balanced",
  ">30% - Life balance is not one of my strengths",
  "Not at all",
  "Always / 24 hours / 7 days", "Sometimes", "Rarely", "Never",
  "Very comfortable", "Comfortable", "Less comfortable", "Uncomfortable",
  "Yes, and always", "Maybe, but I will try", "No, I can't",
  "A Computer", "A Tablet", "A Phone", "No Device",
  "Often / Few days a week", "Rarely / Few hours a week",
];

/** The languages an applicant can tick. Saved in English, shown as `t("<name>|language")`. */
const spokenLanguages = [
  "English", "Arabic", "French", "Spanish", "Mandingo", "Pular", "Wolof", "Hausa", "Turkish",
  "Urdu", "Bengali", "Indonesian", "Malay", "Swahili", "Amharic", "Adlam", "Other",
];

const formErrors = [
  "Please select at least one teaching program.",
  "Please select at least one language.",
];

const teamCategoryText = [
  "All Team", "The full Alluwal family", "Visionaries and educators united by one mission.",
  "Leadership", "Vision & Direction",
  "The architects and coordinators of Alluwal - shaping policy, strategy, operations and culture.",
  "Teachers", "Global Knowledge Carriers",
  "Scholars and educators spanning 10+ countries - bringing religious and academic excellence to every learner, everywhere.",
];

const sorted = (values: Iterable<string>) => [...new Set(values)].sort();
const captures = (source: string, pattern: RegExp) => [...source.matchAll(pattern)].map((match) => unescape(match[1]));

test("every literal passed to t() has a French entry", () => {
  let total = 0;
  for (const [name, source] of Object.entries(sources)) {
    const { literals } = tCalls(source);
    total += literals.length;
    for (const key of literals) assert.ok(known(key), `${name}: no French for ${JSON.stringify(key)}`);
  }
  assert.ok(total > 100, `expected the components to translate their text, found ${total} t() calls`);
});

test("the only non-literal t() calls are the listed ones", () => {
  assert.deepEqual(sorted(tCalls(sources.TeamDirectory).expressions), ["theme.description", "theme.label", "theme.tagline"]);
  assert.deepEqual(sorted(tCalls(sources.ApplicationForms).expressions), ["`${language}|language`", "error", "label", "option.label"]);
  assert.deepEqual(tCalls(sources.LoginRedirect).expressions, []);
});

test("labels translated through a variable have a French entry", () => {
  for (const key of [...optionLabels, ...formErrors, ...teamCategoryText]) {
    assert.ok(known(key), `no French for ${JSON.stringify(key)}`);
  }
  for (const language of spokenLanguages) {
    assert.ok(known(`${language}|language`), `no French for the language ${language}`);
  }
});

test("the listed labels are the ones in the components", () => {
  const forms = sources.ApplicationForms;
  assert.deepEqual(sorted(captures(forms, /\blabel: "((?:[^"\\]|\\.)*)"/g)), sorted(optionLabels));
  assert.deepEqual(sorted(captures(forms, /setError\("((?:[^"\\]|\\.)+)"\)/g)), sorted(formErrors));
  const languageList = /const languages = \[([^\]]*)\]/.exec(forms);
  assert.ok(languageList, "the languages list is still a plain array");
  assert.deepEqual(captures(languageList[1], /"([^"]*)"/g), spokenLanguages);
  assert.deepEqual(
    sorted(captures(sources.TeamDirectory, /\b(?:label|tagline|description): "((?:[^"\\]|\\.)*)"/g)),
    sorted(teamCategoryText),
  );
});

test("no French value is empty and placeholders survive translation", () => {
  for (const [key, french] of Object.entries(FR_PUBLIC_TEAM)) {
    assert.ok(french.trim().length > 0, `empty French for ${JSON.stringify(key)}`);
    for (const placeholder of placeholders(key)) {
      assert.ok(french.includes(placeholder), `${JSON.stringify(key)} lost ${placeholder} in French`);
    }
    assert.deepEqual(sorted(placeholders(french)), sorted(placeholders(key)), `${JSON.stringify(key)} gained a placeholder in French`);
  }
});

test("the team dictionary leaves the language switch alone", () => {
  for (const key of Object.keys(FR_PUBLIC_SHARED)) {
    assert.ok(!(key in FR_PUBLIC_TEAM), `${JSON.stringify(key)} belongs to the shared dictionary`);
  }
});

test("applications are saved in English: nothing sent to Firestore goes through t()", () => {
  const forms = sources.ApplicationForms;
  for (const submit of ["submitTeacherApplication({", "submitLeadershipApplication({"]) {
    const start = forms.indexOf(submit);
    assert.ok(start > 0, `${submit} is still called`);
    const call = forms.slice(start, forms.indexOf("});", start));
    assert.equal(tCalls(call).literals.length + tCalls(call).expressions.length, 0, `${submit} sends translated text`);
  }
  // Selections are stored by their English value, never by the label on screen.
  assert.match(forms, /onClick=\{\(\) => toggleProgram\(value\)\}/);
  assert.match(forms, /onClick=\{\(\) => toggleLanguage\(language\)\}/);
  assert.match(forms, /<option key=\{option\.value\} value=\{option\.value\}>/);
});
