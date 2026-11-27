import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { FR_PUBLIC_FORMS } from "../translations/public/forms.ts";
import { publicSubmitError } from "../publicForms.ts";
import { formatMessage } from "../parentForms.ts";

const source = readFileSync(new URL("../../components/PublicFormPage.tsx", import.meta.url), "utf8");

/** Every `t(` call: its literal key, or the expression when it is not a literal. */
function tCalls(text: string) {
  const literals: string[] = [];
  const expressions: string[] = [];
  const call = /(?<![\w.$])t\(\s*/g;
  const literal = /^"((?:[^"\\]|\\.)*)"/;
  for (let match = call.exec(text); match; match = call.exec(text)) {
    const rest = text.slice(match.index + match[0].length);
    const found = literal.exec(rest);
    if (found) literals.push(found[1]);
    else expressions.push(rest.slice(0, rest.search(/[),]/)).trim());
  }
  return { literals, expressions };
}

test("every literal on the form link page has a French entry", () => {
  const { literals } = tCalls(source);
  assert.ok(literals.length > 20, `expected the page to translate its text, found ${literals.length}`);
  for (const key of literals) assert.ok(key in FR_PUBLIC_FORMS, `no French for ${JSON.stringify(key)}`);
});

test("the only non-literal t() calls are the send error and the answer format checks", () => {
  assert.deepEqual([...new Set(tCalls(source).expressions)].sort(), ["message", "publicSubmitError(error"]);
  for (const code of ["functions/resource-exhausted", "functions/failed-precondition", "functions/invalid-argument", "functions/internal"]) {
    const text = publicSubmitError({ code });
    assert.ok(text in FR_PUBLIC_FORMS, `no French for ${JSON.stringify(text)}`);
  }
  for (const [type, bad] of [["email", "nope"], ["phone", "abc"], ["number", "x"]]) {
    const text = formatMessage(type, bad);
    assert.ok(text && text in FR_PUBLIC_FORMS, `no French for ${JSON.stringify(text)}`);
  }
});

test("no French value is empty", () => {
  for (const [key, french] of Object.entries(FR_PUBLIC_FORMS)) assert.ok(french.trim(), `empty French for ${JSON.stringify(key)}`);
});
