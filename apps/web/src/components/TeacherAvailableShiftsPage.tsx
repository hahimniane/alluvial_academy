"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, orderBy, query, Timestamp, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useState } from "react";
import { CalendarDays, Clock, Menu, RefreshCw, UserRound, Users, X } from "lucide-react";
import { auth, db, functions } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";
import { dateLocale, tr } from "@/lib/i18n";
import { canClaimShift, isLeadershipDuty, tradeSentence, type ShiftTrade } from "@/lib/shiftTrading";
import { loadTeacherTrades } from "@/lib/shiftTradingClient";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type TeacherSummary = { displayName: string; firstName: string; initials: string };

export type OfferedShift = {
  id: string;
  title: string;
  subject: string;
  studentNames: string[];
  start: Date;
  end: Date;
  offeredBy: string;
  teacherId: string;
  category: string;
};

const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");

export function normalizeOfferedShift(id: string, data: Record<string, unknown>): OfferedShift | null {
  const start = data.shift_start instanceof Timestamp ? data.shift_start.toDate() : null;
  const end = data.shift_end instanceof Timestamp ? data.shift_end.toDate() : null;
  if (!start || !end) return null;
  const subject = str(data.subject_display_name) || str(data.subject);
  return {
    id,
    title: str(data.custom_name) || str(data.auto_generated_name) || subject || "Class",
    subject,
    studentNames: Array.isArray(data.student_names) ? data.student_names.map(str).filter(Boolean) : [],
    start,
    end,
    offeredBy: str(data.original_teacher_name) || str(data.teacher_name),
    teacherId: str(data.teacher_id),
    category: str(data.shift_category),
  };
}


async function loadOfferedShifts(uid: string) {
  const snap = await getDocs(
    query(
      collection(db, "teaching_shifts"),
      where("is_published", "==", true),
      where("status", "==", "scheduled"),
      where("shift_start", ">=", Timestamp.now()),
      orderBy("shift_start"),
      limit(100),
    ),
  );
  const shifts = snap.docs
    .map((entry) => normalizeOfferedShift(entry.id, entry.data() as Record<string, unknown>))
    .filter((shift): shift is OfferedShift => shift !== null);
  const now = new Date();
  // A leadership duty goes to a leader; teachers here only take classes.
  return shifts.filter((shift) => !isLeadershipDuty(shift.category) && canClaimShift({ isPublished: true, status: "scheduled", start: shift.start, teacherId: shift.teacherId }, uid, now));
}

export function claimErrorMessage(error: unknown) {
  const code = typeof error === "object" && error && "code" in error ? String((error as { code: unknown }).code) : "";
  const message = error instanceof Error ? error.message : "";
  if (code.endsWith("failed-precondition")) {
    // The server explains a clash with the teacher's own class by name.
    return message && message.startsWith("You already have") ? message : tr("This shift is no longer available to claim.");
  }
  if (code.endsWith("already-exists")) return tr("You are already assigned to this shift.");
  if (code.endsWith("not-found")) return tr("This shift could not be found.");
  if (code.endsWith("unauthenticated")) return tr("Please sign in again, then try claiming.");
  if (code.endsWith("permission-denied")) return tr("You do not have permission to claim shifts. Ask an admin.");
  return tr("Could not claim this shift. Try again.");
}

function summaryFor(user: User, data: Record<string, unknown> | null): TeacherSummary {
  const full = data ? [str(data.first_name), str(data.last_name)].filter(Boolean).join(" ") : "";
  const name = full || user.displayName?.trim() || user.email?.replace(/@.*/, "") || "Teacher";
  const initials = name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase() ?? "").join("") || "TE";
  return { displayName: name, firstName: name.split(/\s+/)[0] || "Teacher", initials };
}

function formatDay(date: Date) {
  return date.toLocaleDateString(dateLocale(), { weekday: "long", month: "short", day: "numeric" });
}

function formatTime(date: Date) {
  return date.toLocaleTimeString(dateLocale(), { hour: "numeric", minute: "2-digit" });
}

function formatWhen(date: Date) {
  return date.toLocaleString(dateLocale(), { weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
}

function formatHappened(date: Date) {
  return date.toLocaleString(dateLocale(), { month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" });
}

function hours(shift: OfferedShift) {
  return `${Math.max(0, (shift.end.getTime() - shift.start.getTime()) / 36e5).toFixed(1)} hrs`;
}

export function TeacherAvailableShiftsPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [user, setUser] = useState<User | null>(null);
  const [shifts, setShifts] = useState<OfferedShift[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [confirming, setConfirming] = useState<OfferedShift | null>(null);
  const [claiming, setClaiming] = useState(false);
  const [claimError, setClaimError] = useState("");
  const [notice, setNotice] = useState("");
  // null until the record has been read (and when it cannot be).
  const [trades, setTrades] = useState<ShiftTrade[] | null>(null);

  const refresh = useCallback(async (uid: string) => {
    setLoading(true);
    setLoadError("");
    // The record is a side note to the list: when it cannot be read the page
    // keeps what it had and still shows the classes on offer.
    void loadTeacherTrades(uid).then(setTrades).catch(() => undefined);
    try {
      setShifts(await loadOfferedShifts(uid));
    } catch {
      setLoadError(tr("Could not load available shifts. Try again."));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let mounted = true;
    const stop = onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      if (!nextUser) {
        setUser(null);
        setAccess("signedOut");
        return;
      }
      setUser(nextUser);
      setAccess("checking");
      try {
        if (!(await isCurrentUserTeacher(nextUser))) {
          if (mounted) setAccess("denied");
          return;
        }
        const record = await getCurrentUserRecord(nextUser);
        if (!mounted) return;
        setSummary(summaryFor(nextUser, record as Record<string, unknown> | null));
        setAccess("allowed");
        void refresh(nextUser.uid);
      } catch {
        if (mounted) setAccess("denied");
      }
    });
    return () => {
      mounted = false;
      stop();
    };
  }, [refresh]);

  const claim = async () => {
    if (!confirming || !user) return;
    setClaiming(true);
    setClaimError("");
    try {
      await httpsCallable(functions, "claimShift")({ shiftId: confirming.id });
      setConfirming(null);
      setNotice(tr("Shift claimed. It is now in My Shifts."));
      window.setTimeout(() => setNotice(""), 4000);
      void refresh(user.uid);
    } catch (error) {
      setClaimError(claimErrorMessage(error));
    } finally {
      setClaiming(false);
    }
  };

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <TeacherShell activeLabel="Available Shifts" breadcrumb="Work / Available Shifts" summary={summary}>
      <main className="min-h-[calc(100vh-56px)] overflow-y-auto bg-[#F1F5F9] text-[#111827]">
        <header className="grid min-h-[68px] grid-cols-[56px_1fr_56px] items-center bg-white px-4 lg:hidden">
          <button type="button" aria-label={tr("Open teacher menu")} onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
            <Menu size={28} />
          </button>
          <div className="min-w-0 text-center text-[20px] font-black text-[#111827]">{tr("Alluwal Education Hub")}</div>
          <span className="grid h-11 w-11 place-items-center rounded-full bg-[#009688] text-base font-black text-white">{summary.initials}</span>
        </header>
        <section className="mx-auto max-w-3xl px-4 pb-20 pt-5 lg:pb-8">
          <div className="flex items-start justify-between gap-3">
            <div>
              <h1 className="text-[24px] font-black leading-tight text-[#111827]">{tr("Available Shifts")}</h1>
              <p className="mt-1 text-sm text-[#64748B]">{tr("Classes other teachers offered. Claim one to add it to My Shifts.")}</p>
            </div>
            <button
              type="button"
              onClick={() => user && void refresh(user.uid)}
              aria-label={tr("Refresh")}
              className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-white text-[#0386FF] shadow-sm"
            >
              <RefreshCw size={18} className={loading ? "animate-spin" : ""} />
            </button>
          </div>

          {notice ? <p className="mt-4 rounded-xl bg-green-50 px-4 py-3 text-sm font-semibold text-green-700">{notice}</p> : null}
          {loadError ? <p className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">{loadError}</p> : null}

          {loading && !shifts.length ? (
            <p className="mt-8 text-center text-sm text-[#64748B]">{tr("Loading...")}</p>
          ) : !shifts.length && !loadError ? (
            <div className="mt-8 rounded-2xl bg-white p-8 text-center shadow-sm">
              <CalendarDays className="mx-auto text-[#94A3B8]" size={36} />
              <p className="mt-3 text-base font-black text-[#1E293B]">{tr("No Available Shifts")}</p>
              <p className="mt-1 text-sm text-[#64748B]">{tr("When a teacher offers a class, it shows up here.")}</p>
            </div>
          ) : (
            <div className="mt-5 grid gap-3">
              {shifts.map((shift) => (
                <article key={shift.id} className="rounded-2xl border-l-4 border-[#10B981] bg-white p-4 shadow-[0_4px_12px_rgba(100,116,139,0.08)]">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h2 className="text-base font-black text-[#1E293B]">{shift.studentNames.join(", ") || shift.title}</h2>
                      <p className="mt-0.5 text-sm font-medium text-[#64748B]">{shift.subject || shift.title}</p>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        setClaimError("");
                        setConfirming(shift);
                      }}
                      className="shrink-0 rounded-lg bg-[#10B981] px-4 py-2 text-sm font-bold text-white hover:bg-[#059669]"
                    >
                      {tr("Claim")}
                    </button>
                  </div>
                  <div className="mt-3 grid gap-1.5 text-sm text-[#475569]">
                    <p className="inline-flex items-center gap-2"><CalendarDays size={15} className="text-[#94A3B8]" />{formatDay(shift.start)}</p>
                    <p className="inline-flex items-center gap-2"><Clock size={15} className="text-[#94A3B8]" />{formatTime(shift.start)} - {formatTime(shift.end)} · {hours(shift)}</p>
                    {shift.offeredBy ? <p className="inline-flex items-center gap-2"><UserRound size={15} className="text-[#94A3B8]" />{tr("Offered by {name}", { name: shift.offeredBy })}</p> : null}
                    {shift.studentNames.length > 1 ? <p className="inline-flex items-center gap-2"><Users size={15} className="text-[#94A3B8]" />{tr("{count} students", { count: String(shift.studentNames.length) })}</p> : null}
                  </div>
                </article>
              ))}
            </div>
          )}

          {trades ? (
            <section aria-labelledby="your-trades" className="mt-8">
              <h2 id="your-trades" className="text-base font-black text-[#1E293B]">{tr("Your trades")}</h2>
              {!trades.length ? (
                <p className="mt-2 text-sm text-[#64748B]">{tr("Classes you offer or take are listed here.")}</p>
              ) : (
                <ul className="mt-3 divide-y divide-[#F1F5F9] rounded-2xl bg-white px-4 shadow-sm">
                  {trades.map((trade) => {
                    const sentence = tradeSentence(trade, user?.uid ?? "");
                    return (
                      <li key={trade.id} className="py-3">
                        <p className="text-sm font-semibold text-[#334155]">
                          {tr(sentence.text, { class: sentence.vars.class || tr("a class"), name: sentence.vars.name })}
                          {trade.shiftStart ? <span className="font-medium text-[#64748B]"> – {formatWhen(trade.shiftStart)}</span> : null}
                        </p>
                        {trade.createdAt ? <p className="mt-0.5 text-xs text-[#94A3B8]">{formatHappened(trade.createdAt)}</p> : null}
                      </li>
                    );
                  })}
                </ul>
              )}
            </section>
          ) : null}
        </section>

        {confirming ? (
          <div className="fixed inset-0 z-50 grid place-items-center bg-black/45 px-4">
            <section role="dialog" aria-modal="true" aria-labelledby="claim-title" className="w-full max-w-[420px] rounded-2xl bg-white p-5 shadow-xl">
              <div className="flex items-center justify-between gap-3">
                <h2 id="claim-title" className="text-lg font-black text-[#1E293B]">{tr("Claim Shift")}</h2>
                <button type="button" onClick={() => setConfirming(null)} aria-label={tr("Close")} className="grid h-8 w-8 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]"><X size={17} /></button>
              </div>
              <p className="mt-3 text-sm text-[#334155]">
                {tr("You will teach {class} on {day}, {time}.", {
                  class: confirming.studentNames.join(", ") || confirming.title,
                  day: formatDay(confirming.start),
                  time: `${formatTime(confirming.start)} - ${formatTime(confirming.end)}`,
                })}
              </p>
              {claimError ? <p className="mt-3 rounded-xl bg-red-50 px-3 py-2 text-sm font-semibold text-red-700">{claimError}</p> : null}
              <div className="mt-5 flex justify-end gap-3">
                <button type="button" onClick={() => setConfirming(null)} className="rounded-xl px-4 py-2 text-sm font-bold text-[#64748B]">{tr("Cancel")}</button>
                <button type="button" onClick={claim} disabled={claiming} className="rounded-xl bg-[#10B981] px-5 py-2 text-sm font-bold text-white disabled:bg-[#86EFAC]">
                  {claiming ? tr("Claiming...") : tr("Claim Shift")}
                </button>
              </div>
            </section>
          </div>
        ) : null}
      </main>
    </TeacherShell>
  );
}
