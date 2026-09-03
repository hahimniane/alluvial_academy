"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import {
  BookOpen,
  CalendarDays,
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  ClipboardCheck,
  Clock3,
  Globe2,
  GraduationCap,
  Info,
  Menu,
  RotateCw,
  Shuffle,
  Timer,
  UserRound,
  X,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import {
  Timestamp,
  arrayUnion,
  collection,
  deleteField,
  doc,
  getDoc,
  increment,
  onSnapshot,
  runTransaction,
  type Unsubscribe,
} from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import { blockById, blockRangeLabel, minutesFromDurationLabel, normalizeBlock, sessionLabel, slotsFor } from "@/lib/enrollmentDomain";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;
type AvailabilityStatus = "available" | "partial";

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type JobOpportunity = {
  id: string;
  enrollmentId: string;
  studentName: string;
  studentAge: string;
  subject: string;
  subjectDisplayName: string;
  gradeLevel: string;
  days: string[];
  timeSlots: string[];
  timeZone: string;
  /** The family's chosen part of the day, e.g. "Evening". */
  block: string;
  /** How long one class is. Drives the slot windows the teacher picks from. */
  sessionMinutes: number;
  sessionsPerWeek: number;
  status: string;
  createdAt: Date;
  acceptedByTeacherId: string;
  acceptedAt: Date | null;
  sessionDuration: string;
  classType: string;
  scheduleTimezoneRef: string;
  adminNotesForTeachers: string;
  targetTeacherIds: string[];
  teacherSelectedTimes: Record<string, string>;
};

type TeacherResponse = {
  availabilityStatus: string;
  comment: string;
};

type ResponseDraft = {
  status: AvailabilityStatus;
  comment: string;
  rankedSlots: string[];
};

const emptyDraft: ResponseDraft = {
  status: "available",
  comment: "",
  rankedSlots: [],
};

export function TeacherJobBoardPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [user, setUser] = useState<User | null>(null);
  const [jobs, setJobs] = useState<JobOpportunity[]>([]);
  const [responses, setResponses] = useState<Record<string, TeacherResponse>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [activeJob, setActiveJob] = useState<JobOpportunity | null>(null);
  const [draft, setDraft] = useState<ResponseDraft>(emptyDraft);
  const [withdrawJob, setWithdrawJob] = useState<JobOpportunity | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [withdrawing, setWithdrawing] = useState(false);
  const [withdrawError, setWithdrawError] = useState("");
  const [statusMessage, setStatusMessage] = useState("");

  useEffect(() => {
    let mounted = true;
    let unsubscribeJobs: Unsubscribe | null = null;

    const unsubscribeAuth = onAuthStateChanged(auth, async (nextUser) => {
      unsubscribeJobs?.();
      unsubscribeJobs = null;
      if (!mounted) return;
      setUser(nextUser);
      setError("");
      setJobs([]);
      setResponses({});

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

        unsubscribeJobs = onSnapshot(
          collection(db, "job_board"),
          async (snapshot) => {
            const loaded = snapshot.docs.map((entry) => normalizeJob(entry.id, entry.data() as Record<string, unknown>));
            loaded.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
            if (!mounted) return;
            setJobs(loaded);
            setLoading(false);

            const openJobs = loaded.filter((job) => job.status === "open");
            const responseEntries = await Promise.all(
              openJobs.map(async (job) => {
                try {
                  const responseSnap = await getDoc(doc(db, "job_board", job.id, "responses", nextUser.uid));
                  if (!responseSnap.exists()) return null;
                  return [job.id, normalizeResponse(responseSnap.data() as Record<string, unknown>)] as const;
                } catch {
                  return null;
                }
              }),
            );
            if (!mounted) return;
            setResponses(Object.fromEntries(responseEntries.filter((entry): entry is readonly [string, TeacherResponse] => entry !== null)));
          },
          (nextError) => {
            if (!mounted) return;
            setError(nextError.message || "Unable to load opportunities.");
            setLoading(false);
          },
        );
      } catch {
        if (mounted) {
          setAccess("denied");
          setLoading(false);
        }
      }
    });

    return () => {
      mounted = false;
      unsubscribeJobs?.();
      unsubscribeAuth();
    };
  }, []);

  const visibleJobs = useMemo(
    () => jobs.filter((job) => !job.targetTeacherIds.length || Boolean(user && job.targetTeacherIds.includes(user.uid))),
    [jobs, user],
  );
  const openJobs = useMemo(() => visibleJobs.filter((job) => job.status === "open"), [visibleJobs]);
  const filledJobs = useMemo(
    () =>
      visibleJobs.filter((job) => {
        if (job.status !== "accepted") return false;
        const referenceDate = job.acceptedAt ?? job.createdAt;
        return Date.now() - referenceDate.getTime() < 24 * 60 * 60 * 1000;
      }),
    [visibleJobs],
  );

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  function openResponseDialog(job: JobOpportunity) {
    setActiveJob(job);
    setDraft(emptyDraft);
    setSubmitError("");
    setStatusMessage("");
  }

  function openWithdrawDialog(job: JobOpportunity) {
    setWithdrawJob(job);
    setWithdrawError("");
    setStatusMessage("");
  }

  async function submitResponse() {
    if (!activeJob || !user || submitting) return;
    const comment = draft.comment.trim();
    if (draft.status === "partial" && !comment) {
      setSubmitError("Please add a comment for this response.");
      return;
    }

    setSubmitting(true);
    setSubmitError("");
    try {
      await submitTeacherAvailability(activeJob, user, draft);
      setActiveJob(null);
      setDraft(emptyDraft);
    } catch (nextError) {
      setSubmitError(jobActionError(nextError, "Unable to submit your response."));
    } finally {
      setSubmitting(false);
    }
  }

  async function submitWithdrawal() {
    if (!withdrawJob || !user || withdrawing) return;

    setWithdrawing(true);
    setWithdrawError("");
    setStatusMessage("");
    try {
      await withdrawTeacherFromJob(withdrawJob.id, user);
      setWithdrawJob(null);
      setStatusMessage("You have withdrawn. The job is now available for other teachers.");
    } catch (nextError) {
      setWithdrawError(jobActionError(nextError, "Unable to withdraw from this opportunity."));
    } finally {
      setWithdrawing(false);
    }
  }

  return (
    <TeacherShell activeLabel="Job Board" breadcrumb="Work / Job Board" summary={summary}>
      <main className="min-h-[calc(100vh-56px)] overflow-y-auto bg-[#F9FAFB] text-[#111827]">
        <MobileTeacherTopBar summary={summary} />
        <section className="bg-white px-6 py-7 lg:w-fit lg:min-w-[375px] lg:px-6 lg:py-8">
          <h1 className="text-[24px] font-black leading-tight text-[#111827]">New Student Opportunities</h1>
          <p className="mt-1 text-[14px] font-medium text-[#6B7280]">Accept new students to fill your schedule</p>
        </section>

        <section className="relative min-h-[calc(100vh-154px)]">
          {statusMessage ? (
            <div className="mx-auto mt-4 max-w-4xl px-4 lg:px-6">
              <p className="rounded-xl border border-[#FDBA74] bg-[#FFF7ED] px-4 py-3 text-sm font-bold text-[#C2410C]">{statusMessage}</p>
            </div>
          ) : null}
          {loading ? (
            <div className="grid min-h-[540px] place-items-center">
              <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
            </div>
          ) : error ? (
            <div className="grid min-h-[540px] place-items-center px-6 text-center text-sm font-semibold text-[#B91C1C]">{error}</div>
          ) : openJobs.length === 0 && filledJobs.length === 0 ? (
            <EmptyJobBoard />
          ) : (
            <div className="mx-auto max-w-4xl px-4 py-6 lg:px-6">
              <div className="grid gap-4">
                {openJobs.map((job) => (
                  <JobCard
                    key={job.id}
                    job={job}
                    isFilled={false}
                    response={responses[job.id]}
                    currentTeacherId={user?.uid ?? ""}
                    onRespond={() => openResponseDialog(job)}
                    onWithdraw={() => openWithdrawDialog(job)}
                    withdrawing={withdrawing && withdrawJob?.id === job.id}
                  />
                ))}
              </div>
              {filledJobs.length > 0 ? (
                <section className="mt-6">
                  <h2 className="mb-4 text-lg font-semibold text-[#B91C1C]">Filled Opportunities</h2>
                  <div className="grid gap-4">
                    {filledJobs.map((job) => (
                      <JobCard
                        key={job.id}
                        job={job}
                        isFilled
                        response={responses[job.id]}
                        currentTeacherId={user?.uid ?? ""}
                        onRespond={() => openResponseDialog(job)}
                        onWithdraw={() => openWithdrawDialog(job)}
                        withdrawing={withdrawing && withdrawJob?.id === job.id}
                      />
                    ))}
                  </div>
                </section>
              ) : null}
            </div>
          )}
        </section>
      </main>

      {activeJob ? (
        <ResponseDialog
          job={activeJob}
          draft={draft}
          error={submitError}
          submitting={submitting}
          onChange={setDraft}
          onClose={() => (submitting ? null : setActiveJob(null))}
          onSubmit={submitResponse}
        />
      ) : null}

      {withdrawJob ? (
        <WithdrawDialog
          job={withdrawJob}
          error={withdrawError}
          submitting={withdrawing}
          onClose={() => (withdrawing ? null : setWithdrawJob(null))}
          onSubmit={submitWithdrawal}
        />
      ) : null}
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-[64px] grid-cols-[48px_1fr_80px] items-center bg-white px-3 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={24} />
      </button>
      <div className="min-w-0 text-center text-[16px] font-semibold text-[#111827]">Alluwal Education Hub</div>
      <div className="flex items-center justify-end gap-3">
        <button type="button" aria-label="Open teacher account options" onClick={openTeacherMobileMenu} className="grid h-9 w-9 place-items-center rounded-xl text-[#111827]"><Shuffle size={17} /></button>
        <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[12px] font-black text-white">{summary.initials}</span>
      </div>
    </header>
  );
}

function EmptyJobBoard() {
  return (
    <div className="grid min-h-[calc(100vh-176px)] place-items-center">
      <div className="text-center">
        <ClipboardCheck size={58} strokeWidth={2.4} className="mx-auto text-[#D9D9D9]" />
        <p className="mt-6 text-[18px] font-normal text-[#9E9E9E]">No opportunities right now</p>
      </div>
    </div>
  );
}

function JobCard({
  job,
  isFilled,
  response,
  currentTeacherId,
  onRespond,
  onWithdraw,
  withdrawing,
}: {
  job: JobOpportunity;
  isFilled: boolean;
  response?: TeacherResponse;
  currentTeacherId: string;
  onRespond: () => void;
  onWithdraw: () => void;
  withdrawing: boolean;
}) {
  const isMyAcceptedJob = Boolean(currentTeacherId && job.acceptedByTeacherId === currentTeacherId);
  return (
    <article className={`rounded-2xl border bg-white p-5 shadow-sm ${isFilled ? "border-[#EF4444] bg-[#FEF2F2]" : "border-transparent"}`}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 flex-wrap gap-2">
          <span className={`rounded-full border px-3 py-1 text-xs font-bold ${isFilled ? "border-[#FCA5A5] bg-[#FEE2E2] text-[#7F1D1D]" : "border-[#BFDBFE] bg-[#EFF6FF] text-[#1D4ED8]"}`}>
            {displaySubject(job)}
          </span>
          {isFilled ? <span className="rounded-full bg-[#EF4444] px-3 py-1 text-[11px] font-black uppercase tracking-[0.08em] text-white">Filled</span> : null}
        </div>
        <time className="shrink-0 text-xs font-medium text-[#9CA3AF]">{formatMonthDay(job.createdAt)}</time>
      </div>

      <h2 className="mt-4 text-xl font-black text-[#111827]">{job.studentName || "Student"}</h2>
      <div className="mt-3 grid gap-2 text-sm text-[#4B5563]">
        <InfoRow icon={UserRound} text={`Age: ${job.studentAge || "N/A"}`} />
        <InfoRow icon={BookOpen} text={`Program: ${displaySubject(job)}`} />
        <InfoRow icon={GraduationCap} text={`Grade: ${job.gradeLevel || "N/A"}`} />
        <div className="flex flex-wrap items-center gap-2">
          <Timer size={16} className="text-[#9CA3AF]" />
          <span className="rounded border border-[#F59E0B] bg-[#FEF3C7] px-2 py-0.5 text-xs font-bold text-[#92400E]">{durationDisplay(job.sessionDuration)}</span>
          {job.classType ? <span className="rounded border border-[#8B5CF6] bg-[#EDE9FE] px-2 py-0.5 text-xs font-bold text-[#5B21B6]">{job.classType}</span> : null}
        </div>
        <InfoRow icon={Globe2} text={job.scheduleTimezoneRef ? `Timezone: ${timezoneAbbr(job.timeZone)} (times in ${job.scheduleTimezoneRef})` : `Timezone: ${timezoneAbbr(job.timeZone)}`} />
        {job.adminNotesForTeachers ? <AdminNote text={job.adminNotesForTeachers} /> : null}
        {response ? <TeacherResponseNote response={response} /> : null}
        <InfoRow icon={CalendarDays} text={`Days: ${job.days.join(", ") || "N/A"}`} />
        <InfoRow
          icon={Clock3}
          text={
            // Families give a window now, not exact hours. Older jobs still
            // carry the slots they picked, so fall back to those.
            blockById(job.block)
              ? `Requested window: ${blockById(job.block)!.label} (${blockRangeLabel(blockById(job.block)!)})`
              : `Times: ${job.timeSlots.join(", ") || "N/A"}`
          }
        />
        {isFilled && job.acceptedAt ? <InfoRow icon={CheckCircle2} text={`Accepted on ${formatFullDate(job.acceptedAt)}`} /> : null}
        {isFilled && Object.keys(job.teacherSelectedTimes).length > 0 ? <SelectedTimes times={job.teacherSelectedTimes} /> : null}
      </div>

      <div className="mt-5">
        {isFilled ? (
          isMyAcceptedJob ? (
            <button type="button" onClick={onWithdraw} disabled={withdrawing} className="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-[#EA580C] px-4 text-base font-bold text-white disabled:opacity-70">
              {withdrawing ? <RotateCw size={18} className="animate-spin" /> : null}
              {withdrawing ? "Withdrawing..." : "Withdraw & Re-broadcast"}
            </button>
          ) : (
            <button type="button" disabled className="inline-flex min-h-12 w-full items-center justify-center rounded-xl border border-[#EF4444] px-4 text-base font-bold text-[#B91C1C] opacity-80">
              Filled by Another Teacher
            </button>
          )
        ) : (
          <>
            <button type="button" onClick={onRespond} className="inline-flex min-h-12 w-full items-center justify-center rounded-xl bg-[#10B981] px-4 text-base font-bold text-white">
              Submit availability
            </button>
            <p className="mt-2 text-center text-xs text-[#6B7280]">Tell admin if you are available or partially available.</p>
          </>
        )}
      </div>
    </article>
  );
}

function WithdrawDialog({
  job,
  error,
  submitting,
  onClose,
  onSubmit,
}: {
  job: JobOpportunity;
  error: string;
  submitting: boolean;
  onClose: () => void;
  onSubmit: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 px-4 py-6">
      <section role="dialog" aria-modal="true" aria-labelledby="job-withdraw-title" className="w-full max-w-[520px] rounded-2xl bg-white p-5 shadow-2xl">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 id="job-withdraw-title" className="text-xl font-black text-[#111827]">Withdraw from this student?</h2>
            <p className="mt-1 text-sm font-semibold text-[#475569]">{job.studentName || "Student"} • {displaySubject(job)}</p>
          </div>
          <button type="button" aria-label="Close withdraw dialog" onClick={onClose} className="grid h-9 w-9 shrink-0 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </div>

        <p className="mt-4 text-sm leading-6 text-[#4B5563]">This will re-broadcast the opportunity to other teachers. You can accept it again if it's still available.</p>
        {error ? <p className="mt-4 rounded-lg bg-[#FEE2E2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">{error}</p> : null}

        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={onClose} disabled={submitting} className="min-h-10 rounded-xl px-4 text-sm font-bold text-[#334155] hover:bg-[#F1F5F9]">Cancel</button>
          <button type="button" onClick={onSubmit} disabled={submitting} className="inline-flex min-h-10 items-center justify-center gap-2 rounded-xl bg-[#DC2626] px-5 text-sm font-bold text-white disabled:opacity-70">
            {submitting ? <RotateCw size={16} className="animate-spin" /> : null}
            {submitting ? "Withdrawing..." : "Withdraw"}
          </button>
        </div>
      </section>
    </div>
  );
}

function InfoRow({ icon: Icon, text }: { icon: typeof UserRound; text: string }) {
  return (
    <div className="flex items-start gap-2">
      <Icon size={16} className="mt-0.5 shrink-0 text-[#9CA3AF]" />
      <span className="min-w-0 flex-1">{text}</span>
    </div>
  );
}

function AdminNote({ text }: { text: string }) {
  return (
    <div className="flex gap-2 rounded-lg border border-[#FCD34D] bg-[#FFFBEB] p-3">
      <Info size={16} className="mt-0.5 shrink-0 text-[#D97706]" />
      <div>
        <p className="text-[11px] font-black uppercase text-[#92400E]">Admin Note</p>
        <p className="mt-0.5 text-xs leading-5 text-[#78350F]">{text}</p>
      </div>
    </div>
  );
}

function TeacherResponseNote({ response }: { response: TeacherResponse }) {
  const statusLabel = response.availabilityStatus === "partial" ? "Partially available" : response.availabilityStatus === "available" ? "Available" : response.availabilityStatus;
  const className =
    response.availabilityStatus === "partial"
      ? "border-[#F59E0B]/40 bg-[#FEF3C7]/70 text-[#92400E]"
      : "border-[#16A34A]/40 bg-[#DCFCE7]/70 text-[#166534]";
  return (
    <div className={`rounded-lg border p-3 text-xs ${className}`}>
      <p className="font-black">Your last response: {statusLabel}</p>
      {response.comment ? <p className="mt-1 text-[#374151]">{response.comment}</p> : null}
    </div>
  );
}

function SelectedTimes({ times }: { times: Record<string, string> }) {
  return (
    <div className="rounded-lg border border-[#10B981] bg-[#D1FAE5] p-3 text-xs text-[#047857]">
      <p className="font-bold text-[#065F46]">Your Selected Times:</p>
      <div className="mt-2 grid gap-1">
        {Object.entries(times).map(([day, time]) => (
          <p key={day}>{day}: {time}</p>
        ))}
      </div>
    </div>
  );
}

function ResponseDialog({
  job,
  draft,
  error,
  submitting,
  onChange,
  onClose,
  onSubmit,
}: {
  job: JobOpportunity;
  draft: ResponseDraft;
  error: string;
  submitting: boolean;
  onChange: (draft: ResponseDraft) => void;
  onClose: () => void;
  onSubmit: () => void;
}) {
  const requiresComment = draft.status === "partial";
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 px-4 py-6">
      <section role="dialog" aria-modal="true" aria-labelledby="job-response-title" className="max-h-full w-full max-w-[560px] overflow-y-auto rounded-2xl bg-white p-5 shadow-2xl">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 id="job-response-title" className="text-xl font-black text-[#111827]">Reply to broadcast</h2>
            <p className="mt-1 text-sm font-semibold text-[#475569]">{job.studentName || "Student"} • {displaySubject(job)}</p>
          </div>
          <button type="button" aria-label="Close response dialog" onClick={onClose} className="grid h-9 w-9 shrink-0 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </div>

        <label className="mt-4 block text-xs font-bold text-[#334155]">
          How available are you for this request?
          <select
            value={draft.status}
            onChange={(event) => onChange({ ...draft, status: event.target.value as AvailabilityStatus })}
            className="mt-2 h-11 w-full rounded border border-[#CBD5E1] bg-white px-3 text-sm font-semibold outline-none focus:border-[#0386FF]"
          >
            <option value="available">Available</option>
            <option value="partial">Partially available</option>
          </select>
        </label>
        <p className="mt-2 text-[11px] leading-5 text-[#64748B]">If you are not available, leave this opportunity open and do not submit a response.</p>

        <label className="mt-4 block text-xs font-bold text-[#334155]">
          {requiresComment ? "Comment (required)" : "Comment (optional)"}
          <textarea
            value={draft.comment}
            onChange={(event) => onChange({ ...draft, comment: event.target.value })}
            rows={3}
            placeholder={requiresComment ? "Example: Not available Tuesday 6 PM due to another class." : "Any note for admin..."}
            className="mt-2 w-full rounded border border-[#CBD5E1] px-3 py-2 text-sm outline-none focus:border-[#0386FF]"
          />
        </label>

        <SlotPicker job={job} draft={draft} onChange={onChange} />
        <p className="mt-2 text-[11px] leading-5 text-[#64748B]">Admin will review responses and confirm the final match.</p>
        {error ? <p className="mt-3 rounded-lg bg-[#FEE2E2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">{error}</p> : null}

        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={onClose} disabled={submitting} className="min-h-10 rounded-xl px-4 text-sm font-bold text-[#334155] hover:bg-[#F1F5F9]">Cancel</button>
          <button type="button" onClick={onSubmit} disabled={submitting} className="inline-flex min-h-10 items-center justify-center gap-2 rounded-xl bg-[#0386FF] px-5 text-sm font-bold text-white disabled:opacity-70">
            {submitting ? <RotateCw size={16} className="animate-spin" /> : null}
            Submit
          </button>
        </div>
      </section>
    </div>
  );
}

/**
 * The teacher picks the exact windows they can teach, in preference order.
 *
 * Replaces a free-text "Alternative times" box, which meant admin had to read
 * prose and retype it. Order is meaningful: index 0 is the teacher's first
 * choice. Windows slide by 30 minutes across the family's chosen block, so a
 * 2-hour class in the evening offers 4-6, 4:30-6:30, 5-7 ... not just the two
 * non-overlapping ones.
 */
function SlotPicker({
  job,
  draft,
  onChange,
}: {
  job: JobOpportunity;
  draft: ResponseDraft;
  onChange: (draft: ResponseDraft) => void;
}) {
  const block = blockById(job.block);
  const slots = useMemo(
    () => slotsFor(block, job.sessionMinutes, 30),
    [block, job.sessionMinutes],
  );
  const needed = job.sessionsPerWeek;

  const toggle = (slot: string) => {
    const ranked = draft.rankedSlots.includes(slot)
      ? draft.rankedSlots.filter((item) => item !== slot)
      : [...draft.rankedSlots, slot];
    onChange({ ...draft, rankedSlots: ranked });
  };

  const move = (index: number, direction: -1 | 1) => {
    const target = index + direction;
    if (target < 0 || target >= draft.rankedSlots.length) return;
    const ranked = [...draft.rankedSlots];
    [ranked[index], ranked[target]] = [ranked[target], ranked[index]];
    onChange({ ...draft, rankedSlots: ranked });
  };

  if (!block || slots.length === 0) {
    return (
      <div className="mt-4 rounded-[10px] border border-[#E2E8F0] bg-[#FAFBFC] p-3">
        <p className="text-xs font-bold text-[#334155]">Pick the slots you can teach</p>
        <p className="mt-1 text-[11px] leading-5 text-[#64748B]">
          {block
            ? `A session of ${sessionLabel(job.sessionMinutes)} does not fit inside ${block.label.toLowerCase()}, ${blockRangeLabel(block)}. Use the comment box above to tell admin what would work.`
            : "This request has no time window recorded, so there are no slots to choose from. Use the comment box above to tell admin when you are free."}
        </p>
      </div>
    );
  }

  return (
    <div className="mt-4 rounded-[10px] border border-[#E2E8F0] bg-[#FAFBFC] p-3">
      <p className="text-xs font-bold text-[#334155]">Pick the slots you can teach</p>
      <p className="mt-0.5 text-[11px] text-[#64748B]">
        {block.label}, {blockRangeLabel(block)} · {sessionLabel(job.sessionMinutes)} per session
        {needed > 0 ? ` · ${needed} a week` : ""}
      </p>

      <div className="mt-2.5 flex flex-wrap gap-1.5">
        {slots.map((slot) => {
          const rank = draft.rankedSlots.indexOf(slot);
          const picked = rank >= 0;
          return (
            <button
              key={slot}
              type="button"
              aria-pressed={picked}
              onClick={() => toggle(slot)}
              className={`inline-flex items-center gap-1.5 rounded-lg border-[1.5px] px-2.5 py-1.5 text-xs transition ${
                picked
                  ? "border-[#10B981] bg-[#D1FAE5] font-bold text-[#065F46]"
                  : "border-[#E2E8F0] bg-white font-medium text-[#475569] hover:bg-slate-50"
              }`}
            >
              {picked ? (
                <span className="grid h-4 w-4 place-items-center rounded-full bg-[#065F46] text-[10px] font-extrabold text-white">
                  {rank + 1}
                </span>
              ) : null}
              {slot}
            </button>
          );
        })}
      </div>

      {draft.rankedSlots.length > 0 ? (
        <div className="mt-3">
          <p className="text-[11px] font-bold text-[#334155]">Your order of preference</p>
          <div className="mt-1.5 grid gap-1.5">
            {draft.rankedSlots.map((slot, index) => (
              <div
                key={slot}
                className="flex items-center gap-2 rounded-lg border border-[#E2E8F0] bg-white px-2.5 py-1.5"
              >
                <span className="grid h-[18px] w-[18px] shrink-0 place-items-center rounded-full bg-[#10B981] text-[10px] font-extrabold text-white">
                  {index + 1}
                </span>
                <span className="min-w-0 flex-1 truncate text-xs font-semibold text-[#1E293B]">{slot}</span>
                <button
                  type="button"
                  aria-label={`Move ${slot} earlier`}
                  onClick={() => move(index, -1)}
                  disabled={index === 0}
                  className="grid h-[26px] w-[26px] place-items-center rounded text-[#64748B] disabled:text-[#CBD5E1]"
                >
                  <ChevronUp size={15} />
                </button>
                <button
                  type="button"
                  aria-label={`Move ${slot} later`}
                  onClick={() => move(index, 1)}
                  disabled={index === draft.rankedSlots.length - 1}
                  className="grid h-[26px] w-[26px] place-items-center rounded text-[#64748B] disabled:text-[#CBD5E1]"
                >
                  <ChevronDown size={15} />
                </button>
                <button
                  type="button"
                  aria-label={`Remove ${slot}`}
                  onClick={() => toggle(slot)}
                  className="grid h-[26px] w-[26px] place-items-center rounded text-[#64748B] hover:bg-[#FEE2E2] hover:text-[#DC2626]"
                >
                  <X size={15} />
                </button>
              </div>
            ))}
          </div>
          {needed > 0 ? (
            <p
              className={`mt-1.5 text-[11px] font-semibold ${
                draft.rankedSlots.length >= needed ? "text-[#047857]" : "text-[#B45309]"
              }`}
            >
              {draft.rankedSlots.length > needed
                ? `${draft.rankedSlots.length} slots ranked for ${needed} sessions a week — the extras give admin room to fit you in.`
                : draft.rankedSlots.length === needed
                  ? `${draft.rankedSlots.length} slots ranked — that covers the ${needed} sessions a week.`
                  : `Ranked ${draft.rankedSlots.length} of the ${needed} sessions this student needs each week.`}
            </p>
          ) : null}
        </div>
      ) : (
        <p className="mt-2 text-[11px] leading-5 text-[#64748B]">
          Tap the slots that work. The order you tap them is the order we send to admin — you can
          reorder below.
        </p>
      )}
    </div>
  );
}

async function submitTeacherAvailability(job: JobOpportunity, user: User, draft: ResponseDraft) {
  if (!navigator.onLine) throw new Error("You appear to be offline. Reconnect and try again.");
  const normalizedComment = draft.comment.trim();
  const rankedSlots = draft.rankedSlots.map((slot) => slot.trim()).filter(Boolean);
  const jobRef = doc(db, "job_board", job.id);
  const userRef = doc(db, "users", user.uid);
  const responseRef = doc(db, "job_board", job.id, "responses", user.uid);

  await runTransaction(db, async (transaction) => {
    const jobSnap = await transaction.get(jobRef);
    if (!jobSnap.exists()) throw new Error("Job not found.");
    const jobData = jobSnap.data() as Record<string, unknown>;
    const status = stringValue(jobData.status);
    if (status !== "open") {
      throw new Error(status === "closed" ? "This opportunity is closed. Ask an admin to reopen it if needed." : `This opportunity is not open for availability responses (current status: ${status}).`);
    }
    if (!stringValue(jobData.enrollmentId)) throw new Error("Job is missing enrollment reference.");

    const userSnap = await transaction.get(userRef);
    const userData = userSnap.exists() ? (userSnap.data() as Record<string, unknown>) : null;
    const teacherName = teacherNameForResponse(user, userData);
    const teacherTimezone = stringValue(userData?.timezone) || "UTC";
    const existingResponse = await transaction.get(responseRef);
    const previousStatus = existingResponse.exists() ? stringValue((existingResponse.data() as Record<string, unknown>).availabilityStatus) : "";
    const nowTs = Timestamp.fromDate(new Date());

    transaction.set(
      responseRef,
      {
        teacherId: user.uid,
        teacherName,
        teacherEmail: user.email,
        teacherTimezone,
        availabilityStatus: draft.status,
        comment: normalizedComment,
        // Ordered: index 0 is the teacher's first choice.
        rankedSlots,
        // Deprecated. Older responses are still read from it; new ones keep it
        // in step so an admin screen that has not moved over yet still works.
        availableAlternatives: rankedSlots,
        createdAt: existingResponse.exists() ? (existingResponse.data()?.createdAt ?? nowTs) : nowTs,
        updatedAt: nowTs,
        adminRejected: deleteField(),
        adminRejectedAt: deleteField(),
        rejectedByAdminId: deleteField(),
        adminRejectedNote: deleteField(),
      },
      { merge: true },
    );

    const jobUpdates: Record<string, unknown> = {
      lastResponseAt: nowTs,
      lastResponseByTeacherId: user.uid,
    };
    if (previousStatus && previousStatus !== draft.status) jobUpdates[`responseCounts.${previousStatus}`] = increment(-1);
    if (!previousStatus || previousStatus !== draft.status) jobUpdates[`responseCounts.${draft.status}`] = increment(1);
    if (draft.status === "available") {
      jobUpdates.status = "closed";
      jobUpdates.closedReason = "teacher_fully_available";
      jobUpdates.closedAt = nowTs;
    }
    transaction.update(jobRef, jobUpdates);
  });
}

async function withdrawTeacherFromJob(jobId: string, user: User) {
  if (!navigator.onLine) throw new Error("You appear to be offline. Reconnect and try again.");
  const jobRef = doc(db, "job_board", jobId);
  const userRef = doc(db, "users", user.uid);
  const notificationRef = doc(collection(db, "admin_notifications"));

  await runTransaction(db, async (transaction) => {
    const jobSnap = await transaction.get(jobRef);
    if (!jobSnap.exists()) throw new Error("Job not found.");
    const jobData = jobSnap.data() as Record<string, unknown>;
    if (stringValue(jobData.acceptedByTeacherId) !== user.uid) {
      throw new Error("You can only withdraw from jobs you accepted.");
    }
    if (stringValue(jobData.status) !== "accepted") {
      throw new Error("Can only withdraw from accepted jobs.");
    }

    const enrollmentId = stringValue(jobData.enrollmentId);
    if (!enrollmentId) throw new Error("Job is missing enrollment reference.");
    const enrollmentRef = doc(db, "enrollments", enrollmentId);
    const userSnap = await transaction.get(userRef);
    const userData = userSnap.exists() ? (userSnap.data() as Record<string, unknown>) : null;
    const teacherName = teacherNameForResponse(user, userData);
    const nowTs = Timestamp.fromDate(new Date());

    transaction.update(jobRef, {
      status: "open",
      acceptedByTeacherId: null,
      acceptedAt: deleteField(),
      teacherSelectedTimes: deleteField(),
      withdrawnAt: nowTs,
      withdrawnByTeacherId: user.uid,
      withdrawalHistory: arrayUnion({
        teacherId: user.uid,
        teacherName,
        withdrawnAt: nowTs,
      }),
    });

    transaction.update(enrollmentRef, {
      "metadata.status": "broadcasted",
      "metadata.matchedTeacherId": null,
      "metadata.matchedTeacherName": deleteField(),
      "metadata.matchedAt": deleteField(),
      "metadata.teacherSelectedTimes": deleteField(),
      "metadata.lastWithdrawnBy": user.uid,
      "metadata.lastWithdrawnAt": nowTs,
      "metadata.actionHistory": arrayUnion({
        action: "teacher_withdrawn",
        status: "broadcasted",
        teacherId: user.uid,
        teacherName,
        timestamp: nowTs,
      }),
    });

    transaction.set(notificationRef, {
      type: "job_withdrawn",
      jobId,
      teacherId: user.uid,
      teacherName,
      enrollmentId,
      studentName: stringValue(jobData.studentName) || "Student",
      subject: stringValue(jobData.subject) || "Subject",
      read: false,
      createdAt: nowTs,
      message: `${teacherName} has withdrawn from teaching ${stringValue(jobData.studentName) || "Student"} (${stringValue(jobData.subject) || "Subject"}). Job is now re-open.`,
      action_required: false,
    });
  });
}

function normalizeJob(id: string, data: Record<string, unknown>): JobOpportunity {
  return {
    id,
    enrollmentId: stringValue(data.enrollmentId),
    studentName: stringValue(data.studentName),
    studentAge: stringValue(data.studentAge),
    subject: stringValue(data.subject),
    subjectDisplayName: stringValue(data.subject_display_name),
    gradeLevel: stringValue(data.gradeLevel),
    days: arrayOfStrings(data.days),
    timeSlots: arrayOfStrings(data.timeSlots),
    timeZone: stringValue(data.timeZone) || "UTC",
    // `timeOfDayPreference` is what enrollment has always written; `block` is
    // the new name. Read both so older jobs keep working.
    block: normalizeBlock(data.block ?? data.timeOfDayPreference) ?? "",
    sessionMinutes: numberValue(data.sessionMinutes) || minutesFromDurationLabel(stringValue(data.sessionDuration)),
    sessionsPerWeek: numberValue(data.sessionsPerWeek) || 0,
    status: stringValue(data.status) || "open",
    createdAt: dateValue(data.createdAt) ?? new Date(),
    acceptedByTeacherId: stringValue(data.acceptedByTeacherId),
    acceptedAt: dateValue(data.acceptedAt),
    sessionDuration: stringValue(data.sessionDuration),
    classType: stringValue(data.classType),
    scheduleTimezoneRef: stringValue(data.scheduleTimezoneRef),
    adminNotesForTeachers: stringValue(data.adminNotesForTeachers),
    targetTeacherIds: arrayOfStrings(data.targetTeacherIds),
    teacherSelectedTimes: recordOfStrings(data.teacherSelectedTimes),
  };
}

function normalizeResponse(data: Record<string, unknown>): TeacherResponse {
  return {
    availabilityStatus: stringValue(data.availabilityStatus),
    comment: stringValue(data.comment),
  };
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

function teacherNameForResponse(user: User, data: UserRecord | null) {
  const profileName = data ? [stringValue(data.first_name), stringValue(data.last_name)].filter(Boolean).join(" ") : "";
  return profileName || user.displayName?.trim() || user.email || "Teacher";
}

function displaySubject(job: JobOpportunity) {
  return job.subjectDisplayName || job.subject || "Program";
}

function durationDisplay(value: string) {
  const normalized = value.toLowerCase();
  if (!normalized) return "60 min";
  if (normalized.includes("1 hr 30")) return "90 min";
  if (normalized.includes("2 hr 30")) return "150 min";
  if (normalized.includes("30 mins")) return "30 min";
  if (normalized.includes("1 hr")) return "60 min";
  if (normalized.includes("2 hrs")) return "120 min";
  if (normalized.includes("3 hrs")) return "180 min";
  if (normalized.includes("4 hrs")) return "240 min";
  const match = normalized.match(/(\d+)/);
  return match ? `${match[1]} min` : value;
}

function timezoneAbbr(value: string) {
  const normalized = value || "UTC";
  if (normalized === "UTC") return "UTC";
  return normalized.split("/").pop()?.replace(/_/g, " ") || normalized;
}

function formatMonthDay(value: Date) {
  return value.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function formatFullDate(value: Date) {
  return value.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
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
  if (!single) return [];
  return single.split(",").map((item) => item.trim()).filter(Boolean);
}

function recordOfStrings(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .map(([key, nextValue]) => [key, stringValue(nextValue)] as const)
      .filter(([, nextValue]) => Boolean(nextValue)),
  );
}

function numberValue(value: unknown) {
  const n = typeof value === "number" ? value : Number.parseFloat(String(value ?? ""));
  return Number.isFinite(n) ? n : 0;
}

/**
 * Older jobs store the session as a label ("1 hr", "90 mins"). New ones store
 * minutes. Parse the label so an existing job still produces slots.
 */

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function jobActionError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String(error || "");
  if (/permission-denied|insufficient permissions/i.test(message)) return "You do not have permission to update this opportunity. Refresh the page or contact an administrator.";
  if (/unavailable|network|offline/i.test(message) || !navigator.onLine) return "You appear to be offline. Reconnect and try again.";
  return message.replace(/^Firebase:\s*/i, "").trim() || fallback;
}

function initialsFromName(name: string) {
  const parts = name.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "TE";
}
