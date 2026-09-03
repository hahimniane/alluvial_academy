"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import {
  collection,
  doc,
  arrayUnion,
  deleteField,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  Timestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  Archive,
  Box,
  Calendar,
  CalendarDays,
  Check,
  CheckCircle2,
  Circle,
  ChevronDown,
  Clock,
  Download,
  Grid2X2,
  Handshake,
  Hourglass,
  Inbox,
  Info,
  Lock,
  Mail,
  MessageCircle,
  Phone,
  Radio,
  School,
  Search,
  StickyNote,
  Tag,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";
import { blockById, blockRangeLabel, normalizeBlock, normalizeClassType } from "@/lib/enrollmentDomain";
import {
  draftSheet,
  exportFileName,
  studentSheet,
  teacherSheet,
  type ExportDraft,
  type ExportTeacher,
} from "@/lib/applicantExport";
import { downloadWorkbook, type Sheet } from "@/lib/xlsx";
import { loadTeacherApplications } from "@/components/TeacherApplicantsAdmin";

const EXPORT_LABELS: Record<"view" | "students" | "teachers" | "everything", string> = {
  view: "applicants_view",
  students: "student_applications",
  teachers: "teacher_applications",
  everything: "alluwal_applications",
};
import {
  DISCOUNT_REASONS,
  discountLabel,
  discountToDraft,
  draftToDiscount,
  emptyDiscountDraft,
  formatStartDate,
  fromDateInput,
  toDateInput,
  validateDiscount,
  type DiscountDraft,
  type StudentDiscount,
} from "@/lib/studentDiscount";
import {
  DEFAULT_SORTS,
  MATCHED_SORTS,
  STAGE_FILTERS,
  countByStage,
  daysWaiting,
  groupByTeacher,
  isStale,
  matchesSearch,
  setupFor,
  sortApplicants,
  type SetupState,
  type SortId,
  type StageFilter,
} from "@/lib/applicantTriage";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type ApplicantStatus = "pending" | "contacted" | "broadcasted" | "archived" | "matched";
type TabId = ApplicantStatus | "incomplete";

type ApplicantTab = {
  id: TabId;
  label: string;
  icon: LucideIcon;
  actionLabel: string;
};

type EnrollmentDraft = {
  id: string;
  updatedAt: Date | null;
  step: number;
  stepTitle: string;
  role: string;
  studentNames: string[];
  subjects: string[];
  email: string;
  phone: string;
  whatsApp: string;
  parentName: string;
  city: string;
  timeZone: string;
};

type EnrollmentApplicant = {
  id: string;
  status: ApplicantStatus;
  submittedAt: Date | null;
  programTitle: string;
  studentName: string;
  gradeLevel: string;
  age: string;
  isAdult: boolean;
  days: string[];
  timeSlots: string[];
  timeZone: string;
  parentName: string;
  phone: string;
  city: string;
  schedulingNotes: string;
  teacherName: string;
  matchedAt: Date | null;
  studentUserId: string;
  parentLinked: boolean;
  discount: StudentDiscount | null;
  // Carried for the export; the card shows none of these.
  gender: string;
  email: string;
  whatsApp: string;
  country: string;
  classType: string;
  sessionDuration: string;
  hoursPerWeek: number | null;
  sessionsPerWeek: number | null;
  block: string;
  preferredLanguage: string;
  matchedTeacherId: string;
  /** Filled in by loadTeacherTimezones() for the export only. */
  teacherTimeZone: string;
};

const enrollmentStatuses: ApplicantStatus[] = ["pending", "contacted", "broadcasted", "archived", "matched"];

const tabs: ApplicantTab[] = [
  { id: "pending", label: "Inbox", icon: Inbox, actionLabel: "Mark Contacted" },
  { id: "incomplete", label: "Incomplete", icon: Hourglass, actionLabel: "Follow Up" },
  { id: "contacted", label: "Ready", icon: Phone, actionLabel: "Broadcast" },
  { id: "broadcasted", label: "Live", icon: Radio, actionLabel: "View Matches" },
  { id: "archived", label: "Archived", icon: Archive, actionLabel: "Unarchive" },
  { id: "matched", label: "Matched", icon: Handshake, actionLabel: "View Match" },
];

export function StudentApplicantsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [activeTab, setActiveTab] = useState<TabId>("pending");
  const [counts, setCounts] = useState<Record<TabId, number>>({
    pending: 0,
    incomplete: 0,
    contacted: 0,
    broadcasted: 0,
    archived: 0,
    matched: 0,
  });
  const [applicants, setApplicants] = useState<EnrollmentApplicant[]>([]);
  const [drafts, setDrafts] = useState<EnrollmentDraft[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [scheduledStudents, setScheduledStudents] = useState<Set<string>>(new Set());
  const [discountFor, setDiscountFor] = useState<EnrollmentApplicant | null>(null);
  const [exportOpen, setExportOpen] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [search, setSearch] = useState("");
  const [sort, setSort] = useState<SortId>("recently-matched");
  const [groupTeachers, setGroupTeachers] = useState(false);
  const [stage, setStage] = useState<StageFilter>("all");
  const activeTabConfig = tabs.find((tab) => tab.id === activeTab) ?? tabs[0];
  const isMatched = activeTab === "matched";

  // Setup state is derived once per applicant and reused by the stage pills,
  // the pill counts and the card strip, so they can never disagree.
  const setups = useMemo(() => {
    const map = new Map<string, SetupState>();
    for (const applicant of applicants) {
      map.set(applicant.id, setupFor(applicant, scheduledStudents.has(applicant.studentUserId)));
    }
    return map;
  }, [applicants, scheduledStudents]);

  const stageCounts = useMemo(
    () => countByStage(applicants.map((a) => setups.get(a.id)!.stage)),
    [applicants, setups],
  );

  const visibleApplicants = useMemo(() => {
    const filtered = applicants.filter((applicant) => {
      if (!matchesSearch(applicant, search)) return false;
      if (!isMatched || stage === "all") return true;
      return setups.get(applicant.id)!.stage === stage;
    });
    return sortApplicants(filtered, sort);
  }, [applicants, search, sort, stage, isMatched, setups]);

  const teacherGroups = useMemo(
    () => (groupTeachers && isMatched ? groupByTeacher(visibleApplicants) : null),
    [groupTeachers, isMatched, visibleApplicants],
  );

  // Each tab offers the sorts that mean something on it; leaving a matched-only
  // sort selected on another tab would silently do nothing.
  const sortOptions = isMatched ? MATCHED_SORTS : DEFAULT_SORTS;
  useEffect(() => {
    if (!sortOptions.some((option) => option.id === sort)) setSort(sortOptions[0].id);
  }, [sortOptions, sort]);

  async function runExport(scope: ExportScope) {
    setExporting(true);
    setMessage("");
    try {
      const sheets: Sheet[] = [];

      if (scope === "view") {
        const zones = await loadTeacherTimezones(visibleApplicants);
        sheets.push(
          studentSheet(
            visibleApplicants.map((a) => ({ ...a, teacherTimeZone: zones.get(a.matchedTeacherId) ?? "" })),
            scheduledStudents,
          ),
        );
      }

      if (scope === "students" || scope === "everything") {
        // Every status, not just the tab in view — the menu says "all".
        const [everyApplicant, everyDraft] = await Promise.all([loadAllApplicants(), loadDrafts()]);
        const [scheduled, discounts, zones] = await Promise.all([
          loadScheduledStudents(everyApplicant),
          loadDiscounts(everyApplicant),
          loadTeacherTimezones(everyApplicant),
        ]);
        sheets.push(
          studentSheet(
            everyApplicant.map((a) => ({
              ...a,
              discount: discounts.get(a.studentUserId) ?? null,
              teacherTimeZone: zones.get(a.matchedTeacherId) ?? "",
            })),
            scheduled,
          ),
        );
        sheets.push(draftSheet(everyDraft as ExportDraft[]));
      }

      if (scope === "teachers" || scope === "everything") {
        sheets.push(teacherSheet(await loadTeacherApplications()));
      }

      const rows = sheets.reduce((sum, sheet) => sum + sheet.rows.length, 0);
      if (rows === 0) {
        setMessage("There is nothing to export.");
        return;
      }
      downloadWorkbook(sheets, exportFileName(EXPORT_LABELS[scope]));
      setMessage(`Exported ${rows} ${rows === 1 ? "row" : "rows"}.`);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not build the export.");
    } finally {
      setExporting(false);
      setExportOpen(false);
    }
  }

  async function saveDiscount(applicant: EnrollmentApplicant, draft: DiscountDraft | null) {
    if (!auth.currentUser) {
      setMessage("Sign in with an administrator account before changing a discount.");
      return;
    }
    if (!applicant.studentUserId) {
      setMessage("Create the student's account before setting a discount.");
      return;
    }
    const admin = auth.currentUser;
    const actor = {
      adminId: admin.uid,
      adminName: admin.email ?? "Admin",
      adminEmail: admin.email ?? "",
      timestamp: Timestamp.now(),
    };
    const previous = applicant.discount ? discountLabel(applicant.discount) : null;

    try {
      if (draft) {
        const discount = draftToDiscount(draft);
        await updateDoc(doc(db, "users", applicant.studentUserId), {
          discount: {
            mode: discount.mode,
            value: discount.value,
            duration: discount.duration,
            ...(discount.months ? { months: discount.months } : {}),
            startDate: Timestamp.fromDate(discount.startDate),
            reason: discount.reason,
            ...(discount.note ? { note: discount.note } : {}),
            createdBy: admin.uid,
            createdByName: admin.email ?? "Admin",
            createdAt: serverTimestamp(),
          },
        });
        await updateDoc(doc(db, "enrollments", applicant.id), {
          "metadata.actionHistory": arrayUnion({
            action: previous ? "discount_changed" : "discount_added",
            discount: discountLabel(discount),
            ...(previous ? { previousDiscount: previous } : {}),
            reason: discount.reason,
            ...actor,
          }),
        });
        setMessage(`Discount saved. It applies from ${formatStartDate(discount.startDate)}.`);
      } else {
        await updateDoc(doc(db, "users", applicant.studentUserId), { discount: deleteField() });
        await updateDoc(doc(db, "enrollments", applicant.id), {
          "metadata.actionHistory": arrayUnion({
            action: "discount_removed",
            ...(previous ? { previousDiscount: previous } : {}),
            ...actor,
          }),
        });
        setMessage("Discount removed.");
      }
      setDiscountFor(null);
      await refreshApplicants(activeTab);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not save the discount.");
    }
  }

  const renderApplicantCard = (applicant: EnrollmentApplicant) => (
    <ApplicantCard
      key={applicant.id}
      applicant={applicant}
      tab={activeTabConfig}
      setup={isMatched ? setups.get(applicant.id) ?? null : null}
      onDiscount={() => setDiscountFor(applicant)}
      onMarkContacted={() => moveApplicant(applicant, "contacted")}
      onArchive={() => moveApplicant(applicant, "archived")}
      onUnarchive={() => moveApplicant(applicant, "pending")}
    />
  );

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
      } catch {
        if (mounted) {
          setAccess("denied");
          setLoading(false);
        }
      }
    });
  }, []);

  useEffect(() => {
    if (access !== "allowed") return;
    void refreshApplicants(activeTab);
  }, [access, activeTab]);

  async function refreshApplicants(status: TabId) {
    setLoading(true);
    setMessage("");
    try {
      if (status === "incomplete") {
        const [nextDrafts, nextCounts] = await Promise.all([loadDrafts(), loadCounts()]);
        setDrafts(nextDrafts);
        setCounts(nextCounts);
      } else {
        const [nextApplicants, nextCounts] = await Promise.all([loadApplicants(status), loadCounts()]);
        setApplicants(nextApplicants);
        setCounts(nextCounts);
        const [scheduled, discounts] = await Promise.all([
          status === "matched" ? loadScheduledStudents(nextApplicants) : Promise.resolve(new Set<string>()),
          loadDiscounts(nextApplicants),
        ]);
        setScheduledStudents(scheduled);
        setApplicants(
          nextApplicants.map((applicant) => ({
            ...applicant,
            discount: discounts.get(applicant.studentUserId) ?? null,
          })),
        );
      }
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not load student applicants.");
      setApplicants([]);
      setDrafts([]);
    } finally {
      setLoading(false);
    }
  }

  async function dismissDraft(draft: EnrollmentDraft) {
    if (!auth.currentUser) {
      setMessage("Sign in with an administrator account before updating applicants.");
      return;
    }
    setMessage("");
    try {
      await updateDoc(doc(db, "enrollment_drafts", draft.id), {
        status: "dismissed",
        dismissedAt: serverTimestamp(),
        dismissedBy: auth.currentUser.uid,
        dismissedByName: auth.currentUser.email ?? "Admin",
      });
      setMessage("Incomplete application dismissed.");
      await refreshApplicants(activeTab);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not dismiss the draft.");
    }
  }

  async function moveApplicant(applicant: EnrollmentApplicant, nextStatus: ApplicantStatus) {
    if (!auth.currentUser) {
      setMessage("Sign in with an administrator account before updating applicants.");
      return;
    }
    setMessage("");
    try {
      const action = nextStatus === "contacted" ? "marked_contacted" : nextStatus === "pending" ? "unarchived" : nextStatus;
      await updateDoc(doc(db, "enrollments", applicant.id), {
        "metadata.status": nextStatus,
        "metadata.lastUpdated": serverTimestamp(),
        "metadata.updatedBy": auth.currentUser.uid,
        "metadata.updatedByName": auth.currentUser.email ?? "Admin",
        ...(nextStatus === "contacted"
          ? {
              "metadata.contactedAt": serverTimestamp(),
              "metadata.contactedBy": auth.currentUser.uid,
              "metadata.contactedByName": auth.currentUser.email ?? "Admin",
            }
          : {}),
        ...(nextStatus === "archived"
          ? {
              "metadata.archivedAt": serverTimestamp(),
              "metadata.archivedBy": auth.currentUser.uid,
              "metadata.archivedByName": auth.currentUser.email ?? "Admin",
              "metadata.archivedPreviousStatus": applicant.status,
            }
          : {}),
        "metadata.actionHistory": arrayUnion(
          {
            action,
            status: nextStatus,
            adminId: auth.currentUser.uid,
            adminName: auth.currentUser.email ?? "Admin",
            adminEmail: auth.currentUser.email ?? "",
            timestamp: Timestamp.now(),
          },
        ),
      });
      setMessage(nextStatus === "contacted" ? "Marked as contacted. Moved to Ready." : "Application updated.");
      await refreshApplicants(activeTab);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not update applicant.");
    }
  }

  if (access !== "allowed") {
    return <StudentApplicantsAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Student Applicants" breadcrumb="People / Student Applicants">
      <main className="min-h-[calc(100vh-56px)] bg-[#F3F4F6]">
        <header className="lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center bg-white px-3 text-[#0F172A]">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl text-[#0F172A]">
              <span className="h-0.5 w-4 bg-current" />
              <span className="-mt-5 h-0.5 w-4 bg-current" />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black text-[#0F172A]">Alluwal Education Hub</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">
              {initialsFor(user)}
            </span>
          </div>
        </header>

        <section className="border-b border-black/10 bg-white px-4 py-5 lg:px-6">
          <div className="flex items-center gap-4">
            <span className="grid h-12 w-12 place-items-center rounded-2xl bg-[#EFF6FF] text-[#3B82F6]">
              <Grid2X2 size={24} />
            </span>
            <div className="min-w-0">
              <h1 className="text-2xl font-black leading-tight text-[#111827]">Student Applicants</h1>
              <p className="mt-1 text-sm text-[#6B7280]">Manage Student Applications And Enrollment</p>
            </div>
          </div>
        </section>

        <section className="overflow-x-auto border-b border-black/20 bg-white px-4 lg:px-6" aria-label="Student applicant pipeline">
          <div className="flex min-w-max items-center gap-5">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              const active = activeTab === tab.id;
              const count = counts[tab.id];
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setActiveTab(tab.id)}
                  className={`relative inline-flex min-h-[52px] items-center gap-2 border-b-[3px] px-1 text-sm font-black ${
                    active ? "border-[#3B82F6] text-[#3B82F6]" : "border-transparent text-[#6B7280]"
                  }`}
                >
                  <Icon size={18} />
                  <span>{tab.label}</span>
                  {count > 0 ? (
                    <span className="rounded-full bg-[#EFF6FF] px-2 py-0.5 text-[11px] font-black text-[#3B82F6]">{count}</span>
                  ) : null}
                </button>
              );
            })}
          </div>
        </section>

        {activeTab !== "incomplete" ? (
          <ApplicantTriageToolbar
            search={search}
            onSearch={setSearch}
            sort={sort}
            onSort={setSort}
            sortOptions={sortOptions}
            showTeacherTools={isMatched}
            groupTeachers={groupTeachers}
            onGroupTeachers={setGroupTeachers}
            stage={stage}
            onStage={setStage}
            stageCounts={stageCounts}
            shown={visibleApplicants.length}
            total={applicants.length}
            exportOpen={exportOpen}
            onExportOpen={setExportOpen}
            exporting={exporting}
            onExport={(scope) => void runExport(scope)}
          />
        ) : null}

        {message ? (
          <div className="mx-4 mt-4 rounded-2xl border border-[#BFDBFE] bg-[#EFF6FF] px-4 py-3 text-sm font-semibold text-[#1D4ED8] lg:mx-6">
            {message}
          </div>
        ) : null}

        <section className="px-4 py-4 lg:px-6">
          {loading ? (
            <div className="grid min-h-[320px] place-items-center">
              <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#3B82F6]" />
            </div>
          ) : activeTab === "incomplete" ? (
            drafts.length === 0 ? (
              <EmptyApplicantsState status={activeTab} />
            ) : (
              <div className="grid gap-3">
                {drafts.map((draft) => (
                  <DraftCard key={draft.id} draft={draft} onDismiss={() => dismissDraft(draft)} />
                ))}
              </div>
            )
          ) : applicants.length === 0 ? (
            <EmptyApplicantsState status={activeTab} />
          ) : visibleApplicants.length === 0 ? (
            <NoMatchesState onClear={() => { setSearch(""); setStage("all"); }} />
          ) : teacherGroups ? (
            <div className="grid gap-6">
              {teacherGroups.map((group) => (
                <div key={group.teacher}>
                  <div className="flex items-center gap-2 pb-2">
                    <School size={16} className="text-[#EA580C]" />
                    <span className="text-xs font-bold text-[#1E293B]">{group.teacher}</span>
                    <span className="rounded-full border border-[#FDBA74] bg-[#FFF7ED] px-2 py-0.5 text-[11px] font-bold text-[#C2410C]">
                      {group.applicants.length}
                    </span>
                  </div>
                  <div className="grid gap-3 border-t border-[#E5E7EB] pt-3">
                    {group.applicants.map((applicant) => renderApplicantCard(applicant))}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="grid gap-3">{visibleApplicants.map((applicant) => renderApplicantCard(applicant))}</div>
          )}
        </section>
        {discountFor ? (
          <DiscountDialog
            studentName={discountFor.studentName}
            existing={discountFor.discount}
            // Best signal available for when this student's enrollment began;
            // nothing records it, so the admin confirms or corrects it here
            // rather than billing code guessing.
            defaultStartDate={discountFor.matchedAt ?? discountFor.submittedAt ?? new Date()}
            onSave={(draft) => void saveDiscount(discountFor, draft)}
            onRemove={() => void saveDiscount(discountFor, null)}
            onClose={() => setDiscountFor(null)}
          />
        ) : null}
      </main>
    </AdminDashboardShell>
  );
}

export function DiscountDialog({
  studentName,
  existing,
  defaultStartDate,
  onSave,
  onRemove,
  onClose,
}: {
  studentName: string;
  existing: StudentDiscount | null;
  defaultStartDate: Date;
  onSave: (draft: DiscountDraft) => void;
  onRemove: () => void;
  onClose: () => void;
}) {
  const [draft, setDraft] = useState<DiscountDraft>(() =>
    existing ? discountToDraft(existing) : emptyDiscountDraft(defaultStartDate),
  );
  const [showError, setShowError] = useState(false);
  const error = validateDiscount(draft);
  const preview = error ? null : draftToDiscount(draft);
  const set = (patch: Partial<DiscountDraft>) => setDraft((current) => ({ ...current, ...patch }));

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true" aria-label="Student discount">
      <div className="max-h-full w-full max-w-[520px] overflow-y-auto rounded-[28px] bg-white p-6 shadow-[0_24px_60px_rgba(0,0,0,0.32)]">
        <h2 className="text-xl font-bold text-[#111827]">Student discount</h2>
        <p className="mt-1 text-[13px] text-[#64748B]">
          {studentName} · applies to every program this student takes
        </p>

        <div className="mt-5 grid grid-cols-2 gap-2.5">
          {([
            { mode: "percent" as const, title: "Percentage", hint: "% off the monthly total" },
            { mode: "fixed" as const, title: "Fixed amount", hint: "$ off each month" },
          ]).map((option) => {
            const active = draft.mode === option.mode;
            return (
              <button
                key={option.mode}
                type="button"
                aria-pressed={active}
                onClick={() => set({ mode: option.mode })}
                className={`rounded-lg border-[1.5px] p-3 text-left transition ${
                  active ? "border-[#3B82F6] bg-[#EFF6FF] text-[#1D4ED8]" : "border-[#E2E8F0] bg-white text-[#475569]"
                }`}
              >
                <span className="block text-xs font-bold">{option.title}</span>
                <span className="mt-0.5 block text-[11px] font-medium text-[#64748B]">{option.hint}</span>
              </button>
            );
          })}
        </div>

        <div className="mt-4 flex items-end gap-2.5">
          <div>
            <label htmlFor="discount-value" className="block text-[11px] font-semibold text-[#1E293B]">Amount</label>
            <input
              id="discount-value"
              type="number"
              min="0"
              step="0.01"
              value={draft.value}
              onChange={(event) => set({ value: event.target.value })}
              className="mt-1 h-10 w-[110px] rounded border border-[#79747E] px-2.5 text-[15px] font-bold text-[#111827] outline-none focus:border-[#3B82F6]"
            />
          </div>
          <span className="pb-2.5 text-xs font-semibold text-[#64748B]">
            {draft.mode === "percent" ? "%" : "$ / month"}
          </span>
        </div>

        <fieldset className="mt-5">
          <legend className="text-[11px] font-semibold text-[#1E293B]">How long it lasts</legend>
          <div className="mt-1.5 grid gap-1.5">
            {([
              { duration: "months" as const, label: "First few months" },
              { duration: "ongoing" as const, label: "Ongoing, until removed" },
            ]).map((option) => (
              <label key={option.duration} className="flex items-center gap-2 text-xs font-medium text-[#334155]">
                <input
                  type="radio"
                  name="discount-duration"
                  checked={draft.duration === option.duration}
                  onChange={() => set({ duration: option.duration })}
                  className="h-[18px] w-[18px] accent-[#3B82F6]"
                />
                {option.label}
              </label>
            ))}
          </div>
          {draft.duration === "months" ? (
            <div className="mt-2 flex items-center gap-2">
              <label htmlFor="discount-months" className="sr-only">Number of months</label>
              <input
                id="discount-months"
                type="number"
                min="1"
                step="1"
                value={draft.months}
                onChange={(event) => set({ months: event.target.value })}
                className="h-10 w-20 rounded border border-[#79747E] px-2.5 text-[15px] font-bold text-[#111827] outline-none focus:border-[#3B82F6]"
              />
              <span className="text-xs text-[#64748B]">months from the start date below</span>
            </div>
          ) : null}
        </fieldset>

        <div className="mt-5">
          <label htmlFor="discount-start" className="block text-[11px] font-semibold text-[#1E293B]">Month 1 starts on</label>
          <input
            id="discount-start"
            type="date"
            value={draft.startDate}
            onChange={(event) => set({ startDate: event.target.value })}
            className="mt-1 h-10 rounded border border-[#79747E] px-2.5 text-sm text-[#111827] outline-none focus:border-[#3B82F6]"
          />
        </div>

        <div className="mt-3 flex gap-2 rounded-[10px] border border-[#BFDBFE] bg-[#EFF6FF] p-3">
          <CalendarDays size={16} className="mt-0.5 shrink-0 text-[#1D4ED8]" />
          <p className="text-xs leading-[1.45] text-[#1E40AF]">
            {preview ? (
              <>
                Month 1 starts on <strong>{formatStartDate(preview.startDate)}</strong>. Every invoice from then on
                shows <strong>{discountLabel(preview)}</strong>.
              </>
            ) : (
              "Set an amount and a start date to see which invoices this covers."
            )}
          </p>
        </div>

        <div className="mt-4">
          <label htmlFor="discount-reason" className="block text-[11px] font-semibold text-[#1E293B]">Reason</label>
          <select
            id="discount-reason"
            value={draft.reason}
            onChange={(event) => set({ reason: event.target.value })}
            className="mt-1 h-10 w-full rounded border border-[#79747E] bg-white px-2.5 text-sm text-[#111827] outline-none focus:border-[#3B82F6]"
          >
            {DISCOUNT_REASONS.map((reason) => (
              <option key={reason} value={reason}>{reason}</option>
            ))}
          </select>
        </div>

        <div className="mt-4">
          <label htmlFor="discount-note" className="block text-[11px] font-semibold text-[#1E293B]">Note (optional)</label>
          <textarea
            id="discount-note"
            rows={2}
            value={draft.note}
            onChange={(event) => set({ note: event.target.value })}
            placeholder="Who approved it and why..."
            className="mt-1 w-full rounded border border-[#79747E] px-2.5 py-2 text-sm text-[#111827] outline-none placeholder:text-[#9CA3AF] focus:border-[#3B82F6]"
          />
        </div>

        {showError && error ? (
          <p role="alert" className="mt-3 text-xs font-semibold text-[#DC2626]">{error}</p>
        ) : null}

        <div className="mt-6 flex items-center gap-3">
          {existing ? (
            <button type="button" onClick={onRemove} className="text-sm font-semibold text-[#DC2626] hover:underline">
              Remove discount
            </button>
          ) : null}
          <span className="flex-1" />
          <button type="button" onClick={onClose} className="px-3 py-2 text-sm font-semibold text-[#475569]">
            Cancel
          </button>
          <button
            type="button"
            onClick={() => (error ? setShowError(true) : onSave(draft))}
            className="rounded-[20px] bg-[#0F172A] px-5 py-2.5 text-sm font-bold text-white"
          >
            Save discount
          </button>
        </div>
      </div>
    </div>
  );
}

type ExportScope = "view" | "students" | "teachers" | "everything";

const EXPORT_OPTIONS: { scope: ExportScope; label: string; hint: string }[] = [
  { scope: "view", label: "This view", hint: "The rows on screen, in the order shown." },
  { scope: "students", label: "All student applications", hint: "Every status, plus unfinished drafts." },
  { scope: "teachers", label: "All teacher applications", hint: "Every teacher application on file." },
  { scope: "everything", label: "Everything", hint: "Students, drafts and teachers in one workbook." },
];

export function ApplicantTriageToolbar({
  search,
  onSearch,
  sort,
  onSort,
  sortOptions,
  showTeacherTools,
  groupTeachers,
  onGroupTeachers,
  stage,
  onStage,
  stageCounts,
  shown,
  total,
  exportOpen,
  onExportOpen,
  exporting,
  onExport,
}: {
  search: string;
  onSearch: (value: string) => void;
  sort: SortId;
  onSort: (value: SortId) => void;
  sortOptions: readonly { id: SortId; label: string }[];
  showTeacherTools: boolean;
  groupTeachers: boolean;
  onGroupTeachers: (value: boolean) => void;
  stage: StageFilter;
  onStage: (value: StageFilter) => void;
  stageCounts: Record<StageFilter, number>;
  shown: number;
  total: number;
  exportOpen: boolean;
  onExportOpen: (value: boolean) => void;
  exporting: boolean;
  onExport: (scope: ExportScope) => void;
}) {
  return (
        <section className="border-b border-[#E5E7EB] bg-white px-4 py-2.5 lg:px-6" aria-label="Filter applicants">
          <div className="flex flex-wrap items-center gap-2.5">
            <div className="relative">
              <Search size={17} className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-[#9CA3AF]" />
              <input
                type="search"
                value={search}
                onChange={(event) => onSearch(event.target.value)}
                placeholder="Search name or teacher"
                aria-label="Search applicants"
                className="h-[34px] w-[260px] rounded-lg border border-[#E5E7EB] pl-8 pr-2.5 text-xs text-[#111827] outline-none placeholder:text-[#9CA3AF] focus:border-[#0386FF]"
              />
            </div>

            <label className="sr-only" htmlFor="applicant-sort">Sort applicants</label>
            <select
              id="applicant-sort"
              value={sort}
              onChange={(event) => onSort(event.target.value as SortId)}
              className="h-[34px] rounded-lg border border-[#E5E7EB] bg-white px-2.5 text-xs font-semibold text-[#111827] outline-none focus:border-[#0386FF]"
            >
              {sortOptions.map((option) => (
                <option key={option.id} value={option.id}>{option.label}</option>
              ))}
            </select>

            {showTeacherTools ? (
              <button
                type="button"
                aria-pressed={groupTeachers}
                onClick={() => onGroupTeachers(!groupTeachers)}
                className={`h-[34px] rounded-lg border px-3 text-xs font-semibold transition ${
                  groupTeachers
                    ? "border-[rgba(3,134,255,0.4)] bg-[#EFF6FF] text-[#0386FF]"
                    : "border-[#E5E7EB] bg-white text-[#475569] hover:bg-slate-50"
                }`}
              >
                Group by teacher
              </button>
            ) : null}

            <div className="relative">
              <button
                type="button"
                aria-haspopup="menu"
                aria-expanded={exportOpen}
                disabled={exporting}
                onClick={() => onExportOpen(!exportOpen)}
                className="inline-flex h-[34px] items-center gap-1.5 rounded-lg border border-[#10B981] bg-[#ECFDF5] px-3 text-xs font-bold text-[#047857] disabled:opacity-60"
              >
                <Download size={16} />
                {exporting ? "Building…" : "Excel"}
                <ChevronDown size={15} />
              </button>
              {exportOpen ? (
                <div
                  role="menu"
                  className="absolute right-0 top-[38px] z-20 w-72 overflow-hidden rounded-xl bg-white shadow-[0_12px_32px_rgba(15,23,42,0.18)]"
                >
                  {EXPORT_OPTIONS.map((option) => (
                    <button
                      key={option.scope}
                      type="button"
                      role="menuitem"
                      onClick={() => onExport(option.scope)}
                      className="block w-full px-3.5 py-2.5 text-left hover:bg-[#F8FAFC]"
                    >
                      <span className="block text-xs font-bold text-[#1E293B]">{option.label}</span>
                      <span className="mt-0.5 block text-[11px] text-[#64748B]">{option.hint}</span>
                    </button>
                  ))}
                </div>
              ) : null}
            </div>

            <span className="ml-auto text-xs font-semibold text-[#6B7280]">
              {shown === total
                ? `${total} ${total === 1 ? "applicant" : "applicants"}`
                : `${shown} of ${total}`}
            </span>
          </div>

          {showTeacherTools ? (
            <div className="mt-2.5 flex flex-wrap items-center gap-2">
              {STAGE_FILTERS.map((filter) => {
                const active = stage === filter.id;
                const count = stageCounts[filter.id];
                return (
                  <button
                    key={filter.id}
                    type="button"
                    aria-pressed={active}
                    onClick={() => onStage(filter.id)}
                    className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold transition ${
                      active ? "bg-[#0386FF] text-white" : "border border-[#E5E7EB] bg-white text-[#475569] hover:bg-slate-50"
                    }`}
                  >
                    {filter.label}
                    <span
                      className={`rounded-full px-1.5 text-[11px] font-bold ${
                        active ? "bg-white/25 text-white" : "bg-[#F1F5F9] text-[#64748B]"
                      }`}
                    >
                      {count}
                    </span>
                  </button>
                );
              })}
            </div>
          ) : null}
        </section>
  );
}

function SetupStrip({ setup }: { setup: SetupState }) {
  const pills = [
    { label: "Account", done: setup.hasAccount },
    { label: "Schedule", done: setup.hasSchedule },
    { label: "Parent", done: setup.hasParent },
  ];
  const ready = setup.stage === "ready";
  return (
    <div className="flex flex-wrap items-center gap-2 border-b border-[#E5E7EB] bg-white px-4 py-2">
      {pills.map((pill) => (
        <span
          key={pill.label}
          className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-bold tracking-[0.3px] ${
            pill.done ? "bg-[#D1FAE5] text-[#065F46]" : "bg-[#F1F5F9] text-[#64748B]"
          }`}
        >
          {pill.done ? <CheckCircle2 size={12} /> : <Circle size={12} />}
          {pill.label}
        </span>
      ))}
      <span className={`ml-auto text-[11px] font-semibold ${ready ? "text-[#059669]" : "text-[#B45309]"}`}>
        {setup.nextAction}
      </span>
    </div>
  );
}

function NoMatchesState({ onClear }: { onClear: () => void }) {
  return (
    <div className="grid min-h-[220px] place-items-center rounded-xl border border-dashed border-[#E5E7EB] bg-white">
      <div className="text-center">
        <p className="text-sm font-bold text-[#334155]">No applicants match these filters</p>
        <button
          type="button"
          onClick={onClear}
          className="mt-2 rounded-lg border border-[#E5E7EB] px-3 py-1.5 text-xs font-semibold text-[#0386FF] hover:bg-slate-50"
        >
          Clear search and filters
        </button>
      </div>
    </div>
  );
}

function ApplicantCard({
  applicant,
  tab,
  setup,
  onDiscount,
  onMarkContacted,
  onArchive,
  onUnarchive,
}: {
  applicant: EnrollmentApplicant;
  tab: ApplicantTab;
  setup: SetupState | null;
  onDiscount: () => void;
  onMarkContacted: () => void;
  onArchive: () => void;
  onUnarchive: () => void;
}) {
  const live = applicant.status === "broadcasted";
  const archived = applicant.status === "archived";
  const matched = applicant.status === "matched";
  const waiting = setup && isStale(applicant.matchedAt, setup.stage) ? daysWaiting(applicant.matchedAt) : null;
  return (
    <article className={`overflow-hidden rounded-xl bg-white shadow-[0_2px_10px_rgba(15,23,42,0.03)] ${live ? "border border-[#10B981]" : ""}`}>
      <div className={`flex items-center gap-2 px-4 py-2 text-[11px] font-bold ${matched ? "bg-[#ECFDF5] text-[#059669]" : live ? "bg-[#ECFDF5] text-[#059669]" : archived ? "bg-[#F1F5F9] text-[#64748B]" : "bg-[#F8FAFC] text-[#94A3B8]"}`}>
        {matched ? <Handshake size={14} /> : live ? <Radio size={14} /> : archived ? <Archive size={14} /> : <Clock size={14} />}
        <span>
          {matched
            ? `MATCHED${applicant.teacherName ? ` • ${applicant.teacherName}` : ""}`
            : live
              ? "LIVE ON JOB BOARD"
              : archived
                ? "ARCHIVED"
                : formatSubmittedAt(applicant.submittedAt)}
        </span>
        <span className="flex-1" />
        {waiting !== null ? (
          <span className="inline-flex items-center gap-1 rounded bg-[#FEF3C7] px-1.5 py-0.5 text-[10px] font-bold text-[#92400E]">
            <Clock size={12} />
            Waiting {waiting} {waiting === 1 ? "day" : "days"}
          </span>
        ) : null}
        {applicant.isAdult ? <span className="rounded bg-[#EFF6FF] px-1.5 py-0.5 text-[10px] font-black text-[#1D4ED8]">ADULT STUDENT</span> : null}
      </div>
      {setup ? <SetupStrip setup={setup} /> : null}
      <div className="p-4">
        <div className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-base font-black text-[#1E293B]">{applicant.programTitle}</h2>
            <p className="mt-1 text-sm leading-5 text-[#64748B]">
              {applicant.studentName} {applicant.gradeLevel ? `• ${applicant.gradeLevel}` : ""}
            </p>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <button type="button" className="grid h-9 w-9 place-items-center rounded-lg bg-[#EEF2FF] text-[#4F46E5]" aria-label={`View ${applicant.studentName}`}>
              <Info size={17} />
            </button>
            {applicant.phone ? (
              <a href={`tel:${applicant.phone}`} className="grid h-9 w-9 place-items-center rounded-lg bg-[#EFF6FF] text-[#2563EB]" aria-label={`Call ${applicant.studentName}`}>
                <Phone size={17} />
              </a>
            ) : null}
          </div>
        </div>
        <div className="mt-3 flex flex-wrap gap-x-3 gap-y-2 text-xs font-semibold text-[#475569]">
          <MiniChip icon={Calendar} text={applicant.days.join(", ")} />
          <MiniChip icon={Clock} text={applicant.timeSlots.join(", ")} />
          <MiniChip icon={School} text={applicant.timeZone} />
          {!applicant.isAdult ? <MiniChip icon={Users} text={applicant.parentName ? `Parent: ${applicant.parentName}` : ""} /> : null}
        </div>
        {applicant.schedulingNotes ? (
          <div className="mt-3 flex items-start gap-2 rounded-lg border border-[#E2E8F0] bg-[#F8FAFC] px-3 py-2.5">
            <StickyNote size={16} className="mt-px shrink-0 text-[#64748B]" />
            <div className="min-w-0">
              <p className="text-[11px] font-bold text-[#475569]">Scheduling notes from the family</p>
              <p className="mt-0.5 whitespace-pre-wrap text-xs leading-relaxed text-[#334155]">
                {applicant.schedulingNotes}
              </p>
            </div>
          </div>
        ) : null}
        <div className="mt-4 border-t border-black/10 pt-3">
          <div className="mb-3 flex flex-wrap items-center gap-2">
            {applicant.discount ? (
              <span className="inline-flex items-center gap-1.5 rounded-lg bg-[#FEF3C7] px-2.5 py-2 text-[11px] text-[#92400E]">
                <Tag size={14} />
                <span className="font-bold">{discountLabel(applicant.discount)}</span>
                {applicant.discount.reason ? <span className="font-medium">· {applicant.discount.reason}</span> : null}
              </span>
            ) : (
              <span className="rounded-lg bg-[#F1F5F9] px-2.5 py-2 text-[11px] font-semibold text-[#475569]">No discount</span>
            )}
            <button
              type="button"
              onClick={onDiscount}
              disabled={!applicant.studentUserId}
              title={applicant.studentUserId ? undefined : "Create the student's account first"}
              className="inline-flex min-h-9 flex-1 items-center justify-center gap-2 rounded-lg border border-black/10 px-3 text-xs font-semibold text-[#B45309] hover:bg-[#FFFBEB] disabled:cursor-not-allowed disabled:text-[#CBD5E1] disabled:hover:bg-transparent"
            >
              <Tag size={16} />
              {applicant.discount ? "Edit discount" : "Add discount"}
            </button>
          </div>
          <div className="flex items-center gap-3">
            {applicant.status !== "archived" ? (
              <button type="button" onClick={onArchive} aria-label={`Archive ${applicant.studentName}`} className="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-[#94A3B8] hover:bg-[#F1F5F9]">
                <Box size={17} />
              </button>
            ) : null}
            {applicant.status === "pending" ? (
              <button type="button" onClick={onMarkContacted} className="inline-flex min-h-9 flex-1 items-center justify-center gap-2 rounded-lg bg-[#3B82F6] px-4 text-sm font-bold text-white">
                <Check size={17} />
                Mark Contacted
              </button>
            ) : applicant.status === "archived" ? (
              <button type="button" onClick={onUnarchive} className="inline-flex min-h-9 flex-1 items-center justify-center rounded-lg bg-[#3B82F6] px-4 text-sm font-bold text-white">
                Unarchive
              </button>
            ) : (
              <Link href="/app/#/login" className="inline-flex min-h-9 flex-1 items-center justify-center rounded-lg bg-[#3B82F6] px-4 text-sm font-bold text-white">
                {tab.actionLabel}
              </Link>
            )}
          </div>
        </div>
      </div>
    </article>
  );
}

function MiniChip({ icon: Icon, text }: { icon: LucideIcon; text: string }) {
  if (!text) return null;
  const display = text.length > 28 ? `${text.slice(0, 25)}...` : text;
  return (
    <span className="inline-flex min-w-0 items-center gap-1">
      <Icon size={13} className="shrink-0 text-[#94A3B8]" />
      <span className="truncate">{display}</span>
    </span>
  );
}

function DraftCard({ draft, onDismiss }: { draft: EnrollmentDraft; onDismiss: () => void }) {
  const students = draft.studentNames.filter(Boolean);
  const subjects = draft.subjects.filter(Boolean);
  const progress = Math.min(Math.max(draft.step + 1, 1), 5);
  const whatsAppDigits = draft.whatsApp.replace(/[^\d]/g, "");
  return (
    <article className="overflow-hidden rounded-xl border border-[#FDE68A] bg-white shadow-[0_2px_10px_rgba(15,23,42,0.03)]">
      <div className="flex items-center gap-2 bg-[#FFFBEB] px-4 py-2 text-[11px] font-bold text-[#B45309]">
        <Hourglass size={14} />
        <span>INCOMPLETE APPLICATION</span>
        <span className="flex-1" />
        <span>{draft.updatedAt ? `Last active ${timeAgo(draft.updatedAt)}` : ""}</span>
      </div>
      <div className="p-4">
        <div className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-base font-black text-[#1E293B]">
              {students.length > 0 ? students.join(", ") : draft.parentName || draft.email || draft.whatsApp || "Unknown applicant"}
            </h2>
            <p className="mt-1 text-sm leading-5 text-[#64748B]">
              {subjects.length > 0 ? subjects.join(", ") : "No program selected yet"}
              {draft.role ? ` • ${draft.role}` : ""}
            </p>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            {draft.email ? (
              <a href={`mailto:${draft.email}`} className="grid h-9 w-9 place-items-center rounded-lg bg-[#EEF2FF] text-[#4F46E5]" aria-label={`Email ${draft.email}`}>
                <Mail size={17} />
              </a>
            ) : null}
            {whatsAppDigits ? (
              <a
                href={`https://wa.me/${whatsAppDigits}`}
                target="_blank"
                rel="noreferrer"
                className="grid h-9 w-9 place-items-center rounded-lg bg-[#ECFDF5] text-[#059669]"
                aria-label={`WhatsApp ${draft.whatsApp}`}
              >
                <MessageCircle size={17} />
              </a>
            ) : null}
            {draft.phone ? (
              <a href={`tel:${draft.phone}`} className="grid h-9 w-9 place-items-center rounded-lg bg-[#EFF6FF] text-[#2563EB]" aria-label={`Call ${draft.phone}`}>
                <Phone size={17} />
              </a>
            ) : null}
          </div>
        </div>
        <div className="mt-3">
          <div className="flex items-center justify-between text-[11px] font-bold text-[#92400E]">
            <span>Stopped at: {draft.stepTitle || `Step ${progress}`}</span>
            <span>{progress} of 5 steps</span>
          </div>
          <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-[#FEF3C7]">
            <div className="h-full rounded-full bg-[#F59E0B]" style={{ width: `${(progress / 5) * 100}%` }} />
          </div>
        </div>
        <div className="mt-3 flex flex-wrap gap-x-3 gap-y-2 text-xs font-semibold text-[#475569]">
          <MiniChip icon={Mail} text={draft.email} />
          <MiniChip icon={Phone} text={draft.phone || draft.whatsApp} />
          <MiniChip icon={Users} text={draft.parentName ? `Parent: ${draft.parentName}` : ""} />
          <MiniChip icon={School} text={draft.city || draft.timeZone} />
        </div>
        <div className="mt-4 border-t border-black/10 pt-3">
          <div className="flex items-center gap-3">
            <button type="button" onClick={onDismiss} className="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-[#94A3B8] hover:bg-[#F1F5F9]" aria-label="Dismiss incomplete application">
              <Box size={17} />
            </button>
            {draft.email ? (
              <a href={`mailto:${draft.email}?subject=${encodeURIComponent("Finish your Alluwal Education Hub enrollment")}`} className="inline-flex min-h-9 flex-1 items-center justify-center gap-2 rounded-lg bg-[#F59E0B] px-4 text-sm font-bold text-white">
                <Mail size={17} />
                Follow Up by Email
              </a>
            ) : whatsAppDigits ? (
              <a href={`https://wa.me/${whatsAppDigits}`} target="_blank" rel="noreferrer" className="inline-flex min-h-9 flex-1 items-center justify-center gap-2 rounded-lg bg-[#059669] px-4 text-sm font-bold text-white">
                <MessageCircle size={17} />
                Follow Up on WhatsApp
              </a>
            ) : draft.phone ? (
              <a href={`tel:${draft.phone}`} className="inline-flex min-h-9 flex-1 items-center justify-center gap-2 rounded-lg bg-[#2563EB] px-4 text-sm font-bold text-white">
                <Phone size={17} />
                Call to Follow Up
              </a>
            ) : (
              <span className="inline-flex min-h-9 flex-1 items-center justify-center rounded-lg bg-[#F1F5F9] px-4 text-sm font-bold text-[#94A3B8]">
                No contact info yet
              </span>
            )}
          </div>
        </div>
      </div>
    </article>
  );
}

function EmptyApplicantsState({ status }: { status: TabId }) {
  return (
    <div className="grid min-h-[420px] place-items-center text-center">
      <div>
        <Check className="mx-auto text-[#D1D5DB]" size={64} />
        <p className="mt-4 text-base font-semibold text-[#6B7280]">No enrollments in &quot;{status}&quot;</p>
      </div>
    </div>
  );
}

function StudentApplicantsAccessPrompt({ access }: { access: AccessState }) {
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
              ? "Sign in with an administrator account before managing student applicants."
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

async function loadApplicants(status: ApplicantStatus) {
  const snap = await getDocs(query(collection(db, "enrollments"), where("metadata.status", "==", status), limit(80)));
  return snap.docs
    .map((docSnap) => normalizeApplicant(docSnap.id, docSnap.data() as Record<string, unknown>))
    .sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0));
}

/** One read per matched teacher, for the export's teacher timezone column. */
async function loadTeacherTimezones(applicants: EnrollmentApplicant[]): Promise<Map<string, string>> {
  const ids = [...new Set(applicants.map((a) => a.matchedTeacherId).filter(Boolean))];
  const zones = new Map<string, string>();
  const snapshots = await Promise.all(ids.map((id) => getDoc(doc(db, "users", id))));
  snapshots.forEach((snapshot, index) => {
    if (!snapshot.exists()) return;
    const zone = stringValue((snapshot.data() as Record<string, unknown>).timezone);
    if (zone) zones.set(ids[index], zone);
  });
  return zones;
}

/** Every status, for the "all applications" export. */
async function loadAllApplicants(): Promise<EnrollmentApplicant[]> {
  const snap = await getDocs(query(collection(db, "enrollments"), limit(1000)));
  return snap.docs
    .map((docSnap) => normalizeApplicant(docSnap.id, docSnap.data() as Record<string, unknown>))
    .sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0));
}

async function loadDrafts() {
  const snap = await getDocs(query(collection(db, "enrollment_drafts"), where("status", "==", "in_progress"), limit(80)));
  return snap.docs
    .map((docSnap) => normalizeDraft(docSnap.id, docSnap.data() as Record<string, unknown>))
    .sort((a, b) => (b.updatedAt?.getTime() ?? 0) - (a.updatedAt?.getTime() ?? 0));
}

async function loadCounts() {
  const pairs = await Promise.all(
    tabs.map(async (tab) => {
      try {
        const snap =
          tab.id === "incomplete"
            ? await getDocs(query(collection(db, "enrollment_drafts"), where("status", "==", "in_progress"), limit(80)))
            : await getDocs(query(collection(db, "enrollments"), where("metadata.status", "==", tab.id), limit(80)));
        return [tab.id, snap.size] as const;
      } catch {
        return [tab.id, 0] as const;
      }
    }),
  );
  return Object.fromEntries(pairs) as Record<TabId, number>;
}

function normalizeDraft(id: string, data: Record<string, unknown>): EnrollmentDraft {
  const contact = recordValue(data.contact);
  const students = Array.isArray(data.students) ? data.students.map((student) => recordValue(student)) : [];
  return {
    id,
    updatedAt: dateValue(data.updatedAt),
    step: typeof data.step === "number" ? data.step : 0,
    stepTitle: stringValue(data.stepTitle),
    role: stringValue(data.role),
    studentNames: students.map((student) => stringValue(student.name)),
    subjects: [...new Set(students.map((student) => stringValue(student.subject)).filter(Boolean))],
    email: stringValue(contact.email),
    phone: stringValue(contact.phoneNumber),
    whatsApp: stringValue(contact.whatsAppNumber),
    parentName: stringValue(contact.parentName),
    city: stringValue(contact.city),
    timeZone: stringValue(data.timeZone),
  };
}

function timeAgo(date: Date) {
  const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hr${hours > 1 ? "s" : ""} ago`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days} day${days > 1 ? "s" : ""} ago`;
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(date);
}

/**
 * Which of these students already have classes on the calendar.
 *
 * A teaching_shift records the students it is for but not the enrollment it
 * came from, so the join is the student's uid. One `array-contains-any` query
 * per 30 students answers the whole list; asking per card would be a query
 * per row.
 */
async function loadScheduledStudents(applicants: EnrollmentApplicant[]): Promise<Set<string>> {
  const uids = [...new Set(applicants.map((a) => a.studentUserId).filter(Boolean))];
  const scheduled = new Set<string>();
  if (uids.length === 0) return scheduled;

  for (let i = 0; i < uids.length; i += 30) {
    const chunk = uids.slice(i, i + 30);
    const snapshot = await getDocs(
      query(collection(db, "teaching_shifts"), where("student_ids", "array-contains-any", chunk)),
    );
    for (const shift of snapshot.docs) {
      for (const uid of stringArray(shift.data().student_ids)) {
        if (chunk.includes(uid)) scheduled.add(uid);
      }
    }
  }
  return scheduled;
}

function normalizeApplicant(id: string, data: Record<string, unknown>): EnrollmentApplicant {
  const metadata = recordValue(data.metadata);
  const contact = recordValue(data.contact);
  const student = recordValue(data.student);
  const program = recordValue(data.program);
  const preferences = recordValue(data.preferences);
  const country = recordValue(contact.country);
  const status = stringValue(metadata.status) as ApplicantStatus;
  const studentName = stringValue(student.name ?? data.studentName) || "Student";
  const age = stringValue(student.age ?? data.studentAge);
  const submittedAt = dateValue(metadata.submittedAt);
  return {
    id,
    status: enrollmentStatuses.includes(status) ? status : "pending",
    submittedAt,
    programTitle: stringValue(data.programTitle ?? data.subject) || "Unknown Subject",
    studentName,
    gradeLevel: stringValue(data.gradeLevel) || stringValue(program.level),
    age,
    isAdult: metadata.isAdult === true || Number.parseInt(age, 10) >= 18,
    days: stringArray(preferences.days),
    timeSlots: stringArray(preferences.timeSlots),
    timeZone: stringValue(preferences.timeZone),
    parentName: stringValue(contact.parentName ?? data.parentName),
    phone: stringValue(contact.phone ?? data.phoneNumber),
    city: stringValue(contact.city ?? data.city ?? country.name),
    // Written by submitEnrollment() but never shown until now — it was only
    // reachable through "Raw Application Data", and it usually holds the
    // constraint that decides the schedule.
    schedulingNotes: stringValue(preferences.schedulingNotes ?? data.schedulingNotes),
    teacherName: stringValue(metadata.matchedTeacherName),
    matchedAt: dateValue(metadata.matchedAt),
    studentUserId: stringValue(metadata.studentUserId),
    // Matches how the matched card itself decides this: an explicit invite
    // status, or a guardian already on the contact.
    parentLinked:
      stringValue(metadata.parentInviteStatus) === "linked" ||
      stringValue(contact.guardianId).length > 0,
    // Filled in by loadDiscounts() — it lives on the student's user record,
    // because it covers every program that student takes rather than one
    // application.
    discount: null,
    gender: stringValue(student.gender),
    email: stringValue(contact.email ?? data.email),
    whatsApp: stringValue(contact.whatsApp),
    country: stringValue(country.name ?? contact.country),
    classType: normalizeClassType(program.classType),
    sessionDuration: stringValue(program.sessionDuration),
    hoursPerWeek: numberOrNull(program.hoursPerWeek),
    sessionsPerWeek: numberOrNull(program.sessionsPerWeek),
    block: normalizeBlock(data.block ?? preferences.timeOfDayPreference) ?? "",
    preferredLanguage: stringValue(preferences.preferredLanguage),
    matchedTeacherId: stringValue(metadata.matchedTeacherId),
    teacherTimeZone: "",
  };
}

function numberOrNull(raw: unknown): number | null {
  const value = Number(raw);
  return Number.isFinite(value) && value > 0 ? value : null;
}

function readDiscount(raw: unknown): StudentDiscount | null {
  const data = recordValue(raw);
  const mode = stringValue(data.mode);
  const value = Number(data.value);
  if ((mode !== "percent" && mode !== "fixed") || !Number.isFinite(value) || value <= 0) return null;
  const duration = stringValue(data.duration) === "ongoing" ? "ongoing" : "months";
  const startDate = dateValue(data.startDate);
  if (!startDate) return null;
  const months = Number(data.months);
  return {
    mode,
    value,
    duration,
    ...(duration === "months" && Number.isFinite(months) && months > 0 ? { months } : {}),
    startDate,
    reason: stringValue(data.reason),
    ...(stringValue(data.note) ? { note: stringValue(data.note) } : {}),
  };
}

/** One read per student who has an account; applicants without one have none. */
async function loadDiscounts(applicants: EnrollmentApplicant[]): Promise<Map<string, StudentDiscount>> {
  const uids = [...new Set(applicants.map((a) => a.studentUserId).filter(Boolean))];
  const found = new Map<string, StudentDiscount>();
  const snapshots = await Promise.all(uids.map((uid) => getDoc(doc(db, "users", uid))));
  snapshots.forEach((snapshot, index) => {
    if (!snapshot.exists()) return;
    const discount = readDiscount((snapshot.data() as Record<string, unknown>).discount);
    if (discount) found.set(uids[index], discount);
  });
  return found;
}

function recordValue(value: unknown) {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function stringArray(value: unknown) {
  return Array.isArray(value) ? value.map((item) => stringValue(item)).filter(Boolean) : [];
}

function dateValue(value: unknown) {
  if (value instanceof Timestamp) return value.toDate();
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    return value.toDate() as Date;
  }
  return null;
}

function formatSubmittedAt(value: Date | null) {
  if (!value) return "";
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(value);
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Admin";
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}
