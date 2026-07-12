"use client";

import Link from "next/link";
import { onAuthStateChanged, signOut, type User } from "firebase/auth";
import { collection, getDocs, limit, query, Timestamp, where } from "firebase/firestore";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import {
  Bell,
  BookOpen,
  Briefcase,
  CalendarCheck,
  CalendarClock,
  CheckCircle2,
  ClipboardCheck,
  ClipboardList,
  Clock3,
  DollarSign,
  FileText,
  Grid3X3,
  GraduationCap,
  LayoutDashboard,
  LogOut,
  Menu,
  MessageSquare,
  Podcast,
  RotateCcw,
  Search,
  ShieldCheck,
  BarChart3,
  Star,
  TimerReset,
  Video,
  X,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher, rolesForUserRecord } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;

type TeacherShift = {
  id: string;
  title: string;
  studentNames: string[];
  start: Date | null;
  end: Date | null;
  status: string;
  isClockedIn: boolean;
};

type TeacherTask = {
  id: string;
  title: string;
  dueDate: Date | null;
  status: string;
};

type TeacherTimesheet = {
  id: string;
  date: Date | null;
  hours: number;
  pay: number;
  status: string;
};

type TeacherHomeData = {
  shifts: TeacherShift[];
  tasks: TeacherTask[];
  timesheets: TeacherTimesheet[];
  completedFormShiftIds: Set<string>;
};

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type SidebarItem = {
  label: string;
  icon: LucideIcon;
  href: string;
  color: string;
};

type SidebarSection = {
  title: string;
  items: SidebarItem[];
};

const teacherSections: SidebarSection[] = [
  {
    title: "Overview",
    items: [{ label: "Dashboard", icon: LayoutDashboard, href: "/teacher/", color: "#0386FF" }],
  },
  {
    title: "Work",
    items: [
      { label: "My Shifts", icon: Clock3, href: "/teacher/shifts/", color: "#10B981" },
      { label: "Time Clock", icon: TimerReset, href: "/teacher/time-clock/", color: "#EF4444" },
      { label: "Tasks", icon: CheckCircle2, href: "/teacher/tasks/", color: "#14B8A6" },
      { label: "Job Board", icon: Briefcase, href: "/teacher/job-board/", color: "#3B82F6" },
    ],
  },
  {
    title: "Communication",
    items: [
      { label: "Chat", icon: MessageSquare, href: "/teacher/chat/", color: "#A646F2" },
      { label: "Classes", icon: Video, href: "/teacher/classes/", color: "#2D8CFF" },
      { label: "Recordings", icon: Video, href: "/teacher/recordings/", color: "#0E72ED" },
      { label: "Surah Podcasts", icon: Podcast, href: "/teacher/surah-podcasts/", color: "#0E72ED" },
      { label: "Curriculum Books", icon: BookOpen, href: "/teacher/curriculum-books/", color: "#0F766E" },
    ],
  },
  {
    title: "Forms",
    items: [
      { label: "Submit Form", icon: FileText, href: "/teacher/submit-form/", color: "#EC4899" },
      { label: "My Form Submissions", icon: RotateCcw, href: "/teacher/form-submissions/", color: "#64748B" },
    ],
  },
  {
    title: "Reports",
    items: [{ label: "My Report", icon: BarChart3, href: "/teacher/report/", color: "#DC2626" }],
  },
];

const quickAccess = [
  { label: "Schedule", icon: CalendarClock, href: "/teacher/shifts/", color: "#0386FF" },
  { label: "Trading", icon: CheckCircle2, href: "/teacher/job-board/", color: "#10B981" },
  { label: "Forms", icon: FileText, href: "/teacher/submit-form/", color: "#F59E0B" },
  { label: "My Form Submissions", icon: RotateCcw, href: "/teacher/form-submissions/", color: "#64748B" },
  { label: "Assignments", icon: ClipboardList, href: "/teacher/tasks/", color: "#8B5CF6" },
];

const TEACHER_MOBILE_MENU_EVENT = "alluwal:open-teacher-mobile-menu";

export function openTeacherMobileMenu() {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new Event(TEACHER_MOBILE_MENU_EVENT));
}

export function TeacherDashboardHome() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [data, setData] = useState<TeacherHomeData>({ shifts: [], tasks: [], timesheets: [], completedFormShiftIds: new Set() });
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");

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
      setLoading(true);
      setLoadError("");
      try {
        const allowed = await isCurrentUserTeacher(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        const userRecord = await getCurrentUserRecord(nextUser);
        if (!mounted) return;
        setSummary(summaryForUser(nextUser, userRecord));
        setAccess("allowed");
        const loaded = await loadTeacherHomeData(nextUser.uid);
        if (mounted) {
          setData(loaded.data);
          setLoadError(homeLoadError(loaded.failed));
        }
      } catch {
        if (mounted) setAccess("denied");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  const retryLoad = async () => {
    if (!user || loading) return;
    setLoading(true);
    setLoadError("");
    try {
      const loaded = await loadTeacherHomeData(user.uid);
      setData(loaded.data);
      setLoadError(homeLoadError(loaded.failed));
    } finally {
      setLoading(false);
    }
  };

  return (
    <TeacherShell activeLabel="Dashboard" breadcrumb="Overview / Dashboard" summary={summary}>
      <TeacherHomeContent data={data} loading={loading} loadError={loadError} onRetry={() => void retryLoad()} summary={summary} user={user} />
    </TeacherShell>
  );
}

function TeacherHomeContent({
  data,
  loading,
  loadError,
  onRetry,
  summary,
}: {
  data: TeacherHomeData;
  loading: boolean;
  loadError: string;
  onRetry: () => void;
  summary: TeacherSummary;
  user: User | null;
}) {
  const [pendingFormsOpen, setPendingFormsOpen] = useState(false);
  const now = new Date();
  const weekStart = startOfWeek(now);
  const weekEnd = addDays(weekStart, 7);
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const nextClass = data.shifts
    .filter((shift) => shift.end && shift.end > now && !isClosedStatus(shift.status) && !shift.isClockedIn)
    .sort((a, b) => (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0))[0];
  const weekTimesheets = data.timesheets.filter((entry) => entry.date && entry.date >= weekStart && entry.date < weekEnd);
  const monthTimesheets = data.timesheets.filter((entry) => entry.date && entry.date >= monthStart);
  const completedThisWeek = data.shifts.filter((shift) => shift.start && shift.start >= weekStart && shift.start < weekEnd && isCompletedStatus(shift.status)).length;
  const weekHours = weekTimesheets.reduce((sum, entry) => sum + entry.hours, 0);
  const weekPay = weekTimesheets.reduce((sum, entry) => sum + entry.pay, 0);
  const monthPay = monthTimesheets.reduce((sum, entry) => sum + entry.pay, 0);
  const todayPay = data.timesheets.filter((entry) => isSameDay(entry.date, now)).reduce((sum, entry) => sum + entry.pay, 0);
  const monthAbsences = data.shifts.filter((shift) => shift.start && shift.start >= monthStart && isMissedStatus(shift.status)).length;
  const monthLate = data.timesheets.filter((entry) => entry.date && entry.date >= monthStart && entry.status.includes("late")).length;
  const openAssignments = data.tasks.filter((task) => task.status !== "done").length;
  const pendingFormShifts = data.shifts
    .filter((shift) => shift.end && shift.end < now && isFormRequiredStatus(shift.status) && !data.completedFormShiftIds.has(shift.id))
    .sort((a, b) => (b.start?.getTime() ?? 0) - (a.start?.getTime() ?? 0));

  return (
    <main className="min-h-[calc(100vh-56px)] overflow-y-auto bg-[#F5F5F5] px-5 pb-20 pt-0 text-[#111827] lg:px-5 lg:pb-8">
      <header className="lg:hidden">
        <div className="grid min-h-14 grid-cols-[44px_1fr_48px] items-center bg-white text-[#0F172A]">
          <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl">
            <Menu size={22} />
          </button>
          <div className="min-w-0 text-center text-base font-bold">Alluwal Academy</div>
          <span className="grid h-9 w-9 place-items-center rounded-full bg-[#009688] text-xs font-black text-white">{summary.initials}</span>
        </div>
      </header>

      {loadError ? (
        <section className="mt-4 flex flex-col gap-3 rounded-2xl border border-[#FCD34D] bg-[#FFFBEB] px-4 py-3 text-sm text-[#92400E] sm:flex-row sm:items-center" role="alert">
          <p className="min-w-0 flex-1 font-semibold">{loadError}</p>
          <button type="button" onClick={onRetry} disabled={loading} className="min-h-10 rounded-xl bg-[#92400E] px-4 text-xs font-bold text-white disabled:opacity-60">{loading ? "Retrying..." : "Try again"}</button>
        </section>
      ) : null}

      <section className="grid grid-cols-3 gap-2 pt-0 lg:gap-3 lg:pt-9">
        <MetricCard icon={Clock3} iconColor="#10B981" value={`${formatNumber(weekHours)}h`} label="This Week" loading={loading} />
        <MetricCard icon={GraduationCap} iconColor="#8B5CF6" value={String(completedThisWeek)} label="Completed" loading={loading} />
        <MetricCard icon={DollarSign} iconColor="#10B981" value={money(weekPay)} label="Earnings" loading={loading} />
        <MetricCard icon={CalendarCheck} iconColor="#EF4444" value={String(monthAbsences)} label="Absences (month)" loading={loading} />
        <MetricCard icon={ClipboardCheck} iconColor="#6366F1" value={String(openAssignments)} label="Assessments & assignments (month)" loading={loading} />
        <MetricCard icon={Clock3} iconColor="#F59E0B" value={String(monthLate)} label="Late clock-ins (month)" loading={loading} />
      </section>

      <section className="mt-2 grid grid-cols-3 overflow-hidden rounded-xl bg-[#0789F8] text-white shadow-[0_8px_18px_rgba(3,134,255,0.22)]">
        <EarningCell label="Today" value={money(todayPay)} />
        <EarningCell label="Week" value={money(weekPay)} />
        <EarningCell label="Month" value={money(monthPay)} />
      </section>

      {pendingFormShifts.length ? <button type="button" onClick={() => setPendingFormsOpen(true)} className="mt-4 flex min-h-20 w-full items-center gap-4 rounded-2xl bg-gradient-to-br from-[#F59E0B] to-[#EF4444] p-4 text-left text-white shadow-[0_8px_18px_rgba(245,158,11,0.28)]"><span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-white/20"><ClipboardList size={25} /></span><span className="min-w-0 flex-1"><span className="block font-extrabold">{pendingFormShifts.length} Readiness Form{pendingFormShifts.length === 1 ? "" : "s"} Required</span><span className="mt-1 block text-sm text-white/90">Complete a report for each completed or missed class.</span></span><span aria-hidden="true" className="text-2xl">›</span></button> : null}

      <section className="mt-5">
        <div className="mb-4 flex items-center justify-between">
          <h1 className="text-[21px] font-black text-[#111827]">Next Class</h1>
          <Link href="/teacher/shifts/" className="text-sm font-bold text-[#0386FF]">
            See All
          </Link>
        </div>
        {nextClass ? <NextClassCard shift={nextClass} /> : <EmptyNextClass />}
        <Link
          href="/teacher/shifts/"
          className="mt-4 inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-xl border border-[#0386FF] bg-white px-4 text-sm font-medium text-[#0369F6]"
        >
          <CalendarClock size={17} />
          View Full Schedule
        </Link>
      </section>

      <section className="mt-6">
        <div className="mb-4 flex items-center gap-3">
          <span className="grid h-10 w-10 place-items-center rounded-xl bg-[#DBEAFE] text-[#0386FF]">
            <Grid3X3 size={21} />
          </span>
          <h2 className="text-xl font-black text-[#1F2937]">Quick Access</h2>
        </div>
        <div className="grid grid-cols-4 gap-3 lg:grid-cols-5">
          {quickAccess.map((item) => (
            <QuickAccessCard key={item.label} item={item} />
          ))}
        </div>
      </section>
      {pendingFormsOpen ? <PendingFormsDialog shifts={pendingFormShifts} onClose={() => setPendingFormsOpen(false)} /> : null}
    </main>
  );
}

function PendingFormsDialog({ shifts, onClose }: { shifts: TeacherShift[]; onClose: () => void }) {
  return <section className="fixed inset-0 z-[90] grid items-end bg-black/45 sm:place-items-center" role="dialog" aria-modal="true" aria-label="Pending readiness forms"><div className="max-h-[78vh] w-full overflow-hidden rounded-t-3xl bg-white shadow-2xl sm:max-w-xl sm:rounded-3xl"><header className="flex items-center gap-3 border-b border-[#E2E8F0] p-5"><span className="grid h-11 w-11 place-items-center rounded-xl bg-amber-100 text-amber-600"><ClipboardList size={22} /></span><div className="min-w-0 flex-1"><h2 className="text-lg font-extrabold text-[#111827]">Pending Readiness Forms</h2><p className="text-sm text-[#64748B]">Select a class to complete its report.</p></div><button type="button" aria-label="Close pending forms" onClick={onClose} className="grid h-10 w-10 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]"><X size={20} /></button></header><div className="max-h-[calc(78vh-84px)] divide-y divide-[#E2E8F0] overflow-y-auto">{shifts.map((shift) => <div key={shift.id} className="flex flex-wrap items-center gap-3 p-5"><div className="min-w-0 flex-1"><p className="truncate font-bold text-[#334155]">{shift.title}</p><p className="mt-1 text-sm text-[#64748B]">{formatDateTimeRange(shift.start, shift.end)}</p><span className={`mt-2 inline-flex rounded-full px-2 py-1 text-xs font-bold ${isMissedStatus(shift.status) ? "bg-amber-100 text-amber-800" : "bg-emerald-100 text-emerald-800"}`}>{isMissedStatus(shift.status) ? "Missed" : "Completed"}</span></div><Link href={`/teacher/submit-form/?shift=${encodeURIComponent(shift.id)}`} className="inline-flex min-h-11 items-center justify-center rounded-xl bg-[#0386FF] px-4 text-sm font-bold text-white">Fill Form</Link></div>)}</div></div></section>;
}

export function TeacherShell({
  activeLabel,
  breadcrumb,
  summary,
  children,
}: {
  activeLabel: string;
  breadcrumb: string;
  summary: TeacherSummary;
  children: ReactNode;
}) {
  const [searchQuery, setSearchQuery] = useState("");
  const [collapsedSections, setCollapsedSections] = useState<Set<string>>(new Set());
  const [favoritedItems, setFavoritedItems] = useState<Set<string>>(new Set());
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [accountMenuOpen, setAccountMenuOpen] = useState(false);
  const [canSwitchToAdmin, setCanSwitchToAdmin] = useState(false);
  const normalizedSearch = searchQuery.trim().toLowerCase();
  const allSidebarItems = useMemo(() => teacherSections.flatMap((section) => section.items), []);
  const favoriteSidebarItems = allSidebarItems.filter((item) => favoritedItems.has(item.label));
  const visibleSidebarSections = useMemo(() => {
    if (!normalizedSearch) return teacherSections;
    return teacherSections
      .map((section) => {
        const titleMatches = section.title.toLowerCase().includes(normalizedSearch);
        const matchedItems = section.items.filter((item) => item.label.toLowerCase().includes(normalizedSearch));
        if (!titleMatches && matchedItems.length === 0) return null;
        return { ...section, items: titleMatches ? section.items : matchedItems };
      })
      .filter((section): section is SidebarSection => section !== null);
  }, [normalizedSearch]);

  function toggleSection(title: string) {
    setCollapsedSections((current) => {
      const next = new Set(current);
      if (next.has(title)) next.delete(title);
      else next.add(title);
      return next;
    });
  }

  function toggleFavoriteItem(label: string) {
    setFavoritedItems((current) => {
      const next = new Set(current);
      if (next.has(label)) next.delete(label);
      else next.add(label);
      return next;
    });
  }

  function resetSidebarLayout() {
    setSearchQuery("");
    setCollapsedSections(new Set());
    setFavoritedItems(new Set());
  }

  useEffect(() => {
    const openMenu = () => setMobileMenuOpen(true);
    window.addEventListener(TEACHER_MOBILE_MENU_EVENT, openMenu);
    return () => window.removeEventListener(TEACHER_MOBILE_MENU_EVENT, openMenu);
  }, []);

  useEffect(() => {
    try {
      const collapsed = JSON.parse(window.localStorage.getItem("teacher-sidebar-collapsed") || "[]");
      const favorites = JSON.parse(window.localStorage.getItem("teacher-sidebar-favorites") || "[]");
      if (Array.isArray(collapsed)) setCollapsedSections(new Set(collapsed.filter((item): item is string => typeof item === "string")));
      if (Array.isArray(favorites)) setFavoritedItems(new Set(favorites.filter((item): item is string => typeof item === "string")));
    } catch {}
    const user = auth.currentUser;
    if (user) {
      void getCurrentUserRecord(user).then((record) => {
        if (!record) return;
        const roles = rolesForUserRecord(record);
        setCanSwitchToAdmin(roles.has("admin") || roles.has("super_admin"));
      });
    }
  }, []);

  useEffect(() => {
    window.localStorage.setItem("teacher-sidebar-collapsed", JSON.stringify(Array.from(collapsedSections)));
  }, [collapsedSections]);

  useEffect(() => {
    window.localStorage.setItem("teacher-sidebar-favorites", JSON.stringify(Array.from(favoritedItems)));
  }, [favoritedItems]);

  const logout = async () => {
    await signOut(auth);
    window.location.assign("/login/");
  };

  return (
    <main className="h-screen overflow-hidden bg-[#F5F5F5] text-[#0F172A]">
      <div className="flex h-screen overflow-hidden">
        <aside className="hidden h-screen w-[260px] shrink-0 flex-col border-r border-[#D7DEE8] bg-white shadow-[4px_0_18px_rgba(15,23,42,0.04)] lg:flex">
          <div className="flex min-h-14 items-center justify-center border-b border-black/5 px-4">
            <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="Alluwal Education Hub" className="h-12 w-auto object-contain" />
          </div>
          <div className="flex items-center justify-between border-b border-black/10 px-4 py-3">
            <p className="text-[21px] font-black text-[#0F172A]">Menu</p>
            <span className="text-[#64748B]">‹</span>
          </div>
          <div className="px-3 py-3">
            <label className="sr-only" htmlFor="teacher-shell-search">
              Search dashboard
            </label>
            <div className="relative">
              <Search aria-hidden="true" className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={16} />
              <input
                id="teacher-shell-search"
                placeholder="Search..."
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                className="h-10 w-full rounded-xl border border-black/10 bg-white px-9 text-sm text-[#334155] outline-none focus:border-[#0386FF]"
              />
              {searchQuery.trim() ? (
                <button
                  type="button"
                  aria-label="Clear search"
                  onClick={() => setSearchQuery("")}
                  className="absolute right-2 top-1/2 grid h-7 w-7 -translate-y-1/2 place-items-center rounded-lg text-[#94A3B8] hover:bg-black/5 hover:text-[#334155]"
                >
                  <X size={15} />
                </button>
              ) : null}
            </div>
          </div>
          <nav className="flex-1 overflow-y-auto px-3 pb-4" aria-label="Teacher dashboard navigation">
            {favoriteSidebarItems.length > 0 ? (
              <SidebarFavorites
                items={favoriteSidebarItems}
                favoritedItems={favoritedItems}
                activeLabel={activeLabel}
                onToggleFavorite={toggleFavoriteItem}
              />
            ) : null}
            {visibleSidebarSections.map((section) => {
              const isCollapsed = !normalizedSearch && collapsedSections.has(section.title);
              return (
                <div key={section.title} className="mb-3">
                  <button
                    type="button"
                    onClick={() => toggleSection(section.title)}
                    className="flex min-h-9 w-full items-center gap-2 rounded-xl px-2 text-left text-[10px] font-black uppercase tracking-[0.14em] text-[#94A3B8] hover:bg-[#F8FAFC]"
                    aria-expanded={!isCollapsed}
                    aria-label={`${isCollapsed ? "Expand" : "Collapse"} ${section.title}`}
                  >
                    <Grid3X3 size={14} />
                    <span className="min-w-0 flex-1 truncate">{section.title}</span>
                    <span>{isCollapsed ? "⌄" : "⌃"}</span>
                  </button>
                  {!isCollapsed ? (
                    <SidebarItems
                      items={section.items}
                      favoritedItems={favoritedItems}
                      activeLabel={activeLabel}
                      onToggleFavorite={toggleFavoriteItem}
                    />
                  ) : null}
                </div>
              );
            })}
          </nav>
          <div className="border-t border-black/10 bg-[#F8FAFC] px-3 py-3">
            <button
              type="button"
              onClick={resetSidebarLayout}
              className="inline-flex min-h-10 items-center gap-2 rounded-xl px-3 text-xs font-bold text-[#94A3B8] hover:bg-white hover:text-[#334155]"
            >
              <RotateCcw size={15} />
              Reset Layout
            </button>
          </div>
        </aside>

        <section className="flex h-screen min-w-0 flex-1 flex-col overflow-hidden">
          <header className="hidden min-h-14 shrink-0 items-center justify-between border-b border-black/5 bg-white px-4 lg:flex">
            <p className="text-sm font-bold text-[#64748B]">{breadcrumb}</p>
            <div className="flex items-center gap-3">
              <span className="inline-flex min-h-9 items-center rounded-full bg-[#0386FF] px-4 text-xs font-black text-white">Teacher</span>
              <Bell size={20} className="text-[#64748B]" />
              <div className="relative">
                <button type="button" aria-label="Open teacher account menu" aria-expanded={accountMenuOpen} onClick={() => setAccountMenuOpen((current) => !current)} className="flex min-h-11 items-center gap-3 rounded-xl px-2 hover:bg-[#F8FAFC]">
                  <span className="max-w-[240px] truncate text-sm font-semibold text-[#2563EB]">{summary.displayName}</span>
                  <span className="grid h-10 w-10 place-items-center rounded-full bg-[#009688] text-sm font-black text-white">{summary.initials}</span>
                </button>
                {accountMenuOpen ? (
                  <div className="absolute right-0 top-12 z-50 w-56 rounded-2xl border border-[#E2E8F0] bg-white p-2 shadow-xl" role="menu" aria-label="Teacher account menu">
                    {canSwitchToAdmin ? <Link href="/admin/" role="menuitem" className="flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-bold text-[#334155] hover:bg-[#F1F5F9]"><ShieldCheck size={18} />Switch to Admin</Link> : null}
                    <button type="button" role="menuitem" onClick={() => void logout()} className="flex min-h-11 w-full items-center gap-3 rounded-xl px-3 text-left text-sm font-bold text-[#DC2626] hover:bg-[#FEF2F2]"><LogOut size={18} />Log out</button>
                  </div>
                ) : null}
              </div>
            </div>
          </header>
          <div className="min-h-0 flex-1 overflow-y-auto" aria-label="Teacher page content">{children}</div>
        </section>
      </div>
      {mobileMenuOpen ? (
        <TeacherMobileMenu
          activeLabel={activeLabel}
          summary={summary}
          canSwitchToAdmin={canSwitchToAdmin}
          onLogout={() => void logout()}
          onClose={() => setMobileMenuOpen(false)}
        />
      ) : null}
    </main>
  );
}

function TeacherMobileMenu({
  activeLabel,
  summary,
  canSwitchToAdmin,
  onLogout,
  onClose,
}: {
  activeLabel: string;
  summary: TeacherSummary;
  canSwitchToAdmin: boolean;
  onLogout: () => void;
  onClose: () => void;
}) {
  return (
    <section className="fixed inset-0 z-[80] lg:hidden" aria-label="Teacher mobile menu">
      <button type="button" aria-label="Close teacher menu backdrop" onClick={onClose} className="absolute inset-0 bg-black/40" />
      <aside className="absolute inset-y-0 left-0 flex w-[310px] max-w-[86vw] flex-col bg-white shadow-2xl">
        <div className="flex min-h-16 items-center gap-3 border-b border-black/10 px-4">
          <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="Alluwal Education Hub" className="h-11 w-auto object-contain" />
          <button type="button" aria-label="Close teacher menu" onClick={onClose} className="ml-auto grid h-10 w-10 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
            <X size={20} />
          </button>
        </div>
        <div className="flex items-center gap-3 border-b border-black/10 px-4 py-3">
          <span className="grid h-10 w-10 place-items-center rounded-full bg-[#009688] text-sm font-black text-white">{summary.initials}</span>
          <div className="min-w-0">
            <p className="truncate text-sm font-black text-[#0F172A]">{summary.displayName}</p>
            <p className="text-xs font-bold text-[#64748B]">Teacher</p>
          </div>
        </div>
        <nav className="flex-1 overflow-y-auto px-3 py-4" aria-label="Teacher mobile navigation">
          {teacherSections.map((section) => (
            <div key={section.title} className="mb-5">
              <p className="mb-2 flex items-center gap-2 px-2 text-[10px] font-black uppercase tracking-[0.14em] text-[#94A3B8]">
                <Grid3X3 size={14} />
                {section.title}
              </p>
              <div className="grid gap-1">
                {section.items.map((item) => {
                  const Icon = item.icon;
                  const isActive = item.label === activeLabel;
                  return (
                    <Link
                      key={item.label}
                      href={item.href}
                      onClick={onClose}
                      className={`flex min-h-12 items-center gap-3 rounded-2xl px-3 text-sm font-bold ${
                        isActive ? "bg-[#E6EEF8] text-[#001E4E]" : "text-[#334155] hover:bg-[#F1F4F8]"
                      }`}
                    >
                      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-[#F8FAFC]">
                        <Icon size={19} style={{ color: item.color }} />
                      </span>
                      <span className="min-w-0 flex-1 truncate">{item.label}</span>
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>
        <div className="border-t border-black/10 p-3">
          {canSwitchToAdmin ? <Link href="/admin/" onClick={onClose} className="flex min-h-12 items-center gap-3 rounded-xl px-3 text-sm font-bold text-[#334155] hover:bg-[#F1F5F9]"><ShieldCheck size={19} />Switch to Admin</Link> : null}
          <button type="button" onClick={onLogout} className="flex min-h-12 w-full items-center gap-3 rounded-xl px-3 text-left text-sm font-bold text-[#DC2626] hover:bg-[#FEF2F2]"><LogOut size={19} />Log out</button>
        </div>
      </aside>
    </section>
  );
}

function MetricCard({
  icon: Icon,
  iconColor,
  value,
  label,
  loading,
}: {
  icon: LucideIcon;
  iconColor: string;
  value: string;
  label: string;
  loading: boolean;
}) {
  return (
    <div className="grid min-h-[72px] place-items-center rounded-lg bg-white px-1 py-2 shadow-sm lg:px-3 lg:py-3">
      <Icon size={17} style={{ color: iconColor }} />
      <div className="text-center">
        <p className="text-base font-black text-[#111827]">{loading ? "..." : value}</p>
        <p className="max-w-full truncate text-[10px] font-medium text-[#64748B] lg:text-[11px]">{label}</p>
      </div>
    </div>
  );
}

function EarningCell({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid min-h-[52px] place-items-center border-r border-white/20 px-2 py-2 last:border-r-0">
      <div className="text-center">
        <p className="text-sm font-black">{value}</p>
        <p className="mt-0.5 text-[10px] font-bold">{label}</p>
      </div>
    </div>
  );
}

function EmptyNextClass() {
  return (
    <div className="grid min-h-[192px] w-full max-w-[240px] place-items-center rounded-xl border border-[#E2E8F0] bg-white px-5 text-center shadow-sm lg:min-h-[192px]">
      <div>
        <span className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-[#F1F5F9] text-[#94A3B8]">
          <CalendarCheck size={32} />
        </span>
        <h2 className="mt-5 text-lg font-black text-[#64748B]">No Upcoming Classes</h2>
        <p className="mt-2 text-sm font-medium text-[#94A3B8]">Enjoy your free time!</p>
      </div>
    </div>
  );
}

function NextClassCard({ shift }: { shift: TeacherShift }) {
  return (
    <div className="w-full max-w-[420px] rounded-xl border border-[#BFDBFE] bg-white p-5 shadow-sm">
      <p className="text-xs font-bold uppercase tracking-[0.08em] text-[#0386FF]">Upcoming class</p>
      <h2 className="mt-2 text-lg font-black text-[#111827]">{shift.title}</h2>
      <p className="mt-2 text-sm font-semibold text-[#64748B]">{shift.studentNames.join(", ") || "Students"}</p>
      <p className="mt-3 text-sm font-medium text-[#334155]">{formatDateTimeRange(shift.start, shift.end)}</p>
    </div>
  );
}

function QuickAccessCard({ item }: { item: { label: string; icon: LucideIcon; href: string; color: string } }) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      className="grid min-h-[78px] place-items-center rounded-xl border border-[#E2E8F0] bg-white px-1 py-3 text-center shadow-sm lg:min-h-[270px] lg:px-2"
    >
      <span className="grid h-11 w-11 place-items-center rounded-full bg-[#F1F5F9]" style={{ color: item.color }}>
        <Icon size={22} />
      </span>
      <span className="mt-2 max-w-full truncate text-[11px] font-semibold text-[#475569] lg:text-xs">{item.label}</span>
    </Link>
  );
}

function SidebarFavorites({
  items,
  favoritedItems,
  activeLabel,
  onToggleFavorite,
}: {
  items: SidebarItem[];
  favoritedItems: Set<string>;
  activeLabel: string;
  onToggleFavorite: (label: string) => void;
}) {
  return (
    <div aria-label="Pinned dashboard items" className="mb-3 rounded-2xl border border-black/10 bg-[#F8FAFC] p-3">
      <div className="mb-2 flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.14em] text-[#64748B]">
        <Star size={14} className="fill-[#F59E0B] text-[#F59E0B]" />
        Favorites
      </div>
      <SidebarItems items={items} favoritedItems={favoritedItems} activeLabel={activeLabel} onToggleFavorite={onToggleFavorite} />
    </div>
  );
}

function SidebarItems({
  items,
  favoritedItems,
  activeLabel,
  onToggleFavorite,
}: {
  items: SidebarItem[];
  favoritedItems: Set<string>;
  activeLabel: string;
  onToggleFavorite: (label: string) => void;
}) {
  return (
    <div className="grid gap-1">
      {items.map((item) => {
        const Icon = item.icon;
        const isActive = item.label === activeLabel;
        return (
          <div key={item.label} className="flex min-h-10 items-center gap-2">
            <Link
              href={item.href}
              className={`flex min-w-0 flex-1 items-center gap-3 rounded-2xl px-3 text-sm font-bold ${
                isActive ? "bg-[#E6EEF8] text-[#001E4E]" : "text-[#334155] hover:bg-[#F1F4F8]"
              }`}
            >
              <span className="grid h-8 w-8 shrink-0 place-items-center rounded-xl bg-[#F8FAFC]">
                <Icon size={18} style={{ color: item.color }} />
              </span>
              <span className="min-w-0 flex-1 truncate">{item.label}</span>
            </Link>
            <button
              type="button"
              aria-label={`${favoritedItems.has(item.label) ? "Unpin" : "Pin"} ${item.label}`}
              onClick={() => onToggleFavorite(item.label)}
              className="grid h-8 w-8 shrink-0 place-items-center rounded-xl text-[#94A3B8] hover:bg-[#F8FAFC] hover:text-[#F59E0B]"
            >
              <Star size={17} className={favoritedItems.has(item.label) ? "fill-[#F59E0B] text-[#F59E0B]" : ""} />
            </button>
          </div>
        );
      })}
    </div>
  );
}

export function TeacherAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F5F8FB] px-4 py-10 text-[#0F172A]">
      <section className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 text-center shadow-sm">
        <div className="mx-auto grid h-12 w-12 place-items-center rounded-2xl bg-[#E6F3FF] text-[#0386FF]">
          <LayoutDashboard size={24} />
        </div>
        <h1 className="mt-4 text-2xl font-black">{checking ? "Checking teacher access" : access === "signedOut" ? "Teacher sign-in required" : "Teacher access required"}</h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {checking ? "Please wait while we verify your account." : "Sign in with a teacher account to open the teacher dashboard."}
        </p>
        {!checking ? (
          <Link href="/login/" className="mt-5 inline-flex min-h-11 items-center justify-center rounded-xl bg-[#0386FF] px-5 text-sm font-bold text-white">
            Go to login
          </Link>
        ) : null}
      </section>
    </main>
  );
}

async function loadTeacherHomeData(uid: string): Promise<{data: TeacherHomeData; failed: string[]}> {
  const results = await Promise.allSettled([loadTeacherShifts(uid), loadTeacherTasks(uid), loadTeacherTimesheets(uid), loadTeacherFormShiftIds(uid)]);
  const labels = ["class schedule", "tasks", "timesheets", "form status"];
  return {
    data: {
      shifts: results[0].status === "fulfilled" ? results[0].value : [],
      tasks: results[1].status === "fulfilled" ? results[1].value : [],
      timesheets: results[2].status === "fulfilled" ? results[2].value : [],
      completedFormShiftIds: results[3].status === "fulfilled" ? results[3].value : new Set(),
    },
    failed: results.flatMap((result, index) => result.status === "rejected" ? [labels[index]] : []),
  };
}

async function loadTeacherFormShiftIds(uid: string) {
  const snapshots = await Promise.all(["userId", "submittedBy", "submitted_by"].map((field) => getDocs(query(collection(db, "form_responses"), where(field, "==", uid), limit(200))).catch(() => null)));
  const ids = new Set<string>();
  snapshots.flatMap((snapshot) => snapshot?.docs ?? []).forEach((entry) => {
    const data = entry.data() as Record<string, unknown>;
    const shiftId = stringValue(data.shiftId ?? data.shift_id ?? data.linked_shift_id);
    if (shiftId) ids.add(shiftId);
  });
  return ids;
}

function homeLoadError(failed: string[]) {
  if (!failed.length) return "";
  return `Some dashboard data could not be refreshed: ${failed.join(", ")}. Existing values for those sections may be incomplete.`;
}

async function loadTeacherShifts(uid: string) {
  const snapshots = await Promise.all(["teacher_id", "teacherId"].map((field) => getDocs(query(collection(db, "teaching_shifts"), where(field, "==", uid), limit(500))).catch(() => null)));
  const byId = new Map<string, TeacherShift>();
  snapshots.flatMap((snapshot) => snapshot?.docs ?? []).forEach((entry) => byId.set(entry.id, normalizeShift(entry.id, entry.data() as Record<string, unknown>)));
  return Array.from(byId.values());
}

async function loadTeacherTasks(uid: string) {
  const byAssignee = await getDocs(query(collection(db, "tasks"), where("assignedTo", "array-contains", uid), limit(50)));
  return byAssignee.docs.map((entry) => normalizeTask(entry.id, entry.data() as Record<string, unknown>));
}

async function loadTeacherTimesheets(uid: string) {
  const snap = await getDocs(query(collection(db, "timesheet_entries"), where("teacher_id", "==", uid), limit(100)));
  return snap.docs.map((entry) => normalizeTimesheet(entry.id, entry.data() as Record<string, unknown>));
}

function normalizeShift(id: string, data: Record<string, unknown>): TeacherShift {
  const studentNames = arrayOfStrings(data.student_names ?? data.studentNames);
  const title =
    stringValue(data.custom_name ?? data.customName) ||
    stringValue(data.auto_generated_name ?? data.autoGeneratedName) ||
    stringValue(data.subject_display_name ?? data.subjectDisplayName ?? data.subject) ||
    "Teaching Shift";
  return {
    id,
    title,
    studentNames,
    start: dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime),
    end: dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime),
    status: stringValue(data.status) || "scheduled",
    isClockedIn: data.is_clocked_in === true || data.isClockedIn === true,
  };
}

function normalizeTask(id: string, data: Record<string, unknown>): TeacherTask {
  return {
    id,
    title: stringValue(data.title) || "Untitled Task",
    dueDate: dateValue(data.dueDate ?? data.due_date),
    status: stringValue(data.status).replace("TaskStatus.", "") || "todo",
  };
}

function normalizeTimesheet(id: string, data: Record<string, unknown>): TeacherTimesheet {
  const date = dateValue(data.clock_in_timestamp ?? data.clockInTimestamp ?? data.created_at ?? data.createdAt ?? data.date);
  const hours = numberValue(data.total_hours ?? data.totalHours ?? data.hours, 0);
  const pay = numberValue(data.payment_amount ?? data.paymentAmount ?? data.total_pay ?? data.totalPay, hours * numberValue(data.hourly_rate ?? data.hourlyRate, 0));
  return {
    id,
    date,
    hours,
    pay,
    status: stringValue(data.status).toLowerCase(),
  };
}

function summaryForUser(user: User, data: UserRecord | null): TeacherSummary {
  const displayName =
    data
      ? [stringValue(data.first_name ?? data["first-name"]), stringValue(data.last_name ?? data["last-name"])].filter(Boolean).join(" ")
      : "";
  const fallback = user.displayName?.trim() || user.email?.replace(/@.*/, "") || "Teacher";
  const name = displayName || fallback;
  return {
    displayName: name,
    firstName: name.split(/\s+/)[0] || "Teacher",
    initials: initialsFromName(name),
  };
}

function arrayOfStrings(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => stringValue(item)).filter(Boolean);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown, fallback: number) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() && !Number.isNaN(Number(value))) return Number(value);
  return fallback;
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

function isCompletedStatus(status: string) {
  return ["completed", "fullycompleted", "fully_completed", "partiallycompleted", "partially_completed"].includes(status.toLowerCase().replace(/\s+/g, ""));
}

function isMissedStatus(status: string) {
  return ["missed", "no_show", "noshow"].includes(status.toLowerCase().replace(/\s+/g, ""));
}

function isFormRequiredStatus(status: string) { return isCompletedStatus(status) || isMissedStatus(status); }

function formatNumber(value: number) {
  return value.toFixed(1).replace(/\\.0$/, ".0");
}

function money(value: number) {
  return `$${value.toFixed(2)}`;
}

function formatDateTimeRange(start: Date | null, end: Date | null) {
  if (!start && !end) return "Schedule pending";
  const day = start?.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }) ?? "Date pending";
  const startTime = start?.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" }) ?? "-";
  const endTime = end?.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" }) ?? "-";
  return `${day} · ${startTime}-${endTime}`;
}

function initialsFromName(name: string) {
  const parts = name.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "TE";
}
