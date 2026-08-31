"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, Timestamp } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import { ChevronDown, ClipboardList, FileQuestion, FileText, HelpCircle, Lock, Menu, MoreVertical, Plus, Search } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type StatusFilter = "all" | "active" | "inactive";
type SortMode = "newest" | "oldest" | "name";

type FormTemplateRecord = {
  id: string;
  name: string;
  description: string;
  fieldsCount: number;
  isActive: boolean;
  version: number;
  createdAt: Date | null;
  updatedAt: Date | null;
};

const statusOptions: { value: StatusFilter; label: string }[] = [
  { value: "all", label: "All Forms" },
  { value: "active", label: "Active" },
  { value: "inactive", label: "Inactive" },
];

const sortOptions: { value: SortMode; label: string }[] = [
  { value: "newest", label: "Newest First" },
  { value: "oldest", label: "Oldest First" },
  { value: "name", label: "Name A-Z" },
];

export function FormBuilderAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [templates, setTemplates] = useState<FormTemplateRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [sortMode, setSortMode] = useState<SortMode>("newest");
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
        setTemplates(await loadFormTemplates());
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load form templates.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const visibleTemplates = useMemo(() => {
    const term = search.trim().toLowerCase();
    const filtered = templates.filter((template) => {
      if (term && !template.name.toLowerCase().includes(term)) return false;
      if (statusFilter === "active" && !template.isActive) return false;
      if (statusFilter === "inactive" && template.isActive) return false;
      return true;
    });

    const dedupedByName = new Map<string, FormTemplateRecord>();
    filtered.forEach((template) => {
      const key = template.name.trim().toLowerCase().replace(/\s+/g, " ") || template.id;
      const existing = dedupedByName.get(key);
      if (!existing || shouldPreferTemplate(template, existing)) {
        dedupedByName.set(key, template);
      }
    });

    return Array.from(dedupedByName.values()).sort((a, b) => {
      if (sortMode === "name") return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
      const aTime = a.createdAt?.getTime() ?? 0;
      const bTime = b.createdAt?.getTime() ?? 0;
      return sortMode === "newest" ? bTime - aTime : aTime - bTime;
    });
  }, [search, sortMode, statusFilter, templates]);

  if (access !== "allowed") {
    return <FormBuilderAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Form Builder" breadcrumb="Forms / Form Builder">
      <main className="min-h-[calc(100vh-56px)] bg-[#F0EBF8] text-[#1F2937]">
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

        <section className="bg-white px-6 py-6 shadow-[0_2px_4px_rgba(0,0,0,0.05)] max-[700px]:px-6 max-[700px]:py-6">
          <div className="flex items-center gap-4 max-[700px]:items-center">
            <div className="grid h-[52px] w-[52px] shrink-0 place-items-center rounded-xl bg-[#673AB7]/10 text-[#673AB7] max-[700px]:h-[52px] max-[700px]:w-[52px]">
              <FileText size={28} />
            </div>
            <div className="min-w-0 flex-1">
              <h1 className="text-2xl font-semibold leading-tight text-[#1F2937] max-[700px]:max-w-[108px] max-[700px]:text-[24px]">
                Form Templates
              </h1>
              <p className="mt-1 text-sm text-[#6B7280] max-[700px]:max-w-[132px] max-[700px]:leading-5">
                Create And Manage Your Form Templates
              </p>
            </div>
            <button
              type="button"
              onClick={() => setMessage("Form creation stays in the Flutter app until the editor is migrated.")}
              className="inline-flex min-h-12 shrink-0 items-center justify-center gap-2 rounded-lg bg-[#673AB7] px-5 text-sm font-medium text-white shadow-sm max-[700px]:min-w-[152px] max-[700px]:px-4 max-[700px]:text-base max-[700px]:font-semibold"
            >
              <Plus size={20} />
              Create Form
            </button>
          </div>

          <button type="button" className="mt-5 flex min-h-[42px] w-full items-center justify-center gap-2 rounded-lg border border-[#673AB7] bg-[#673AB7] text-[13px] font-semibold text-white">
            <ClipboardList size={16} />
            Form Templates
          </button>

          <div className="mt-4 grid grid-cols-[minmax(0,1fr)_120px_146px] gap-3 max-[700px]:grid-cols-[52px_120px_146px]">
            <label className="relative block">
              <span className="sr-only">Search forms</span>
              <Search className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#9CA3AF]" size={22} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search Forms"
                aria-label="Search forms"
                className="h-12 w-full rounded-lg border border-[#D1D5DB] bg-[#F9FAFB] pl-11 pr-3 text-base outline-none placeholder:text-[#9CA3AF] focus:border-[#673AB7] max-[700px]:px-0 max-[700px]:text-transparent max-[700px]:placeholder:text-transparent"
              />
            </label>
            <FilterSelect value={statusFilter} onChange={(value) => setStatusFilter(value as StatusFilter)} options={statusOptions} label="Status filter" />
            <FilterSelect value={sortMode} onChange={(value) => setSortMode(value as SortMode)} options={sortOptions} label="Sort forms" />
          </div>
          {message ? <p className="mt-3 rounded-lg bg-[#F3E8FF] px-3 py-2 text-sm font-semibold text-[#673AB7]">{message}</p> : null}
        </section>

        <section className="min-h-[calc(100vh-276px)] max-[700px]:min-h-[451px]">
          {loading ? (
            <div className="grid min-h-[420px] place-items-center">
              <div className="h-9 w-9 animate-spin rounded-full border-4 border-[#D8CFF0] border-t-[#673AB7]" />
            </div>
          ) : templates.length === 0 ? (
            <EmptyFormsState onCreate={() => setMessage("Form creation stays in the Flutter app until the editor is migrated.")} />
          ) : visibleTemplates.length === 0 ? (
            <NoResultsState />
          ) : (
            <div className="grid grid-cols-[repeat(auto-fill,minmax(240px,300px))] gap-4 p-6 max-[700px]:grid-cols-1">
              {visibleTemplates.map((template) => (
                <TemplateCard key={template.id} template={template} onAction={setMessage} />
              ))}
            </div>
          )}
        </section>
      </main>
    </AdminDashboardShell>
  );
}

function FilterSelect({
  value,
  onChange,
  options,
  label,
}: {
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
  label: string;
}) {
  return (
    <label className="relative block">
      <span className="sr-only">{label}</span>
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        aria-label={label}
        className="h-12 w-full appearance-none rounded-lg border border-[#D1D5DB] bg-[#F9FAFB] px-3 pr-8 text-base text-[#374151] outline-none focus:border-[#673AB7]"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
      <ChevronDown className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-[#6B7280]" size={16} />
    </label>
  );
}

function TemplateCard({ template, onAction }: { template: FormTemplateRecord; onAction: (message: string) => void }) {
  return (
    <article className="min-h-[280px] overflow-hidden rounded-lg border border-[#E5E7EB] bg-white shadow-[0_2px_8px_rgba(0,0,0,0.05)]">
      <div className="relative grid h-20 place-items-center bg-[#10B981]/15 text-[#10B981]">
        <span className={`absolute left-2 top-2 rounded-full px-2 py-1 text-[10px] font-medium text-white ${template.isActive ? "bg-green-500" : "bg-gray-500"}`}>
          {template.isActive ? "Active" : "Inactive"}
        </span>
        <FileText size={40} />
        <button
          type="button"
          aria-label={`Open actions for ${template.name}`}
          onClick={() => onAction("Template editing stays in Flutter until the editor is migrated.")}
          className="absolute right-1 top-1 grid h-9 w-9 place-items-center rounded-full text-[#6B7280] hover:bg-white/60"
        >
          <MoreVertical size={20} />
        </button>
      </div>
      <div className="flex min-h-[200px] flex-col p-4">
        <h2 className="line-clamp-2 text-base font-semibold text-[#1F2937]">{template.name || "Untitled Template"}</h2>
        {template.description ? <p className="mt-1 line-clamp-2 text-xs text-[#6B7280]">{template.description}</p> : null}
        <div className="mt-auto flex items-center gap-1 text-xs text-[#6B7280]">
          <HelpCircle size={14} />
          <span>
            {template.fieldsCount} field{template.fieldsCount === 1 ? "" : "s"}
          </span>
          <span className="ml-auto text-[11px] text-[#9CA3AF]">{formatShortDate(template.createdAt)}</span>
        </div>
      </div>
    </article>
  );
}

function EmptyFormsState({ onCreate }: { onCreate: () => void }) {
  return (
    <div className="grid min-h-[620px] place-items-center px-6 text-center max-[700px]:min-h-[451px]">
      <div>
        <FileText className="mx-auto text-[#D1D5DB]" size={80} strokeWidth={1.8} />
        <h2 className="mt-4 text-xl font-semibold text-[#737373]">No Forms Yet</h2>
        <p className="mt-2 text-sm text-[#9CA3AF]">Create Your First Form To Get</p>
        <button type="button" onClick={onCreate} className="mt-6 inline-flex min-h-10 items-center justify-center gap-2 rounded-full bg-[#673AB7] px-6 text-sm font-medium text-white">
          <Plus size={18} />
          Create Form
        </button>
      </div>
    </div>
  );
}

function NoResultsState() {
  return (
    <div className="grid min-h-[620px] place-items-center px-6 text-center max-[700px]:min-h-[451px]">
      <div>
        <FileQuestion className="mx-auto text-[#D1D5DB]" size={64} strokeWidth={1.8} />
        <h2 className="mt-4 text-lg font-semibold text-[#737373]">No Forms Found</h2>
        <p className="mt-2 text-sm text-[#9CA3AF]">Try adjusting your search or filters</p>
      </div>
    </div>
  );
}

function FormBuilderAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F1F4F8] px-5 text-[#0F172A]">
      <section className="w-full max-w-md rounded-[20px] border border-black/10 bg-white px-6 py-10 text-center shadow-sm">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#F3E8FF] text-[#673AB7]">
          <Lock size={24} />
        </div>
        <h1 className="mt-4 text-xl font-bold">
          {checking ? "Checking admin access" : access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {checking
            ? "Please wait while we verify your dashboard permissions."
            : access === "signedOut"
              ? "Sign in with an administrator account before managing forms."
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

async function loadFormTemplates() {
  const snap = await getDocs(collection(db, "form_templates"));
  return snap.docs.map((docSnap) => normalizeTemplate(docSnap.id, docSnap.data() as Record<string, unknown>));
}

function normalizeTemplate(id: string, data: Record<string, unknown>): FormTemplateRecord {
  return {
    id,
    name: stringValue(data.name) || "Untitled Template",
    description: stringValue(data.description),
    fieldsCount: fieldsCount(data.fields),
    isActive: data.isActive !== false,
    version: numberValue(data.version) || 1,
    createdAt: dateValue(data.createdAt),
    updatedAt: dateValue(data.updatedAt) ?? dateValue(data.createdAt),
  };
}

function shouldPreferTemplate(candidate: FormTemplateRecord, existing: FormTemplateRecord) {
  if (candidate.isActive && !existing.isActive) return true;
  if (candidate.isActive !== existing.isActive) return false;
  if (candidate.version !== existing.version) return candidate.version > existing.version;
  return (candidate.updatedAt?.getTime() ?? candidate.createdAt?.getTime() ?? 0) > (existing.updatedAt?.getTime() ?? existing.createdAt?.getTime() ?? 0);
}

function fieldsCount(value: unknown) {
  if (Array.isArray(value)) return value.length;
  if (value && typeof value === "object") return Object.keys(value).length;
  return 0;
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
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

function formatShortDate(date: Date | null) {
  if (!date) return "";
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(date);
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
