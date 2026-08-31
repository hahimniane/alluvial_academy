"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import {
  collection,
  getCountFromServer,
  getDocs,
  limit,
  orderBy,
  query,
  Timestamp,
  where,
} from "firebase/firestore";
import { useEffect, useState } from "react";
import {
  ArrowRight,
  CalendarClock,
  ClipboardCheck,
  ClipboardList,
  ExternalLink,
  LayoutDashboard,
  Lock,
  Menu,
  ReceiptText,
  School,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type CardState = "loading" | "ready" | "error";

type AdminCard = {
  id: string;
  title: string;
  icon: LucideIcon;
  accentColor: string;
  viewAllLabel: string;
  href: string;
  state: CardState;
  emptyText: string;
  lines: string[];
  footer?: string;
};

const cardDefaults: AdminCard[] = [
  {
    id: "timesheets",
    title: "Pending timesheets",
    icon: ReceiptText,
    accentColor: "#8B5CF6",
    viewAllLabel: "Timesheet review",
    href: "/app/#/login",
    state: "loading",
    emptyText: "No pending timesheets",
    lines: [],
  },
  {
    id: "tasks",
    title: "Overdue tasks",
    icon: ClipboardCheck,
    accentColor: "#14B8A6",
    viewAllLabel: "Open tasks",
    href: "/app/#/login",
    state: "loading",
    emptyText: "No overdue tasks",
    lines: [],
  },
  {
    id: "submissions",
    title: "Recent submissions",
    icon: ClipboardList,
    accentColor: "#0EA5E9",
    viewAllLabel: "All submissions",
    href: "/app/#/login",
    state: "loading",
    emptyText: "No submissions yet",
    lines: [],
  },
  {
    id: "shifts",
    title: "Upcoming shifts",
    icon: CalendarClock,
    accentColor: "#F59E0B",
    viewAllLabel: "Open shifts",
    href: "/app/#/login",
    state: "loading",
    emptyText: "No upcoming shifts",
    lines: [],
  },
  {
    id: "applicants",
    title: "Applicants to review",
    icon: School,
    accentColor: "#DC2626",
    viewAllLabel: "Review applications",
    href: "/admin/student-applicants/",
    state: "loading",
    emptyText: "No applicants to review",
    lines: [],
  },
  {
    id: "website",
    title: "Public pricing & team",
    icon: Users,
    accentColor: "#059669",
    viewAllLabel: "Open editor",
    href: "/admin/public-site-cms/",
    state: "loading",
    emptyText: "Team on website: 0",
    lines: ["Change landing prices, bullet lines, and who appears on the Team page."],
  },
];

export default function AdminDashboardPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [cards, setCards] = useState<AdminCard[]>(cardDefaults);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      if (!nextUser) {
        setAccess("signedOut");
        setCards(cardDefaults);
        return;
      }

      setAccess("checking");
      try {
        const allowed = await isCurrentUserAdmin(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setCards(cardDefaults);
          return;
        }
        setAccess("allowed");
        setCards(cardDefaults);
        loadAdminCards().then((nextCards) => {
          if (mounted) setCards(nextCards);
        });
      } catch {
        if (mounted) setAccess("denied");
      }
    });
  }, []);

  if (access !== "allowed") {
    return <AdminAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Dashboard" breadcrumb="Overview / Dashboard">
      <AdminHomeContent cards={cards} user={user} />
    </AdminDashboardShell>
  );
}

function AdminHomeContent({ cards, user }: { cards: AdminCard[]; user: User | null }) {
  const firstName = firstNameFor(user);
  const greeting = greetingForNow();
  return (
    <div className="min-h-[calc(100vh-56px)] overflow-y-auto px-4 pb-24 pt-4 lg:px-6 lg:pb-8 lg:pt-6">
      <header className="mb-4 lg:hidden">
        <div className="grid min-h-14 grid-cols-[48px_1fr_96px] items-center rounded-2xl bg-white px-3 text-[#0F172A] shadow-sm">
          <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl text-[#0F172A]">
            <Menu size={22} />
          </button>
          <div className="min-w-0 text-center">
            <div className="truncate text-sm font-black text-[#0F172A]">Alluwal Education Hub</div>
            <div className="truncate text-[10px] font-bold text-[#94A3B8]">Dashboard</div>
          </div>
          <div className="flex items-center justify-end gap-2">
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">
              {initialsFor(user)}
            </span>
          </div>
        </div>
      </header>

      <section className="rounded-[24px] bg-gradient-to-br from-[#168BEE] to-[#0D83F0] p-[22px] text-white shadow-[0_12px_24px_rgba(22,139,238,0.3)] lg:rounded-2xl lg:from-[#667EEA] lg:to-[#764BA2] lg:p-7 lg:shadow-[0_12px_28px_rgba(102,126,234,0.24)]">
        <div className="flex items-center gap-5">
          <div className="min-w-0 flex-1">
            <p className="text-sm font-semibold text-white/90 lg:hidden">{greeting}</p>
            <h1 className="text-[26px] font-black leading-tight lg:text-[28px]">
              <span className="lg:hidden">{firstName}</span>
              <span className="hidden lg:inline">Welcome Back, {firstName}</span>
            </h1>
            <p className="mt-2 text-[13px] font-medium text-white/80 lg:text-base lg:font-semibold lg:text-white/90">
              <span className="lg:hidden">You&apos;re managing as Administrator</span>
              <span className="hidden lg:inline">You&apos;re signed in as Administrator</span>
            </p>
            <p className="mt-8 text-[13px] font-medium leading-6 text-white/80 lg:mt-4 lg:text-sm">
              <span className="lg:hidden">Quick actions are available below.</span>
              <span className="hidden lg:inline">Manage your educational institution with powerful admin tools.</span>
            </p>
          </div>
          <span className="grid h-14 w-14 shrink-0 place-items-center rounded-[18px] bg-white/20 lg:h-20 lg:w-20 lg:rounded-2xl">
            <LayoutDashboard size={32} className="lg:hidden" />
            <LayoutDashboard size={42} className="hidden lg:block" />
          </span>
        </div>
      </section>

      <section className="mt-6 grid gap-5 xl:grid-cols-2">
        {cards.slice(0, 4).map((card) => (
          <AdminActionCard key={card.id} card={card} />
        ))}
      </section>

      <section className="mt-5 grid gap-5">
        {cards.slice(4).map((card) => (
          <AdminActionCard key={card.id} card={card} wide />
        ))}
      </section>
    </div>
  );
}

function AdminActionCard({ card, wide = false }: { card: AdminCard; wide?: boolean }) {
  const Icon = card.icon;
  return (
    <article
      className={`rounded-2xl border bg-white p-4 shadow-sm ${wide ? "" : "min-h-[188px]"}`}
      style={{ borderColor: alphaHex(card.accentColor, "2E") }}
    >
      <div className="flex items-start gap-3">
        <span className="grid h-[34px] w-[34px] shrink-0 place-items-center rounded-xl" style={{ backgroundColor: alphaHex(card.accentColor, "1F") }}>
          <Icon size={18} style={{ color: card.accentColor }} />
        </span>
        <h2 className="min-w-0 flex-1 text-sm font-black leading-5 text-[#111827]">{card.title}</h2>
      </div>

      <div className="mt-3 min-h-[72px]">
        {card.state === "loading" ? (
          <div className="grid gap-3 py-1">
            {Array.from({ length: 3 }).map((_, index) => (
              <div key={index} className="flex items-center gap-3">
                <span className="h-2.5 w-2.5 rounded-full bg-[#E5E7EB]" />
                <span className="h-2.5 flex-1 rounded-full bg-[#E5E7EB]" />
              </div>
            ))}
          </div>
        ) : null}
        {card.state === "error" ? <p className="py-2 text-xs font-semibold text-[#6B7280]">Error loading {card.title.toLowerCase()}</p> : null}
        {card.state === "ready" && card.lines.length === 0 ? (
          <p className="py-2 text-xs font-semibold text-[#6B7280]">{card.emptyText}</p>
        ) : null}
        {card.state === "ready" && card.lines.length > 0 ? (
          <div className="grid gap-3">
            {card.lines.map((line) => (
              <div key={line} className="flex min-w-0 items-center gap-3">
                <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: alphaHex(card.accentColor, "40") }} />
                <p className="min-w-0 flex-1 truncate text-xs font-bold text-[#374151]">{line}</p>
              </div>
            ))}
          </div>
        ) : null}
        {card.footer ? <p className="mt-3 text-xs font-bold text-[#374151]">{card.footer}</p> : null}
      </div>

      <div className="mt-3 flex justify-end">
        <Link
          href={card.href}
          className="inline-flex min-h-9 items-center gap-2 rounded-xl px-3 text-xs font-bold"
          style={{ color: card.accentColor }}
        >
          {card.viewAllLabel}
          <ArrowRight size={15} />
        </Link>
      </div>
    </article>
  );
}

function AdminAccessPrompt({ access }: { access: AccessState }) {
  const isChecking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F1F4F8] px-5 text-[#0F172A]">
      <section className="w-full max-w-md rounded-[20px] border border-black/10 bg-white px-6 py-10 text-center shadow-sm">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#E6EEF8] text-[#001E4E]">
          <Lock size={24} />
        </div>
        <h1 className="mt-4 text-xl font-bold">
          {isChecking ? "Checking admin access" : access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {isChecking
            ? "Please wait while we verify your dashboard permissions."
            : access === "signedOut"
              ? "Sign in with an administrator account before opening the dashboard."
              : "Your signed-in account does not have administrator permissions for this dashboard."}
        </p>
        {!isChecking ? (
          <Link href="/login/" className="mt-5 inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-[#001E4E] px-5 text-sm font-semibold text-white">
            Go to login
            <ExternalLink size={16} />
          </Link>
        ) : null}
      </section>
    </main>
  );
}

async function loadAdminCards() {
  const [
    timesheets,
    tasks,
    submissions,
    shifts,
    applicants,
    website,
  ] = await Promise.all([
    readLines(
      "timesheets",
      query(collection(db, "timesheet_entries"), where("status", "==", "pending"), limit(5)),
      (data) => `${stringValue(data.student_name ?? data.subject) || "Pending"}${stringValue(data.date) ? ` • ${stringValue(data.date)}` : ""}`,
    ),
    readOverdueTasks(),
    readLines(
      "submissions",
      query(collection(db, "form_responses"), orderBy("submittedAt", "desc"), limit(5)),
      (data) => `${stringValue(data.formTitle ?? data.form_title ?? data.title) || "Form"}${dateLabel(data.submittedAt) ? ` • ${dateLabel(data.submittedAt)}` : ""}`,
    ),
    readLines(
      "shifts",
      query(collection(db, "teaching_shifts"), where("shift_start", ">=", Timestamp.now()), orderBy("shift_start", "asc"), limit(5)),
      (data) => {
        const students = Array.isArray(data.student_names) ? data.student_names : [];
        const student = stringValue(students[0]) || "Shift";
        const subject = stringValue(data.subject_display_name ?? data.subject);
        const date = dateLabel(data.shift_start);
        return `${student}${subject ? ` • ${subject}` : ""}${date ? ` • ${date}` : ""}`;
      },
    ),
    readApplicants(),
    readWebsiteCard(),
  ]);

  return cardDefaults.map((card) => {
    const next = [timesheets, tasks, submissions, shifts, applicants, website].find((item) => item.id === card.id);
    return next ? { ...card, ...next } : card;
  });
}

async function readLines(id: string, cardQuery: ReturnType<typeof query>, mapLine: (data: Record<string, unknown>) => string) {
  try {
    const snap = await getDocs(cardQuery);
    return {
      id,
      state: "ready" as const,
      lines: snap.docs.map((docSnap) => mapLine(docSnap.data() as Record<string, unknown>)).filter(Boolean),
    };
  } catch {
    return { id, state: "error" as const, lines: [] };
  }
}

async function readOverdueTasks() {
  try {
    const snap = await getDocs(query(collection(db, "tasks"), where("dueDate", "<", Timestamp.now()), limit(20)));
    const lines = snap.docs
      .map((docSnap) => docSnap.data())
      .filter((data) => !stringValue(data.status).toLowerCase().includes("done"))
      .slice(0, 5)
      .map((data) => {
        const title = stringValue(data.title) || "Task";
        const due = dateLabel(data.dueDate);
        return due ? `${title} • Due ${due}` : title;
      });
    return { id: "tasks", state: "ready" as const, lines };
  } catch {
    return { id: "tasks", state: "error" as const, lines: [] };
  }
}

async function readApplicants() {
  const studentLines = await readStudentApplicantLines();
  const teacherLines = await readTeacherApplicantLines();
  return {
    id: "applicants",
    state: "ready" as const,
    lines: [
      ...(studentLines.length ? ["Students", ...studentLines] : ["No student applicants"]),
      ...(teacherLines.length ? ["Teachers", ...teacherLines] : ["No teacher applicants"]),
    ].slice(0, 7),
  };
}

async function readStudentApplicantLines() {
  try {
    const studentSnap = await getDocs(query(collection(db, "enrollments"), where("metadata.status", "==", "pending"), limit(5)));
    return studentSnap.docs.map((docSnap) => {
      const data = docSnap.data();
      const student = nestedString(data.student, "name") || stringValue(data.studentName) || "Student";
      const subject = stringValue(data.programTitle ?? data.subject);
      return `${student}${subject ? ` • ${subject}` : ""}`;
    });
  } catch {
    return [];
  }
}

async function readTeacherApplicantLines() {
  try {
    const teacherSnap = await getDocs(query(collection(db, "teacher_applications"), where("status", "==", "pending"), limit(5)));
    return teacherSnap.docs.map((docSnap) => {
      const data = docSnap.data();
      const name = [stringValue(data.first_name ?? data.firstName), stringValue(data.last_name ?? data.lastName)]
        .filter(Boolean)
        .join(" ");
      return name || stringValue(data.email) || "Applicant";
    });
  } catch {
    return [];
  }
}

async function readWebsiteCard() {
  try {
    const count = await getCountFromServer(collection(db, "public_site_cms_team"));
    return {
      id: "website",
      state: "ready" as const,
      lines: ["Change landing prices, bullet lines, and who appears on the Team page."],
      footer: `Team on website: ${count.data().count}`,
    };
  } catch {
    return {
      id: "website",
      state: "ready" as const,
      lines: ["Change landing prices, bullet lines, and who appears on the Team page."],
      footer: "Team on website: 0",
    };
  }
}

function firstNameFor(user: User | null) {
  const source = user?.displayName || user?.email || "User";
  const clean = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean)[0];
  return clean ? clean[0].toUpperCase() + clean.slice(1) : "User";
}

function greetingForNow() {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 17) return "Good afternoon";
  if (hour < 21) return "Good evening";
  return "Good night";
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Admin";
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}

function alphaHex(color: string, alpha: string) {
  return `${color}${alpha}`;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function nestedString(value: unknown, key: string) {
  if (!value || typeof value !== "object") return "";
  return stringValue((value as Record<string, unknown>)[key]);
}

function dateLabel(value: unknown) {
  if (value instanceof Timestamp) return value.toDate().toISOString().slice(0, 10);
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    return value.toDate().toISOString().slice(0, 10);
  }
  return "";
}
