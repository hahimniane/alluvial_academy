"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import {
  collection,
  doc,
  arrayUnion,
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
  Check,
  Clock,
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
  StickyNote,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

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
  const activeTabConfig = tabs.find((tab) => tab.id === activeTab) ?? tabs[0];

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
          ) : (
            <div className="grid gap-3">
              {applicants.map((applicant) => (
                <ApplicantCard
                  key={applicant.id}
                  applicant={applicant}
                  tab={activeTabConfig}
                  onMarkContacted={() => moveApplicant(applicant, "contacted")}
                  onArchive={() => moveApplicant(applicant, "archived")}
                  onUnarchive={() => moveApplicant(applicant, "pending")}
                />
              ))}
            </div>
          )}
        </section>
      </main>
    </AdminDashboardShell>
  );
}

function ApplicantCard({
  applicant,
  tab,
  onMarkContacted,
  onArchive,
  onUnarchive,
}: {
  applicant: EnrollmentApplicant;
  tab: ApplicantTab;
  onMarkContacted: () => void;
  onArchive: () => void;
  onUnarchive: () => void;
}) {
  const live = applicant.status === "broadcasted";
  const archived = applicant.status === "archived";
  return (
    <article className={`overflow-hidden rounded-xl bg-white shadow-[0_2px_10px_rgba(15,23,42,0.03)] ${live ? "border border-[#10B981]" : ""}`}>
      <div className={`flex items-center gap-2 px-4 py-2 text-[11px] font-bold ${live ? "bg-[#ECFDF5] text-[#059669]" : archived ? "bg-[#F1F5F9] text-[#64748B]" : "bg-[#F8FAFC] text-[#94A3B8]"}`}>
        {live ? <Radio size={14} /> : archived ? <Archive size={14} /> : <Clock size={14} />}
        <span>{live ? "LIVE ON JOB BOARD" : archived ? "ARCHIVED" : formatSubmittedAt(applicant.submittedAt)}</span>
        <span className="flex-1" />
        {applicant.isAdult ? <span className="rounded bg-[#EFF6FF] px-1.5 py-0.5 text-[10px] font-black text-[#1D4ED8]">ADULT STUDENT</span> : null}
      </div>
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
  };
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
