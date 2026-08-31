"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, query, Timestamp, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useEffect, useMemo, useState } from "react";
import { CalendarDays, CheckCircle2, Clock3, Loader2, Lock, Menu, Search, Shuffle, SlidersHorizontal, X } from "lucide-react";
import { auth, db, functions } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;
type TaskTab = "all" | "my" | "today";
type TaskStatus = "todo" | "inProgress" | "done";
type TaskPriority = "low" | "medium" | "high";

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type TeacherTask = {
  id: string;
  title: string;
  description: string;
  createdBy: string;
  assignedTo: string[];
  dueDate: Date | null;
  priority: TaskPriority;
  status: TaskStatus;
  isArchived: boolean;
  labels: string[];
};

const taskTabs: { id: TaskTab; label: string }[] = [
  { id: "all", label: "All Tasks" },
  { id: "my", label: "My Tasks" },
  { id: "today", label: "Today" },
];

export function TeacherTasksPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [tasks, setTasks] = useState<TeacherTask[]>([]);
  const [activeTab, setActiveTab] = useState<TaskTab>("all");
  const [search, setSearch] = useState("");
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [statusFilter, setStatusFilter] = useState<TaskStatus | "all">("all");
  const [priorityFilter, setPriorityFilter] = useState<TaskPriority | "all">("all");
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [user, setUser] = useState<User | null>(null);
  const [selectedTask, setSelectedTask] = useState<TeacherTask | null>(null);
  const [statusBusy, setStatusBusy] = useState(false);
  const [statusError, setStatusError] = useState("");
  const [notice, setNotice] = useState("");

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

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
        const loaded = await loadTeacherTasks(nextUser.uid);
        if (mounted) {
          setTasks(loaded);
          setLoadError("");
        }
      } catch (error) {
        if (mounted) {
          setTasks([]);
          setLoadError(taskLoadErrorMessage(error));
        }
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  useEffect(() => {
    if (!tasks.length || typeof window === "undefined") return;
    const requestedId = new URLSearchParams(window.location.search).get("task")?.trim() ?? "";
    if (!requestedId) return;
    const requested = tasks.find((task) => task.id === requestedId);
    if (requested) setSelectedTask((current) => current?.id === requestedId ? current : requested);
  }, [tasks]);

  const visibleTasks = useMemo(() => {
    const term = search.trim().toLowerCase();
    const today = new Date();
    return tasks.filter((task) => {
      if (task.isArchived) return false;
      if (activeTab === "my" && user && !task.assignedTo.includes(user.uid) && task.createdBy !== user.uid) return false;
      if (activeTab === "today" && !isSameDay(task.dueDate, today)) return false;
      if (statusFilter !== "all" && task.status !== statusFilter) return false;
      if (priorityFilter !== "all" && task.priority !== priorityFilter) return false;
      if (!term) return true;
      return [task.title, task.description, task.priority, task.status, ...task.labels].some((value) => value.toLowerCase().includes(term));
    });
  }, [activeTab, priorityFilter, search, statusFilter, tasks, user]);

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  const retryLoad = async () => {
    if (!user || loading) return;
    setLoading(true);
    setLoadError("");
    try {
      setTasks(await loadTeacherTasks(user.uid));
    } catch (error) {
      setLoadError(taskLoadErrorMessage(error));
    } finally {
      setLoading(false);
    }
  };

  const updateTaskStatus = async (task: TeacherTask, status: TaskStatus) => {
    if (!user || statusBusy || task.status === status) return;
    setStatusBusy(true);
    setStatusError("");
    try {
      const callable = httpsCallable(functions, "updateAssignedTaskStatus");
      await callable({taskId: task.id, status});
      const updated = {...task, status};
      setTasks((current) => current.map((item) => item.id === task.id ? updated : item));
      setSelectedTask(updated);
      setNotice(status === "done" ? "Task submitted successfully" : "Task status updated");
      window.setTimeout(() => setNotice(""), 3000);
      void httpsCallable(functions, "sendTaskStatusUpdateNotification")({
        taskId: task.id,
        taskTitle: task.title,
        oldStatus: task.status,
        newStatus: status,
        updatedByName: summary.displayName,
        createdBy: task.createdBy,
      }).catch(() => undefined);
    } catch (error) {
      setStatusError(cleanFunctionError(error, "Unable to update this task."));
    } finally {
      setStatusBusy(false);
    }
  };

  return (
    <TeacherShell activeLabel="Tasks" breadcrumb="Work / Tasks" summary={summary}>
      <main className="min-h-[calc(100vh-56px)] overflow-y-auto bg-[#F1F4F8] text-[#111827]">
        <MobileTeacherTopBar summary={summary} />
        <section className="border-b border-[#DDE3EA] bg-white px-3 py-2 lg:px-4">
          <div className="flex items-center gap-3">
            <h1 className="shrink-0 text-[20px] font-bold text-[#111827]">Tasks</h1>
            <label className="relative block h-[35px] min-w-0 flex-1 lg:h-[35px]">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" size={19} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search Tasks"
                aria-label="Search tasks"
                className="h-full w-full rounded-full border border-[#CBD5E1] bg-white pl-11 pr-3 text-[15px] font-medium text-[#374151] outline-none focus:border-[#0386FF]"
              />
            </label>
          </div>

          <div className="mt-2 flex gap-5 overflow-x-auto text-[13px]">
            {taskTabs.map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`min-h-7 shrink-0 border-b-2 font-semibold ${
                  activeTab === tab.id ? "border-[#0386FF] text-[#0386FF]" : "border-transparent text-[#64748B]"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <button type="button" onClick={() => setFiltersOpen((current) => !current)} className="mt-2 inline-flex min-h-8 items-center gap-2 text-sm font-medium text-[#0386FF]">
            <SlidersHorizontal size={18} />
            {filtersOpen ? "Hide filters" : "Show filters"}
          </button>

          {filtersOpen ? (
            <div className="mt-2 flex flex-wrap gap-2 pb-2">
              <FilterSelect label="Status" value={statusFilter} onChange={(value) => setStatusFilter(value as TaskStatus | "all")} options={["all", "todo", "inProgress", "done"]} />
              <FilterSelect label="Priority" value={priorityFilter} onChange={(value) => setPriorityFilter(value as TaskPriority | "all")} options={["all", "low", "medium", "high"]} />
            </div>
          ) : null}
        </section>

        <section className="relative min-h-[calc(100vh-178px)]">
          {loading ? (
            <div className="grid min-h-[560px] place-items-center">
              <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
            </div>
          ) : loadError ? (
            <TaskLoadFailure message={loadError} onRetry={() => void retryLoad()} />
          ) : visibleTasks.length === 0 ? (
            <EmptyTasks />
          ) : (
            <div className="grid gap-4 p-4 md:grid-cols-2 xl:grid-cols-3">
              {visibleTasks.map((task) => (
                <TaskCard key={task.id} task={task} onOpen={() => { setSelectedTask(task); setStatusError(""); }} />
              ))}
            </div>
          )}
        </section>
        {notice ? <div className="fixed bottom-5 right-5 z-50 rounded-xl bg-[#111827] px-4 py-3 text-sm font-semibold text-white shadow-lg">{notice}</div> : null}
        {selectedTask ? (
          <TaskDetailsDialog
            task={selectedTask}
            busy={statusBusy}
            error={statusError}
            onClose={() => setSelectedTask(null)}
            onStatusChange={(status) => void updateTaskStatus(selectedTask, status)}
          />
        ) : null}
      </main>
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-[64px] grid-cols-[56px_1fr_96px] items-center bg-white px-3 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={24} />
      </button>
      <div className="min-w-0 text-center text-[16px] font-semibold text-[#111827]">Alluwal Education Hub</div>
      <div className="flex items-center justify-end gap-3">
        <button type="button" aria-label="Open teacher account options" onClick={openTeacherMobileMenu} className="grid h-10 w-10 place-items-center rounded-xl text-[#111827]"><Shuffle size={18} /></button>
        <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[12px] font-black text-white">{summary.initials}</span>
      </div>
    </header>
  );
}

function FilterSelect({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (value: string) => void }) {
  return (
    <label className="inline-flex min-h-9 items-center gap-2 rounded-xl border border-[#CBD5E1] bg-white px-3 text-sm text-[#374151]">
      {label}
      <select value={value} onChange={(event) => onChange(event.target.value)} className="bg-transparent text-sm font-semibold outline-none">
        {options.map((option) => (
          <option key={option} value={option}>
            {option === "all" ? "All" : labelFor(option)}
          </option>
        ))}
      </select>
    </label>
  );
}

function EmptyTasks() {
  return (
    <div className="grid min-h-[590px] place-items-center lg:min-h-[660px]">
      <div className="text-center">
        <div className="mx-auto grid h-[100px] w-[100px] place-items-center rounded-full bg-[#E5E7EB] text-[#BDBDBD]">
          <Search size={54} />
        </div>
        <div className="mt-7 text-2xl font-semibold text-[#111827]">No Tasks Found</div>
        <div className="mt-3 text-base tracking-wide text-[#6B7280]">Try Adjusting Your Filters Or Search</div>
      </div>
    </div>
  );
}

function TaskLoadFailure({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="grid min-h-[590px] place-items-center px-4 lg:min-h-[660px]" role="alert">
      <div className="max-w-md text-center">
        <div className="mx-auto grid h-[82px] w-[82px] place-items-center rounded-full bg-[#FEE2E2] text-[#B91C1C]"><Lock size={38} /></div>
        <h2 className="mt-5 text-xl font-bold text-[#111827]">Could not load tasks</h2>
        <p className="mt-2 text-sm text-[#64748B]">{message}</p>
        <button type="button" onClick={onRetry} className="mt-5 min-h-11 rounded-xl bg-[#0386FF] px-5 text-sm font-bold text-white">Try again</button>
      </div>
    </div>
  );
}

function TaskCard({ task, onOpen }: { task: TeacherTask; onOpen: () => void }) {
  const overdue = Boolean(task.dueDate && task.dueDate < new Date() && task.status !== "done");
  return (
    <article className="rounded-xl border border-[#E5E7EB] bg-white p-4 shadow-sm">
      <div className="flex items-start gap-3">
        <span className={`mt-1 grid h-8 w-8 shrink-0 place-items-center rounded-xl ${task.status === "done" ? "bg-[#DCFCE7] text-[#16A34A]" : "bg-[#E6F3FF] text-[#0386FF]"}`}>
          {task.status === "done" ? <CheckCircle2 size={18} /> : <Clock3 size={18} />}
        </span>
        <div className="min-w-0 flex-1">
          <h2 className="truncate text-base font-bold text-[#111827]">{task.title}</h2>
          <p className="mt-1 line-clamp-2 min-h-10 text-sm text-[#64748B]">{task.description || "No description"}</p>
        </div>
      </div>
      <div className="mt-4 flex flex-wrap items-center gap-2 text-xs text-[#64748B]">
        <span className={`inline-flex items-center gap-1 rounded-full px-2 py-1 font-semibold ${overdue ? "bg-[#FEE2E2] text-[#B91C1C]" : "bg-[#F8FAFC]"}`}>
          <CalendarDays size={13} />
          {task.dueDate ? `Due ${task.dueDate.toLocaleDateString("en-US", { month: "short", day: "numeric" })}` : "No due date"}
        </span>
        <span className="rounded-full bg-[#F8FAFC] px-2 py-1 font-semibold">{labelFor(task.status)}</span>
        <span className="rounded-full bg-[#F8FAFC] px-2 py-1 font-semibold">{labelFor(task.priority)}</span>
      </div>
      <button type="button" onClick={onOpen} className="mt-4 min-h-10 w-full rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] text-sm font-bold text-[#0369A1] hover:bg-[#DBEAFE]">
        View and update
      </button>
    </article>
  );
}

function TaskDetailsDialog({ task, busy, error, onClose, onStatusChange }: { task: TeacherTask; busy: boolean; error: string; onClose: () => void; onStatusChange: (status: TaskStatus) => void }) {
  return (
    <div className="fixed inset-0 z-50 grid place-items-end bg-black/40 sm:place-items-center sm:p-6" role="dialog" aria-modal="true" aria-label={`${task.title} details`}>
      <section className="max-h-[90vh] w-full overflow-y-auto rounded-t-3xl bg-white p-5 shadow-2xl sm:max-w-xl sm:rounded-2xl">
        <header className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            <p className="text-xs font-black uppercase tracking-wide text-[#0386FF]">Task details</p>
            <h2 className="mt-1 text-xl font-black text-[#111827]">{task.title}</h2>
          </div>
          <button type="button" aria-label="Close task details" onClick={onClose} disabled={busy} className="grid h-10 w-10 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9] disabled:opacity-50"><X size={20} /></button>
        </header>
        <p className="mt-4 whitespace-pre-wrap text-sm leading-6 text-[#475569]">{task.description || "No description"}</p>
        <div className="mt-4 grid gap-2 rounded-xl bg-[#F8FAFC] p-4 text-sm">
          <p><span className="font-bold text-[#64748B]">Due:</span> {task.dueDate ? task.dueDate.toLocaleString() : "No due date"}</p>
          <p><span className="font-bold text-[#64748B]">Priority:</span> {labelFor(task.priority)}</p>
          {task.labels.length ? <p><span className="font-bold text-[#64748B]">Labels:</span> {task.labels.join(", ")}</p> : null}
        </div>
        <h3 className="mt-5 text-sm font-black text-[#111827]">Update status</h3>
        <div className="mt-2 grid grid-cols-3 gap-2">
          {(["todo", "inProgress", "done"] as TaskStatus[]).map((status) => (
            <button key={status} type="button" onClick={() => onStatusChange(status)} disabled={busy || status === task.status} className={`min-h-11 rounded-xl px-2 text-xs font-bold disabled:cursor-default ${status === task.status ? "bg-[#0386FF] text-white" : "border border-[#CBD5E1] bg-white text-[#475569] hover:bg-[#F8FAFC]"}`}>
              {busy && status !== task.status ? <Loader2 size={16} className="mx-auto animate-spin" /> : labelFor(status)}
            </button>
          ))}
        </div>
        {error ? <p className="mt-3 rounded-xl bg-[#FEE2E2] px-3 py-2 text-sm font-semibold text-[#B91C1C]" role="alert">{error}</p> : null}
      </section>
    </div>
  );
}

async function loadTeacherTasks(uid: string) {
  const assigned = await getDocs(query(collection(db, "tasks"), where("assignedTo", "array-contains", uid), limit(100)));
  const byId = new Map<string, TeacherTask>();
  assigned.docs.forEach((entry) => {
    byId.set(entry.id, normalizeTask(entry.id, entry.data() as Record<string, unknown>));
  });
  return Array.from(byId.values()).sort((a, b) => (a.dueDate?.getTime() ?? Number.MAX_SAFE_INTEGER) - (b.dueDate?.getTime() ?? Number.MAX_SAFE_INTEGER));
}

function normalizeTask(id: string, data: Record<string, unknown>): TeacherTask {
  return {
    id,
    title: stringValue(data.title) || "Untitled Task",
    description: stringValue(data.description),
    createdBy: stringValue(data.createdBy ?? data.created_by),
    assignedTo: arrayOfStrings(data.assignedTo ?? data.assigned_to),
    dueDate: dateValue(data.dueDate ?? data.due_date),
    priority: parsePriority(data.priority),
    status: parseStatus(data.status),
    isArchived: data.isArchived === true || data.is_archived === true,
    labels: arrayOfStrings(data.labels),
  };
}

function parsePriority(value: unknown): TaskPriority {
  const normalized = stringValue(value).replace("TaskPriority.", "");
  if (normalized === "low" || normalized === "high") return normalized;
  return "medium";
}

function parseStatus(value: unknown): TaskStatus {
  const normalized = stringValue(value).replace("TaskStatus.", "");
  if (normalized === "inProgress" || normalized === "done") return normalized;
  return "todo";
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
  if (Array.isArray(value)) return value.map((item) => stringValue(item)).filter(Boolean);
  const single = stringValue(value);
  return single ? [single] : [];
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

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function cleanFunctionError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String(error || "");
  if (/not-found|task not found/i.test(message)) return "This task is no longer available. Close it and refresh your task list.";
  if (/permission-denied|only assigned users/i.test(message)) return "You are no longer assigned to this task and cannot update it.";
  if (/unavailable|network|offline/i.test(message) || !navigator.onLine) return "You appear to be offline. Reconnect and try again.";
  return message.replace(/^Firebase:\s*/i, "").replace(/^functions\//i, "").trim() || fallback;
}

function taskLoadErrorMessage(error: unknown) {
  const message = error instanceof Error ? error.message : String(error || "");
  if (/permission-denied/i.test(message)) return "You do not have permission to view assigned tasks. Contact an administrator if this continues.";
  if (/unavailable|network|offline/i.test(message) || !navigator.onLine) return "You appear to be offline. Reconnect and try again.";
  return "Check your connection and try again. If the problem continues, contact an administrator.";
}

function labelFor(value: string) {
  return value.replace(/([A-Z])/g, " $1").replace(/^./, (letter) => letter.toUpperCase());
}

function initialsFromName(name: string) {
  const parts = name.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "TE";
}
