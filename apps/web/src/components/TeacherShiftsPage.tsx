"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { addDoc, collection, doc, getDocs, limit, query, serverTimestamp, Timestamp, updateDoc, where, writeBatch } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  Calendar,
  CalendarCheck,
  CalendarDays,
  Clock,
  ChevronLeft,
  ChevronRight,
  Grid2X2,
  Info,
  List,
  Menu,
  PanelTop,
  Settings,
  Shuffle,
  Timer,
  X,
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type TeacherShift = {
  id: string;
  title: string;
  studentNames: string[];
  start: Date | null;
  end: Date | null;
  status: string;
  subject: string;
  teacherName: string;
  teacherId: string;
  hourlyRate: number;
  clockInTime: Date | null;
  clockOutTime: Date | null;
};

export function TeacherShiftsPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [shifts, setShifts] = useState<TeacherShift[]>([]);
  const [loading, setLoading] = useState(true);
  const [anchorDate, setAnchorDate] = useState(() => new Date());
  const [viewMode, setViewMode] = useState<"grid" | "list">("list");
  const [rangeMode, setRangeMode] = useState<"day" | "week" | "month">("week");
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [selectedShift, setSelectedShift] = useState<TeacherShift | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [issueShift, setIssueShift] = useState<TeacherShift | null>(null);
  const [timezoneOpen, setTimezoneOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const [clockBusyShiftId, setClockBusyShiftId] = useState<string | null>(null);

  const showNotice = (message: string) => {
    setNotice(message);
    window.setTimeout(() => setNotice(""), 3000);
  };

  const handleClockAction = async (shift: TeacherShift) => {
    if (!currentUser || clockBusyShiftId) return;
    setClockBusyShiftId(shift.id);
    try {
      const action = clockAction(shift);
      if (action.kind === "disabled") {
        showNotice(action.disabledMessage);
        return;
      }
      const location = await getBrowserLocation(action.kind === "clockIn");
      const result = action.kind === "clockOut"
        ? await clockOutOfShift(currentUser, shift, location)
        : await clockInToShift(currentUser, shift, location);
      showNotice(result.message);
      const loaded = await loadTeacherShifts(currentUser.uid);
      setShifts(loaded);
      setSelectedShift((current) => current ? loaded.find((nextShift) => nextShift.id === current.id) ?? current : current);
    } catch (error) {
      showNotice(error instanceof Error ? error.message : "Could not update this shift.");
    } finally {
      setClockBusyShiftId(null);
    }
  };

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      if (!nextUser) {
        setCurrentUser(null);
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setCurrentUser(nextUser);
      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserTeacher(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        const userRecord = await getCurrentUserRecord(nextUser);
        if (!mounted) return;
        setSummary(summaryForUser(nextUser, userRecord));
        setAccess("allowed");
        const loaded = await loadTeacherShifts(nextUser.uid);
        if (mounted) setShifts(loaded);
      } catch {
        if (mounted) setAccess("denied");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const weekStart = useMemo(() => startOfWeekSunday(anchorDate), [anchorDate]);
  const weekDays = useMemo(() => Array.from({ length: 7 }, (_, index) => addDays(weekStart, index)), [weekStart]);
  const weekEnd = useMemo(() => addDays(weekStart, 7), [weekStart]);
  const weekShifts = useMemo(
    () => shifts.filter((shift) => shift.start && shift.start >= weekStart && shift.start < weekEnd),
    [shifts, weekEnd, weekStart],
  );
  const dayShifts = useMemo(
    () => shifts.filter((shift) => isSameDay(shift.start, anchorDate)),
    [anchorDate, shifts],
  );
  const monthDays = useMemo(() => buildMonthDays(anchorDate), [anchorDate]);
  const activeSessionShift = useMemo(() => findActiveSessionShift(shifts), [shifts]);

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <TeacherShell activeLabel="My Shifts" breadcrumb="Work / My Shifts" summary={summary}>
      <main className="min-h-[calc(100vh-56px)] overflow-y-auto bg-[#F1F5F9] text-[#111827]">
        <MobileTeacherTopBar summary={summary} />
        <ScheduleToolbar
          rangeMode={rangeMode}
          onRangeModeChange={setRangeMode}
          summary={summary}
          onSettings={() => setSettingsOpen(true)}
        />

        <section className="px-3 pb-20 pt-0 lg:px-3 lg:pb-8">
          {activeSessionShift ? (
            <ActiveSessionCard
              shift={activeSessionShift}
              busy={clockBusyShiftId === activeSessionShift.id}
              onView={setSelectedShift}
              onClockAction={handleClockAction}
            />
          ) : null}
          <div className="py-3">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
              <h1 className="text-[22px] font-black leading-tight text-[#111827] lg:text-[22px]">Weekly Calendar</h1>
              <p className="mt-1 text-[13px] font-medium leading-5 text-[#64748B] lg:text-[13px]">
                Grid shows three days at a time; list shows your agenda.
              </p>
              </div>
              <ViewModeToggle value={viewMode} onChange={setViewMode} />
            </div>
          </div>

          {rangeMode === "day" ? (
            <DaySchedule anchorDate={anchorDate} shifts={dayShifts} loading={loading} onSelectDate={setAnchorDate} onSelectShift={setSelectedShift} onClockAction={handleClockAction} clockBusyShiftId={clockBusyShiftId} />
          ) : rangeMode === "month" ? (
            <MonthSchedule days={monthDays} anchorDate={anchorDate} shifts={shifts} loading={loading} onSelectDate={(date) => { setAnchorDate(date); setRangeMode("day"); }} onSelectShift={setSelectedShift} />
          ) : (
            <>
              <WeekNavigator
                weekStart={weekStart}
                onPrevious={() => setAnchorDate(addDays(anchorDate, -7))}
                onToday={() => setAnchorDate(new Date())}
                onNext={() => setAnchorDate(addDays(anchorDate, 7))}
              />

              {viewMode === "list" ? (
                <WeeklyList days={weekDays} shifts={weekShifts} loading={loading} onSelectShift={setSelectedShift} />
              ) : (
                <WeeklyGrid days={weekDays.slice(0, 3)} shifts={weekShifts} loading={loading} onSelectShift={setSelectedShift} />
              )}
            </>
          )}
        </section>
        {notice ? <div className="fixed bottom-5 right-5 z-50 rounded-xl bg-[#111827] px-4 py-3 text-sm font-semibold text-white shadow-lg">{notice}</div> : null}
        {selectedShift ? (
          <ShiftDetailsDialog
            shift={selectedShift}
            busy={clockBusyShiftId === selectedShift.id}
            onClockAction={handleClockAction}
            onClose={() => setSelectedShift(null)}
            onReportIssue={() => {
              setIssueShift(selectedShift);
              setSelectedShift(null);
            }}
          />
        ) : null}
        {settingsOpen ? (
          <ScheduleSettingsDialog
            shifts={dayShifts}
            onClose={() => setSettingsOpen(false)}
            onReportShift={(shift) => {
              setSettingsOpen(false);
              setIssueShift(shift);
            }}
            onTimezoneOnly={() => {
              setSettingsOpen(false);
              setTimezoneOpen(true);
            }}
          />
        ) : null}
        {issueShift && currentUser ? (
          <ReportScheduleIssueDialog
            shift={issueShift}
            user={currentUser}
            onClose={() => setIssueShift(null)}
            onSubmitted={(message) => {
              showNotice(message);
            }}
          />
        ) : null}
        {timezoneOpen && currentUser ? (
          <TimezoneDialog
            user={currentUser}
            onClose={() => setTimezoneOpen(false)}
            onSaved={(message) => {
              showNotice(message);
            }}
          />
        ) : null}
      </main>
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-[68px] grid-cols-[56px_1fr_96px] items-center bg-white px-4 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={28} />
      </button>
      <div className="min-w-0 text-center text-[20px] font-black text-[#111827]">Alluwal Academy</div>
      <div className="flex items-center justify-end gap-3">
        <Shuffle size={24} className="text-[#111827]" />
        <span className="grid h-11 w-11 place-items-center rounded-full bg-[#009688] text-base font-black text-white">{summary.initials}</span>
      </div>
    </header>
  );
}

function ScheduleToolbar({
  rangeMode,
  onRangeModeChange,
  onSettings,
}: {
  rangeMode: "day" | "week" | "month";
  onRangeModeChange: (mode: "day" | "week" | "month") => void;
  summary: TeacherSummary;
  onSettings: () => void;
}) {
  return (
    <div className="flex min-h-[88px] items-center gap-2 bg-white px-3 lg:min-h-14 lg:border-b lg:border-black/5">
      <Link href="/teacher/" aria-label="Back to teacher dashboard" className="grid h-11 w-11 shrink-0 place-items-center rounded-xl text-[#475569] hover:bg-[#F8FAFC]">
        <ArrowLeft size={24} />
      </Link>
      <h1 className="min-w-0 flex-1 truncate text-[21px] font-black text-[#111827] lg:text-[22px]">Schedule</h1>
      <div className="flex shrink-0 items-center gap-1 lg:gap-2">
        <RangeButton icon={PanelTop} label="Day" active={rangeMode === "day"} onClick={() => onRangeModeChange("day")} />
        <RangeButton icon={List} label="Week" active={rangeMode === "week"} onClick={() => onRangeModeChange("week")} />
        <RangeButton icon={CalendarDays} label="Month" active={rangeMode === "month"} onClick={() => onRangeModeChange("month")} />
        <button type="button" aria-label="Schedule settings" onClick={onSettings} className="grid h-11 w-11 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
          <Settings size={22} />
        </button>
      </div>
    </div>
  );
}

function RangeButton({
  icon: Icon,
  label,
  active,
  onClick,
}: {
  icon: typeof PanelTop;
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex min-h-10 items-center gap-1.5 rounded-lg px-2 text-sm font-black lg:px-3 ${
        active ? "bg-[#0D8BFF] text-white shadow-sm" : "text-[#64748B] hover:bg-[#F1F5F9]"
      }`}
    >
      <Icon size={18} />
      <span>{label}</span>
    </button>
  );
}

function ActiveSessionCard({
  shift,
  busy,
  onView,
  onClockAction,
}: {
  shift: TeacherShift;
  busy: boolean;
  onView: (shift: TeacherShift) => void;
  onClockAction: (shift: TeacherShift) => void;
}) {
  const action = clockAction(shift);
  const isActive = action.kind === "clockOut";
  return (
    <article
      className={`mt-3 rounded-[20px] p-5 text-white shadow-[0_8px_15px_rgba(14,114,237,0.3)] ${
        isActive ? "bg-gradient-to-br from-[#10B981] to-[#059669]" : "bg-gradient-to-br from-[#0E72ED] to-[#0386FF]"
      }`}
    >
      <div className="flex items-center gap-3">
        <span className="grid h-9 w-9 place-items-center rounded-lg bg-white/20">
          {isActive ? <Clock size={20} /> : <Timer size={20} />}
        </span>
        <p className="min-w-0 flex-1 text-sm font-semibold text-white/90">{isActive ? "Active Session" : "Upcoming Session"}</p>
        <span className="rounded-full bg-white/20 px-3 py-1 text-[10px] font-black uppercase">{isActive ? "In Progress" : "Ready"}</span>
      </div>
      <h2 className="mt-4 line-clamp-2 text-lg font-bold">{shift.studentNames.join(", ") || shift.title}</h2>
      <p className="mt-2 text-sm text-white/80">{formatTimeRange(shift.start, shift.end)}</p>
      <div className="mt-4 grid grid-cols-2 gap-3">
        <button
          type="button"
          onClick={() => onView(shift)}
          className="min-h-11 rounded-xl border border-white bg-transparent text-sm font-semibold text-white hover:bg-white/10"
        >
          View Session
        </button>
        <button
          type="button"
          disabled={busy || action.kind === "disabled"}
          onClick={() => onClockAction(shift)}
          className={`inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-white text-sm font-semibold ${
            isActive ? "text-[#EF4444]" : "text-[#0E72ED]"
          } disabled:opacity-70`}
        >
          <Clock size={18} />
          {busy ? "Updating..." : action.kind === "clockOut" ? "Clock Out" : "Clock In"}
        </button>
      </div>
    </article>
  );
}

function ViewModeToggle({ value, onChange }: { value: "grid" | "list"; onChange: (value: "grid" | "list") => void }) {
  return (
    <div className="inline-grid w-fit grid-cols-2 rounded-2xl border border-[#E2E8F0] bg-white p-1 shadow-sm">
      <button
        type="button"
        onClick={() => onChange("grid")}
        className={`inline-flex min-h-9 items-center justify-center gap-2 rounded-xl px-3 text-sm font-black ${
          value === "grid" ? "bg-[#E6F3FF] text-[#0386FF]" : "text-[#94A3B8]"
        }`}
      >
        <Grid2X2 size={18} />
        Grid
      </button>
      <button
        type="button"
        onClick={() => onChange("list")}
        className={`inline-flex min-h-9 items-center justify-center gap-2 rounded-xl px-3 text-sm font-black ${
          value === "list" ? "bg-[#DDEEFF] text-[#0386FF]" : "text-[#94A3B8]"
        }`}
      >
        <List size={18} />
        List
      </button>
    </div>
  );
}

function WeekNavigator({
  weekStart,
  onPrevious,
  onToday,
  onNext,
}: {
  weekStart: Date;
  onPrevious: () => void;
  onToday: () => void;
  onNext: () => void;
}) {
  return (
    <div className="mb-3 grid min-h-10 grid-cols-[1fr_80px_1fr] items-center rounded-xl border border-[#DDE6F0] bg-white shadow-sm">
      <button type="button" aria-label="Previous week" onClick={onPrevious} className="grid h-10 place-items-center rounded-l-xl text-[#475569] hover:bg-[#F8FAFC]">
        <ChevronLeft size={24} />
      </button>
      <button type="button" aria-label={`Current week ${formatWeekRange(weekStart)}`} onClick={onToday} className="mx-auto grid h-10 w-12 place-items-center rounded-full bg-[#DFF0FF] text-[#0386FF]">
        <CalendarCheck size={24} />
      </button>
      <button type="button" aria-label="Next week" onClick={onNext} className="grid h-10 place-items-center rounded-r-xl text-[#475569] hover:bg-[#F8FAFC]">
        <ChevronRight size={24} />
      </button>
    </div>
  );
}

function WeeklyList({ days, shifts, loading, onSelectShift }: { days: Date[]; shifts: TeacherShift[]; loading: boolean; onSelectShift: (shift: TeacherShift) => void }) {
  const hasShifts = shifts.length > 0;
  const firstDay = days[0];
  return (
    <section className="min-h-[590px] rounded-2xl bg-white shadow-sm lg:min-h-[828px]">
      <div className="border-b border-[#EEF2F7] px-6 py-7 text-center lg:hidden">
        <h2 className="text-[22px] font-medium text-[#9CA3AF]">{formatWeekRange(firstDay)}</h2>
      </div>
      {loading ? (
        <div className="grid min-h-[360px] place-items-center text-sm font-bold text-[#64748B]">Loading schedule...</div>
      ) : hasShifts ? (
        <div className="divide-y divide-[#EEF2F7]">
          {days.map((day) => (
            <DayAgenda key={day.toISOString()} day={day} shifts={shifts.filter((shift) => isSameDay(shift.start, day))} onSelectShift={onSelectShift} />
          ))}
        </div>
      ) : (
        <NoEventsDay day={firstDay} />
      )}
    </section>
  );
}

function WeeklyGrid({ days, shifts, loading, onSelectShift }: { days: Date[]; shifts: TeacherShift[]; loading: boolean; onSelectShift: (shift: TeacherShift) => void }) {
  return (
    <section className="grid min-h-[590px] grid-cols-1 overflow-hidden rounded-2xl bg-white shadow-sm lg:min-h-[828px] lg:grid-cols-3">
      {loading ? (
        <div className="col-span-full grid min-h-[360px] place-items-center text-sm font-bold text-[#64748B]">Loading schedule...</div>
      ) : (
        days.map((day) => (
          <div key={day.toISOString()} className="border-b border-[#EEF2F7] p-5 lg:border-b-0 lg:border-r lg:last:border-r-0">
            <p className="text-xs font-black uppercase text-[#D8F0FF]">{weekdayLabel(day)}</p>
            <div className="mt-2 flex items-center gap-4">
              <span className="grid h-11 w-11 place-items-center rounded-full bg-[#E1F2FF] text-xl font-black text-[#0386FF]">{day.getDate()}</span>
              <div className="min-w-0 flex-1">
                {shifts.filter((shift) => isSameDay(shift.start, day)).length ? (
                  shifts.filter((shift) => isSameDay(shift.start, day)).map((shift) => <ShiftPill key={shift.id} shift={shift} onSelect={onSelectShift} />)
                ) : (
                  <p className="text-base font-medium text-[#9CA3AF]">No events</p>
                )}
              </div>
            </div>
          </div>
        ))
      )}
    </section>
  );
}

function DayAgenda({ day, shifts, onSelectShift }: { day: Date; shifts: TeacherShift[]; onSelectShift: (shift: TeacherShift) => void }) {
  return (
    <div className="grid min-h-[88px] grid-cols-[96px_1fr] items-start gap-5 px-6 py-5">
      <DayBadge day={day} />
      <div className="pt-4">
        {shifts.length ? shifts.map((shift) => <ShiftPill key={shift.id} shift={shift} onSelect={onSelectShift} />) : <p className="text-base font-medium text-[#9CA3AF]">No events</p>}
      </div>
    </div>
  );
}

function NoEventsDay({ day }: { day: Date }) {
  return (
    <div className="grid min-h-[88px] grid-cols-[96px_1fr] items-start gap-5 border-b border-[#EEF2F7] px-6 py-5 lg:grid-cols-[128px_1fr]">
      <DayBadge day={day} />
      <p className="pt-4 text-base font-medium text-[#9CA3AF]">No events</p>
    </div>
  );
}

function DayBadge({ day }: { day: Date }) {
  return (
    <div className="flex items-center gap-3 lg:justify-center">
      <span className="grid h-11 w-11 place-items-center rounded-full bg-[#E1F2FF] text-xl font-black text-[#0386FF]">{day.getDate()}</span>
      <span className="hidden text-[10px] font-black uppercase text-[#D8F0FF] lg:inline">{monthDayTiny(day)}</span>
      <span className="text-xs font-black uppercase text-[#D8F0FF] lg:hidden">{weekdayLabel(day)}</span>
    </div>
  );
}

function ShiftPill({ shift, onSelect }: { shift: TeacherShift; onSelect: (shift: TeacherShift) => void }) {
  return (
    <button type="button" onClick={() => onSelect(shift)} className="mb-2 block w-full rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-3 py-2 text-left text-sm text-[#1E3A8A] hover:border-[#60A5FA]">
      <p className="font-black">{shift.title}</p>
      <p className="mt-1 text-xs font-semibold text-[#2563EB]">{formatTimeRange(shift.start, shift.end)}</p>
      {shift.studentNames.length ? <p className="mt-1 truncate text-xs font-medium text-[#64748B]">{shift.studentNames.join(", ")}</p> : null}
    </button>
  );
}

function DaySchedule({
  anchorDate,
  shifts,
  loading,
  onSelectDate,
  onSelectShift,
  onClockAction,
  clockBusyShiftId,
}: {
  anchorDate: Date;
  shifts: TeacherShift[];
  loading: boolean;
  onSelectDate: (date: Date) => void;
  onSelectShift: (shift: TeacherShift) => void;
  onClockAction: (shift: TeacherShift) => void;
  clockBusyShiftId: string | null;
}) {
  const stripStart = addDays(anchorDate, -2);
  const stripDays = Array.from({ length: 15 }, (_, index) => addDays(stripStart, index));
  return (
    <section>
      <div className="mb-3 rounded-2xl bg-white p-4 shadow-sm">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-black text-[#1E293B]">{anchorDate.toLocaleDateString("en-US", { month: "long", year: "numeric" })}</h2>
          <Calendar size={22} className="text-[#64748B]" />
        </div>
        <div className="flex gap-3 overflow-x-auto pb-1">
          {stripDays.map((day) => {
            const active = isSameDay(day, anchorDate);
            return (
              <button key={day.toISOString()} type="button" onClick={() => onSelectDate(day)} className={`grid min-h-[58px] min-w-[58px] place-items-center rounded-2xl border px-3 ${active ? "border-[#0386FF] bg-[#0386FF] text-white" : "border-[#E5E7EB] bg-white text-[#1E293B]"}`}>
                <span className={`text-[10px] font-black uppercase ${active ? "text-white/80" : "text-[#94A3B8]"}`}>{weekdayLabel(day)}</span>
                <span className="text-lg font-black">{day.getDate()}</span>
              </button>
            );
          })}
        </div>
      </div>
      <div className="mb-0 flex items-center gap-2 border-b border-[#E2E8F0] bg-[#F8FAFC] px-3 py-3">
        <Calendar size={18} className="text-[#64748B]" />
        <h2 className="text-sm font-bold text-[#334155]">{anchorDate.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" })}</h2>
        {shifts.length ? <span className="ml-auto rounded-full bg-[#DFF0FF] px-3 py-1 text-xs font-bold text-[#0386FF]">{shifts.length} shift{shifts.length === 1 ? "" : "s"}</span> : null}
      </div>
      <div className="min-h-[540px] rounded-b-2xl bg-white p-5 shadow-sm">
        {loading ? (
          <div className="grid min-h-[260px] place-items-center text-sm font-bold text-[#64748B]">Loading schedule...</div>
        ) : shifts.length === 0 ? (
          <div className="grid min-h-[360px] place-items-center text-center">
            <div>
              <CalendarCheck size={60} className="mx-auto text-[#CBD5E1]" />
              <h3 className="mt-4 text-lg font-bold text-[#9CA3AF]">No Shifts Today</h3>
              <p className="mt-2 text-sm text-[#9CA3AF]">Enjoy your free time!</p>
            </div>
          </div>
        ) : (
          shifts.map((shift, index) => <TimelineShiftCard key={shift.id} shift={shift} isLast={index === shifts.length - 1} onSelect={onSelectShift} onClockAction={onClockAction} busy={clockBusyShiftId === shift.id} />)
        )}
      </div>
    </section>
  );
}

function TimelineShiftCard({
  shift,
  isLast,
  onSelect,
  onClockAction,
  busy,
}: {
  shift: TeacherShift;
  isLast: boolean;
  onSelect: (shift: TeacherShift) => void;
  onClockAction: (shift: TeacherShift) => void;
  busy: boolean;
}) {
  const config = shiftVisualConfig(shift);
  const action = clockAction(shift);
  const isDisabled = action.kind === "disabled" || busy;
  return (
    <div className="grid grid-cols-[72px_28px_1fr] items-stretch gap-2">
      <div className="pt-1 text-right">
        <p className="text-sm font-semibold text-[#1E293B]">{shift.start ? formatTime24(shift.start) : "--:--"}</p>
        <p className="text-xs text-[#94A3B8]">{shift.end ? formatTime24(shift.end) : "--:--"}</p>
      </div>
      <div className="flex flex-col items-center">
        <span className="mt-1 h-3 w-3 rounded-full border-[3px] border-[#0386FF] bg-white" />
        {!isLast ? <span className="mt-1 h-8 w-0.5 bg-[#E5E7EB]" /> : null}
      </div>
      <article className="mb-6 rounded-2xl border-l-4 bg-white p-4 shadow-[0_4px_12px_rgba(100,116,139,0.08)]" style={{ borderLeftColor: config.color }}>
        <button type="button" onClick={() => onSelect(shift)} className="block w-full text-left">
          <div className="flex items-start justify-between gap-3">
            <div>
              <h3 className="text-base font-black text-[#1E293B]">{shift.studentNames.join(", ") || shift.title}</h3>
              <p className="mt-1 text-sm font-medium text-[#64748B]">{shift.subject || shift.title}</p>
            </div>
            <span className={`rounded-md px-2 py-1 text-[10px] font-black uppercase ${config.badge}`}>{config.label}</span>
          </div>
          <p className="mt-3 inline-flex items-center gap-1 text-sm text-[#64748B]">
            <Timer size={16} />
            {shiftDuration(shift)}
          </p>
        </button>
        <button
          type="button"
          disabled={isDisabled}
          onClick={() => onClockAction(shift)}
          className={`mt-4 inline-flex min-h-9 w-full items-center justify-center gap-2 rounded-lg text-sm font-bold ${
            isDisabled
              ? "bg-[#E2E8F0] text-[#94A3B8]"
              : action.kind === "clockOut"
                ? "bg-[#EF4444] text-white hover:bg-[#DC2626]"
                : "bg-[#10B981] text-white hover:bg-[#059669]"
          }`}
        >
          <Clock size={16} />
          {busy ? "Updating..." : action.label}
        </button>
      </article>
    </div>
  );
}

function MonthSchedule({ days, anchorDate, shifts, loading, onSelectDate, onSelectShift }: { days: Date[]; anchorDate: Date; shifts: TeacherShift[]; loading: boolean; onSelectDate: (date: Date) => void; onSelectShift: (shift: TeacherShift) => void }) {
  return (
    <section className="rounded-2xl bg-white p-4 shadow-sm">
      <h2 className="mb-4 text-lg font-black text-[#1E293B]">{anchorDate.toLocaleDateString("en-US", { month: "long", year: "numeric" })}</h2>
      {loading ? <div className="grid min-h-[320px] place-items-center text-sm font-bold text-[#64748B]">Loading schedule...</div> : null}
      <div className="grid grid-cols-7 gap-2">
        {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map((label) => <p key={label} className="py-2 text-center text-xs font-black uppercase text-[#94A3B8]">{label}</p>)}
        {days.map((day) => {
          const dayShifts = shifts.filter((shift) => isSameDay(shift.start, day));
          const inMonth = day.getMonth() === anchorDate.getMonth();
          return (
            <button key={day.toISOString()} type="button" onClick={() => dayShifts[0] ? onSelectShift(dayShifts[0]) : onSelectDate(day)} className={`min-h-[94px] rounded-xl border p-2 text-left ${inMonth ? "border-[#E5E7EB] bg-white" : "border-[#F1F5F9] bg-[#F8FAFC] text-[#CBD5E1]"}`}>
              <span className="text-sm font-black">{day.getDate()}</span>
              {dayShifts.slice(0, 2).map((shift) => <span key={shift.id} className="mt-1 block truncate rounded-md bg-[#EFF6FF] px-2 py-1 text-[11px] font-bold text-[#2563EB]">{shift.studentNames[0] || shift.title}</span>)}
            </button>
          );
        })}
      </div>
    </section>
  );
}

function ShiftDetailsDialog({
  shift,
  busy,
  onClockAction,
  onClose,
  onReportIssue,
}: {
  shift: TeacherShift;
  busy: boolean;
  onClockAction: (shift: TeacherShift) => void;
  onClose: () => void;
  onReportIssue: () => void;
}) {
  const action = clockAction(shift);
  const canAct = action.kind !== "disabled";
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/45 px-4">
      <section className="w-full max-w-[560px] rounded-2xl bg-white p-6 shadow-xl">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="text-xl font-black text-[#111827]">{shift.studentNames.join(", ") || shift.title}</h2>
            <p className="mt-1 text-sm font-semibold text-[#64748B]">{shift.subject || shift.title}</p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close shift details" className="grid h-9 w-9 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </div>
        <div className="mt-5 grid gap-3 text-sm">
          <InfoRow label="Date" value={shift.start ? shift.start.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" }) : "Date TBD"} />
          <InfoRow label="Time" value={formatTimeRange(shift.start, shift.end)} />
          <InfoRow label="Teacher" value={shift.teacherName || "Teacher"} />
          <InfoRow label="Students" value={shift.studentNames.join(", ") || "No students listed"} />
          <InfoRow label="Status" value={shiftVisualConfig(shift).label} />
        </div>
        <div className="mt-6 flex flex-wrap justify-end gap-3">
          <button type="button" onClick={onReportIssue} className="inline-flex items-center gap-2 rounded-xl border border-orange-200 px-4 py-2 text-sm font-bold text-orange-700 hover:bg-orange-50">
            <Info size={16} />
            Report Issue
          </button>
          {canAct ? (
            <button
              type="button"
              disabled={busy}
              onClick={() => onClockAction(shift)}
              className={`inline-flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-bold text-white disabled:opacity-70 ${
                action.kind === "clockOut" ? "bg-[#EF4444] hover:bg-[#DC2626]" : "bg-[#10B981] hover:bg-[#059669]"
              }`}
            >
              <Clock size={16} />
              {busy ? "Updating..." : action.kind === "clockOut" ? "Clock Out" : "Clock In"}
            </button>
          ) : null}
          <button type="button" onClick={onClose} className="rounded-xl bg-[#0386FF] px-5 py-2 text-sm font-bold text-white">Done</button>
        </div>
      </section>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4 rounded-xl bg-[#F8FAFC] px-4 py-3">
      <span className="font-semibold text-[#64748B]">{label}</span>
      <span className="text-right font-bold text-[#111827]">{value}</span>
    </div>
  );
}

function ScheduleSettingsDialog({ shifts, onClose, onReportShift, onTimezoneOnly }: { shifts: TeacherShift[]; onClose: () => void; onReportShift: (shift: TeacherShift) => void; onTimezoneOnly: () => void }) {
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/45 px-4">
      <section className="w-full max-w-[380px] rounded-3xl bg-white p-6 shadow-xl">
        <div className="flex items-start justify-between">
          <h2 className="text-2xl font-black text-[#111827]">Report Schedule Issue</h2>
          <button type="button" onClick={onClose} aria-label="Close settings" className="grid h-8 w-8 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]"><X size={17} /></button>
        </div>
        <p className="mt-4 text-center text-sm text-[#334155]">Select a shift to report an issue</p>
        <div className="mt-5 grid gap-2">
          {shifts.map((shift) => (
            <button key={shift.id} type="button" onClick={() => onReportShift(shift)} className="flex items-center gap-3 rounded-xl px-3 py-3 text-left hover:bg-[#F8FAFC]">
              <Calendar className="text-[#0386FF]" size={22} />
              <span>
                <span className="block text-sm font-semibold text-[#1E293B]">{shift.title}</span>
                <span className="block text-xs text-[#64748B]">{formatTimeRange(shift.start, shift.end)}</span>
              </span>
            </button>
          ))}
          <button type="button" onClick={onTimezoneOnly} className="flex items-center gap-3 rounded-xl px-3 py-3 text-left hover:bg-[#F8FAFC]">
            <Clock className="text-[#F59E0B]" size={22} />
            <span>
              <span className="block text-sm font-bold text-[#1E293B]">Fix My Timezone Only</span>
              <span className="block text-xs text-[#64748B]">Update timezone without reporting a shift</span>
            </span>
          </button>
        </div>
      </section>
    </div>
  );
}

function ReportScheduleIssueDialog({ shift, user, onClose, onSubmitted }: { shift: TeacherShift; user: User; onClose: () => void; onSubmitted: (message: string) => void }) {
  const [issueType, setIssueType] = useState("timezone");
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const submit = async () => {
    setSaving(true);
    setError("");
    try {
      await addDoc(collection(db, "schedule_issue_reports"), {
        shift_id: shift.id,
        shiftId: shift.id,
        teacher_id: user.uid,
        teacherId: user.uid,
        reportedBy: user.uid,
        teacher_name: shift.teacherName,
        teacherName: shift.teacherName,
        issue_type: issueType,
        issueType,
        notes: notes.trim(),
        reported_at: serverTimestamp(),
        reportedAt: serverTimestamp(),
      });
      onSubmitted(issueType === "publish" ? "Shift offered to other teachers!" : "Issue reported! Admin will review and fix it.");
      onClose();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Could not submit this report.");
    } finally {
      setSaving(false);
    }
  };
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/45 px-4">
      <section className="w-full max-w-[420px] rounded-2xl bg-white p-5 shadow-xl">
        <div className="flex items-center justify-between gap-3">
          <h2 className="text-lg font-black text-[#1E293B]">Report Schedule Issue</h2>
          <button type="button" onClick={onClose} aria-label="Close report issue" className="grid h-8 w-8 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]"><X size={17} /></button>
        </div>
        <p className="mt-4 text-sm font-bold text-[#374151]">What’s the issue?</p>
        <div className="mt-2 grid gap-2">
          {[["timezone", "My timezone is wrong"], ["incorrect_time", "Shift time is incorrect"], ["publish", "Offer shift to other teachers"], ["other", "Other issue"]].map(([value, label]) => (
            <button key={value} type="button" onClick={() => setIssueType(value)} className={`rounded-xl border px-3 py-3 text-left text-sm font-semibold ${issueType === value ? "border-[#0386FF] bg-[#EFF6FF] text-[#1D4ED8]" : "border-[#E5E7EB] text-[#334155]"}`}>{label}</button>
          ))}
        </div>
        <label className="mt-4 block text-sm font-bold text-[#374151]">Additional Notes (Optional)</label>
        <textarea value={notes} onChange={(event) => setNotes(event.target.value)} rows={3} placeholder="Explain the issue" className="mt-2 w-full rounded-xl border border-[#E5E7EB] p-3 text-sm outline-none focus:border-[#0386FF]" />
        {error ? <p className="mt-3 rounded-xl bg-red-50 px-3 py-2 text-sm font-semibold text-red-700">{error}</p> : null}
        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={onClose} className="rounded-xl px-4 py-2 text-sm font-bold text-[#64748B]">Cancel</button>
          <button type="button" onClick={submit} disabled={saving} className="rounded-xl bg-[#0386FF] px-5 py-2 text-sm font-bold text-white disabled:bg-[#93C5FD]">{saving ? "Submitting..." : "Submit"}</button>
        </div>
      </section>
    </div>
  );
}

function TimezoneDialog({ user, onClose, onSaved }: { user: User; onClose: () => void; onSaved: (message: string) => void }) {
  const [timezone, setTimezone] = useState("America/New_York");
  const [saving, setSaving] = useState(false);
  const save = async () => {
    setSaving(true);
    try {
      await updateDoc(doc(db, "users", user.uid), {
        timezone,
        timezone_updated_at: serverTimestamp(),
      });
      onSaved(`Timezone updated to ${timezone}`);
      onClose();
    } finally {
      setSaving(false);
    }
  };
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/45 px-4">
      <section className="w-full max-w-[400px] rounded-2xl bg-white p-5 shadow-xl">
        <div className="flex items-center justify-between gap-3">
          <h2 className="text-lg font-black text-[#1E293B]">Fix Timezone</h2>
          <button type="button" onClick={onClose} aria-label="Close timezone" className="grid h-8 w-8 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]"><X size={17} /></button>
        </div>
        <label className="mt-4 block text-sm font-bold text-[#374151]">Select your correct timezone</label>
        <select value={timezone} onChange={(event) => setTimezone(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-[#E5E7EB] px-3 text-sm outline-none focus:border-[#0386FF]">
          {["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "UTC", "Africa/Conakry"].map((item) => <option key={item} value={item}>{item}</option>)}
        </select>
        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={onClose} className="rounded-xl px-4 py-2 text-sm font-bold text-[#64748B]">Cancel</button>
          <button type="button" onClick={save} disabled={saving} className="rounded-xl bg-[#0386FF] px-5 py-2 text-sm font-bold text-white disabled:bg-[#93C5FD]">{saving ? "Updating..." : "Update"}</button>
        </div>
      </section>
    </div>
  );
}

async function loadTeacherShifts(uid: string) {
  const snapshots = await Promise.all([
    getDocs(query(collection(db, "teaching_shifts"), where("teacher_id", "==", uid), limit(200))).catch(() => null),
    getDocs(query(collection(db, "teaching_shifts"), where("teacherId", "==", uid), limit(200))).catch(() => null),
  ]);
  const byId = new Map<string, TeacherShift>();
  snapshots.forEach((snap) => {
    snap?.docs.forEach((entry) => byId.set(entry.id, normalizeShift(entry.id, entry.data() as Record<string, unknown>)));
  });
  return Array.from(byId.values()).sort((a, b) => (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0));
}

function normalizeShift(id: string, data: Record<string, unknown>): TeacherShift {
  const studentNames = arrayOfStrings(data.student_names ?? data.studentNames);
  const subject = stringValue(data.subject_display_name ?? data.subjectDisplayName ?? data.subject);
  const title =
    stringValue(data.custom_name ?? data.customName) ||
    stringValue(data.auto_generated_name ?? data.autoGeneratedName) ||
    subject ||
    "Teaching Shift";
  return {
    id,
    title,
    studentNames,
    start: dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime),
    end: dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime),
    status: stringValue(data.status) || "scheduled",
    subject,
    teacherName: stringValue(data.teacher_name ?? data.teacherName),
    teacherId: stringValue(data.teacher_id ?? data.teacherId),
    hourlyRate: numberValue(data.hourly_rate ?? data.hourlyRate),
    clockInTime: dateValue(data.clock_in_time ?? data.clockInTime),
    clockOutTime: dateValue(data.clock_out_time ?? data.clockOutTime),
  };
}

type BrowserLocation = {
  latitude: number;
  longitude: number;
  address: string;
  neighborhood: string;
};

async function clockInToShift(user: User, shift: TeacherShift, location: BrowserLocation) {
  if (!canClockInNow(shift)) {
    throw new Error("Shift not found or not valid for clock-in right now");
  }
  const openEntry = await findOpenTimesheetEntry(user.uid, shift.id);
  if (openEntry) {
    throw new Error("You are already clocked in to this shift");
  }
  const now = new Date();
  const batch = writeBatch(db);
  const timesheetRef = doc(collection(db, "timesheet_entries"));
  batch.set(timesheetRef, {
    teacher_id: user.uid,
    teacher_email: user.email,
    teacher_name: shift.teacherName,
    shift_id: shift.id,
    date: formatTimesheetDate(now),
    student_name: shift.studentNames.length ? shift.studentNames.join(", ") : "No students assigned",
    start_time: formatClockTime(now),
    end_time: "",
    total_hours: "00:00",
    hourly_rate: shift.hourlyRate,
    description: `Teaching session: ${shift.subject || shift.title} - ${shift.title}`,
    status: "pending",
    source: "shift_clock_in",
    completion_method: "pending",
    clock_in_timestamp: Timestamp.fromDate(now),
    clock_in_platform: "web",
    clock_in_latitude: location.latitude,
    clock_in_longitude: location.longitude,
    clock_in_address: location.address,
    clock_in_neighborhood: location.neighborhood,
    clock_out_latitude: null,
    clock_out_longitude: null,
    clock_out_address: null,
    clock_out_neighborhood: null,
    shift_title: shift.title,
    shift_type: buildShiftTypeString(shift),
    scheduled_start: shift.start ? Timestamp.fromDate(shift.start) : null,
    scheduled_end: shift.end ? Timestamp.fromDate(shift.end) : null,
    scheduled_duration_minutes: scheduledDurationMinutes(shift),
    employee_notes: "",
    manager_notes: "",
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
  });
  batch.update(doc(db, "teaching_shifts", shift.id), {
    last_modified: Timestamp.fromDate(now),
    status: "active",
    clock_out_time: null,
    clock_in_time: shift.clockInTime ? Timestamp.fromDate(shift.clockInTime) : Timestamp.fromDate(now),
    last_clock_in_platform: "web",
  });
  await batch.commit();
  return { message: `Successfully clocked in to ${shift.title}` };
}

async function clockOutOfShift(user: User, shift: TeacherShift, location: BrowserLocation) {
  const openEntry = await findOpenTimesheetEntry(user.uid, shift.id);
  if (!openEntry) {
    throw new Error("No active clock-in found for this shift.");
  }
  const now = new Date();
  const clockIn = dateValue(openEntry.data.clock_in_timestamp) ?? shift.clockInTime ?? shift.start ?? now;
  const effectiveStart = shift.start && clockIn < shift.start ? shift.start : clockIn;
  const effectiveEnd = shift.end && now > shift.end ? shift.end : now;
  const rawDurationMs = effectiveEnd.getTime() - effectiveStart.getTime();
  const scheduledMs = shift.start && shift.end ? shift.end.getTime() - shift.start.getTime() : rawDurationMs;
  const validMs = Math.max(0, Math.min(rawDurationMs, Math.max(0, scheduledMs)));
  const hoursWorked = validMs / 36e5;
  const calculatedPay = hoursWorked * shift.hourlyRate;
  const batch = writeBatch(db);
  batch.update(openEntry.ref, {
    end_time: formatClockTime(effectiveEnd),
    total_hours: formatDurationHms(validMs),
    clock_out_timestamp: Timestamp.fromDate(now),
    effective_end_timestamp: Timestamp.fromDate(effectiveEnd),
    total_pay: calculatedPay,
    payment_amount: calculatedPay,
    hourly_rate: shift.hourlyRate,
    status: "pending",
    completion_method: "manual",
    clock_out_latitude: location.latitude,
    clock_out_longitude: location.longitude,
    clock_out_address: location.address,
    clock_out_neighborhood: location.neighborhood,
    clock_out_platform: "web",
    updated_at: serverTimestamp(),
  });
  batch.update(doc(db, "teaching_shifts", shift.id), {
    last_modified: Timestamp.fromDate(now),
    clock_out_time: Timestamp.fromDate(now),
  });
  await batch.commit();
  return { message: `Successfully clocked out from ${shift.title}` };
}

async function findOpenTimesheetEntry(teacherId: string, shiftId: string) {
  const base = [where("teacher_id", "==", teacherId), where("shift_id", "==", shiftId), limit(1)] as const;
  const empty = await getDocs(query(collection(db, "timesheet_entries"), where("end_time", "==", ""), ...base));
  const docSnap = empty.docs[0];
  if (docSnap) return { ref: docSnap.ref, data: docSnap.data() as Record<string, unknown> };
  const nullResult = await getDocs(query(collection(db, "timesheet_entries"), where("end_time", "==", null), ...base));
  const nullDoc = nullResult.docs[0];
  return nullDoc ? { ref: nullDoc.ref, data: nullDoc.data() as Record<string, unknown> } : null;
}

async function getBrowserLocation(required: boolean): Promise<BrowserLocation> {
  if (!("geolocation" in navigator)) {
    if (required) throw new Error("Clock-in location error");
    return fallbackLocation();
  }
  try {
    const position = await new Promise<GeolocationPosition>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 });
    });
    const { latitude, longitude } = position.coords;
    return {
      latitude,
      longitude,
      address: `Location: ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`,
      neighborhood: "GPS coordinates",
    };
  } catch {
    if (required) throw new Error("Clock-in location error");
    return fallbackLocation();
  }
}

function fallbackLocation(): BrowserLocation {
  return {
    latitude: 0,
    longitude: 0,
    address: "Clock-out location unavailable",
    neighborhood: "Location unavailable",
  };
}

function summaryForUser(user: User, data: UserRecord | null): TeacherSummary {
  const displayName =
    data
      ? [stringValue(data.first_name ?? data["first-name"]), stringValue(data.last_name ?? data["last-name"])].filter(Boolean).join(" ")
      : "";
  const fallback = user.displayName?.trim() || user.email?.replace(/@.*/, "") || "Teacher";
  const name = displayName || fallback;
  return {
    displayName: name,
    firstName: name.split(/\s+/)[0] || "Teacher",
    initials: initialsFromName(name),
  };
}

function startOfWeekSunday(date: Date) {
  const normalized = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  normalized.setDate(normalized.getDate() - normalized.getDay());
  return normalized;
}

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function isSameDay(value: Date | null, day: Date) {
  return Boolean(value && value.getFullYear() === day.getFullYear() && value.getMonth() === day.getMonth() && value.getDate() === day.getDate());
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

function arrayOfStrings(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => stringValue(item)).filter(Boolean);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function buildMonthDays(anchor: Date) {
  const first = new Date(anchor.getFullYear(), anchor.getMonth(), 1);
  const start = startOfWeekSunday(first);
  return Array.from({ length: 42 }, (_, index) => addDays(start, index));
}

function shiftDuration(shift: TeacherShift) {
  if (!shift.start || !shift.end) return "Duration TBD";
  const hours = shift.end.getTime() - shift.start.getTime();
  return `${Math.max(0, hours / 36e5).toFixed(1)} hrs`;
}

function formatTime24(date: Date) {
  return date.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false });
}

type ClockAction =
  | { kind: "clockIn"; label: string }
  | { kind: "clockOut"; label: string }
  | { kind: "disabled"; label: string; disabledMessage: string };

function clockAction(shift: TeacherShift): ClockAction {
  const now = new Date();
  if (isClockedIn(shift)) return { kind: "clockOut", label: "Clock Out" };
  if (canClockInNow(shift)) return { kind: "clockIn", label: "Clock In Now" };
  if (shift.start && shift.start > now) return { kind: "disabled", label: "Clock In (Not Yet)", disabledMessage: "Too early to clock in. Please wait until the shift starts." };
  return { kind: "disabled", label: "View Details", disabledMessage: "This shift is not available for clock-in." };
}

function canClockInNow(shift: TeacherShift) {
  if (!shift.start || !shift.end || isClockedIn(shift)) return false;
  const now = new Date();
  const clockInWindowStart = new Date(shift.start.getTime() - 60_000);
  return now >= clockInWindowStart && now <= shift.end;
}

function isClockedIn(shift: TeacherShift) {
  return Boolean(shift.clockInTime && !shift.clockOutTime && shift.status === "active");
}

function findActiveSessionShift(shifts: TeacherShift[]) {
  const clockedIn = shifts.find((shift) => isClockedIn(shift));
  if (clockedIn) return clockedIn;
  const now = new Date();
  return shifts
    .filter((shift) => shift.start && shift.end && now >= new Date(shift.start.getTime() - 60_000) && now <= shift.end)
    .sort((a, b) => (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0))[0] ?? null;
}

function shiftVisualConfig(shift: TeacherShift) {
  const now = new Date();
  if (isClockedIn(shift)) return { label: "In Progress", color: "#10B981", badge: "bg-green-100 text-green-700" };
  if (["completed", "fullyCompleted"].includes(shift.status)) return { label: "Completed", color: "#8B5CF6", badge: "bg-purple-100 text-purple-700" };
  if (shift.status === "partiallyCompleted") return { label: "Partial", color: "#F59E0B", badge: "bg-orange-100 text-orange-700" };
  if (shift.clockInTime && shift.clockOutTime) return { label: "Completed", color: "#8B5CF6", badge: "bg-purple-100 text-purple-700" };
  if (shift.status === "missed" || (shift.end && shift.end < now && shift.status === "scheduled")) return { label: "Missed", color: "#EF4444", badge: "bg-red-100 text-red-700" };
  if (shift.status === "cancelled") return { label: "Cancelled", color: "#9CA3AF", badge: "bg-gray-100 text-gray-700" };
  if (shift.start && shift.start <= now && shift.end && shift.end > now) return { label: "Ready", color: "#10B981", badge: "bg-green-100 text-green-700" };
  return { label: "Upcoming", color: "#0386FF", badge: "bg-blue-100 text-blue-700" };
}

function scheduledDurationMinutes(shift: TeacherShift) {
  if (!shift.start || !shift.end) return 0;
  return Math.max(0, Math.round((shift.end.getTime() - shift.start.getTime()) / 60000));
}

function buildShiftTypeString(shift: TeacherShift) {
  const subject = shift.subject || shift.title || "Teaching Shift";
  const duration = scheduledDurationMinutes(shift);
  return duration ? `${subject} (${duration} min)` : subject;
}

function formatTimesheetDate(date: Date) {
  return date.toLocaleDateString("en-US", { month: "short", day: "2-digit", year: "numeric" });
}

function formatClockTime(date: Date) {
  return date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", hour12: true });
}

function formatDurationHms(durationMs: number) {
  const totalSeconds = Math.max(0, Math.floor(durationMs / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  return (parts[0]?.[0] ?? "T").concat(parts[1]?.[0] ?? parts[0]?.[1] ?? "E").toUpperCase();
}

function formatWeekRange(start: Date) {
  const end = addDays(start, 6);
  return `${shortMonth(start)} ${start.getDate()} - ${end.getDate()}`;
}

function weekdayLabel(date: Date) {
  return date.toLocaleDateString("en-US", { weekday: "short" });
}

function monthDayTiny(date: Date) {
  return date.toLocaleDateString("en-US", { month: "short", weekday: "short" }).replace(",", "");
}

function shortMonth(date: Date) {
  return date.toLocaleDateString("en-US", { month: "short" });
}

function formatTimeRange(start: Date | null, end: Date | null) {
  if (!start || !end) return "Time TBD";
  return `${formatTime(start)} - ${formatTime(end)}`;
}

function formatTime(date: Date) {
  return date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
}
