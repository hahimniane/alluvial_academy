"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, orderBy, query, Timestamp, where } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Inbox,
  LayoutPanelLeft,
  Lock,
  Menu,
  Search,
  Settings,
  Star,
  X,
} from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type StatusFilter = "all" | "completed" | "pending" | "draft";

type TeacherRecord = {
  id: string;
  name: string;
  email: string;
};

type SubmissionRecord = {
  id: string;
  userId: string;
  formId: string;
  formTitle: string;
  status: string;
  formType: string;
  yearMonth: string | null;
  submittedAt: Date | null;
};

const statusOptions: { value: StatusFilter; label: string }[] = [
  { value: "all", label: "All Status" },
  { value: "completed", label: "Completed" },
  { value: "pending", label: "Pending" },
  { value: "draft", label: "Draft" },
];

export function AllSubmissionsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [teachers, setTeachers] = useState<Record<string, TeacherRecord>>({});
  const [submissions, setSubmissions] = useState<SubmissionRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selectedStatus, setSelectedStatus] = useState<StatusFilter>("all");
  const [selectedMonth, setSelectedMonth] = useState(currentYearMonth());
  const [showAllMonths, setShowAllMonths] = useState(false);
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
        const [teacherRecords, responseRecords] = await Promise.all([
          loadTeachers(),
          loadSubmissions({ yearMonth: selectedMonth, showAllMonths }),
        ]);
        if (!mounted) return;
        setTeachers(teacherRecords);
        setSubmissions(responseRecords);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load submissions.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  useEffect(() => {
    if (access !== "allowed") return;
    let mounted = true;
    setLoading(true);
    setMessage("");
    void loadSubmissions({ yearMonth: selectedMonth, showAllMonths })
      .then((records) => {
        if (mounted) setSubmissions(records);
      })
      .catch((error) => {
        if (mounted) {
          setSubmissions([]);
          setMessage(error instanceof Error ? error.message : "Could not load submissions.");
        }
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, [access, selectedMonth, showAllMonths]);

  const filteredSubmissions = useMemo(() => {
    const term = search.trim().toLowerCase();
    return submissions.filter((submission) => {
      if (selectedStatus !== "all" && normalizeStatus(submission.status) !== selectedStatus) return false;
      if (!term) return true;
      const teacher = teachers[submission.userId];
      return [submission.formTitle, teacher?.name, teacher?.email].some((value) => (value ?? "").toLowerCase().includes(term));
    });
  }, [search, selectedStatus, submissions, teachers]);

  const stats = useMemo(() => quickStats(filteredSubmissions), [filteredSubmissions]);
  const groupedTeachers = useMemo(() => groupByTeacher(filteredSubmissions, teachers), [filteredSubmissions, teachers]);
  const monthLabel = showAllMonths ? "All time" : formatMonth(selectedMonth);

  if (access !== "allowed") {
    return <AllSubmissionsAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="All Submissions" breadcrumb="Forms / All Submissions">
      <main className="min-h-[calc(100vh-56px)] bg-white text-[#1E293B]">
        <header className="lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center bg-white px-3 text-[#0F172A]">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <Menu size={20} />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Education Hub</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">
              {initialsFor(user)}
            </span>
          </div>
        </header>

        <section className="border-b border-[#E2E8F0] bg-white px-3 pb-2 pt-2">
          <div className="flex min-h-8 items-center gap-2">
            <span className="text-[#64748B]">
              <ChevronLeft size={20} />
            </span>
            <h1 className="shrink-0 text-sm font-semibold text-[#1E293B]">All Submissions (Admin)</h1>
            <p className="min-w-0 truncate text-[11px] text-[#94A3B8]">
              {stats.total} total · {stats.teachers} teachers · {stats.completed} done · {stats.pending} pending
            </p>
            <div className="ml-auto flex shrink-0 items-center gap-1 max-[700px]:hidden">
              <IconButton label="Review mode" onClick={() => setMessage("Review mode stays in Flutter until the review/export flow is migrated.")}>
                <LayoutPanelLeft size={18} />
              </IconButton>
              <IconButton label="Preferences" onClick={() => setMessage("Admin submission preferences stay in Flutter until settings are migrated.")}>
                <Settings size={18} />
              </IconButton>
            </div>
          </div>

          <div className="mt-1 flex min-h-[30px] items-center gap-1 overflow-x-auto">
            <label className="relative block h-[26px] w-[200px] shrink-0 max-[700px]:w-[198px]">
              <span className="sr-only">Search submissions</span>
              <Search className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#64748B]" size={16} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search by teacher or f..."
                aria-label="Search submissions"
                className="h-full w-full rounded-md border border-[#E2E8F0] bg-[#F8FAFC] pl-8 pr-7 text-xs outline-none placeholder:text-[#94A3B8] focus:border-[#0386FF]"
              />
              {search ? (
                <button type="button" onClick={() => setSearch("")} aria-label="Clear search" className="absolute right-1 top-1/2 grid h-5 w-5 -translate-y-1/2 place-items-center text-[#64748B]">
                  <X size={14} />
                </button>
              ) : null}
            </label>
            <Chip label="Teachers (All)" />
            <Chip label={monthLabel} active={!showAllMonths} onClick={() => setShowAllMonths(false)} />
            <select
              value={selectedStatus}
              onChange={(event) => setSelectedStatus(event.target.value as StatusFilter)}
              aria-label="Submission status"
              className="h-[26px] shrink-0 rounded-md border border-[#E2E8F0] bg-[#F8FAFC] px-2 text-[11px] text-[#64748B] outline-none focus:border-[#0386FF]"
            >
              {statusOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            <Chip label="All forms" />
            {(search || selectedStatus !== "all" || showAllMonths) ? (
              <button
                type="button"
                onClick={() => {
                  setSearch("");
                  setSelectedStatus("all");
                  setShowAllMonths(false);
                  setSelectedMonth(currentYearMonth());
                }}
                className="h-[26px] shrink-0 rounded px-2 text-[11px] font-medium text-[#EF4444] bg-[#FEE2E2]"
              >
                Clear
              </button>
            ) : null}
          </div>
        </section>

        {!showAllMonths ? (
          <section className="flex min-h-[54px] items-center gap-3 bg-[#EFF6FF] px-3">
            <button type="button" aria-label="Previous month" onClick={() => setSelectedMonth(addMonths(selectedMonth, -1))} className="grid h-8 w-8 shrink-0 place-items-center text-[#94A3B8]">
              <ChevronLeft size={20} />
            </button>
            <span className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-[#0386FF]/10 text-[#0386FF]">
              <CalendarDays size={20} />
            </span>
            <div className="min-w-0 flex-1">
              <h2 className="text-sm font-semibold text-[#1E293B]">{formatMonth(selectedMonth)}</h2>
              <p className="text-xs text-[#94A3B8]">
                {filteredSubmissions.length} submission{filteredSubmissions.length === 1 ? "" : "s"}
              </p>
            </div>
            <button type="button" aria-label="Next month" onClick={() => setSelectedMonth(addMonths(selectedMonth, 1))} className="grid h-8 w-8 shrink-0 place-items-center text-[#94A3B8]">
              <ChevronRight size={20} />
            </button>
            <button type="button" onClick={() => setShowAllMonths(true)} className="h-8 shrink-0 px-2 text-xs font-medium text-[#0386FF]">
              View All
            </button>
          </section>
        ) : null}

        {message ? <p className="mx-3 mt-2 rounded-lg bg-[#EFF6FF] px-3 py-2 text-xs font-semibold text-[#2563EB]">{message}</p> : null}

        <section className={showAllMonths ? "min-h-[calc(100vh-148px)]" : "min-h-[calc(100vh-202px)]"}>
          {loading ? (
            <SubmissionsLoading title="All Submissions (Admin)" />
          ) : filteredSubmissions.length === 0 ? (
            <EmptySubmissions />
          ) : (
            <div className="divide-y divide-[#F1F5F9]">
              {groupedTeachers.map((entry) => (
                <TeacherSubmissionRow key={entry.teacherId} entry={entry} onOpen={() => setMessage("Submission detail review stays in Flutter until the detail flow is migrated.")} />
              ))}
            </div>
          )}
        </section>
      </main>
    </AdminDashboardShell>
  );
}

function IconButton({ label, onClick, children }: { label: string; onClick: () => void; children: React.ReactNode }) {
  return (
    <button type="button" aria-label={label} onClick={onClick} className="grid h-8 w-8 place-items-center rounded text-[#64748B] hover:bg-[#F8FAFC]">
      {children}
    </button>
  );
}

function Chip({ label, active, onClick }: { label: string; active?: boolean; onClick?: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`h-[26px] shrink-0 rounded border px-2 text-[11px] ${
        active ? "border-[#0386FF]/30 bg-[#0386FF]/10 font-semibold text-[#0386FF]" : "border-[#E2E8F0] bg-[#F8FAFC] text-[#64748B]"
      }`}
    >
      {label}
    </button>
  );
}

function SubmissionsLoading({ title }: { title: string }) {
  return (
    <div className="grid min-h-[320px] place-items-center text-center">
      <div>
        <div className="mx-auto h-8 w-8 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
        <p className="mt-3 text-sm font-semibold text-[#64748B]">{title}</p>
      </div>
    </div>
  );
}

function EmptySubmissions() {
  return (
    <div className="grid min-h-[520px] place-items-center px-4 text-center max-[700px]:min-h-[650px]">
      <div>
        <Inbox className="mx-auto text-[#D1D5DB]" size={36} strokeWidth={1.8} />
        <h2 className="mt-2 text-[13px] font-normal text-[#64748B]">No submissions found</h2>
        <p className="mt-1 text-[11px] text-[#94A3B8]">Try adjusting your filters</p>
      </div>
    </div>
  );
}

function TeacherSubmissionRow({ entry, onOpen }: { entry: TeacherGroup; onOpen: () => void }) {
  return (
    <button type="button" onClick={onOpen} className="flex h-[38px] w-full items-center gap-2 px-3 text-left hover:bg-[#F1F5F9]">
      <span className="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-[#0386FF]/10 text-[10px] font-medium text-[#0386FF]">
        {entry.teacherName.slice(0, 1).toUpperCase() || "?"}
      </span>
      <span className="min-w-0 flex-1 truncate text-xs font-medium text-[#1E293B]">{entry.teacherName}</span>
      <span className="rounded bg-[#F1F5F9] px-1.5 py-0.5 text-[10px] font-semibold text-[#64748B]">{entry.count}</span>
      <Star size={16} className="text-[#CBD5E1]" />
      <ChevronRight size={16} className="text-[#CBD5E1]" />
    </button>
  );
}

function AllSubmissionsAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F1F4F8] px-5 text-[#0F172A]">
      <section className="w-full max-w-md rounded-[20px] border border-black/10 bg-white px-6 py-10 text-center shadow-sm">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#EFF6FF] text-[#0386FF]">
          <Lock size={24} />
        </div>
        <h1 className="mt-4 text-xl font-bold">
          {checking ? "Checking admin access" : access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {checking
            ? "Please wait while we verify your dashboard permissions."
            : access === "signedOut"
              ? "Sign in with an administrator account before reviewing submissions."
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

type TeacherGroup = {
  teacherId: string;
  teacherName: string;
  count: number;
};

async function loadTeachers() {
  const teachers: Record<string, TeacherRecord> = {};
  const queries = [
    query(collection(db, "users"), where("role", "==", "teacher"), limit(300)),
    query(collection(db, "users"), where("user_type", "==", "teacher"), limit(300)),
  ];
  for (const teacherQuery of queries) {
    const snap = await getDocs(teacherQuery).catch(() => null);
    snap?.docs.forEach((docSnap) => {
      teachers[docSnap.id] = normalizeTeacher(docSnap.id, docSnap.data() as Record<string, unknown>);
    });
  }
  return teachers;
}

async function loadSubmissions({ yearMonth, showAllMonths }: { yearMonth: string; showAllMonths: boolean }) {
  const base = collection(db, "form_responses");
  const responseQuery = showAllMonths
    ? query(base, orderBy("submittedAt", "desc"), limit(500))
    : query(base, where("yearMonth", "==", yearMonth), limit(500));
  const snap = await getDocs(responseQuery);
  return snap.docs
    .map((docSnap) => normalizeSubmission(docSnap.id, docSnap.data() as Record<string, unknown>))
    .sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0));
}

function normalizeTeacher(id: string, data: Record<string, unknown>): TeacherRecord {
  const firstName = stringValue(data.first_name ?? data.firstName);
  const lastName = stringValue(data.last_name ?? data.lastName);
  const email = stringValue(data.email ?? data["e-mail"]);
  return {
    id,
    name: stringValue(data.displayName ?? data.display_name) || [firstName, lastName].filter(Boolean).join(" ") || email.split("@")[0] || "Unknown",
    email,
  };
}

function normalizeSubmission(id: string, data: Record<string, unknown>): SubmissionRecord {
  const submittedAt = dateValue(data.submittedAt);
  return {
    id,
    userId: stringValue(data.userId ?? data.user_id ?? data.teacherId ?? data.teacher_id),
    formId: stringValue(data.formId ?? data.form_id ?? data.templateId),
    formTitle: stringValue(data.formTitle ?? data.form_title ?? data.title) || "Untitled Form",
    status: stringValue(data.status) || "completed",
    formType: stringValue(data.formType ?? data.form_type),
    yearMonth: stringValue(data.yearMonth) || (submittedAt ? `${submittedAt.getFullYear()}-${String(submittedAt.getMonth() + 1).padStart(2, "0")}` : null),
    submittedAt,
  };
}

function groupByTeacher(submissions: SubmissionRecord[], teachers: Record<string, TeacherRecord>): TeacherGroup[] {
  const counts = new Map<string, number>();
  submissions.forEach((submission) => {
    const key = submission.userId || "unknown";
    counts.set(key, (counts.get(key) ?? 0) + 1);
  });
  return Array.from(counts.entries())
    .map(([teacherId, count]) => ({
      teacherId,
      teacherName: teachers[teacherId]?.name || (teacherId === "unknown" ? "Unknown" : teacherId),
      count,
    }))
    .sort((a, b) => a.teacherName.localeCompare(b.teacherName));
}

function quickStats(submissions: SubmissionRecord[]) {
  const teacherIds = new Set<string>();
  let completed = 0;
  let pending = 0;
  submissions.forEach((submission) => {
    if (submission.userId) teacherIds.add(submission.userId);
    const status = normalizeStatus(submission.status);
    if (status === "completed") completed += 1;
    if (status === "pending") pending += 1;
  });
  return {
    total: submissions.length,
    teachers: teacherIds.size,
    completed,
    pending,
  };
}

function normalizeStatus(value: string): StatusFilter {
  const normalized = value.toLowerCase();
  if (normalized.includes("pending")) return "pending";
  if (normalized.includes("draft")) return "draft";
  if (normalized.includes("complete") || normalized === "done") return "completed";
  return "completed";
}

function currentYearMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function addMonths(yearMonth: string, delta: number) {
  const [year, month] = yearMonth.split("-").map(Number);
  const date = new Date(year, month - 1 + delta, 1);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

function formatMonth(yearMonth: string) {
  const [year, month] = yearMonth.split("-").map(Number);
  if (!year || !month) return yearMonth;
  return new Intl.DateTimeFormat("en", { month: "short", year: "numeric" }).format(new Date(year, month - 1, 1));
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    const parsed = value.toDate();
    return parsed instanceof Date ? parsed : null;
  }
  return null;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Administrator";
  return source
    .replace(/@.*/, "")
    .split(/[\s._-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("") || "AD";
}
