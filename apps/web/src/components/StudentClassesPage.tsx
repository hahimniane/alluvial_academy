"use client";

import { onAuthStateChanged } from "firebase/auth";
import { collection, doc, getDoc, onSnapshot, query, Timestamp, where } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import { Loader2, Lock, Radio, Video, VideoOff } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";
import { dateLocale, useT } from "@/lib/i18n";

type AccessState = "checking" | "signedOut" | "denied" | "allowed";

type ClassRecord = {
  id: string;
  name: string;
  teacherName: string;
  start: Date | null;
  end: Date | null;
  status: string;
  hasVideoCall: boolean;
  isClockedIn: boolean;
};

/**
 * Joining happens inside this app at /student/classroom/.
 *
 * It calls the same callables the Flutter app does — getZoomJoinInfo, or
 * getRealtimeKitJoinToken — and passes returnUrl=/student/classes/, so leaving
 * the meeting comes back here instead of stranding the student on the Flutter
 * dashboard.
 */
const joinHref = (shiftId: string) => `/student/classroom/?shiftId=${encodeURIComponent(shiftId)}`;

/** ClassVideoService.canJoinClass: 10 minutes before start until 10 after end. */
const JOIN_OPENS_MS = 10 * 60 * 1000;
const JOIN_CLOSES_MS = 10 * 60 * 1000;

function canJoin(item: ClassRecord, now: number) {
  if (!item.hasVideoCall || !item.start || !item.end) return false;
  return now >= item.start.getTime() - JOIN_OPENS_MS && now <= item.end.getTime() + JOIN_CLOSES_MS;
}

function isLive(item: ClassRecord) {
  return item.status.toLowerCase() === "active" || item.isClockedIn;
}

/** Finished and past its join window — belongs in Past, not the main view. */
function isEnded(item: ClassRecord, now: number) {
  return !isLive(item) && !canJoin(item, now) && item.end !== null && item.end.getTime() < now;
}

export default function StudentClassesPage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [classes, setClasses] = useState<ClassRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [suspended, setSuspended] = useState(false);
  const t = useT();
  const [now, setNow] = useState(() => Date.now());
  const [tab, setTab] = useState<"upcoming" | "past">("upcoming");

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
      // Suspension changes server-side (an unpaid invoice suspends; paying
      // restores). The cached session freezes it, so read it fresh here — a
      // student who just paid should not have to sign out to regain access.
      getDoc(doc(db, "users", nextUser.uid))
        .then((snap) => {
          const data = (snap.data() ?? {}) as Record<string, unknown>;
          setSuspended(data.access_suspended === true || data.accessSuspended === true);
        })
        .catch(() => setSuspended(session.accessSuspended));
      setAccess("allowed");
    });
  }, []);

  // Join windows open and close on the minute, so the buttons re-evaluate.
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 30_000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    const uid = auth.currentUser?.uid;
    if (access !== "allowed" || !uid) return;
    // Two days back so a class that ended within the last 24h (and may have
    // started yesterday) is still fetched for the Past tab.
    const lowerBound = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000);

    return onSnapshot(
      query(
        collection(db, "teaching_shifts"),
        where("student_ids", "array-contains", uid),
        where("shift_start", ">=", Timestamp.fromDate(lowerBound)),
      ),
      (snap) => {
        setClasses(
          snap.docs
            .map((entry) => normalizeClass(entry.id, entry.data() as Record<string, unknown>))
            .filter((item) => item.status.toLowerCase() !== "cancelled")
            .sort((a, b) => (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0)),
        );
        setLoading(false);
      },
      () => setLoading(false),
    );
  }, [access]);

  const { today, upcoming, past } = useMemo(() => {
    const endOfToday = new Date();
    endOfToday.setHours(23, 59, 59, 999);
    const dayAgo = now - 24 * 60 * 60 * 1000;

    // Ended = finished and no longer joinable. Kept out of the main view and
    // shown in Past only for 24h after they end.
    const notEnded = classes.filter((item) => !isEnded(item, now));
    const recentlyEnded = classes
      .filter((item) => isEnded(item, now) && item.end !== null && item.end.getTime() >= dayAgo)
      .sort((a, b) => (b.end?.getTime() ?? 0) - (a.end?.getTime() ?? 0)); // most recent first

    return {
      today: notEnded.filter((item) => item.start && item.start.getTime() <= endOfToday.getTime()),
      upcoming: notEnded.filter((item) => item.start && item.start.getTime() > endOfToday.getTime()),
      past: recentlyEnded,
    };
  }, [classes, now]);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  return (
    <StudentShell activeLabel="Classes" breadcrumb="Learning / Classes" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="mx-auto w-full max-w-[1180px] px-4 py-6 md:px-6">
        <h1 className="text-center text-2xl font-black text-[#0F172A]">{t("My Classes")}</h1>

        {suspended ? (
          <p className="mx-auto mt-4 flex max-w-xl items-center justify-center gap-2 rounded-2xl bg-[#FEF2F2] px-4 py-3 text-center text-sm font-bold text-[#B91C1C]">
            <Lock size={16} />
            {t("Class Access Suspended")}
          </p>
        ) : null}

        {loading ? (
          <div className="grid min-h-[45vh] place-items-center text-[#64748B]">
            <span className="inline-flex items-center gap-2 text-sm font-bold">
              <Loader2 className="animate-spin" size={18} />
              {t("Loading your classes…")}
            </span>
          </div>
        ) : classes.length === 0 ? (
          <div className="grid min-h-[45vh] place-items-center text-center">
            <div>
              <span className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-[#DBEAFE] text-[#2563EB]">
                <VideoOff size={34} />
              </span>
              <h2 className="mt-5 text-xl font-black text-[#0F172A]">{t("No Classes Right Now")}</h2>
              <p className="mt-1 text-sm font-semibold text-[#64748B]">{t("Your Scheduled Classes Will Appear Here")}</p>
            </div>
          </div>
        ) : (
          <>
            <div className="mt-5 grid grid-cols-2 overflow-hidden rounded-xl border border-[#E2E8F0] bg-white">
              {(["upcoming", "past"] as const).map((key) => (
                <button
                  key={key}
                  type="button"
                  onClick={() => setTab(key)}
                  aria-pressed={tab === key}
                  className={`min-h-11 text-sm font-black capitalize transition ${
                    tab === key ? "bg-[#1D4ED8] text-white" : "text-[#64748B] hover:bg-[#F1F5F9]"
                  }`}
                >
                  {key === "upcoming" ? t("Upcoming") : t("Past")}
                  {key === "past" && past.length > 0 ? ` (${past.length})` : ""}
                </button>
              ))}
            </div>

            {tab === "upcoming" ? (
              today.length === 0 && upcoming.length === 0 ? (
                <EmptyClasses title={t("No upcoming classes")} subtitle={t("Your scheduled classes will appear here.")} />
              ) : (
                <div className="mt-6 grid gap-6">
                  {today.length > 0 ? <Section title={t("Today")} items={today} now={now} suspended={suspended} /> : null}
                  {upcoming.length > 0 ? <Section title={t("Upcoming Classes")} items={upcoming} now={now} suspended={suspended} /> : null}
                </div>
              )
            ) : past.length === 0 ? (
              <EmptyClasses title={t("No recent classes")} subtitle={t("Classes you attended in the last 24 hours appear here.")} />
            ) : (
              <div className="mt-6">
                <Section title={t("Last 24 hours")} items={past} now={now} suspended={suspended} />
              </div>
            )}
          </>
        )}
      </div>
    </StudentShell>
  );
}

function EmptyClasses({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div className="grid min-h-[40vh] place-items-center text-center">
      <div>
        <span className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-[#DBEAFE] text-[#2563EB]">
          <VideoOff size={34} />
        </span>
        <h2 className="mt-5 text-xl font-black text-[#0F172A]">{title}</h2>
        <p className="mt-1 text-sm font-semibold text-[#64748B]">{subtitle}</p>
      </div>
    </div>
  );
}

function Section({ title, items, now, suspended }: { title: string; items: ClassRecord[]; now: number; suspended: boolean }) {
  return (
    <section>
      <h2 className="mb-3 text-sm font-black uppercase tracking-[0.1em] text-[#94A3B8]">{title}</h2>
      <div className="grid gap-3">
        {items.map((item) => (
          <ClassCard key={item.id} item={item} now={now} suspended={suspended} />
        ))}
      </div>
    </section>
  );
}

function ClassCard({ item, now, suspended }: { item: ClassRecord; now: number; suspended: boolean }) {
  const t = useT();
  const live = item.status.toLowerCase() === "active" || item.isClockedIn;
  const joinable = canJoin(item, now);
  const open = item.hasVideoCall && (joinable || live);
  const minutesUntil = item.start ? Math.round((item.start.getTime() - now) / 60000) : null;
  // "Starting in 15 min" / "2h 30m" / "Tomorrow" / "In 3 days" — the live
  // countdown the Flutter card shows (_formatTimeUntil). Only for classes that
  // have not started; once joinable/live the status pill carries the state.
  // Flutter guards timeUntil with shiftStart.isAfter(now), so a class that has
  // already started (or finished earlier today) shows no countdown.
  const upcomingFuture = item.start !== null && item.start.getTime() > now;
  const countdown = !live && !joinable && upcomingFuture ? formatTimeUntil(item.start, now, t) : "";

  // Mirrors _ClassStatus in student_classes_screen.dart.
  // A class whose end has passed and is not live/joinable has finished — it must
  // not read "Starting now" (minutesUntil goes negative for past classes).
  const ended = !live && !joinable && item.end !== null && item.end.getTime() < now;
  const startingNow = !live && !joinable && minutesUntil !== null && minutesUntil >= 0 && minutesUntil <= 5;
  const status = live
    ? { text: "Live", color: "#10B981", bg: "#D1FAE5" }
    : joinable
      ? { text: "Join Now", color: "#0E72ED", bg: "#DBEAFE" }
      : ended
        ? { text: "Ended", color: "#94A3B8", bg: "#F1F5F9" }
        : startingNow
          ? { text: "Starting now", color: "#F59E0B", bg: "#FEF3C7" }
          : { text: "Upcoming", color: "#64748B", bg: "#F1F5F9" };

  return (
    <article className="flex flex-wrap items-center gap-4 rounded-2xl border border-black/5 bg-white px-4 py-4 shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-[#EFF6FF] text-[#2D8CFF]">
        {live ? <Radio size={20} /> : <Video size={20} />}
      </span>
      <div className="min-w-0 flex-1">
        <h3 className="truncate text-base font-black text-[#0F172A]">{item.name}</h3>
        <p className="mt-0.5 truncate text-xs font-semibold text-[#64748B]">
          {item.teacherName}
          {item.start ? ` · ${formatTime(item.start)}${item.end ? ` – ${formatTime(item.end)}` : ""}` : ""}
        </p>
        {countdown ? (
          <p className="mt-1 text-xs font-black" style={{ color: status.color }}>
            {countdown}
          </p>
        ) : null}
      </div>
      <span
        className="shrink-0 rounded-full px-3 py-1 text-[11px] font-black"
        style={{ backgroundColor: status.bg, color: status.color }}
      >
        {t(status.text)}
      </span>
      {open ? (
        suspended ? (
          <span className="inline-flex min-h-10 shrink-0 items-center gap-2 rounded-xl bg-[#FEF2F2] px-4 text-xs font-black text-[#B91C1C]">
            <Lock size={15} />
            {t("Suspended")}
          </span>
        ) : (
          <a
            href={joinHref(item.id)}
            className="inline-flex min-h-10 shrink-0 items-center gap-2 rounded-xl bg-[#0E72ED] px-4 text-sm font-black text-white hover:bg-[#0b5fc4]"
          >
            <Video size={16} />
            {t("Join")}
          </a>
        )
      ) : null}
    </article>
  );
}

function normalizeClass(id: string, data: Record<string, unknown>): ClassRecord {
  // TeachingShift.hasVideoCall is `category == teaching && studentIds.isNotEmpty`,
  // and the category is read from shift_category defaulting to 'teaching' when
  // absent — which it is on almost every document. Deriving this from a
  // video_provider field instead (as an earlier version did) hid the Join
  // button on any class whose document lacks that field.
  const category = stringValue(data.shift_category ?? data.shiftCategory) || "teaching";
  const studentIds = Array.isArray(data.student_ids) ? data.student_ids : [];
  return {
    id,
    name: stringValue(data.display_name) || stringValue(data.subject) || stringValue(data.shift_name) || "Class",
    teacherName: stringValue(data.teacher_name ?? data.teacherName) || "Your teacher",
    start: dateValue(data.shift_start ?? data.shiftStart),
    end: dateValue(data.shift_end ?? data.shiftEnd),
    status: stringValue(data.status),
    // A shift has a video call when a provider is set, matching shift.hasVideoCall.
    hasVideoCall: category === "teaching" && studentIds.length > 0,
    isClockedIn: data.is_clocked_in === true || data.isClockedIn === true,
  };
}

/** Mirrors _formatTimeUntil in student_classes_screen.dart. */
function formatTimeUntil(start: Date | null, now: number, t: (en: string, vars?: Record<string, string | number>) => string): string {
  if (!start) return "";
  const totalMinutes = Math.floor((start.getTime() - now) / 60000);
  if (totalMinutes <= 0) return t("Starting now");
  if (totalMinutes < 2) return t("Starting in 1 min");
  if (totalMinutes < 60) return t("Starting in {n} min", { n: totalMinutes });
  const totalHours = Math.floor(totalMinutes / 60);
  if (totalHours < 24) {
    const mins = totalMinutes % 60;
    return mins === 0 ? t("Starting in {h}h", { h: totalHours }) : t("Starting in {h}h {m}m", { h: totalHours, m: mins });
  }
  const days = Math.floor(totalMinutes / 1440);
  if (days === 1) return t("Tomorrow");
  if (days < 7) return t("In {n} days", { n: days });
  const weeks = Math.floor(days / 7);
  return weeks === 1 ? t("In {n} week", { n: weeks }) : t("In {n} weeks", { n: weeks });
}

function formatTime(value: Date) {
  return value.toLocaleTimeString(dateLocale(), { hour: "numeric", minute: "2-digit" });
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
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
