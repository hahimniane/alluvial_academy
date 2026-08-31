"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { addDoc, collection, doc, getDoc, getDocs, limit, query, serverTimestamp, setDoc, Timestamp, updateDoc, where } from "firebase/firestore";
import { deleteObject, getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  AlertCircle,
  BarChart3,
  Calendar,
  Check,
  ChevronLeft,
  ChevronRight,
  ClipboardList,
  Clock,
  FileText,
  History,
  Image as ImageIcon,
  Loader2,
  Lock,
  Menu,
  MessageSquare,
  PenLine,
  Search,
  Send,
  Shield,
  Shuffle,
  Trash2,
  Upload,
  X,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { auth, db, storage } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type Frequency = "perSession" | "weekly" | "monthly" | "onDemand";
type Category = "teaching" | "studentAssessment" | "feedback" | "administrative" | "other";
type UserRecord = Record<string, unknown>;
type FieldType =
  | "text"
  | "email"
  | "phone"
  | "long_text"
  | "multiline"
  | "description"
  | "dropdown"
  | "select"
  | "multi_select"
  | "radio"
  | "number"
  | "date"
  | "time"
  | "boolean"
  | "yes_no"
  | "yesNo"
  | "image_upload"
  | "imageUpload"
  | "signature";
type FileFieldKind = "image" | "signature";
type PendingFileValue = {
  kind: "pendingFile";
  fieldType: FileFieldKind;
  file: File;
  fileName: string;
  size: number;
  contentType: string;
  previewUrl: string;
};
type UploadedFileValue = {
  fileName: string;
  downloadURL: string;
  url: string;
  storagePath: string;
  size: number;
  contentType: string;
  type: FileFieldKind;
  uploadedAt: ReturnType<typeof serverTimestamp>;
};
type FormFieldValue = string | string[] | PendingFileValue | UploadedFileValue;
type SubmittedFieldValue = string | string[] | UploadedFileValue | Record<string, unknown>;

type TemplateField = {
  id: string;
  label: string;
  type: FieldType;
  placeholder: string;
  required: boolean;
  order: number;
  options: string[];
};

type ShiftOption = {
  id: string;
  title: string;
  status: string;
  start: Date;
  end: Date;
  subject: string;
  formResponseId: string;
  timesheetId: string;
};

type ExistingSubmission = {
  id: string;
  formTitle: string;
  submittedAt: Date | null;
  responses: Record<string, unknown>;
  fieldLabels: Record<string, string>;
};

type TimesheetDetail = {
  id: string;
  status: string;
  start: Date | null;
  end: Date | null;
  clockIn: Date | null;
  clockOut: Date | null;
  totalHours: number;
  reportedHours: number;
  payAmount: number;
  formCompleted: boolean;
  formResponseId: string;
};

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type FormTemplateRecord = {
  id: string;
  name: string;
  description: string;
  frequency: Frequency;
  category: Category;
  version: number;
  fieldsCount: number;
  fields: TemplateField[];
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

const defaultFields: Record<string, TemplateField[]> = {
  daily_class_report: [
    field("lesson_completed", "What lesson/topic did you cover today?", "text", 1, true, "e.g., Surah Al-Fatiha verses 1-3"),
    field("students_present", "How many students attended?", "number", 2, true, "Number of students present"),
    field("session_quality", "How did the session go?", "radio", 3, true, "", ["Excellent", "Good", "Average", "Challenging"]),
    field("issues", "Any issues or concerns?", "long_text", 4, false, "Leave empty if none"),
    field("next_plan", "Plan for next session", "text", 5, false, "What will you cover next?"),
  ],
  weekly_summary: [
    field("weekly_progress", "How would you rate this week overall?", "radio", 1, true, "", ["Excellent", "Good", "Needs Improvement"]),
    field("achievements", "What were the key achievements this week?", "long_text", 2, true, "Summarize student progress, milestones reached, etc."),
    field("challenges", "Any challenges or support needed?", "long_text", 3, false, "Leave empty if none"),
  ],
  monthly_review: [
    field("month_rating", "How would you rate this month?", "radio", 1, true, "", ["Excellent", "Good", "Average", "Challenging"]),
    field("goals_met", "Were your teaching goals met?", "radio", 2, true, "", ["Yes, all goals", "Most goals", "Some goals", "Few goals"]),
    field("comments", "Additional comments for admin", "long_text", 3, false, "Any feedback, requests, or concerns"),
  ],
  leadership_feedback: [
    field("leader_rating", "How would you rate your coach/leader overall?", "radio", 1, true, "", ["Excellent", "Good", "Average", "Needs Improvement", "Poor"]),
    field("communication", "How effective is their communication?", "radio", 2, true, "", ["Excellent", "Good", "Average", "Needs Improvement"]),
    field("support_quality", "How helpful is the support you receive?", "radio", 3, true, "", ["Very Helpful", "Somewhat Helpful", "Not Helpful", "N/A"]),
    field("suggestions", "Any suggestions for improvement?", "long_text", 4, false, "What could be done better?"),
  ],
  teacher_feedback: [
    field("feedback_type", "Type of Feedback", "radio", 1, true, "", ["Suggestion", "Complaint", "Appreciation", "Concern", "Other"]),
    field("priority", "Priority Level", "radio", 2, true, "", ["Low", "Medium", "High", "Urgent"]),
    field("subject", "Subject", "text", 3, true, "Brief subject of your feedback"),
    field("details", "Details", "long_text", 4, true, "Please provide details..."),
    field("anonymous", "Submit anonymously?", "radio", 5, false, "", ["Yes", "No"]),
  ],
  student_assessment: [
    field("student_name", "Student Name", "text", 1, true, "Enter student full name"),
    field("assessment_type", "Assessment Type", "radio", 2, true, "", ["Initial (New Student)", "Mid-Semester", "End of Semester"]),
    field("surahs_known", "How many Surahs does this student know?", "number", 3, true, "Number of Surahs"),
    field("reading_level", "Arabic Reading Level", "radio", 4, true, "", ["Not Started", "Beginner", "Intermediate", "Advanced", "Fluent"]),
    field("writing_level", "Arabic Writing Level", "radio", 5, true, "", ["Not Started", "Beginner", "Intermediate", "Advanced", "Fluent"]),
    field("overall_level", "Overall Student Level", "radio", 6, true, "", ["Beginner", "Intermediate", "Advanced"]),
    field("hadiths_known", "How many Hadiths does this student know?", "number", 7, false, "Number of Hadiths"),
    field("reading_rating", "Rate reading skills (1-5)", "radio", 8, true, "", ["1 - Very Poor", "2 - Poor", "3 - Average", "4 - Good", "5 - Excellent"]),
    field("writing_rating", "Rate writing skills (1-5)", "radio", 9, true, "", ["1 - Very Poor", "2 - Poor", "3 - Average", "4 - Good", "5 - Excellent"]),
    field("additional_notes", "Additional Notes", "long_text", 10, false, "Any additional observations about the student..."),
  ],
  leave_request: [
    field("leave_type", "Type of Leave", "radio", 1, true, "", ["Sick Leave", "Personal Emergency", "Family Emergency", "Religious Holiday", "Pre-planned Absence", "Other"]),
    field("start_date", "Start Date", "date", 2, true),
    field("end_date", "End Date", "date", 3, true),
    field("affected_shifts", "Number of shifts affected", "number", 4, true, "How many classes will be missed?"),
    field("reason", "Reason for Leave", "long_text", 5, true, "Please explain the reason for your request..."),
  ],
  incident_report: [
    field("incident_date", "Date of Incident", "date", 1, true),
    field("incident_type", "Type of Incident", "radio", 2, true, "", ["Technical Issue", "Student Behavior", "Parent Concern", "Scheduling Conflict", "Other"]),
    field("description", "Describe what happened", "long_text", 3, true, "Please provide a detailed description..."),
    field("people_involved", "Who was involved?", "text", 4, false, "Names of people involved"),
    field("action_taken", "What action did you take?", "long_text", 5, false, "Describe any immediate action taken..."),
    field("followup_needed", "Is follow-up needed?", "radio", 6, true, "", ["Yes - Urgent", "Yes - Non-urgent", "No"]),
  ],
};

const defaultTemplates: FormTemplateRecord[] = [
  {
    id: "daily_class_report",
    name: "Daily Class Report",
    description: "Quick report after each teaching session",
    frequency: "perSession",
    category: "teaching",
    version: 1,
    fieldsCount: 5,
    fields: defaultFields.daily_class_report,
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
    fields: defaultFields.weekly_summary,
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
    fields: defaultFields.monthly_review,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher"],
  },
  {
    id: "leadership_feedback",
    name: "Feedback for Leaders",
    description: "Rate and provide feedback about your coach/supervisor",
    frequency: "onDemand",
    category: "feedback",
    version: 1,
    fieldsCount: 4,
    fields: defaultFields.leadership_feedback,
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
    fields: defaultFields.teacher_feedback,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher", "coach"],
  },
  {
    id: "student_assessment",
    name: "Student Assessment",
    description: "Evaluate student progress and skills at enrollment or semester end",
    frequency: "onDemand",
    category: "studentAssessment",
    version: 1,
    fieldsCount: 10,
    fields: defaultFields.student_assessment,
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
    fields: defaultFields.leave_request,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher", "coach"],
  },
  {
    id: "incident_report",
    name: "Incident Report",
    description: "Report an incident or issue that occurred",
    frequency: "onDemand",
    category: "administrative",
    version: 1,
    fieldsCount: 6,
    fields: defaultFields.incident_report,
    isActive: true,
    updatedAt: null,
    allowedRoles: ["teacher", "coach", "admin"],
  },
];

export function TeacherSubmitFormPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [templates, setTemplates] = useState<FormTemplateRecord[]>([]);
  const [submitted, setSubmitted] = useState<SubmittedStatus>({ daily: false, weekly: false, monthly: false });
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [message, setMessage] = useState("");
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [activeTemplate, setActiveTemplate] = useState<FormTemplateRecord | null>(null);
  const [shiftTemplate, setShiftTemplate] = useState<FormTemplateRecord | null>(null);
  const [selectedShift, setSelectedShift] = useState<ShiftOption | null>(null);
  const [existingSubmission, setExistingSubmission] = useState<ExistingSubmission | null>(null);
  const openedShiftDeepLink = useRef("");

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setMessage("");
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
        const [loadedTemplates, loadedSubmitted] = await Promise.all([loadTemplates(), loadSubmittedStatus(nextUser.uid)]);
        if (!mounted) return;
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
    const baseTemplates = templates.length > 0 ? templates : defaultTemplates;
    baseTemplates
      .filter((template) => template.isActive)
      .filter((template) => canRoleSeeTemplate(template, "teacher"))
      .forEach((template) => {
        const candidate = { ...template, category: displayCategoryFor(template) };
        const key = candidate.name.trim().toLowerCase().replace(/\s+/g, " ");
        const existing = byName.get(key);
        if (!existing || shouldPreferTemplate(candidate, existing)) byName.set(key, candidate);
      });

    const deduped = Array.from(byName.values());
    if (!deduped.some((template) => template.category === "teaching")) {
      defaultTemplates.filter((template) => template.category === "teaching").forEach((template) => byName.set(template.id, template));
    }
    if (!deduped.some((template) => template.category === "feedback")) {
      defaultTemplates.filter((template) => template.category === "feedback").forEach((template) => byName.set(template.id, template));
    }
    if (!deduped.some((template) => template.category === "studentAssessment")) {
      defaultTemplates.filter((template) => template.category === "studentAssessment").forEach((template) => byName.set(template.id, template));
    }
    if (!deduped.some((template) => template.category === "administrative")) {
      defaultTemplates.filter((template) => template.category === "administrative").forEach((template) => byName.set(template.id, template));
    }

    const term = search.trim().toLowerCase();
    return Array.from(byName.values()).filter((template) => {
      if (!term) return true;
      const category = categoryConfigs.find((item) => item.id === template.category)?.label ?? "";
      return [template.name, template.description, category, frequencyLabel(template.frequency)].some((value) => value.toLowerCase().includes(term));
    });
  }, [search, templates]);

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

  useEffect(() => {
    if (!currentUser || loading || typeof window === "undefined") return;
    const requestedShiftId = new URLSearchParams(window.location.search).get("shift")?.trim() ?? "";
    if (!requestedShiftId || openedShiftDeepLink.current === requestedShiftId) return;
    const perSessionTemplate = visibleTemplates.find((template) => template.frequency === "perSession" && template.isActive);
    if (!perSessionTemplate) return;
    openedShiftDeepLink.current = requestedShiftId;
    void loadRecentTeacherShifts(currentUser.uid).then(async (shifts) => {
      const shift = shifts.find((item) => item.id === requestedShiftId);
      if (!shift) { setMessage("This class is not currently available for a readiness form."); return; }
      if (shift.formResponseId) {
        const existing = await loadExistingSubmission(shift.formResponseId);
        if (existing) { setExistingSubmission(existing); return; }
      }
      setSelectedShift(shift);
      setActiveTemplate(perSessionTemplate);
    }).catch(() => setMessage("Could not open the selected class. Please choose it from the form list."));
  }, [currentUser, loading, visibleTemplates]);

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  const openTemplate = (template: FormTemplateRecord) => {
    setMessage("");
    setExistingSubmission(null);
    if (template.frequency === "perSession") {
      setShiftTemplate(template);
      return;
    }
    setSelectedShift(null);
    setActiveTemplate(template);
  };

  const openShiftTemplate = async (shift: ShiftOption) => {
    if (!shiftTemplate) return;
    if (shift.formResponseId) {
      setMessage("");
      const submission = await loadExistingSubmission(shift.formResponseId);
      if (submission) {
        setExistingSubmission(submission);
        setShiftTemplate(null);
      } else {
        setMessage("Could not load the submitted form.");
      }
      return;
    }
    setSelectedShift(shift);
    setActiveTemplate(shiftTemplate);
    setShiftTemplate(null);
  };

  const handleSubmitted = async () => {
    if (!currentUser) return;
    setSubmitted(await loadSubmittedStatus(currentUser.uid));
  };

  return (
    <TeacherShell activeLabel="Submit Form" breadcrumb="Forms / Submit Form" summary={summary}>
      <main className="min-h-screen bg-[#F1F5F9] text-[#1E293B] lg:min-h-[calc(100vh-56px)]">
        <MobileTeacherTopBar summary={summary} />
        <section className="relative overflow-hidden bg-gradient-to-br from-[#6366F1] to-[#8B5CF6] px-5 pb-7 pt-5 text-white lg:min-h-[200px]">
          <div className="flex items-center justify-between">
            <Link href="/teacher/" aria-label="Back to teacher dashboard" className="grid h-11 w-11 place-items-center rounded-xl text-2xl leading-none hover:bg-white/10"><ChevronLeft size={26} /></Link>
            <Link href="/teacher/form-submissions/" aria-label="My submissions" className="grid h-10 w-10 place-items-center rounded-full text-white hover:bg-white/10">
              <History size={22} />
            </Link>
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
                <CategorySection key={group.category.id} category={group.category} templates={group.items} submitted={submitted} onOpen={openTemplate} />
              ))}
            </div>
          )}
        </section>
        {activeTemplate && currentUser ? (
          <TeacherFormSheet
            template={activeTemplate}
            user={currentUser}
            summary={summary}
            selectedShift={selectedShift}
            onClose={() => {
              setActiveTemplate(null);
              setSelectedShift(null);
            }}
            onSubmitted={handleSubmitted}
          />
        ) : null}
        {shiftTemplate && currentUser ? (
          <ShiftSelectionSheet template={shiftTemplate} user={currentUser} onClose={() => setShiftTemplate(null)} onSelect={openShiftTemplate} />
        ) : null}
        {existingSubmission ? <ExistingSubmissionSheet submission={existingSubmission} onClose={() => setExistingSubmission(null)} /> : null}
      </main>
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-14 grid-cols-[56px_1fr_96px] items-center bg-white px-4 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={24} />
      </button>
      <div className="min-w-0 text-center text-base font-bold text-[#111827]">Alluwal Education Hub</div>
      <div className="flex items-center justify-end gap-3">
        <button type="button" aria-label="Open teacher account options" onClick={openTeacherMobileMenu} className="grid h-10 w-10 place-items-center rounded-xl text-[#111827]"><Shuffle size={20} /></button>
        <span className="grid h-9 w-9 place-items-center rounded-full bg-[#009688] text-xs font-black text-white">{summary.initials}</span>
      </div>
    </header>
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

function CategorySection({ category, templates, submitted, onOpen }: { category: CategoryConfig; templates: FormTemplateRecord[]; submitted: SubmittedStatus; onOpen: (template: FormTemplateRecord) => void }) {
  return (
    <section className="mt-4">
      <div className="mb-3 flex items-center gap-2">
        <h2 className="shrink-0 text-xs font-black uppercase tracking-[0.1em] text-[#7890A0]">{category.label}</h2>
        <div className="h-px flex-1 bg-[#D5DDE5]" />
      </div>
      <div className="grid gap-4">
        {templates.map((template) => (
          <FormCard key={template.id} template={template} color={category.color} icon={category.icon} submitted={submitted} onOpen={onOpen} />
        ))}
      </div>
    </section>
  );
}

function FormCard({ template, color, icon: Icon, submitted, onOpen }: { template: FormTemplateRecord; color: string; icon: LucideIcon; submitted: SubmittedStatus; onOpen: (template: FormTemplateRecord) => void }) {
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
      onClick={() => onOpen(template)}
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

function TeacherFormSheet({
  template,
  user,
  summary,
  selectedShift,
  onClose,
  onSubmitted,
}: {
  template: FormTemplateRecord;
  user: User;
  summary: TeacherSummary;
  selectedShift: ShiftOption | null;
  onClose: () => void;
  onSubmitted: () => Promise<void>;
}) {
  const fields = template.fields.length > 0 ? template.fields : defaultFields[template.id] ?? [];
  const [values, setValues] = useState<Record<string, FormFieldValue>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState("");
  const previewUrlsRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    return () => {
      previewUrlsRef.current.forEach((previewUrl) => URL.revokeObjectURL(previewUrl));
      previewUrlsRef.current.clear();
    };
  }, []);

  const setValue = (fieldId: string, value: FormFieldValue) => {
    setValues((current) => {
      const previous = current[fieldId];
      if (isPendingFileValue(previous) && previous.previewUrl !== (isPendingFileValue(value) ? value.previewUrl : "")) {
        URL.revokeObjectURL(previous.previewUrl);
        previewUrlsRef.current.delete(previous.previewUrl);
      }
      if (isPendingFileValue(value)) previewUrlsRef.current.add(value.previewUrl);
      return { ...current, [fieldId]: value };
    });
    setErrors((current) => {
      if (!current[fieldId]) return current;
      const next = { ...current };
      delete next[fieldId];
      return next;
    });
  };

  const submit = async () => {
    const nextErrors: Record<string, string> = {};
    fields.forEach((item) => {
      const value = values[item.id];
      const empty = isEmptyFormValue(value);
      if (item.required && empty) nextErrors[item.id] = "This question is required";
      if (!empty && item.type === "email" && typeof value === "string" && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value.trim())) {
        nextErrors[item.id] = "Please enter a valid email address";
      }
      if (!empty && item.type === "phone" && typeof value === "string" && !/^\+?[\d\s-]+$/.test(value.trim())) {
        nextErrors[item.id] = "Please enter a valid phone number";
      }
    });
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    setNotice("");
    let uploadedPaths: string[] = [];
    try {
      if (!navigator.onLine) throw new Error("You appear to be offline. Reconnect and try again.");
      const uploadResult = await uploadPendingFiles(values, user.uid);
      const uploadedValues = uploadResult.values;
      uploadedPaths = uploadResult.storagePaths;
      const responses = fields.reduce<Record<string, SubmittedFieldValue>>((acc, item) => {
        acc[item.id] = uploadedValues[item.id] ?? "";
        return acc;
      }, {});
      const formType = submissionFormType(template.frequency);
      const now = new Date();
      const submissionData = {
        formId: template.id,
        formName: template.name,
        formTitle: template.name,
        formType,
        frequency: template.frequency,
        templateId: template.id,
        userId: user.uid,
        submittedBy: user.uid,
        teacherId: user.uid,
        teacher_id: user.uid,
        userEmail: user.email ?? "",
        firstName: summary.firstName,
        lastName: "",
        userFirstName: summary.firstName,
        userLastName: "",
        responses,
        submittedAt: serverTimestamp(),
        status: "completed",
        lastUpdated: serverTimestamp(),
        yearMonth: yearMonthFor(selectedShift?.start ?? now),
        reportingContext: selectedShift ? { shiftId: selectedShift.id } : {},
        ...(selectedShift ? { shiftId: selectedShift.id, shift_id: selectedShift.id } : {}),
        ...(selectedShift?.timesheetId ? { timesheetId: selectedShift.timesheetId } : {}),
      };

      const responseRef = selectedShift
        ? doc(db, "form_responses", perSessionResponseId(template.id, selectedShift.id, user.uid))
        : await addDoc(collection(db, "form_responses"), submissionData);
      if (selectedShift) {
        try {
          await setDoc(responseRef, submissionData);
        } catch (error) {
          const existing = await getDoc(responseRef).catch(() => null);
          const existingData = existing?.exists() ? (existing.data() as Record<string, unknown>) : null;
          if (existingData && stringValue(existingData.userId) === user.uid && stringValue(existingData.shiftId ?? existingData.shift_id) === selectedShift.id) {
            throw new Error("This form has already been submitted for the selected shift.");
          }
          throw error;
        }
      }
      if (selectedShift) {
        await linkFormResponseToShiftAndTimesheet(selectedShift, responseRef.id).catch(() => null);
      }
      setNotice("Form submitted successfully");
      await onSubmitted();
      window.setTimeout(onClose, 900);
    } catch (error) {
      if (uploadedPaths.length) await cleanupUploadedFiles(uploadedPaths);
      setNotice(formActionError(error, "Could not submit this form."));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-[#0F172A]/45 px-4 py-5">
      <div className="mx-auto max-w-[800px]">
        <div className="mb-4 flex justify-end">
          <button type="button" onClick={onClose} aria-label="Close form" className="grid h-10 w-10 place-items-center rounded-full bg-white text-[#334155] shadow-sm">
            <X size={20} />
          </button>
        </div>
        <section className="rounded-2xl bg-white p-8 shadow-[0_4px_10px_rgba(15,23,42,0.08)] max-[700px]:p-5">
          <div className="flex gap-4">
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-[#0386FF]/10 text-[#0386FF]">
              <FileText size={24} />
            </span>
            <div className="min-w-0">
              <h2 className="text-[28px] font-bold leading-tight text-[#111827] max-[700px]:text-2xl">{template.name}</h2>
              {template.description ? <p className="mt-2 text-base leading-6 text-[#6B7280]">{template.description}</p> : null}
              {selectedShift ? (
                <p className="mt-3 rounded-xl bg-[#EFF6FF] px-3 py-2 text-sm font-semibold text-[#2563EB]">
                  {selectedShift.title} • {formatShortDate(selectedShift.start)} • {formatTime(selectedShift.start)} - {formatTime(selectedShift.end)}
                </p>
              ) : null}
            </div>
          </div>
        </section>

        <div className="mt-6">
          {fields.length === 0 ? (
            <div className="rounded-lg border border-[#F59E0B] bg-[#FEF3C7] p-4 text-sm font-semibold text-[#B45309]">No form fields are currently visible.</div>
          ) : (
            fields.map((item) => (
              <FormQuestionCard key={item.id} field={item} value={values[item.id]} error={errors[item.id]} onChange={(value) => setValue(item.id, value)} />
            ))
          )}
        </div>

        <section className="mb-8 mt-2 rounded-2xl bg-white p-6 shadow-[0_4px_10px_rgba(15,23,42,0.08)] max-[700px]:p-4">
          {notice ? <p className={`mb-4 rounded-xl px-4 py-3 text-sm font-semibold ${notice.includes("success") ? "bg-green-50 text-green-700" : "bg-red-50 text-red-700"}`}>{notice}</p> : null}
          <div className="flex flex-wrap justify-end gap-3 max-[700px]:grid max-[700px]:grid-cols-1">
            <button type="button" onClick={onClose} className="rounded-xl border border-[#E5E7EB] px-5 py-3 text-sm font-bold text-[#6B7280] hover:bg-[#F8FAFC]">
              Cancel
            </button>
            <button
              type="button"
              onClick={submit}
              disabled={submitting || fields.length === 0}
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-[#0386FF] px-6 py-3 text-sm font-bold text-white shadow-sm disabled:cursor-not-allowed disabled:bg-[#93C5FD]"
            >
              {submitting ? <Loader2 size={18} className="animate-spin" /> : <Send size={18} />}
              {submitting ? "Submitting..." : "Submit Form"}
            </button>
          </div>
        </section>
      </div>
    </div>
  );
}

function FormQuestionCard({ field, value, error, onChange }: { field: TemplateField; value: FormFieldValue | undefined; error?: string; onChange: (value: FormFieldValue) => void }) {
  return (
    <section className="mb-4 rounded-lg bg-white p-6 shadow-[0_1px_2px_rgba(15,23,42,0.06)] focus-within:border-l-4 focus-within:border-[#0386FF] max-[700px]:p-5">
      <label className="block text-base font-medium text-black/85">
        {field.label}
        {field.required ? <span className="ml-1 text-red-600">*</span> : null}
      </label>
      <div className="mt-4">{renderFieldInput(field, value, onChange)}</div>
      {error ? (
        <p className="mt-3 inline-flex items-center gap-1 text-xs font-semibold text-red-600">
          <AlertCircle size={14} />
          {error}
        </p>
      ) : null}
    </section>
  );
}

function renderFieldInput(field: TemplateField, value: FormFieldValue | undefined, onChange: (value: FormFieldValue) => void) {
  const current = Array.isArray(value) ? value.join(", ") : typeof value === "string" ? value : "";
  const inputClasses = "w-full rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] px-4 py-3 text-sm text-[#111827] outline-none placeholder:text-[#9CA3AF] focus:border-[#0386FF]";
  if (field.type === "long_text" || field.type === "multiline" || field.type === "description") {
    return <textarea aria-label={field.label} value={current} onChange={(event) => onChange(event.target.value)} placeholder={field.placeholder || "Your answer"} rows={4} className={`${inputClasses} min-h-[120px] resize-y leading-6`} />;
  }
  if (field.type === "dropdown" || field.type === "select") {
    return (
      <select aria-label={field.label} value={current} onChange={(event) => onChange(event.target.value)} className={inputClasses}>
        <option value="">{field.placeholder || "Select an option"}</option>
        {field.options.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    );
  }
  if (field.type === "radio" && field.options.length > 0) {
    return (
      <div className="max-h-[220px] overflow-y-auto rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-3">
        {field.options.map((option) => (
          <label key={option} className="flex cursor-pointer items-center gap-3 rounded-lg px-2 py-2 text-sm text-[#111827] hover:bg-white">
            <input aria-label={`${field.label}: ${option}`} type="radio" name={field.id} value={option} checked={current === option} onChange={() => onChange(option)} className="h-4 w-4 accent-[#0386FF]" />
            <span>{option}</span>
          </label>
        ))}
      </div>
    );
  }
  if (field.type === "multi_select") {
    const selected = Array.isArray(value) ? value : [];
    return (
      <div className="rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-3">
        {field.options.map((option) => (
          <label key={option} className="flex cursor-pointer items-center gap-3 rounded-lg px-2 py-2 text-sm text-[#111827] hover:bg-white">
            <input
              type="checkbox"
              aria-label={`${field.label}: ${option}`}
              checked={selected.includes(option)}
              onChange={(event) => onChange(event.target.checked ? [...selected, option] : selected.filter((item) => item !== option))}
              className="h-4 w-4 rounded accent-[#0386FF]"
            />
            <span>{option}</span>
          </label>
        ))}
      </div>
    );
  }
  if (field.type === "radio" || field.type === "boolean" || field.type === "yes_no" || field.type === "yesNo") {
    return (
      <div className="flex gap-6 rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-4">
        {["Yes", "No"].map((option) => (
          <label key={option} className="flex cursor-pointer items-center gap-2 text-sm text-[#111827]">
            <input aria-label={`${field.label}: ${option}`} type="radio" name={field.id} value={option} checked={current === option} onChange={() => onChange(option)} className="h-4 w-4 accent-[#0386FF]" />
            {option}
          </label>
        ))}
      </div>
    );
  }
  if (field.type === "image_upload" || field.type === "imageUpload" || field.type === "signature") {
    return <FileFieldInput field={field} value={value} onChange={onChange} />;
  }
  return <input aria-label={field.label} value={current} type={htmlInputType(field.type)} onChange={(event) => onChange(event.target.value)} placeholder={field.placeholder || "Your answer"} className={inputClasses} />;
}

function FileFieldInput({ field, value, onChange }: { field: TemplateField; value: FormFieldValue | undefined; onChange: (value: FormFieldValue) => void }) {
  const kind: FileFieldKind = field.type === "signature" ? "signature" : "image";
  const [fileError, setFileError] = useState("");
  const pending = isPendingFileValue(value) ? value : null;
  const uploaded = isUploadedFileValue(value) ? value : null;
  const selectedFileName = pending?.fileName ?? uploaded?.fileName ?? "";
  const selectedSize = pending?.size ?? uploaded?.size ?? 0;
  const maxBytes = kind === "signature" ? 5 * 1024 * 1024 : 10 * 1024 * 1024;
  const Icon = kind === "signature" ? PenLine : ImageIcon;

  const onFileSelected = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    if (file.size > maxBytes) {
      setFileError(kind === "signature" ? "Signature file size must be less than 5MB." : "File size must be less than 10MB.");
      return;
    }
    if (!file.type.startsWith("image/")) {
      setFileError("Please choose an image file.");
      return;
    }
    setFileError("");
    onChange({
      kind: "pendingFile",
      fieldType: kind,
      file,
      fileName: file.name,
      size: file.size,
      contentType: file.type || contentTypeForFileName(file.name),
      previewUrl: URL.createObjectURL(file),
    });
  };

  if (pending || uploaded) {
    return (
      <div className="space-y-3">
        <div className={`relative grid ${kind === "signature" ? "h-[120px]" : "min-h-[180px]"} place-items-center overflow-hidden rounded-xl border-2 border-[#0386FF] bg-white`}>
          {pending ? <img src={pending.previewUrl} alt="" className="h-full w-full object-contain" /> : <Icon size={36} className="text-[#0386FF]" />}
          <button
            type="button"
            onClick={() => {
              setFileError("");
              onChange("");
            }}
            aria-label={`Remove ${field.label}`}
            className="absolute right-2 top-2 grid h-8 w-8 place-items-center rounded-full bg-[#EF4444] text-white shadow-sm"
          >
            <Trash2 size={16} />
          </button>
        </div>
        <div className="flex items-center gap-3 rounded-lg border border-green-200 bg-green-50 p-3">
          <Check size={20} className="shrink-0 text-green-600" />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-[#111827]">{kind === "signature" ? "Signature captured" : selectedFileName}</p>
            <p className="text-xs text-[#6B7280]">{formatFileSize(selectedSize)}</p>
          </div>
          <label className="cursor-pointer rounded-lg px-3 py-2 text-xs font-bold text-[#0386FF] hover:bg-white">
            Change
            <input type="file" accept="image/*" onChange={onFileSelected} className="sr-only" aria-label={`Change ${field.label}`} />
          </label>
        </div>
        {fileError ? <p className="rounded-lg bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#DC2626]">{fileError}</p> : null}
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <label className={`grid w-full cursor-pointer place-items-center rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-6 text-center ${kind === "signature" ? "min-h-[120px]" : "min-h-[180px]"}`}>
        <span className={`grid rounded-full ${kind === "signature" ? "bg-[#9B51E0]/10 p-3 text-[#9B51E0]" : "bg-[#0386FF]/10 p-4 text-[#0386FF]"}`}>
          {kind === "signature" ? <PenLine size={24} /> : <Upload size={32} />}
        </span>
        <span className="mt-3 block text-sm font-bold text-[#111827]">{kind === "signature" ? "Click to add signature" : "Click to upload image"}</span>
        <span className="mt-1 block text-xs text-[#6B7280]">{kind === "signature" ? "Upload image or use signature pad" : "JPG, PNG, GIF up to 10MB"}</span>
        <input type="file" accept="image/*" onChange={onFileSelected} className="sr-only" aria-label={field.label} />
      </label>
      {fileError ? <p className="rounded-lg bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#DC2626]">{fileError}</p> : null}
    </div>
  );
}

function htmlInputType(type: FieldType) {
  if (type === "number") return "number";
  if (type === "date") return "date";
  if (type === "time") return "time";
  if (type === "email") return "email";
  if (type === "phone") return "tel";
  return "text";
}

function isPendingFileValue(value: unknown): value is PendingFileValue {
  return Boolean(value && typeof value === "object" && (value as PendingFileValue).kind === "pendingFile" && (value as PendingFileValue).file instanceof File);
}

function isUploadedFileValue(value: unknown): value is UploadedFileValue {
  return Boolean(value && typeof value === "object" && stringValue((value as Record<string, unknown>).downloadURL) && stringValue((value as Record<string, unknown>).fileName));
}

function isEmptyFormValue(value: FormFieldValue | undefined) {
  if (Array.isArray(value)) return value.length === 0;
  if (isPendingFileValue(value) || isUploadedFileValue(value)) return false;
  return !String(value ?? "").trim();
}

async function uploadPendingFiles(values: Record<string, FormFieldValue>, uid: string) {
  const uploaded: Record<string, SubmittedFieldValue> = {};
  const storagePaths: string[] = [];
  try {
    for (const [fieldId, value] of Object.entries(values)) {
      if (!isPendingFileValue(value)) {
        uploaded[fieldId] = value as SubmittedFieldValue;
        continue;
      }
      const safeName = safeStorageFileName(value.fileName);
      const storagePath = `form_images/${uid}/${Date.now()}_${safeName}`;
      const storageRef = ref(storage, storagePath);
      const snapshot = await uploadBytes(storageRef, value.file, {
        contentType: value.contentType || contentTypeForFileName(value.fileName),
        customMetadata: {
          uploadedBy: uid,
          originalFileName: value.fileName,
        },
      });
      storagePaths.push(storagePath);
      const downloadURL = await getDownloadURL(snapshot.ref);
      uploaded[fieldId] = {
        fileName: value.fileName,
        downloadURL,
        url: downloadURL,
        storagePath,
        size: value.size,
        contentType: value.contentType || contentTypeForFileName(value.fileName),
        type: value.fieldType,
        uploadedAt: serverTimestamp(),
      };
    }
    return { values: uploaded, storagePaths };
  } catch (error) {
    await cleanupUploadedFiles(storagePaths);
    throw error;
  }
}

async function cleanupUploadedFiles(storagePaths: string[]) {
  await Promise.allSettled(storagePaths.map((storagePath) => deleteObject(ref(storage, storagePath))));
}

function perSessionResponseId(templateId: string, shiftId: string, uid: string) {
  return [templateId, shiftId, uid].map((value) => value.replace(/[^a-zA-Z0-9_-]+/g, "_")).join("__").slice(0, 1400);
}

function formActionError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String(error || "");
  if (/permission-denied|insufficient permissions/i.test(message)) return "You do not have permission to submit this form. Contact an administrator if this continues.";
  if (/unavailable|network|offline/i.test(message) || !navigator.onLine) return "You appear to be offline. Reconnect and try again.";
  return message.replace(/^Firebase:\s*/i, "").trim() || fallback;
}

function safeStorageFileName(fileName: string) {
  const trimmed = fileName.trim() || "upload.jpg";
  return trimmed.replace(/[^a-zA-Z0-9._-]+/g, "_").slice(0, 120);
}

function contentTypeForFileName(fileName: string) {
  const extension = fileName.toLowerCase().split(".").pop();
  if (extension === "png") return "image/png";
  if (extension === "gif") return "image/gif";
  if (extension === "webp") return "image/webp";
  return "image/jpeg";
}

function formatFileSize(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function ShiftSelectionSheet({ template, user, onClose, onSelect }: { template: FormTemplateRecord; user: User; onClose: () => void; onSelect: (shift: ShiftOption) => void | Promise<void> }) {
  const [loading, setLoading] = useState(true);
  const [shifts, setShifts] = useState<ShiftOption[]>([]);
  const [error, setError] = useState("");
  const [timesheetLoadingId, setTimesheetLoadingId] = useState("");
  const [timesheetNotice, setTimesheetNotice] = useState("");
  const [activeTimesheet, setActiveTimesheet] = useState<TimesheetDetail | null>(null);
  const [activeShiftDetail, setActiveShiftDetail] = useState<ShiftOption | null>(null);

  useEffect(() => {
    let mounted = true;
    loadRecentTeacherShifts(user.uid)
      .then((items) => {
        if (mounted) setShifts(items);
      })
      .catch((nextError) => {
        if (mounted) setError(nextError instanceof Error ? nextError.message : "Could not load shifts.");
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, [user.uid]);

  const openTimesheet = async (shift: ShiftOption) => {
    setTimesheetNotice("");
    setTimesheetLoadingId(shift.id);
    try {
      const timesheet = await loadTimesheetForShift(user.uid, shift);
      if (!timesheet) {
        setTimesheetNotice("No timesheet was found for this shift yet.");
        return;
      }
      setActiveTimesheet(timesheet);
    } catch (nextError) {
      setTimesheetNotice(nextError instanceof Error ? nextError.message : "Could not load this timesheet.");
    } finally {
      setTimesheetLoadingId("");
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end bg-[#0F172A]/45">
      <section className="max-h-[86vh] w-full overflow-y-auto rounded-t-3xl bg-white p-6 shadow-[0_-12px_32px_rgba(15,23,42,0.18)]">
        <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-[#D1D5DB]" />
        <div className="mx-auto max-w-[760px]">
          <div className="flex items-start justify-between gap-3">
            <div>
              <h2 className="text-xl font-bold text-[#111827]">Select a Shift</h2>
              <p className="mt-1 text-sm text-[#64748B]">{template.name}</p>
            </div>
            <button type="button" onClick={onClose} aria-label="Close shift selection" className="grid h-9 w-9 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]">
              <X size={19} />
            </button>
          </div>
          {loading ? (
            <div className="grid min-h-[240px] place-items-center">
              <Loader2 className="animate-spin text-[#0386FF]" size={30} />
            </div>
          ) : error ? (
            <p className="mt-5 rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">{error}</p>
          ) : shifts.length === 0 ? (
            <p className="mt-5 rounded-xl bg-[#F8FAFC] px-4 py-4 text-sm font-semibold text-[#64748B]">No recent shifts found to report.</p>
          ) : (
            <div className="mt-5 grid gap-3">
              {timesheetNotice ? <p className="rounded-xl bg-[#F8FAFC] px-4 py-3 text-sm font-semibold text-[#64748B]">{timesheetNotice}</p> : null}
              {shifts.map((shift) => (
                <article key={shift.id} className="rounded-xl border border-[#E5E7EB] p-4">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <h3 className="font-semibold text-[#111827]">{shift.title}</h3>
                      <p className="mt-1 text-sm text-[#64748B]">
                        {formatShortDate(shift.start)} • {formatTime(shift.start)} - {formatTime(shift.end)}
                      </p>
                    </div>
                    <span className={`rounded-full border px-2 py-1 text-[10px] font-bold uppercase ${shiftStatusClass(shift.status)}`}>{shift.status}</span>
                  </div>
                  {shift.formResponseId ? (
                    <p className="mt-3 rounded-lg bg-green-50 px-3 py-2 text-xs font-semibold text-green-700">Form already submitted</p>
                  ) : null}
                  <div className="mt-4 flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() => onSelect(shift)}
                      className={`rounded-lg border px-4 py-2 text-xs font-semibold ${
                        shift.formResponseId ? "border-green-300 text-green-700 hover:bg-green-50" : "border-blue-300 text-blue-600 hover:bg-blue-50"
                      }`}
                    >
                      {shift.formResponseId ? "View Form" : "Form"}
                    </button>
                    <button
                      type="button"
                      onClick={() => openTimesheet(shift)}
                      disabled={timesheetLoadingId === shift.id}
                      className="inline-flex items-center gap-2 rounded-lg border border-[#E5E7EB] px-4 py-2 text-xs font-semibold text-[#475569] hover:bg-[#F8FAFC] disabled:cursor-wait disabled:opacity-70"
                    >
                      {timesheetLoadingId === shift.id ? <Loader2 size={14} className="animate-spin" /> : null}
                      {timesheetLoadingId === shift.id ? "Loading..." : "Timesheet"}
                    </button>
                    <button
                      type="button"
                      onClick={() => setActiveShiftDetail(shift)}
                      className="rounded-lg border border-orange-300 px-4 py-2 text-xs font-semibold text-orange-600 hover:bg-orange-50"
                    >
                      Details
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>
      </section>
      {activeTimesheet ? <TimesheetDetailSheet timesheet={activeTimesheet} onClose={() => setActiveTimesheet(null)} /> : null}
      {activeShiftDetail ? <ShiftDetailSheet shift={activeShiftDetail} onClose={() => setActiveShiftDetail(null)} /> : null}
    </div>
  );
}

function ShiftDetailSheet({ shift, onClose }: { shift: ShiftOption; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-[60] overflow-y-auto bg-[#0F172A]/55 px-4 py-5">
      <div className="mx-auto max-w-[680px]">
        <div className="mb-4 flex justify-end">
          <button type="button" onClick={onClose} aria-label="Close shift details" className="grid h-10 w-10 place-items-center rounded-full bg-white text-[#334155] shadow-sm">
            <X size={20} />
          </button>
        </div>
        <section className="rounded-2xl bg-white p-6 shadow-[0_4px_10px_rgba(15,23,42,0.08)]">
          <div className="flex items-start gap-4">
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-orange-50 text-orange-600">
              <AlertCircle size={24} />
            </span>
            <div>
              <h2 className="text-2xl font-bold text-[#111827]">Shift Details</h2>
              <p className="mt-1 text-sm font-semibold text-[#64748B]">{shift.title}</p>
            </div>
          </div>
          <div className="mt-6 grid gap-3 sm:grid-cols-2">
            <TimesheetValue label="Status" value={humanizeFieldId(shift.status)} />
            <TimesheetValue label="Subject" value={shift.subject || "Unknown Subject"} />
            <TimesheetValue label="Schedule" value={formatDateRange(shift.start, shift.end)} />
            <TimesheetValue label="Class Report" value={shift.formResponseId ? "Submitted" : "Not submitted"} />
            <TimesheetValue label="Timesheet" value={shift.timesheetId ? "Available" : "Not found"} />
            <TimesheetValue label="Shift ID" value={shift.id} />
          </div>
        </section>
      </div>
    </div>
  );
}

function TimesheetDetailSheet({ timesheet, onClose }: { timesheet: TimesheetDetail; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-[60] overflow-y-auto bg-[#0F172A]/55 px-4 py-5">
      <div className="mx-auto max-w-[680px]">
        <div className="mb-4 flex justify-end">
          <button type="button" onClick={onClose} aria-label="Close timesheet" className="grid h-10 w-10 place-items-center rounded-full bg-white text-[#334155] shadow-sm">
            <X size={20} />
          </button>
        </div>
        <section className="rounded-2xl bg-white p-6 shadow-[0_4px_10px_rgba(15,23,42,0.08)]">
          <div className="flex items-start gap-4">
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-[#EEF2FF] text-[#6366F1]">
              <Clock size={24} />
            </span>
            <div>
              <h2 className="text-2xl font-bold text-[#111827]">Timesheet</h2>
              <p className="mt-1 text-sm font-semibold text-[#64748B]">Status: {humanizeFieldId(timesheet.status || "pending")}</p>
            </div>
          </div>
          <div className="mt-6 grid gap-3 sm:grid-cols-2">
            <TimesheetValue label="Scheduled" value={formatDateRange(timesheet.start, timesheet.end)} />
            <TimesheetValue label="Clock Time" value={formatDateRange(timesheet.clockIn, timesheet.clockOut)} />
            <TimesheetValue label="Total Hours" value={timesheet.totalHours ? timesheet.totalHours.toFixed(2) : "Not recorded"} />
            <TimesheetValue label="Reported Hours" value={timesheet.reportedHours ? timesheet.reportedHours.toFixed(2) : "Not reported"} />
            <TimesheetValue label="Pay" value={timesheet.payAmount ? `$${timesheet.payAmount.toFixed(2)}` : "Not calculated"} />
            <TimesheetValue label="Class Report" value={timesheet.formCompleted || timesheet.formResponseId ? "Submitted" : "Not submitted"} />
          </div>
          {timesheet.formResponseId ? (
            <p className="mt-4 rounded-xl bg-green-50 px-4 py-3 text-sm font-semibold text-green-700">Linked form response: {timesheet.formResponseId}</p>
          ) : null}
        </section>
      </div>
    </div>
  );
}

function TimesheetValue({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-[#E5E7EB] bg-[#F8FAFC] p-4">
      <p className="text-xs font-black uppercase tracking-[0.08em] text-[#64748B]">{label}</p>
      <p className="mt-2 text-sm font-semibold leading-6 text-[#111827]">{value}</p>
    </div>
  );
}

function ExistingSubmissionSheet({ submission, onClose }: { submission: ExistingSubmission; onClose: () => void }) {
  const entries = Object.entries(submission.responses);
  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-[#0F172A]/45 px-4 py-5">
      <div className="mx-auto max-w-[760px]">
        <div className="mb-4 flex justify-end">
          <button type="button" onClick={onClose} aria-label="Close submitted form" className="grid h-10 w-10 place-items-center rounded-full bg-white text-[#334155] shadow-sm">
            <X size={20} />
          </button>
        </div>
        <section className="rounded-2xl bg-white p-6 shadow-[0_4px_10px_rgba(15,23,42,0.08)]">
          <div className="flex items-start gap-4">
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-green-50 text-green-600">
              <Check size={24} />
            </span>
            <div>
              <h2 className="text-2xl font-bold text-[#111827]">{submission.formTitle || "Submitted Form"}</h2>
              <p className="mt-1 text-sm font-semibold text-[#64748B]">
                {submission.submittedAt ? `Submitted ${formatShortDate(submission.submittedAt)} at ${formatTime(submission.submittedAt)}` : "Submitted form response"}
              </p>
            </div>
          </div>
        </section>
        <section className="mt-5 rounded-2xl bg-white p-6 shadow-[0_4px_10px_rgba(15,23,42,0.08)]">
          {entries.length === 0 ? (
            <p className="rounded-xl bg-[#F8FAFC] px-4 py-4 text-sm font-semibold text-[#64748B]">No response fields were saved for this form.</p>
          ) : (
            <div className="grid gap-3">
              {entries.map(([key, value]) => (
                <div key={key} className="rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-4">
                  <p className="text-xs font-black uppercase tracking-[0.08em] text-[#64748B]">{submission.fieldLabels[key] || humanizeFieldId(key)}</p>
                  <p className="mt-2 whitespace-pre-wrap text-sm font-semibold leading-6 text-[#111827]">{formatResponseValue(value)}</p>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
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

function field(id: string, label: string, type: FieldType, order: number, required = false, placeholder = "", options: string[] = []): TemplateField {
  return { id, label, type, order, required, placeholder, options };
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
    daily: docs.some((item) => item.formType === "daily" && (item.submittedAt?.getTime() ?? 0) >= todayStart.getTime()),
    weekly: docs.some((item) => item.formType === "weekly" && (item.submittedAt?.getTime() ?? 0) >= weekStart.getTime()),
    monthly: docs.some((item) => item.formType === "monthly" && item.yearMonth === yearMonth),
  };
}

function normalizeTemplate(id: string, data: Record<string, unknown>): FormTemplateRecord {
  const fields = normalizeFields(data.fields);
  const fallbackFields = defaultFields[id] ?? [];
  return {
    id,
    name: stringValue(data.name) || "Untitled",
    description: stringValue(data.description),
    frequency: normalizeFrequency(stringValue(data.frequency)),
    category: normalizeCategory(stringValue(data.category)),
    version: numberValue(data.version) || 1,
    fieldsCount: fields.length || fallbackFields.length || fieldsCount(data.fields),
    fields: fields.length > 0 ? fields : fallbackFields,
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
  if (template.allowedRoles.length > 0) return template.allowedRoles.includes(role);
  return ["teaching", "feedback", "administrative", "studentAssessment"].includes(template.category) || ["perSession", "weekly", "monthly"].includes(template.frequency);
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

function normalizeFields(value: unknown): TemplateField[] {
  const entries: Array<[string, unknown]> = Array.isArray(value)
    ? value.map((item, index) => [stringValue((item as Record<string, unknown>)?.id) || `field_${index}`, item])
    : value && typeof value === "object"
      ? Object.entries(value as Record<string, unknown>)
      : [];

  return entries
    .map(([id, item], index) => {
      const data = item && typeof item === "object" ? (item as Record<string, unknown>) : {};
      return field(
        id,
        stringValue(data.label) || stringValue(data.name) || "Untitled Field",
        normalizeFieldType(stringValue(data.type)),
        numberValue(data.order) || index,
        data.required === true,
        stringValue(data.placeholder),
        stringArray(data.options),
      );
    })
    .sort((a, b) => a.order - b.order);
}

function normalizeFieldType(value: string): FieldType {
  if (value === "email" || value === "phone") return value;
  if (value === "long_text" || value === "multiline" || value === "description") return value;
  if (value === "dropdown" || value === "select") return value;
  if (value === "multi_select") return value;
  if (value === "radio") return "radio";
  if (value === "number") return "number";
  if (value === "date") return "date";
  if (value === "time") return "time";
  if (value === "boolean" || value === "yes_no" || value === "yesNo") return value;
  if (value === "image_upload" || value === "imageUpload" || value === "signature") return value;
  return "text";
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

async function loadRecentTeacherShifts(uid: string): Promise<ShiftOption[]> {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const startNextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  const snapshots = await Promise.all(
    ["teacher_id", "teacherId"].map((teacherField) =>
      getDocs(
        query(
          collection(db, "teaching_shifts"),
          where(teacherField, "==", uid),
          where("shift_start", ">=", Timestamp.fromDate(startOfMonth)),
          where("shift_start", "<", Timestamp.fromDate(startNextMonth)),
          limit(100),
        ),
      ).catch(() => null),
    ),
  );

  const byId = new Map<string, ShiftOption>();
  snapshots
    .flatMap((snap) => snap?.docs ?? [])
    .map((docSnap) => {
      const data = docSnap.data() as Record<string, unknown>;
      const start = dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime);
      const end = dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime);
      const status = stringValue(data.status) || "scheduled";
      if (!start || !end) return null;
      const normalizedStatus = normalizeShiftStatus(status);
      const allowed = ["completed", "fullyCompleted", "partiallyCompleted", "missed"].includes(normalizedStatus);
      if (!allowed || start >= now || end >= now) return null;
      const names = stringArray(data.student_names ?? data.studentNames);
      const subject = stringValue(data.subject_display_name ?? data.subjectDisplayName ?? data.subject) || "Unknown Subject";
      return {
        id: docSnap.id,
        title: names.length > 0 ? names.join(", ") : subject,
        status: normalizedStatus,
        start,
        end,
        subject,
        formResponseId: "",
        timesheetId: "",
      };
    })
    .filter((item): item is ShiftOption => Boolean(item))
    .forEach((shift) => byId.set(shift.id, shift));

  const shifts = Array.from(byId.values()).sort((a, b) => b.start.getTime() - a.start.getTime());

  const enriched = await Promise.all(
    shifts.map(async (shift) => ({
      ...shift,
      formResponseId: await findFormResponseForShift(uid, shift.id),
      timesheetId: await findTimesheetForShift(uid, shift.id),
    })),
  );
  return enriched;
}

function normalizeShiftStatus(status: string) {
  const normalized = status.trim();
  if (normalized === "fully_completed" || normalized === "fully-completed") return "fullyCompleted";
  if (normalized === "partially_completed" || normalized === "partially-completed") return "partiallyCompleted";
  return normalized;
}

async function findFormResponseForShift(uid: string, shiftId: string) {
  const shiftDoc = await getDoc(doc(db, "teaching_shifts", shiftId)).catch(() => null);
  const linkedId = stringValue(shiftDoc?.data()?.form_response_id);
  if (linkedId) {
    const linked = await getDoc(doc(db, "form_responses", linkedId)).catch(() => null);
    if (linked?.exists()) return linkedId;
  }

  const shiftFields = ["shiftId", "shift_id", "linked_shift_id"];
  const userFields = ["userId", "submittedBy", "submitted_by", "teacher_id", "teacherId"];
  const matches = new Map<string, { id: string; submittedAt: Date | null }>();
  for (const shiftField of shiftFields) {
    for (const userField of userFields) {
      const snap = await getDocs(query(collection(db, "form_responses"), where(shiftField, "==", shiftId), where(userField, "==", uid), limit(20))).catch(() => null);
      snap?.docs.forEach((entry) => {
        const data = entry.data() as Record<string, unknown>;
        matches.set(entry.id, { id: entry.id, submittedAt: dateValue(data.submittedAt ?? data.submitted_at) });
      });
    }
  }
  return Array.from(matches.values()).sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0))[0]?.id ?? "";
}

async function findTimesheetForShift(uid: string, shiftId: string) {
  const candidates = [
    ["shift_id", "teacher_id"],
    ["shiftId", "teacher_id"],
    ["shift_id", "teacherId"],
    ["shiftId", "teacherId"],
    ["shift_id", "userId"],
    ["shiftId", "userId"],
  ] as const;
  for (const [shiftField, userField] of candidates) {
    const snap = await getDocs(query(collection(db, "timesheet_entries"), where(shiftField, "==", shiftId), where(userField, "==", uid), limit(1))).catch(() => null);
    const first = snap?.docs[0];
    if (first) return first.id;
  }
  return "";
}

async function loadTimesheetForShift(uid: string, shift: ShiftOption): Promise<TimesheetDetail | null> {
  const timesheetId = shift.timesheetId || (await findTimesheetForShift(uid, shift.id));
  if (!timesheetId) return null;
  const timesheetDoc = await getDoc(doc(db, "timesheet_entries", timesheetId)).catch(() => null);
  if (!timesheetDoc?.exists()) return null;
  return normalizeTimesheetDetail(timesheetDoc.id, timesheetDoc.data() as Record<string, unknown>);
}

function normalizeTimesheetDetail(id: string, data: Record<string, unknown>): TimesheetDetail {
  return {
    id,
    status: stringValue(data.status) || "pending",
    start: dateValue(data.scheduled_start ?? data.scheduledStart ?? data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime),
    end: dateValue(data.scheduled_end ?? data.scheduledEnd ?? data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime),
    clockIn: dateValue(data.clock_in_time ?? data.clockInTime ?? data.start_time ?? data.startTime),
    clockOut: dateValue(data.clock_out_time ?? data.clockOutTime ?? data.end_time ?? data.endTime),
    totalHours: numberValue(data.total_hours ?? data.totalHours),
    reportedHours: numberValue(data.reported_hours ?? data.reportedHours),
    payAmount: numberValue(data.pay_amount ?? data.payAmount ?? data.total_pay ?? data.totalPay),
    formCompleted: data.form_completed === true || data.formCompleted === true,
    formResponseId: stringValue(data.form_response_id ?? data.formResponseId),
  };
}

async function loadExistingSubmission(formResponseId: string): Promise<ExistingSubmission | null> {
  const responseDoc = await getDoc(doc(db, "form_responses", formResponseId)).catch(() => null);
  if (!responseDoc?.exists()) return null;
  const data = responseDoc.data() as Record<string, unknown>;
  const rawResponses = data.responses && typeof data.responses === "object" ? (data.responses as Record<string, unknown>) : {};
  const formId = stringValue(data.formId ?? data.form_id ?? data.templateId ?? data.formTemplateId);
  return {
    id: responseDoc.id,
    formTitle: stringValue(data.formTitle ?? data.formName ?? data.title) || "Submitted Form",
    submittedAt: dateValue(data.submittedAt ?? data.submitted_at),
    responses: rawResponses,
    fieldLabels: formId ? await loadFieldLabelsForForm(formId) : {},
  };
}

async function loadFieldLabelsForForm(formId: string): Promise<Record<string, string>> {
  const template = await getDoc(doc(db, "form_templates", formId)).catch(() => null);
  if (template?.exists()) {
    return buildFieldLabels((template.data() as Record<string, unknown>).fields);
  }
  const legacy = await getDoc(doc(db, "form", formId)).catch(() => null);
  if (legacy?.exists()) {
    return buildFieldLabels((legacy.data() as Record<string, unknown>).fields);
  }
  return {};
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

async function linkFormResponseToShiftAndTimesheet(shift: ShiftOption, formResponseId: string) {
  if (shift.timesheetId) {
    await updateDoc(doc(db, "timesheet_entries", shift.timesheetId), {
      form_response_id: formResponseId,
      formResponseId,
      form_completed: true,
      formCompleted: true,
      reported_hours: null,
      reportedHours: null,
      form_notes: null,
      formNotes: null,
      form_completed_at: serverTimestamp(),
      formCompletedAt: serverTimestamp(),
    }).catch(() => null);
  } else {
    const timesheetId = await findTimesheetForShift(auth.currentUser?.uid ?? "", shift.id);
    if (timesheetId) {
      await updateDoc(doc(db, "timesheet_entries", timesheetId), {
        form_response_id: formResponseId,
        formResponseId,
        form_completed: true,
        formCompleted: true,
        reported_hours: null,
        reportedHours: null,
        form_notes: null,
        formNotes: null,
        form_completed_at: serverTimestamp(),
        formCompletedAt: serverTimestamp(),
      }).catch(() => null);
    }
  }
  await updateDoc(doc(db, "teaching_shifts", shift.id), {
    form_response_id: formResponseId,
    formResponseId,
    form_completed: true,
    formCompleted: true,
    form_completed_at: serverTimestamp(),
    formCompletedAt: serverTimestamp(),
    reported_hours: null,
    reportedHours: null,
    form_notes: null,
    formNotes: null,
  }).catch(() => null);
}

function submissionFormType(frequency: Frequency) {
  if (frequency === "weekly") return "weekly";
  if (frequency === "monthly") return "monthly";
  if (frequency === "onDemand") return "onDemand";
  return "daily";
}

function yearMonthFor(value: Date) {
  return `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, "0")}`;
}

function formatShortDate(value: Date) {
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" }).format(value);
}

function formatTime(value: Date) {
  return new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit" }).format(value);
}

function formatDateRange(start: Date | null, end: Date | null) {
  if (!start && !end) return "Not recorded";
  if (start && end) return `${formatShortDate(start)} ${formatTime(start)} - ${formatTime(end)}`;
  if (start) return `${formatShortDate(start)} ${formatTime(start)} - not recorded`;
  return `Not recorded - ${formatShortDate(end as Date)} ${formatTime(end as Date)}`;
}

function humanizeFieldId(value: string) {
  return value
    .replace(/^_+/, "")
    .replace(/[_-]+/g, " ")
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .trim()
    .replace(/\b\w/g, (letter) => letter.toUpperCase()) || "Response";
}

function formatResponseValue(value: unknown): string {
  if (Array.isArray(value)) return value.map(formatResponseValue).join(", ");
  if (value instanceof Timestamp) return `${formatShortDate(value.toDate())} ${formatTime(value.toDate())}`;
  if (value instanceof Date) return `${formatShortDate(value)} ${formatTime(value)}`;
  if (value && typeof value === "object") {
    const fileName = stringValue((value as Record<string, unknown>).fileName);
    if (fileName) return fileName;
    return JSON.stringify(value);
  }
  const text = String(value ?? "").trim();
  return text || "No answer";
}

function shiftStatusClass(status: string) {
  if (status === "completed" || status === "fullyCompleted") return "border-green-200 bg-green-50 text-green-700";
  if (status === "missed") return "border-red-200 bg-red-50 text-red-700";
  if (status === "partiallyCompleted") return "border-orange-200 bg-orange-50 text-orange-700";
  return "border-slate-200 bg-slate-50 text-slate-600";
}

function summaryForUser(user: User, data: UserRecord | null): TeacherSummary {
  const firstName = stringValue(data?.first_name) || stringValue(data?.firstName);
  const lastName = stringValue(data?.last_name) || stringValue(data?.lastName);
  const fullName = [firstName, lastName].filter(Boolean).join(" ").trim();
  const displayName = fullName || user.displayName || user.email || "Teacher";
  return {
    displayName,
    firstName: firstName || displayName.split(/\s+/)[0] || "Teacher",
    initials: initialsFor(displayName),
  };
}

function initialsFor(name: string) {
  return (
    name
      .split(/[^a-zA-Z0-9]+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? "")
      .join("") || "TE"
  );
}
