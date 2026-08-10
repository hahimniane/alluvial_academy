"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, query, Timestamp } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  CalendarClock,
  CalendarDays,
  CheckSquare,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Grid3X3,
  List,
  Lock,
  Plus,
  RefreshCw,
  Search,
  Settings,
  SlidersHorizontal,
  UserMinus,
  UserRound,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type ShiftTab = "all" | "today" | "upcoming" | "active";
type ViewMode = "grid" | "list";
type StaffGroup = "teacher" | "leader";

type StaffUser = {
  id: string;
  displayName: string;
  email: string;
  initials: string;
  group: StaffGroup;
};

type ShiftRecord = {
  id: string;
  teacherId: string;
  teacherName: string;
  studentNames: string[];
  title: string;
  start: Date | null;
  end: Date | null;
  status: string;
  category: string;
};

type GridRow = { kind: "section"; id: string; label: string } | { kind: "user"; user: StaffUser };

const tabs: { id: ShiftTab; label: string }[] = [
  { id: "all", label: "All Shifts" },
  { id: "today", label: "Today" },
  { id: "upcoming", label: "Upcoming" },
  { id: "active", label: "Active" },
];

export function ShiftsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [shifts, setShifts] = useState<ShiftRecord[]>([]);
  const [staff, setStaff] = useState<StaffUser[]>([]);
  const [activeTab, setActiveTab] = useState<ShiftTab>("all");
  const [viewMode, setViewMode] = useState<ViewMode>("grid");
  const [search, setSearch] = useState("");
  const [teacherSearch, setTeacherSearch] = useState("");
  const [weekStart, setWeekStart] = useState(() => startOfWeek(new Date()));
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      setMessage("");
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserAdmin(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        setAccess("allowed");
        const [loadedShifts, loadedStaff] = await Promise.all([loadShifts(), loadStaff()]);
        if (!mounted) return;
        setShifts(loadedShifts);
        setStaff(mergeShiftTeachers(loadedStaff, loadedShifts));
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load shifts.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const counts = useMemo(() => {
    const now = new Date();
    return {
      all: shifts.length,
      today: shifts.filter((shift) => isSameDay(shift.start, now)).length,
      upcoming: shifts.filter((shift) => shift.start && shift.start > now && !isClosedStatus(shift.status)).length,
      active: shifts.filter((shift) => shift.status.toLowerCase() === "active").length,
    };
  }, [shifts]);

  const visibleShifts = useMemo(() => {
    const now = new Date();
    return shifts.filter((shift) => {
      if (activeTab === "today" && !isSameDay(shift.start, now)) return false;
      if (activeTab === "upcoming" && (!shift.start || shift.start <= now || isClosedStatus(shift.status))) return false;
      if (activeTab === "active" && shift.status.toLowerCase() !== "active") return false;
      return matchesShiftSearch(shift, search);
    });
  }, [activeTab, search, shifts]);

  const filteredStaff = useMemo(() => {
    const term = teacherSearch.trim().toLowerCase();
    const namesFromShifts = new Set(visibleShifts.map((shift) => shift.teacherId || shift.teacherName).filter(Boolean));
    return staff.filter((staffUser) => {
      const matchesTeacherSearch =
        !term || staffUser.displayName.toLowerCase().includes(term) || staffUser.email.toLowerCase().includes(term);
      if (!matchesTeacherSearch) return false;
      if (search.trim()) return namesFromShifts.has(staffUser.id) || namesFromShifts.has(staffUser.displayName);
      return true;
    });
  }, [search, staff, teacherSearch, visibleShifts]);

  const weekDays = useMemo(() => Array.from({ length: 7 }, (_, index) => addDays(weekStart, index)), [weekStart]);
  const weekEnd = addDays(weekStart, 6);

  if (access !== "allowed") {
    return <ShiftsAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Shifts" breadcrumb="Operations / Shifts">
      <main className="min-h-[calc(100vh-56px)] overflow-hidden bg-[#F8FAFC] text-[#111827]">
        <header className="lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center bg-white px-3">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <span className="h-0.5 w-4 bg-current" />
              <span className="-mt-5 h-0.5 w-4 bg-current" />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Education Hub</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">
              {initialsFor(user)}
            </span>
          </div>
        </header>

        <section className="border-b border-[#E2E8F0] bg-white px-3 py-3 lg:px-4">
          <div className="flex flex-wrap items-center gap-3">
            <div className="grid h-11 w-11 place-items-center rounded-xl bg-[#E6F3FF] text-[#0386FF]">
              <Clock3 size={22} />
            </div>
            <h1 className="min-w-[190px] flex-1 text-xl font-bold text-[#111827]">Shift Management</h1>
            <Link href="/app/#/login" className="inline-flex min-h-11 items-center gap-2 rounded-full bg-[#0386FF] px-5 text-sm font-bold text-white">
              <Plus size={18} />
              Create Shift
            </Link>
            <button
              type="button"
              aria-label="Shift settings"
              onClick={() => setMessage("Shift settings are still available in the Flutter bridge while this module is migrated.")}
              className="grid h-11 w-11 place-items-center rounded-xl border border-[#CBD5E1] bg-white text-[#64748B]"
            >
              <Settings size={20} />
            </button>
            <button
              type="button"
              onClick={() => setMessage("Bulk selection is available in the Flutter bridge while native editing is migrated.")}
              className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-white px-3 text-sm font-semibold text-[#0386FF]"
            >
              <CheckSquare size={18} />
              Select
            </button>
            <label className="relative block h-11 w-full max-w-[240px]">
              <input
                value={teacherSearch}
                onChange={(event) => setTeacherSearch(event.target.value)}
                placeholder={`Search Teacher (${staff.length})`}
                aria-label="Search teacher"
                className="h-full w-full rounded-xl border border-[#CBD5E1] bg-white px-4 pr-10 text-sm outline-none focus:border-[#0386FF]"
              />
              <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-[#64748B]" size={18} />
            </label>
            <button
              type="button"
              onClick={() => setMessage("Teacher shift deletion stays in the Flutter bridge until native edit/delete flows are migrated.")}
              className="hidden min-h-11 items-center gap-2 rounded-full bg-[#E5E7EB] px-4 text-sm font-semibold text-[#9CA3AF] lg:inline-flex"
            >
              <UserMinus size={18} />
              Delete Teacher Shifts
            </button>
            <button type="button" aria-label="Refresh shifts" onClick={() => window.location.reload()} className="grid h-11 w-11 place-items-center rounded-xl text-[#64748B]">
              <RefreshCw size={20} />
            </button>
          </div>
        </section>

        <section className="overflow-x-auto border-b border-[#E2E8F0] bg-[#F8FAFC] px-4 py-2">
          <div className="flex min-w-max items-center gap-2">
            <StatChip label="Total" value={counts.all} icon={CalendarClock} color="#0386FF" />
            <StatChip label="Active" value={counts.active} icon={Clock3} color="#10B981" />
            <StatChip label="Today" value={counts.today} icon={CalendarDays} color="#F59E0B" />
            <StatChip label="Upcoming" value={counts.upcoming} icon={Users} color="#8B5CF6" />
          </div>
        </section>

        {message ? (
          <div className="mx-3 mt-3 rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-4 py-3 text-sm font-semibold text-[#1D4ED8] lg:mx-4">
            {message}
          </div>
        ) : null}

        <section className="m-3 overflow-hidden rounded-xl border border-[#E2E8F0] bg-white shadow-sm lg:m-4">
          <div className="flex flex-wrap items-center gap-3 border-b border-[#E2E8F0] px-3 pt-3">
            <div className="flex min-w-0 flex-1 items-center gap-6 overflow-x-auto">
              {tabs.map((tab) => (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setActiveTab(tab.id)}
                  className={`min-h-11 shrink-0 border-b-4 px-2 text-sm font-semibold ${
                    activeTab === tab.id ? "border-[#0386FF] text-[#0386FF]" : "border-transparent text-[#64748B]"
                  }`}
                >
                  {tab.label} ({counts[tab.id]})
                </button>
              ))}
            </div>
            <div className="flex rounded-xl bg-[#F3F4F6] p-1">
              <ViewToggleButton icon={Grid3X3} label="Grid" selected={viewMode === "grid"} onClick={() => setViewMode("grid")} />
              <ViewToggleButton icon={List} label="List" selected={viewMode === "list"} onClick={() => setViewMode("list")} />
            </div>
          </div>

          <div className="flex items-center gap-3 border-b border-[#E2E8F0] px-3 py-3">
            <label className="relative block h-10 min-w-0 flex-1">
              <Search aria-hidden="true" className="absolute left-3 top-1/2 -translate-y-1/2 text-[#64748B]" size={18} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search Users Or Shifts"
                aria-label="Search users or shifts"
                className="h-full w-full rounded-lg border border-[#CBD5E1] bg-white pl-10 pr-3 text-sm outline-none focus:border-[#0386FF]"
              />
            </label>
            <button type="button" aria-label="Filter shifts" className="grid h-10 w-10 place-items-center rounded-lg text-[#64748B]">
              <SlidersHorizontal size={18} />
            </button>
          </div>

          {viewMode === "grid" ? (
            <>
              <div className="flex items-center gap-2 border-b border-[#E2E8F0] bg-[#F8FAFC] px-3 py-2 text-sm font-semibold text-[#0386FF]">
                <CalendarDays size={17} />
                <button type="button" onClick={() => setWeekStart(addDays(weekStart, -7))}>
                  Previous Week
                </button>
                <button type="button" aria-label="Previous week" onClick={() => setWeekStart(addDays(weekStart, -7))} className="grid h-8 w-8 place-items-center">
                  <ChevronLeft size={20} />
                </button>
                <div className="min-w-[150px] flex-1 text-center text-sm font-bold text-[#374151]">
                  {formatDayRange(weekStart, weekEnd)}
                </div>
                <button type="button" aria-label="Next week" onClick={() => setWeekStart(addDays(weekStart, 7))} className="grid h-8 w-8 place-items-center">
                  <ChevronRight size={20} />
                </button>
                <button type="button" onClick={() => setWeekStart(addDays(weekStart, 7))}>
                  Next Week
                </button>
              </div>
              {loading ? (
                <LoadingPanel />
              ) : (
                <WeeklyGrid weekDays={weekDays} staff={filteredStaff} shifts={visibleShifts} />
              )}
            </>
          ) : loading ? (
            <LoadingPanel />
          ) : (
            <ShiftList shifts={visibleShifts} />
          )}
        </section>
      </main>
    </AdminDashboardShell>
  );
}

function WeeklyGrid({ weekDays, staff, shifts }: { weekDays: Date[]; staff: StaffUser[]; shifts: ShiftRecord[] }) {
  const rows = groupedRows(staff);
  return (
    <div className="overflow-auto">
      <div className="min-w-[1040px]">
        <div className="grid grid-cols-[180px_repeat(7,minmax(120px,1fr))] border-b border-[#E2E8F0] bg-[#F8FAFC] text-center text-xs text-[#64748B]">
          <div className="flex h-14 items-center justify-center border-r border-[#E2E8F0] font-semibold">
            Teachers
            <span className="ml-1 text-[#94A3B8]">({staff.length})</span>
          </div>
          {weekDays.map((day) => (
            <div key={day.toISOString()} className={`flex h-14 flex-col items-center justify-center border-r border-[#E2E8F0] ${isSameDay(day, new Date()) ? "bg-[#EAF5FF]" : ""}`}>
              <span className="font-bold text-[#374151]">{shortWeekday(day)}</span>
              <span>{formatMonthDay(day)}</span>
              <span className="mt-0.5 text-[10px] text-[#94A3B8]">0.0 | 0</span>
            </div>
          ))}
        </div>
        {rows.length === 0 ? (
          <div className="grid min-h-[360px] place-items-center text-sm font-semibold text-[#64748B]">No teachers or shifts found</div>
        ) : (
          rows.map((row) =>
            row.kind === "section" ? (
              <div key={row.id} className="flex h-9 items-center gap-2 border-b border-[#E2E8F0] bg-[#F3F4F6] px-4 text-xs font-bold uppercase tracking-[0.02em] text-[#64748B]">
                <UserRound size={14} />
                {row.label}
              </div>
            ) : (
              <div key={row.user.id} className="grid min-h-20 grid-cols-[180px_repeat(7,minmax(120px,1fr))] border-b border-[#E2E8F0]">
                <button type="button" className="flex items-center gap-3 border-r border-[#E2E8F0] bg-white px-3 text-left">
                  <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-[#DBEAFE] text-xs font-bold text-[#0386FF]">{row.user.initials}</span>
                  <span className="min-w-0">
                    <span className="block truncate text-sm font-semibold text-[#374151]">{row.user.displayName}</span>
                    <span className="block text-[11px] text-[#94A3B8]">0.0 | 0</span>
                  </span>
                </button>
                {weekDays.map((day) => (
                  <div key={`${row.user.id}-${day.toISOString()}`} className="min-h-20 border-r border-[#E2E8F0] bg-white p-1.5">
                    {shiftsForCell(shifts, row.user, day).map((shift) => (
                      <ShiftBlock key={shift.id} shift={shift} />
                    ))}
                  </div>
                ))}
              </div>
            ),
          )
        )}
      </div>
    </div>
  );
}

function ShiftBlock({ shift }: { shift: ShiftRecord }) {
  return (
    <article className="mb-1 rounded-lg border border-[#BFDBFE] bg-[#EFF6FF] px-2 py-1.5 text-xs text-[#1E3A8A]">
      <div className="truncate font-bold">{shift.title}</div>
      <div className="truncate text-[#2563EB]">{shift.studentNames.join(", ") || shift.teacherName}</div>
      <div className="mt-1 flex items-center justify-between gap-2 text-[11px]">
        <span>{formatTimeRange(shift.start, shift.end)}</span>
        <span className="rounded-full bg-white px-1.5 py-0.5 font-semibold capitalize text-[#1D4ED8]">{shift.status || "scheduled"}</span>
      </div>
    </article>
  );
}

function ShiftList({ shifts }: { shifts: ShiftRecord[] }) {
  if (shifts.length === 0) {
    return <div className="grid min-h-[360px] place-items-center text-sm font-semibold text-[#64748B]">No shifts found</div>;
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
          {shifts.map((shift) => (
            <tr key={shift.id} className="border-b border-[#E2E8F0]">
              <td className="truncate px-4 py-3 font-semibold">{shift.title}</td>
              <td className="truncate px-4 py-3">{shift.teacherName}</td>
              <td className="truncate px-4 py-3">{shift.studentNames.join(", ")}</td>
              <td className="px-4 py-3">{shift.start ? formatMonthDay(shift.start) : "-"}</td>
              <td className="px-4 py-3">{formatTimeRange(shift.start, shift.end)}</td>
              <td className="px-4 py-3">
                <span className="rounded-full bg-[#EFF6FF] px-2 py-1 text-xs font-bold capitalize text-[#1D4ED8]">{shift.status || "scheduled"}</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function StatChip({ label, value, icon: Icon, color }: { label: string; value: number; icon: LucideIcon; color: string }) {
  return (
    <div className="inline-flex min-h-8 items-center gap-2 rounded-full border px-3 text-xs font-semibold" style={{ borderColor: `${color}33`, backgroundColor: `${color}14`, color }}>
      <Icon size={16} />
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
      className={`inline-flex min-h-9 items-center gap-1.5 rounded-lg px-3 text-sm font-bold ${selected ? "bg-[#0386FF] text-white" : "text-[#64748B]"}`}
    >
      <Icon size={16} />
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

async function loadShifts() {
  const snap = await getDocs(query(collection(db, "teaching_shifts"), limit(500)));
  const cutoffStart = addDays(new Date(), -90);
  const cutoffEnd = addDays(new Date(), 121);
  return snap.docs
    .map((docSnap) => normalizeShift(docSnap.id, docSnap.data() as Record<string, unknown>))
    .filter((shift) => !shift.start || (shift.start >= cutoffStart && shift.start <= cutoffEnd))
    .sort((a, b) => (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0));
}

async function loadStaff() {
  const snap = await getDocs(query(collection(db, "users"), limit(500)));
  return snap.docs
    .map((docSnap) => normalizeStaffUser(docSnap.id, docSnap.data() as Record<string, unknown>))
    .filter((staffUser): staffUser is StaffUser => staffUser !== null)
    .sort((a, b) => a.displayName.localeCompare(b.displayName));
}

function normalizeShift(id: string, data: Record<string, unknown>): ShiftRecord {
  const teacherId = stringValue(data.teacher_id ?? data.teacherId);
  const teacherName = stringValue(data.teacher_name ?? data.teacherName) || "Unassigned";
  const studentNames = arrayOfStrings(data.student_names ?? data.studentNames);
  const subjectValue = data.subject_display_name ?? data.subjectDisplayName ?? data.subject;
  const title =
    stringValue(data.custom_name ?? data.customName) ||
    stringValue(data.auto_generated_name ?? data.autoGeneratedName) ||
    stringValue(subjectValue) ||
    "Teaching Shift";
  return {
    id,
    teacherId,
    teacherName,
    studentNames,
    title,
    start: dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime),
    end: dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime),
    status: stringValue(data.status) || "scheduled",
    category: stringValue(data.category) || "teaching",
  };
}

function normalizeStaffUser(id: string, data: Record<string, unknown>): StaffUser | null {
  const userType = stringValue(data.user_type ?? data.userType).toLowerCase();
  const isAdminTeacher = data.is_admin_teacher === true || data.isAdminTeacher === true;
  const secondaryRoles = arrayOfStrings(data.secondary_roles ?? data.secondaryRoles).map((role) => role.toLowerCase());
  const isTeacher = userType === "teacher";
  const isLeader = userType === "admin" || userType === "super_admin" || isAdminTeacher || secondaryRoles.includes("admin");
  if (!isTeacher && !isLeader) return null;
  const firstName = stringValue(data.first_name ?? data.firstName);
  const lastName = stringValue(data.last_name ?? data.lastName);
  const email = stringValue(data["e-mail"] ?? data.email);
  const displayName = [firstName, lastName].filter(Boolean).join(" ") || email || id;
  return {
    id,
    displayName,
    email,
    initials: initialsFromName(displayName),
    group: isLeader ? "leader" : "teacher",
  };
}

function mergeShiftTeachers(staff: StaffUser[], shifts: ShiftRecord[]) {
  const byId = new Map(staff.map((staffUser) => [staffUser.id, staffUser]));
  for (const shift of shifts) {
    const key = shift.teacherId || shift.teacherName;
    if (!key || byId.has(key)) continue;
    byId.set(key, {
      id: key,
      displayName: shift.teacherName || "Unassigned",
      email: "",
      initials: initialsFromName(shift.teacherName || "Unassigned"),
      group: shift.category === "teaching" ? "teacher" : "leader",
    });
  }
  return Array.from(byId.values()).sort((a, b) => a.displayName.localeCompare(b.displayName));
}

function groupedRows(staff: StaffUser[]): GridRow[] {
  const teachers = staff.filter((user) => user.group === "teacher");
  const leaders = staff.filter((user) => user.group === "leader");
  const rows: GridRow[] = [];
  if (teachers.length) {
    rows.push({ kind: "section", id: "teachers", label: `Teachers (${teachers.length})` });
    rows.push(...teachers.map((user) => ({ kind: "user" as const, user })));
  }
  if (leaders.length) {
    rows.push({ kind: "section", id: "leaders", label: `Leaders (${leaders.length})` });
    rows.push(...leaders.map((user) => ({ kind: "user" as const, user })));
  }
  return rows;
}

function shiftsForCell(shifts: ShiftRecord[], staffUser: StaffUser, day: Date) {
  return shifts.filter((shift) => {
    const sameTeacher = shift.teacherId === staffUser.id || (!shift.teacherId && shift.teacherName === staffUser.displayName);
    return sameTeacher && isSameDay(shift.start, day);
  });
}

function matchesShiftSearch(shift: ShiftRecord, search: string) {
  const term = search.trim().toLowerCase();
  if (!term) return true;
  return [shift.title, shift.teacherName, shift.status, shift.category, ...shift.studentNames].some((value) => value.toLowerCase().includes(term));
}

function arrayOfStrings(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => stringValue(item)).filter(Boolean);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    const parsed = value.toDate();
    return parsed instanceof Date && !Number.isNaN(parsed.getTime()) ? parsed : null;
  }
  return null;
}

function startOfWeek(date: Date) {
  const normalized = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const offset = normalized.getDay() === 0 ? 6 : normalized.getDay() - 1;
  normalized.setDate(normalized.getDate() - offset);
  return normalized;
}

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function isSameDay(value: Date | null, day: Date) {
  return Boolean(value && value.getFullYear() === day.getFullYear() && value.getMonth() === day.getMonth() && value.getDate() === day.getDate());
}

function isClosedStatus(status: string) {
  return ["cancelled", "completed", "fullycompleted", "fully_completed", "missed"].includes(status.toLowerCase().replace(/\s+/g, ""));
}

function formatMonthDay(date: Date) {
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function shortWeekday(date: Date) {
  return date.toLocaleDateString("en-US", { weekday: "short" });
}

function formatDayRange(start: Date, end: Date) {
  return `${shortWeekday(start)} ${formatMonthDay(start)} -> ${shortWeekday(end)} ${formatMonthDay(end)}`;
}

function formatTimeRange(start: Date | null, end: Date | null) {
  if (!start && !end) return "-";
  const startText = start ? formatTime(start) : "-";
  const endText = end ? formatTime(end) : "-";
  return `${startText} - ${endText}`;
}

function formatTime(date: Date) {
  return date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Admin";
  return initialsFromName(source.replace(/@.*/, ""));
}

function initialsFromName(name: string) {
  const parts = name.split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}
