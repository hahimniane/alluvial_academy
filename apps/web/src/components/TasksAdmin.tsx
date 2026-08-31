"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { addDoc, collection, getDocs, limit, query, serverTimestamp, Timestamp, updateDoc, doc } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  Archive,
  CalendarDays,
  CheckCircle2,
  Circle,
  Clock3,
  Filter,
  Lock,
  Plus,
  Search,
  SlidersHorizontal,
  X,
} from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type TaskTab = "all" | "my_tasks" | "today" | "drafts";
type TaskStatus = "todo" | "inProgress" | "done";
type TaskPriority = "low" | "medium" | "high";

type TaskRecord = {
  id: string;
  title: string;
  description: string;
  createdBy: string;
  assignedTo: string[];
  dueDate: Date | null;
  priority: TaskPriority;
  status: TaskStatus;
  isArchived: boolean;
  isDraft: boolean;
  labels: string[];
};

const taskTabs: { id: TaskTab; label: string }[] = [
  { id: "all", label: "All Tasks" },
  { id: "my_tasks", label: "My Tasks" },
  { id: "today", label: "Today" },
  { id: "drafts", label: "Drafts" },
];

export function TasksAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [tasks, setTasks] = useState<TaskRecord[]>([]);
  const [activeTab, setActiveTab] = useState<TaskTab>("all");
  const [search, setSearch] = useState("");
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [statusFilter, setStatusFilter] = useState<TaskStatus | "all">("all");
  const [priorityFilter, setPriorityFilter] = useState<TaskPriority | "all">("all");
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [addOpen, setAddOpen] = useState(false);

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
        setTasks(await loadTasks());
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load tasks.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const filteredTasks = useMemo(() => {
    const term = search.trim().toLowerCase();
    const today = new Date();
    return tasks.filter((task) => {
      if (activeTab !== "drafts" && task.isDraft) return false;
      if (activeTab === "drafts" && !task.isDraft) return false;
      if (activeTab === "today" && !isSameDay(task.dueDate, today)) return false;
      if (activeTab === "my_tasks" && user && !task.assignedTo.includes(user.uid) && task.createdBy !== user.uid) return false;
      if (statusFilter !== "all" && task.status !== statusFilter) return false;
      if (priorityFilter !== "all" && task.priority !== priorityFilter) return false;
      if (!term) return true;
      return [task.title, task.description, task.priority, task.status, ...task.labels].some((value) => value.toLowerCase().includes(term));
    });
  }, [activeTab, priorityFilter, search, statusFilter, tasks, user]);

  const openTasks = filteredTasks.filter((task) => task.status !== "done").length;
  const doneTasks = filteredTasks.filter((task) => task.status === "done").length;

  async function addTask(input: { title: string; description: string; dueDate: string; priority: TaskPriority; draft: boolean }) {
    if (!user) return;
    const dueDate = input.dueDate ? new Date(`${input.dueDate}T17:00:00`) : new Date();
    const docRef = await addDoc(collection(db, "tasks"), {
      title: input.title,
      description: input.description,
      createdBy: user.uid,
      assignedTo: [user.uid],
      dueDate: Timestamp.fromDate(dueDate),
      priority: `TaskPriority.${input.priority}`,
      status: "TaskStatus.todo",
      isRecurring: false,
      recurrenceType: "RecurrenceType.none",
      enhancedRecurrence: { type: "none" },
      createdAt: serverTimestamp(),
      attachments: [],
      isArchived: false,
      isDraft: input.draft,
      labels: [],
      subTaskIds: [],
      ...(input.draft ? {} : { publishedAt: serverTimestamp() }),
    });
    setTasks((current) => [
      normalizeTask(docRef.id, {
        title: input.title,
        description: input.description,
        createdBy: user.uid,
        assignedTo: [user.uid],
        dueDate: Timestamp.fromDate(dueDate),
        priority: `TaskPriority.${input.priority}`,
        status: "TaskStatus.todo",
        isDraft: input.draft,
      }),
      ...current,
    ]);
    setMessage(input.draft ? "Draft task saved." : "Task added.");
    setAddOpen(false);
  }

  async function markDone(task: TaskRecord) {
    await updateDoc(doc(db, "tasks", task.id), {
      status: "TaskStatus.done",
      completedAt: serverTimestamp(),
    });
    setTasks((current) => current.map((item) => (item.id === task.id ? { ...item, status: "done" } : item)));
  }

  if (access !== "allowed") {
    return <TasksAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Tasks" breadcrumb="Operations / Tasks">
      <main className="min-h-[calc(100vh-56px)] bg-[#F1F4F8] text-[#111827]">
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

        <section className="border-b border-[#E5E7EB] bg-white px-3 py-2 lg:px-4">
          <div className="flex items-center gap-3">
            <h1 className="text-xl font-bold text-[#111827]">Tasks</h1>
            <label className="relative block h-10 min-w-0 flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" size={19} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search Tasks"
                aria-label="Search tasks"
                className="h-full w-full rounded-full border border-[#CBD5E1] bg-white pl-10 pr-3 text-sm outline-none focus:border-[#0386FF]"
              />
            </label>
          </div>

          <div className="mt-2 flex gap-5 overflow-x-auto text-sm">
            {taskTabs.map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`min-h-8 shrink-0 border-b-2 font-semibold ${
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

        {message ? (
          <div className="mx-3 mt-3 rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-4 py-3 text-sm font-semibold text-[#1D4ED8] lg:mx-4">
            {message}
          </div>
        ) : null}

        <section className="relative min-h-[680px]">
          {loading ? (
            <div className="grid min-h-[600px] place-items-center">
              <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
            </div>
          ) : filteredTasks.length === 0 ? (
            <EmptyTasks />
          ) : (
            <div className="p-4">
              <div className="mb-4 grid gap-3 sm:grid-cols-3">
                <SummaryCard label="Total Tasks" value={filteredTasks.length} icon={Filter} color="#0386FF" />
                <SummaryCard label="Open Tasks" value={openTasks} icon={Circle} color="#F59E0B" />
                <SummaryCard label="Done Tasks" value={doneTasks} icon={CheckCircle2} color="#10B981" />
              </div>
              <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                {filteredTasks.map((task) => (
                  <TaskCard key={task.id} task={task} onDone={markDone} />
                ))}
              </div>
            </div>
          )}
          <button
            type="button"
            onClick={() => setAddOpen(true)}
            className="fixed bottom-4 right-4 z-20 inline-flex min-h-14 items-center gap-3 rounded-2xl bg-[#2196F3] px-7 text-base font-medium text-[#0F172A] shadow-xl lg:bottom-6 lg:right-6"
          >
            <Plus size={22} />
            Add Task
          </button>
        </section>

        {addOpen ? <AddTaskDialog onClose={() => setAddOpen(false)} onSubmit={addTask} /> : null}
      </main>
    </AdminDashboardShell>
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

function SummaryCard({ label, value, icon: Icon, color }: { label: string; value: number; icon: typeof Filter; color: string }) {
  return (
    <article className="rounded-xl border border-[#E5E7EB] bg-white p-4 shadow-sm">
      <div className="flex items-center gap-3">
        <span className="grid h-10 w-10 place-items-center rounded-xl" style={{ backgroundColor: `${color}1A`, color }}>
          <Icon size={20} />
        </span>
        <div>
          <div className="text-2xl font-bold">{value}</div>
          <div className="text-sm text-[#64748B]">{label}</div>
        </div>
      </div>
    </article>
  );
}

function TaskCard({ task, onDone }: { task: TaskRecord; onDone: (task: TaskRecord) => void }) {
  const overdue = Boolean(task.dueDate && task.dueDate < new Date() && task.status !== "done");
  return (
    <article className="rounded-xl border border-[#E5E7EB] bg-white p-4 shadow-sm">
      <div className="flex items-start gap-3">
        <span className={`mt-1 h-3 w-3 rounded-full ${task.status === "done" ? "bg-[#10B981]" : task.status === "inProgress" ? "bg-[#F59E0B]" : "bg-[#0386FF]"}`} />
        <div className="min-w-0 flex-1">
          <h2 className="truncate text-base font-bold text-[#111827]">{task.title}</h2>
          <p className="mt-1 line-clamp-2 min-h-10 text-sm text-[#64748B]">{task.description || "No description"}</p>
        </div>
        <PriorityPill priority={task.priority} />
      </div>
      <div className="mt-4 flex flex-wrap items-center gap-2 text-xs text-[#64748B]">
        <span className={`inline-flex items-center gap-1 rounded-full px-2 py-1 font-semibold ${overdue ? "bg-[#FEE2E2] text-[#B91C1C]" : "bg-[#F8FAFC]"}`}>
          <CalendarDays size={13} />
          {task.dueDate ? `Due ${task.dueDate.toLocaleDateString("en-US", { month: "short", day: "numeric" })}` : "No due date"}
        </span>
        <span className="inline-flex items-center gap-1 rounded-full bg-[#F8FAFC] px-2 py-1 font-semibold">
          <Clock3 size={13} />
          {labelFor(task.status)}
        </span>
        {task.isDraft ? <span className="rounded-full bg-[#F3F4F6] px-2 py-1 font-semibold text-[#4B5563]">Draft</span> : null}
        {task.isArchived ? <Archive size={14} /> : null}
      </div>
      {task.status !== "done" ? (
        <button type="button" onClick={() => onDone(task)} className="mt-4 min-h-9 rounded-xl bg-[#EFF6FF] px-3 text-sm font-semibold text-[#0386FF]">
          Mark Done
        </button>
      ) : null}
    </article>
  );
}

function PriorityPill({ priority }: { priority: TaskPriority }) {
  const style = priority === "high" ? "bg-[#FEE2E2] text-[#B91C1C]" : priority === "medium" ? "bg-[#FEF3C7] text-[#B45309]" : "bg-[#DCFCE7] text-[#15803D]";
  return <span className={`rounded-full px-2 py-1 text-xs font-bold ${style}`}>{labelFor(priority)}</span>;
}

function EmptyTasks() {
  return (
    <div className="grid min-h-[660px] place-items-center">
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

function AddTaskDialog({
  onClose,
  onSubmit,
}: {
  onClose: () => void;
  onSubmit: (input: { title: string; description: string; dueDate: string; priority: TaskPriority; draft: boolean }) => void;
}) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [dueDate, setDueDate] = useState(new Date().toISOString().slice(0, 10));
  const [priority, setPriority] = useState<TaskPriority>("medium");
  const [draft, setDraft] = useState(false);

  return (
    <div className="fixed inset-0 z-40 grid place-items-center bg-black/35 p-4" role="dialog" aria-modal="true" aria-label="Add Task">
      <form
        className="w-full max-w-md rounded-2xl bg-white p-5 shadow-2xl"
        onSubmit={(event) => {
          event.preventDefault();
          if (!title.trim()) return;
          onSubmit({ title: title.trim(), description: description.trim(), dueDate, priority, draft });
        }}
      >
        <div className="flex items-center gap-3">
          <h2 className="flex-1 text-xl font-bold">Add Task</h2>
          <button type="button" aria-label="Close add task" onClick={onClose} className="grid h-9 w-9 place-items-center rounded-lg hover:bg-[#F8FAFC]">
            <X size={18} />
          </button>
        </div>
        <label className="mt-4 block text-sm font-semibold">
          Title
          <input value={title} onChange={(event) => setTitle(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3 outline-none focus:border-[#0386FF]" />
        </label>
        <label className="mt-3 block text-sm font-semibold">
          Description
          <textarea value={description} onChange={(event) => setDescription(event.target.value)} className="mt-2 min-h-24 w-full rounded-xl border border-[#CBD5E1] px-3 py-2 outline-none focus:border-[#0386FF]" />
        </label>
        <div className="mt-3 grid grid-cols-2 gap-3">
          <label className="block text-sm font-semibold">
            Due date
            <input type="date" value={dueDate} onChange={(event) => setDueDate(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3 outline-none focus:border-[#0386FF]" />
          </label>
          <label className="block text-sm font-semibold">
            Priority
            <select value={priority} onChange={(event) => setPriority(event.target.value as TaskPriority)} className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3 outline-none focus:border-[#0386FF]">
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
            </select>
          </label>
        </div>
        <label className="mt-4 flex items-center gap-2 text-sm font-semibold">
          <input type="checkbox" checked={draft} onChange={(event) => setDraft(event.target.checked)} className="h-5 w-5 accent-[#0386FF]" />
          Save as draft
        </label>
        <button type="submit" className="mt-5 min-h-11 w-full rounded-xl bg-[#0386FF] text-sm font-bold text-white">
          Save Task
        </button>
      </form>
    </div>
  );
}

function TasksAccessPrompt({ access }: { access: AccessState }) {
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
              ? "Sign in with an administrator account before managing tasks."
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

async function loadTasks() {
  const snap = await getDocs(query(collection(db, "tasks"), limit(500)));
  return snap.docs
    .map((docSnap) => normalizeTask(docSnap.id, docSnap.data() as Record<string, unknown>))
    .sort((a, b) => (a.dueDate?.getTime() ?? 0) - (b.dueDate?.getTime() ?? 0));
}

function normalizeTask(id: string, data: Record<string, unknown>): TaskRecord {
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
    isDraft: data.isDraft === true || data.is_draft === true,
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

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function labelFor(value: string) {
  return value.replace(/([A-Z])/g, " $1").replace(/^./, (letter) => letter.toUpperCase());
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Admin";
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}
