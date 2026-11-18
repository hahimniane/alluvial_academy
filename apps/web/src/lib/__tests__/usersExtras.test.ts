import test from "node:test";
import assert from "node:assert/strict";
import { NO_FILTERS, mapUserDoc, type UserRow } from "../adminUsers.ts";
import { attentionCounts, attentionList, findPossibleDuplicates, needsAttention, reasonText } from "../usersAttention.ts";
import { emailResultText, guardianContacts, guardianEmail, loginDetailsProblem, loginFactsOf, loginMessage, whatsAppNumber, whatsAppUrl } from "../loginDetails.ts";
import { confirmText, planBulk, pruneSelection, resultSummary, runBulk, selectAllState, skipReason } from "../bulkActions.ts";
import {
  attendanceText,
  isValidTimeZone,
  localTime,
  mapPanelShift,
  mergeShifts,
  monthAttendance,
  nextClass,
  owedDetail,
  owedFromInvoices,
  owedText,
  zoneOffsetMinutes,
} from "../panelFacts.ts";
import {
  MAX_SAVED_FILTERS,
  applySavedFilter,
  describeFilter,
  filterFromView,
  isApplied,
  nameProblem,
  parseSavedFilters,
  removeFilter,
  renameFilter,
  upsertFilter,
  type SavedFilter,
} from "../savedFilters.ts";

const ts = (d: Date) => ({ seconds: Math.floor(d.getTime() / 1000), nanoseconds: 0, toDate: () => d });
const NOW = new Date("2026-11-17T15:00:00Z");
const daysAgo = (n: number) => ts(new Date(NOW.getTime() - n * 86_400_000));
const row = (id: string, data: Record<string, unknown>): UserRow => mapUserDoc(id, { date_added: daysAgo(30), last_login: daysAgo(1), ...data });

// ─── UserRow: rate + timezone ──────────────────────────────────────────────

test("hourly rate: wage_override first, then hourly_rate; text numbers; 0 kept; junk is none", () => {
  assert.equal(row("t", { wage_override: 6, hourly_rate: 4 }).hourlyRate, 6);
  assert.equal(row("t", { hourly_rate: 4.5 }).hourlyRate, 4.5);
  assert.equal(row("t", { hourly_rate: "5" }).hourlyRate, 5);
  assert.equal(row("t", { hourly_rate: 0 }).hourlyRate, 0);
  assert.equal(row("t", { wage_override: null, hourly_rate: 3 }).hourlyRate, 3);
  assert.equal(row("t", { hourly_rate: "abc" }).hourlyRate, null);
  assert.equal(row("t", {}).hourlyRate, null);
  assert.equal(row("t", { timezone: " Africa/Conakry " }).timezone, "Africa/Conakry");
});

// ─── F1 Needs attention ────────────────────────────────────────────────────

const family = () => [
  row("p1", { user_type: "parent", first_name: "Mariama", last_name: "Barry", "e-mail": "m@x.org", phone_number: "6465550100", country_code: "+1" }),
  row("s1", { user_type: "student", first_name: "Awa", last_name: "Barry", guardian_ids: ["p1"], phone_number: "6465550100", country_code: "+1", "e-mail": "awa.barry@alluwaleducationhub.org" }),
  row("s2", { user_type: "student", first_name: "Ali", last_name: "Barry", guardianIds: ["p1"], phone_number: "+16465550100", "e-mail": "m@x.org" }),
  // Linked only from the parent side.
  row("p2", { user_type: "parent", first_name: "Omar", last_name: "Bah", children_ids: ["s3"] }),
  row("s3", { user_type: "student", first_name: "Bilal", last_name: "Bah" }),
  // No guardian at all.
  row("s4", { user_type: "student", first_name: "Chérif", last_name: "Sow" }),
  // Adult, no guardian needed.
  row("s5", { user_type: "student", first_name: "Fanta", last_name: "Camara", is_adult_student: true }),
  // Link to an account that no longer exists.
  row("s6", { user_type: "student", first_name: "Dalanda", last_name: "Diallo", guardian_ids: ["gone"] }),
  // Archived: never listed.
  row("s7", { user_type: "student", first_name: "Eve", last_name: "Archived", is_active: false }),
  // Merged duplicate: never listed.
  row("s8", { user_type: "student", first_name: "Chérif", last_name: "Sow", merged_into: "s4", is_active: true }),
  row("t1", { user_type: "teacher", first_name: "Ibrahima", last_name: "Camara" }),
  row("t2", { user_type: "teacher", first_name: "Sekou", last_name: "Toure", hourly_rate: 0 }),
  row("t3", { user_type: "teacher", first_name: "Aisha", last_name: "Conde", hourly_rate: 5 }),
  row("t4", { user_type: "teacher", first_name: "Musa", last_name: "Kaba", wage_override: 0, hourly_rate: 5 }),
  // Never logged in: 10 days vs 3 days vs no date.
  row("n1", { user_type: "parent", first_name: "Nene", last_name: "Old", last_login: null, date_added: daysAgo(10) }),
  row("n2", { user_type: "parent", first_name: "Nene", last_name: "New", last_login: null, date_added: daysAgo(3) }),
  row("n3", { user_type: "parent", first_name: "Nene", last_name: "Nodate", last_login: null, date_added: null }),
  row("n4", { user_type: "parent", first_name: "Nene", last_name: "Seven", last_login: null, date_added: daysAgo(7) }),
];

test("no guardian: minors only, either side counts, both spellings count, dangling flagged, archived/merged skipped", () => {
  const map = needsAttention({ rows: family(), upcomingStudentIds: null, now: NOW });
  const kinds = (id: string) => (map.get(id) ?? []).map((r) => r.kind);
  assert.ok(!kinds("s1").includes("noGuardian"));
  assert.ok(!kinds("s2").includes("noGuardian"), "guardianIds spelling");
  assert.ok(!kinds("s3").includes("noGuardian"), "linked from the parent side");
  assert.ok(kinds("s4").includes("noGuardian"));
  assert.ok(!kinds("s5").includes("noGuardian"), "adult");
  assert.deepEqual(map.get("s6")?.find((r) => r.kind === "noGuardian"), { kind: "noGuardian", dangling: true });
  assert.equal(map.has("s7"), false);
  assert.equal(map.has("s8"), false);
});

test("no hourly rate: missing vs $0; wage_override 0 beats hourly_rate", () => {
  const map = needsAttention({ rows: family(), upcomingStudentIds: null, now: NOW });
  assert.deepEqual(map.get("t1")?.find((r) => r.kind === "noRate"), { kind: "noRate", zero: false });
  assert.deepEqual(map.get("t2")?.find((r) => r.kind === "noRate"), { kind: "noRate", zero: true });
  assert.equal(map.get("t3"), undefined);
  assert.deepEqual(map.get("t4")?.find((r) => r.kind === "noRate"), { kind: "noRate", zero: true });
  assert.match(reasonText({ kind: "noRate", zero: true }), /\$0/);
});

test("no upcoming class: left out until the classes are read, then every student without one", () => {
  const rows = family();
  const before = needsAttention({ rows, upcomingStudentIds: null, now: NOW });
  assert.equal(attentionCounts(before).noUpcomingClass, 0);
  const after = needsAttention({ rows, upcomingStudentIds: new Set(["s1", "s5"]), now: NOW });
  const ids = [...after].filter(([, r]) => r.some((x) => x.kind === "noUpcomingClass")).map(([id]) => id).sort();
  assert.deepEqual(ids, ["s2", "s3", "s4", "s6"]);
});

test("never logged in: at least 7 days after being added; no date, no flag", () => {
  const map = needsAttention({ rows: family(), upcomingStudentIds: null, now: NOW });
  assert.deepEqual(map.get("n1")?.find((r) => r.kind === "neverLoggedIn"), { kind: "neverLoggedIn", days: 10 });
  assert.equal(map.get("n2")?.some((r) => r.kind === "neverLoggedIn") ?? false, false);
  assert.equal(map.get("n3")?.some((r) => r.kind === "neverLoggedIn") ?? false, false);
  assert.equal(map.get("n4")?.some((r) => r.kind === "neverLoggedIn"), true);
});

test("duplicates: family sharing a phone or email is not a duplicate; same name either order, accents ignored", () => {
  const rows = [
    ...family(),
    row("d1", { user_type: "teacher", first_name: "Cherif", last_name: "SOW", hourly_rate: 5 }),
    row("d2", { user_type: "parent", first_name: "Sow", last_name: "Chérif" }),
    row("d3", { user_type: "parent", first_name: "Kadi", last_name: "One", "e-mail": " Shared@Mail.org " }),
    row("d4", { user_type: "teacher", first_name: "Kadi", last_name: "Two", email: "shared@mail.org", hourly_rate: 5 }),
    row("d5", { user_type: "parent", first_name: "Phone", last_name: "A", phone_number: "621123456", country_code: "+224" }),
    row("d6", { user_type: "teacher", first_name: "Phone", last_name: "B", phone_number: "+224621123456", hourly_rate: 5 }),
  ];
  const dup = findPossibleDuplicates(rows);
  // Parent + children share a phone and an email: no duplicate.
  for (const id of ["p1", "s1", "s2"]) assert.equal(dup.has(id), false, id);
  assert.deepEqual(dup.get("s4")?.map((o) => o.id).sort(), ["d1", "d2"]);
  assert.deepEqual(dup.get("d3")?.[0], { id: "d4", name: "Kadi Two", reasons: ["email"] });
  assert.deepEqual(dup.get("d5")?.[0].reasons, ["phone"]);
  assert.equal(dup.has("s8"), false, "merged account");
  assert.match(reasonText({ kind: "duplicate", others: dup.get("d3")! }), /^Same email as Kadi Two$/);
  assert.match(reasonText({ kind: "duplicate", others: dup.get("s4")! }), /and 1 more$/);
});

test("counts and list: a person with two reasons counts in both; list filters by reason and sorts", () => {
  const rows = family();
  const map = needsAttention({ rows, upcomingStudentIds: new Set(), now: NOW });
  const c = attentionCounts(map);
  assert.equal(c.people, map.size);
  assert.equal(c.noGuardian, 2); // s4, s6
  assert.equal(c.noRate, 3); // t1, t2, t4
  assert.equal(c.neverLoggedIn, 2); // n1, n4
  const onlyRate = attentionList(rows, map, "noRate").map((x) => x.row.id);
  assert.deepEqual(onlyRate.sort(), ["t1", "t2", "t4"]);
  const all = attentionList(rows, map, null);
  assert.ok(all[0].reasons.length >= all[all.length - 1].reasons.length);
});

// ─── F2 Login details ──────────────────────────────────────────────────────

test("WhatsApp number: with +, without + (profile country code), national 0, none", () => {
  assert.equal(whatsAppNumber("+224 621 12 34 56", ""), "224621123456");
  assert.equal(whatsAppNumber("621123456", "+224"), "224621123456");
  assert.equal(whatsAppNumber("621123456", "224"), "224621123456");
  assert.equal(whatsAppNumber("0621123456", "+224"), "224621123456");
  assert.equal(whatsAppNumber("(646) 555-0100", ""), "6465550100");
  assert.equal(whatsAppNumber("12", "+1"), null);
  assert.equal(whatsAppNumber("", "+1"), null);
});

test("WhatsApp text keeps accents and encodes in the link", () => {
  const s = row("s", { user_type: "student", first_name: "N'Famara", last_name: "Condé", student_code: "nfamara.conde" });
  const secret = ["tig", "er48", "27"].join(""); // made-up value, kept out of scanners' way
  const facts = loginFactsOf(s, secret);
  const en = loginMessage(facts, "Mariama Barry", "en");
  assert.match(en, /^Hello Mariama Barry,/);
  assert.match(en, /N'Famara Condé's login details/);
  assert.ok(en.includes(`Student ID: nfamara.conde\nPassword: ${secret}`));
  const fr = loginMessage(facts, "Mariama", "fr");
  assert.match(fr, /Identifiant élève : nfamara.conde/);
  const url = whatsAppUrl("224621123456", en);
  assert.ok(url.startsWith("https://wa.me/224621123456?text="));
  assert.equal(decodeURIComponent(url.split("text=")[1]), en);
  assert.ok(whatsAppUrl(null, "x").startsWith("https://wa.me/?text="));
});

test("guardian contacts: both sides, email from either field, aliases dropped, missing accounts left out", () => {
  const rows = [
    row("g1", { user_type: "parent", first_name: "Awa", last_name: "One", "e-mail": "AWA@x.org", phone_number: "621123456", country_code: "+224" }),
    row("g2", { user_type: "parent", first_name: "Bo", last_name: "Two", email: "bo@x.org", children_ids: ["k"] }),
    row("g3", { user_type: "parent", first_name: "Cy", last_name: "Three", "e-mail": "cy.three@alluwaleducationhub.org" }),
    row("k", { user_type: "student", first_name: "Kid", last_name: "K", guardian_ids: ["g1", "gone"], guardianIds: ["g3"] }),
  ];
  const byId = new Map(rows.map((r) => [r.id, r]));
  const c = guardianContacts(rows[3], rows, byId);
  assert.deepEqual(
    c.map((x) => [x.id, x.email, x.whatsApp, x.onStudentDoc]),
    [
      ["g1", "awa@x.org", "224621123456", true],
      ["g2", "bo@x.org", null, false],
      ["g3", "", null, true],
    ],
  );
  assert.equal(guardianEmail({ email: "", otherEmail: "" }), "");
});

test("login problems and email result text", () => {
  assert.match(loginDetailsProblem({ storedStudentCode: "" }, "x")!, /no Student ID/);
  assert.match(loginDetailsProblem({ storedStudentCode: "a.b" }, "")!, /No password/);
  assert.equal(loginDetailsProblem({ storedStudentCode: "a.b" }, null), null);
  assert.equal(loginDetailsProblem({ storedStudentCode: "a.b" }, "p"), null);
  assert.deepEqual(emailResultText({ sentTo: ["A", "B"], failed: [], noEmail: [] }), { text: "Login details emailed to A and B.", tone: "ok" });
  assert.equal(emailResultText({ sentTo: ["A"], failed: ["B"], noEmail: ["C"] }).tone, "error");
});

// ─── F4 Bulk ───────────────────────────────────────────────────────────────

const people = () => [
  row("me", { user_type: "admin", first_name: "Me", last_name: "Admin" }),
  row("a", { user_type: "student", first_name: "Ann", last_name: "A" }),
  row("b", { user_type: "student", first_name: "Bob", last_name: "B", is_active: false }),
  row("c", { user_type: "teacher", first_name: "Cat", last_name: "C", ai_tutor_enabled: true }),
  row("d", { user_type: "parent", first_name: "Dan", last_name: "D" }),
];

test("bulk plan: self always left out; archived in an archive run; types; AI Tutor states", () => {
  const sel = people();
  const archive = planBulk("archive", sel, "me");
  assert.deepEqual(archive.targets.map((r) => r.id), ["a", "c", "d"]);
  assert.deepEqual(archive.skipped.map((s) => [s.id, s.reason]), [["me", "That's you"], ["b", "Already archived"]]);
  assert.deepEqual(planBulk("restore", sel, "me").targets.map((r) => r.id), ["b"]);
  assert.deepEqual(planBulk("resetPassword", sel, "me").targets.map((r) => r.id), ["a", "b"]);
  assert.deepEqual(planBulk("aiTutorOn", sel, "me").targets.map((r) => r.id), ["a"]);
  assert.deepEqual(planBulk("aiTutorOff", sel, "me").targets.map((r) => r.id), ["c"]);
  assert.equal(skipReason("aiTutorOn", sel[2], "me"), "Archived");
  assert.equal(skipReason("aiTutorOn", sel[4], "me"), "AI Tutor is for students and teachers");
  assert.deepEqual(planBulk("export", sel, "me").targets.length, 5);
  assert.deepEqual(planBulk("archive", [], "me"), { kind: "archive", targets: [], skipped: [] });
  assert.equal(planBulk("archive", [sel[0]], "me").targets.length, 0);
});

test("bulk run: one at a time, keeps going after a failure, stops when asked", async () => {
  let running = 0;
  let maxRunning = 0;
  const order: string[] = [];
  const progress: number[] = [];
  const results = await runBulk(
    people().slice(1),
    async (r) => {
      running += 1;
      maxRunning = Math.max(maxRunning, running);
      await new Promise((res) => setTimeout(res, 2));
      order.push(r.id);
      running -= 1;
      if (r.id === "b") throw Object.assign(new Error("boom"), { code: "permission-denied" });
      return r.id.toUpperCase();
    },
    (e) => (e as Error).message,
    (done) => progress.push(done),
  );
  assert.equal(maxRunning, 1);
  assert.deepEqual(order, ["a", "b", "c", "d"]);
  assert.deepEqual(progress, [1, 2, 3, 4]);
  assert.deepEqual(results.map((r) => r.ok), [true, false, true, true]);
  assert.equal(results[1].ok === false && results[1].error, "boom");
  assert.equal(resultSummary("archive", results, 1, false), "3 people archived. 1 failed. 1 left out.");
  let n = 0;
  const stopped = await runBulk(people(), async () => (n += 1), String, undefined, () => n >= 2);
  assert.equal(stopped.length, 2);
});

test("bulk confirm text, selection pruning and select-all state", () => {
  const plan = planBulk("resetPassword", people(), "me");
  assert.deepEqual(confirmText(plan), { title: "Reset 2 students' passwords?", skippedLine: "3 people are left out:" });
  assert.equal(confirmText(planBulk("archive", [people()[1]], "me")).title, "Archive 1 person?");
  const sel = new Set(["a", "b", "x"]);
  assert.deepEqual([...pruneSelection(sel, ["a", "b", "c"])], ["a", "b"]);
  const same = new Set(["a"]);
  assert.equal(pruneSelection(same, ["a", "b"]), same);
  assert.equal(selectAllState(new Set(), []), "none");
  assert.equal(selectAllState(new Set(["a"]), ["a", "b"]), "some");
  assert.equal(selectAllState(new Set(["a", "b"]), ["a", "b"]), "all");
});

// ─── F5 Panel facts ────────────────────────────────────────────────────────

const inv = (id: string, d: Record<string, unknown>) => ({ id, data: { currency: "USD", due_date: "2026-11-30", ...d } });

test("owed: partial payments, cancelled invoices, overdue part, dedupe across both reads, other currency", () => {
  const docs = [
    inv("i1", { total_amount: 100, paid_amount: 40 }),
    inv("i2", { total_amount: 80, paid_amount: 0, due_date: "2026-11-01" }),
    inv("i3", { total_amount: 50, paid_amount: 0, status: "cancelled" }),
    inv("i4", { total_amount: 60, paid_amount: 60 }),
    inv("i1", { total_amount: 100, paid_amount: 40 }),
    inv("i5", { total_amount: 40000, currency: "GNF" }),
  ];
  const o = owedFromInvoices(docs, NOW);
  assert.equal(o.owed.get("USD"), 140);
  assert.equal(o.late.get("USD"), 80);
  assert.equal(o.openInvoices, 3);
  assert.equal(o.partlyPaid, 1);
  assert.match(owedText(o), /^\$140\.00 \+ GNF/);
  assert.match(owedDetail(o), /3 unpaid invoices · 1 partly paid · \$80\.00 overdue/);
  const none = owedFromInvoices([inv("x", { total_amount: 10, status: "cancelled" })], NOW);
  assert.equal(owedText(none), "Nothing owed");
});

const shift = (id: string, start: string, status: string, extra: Record<string, unknown> = {}) =>
  mapPanelShift(id, { shift_start: ts(new Date(start)), shift_end: ts(new Date(new Date(start).getTime() + 3_600_000)), status, ...extra })!;

test("attendance this month: the Progress formula, this month only, unmarked not counted, archive merged", () => {
  const now = new Date(2026, 10, 17, 12);
  const live = [
    shift("a", new Date(2026, 10, 2, 10).toISOString(), "completed"),
    shift("b", new Date(2026, 10, 4, 10).toISOString(), "fullyCompleted"),
    shift("c", new Date(2026, 10, 6, 10).toISOString(), "missed"),
    shift("d", new Date(2026, 10, 8, 10).toISOString(), "cancelled"),
    shift("e", new Date(2026, 10, 10, 10).toISOString(), "scheduled"),
    shift("f", new Date(2026, 9, 30, 10).toISOString(), "completed"),
    shift("g", new Date(2026, 10, 20, 10).toISOString(), "completed"),
    shift("h", new Date(2026, 10, 12, 10).toISOString(), "completed", { shift_category: "leadership" }),
  ];
  const archived = [shift("a", new Date(2026, 10, 2, 10).toISOString(), "missed"), shift("z", new Date(2026, 10, 1, 9).toISOString(), "partiallyCompleted")];
  const merged = mergeShifts(live, archived);
  assert.equal(merged.find((s) => s.id === "a")!.status, "completed", "live copy wins");
  const a = monthAttendance(merged, now);
  assert.deepEqual(a, { attended: 3, missed: 1, cancelled: 1, tracked: 5, rate: 0.6 });
  assert.equal(attendanceText(a), "3 of 5 classes · 60%");
  assert.equal(attendanceText(monthAttendance([], now)), "No classes marked yet this month");
});

test("next class: in progress first, cancelled skipped", () => {
  const now = new Date("2026-11-17T15:30:00Z");
  const list = [
    shift("x", "2026-11-17T15:00:00Z", "active"),
    shift("y", "2026-11-17T18:00:00Z", "scheduled"),
    shift("c", "2026-11-17T16:00:00Z", "cancelled"),
  ];
  assert.deepEqual(nextClass(list, now), { shift: list[0], now: true });
  assert.equal(nextClass(list, new Date("2026-11-17T16:30:00Z"))!.shift.id, "y");
  assert.equal(nextClass([], now), null);
});

test("local time: DST-correct, no-DST zones, invalid zone, none", () => {
  assert.equal(isValidTimeZone("America/Regina"), true);
  assert.equal(isValidTimeZone("Mars/Base"), false);
  // New York changes clocks; Regina (no DST) and Monrovia (no DST) do not.
  const summer = new Date("2026-07-01T12:00:00Z");
  const winter = new Date("2026-12-01T12:00:00Z");
  assert.equal(zoneOffsetMinutes("America/New_York", summer), -240);
  assert.equal(zoneOffsetMinutes("America/New_York", winter), -300);
  assert.equal(zoneOffsetMinutes("America/Regina", summer), -360);
  assert.equal(zoneOffsetMinutes("America/Regina", winter), -360);
  assert.equal(zoneOffsetMinutes("Africa/Monrovia", winter), 0);
  const w = localTime("Africa/Monrovia", winter, "America/New_York");
  assert.ok(w && "time" in w);
  assert.equal(w && "relative" in w ? w.relative : "", "5 hours ahead of you");
  assert.equal(w && "offset" in w ? w.offset : "", "UTC+0");
  const s = localTime("Africa/Monrovia", summer, "America/New_York");
  assert.equal(s && "relative" in s ? s.relative : "", "4 hours ahead of you");
  const r = localTime("America/Regina", winter, "America/New_York");
  assert.equal(r && "relative" in r ? r.relative : "", "1 hour behind you");
  const india = localTime("Asia/Kolkata", winter, "UTC");
  assert.equal(india && "offset" in india ? india.offset : "", "UTC+5:30");
  assert.deepEqual(localTime("Mars/Base", winter, "UTC"), { invalid: "Mars/Base" });
  assert.equal(localTime("", winter, "UTC"), null);
});

// ─── F7 Saved filters ──────────────────────────────────────────────────────

test("saved filters: parse safely, unique names, limit, rename, delete", () => {
  const parsed = parseSavedFilters({
    filters: [
      { id: "a", name: "Minors", tab: "users", type: "student", kind: "minor", status: "any", parentId: "", search: "" },
      { id: "a", name: "dup id" },
      { id: "b", name: "Bad values", tab: "x", type: "y", kind: "z", status: "w" },
      { name: "no id" },
      "junk",
    ],
  });
  assert.deepEqual(parsed.map((f) => f.id), ["a", "b"]);
  assert.deepEqual([parsed[1].tab, parsed[1].type, parsed[1].kind, parsed[1].status, parsed[1].parentId], ["users", "all", "all", "any", null]);
  assert.match(nameProblem(" minors ", parsed, null)!, /already/);
  assert.equal(nameProblem("Minors", parsed, "a"), null);
  assert.match(nameProblem("  ", parsed, null)!, /name/);
  const full = Array.from({ length: MAX_SAVED_FILTERS }, (_, i) => ({ ...parsed[0], id: `f${i}`, name: `n${i}` }));
  assert.equal(upsertFilter(full, { ...parsed[0], id: "new" }), "full");
  assert.equal((upsertFilter(full, { ...parsed[0], id: "f3", name: "x" }) as SavedFilter[])[3].name, "x");
  assert.equal(renameFilter(parsed, "a", "  Kids ")[0].name, "Kids");
  assert.deepEqual(removeFilter(parsed, "a").map((f) => f.id), ["b"]);
  assert.deepEqual(parseSavedFilters(null), []);
});

test("saved filters: save the view, apply it, a deleted parent is dropped and reported", () => {
  const view = { ...NO_FILTERS, type: "student" as const, kind: "minor" as const, status: "never" as const, search: "ba" };
  const saved = filterFromView("f1", "Minor never", "users", view);
  assert.equal(isApplied(saved, "users", view), true);
  const applied = applySavedFilter(saved, () => true);
  assert.deepEqual(applied, { tab: "users", filters: { ...view, parentId: null }, droppedParent: false });
  const withParent = filterFromView("f2", "Barry family", "users", { ...NO_FILTERS, parentId: "p1" });
  assert.deepEqual(applySavedFilter(withParent, (id) => id === "p1").filters.parentId, "p1");
  const gone = applySavedFilter(withParent, () => false);
  assert.equal(gone.droppedParent, true);
  assert.equal(gone.filters.parentId, null);
  assert.equal(describeFilter(withParent, () => null), "Parent: account no longer exists");
  assert.equal(describeFilter(saved, () => null), "Students · Minors · Never logged in · “ba”");
  // Kind only means something for students.
  assert.equal(filterFromView("f3", "T", "users", { ...NO_FILTERS, type: "teacher", kind: "minor" }).kind, "all");
});

test("a server message that ends with a full stop is not doubled", async () => {
  const { failed } = await import("../adminUsersActions.ts");
  assert.equal(failed("Could not email A", { code: "functions/failed-precondition", message: "Email is not set up on this server, so nothing was sent." }), "Could not email A: Email is not set up on this server, so nothing was sent.");
});
