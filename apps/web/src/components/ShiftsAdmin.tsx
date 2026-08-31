"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CalendarClock,
  CalendarDays,
  CalendarOff,
  CalendarSync,
  CheckCircle2,
  CheckSquare,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Grid3X3,
  List,
  Loader2,
  Lock,
  MoreVertical,
  Pencil,
  Plus,
  RefreshCw,
  Search,
  SlidersHorizontal,
  Timer,
  Trash2,
  UserRound,
  UserPlus,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { ShiftDeleteDialog } from "@/components/ShiftDeleteDialog";
import { ShiftDetailsDialog } from "@/components/ShiftDetailsDialog";
import { ShiftEditOptionsDialog } from "@/components/ShiftEditOptionsDialog";
import { ShiftEditorDialog } from "@/components/ShiftEditorDialog";
import { ShiftSeriesEditDialog } from "@/components/ShiftSeriesEditDialog";
import { FamilyPauseDialog } from "@/components/FamilyPauseDialog";
import { TemplateManagerDialog } from "@/components/TemplateManagerDialog";
import {
  type ShiftFilters,
  EMPTY_FILTERS,
  ShiftFilterPanel,
  activeFilterCount,
  applyFilters,
} from "@/components/ShiftFilterPanel";
import { auth } from "@/lib/firebase";
import { safeTimezone, timezoneAbbreviation } from "@/lib/timezones";
import { isCurrentUserAdmin } from "@/lib/userRoles";
import {
  type ShiftCounts,
  type ShiftDoc,
  type StaffMember,
  type StudentOption,
  type SubjectOption,
  loadAdminProfile,
  loadAllShiftsPaged,
  loadSeriesShifts,
  loadShiftById,
  loadShiftCounts,
  loadStaff,
  loadStudents,
  loadSubjects,
  loadWeekShifts,
  isRecurringShift,
  seriesTemplateId,
} from "@/lib/shifts";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type ViewMode = "grid" | "list";
type ShiftTab = "all" | "today" | "upcoming" | "active";
type EditorState =
  | { open: false }
  | { open: true; mode: "create"; shift: null; staffId: string | null; date: Date | null }
  | { open: true; mode: "edit"; shift: ShiftDoc; staffId: null; date: null }
  | { open: true; mode: "details"; shift: ShiftDoc; staffId: null; date: null }
  | { open: true; mode: "editOptions"; shift: ShiftDoc; staffId: null; date: null }
  | {
      open: true;
      mode: "series";
      shift: ShiftDoc;
      series: ShiftDoc[];
      staffId: null;
      date: null;
      /** Student-scoped bulk edits span several series — no template write. */
      updateTemplate: boolean;
      heading?: string;
    };

/**
 * Colors ported from the Flutter ShiftColors palette. Subjects that are not
 * in the map fall back to neutral gray — which matches production, where most
 * classes use the generic "other" subject and render as gray chips.
 */
const SUBJECT_COLORS: Record<string, string> = {
  quran: "#10B981",
  quranstudies: "#10B981",
  hadith: "#F59E0B",
  fiqh: "#8B5CF6",
  arabic: "#3B82F6",
  arabiclanguage: "#3B82F6",
  islamichistory: "#EF4444",
  aqeedah: "#06B6D4",
  tafseer: "#EC4899",
  seerah: "#F97316",
  english: "#2563EB",
  maths: "#059669",
  tutoring: "#0EA5E9",
};
/** Past-date chip tints keyed by status — same mapping as the Flutter grid. */
const PAST_BG: Record<string, string> = {
  scheduled: "#DDEAFF",
  active: "#DDEAFF",
  completed: "#E6F7E8",
  fullycompleted: "#E6F7E8",
  partiallycompleted: "#FFF7D1",
  missed: "#FDE0E0",
  cancelled: "#F3F4F6",
};
const PAST_FG: Record<string, string> = {
  scheduled: "#0386FF",
  active: "#0386FF",
  completed: "#10B981",
  fullycompleted: "#10B981",
  partiallycompleted: "#F59E0B",
  missed: "#EF4444",
  cancelled: "#9CA3AF",
};

const TABS: { id: ShiftTab; label: string }[] = [
  { id: "all", label: "All Shifts" },
  { id: "today", label: "Today" },
  { id: "upcoming", label: "Upcoming" },
  { id: "active", label: "Active" },
];

// Flutter's list virtualizes all ~9k rows; an HTML table can't, so cap what
// is rendered and tell the admin to narrow with search/filters.
const LIST_RENDER_CAP = 500;

export function ShiftsAdmin() {
  const [embedded, setEmbedded] = useState(false);
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [adminName, setAdminName] = useState("");
  const [adminTimezone, setAdminTimezone] = useState("America/New_York");
  const [shiftMap, setShiftMap] = useState<Map<string, ShiftDoc>>(() => new Map());
  const shifts = useMemo(() => [...shiftMap.values()], [shiftMap]);
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [students, setStudents] = useState<StudentOption[]>([]);
  const [subjects, setSubjects] = useState<SubjectOption[]>([]);
  const [viewMode, setViewMode] = useState<ViewMode>("grid");
  const [activeTab, setActiveTab] = useState<ShiftTab>("all");
  const [search, setSearch] = useState("");
  const [weekStart, setWeekStart] = useState(() => startOfWeek(new Date()));
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [toast, setToast] = useState("");
  const [editor, setEditor] = useState<EditorState>({ open: false });
  const [pendingDelete, setPendingDelete] = useState<ShiftDoc | null>(null);
  const [filtersExpanded, setFiltersExpanded] = useState(false);
  const [filters, setFilters] = useState<ShiftFilters>(EMPTY_FILTERS);
  const [globalCounts, setGlobalCounts] = useState<ShiftCounts | null>(null);
  const [hydration, setHydration] = useState<{ loaded: number; done: boolean } | null>(null);
  const [templatesOpen, setTemplatesOpen] = useState(false);
  const [familyPauseOpen, setFamilyPauseOpen] = useState(false);

  const refreshShifts = useCallback(async (targetWeek: Date) => {
    setLoading(true);
    // Chips count the whole history (Flutter parity); a count failure never
    // blocks the grid, the chips just keep their last value.
    void loadShiftCounts().then(setGlobalCounts).catch(() => {});
    try {
      const weekDocs = await loadWeekShifts(targetWeek);
      const weekEnd = addDays(targetWeek, 7);
      // The refetched week is authoritative: drop everything previously known
      // in that window (so deletions disappear), then merge the fresh docs.
      setShiftMap((prev) => {
        const next = new Map(prev);
        for (const [id, shift] of next) {
          if (shift.start >= targetWeek && shift.start < weekEnd) next.delete(id);
        }
        for (const shift of weekDocs) next.set(shift.id, shift);
        return next;
      });
      setMessage("");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not load shifts.");
    } finally {
      setLoading(false);
    }
  }, []);

  // After any series-wide operation, the hydrated cache must mirror the
  // server for EVERY week, not just the visible one — otherwise deleted
  // future occurrences linger as ghosts (or new/edited ones stay invisible)
  // until a reload. Drop everything known about the series, then merge back
  // exactly what the server still has.
  const reconcileSeriesInCache = useCallback(async (templateId: string) => {
    let fresh: ShiftDoc[] = [];
    try {
      fresh = await loadSeriesShifts(templateId);
    } catch {
      fresh = [];
    }
    setShiftMap((prev) => {
      const next = new Map(prev);
      for (const [id, shift] of next) {
        if (id === templateId || shift.templateId === templateId) next.delete(id);
      }
      for (const shift of fresh) next.set(shift.id, shift);
      return next;
    });
  }, []);

  // Background full-history hydration (Flutter parity): the current week
  // paints first, then every other shift streams in so search, the list view
  // and the tabs cover the whole schedule. Freshly refetched week docs win
  // over the hydrated snapshot.
  useEffect(() => {
    if (access !== "allowed") return;
    const signal = { aborted: false };
    setHydration({ loaded: 0, done: false });
    loadAllShiftsPaged((batch, loadedSoFar) => {
      setShiftMap((prev) => {
        const next = new Map(prev);
        for (const shift of batch) {
          if (!next.has(shift.id)) next.set(shift.id, shift);
        }
        return next;
      });
      setHydration({ loaded: loadedSoFar, done: false });
    }, signal)
      .then(() => {
        if (!signal.aborted) setHydration((prev) => ({ loaded: prev?.loaded ?? 0, done: true }));
      })
      .catch(() => {
        if (!signal.aborted) setHydration((prev) => ({ loaded: prev?.loaded ?? 0, done: true }));
      });
    return () => {
      signal.aborted = true;
    };
  }, [access]);

  useEffect(() => {
    const inFlutterFrame =
      window.self !== window.top || new URLSearchParams(window.location.search).has("embed");
    if (inFlutterFrame) {
      setEmbedded(true);
    } else {
      window.location.replace("/app/");
    }
  }, []);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }
      setAccess("checking");
      try {
        const allowed = await isCurrentUserAdmin(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        setAccess("allowed");
        const [profile, loadedStaff, loadedStudents, loadedSubjects] = await Promise.all([
          loadAdminProfile(nextUser),
          loadStaff(),
          loadStudents(),
          loadSubjects(),
        ]);
        if (!mounted) return;
        setAdminName(profile.name);
        setAdminTimezone(profile.timezone);
        setStaff(loadedStaff);
        setStudents(loadedStudents);
        setSubjects(loadedSubjects);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load shift data.");
      }
    });
  }, []);

  useEffect(() => {
    if (access === "allowed") void refreshShifts(weekStart);
  }, [access, weekStart, refreshShifts]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(""), 4000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const weekDays = useMemo(() => Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)), [weekStart]);

  // Chips/tab badges show the FULL history counts (server aggregation, same
  // numbers as Flutter); the week's own data only fills in while they load.
  const counts = useMemo(() => {
    if (globalCounts) return globalCounts;
    const now = new Date();
    return {
      all: shifts.length,
      today: shifts.filter((shift) => isSameDay(shift.start, now)).length,
      upcoming: shifts.filter((shift) => shift.start > now && !["cancelled", "missed"].includes(shift.status)).length,
      active: shifts.filter((shift) => shift.status.toLowerCase() === "active").length,
    };
  }, [shifts, globalCounts]);

  const visibleShifts = useMemo(() => {
    const now = new Date();
    let filtered = shifts;
    if (activeTab === "today") filtered = filtered.filter((shift) => isSameDay(shift.start, now));
    if (activeTab === "upcoming") {
      filtered = filtered.filter((shift) => shift.start > now && !["cancelled", "missed"].includes(shift.status));
    }
    if (activeTab === "active") filtered = filtered.filter((shift) => shift.status.toLowerCase() === "active");
    filtered = applyFilters(filtered, filters, students);
    const q = search.trim().toLowerCase();
    if (!q) return filtered;
    return filtered.filter(
      (shift) =>
        shift.title.toLowerCase().includes(q) ||
        shift.teacherName.toLowerCase().includes(q) ||
        shift.subjectDisplayName.toLowerCase().includes(q) ||
        shift.studentNames.some((name) => name.toLowerCase().includes(q)),
    );
  }, [shifts, search, activeTab, filters, students]);

  // The grid always renders the selected week; the hydrated full history
  // feeds search, the list view and the tab filters (Flutter parity).
  const weekVisibleShifts = useMemo(() => {
    const weekEnd = addDays(weekStart, 7);
    return visibleShifts.filter((shift) => shift.start >= weekStart && shift.start < weekEnd);
  }, [visibleShifts, weekStart]);

  // With a teacher filter, the grid shows ONLY that teacher's row; with any
  // other filter or a search, rows without a single matching shift disappear
  // so the result is just the teachers the query is about. No filters = the
  // full roster, empty rows included (that is how the week is planned).
  const gridStaff = useMemo(() => {
    if (filters.teacherId) return staff.filter((member) => member.id === filters.teacherId);
    const narrowing = search.trim().length > 0 || activeFilterCount(filters) > 0;
    if (!narrowing) return staff;
    const teachersWithResults = new Set(weekVisibleShifts.map((shift) => shift.teacherId));
    return staff.filter((member) => teachersWithResults.has(member.id));
  }, [staff, filters, search, weekVisibleShifts]);

  const studentTimezoneById = useMemo(() => new Map(students.map((s) => [s.id, s.timezone])), [students]);
  const studentCodeById = useMemo(() => new Map(students.map((s) => [s.id, s.studentCode])), [students]);

  const filterCount = activeFilterCount(filters);

  // Editing a recurring shift routes through the Edit Options router (this
  // shift vs the whole series); a one-off goes straight to the editor.
  const openEdit = useCallback((shift: ShiftDoc) => {
    // Past classes are pay/attendance history — never editable (Delete for
    // admins stays available for cleanup).
    if (shift.end.getTime() < Date.now()) {
      setToast("Past shifts can't be edited — their record is part of pay history.");
      return;
    }
    if (isRecurringShift(shift)) {
      setEditor({ open: true, mode: "editOptions", shift, staffId: null, date: null });
    } else {
      setEditor({ open: true, mode: "edit", shift, staffId: null, date: null });
    }
  }, []);

  // This screen only ever renders inside the Flutter web app's content area
  // (same-origin iframe), so admins always keep their real Flutter sidebar.
  // A direct visit to /admin/shifts/ goes to the Flutter app instead.
  if (!embedded) return null;

  if (access !== "allowed") return <ShiftsAccessPrompt access={access} />;

  return (
      <main className="min-h-screen bg-[#F7F8FA] px-4 py-5 lg:px-6">
        {/* Title row — mirrors the Flutter "Shift Management" header */}
        <header className="mb-3 flex flex-wrap items-center gap-3">
          <span className="grid h-9 w-9 place-items-center rounded-full bg-[#EAF5FF] text-[#0386FF]">
            <CalendarClock size={19} />
          </span>
          <h1 className="text-xl font-bold text-[#1F2937]">Shift Management</h1>
          <div className="ml-auto flex items-center gap-2">
            <button
              type="button"
              onClick={() => setEditor({ open: true, mode: "create", shift: null, staffId: null, date: null })}
              className="inline-flex h-10 items-center gap-1.5 rounded-full bg-[#0386FF] px-4 text-sm font-bold text-white shadow-sm hover:bg-[#0271d6]"
            >
              <Plus size={16} />
              Create Shift
            </button>
            <button
              type="button"
              onClick={() => setFamilyPauseOpen(true)}
              className="grid h-10 w-10 place-items-center rounded-full text-[#C2410C] hover:bg-[#FFF7ED]"
              title="Pause classes for a break"
              aria-label="Pause classes for a break"
            >
              <CalendarOff size={17} />
            </button>
            <button
              type="button"
              onClick={() => setTemplatesOpen(true)}
              className="grid h-10 w-10 place-items-center rounded-full text-[#64748B] hover:bg-[#EEF2F7]"
              title="Manage repeat patterns"
              aria-label="Manage repeat patterns"
            >
              <CalendarSync size={17} />
            </button>
            <button
              type="button"
              onClick={() => void refreshShifts(weekStart)}
              className="grid h-10 w-10 place-items-center rounded-full text-[#64748B] hover:bg-[#EEF2F7]"
              aria-label="Refresh"
            >
              <RefreshCw size={17} />
            </button>
          </div>
        </header>

        {/* Stats chips — centered like Flutter */}
        <div className="mb-3 flex flex-wrap items-center justify-center gap-2">
          <StatChip label="Total" value={counts.all} icon={CalendarDays} color="#0386FF" />
          <StatChip label="Active" value={counts.active} icon={Users} color="#10B981" />
          <StatChip label="Today" value={counts.today} icon={Clock3} color="#F59E0B" />
          <StatChip label="Upcoming" value={counts.upcoming} icon={CheckSquare} color="#8B5CF6" />
          {hydration && !hydration.done ? (
            <span className="inline-flex items-center gap-1.5 rounded-full border border-[#BFDBFE] bg-[#EFF6FF] px-3 py-1.5 text-xs font-semibold text-[#1D4ED8]">
              <Loader2 size={12} className="animate-spin" />
              {counts.all > hydration.loaded
                ? `Loading full history: ${Math.floor((hydration.loaded / counts.all) * 100)}% (${hydration.loaded} of ${counts.all})`
                : `Loading full history: ${hydration.loaded} shifts`}
            </span>
          ) : null}
        </div>

        <section className="rounded-2xl border border-[#E2E8F0] bg-white shadow-sm">
          {/* Tabs + view toggle */}
          <div className="flex flex-wrap items-center border-b border-[#E2E8F0] px-4">
            {TABS.map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`relative -mb-px border-b-2 px-3 py-3 text-sm font-semibold ${
                  activeTab === tab.id ? "border-[#0386FF] text-[#0386FF]" : "border-transparent text-[#64748B]"
                }`}
              >
                {tab.label} ({counts[tab.id]})
              </button>
            ))}
            <div className="ml-auto flex items-center gap-1 py-2">
              <ViewToggleButton icon={Grid3X3} label="Grid" selected={viewMode === "grid"} onClick={() => setViewMode("grid")} />
              <ViewToggleButton icon={List} label="List" selected={viewMode === "list"} onClick={() => setViewMode("list")} />
            </div>
          </div>

          {/* Search row with filter toggle */}
          <div className="flex items-center gap-2 border-b border-[#E2E8F0] px-4 py-2.5">
            <label className="flex flex-1 items-center gap-2">
              <Search size={15} className="text-[#94A3B8]" />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search Users Or Shifts"
                className="w-full text-sm outline-none"
              />
            </label>
            <button
              type="button"
              onClick={() => setFiltersExpanded((open) => !open)}
              title={filtersExpanded ? "Hide filters" : "Show filters"}
              className={`relative grid h-9 w-9 place-items-center rounded-lg hover:bg-[#F1F5F9] ${
                filterCount > 0 ? "text-[#0386FF]" : "text-[#6B7280]"
              }`}
            >
              <SlidersHorizontal size={18} />
              {filterCount > 0 ? (
                <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-[#0386FF]" />
              ) : null}
            </button>
          </div>

          {filtersExpanded ? (
            <ShiftFilterPanel
              filters={filters}
              onChange={setFilters}
              onClear={() => setFilters(EMPTY_FILTERS)}
              staff={staff}
              students={students}
              subjects={subjects}
              resultCount={visibleShifts.length}
            />
          ) : null}

          {/* Week navigation — Flutter style */}
          <div className="flex items-center border-b border-[#E2E8F0] px-4 py-2 text-sm">
            <button
              type="button"
              onClick={() => setWeekStart(addDays(weekStart, -7))}
              className="inline-flex items-center gap-1 font-semibold text-[#0386FF] hover:underline"
            >
              <CalendarDays size={15} />
              Previous Week
              <ChevronLeft size={16} />
            </button>
            <button
              type="button"
              onClick={() => setWeekStart(startOfWeek(new Date()))}
              className="mx-auto font-bold text-[#374151] hover:text-[#0386FF]"
              title="Jump to this week"
            >
              {shortWeekday(weekStart)} {formatMonthDay(weekStart)} → {shortWeekday(addDays(weekStart, 6))} {formatMonthDay(addDays(weekStart, 6))}
            </button>
            <button
              type="button"
              onClick={() => setWeekStart(addDays(weekStart, 7))}
              className="inline-flex items-center gap-1 font-semibold text-[#0386FF] hover:underline"
            >
              <ChevronRight size={16} />
              Next Week
            </button>
          </div>

          {message ? <p className="border-b border-[#FDE68A] bg-[#FFFBEB] px-4 py-2.5 text-sm font-semibold text-[#92400E]">{message}</p> : null}

          {loading ? (
            <LoadingPanel />
          ) : viewMode === "grid" ? (
            <WeeklyGrid
              weekDays={weekDays}
              staff={gridStaff}
              shifts={weekVisibleShifts}
              studentTimezoneById={studentTimezoneById}
              studentCodeById={studentCodeById}
              onShiftClick={(shift) => setEditor({ open: true, mode: "details", shift, staffId: null, date: null })}
              onShiftEdit={openEdit}
              onShiftDelete={(shift) => setPendingDelete(shift)}
              onEmptyCellClick={(staffId, day) => setEditor({ open: true, mode: "create", shift: null, staffId, date: day })}
            />
          ) : (
            <>
              <ShiftList
                shifts={visibleShifts.slice(0, LIST_RENDER_CAP)}
                onShiftClick={(shift) => setEditor({ open: true, mode: "details", shift, staffId: null, date: null })}
              />
              {visibleShifts.length > LIST_RENDER_CAP ? (
                <p className="border-t border-[#E2E8F0] px-4 py-2.5 text-xs font-semibold text-[#6B7280]">
                  Showing the first {LIST_RENDER_CAP} of {visibleShifts.length} shifts — search or filter to narrow the list.
                </p>
              ) : null}
            </>
          )}
        </section>

        {familyPauseOpen ? (
          <FamilyPauseDialog
            students={students}
            adminTimezone={adminTimezone}
            adminName={adminName}
            onClose={() => setFamilyPauseOpen(false)}
            onChanged={() => {
              void loadShiftCounts().then(setGlobalCounts).catch(() => {});
              void refreshShifts(weekStart);
            }}
          />
        ) : null}

        {templatesOpen ? (
          <TemplateManagerDialog
            staff={staff}
            adminName={adminName}
            studentCodeById={studentCodeById}
            onOpenSeries={(templateId) => {
              // The directory never edits — it hands off to the one editor.
              void loadSeriesShifts(templateId).then((seriesShifts) => {
                if (seriesShifts.length === 0) return;
                setTemplatesOpen(false);
                setEditor({
                  open: true,
                  mode: "series",
                  shift: seriesShifts[0],
                  series: seriesShifts,
                  staffId: null,
                  date: null,
                  updateTemplate: true,
                });
              });
            }}
            onClose={() => setTemplatesOpen(false)}
            onChanged={() => {
              void loadShiftCounts().then(setGlobalCounts).catch(() => {});
              void refreshShifts(weekStart);
            }}
          />
        ) : null}

        {/* Confirmation an admin cannot miss: a green tick, the exact outcome,
            and it sits long enough to read (4s) before fading. */}
        {toast ? (
          <div
            role="status"
            aria-live="polite"
            className="fixed bottom-6 left-1/2 z-[90] flex max-w-[min(90vw,520px)] -translate-x-1/2 items-start gap-2.5 rounded-xl bg-[#0F172A] px-5 py-3.5 text-sm font-semibold text-white shadow-2xl"
          >
            <CheckCircle2 size={17} className="mt-px shrink-0 text-[#34D399]" />
            <span>{toast}</span>
          </div>
        ) : null}

        {editor.open && editor.mode === "details" ? (
          <ShiftDetailsDialog
            shift={editor.shift}
            studentCodeById={studentCodeById}
            onEdit={() => openEdit(editor.shift)}
            onRequestDelete={() => {
              const target = editor.shift;
              setEditor({ open: false });
              setPendingDelete(target);
            }}
            onClose={() => setEditor({ open: false })}
          />
        ) : null}

        {pendingDelete ? (
          <ShiftDeleteDialog
            shift={pendingDelete}
            onDeleted={(deletedMessage, mode) => {
              const target = pendingDelete;
              setPendingDelete(null);
              setToast(deletedMessage);
              if (mode === "series") {
                void reconcileSeriesInCache(seriesTemplateId(target));
              } else {
                setShiftMap((prev) => {
                  const next = new Map(prev);
                  next.delete(target.id);
                  return next;
                });
              }
              void refreshShifts(weekStart);
            }}
            onClose={() => setPendingDelete(null)}
          />
        ) : null}

        {editor.open && editor.mode === "editOptions" ? (
          <ShiftEditOptionsDialog
            shift={editor.shift}
            studentCodeById={studentCodeById}
            onClose={() => setEditor({ open: false })}
            onPick={(scope, pickedShifts, heading) => {
              const target = editor.shift;
              if (scope === "single") {
                setEditor({ open: true, mode: "edit", shift: target, staffId: null, date: null });
              } else {
                setEditor({
                  open: true,
                  mode: "series",
                  shift: target,
                  series: pickedShifts,
                  staffId: null,
                  date: null,
                  updateTemplate: scope === "series",
                  heading,
                });
              }
            }}
          />
        ) : null}

        {editor.open && editor.mode === "series" && user ? (
          <ShiftSeriesEditDialog
            shift={editor.shift}
            seriesShifts={editor.series}
            staff={staff}
            students={students}
            subjects={subjects}
            admin={user}
            adminName={adminName}
            updateTemplate={editor.updateTemplate}
            heading={editor.heading}
            onClose={() => setEditor({ open: false })}
            onSaved={(savedMessage) => {
              const target = editor.shift;
              const touched = editor.series;
              setEditor({ open: false });
              setToast(savedMessage);
              // Refresh every series the edit touched (a student-scoped bulk
              // edit can span several), then the visible week.
              const templateIds = new Set(touched.map((s) => s.templateId ?? s.id));
              templateIds.add(seriesTemplateId(target));
              for (const templateId of templateIds) void reconcileSeriesInCache(templateId);
              void refreshShifts(weekStart);
            }}
          />
        ) : null}

        {editor.open && (editor.mode === "create" || editor.mode === "edit") && user ? (
          <ShiftEditorDialog
            mode={editor.mode}
            shift={editor.mode === "edit" ? editor.shift : null}
            prefill={{ staffId: editor.mode === "create" ? editor.staffId : null, date: editor.mode === "create" ? editor.date : null }}
            staff={staff}
            students={students}
            subjects={subjects}
            admin={user}
            adminName={adminName}
            adminTimezone={adminTimezone}
            onSubjectsChanged={() => void loadSubjects().then(setSubjects).catch(() => {})}
            onClose={() => setEditor({ open: false })}
            onSaved={(savedMessage, outcome) => {
              const edited = editor.mode === "edit" ? editor.shift : null;
              setEditor({ open: false });
              setToast(savedMessage);
              // A new recurring series generates occurrences far beyond the
              // current week — pull them all in so future weeks show them
              // without a reload. An edit refreshes that one shift wherever
              // it lives (it may sit outside the refetched week).
              if (outcome?.kind === "template") {
                void reconcileSeriesInCache(outcome.templateId);
              } else if (outcome?.kind === "templates") {
                // Per-day-time weekly create makes one series per distinct
                // time — pull every one into the cache so all weeks show them.
                for (const templateId of outcome.templateIds) {
                  void reconcileSeriesInCache(templateId);
                }
              } else if (outcome?.kind === "multi") {
                // One-time multi-day creates can land in future weeks — pull
                // each new shift into the cache so every week shows it now.
                for (const shiftId of outcome.shiftIds) {
                  void loadShiftById(shiftId).then((fresh) => {
                    if (!fresh) return;
                    setShiftMap((prev) => {
                      const next = new Map(prev);
                      next.set(fresh.id, fresh);
                      return next;
                    });
                  }).catch(() => {});
                }
              } else if (edited) {
                void loadShiftById(edited.id).then((fresh) => {
                  setShiftMap((prev) => {
                    const next = new Map(prev);
                    if (fresh) next.set(fresh.id, fresh);
                    else next.delete(edited.id);
                    return next;
                  });
                }).catch(() => {});
              }
              void refreshShifts(weekStart);
            }}
          />
        ) : null}
      </main>
  );
}

function WeeklyGrid({
  weekDays,
  staff,
  shifts,
  studentTimezoneById,
  studentCodeById,
  onShiftClick,
  onShiftEdit,
  onShiftDelete,
  onEmptyCellClick,
}: {
  weekDays: Date[];
  staff: StaffMember[];
  shifts: ShiftDoc[];
  studentTimezoneById: Map<string, string>;
  studentCodeById: Map<string, string>;
  onShiftClick: (shift: ShiftDoc) => void;
  onShiftEdit: (shift: ShiftDoc) => void;
  onShiftDelete: (shift: ShiftDoc) => void;
  onEmptyCellClick: (staffId: string, day: Date) => void;
}) {
  // One floating hover card for the whole grid (fixed-position so the grid's
  // own scroll container never clips it) — replica of the Flutter chip tooltip.
  const [hover, setHover] = useState<{ shift: ShiftDoc; x: number; y: number } | null>(null);
  const showHover = (shift: ShiftDoc) => (event: React.MouseEvent<HTMLElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const width = 232;
    const x = rect.right + 8 + width > window.innerWidth ? Math.max(8, rect.left - width - 8) : rect.right + 8;
    const y = Math.max(8, Math.min(rect.top, window.innerHeight - 300));
    setHover({ shift, x, y });
  };
  const hideHover = () => setHover(null);
  const byStaffAndDay = useMemo(() => {
    const map = new Map<string, ShiftDoc[]>();
    for (const shift of shifts) {
      const key = `${shift.teacherId}|${dayKey(shift.start)}`;
      const list = map.get(key);
      if (list) list.push(shift);
      else map.set(key, [shift]);
    }
    for (const list of map.values()) list.sort((a, b) => a.start.getTime() - b.start.getTime());
    return map;
  }, [shifts]);

  const weeklyTotals = useMemo(() => {
    const totals = new Map<string, { hours: number; count: number }>();
    for (const shift of shifts) {
      const entry = totals.get(shift.teacherId) ?? { hours: 0, count: 0 };
      entry.hours += (shift.end.getTime() - shift.start.getTime()) / 3600e3;
      entry.count += 1;
      totals.set(shift.teacherId, entry);
    }
    return totals;
  }, [shifts]);

  const dailyTotals = useMemo(
    () =>
      weekDays.map((day) => {
        let hours = 0;
        let count = 0;
        for (const shift of shifts) {
          if (isSameDay(shift.start, day)) {
            hours += (shift.end.getTime() - shift.start.getTime()) / 3600e3;
            count += 1;
          }
        }
        return { hours, count };
      }),
    [weekDays, shifts],
  );

  const teachers = staff.filter((member) => member.group === "teacher");
  const leaders = staff.filter((member) => member.group === "leader");
  const today = new Date();

  const renderRow = (member: StaffMember) => (
    <div key={member.id} className="grid min-h-16 grid-cols-[180px_repeat(7,minmax(126px,1fr))] border-b border-[#EDF0F4]">
      <div className="flex items-center gap-2.5 border-r border-[#EDF0F4] bg-white px-3 py-2">
        <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-[#DBEAFE] text-xs font-bold text-[#0386FF]">
          {member.initials}
        </span>
        <span className="min-w-0">
          <span className="block truncate text-[13px] font-semibold text-[#374151]">{member.displayName}</span>
          <span className="flex items-center gap-1 text-[11px] text-[#94A3B8]">
            <Timer size={11} />
            {(weeklyTotals.get(member.id)?.hours ?? 0).toFixed(1)}
            <span className="text-[#CBD5E1]">|</span>
            <CalendarDays size={11} />
            {weeklyTotals.get(member.id)?.count ?? 0}
          </span>
        </span>
      </div>
      {weekDays.map((day) => {
        const cellShifts = byStaffAndDay.get(`${member.id}|${dayKey(day)}`) ?? [];
        const isPast = endOfDay(day) < today;
        const isToday = isSameDay(day, today);
        return (
          <div
            key={`${member.id}-${day.toISOString()}`}
            className={`group relative min-h-16 border-r border-[#EDF0F4] p-1 ${isToday ? "bg-[#F2F8FF]" : "bg-white"}`}
          >
            {cellShifts.map((shift, index) => (
              <ShiftChip
                key={shift.id}
                shift={shift}
                index={index + 1}
                total={cellShifts.length}
                isPast={isPast}
                onOpen={() => onShiftClick(shift)}
                onEdit={() => onShiftEdit(shift)}
                onDelete={() => onShiftDelete(shift)}
                onAdd={() => onEmptyCellClick(member.id, day)}
                onHoverStart={showHover(shift)}
                onHoverEnd={hideHover}
                editable={shift.end.getTime() >= Date.now()}
              />
            ))}
            {!isPast ? (
              <button
                type="button"
                onClick={() => onEmptyCellClick(member.id, day)}
                className={`w-full items-center justify-center rounded-md border border-dashed border-[#CBD5E1] bg-white py-1 text-[#94A3B8] hover:border-[#0386FF] hover:text-[#0386FF] ${
                  cellShifts.length === 0 ? "hidden h-full min-h-12 group-hover:flex" : "mt-0.5 hidden group-hover:flex"
                }`}
                aria-label={`Add shift for ${member.displayName} on ${formatMonthDay(day)}`}
              >
                <Plus size={14} />
              </button>
            ) : null}
          </div>
        );
      })}
    </div>
  );

  return (
    <div className="overflow-auto">
      <div className="min-w-[1080px]">
        <div className="grid grid-cols-[180px_repeat(7,minmax(126px,1fr))] border-b border-[#E2E8F0] bg-[#FAFBFC] text-center text-xs text-[#64748B]">
          <div className="flex h-12 flex-col items-center justify-center border-r border-[#EDF0F4]">
            <span className="font-semibold">Teachers</span>
            <span className="text-[10px] text-[#94A3B8]">({staff.filter((s) => s.group === "teacher").length})</span>
          </div>
          {weekDays.map((day, index) => (
            <div
              key={day.toISOString()}
              className={`flex h-12 flex-col items-center justify-center border-r border-[#EDF0F4] ${isSameDay(day, today) ? "bg-[#E8F3FF]" : ""}`}
            >
              <span className={`font-bold ${isSameDay(day, today) ? "text-[#0386FF]" : "text-[#374151]"}`}>
                {shortWeekday(day)}
              </span>
              <span className="text-[11px]">{formatMonthDay(day)}</span>
              <span className="mt-0.5 flex items-center gap-1 text-[10px] text-[#94A3B8]">
                <Timer size={10} />
                {dailyTotals[index].hours.toFixed(1)}
                <span className="text-[#CBD5E1]">|</span>
                <CalendarDays size={10} />
                {dailyTotals[index].count}
              </span>
            </div>
          ))}
        </div>

        {teachers.length > 0 ? (
          <div className="flex h-8 items-center gap-2 border-b border-[#E2E8F0] bg-[#F3F4F6] px-4 text-[11px] font-bold uppercase tracking-[0.03em] text-[#64748B]">
            <UserRound size={13} />
            Teachers ({teachers.length})
          </div>
        ) : null}
        {teachers.map(renderRow)}

        {leaders.length > 0 ? (
          <div className="flex h-8 items-center gap-2 border-b border-[#E2E8F0] bg-[#F3F4F6] px-4 text-[11px] font-bold uppercase tracking-[0.03em] text-[#64748B]">
            <UserRound size={13} />
            Leaders ({leaders.length})
          </div>
        ) : null}
        {leaders.map(renderRow)}

        {teachers.length === 0 && leaders.length === 0 ? (
          <div className="grid min-h-[360px] place-items-center text-sm font-semibold text-[#64748B]">No staff found</div>
        ) : null}
      </div>
      {hover ? (
        <ShiftHoverCard
          shift={hover.shift}
          x={hover.x}
          y={hover.y}
          studentTimezone={hover.shift.studentIds.length ? (studentTimezoneById.get(hover.shift.studentIds[0]) ?? "") : ""}
          studentCodeById={studentCodeById}
        />
      ) : null}
    </div>
  );
}

/**
 * Replica of the Flutter chip tooltip: subject + duration header, the class
 * window converted into the student's and the teacher's own timezones, the
 * student roster, and who created the shift. Dark panel, fixed-position.
 */
function ShiftHoverCard({
  shift,
  x,
  y,
  studentTimezone,
  studentCodeById,
}: {
  shift: ShiftDoc;
  x: number;
  y: number;
  studentTimezone: string;
  studentCodeById: Map<string, string>;
}) {
  const timeIn = (date: Date, zone: string) =>
    new Intl.DateTimeFormat("en-US", { timeZone: safeTimezone(zone), hour: "numeric", minute: "2-digit", hour12: true }).format(date);
  const range = (zone: string) => `${timeIn(shift.start, zone)} – ${timeIn(shift.end, zone)}`;
  const durationMinutes = Math.round((shift.end.getTime() - shift.start.getTime()) / 60e3);
  const duration =
    durationMinutes >= 60
      ? `${Math.floor(durationMinutes / 60)}h${durationMinutes % 60 > 0 ? ` ${durationMinutes % 60}m` : ""}`
      : `${durationMinutes}m`;
  const subject = shift.subjectDisplayName || shift.subject || shift.title;
  const teaching = shift.category === "teaching";
  return (
    <div
      className="pointer-events-none fixed z-[80] w-[232px] rounded-lg bg-[#0F172A] px-3.5 py-3 shadow-xl"
      style={{ left: x, top: y }}
    >
      <p className="text-[10px] font-bold uppercase tracking-[0.08em] text-[#94A3B8]">
        {subject} · {duration}
      </p>
      {studentTimezone ? (
        <div className="mt-2">
          <p className="text-[10px] font-medium text-[#94A3B8]">Student</p>
          <p className="text-xs font-semibold text-white">
            {range(studentTimezone)}{" "}
            <span className="text-[10px] font-semibold text-[#FBBF24]">{timezoneAbbreviation(studentTimezone, shift.start)}</span>
          </p>
        </div>
      ) : null}
      <div className="mt-2">
        <p className="text-[10px] font-medium text-[#94A3B8]">Teacher</p>
        <p className="text-xs font-semibold text-white">
          {range(shift.teacherTimezone)}{" "}
          <span className="text-[10px] font-semibold text-[#34D399]">{timezoneAbbreviation(shift.teacherTimezone, shift.start)}</span>
        </p>
        {shift.teacherName ? <p className="text-[10px] text-[#64748B]">&nbsp;&nbsp;{shift.teacherName}</p> : null}
      </div>
      {teaching && shift.studentNames.length > 0 ? (
        <div className="mt-2">
          <p className="text-[10px] font-bold uppercase tracking-[0.08em] text-[#94A3B8]">
            Student{shift.studentNames.length === 1 ? "" : "s"}
          </p>
          {shift.studentNames.slice(0, 6).map((name, index) => {
            const code = studentCodeById.get(shift.studentIds[index] ?? "") ?? "";
            return (
              <p key={`${name}-${index}`} className="text-[11px] font-medium text-white">
                <span className="text-[#64748B]">· </span>
                {name}
                {code ? <span className="text-[10px] text-[#64748B]"> · {code}</span> : null}
              </p>
            );
          })}
          {shift.studentNames.length > 6 ? (
            <p className="text-[10px] text-[#64748B]">+ {shift.studentNames.length - 6} more</p>
          ) : null}
        </div>
      ) : null}
      {shift.createdByName.trim() ? (
        <div className="mt-2">
          <p className="text-[10px] font-bold uppercase tracking-[0.08em] text-[#94A3B8]">Created by</p>
          <p className="text-[11px] font-medium text-white">{shift.createdByName.trim()}</p>
        </div>
      ) : null}
    </div>
  );
}

/**
 * Chip styled after the Flutter ShiftBlock: the chip FILLS its cell with a
 * translucent status/subject tint (not a small card). On hover a toolbar of
 * edit / details / delete / add-here actions appears, matching the Flutter
 * grid. Past shifts are tinted by status; future shifts by subject.
 */
function ShiftChip({
  shift,
  index,
  total,
  isPast,
  onOpen,
  onEdit,
  onDelete,
  onAdd,
  onHoverStart,
  onHoverEnd,
  editable,
}: {
  shift: ShiftDoc;
  index: number;
  total: number;
  isPast: boolean;
  onOpen: () => void;
  onEdit: () => void;
  onDelete: () => void;
  onAdd: () => void;
  onHoverStart: (event: React.MouseEvent<HTMLElement>) => void;
  onHoverEnd: () => void;
  editable: boolean;
}) {
  const subjectKey = (shift.subjectId || shift.subject || "").toLowerCase().replace(/[^a-z]/g, "");
  const subjectColor = SUBJECT_COLORS[subjectKey] ?? null;
  const statusKey = shift.status.toLowerCase().replace(/[^a-z]/g, "");
  const bg = isPast ? (PAST_BG[statusKey] ?? "#F3F4F6") : subjectColor ? `${subjectColor}22` : "#EDEFF2";
  const border = isPast ? (PAST_FG[statusKey] ?? "#9CA3AF") : (subjectColor ?? "#CBD5E1");
  const fg = isPast ? (PAST_FG[statusKey] ?? "#4B5563") : (subjectColor ? "#1F2937" : "#374151");
  const label =
    shift.category === "teaching" ? shift.subjectDisplayName || shift.subject || "Class" : shift.leaderRole || shift.category;
  const stop = (fn: () => void) => (event: React.MouseEvent) => {
    event.stopPropagation();
    fn();
  };
  return (
    <div
      onClick={onOpen}
      onMouseEnter={onHoverStart}
      onMouseLeave={onHoverEnd}
      className="group/chip relative mb-1 min-h-[52px] cursor-pointer rounded-md px-2 py-1.5 text-left text-[11px] leading-tight"
      style={{ backgroundColor: bg, borderLeft: `3px solid ${border}` }}
    >
      <div className="flex items-start gap-1">
        <span className="font-bold" style={{ color: fg }}>
          {formatTimeRange(shift.start, shift.end)}
        </span>
        {total > 1 ? (
          <span className="ml-auto rounded bg-white/70 px-1 text-[9px] font-bold text-[#64748B]">
            {index}/{total}
          </span>
        ) : null}
        <UserPlus size={11} className={`${total > 1 ? "" : "ml-auto"} mt-px shrink-0 text-[#94A3B8]`} />
      </div>
      <span className="mt-0.5 block truncate font-medium text-[#4B5563]">{label}</span>
      {shift.studentNames.length > 0 ? (
        <span className="block truncate text-[10px] text-[#94A3B8]">
          {shift.studentNames.length === 1 ? shift.studentNames[0] : `${shift.studentNames.length} students`}
        </span>
      ) : null}

      {/* Hover toolbar — edit / details / delete / add-here */}
      <div className="absolute right-1 top-1 hidden items-center gap-0.5 rounded-md bg-white/95 px-1 py-0.5 shadow-sm group-hover/chip:flex">
        {editable ? (
          <button type="button" onClick={stop(onEdit)} title="Edit shift" className="grid h-5 w-5 place-items-center rounded text-[#475569] hover:bg-[#EEF2F7]">
            <Pencil size={12} />
          </button>
        ) : null}
        <button type="button" onClick={stop(onOpen)} title="Details" className="grid h-5 w-5 place-items-center rounded text-[#475569] hover:bg-[#EEF2F7]">
          <MoreVertical size={12} />
        </button>
        <button type="button" onClick={stop(onDelete)} title="Delete shift" className="grid h-5 w-5 place-items-center rounded text-[#DC2626] hover:bg-[#FEE2E2]">
          <Trash2 size={12} />
        </button>
        <button type="button" onClick={stop(onAdd)} title="Add shift here" className="grid h-5 w-5 place-items-center rounded bg-[#0386FF] text-white hover:bg-[#0271d6]">
          <Plus size={12} />
        </button>
      </div>
    </div>
  );
}

function ShiftList({ shifts, onShiftClick }: { shifts: ShiftDoc[]; onShiftClick: (shift: ShiftDoc) => void }) {
  if (shifts.length === 0) {
    return <div className="grid min-h-[360px] place-items-center text-sm font-semibold text-[#64748B]">No shifts this week</div>;
  }
  return (
    <div className="overflow-x-auto">
      <table className="min-w-[880px] table-fixed border-collapse text-left text-sm">
        <thead className="bg-[#F8FAFC] text-xs uppercase text-[#64748B]">
          <tr>
            {["Shift", "Teacher", "Students", "Date", "Time", "Status"].map((heading) => (
              <th key={heading} className="border-b border-[#E2E8F0] px-4 py-3 font-bold">
                {heading}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {shifts.map((shift) => {
            const statusKey = shift.status.toLowerCase().replace(/[^a-z]/g, "");
            const fg = PAST_FG[statusKey] ?? "#6B7280";
            return (
              <tr key={shift.id} onClick={() => onShiftClick(shift)} className="cursor-pointer border-b border-[#E2E8F0] hover:bg-[#F8FAFC]">
                <td className="truncate px-4 py-3 font-semibold">{shift.title}</td>
                <td className="truncate px-4 py-3">{shift.teacherName}</td>
                <td className="truncate px-4 py-3">{shift.studentNames.join(", ")}</td>
                <td className="px-4 py-3">{formatMonthDay(shift.start)}</td>
                <td className="px-4 py-3">{formatTimeRange(shift.start, shift.end)}</td>
                <td className="px-4 py-3">
                  <span className="rounded-full px-2 py-1 text-xs font-bold capitalize" style={{ backgroundColor: `${fg}1A`, color: fg }}>
                    {shift.status || "scheduled"}
                  </span>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function StatChip({ label, value, icon: Icon, color }: { label: string; value: number; icon: LucideIcon; color: string }) {
  return (
    <div
      className="inline-flex min-h-7 items-center gap-1.5 rounded-full border px-3 text-xs font-semibold"
      style={{ borderColor: `${color}33`, backgroundColor: `${color}12`, color }}
    >
      <Icon size={14} />
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function ViewToggleButton({ icon: Icon, label, selected, onClick }: { icon: LucideIcon; label: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex min-h-8 items-center gap-1.5 rounded-lg px-3 text-[13px] font-bold ${
        selected ? "bg-[#0386FF] text-white" : "bg-[#F1F5F9] text-[#64748B]"
      }`}
    >
      <Icon size={15} />
      {label}
    </button>
  );
}

function LoadingPanel() {
  return (
    <div className="grid min-h-[360px] place-items-center">
      <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
    </div>
  );
}

function ShiftsAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F1F4F8] px-5 text-[#0F172A]">
      <section className="w-full max-w-md rounded-[20px] border border-black/10 bg-white px-6 py-10 text-center shadow-sm">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#E6EEF8] text-[#001E4E]">
          <Lock size={24} />
        </div>
        <h1 className="mt-4 text-xl font-bold">
          {checking ? "Checking admin access" : access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {checking
            ? "Please wait while we verify your dashboard permissions."
            : access === "signedOut"
              ? "Sign in with an administrator account before managing shifts."
              : "Your signed-in account does not have administrator permissions for this module."}
        </p>
        {!checking ? (
          <Link href="/login/" className="mt-5 inline-flex min-h-11 items-center justify-center rounded-xl bg-[#001E4E] px-5 text-sm font-semibold text-white">
            Go to login
          </Link>
        ) : null}
      </section>
    </main>
  );
}

/* ------------------------------- date helpers ------------------------------ */

function startOfWeek(date: Date) {
  const result = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = (result.getDay() + 6) % 7; // Monday = 0
  result.setDate(result.getDate() - weekday);
  return result;
}

function addDays(date: Date, days: number) {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

function dayKey(date: Date) {
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}

function endOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59);
}

function isSameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function formatMonthDay(date: Date) {
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function shortWeekday(date: Date) {
  return new Intl.DateTimeFormat("en-US", { weekday: "short" }).format(date);
}

function formatTimeRange(start: Date, end: Date) {
  return `${formatTime(start)}-${formatTime(end)}`;
}

function formatTime(date: Date) {
  const formatted = new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit" }).format(date);
  return formatted.replace(/\s?(AM|PM)$/i, "");
}
