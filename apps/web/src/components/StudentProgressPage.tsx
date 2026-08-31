"use client";

import { onAuthStateChanged } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useState } from "react";
import { ChevronRight, Loader2, RefreshCw, X } from "lucide-react";
import { auth, functions } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { dateLocale, useT } from "@/lib/i18n";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type Period = "weekly" | "monthly";

/** One row of the class-by-class list: the exact class and what happened. */
type ClassStatus = "attended" | "late" | "left_early" | "missed" | "cancelled";
type ClassSession = { join: Date | null; leave: Date | null; minutes: number };
type ClassAttendance = {
  shiftId: string;
  start: Date | null;
  end: Date | null;
  subject: string;
  status: ClassStatus;
  joinOffsetMinutes: number | null;
  presenceMinutes: number;
  teacherOverlapMinutes: number;
  teacherPresent: boolean;
  joinCount: number;
  firstJoin: Date | null;
  lastLeave: Date | null;
  sessions: ClassSession[];
  teacherAbsent: boolean;
};

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
  classes: ClassAttendance[];
};

const EMPTY: Analytics = {
  hasReport: false,
  classes: [],
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
  const t = useT();
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [period, setPeriod] = useState<Period>("weekly");
  const [analytics, setAnalytics] = useState<Analytics>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [studentId, setStudentId] = useState("");
  const [selectedClass, setSelectedClass] = useState<ClassAttendance | null>(null);

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
            <h1 className="text-2xl font-black">{t("Progress")}</h1>
            <p className="mt-1 text-sm font-semibold text-white/85">
              {t("Attendance and punctuality insights for {name}", { name: summary.displayName })}
            </p>
          </div>
          <button
            type="button"
            onClick={() => void load(studentId, period, true)}
            aria-label={t("Refresh progress")}
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
              {t(option)}
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
              {t("Loading your progress…")}
            </span>
          </div>
        ) : !analytics.hasReport ? (
          <p className="mt-6 rounded-2xl border border-dashed border-[#CBD5E1] px-4 py-10 text-center text-sm font-semibold text-[#94A3B8]">
            {t("No attendance analytics yet. Attendance insights will appear once your class attendance is tracked.")}
          </p>
        ) : (
          <>
            <div className="mt-5 grid gap-4 sm:grid-cols-3">
              <Metric
                label={t("Your class time")}
                value={`${(analytics.totalPresenceMinutes / 60).toFixed(1)} h`}
                helper={period === "weekly" ? t("Weekly") : t("Monthly")}
                color="#7C3AED"
              />
              <Metric
                label={t("Attendance")}
                value={`${Math.round(analytics.attendanceRate * 100)}%`}
                helper={t("{done}/{total} classes", { done: analytics.attendedClasses, total: analytics.scheduledClasses })}
                color="#2563EB"
              />
              <Metric
                label={t("On Time")}
                value={`${Math.round(analytics.punctualityRate * 100)}%`}
                helper={t("{done}/{total} attended", { done: analytics.onTimeClasses, total: analytics.attendedClasses })}
                color="#10B981"
              />
            </div>

            <Section title={t("Class by class")}>
              {analytics.classes.length === 0 ? (
                <p className="text-sm font-semibold text-[#94A3B8]">{t("No class history in this period yet.")}</p>
              ) : (
                <div className="max-h-[440px] space-y-2 overflow-y-auto pr-1">
                  {analytics.classes.map((item) => (
                    <ClassRow
                      key={`${item.shiftId}-${item.start?.toISOString() ?? ""}`}
                      item={item}
                      t={t}
                      onSelect={() => setSelectedClass(item)}
                    />
                  ))}
                </div>
              )}
            </Section>

            <Section title={t("Class Status Breakdown")}>
              <div className="grid gap-3 sm:grid-cols-4">
                <Tally label={t("On Time")} value={analytics.onTimeClasses} color="#2563EB" />
                <Tally label={t("Late")} value={analytics.lateClasses} color="#F59E0B" />
                <Tally label={t("Absent")} value={analytics.absentClasses} color="#EF4444" />
                <Tally label={t("Attended")} value={analytics.attendedClasses} color="#10B981" />
              </div>
            </Section>

            <Section title={t("Additional Information")}>
              <dl className="grid gap-y-3">
                <Row label={t("Arrived before start (classes)")} value={`${analytics.arrivedBeforeStartClasses}`} />
                <Row label={t("Joined before start (events)")} value={`${analytics.joinsBeforeStartEvents}`} />
                <Row label={t("Student present / teacher absent")} value={`${analytics.teacherAbsentIncidents}`} />
                <Row label={t("Average join offset")} value={t("{n} min", { n: analytics.averageJoinOffsetMinutes.toFixed(1) })} />
                <Row label={t("Presence coverage")} value={`${Math.round(analytics.presenceCoverageRate * 100)}%`} />
                <Row label={t("Teacher overlap")} value={`${Math.round(analytics.teacherOverlapRate * 100)}%`} />
                <Row label={t("Total presence minutes")} value={analytics.totalPresenceMinutes.toFixed(1)} />
                <Row label={t("Teacher overlap minutes")} value={analytics.totalOverlapMinutes.toFixed(1)} />
                <Row label={t("Late rate")} value={`${Math.round(analytics.lateRate * 100)}%`} />
              </dl>
            </Section>
          </>
        )}
      </div>
      <ClassDetailDialog item={selectedClass} onClose={() => setSelectedClass(null)} t={t} />
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

  // Per-class breakdown: the exact classes and whether the student joined,
  // was late, or missed each one. Most recent first.
  const breakdown = Array.isArray(report.shift_breakdown) ? report.shift_breakdown : [];
  const classes: ClassAttendance[] = breakdown
    .map((entry) => {
      const item = asMap(entry);
      const cancelled = item.cancelled === true || item.status === "cancelled";
      const attended = item.attended === true;
      const late = item.late === true;
      const presenceMinutes = asDouble(item.student_presence_minutes) ?? 0;
      const joinEvents = asInt(item.join_events);
      // The server applies the minimum-presence rule to `attended`. A class the
      // student did open but left before that threshold is "left early" — not
      // "missed", which is reserved for classes they never joined at all.
      const joinedAtAll = presenceMinutes > 0 || joinEvents > 0 || asDouble(item.first_join_offset_minutes) !== null;
      const status: ClassStatus = cancelled
        ? "cancelled"
        : attended
          ? (late ? "late" : "attended")
          : joinedAtAll
            ? "left_early"
            : "missed";
      const sessions: ClassSession[] = (Array.isArray(item.sessions) ? item.sessions : [])
        .map((raw) => {
          const w = asMap(raw);
          return {
            join: parseDate(w.join_iso),
            leave: parseDate(w.leave_iso),
            minutes: asDouble(w.minutes) ?? 0,
          };
        });
      return {
        shiftId: stringValue(item.shift_id),
        start: parseDate(item.shift_start_iso),
        end: parseDate(item.shift_end_iso),
        subject: stringValue(item.subject),
        status,
        joinOffsetMinutes: asDouble(item.first_join_offset_minutes),
        presenceMinutes,
        teacherOverlapMinutes: asDouble(item.teacher_overlap_minutes) ?? 0,
        teacherPresent: item.teacher_present === true,
        joinCount: joinEvents,
        firstJoin: parseDate(item.first_join_iso),
        lastLeave: parseDate(item.last_leave_iso),
        sessions,
        teacherAbsent: item.student_present_teacher_absent === true,
      };
    })
    .sort((a, b) => (b.start?.getTime() ?? 0) - (a.start?.getTime() ?? 0));

  return {
    hasReport: true,
    classes,
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

type Translate = (en: string, vars?: Record<string, string | number>) => string;

function ClassRow({
  item,
  t,
  onSelect,
}: {
  item: ClassAttendance;
  t: Translate;
  onSelect: () => void;
}) {
  const styles: Record<ClassStatus, { label: string; bg: string; fg: string; dot: string }> = {
    attended: { label: t("Attended"), bg: "bg-[#DCFCE7]", fg: "text-[#166534]", dot: "#16A34A" },
    late: { label: t("Late"), bg: "bg-[#FEF3C7]", fg: "text-[#92400E]", dot: "#F59E0B" },
    left_early: { label: t("Left early"), bg: "bg-[#FEF3C7]", fg: "text-[#92400E]", dot: "#F97316" },
    missed: { label: t("Missed"), bg: "bg-[#FEE2E2]", fg: "text-[#B91C1C]", dot: "#EF4444" },
    cancelled: { label: t("Cancelled"), bg: "bg-[#F1F5F9]", fg: "text-[#64748B]", dot: "#94A3B8" },
  };
  const s = styles[item.status];
  const when = item.start
    ? `${item.start.toLocaleDateString(dateLocale(), { weekday: "short", month: "short", day: "numeric" })} · ${item.start.toLocaleTimeString(dateLocale(), { hour: "numeric", minute: "2-digit" })}`
    : "";

  let detail = "";
  if (item.status === "attended" || item.status === "late") {
    const off = item.joinOffsetMinutes;
    if (off == null) detail = t("Joined");
    else if (Math.round(off) > 0) detail = t("Joined {n} min late", { n: Math.round(off) });
    else if (Math.round(off) < 0) detail = t("Joined {n} min early", { n: Math.abs(Math.round(off)) });
    else detail = t("Joined on time");
  } else if (item.status === "left_early") {
    detail = t("Joined {n} min, left early", { n: Math.max(1, Math.round(item.presenceMinutes)) });
  } else if (item.status === "missed") {
    detail = t("Did not join");
  }

  return (
    <button
      type="button"
      onClick={onSelect}
      className="flex w-full items-center gap-3 rounded-xl border border-[#E2E8F0] bg-white px-3 py-2.5 text-left transition hover:border-[#CBD5E1] hover:bg-[#F8FAFC]"
    >
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full" style={{ backgroundColor: `${s.dot}1A` }}>
        <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: s.dot }} />
      </span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-black text-[#0F172A]">{item.subject || t("Class")}</div>
        <div className="truncate text-xs font-semibold text-[#64748B]">
          {when}
          {detail ? ` · ${detail}` : ""}
          {item.teacherAbsent ? ` · ${t("Teacher didn't join")}` : ""}
        </div>
      </div>
      <span className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-black ${s.bg} ${s.fg}`}>{s.label}</span>
      <ChevronRight size={16} className="shrink-0 text-[#CBD5E1]" />
    </button>
  );
}

function ClassDetailDialog({ item, onClose, t }: { item: ClassAttendance | null; onClose: () => void; t: Translate }) {
  useEffect(() => {
    if (!item) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [item, onClose]);

  if (!item) return null;
  const fmtDate = (d: Date | null) =>
    d ? d.toLocaleDateString(dateLocale(), { weekday: "long", month: "long", day: "numeric" }) : "—";
  const fmtTime = (d: Date | null) =>
    d ? d.toLocaleTimeString(dateLocale(), { hour: "numeric", minute: "2-digit" }) : "—";
  const fmtMins = (m: number) => {
    const total = Math.max(0, Math.round(m));
    if (total < 60) return t("{n} min", { n: total });
    const h = Math.floor(total / 60);
    const min = total % 60;
    return min ? `${t("{n} h", { n: h })} ${t("{n} min", { n: min })}` : t("{n} h", { n: h });
  };

  return (
    <div className="fixed inset-0 z-[100] grid place-items-end bg-black/40 sm:place-items-center sm:p-6" role="dialog" aria-modal="true" aria-label={t("Class details")}>
      <button type="button" aria-label={t("Cancel")} onClick={onClose} className="absolute inset-0 cursor-default" />
      <section className="relative max-h-[90vh] w-full overflow-y-auto rounded-t-3xl bg-white p-5 shadow-2xl sm:max-w-lg sm:rounded-2xl">
        <header className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 className="text-lg font-black text-[#0F172A]">{item.subject || t("Class")}</h2>
            <p className="mt-0.5 text-xs font-semibold text-[#64748B]">
              {fmtDate(item.start)}
              {item.start ? ` · ${fmtTime(item.start)}` : ""}
              {item.end ? ` – ${fmtTime(item.end)}` : ""}
            </p>
          </div>
          <button type="button" aria-label={t("Cancel")} onClick={onClose} className="grid h-9 w-9 shrink-0 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={19} />
          </button>
        </header>

        <dl className="mt-4 grid grid-cols-2 gap-2">
          <Stat label={t("First joined")} value={fmtTime(item.firstJoin)} />
          <Stat label={t("Last left")} value={fmtTime(item.lastLeave)} />
          <Stat label={t("Time in class")} value={fmtMins(item.presenceMinutes)} />
          <Stat label={t("Time with teacher")} value={fmtMins(item.teacherOverlapMinutes)} />
          <Stat label={t("Times joined")} value={`${item.joinCount}`} />
          <Stat label={t("Teacher present")} value={item.teacherPresent ? t("Yes") : t("No")} />
        </dl>

        <h3 className="mt-5 text-sm font-black text-[#0F172A]">{t("Sessions")}</h3>
        {item.sessions.length === 0 ? (
          <p className="mt-2 text-sm font-semibold text-[#94A3B8]">{t("This student never joined this class.")}</p>
        ) : (
          <ol className="mt-2 space-y-2">
            {item.sessions.map((session, index) => (
              <li key={index} className="flex items-center gap-3 rounded-xl bg-[#F8FAFC] px-3 py-2.5">
                <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-[#DBEAFE] text-xs font-black text-[#1D4ED8]">
                  {index + 1}
                </span>
                <div className="min-w-0 flex-1 text-sm font-bold text-[#0F172A]">
                  {fmtTime(session.join)} <span className="text-[#94A3B8]">→</span> {fmtTime(session.leave)}
                </div>
                <span className="shrink-0 text-xs font-black text-[#64748B]">{fmtMins(session.minutes)}</span>
              </li>
            ))}
          </ol>
        )}
        {item.sessions.length > 1 ? (
          <p className="mt-2 text-xs font-semibold text-[#64748B]">
            {item.sessions.length === 2
              ? t("Left and rejoined once")
              : t("Left and rejoined {n} times", { n: item.sessions.length - 1 })}
          </p>
        ) : null}
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-[#E2E8F0] bg-white px-3 py-2.5">
      <dt className="text-[11px] font-black uppercase tracking-wide text-[#94A3B8]">{label}</dt>
      <dd className="mt-0.5 text-sm font-black text-[#0F172A]">{value}</dd>
    </div>
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

function parseDate(value: unknown): Date | null {
  if (typeof value !== "string" || !value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
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
