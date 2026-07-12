"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, doc, getDoc, getDocs, query, where } from "firebase/firestore";
import { AlertTriangle, BarChart3, CalendarDays, Clock3, Download, FileText, Menu, RefreshCw } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";
import { auth, db } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type AuditData = Record<string, unknown> & { id: string };
type Tab = "Overview" | "Classes" | "Clock-ins" | "Forms";

export function TeacherReportPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [summary, setSummary] = useState({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [audits, setAudits] = useState<AuditData[]>([]);
  const [month, setMonth] = useState(currentMonth());
  const [tab, setTab] = useState<Tab>("Overview");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => onAuthStateChanged(auth, async (nextUser) => {
    setUser(nextUser);
    if (!nextUser) {
      setAccess("signedOut");
      setLoading(false);
      return;
    }
    const allowed = await isCurrentUserTeacher(nextUser);
    if (!allowed) {
      setAccess("denied");
      setLoading(false);
      return;
    }
    const record = await getCurrentUserRecord(nextUser);
    const displayName = stringValue(record?.fullName ?? record?.displayName) || nextUser.displayName || nextUser.email || "Teacher";
    const words = displayName.trim().split(/\s+/);
    setSummary({ displayName, firstName: words[0] || "Teacher", initials: words.slice(0, 2).map((word) => word[0]).join("").toUpperCase() || "TE" });
    setAccess("allowed");
    await loadAudits(nextUser.uid, setAudits, setMonth, setError, setLoading);
  }), []);

  const audit = useMemo(() => audits.find((item) => stringValue(item.yearMonth) === month) ?? null, [audits, month]);
  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <TeacherShell activeLabel="My Report" breadcrumb="Reports / My Report" summary={summary}>
      <div className="min-h-full bg-[#F8FAFC]">
        <div className="flex items-center gap-3 border-b border-[#E2E8F0] bg-white px-4 py-3 lg:hidden">
          <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl"><Menu size={22} /></button>
          <div><p className="text-sm text-[#64748B]">Reports</p><p className="font-bold text-[#111827]">My Performance Audit</p></div>
        </div>
        <div className="mx-auto max-w-7xl p-4 sm:p-6 lg:p-8">
          <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
            <div><h1 className="text-2xl font-extrabold text-[#111827]">My Performance Audit</h1><p className="mt-1 text-sm text-[#64748B]">Review your monthly classes, punctuality, forms, and performance.</p></div>
            <div className="flex items-center gap-2">
              {audits.length ? <select aria-label="Report month" value={month} onChange={(event) => setMonth(event.target.value)} className="h-11 rounded-xl border border-[#CBD5E1] bg-white px-3 font-semibold text-[#334155]">{audits.map((item) => { const value = stringValue(item.yearMonth); return <option key={item.id} value={value}>{monthLabel(value)}</option>; })}</select> : null}
              <button type="button" aria-label="Refresh report" disabled={loading || !user} onClick={() => user && void loadAudits(user.uid, setAudits, setMonth, setError, setLoading, month)} className="grid h-11 w-11 place-items-center rounded-xl border border-[#CBD5E1] bg-white text-[#0386FF] disabled:opacity-50"><RefreshCw size={18} className={loading ? "animate-spin" : ""} /></button>
            </div>
          </div>

          {error ? <div role="alert" className="mb-5 flex items-start gap-3 rounded-2xl border border-red-200 bg-red-50 p-4 text-red-800"><AlertTriangle className="mt-0.5 shrink-0" size={20} /><div><p className="font-bold">Could not load your report</p><p className="text-sm">{error}</p></div></div> : null}
          {loading ? <div className="grid min-h-72 place-items-center"><RefreshCw className="animate-spin text-[#0386FF]" /></div> : !audit ? <EmptyReport month={month} /> : (
            <>
              <div role="tablist" aria-label="Report sections" className="mb-5 grid grid-cols-2 gap-2 rounded-2xl border border-[#E2E8F0] bg-white p-2 sm:grid-cols-4">
                {(["Overview", "Classes", "Clock-ins", "Forms"] as Tab[]).map((item) => { const Icon = item === "Overview" ? BarChart3 : item === "Classes" ? CalendarDays : item === "Clock-ins" ? Clock3 : FileText; return <button key={item} type="button" role="tab" aria-selected={tab === item} onClick={() => setTab(item)} className={`flex min-h-11 items-center justify-center gap-2 rounded-xl px-3 text-sm font-bold ${tab === item ? "bg-[#EAF4FF] text-[#0386FF]" : "text-[#64748B] hover:bg-[#F8FAFC]"}`}><Icon size={17} />{item}</button>; })}
              </div>
              {tab === "Overview" ? <Overview audit={audit} onExport={() => exportAuditCsv(audit)} /> : <DetailTable tab={tab} audit={audit} />}
            </>
          )}
        </div>
      </div>
    </TeacherShell>
  );
}

function Overview({ audit, onExport }: { audit: AuditData; onExport: () => void }) {
  const score = numberValue(audit.overallScore);
  const tier = stringValue(audit.performanceTier) || (score >= 90 ? "Excellent" : score >= 75 ? "Good" : score >= 60 ? "Fair" : "Needs Improvement");
  const stats = [
    ["Classes", `${numberValue(audit.totalClassesCompleted)}/${numberValue(audit.totalClassesScheduled)}`],
    ["On-Time", `${numberValue(audit.onTimeClockIns)}/${numberValue(audit.totalClockIns)}`],
    ["Worked hours", numberValue(audit.totalWorkedHours).toFixed(2)],
    ["Forms", `${numberValue(audit.readinessFormsSubmitted)}/${numberValue(audit.readinessFormsRequired)}`],
    ["Issues", String(arrayValue(audit.issues).length)],
    ["Late", String(numberValue(audit.lateClockIns))],
  ];
  return <div className="space-y-5">
    <section className="rounded-3xl bg-gradient-to-br from-[#0386FF] to-[#0E72ED] p-7 text-center text-white shadow-lg"><p className="text-5xl font-black">{score.toFixed(1)}%</p><p className="mt-2 text-lg font-bold uppercase tracking-[0.2em]">{tier}</p><p className="mt-1 text-sm text-white/75">{monthLabel(stringValue(audit.yearMonth))}</p></section>
    <section><h2 className="mb-3 text-lg font-extrabold text-[#111827]">Score Breakdown</h2><div className="grid gap-3 sm:grid-cols-3"><RateCard label="Completion" value={numberValue(audit.completionRate)} weight="40%" /><RateCard label="Punctuality" value={numberValue(audit.punctualityRate)} weight="35%" /><RateCard label="Form Compliance" value={numberValue(audit.formComplianceRate)} weight="25%" /></div></section>
    <section><h2 className="mb-3 text-lg font-extrabold text-[#111827]">Quick Stats</h2><div className="grid grid-cols-2 gap-3 sm:grid-cols-3">{stats.map(([label, value]) => <div key={label} className="rounded-2xl border border-[#E2E8F0] bg-white p-4"><p className="text-sm text-[#64748B]">{label}</p><p className="mt-1 text-xl font-extrabold text-[#111827]">{value}</p></div>)}</div></section>
    {arrayValue(audit.issues).length ? <section><h2 className="mb-3 text-lg font-extrabold text-[#111827]">Issues to Address</h2><div className="space-y-2">{arrayValue(audit.issues).map((raw, index) => { const item = objectValue(raw); return <div key={index} className="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">{stringValue(item.description) || "Performance issue"}</div>; })}</div></section> : null}
    <button type="button" onClick={onExport} className="flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-[#0E72ED] px-5 font-bold text-white"><Download size={19} />Download My Teaching Data (CSV)</button>
  </div>;
}

function RateCard({ label, value, weight }: { label: string; value: number; weight: string }) {
  const safe = Math.max(0, Math.min(100, value));
  return <div className="rounded-2xl border border-[#E2E8F0] bg-white p-4"><div className="flex justify-between"><p className="font-bold text-[#334155]">{label}</p><span className="text-xs text-[#94A3B8]">{weight}</span></div><p className="mt-2 text-2xl font-extrabold text-[#111827]">{safe.toFixed(1)}%</p><div className="mt-3 h-2 overflow-hidden rounded-full bg-[#E2E8F0]"><div className="h-full rounded-full bg-[#0386FF]" style={{ width: `${safe}%` }} /></div></div>;
}

function DetailTable({ tab, audit }: { tab: Exclude<Tab, "Overview">; audit: AuditData }) {
  const rows = tab === "Classes" ? arrayValue(audit.detailedShifts) : tab === "Clock-ins" ? arrayValue(audit.detailedTimesheets) : arrayValue(audit.detailedForms);
  return <section className="overflow-hidden rounded-2xl border border-[#E2E8F0] bg-white"><div className="border-b border-[#E2E8F0] px-5 py-4"><h2 className="font-extrabold text-[#111827]">{tab}</h2></div>{rows.length ? <div className="divide-y divide-[#E2E8F0]">{rows.map((raw, index) => { const row = objectValue(raw); const title = stringValue(row.title ?? row.shift_name ?? row.formTitle ?? row.form_title ?? row.subject) || `${tab.slice(0, -1)} ${index + 1}`; const status = stringValue(row.status ?? row.clock_status) || "Recorded"; const date = dateLabel(row.shift_start ?? row.created_at ?? row.submittedAt ?? row.clock_in_time); return <div key={index} className="flex flex-wrap items-center justify-between gap-3 px-5 py-4"><div><p className="font-bold text-[#334155]">{title}</p><p className="text-sm text-[#64748B]">{date || "Date unavailable"}</p></div><span className="rounded-full bg-[#F1F5F9] px-3 py-1 text-xs font-bold capitalize text-[#475569]">{status}</span></div>; })}</div> : <p className="p-8 text-center text-[#64748B]">No {tab.toLowerCase()} recorded for this month.</p>}</section>;
}

function EmptyReport({ month }: { month: string }) { return <div className="grid min-h-80 place-items-center rounded-3xl border border-dashed border-[#CBD5E1] bg-white p-8 text-center"><div><BarChart3 className="mx-auto text-[#CBD5E1]" size={60} /><h2 className="mt-4 text-lg font-extrabold text-[#334155]">No audit data for {monthLabel(month)}</h2><p className="mt-2 text-sm text-[#64748B]">Your performance data will appear here when a monthly report is available.</p></div></div>; }

async function loadAudits(uid: string, setAudits: (items: AuditData[]) => void, setMonth: (month: string) => void, setError: (value: string) => void, setLoading: (value: boolean) => void, preferred?: string) {
  setLoading(true); setError("");
  try {
    const [legacy, current, direct] = await Promise.all([
      getDocs(query(collection(db, "teacher_audits"), where("oderId", "==", uid))),
      getDocs(query(collection(db, "teacher_audits"), where("userId", "==", uid))),
      getDoc(doc(db, "teacher_audits", `${uid}_${currentMonth()}`)),
    ]);
    const map = new Map<string, AuditData>();
    [...legacy.docs, ...current.docs].forEach((item) => map.set(item.id, { id: item.id, ...item.data() }));
    if (direct.exists()) map.set(direct.id, { id: direct.id, ...direct.data() });
    const items = Array.from(map.values()).sort((a, b) => stringValue(b.yearMonth).localeCompare(stringValue(a.yearMonth)));
    setAudits(items);
    const months = items.map((item) => stringValue(item.yearMonth));
    setMonth(preferred && months.includes(preferred) ? preferred : months.includes(currentMonth()) ? currentMonth() : months[0] || currentMonth());
  } catch (cause) { setError(cause instanceof Error ? cause.message : "Please check your connection and try again."); }
  finally { setLoading(false); }
}

function exportAuditCsv(audit: AuditData) {
  const rows = [["Metric", "Value"], ["Month", stringValue(audit.yearMonth)], ["Overall Score", numberValue(audit.overallScore)], ["Completion Rate", numberValue(audit.completionRate)], ["Punctuality Rate", numberValue(audit.punctualityRate)], ["Form Compliance Rate", numberValue(audit.formComplianceRate)], ["Classes Scheduled", numberValue(audit.totalClassesScheduled)], ["Classes Completed", numberValue(audit.totalClassesCompleted)], ["Worked Hours", numberValue(audit.totalWorkedHours)], ["Late Clock-ins", numberValue(audit.lateClockIns)]];
  const csv = rows.map((row) => row.map((cell) => `"${String(cell).replaceAll('"', '""')}"`).join(",")).join("\n");
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  const anchor = document.createElement("a"); anchor.href = url; anchor.download = `teacher-report-${stringValue(audit.yearMonth) || "report"}.csv`; anchor.click(); URL.revokeObjectURL(url);
}

function currentMonth() { const date = new Date(); return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`; }
function monthLabel(value: string) { const match = /^(\d{4})-(\d{2})$/.exec(value); return match ? new Intl.DateTimeFormat("en", { month: "long", year: "numeric" }).format(new Date(Number(match[1]), Number(match[2]) - 1, 1)) : value || "Selected month"; }
function stringValue(value: unknown) { return typeof value === "string" ? value.trim() : value == null ? "" : String(value); }
function numberValue(value: unknown) { const parsed = typeof value === "number" ? value : Number(value); return Number.isFinite(parsed) ? parsed : 0; }
function arrayValue(value: unknown): unknown[] { return Array.isArray(value) ? value : []; }
function objectValue(value: unknown): Record<string, unknown> { return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {}; }
function dateLabel(value: unknown) { const object = objectValue(value); const raw = typeof object.toDate === "function" ? (object.toDate as () => Date)() : value instanceof Date ? value : typeof value === "string" || typeof value === "number" ? new Date(value) : null; return raw instanceof Date && !Number.isNaN(raw.getTime()) ? new Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(raw) : ""; }
