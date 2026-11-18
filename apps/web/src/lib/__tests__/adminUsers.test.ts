import test from "node:test";
import assert from "node:assert/strict";
import {
  EXPORT_HEADERS,
  NO_FILTERS,
  adminUsersCutoverAllows,
  buildParentLinks,
  buildWeekSchedule,
  dartDateTimeText,
  displayNameOf,
  enrichRow,
  exportRow,
  filterRows,
  firstClassText,
  hasActiveFilters,
  isAdminRow,
  isNeverLoggedIn,
  loginEmailOf,
  mapUserDoc,
  mapWeekShift,
  matchesUserSearch,
  parentChoices,
  parentMatches,
  phoneDisplay,
  sameRow,
  scheduledHours,
  sortByName,
  storedDateText,
  toCsv,
  typeInfo,
  weekBounds,
  weeklyHoursLabel,
  type UserFilters,
} from "../adminUsers.ts";

const ts = (iso: string, nanosExtra = 0) => {
  const d = new Date(iso);
  const ms = d.getTime();
  return { seconds: Math.floor(ms / 1000), nanoseconds: (ms % 1000) * 1e6 + nanosExtra, toDate: () => new Date(ms) };
};

// ─── mapping ───────────────────────────────────────────────────────────────

test("mapUserDoc reads named fields only and never keeps others", () => {
  const row = mapUserDoc("u1", {
    first_name: "Amina",
    last_name: "Diallo",
    "e-mail": "amina@x.org",
    email: "ignored@x.org",
    phone_number: "6465550110",
    country_code: "+1",
    user_type: "student",
    student_code: "amina.diallo",
    temp_password: "secret123",
    is_adult_student: true,
    guardian_ids: ["p1", " p2 ", ""],
    guardianIds: ["p2", "p3"],
  });
  assert.equal(row.email, "amina@x.org");
  assert.equal(row.studentCode, "amina.diallo");
  assert.equal(row.kioskCode, "u1");
  assert.equal(row.isAdultStudent, true);
  assert.deepEqual(row.guardianIds, ["p1", "p2", "p3"]);
  assert.equal(JSON.stringify(row).includes("secret123"), false);
  assert.equal(Object.keys(row).includes("temp_password"), false);
});

test("missing fields fall back like Flutter", () => {
  const row = mapUserDoc("u2", {});
  assert.equal(row.isActive, true);
  assert.equal(row.isAdminTeacher, false);
  assert.equal(row.dateAddedText, "Never");
  assert.equal(row.lastLoginText, "Never");
  assert.equal(row.studentCode, "");
  assert.equal(row.kioskCode, "");
  assert.equal(row.parentPick, null);
});

test("non-string fields do not break the mapping", () => {
  const row = mapUserDoc("u3", { first_name: 42, last_name: { a: 1 }, kiosk_code: null, is_active: "false", user_type: ["x"] });
  assert.equal(row.firstName, "42");
  assert.equal(row.lastName, "");
  assert.equal(row.isActive, true);
  assert.equal(row.userType, "");
});

test("student code falls back student_code → studentCode → student_id → kiosk code → id", () => {
  assert.equal(mapUserDoc("a", { user_type: "student", studentCode: "sc" }).studentCode, "sc");
  assert.equal(mapUserDoc("a", { user_type: "student", student_id: 12 }).studentCode, "12");
  assert.equal(mapUserDoc("a", { user_type: "student", kiosk_code: "K1" }).studentCode, "K1");
  assert.equal(mapUserDoc("a", { user_type: "student", student_code: "  " }).studentCode, "a");
  assert.equal(mapUserDoc("a", { user_type: "teacher", student_code: "x" }).studentCode, "");
  // Dart `??` stops at the first non-null value, even an empty one.
  assert.equal(mapUserDoc("a", { user_type: "student", student_code: "", studentCode: "sc" }).studentCode, "a");
});

test("adult flag follows Dart ?? (is_adult_student wins when present)", () => {
  assert.equal(mapUserDoc("a", { isAdultStudent: true }).isAdultStudent, true);
  assert.equal(mapUserDoc("a", { is_adult_student: false, isAdultStudent: true }).isAdultStudent, false);
});

test("dates are shown as Dart DateTime.toString in local time", () => {
  const d = new Date(2026, 10, 15, 14, 3, 22, 123);
  assert.equal(dartDateTimeText(d), "2026-11-15 14:03:22.123");
  assert.equal(dartDateTimeText(d, 456), "2026-11-15 14:03:22.123456");
  const stamp = { seconds: Math.floor(d.getTime() / 1000), nanoseconds: 123456000, toDate: () => d };
  assert.equal(storedDateText(stamp), "2026-11-15 14:03:22.123456");
  assert.equal(storedDateText(null), "Never");
  assert.equal(storedDateText("2024-01-01"), "2024-01-01");
});

test("never logged in matches the Flutter placeholder list", () => {
  for (const t of ["", "Never", "n/a", "-", "null", "None", "xnullx", "1970-01-01 00:00:00.000", "Instance of 'X'"]) {
    assert.equal(isNeverLoggedIn({ lastLoginText: t }), true, t);
  }
  assert.equal(isNeverLoggedIn({ lastLoginText: "2026-11-15 14:03:22.123" }), false);
  assert.equal(isNeverLoggedIn(mapUserDoc("x", { last_login: ts("2026-11-15T10:00:00Z") })), false);
  assert.equal(isNeverLoggedIn(mapUserDoc("x", {})), true);
});

test("sameRow ignores fields the page does not read", () => {
  const a = mapUserDoc("u", { first_name: "A", guardian_ids: ["p"], last_login: ts("2026-11-15T10:00:00Z") });
  const b = mapUserDoc("u", { first_name: "A", guardian_ids: ["p"], last_login: ts("2026-11-15T10:00:00Z"), is_online: true, last_seen: ts("2026-11-17T10:00:00Z") });
  assert.equal(sameRow(a, b), true);
  assert.equal(sameRow(a, mapUserDoc("u", { first_name: "B", guardian_ids: ["p"] })), false);
});

// ─── tabs, links, schedule ─────────────────────────────────────────────────

const people = () => [
  mapUserDoc("t1", { first_name: "Ibrahima", last_name: "Camara", user_type: "teacher", "e-mail": "ib@x.org", last_login: ts("2026-11-16T10:00:00Z") }),
  mapUserDoc("t2", { first_name: "Hawa", last_name: "Touré", user_type: "teacher", is_admin_teacher: true }),
  mapUserDoc("a1", { first_name: "Sékou", last_name: "Condé", user_type: "admin" }),
  mapUserDoc("a2", { first_name: "Root", last_name: "Admin", user_type: "super_admin", is_active: false }),
  mapUserDoc("sr", { first_name: "Second", last_name: "Role", user_type: "teacher", secondary_roles: ["admin"] }),
  mapUserDoc("p1", { first_name: "Mariama", last_name: "Barry", user_type: "parent", "e-mail": " mb@x.org ", phone_number: "3475550187", country_code: "1" }),
  mapUserDoc("p2", { first_name: "Abdoulaye", last_name: "Sylla", user_type: "parent", is_active: false }),
  mapUserDoc("s1", { first_name: "Aminata", last_name: "Barry", user_type: "student", student_code: "aminata.barry", guardian_ids: ["p1"], last_login: ts("2026-11-15T10:00:00Z") }),
  mapUserDoc("s2", { first_name: "Alpha", last_name: "Barry", user_type: "student", guardianIds: ["p1", "p2"], is_adult_student: false }),
  mapUserDoc("s3", { first_name: "Fatou", last_name: "Keita", user_type: "student", is_adult_student: true, is_active: false }),
  mapUserDoc("s4", { first_name: "Orphan", last_name: "Link", user_type: "student", guardian_ids: ["gone"] }),
  mapUserDoc("x1", { first_name: "Circle", last_name: "Member", user_type: "circle_member" }),
  mapUserDoc("x2", {}),
];

test("admins tab = admin, super_admin or admin-teacher; secondary admin stays on Users", () => {
  const ids = people().filter(isAdminRow).map((r) => r.id);
  assert.deepEqual(ids, ["t2", "a1", "a2"]);
});

test("parent links come from students' guardian_ids + guardianIds, first guardian shown", () => {
  const links = buildParentLinks(people());
  assert.deepEqual(links.studentsByParent.get("p1"), ["s1", "s2"]);
  assert.deepEqual(links.studentsByParent.get("p2"), ["s2"]);
  assert.deepEqual(links.firstParentByStudent.get("s2"), { id: "p1", name: "Mariama Barry", email: "mb@x.org" });
  assert.deepEqual(links.firstParentByStudent.get("s4"), { id: "gone", name: "", email: "" });
  assert.equal(links.firstParentByStudent.has("s3"), false);
});

test("parent links skip students whose user_type is not exactly 'student'", () => {
  const rows = [mapUserDoc("p", { user_type: "parent" }), mapUserDoc("s", { user_type: "Student", guardian_ids: ["p"] })];
  assert.equal(buildParentLinks(rows).studentsByParent.has("p"), false);
});

test("week bounds start Monday 00:00 local and span seven days", () => {
  const { start, end } = weekBounds(new Date(2026, 10, 18, 15, 0)); // Wed Nov 18 2026
  assert.equal(start.getDay(), 1);
  assert.equal(start.getDate(), 16);
  assert.equal(start.getHours(), 0);
  assert.equal(end.getTime() - start.getTime(), 7 * 24 * 3600 * 1000);
  assert.equal(weekBounds(new Date(2026, 10, 22, 23, 0)).start.getDate(), 16); // Sunday stays in the same week
  assert.equal(weekBounds(new Date(2026, 10, 23, 0, 0)).start.getDate(), 23); // Monday starts a new one
});

test("scheduled hours: end − start, else duration_minutes, else duration", () => {
  assert.equal(scheduledHours({ shift_start: ts("2026-11-16T10:00:00Z"), shift_end: ts("2026-11-16T11:30:00Z") }), 1.5);
  assert.equal(scheduledHours({ shift_start: ts("2026-11-16T10:00:00Z"), shift_end: ts("2026-11-16T10:00:00Z"), duration_minutes: 45 }), 0.75);
  assert.equal(scheduledHours({ duration: "2" }), 2);
  assert.equal(scheduledHours({}), 0);
});

test("week schedule: teaching, not cancelled, shared between students, teachers A→Z", () => {
  const hour = (h: number) => ({ shift_start: ts("2026-11-16T10:00:00Z"), shift_end: ts(new Date(Date.parse("2026-11-16T10:00:00Z") + h * 3600000).toISOString()) });
  const week = buildWeekSchedule(
    [
      { ...hour(1), student_ids: ["s1", "s2"], teacher_name: "Ousmane Sow" },
      { ...hour(2), student_ids: ["s1"], teacher_name: "Hawa Touré", status: "missed" },
      { ...hour(1), student_ids: ["s1"], teacher_name: "Zed", status: "Cancelled" },
      { ...hour(1), student_ids: ["s1"], teacher_name: "Meet", category: "leadership" },
      { ...hour(1), student_ids: ["s1"], teacher_name: "Blank", category: "" },
      { ...hour(1), student_ids: [], teacher_name: "Nobody" },
      { ...hour(0), student_ids: ["s2"], teacher_name: "Zero" },
      { ...hour(1), student_ids: ["s2", " "], teacher_name: " " },
    ].map(mapWeekShift),
  );
  assert.deepEqual(week.get("s1"), { hours: 2.5, teachers: "Hawa Touré, Ousmane Sow" });
  assert.deepEqual(week.get("s2"), { hours: 1.5, teachers: "Ousmane Sow" });
});

test("weekly hours label: one decimal, none when whole, blank at zero", () => {
  assert.equal(weeklyHoursLabel(3), "3 hrs");
  assert.equal(weeklyHoursLabel(1.5), "1.5 hrs");
  assert.equal(weeklyHoursLabel(1.04), "1 hrs");
  assert.equal(weeklyHoursLabel(0.333333), "0.3 hrs");
  assert.equal(weeklyHoursLabel(0), "");
  assert.equal(weeklyHoursLabel(undefined), "");
});

// ─── filters ───────────────────────────────────────────────────────────────

const run = (over: Partial<UserFilters>) => {
  const rows = people();
  const links = buildParentLinks(rows);
  const out = filterRows(rows, { ...NO_FILTERS, ...over }, links);
  return { users: out.users.map((r) => r.id), admins: out.admins.map((r) => r.id) };
};

test("no filters: everyone, split by tab", () => {
  const { users, admins } = run({});
  assert.deepEqual(users, ["t1", "sr", "p1", "p2", "s1", "s2", "s3", "s4", "x1", "x2"]);
  assert.deepEqual(admins, ["t2", "a1", "a2"]);
});

test("type narrows the Users tab only", () => {
  assert.deepEqual(run({ type: "teacher" }), { users: ["t1", "sr"], admins: ["t2", "a1", "a2"] });
  assert.deepEqual(run({ type: "parent" }).users, ["p1", "p2"]);
});

test("minor / adult apply to students", () => {
  assert.deepEqual(run({ type: "student", kind: "minor" }).users, ["s1", "s2", "s4"]);
  assert.deepEqual(run({ type: "student", kind: "adult" }).users, ["s3"]);
  assert.deepEqual(run({ type: "teacher", kind: "adult" }).users, ["t1", "sr"]);
});

test("status narrows both tabs and combines with type", () => {
  assert.deepEqual(run({ status: "archived" }), { users: ["p2", "s3"], admins: ["a2"] });
  assert.deepEqual(run({ status: "active", type: "parent" }).users, ["p1"]);
  assert.deepEqual(run({ status: "never" }), { users: ["sr", "p1", "p2", "s2", "s3", "s4", "x1", "x2"], admins: ["t2", "a1", "a2"] });
});

test("parent filter shows that parent's students", () => {
  assert.deepEqual(run({ parentId: "p1" }), { users: ["s1", "s2"], admins: ["t2", "a1", "a2"] });
  assert.deepEqual(run({ parentId: "p2", status: "active" }).users, ["s2"]);
  assert.deepEqual(run({ parentId: "nobody" }).users, []);
});

test("search narrows both tabs", () => {
  assert.deepEqual(run({ search: "barry" }), { users: ["p1", "s1", "s2"], admins: [] });
  assert.deepEqual(run({ search: "aminata barry" }).users, ["s1"]);
  assert.deepEqual(run({ search: "aminatabarry" }).users, ["s1"]);
  assert.deepEqual(run({ search: "teacher" }), { users: ["t1", "sr"], admins: ["t2"] });
  assert.deepEqual(run({ search: "347-555-0187" }).users, ["p1"]);
  assert.deepEqual(run({ search: "1 347 555 0187" }).users, ["p1"]);
  assert.deepEqual(run({ search: "condé" }).admins, ["a1"]);
});

test("hasActiveFilters", () => {
  assert.equal(hasActiveFilters(NO_FILTERS), false);
  assert.equal(hasActiveFilters({ ...NO_FILTERS, search: "  " }), false);
  assert.equal(hasActiveFilters({ ...NO_FILTERS, parentId: "p" }), true);
});

test("search matches kiosk code, uid and title", () => {
  const row = mapUserDoc("UID123", { first_name: "K", user_type: "teacher", kiosk_code: "AMTC04712345", title: "Coordinator" });
  assert.equal(matchesUserSearch(row, "amtc047"), true);
  assert.equal(matchesUserSearch(row, "uid12"), true);
  assert.equal(matchesUserSearch(row, "coordin"), true);
});

test("sort by name both ways, unicode and empty names", () => {
  const rows = [mapUserDoc("b", { first_name: "Émile" }), mapUserDoc("a", { first_name: "abdou" }), mapUserDoc("c", { first_name: "Zara" }), mapUserDoc("d", {})];
  assert.deepEqual(sortByName(rows, true).map((r) => r.id), ["a", "d", "b", "c"]);
  assert.deepEqual(sortByName(rows, false).map((r) => r.id), ["c", "b", "d", "a"]);
});

test("displayNameOf falls back to code, email, id", () => {
  assert.equal(displayNameOf(mapUserDoc("i", { user_type: "student", student_code: "sc" })), "sc");
  assert.equal(displayNameOf(mapUserDoc("i", { "e-mail": "e@x" })), "e@x");
  assert.equal(displayNameOf(mapUserDoc("i", {})), "i");
});

// ─── parent picker ─────────────────────────────────────────────────────────

test("parent choices: all parents incl. archived, most students first, then name", () => {
  const rows = [...people(), mapUserDoc("p3", { name: "Zz Stored Name", user_type: "parent", email: "alt@x.org" })];
  const choices = parentChoices(rows, buildParentLinks(rows));
  assert.deepEqual(choices.map((c) => [c.id, c.studentCount]), [["p1", 2], ["p2", 1], ["p3", 0]]);
  assert.equal(choices[2].name, "Zz Stored Name");
  assert.equal(choices[2].email, "alt@x.org");
  assert.equal(parentMatches(choices[0], "13475550187"), true);
  assert.equal(parentMatches(choices[0], "mariama"), true);
  assert.equal(parentMatches(choices[2], "alt@"), true);
  assert.equal(parentMatches(choices[2], "p3"), true);
});

// ─── export ────────────────────────────────────────────────────────────────

test("export keeps today's 13 columns and values", () => {
  assert.equal(EXPORT_HEADERS.length, 13);
  const rows = people();
  const links = buildParentLinks(rows);
  const week = buildWeekSchedule([mapWeekShift({ duration_minutes: 90, student_ids: ["s1"], teacher_name: "Ousmane Sow" })]);
  const s1 = enrichRow(rows.find((r) => r.id === "s1")!, links, week);
  const out = exportRow(s1);
  assert.equal(out.length, 13);
  assert.deepEqual(out.slice(0, 11), ["Aminata", "Barry", "", "", "student", "aminata.barry", "s1", "Mariama Barry", "mb@x.org", "Ousmane Sow", "1.5 hrs"]);
  assert.equal(out[11], "Never");
  assert.match(out[12], /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$/);
  const t1 = exportRow(enrichRow(rows[0], links, week));
  assert.deepEqual(t1.slice(5, 11), ["", "", "", "", "", ""]);
});

test("csv: quotes only when needed, CRLF between rows, no BOM", () => {
  const csv = toCsv(["A", "B"], [["x,y", 'say "hi"'], ["line\nbreak", "plain"]]);
  assert.equal(csv, 'A,B\r\n"x,y","say ""hi"""\r\n"line\nbreak",plain');
  assert.equal(csv.charCodeAt(0), 65);
});

// ─── display ───────────────────────────────────────────────────────────────

test("phone display adds the country code once", () => {
  assert.equal(phoneDisplay({ countryCode: "1", phone: "6465550110" }), "+1 6465550110");
  assert.equal(phoneDisplay({ countryCode: "+1", phone: "16465550110" }), "16465550110");
  assert.equal(phoneDisplay({ countryCode: "+33", phone: "+33 6 12 34" }), "+33 6 12 34");
  assert.equal(phoneDisplay({ countryCode: "", phone: "620000000" }), "620000000");
  assert.equal(phoneDisplay({ countryCode: "1", phone: "" }), "");
});

test("type labels", () => {
  assert.equal(typeInfo(mapUserDoc("a", { user_type: "student", is_adult_student: true })).label, "Adult student");
  assert.equal(typeInfo(mapUserDoc("a", { user_type: "super_admin" })).label, "Super admin");
  assert.equal(typeInfo(mapUserDoc("a", { user_type: "circle_member" })).label, "Circle member");
  assert.equal(typeInfo(mapUserDoc("a", {})).label, "No type");
});

test("login email only from a stored student_code", () => {
  assert.equal(loginEmailOf(mapUserDoc("a", { user_type: "student", student_code: "ab.cd" })), "ab.cd@alluwaleducationhub.org");
  assert.equal(loginEmailOf(mapUserDoc("a", { user_type: "student" })), "");
});

test("first class text for students only", () => {
  assert.equal(firstClassText(mapUserDoc("a", { user_type: "student" })), "Not yet");
  assert.equal(firstClassText(mapUserDoc("a", { user_type: "student", first_class_at: ts("2026-09-08T16:00:00Z") })), "Sep 8, 2026");
  assert.equal(firstClassText(mapUserDoc("a", { user_type: "teacher", first_class_at: ts("2026-09-08T16:00:00Z") })), "");
});

// ─── cutover ───────────────────────────────────────────────────────────────

test("cutover fails closed", () => {
  assert.equal(adminUsersCutoverAllows(null, "u"), false);
  assert.equal(adminUsersCutoverAllows({}, "u"), false);
  assert.equal(adminUsersCutoverAllows({ mode: "off", adminIds: ["u"] }, "u"), false);
  assert.equal(adminUsersCutoverAllows({ mode: "weird" }, "u"), false);
  assert.equal(adminUsersCutoverAllows({ mode: "allowlist" }, "u"), false);
  assert.equal(adminUsersCutoverAllows({ mode: "allowlist", adminIds: "u" }, "u"), false);
  assert.equal(adminUsersCutoverAllows({ mode: "allowlist", adminIds: ["v"] }, "u"), false);
  assert.equal(adminUsersCutoverAllows({ mode: " AllowList ", adminIds: ["u"] }, "u"), true);
  assert.equal(adminUsersCutoverAllows({ mode: "all" }, ""), false);
  assert.equal(adminUsersCutoverAllows({ mode: "ALL" }, "u"), true);
});

test("CSV export: typed formulas are neutralised, numbers and plain text are not", async () => {
  const { toCsv, csvSafe } = await import("../adminUsers.ts");
  assert.equal(csvSafe('=HYPERLINK("http://x","y")'), `'=HYPERLINK("http://x","y")`);
  assert.equal(csvSafe("+Zz-Formula"), "'+Zz-Formula");
  assert.equal(csvSafe("@zz.formula@example.invalid"), "'@zz.formula@example.invalid");
  assert.equal(csvSafe("+224 620 00 00 00"), "'+224 620 00 00 00");
  assert.equal(csvSafe("+224621123456"), "+224621123456");
  assert.equal(csvSafe("-12"), "-12");
  assert.equal(csvSafe("Aminata"), "Aminata");
  assert.equal(csvSafe(""), "");
  assert.equal(toCsv(["A", "B"], [['=1+1', 'x,"y"']]), `A,B\r\n'=1+1,"x,""y"""`);
});

test("isViewerRow: by document id or by the profile's uid field", async () => {
  const { isViewerRow, mapUserDoc } = await import("../adminUsers.ts");
  const own = mapUserDoc("admin@example.invalid", { user_type: "admin", uid: "u1" });
  assert.equal(own.uid, "u1");
  assert.equal(isViewerRow(own, "u1"), true);
  assert.equal(isViewerRow(mapUserDoc("u1", { user_type: "admin" }), "u1"), true);
  assert.equal(isViewerRow(mapUserDoc("u2", { user_type: "admin", uid: "u2" }), "u1"), false);
  assert.equal(isViewerRow(mapUserDoc("u2", {}), ""), false);
});
