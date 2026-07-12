"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDoc, getDocs, doc, limit, query, Timestamp, where } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  Calendar,
  Check,
  ChevronRight,
  ClipboardList,
  FileText,
  Folder,
  Infinity,
  Search,
  X,
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type SubmissionRecord = {
  id: string;
  formId: string;
  formTitle: string;
  status: string;
  responses: Record<string, unknown>;
  fieldLabels: Record<string, string>;
  submittedAt: Date | null;
  yearMonth: string;
};

type SubmissionGroup = {
  id: string;
  title: string;
  submissions: SubmissionRecord[];
};

const noFormIdGroup = "__no_form_id__";
const defaultSummary = {displayName: "Teacher", firstName: "Teacher", initials: "TE"};

export function TeacherFormSubmissionsPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState(defaultSummary);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [submissions, setSubmissions] = useState<SubmissionRecord[]>([]);
  const [selectedYearMonth, setSelectedYearMonth] = useState(currentYearMonth());
  const [showAllMonths, setShowAllMonths] = useState(false);
  const [search, setSearch] = useState("");
  const [monthPickerOpen, setMonthPickerOpen] = useState(false);
  const [activeGroup, setActiveGroup] = useState<SubmissionGroup | null>(null);
  const [activeSubmission, setActiveSubmission] = useState<SubmissionRecord | null>(null);

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

      setAccess("checking");
      setLoading(true);
      setLoadError("");
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
        setCurrentUser(nextUser);
        setSummary(summaryForUser(nextUser, userRecord));
        setAccess("allowed");
        try {
          const records = await loadSubmissions(nextUser);
          if (mounted) setSubmissions(records);
        } catch (error) {
          if (mounted) setLoadError(submissionLoadError(error));
        }
      } catch {
        if (mounted) setAccess("denied");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const availableMonths = useMemo(() => {
    return Array.from(new Set(submissions.map((item) => item.yearMonth).filter(Boolean))).sort((a, b) => b.localeCompare(a));
  }, [submissions]);

  const visibleSubmissions = useMemo(() => {
    return submissions.filter((item) => showAllMonths || item.yearMonth === selectedYearMonth);
  }, [selectedYearMonth, showAllMonths, submissions]);

  const groupedSubmissions = useMemo(() => {
    const term = search.trim().toLowerCase();
    const byForm = new Map<string, SubmissionGroup>();
    for (const item of visibleSubmissions) {
      const groupId = item.formId || noFormIdGroup;
      const existing = byForm.get(groupId);
      const title = item.formTitle || (groupId === noFormIdGroup ? "Submissions without a form" : "Form Submission");
      if (!existing) byForm.set(groupId, { id: groupId, title, submissions: [] });
      byForm.get(groupId)?.submissions.push(item);
    }
    const groups = Array.from(byForm.values()).map((group) => ({
      ...group,
      submissions: group.submissions.sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0)),
    }));

    if (!term) return groups;
    return groups
      .map((group) => {
        if (group.title.toLowerCase().includes(term)) return group;
        const matching = group.submissions.filter((item) => item.status.toLowerCase().includes(term));
        return matching.length > 0 ? { ...group, submissions: matching } : null;
      })
      .filter((group): group is SubmissionGroup => group !== null);
  }, [search, visibleSubmissions]);

  const currentMonthCount = visibleSubmissions.length;

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  const retryLoad = async () => {
    if (!currentUser || loading) return;
    setLoading(true);
    setLoadError("");
    try {
      setSubmissions(await loadSubmissions(currentUser));
    } catch (error) {
      setLoadError(submissionLoadError(error));
    } finally {
      setLoading(false);
    }
  };

  return (
    <TeacherShell activeLabel="My Form Submissions" breadcrumb="Forms / My Form Submissions" summary={summary}>
    <main className="min-h-full bg-[#F5F7FA] text-[#1E293B]">
      <header className="grid min-h-14 grid-cols-[56px_1fr_minmax(112px,auto)] items-center border-b border-[#E2E8F0] bg-white px-2 max-[700px]:grid-cols-[48px_1fr_44px]">
        <Link href="/teacher/" aria-label="Back" className="grid h-11 w-11 place-items-center rounded-xl text-[#111827] hover:bg-[#F8FAFC]">
          <ArrowLeft size={24} />
        </Link>
        <h1 className="truncate text-center text-xl font-bold text-[#1E293B] max-[700px]:text-base">My Form Submissions</h1>
        <button
          type="button"
          onClick={() => setMonthPickerOpen(true)}
          className="inline-flex min-h-10 items-center justify-end gap-2 rounded-xl px-3 text-sm font-semibold text-[#0386FF] hover:bg-[#EFF6FF] max-[700px]:px-1"
          aria-label="Select month"
        >
          <Calendar size={17} />
          <span className="max-[700px]:sr-only">{showAllMonths ? "All Time" : monthDisplayName(selectedYearMonth)}</span>
        </button>
      </header>

      {!loading && !showAllMonths ? (
        <section className="flex items-center gap-3 bg-[#EFF6FF] px-4 py-3">
          <span className="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-[#0386FF]/10 text-[#0386FF]">
            <ClipboardList size={20} />
          </span>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-bold text-[#1E293B]">{monthDisplayName(selectedYearMonth)}</p>
            <p className="mt-0.5 text-xs text-[#64748B]">{currentMonthCount} {currentMonthCount === 1 ? "submission" : "submissions"} this month</p>
            <p className="mt-1 text-[11px] leading-4 text-[#64748B]">Only submissions dated in the selected month are shown. Use View all to see other months.</p>
          </div>
          <button type="button" onClick={() => setShowAllMonths(true)} className="rounded-xl px-3 py-2 text-xs font-semibold text-[#0386FF] hover:bg-white">
            View All
          </button>
        </section>
      ) : null}

      <section className="bg-white p-4">
        <label className="relative block">
          <span className="sr-only">Search by form name or status</span>
          <Search className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#64748B]" size={21} />
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search by form name or status"
            aria-label="Search by form name or status"
            className="min-h-12 w-full rounded-lg border-0 bg-[#F8FAFC] pl-11 pr-11 text-base text-[#1E293B] outline-none ring-1 ring-[#E2E8F0] placeholder:text-[#94A3B8] focus:ring-2 focus:ring-[#0386FF]"
          />
          {search ? (
            <button type="button" onClick={() => setSearch("")} aria-label="Clear search" className="absolute right-2 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-lg text-[#64748B] hover:bg-[#E2E8F0]">
              <X size={18} />
            </button>
          ) : null}
        </label>
      </section>

      <section className="min-h-[calc(100vh-178px)]">
        {loading ? (
          <div className="grid min-h-[460px] place-items-center">
            <div className="h-9 w-9 animate-spin rounded-full border-4 border-[#BFDBFE] border-t-[#0386FF]" />
          </div>
        ) : loadError ? (
          <div className="grid min-h-[460px] place-items-center px-6 text-center" role="alert">
            <div className="max-w-md">
              <h2 className="text-xl font-bold text-[#1E293B]">Could not load submissions</h2>
              <p className="mt-2 text-sm text-[#64748B]">{loadError}</p>
              <button type="button" onClick={() => void retryLoad()} className="mt-5 min-h-11 rounded-xl bg-[#0386FF] px-5 text-sm font-bold text-white">Try again</button>
            </div>
          </div>
        ) : groupedSubmissions.length === 0 ? (
          <EmptySubmissions search={search} />
        ) : (
          <div className="grid gap-3 p-4">
            {groupedSubmissions.map((group) => (
              <SubmissionGroupCard key={group.id} group={group} onOpen={() => setActiveGroup(group)} />
            ))}
          </div>
        )}
      </section>

      {monthPickerOpen ? (
        <MonthPicker
          months={availableMonths}
          selectedYearMonth={selectedYearMonth}
          showAllMonths={showAllMonths}
          onClose={() => setMonthPickerOpen(false)}
          onSelectAll={() => {
            setShowAllMonths(true);
            setMonthPickerOpen(false);
          }}
          onSelectMonth={(month) => {
            setSelectedYearMonth(month);
            setShowAllMonths(false);
            setMonthPickerOpen(false);
          }}
        />
      ) : null}

      {activeGroup ? (
        <GroupSheet
          group={activeGroup}
          onClose={() => setActiveGroup(null)}
          onView={(submission) => {
            setActiveGroup(null);
            setActiveSubmission(submission);
          }}
        />
      ) : null}

      {activeSubmission ? <SubmissionDetail submission={activeSubmission} onClose={() => setActiveSubmission(null)} /> : null}
    </main>
    </TeacherShell>
  );
}

function EmptySubmissions({ search }: { search: string }) {
  return (
    <div className="grid min-h-[460px] place-items-center px-6 text-center">
      <div>
        <span className="mx-auto grid h-28 w-28 place-items-center rounded-2xl bg-[#F1F5F9] text-[#64748B]">
          <ClipboardList size={64} />
        </span>
        <h2 className="mt-6 text-xl font-bold text-[#1E293B]">{search.trim() ? "No results found" : "No form submissions yet"}</h2>
        <p className="mt-2 text-base text-[#64748B]">{search.trim() ? "Try adjusting your search" : "Your submitted forms will appear here"}</p>
      </div>
    </div>
  );
}

function SubmissionGroupCard({ group, onOpen }: { group: SubmissionGroup; onOpen: () => void }) {
  const latest = group.submissions[0];
  const completed = group.submissions.filter((item) => item.status.toLowerCase() === "completed").length;
  return (
    <button type="button" onClick={onOpen} className="grid min-h-[96px] grid-cols-[48px_minmax(0,1fr)_20px] items-center gap-4 rounded-xl border border-[#E2E8F0] bg-white p-4 text-left hover:border-[#BFDBFE] hover:shadow-sm">
      <span className="grid h-12 w-12 place-items-center rounded-xl bg-[#0386FF]/10 text-[#0386FF]">
        <Folder size={24} />
      </span>
      <span className="min-w-0">
        <span className="line-clamp-2 block text-base font-bold text-[#1E293B]">{group.title}</span>
        <span className="mt-2 flex flex-wrap gap-2">
          <MiniChip icon={ClipboardList} text={`${group.submissions.length} ${group.submissions.length === 1 ? "submission" : "submissions"}`} />
          {completed > 0 ? <MiniChip icon={Check} text={`${completed} completed`} tone="green" /> : null}
        </span>
        {latest?.submittedAt ? <span className="mt-2 block text-xs text-[#64748B]">Last submitted {shortDate(latest.submittedAt)}</span> : null}
      </span>
      <ChevronRight size={17} className="text-[#94A3B8]" />
    </button>
  );
}

function MiniChip({ icon: Icon, text, tone = "slate" }: { icon: typeof ClipboardList; text: string; tone?: "slate" | "green" }) {
  const classes = tone === "green" ? "bg-[#DCFCE7] text-[#16A34A]" : "bg-[#F1F5F9] text-[#64748B]";
  return (
    <span className={`inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-semibold ${classes}`}>
      <Icon size={14} />
      {text}
    </span>
  );
}

function MonthPicker({
  months,
  selectedYearMonth,
  showAllMonths,
  onClose,
  onSelectAll,
  onSelectMonth,
}: {
  months: string[];
  selectedYearMonth: string;
  showAllMonths: boolean;
  onClose: () => void;
  onSelectAll: () => void;
  onSelectMonth: (month: string) => void;
}) {
  return (
    <div className="fixed inset-0 z-40 grid place-items-end bg-black/30" role="dialog" aria-modal="true" aria-label="Select Month">
      <div className="max-h-[80vh] w-full overflow-hidden rounded-t-2xl bg-white shadow-2xl lg:mx-auto lg:max-w-xl">
        <div className="flex min-h-16 items-center border-b border-[#E2E8F0] px-4">
          <h2 className="text-lg font-bold text-[#1E293B]">Select Month</h2>
          <button type="button" onClick={onClose} aria-label="Close" className="ml-auto grid h-10 w-10 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
            <X size={20} />
          </button>
        </div>
        <button type="button" onClick={onSelectAll} className="flex min-h-14 w-full items-center gap-3 px-4 text-left hover:bg-[#F8FAFC]">
          <Infinity size={20} className={showAllMonths ? "text-[#0386FF]" : "text-[#64748B]"} />
          <span className={`flex-1 text-sm ${showAllMonths ? "font-bold text-[#0386FF]" : "font-medium text-[#1E293B]"}`}>All Time</span>
          {showAllMonths ? <Check size={19} className="text-[#0386FF]" /> : null}
        </button>
        <div className="h-px bg-[#E2E8F0]" />
        <div className="max-h-[52vh] overflow-y-auto">
          {(months.length > 0 ? months : [selectedYearMonth]).map((month) => {
            const selected = !showAllMonths && month === selectedYearMonth;
            const isCurrent = month === currentYearMonth();
            return (
              <button key={month} type="button" onClick={() => onSelectMonth(month)} className="flex min-h-14 w-full items-center gap-3 px-4 text-left hover:bg-[#F8FAFC]">
                <Calendar size={19} className={selected ? "text-[#0386FF]" : "text-[#64748B]"} />
                <span className={`flex min-w-0 flex-1 items-center gap-2 text-sm ${selected ? "font-bold text-[#0386FF]" : "font-medium text-[#1E293B]"}`}>
                  <span className="truncate">{monthDisplayName(month)}</span>
                  {isCurrent ? <span className="rounded bg-[#DCFCE7] px-1.5 py-0.5 text-[10px] font-semibold text-[#10B981]">Current Month</span> : null}
                </span>
                {selected ? <Check size={19} className="text-[#0386FF]" /> : null}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function GroupSheet({ group, onClose, onView }: { group: SubmissionGroup; onClose: () => void; onView: (submission: SubmissionRecord) => void }) {
  return (
    <div className="fixed inset-0 z-40 grid place-items-end bg-black/30" role="dialog" aria-modal="true" aria-label={group.title}>
      <div className="max-h-[88vh] w-full overflow-hidden rounded-t-2xl bg-white shadow-2xl lg:mx-auto lg:max-w-2xl">
        <div className="mx-auto mt-3 h-1 w-10 rounded-full bg-[#E2E8F0]" />
        <div className="flex min-h-16 items-center border-b border-[#E2E8F0] px-5">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-xl font-bold text-[#1E293B]">{group.title}</h2>
            <p className="mt-1 text-sm text-[#64748B]">{group.submissions.length} {group.submissions.length === 1 ? "submission" : "submissions"}</p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close" className="grid h-10 w-10 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
            <X size={20} />
          </button>
        </div>
        <div className="max-h-[70vh] overflow-y-auto p-4">
          {group.submissions.map((submission) => (
            <button key={submission.id} type="button" onClick={() => onView(submission)} className="mb-3 grid min-h-[76px] w-full grid-cols-[1fr_20px] items-center gap-4 rounded-xl border border-[#E2E8F0] bg-white p-4 text-left hover:border-[#BFDBFE]">
              <span className="min-w-0">
                <span className="block text-sm font-bold text-[#1E293B]">{submission.submittedAt ? fullDate(submission.submittedAt) : "Submission date unknown"}</span>
                <span className="mt-2 inline-flex rounded-md bg-[#EFF6FF] px-2 py-1 text-xs font-semibold text-[#0386FF]">{submission.status || "Submitted"}</span>
              </span>
              <ChevronRight size={17} className="text-[#94A3B8]" />
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

function SubmissionDetail({ submission, onClose }: { submission: SubmissionRecord; onClose: () => void }) {
  const entries = Object.entries(submission.responses);
  return (
    <div className="fixed inset-0 z-50 grid place-items-end bg-black/30" role="dialog" aria-modal="true" aria-label={`${submission.formTitle} details`}>
      <div className="max-h-[90vh] w-full overflow-hidden rounded-t-2xl bg-white shadow-2xl lg:mx-auto lg:max-w-3xl">
        <div className="mx-auto mt-3 h-1 w-10 rounded-full bg-[#E2E8F0]" />
        <div className="flex min-h-20 items-start border-b border-[#E2E8F0] px-5 py-4">
          <div className="min-w-0 flex-1">
            <div className="flex items-start gap-2">
              <h2 className="min-w-0 flex-1 text-xl font-bold text-[#1E293B]">{submission.formTitle || "Form Submission"}</h2>
              <span className="inline-flex items-center gap-1 rounded-md bg-[#EFF6FF] px-2.5 py-1 text-xs font-semibold text-[#0386FF]">
                <FileText size={14} />
                Read Only
              </span>
            </div>
            <p className="mt-2 text-sm text-[#64748B]">{submission.submittedAt ? `Submitted on ${fullDate(submission.submittedAt)}` : "Submission date unknown"}</p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close" className="ml-3 grid h-10 w-10 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
            <X size={20} />
          </button>
        </div>
        <div className="max-h-[72vh] overflow-y-auto p-5">
          {entries.length === 0 ? (
            <div className="grid min-h-[280px] place-items-center text-center">
              <div>
                <ClipboardList className="mx-auto text-[#94A3B8]" size={64} />
                <p className="mt-4 text-base font-semibold text-[#64748B]">No responses recorded</p>
              </div>
            </div>
          ) : (
            entries.map(([field, value]) => (
              <div key={field} className="mb-4 rounded-xl border border-[#E2E8F0] p-4">
                <p className="text-sm font-semibold text-[#64748B]">{submission.fieldLabels[field] || formatFieldLabel(field)}</p>
                <SubmissionResponseValue value={value} />
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

function SubmissionResponseValue({ value }: { value: unknown }) {
  const file = objectValue(value);
  const fileUrl = stringValue(file.downloadURL ?? file.url ?? file.file_url);
  const fileName = stringValue(file.fileName ?? file.file_name) || "Uploaded file";
  const fileType = stringValue(file.type ?? file.contentType ?? file.mime_type).toLowerCase();
  if (fileUrl) {
    const isImage = fileType.includes("image") || /\.(png|jpe?g|gif|webp)$/i.test(fileName);
    return (
      <div className="mt-3">
        {isImage ? <img src={fileUrl} alt={fileName} className="mb-3 max-h-72 rounded-xl border border-[#E2E8F0] object-contain" /> : null}
        <a href={fileUrl} target="_blank" rel="noreferrer" className="inline-flex min-h-10 items-center rounded-xl bg-[#EFF6FF] px-4 text-sm font-bold text-[#0369A1] underline">
          {fileName}
        </a>
      </div>
    );
  }
  return <p className="mt-2 whitespace-pre-wrap text-base text-[#1E293B]">{formatFieldValue(value)}</p>;
}

async function loadSubmissions(user: User) {
  const byId = new Map<string, SubmissionRecord>();
  const col = collection(db, "form_responses");

  const snapshots = await Promise.all(
    ["userId", "submittedBy", "teacher_id", "teacherId"].map((field) => getDocs(query(col, where(field, "==", user.uid), limit(500)))),
  );
  for (const snap of snapshots) {
    for (const docSnap of snap.docs) {
      if (byId.has(docSnap.id)) continue;
      byId.set(docSnap.id, normalizeSubmission(docSnap.id, docSnap.data() as Record<string, unknown>));
    }
  }
  const records = Array.from(byId.values()).sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0));
  await hydrateTitles(records);
  return records;
}

async function hydrateTitles(records: SubmissionRecord[]) {
  const templateIds = Array.from(new Set(records.filter((item) => item.formId && item.formId !== noFormIdGroup).map((item) => item.formId)));
  const titles = new Map<string, string>();
  const labels = new Map<string, Record<string, string>>();
  await Promise.all(
    templateIds.map(async (id) => {
      const template = await getDoc(doc(db, "form_templates", id)).catch(() => null);
      if (template?.exists()) {
        const data = template.data() as Record<string, unknown>;
        const title = stringValue(data.name ?? data.title);
        if (title) titles.set(id, title);
        labels.set(id, buildFieldLabels(data.fields));
        return;
      }
      const legacy = await getDoc(doc(db, "form", id)).catch(() => null);
      if (legacy?.exists()) {
        const data = legacy.data() as Record<string, unknown>;
        const title = stringValue(data.title ?? data.formTitle);
        if (title) titles.set(id, title);
        labels.set(id, buildFieldLabels(data.fields));
      }
    }),
  );
  for (const record of records) {
    if (!record.formTitle && record.formId) record.formTitle = titles.get(record.formId) || "Form Submission";
    record.fieldLabels = labels.get(record.formId) ?? {};
  }
}

function normalizeSubmission(id: string, data: Record<string, unknown>): SubmissionRecord {
  const submittedAt = dateValue(data.submittedAt ?? data.submitted_at);
  const responses = objectValue(data.responses);
  const formId = stringValue(data.formId ?? data.form_id ?? data.templateId ?? data.formTemplateId) || noFormIdGroup;
  const title = stringValue(data.formTitle ?? data.form_title ?? data.formName ?? data.title);
  return {
    id,
    formId,
    formTitle: title,
    status: stringValue(data.status) || "Submitted",
    responses,
    fieldLabels: {},
    submittedAt,
    yearMonth: stringValue(data.yearMonth) || (submittedAt ? yearMonthFor(submittedAt) : ""),
  };
}

function buildFieldLabels(value: unknown): Record<string, string> {
  const entries: Array<[string, unknown]> = Array.isArray(value)
    ? value.map((item, index) => [stringValue((item as Record<string, unknown>)?.id) || `field_${index}`, item])
    : value && typeof value === "object"
      ? Object.entries(value as Record<string, unknown>)
      : [];

  return entries.reduce<Record<string, string>>((acc, [id, item]) => {
    const data = item && typeof item === "object" ? (item as Record<string, unknown>) : {};
    const label = stringValue(data.label ?? data.name);
    if (id && label) acc[id] = label;
    return acc;
  }, {});
}

function currentYearMonth() {
  return yearMonthFor(new Date());
}

function yearMonthFor(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

function monthDisplayName(yearMonth: string) {
  const [year, month] = yearMonth.split("-").map((part) => Number(part));
  if (!year || !month) return yearMonth;
  return new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" }).format(new Date(year, month - 1, 1));
}

function shortDate(date: Date) {
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(date);
}

function fullDate(date: Date) {
  return new Intl.DateTimeFormat("en-US", { month: "long", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" }).format(date);
}

function formatFieldLabel(field: string) {
  return field
    .replace(/([A-Z])/g, " $1")
    .replace(/_/g, " ")
    .trim()
    .split(/\s+/)
    .map((word) => (word ? `${word[0].toUpperCase()}${word.slice(1).toLowerCase()}` : ""))
    .join(" ");
}

function formatFieldValue(value: unknown): string {
  if (value == null) return "Not provided";
  if (value instanceof Timestamp) return fullDate(value.toDate());
  if (value instanceof Date) return fullDate(value);
  if (Array.isArray(value)) return value.map(formatFieldValue).join(", ");
  if (typeof value === "boolean") return value ? "Yes" : "No";
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

function objectValue(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) return value as Record<string, unknown>;
  return {};
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

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function summaryForUser(user: User, data: Record<string, unknown> | null) {
  const firstName = stringValue(data?.first_name ?? data?.firstName);
  const lastName = stringValue(data?.last_name ?? data?.lastName);
  const displayName = [firstName, lastName].filter(Boolean).join(" ") || user.displayName || user.email || "Teacher";
  const parts = displayName.replace(/@.*/, "").split(/[^a-zA-Z0-9]+/).filter(Boolean);
  return {
    displayName,
    firstName: firstName || parts[0] || "Teacher",
    initials: parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "TE",
  };
}

function submissionLoadError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error || "");
  if (/permission-denied|insufficient permissions/i.test(message)) return "You do not have permission to view these submissions. Contact an administrator if this continues.";
  if (/unavailable|network|offline/i.test(message) || !navigator.onLine) return "You appear to be offline. Reconnect and try again.";
  return "Check your connection and try again. If the problem continues, contact an administrator.";
}
