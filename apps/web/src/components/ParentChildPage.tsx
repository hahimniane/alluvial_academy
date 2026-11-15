"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  BookOpen,
  Calendar,
  CalendarDays,
  CheckCircle2,
  ClipboardCheck,
  ClipboardList,
  Clock,
  Flag,
  History,
  Paperclip,
  RefreshCw,
  School,
  ListTree,
  TrendingDown,
  TrendingUp,
  MoveRight,
  User,
} from "lucide-react";
import { useParentSession } from "@/components/ParentArea";
import { ParentClassCard } from "@/components/ParentClassCard";
import { Ring, SplitBar, WeeklyChart } from "@/components/ParentDashboardHome";
import { ParentEmptyCard, ParentErrorCard, ParentSectionHeader, ParentSpinner, alpha, cardShadow } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import { fetchShiftHistory, fetchTodayShifts, fetchUpcomingShifts, fetchUserName, watchChildShifts, watchChildTasks } from "@/lib/parentData";
import {
  ATTENTION_COLOR,
  ATTENTION_LABEL,
  CALENDAR_TINT,
  TASK_PRIORITY_BADGE,
  TASK_STATUS_BADGE,
  calendarWeeks,
  childProgressMetrics,
  completionColor,
  formatActivityDate,
  formatMonthYear,
  formatPaddedDate,
  historyWindow,
  percent,
  quickStats,
  recentActivity,
  sortTasks,
  subjectLabel,
  taskCounters,
  taskIsOverdue,
  taskMatches,
  todayClasses,
  trendColor,
  trendLabel,
  upcomingList,
  upcomingPreview,
  type ParentShift,
  type ParentTask,
  type SubjectProgress,
  type TaskFilter,
} from "@/lib/parentHome";
import { fill, parentHomeText, type ParentHomeText } from "@/lib/parentHomeText";
import { fetchParentChildren } from "@/lib/parentSession";
import { PARENT_ROUTES, type ParentChild } from "@/lib/parentWeb";

type Tab = "overview" | "classes" | "tasks" | "progress";
type Load<T> = { state: "loading" } | { state: "error" } | { state: "ready"; value: T };

/**
 * The child page (StudentDetailScreen, A-058…A-085): a full page over the
 * shell with the child's name, a back arrow and four tabs. The child must be
 * one of the parent's own children (A-059): an id that is not is refused,
 * because the rules alone would let any class or task be read.
 */
export default function ParentChildPage() {
  const session = useParentSession();
  const id = useSearchParams()?.get("id") ?? "";
  const fr = useLocale() === "fr";
  const text = parentHomeText(fr);
  const [child, setChild] = useState<Load<ParentChild | null>>({ state: "loading" });
  const [tab, setTab] = useState<Tab>("overview");
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let active = true;
    setChild({ state: "loading" });
    fetchParentChildren(session.uid)
      .then((list) => {
        if (active) setChild({ state: "ready", value: list.find((c) => c.id === id) ?? null });
      })
      .catch(() => {
        if (active) setChild({ state: "error" });
      });
    return () => {
      active = false;
    };
  }, [session.uid, id]);

  const tabs: Array<[Tab, string]> = [
    ["overview", text.tabOverview],
    ["classes", text.tabClasses],
    ["tasks", text.tabTasks],
    ["progress", text.tabProgress],
  ];
  const ready = child.state === "ready" && child.value;

  return (
    <div className="min-h-full bg-[#F8FAFC]">
      <header className="sticky top-0 z-10 bg-white">
        <div className="flex h-14 items-center gap-1 px-1">
          <Link href={PARENT_ROUTES.home} aria-label={text.back} title={text.back} className="grid h-12 w-12 place-items-center rounded-full text-[#111827] hover:bg-black/5">
            <ArrowLeft size={24} />
          </Link>
          <h1 className="min-w-0 flex-1 truncate text-center text-lg font-extrabold text-[#111827]">{ready ? child.value!.name : ""}</h1>
          {ready ? (
            <button
              type="button"
              onClick={() => setReloadKey((k) => k + 1)}
              title={text.refresh}
              aria-label={text.refresh}
              className="grid h-12 w-12 place-items-center rounded-full text-[#6B7280] hover:bg-black/5"
            >
              <RefreshCw size={20} />
            </button>
          ) : null}
        </div>
        {ready ? (
          <div role="tablist" aria-label={child.value!.name} className="flex border-b border-[#E5E7EB]">
            {tabs.map(([key, label]) => (
              <button
                key={key}
                type="button"
                role="tab"
                aria-selected={tab === key}
                onClick={() => setTab(key)}
                className={`flex min-h-12 flex-1 justify-center px-2 text-sm ${tab === key ? "font-semibold text-[#0386FF]" : "font-medium text-[#6B7280]"} hover:bg-black/[0.03]`}
              >
                <span className="relative flex items-center">
                  {label}
                  {tab === key ? <span className="absolute inset-x-0 bottom-0 h-[3px] rounded-t-sm bg-[#0386FF]" /> : null}
                </span>
              </button>
            ))}
          </div>
        ) : null}
      </header>

      {child.state === "loading" ? (
        <ParentSpinner padding={24} label={text.loading} />
      ) : child.state === "error" ? (
        <div className="p-4">
          <ParentErrorCard message={text.couldNotLoad} />
        </div>
      ) : !child.value ? (
        <div className="p-4">
          <ParentEmptyCard icon={User} title={text.childNotLinked} subtitle={text.backToDashboard} />
          <Link href={PARENT_ROUTES.home} className="mt-3 inline-block rounded-lg px-3 py-2 text-sm font-bold text-[#0386FF] hover:bg-[#0386FF]/10">
            {text.backToDashboard}
          </Link>
        </div>
      ) : (
        <div className="p-4" key={`${tab}-${reloadKey}`}>
          {tab === "overview" ? <OverviewTab childId={child.value.id} text={text} /> : null}
          {tab === "classes" ? <ClassesTab childId={child.value.id} text={text} /> : null}
          {tab === "tasks" ? <TasksTab childId={child.value.id} text={text} /> : null}
          {tab === "progress" ? <ProgressTab childId={child.value.id} childName={child.value.name} text={text} /> : null}
        </div>
      )}
    </div>
  );
}

/** The time used by the class cards, refreshed every 30 s so badges and Join keep up. */
function useNow(intervalMs = 30_000) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), intervalMs);
    return () => window.clearInterval(timer);
  }, [intervalMs]);
  return now;
}

function useOnce<T>(load: () => Promise<T>, deps: unknown[]): Load<T> {
  const [state, setState] = useState<Load<T>>({ state: "loading" });
  useEffect(() => {
    let active = true;
    load()
      .then((value) => active && setState({ state: "ready", value }))
      .catch(() => active && setState({ state: "error" }));
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return state;
}

function useLiveTasks(childId: string): Load<ParentTask[]> {
  const [state, setState] = useState<Load<ParentTask[]>>({ state: "loading" });
  useEffect(
    () =>
      watchChildTasks(
        childId,
        (tasks) => setState({ state: "ready", value: sortTasks(tasks) }),
        () => setState({ state: "error" }),
      ),
    [childId],
  );
  return state;
}

function useLiveShifts(childId: string): Load<ParentShift[]> {
  const [state, setState] = useState<Load<ParentShift[]>>({ state: "loading" });
  useEffect(
    () =>
      watchChildShifts(
        childId,
        (shifts) => setState({ state: "ready", value: shifts }),
        () => setState({ state: "error" }),
      ),
    [childId],
  );
  return state;
}

function ClassCards({ shifts, now, text }: { shifts: ParentShift[]; now: Date; text: ParentHomeText }) {
  return (
    <div className="grid gap-3">
      {shifts.map((shift) => (
        <ParentClassCard key={shift.id} shift={shift} now={now} text={text} />
      ))}
    </div>
  );
}

// ─── Overview tab (A-060…A-063) ────────────────────────────────────────────

function OverviewTab({ childId, text }: { childId: string; text: ParentHomeText }) {
  const now = useNow();
  const tasks = useLiveTasks(childId);
  const past = useOnce(() => fetchShiftHistory(childId, new Date(), null), [childId]);
  const today = useOnce(async () => todayClasses(await fetchTodayShifts(childId, new Date()), new Date()), [childId]);
  const upcoming = useOnce(async () => upcomingPreview(await fetchUpcomingShifts(childId, new Date()), new Date()), [childId]);

  // Quick stats use the first task snapshot, as Flutter's `.first`.
  const [firstTasks, setFirstTasks] = useState<ParentTask[] | null>(null);
  useEffect(() => {
    if (firstTasks === null && tasks.state === "ready") setFirstTasks(tasks.value);
  }, [tasks, firstTasks]);
  const statsFailed = tasks.state === "error" && firstTasks === null;
  const stats = past.state === "ready" && firstTasks ? quickStats(past.value, firstTasks, new Date()) : null;

  return (
    <div>
      {statsFailed ? (
        <ParentErrorCard message="Failed to load statistics. Please refresh to try again." />
      ) : !stats ? (
        <ParentSpinner padding={24} label={text.loading} />
      ) : (
        <div className={`flex gap-6 rounded-2xl border border-[#E5E7EB] bg-white p-5 ${cardShadow}`}>
          <QuickStat icon={Calendar} color="#1D4ED8" value={`${stats.totalClasses}`} label={text.totalClasses} />
          <QuickStat icon={CheckCircle2} color="#16A34A" value={`${percent(stats.attendanceRate)}%`} label={text.quickAttendance} />
          <QuickStat icon={ClipboardCheck} color="#F59E0B" value={`${stats.completedTasks}/${stats.totalTasks}`} label={text.tasksDone} />
        </div>
      )}

      <div className="mt-5">
        <ParentSectionHeader>Today&apos;s Classes</ParentSectionHeader>
      </div>
      <div className="mt-2.5">
        {today.state === "loading" ? (
          <ParentSpinner label={text.loading} />
        ) : today.state === "ready" && today.value.length > 0 ? (
          <ClassCards shifts={today.value} now={now} text={text} />
        ) : (
          <ParentEmptyCard icon={Calendar} title={text.noClassesToday} subtitle={text.noClassesTodayBody} />
        )}
      </div>

      <div className="mt-5">
        <ParentSectionHeader>Upcoming Classes</ParentSectionHeader>
      </div>
      <div className="mt-2.5">
        {upcoming.state === "loading" ? (
          <ParentSpinner label={text.loading} />
        ) : upcoming.state === "ready" && upcoming.value.length > 0 ? (
          <ClassCards shifts={upcoming.value} now={now} text={text} />
        ) : (
          <ParentEmptyCard icon={CalendarDays} title={text.noUpcoming} subtitle={text.noUpcomingBody} />
        )}
      </div>

      <div className="mt-5">
        <ParentSectionHeader>Recent Activity</ParentSectionHeader>
      </div>
      <div className="mt-2.5">
        <RecentActivity tasks={tasks} past={past} text={text} />
      </div>
      <div className="h-4" />
    </div>
  );
}

function QuickStat({ icon: Icon, color, value, label }: { icon: typeof Calendar; color: string; value: string; label: string }) {
  return (
    <div className="min-w-0 flex-1">
      <span className="grid h-10 w-10 place-items-center rounded-[10px]" style={{ color, backgroundColor: alpha(color, 0.1) }}>
        <Icon size={20} />
      </span>
      <p className="mt-3 text-2xl font-extrabold text-[#111827]">{value}</p>
      <p className="mt-1 text-xs font-medium text-[#6B7280]">{label}</p>
    </div>
  );
}

function RecentActivity({ tasks, past, text }: { tasks: Load<ParentTask[]>; past: Load<ParentShift[]>; text: ParentHomeText }) {
  if (tasks.state === "loading") return <ParentSpinner label={text.loading} />;
  if (tasks.state === "error") return <ParentErrorCard message="Failed to load recent activity. Please refresh to try again." />;
  const { lastTask, lastClass } = recentActivity(tasks.value, past.state === "ready" ? past.value : []);
  if (!lastTask && !lastClass) return <ParentEmptyCard icon={History} title={text.noRecentActivity} subtitle={text.noRecentActivityBody} />;
  return (
    <div className="grid gap-3">
      {lastClass ? (
        <ActivityRow icon={School} color="#16A34A" title={text.lastClassCompleted} detail={subjectLabel(lastClass)} subtitle={formatActivityDate(lastClass.shiftStart)} />
      ) : null}
      {lastTask ? (
        <ActivityRow
          icon={ClipboardCheck}
          color="#0386FF"
          title={text.lastTaskCompleted}
          detail={lastTask.title}
          subtitle={lastTask.completedAt ? formatPaddedDate(lastTask.completedAt) : "Recently"}
        />
      ) : null}
    </div>
  );
}

function ActivityRow({ icon: Icon, color, title, detail, subtitle }: { icon: typeof School; color: string; title: string; detail: string; subtitle: string }) {
  return (
    <div className="flex items-center gap-3 rounded-xl border border-[#E5E7EB] bg-white p-4">
      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-[10px]" style={{ color, backgroundColor: alpha(color, 0.1) }}>
        <Icon size={20} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="text-[13px] font-bold text-[#111827]">{title}</p>
        <p className="mt-0.5 truncate text-[13px] font-medium text-[#111827]">{detail}</p>
        <p className="mt-0.5 text-xs font-medium text-[#6B7280]">{subtitle}</p>
      </div>
    </div>
  );
}

// ─── Classes tab (A-071…A-074) ─────────────────────────────────────────────

function Segmented<T extends string>({ options, value, onChange, size }: { options: Array<[T, string]>; value: T; onChange: (v: T) => void; size: number }) {
  return (
    <div className="flex rounded-[10px] bg-[#F3F4F6] p-1" role="group">
      {options.map(([key, label]) => (
        <button
          key={key}
          type="button"
          aria-pressed={value === key}
          onClick={() => onChange(key)}
          className={`min-w-0 flex-1 rounded-lg py-2.5 ${value === key ? "bg-white font-bold text-[#111827] shadow-[0_2px_8px_rgba(0,0,0,0.06)]" : "font-medium text-[#6B7280]"}`}
          style={{ fontSize: size }}
        >
          {label}
        </button>
      ))}
    </div>
  );
}

function ClassesTab({ childId, text }: { childId: string; text: ParentHomeText }) {
  const now = useNow();
  const [mode, setMode] = useState<"upcoming" | "history">("upcoming");
  const live = useLiveShifts(childId);
  const history = useOnce(async () => historyWindow(await fetchShiftHistory(childId, new Date(), null), new Date(), null), [childId]);
  const month = useMemo(() => new Date(), []);

  return (
    <div>
      <Segmented
        options={[
          ["upcoming", "Upcoming"],
          ["history", "History"],
        ]}
        value={mode}
        onChange={setMode}
        size={14}
      />
      <div className="mt-5">
        <ParentSectionHeader>Attendance Calendar</ParentSectionHeader>
      </div>
      <div className="mt-2.5">
        <AttendanceCalendar shifts={live.state === "ready" ? live.value : []} month={month} now={now} />
      </div>
      <div className="mt-5">
        <ParentSectionHeader>{mode === "upcoming" ? "Upcoming Classes" : "Class History"}</ParentSectionHeader>
      </div>
      <div className="mt-2.5">
        {mode === "upcoming" ? (
          live.state === "loading" ? (
            <ParentSpinner padding={24} label={text.loading} />
          ) : live.state === "error" ? (
            <ParentErrorCard message="Failed to load upcoming classes. Please refresh to try again." />
          ) : upcomingList(live.value, now).length === 0 ? (
            <ParentEmptyCard icon={CalendarDays} title={text.noUpcoming} subtitle={text.noUpcomingBody} />
          ) : (
            <ClassCards shifts={upcomingList(live.value, now)} now={now} text={text} />
          )
        ) : history.state === "loading" ? (
          <ParentSpinner padding={24} label={text.loading} />
        ) : history.state === "ready" && history.value.length > 0 ? (
          <ClassCards shifts={history.value} now={now} text={text} />
        ) : (
          <ParentEmptyCard icon={History} title={text.noClassHistory} subtitle={text.noClassHistoryBody} />
        )}
      </div>
      <div className="h-4" />
    </div>
  );
}

const LEGEND: Array<[string, string]> = [
  ["Completed", "#16A34A"],
  ["Missed", "#DC2626"],
  ["Scheduled", "#2563EB"],
  ["None", "#E5E7EB"],
];

function AttendanceCalendar({ shifts, month, now }: { shifts: ParentShift[]; month: Date; now: Date }) {
  const weeks = calendarWeeks(shifts, month, now);
  return (
    <div className="rounded-2xl border border-[#E5E7EB] bg-white p-5">
      <h3 className="text-lg font-extrabold text-[#111827]">{formatMonthYear(month)}</h3>
      <div className="mt-5 grid grid-cols-7">
        {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((day) => (
          <span key={day} className="text-center text-xs font-bold text-[#6B7280]">
            {day}
          </span>
        ))}
      </div>
      <div className="mt-3 grid gap-2">
        {weeks.map((week, w) => (
          <div key={w} className="grid grid-cols-7">
            {week.map((cell, d) =>
              cell ? (
                <span
                  key={d}
                  className={`mx-0.5 grid h-10 place-items-center rounded-lg text-[13px] text-[#111827] ${cell.isToday ? "font-extrabold" : "font-semibold"}`}
                  style={{
                    backgroundColor: (cell.status && CALENDAR_TINT[cell.status]) || "#F9FAFB",
                    boxShadow: cell.isToday ? "inset 0 0 0 2px #0386FF" : undefined,
                  }}
                >
                  {cell.day}
                </span>
              ) : (
                <span key={d} />
              ),
            )}
          </div>
        ))}
      </div>
      <div className="mt-5 flex flex-wrap justify-evenly gap-2">
        {LEGEND.map(([label, color]) => (
          <span key={label} className="inline-flex items-center gap-1.5 text-[11px] font-medium text-[#6B7280]">
            <span className="h-4 w-4 rounded" style={{ backgroundColor: color }} />
            {label}
          </span>
        ))}
      </div>
    </div>
  );
}

// ─── Tasks tab (A-075…A-079) ───────────────────────────────────────────────

function TasksTab({ childId, text }: { childId: string; text: ParentHomeText }) {
  const tasks = useLiveTasks(childId);
  const [filter, setFilter] = useState<TaskFilter>("all");
  const now = new Date();
  const counters = tasks.state === "ready" ? taskCounters(tasks.value, now) : null;
  const shown = tasks.state === "ready" ? tasks.value.filter((t) => taskMatches(t, filter, now)) : [];

  return (
    <div>
      {counters ? (
        <div className={`flex rounded-2xl border border-[#E5E7EB] bg-white p-5 ${cardShadow}`}>
          <TaskCounter label="Total" value={counters.total} color="#111827" />
          <TaskCounter label="Completed" value={counters.completed} color="#16A34A" />
          <TaskCounter label="Pending" value={counters.pending} color="#F59E0B" />
          <TaskCounter label="Overdue" value={counters.overdue} color="#DC2626" />
        </div>
      ) : null}
      <div className="mt-5">
        <Segmented
          options={[
            ["all", "All"],
            ["pending", "Pending"],
            ["completed", "Completed"],
            ["overdue", "Overdue"],
          ]}
          value={filter}
          onChange={setFilter}
          size={13}
        />
      </div>
      <div className="mt-5">
        {tasks.state === "loading" ? (
          <ParentSpinner padding={24} label={text.loading} />
        ) : tasks.state === "error" ? (
          <ParentErrorCard message="Failed to load tasks. Please refresh to try again." />
        ) : shown.length === 0 ? (
          <ParentEmptyCard icon={ClipboardList} title={text.noTasks} subtitle={filter === "all" ? "Your child has no tasks assigned." : "No tasks match the selected filter."} />
        ) : (
          <div className="grid gap-3">
            {shown.map((task) => (
              <TaskCard key={task.id} task={task} now={now} text={text} />
            ))}
          </div>
        )}
      </div>
      <div className="h-4" />
    </div>
  );
}

function TaskCounter({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="min-w-0 flex-1 text-center">
      <p className="text-2xl font-extrabold" style={{ color }}>
        {value}
      </p>
      <p className="mt-1 text-xs font-medium text-[#6B7280]">{label}</p>
    </div>
  );
}

/** TaskCard, read-only for parents (A-079): it does not open. */
function TaskCard({ task, now, text }: { task: ParentTask; now: Date; text: ParentHomeText }) {
  const overdue = taskIsOverdue(task, now);
  const [assignedBy, setAssignedBy] = useState<string | null>(null);
  useEffect(() => {
    let active = true;
    void fetchUserName(task.createdBy).then((name) => active && setAssignedBy(name));
    return () => {
      active = false;
    };
  }, [task.createdBy]);
  const priority = TASK_PRIORITY_BADGE[task.priority];
  const status = TASK_STATUS_BADGE[task.status];
  return (
    <article className="rounded-xl border bg-white p-4" style={{ borderColor: overdue ? "#FEE2E2" : "#E5E7EB" }}>
      <div className="flex items-center gap-2">
        <div className="min-w-0 flex-1">
          <p className="truncate text-[15px] font-extrabold text-[#111827]">{task.title}</p>
          {task.description ? <p className="mt-1 line-clamp-2 text-[13px] font-normal text-[#6B7280]">{task.description}</p> : null}
        </div>
        <span className="shrink-0 rounded-lg px-2 py-1 text-[10px] font-bold" style={{ backgroundColor: priority.bg, color: priority.fg }}>
          {priority.label}
        </span>
        <span className="shrink-0 rounded-lg px-2 py-1 text-[10px] font-bold" style={{ backgroundColor: status.bg, color: status.fg }}>
          {status.label}
        </span>
      </div>
      <div className="mt-3 flex items-center gap-1.5">
        <Calendar size={14} className="shrink-0" style={{ color: overdue ? "#DC2626" : "#6B7280" }} />
        <span className="truncate text-xs font-medium" style={{ color: overdue ? "#DC2626" : "#6B7280" }}>
          {formatPaddedDate(task.dueDate)}
        </span>
        {overdue ? <span className="ml-0.5 rounded-lg bg-[#FEE2E2] px-2 py-0.5 text-[10px] font-bold text-[#DC2626]">{text.overdue}</span> : null}
        {task.attachmentCount > 0 ? (
          <span className="ml-auto inline-flex items-center gap-1 text-xs font-medium text-[#6B7280]">
            <Paperclip size={14} />
            {task.attachmentCount}
          </span>
        ) : null}
      </div>
      {assignedBy ? (
        <p className="mt-2 flex items-center gap-1.5 text-xs font-medium text-[#6B7280]">
          <User size={14} />
          {fill(text.assignedBy, { name: assignedBy })}
        </p>
      ) : null}
    </article>
  );
}

// ─── Progress tab (A-080…A-085) ────────────────────────────────────────────

function ProgressTab({ childId, childName, text }: { childId: string; childName: string; text: ParentHomeText }) {
  const live = useLiveShifts(childId);
  if (live.state === "loading") {
    return (
      <div className="flex items-center gap-3 rounded-[20px] bg-[#0F2B57] p-5" role="status">
        <span className="h-5 w-5 animate-spin rounded-full border-[2.4px] border-white border-t-transparent" />
        <span className="text-[13px] font-semibold text-white">Loading student progress insights...</span>
      </div>
    );
  }
  if (live.state === "error") return <ParentErrorCard message="Failed to load progress. Please refresh to try again." />;
  const m = childProgressMetrics(live.value, new Date());
  const delta = m.classesLast7Days - m.classesPrevious7Days;
  const color = trendColor(delta, "#64748B");
  const TrendIcon = delta > 0 ? TrendingUp : delta < 0 ? TrendingDown : MoveRight;
  const status = ATTENTION_COLOR[m.attentionLevel];

  return (
    <div>
      <section className="rounded-[22px] bg-gradient-to-br from-[#0F2B57] to-[#1659B7] p-[18px] shadow-[0_12px_24px_rgba(15,43,87,0.28)]">
        <div className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            <h2 className="text-[19px] font-extrabold text-white">{childName} Progress</h2>
            <p className="mt-1.5 text-[12.5px] leading-[1.35] font-medium text-white/[0.86]">A focused view of attendance, study volume, and class consistency.</p>
          </div>
          <Ring value={m.attendanceRate} label={`${percent(m.attendanceRate)}%`} caption="Attendance" captionSize={10} />
        </div>
        <div className="@container mt-4">
          <div className="grid gap-2.5 @min-[620px]:grid-cols-4">
            <ProgressHeroTile icon={CalendarDays} label="Classes (7d)" value={`${m.classesLast7Days}`} />
            <ProgressHeroTile icon={Clock} label="Hours (30d)" value={m.totalHoursLast30Days.toFixed(1)} />
            <ProgressHeroTile icon={BookOpen} label="Subjects" value={`${m.uniqueSubjectsLast30Days}`} />
            <ProgressHeroTile icon={Flag} label="Status" value={ATTENTION_LABEL[m.attentionLevel]} accent={status} />
          </div>
        </div>
        <div className="mt-4">
          <WeeklyChart counts={m.weeklyCounts} days={m.weekDays} total={m.classesLast7Days} />
        </div>
        <p className="mt-3 flex items-center gap-1.5 text-[11.5px] font-semibold" style={{ color }}>
          <TrendIcon size={16} />
          {trendLabel(delta, "Stable class activity vs previous week")}
        </p>
      </section>

      <section className={`mt-4 rounded-2xl border border-[#E5E7EB] bg-white p-4 ${cardShadow}`}>
        <div className="flex items-center">
          <h3 className="min-w-0 flex-1 text-[15px] font-extrabold text-[#111827]">Attendance Breakdown (30 days)</h3>
          <span className="text-sm font-extrabold text-[#1D4ED8]">{m.totalTrackedClasses === 0 ? "--" : `${percent(m.attendanceRate)}%`}</span>
        </div>
        <div className="mt-3">
          <SplitBar completed={m.completedClasses} missed={m.missedClasses} cancelled={m.cancelledClasses} />
        </div>
        <div className="mt-3 flex">
          <Figure label="Completed" value={`${m.completedClasses}`} color="#16A34A" size={15} />
          <Figure label="Missed" value={`${m.missedClasses}`} color="#DC2626" size={15} />
          <Figure label="Cancelled" value={`${m.cancelledClasses}`} color="#6B7280" size={15} />
          <Figure label="Tracked" value={`${m.totalTrackedClasses}`} color="#111827" size={15} />
        </div>
      </section>

      <div className="mt-4">
        <ParentSectionHeader>Subject Performance</ParentSectionHeader>
      </div>
      <div className="mt-2.5">
        {m.subjectStats.length === 0 ? (
          <ParentEmptyCard icon={ListTree} title={text.noSubjectData} subtitle={text.noSubjectDataBody} />
        ) : (
          <div className="grid gap-3">
            {m.subjectStats.slice(0, 6).map((subject) => (
              <SubjectCard key={subject.name} data={subject} />
            ))}
          </div>
        )}
      </div>
      <div className="h-2" />
    </div>
  );
}

function ProgressHeroTile({ icon: Icon, label, value, accent = "#BFDBFE" }: { icon: typeof Clock; label: string; value: string; accent?: string }) {
  return (
    <div className="flex min-w-0 items-center gap-2.5 rounded-[14px] border border-white/[0.24] bg-white/[0.14] p-3">
      <span className="grid h-[34px] w-[34px] shrink-0 place-items-center rounded-[10px] text-white" style={{ backgroundColor: alpha(accent, 0.28) }}>
        <Icon size={18} />
      </span>
      <span className="min-w-0">
        <span className="block text-base font-extrabold text-white">{value}</span>
        <span className="block text-[11.2px] font-bold text-white/[0.84]">{label}</span>
      </span>
    </div>
  );
}

function Figure({ label, value, color, size }: { label: string; value: string; color: string; size: number }) {
  return (
    <div className="min-w-0 flex-1">
      <p className="font-extrabold" style={{ color, fontSize: size }}>
        {value}
      </p>
      <p className="mt-0.5 text-[10.5px] font-semibold text-[#6B7280]">{label}</p>
    </div>
  );
}

function SubjectCard({ data }: { data: SubjectProgress }) {
  const rate = data.totalClasses > 0 ? data.completedClasses / data.totalClasses : 0;
  const color = completionColor(rate);
  return (
    <div className={`rounded-2xl border border-[#E5E7EB] bg-white p-4 ${cardShadow}`}>
      <div className="flex items-center gap-2">
        <p className="min-w-0 flex-1 text-[15px] font-extrabold text-[#111827]">{data.name}</p>
        <span className="shrink-0 rounded-full px-[9px] py-[5px] text-[10.5px] font-bold" style={{ color, backgroundColor: alpha(color, 0.12) }}>
          {percent(rate)}% completed
        </span>
      </div>
      <div className="mt-2.5 h-2 overflow-hidden rounded-full bg-[#E5E7EB]">
        <div className="h-full" style={{ width: `${Math.min(1, rate) * 100}%`, backgroundColor: color }} />
      </div>
      <div className="mt-3 flex">
        <Figure label="Classes" value={`${data.totalClasses}`} color="#111827" size={14} />
        <Figure label="Completed" value={`${data.completedClasses}`} color="#16A34A" size={14} />
        <Figure label="Hours" value={`${data.totalHours.toFixed(1)}h`} color="#0F766E" size={14} />
      </div>
    </div>
  );
}
