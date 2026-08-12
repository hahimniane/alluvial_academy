"use client";

import { onAuthStateChanged } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useState } from "react";
import { Loader2, RefreshCw } from "lucide-react";
import { auth, functions } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type Period = "weekly" | "monthly";

/**
 * Same numbers as the Flutter Progress screen, from the same source: the
 * getStudentAttendanceReport callable. Its permission check allows
 * `uid === studentId`, so a student may pull their own report — unlike
 * getAdminStudentAttendanceOverview, which is admin-only.
 *
 * Field names and the derived-rate fallbacks mirror _loadAnalytics in
 * lib/features/student/screens/student_progress_screen.dart so both clients
 * show identical figures.
 */
type Analytics = {
  hasReport: boolean;
  scheduledClasses: number;
  attendedClasses: number;
  absentClasses: number;
  lateClasses: number;
  onTimeClasses: number;
  arrivedBeforeStartClasses: number;
  teacherAbsentIncidents: number;
  joinsBeforeStartEvents: number;
  totalPresenceMinutes: number;
  totalOverlapMinutes: number;
  attendanceRate: number;
  punctualityRate: number;
  lateRate: number;
  presenceCoverageRate: number;
  teacherOverlapRate: number;
  averageJoinOffsetMinutes: number;
};

const EMPTY: Analytics = {
  hasReport: false,
  scheduledClasses: 0,
  attendedClasses: 0,
  absentClasses: 0,
  lateClasses: 0,
  onTimeClasses: 0,
  arrivedBeforeStartClasses: 0,
  teacherAbsentIncidents: 0,
  joinsBeforeStartEvents: 0,
  totalPresenceMinutes: 0,
  totalOverlapMinutes: 0,
  attendanceRate: 0,
  punctualityRate: 0,
  lateRate: 0,
  presenceCoverageRate: 0,
  teacherOverlapRate: 0,
  averageJoinOffsetMinutes: 0,
};

export default function StudentProgressPage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [period, setPeriod] = useState<Period>("weekly");
  const [analytics, setAnalytics] = useState<Analytics>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [studentId, setStudentId] = useState("");

  const load = useCallback(async (uid: string, nextPeriod: Period, forceRefresh = false) => {
    if (!uid) return;
    setLoading(true);
    setLoadError("");
    try {
      setAnalytics(await fetchAnalytics(uid, nextPeriod, forceRefresh));
    } catch (error) {
      setAnalytics(EMPTY);
      setLoadError(error instanceof Error ? error.message : "Could not load your progress.");
    } finally {
      setLoading(false);
    }
  }, []);

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
      setStudentId(nextUser.uid);
      await load(nextUser.uid, period, false);
    });
    // `period` is deliberately not a dependency: changing it re-fetches through
    // the toggle handler rather than re-subscribing to auth.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [load]);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  const changePeriod = (next: Period) => {
    setPeriod(next);
    void load(studentId, next, false);
  };

  return (
    <StudentShell activeLabel="Progress" breadcrumb="Learning / Progress" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="mx-auto w-full max-w-[1180px] px-4 py-6 md:px-6">
        {/* Navy gradient banner and full-width segmented toggle, as in the
            Flutter Progress screen. */}
        <header className="flex items-start justify-between gap-4 rounded-2xl bg-[linear-gradient(120deg,#1E3A8A_0%,#2563EB_100%)] px-6 py-5 text-white">
          <div className="min-w-0">
            <h1 className="text-2xl font-black">Progress</h1>
            <p className="mt-1 text-sm font-semibold text-white/85">
              Attendance and punctuality insights for {summary.displayName}
            </p>
          </div>
          <button
            type="button"
            onClick={() => void load(studentId, period, true)}
            aria-label="Refresh progress"
            className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-white/15 text-white hover:bg-white/25"
          >
            <RefreshCw size={17} />
          </button>
        </header>

        <div className="mt-4 grid grid-cols-2 overflow-hidden rounded-xl border border-[#E2E8F0] bg-white">
          {(["weekly", "monthly"] as Period[]).map((option) => (
            <button
              key={option}
              type="button"
              onClick={() => changePeriod(option)}
              aria-pressed={period === option}
              className={`min-h-11 text-sm font-black capitalize transition ${
                period === option ? "bg-[#1E293B] text-white" : "text-[#64748B] hover:bg-[#F1F5F9]"
              }`}
            >
              {option}
            </button>
          ))}
        </div>

        {loadError ? (
          <p className="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-bold text-red-700">{loadError}</p>
        ) : null}

        {loading ? (
          <div className="grid min-h-[40vh] place-items-center text-[#64748B]">
            <span className="inline-flex items-center gap-2 text-sm font-bold">
              <Loader2 className="animate-spin" size={18} />
              Loading your progress…
            </span>
          </div>
        ) : !analytics.hasReport ? (
          <p className="mt-6 rounded-2xl border border-dashed border-[#CBD5E1] px-4 py-10 text-center text-sm font-semibold text-[#94A3B8]">
            No attendance analytics yet. Attendance insights will appear once your class attendance is tracked.
          </p>
        ) : (
          <>
            <div className="mt-5 grid gap-4 sm:grid-cols-3">
              <Metric
                label="Your class time"
                value={`${(analytics.totalPresenceMinutes / 60).toFixed(1)} h`}
                helper={period === "weekly" ? "Weekly" : "Monthly"}
                color="#7C3AED"
              />
              <Metric
                label="Attendance"
                value={`${Math.round(analytics.attendanceRate * 100)}%`}
                helper={`${analytics.attendedClasses}/${analytics.scheduledClasses} classes`}
                color="#2563EB"
              />
              <Metric
                label="On Time"
                value={`${Math.round(analytics.punctualityRate * 100)}%`}
                helper={`${analytics.onTimeClasses}/${analytics.attendedClasses} attended`}
                color="#10B981"
              />
            </div>

            <Section title="Class Status Breakdown">
              <div className="grid gap-3 sm:grid-cols-4">
                <Tally label="On Time" value={analytics.onTimeClasses} color="#2563EB" />
                <Tally label="Late" value={analytics.lateClasses} color="#F59E0B" />
                <Tally label="Absent" value={analytics.absentClasses} color="#EF4444" />
                <Tally label="Attended" value={analytics.attendedClasses} color="#10B981" />
              </div>
            </Section>

            <Section title="Additional Information">
              <dl className="grid gap-y-3">
                <Row label="Arrived before start (classes)" value={`${analytics.arrivedBeforeStartClasses}`} />
                <Row label="Joined before start (events)" value={`${analytics.joinsBeforeStartEvents}`} />
                <Row label="Student present / teacher absent" value={`${analytics.teacherAbsentIncidents}`} />
                <Row label="Average join offset" value={`${analytics.averageJoinOffsetMinutes.toFixed(1)} min`} />
                <Row label="Presence coverage" value={`${Math.round(analytics.presenceCoverageRate * 100)}%`} />
                <Row label="Teacher overlap" value={`${Math.round(analytics.teacherOverlapRate * 100)}%`} />
                <Row label="Total presence minutes" value={analytics.totalPresenceMinutes.toFixed(1)} />
                <Row label="Teacher overlap minutes" value={analytics.totalOverlapMinutes.toFixed(1)} />
                <Row label="Late rate" value={`${Math.round(analytics.lateRate * 100)}%`} />
              </dl>
            </Section>
          </>
        )}
      </div>
    </StudentShell>
  );
}

async function fetchAnalytics(studentId: string, periodType: Period, forceRefresh: boolean): Promise<Analytics> {
  const callable = httpsCallable(functions, "getStudentAttendanceReport");
  const result = await callable({ studentId, periodType, forceRefresh });

  // The callable answers { success, report: { metrics, rates, averages } } —
  // the metrics are nested under `report`, not at the top level. Reading
  // result.data.metrics silently yields {} and renders every figure as zero.
  const envelope = asMap(result.data);
  if (envelope.success !== true) return EMPTY;
  const report = asMap(envelope.report);
  if (Object.keys(report).length === 0) return EMPTY;

  const metrics = asMap(report.metrics);
  const rates = asMap(report.rates);
  const averages = asMap(report.averages);

  const scheduledClasses = asInt(metrics.scheduled_classes);
  const attendedClasses = asInt(metrics.attended_classes);
  const lateClasses = asInt(metrics.late_classes);
  const onTimeClasses = asInt(metrics.on_time_classes);

  // Same fallbacks the Flutter screen uses when the server omits a rate.
  const attendanceRate = asDouble(rates.attendance_rate) ?? (scheduledClasses > 0 ? attendedClasses / scheduledClasses : 0);
  const punctualityRate = asDouble(rates.punctuality_rate) ?? (attendedClasses > 0 ? onTimeClasses / attendedClasses : 0);
  const lateRate = asDouble(rates.late_rate) ?? (attendedClasses > 0 ? lateClasses / attendedClasses : 0);

  return {
    hasReport: true,
    scheduledClasses,
    attendedClasses,
    absentClasses: asInt(metrics.absent_classes),
    lateClasses,
    onTimeClasses,
    arrivedBeforeStartClasses: asInt(metrics.arrived_before_start_classes),
    teacherAbsentIncidents: asInt(metrics.student_present_teacher_absent_classes),
    joinsBeforeStartEvents: asInt(metrics.total_joins_before_start_events),
    totalPresenceMinutes: asDouble(metrics.total_student_presence_minutes) ?? 0,
    totalOverlapMinutes: asDouble(metrics.total_teacher_overlap_minutes) ?? 0,
    attendanceRate: clamp01(attendanceRate),
    punctualityRate: clamp01(punctualityRate),
    lateRate: clamp01(lateRate),
    presenceCoverageRate: clamp01(asDouble(rates.presence_coverage_rate) ?? 0),
    teacherOverlapRate: clamp01(asDouble(rates.teacher_overlap_rate) ?? 0),
    averageJoinOffsetMinutes: asDouble(averages.average_join_offset_minutes) ?? 0,
  };
}

function Metric({ label, value, helper, color }: { label: string; value: string; helper: string; color: string }) {
  return (
    <div className="rounded-2xl border border-black/5 bg-white p-5 shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
      <div className="text-xs font-black uppercase tracking-[0.1em] text-[#94A3B8]">{label}</div>
      <div className="mt-2 text-[34px] font-black leading-none" style={{ color }}>
        {value}
      </div>
      <div className="mt-2 text-xs font-semibold text-[#64748B]">{helper}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mt-5 rounded-2xl border border-black/5 bg-white p-5 shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
      <h2 className="mb-4 text-sm font-black text-[#0F172A]">{title}</h2>
      {children}
    </section>
  );
}

function Tally({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="rounded-xl border border-black/5 bg-[#F8FAFC] px-3 py-4 text-center">
      <div className="text-[26px] font-black leading-none" style={{ color }}>
        {value}
      </div>
      <div className="mt-1.5 text-xs font-bold text-[#64748B]">{label}</div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-dashed border-[#E2E8F0] pb-2">
      <dt className="text-xs font-semibold text-[#64748B]">{label}</dt>
      <dd className="text-sm font-black text-[#0F172A]">{value}</dd>
    </div>
  );
}

function asMap(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function asInt(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.round(parsed) : 0;
}

function asDouble(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function clamp01(value: number) {
  return Math.min(Math.max(value, 0), 1);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "ST";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
