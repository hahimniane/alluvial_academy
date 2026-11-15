/**
 * Pure rules for the parent web area: who is moved, who a parent's children
 * are, and how the parent sidebar is laid out and remembered. No Firebase here,
 * so every rule is unit-tested against the Flutter behaviour it mirrors.
 */

type Data = Record<string, unknown>;

// ─── Cut-over switch ───────────────────────────────────────────────────────

/**
 * `settings/parent_web_cutover` — the same document the Flutter app reads
 * (lib/core/services/parent_web_cutover.dart):
 *
 *   mode: 'off' | 'allowlist' | 'all'
 *   parentIds: [uid, ...]   // used when mode == 'allowlist'
 *
 * Fails closed on both sides: a missing document, an unknown mode or a parent
 * not on the list keeps that parent on the Flutter app they have today.
 */
export const PARENT_CUTOVER_DOC = { collection: "settings", id: "parent_web_cutover" } as const;

export function parentCutoverAllows(data: Data | undefined | null, uid: string): boolean {
  if (!data || !uid) return false;
  const mode = String(data.mode ?? "off").trim().toLowerCase();
  if (mode === "all") return true;
  if (mode !== "allowlist") return false;
  const ids = data.parentIds;
  return Array.isArray(ids) && ids.map(String).includes(uid);
}

// ─── Children (ParentService.getParentChildren) ────────────────────────────

export type ParentChild = {
  id: string;
  name: string;
  studentCode: string | null;
  kioskCode: string | null;
  email: string | null;
};

/** Maps one student document exactly as ParentService.getParentChildren does. */
export function parentChildFromDoc(id: string, data: Data): ParentChild {
  const first = String(data.first_name ?? "").trim();
  const last = String(data.last_name ?? "").trim();
  const name = `${first} ${last}`.trim();
  const studentCode = String(data.student_code ?? data.studentCode ?? data.student_id ?? "").trim();
  const kioskCode = String(data.kiosk_code ?? "").trim();
  const email = data["e-mail"] ?? data.email;
  return {
    id,
    name: name || id,
    studentCode: studentCode || null,
    kioskCode: kioskCode || null,
    email: email == null ? null : String(email),
  };
}

/**
 * Children are the students whose `guardian_ids` holds the parent. The
 * `guardianIds` spelling is asked only when the first query finds nobody, so
 * a family with children on both spellings shows only the `guardian_ids`
 * ones — same as Flutter. Sorted by name with a plain code-unit compare, which
 * is what Dart's String.compareTo does (so "Zainab" sorts before "aminata").
 */
export function resolveParentChildren(
  primary: Array<{ id: string; data: Data }>,
  fallback: Array<{ id: string; data: Data }> | null,
): ParentChild[] {
  const docs = primary.length > 0 ? primary : fallback ?? [];
  return docs.map((entry) => parentChildFromDoc(entry.id, entry.data)).sort((a, b) => codeUnitCompare(a.name, b.name));
}

/** True when the fallback (`guardianIds`) query must run. */
export function needsGuardianIdsFallback(primaryCount: number) {
  return primaryCount === 0;
}

function codeUnitCompare(a: string, b: string) {
  if (a === b) return 0;
  return a < b ? -1 : 1;
}

// ─── Names ─────────────────────────────────────────────────────────────────

/** Top-bar name: "first last", or "Parent" when both are empty (LAYOUT:259-263). */
export function parentDisplayName(data: Data | null | undefined) {
  const first = String(data?.first_name ?? "").trim();
  const last = String(data?.last_name ?? "").trim();
  return `${first} ${last}`.trim() || "Parent";
}

/** Dashboard heading: "Welcome, {first_name}" or "Parent Dashboard" (PDS:151-160). */
export function parentGreeting(data: Data | null | undefined) {
  const first = String(data?.first_name ?? "").trim();
  return first ? `Welcome, ${first}` : "Parent Dashboard";
}

// ─── Presence heartbeat (RoleBasedDashboard._updatePresence) ───────────────

export const PRESENCE_INTERVAL_MS = 60_000;
export const PRESENCE_MIN_INTERVAL_MS = 20_000;

/**
 * Flutter skips any presence write that comes within 20 s of the previous one —
 * the offline write included.
 */
export function presenceWriteDue(lastWriteMs: number | null, nowMs: number) {
  return lastWriteMs === null || nowMs - lastWriteMs >= PRESENCE_MIN_INTERVAL_MS;
}

// ─── Role chips (RoleSwitcher) ─────────────────────────────────────────────

/** Chip colours from RoleSwitcher._getRoleColor. */
export function roleColor(role: string) {
  switch (role) {
    case "admin":
    case "super_admin":
      return "#EF4444";
    case "teacher":
      return "#0386FF";
    case "parent":
      return "#F59E0B";
    case "student":
      return "#10B981";
    default:
      return "#6B7280";
  }
}

/** Chip text from UserRoleService.getRoleDisplayName. */
export function roleDisplayName(role: string) {
  switch (role) {
    case "admin":
      return "Administrator";
    case "super_admin":
      return "Super Administrator";
    case "teacher":
      return "Teacher";
    case "student":
      return "Student";
    case "parent":
      return "Parent";
    case "circle_member":
      return "Member";
    default:
      return "User";
  }
}

// ─── Sidebar (SidebarConfig._getParentStructure) ───────────────────────────

export type ParentIconKey =
  | "dashboard"
  | "chat"
  | "classes"
  | "recordings"
  | "curriculum_books"
  | "quran"
  | "invoices"
  | "payments"
  | "forms"
  | "profile"
  | "settings";

export type ParentSidebarItem = {
  id: ParentIconKey;
  label: string;
  /** French label from app_fr.arb; absent where Flutter shows English in both languages. */
  fr?: string;
  href: string;
  color: string;
};

export type ParentSidebarSection = {
  id: string;
  title: string;
  fr?: string;
  items: ParentSidebarItem[];
};

/**
 * Same sections, ids, labels, order and colours as the Flutter parent sidebar.
 * Circles is left out because SidebarConfig.showCircles is false. French text
 * is what SidebarLocalization returns today; labels it does not translate
 * (Recordings, Curriculum Books, Quran, Invoices, Payments, Profile, Account,
 * and Finance, which has no French entry) stay English in both languages.
 */
export const PARENT_SIDEBAR_SECTIONS: readonly ParentSidebarSection[] = [
  {
    id: "overview",
    title: "Overview",
    fr: "Aperçu général",
    items: [{ id: "dashboard", label: "Dashboard", fr: "Tableau de bord", href: "/parent/", color: "#0386FF" }],
  },
  {
    id: "communication",
    title: "Communication",
    fr: "Communication",
    items: [{ id: "chat", label: "Chat", fr: "Chat", href: "/parent/chat/", color: "#A646F2" }],
  },
  {
    id: "classes",
    title: "Learning",
    fr: "Learning",
    items: [
      { id: "classes", label: "Classes", fr: "Cours", href: "/parent/classes/", color: "#2D8CFF" },
      { id: "recordings", label: "Recordings", href: "/parent/recordings/", color: "#0E72ED" },
      { id: "curriculum_books", label: "Curriculum Books", href: "/parent/curriculum-books/", color: "#0F766E" },
      { id: "quran", label: "Quran", href: "/parent/quran/", color: "#0E7490" },
    ],
  },
  {
    id: "finance",
    title: "Finance",
    items: [
      { id: "invoices", label: "Invoices", href: "/parent/invoices/", color: "#10B981" },
      { id: "payments", label: "Payments", href: "/parent/payments/", color: "#059669" },
    ],
  },
  {
    id: "forms",
    title: "Forms",
    fr: "Forms",
    items: [{ id: "forms", label: "Forms", fr: "Forms", href: "/parent/forms/", color: "#EC4899" }],
  },
  {
    id: "account",
    title: "Account",
    items: [
      { id: "profile", label: "Profile", href: "/parent/profile/", color: "#6B7280" },
      { id: "settings", label: "Settings", fr: "Paramètres", href: "/parent/settings/", color: "#6B7280" },
    ],
  },
];

/**
 * Screens that exist on the web so far. The shell lists only these, so a
 * parent is never sent to a page that does not exist; each later slice adds
 * its ids here when its parity check passes.
 */
export const PARENT_WEB_SCREENS: ReadonlySet<ParentIconKey> = new Set<ParentIconKey>(["dashboard", "invoices", "payments"]);

/**
 * Where the parent screens send each other. Flutter pushes these as pages over
 * the shell; on the web each one is its own URL.
 */
export const PARENT_ROUTES = {
  home: "/parent/",
  child: (id: string) => `/parent/child/?id=${encodeURIComponent(id)}`,
  invoices: "/parent/invoices/",
  invoicesPending: "/parent/invoices/?status=pending",
  invoice: (id: string) => `/parent/invoices/detail/?id=${encodeURIComponent(id)}`,
  pay: (id: string) => `/parent/pay/?invoiceId=${encodeURIComponent(id)}`,
  payReturn: "/parent/pay/return/",
  payments: "/parent/payments/",
  classroom: (shiftId: string) => `/parent/classroom/?shiftId=${encodeURIComponent(shiftId)}`,
} as const;

/**
 * Pages Flutter pushes over the whole shell (no sidebar or top bar): the child
 * page, and the invoice/payment pages opened from the dashboard.
 */
const PUSHED_PREFIXES = ["/parent/child/", "/parent/invoices/detail/", "/parent/pay/"];

export function isPushedParentPage(pathname: string) {
  const path = pathname.endsWith("/") ? pathname : `${pathname}/`;
  return PUSHED_PREFIXES.some((prefix) => path.startsWith(prefix));
}

export function sidebarLabel(entry: { label?: string; title?: string; fr?: string }, locale: string) {
  const en = entry.label ?? entry.title ?? "";
  return locale === "fr" && entry.fr ? entry.fr : en;
}

/** The sidebar item a path belongs to; unknown paths fall back to Dashboard. */
export function activeParentItemId(pathname: string): ParentIconKey {
  const path = pathname.endsWith("/") ? pathname : `${pathname}/`;
  let best: ParentSidebarItem | null = null;
  for (const section of PARENT_SIDEBAR_SECTIONS) {
    for (const item of section.items) {
      if (item.href === "/parent/") continue;
      if (path.startsWith(item.href) && (!best || item.href.length > best.href.length)) best = item;
    }
  }
  return best?.id ?? "dashboard";
}

// ─── Sidebar preferences (SidebarService, key admin_sidebar_preferences) ───

/**
 * Flutter keeps sidebar order, folding and favourites in SharedPreferences
 * under `admin_sidebar_preferences`; on the web that is localStorage key
 * `flutter.admin_sidebar_preferences` holding a JSON-encoded JSON string. The
 * parent shell reads and writes the same key, so a parent's layout carries
 * across both apps. (Flutter shares the key between every role on a browser;
 * kept as it is.)
 */
export const SIDEBAR_PREFS_KEY = "flutter.admin_sidebar_preferences";
/** LAYOUT._loadSidebarState: SharedPreferences bool `parent_sidebar_collapsed`. */
export const SIDEBAR_RAIL_KEY = "flutter.parent_sidebar_collapsed";

export type SidebarPreferences = {
  sectionOrder: string[];
  sectionExpansionState: Record<string, boolean>;
  favoritedItemIds: string[];
};

export function parseSidebarPreferences(stored: string | null): SidebarPreferences | null {
  if (!stored) return null;
  try {
    let value: unknown = JSON.parse(stored);
    if (typeof value === "string") value = JSON.parse(value);
    if (!value || typeof value !== "object") return null;
    const raw = value as Data;
    const order = Array.isArray(raw.sectionOrder) ? raw.sectionOrder.filter((id): id is string => typeof id === "string") : [];
    const expansion: Record<string, boolean> = {};
    if (raw.sectionExpansionState && typeof raw.sectionExpansionState === "object") {
      for (const [id, expanded] of Object.entries(raw.sectionExpansionState as Data)) {
        if (typeof expanded === "boolean") expansion[id] = expanded;
      }
    }
    const favorites = Array.isArray(raw.favoritedItemIds)
      ? raw.favoritedItemIds.filter((id): id is string => typeof id === "string")
      : [];
    return { sectionOrder: order, sectionExpansionState: expansion, favoritedItemIds: favorites };
  } catch {
    return null;
  }
}

export function serializeSidebarPreferences(prefs: SidebarPreferences) {
  return JSON.stringify(JSON.stringify(prefs));
}

export type SectionState = { id: string; expanded: boolean };

/**
 * SidebarService._applyPreferences: sections in the saved order with their
 * saved folding, then any section the saved order does not name, in default
 * order. Sections start expanded.
 */
export function applySidebarPreferences(defaultIds: readonly string[], prefs: SidebarPreferences | null): SectionState[] {
  const remaining = new Set(defaultIds);
  const ordered: SectionState[] = [];
  for (const id of prefs?.sectionOrder ?? []) {
    if (!remaining.has(id)) continue;
    remaining.delete(id);
    ordered.push({ id, expanded: prefs?.sectionExpansionState[id] ?? true });
  }
  for (const id of defaultIds) {
    if (remaining.has(id)) ordered.push({ id, expanded: true });
  }
  return ordered;
}

/**
 * CustomSidebar._applyAutoCollapseForSelectedIndex: choosing an item opens its
 * section and folds every other section the parent did not open by hand.
 */
export function autoCollapseForSection(sections: SectionState[], targetId: string | null, manualExpanded: ReadonlySet<string>): SectionState[] {
  if (!targetId || !sections.some((section) => section.id === targetId)) return sections;
  return sections.map((section) => ({
    id: section.id,
    expanded: section.id === targetId || manualExpanded.has(section.id),
  }));
}

/** ReorderableListView's onReorder, with Flutter's index adjustment. */
export function reorderSections<T>(list: readonly T[], oldIndex: number, newIndex: number): T[] {
  const next = [...list];
  let target = newIndex;
  if (oldIndex < target) target -= 1;
  const [moved] = next.splice(oldIndex, 1);
  next.splice(target, 0, moved);
  return next;
}

/**
 * Sidebar search (CustomSidebar._buildSectionsList): match the displayed
 * section title or item labels; a title match shows the whole section.
 */
export function filterSidebar<S extends { title: string; items: I[] }, I extends { label: string }>(sections: S[], query: string): Array<S & { items: I[] }> {
  const q = query.trim().toLowerCase();
  if (!q) return sections;
  const result: Array<S & { items: I[] }> = [];
  for (const section of sections) {
    const titleMatches = section.title.toLowerCase().includes(q);
    const items = section.items.filter((item) => item.label.toLowerCase().includes(q));
    if (!titleMatches && items.length === 0) continue;
    result.push({ ...section, items: titleMatches ? section.items : items });
  }
  return result;
}
