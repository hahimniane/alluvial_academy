import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { mapUserDoc } from "../adminUsers.ts";
import { nationalDigits, phoneProblem, storedPhoneForms, toE164 } from "../phoneNumbers.ts";
import { buildDuplicateIndex, findDuplicates, normalizePersonName, personNameKeys, reasonText } from "../userDuplicates.ts";
import {
  accountPayload,
  baseStudentCode,
  batchOutcomes,
  createFailureReason,
  emptyRow,
  existingChildOf,
  existingPeople,
  kioskCodeFits,
  makeKioskCode,
  outcomeLine,
  outcomeSummary,
  predictStudentCode,
  repeatedEmails,
  rowCounts,
  rowProblems,
  studentIdPart,
  studentPayload,
  takenKioskCodes,
  takenStudentCodes,
  type DraftRow,
} from "../addUsers.ts";

const row = (over: Partial<DraftRow> = {}): DraftRow => ({ ...emptyRow(1, "teacher"), firstName: "Nafi", lastName: "Bah", email: "nafi@example.org", ...over });
const users = (docs: Record<string, Record<string, unknown>>) => Object.entries(docs).map(([id, d]) => mapUserDoc(id, d));

// ─── Phone numbers ─────────────────────────────────────────────────────────

test("phone: +224, +1, spaces, dashes, brackets and a leading 0 all normalise to E.164", () => {
  assert.equal(toE164("GN", "621 12 34 56"), "+224621123456");
  assert.equal(toE164("GN", "0621123456"), "+224621123456");
  assert.equal(toE164("GN", "+224 621-12-34-56"), "+224621123456");
  assert.equal(toE164("GN", "00224621123456"), "+224621123456");
  assert.equal(toE164("US", "(646) 555-0100"), "+16465550100");
  assert.equal(toE164("US", "+1 646 555 0100"), "+16465550100");
  assert.equal(toE164("US", "16465550100"), "+16465550100");
  assert.equal(toE164("FR", "06 12 34 56 78"), "+33612345678");
  assert.equal(toE164("IT", "06 1234 5678"), "+390612345678");
  assert.equal(toE164("US", ""), "");
  assert.equal(nationalDigits("SL", "076 123456"), "76123456");
});

test("phone: checked per country, optional when empty", () => {
  assert.equal(phoneProblem("US", ""), null);
  assert.equal(phoneProblem("US", "646 555 0100"), null);
  assert.match(phoneProblem("US", "646 555 010") ?? "", /United States/);
  assert.match(phoneProblem("US", "146 555 0100") ?? "", /United States/);
  assert.equal(phoneProblem("GN", "621 12 34 56"), null);
  assert.match(phoneProblem("GN", "521 12 34 56") ?? "", /Guinea/);
  assert.match(phoneProblem("GN", "62112345") ?? "", /Guinea/);
  assert.equal(phoneProblem("SL", "76 123 456"), null);
  // Countries without a specific rule use Flutter's general one.
  assert.equal(phoneProblem("PK", "3001234567"), null);
  assert.match(phoneProblem("PK", "123") ?? "", /4–15 digits/);
});

test("phone: stored numbers in every shape compare in E.164", () => {
  assert.deepEqual(storedPhoneForms("+224621123456", ""), ["+224621123456"]);
  assert.ok(storedPhoneForms("621123456", "+224").includes("+224621123456"));
  assert.ok(storedPhoneForms("621123456", "224").includes("+224621123456"));
  assert.ok(storedPhoneForms("+1(646) 555-0100", "+1").includes("+16465550100"));
  assert.ok(storedPhoneForms("6465550100", "").includes("+16465550100"));
  assert.ok(storedPhoneForms("0621123456", "+224").includes("+224621123456"));
  assert.deepEqual(storedPhoneForms("12", "+1"), []);
});

// ─── Duplicate check (F3) ──────────────────────────────────────────────────

test("names: accents, case, spacing and punctuation are ignored; non-Latin letters kept", () => {
  assert.equal(normalizePersonName("  Aïcha "), "aicha");
  assert.equal(normalizePersonName("N'Diaye"), "ndiaye");
  assert.equal(normalizePersonName("Abdoul-Aziz"), "abdoulaziz");
  assert.equal(normalizePersonName("MARY  ann"), "maryann");
  assert.equal(normalizePersonName("محمد"), "محمد");
  assert.equal(personNameKeys("Mamadou Saliou", "Diallo")[0], personNameKeys("Mamadou", "Saliou Diallo")[0]);
  assert.deepEqual(personNameKeys("", "Diallo"), []);
});

const people = existingPeople(
  users({
    u1: { first_name: "Aïcha", last_name: "N'Diaye", user_type: "student", "e-mail": "aicha.ndiaye@alluwaleducationhub.org" },
    u2: { first_name: "Kadiatou", last_name: "Sow", user_type: "parent", "e-mail": "Kadi@Example.org", phone_number: "621123456", country_code: "+224" },
    u3: { first_name: "Oumar", last_name: "Diallo", user_type: "teacher", email: "oumar@example.org", phone_number: "+1(646) 555-0100" },
    u4: { first_name: "Old", last_name: "Account", user_type: "teacher", is_active: false, phone_number: "0612345678", country_code: "33" },
  }),
);
const index = buildDuplicateIndex(people);

test("duplicates: same name in another spelling", () => {
  const hits = findDuplicates({ firstName: "aicha", lastName: "ndiaye", email: "", phoneE164: "" }, index);
  assert.deepEqual(hits.map((h) => [h.id, h.reasons]), [["u1", ["name"]]]);
  // Either order.
  assert.equal(findDuplicates({ firstName: "Ndiaye", lastName: "Aicha", email: "", phoneE164: "" }, index)[0]?.id, "u1");
});

test("duplicates: same email (any case, either email field) and same phone in another format", () => {
  assert.equal(findDuplicates({ firstName: "K", lastName: "S", email: " kadi@example.org ", phoneE164: "" }, index)[0]?.id, "u2");
  assert.equal(findDuplicates({ firstName: "x", lastName: "y", email: "OUMAR@example.org", phoneE164: "" }, index)[0]?.id, "u3");
  assert.equal(findDuplicates({ firstName: "x", lastName: "y", email: "", phoneE164: toE164("GN", "0621 12 34 56") }, index)[0]?.id, "u2");
  assert.equal(findDuplicates({ firstName: "x", lastName: "y", email: "", phoneE164: toE164("US", "646-555-0100") }, index)[0]?.id, "u3");
  const archived = findDuplicates({ firstName: "x", lastName: "y", email: "", phoneE164: toE164("FR", "06 12 34 56 78") }, index)[0];
  assert.equal(archived?.id, "u4");
  assert.equal(archived?.isActive, false);
});

test("duplicates: strongest match first, reasons in words, nothing for a new person", () => {
  const hits = findDuplicates({ firstName: "Kadiatou", lastName: "Sow", email: "kadi@example.org", phoneE164: "+224621123456" }, index);
  assert.deepEqual(hits[0].reasons, ["email", "phone", "name"]);
  assert.equal(reasonText(hits[0].reasons), "same email, same phone, same name");
  assert.deepEqual(findDuplicates({ firstName: "Brand", lastName: "New", email: "new@example.org", phoneE164: "+224622000000" }, index), []);
});

// ─── Student ID preview == server ──────────────────────────────────────────

test("Student ID mirrors students.js normalizeString exactly (accents dropped, not translated)", () => {
  assert.equal(baseStudentCode("Aïcha", "Bâ"), "acha.b");
  assert.equal(baseStudentCode("N'Diaye", "Mary Ann"), "ndiaye.maryann");
  assert.equal(baseStudentCode("Abdoul-Aziz", "Diallo"), "abdoulaziz.diallo");
  assert.equal(baseStudentCode("Mohamedabdoulaye", "X"), "mohamedabd.x");
  assert.equal(studentIdPart("محمد"), "");
  assert.match(rowProblems(row({ type: "student", adult: true, firstName: "محمد" })).studentId ?? "", /Latin letters/);
});

test("Student ID collisions: the next free number, also within one save", () => {
  const rows = users({ a: { user_type: "student", student_code: "alpha.barry" }, b: { user_type: "student", student_code: "1alpha.barry" } });
  const taken = takenStudentCodes(rows);
  const first = predictStudentCode("Alpha", "Barry", taken);
  assert.equal(first, "2alpha.barry");
  taken.add(first);
  assert.equal(predictStudentCode("Alpha", "Barry", taken), "3alpha.barry");
  assert.equal(predictStudentCode("Néné", "Diallo", taken), "nn.diallo");
});

test("existing child: the server's same-child rule", () => {
  const rows = users({
    k1: { user_type: "student", first_name: "Alpha", last_name: "Barry", guardian_ids: ["p1"], is_active: true },
    k2: { user_type: "student", first_name: "Binta", last_name: "Barry", guardian_ids: ["p1"], is_active: false },
    k3: { user_type: "student", first_name: "Fanta", last_name: "Barry", guardian_ids: ["p1"], merged_into: "k9" },
  });
  assert.equal(existingChildOf(["p1"], "ALPHA", "barry", rows)?.id, "k1");
  assert.equal(existingChildOf(["p1"], "Alpha", "", rows)?.id, "k1");
  assert.equal(existingChildOf(["p2"], "Alpha", "Barry", rows), null);
  assert.equal(existingChildOf(["p1"], "Binta", "Barry", rows), null);
  assert.equal(existingChildOf(["p1"], "Fanta", "Barry", rows), null);
});

// ─── Kiosk code ────────────────────────────────────────────────────────────

test("kiosk code: Flutter's format, and kept while the initials and type still fit", () => {
  const code = makeKioskCode("aminata", "mara", "teacher", 1731840012345, 47);
  assert.equal(code, "AMTC04712345");
  assert.equal(makeKioskCode("", "Mara", "teacher"), "");
  assert.ok(kioskCodeFits(code, "Aminata Kadi", "Mara", "teacher"));
  assert.ok(!kioskCodeFits(code, "Aminata", "Mara", "parent"));
  assert.ok(!kioskCodeFits(code, "Binta", "Mara", "teacher"));
  const taken = takenKioskCodes(users({ t: { user_type: "teacher", kiosk_code: "AMTC04712345" }, s: { user_type: "student" } }));
  assert.deepEqual([...taken], ["AMTC04712345"]);
});

// ─── Row checks ────────────────────────────────────────────────────────────

test("row checks: required fields per type", () => {
  assert.deepEqual(rowProblems(row()), {});
  assert.ok(rowProblems(row({ email: "" })).email);
  assert.ok(rowProblems(row({ email: "not-an-email" })).email);
  const minor = row({ type: "student", adult: false, email: "" });
  assert.deepEqual(Object.keys(rowProblems(minor)), ["parent"]);
  assert.deepEqual(rowProblems({ ...minor, parentId: "p1" }), {});
  assert.ok(rowProblems(row({ type: "student", adult: true, email: "" })).email);
  assert.ok(rowProblems(row({ firstName: " " })).firstName);
  assert.ok(rowProblems(row({ hourlyRate: "abc" })).hourlyRate);
  assert.equal(rowProblems(row({ hourlyRate: "4.50" })).hourlyRate, undefined);
  assert.equal(rowProblems(row({ type: "parent", hourlyRate: "abc" })).hourlyRate, undefined);
  assert.ok(rowProblems(row({ countryIso: "GN", phone: "12" })).phone);
  assert.ok(!rowCounts(emptyRow(2, "teacher")));
  assert.ok(rowCounts({ ...emptyRow(2, "teacher"), phone: "6" }));
});

test("the same email twice in one save is caught before anything is sent", () => {
  const dups = repeatedEmails([row(), row({ email: "other@example.org" }), row({ email: " NAFI@example.org " })]);
  assert.deepEqual([...dups], [[2, 0]]);
});

test("payloads: hourly rate saved for staff only, E.164 phone, minors keep their parent", () => {
  assert.deepEqual(accountPayload(row({ hourlyRate: "4.5", countryIso: "GN", phone: "0621 12 34 56", kioskCode: "NBTC00112345", email: " Nafi@Example.org " })), {
    email: "nafi@example.org",
    firstName: "Nafi",
    lastName: "Bah",
    phoneNumber: "+224621123456",
    countryCode: "+224",
    userType: "teacher",
    title: "Teacher",
    kioskCode: "NBTC00112345",
    hourlyRate: 4.5,
  });
  assert.equal("hourlyRate" in accountPayload(row({ type: "parent", hourlyRate: "4" })), false);
  assert.equal("hourlyRate" in accountPayload(row({ hourlyRate: "" })), false);
  assert.deepEqual(studentPayload(row({ type: "student", adult: false, email: "", parentId: "p1" })), {
    userType: "student",
    firstName: "Nafi",
    lastName: "Bah",
    phoneNumber: "",
    isAdultStudent: false,
    guardianIds: ["p1"],
  });
});

// ─── Results and messages ──────────────────────────────────────────────────

test("batch results map to rows by index; a missing answer is never reported as done", () => {
  const rows = [row(), row({ type: "student", adult: false, parentId: "p1", email: "" }), row({ email: "dup@example.org" }), row()];
  const outcomes = batchOutcomes(
    rows,
    {
      results: [
        { index: 1, success: true, result: { studentId: "s1", studentCode: "nafi.bah", emailsToGuardians: 1, emailsSent: 1 } },
        { index: 0, success: true, result: { uid: "t1", emailSent: false } },
      ],
      errors: [{ index: 2, error: "The email address is already in use by another account." }],
    },
    createFailureReason,
  );
  assert.deepEqual(outcomes.map((o) => o.kind), ["created", "student", "failed", "failed"]);
  assert.match(outcomeLine(outcomes[0]), /welcome email could not be sent/);
  assert.match(outcomeLine(outcomes[1]), /Student ID nafi\.bah\. The login was emailed to the parent\./);
  assert.match(outcomeLine(outcomes[2]), /already belongs to an account/);
  assert.match(outcomeLine(outcomes[3]), /No answer came back/);
  assert.equal(outcomeSummary(outcomes), "2 of 4 done, 2 not created.");
});

test("adult student: the message never claims an email was sent", () => {
  const [o] = batchOutcomes([row({ type: "student", adult: true })], { results: [{ index: 0, result: { studentId: "s", studentCode: "nafi.bah", emailsToGuardians: 0, emailsSent: 0 } }] }, createFailureReason);
  const line = outcomeLine(o);
  assert.match(line, /No email is sent to adult students/);
  assert.doesNotMatch(line, /emailed|email sent/i);
});

test("existing child: says nothing new was created", () => {
  const [o] = batchOutcomes([row({ type: "student", parentId: "p1", email: "" })], { results: [{ index: 0, existing: true, result: { existing: true, studentId: "k1", studentCode: "nafi.bah" } }] }, createFailureReason);
  assert.match(outcomeLine(o), /Nothing new was created/);
});

test("Add users code never touches a password", () => {
  for (const file of ["../addUsers.ts", "../addUsersData.ts", "../../components/admin-users/AddUsersDialog.tsx", "../../components/admin-users/FamilyEnrollDialog.tsx"]) {
    const source = readFileSync(fileURLToPath(new URL(file, import.meta.url)), "utf8");
    assert.doesNotMatch(source, /tempPassword|temp_password|student_credentials/, file);
  }
});
