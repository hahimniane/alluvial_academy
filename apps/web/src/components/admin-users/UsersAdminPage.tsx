"use client";

import { memo, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { onAuthStateChanged, type User } from "firebase/auth";
import { ArrowDown, ArrowUp, Download, Plus, Search, SlidersHorizontal, UserPlus, Users as UsersIcon, X } from "lucide-react";
import { auth } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";
import { downloadWorkbook } from "@/lib/xlsx";
import { downloadCsv } from "@/lib/finance/csv";
import {
  EXPORT_FILE_BASE,
  EXPORT_HEADERS,
  NO_FILTERS,
  adminTypeLabel,
  buildParentLinks,
  buildWeekSchedule,
  dayOrText,
  displayNameOf,
  enrichRow,
  exportRow,
  filterRows,
  firstClassText,
  hasActiveFilters,
  isNeverLoggedIn,
  isStudentType,
  parentChoices,
  phoneDisplay,
  shortDay,
  sortByName,
  toCsv,
  typeInfo,
  weekBounds,
  type KindFilter,
  type ListRow,
  type ParentLinks,
  type StatusFilter,
  type StudentWeek,
  type TypeFilter,
  type UserFilters,
  type UserRow,
  type UsersTab,
  type WeekShift,
} from "@/lib/adminUsers";
import { adminUsesWebUsersPage, listenUsers, listenWeekShifts } from "@/lib/adminUsersData";
import { AddUsersDialog } from "./AddUsersDialog";
import { FamilyEnrollDialog } from "./FamilyEnrollDialog";
import { ParentPicker } from "./ParentPicker";
import { UserPanel } from "./UserPanel";
import { ArchivedBadge, Avatar, Chip, Pill, Spinner, TypePill } from "./ui";

type Access = "checking" | "signedOut" | "denied" | "notMoved" | "switchError" | "allowed";

/**
 * The admin Users page. It only renders inside the Flutter web app's content
 * area (same-origin iframe, `?embed=1`), like Shifts and Finance, and only for
 * admins that settings/admin_users_web_cutover moves here; a direct visit goes
 * to the Flutter app.
 */
export function UsersAdminPage() {
  const [embedded, setEmbedded] = useState(false);
  const [access, setAccess] = useState<Access>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const inFlutterFrame = window.self !== window.top || new URLSearchParams(window.location.search).has("embed");
    if (inFlutterFrame) setEmbedded(true);
    else window.location.replace("/app/");
  }, []);

  useEffect(() => {
    let live = true;
    const off = onAuthStateChanged(auth, async (next) => {
      if (!live) return;
      setUser(next);
      if (!next) {
        setAccess("signedOut");
        return;
      }
      setAccess("checking");
      const isAdmin = await isCurrentUserAdmin(next).catch(() => false);
      if (!live) return;
      if (!isAdmin) {
        setAccess("denied");
        return;
      }
      try {
        const moved = await adminUsesWebUsersPage(next.uid);
        if (live) setAccess(moved ? "allowed" : "notMoved");
      } catch {
        if (live) setAccess("switchError");
      }
    });
    return () => {
      live = false;
      off();
    };
  }, [attempt]);

  if (!embedded) return null;
  if (access === "checking") return <Spinner label="Loading…" />;
  if (access !== "allowed" || !user) {
    const message =
      access === "signedOut"
        ? "Sign in to see users."
        : access === "denied"
          ? "Users is for administrators."
          : access === "switchError"
            ? "Users could not be opened."
            : "Reload the page to open Users.";
    return (
      <main className="p-6 font-sans">
        <h1 className="text-lg font-bold text-slate-900">Users</h1>
        <p className="mt-2 text-sm text-slate-600">{message}</p>
        {access === "switchError" ? (
          <button type="button" onClick={() => setAttempt((n) => n + 1)} className="mt-3 min-h-10 rounded-[10px] border border-[#CBD5E1] bg-white px-4 font-semibold">
            Try again
          </button>
        ) : null}
        {access === "notMoved" ? (
          <button type="button" onClick={() => (window.top ?? window).location.reload()} className="mt-3 min-h-10 rounded-[10px] border border-[#CBD5E1] bg-white px-4 font-semibold">
            Reload
          </button>
        ) : null}
      </main>
    );
  }
  return <UsersDirectory viewerUid={user.uid} />;
}

// ─── Data ──────────────────────────────────────────────────────────────────

function useWeekKey(): { start: Date; end: Date } {
  const [week, setWeek] = useState(() => weekBounds(new Date()));
  useEffect(() => {
    const id = window.setInterval(() => {
      const next = weekBounds(new Date());
      setWeek((cur) => (cur.start.getTime() === next.start.getTime() ? cur : next));
    }, 60_000);
    return () => window.clearInterval(id);
  }, []);
  return week;
}

function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia(query);
    const update = () => setMatches(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, [query]);
  return matches;
}

/** Keeps each enriched row the same object while nothing it shows changed, so unchanged rows do not re-render. */
function useEnrichedRows(rows: UserRow[] | null, links: ParentLinks, week: Map<string, StudentWeek>): ListRow[] {
  const cache = useRef(new WeakMap<UserRow, { key: string; value: ListRow }>());
  return useMemo(() => {
    if (!rows) return [];
    return rows.map((row) => {
      let key = "";
      if (isStudentType(row)) {
        const p = links.firstParentByStudent.get(row.id);
        const w = week.get(row.id);
        key = `${p?.id ?? ""}|${p?.name ?? ""}|${p?.email ?? ""}|${w?.hours ?? 0}|${w?.teachers ?? ""}`;
      }
      const hit = cache.current.get(row);
      if (hit && hit.key === key) return hit.value;
      const value = enrichRow(row, links, week);
      cache.current.set(row, { key, value });
      return value;
    });
  }, [rows, links, week]);
}

// ─── Page ──────────────────────────────────────────────────────────────────

const TYPE_CHIPS: [TypeFilter, string][] = [
  ["all", "Everyone"],
  ["teacher", "Teachers"],
  ["student", "Students"],
  ["parent", "Parents"],
];
const KIND_CHIPS: [KindFilter, string][] = [
  ["all", "All students"],
  ["minor", "Minors"],
  ["adult", "Adults"],
];
const STATUS_CHIPS: [StatusFilter, string][] = [
  ["any", "Any status"],
  ["active", "Active"],
  ["archived", "Archived"],
  ["never", "Never logged in"],
];

function UsersDirectory({ viewerUid }: { viewerUid: string }) {
  const [rows, setRows] = useState<UserRow[] | null>(null);
  const [loadError, setLoadError] = useState(false);
  const [retry, setRetry] = useState(0);
  const [shifts, setShifts] = useState<WeekShift[]>([]);
  const week = useWeekKey();

  const [tab, setTab] = useState<UsersTab>("users");
  const [filters, setFilters] = useState<UserFilters>(NO_FILTERS);
  const [sortAsc, setSortAsc] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [exportOpen, setExportOpen] = useState(false);
  const [parentOpen, setParentOpen] = useState(false);
  const [moreFilters, setMoreFilters] = useState(false);
  const [toast, setToast] = useState<{ text: string; tone: "ok" | "error" } | null>(null);
  /** Add users / Enroll a family. Hidden (not closed) while the admin checks a possible duplicate, so nothing typed is lost. */
  const [adding, setAdding] = useState<{ kind: "users" | "family"; hidden: boolean; n: number } | null>(null);
  const toastTimer = useRef<number | undefined>(undefined);

  const wide = useMediaQuery("(min-width: 768px)");
  const roomy = useMediaQuery("(min-width: 1280px)");

  useEffect(() => {
    setLoadError(false);
    return listenUsers(setRows, () => setLoadError(true));
  }, [retry]);

  useEffect(() => listenWeekShifts(week, setShifts, () => setShifts([])), [week]);

  const links = useMemo(() => buildParentLinks(rows ?? []), [rows]);
  const weekMap = useMemo(() => buildWeekSchedule(shifts), [shifts]);
  const enriched = useEnrichedRows(rows, links, weekMap);
  const byId = useMemo(() => new Map(enriched.map((r) => [r.id, r])), [enriched]);
  const parents = useMemo(() => parentChoices(rows ?? [], links), [rows, links]);

  const filtered = useMemo(() => filterRows(enriched, filters, links), [enriched, filters, links]);
  const users = useMemo(() => sortByName(filtered.users, sortAsc), [filtered.users, sortAsc]);
  const admins = useMemo(() => sortByName(filtered.admins, sortAsc), [filtered.admins, sortAsc]);
  const shown = tab === "users" ? users : admins;
  const selected = selectedId ? byId.get(selectedId) ?? null : null;
  const activeParents = useMemo(() => parents.filter((p) => p.isActive), [parents]);
  const openAdd = (kind: "users" | "family") => {
    setExportOpen(false);
    setParentOpen(false);
    setAdding((cur) => (cur && cur.kind === kind ? { ...cur, hidden: false } : { kind, hidden: false, n: (cur?.n ?? 0) + 1 }));
  };
  const closeAdd = useCallback(() => setAdding(null), []);
  const openFromAdd = useCallback((id: string) => {
    setAdding((cur) => (cur ? { ...cur, hidden: true } : cur));
    setSelectedId(id);
  }, []);
  const parentName = filters.parentId ? parents.find((p) => p.id === filters.parentId)?.name || filters.parentId : "";

  const say = useCallback((text: string, tone: "ok" | "error" = "ok") => {
    setToast({ text, tone });
    window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(null), tone === "error" ? 6000 : 3200);
  }, []);

  const set = (patch: Partial<UserFilters>) => setFilters((f) => ({ ...f, ...patch }));
  const pickParent = (id: string) => {
    setFilters({ ...NO_FILTERS, parentId: id });
    setTab("users");
    setParentOpen(false);
  };
  const closeParent = useCallback(() => setParentOpen(false), []);
  const select = useCallback((id: string) => {
    setSelectedId(id);
    setExportOpen(false);
    setParentOpen(false);
  }, []);

  const runExport = (kind: "xlsx" | "csv") => {
    setExportOpen(false);
    if (users.length === 0) {
      say("No data to export");
      return;
    }
    const data = users.map(exportRow);
    if (kind === "xlsx") downloadWorkbook([{ name: "Sheet1", headers: [...EXPORT_HEADERS], rows: data }], `${EXPORT_FILE_BASE}.xlsx`);
    else downloadCsv(`${EXPORT_FILE_BASE}.csv`, toCsv(EXPORT_HEADERS, data));
    say(`Downloaded ${EXPORT_FILE_BASE}.${kind} · ${users.length} ${users.length === 1 ? "row" : "rows"}`);
  };

  useEffect(() => {
    if (!selected || roomy) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setSelectedId(null);
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [selected, roomy]);

  const statusChips = (
    <div className="flex flex-wrap gap-1.5" role="group" aria-label="Status">
      {STATUS_CHIPS.map(([v, label]) => (
        <Chip key={v} on={filters.status === v} onClick={() => set({ status: v })}>
          {label}
        </Chip>
      ))}
    </div>
  );

  const parentButton = (
    <div className="relative">
      <button
        type="button"
        onClick={() => {
          setParentOpen((o) => !o);
          setExportOpen(false);
        }}
        aria-expanded={parentOpen}
        className="flex min-h-9 items-center gap-1.5 rounded-full border border-[#DDD6FE] bg-[#F5F3FF] px-3.5 text-[13px] font-semibold text-[#5B21B6] hover:border-[#C4B5FD]"
      >
        <UsersIcon size={15} aria-hidden="true" />
        Filter by parent
      </button>
      {parentOpen ? (
        <ParentPicker
          parents={parents}
          selectedId={filters.parentId}
          onPick={pickParent}
          onClear={() => {
            set({ parentId: null });
            setParentOpen(false);
          }}
          onClose={closeParent}
        />
      ) : null}
    </div>
  );

  const parentChip = filters.parentId ? (
    <button
      type="button"
      onClick={() => set({ parentId: null })}
      aria-label={`Clear parent filter ${parentName}`}
      className="flex min-h-9 max-w-full items-center gap-1.5 rounded-full bg-[#5B21B6] px-3 text-[13px] font-semibold text-white"
    >
      <span className="truncate">Parent: {parentName}</span>
      <X size={14} aria-hidden="true" />
    </button>
  ) : null;

  const panel = selected ? (
    <UserPanel key={selected.id} row={selected} byId={byId} links={links} viewerUid={viewerUid} say={say} onClose={() => setSelectedId(null)} onSelect={select} />
  ) : null;

  return (
    <div className="users-area min-h-screen bg-[#F8FAFC] font-sans text-sm text-[#0F172A]">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-5 px-4 pb-12 pt-5 md:px-8 md:pt-7">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div className="flex flex-col gap-1">
            <h1 className="m-0 text-[22px] font-bold tracking-[-0.01em] md:text-[26px]">Users</h1>
            <p className="m-0 hidden text-[#64748B] md:block">Students, teachers, parents and admins. Click anyone to see their details.</p>
          </div>
          <div className="flex flex-wrap items-center gap-2.5">
          <div className="relative">
            <button
              type="button"
              onClick={() => {
                setExportOpen((o) => !o);
                setParentOpen(false);
              }}
              aria-expanded={exportOpen}
              className="flex min-h-11 items-center gap-2 rounded-[10px] border border-[#CBD5E1] bg-white px-4 font-semibold text-[#334155] hover:bg-[#F8FAFC]"
            >
              <Download size={16} aria-hidden="true" />
              Export
            </button>
            {exportOpen ? (
              <div role="menu" className="absolute right-0 top-[50px] z-30 flex w-[260px] flex-col rounded-xl border border-[#E2E8F0] bg-white p-1.5 shadow-[0_12px_32px_rgba(15,23,42,0.12)]">
                <button type="button" role="menuitem" onClick={() => runExport("xlsx")} className="flex flex-col gap-0.5 rounded-lg px-3 py-2.5 text-left hover:bg-[#F1F5F9]">
                  <span className="font-semibold">Excel (.xlsx)</span>
                  <span className="text-xs text-[#64748B]">The users shown, all 13 columns</span>
                </button>
                <button type="button" role="menuitem" onClick={() => runExport("csv")} className="flex flex-col gap-0.5 rounded-lg px-3 py-2.5 text-left hover:bg-[#F1F5F9]">
                  <span className="font-semibold">CSV (.csv)</span>
                  <span className="text-xs text-[#64748B]">Opens in any spreadsheet app</span>
                </button>
              </div>
            ) : null}
          </div>
          <button
            type="button"
            onClick={() => openAdd("family")}
            disabled={!rows}
            className="flex min-h-11 items-center gap-2 rounded-[10px] border border-[#BFDBFE] bg-[#EFF6FF] px-4 font-semibold text-[#0369D9] hover:border-[#93C5FD] disabled:opacity-60"
          >
            <UserPlus size={16} aria-hidden="true" />
            Enroll a family
          </button>
          <button
            type="button"
            onClick={() => openAdd("users")}
            disabled={!rows}
            className="flex min-h-11 items-center gap-2 rounded-[10px] bg-[#0369D9] px-[18px] font-semibold text-white hover:bg-[#024E96] disabled:opacity-60"
          >
            <Plus size={16} aria-hidden="true" />
            Add users
          </button>
          </div>
        </div>

        <div className="flex gap-1 border-b border-[#E2E8F0]" role="tablist">
          {(["users", "admins"] as const).map((t) => {
            const on = tab === t;
            const count = t === "users" ? users.length : admins.length;
            return (
              <button
                key={t}
                type="button"
                role="tab"
                aria-selected={on}
                onClick={() => setTab(t)}
                className={`-mb-px flex min-h-11 flex-1 items-center justify-center border-b-2 px-4 font-semibold md:flex-none ${on ? "border-[#0369D9] text-[#0369D9]" : "border-transparent text-[#475569]"}`}
              >
                {t === "users" ? "Users" : "Admins"}
                <span className="ml-1.5 rounded-full bg-[#EEF2F7] px-2 py-px text-xs text-[#334155]">{rows ? count : "…"}</span>
              </button>
            );
          })}
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <label className="relative flex min-w-0 flex-[1_1_280px] items-center md:max-w-[360px]">
            <span className="pointer-events-none absolute left-3 flex text-[#64748B]">
              <Search size={16} aria-hidden="true" />
            </span>
            <input
              type="search"
              aria-label="Search users"
              placeholder="Search name, email, phone or Student ID"
              value={filters.search}
              onChange={(e) => set({ search: e.target.value })}
              className="min-h-11 w-full rounded-[10px] border border-[#CBD5E1] bg-white pl-9 pr-3 text-sm text-[#0F172A]"
            />
          </label>
          {tab === "users" ? (
            <div className="flex max-w-full gap-1.5 overflow-x-auto [scrollbar-width:none] md:flex-wrap md:overflow-visible" role="group" aria-label="Type">
              {TYPE_CHIPS.map(([v, label]) => (
                <Chip key={v} on={filters.type === v} onClick={() => set({ type: v, kind: "all" })}>
                  {label}
                </Chip>
              ))}
              {!wide ? (
                <button
                  type="button"
                  onClick={() => setMoreFilters((m) => !m)}
                  aria-expanded={moreFilters}
                  className={`flex min-h-9 flex-none items-center gap-1.5 rounded-full border px-3.5 text-[13px] font-semibold ${
                    filters.status !== "any" || moreFilters ? "border-[#0369D9] text-[#0369D9]" : "border-[#CBD5E1] text-[#334155]"
                  } bg-white`}
                >
                  <SlidersHorizontal size={14} aria-hidden="true" />
                  More filters
                </button>
              ) : null}
            </div>
          ) : null}
          {wide || tab === "admins" || moreFilters ? (
            <>
              {wide ? <div className="h-7 w-px bg-[#E2E8F0]" aria-hidden="true" /> : null}
              {statusChips}
              {tab === "users" ? parentButton : null}
            </>
          ) : null}
          {parentChip}
        </div>

        {tab === "users" && filters.type === "student" ? (
          <div className="-mt-2 flex flex-wrap gap-1.5" role="group" aria-label="Student type">
            {KIND_CHIPS.map(([v, label]) => (
              <Chip key={v} on={filters.kind === v} onClick={() => set({ kind: v })}>
                {label}
              </Chip>
            ))}
          </div>
        ) : null}

        <div className="flex items-start gap-5">
          <div className="min-w-0 flex-1 overflow-hidden rounded-[14px] border border-[#E2E8F0] bg-white">
            {loadError ? (
              <div className="p-10 text-center">
                <div className="font-semibold text-[#334155]">Users could not be loaded.</div>
                <button type="button" onClick={() => setRetry((n) => n + 1)} className="mt-3 min-h-10 rounded-[10px] border border-[#CBD5E1] bg-white px-4 font-semibold">
                  Try again
                </button>
              </div>
            ) : !rows ? (
              <Spinner label="Loading users…" />
            ) : shown.length === 0 ? (
              <EmptyState
                filtered={hasActiveFilters(filters)}
                tab={tab}
                onReset={() => {
                  setFilters(NO_FILTERS);
                }}
              />
            ) : wide ? (
              <div className="overflow-x-auto">
                {tab === "users" ? (
                  <UsersTable rows={users} sortAsc={sortAsc} onSort={() => setSortAsc((s) => !s)} selectedId={selectedId} onSelect={select} />
                ) : (
                  <AdminsTable rows={admins} sortAsc={sortAsc} onSort={() => setSortAsc((s) => !s)} selectedId={selectedId} onSelect={select} />
                )}
              </div>
            ) : (
              <CardList rows={shown} links={links} selectedId={selectedId} onSelect={select} />
            )}
            {rows && !loadError ? (
              <div className="border-t border-[#F1F5F9] px-4 py-3 text-xs text-[#64748B]">
                Showing {shown.length} {shown.length === 1 ? "person" : "people"}
              </div>
            ) : null}
          </div>

          {panel && roomy ? (
            <aside aria-label="User details" className="sticky top-4 max-h-[calc(100vh-32px)] w-[400px] flex-none overflow-y-auto rounded-[14px] border border-[#E2E8F0] bg-white">
              {panel}
            </aside>
          ) : null}
        </div>
      </div>

      {panel && !roomy ? (
        <div className="fixed inset-0 z-40 flex justify-end">
          <button type="button" aria-label="Close panel" className="absolute inset-0 cursor-default bg-[rgba(15,23,42,0.35)]" onClick={() => setSelectedId(null)} />
          <aside aria-label="User details" role="dialog" className="relative h-full w-full overflow-y-auto bg-white shadow-[0_0_40px_rgba(15,23,42,0.25)] md:w-[440px]">
            {panel}
          </aside>
        </div>
      ) : null}

      {adding && rows ? (
        adding.kind === "users" ? (
          <AddUsersDialog key={adding.n} rows={rows} parents={activeParents} hidden={adding.hidden} onClose={closeAdd} onOpenUser={openFromAdd} />
        ) : (
          <FamilyEnrollDialog key={adding.n} rows={rows} parents={activeParents} hidden={adding.hidden} onClose={closeAdd} onOpenUser={openFromAdd} />
        )
      ) : null}
      {adding?.hidden ? (
        <button
          type="button"
          onClick={() => setAdding((cur) => (cur ? { ...cur, hidden: false } : cur))}
          className="fixed bottom-6 right-4 z-[50] min-h-11 rounded-full bg-[#0369D9] px-5 font-semibold text-white shadow-[0_10px_30px_rgba(15,23,42,0.25)] md:right-8"
        >
          {adding.kind === "users" ? "Back to Add users" : "Back to Enroll a family"}
        </button>
      ) : null}

      {toast ? (
        <div
          role={toast.tone === "error" ? "alert" : "status"}
          className={`fixed bottom-6 left-1/2 z-[70] w-max max-w-[calc(100vw-32px)] -translate-x-1/2 rounded-xl px-[18px] py-3 font-semibold text-white shadow-[0_10px_30px_rgba(15,23,42,0.25)] ${
            toast.tone === "error" ? "bg-[#B91C1C]" : "bg-[#0F172A]"
          }`}
        >
          {toast.text}
        </div>
      ) : null}
    </div>
  );
}

function EmptyState({ filtered, tab, onReset }: { filtered: boolean; tab: UsersTab; onReset: () => void }) {
  return (
    <div className="px-6 py-12 text-center text-[#64748B]">
      <div className="mb-1 font-semibold text-[#334155]">{filtered ? "No one matches these filters" : tab === "admins" ? "No admins yet" : "No users yet"}</div>
      {filtered ? (
        <button type="button" onClick={onReset} className="mt-2 min-h-10 rounded-[10px] border border-[#CBD5E1] bg-white px-3.5 font-semibold text-[#334155]">
          Clear filters
        </button>
      ) : null}
    </div>
  );
}

// ─── Tables ────────────────────────────────────────────────────────────────

function SortHeader({ sortAsc, onSort }: { sortAsc: boolean; onSort: () => void }) {
  return (
    <th className="px-4 py-3 font-semibold" aria-sort={sortAsc ? "ascending" : "descending"}>
      <button type="button" onClick={onSort} className="flex items-center gap-1 font-semibold text-inherit">
        Name {sortAsc ? <ArrowUp size={13} aria-hidden="true" /> : <ArrowDown size={13} aria-hidden="true" />}
      </button>
    </th>
  );
}

const NameCell = ({ row, onSelect }: { row: ListRow; onSelect: (id: string) => void }) => (
  <td className="px-4 py-2.5">
    <button type="button" onClick={() => onSelect(row.id)} className="flex min-h-10 items-center gap-2.5 text-left">
      <Avatar row={row} size={36} />
      <span className="flex min-w-0 flex-col gap-px">
        <span className={`font-semibold ${row.isActive ? "text-[#0F172A]" : "text-[#64748B] line-through"}`}>{displayNameOf(row)}</span>
        {row.email ? <span className="max-w-[260px] truncate text-xs text-[#64748B]" title={row.email}>{row.email}</span> : null}
      </span>
    </button>
  </td>
);

const LastLoginCell = ({ row }: { row: ListRow }) => {
  const never = isNeverLoggedIn(row);
  return (
    <td className={`whitespace-nowrap px-4 py-2.5 ${never ? "font-semibold text-[#B45309]" : "text-[#334155]"}`} title={row.lastLoginText}>
      {never ? "Never" : dayOrText(row.lastLogin, row.lastLoginText)}
    </td>
  );
};

const rowClass = (selected: boolean) => `cursor-pointer border-t border-[#F1F5F9] hover:bg-[#F1F5F9] ${selected ? "bg-[#EFF6FF]" : ""}`;
const DASH = "—";

const UsersRow = memo(function UsersRow({ row, selected, onSelect }: { row: ListRow; selected: boolean; onSelect: (id: string) => void }) {
  const student = isStudentType(row);
  const teacherWeek = student ? [row.teacherNames, row.weeklyHoursLabel].filter(Boolean).join(" · ") : "";
  return (
    <tr className={rowClass(selected)} onClick={() => onSelect(row.id)} style={{ contentVisibility: "auto", containIntrinsicSize: "auto 61px" }}>
      <NameCell row={row} onSelect={onSelect} />
      <td className="whitespace-nowrap px-3 py-2.5 text-[#334155]">{phoneDisplay(row) || DASH}</td>
      <td className="whitespace-nowrap px-3 py-2.5">
        <TypePill row={row} />
        {!row.isActive ? <ArchivedBadge /> : null}
      </td>
      <td className="px-3 py-2.5 font-mono text-xs text-[#334155]">{student && row.studentCode ? row.studentCode : DASH}</td>
      <td className="px-3 py-2.5 text-[#334155]">
        {student && row.parentName ? (
          <span className="flex flex-col">
            <span>{row.parentName}</span>
            {row.parentEmail ? <span className="max-w-[220px] truncate text-xs text-[#64748B]" title={row.parentEmail}>{row.parentEmail}</span> : null}
          </span>
        ) : (
          DASH
        )}
      </td>
      <td className="min-w-[170px] px-3 py-2.5 text-[#334155]">{teacherWeek || DASH}</td>
      <td className="whitespace-nowrap px-3 py-2.5 text-[#334155]">{student ? firstClassText(row) : DASH}</td>
      <td className="whitespace-nowrap px-3 py-2.5 text-[#334155]" title={row.dateAddedText}>
        {row.dateAdded ? dayOrText(row.dateAdded, row.dateAddedText) : row.dateAddedText === "Never" ? DASH : row.dateAddedText}
      </td>
      <LastLoginCell row={row} />
    </tr>
  );
});

function UsersTable({
  rows,
  sortAsc,
  onSort,
  selectedId,
  onSelect,
}: {
  rows: ListRow[];
  sortAsc: boolean;
  onSort: () => void;
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  return (
    <table className="w-full min-w-[1180px] border-collapse text-[13px]">
      <thead>
        <tr className="whitespace-nowrap bg-[#F8FAFC] text-left text-[#475569]">
          <SortHeader sortAsc={sortAsc} onSort={onSort} />
          <th className="px-3 py-3 font-semibold">Phone</th>
          <th className="px-3 py-3 font-semibold">Type</th>
          <th className="px-3 py-3 font-semibold">Student ID</th>
          <th className="px-3 py-3 font-semibold">Parent</th>
          <th className="px-3 py-3 font-semibold">Teacher · this week</th>
          <th className="px-3 py-3 font-semibold">First class</th>
          <th className="px-3 py-3 font-semibold">Added</th>
          <th className="px-4 py-3 font-semibold">Last login</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <UsersRow key={r.id} row={r} selected={r.id === selectedId} onSelect={onSelect} />
        ))}
      </tbody>
    </table>
  );
}

const roleText = (row: UserRow) => {
  const t = row.userType.toLowerCase();
  if (t === "teacher") return "Teacher";
  if (t === "admin") return "Admin";
  if (t === "super_admin") return "Super admin";
  return typeInfo(row).label;
};

const AdminsRow = memo(function AdminsRow({ row, selected, onSelect }: { row: ListRow; selected: boolean; onSelect: (id: string) => void }) {
  const tone = row.isAdminTeacher ? { bg: "#FFF7ED", fg: "#C2410C" } : { bg: "#EFF6FF", fg: "#1D4ED8" };
  return (
    <tr className={rowClass(selected)} onClick={() => onSelect(row.id)}>
      <NameCell row={row} onSelect={onSelect} />
      <td className="whitespace-nowrap px-3 py-2.5 text-[#334155]">{phoneDisplay(row) || DASH}</td>
      <td className="whitespace-nowrap px-3 py-2.5 text-[#334155]">
        {roleText(row)}
        {!row.isActive ? <ArchivedBadge /> : null}
      </td>
      <td className="px-3 py-2.5">
        <Pill {...tone}>{adminTypeLabel(row)}</Pill>
      </td>
      <LastLoginCell row={row} />
    </tr>
  );
});

function AdminsTable({
  rows,
  sortAsc,
  onSort,
  selectedId,
  onSelect,
}: {
  rows: ListRow[];
  sortAsc: boolean;
  onSort: () => void;
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  return (
    <table className="w-full min-w-[820px] border-collapse text-[13px]">
      <thead>
        <tr className="whitespace-nowrap bg-[#F8FAFC] text-left text-[#475569]">
          <SortHeader sortAsc={sortAsc} onSort={onSort} />
          <th className="px-3 py-3 font-semibold">Phone</th>
          <th className="px-3 py-3 font-semibold">Role</th>
          <th className="px-3 py-3 font-semibold">Admin type</th>
          <th className="px-4 py-3 font-semibold">Last login</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <AdminsRow key={r.id} row={r} selected={r.id === selectedId} onSelect={onSelect} />
        ))}
      </tbody>
    </table>
  );
}

// ─── Narrow window: cards ──────────────────────────────────────────────────

const Card = memo(function Card({
  row,
  selected,
  now,
  studentCount,
  onSelect,
}: {
  row: ListRow;
  selected: boolean;
  now: Date;
  studentCount: number;
  onSelect: (id: string) => void;
}) {
  const student = isStudentType(row);
  const type = typeInfo(row);
  let sub: string;
  if (!row.isActive) sub = `${type.label} · Archived`;
  else if (student) sub = [type.label, row.studentCode, row.parentName].filter(Boolean).join(" · ");
  else if (row.userType.toLowerCase() === "parent") sub = `${type.label} · ${studentCount === 1 ? "1 student" : `${studentCount} students`}`;
  else sub = [type.label, phoneDisplay(row) || row.email].filter(Boolean).join(" · ");
  const never = isNeverLoggedIn(row);
  const corner = student && row.weeklyHoursLabel ? row.weeklyHoursLabel : never ? "Never" : shortDay(row.lastLogin, now);
  return (
    <button
      type="button"
      onClick={() => onSelect(row.id)}
      className={`flex w-full items-center gap-3 rounded-[14px] border bg-white px-3.5 py-3 text-left ${selected ? "border-[#93C5FD]" : "border-[#E2E8F0]"}`}
    >
      <Avatar row={row} size={40} />
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className={`truncate font-semibold ${row.isActive ? "" : "text-[#64748B] line-through"}`}>{displayNameOf(row)}</span>
        <span className={`truncate text-xs ${row.isActive ? "text-[#64748B]" : "font-semibold text-[#B91C1C]"}`}>{sub}</span>
      </span>
      <span className={`flex-none text-xs ${never && !(student && row.weeklyHoursLabel) ? "font-semibold text-[#B45309]" : "text-[#334155]"}`}>{corner}</span>
    </button>
  );
});

function CardList({
  rows,
  links,
  selectedId,
  onSelect,
}: {
  rows: ListRow[];
  links: ParentLinks;
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  const now = useMemo(() => new Date(), []);
  return (
    <div className="flex flex-col gap-2.5 bg-[#F8FAFC] p-2.5">
      {rows.map((r) => (
        <Card key={r.id} row={r} selected={r.id === selectedId} now={now} studentCount={links.studentsByParent.get(r.id)?.length ?? 0} onSelect={onSelect} />
      ))}
    </div>
  );
}
