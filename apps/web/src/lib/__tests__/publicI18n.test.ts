import { test } from "node:test";
import assert from "node:assert/strict";
import { browserPrefersFrench, translate } from "../localeStore.ts";

const dict = { "Enroll now": "Inscrivez-vous", "Hello {name}": "Bonjour {name}", "End|verb": "Terminer" };

test("French when chosen and translated, English otherwise", () => {
  assert.equal(translate(dict, "fr", "Enroll now"), "Inscrivez-vous");
  assert.equal(translate(dict, "en", "Enroll now"), "Enroll now");
  assert.equal(translate(dict, "fr", "Not translated yet"), "Not translated yet");
});

test("placeholders and context keys", () => {
  assert.equal(translate(dict, "fr", "Hello {name}", { name: "Aisha" }), "Bonjour Aisha");
  assert.equal(translate(dict, "fr", "End|verb"), "Terminer");
  assert.equal(translate(dict, "en", "End|verb"), "End");
});

test("a French browser is detected from its first language", () => {
  assert.equal(browserPrefersFrench(["fr-CA", "en"]), true);
  assert.equal(browserPrefersFrench(["en-US", "fr"]), false);
  assert.equal(browserPrefersFrench(undefined, "fr"), true);
  assert.equal(browserPrefersFrench([], undefined), false);
});
