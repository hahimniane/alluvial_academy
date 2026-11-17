import test from "node:test";
import assert from "node:assert/strict";
import { appSearchMatches, looksLikePhone, normalizeIdentifier, normalizeText, searchFieldsOfMap } from "../appSearch.ts";

test("normalisers match the Dart ones", () => {
  assert.equal(normalizeText("  Amina   DIALLO \t"), "amina diallo");
  assert.equal(normalizeIdentifier("Amina.Diallo-2"), "aminadiallo2");
  assert.equal(looksLikePhone("+1 (646) 555-0110"), true);
  assert.equal(looksLikePhone("646 555 0110 x"), false);
});

test("empty query matches everyone", () => {
  assert.equal(appSearchMatches("   ", { names: ["x"] }), true);
});

test("names and emails match by contained text, case and spaces ignored", () => {
  const f = { names: ["Amina Diallo", "Diallo Amina"], emails: ["Amina@Example.org"] };
  assert.equal(appSearchMatches("amina  dia", f), true);
  assert.equal(appSearchMatches("diallo amina", f), true);
  assert.equal(appSearchMatches("example.org", f), true);
  assert.equal(appSearchMatches("fatou", f), false);
});

test("ids match plainly or with punctuation removed on both sides", () => {
  const f = { ids: ["amina.diallo", "AMTC04712345"] };
  assert.equal(appSearchMatches("amina diallo", f), true);
  assert.equal(appSearchMatches("aminadiallo", f), true);
  assert.equal(appSearchMatches("amtc0471", f), true);
  assert.equal(appSearchMatches("...", f), false);
});

test("phones need a phone-looking query with 7+ digits and match either end", () => {
  const f = { phones: ["6465550110", "16465550110"] };
  assert.equal(appSearchMatches("646-555-0110", f), true);
  assert.equal(appSearchMatches("+1 646 555 0110", f), true);
  assert.equal(appSearchMatches("555 0110", f), true);
  assert.equal(appSearchMatches("555011", f), false);
  assert.equal(appSearchMatches("6465550110 a", f), false);
});

test("one leading zero is ignored on either side", () => {
  assert.equal(appSearchMatches("0612345678", { phones: ["+33612345678"] }), true);
  assert.equal(appSearchMatches("612345678", { phones: ["0612345678"] }), true);
});

test("short phones never match", () => {
  assert.equal(appSearchMatches("1234567", { phones: ["12345"] }), false);
});

test("additional values match by contained text", () => {
  assert.equal(appSearchMatches("teach", { additionalValues: ["teacher"] }), true);
});

test("searchFieldsOfMap gathers the matchesMap fields", () => {
  const f = searchFieldsOfMap({ first_name: "Mariama", last_name: "Barry", "e-mail": "m@x.org", phone_number: "6465550187", kiosk_code: "MB001", uid: 7 }, "doc1");
  assert.deepEqual(f.names, ["Mariama Barry", "Barry Mariama"]);
  assert.deepEqual(f.emails, ["m@x.org"]);
  assert.deepEqual(f.phones, ["6465550187"]);
  assert.deepEqual(f.ids, ["doc1", "7", "MB001"]);
});
