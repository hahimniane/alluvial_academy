"use client";

import Link from "next/link";
import { onAuthStateChanged, signOut, type User } from "firebase/auth";
import { collection, getDocs, limit, orderBy, query, Timestamp, where } from "firebase/firestore";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import {
  Bell,
  BookOpen,
  CalendarClock,
  ChevronDown,
  ChevronLeft,
  CheckCircle2,
  CircleUserRound,
  ClipboardList,
  CreditCard,
  Grid3X3,
  LayoutDashboard,
  Loader2,
  LogOut,
  Menu,
  MessageSquare,
  MonitorPlay,
  Podcast,
  ReceiptText,
  RotateCcw,
  Search,
  Star,
  TrendingUp,
  UserRound,
  Video,
  X,
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { cachedStudentSession, clearStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { ConfirmDialog, type ConfirmRequest } from "@/components/ConfirmDialog";

type UserRecord = Record<string, unknown>;
type AccessState = "checking" | "signedOut" | "allowed" | "denied";

type StudentSummary = {
  displayName: string;
  firstName: string;
  initials: string;
  photoUrl?: string;
};

type SidebarItem = {
  label: string;
  icon: typeof LayoutDashboard;
  href: string;
  color: string;
};

type SidebarSection = {
  title: string;
  items: SidebarItem[];
};


/**
 * Mirrors _getStudentStructure in lib/features/dashboard/config/sidebar_config.dart
 * — same sections, same order, same labels, same accent colours. Circles is
 * omitted because SidebarConfig.showCircles is false, so no student sees it.
 */
function studentSections(isAdultStudent: boolean): SidebarSection[] {
  return [
    {
      title: "Overview",
      items: [{ label: "Dashboard", icon: LayoutDashboard, href: "/student/", color: "#0386FF" }],
    },
    // Adult students pay their own tuition and so get the Finance section a
    // parent would. Minors never see it.
    ...(isAdultStudent
      ? [
          {
            title: "Finance",
            items: [
              { label: "Invoices", icon: ReceiptText, href: "/student/invoices/", color: "#10B981" },
              { label: "Payments", icon: CreditCard, href: "/student/payments/", color: "#059669" },
            ],
          },
        ]
      : []),
    {
      title: "Learning",
      items: [
        { label: "Classes", icon: Video, href: "/student/classes/", color: "#2D8CFF" },
        { label: "Recordings", icon: MonitorPlay, href: "/student/recordings/", color: "#0E72ED" },
        { label: "Tasks", icon: CheckCircle2, href: "/student/tasks/", color: "#14B8A6" },
        { label: "Quiz", icon: ClipboardList, href: "/student/quiz/", color: "#8B5CF6" },
        { label: "Progress", icon: TrendingUp, href: "/student/progress/", color: "#2563EB" },
        { label: "Surah Podcasts", icon: Podcast, href: "/student/surah-podcasts/", color: "#0E72ED" },
        { label: "Curriculum Books", icon: BookOpen, href: "/student/curriculum-books/", color: "#0F766E" },
      ],
    },
    {
      title: "Communication",
      items: [{ label: "Chat", icon: MessageSquare, href: "/student/chat/", color: "#A646F2" }],
    },
  ];
}

const STUDENT_MOBILE_MENU_EVENT = "alluwal:open-student-mobile-menu";

/**
 * The signed-in student's avatar: their photo once one exists, initials until
 * then. Every header and menu renders through this so a photo uploaded on the
 * profile page replaces the initials everywhere at once.
 */
export function StudentAvatar({ summary, size = 40, textClass = "text-sm" }: { summary: StudentSummary; size?: number; textClass?: string }) {
  if (summary.photoUrl) {
    return (
      <img
        src={summary.photoUrl}
        alt=""
        style={{ width: size, height: size }}
        className="shrink-0 rounded-full object-cover"
      />
    );
  }
  return (
    <span
      style={{ width: size, height: size }}
      className={`grid shrink-0 place-items-center rounded-full bg-[#009688] font-black text-white ${textClass}`}
    >
      {summary.initials}
    </span>
  );
}

export function openStudentMobileMenu() {
  window.dispatchEvent(new CustomEvent(STUDENT_MOBILE_MENU_EVENT));
}

type StudentClass = {
  id: string;
  name: string;
  teacherName: string;
  start: Date | null;
  end: Date | null;
};

type StudentTask = {
  id: string;
  title: string;
  due: Date | null;
  done: boolean;
};

type HomeData = {
  todayClasses: StudentClass[];
  upcomingClasses: StudentClass[];
  tasks: StudentTask[];
  attendedCount: number;
  totalPastClasses: number;
};

const EMPTY_DATA: HomeData = {
  todayClasses: [],
  upcomingClasses: [],
  tasks: [],
  attendedCount: 0,
  totalPastClasses: 0,
};

export default function StudentDashboardHome() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [data, setData] = useState<HomeData>(EMPTY_DATA);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }
      const session = await resolveStudentSession(nextUser);
      if (!session.isStudent) {
        setAccess("denied");
        setLoading(false);
        return;
      }
      setSummary(session.summary);
      setIsAdultStudent(session.isAdultStudent);
      setAccess("allowed");
      await loadHomeData(nextUser.uid);
    });
  }, []);

  async function loadHomeData(uid: string) {
    setLoading(true);
    setLoadError("");
    try {
      setData(await fetchHomeData(uid));
    } catch (error) {
      setLoadError(error instanceof Error ? error.message : "Could not load your dashboard.");
    } finally {
      setLoading(false);
    }
  }

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  return (
    <StudentShell activeLabel="Dashboard" breadcrumb="Overview / Dashboard" summary={summary} isAdultStudent={isAdultStudent}>
      <StudentHomeContent
        data={data}
        loading={loading}
        loadError={loadError}
        summary={summary}
        onRetry={() => void loadHomeData(auth.currentUser?.uid ?? "")}
      />
    </StudentShell>
  );
}

/**
 * Every figure here comes from Firestore. The Flutter home this replaces showed
 * hardcoded placeholders ("Math Homework", "Mathematics 85%") that were
 * identical for every student — see _buildStudentDashboard in
 * lib/features/dashboard/screens/admin_dashboard_screen.dart.
 */
async function fetchHomeData(uid: string): Promise<HomeData> {
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);
  const horizon = new Date(startOfDay.getTime() + 30 * 24 * 60 * 60 * 1000);
  const attendanceWindowStart = new Date(startOfDay.getTime() - 90 * 24 * 60 * 60 * 1000);

  // Same shape as ShiftService.getTodayShiftsForStudent / getUpcomingShiftsForStudent.
  const [upcomingSnap, pastSnap, tasksSnap] = await Promise.all([
    getDocs(
      query(
        collection(db, "teaching_shifts"),
        where("student_ids", "array-contains", uid),
        where("shift_start", ">=", Timestamp.fromDate(startOfDay)),
        where("shift_start", "<", Timestamp.fromDate(horizon)),
        orderBy("shift_start"),
        limit(100),
      ),
    ),
    // Attendance is measured over the last 90 days, ascending. A descending
    // order here would need a composite index that does not exist
    // (firestore.indexes.json only has student_ids CONTAINS + shift_start ASC),
    // and the window keeps the figure meaningful for long-standing students
    // rather than skewed by their very first term.
    getDocs(
      query(
        collection(db, "teaching_shifts"),
        where("student_ids", "array-contains", uid),
        where("shift_start", ">=", Timestamp.fromDate(attendanceWindowStart)),
        where("shift_start", "<", Timestamp.fromDate(startOfDay)),
        orderBy("shift_start"),
        limit(300),
      ),
    ),
    getDocs(query(collection(db, "tasks"), where("assignedTo", "array-contains", uid), limit(100))),
  ]);

  const upcoming = upcomingSnap.docs
    .map((entry) => normalizeClass(entry.id, entry.data() as UserRecord))
    .filter((item) => item.start !== null);

  const todayClasses = upcoming.filter((item) => item.start! >= startOfDay && item.start! < endOfDay);
  const upcomingClasses = upcoming.filter((item) => item.start! >= endOfDay);

  const pastClasses = pastSnap.docs.map((entry) => entry.data() as UserRecord).filter(countsTowardAttendance);
  const attendedCount = pastClasses.filter(attendedByStudent).length;

  const tasks = tasksSnap.docs
    .map((entry) => normalizeTask(entry.id, entry.data() as UserRecord))
    .sort((a, b) => (a.due?.getTime() ?? Infinity) - (b.due?.getTime() ?? Infinity));

  return {
    todayClasses,
    upcomingClasses,
    tasks,
    attendedCount,
    totalPastClasses: pastClasses.length,
  };
}

/**
 * Attendance comes from the shift's own status. There is no per-student
 * attendance map on teaching_shifts — the values in production are
 * fullyCompleted, partiallyCompleted, missed and scheduled. The richer
 * per-minute overview the Flutter app shows is produced by the
 * getAdminStudentAttendanceOverview callable, which is admin-only and so is not
 * available to a signed-in student.
 *
 * Shifts with no status (or still scheduled) are excluded from both sides of
 * the ratio rather than counted as absences.
 */
const ATTENDED_STATUSES = new Set(["fullycompleted", "partiallycompleted"]);
const COUNTED_STATUSES = new Set(["fullycompleted", "partiallycompleted", "missed"]);

function shiftStatus(shift: UserRecord) {
  return stringValue(shift.status).toLowerCase();
}

function countsTowardAttendance(shift: UserRecord) {
  return COUNTED_STATUSES.has(shiftStatus(shift));
}

function attendedByStudent(shift: UserRecord) {
  return ATTENDED_STATUSES.has(shiftStatus(shift));
}

function normalizeClass(id: string, data: UserRecord): StudentClass {
  return {
    id,
    name: stringValue(data.display_name) || stringValue(data.subject) || stringValue(data.shift_name) || "Class",
    teacherName: stringValue(data.teacher_name) || "Your teacher",
    start: toDate(data.shift_start),
    end: toDate(data.shift_end),
  };
}

function normalizeTask(id: string, data: UserRecord): StudentTask {
  const status = stringValue(data.status).toLowerCase();
  return {
    id,
    title: stringValue(data.title) || stringValue(data.name) || "Task",
    due: toDate(data.dueDate ?? data.due_date),
    done: status === "done" || status === "completed" || data.completed === true,
  };
}

function toDate(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function StudentHomeContent({
  data,
  loading,
  loadError,
  summary,
  onRetry,
}: {
  data: HomeData;
  loading: boolean;
  loadError: string;
  summary: StudentSummary;
  onRetry: () => void;
}) {
  const pendingTasks = data.tasks.filter((task) => !task.done);
  const completedTasks = data.tasks.filter((task) => task.done);
  const attendanceRate = data.totalPastClasses > 0 ? Math.round((data.attendedCount / data.totalPastClasses) * 100) : null;

  if (loading) {
    return (
      <div className="grid min-h-[60vh] place-items-center text-[#64748B]">
        <span className="inline-flex items-center gap-2 text-sm font-bold">
          <Loader2 className="animate-spin" size={18} />
          Loading your dashboard…
        </span>
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[1180px] px-4 py-6 md:px-6">
      {/* Gradient, copy and avatar block mirror the Flutter student header —
          the gradient is the same [#43e97b → #38f9d7] pair _getRoleGradient
          returns for the student role. */}
      <header className="flex items-center gap-4 rounded-3xl bg-[linear-gradient(120deg,#43e97b_0%,#38f9d7_100%)] p-6 text-white shadow-[0_18px_40px_rgba(67,233,123,0.22)] md:p-8">
        <div className="min-w-0 flex-1">
          <h1 className="text-[28px] font-black leading-tight md:text-[40px]">Welcome Back, {summary.firstName}</h1>
          <p className="mt-2 text-base font-semibold text-white/95 md:text-lg">You&rsquo;re signed in as Student</p>
          <p className="mt-3 text-base font-medium text-white/90 md:text-lg">Continue your learning journey and track your progress.</p>
        </div>
        <span className="hidden h-24 w-24 shrink-0 place-items-center rounded-3xl bg-white/25 text-white sm:grid">
          <UserRound size={52} />
        </span>
      </header>

      {loadError ? (
        <div className="mt-4 flex flex-wrap items-center gap-3 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-bold text-red-700">
          {loadError}
          <button type="button" onClick={onRetry} className="inline-flex min-h-9 items-center rounded-xl bg-red-600 px-3 text-xs font-black text-white">
            Try again
          </button>
        </div>
      ) : null}

      <div className="mt-5 grid gap-4 sm:grid-cols-3">
        <StatCard label="Classes today" value={data.todayClasses.length} icon={CalendarClock} color="#2D8CFF" />
        <StatCard label="Tasks completed" value={completedTasks.length} icon={CheckCircle2} color="#10B981" />
        <StatCard label="Tasks pending" value={pendingTasks.length} icon={ClipboardList} color="#F59E0B" />
      </div>

      <div className="mt-5 grid gap-4 lg:grid-cols-2">
        <Panel title="My tasks" href="/student/tasks/" linkLabel="View all">
          {pendingTasks.length === 0 ? (
            <EmptyRow text="Nothing due right now. Enjoy it." />
          ) : (
            <ul className="grid gap-2">
              {pendingTasks.slice(0, 4).map((task) => (
                <li key={task.id} className="flex items-center gap-3 rounded-xl border border-black/5 bg-[#F8FAFC] px-3 py-2.5">
                  <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-white text-[#14B8A6]">
                    <ClipboardList size={16} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-bold text-[#0F172A]">{task.title}</span>
                    <span className="block text-xs font-semibold text-[#64748B]">{task.due ? `Due ${formatDay(task.due)}` : "No due date"}</span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Panel>

        <Panel title="My progress" href="/student/progress/" linkLabel="Details">
          {attendanceRate === null ? (
            <EmptyRow text="Your progress appears once you've attended a class." />
          ) : (
            <div>
              <div className="flex items-baseline gap-2">
                <span className="text-[34px] font-black leading-none text-[#0F172A]">{attendanceRate}%</span>
                <span className="text-sm font-bold text-[#64748B]">attendance</span>
              </div>
              <div className="mt-3 h-2.5 overflow-hidden rounded-full bg-[#E2E8F0]">
                <div className="h-full rounded-full bg-[linear-gradient(90deg,#2563EB,#38f9d7)]" style={{ width: `${attendanceRate}%` }} />
              </div>
              <p className="mt-2 text-xs font-semibold text-[#64748B]">
                {data.attendedCount} of {data.totalPastClasses} classes attended (last 90 days)
              </p>
            </div>
          )}
        </Panel>
      </div>

      <div className="mt-5">
        <Panel title="Upcoming classes" href="/student/classes/" linkLabel="Open classes">
          {data.todayClasses.length === 0 && data.upcomingClasses.length === 0 ? (
            <EmptyRow text="No classes scheduled in the next 30 days." />
          ) : (
            <ul className="grid gap-2">
              {[...data.todayClasses, ...data.upcomingClasses].slice(0, 6).map((item) => (
                <li key={item.id} className="flex items-center gap-3 rounded-xl border border-black/5 bg-[#F8FAFC] px-3 py-2.5">
                  <span className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-white text-[#2D8CFF]">
                    <Video size={17} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-bold text-[#0F172A]">{item.name}</span>
                    <span className="block truncate text-xs font-semibold text-[#64748B]">{item.teacherName}</span>
                  </span>
                  <span className="shrink-0 text-right text-xs font-bold text-[#334155]">
                    {item.start ? formatDay(item.start) : "—"}
                    <span className="block font-semibold text-[#94A3B8]">{item.start ? formatTime(item.start) : ""}</span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Panel>
      </div>
    </div>
  );
}

/** Centred icon tile, large figure, label underneath — the Flutter stat card. */
function StatCard({ label, value, icon: Icon, color }: { label: string; value: number; icon: typeof LayoutDashboard; color: string }) {
  return (
    <div className="grid place-items-center rounded-3xl border border-black/5 bg-white px-4 py-7 text-center shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
      <span className="grid h-14 w-14 place-items-center rounded-2xl" style={{ backgroundColor: `${color}1f`, color }}>
        <Icon size={28} />
      </span>
      <div className="mt-4 text-[40px] font-black leading-none text-[#0F172A]">{value}</div>
      <div className="mt-2 text-sm font-bold text-[#64748B]">{label}</div>
    </div>
  );
}

function Panel({ title, href, linkLabel, children }: { title: string; href: string; linkLabel: string; children: ReactNode }) {
  return (
    <section className="rounded-2xl border border-black/5 bg-white p-4 shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
      <div className="mb-3 flex items-center justify-between gap-3">
        <h2 className="text-sm font-black text-[#0F172A]">{title}</h2>
        <Link href={href} className="text-xs font-bold text-[#2563EB] hover:underline">
          {linkLabel}
        </Link>
      </div>
      {children}
    </section>
  );
}

function EmptyRow({ text }: { text: string }) {
  return <p className="rounded-xl border border-dashed border-[#CBD5E1] px-3 py-4 text-center text-xs font-semibold text-[#94A3B8]">{text}</p>;
}

function formatDay(value: Date) {
  const today = new Date();
  const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const days = Math.round((new Date(value.getFullYear(), value.getMonth(), value.getDate()).getTime() - startOfToday.getTime()) / 86400000);
  if (days === 0) return "Today";
  if (days === 1) return "Tomorrow";
  return value.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function formatTime(value: Date) {
  return value.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
}

export function StudentShell({
  activeLabel,
  breadcrumb,
  summary,
  isAdultStudent,
  children,
}: {
  activeLabel: string;
  breadcrumb: string;
  summary: StudentSummary;
  isAdultStudent: boolean;
  children: ReactNode;
}) {
  const [searchQuery, setSearchQuery] = useState("");
  const [collapsedSections, setCollapsedSections] = useState<Set<string>>(new Set());
  const [favoritedItems, setFavoritedItems] = useState<Set<string>>(new Set());
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [accountMenuOpen, setAccountMenuOpen] = useState(false);
  const [notificationCount, setNotificationCount] = useState(0);
  const [confirm, setConfirm] = useState<ConfirmRequest | null>(null);
  // Icon-rail collapse, the way desktop dashboards behave. Persisted so the
  // choice survives navigation and reload, and mirrored from the Flutter
  // sidebar which stores the same preference.
  const [railCollapsed, setRailCollapsed] = useState(false);
  const normalizedSearch = searchQuery.trim().toLowerCase();

  const availableSidebarSections = useMemo(() => studentSections(isAdultStudent), [isAdultStudent]);
  const allSidebarItems = useMemo(() => availableSidebarSections.flatMap((section) => section.items), [availableSidebarSections]);
  const favoriteSidebarItems = allSidebarItems.filter((item) => favoritedItems.has(item.label));
  const visibleSidebarSections = useMemo(() => {
    if (!normalizedSearch) return availableSidebarSections;
    return availableSidebarSections
      .map((section) => {
        const titleMatches = section.title.toLowerCase().includes(normalizedSearch);
        const matchedItems = section.items.filter((item) => item.label.toLowerCase().includes(normalizedSearch));
        if (!titleMatches && matchedItems.length === 0) return null;
        return { ...section, items: titleMatches ? section.items : matchedItems };
      })
      .filter((section): section is SidebarSection => section !== null);
  }, [availableSidebarSections, normalizedSearch]);

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
    window.addEventListener(STUDENT_MOBILE_MENU_EVENT, openMenu);
    return () => window.removeEventListener(STUDENT_MOBILE_MENU_EVENT, openMenu);
  }, []);

  useEffect(() => {
    try {
      const collapsed = JSON.parse(window.localStorage.getItem("student-sidebar-collapsed") || "[]");
      const favorites = JSON.parse(window.localStorage.getItem("student-sidebar-favorites") || "[]");
      if (Array.isArray(collapsed)) setCollapsedSections(new Set(collapsed.filter((item): item is string => typeof item === "string")));
      if (Array.isArray(favorites)) setFavoritedItems(new Set(favorites.filter((item): item is string => typeof item === "string")));
    } catch {}
  }, []);

  useEffect(() => {
    window.localStorage.setItem("student-sidebar-collapsed", JSON.stringify(Array.from(collapsedSections)));
  }, [collapsedSections]);

  useEffect(() => {
    setRailCollapsed(window.localStorage.getItem("student-sidebar-rail") === "collapsed");
  }, []);

  useEffect(() => {
    window.localStorage.setItem("student-sidebar-rail", railCollapsed ? "collapsed" : "expanded");
  }, [railCollapsed]);

  // Cmd/Ctrl+B is the convention for toggling a dashboard sidebar.
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "b") {
        event.preventDefault();
        setRailCollapsed((current) => !current);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    window.localStorage.setItem("student-sidebar-favorites", JSON.stringify(Array.from(favoritedItems)));
  }, [favoritedItems]);

  const logout = async () => {
    // Drop the cached session so the next account cannot inherit this one.
    clearStudentSession();
    await signOut(auth);
    window.location.assign("/student/login/");
  };

  return (
    <main className="h-screen overflow-hidden bg-[#F5F5F5] text-[#0F172A]">
      <div className="flex h-screen overflow-hidden">
        <aside
          className={`hidden h-screen shrink-0 flex-col border-r border-[#D7DEE8] bg-white shadow-[4px_0_18px_rgba(15,23,42,0.04)] transition-[width] duration-200 ease-out lg:flex ${
            railCollapsed ? "w-[76px]" : "w-[260px]"
          }`}
        >
          <div className="flex min-h-14 items-center justify-center border-b border-black/5 px-4">
            <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="Alluwal Education Hub" className="h-12 w-auto object-contain" />
          </div>
          <div className={`flex items-center border-b border-black/10 py-3 ${railCollapsed ? "justify-center px-2" : "justify-between px-4"}`}>
            {railCollapsed ? null : <p className="text-[21px] font-black text-[#0F172A]">Menu</p>}
            <button
              type="button"
              onClick={() => setRailCollapsed((current) => !current)}
              aria-label={railCollapsed ? "Expand sidebar" : "Collapse sidebar"}
              aria-expanded={!railCollapsed}
              title={`${railCollapsed ? "Expand" : "Collapse"} sidebar (⌘B)`}
              className="grid h-9 w-9 place-items-center rounded-xl text-[#64748B] transition hover:bg-[#F1F5F9] hover:text-[#334155]"
            >
              <ChevronLeft size={18} className={`transition-transform duration-200 ${railCollapsed ? "rotate-180" : ""}`} />
            </button>
          </div>
          <div className={railCollapsed ? "hidden" : "px-3 py-3"}>
            <label className="sr-only" htmlFor="student-shell-search">
              Search dashboard
            </label>
            <div className="relative">
              <Search aria-hidden="true" className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={16} />
              <input
                id="student-shell-search"
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
          <nav className="flex-1 overflow-y-auto px-3 pb-4" aria-label="Student dashboard navigation">
            {favoriteSidebarItems.length > 0 && !railCollapsed ? (
              <StudentSidebarFavorites items={favoriteSidebarItems} favoritedItems={favoritedItems} activeLabel={activeLabel} onToggleFavorite={toggleFavoriteItem} />
            ) : null}
            {visibleSidebarSections.map((section) => {
              const isCollapsed = !normalizedSearch && collapsedSections.has(section.title);
              return (
                <div key={section.title} className="mb-3">
                  {railCollapsed ? (
                    <div className="mx-auto mb-2 h-px w-8 bg-[#E2E8F0]" aria-hidden="true" />
                  ) : null}
                  <button
                    type="button"
                    hidden={railCollapsed}
                    onClick={() => toggleSection(section.title)}
                    className="flex min-h-9 w-full items-center gap-2 rounded-xl px-2 text-left text-[10px] font-black uppercase tracking-[0.14em] text-[#94A3B8] hover:bg-[#F8FAFC]"
                    aria-expanded={!isCollapsed}
                    aria-label={`${isCollapsed ? "Expand" : "Collapse"} ${section.title}`}
                  >
                    <Grid3X3 size={14} />
                    <span className="min-w-0 flex-1 truncate">{section.title}</span>
                    <span>{isCollapsed ? "⌄" : "⌃"}</span>
                  </button>
                  {!isCollapsed || railCollapsed ? (
                    <StudentSidebarItems collapsed={railCollapsed} items={section.items} favoritedItems={favoritedItems} activeLabel={activeLabel} onToggleFavorite={toggleFavoriteItem} />
                  ) : null}
                </div>
              );
            })}
          </nav>
          <div className="border-t border-black/10 bg-[#F8FAFC] px-3 py-3">
            <button
              type="button"
              onClick={resetSidebarLayout}
              title="Reset Layout"
              className={`inline-flex min-h-10 items-center gap-2 rounded-xl text-xs font-bold text-[#94A3B8] hover:bg-white hover:text-[#334155] ${
                railCollapsed ? "w-full justify-center px-0" : "px-3"
              }`}
            >
              <RotateCcw size={15} />
              {railCollapsed ? null : "Reset Layout"}
            </button>
          </div>
        </aside>

        <section className="flex h-screen min-w-0 flex-1 flex-col overflow-hidden">
          {/* Below lg the sidebar and desktop header are gone, so this bar is
              the only navigation on a phone: hamburger for the drawer, the
              current page, and the account avatar. It lives in the shell so no
              page can ship without it again. */}
          <header className="flex min-h-14 shrink-0 items-center gap-2 border-b border-black/5 bg-white px-3 lg:hidden">
            <button
              type="button"
              aria-label="Open menu"
              onClick={() => setMobileMenuOpen(true)}
              className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]"
            >
              <Menu size={24} />
            </button>
            <span className="min-w-0 flex-1 truncate text-center text-base font-black text-[#0F172A]">{activeLabel}</span>
            <Link href="/student/profile/" aria-label="Open your profile">
              <StudentAvatar summary={summary} size={36} textClass="text-xs" />
            </Link>
          </header>
          <header className="hidden min-h-14 shrink-0 items-center justify-between border-b border-black/5 bg-white px-4 lg:flex">
            <p className="text-sm font-bold text-[#64748B]">{breadcrumb}</p>
            <div className="flex items-center gap-3">
              {/* Role pill, bell and name-with-chip mirror the Flutter top bar.
                  Green is the student role colour (_getRoleColor). */}
              <span className="inline-flex min-h-10 items-center gap-2 rounded-full bg-[#10B981] px-5 text-sm font-black text-white">
                <UserRound size={18} />
                Student
              </span>
              {/* Not a link: there is no student notifications page yet, and
                  sending it to /app/ would drop the student into the Flutter
                  dashboard. Kept for visual parity with the app's header. */}
              <span
                aria-label={notificationCount ? `${notificationCount} unread notification${notificationCount === 1 ? "" : "s"}` : "Notifications"}
                className="relative grid h-11 w-11 place-items-center rounded-xl text-[#64748B]"
              >
                <Bell size={22} />
                {notificationCount ? (
                  <span className="absolute right-1 top-1 grid min-h-4 min-w-4 place-items-center rounded-full bg-red-500 px-1 text-[9px] font-black text-white">
                    {notificationCount > 99 ? "99+" : notificationCount}
                  </span>
                ) : null}
              </span>
              <div className="relative">
                <button
                  type="button"
                  aria-label="Open student account menu"
                  aria-expanded={accountMenuOpen}
                  onClick={() => setAccountMenuOpen((current) => !current)}
                  className="flex min-h-11 items-center gap-3 rounded-xl px-2 hover:bg-[#F8FAFC]"
                >
                  <span className="grid max-w-[240px] justify-items-end">
                    <span className="w-full truncate text-right text-sm font-bold text-[#2563EB]">{summary.displayName}</span>
                    <span className="mt-0.5 inline-flex items-center rounded-md bg-[#D1FAE5] px-2 py-0.5 text-[10px] font-black uppercase tracking-wide text-[#047857]">
                      Student
                    </span>
                  </span>
                  <StudentAvatar summary={summary} size={44} />
                  <ChevronDown size={18} className="text-[#64748B]" />
                </button>
                {accountMenuOpen ? (
                  <div className="absolute right-0 top-12 z-50 w-56 rounded-2xl border border-[#E2E8F0] bg-white p-2 shadow-xl" role="menu" aria-label="Student account menu">
                    <Link href="/student/profile/" role="menuitem" className="flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-bold text-[#334155] hover:bg-[#F1F5F9]">
                      <CircleUserRound size={18} />
                      View Profile
                    </Link>
                    <button
                      type="button"
                      role="menuitem"
                      onClick={() =>
                        setConfirm({
                          title: "Sign Out",
                          body: "Are you sure you want to sign out?",
                          confirmLabel: "Sign Out",
                          onConfirm: () => void logout(),
                        })
                      }
                      className="flex min-h-11 w-full items-center gap-3 rounded-xl px-3 text-left text-sm font-bold text-[#DC2626] hover:bg-[#FEF2F2]"
                    >
                      <LogOut size={18} />
                      Log out
                    </button>
                  </div>
                ) : null}
              </div>
            </div>
          </header>
          <div className="min-h-0 flex-1 overflow-y-auto" aria-label="Student page content">
            {children}
          </div>
        </section>
      </div>

      <ConfirmDialog request={confirm} onClose={() => setConfirm(null)} />
      {mobileMenuOpen ? (
        <section className="fixed inset-0 z-[80] lg:hidden" aria-label="Student mobile menu">
          <button type="button" aria-label="Close student menu backdrop" onClick={() => setMobileMenuOpen(false)} className="absolute inset-0 bg-black/40" />
          <aside className="absolute inset-y-0 left-0 flex w-[310px] max-w-[86vw] flex-col bg-white shadow-2xl">
            <div className="flex min-h-16 items-center gap-3 border-b border-black/10 px-4">
              <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="Alluwal Education Hub" className="h-11 w-auto object-contain" />
              <button
                type="button"
                aria-label="Close student menu"
                onClick={() => setMobileMenuOpen(false)}
                className="ml-auto grid h-10 w-10 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]"
              >
                <X size={20} />
              </button>
            </div>
            <div className="flex items-center gap-3 border-b border-black/10 px-4 py-3">
              <StudentAvatar summary={summary} size={40} />
              <span className="min-w-0 flex-1 truncate text-sm font-bold text-[#334155]">{summary.displayName}</span>
            </div>
            <nav className="flex-1 overflow-y-auto px-3 py-3" aria-label="Student mobile navigation">
              {availableSidebarSections.map((section) => (
                <div key={section.title} className="mb-3">
                  <p className="mb-1 px-2 text-[10px] font-black uppercase tracking-[0.14em] text-[#94A3B8]">{section.title}</p>
                  <StudentSidebarItems items={section.items} favoritedItems={favoritedItems} activeLabel={activeLabel} onToggleFavorite={toggleFavoriteItem} />
                </div>
              ))}
            </nav>
            <div className="border-t border-black/10 px-3 py-3">
              <button
                type="button"
                onClick={() =>
                  setConfirm({
                    title: "Sign Out",
                    body: "Are you sure you want to sign out?",
                    confirmLabel: "Sign Out",
                    onConfirm: () => void logout(),
                  })
                }
                className="flex min-h-11 w-full items-center gap-3 rounded-xl px-3 text-left text-sm font-bold text-[#DC2626] hover:bg-[#FEF2F2]"
              >
                <LogOut size={18} />
                Log out
              </button>
            </div>
          </aside>
        </section>
      ) : null}
    </main>
  );
}

function StudentSidebarFavorites({
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
      <StudentSidebarItems items={items} favoritedItems={favoritedItems} activeLabel={activeLabel} onToggleFavorite={onToggleFavorite} />
    </div>
  );
}

function StudentSidebarItems({
  items,
  favoritedItems,
  activeLabel,
  onToggleFavorite,
  collapsed = false,
}: {
  items: SidebarItem[];
  favoritedItems: Set<string>;
  activeLabel: string;
  onToggleFavorite: (label: string) => void;
  collapsed?: boolean;
}) {
  // Icon rail: labels and the pin control are dropped, and the native title
  // carries the name so a collapsed sidebar is still navigable.
  if (collapsed) {
    return (
      <div className="grid gap-1">
        {items.map((item) => {
          const Icon = item.icon;
          const isActive = item.label === activeLabel;
          return (
            <Link
              key={item.label}
              href={item.href}
              title={item.label}
              aria-label={item.label}
              aria-current={isActive ? "page" : undefined}
              className={`mx-auto grid h-11 w-11 place-items-center rounded-2xl transition ${
                isActive ? "bg-[#E6EEF8]" : "hover:bg-[#F1F4F8]"
              }`}
            >
              <Icon size={20} style={{ color: item.color }} />
            </Link>
          );
        })}
      </div>
    );
  }

  return (
    <div className="grid gap-1">
      {items.map((item) => {
        const Icon = item.icon;
        const isActive = item.label === activeLabel;
        return (
          <div key={item.label} className="flex min-h-10 items-center gap-2">
            <Link
              href={item.href}
              aria-current={isActive ? "page" : undefined}
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

export function StudentAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";

  // While verifying, show the dashboard's own frame rather than a card that
  // announces "Checking student access". On a reload the session is usually
  // already cached, so this is a brief skeleton instead of a jarring interstitial
  // — and someone who is signed in never sees an access-denied-looking screen.
  if (checking) {
    return (
      <main className="h-screen overflow-hidden bg-[#F5F5F5]" aria-busy="true" aria-label="Loading dashboard">
        <div className="flex h-screen">
          <aside className="hidden w-[260px] shrink-0 flex-col gap-3 border-r border-[#D7DEE8] bg-white p-4 lg:flex">
            <div className="h-9 w-28 animate-pulse rounded-lg bg-[#EEF2F7]" />
            <div className="h-10 w-full animate-pulse rounded-xl bg-[#F1F5F9]" />
            <div className="mt-2 grid gap-2">
              {Array.from({ length: 7 }).map((_, index) => (
                <div key={index} className="h-9 w-full animate-pulse rounded-xl bg-[#F1F5F9]" />
              ))}
            </div>
          </aside>
          <section className="flex min-w-0 flex-1 flex-col">
            <div className="hidden min-h-14 items-center border-b border-black/5 bg-white px-4 lg:flex">
              <div className="h-4 w-40 animate-pulse rounded bg-[#EEF2F7]" />
            </div>
            <div className="flex-1 p-6">
              <div className="h-28 w-full animate-pulse rounded-3xl bg-[#EDF1F6]" />
              <div className="mt-5 grid gap-4 sm:grid-cols-3">
                {Array.from({ length: 3 }).map((_, index) => (
                  <div key={index} className="h-28 animate-pulse rounded-2xl bg-[#EDF1F6]" />
                ))}
              </div>
            </div>
          </section>
        </div>
      </main>
    );
  }

  return (
    <main className="grid min-h-screen place-items-center bg-[#F5F8FB] px-4 py-10 text-[#0F172A]">
      <section className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 text-center shadow-sm">
        <div className="mx-auto grid h-12 w-12 place-items-center rounded-2xl bg-[#E6F3FF] text-[#0386FF]">
          <LayoutDashboard size={24} />
        </div>
        <h1 className="mt-4 text-2xl font-black">
          {access === "signedOut" ? "Student sign-in required" : "Student access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          Sign in with a student account to open the student dashboard.
        </p>
        {true ? (
          <Link href="/student/login/" className="mt-5 inline-flex min-h-11 items-center justify-center rounded-xl bg-[#0386FF] px-5 text-sm font-bold text-white">
            Go to login
          </Link>
        ) : null}
      </section>
    </main>
  );
}

function summaryForUser(user: User, data: UserRecord | null): StudentSummary {
  const displayName = data
    ? [stringValue(data.first_name ?? data["first-name"]), stringValue(data.last_name ?? data["last-name"])].filter(Boolean).join(" ")
    : "";
  const fallback = user.displayName?.trim() || user.email?.replace(/@.*/, "") || "Student";
  const name = displayName || fallback;
  return {
    displayName: name,
    firstName: name.split(/\s+/)[0] || "Student",
    initials: initialsFromName(name),
  };
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "ST";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}
