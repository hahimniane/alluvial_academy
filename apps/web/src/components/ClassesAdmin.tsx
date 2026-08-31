"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, query, Timestamp } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import { CalendarClock, ChevronLeft, Clock3, Lock, Search, SlidersHorizontal, Video, VideoIcon, X } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type TimeFilter = "activeNow" | "joinable" | "upcoming" | "all";

type ClassRecord = {
  id: string;
  title: string;
  teacherName: string;
  studentNames: string[];
  subject: string;
  start: Date | null;
  end: Date | null;
  status: string;
  category: string;
  videoProvider: string;
  livekitRoomName: string;
  zoomMeetingId: string;
};

const filterOptions: { id: TimeFilter; label: string }[] = [
  { id: "activeNow", label: "Active now" },
  { id: "joinable", label: "Joinable" },
  { id: "upcoming", label: "Upcoming" },
  { id: "all", label: "All" },
];

export function ClassesAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [classes, setClasses] = useState<ClassRecord[]>([]);
  const [search, setSearch] = useState("");
  const [timeFilter, setTimeFilter] = useState<TimeFilter>("activeNow");
  const [filtersOpen, setFiltersOpen] = useState(false);
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
        const loadedClasses = await loadClasses();
        if (mounted) setClasses(loadedClasses);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load classes.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const visibleClasses = useMemo(() => {
    const now = new Date();
    const term = search.trim().toLowerCase();
    return classes
      .filter((classItem) => classItem.end === null || addMinutes(classItem.end, 10) >= now)
      .filter((classItem) => {
        if (timeFilter === "activeNow") return isActiveNow(classItem, now);
        if (timeFilter === "joinable") return canJoinClass(classItem, now);
        if (timeFilter === "upcoming") return classItem.start !== null && classItem.start > now;
        return true;
      })
      .filter((classItem) => {
        if (!term) return true;
        return [classItem.title, classItem.teacherName, classItem.subject, classItem.status, ...classItem.studentNames].some((value) =>
          value.toLowerCase().includes(term),
        );
      })
      .sort((a, b) => compareClasses(a, b, now));
  }, [classes, search, timeFilter]);

  const hasActiveFilters = search.trim() !== "" || timeFilter !== "activeNow";

  if (access !== "allowed") {
    return <ClassesAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Classes" breadcrumb="Communication / Classes">
      <main className="min-h-[calc(100vh-56px)] bg-[#F8FAFC] text-[#0F172A]">
        <header className="border-b border-[#F3F4F6] bg-white lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center px-3">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <span className="h-0.5 w-4 bg-current" />
              <span className="-mt-5 h-0.5 w-4 bg-current" />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Education Hub</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">{initialsFor(user)}</span>
          </div>
        </header>

        <header className="border-b border-[#E5E7EB] bg-white">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center px-3 sm:px-4">
            <Link href="/admin/" aria-label="Back to dashboard" className="grid h-11 w-11 place-items-center rounded-xl text-[#0F172A] hover:bg-[#F8FAFC]">
              <ChevronLeft size={24} />
            </Link>
            <h1 className="truncate text-center text-lg font-bold text-[#111827]">Classes</h1>
            <Link href="/admin/recordings/" aria-label="Class Recordings" className="grid h-11 w-11 place-items-center rounded-xl text-[#0E72ED] hover:bg-[#E7F3FF]">
              <VideoIcon size={23} />
            </Link>
          </div>
        </header>

        <section className="mx-auto max-w-6xl px-4 py-4">
          <div className="flex flex-row gap-3">
            <label className="relative block min-h-11 flex-1">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[#64748B]" size={18} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search Classes Teacher Student Subject"
                aria-label="Search classes teacher student subject"
                className="h-11 w-full rounded-[14px] border border-[#CBD5E1] bg-white pl-11 pr-10 text-sm text-[#111827] outline-none placeholder:text-[#94A3B8] focus:border-[#0386FF] focus:ring-2 focus:ring-[#BFDBFE]"
              />
              {search ? (
                <button type="button" aria-label="Clear search" onClick={() => setSearch("")} className="absolute right-2 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-lg text-[#64748B] hover:bg-[#F1F5F9]">
                  <X size={16} />
                </button>
              ) : null}
            </label>

            <div className="relative">
              <button
                type="button"
                onClick={() => setFiltersOpen((open) => !open)}
                className="inline-flex h-11 w-[108px] items-center justify-center gap-2 rounded-[14px] border border-[#CBD5E1] bg-white px-3 text-sm font-bold text-[#0386FF] hover:bg-[#F8FAFC] sm:w-auto sm:px-4"
              >
                <SlidersHorizontal size={18} />
                {timeFilter === "activeNow" ? "Filters" : "Filters (1)"}
              </button>
              {filtersOpen ? (
                <section className="absolute right-0 z-20 mt-2 w-64 rounded-2xl border border-[#E2E8F0] bg-white p-3 shadow-xl" aria-label="Class filters">
                  <p className="px-2 pb-2 text-xs font-bold uppercase tracking-wide text-[#64748B]">Time</p>
                  <div className="grid gap-1">
                    {filterOptions.map((option) => (
                      <button
                        key={option.id}
                        type="button"
                        onClick={() => {
                          setTimeFilter(option.id);
                          setFiltersOpen(false);
                        }}
                        className={`rounded-xl px-3 py-2 text-left text-sm font-semibold ${
                          timeFilter === option.id ? "bg-[#E7F3FF] text-[#0386FF]" : "text-[#334155] hover:bg-[#F8FAFC]"
                        }`}
                      >
                        {option.label}
                      </button>
                    ))}
                  </div>
                </section>
              ) : null}
            </div>

            {hasActiveFilters ? (
              <button type="button" onClick={() => clearFilters(setSearch, setTimeFilter)} className="hidden h-11 rounded-[14px] px-4 text-sm font-bold text-[#0386FF] hover:bg-[#E7F3FF] sm:block">
                Clear
              </button>
            ) : null}
          </div>

          <p className="mt-3 text-xs font-semibold text-[#64748B]">{visibleClasses.length === 0 ? "0 Results" : `${visibleClasses.length} Results`}</p>

          <HeaderCard />

          {message ? <p className="mt-3 rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-4 py-3 text-sm font-semibold text-[#B91C1C]">{message}</p> : null}

          {loading ? (
            <LoadingClasses />
          ) : visibleClasses.length === 0 ? (
            <NoClassResultsCard hasActiveFilters={hasActiveFilters} onClear={() => clearFilters(setSearch, setTimeFilter)} />
          ) : (
            <section className="mt-3 grid gap-3">
              {visibleClasses.map((classItem) => (
                <ClassCard key={classItem.id} classItem={classItem} />
              ))}
            </section>
          )}
        </section>
      </main>
    </AdminDashboardShell>
  );
}

function HeaderCard() {
  return (
    <section className="mt-3 flex items-start gap-3 rounded-2xl bg-white p-4 shadow-[0_4px_14px_rgba(15,23,42,0.08)]">
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-[#E7F3FF] text-[#0E72ED]">
        <Video size={24} />
      </span>
      <div className="min-w-0">
        <h2 className="text-base font-bold text-[#111827]">Your classes</h2>
        <p className="mt-1 text-sm leading-6 text-[#64748B]">Join your classes directly in the app. The Join button becomes active 10 minutes before the class starts.</p>
      </div>
    </section>
  );
}

function NoClassResultsCard({ hasActiveFilters, onClear }: { hasActiveFilters: boolean; onClear: () => void }) {
  return (
    <section className="mt-3 grid min-h-[170px] place-items-center rounded-2xl bg-white px-6 py-6 text-center shadow-[0_4px_14px_rgba(15,23,42,0.08)]">
      <div>
        <div className="mx-auto grid h-[72px] w-[72px] place-items-center rounded-full bg-[#E7F3FF] text-[#0386FF]">
          <Search size={32} />
        </div>
        <h2 className="mt-4 text-lg font-bold text-[#111827]">{hasActiveFilters ? "No classes match your filters" : "No active classes right now"}</h2>
        <p className="mt-2 max-w-md text-sm leading-6 text-[#64748B]">
          {hasActiveFilters ? "Clear search or filters to see more classes." : "Switch the Time filter to Upcoming or All to browse other classes."}
        </p>
        {hasActiveFilters ? (
          <button type="button" onClick={onClear} className="mt-5 min-h-10 rounded-xl bg-[#0386FF] px-4 text-sm font-bold text-white">
            Clear filters
          </button>
        ) : null}
      </div>
    </section>
  );
}

function ClassCard({ classItem }: { classItem: ClassRecord }) {
  const now = new Date();
  const joinable = canJoinClass(classItem, now);
  const hasVideoCall = Boolean(classItem.livekitRoomName || classItem.zoomMeetingId || classItem.videoProvider);
  const buttonLabel = joinable ? "Join" : classItem.start && classItem.start > now ? `Join in ${formatDuration(addMinutes(classItem.start, -10).getTime() - now.getTime())}` : "Class ended";
  return (
    <article className="flex items-start gap-3 rounded-xl border border-[#E2E8F0] bg-white p-4 shadow-sm">
      <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-[10px] ${joinable ? "bg-[#DCFCE7] text-[#10B981]" : hasVideoCall ? "bg-[#FEF3C7] text-[#B45309]" : "bg-[#F1F5F9] text-[#64748B]"}`}>
        {joinable ? <Video size={21} /> : <Clock3 size={20} />}
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-start">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-sm font-bold text-[#1E293B]">{classItem.teacherName || "No teacher assigned"}</h2>
            <p className="mt-1 truncate text-sm text-[#64748B]">{classItem.studentNames.length ? classItem.studentNames.join(", ") : "No students"}</p>
          </div>
          <button
            type="button"
            disabled={!joinable}
            className={`min-h-9 rounded-xl px-4 text-sm font-bold ${
              joinable ? "bg-[#0386FF] text-white hover:bg-[#0E72ED]" : "cursor-not-allowed bg-[#E2E8F0] text-[#64748B]"
            }`}
          >
            {buttonLabel}
          </button>
        </div>
        <div className="mt-3 flex flex-wrap items-center gap-2 text-xs font-semibold text-[#64748B]">
          <span className="inline-flex items-center gap-1 rounded-lg bg-[#F8FAFC] px-2 py-1">
            <CalendarClock size={14} />
            {formatClassTime(classItem)}
          </span>
          {classItem.subject ? <span className="rounded-lg bg-[#E7F3FF] px-2 py-1 text-[#0E72ED]">{classItem.subject}</span> : null}
          {classItem.videoProvider ? <span className="rounded-lg bg-[#F5F3FF] px-2 py-1 text-[#7C3AED]">{classItem.videoProvider}</span> : null}
        </div>
      </div>
    </article>
  );
}

function LoadingClasses() {
  return (
    <div className="grid min-h-[360px] place-items-center rounded-2xl bg-white">
      <div className="text-center">
        <div className="mx-auto h-11 w-11 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
        <p className="mt-4 text-sm font-semibold text-[#64748B]">Loading classes...</p>
      </div>
    </div>
  );
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Administrator";
  return source
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}

function ClassesAccessPrompt({ access }: { access: AccessState }) {
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
              ? "Sign in with an administrator account before opening classes."
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

async function loadClasses() {
  const snap = await getDocs(query(collection(db, "teaching_shifts"), limit(500)));
  const now = new Date();
  const futureCutoff = addDays(now, 121);
  return snap.docs
    .map((docSnap) => normalizeClass(docSnap.id, docSnap.data() as Record<string, unknown>))
    .filter((classItem) => classItem.category.toLowerCase() === "teaching")
    .filter((classItem) => !classItem.start || classItem.start <= futureCutoff)
    .sort((a, b) => (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0));
}

function normalizeClass(id: string, data: Record<string, unknown>): ClassRecord {
  const subject = stringValue(data.subject_display_name ?? data.subjectDisplayName ?? data.subject);
  const teacherName = stringValue(data.teacher_name ?? data.teacherName) || "No teacher assigned";
  const studentNames = arrayOfStrings(data.student_names ?? data.studentNames);
  const title =
    stringValue(data.custom_name ?? data.customName) ||
    stringValue(data.auto_generated_name ?? data.autoGeneratedName) ||
    [teacherName, subject, studentNames.join(", ")].filter(Boolean).join(" - ") ||
    "Class";
  return {
    id,
    title,
    teacherName,
    studentNames,
    subject,
    start: dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime),
    end: dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime),
    status: stringValue(data.status) || "scheduled",
    category: stringValue(data.category) || "teaching",
    videoProvider: stringValue(data.video_provider ?? data.videoProvider),
    livekitRoomName: stringValue(data.livekit_room_name ?? data.livekitRoomName),
    zoomMeetingId: stringValue(data.zoom_meeting_id ?? data.zoomMeetingId),
  };
}

function compareClasses(a: ClassRecord, b: ClassRecord, now: Date) {
  const aJoinable = canJoinClass(a, now);
  const bJoinable = canJoinClass(b, now);
  if (aJoinable && !bJoinable) return -1;
  if (!aJoinable && bJoinable) return 1;
  const aEnded = a.end ? addMinutes(a.end, 10) < now : false;
  const bEnded = b.end ? addMinutes(b.end, 10) < now : false;
  if (aEnded && !bEnded) return 1;
  if (!aEnded && bEnded) return -1;
  if (aEnded && bEnded) return (b.start?.getTime() ?? 0) - (a.start?.getTime() ?? 0);
  return (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0);
}

function isActiveNow(classItem: ClassRecord, now: Date) {
  if (!classItem.start || !classItem.end) return classItem.status.toLowerCase() === "active";
  return classItem.start <= now && classItem.end >= now;
}

function canJoinClass(classItem: ClassRecord, now: Date) {
  if (!classItem.start || !classItem.end) return false;
  const hasVideoCall = Boolean(classItem.livekitRoomName || classItem.zoomMeetingId || classItem.videoProvider);
  return hasVideoCall && addMinutes(classItem.start, -10) <= now && addMinutes(classItem.end, 10) >= now;
}

function clearFilters(setSearch: (value: string) => void, setTimeFilter: (value: TimeFilter) => void) {
  setSearch("");
  setTimeFilter("activeNow");
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

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function addMinutes(date: Date, minutes: number) {
  const next = new Date(date);
  next.setMinutes(next.getMinutes() + minutes);
  return next;
}

function formatClassTime(classItem: ClassRecord) {
  if (!classItem.start || !classItem.end) return "Time not set";
  return `${shortDate(classItem.start)} ${shortTime(classItem.start)} - ${shortTime(classItem.end)}`;
}

function shortDate(date: Date) {
  const today = new Date();
  const tomorrow = addDays(today, 1);
  if (sameDate(date, today)) return "Today";
  if (sameDate(date, tomorrow)) return "Tomorrow";
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(date);
}

function shortTime(date: Date) {
  return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit" }).format(date);
}

function sameDate(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function formatDuration(milliseconds: number) {
  const totalMinutes = Math.max(0, Math.ceil(milliseconds / 60_000));
  if (totalMinutes < 60) return `${totalMinutes}m`;
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return minutes ? `${hours}h ${minutes}m` : `${hours}h`;
}
