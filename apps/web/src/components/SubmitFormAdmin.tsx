"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, doc, getDoc, getDocs, limit, query, Timestamp, where } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  BarChart3,
  Calendar,
  CalendarDays,
  Check,
  ChevronRight,
  ClipboardList,
  Clock,
  FileText,
  History,
  Lock,
  Menu,
  MessageSquare,
  Search,
  Shield,
  X,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type Frequency = "perSession" | "weekly" | "monthly" | "onDemand";
type Category = "teaching" | "studentAssessment" | "feedback" | "administrative" | "other";

type FormTemplateRecord = {
  id: string;
  name: string;
  description: string;
  frequency: Frequency;
  category: Category;
  version: number;
  fieldsCount: number;
  isActive: boolean;
  updatedAt: Date | null;
  allowedRoles: string[];
};

type SubmittedStatus = {
  daily: boolean;
  weekly: boolean;
  monthly: boolean;
};

type CategoryConfig = {
  id: Category;
  label: string;
  color: string;
  icon: LucideIcon;
};

const categoryConfigs: CategoryConfig[] = [
  { id: "teaching", label: "Teaching Reports", color: "#10B981", icon: Calendar },
  { id: "feedback", label: "Feedback & Complaints", color: "#8B5CF6", icon: MessageSquare },
  { id: "studentAssessment", label: "Student Assessment", color: "#3B82F6", icon: BarChart3 },
  { id: "administrative", label: "Administrative", color: "#F59E0B", icon: Shield },
  { id: "other", label: "Other Forms", color: "#64748B", icon: FileText },
];

const defaultTemplates: FormTemplateRecord[] = [
  {
    id: "daily_class_report",
    name: "Daily Class Report",
    description: "Quick report after each teaching session",
    frequency: "perSession",
    category: "teaching",
    version: 1,
    fieldsCount: 5,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher"],
  },
  {
    id: "weekly_summary",
    name: "Weekly Summary",
    description: "End of week teaching summary",
    frequency: "weekly",
    category: "teaching",
    version: 1,
    fieldsCount: 3,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher"],
  },
  {
    id: "monthly_review",
    name: "Monthly Review",
    description: "End of month teaching review",
    frequency: "monthly",
    category: "teaching",
    version: 1,
    fieldsCount: 3,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher"],
  },
  {
    id: "teacher_feedback",
    name: "Teacher Feedback & Complaints",
    description: "Submit feedback, suggestions, or complaints to leadership",
    frequency: "onDemand",
    category: "feedback",
    version: 1,
    fieldsCount: 5,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher", "coach"],
  },
  {
    id: "leadership_feedback",
    name: "Feedback for Leaders",
    description: "Rate and provide feedback about your coach/supervisor",
    frequency: "onDemand",
    category: "feedback",
    version: 1,
    fieldsCount: 4,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher"],
  },
  {
    id: "student_assessment",
    name: "Student Assessment",
    description: "Evaluate student progress and skills at enrollment or semester end",
    frequency: "onDemand",
    category: "studentAssessment",
    version: 1,
    fieldsCount: 10,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher", "coach", "admin"],
  },
  {
    id: "incident_report",
    name: "Incident Report",
    description: "Report an incident or issue that occurred",
    frequency: "onDemand",
    category: "administrative",
    version: 1,
    fieldsCount: 6,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher", "coach", "admin"],
  },
  {
    id: "leave_request",
    name: "Leave Request",
    description: "Request time off or absence from scheduled shifts",
    frequency: "onDemand",
    category: "administrative",
    version: 1,
    fieldsCount: 5,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher", "coach"],
  },
  {
    id: "admin_self_assessment",
    name: "Admin Self-Assessment",
    description: "Monthly self-evaluation for administrators and coaches",
    frequency: "monthly",
    category: "feedback",
    version: 1,
    fieldsCount: 9,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["admin", "coach"],
  },
  {
    id: "coach_performance_review",
    name: "Coach Performance Review",
    description: "Review coach performance and leadership support",
    frequency: "monthly",
    category: "feedback",
    version: 1,
    fieldsCount: 8,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["admin"],
  },
];

export function SubmitFormAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [role, setRole] = useState("admin");
  const [templates, setTemplates] = useState<FormTemplateRecord[]>([]);
  const [submitted, setSubmitted] = useState<SubmittedStatus>({ daily: false, weekly: false, monthly: false });
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [message, setMessage] = useState("");

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
        const [loadedRole, loadedTemplates, loadedSubmitted] = await Promise.all([
          loadCurrentUserRole(nextUser),
          loadTemplates(),
          loadSubmittedStatus(nextUser.uid),
        ]);
        if (!mounted) return;
        setRole(loadedRole);
        setTemplates(loadedTemplates);
        setSubmitted(loadedSubmitted);
      } catch (error) {
        if (mounted) {
          setMessage(error instanceof Error ? error.message : "Could not load forms.");
          setTemplates(defaultTemplates);
        }
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const visibleTemplates = useMemo(() => {
    const byName = new Map<string, FormTemplateRecord>();
    const roleName = normalizeRole(role);
    const baseTemplates = templates.length > 0 ? templates : defaultTemplates;
    baseTemplates
      .filter((template) => template.isActive)
      .filter((template) => canRoleSeeTemplate(template, roleName))
      .forEach((template) => {
        const displayCategory = displayCategoryFor(template);
        const candidate = { ...template, category: displayCategory };
        const key = candidate.name.trim().toLowerCase().replace(/\s+/g, " ");
        const existing = byName.get(key);
        if (!existing || shouldPreferTemplate(candidate, existing)) byName.set(key, candidate);
      });

    const deduped = Array.from(byName.values());
    if (!deduped.some((template) => template.category === "teaching")) {
      defaultTemplates.filter((template) => template.category === "teaching").forEach((template) => byName.set(template.id, template));
    }
    if (!deduped.some((template) => template.category === "feedback")) {
      defaultTemplates.filter((template) => template.category === "feedback" && canRoleSeeTemplate(template, roleName)).forEach((template) => byName.set(template.id, template));
    }
    if (!deduped.some((template) => template.category === "studentAssessment")) {
      defaultTemplates.filter((template) => template.category === "studentAssessment" && canRoleSeeTemplate(template, roleName)).forEach((template) => byName.set(template.id, template));
    }
    if (!deduped.some((template) => template.category === "administrative")) {
      defaultTemplates.filter((template) => template.category === "administrative" && canRoleSeeTemplate(template, roleName)).forEach((template) => byName.set(template.id, template));
    }

    const term = search.trim().toLowerCase();
    return Array.from(byName.values()).filter((template) => {
      if (!term) return true;
      const category = categoryConfigs.find((item) => item.id === template.category)?.label ?? "";
      return [template.name, template.description, category, frequencyLabel(template.frequency)].some((value) => value.toLowerCase().includes(term));
    });
  }, [role, search, templates]);

  const groupedTemplates = useMemo(() => {
    return categoryConfigs
      .map((category) => {
        const items = visibleTemplates
          .filter((template) => template.category === category.id)
          .sort((a, b) => templateSort(a, b, category.id));
        return { category, items };
      })
      .filter((group) => group.items.length > 0);
  }, [visibleTemplates]);

  if (access !== "allowed") {
    return <SubmitFormAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Submit Form" breadcrumb="Forms / Submit Form">
      <main className="min-h-[calc(100vh-56px)] bg-[#F1F5F9] text-[#1E293B]">
        <header className="lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center bg-white px-3">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <Menu size={20} />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Education Hub</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">
              {initialsFor(user)}
            </span>
          </div>
        </header>

        <section className="relative overflow-hidden bg-gradient-to-br from-[#6366F1] to-[#8B5CF6] px-5 pb-7 pt-5 text-white lg:min-h-[200px]">
          <div className="flex items-center justify-between">
            <span className="text-2xl leading-none">←</span>
            <button type="button" onClick={() => setMessage("My submissions stays in Flutter until the submission history flow is migrated.")} aria-label="My submissions" className="grid h-10 w-10 place-items-center rounded-full text-white hover:bg-white/10">
              <History size={22} />
            </button>
          </div>
          <p className="mt-7 text-sm text-white/80 max-[700px]:mt-5 max-[700px]:text-base">Submit Reports Feedback</p>
          <div className="mt-5 flex gap-3 overflow-x-auto">
            <StatusPill label="Daily" status={submitted.daily ? "Done" : "Due"} complete={submitted.daily} />
            <StatusPill label="Weekly" status={isWeeklyAvailable() ? (submitted.weekly ? "Done" : "Due") : "Sun-Tue"} complete={submitted.weekly} available={isWeeklyAvailable()} />
            <StatusPill label="Monthly" status={isMonthlyAvailable() ? (submitted.monthly ? "Done" : "Due") : "End/Start"} complete={submitted.monthly} available={isMonthlyAvailable()} />
          </div>
          <h1 className="mt-1 text-center text-[34px] font-black leading-tight tracking-normal text-white max-[700px]:mt-0 max-[700px]:text-[34px]">Forms Reports</h1>
        </section>

        <section className="px-4 py-4">
          <label className="relative block">
            <span className="sr-only">Search forms</span>
            <Search className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[#1E293B]" size={22} />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search Forms"
              aria-label="Search forms"
              className="h-[46px] w-full rounded-xl border border-[#E5E7EB] bg-white pl-12 pr-10 text-base text-[#1E293B] shadow-[0_2px_8px_rgba(100,116,139,0.08)] outline-none placeholder:text-[#64748B] focus:border-[#6366F1]"
            />
            {search ? (
              <button type="button" onClick={() => setSearch("")} aria-label="Clear search" className="absolute right-3 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center text-[#64748B]">
                <X size={18} />
              </button>
            ) : null}
          </label>

          {message ? <p className="mt-3 rounded-xl bg-white px-4 py-3 text-sm font-semibold text-[#6366F1] shadow-sm">{message}</p> : null}

          {loading ? (
            <div className="grid min-h-[420px] place-items-center">
              <div className="h-9 w-9 animate-spin rounded-full border-4 border-[#DDD6FE] border-t-[#6366F1]" />
            </div>
          ) : groupedTemplates.length === 0 ? (
            <NoFormsFound />
          ) : (
            <div className="pb-24">
              {groupedTemplates.map((group) => (
                <CategorySection
                  key={group.category.id}
                  category={group.category}
                  templates={group.items}
                  submitted={submitted}
                  onOpen={(template) => setMessage(`${template.name} stays in Flutter until the form-fill flow is migrated.`)}
                />
              ))}
            </div>
          )}
        </section>
      </main>
    </AdminDashboardShell>
  );
}

function StatusPill({ label, status, complete, available = true }: { label: string; status: string; complete: boolean; available?: boolean }) {
  const Icon = complete ? Check : available ? ClipboardList : Lock;
  return (
    <div className={`flex min-w-[79px] items-center gap-2 rounded-[20px] border border-white/10 px-3.5 py-2 ${complete ? "bg-green-300/20 text-green-100" : available ? "bg-white/15 text-white" : "bg-black/20 text-white/60"}`}>
      <Icon size={16} />
      <span>
        <span className="block text-[10px] font-semibold leading-3 text-white/70">{label}</span>
        <span className="block text-xs font-black leading-4">{status}</span>
      </span>
    </div>
  );
}

function CategorySection({
  category,
  templates,
  submitted,
  onOpen,
}: {
  category: CategoryConfig;
  templates: FormTemplateRecord[];
  submitted: SubmittedStatus;
  onOpen: (template: FormTemplateRecord) => void;
}) {
  return (
    <section className="mt-4">
      <div className="mb-3 flex items-center gap-2">
        <h2 className="shrink-0 text-xs font-black uppercase tracking-[0.1em] text-[#7890A0]">{category.label}</h2>
        <div className="h-px flex-1 bg-[#D5DDE5]" />
      </div>
      <div className="grid gap-4">
        {templates.map((template) => (
          <FormCard key={template.id} template={template} color={category.color} icon={category.icon} submitted={submitted} onOpen={() => onOpen(template)} />
        ))}
      </div>
    </section>
  );
}

function FormCard({
  template,
  color,
  icon: Icon,
  submitted,
  onOpen,
}: {
  template: FormTemplateRecord;
  color: string;
  icon: LucideIcon;
  submitted: SubmittedStatus;
  onOpen: () => void;
}) {
  const formType = frequencyType(template.frequency);
  const isTeaching = template.category === "teaching";
  const isSubmitted = isTeaching && submitted[formType] === true;
  const available = isFrequencyAvailable(template.frequency);
  const disabled = isTeaching && !available;
  const iconColor = isSubmitted ? "#22C55E" : disabled ? "#BDBDBD" : color;
  const iconBg = isSubmitted ? "#F0FDF4" : disabled ? "#F3F4F6" : `${color}1A`;

  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onOpen}
      className="grid min-h-[112px] w-full grid-cols-[52px_minmax(0,1fr)_22px] gap-4 rounded-[20px] bg-white p-5 text-left shadow-[0_4px_12px_rgba(100,116,139,0.08)] disabled:cursor-not-allowed max-[700px]:min-h-[128px]"
    >
      <span className="grid h-[52px] w-[52px] place-items-center rounded-2xl" style={{ backgroundColor: iconBg }}>
        {isSubmitted ? <Check size={26} style={{ color: iconColor }} /> : <Icon size={26} style={{ color: iconColor }} />}
      </span>
      <span className="min-w-0">
        <span className={`flex flex-wrap items-center gap-2 text-base font-black leading-tight ${disabled ? "text-[#B8B8B8]" : "text-[#1E293B]"}`}>
          {template.name}
          {isSubmitted ? <Badge text="Completed" tone="green" /> : null}
          {disabled ? <Badge text={availabilityLabel(template.frequency)} tone="orange" /> : null}
        </span>
        <span className="mt-1 line-clamp-2 block text-[13px] leading-5 text-[#7890A0]">{template.description}</span>
        <span className="mt-3 flex flex-wrap items-center gap-3 text-xs font-medium text-[#7890A0]">
          <span className="inline-flex items-center gap-1">
            <ClipboardList size={14} />
            {template.fieldsCount} items
          </span>
          <span className="inline-flex items-center gap-1">
            <Clock size={14} />
            {frequencyLabel(template.frequency)}
          </span>
        </span>
      </span>
      <span className="mt-3 text-[#CBD5E1]">{disabled ? null : <ChevronRight size={18} />}</span>
    </button>
  );
}

function Badge({ text, tone }: { text: string; tone: "green" | "orange" }) {
  const classes = tone === "green" ? "border-green-100 bg-green-50 text-green-700" : "border-orange-100 bg-orange-50 text-orange-700";
  return <span className={`inline-flex items-center rounded-md border px-2 py-0.5 text-[10px] font-black ${classes}`}>{text}</span>;
}

function NoFormsFound() {
  return (
    <div className="grid min-h-[420px] place-items-center px-6 text-center">
      <div>
        <Search className="mx-auto text-[#CBD5E1]" size={56} />
        <h2 className="mt-3 text-base font-black text-[#475569]">No active forms match your search</h2>
        <p className="mt-1 text-sm text-[#94A3B8]">Try adjusting your search</p>
      </div>
    </div>
  );
}

function SubmitFormAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F1F4F8] px-5 text-[#0F172A]">
      <section className="w-full max-w-md rounded-[20px] border border-black/10 bg-white px-6 py-10 text-center shadow-sm">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#EEF2FF] text-[#6366F1]">
          <Lock size={24} />
        </div>
        <h1 className="mt-4 text-xl font-bold">
          {checking ? "Checking admin access" : access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {checking
            ? "Please wait while we verify your dashboard permissions."
            : access === "signedOut"
              ? "Sign in with an administrator account before submitting forms."
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

async function loadCurrentUserRole(user: User) {
  const email = user.email?.trim().toLowerCase();
  const userDocs = [user.uid, email].filter(Boolean) as string[];
  for (const id of userDocs) {
    const snap = await getDoc(doc(db, "users", id)).catch(() => null);
    const data = snap?.exists() ? (snap.data() as Record<string, unknown>) : undefined;
    const role = stringValue(data?.user_type ?? data?.role);
    if (role) return normalizeRole(role);
  }
  if (email) {
    for (const field of ["email", "e-mail"]) {
      const snap = await getDocs(query(collection(db, "users"), where(field, "==", email), limit(1))).catch(() => null);
      const data = snap?.docs[0]?.data() as Record<string, unknown> | undefined;
      const role = stringValue(data?.user_type ?? data?.role);
      if (role) return normalizeRole(role);
    }
  }
  return "admin";
}

async function loadTemplates() {
  const snap = await getDocs(collection(db, "form_templates"));
  const records = snap.docs.map((docSnap) => normalizeTemplate(docSnap.id, docSnap.data() as Record<string, unknown>));
  return records.length > 0 ? records : defaultTemplates;
}

async function loadSubmittedStatus(uid: string): Promise<SubmittedStatus> {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const weekStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (now.getDay() === 0 ? 6 : now.getDay() - 1));
  const yearMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const snap = await getDocs(query(collection(db, "form_responses"), where("userId", "==", uid), limit(500))).catch(() => null);
  const docs = snap?.docs.map((docSnap) => normalizeResponse(docSnap.data() as Record<string, unknown>)) ?? [];
  return {
    daily: docs.some((doc) => doc.formType === "daily" && (doc.submittedAt?.getTime() ?? 0) >= todayStart.getTime()),
    weekly: docs.some((doc) => doc.formType === "weekly" && (doc.submittedAt?.getTime() ?? 0) >= weekStart.getTime()),
    monthly: docs.some((doc) => doc.formType === "monthly" && doc.yearMonth === yearMonth),
  };
}

function normalizeTemplate(id: string, data: Record<string, unknown>): FormTemplateRecord {
  const frequency = normalizeFrequency(stringValue(data.frequency));
  const category = normalizeCategory(stringValue(data.category));
  return {
    id,
    name: stringValue(data.name) || "Untitled",
    description: stringValue(data.description),
    frequency,
    category,
    version: numberValue(data.version) || 1,
    fieldsCount: fieldsCount(data.fields),
    isActive: data.isActive !== false,
    updatedAt: dateValue(data.updatedAt),
    allowedRoles: stringArray(data.allowedRoles).map(normalizeRole),
  };
}

function normalizeResponse(data: Record<string, unknown>) {
  return {
    formType: stringValue(data.formType ?? data.form_type).toLowerCase(),
    yearMonth: stringValue(data.yearMonth),
    submittedAt: dateValue(data.submittedAt ?? data.submitted_at),
  };
}

function canRoleSeeTemplate(template: FormTemplateRecord, role: string) {
  if (role === "admin" || role === "coach") return true;
  if (template.allowedRoles.length > 0) return template.allowedRoles.includes(role);
  if (role === "teacher") {
    return ["teaching", "feedback", "administrative", "studentAssessment"].includes(template.category) || ["perSession", "weekly", "monthly"].includes(template.frequency);
  }
  return false;
}

function displayCategoryFor(template: FormTemplateRecord): Category {
  if (template.category === "other" && ["perSession", "weekly", "monthly"].includes(template.frequency)) return "teaching";
  return template.category;
}

function shouldPreferTemplate(candidate: FormTemplateRecord, existing: FormTemplateRecord) {
  if (candidate.version !== existing.version) return candidate.version > existing.version;
  return (candidate.updatedAt?.getTime() ?? 0) > (existing.updatedAt?.getTime() ?? 0);
}

function templateSort(a: FormTemplateRecord, b: FormTemplateRecord, category: Category) {
  if (category === "teaching") {
    const order: Record<Frequency, number> = { perSession: 0, weekly: 1, monthly: 2, onDemand: 3 };
    return order[a.frequency] - order[b.frequency];
  }
  return a.name.localeCompare(b.name);
}

function normalizeRole(role: string) {
  const normalized = role.trim().toLowerCase();
  if (["tutor", "tutors", "teacher", "teachers", "instructor", "instructors"].includes(normalized)) return "teacher";
  if (["admins", "administrator", "administrators", "super_admin"].includes(normalized)) return "admin";
  if (normalized === "coaches") return "coach";
  if (normalized === "students") return "student";
  if (normalized === "parents") return "parent";
  return normalized;
}

function normalizeFrequency(value: string): Frequency {
  if (value === "weekly") return "weekly";
  if (value === "monthly") return "monthly";
  if (value === "onDemand" || value === "on_demand") return "onDemand";
  return "perSession";
}

function normalizeCategory(value: string): Category {
  if (value === "studentAssessment" || value === "student_assessment") return "studentAssessment";
  if (value === "feedback") return "feedback";
  if (value === "administrative") return "administrative";
  if (value === "teaching") return "teaching";
  return "other";
}

function frequencyType(frequency: Frequency): keyof SubmittedStatus {
  if (frequency === "weekly") return "weekly";
  if (frequency === "monthly") return "monthly";
  return "daily";
}

function frequencyLabel(frequency: Frequency) {
  if (frequency === "weekly") return "Weekly";
  if (frequency === "monthly") return "Monthly";
  if (frequency === "onDemand") return "Anytime";
  return "Daily";
}

function isFrequencyAvailable(frequency: Frequency) {
  if (frequency === "weekly") return isWeeklyAvailable();
  if (frequency === "monthly") return isMonthlyAvailable();
  return true;
}

function isWeeklyAvailable() {
  const day = new Date().getDay();
  return day === 0 || day === 1 || day === 2;
}

function isMonthlyAvailable() {
  const now = new Date();
  const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  return now.getDate() >= lastDay - 2 || now.getDate() <= 3;
}

function availabilityLabel(frequency: Frequency) {
  if (frequency === "weekly") return "Sun-Tue";
  if (frequency === "monthly") return "End/Start";
  return "Unavailable";
}

function fieldsCount(value: unknown) {
  if (Array.isArray(value)) return value.length;
  if (value && typeof value === "object") return Object.keys(value).length;
  return 0;
}

function stringArray(value: unknown) {
  if (Array.isArray(value)) return value.map((item) => String(item ?? "").trim()).filter(Boolean);
  if (value && typeof value === "object") return Object.values(value).map((item) => String(item ?? "").trim()).filter(Boolean);
  return [];
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    const parsed = value.toDate();
    return parsed instanceof Date ? parsed : null;
  }
  return null;
}

function numberValue(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Administrator";
  return source
    .replace(/@.*/, "")
    .split(/[\s._-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("") || "AD";
}
