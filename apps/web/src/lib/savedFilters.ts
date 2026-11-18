/**
 * Saved filters on the admin Users page (F7): one document per admin,
 * `admin_saved_filters/{adminUid}` { filters: SavedFilter[], updated_at },
 * readable and writable only by that admin (firestore.rules). Pure helpers for
 * reading, saving, renaming, deleting and applying; usersExtrasData.ts writes
 * the document.
 */

import { NO_FILTERS, type KindFilter, type StatusFilter, type TypeFilter, type UserFilters, type UsersTab } from "./adminUsers.ts";

export const SAVED_FILTERS_COLLECTION = "admin_saved_filters";
export const MAX_SAVED_FILTERS = 30;
export const MAX_FILTER_NAME = 60;

export type SavedFilter = {
  id: string;
  name: string;
  tab: UsersTab;
  type: TypeFilter;
  kind: KindFilter;
  status: StatusFilter;
  parentId: string | null;
  search: string;
};

const TABS: readonly UsersTab[] = ["users", "admins"];
const TYPES: readonly TypeFilter[] = ["all", "teacher", "student", "parent"];
const KINDS: readonly KindFilter[] = ["all", "minor", "adult"];
const STATUSES: readonly StatusFilter[] = ["any", "active", "archived", "never"];

const pick = <T extends string>(value: unknown, allowed: readonly T[], fallback: T): T =>
  typeof value === "string" && (allowed as readonly string[]).includes(value) ? (value as T) : fallback;

const clean = (value: unknown, max: number) => (typeof value === "string" ? value.trim().slice(0, max) : "");

/** One stored entry, made safe; null when it has no id or name. */
export function parseSavedFilter(raw: unknown): SavedFilter | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const id = clean(r.id, 40);
  const name = clean(r.name, MAX_FILTER_NAME);
  if (!id || !name) return null;
  const parentId = clean(r.parentId, 200);
  return {
    id,
    name,
    tab: pick(r.tab, TABS, "users"),
    type: pick(r.type, TYPES, "all"),
    kind: pick(r.kind, KINDS, "all"),
    status: pick(r.status, STATUSES, "any"),
    parentId: parentId || null,
    search: typeof r.search === "string" ? r.search.slice(0, 200) : "",
  };
}

export function parseSavedFilters(data: Record<string, unknown> | undefined | null): SavedFilter[] {
  const list = Array.isArray(data?.filters) ? data!.filters : [];
  const seen = new Set<string>();
  const out: SavedFilter[] = [];
  for (const raw of list) {
    const f = parseSavedFilter(raw);
    if (!f || seen.has(f.id)) continue;
    seen.add(f.id);
    out.push(f);
  }
  return out;
}

export function nameProblem(name: string, list: readonly SavedFilter[], exceptId: string | null): string | null {
  const n = name.trim();
  if (!n) return "Give the filter a name.";
  if (n.length > MAX_FILTER_NAME) return `Use ${MAX_FILTER_NAME} characters or fewer.`;
  if (list.some((f) => f.id !== exceptId && f.name.toLocaleLowerCase() === n.toLocaleLowerCase())) return "You already have a filter with this name.";
  return null;
}

/** The current view as a saved filter. A parent filter replaces type / kind / status, as picking a parent does. */
export function filterFromView(id: string, name: string, tab: UsersTab, f: UserFilters): SavedFilter {
  return {
    id,
    name: name.trim().slice(0, MAX_FILTER_NAME),
    tab,
    type: f.type,
    kind: f.type === "student" ? f.kind : "all",
    status: f.status,
    parentId: f.parentId,
    search: f.search,
  };
}

export const isEmptyView = (tab: UsersTab, f: UserFilters) =>
  tab === "users" && f.type === "all" && f.kind === "all" && f.status === "any" && f.parentId === null && f.search.trim() === "";

/** Add (newest last) or replace by id; refuses past the limit. */
export function upsertFilter(list: readonly SavedFilter[], next: SavedFilter): SavedFilter[] | "full" {
  const i = list.findIndex((f) => f.id === next.id);
  if (i >= 0) return list.map((f, j) => (j === i ? next : f));
  if (list.length >= MAX_SAVED_FILTERS) return "full";
  return [...list, next];
}

export const renameFilter = (list: readonly SavedFilter[], id: string, name: string): SavedFilter[] =>
  list.map((f) => (f.id === id ? { ...f, name: name.trim().slice(0, MAX_FILTER_NAME) } : f));

export const removeFilter = (list: readonly SavedFilter[], id: string): SavedFilter[] => list.filter((f) => f.id !== id);

/**
 * What applying a saved filter does. A parent that no longer exists (or is no
 * longer a parent account) is dropped, and the admin is told, rather than
 * showing an empty list for a filter nobody can clear.
 */
export function applySavedFilter(saved: SavedFilter, parentExists: (id: string) => boolean): { tab: UsersTab; filters: UserFilters; droppedParent: boolean } {
  const droppedParent = saved.parentId !== null && !parentExists(saved.parentId);
  const parentId = droppedParent ? null : saved.parentId;
  return {
    tab: parentId ? "users" : saved.tab,
    filters: {
      ...NO_FILTERS,
      type: saved.type,
      kind: saved.type === "student" ? saved.kind : "all",
      status: saved.status,
      parentId,
      search: saved.search,
    },
    droppedParent,
  };
}

/** Whether the page shows exactly this saved filter now. */
export function isApplied(saved: SavedFilter, tab: UsersTab, f: UserFilters): boolean {
  return (
    saved.tab === tab &&
    saved.type === f.type &&
    (saved.type === "student" ? saved.kind : "all") === f.kind &&
    saved.status === f.status &&
    saved.parentId === f.parentId &&
    saved.search === f.search
  );
}

/** A short description: "Students · Minors · Never logged in · “ali”". */
export function describeFilter(saved: SavedFilter, parentName: (id: string) => string | null): string {
  const parts: string[] = [];
  if (saved.tab === "admins") parts.push("Admins");
  if (saved.type !== "all") parts.push({ teacher: "Teachers", student: "Students", parent: "Parents" }[saved.type]);
  if (saved.type === "student" && saved.kind !== "all") parts.push(saved.kind === "minor" ? "Minors" : "Adults");
  if (saved.status !== "any") parts.push({ active: "Active", archived: "Archived", never: "Never logged in" }[saved.status]);
  if (saved.parentId) parts.push(`Parent: ${parentName(saved.parentId) ?? "account no longer exists"}`);
  if (saved.search.trim()) parts.push(`“${saved.search.trim()}”`);
  return parts.join(" · ") || "Everyone";
}

/** A short random id for a new entry. */
export function newFilterId(random: () => number = Math.random): string {
  return `f${Date.now().toString(36)}${Math.floor(random() * 1e9).toString(36)}`;
}
