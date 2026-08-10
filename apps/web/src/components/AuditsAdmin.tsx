"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, query, Timestamp } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  BarChart3,
  Bolt,
  CalendarDays,
  ChevronDown,
  Download,
  FileSpreadsheet,
  Filter,
  Lock,
  RefreshCw,
  Search,
  ShieldCheck,
  Table2,
  Users,
} from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type AuditViewMode = "teachers" | "admins";

type TeacherAuditRecord = {
  id: string;
  teacherName: string;
  teacherEmail: string;
  yearMonth: string;
  status: string;
  overallScore: number;
  totalPayment: number;
  totalWorkedHours: number;
  updatedAt: Date | null;
};

type AdminAuditRecord = {
  id: string;
  adminName: string;
  adminEmail: string;
  yearMonth: string;
  status: string;
  score: number;
  formsCount: number;
};

const currentMonthKey = monthKey(new Date());

export function AuditsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [teacherAudits, setTeacherAudits] = useState<TeacherAuditRecord[]>([]);
  const [adminAudits, setAdminAudits] = useState<AdminAuditRecord[]>([]);
  const [viewMode, setViewMode] = useState<AuditViewMode>("teachers");
  const [selectedMonth, setSelectedMonth] = useState(currentMonthKey);
  const [search, setSearch] = useState("");
  const [departmentFilter, setDepartmentFilter] = useState("All Departments");
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [bottomCollapsed, setBottomCollapsed] = useState(false);

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
        const [teachers, admins] = await Promise.all([loadTeacherAudits(), loadAdminAudits()]);
        if (!mounted) return;
        setTeacherAudits(teachers);
        setAdminAudits(admins);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load audits.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const visibleTeacherAudits = useMemo(() => {
    const term = search.trim().toLowerCase();
    return teacherAudits.filter((audit) => {
      if (audit.yearMonth && audit.yearMonth !== selectedMonth) return false;
      if (!term) return true;
      return [audit.teacherName, audit.teacherEmail, audit.status, audit.yearMonth].some((value) => value.toLowerCase().includes(term));
    });
  }, [search, selectedMonth, teacherAudits]);

  const visibleAdminAudits = useMemo(() => {
    const term = search.trim().toLowerCase();
    return adminAudits.filter((audit) => {
      if (audit.yearMonth && audit.yearMonth !== selectedMonth) return false;
      if (!term) return true;
      return [audit.adminName, audit.adminEmail, audit.status, audit.yearMonth].some((value) => value.toLowerCase().includes(term));
    });
  }, [adminAudits, search, selectedMonth]);

  const activeTeachers = viewMode === "teachers";
  const activeRows = activeTeachers ? visibleTeacherAudits : visibleAdminAudits;
  const averageScore = visibleTeacherAudits.length ? visibleTeacherAudits.reduce((sum, audit) => sum + audit.overallScore, 0) / visibleTeacherAudits.length : 0;
  const totalPayment = visibleTeacherAudits.reduce((sum, audit) => sum + audit.totalPayment, 0);
  const pendingCount = visibleTeacherAudits.filter((audit) => isPendingAudit(audit.status)).length;

  function refreshAudits() {
    setLoading(true);
    setMessage("");
    Promise.all([loadTeacherAudits(), loadAdminAudits()])
      .then(([teachers, admins]) => {
        setTeacherAudits(teachers);
        setAdminAudits(admins);
        setMessage("Audits refreshed.");
      })
      .catch((error) => setMessage(error instanceof Error ? error.message : "Could not refresh audits."))
      .finally(() => setLoading(false));
  }

  if (access !== "allowed") {
    return <AuditsAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Audits" breadcrumb="Operations / Audits">
      <main className="min-h-[calc(100vh-56px)] bg-[#F4F4F5] pb-20 text-[#111827]">
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

        <section className="border-b border-[#E5E7EB] bg-white px-2 py-4 lg:px-6">
          <div className="flex flex-wrap items-center gap-2 lg:gap-3">
            <button type="button" aria-label="Back" className="grid h-8 w-8 place-items-center rounded-full text-[#64748B] hover:bg-[#F8FAFC] lg:h-9 lg:w-9">
              <span className="text-2xl leading-none">&lsaquo;</span>
            </button>
            <div className="hidden min-w-0 flex-1 lg:block">
              <h1 className="text-xl font-semibold text-[#222222]">Audit Management</h1>
              <p className="text-xs tracking-wide text-[#626262]">Manage Teacher Performance And Payments</p>
            </div>
            <div className="inline-flex min-h-9 overflow-hidden rounded-full border border-[#7B8494] bg-white text-sm">
              <button
                type="button"
                onClick={() => setViewMode("teachers")}
                className={`inline-flex min-w-[101px] items-center justify-center gap-2 px-3 lg:min-w-[108px] lg:px-4 ${activeTeachers ? "bg-[#E7ECFA] text-[#334155]" : "text-[#30343B]"}`}
              >
                <ShieldCheck size={16} />
                Teachers
              </button>
              <button
                type="button"
                onClick={() => setViewMode("admins")}
                className={`inline-flex min-w-[101px] items-center justify-center gap-2 border-l border-[#7B8494] px-3 lg:min-w-[108px] lg:px-4 ${!activeTeachers ? "bg-[#E7ECFA] text-[#334155]" : "text-[#30343B]"}`}
              >
                <Users size={16} />
                Admins
              </button>
            </div>
            <label className="inline-flex min-h-9 items-center gap-1 rounded-md border border-[#E2E8F0] bg-white px-2 text-sm text-[#1F2937] lg:gap-2 lg:px-3">
              <CalendarDays size={16} />
              <select value={selectedMonth} onChange={(event) => setSelectedMonth(event.target.value)} className="max-w-[78px] bg-transparent outline-none lg:max-w-none">
                {monthOptions([selectedMonth, ...teacherAudits.map((audit) => audit.yearMonth), ...adminAudits.map((audit) => audit.yearMonth)]).map((value) => (
                  <option key={value} value={value}>
                    {formatMonth(value)}
                  </option>
                ))}
              </select>
            </label>
            <button type="button" onClick={refreshAudits} className="hidden min-h-9 items-center gap-2 rounded-md border border-[#E2E8F0] bg-white px-3 text-sm text-[#1F2937] lg:inline-flex">
              <RefreshCw size={15} />
              Refresh
            </button>
          </div>

          {activeTeachers && teacherAudits.length > 0 ? (
            <div className="mt-4 grid gap-2 md:grid-cols-4">
              <StatCard label="Teachers" value={visibleTeacherAudits.length.toString()} icon={Users} color="#0386FF" />
              <StatCard label="Avg Score" value={`${averageScore.toFixed(1)}%`} icon={BarChart3} color="#9333EA" />
              <StatCard label="Total Payment" value={`$${totalPayment.toFixed(2)}`} icon={FileSpreadsheet} color="#F97316" />
              <StatCard label="Pending" value={pendingCount.toString()} icon={Table2} color="#EC4899" />
            </div>
          ) : null}
        </section>

        <section className="border-b border-[#E5E7EB] bg-[#F7F7F8] px-4 py-2 lg:px-6">
          <div className="flex gap-2 overflow-x-auto">
            <label className="relative h-10 min-w-[300px] flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#A3A3A3]" size={19} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search by name or email"
                aria-label="Search audits"
                className="h-full w-full rounded-lg border border-[#E1E5EA] bg-white pl-10 pr-3 text-sm outline-none focus:border-[#0386FF]"
              />
            </label>
            <label className="inline-flex min-h-10 shrink-0 items-center gap-2 rounded-lg border border-[#E1E5EA] bg-white px-3 text-sm text-[#626262]">
              <select value={departmentFilter} onChange={(event) => setDepartmentFilter(event.target.value)} className="bg-transparent outline-none">
                <option>All Departments</option>
              </select>
              <ChevronDown size={16} />
            </label>
            <button type="button" aria-label="Filter audits" className="grid h-10 w-10 shrink-0 place-items-center rounded-lg border border-[#E1E5EA] bg-white text-[#626262]">
              <Filter size={18} />
            </button>
            <button
              type="button"
              disabled={activeRows.length === 0}
              className="inline-flex min-h-10 shrink-0 items-center gap-2 rounded-lg bg-[#E5E7EB] px-4 text-sm font-semibold text-[#8B8B8B] disabled:opacity-80"
            >
              <Table2 size={16} />
              Review Mode
            </button>
            <button type="button" className="hidden min-h-10 shrink-0 items-center gap-2 rounded-lg bg-[#666666] px-4 text-sm font-bold text-white lg:inline-flex">
              <Download size={16} />
              Csv
            </button>
            <button type="button" className="hidden min-h-10 shrink-0 items-center gap-2 rounded-lg bg-[#217346] px-4 text-sm font-bold text-white lg:inline-flex">
              <FileSpreadsheet size={16} />
              Export
            </button>
          </div>
        </section>

        {message ? <div className="mx-4 mt-3 rounded-lg border border-[#BFDBFE] bg-[#EFF6FF] px-4 py-3 text-sm font-semibold text-[#1D4ED8] lg:mx-6">{message}</div> : null}

        <section className="relative min-h-[610px]">
          {loading ? (
            <div className="grid min-h-[540px] place-items-center">
              <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
            </div>
          ) : activeRows.length === 0 ? (
            <EmptyAudits onGenerate={() => setMessage("Audit generation remains available in the Flutter workflow during migration.")} />
          ) : activeTeachers ? (
            <TeacherAuditTable audits={visibleTeacherAudits} />
          ) : (
            <AdminAuditTable audits={visibleAdminAudits} />
          )}
        </section>

        <div className="fixed inset-x-0 bottom-0 z-20 bg-black px-4 py-3 text-white shadow-[0_-10px_20px_rgba(0,0,0,0.22)] lg:left-[260px]">
          <div className="mx-auto flex max-w-5xl items-center gap-3">
            {viewMode === "admins" ? (
              <button type="button" disabled={adminAudits.length === 0} className="hidden min-h-11 flex-1 items-center justify-center gap-2 rounded-xl border border-white/20 text-sm font-semibold text-white/90 disabled:opacity-50 sm:inline-flex">
                <Download size={18} />
                Export CSV
              </button>
            ) : null}
            {!bottomCollapsed ? (
              <button type="button" onClick={() => setMessage("Audit generation remains available in the Flutter workflow during migration.")} className="inline-flex min-h-11 flex-1 items-center justify-center gap-2 rounded-xl border border-yellow-300/30 bg-black text-sm font-bold text-white">
                <Bolt className="text-yellow-300" size={19} />
                Generate Audits
              </button>
            ) : null}
            <button type="button" aria-label={bottomCollapsed ? "Expand" : "Collapse"} onClick={() => setBottomCollapsed((current) => !current)} className="grid h-10 w-10 place-items-center rounded-lg text-white">
              <ChevronDown className={bottomCollapsed ? "rotate-180" : ""} size={22} />
            </button>
          </div>
        </div>
      </main>
    </AdminDashboardShell>
  );
}

function StatCard({ label, value, icon: Icon, color }: { label: string; value: string; icon: typeof Users; color: string }) {
  return (
    <article className="rounded-lg border border-[#E5E7EB] bg-white p-3">
      <div className="flex items-center gap-3">
        <span className="grid h-9 w-9 place-items-center rounded-lg" style={{ backgroundColor: `${color}1A`, color }}>
          <Icon size={18} />
        </span>
        <div>
          <div className="text-base font-bold">{value}</div>
          <div className="text-xs text-[#6B7280]">{label}</div>
        </div>
      </div>
    </article>
  );
}

function EmptyAudits({ onGenerate }: { onGenerate: () => void }) {
  return (
    <div className="grid min-h-[590px] place-items-center">
      <div className="text-center">
        <div className="mx-auto grid h-24 w-24 place-items-center rounded-full bg-[#E0F2FE] text-[#60A5FA]">
          <BarChart3 size={42} />
        </div>
        <h2 className="mt-6 text-xl font-bold text-[#262626]">No Audits Found</h2>
        <p className="mt-2 text-sm tracking-wide text-[#9A9A9A]">Try Changing The Month Or Generating</p>
        <button type="button" onClick={onGenerate} className="mt-6 min-h-9 rounded-full border border-[#0386FF] px-7 text-sm font-medium text-[#0386FF]">
          Generate Now
        </button>
      </div>
    </div>
  );
}

function TeacherAuditTable({ audits }: { audits: TeacherAuditRecord[] }) {
  return (
    <div className="p-4 lg:p-6">
      <div className="overflow-hidden rounded-lg border border-[#E5E7EB] bg-white">
        <table className="w-full min-w-[780px] text-left text-sm">
          <thead className="bg-[#F8FAFC] text-xs uppercase tracking-wide text-[#64748B]">
            <tr>
              <th className="px-4 py-3">Teacher</th>
              <th className="px-4 py-3">Month</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Score</th>
              <th className="px-4 py-3">Hours</th>
              <th className="px-4 py-3">Payment</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#EEF2F7]">
            {audits.map((audit) => (
              <tr key={audit.id}>
                <td className="px-4 py-3">
                  <div className="font-semibold text-[#111827]">{audit.teacherName}</div>
                  <div className="text-xs text-[#64748B]">{audit.teacherEmail}</div>
                </td>
                <td className="px-4 py-3">{formatMonth(audit.yearMonth)}</td>
                <td className="px-4 py-3">{labelFor(audit.status)}</td>
                <td className="px-4 py-3">{audit.overallScore.toFixed(1)}%</td>
                <td className="px-4 py-3">{audit.totalWorkedHours.toFixed(2)}</td>
                <td className="px-4 py-3">${audit.totalPayment.toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function AdminAuditTable({ audits }: { audits: AdminAuditRecord[] }) {
  return (
    <div className="p-4 lg:p-6">
      <div className="overflow-hidden rounded-lg border border-[#E5E7EB] bg-white">
        <table className="w-full min-w-[680px] text-left text-sm">
          <thead className="bg-[#F8FAFC] text-xs uppercase tracking-wide text-[#64748B]">
            <tr>
              <th className="px-4 py-3">Admin</th>
              <th className="px-4 py-3">Month</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Score</th>
              <th className="px-4 py-3">Forms</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#EEF2F7]">
            {audits.map((audit) => (
              <tr key={audit.id}>
                <td className="px-4 py-3">
                  <div className="font-semibold text-[#111827]">{audit.adminName}</div>
                  <div className="text-xs text-[#64748B]">{audit.adminEmail}</div>
                </td>
                <td className="px-4 py-3">{formatMonth(audit.yearMonth)}</td>
                <td className="px-4 py-3">{labelFor(audit.status)}</td>
                <td className="px-4 py-3">{audit.score.toFixed(1)}%</td>
                <td className="px-4 py-3">{audit.formsCount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function AuditsAccessPrompt({ access }: { access: AccessState }) {
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
              ? "Sign in with an administrator account before managing audits."
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

async function loadTeacherAudits() {
  const snap = await getDocs(query(collection(db, "teacher_audits"), limit(500)));
  return snap.docs.map((docSnap) => normalizeTeacherAudit(docSnap.id, docSnap.data() as Record<string, unknown>)).sort(sortByMonthDesc);
}

async function loadAdminAudits() {
  const snap = await getDocs(query(collection(db, "admin_audits"), limit(500)));
  return snap.docs.map((docSnap) => normalizeAdminAudit(docSnap.id, docSnap.data() as Record<string, unknown>)).sort(sortByMonthDesc);
}

function normalizeTeacherAudit(id: string, data: Record<string, unknown>): TeacherAuditRecord {
  const paymentSummary = objectValue(data.paymentSummary);
  const netPayment = numberValue(paymentSummary.totalNetPayment);
  const grossPayment = numberValue(paymentSummary.totalGrossPayment);
  return {
    id,
    teacherName: stringValue(data.teacherName ?? data.teacher_name ?? data.name) || "Unknown Teacher",
    teacherEmail: stringValue(data.teacherEmail ?? data.teacher_email ?? data.email),
    yearMonth: stringValue(data.yearMonth ?? data.year_month) || currentMonthKey,
    status: stringValue(data.status ?? data.auditStatus) || "pending",
    overallScore: numberValue(data.overallScore ?? data.overall_score),
    totalPayment: netPayment > 0 ? netPayment : grossPayment,
    totalWorkedHours: numberValue(data.totalWorkedHours ?? data.total_worked_hours),
    updatedAt: dateValue(data.updatedAt ?? data.updated_at ?? data.createdAt ?? data.created_at),
  };
}

function normalizeAdminAudit(id: string, data: Record<string, unknown>): AdminAuditRecord {
  const formsBreakdown = objectValue(data.formsBreakdown ?? data.forms_breakdown);
  return {
    id,
    adminName: stringValue(data.adminName ?? data.admin_name ?? data.name) || "Unknown Admin",
    adminEmail: stringValue(data.adminEmail ?? data.admin_email ?? data.email),
    yearMonth: stringValue(data.yearMonth ?? data.year_month) || currentMonthKey,
    status: stringValue(data.status) || "pending",
    score: numberValue(data.score ?? data.overallScore ?? data.overall_score),
    formsCount: numberValue(data.formsCount ?? data.forms_count) || Object.values(formsBreakdown).reduce<number>((sum, value) => sum + numberValue(value), 0),
  };
}

function sortByMonthDesc(a: { yearMonth: string }, b: { yearMonth: string }) {
  return b.yearMonth.localeCompare(a.yearMonth);
}

function isPendingAudit(status: string) {
  const normalized = status.toLowerCase();
  return normalized.includes("pending") || normalized.includes("submitted");
}

function monthKey(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

function monthOptions(values: string[]) {
  const normalized = values.filter((value) => /^\d{4}-\d{2}$/.test(value));
  return Array.from(new Set(normalized.length ? normalized : [currentMonthKey])).sort((a, b) => b.localeCompare(a));
}

function formatMonth(value: string) {
  const [year, month] = value.split("-").map(Number);
  if (!year || !month) return value || "Current Month";
  return new Date(year, month - 1, 1).toLocaleDateString("en-US", { month: "short", year: "numeric" });
}

function labelFor(value: string) {
  return value.replace(/^AuditStatus\./, "").replace(/([A-Z])/g, " $1").replace(/^./, (letter) => letter.toUpperCase());
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

function objectValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function numberValue(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value.replace(/[$,]/g, ""));
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Admin";
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}
