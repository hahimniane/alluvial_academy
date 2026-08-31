"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { useEffect, useMemo, useState } from "react";
import { ChevronLeft, ChevronRight, Lock, PlaySquare, RefreshCw, Search, UserRound, Video, X } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, functions } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";

type RecordingItem = {
  recordingId: string;
  shiftId: string;
  shiftName: string;
  subjectName: string;
  teacherId: string;
  teacherName: string;
  studentIds: string[];
  status: string;
  mergeStatus: string;
  error: string;
  filePath: string;
  startedAt: Date | null;
  requestedAt: Date | null;
  updatedAt: Date | null;
  deleteAfter: Date | null;
  canPlay: boolean;
};

type TeacherBucket = {
  key: string;
  name: string;
  studentCount: number;
  latestDate: Date | null;
  recordings: RecordingItem[];
};

export function RecordingsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [recordings, setRecordings] = useState<RecordingItem[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [accessRole, setAccessRole] = useState("");

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
        const result = await loadRecordings();
        if (!mounted) return;
        setRecordings(result.recordings);
        setAccessRole(result.role);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Failed to load recordings");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const teacherBuckets = useMemo(() => buildTeacherBuckets(recordings, search), [recordings, search]);
  const showSearch = recordings.length > 0;
  const headerSubtitle = `${teacherBuckets.length} teacher${teacherBuckets.length === 1 ? "" : "s"}`;

  if (access !== "allowed") {
    return <RecordingsAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Recordings" breadcrumb="Communication / Recordings">
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

        <section className="border-b border-[#F1F5F9] bg-white">
          <div className="flex min-h-[60px] items-center px-2 sm:px-4">
            <span className="grid h-12 w-12 shrink-0 place-items-center text-[#1E293B]" />
            <div className="min-w-0 flex-1">
              <h1 className="truncate text-lg font-bold text-[#0F172A]">Teachers</h1>
              <p className="mt-0.5 text-xs text-[#64748B]">{headerSubtitle}</p>
            </div>
            <button
              type="button"
              onClick={async () => {
                setLoading(true);
                setMessage("");
                try {
                  const result = await loadRecordings();
                  setRecordings(result.recordings);
                  setAccessRole(result.role);
                  setSearch("");
                } catch (error) {
                  setMessage(error instanceof Error ? error.message : "Failed to load recordings");
                } finally {
                  setLoading(false);
                }
              }}
              aria-label="Refresh recordings"
              className="grid h-11 w-11 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]"
            >
              <RefreshCw size={22} />
            </button>
          </div>
        </section>

        {showSearch ? (
          <section className="px-4 py-3">
            <label className="relative block h-11 max-w-2xl">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={20} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search teachers"
                aria-label="Search recordings"
                className="h-full w-full rounded-xl border border-[#E2E8F0] bg-white pl-11 pr-10 text-sm text-[#0F172A] outline-none placeholder:text-[#94A3B8] focus:border-[#0E72ED] focus:ring-2 focus:ring-[#BFDBFE]"
              />
              {search ? (
                <button type="button" aria-label="Clear search" onClick={() => setSearch("")} className="absolute right-2 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-lg text-[#64748B] hover:bg-[#F1F5F9]">
                  <X size={16} />
                </button>
              ) : null}
            </label>
          </section>
        ) : null}

        {message ? <ErrorCard message={message} onRetry={() => void retryLoad(setLoading, setMessage, setRecordings, setAccessRole, setSearch)} /> : null}

        {loading ? (
          <LoadingRecordings />
        ) : recordings.length === 0 ? (
          <NoRecordingsCard />
        ) : teacherBuckets.length === 0 ? (
          <SearchEmptyCard />
        ) : (
          <section className="px-4 py-2">
            <div className="mx-auto grid max-w-5xl gap-2">
              {teacherBuckets.map((teacher) => (
                <TeacherCard key={teacher.key} teacher={teacher} />
              ))}
            </div>
          </section>
        )}

        {accessRole ? <span className="sr-only">Recordings role: {accessRole}</span> : null}
      </main>
    </AdminDashboardShell>
  );
}

function TeacherCard({ teacher }: { teacher: TeacherBucket }) {
  return (
    <article className="flex items-center gap-3 rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-[0_2px_8px_rgba(15,23,42,0.03)]">
      <span className="grid h-[38px] w-[38px] shrink-0 place-items-center rounded-[10px] bg-[#E7F3FF] text-[#0E72ED]">
        <UserRound size={20} />
      </span>
      <div className="min-w-0 flex-1">
        <h2 className="truncate text-sm font-semibold text-[#0F172A]">{teacher.name}</h2>
        <p className="mt-0.5 truncate text-xs text-[#64748B]">
          {teacher.studentCount} student{teacher.studentCount === 1 ? "" : "s"} · {teacher.recordings.length} recording{teacher.recordings.length === 1 ? "" : "s"}
        </p>
        {teacher.latestDate ? <p className="mt-0.5 truncate text-[11px] text-[#94A3B8]">Latest: {shortDate(teacher.latestDate)}</p> : null}
      </div>
      <ChevronRight className="text-[#94A3B8]" size={22} />
    </article>
  );
}

function NoRecordingsCard() {
  return (
    <section className="grid min-h-[calc(100vh-190px)] place-items-center px-8 py-10">
      <div className="w-full max-w-[480px] translate-y-12 rounded-2xl bg-white px-6 py-8 text-center shadow-[0_4px_12px_rgba(15,23,42,0.04)] lg:translate-y-16">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#E7F3FF] text-[#60A5FA]">
          <PlaySquare size={34} />
        </div>
        <h2 className="mt-5 text-base font-bold text-[#374151]">No recordings yet</h2>
        <p className="mt-3 text-sm leading-6 text-[#6B7280]">Class recordings will appear here after sessions are recorded.</p>
      </div>
    </section>
  );
}

function SearchEmptyCard() {
  return (
    <section className="grid min-h-[360px] place-items-center px-8 py-10">
      <div className="text-center">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#F1F5F9] text-[#94A3B8]">
          <Search size={30} />
        </div>
        <h2 className="mt-5 text-base font-bold text-[#374151]">No teachers found</h2>
        <p className="mt-2 text-sm text-[#6B7280]">Try a different search term.</p>
      </div>
    </section>
  );
}

function LoadingRecordings() {
  return (
    <div className="grid min-h-[calc(100vh-160px)] place-items-center">
      <div className="h-11 w-11 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0E72ED]" />
    </div>
  );
}

function ErrorCard({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <section className="mx-auto mt-6 w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-sm">
      <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#FEE2E2] text-[#EF4444]">
        <X size={28} />
      </div>
      <p className="mt-4 text-sm font-semibold text-[#374151]">{message}</p>
      <button type="button" onClick={onRetry} className="mt-5 inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#0E72ED] px-5 text-sm font-semibold text-white">
        <RefreshCw size={16} />
        Try Again
      </button>
    </section>
  );
}

function RecordingsAccessPrompt({ access }: { access: AccessState }) {
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
              ? "Sign in with an administrator account before opening recordings."
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

async function retryLoad(
  setLoading: (value: boolean) => void,
  setMessage: (value: string) => void,
  setRecordings: (value: RecordingItem[]) => void,
  setAccessRole: (value: string) => void,
  setSearch: (value: string) => void,
) {
  setLoading(true);
  setMessage("");
  try {
    const result = await loadRecordings();
    setRecordings(result.recordings);
    setAccessRole(result.role);
    setSearch("");
  } catch (error) {
    setMessage(error instanceof Error ? error.message : "Failed to load recordings");
  } finally {
    setLoading(false);
  }
}

async function loadRecordings() {
  const callable = httpsCallable(functions, "listClassRecordings");
  const result = await callable({ limit: 200, activeRole: "admin" });
  const raw = result.data;
  if (!raw || typeof raw !== "object") throw new Error("Unexpected response from server");
  const data = raw as Record<string, unknown>;
  if (data.success !== true) throw new Error(stringValue(data.error) || "Failed to load recordings");
  const items = Array.isArray(data.recordings) ? data.recordings : [];
  return {
    role: stringValue(data.role),
    recordings: items.map((item) => normalizeRecording(item)).filter((item): item is RecordingItem => item !== null),
  };
}

function normalizeRecording(raw: unknown): RecordingItem | null {
  if (!raw || typeof raw !== "object") return null;
  const data = raw as Record<string, unknown>;
  const recordingId = stringValue(data.recordingId);
  const filePath = stringValue(data.filePath);
  if (!recordingId || !filePath) return null;
  return {
    recordingId,
    shiftId: stringValue(data.shiftId),
    shiftName: stringValue(data.shiftName) || "Class Recording",
    subjectName: stringValue(data.subjectName),
    teacherId: stringValue(data.teacherId),
    teacherName: stringValue(data.teacherName),
    studentIds: arrayOfStrings(data.studentIds),
    status: stringValue(data.status) || "unknown",
    mergeStatus: stringValue(data.mergeStatus),
    error: stringValue(data.error),
    filePath,
    startedAt: dateValue(data.startedAtIso),
    requestedAt: dateValue(data.requestedAtIso),
    updatedAt: dateValue(data.updatedAtIso),
    deleteAfter: dateValue(data.deleteAfterIso),
    canPlay: data.canPlay === true,
  };
}

function buildTeacherBuckets(recordings: RecordingItem[], search: string) {
  const term = search.trim().toLowerCase();
  const buckets = new Map<string, RecordingItem[]>();
  for (const recording of recordings) {
    const key = recording.teacherId || recording.teacherName || "unknown";
    const list = buckets.get(key) ?? [];
    list.push(recording);
    buckets.set(key, list);
  }
  return Array.from(buckets.entries())
    .map(([key, items]) => {
      const name = items.find((item) => item.teacherName)?.teacherName || "Unknown teacher";
      const latestDate = latestRecordingDate(items);
      return {
        key,
        name,
        studentCount: new Set(items.flatMap((item) => item.studentIds)).size,
        latestDate,
        recordings: items,
      };
    })
    .filter((bucket) => !term || [bucket.name, ...bucket.recordings.map((item) => item.shiftName), ...bucket.recordings.map((item) => item.subjectName)].some((value) => value.toLowerCase().includes(term)))
    .sort((a, b) => (b.latestDate?.getTime() ?? 0) - (a.latestDate?.getTime() ?? 0) || a.name.localeCompare(b.name));
}

function latestRecordingDate(items: RecordingItem[]) {
  let latest: Date | null = null;
  for (const item of items) {
    const date = item.startedAt ?? item.requestedAt ?? item.updatedAt;
    if (date && (!latest || date > latest)) latest = date;
  }
  return latest;
}

function arrayOfStrings(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => stringValue(item)).filter(Boolean);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function dateValue(value: unknown): Date | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function shortDate(date: Date) {
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(date);
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
