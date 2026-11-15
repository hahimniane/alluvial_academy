import assert from "node:assert/strict";
import { test } from "node:test";
import {
  PARENT_SIDEBAR_SECTIONS,
  activeParentItemId,
  applySidebarPreferences,
  autoCollapseForSection,
  filterSidebar,
  needsGuardianIdsFallback,
  parentChildFromDoc,
  parentCutoverAllows,
  parentDisplayName,
  parentGreeting,
  parseSidebarPreferences,
  presenceWriteDue,
  reorderSections,
  resolveParentChildren,
  roleColor,
  roleDisplayName,
  serializeSidebarPreferences,
  sidebarLabel,
} from "../parentWeb.ts";
import { activeRoleOf, allRolesOf, otherRolesOf } from "../roles.ts";

// ─── Cut-over switch ───

test("the switch fails closed: no document, off, unknown mode or no list keeps parents on Flutter", () => {
  assert.equal(parentCutoverAllows(null, "p1"), false);
  assert.equal(parentCutoverAllows(undefined, "p1"), false);
  assert.equal(parentCutoverAllows({ mode: "off" }, "p1"), false);
  assert.equal(parentCutoverAllows({ mode: "everyone" }, "p1"), false);
  assert.equal(parentCutoverAllows({ parentIds: ["p1"] }, "p1"), false);
  assert.equal(parentCutoverAllows({ mode: "allowlist" }, "p1"), false);
  assert.equal(parentCutoverAllows({ mode: "allowlist", parentIds: "p1" }, "p1"), false);
});

test("allowlist moves only the named parents; all moves everyone; empty uid never moves", () => {
  const data = { mode: "allowlist", parentIds: ["p1", "p2"] };
  assert.equal(parentCutoverAllows(data, "p1"), true);
  assert.equal(parentCutoverAllows(data, "p3"), false);
  assert.equal(parentCutoverAllows({ mode: " ALL " }, "anyone"), true);
  assert.equal(parentCutoverAllows({ mode: "all" }, ""), false);
});

// ─── Children (ParentService.getParentChildren) ───

test("a child maps exactly as ParentService does, with each fallback field", () => {
  assert.deepEqual(parentChildFromDoc("s1", { first_name: " Aisha ", last_name: "Bah", student_code: " AB12 ", kiosk_code: "K9", "e-mail": "a@x.org", email: "b@x.org" }), {
    id: "s1",
    name: "Aisha Bah",
    studentCode: "AB12",
    kioskCode: "K9",
    email: "a@x.org",
  });
  assert.deepEqual(parentChildFromDoc("s2", { studentCode: "SC", email: "b@x.org" }), {
    id: "s2",
    name: "s2",
    studentCode: "SC",
    kioskCode: null,
    email: "b@x.org",
  });
  assert.equal(parentChildFromDoc("s3", { student_id: "ID7" }).studentCode, "ID7");
  assert.equal(parentChildFromDoc("s4", { first_name: "Only" }).name, "Only");
  assert.equal(parentChildFromDoc("s5", {}).email, null);
});

test("guardianIds is asked only when guardian_ids finds nobody", () => {
  assert.equal(needsGuardianIdsFallback(0), true);
  assert.equal(needsGuardianIdsFallback(1), false);
  const primary = [{ id: "a", data: { first_name: "Amadou" } }];
  const fallback = [{ id: "b", data: { first_name: "Binta" } }];
  assert.deepEqual(resolveParentChildren(primary, fallback).map((c) => c.id), ["a"]);
  assert.deepEqual(resolveParentChildren([], fallback).map((c) => c.id), ["b"]);
  assert.deepEqual(resolveParentChildren([], null), []);
});

test("children sort like Dart's String.compareTo: code units, capitals first", () => {
  const docs = ["aminata", "Zainab", "Binta", "binta"].map((first, i) => ({ id: `s${i}`, data: { first_name: first } }));
  assert.deepEqual(resolveParentChildren(docs, null).map((c) => c.name), ["Binta", "Zainab", "aminata", "binta"]);
});

// ─── Names ───

test("top-bar name falls back to Parent; greeting falls back to Parent Dashboard", () => {
  assert.equal(parentDisplayName({ first_name: "Salematou", last_name: " Bah " }), "Salematou Bah");
  assert.equal(parentDisplayName({}), "Parent");
  assert.equal(parentDisplayName(null), "Parent");
  assert.equal(parentGreeting({ first_name: "Salematou" }), "Welcome, Salematou");
  assert.equal(parentGreeting({ first_name: "  ", last_name: "Bah" }), "Parent Dashboard");
});

// ─── Presence ───

test("presence writes are at least 20 seconds apart, the first always goes", () => {
  assert.equal(presenceWriteDue(null, 0), true);
  assert.equal(presenceWriteDue(1_000, 20_999), false);
  assert.equal(presenceWriteDue(1_000, 21_000), true);
});

// ─── Roles ───

test("roles come out in the Flutter switcher order; student is kept for the parent shell", () => {
  assert.deepEqual(allRolesOf({ user_type: "parent", secondary_roles: ["Student"] }), ["parent", "student"]);
  assert.deepEqual(allRolesOf({ user_type: "admin", secondary_roles: ["parent"] }), ["admin", "teacher", "parent"]);
  assert.deepEqual(otherRolesOf({ user_type: "parent", secondary_roles: ["student"] }), ["parent"]);
});

test("active role is the saved switcher role while the account holds it, else user_type", () => {
  const record = { user_type: "Parent", secondary_roles: ["student"] };
  assert.equal(activeRoleOf(record, "student"), "student");
  assert.equal(activeRoleOf(record, "teacher"), "parent");
  assert.equal(activeRoleOf(record, null), "parent");
  assert.equal(activeRoleOf(undefined, "parent"), "");
});

test("role chips use the switcher colours and names", () => {
  assert.equal(roleColor("parent"), "#F59E0B");
  assert.equal(roleColor("super_admin"), "#EF4444");
  assert.equal(roleColor("unknown"), "#6B7280");
  assert.equal(roleDisplayName("admin"), "Administrator");
  assert.equal(roleDisplayName("circle_member"), "Member");
  assert.equal(roleDisplayName("x"), "User");
});

// ─── Sidebar ───

test("sidebar sections, items and order match SidebarConfig._getParentStructure", () => {
  assert.deepEqual(
    PARENT_SIDEBAR_SECTIONS.map((section) => [section.id, section.title, section.items.map((item) => item.label)]),
    [
      ["overview", "Overview", ["Dashboard"]],
      ["communication", "Communication", ["Chat"]],
      ["classes", "Learning", ["Classes", "Recordings", "Curriculum Books", "Quran"]],
      ["finance", "Finance", ["Invoices", "Payments"]],
      ["forms", "Forms", ["Forms"]],
      ["account", "Account", ["Profile", "Settings"]],
    ],
  );
  const colors = PARENT_SIDEBAR_SECTIONS.flatMap((section) => section.items.map((item) => `${item.id}:${item.color}`));
  assert.deepEqual(colors, [
    "dashboard:#0386FF",
    "chat:#A646F2",
    "classes:#2D8CFF",
    "recordings:#0E72ED",
    "curriculum_books:#0F766E",
    "quran:#0E7490",
    "invoices:#10B981",
    "payments:#059669",
    "forms:#EC4899",
    "profile:#6B7280",
    "settings:#6B7280",
  ]);
});

test("French labels are the app_fr.arb text; untranslated labels stay English", () => {
  const byId = Object.fromEntries(PARENT_SIDEBAR_SECTIONS.flatMap((section) => section.items).map((item) => [item.id, item]));
  assert.equal(sidebarLabel(byId.dashboard, "fr"), "Tableau de bord");
  assert.equal(sidebarLabel(byId.classes, "fr"), "Cours");
  assert.equal(sidebarLabel(byId.settings, "fr"), "Paramètres");
  assert.equal(sidebarLabel(byId.invoices, "fr"), "Invoices");
  assert.equal(sidebarLabel(byId.profile, "fr"), "Profile");
  assert.equal(sidebarLabel(PARENT_SIDEBAR_SECTIONS[0], "fr"), "Aperçu général");
  assert.equal(sidebarLabel(PARENT_SIDEBAR_SECTIONS[3], "fr"), "Finance");
  assert.equal(sidebarLabel(byId.dashboard, "en"), "Dashboard");
});

test("the active item follows the path; anything unknown is Dashboard", () => {
  assert.equal(activeParentItemId("/parent/"), "dashboard");
  assert.equal(activeParentItemId("/parent"), "dashboard");
  assert.equal(activeParentItemId("/parent/invoices/"), "invoices");
  assert.equal(activeParentItemId("/parent/invoices/abc"), "invoices");
  assert.equal(activeParentItemId("/parent/curriculum-books/"), "curriculum_books");
  assert.equal(activeParentItemId("/parent/nope/"), "dashboard");
});

test("sidebar preferences read Flutter's double-encoded value and write it back the same way", () => {
  const prefs = { sectionOrder: ["finance", "overview"], sectionExpansionState: { finance: false }, favoritedItemIds: ["invoices"] };
  const stored = serializeSidebarPreferences(prefs);
  assert.equal(typeof JSON.parse(stored), "string");
  assert.deepEqual(parseSidebarPreferences(stored), prefs);
  assert.deepEqual(parseSidebarPreferences(JSON.stringify(prefs)), prefs);
  assert.equal(parseSidebarPreferences(null), null);
  assert.equal(parseSidebarPreferences("not json"), null);
});

test("saved order applies first, unnamed sections follow in default order, folding is kept", () => {
  const ids = ["overview", "communication", "classes", "finance"];
  const prefs = { sectionOrder: ["finance", "gone", "overview"], sectionExpansionState: { finance: false }, favoritedItemIds: [] };
  assert.deepEqual(applySidebarPreferences(ids, prefs), [
    { id: "finance", expanded: false },
    { id: "overview", expanded: true },
    { id: "communication", expanded: true },
    { id: "classes", expanded: true },
  ]);
  assert.deepEqual(applySidebarPreferences(ids, null).map((s) => s.id), ids);
});

test("choosing an item opens its section and folds sections not opened by hand", () => {
  const sections = [
    { id: "overview", expanded: true },
    { id: "classes", expanded: true },
    { id: "finance", expanded: false },
  ];
  assert.deepEqual(autoCollapseForSection(sections, "finance", new Set(["overview"])), [
    { id: "overview", expanded: true },
    { id: "classes", expanded: false },
    { id: "finance", expanded: true },
  ]);
  assert.equal(autoCollapseForSection(sections, null, new Set()), sections);
});

test("reorder uses Flutter's ReorderableListView index rule", () => {
  assert.deepEqual(reorderSections(["a", "b", "c", "d"], 0, 3), ["b", "c", "a", "d"]);
  assert.deepEqual(reorderSections(["a", "b", "c", "d"], 3, 0), ["d", "a", "b", "c"]);
  assert.deepEqual(reorderSections(["a", "b", "c"], 1, 1), ["a", "b", "c"]);
});

test("search matches the shown labels; a title match keeps the whole section", () => {
  const sections = [
    { title: "Finance", items: [{ label: "Invoices" }, { label: "Payments" }] },
    { title: "Learning", items: [{ label: "Classes" }, { label: "Recordings" }] },
  ];
  assert.deepEqual(filterSidebar(sections, " fin "), [sections[0]]);
  assert.deepEqual(filterSidebar(sections, "rec"), [{ title: "Learning", items: [{ label: "Recordings" }] }]);
  assert.deepEqual(filterSidebar(sections, "zzz"), []);
  assert.equal(filterSidebar(sections, "  "), sections);
});
