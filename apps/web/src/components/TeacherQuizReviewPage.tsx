"use client";

import { onAuthStateChanged } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useState } from "react";
import { Check, ClipboardCheck, Loader2, RefreshCw, Send, Sparkles, Users, X } from "lucide-react";
import { auth, functions } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell } from "@/components/TeacherDashboardHome";
import { useT } from "@/lib/i18n";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type TeacherSummary = { displayName: string; firstName: string; initials: string };

type ReviewQuestion = {
  id: string;
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
  difficulty: string;
  category: string;
};

type RecentReview = { question: string; status: string; reviewerName: string; reviewerRole: string };

type ReviewQueue = {
  questions: ReviewQuestion[];
  recentReviews: RecentReview[];
  canManageReviewers: boolean;
  reviewerTeacherIds: string[];
};

/** Same ids, names and colours as `QuizCategory.defaultCategories` in the app. */
const CATEGORIES: Record<string, { name: string; color: string }> = {
  five_pillars: { name: "Five Pillars", color: "#4CAF50" },
  prophets: { name: "Prophets", color: "#2196F3" },
  quran_basics: { name: "Quran Basics", color: "#9C27B0" },
  daily_duas: { name: "Daily Duas", color: "#FF9800" },
  islamic_history: { name: "Islamic History", color: "#795548" },
  arabic_basics: { name: "Arabic Letters", color: "#00BCD4" },
  seerah: { name: "Life of the Prophet", color: "#009688" },
  sahaba: { name: "The Companions", color: "#3F51B5" },
  islamic_manners: { name: "Islamic Manners", color: "#E91E63" },
};

const difficultyColor = (difficulty: string) =>
  difficulty === "hard" ? "#EF4444" : difficulty === "medium" ? "#F59E0B" : "#10B981";

const str = (v: unknown) => (typeof v === "string" ? v : "");
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);

function normalizeQueue(raw: unknown): ReviewQueue {
  const data = (raw ?? {}) as Record<string, unknown>;
  const list = (key: string) => (Array.isArray(data[key]) ? (data[key] as unknown[]) : []);
  return {
    questions: list("questions")
      .filter((q): q is Record<string, unknown> => typeof q === "object" && q !== null)
      .map((q) => ({
        id: str(q.id),
        question: str(q.question),
        options: Array.isArray(q.options) ? q.options.map((o) => str(o)) : [],
        correctAnswer: num(q.correctAnswer),
        explanation: str(q.explanation),
        difficulty: str(q.difficulty) || "easy",
        category: str(q.category),
      })),
    recentReviews: list("recentReviews")
      .filter((r): r is Record<string, unknown> => typeof r === "object" && r !== null)
      .map((r) => ({
        question: str(r.question),
        status: str(r.status),
        reviewerName: str(r.reviewerName),
        reviewerRole: str(r.reviewerRole),
      })),
    canManageReviewers: data.canManageReviewers === true,
    reviewerTeacherIds: list("reviewerTeacherIds").map((v) => str(v)).filter(Boolean),
  };
}

/**
 * AI quiz question review — the web twin of `AdminQuizReviewScreen`.
 *
 * Everything goes through the same callables the app uses, so the rules about
 * who may review are the server's, not this page's: `getQuizReviewQueue`
 * refuses a teacher who has not been added as a reviewer, and the
 * generate/send/reviewers actions only appear when the server says the caller
 * may manage reviewers.
 */
export function TeacherQuizReviewPage() {
  const t = useT();
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [queue, setQueue] = useState<ReviewQueue | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [message, setMessage] = useState("");
  const [busyId, setBusyId] = useState("");
  const [generating, setGenerating] = useState(false);
  const [sendingBatch, setSendingBatch] = useState(false);
  const [rejecting, setRejecting] = useState<ReviewQuestion | null>(null);

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setLoadError("");
    try {
      const result = await httpsCallable(functions, "getQuizReviewQueue")();
      setQueue(normalizeQueue(result.data));
    } catch {
      // The callable refuses anyone who is not a reviewer; say so the way the app does.
      setLoadError("Your administrator must add you as a quiz reviewer before you can review questions.");
      setQueue(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      if (!nextUser) {
        setAccess("signedOut");
        return;
      }
      setAccess("checking");
      try {
        const allowed = await isCurrentUserTeacher(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          return;
        }
        const record = (await getCurrentUserRecord(nextUser)) as Record<string, unknown> | null;
        if (!mounted) return;
        const name = `${str(record?.first_name)} ${str(record?.last_name)}`.trim() || nextUser.displayName || nextUser.email || "Teacher";
        const parts = name.split(/\s+/).filter(Boolean);
        setSummary({
          displayName: name,
          firstName: parts[0] ?? name,
          initials: parts.slice(0, 2).map((p) => p[0]?.toUpperCase() ?? "").join("") || "TE",
        });
        setAccess("allowed");
        void loadQueue();
      } catch {
        if (mounted) setAccess("denied");
      }
    });
  }, [loadQueue]);

  async function setStatus(questionId: string, status: "approved" | "rejected", rejectionReason?: string) {
    setBusyId(questionId);
    setMessage("");
    try {
      await httpsCallable(functions, "reviewQuizQuestion")({
        questionId,
        status,
        ...(rejectionReason ? { rejectionReason } : {}),
      });
      setMessage(status === "approved" ? t("Question approved") : t("Question rejected"));
      await loadQueue();
    } catch (error) {
      setMessage(`Action failed: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setBusyId("");
    }
  }

  async function generateNow() {
    setGenerating(true);
    setMessage("");
    try {
      await httpsCallable(functions, "generateQuizQuestionsNow")();
      setMessage("Generating new questions… they will appear here in a minute.");
    } catch (error) {
      setMessage(`Action failed: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setGenerating(false);
    }
  }

  async function sendStudentBatch() {
    setSendingBatch(true);
    setMessage("");
    try {
      await httpsCallable(functions, "sendQuizStudentApprovalBatchNow")();
      setMessage("The approved-question batch was sent to students.");
    } catch (error) {
      setMessage(`Action failed: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setSendingBatch(false);
    }
  }

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  const pending = queue?.questions ?? [];

  return (
    <TeacherShell activeLabel="Quiz Review" breadcrumb="Communication / Quiz Review" summary={summary}>
      <main className="min-h-screen bg-[#F8FAFC] pb-16 text-[#0F172A] lg:min-h-[calc(100vh-56px)]">
        <section className="mx-auto max-w-[1100px] px-5 py-6 lg:px-6">
          <header className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h1 className="text-[22px] font-black text-[#1F2937]">{t("AI Quiz Question Review")}</h1>
              <p className="mt-1 text-sm font-semibold text-[#64748B]">{pending.length} {t("pending")}</p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                onClick={() => void loadQueue()}
                disabled={loading}
                className="inline-flex min-h-10 items-center gap-2 rounded-xl border border-black/10 px-3 text-sm font-semibold text-[#334155] hover:bg-white disabled:opacity-60"
              >
                <RefreshCw size={16} className={loading ? "animate-spin" : ""} />
                {t("Refresh")}
              </button>
              {queue?.canManageReviewers ? (
                <>
                  <button
                    type="button"
                    onClick={() => void generateNow()}
                    disabled={generating}
                    className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#7C3AED] px-3 text-sm font-semibold text-white disabled:opacity-60"
                  >
                    {generating ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
                    {t("Generate questions")}
                  </button>
                  <button
                    type="button"
                    onClick={() => void sendStudentBatch()}
                    disabled={sendingBatch}
                    className="inline-flex min-h-10 items-center gap-2 rounded-xl border border-black/10 px-3 text-sm font-semibold text-[#334155] hover:bg-white disabled:opacity-60"
                  >
                    {sendingBatch ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
                    {t("Send student batch")}
                  </button>
                  <a
                    href="/app/"
                    className="inline-flex min-h-10 items-center gap-2 rounded-xl border border-black/10 px-3 text-sm font-semibold text-[#334155] hover:bg-white"
                  >
                    <Users size={16} />
                    {t("Review teachers")}
                  </a>
                </>
              ) : null}
            </div>
          </header>

          {message ? (
            <p role="status" className="mt-4 rounded-xl bg-[#EEF2FF] px-3 py-2 text-sm font-semibold text-[#3730A3]">
              {message}
            </p>
          ) : null}

          {loading ? (
            <div className="mt-10 grid place-items-center">
              <Loader2 size={26} className="animate-spin text-[#7C3AED]" />
            </div>
          ) : loadError ? (
            <p className="mt-10 text-center text-sm font-semibold leading-6 text-[#64748B]">{t(loadError)}</p>
          ) : pending.length === 0 ? (
            <div className="mt-10 grid place-items-center text-center">
              <ClipboardCheck size={32} className="text-[#CBD5E1]" />
              <p className="mt-3 text-sm font-semibold text-[#64748B]">{t("No pending questions to review.")}</p>
            </div>
          ) : (
            <div className="mt-5 grid gap-4">
              {pending.map((q) => (
                <QuestionCard
                  key={q.id}
                  question={q}
                  busy={busyId === q.id}
                  onApprove={() => void setStatus(q.id, "approved")}
                  onReject={() => setRejecting(q)}
                />
              ))}
            </div>
          )}

          {queue && queue.recentReviews.length > 0 ? (
            <section className="mt-8">
              <h2 className="text-base font-black text-[#0F172A]">{t("Recent decisions")}</h2>
              <ul className="mt-3 grid gap-2">
                {queue.recentReviews.map((r, i) => (
                  <li key={`${r.question}-${i}`} className="rounded-xl border border-[#E2E8F0] bg-white px-3 py-2">
                    <p className="text-sm font-semibold text-[#0F172A]">{r.question}</p>
                    <p className="mt-0.5 text-xs font-semibold text-[#64748B]">
                      {r.status} by {r.reviewerName} ({r.reviewerRole})
                    </p>
                  </li>
                ))}
              </ul>
            </section>
          ) : null}
        </section>

        {rejecting ? (
          <RejectDialog
            question={rejecting}
            onCancel={() => setRejecting(null)}
            onConfirm={async (reason) => {
              const target = rejecting;
              setRejecting(null);
              await setStatus(target.id, "rejected", reason);
            }}
          />
        ) : null}
      </main>
    </TeacherShell>
  );
}

function QuestionCard({
  question,
  busy,
  onApprove,
  onReject,
}: {
  question: ReviewQuestion;
  busy: boolean;
  onApprove: () => void;
  onReject: () => void;
}) {
  const category = CATEGORIES[question.category] ?? { name: question.category || "Uncategorised", color: "#607D8B" };
  return (
    <article className="rounded-2xl border border-[#E2E8F0] bg-white p-5 shadow-[0_3px_12px_rgba(15,23,42,0.04)]">
      <div className="flex flex-wrap items-center gap-2">
        <Chip label={category.name} color={category.color} />
        <Chip label={question.difficulty} color={difficultyColor(question.difficulty)} />
      </div>
      <p className="mt-3 text-[15px] font-bold leading-6 text-[#0F172A]">{question.question}</p>
      <ol className="mt-3 grid gap-1.5">
        {question.options.map((option, index) => {
          const correct = index === question.correctAnswer;
          return (
            <li
              key={`${option}-${index}`}
              className={`flex items-start gap-2 rounded-lg px-2.5 py-1.5 text-sm ${correct ? "bg-[#ECFDF5] font-bold text-[#065F46]" : "text-[#334155]"}`}
            >
              {correct ? <Check size={16} className="mt-0.5 shrink-0 text-[#059669]" /> : <span className="mt-0.5 w-4 shrink-0" />}
              <span>{option}</span>
            </li>
          );
        })}
      </ol>
      {question.explanation ? (
        <p className="mt-3 text-[13px] leading-6 text-[#475569]">{question.explanation}</p>
      ) : null}
      <div className="mt-4 flex flex-wrap justify-end gap-2">
        <button
          type="button"
          onClick={onReject}
          disabled={busy}
          className="inline-flex min-h-10 items-center gap-2 rounded-xl border border-[#FECACA] px-3 text-sm font-semibold text-[#B91C1C] hover:bg-[#FEF2F2] disabled:opacity-60"
        >
          <X size={17} />
          Reject
        </button>
        <button
          type="button"
          onClick={onApprove}
          disabled={busy}
          className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#059669] px-4 text-sm font-semibold text-white disabled:opacity-60"
        >
          {busy ? <Loader2 size={16} className="animate-spin" /> : <Check size={17} />}
          Approve
        </button>
      </div>
    </article>
  );
}

function RejectDialog({
  question,
  onCancel,
  onConfirm,
}: {
  question: ReviewQuestion;
  onCancel: () => void;
  onConfirm: (reason: string) => void | Promise<void>;
}) {
  const [reason, setReason] = useState("");
  const [error, setError] = useState("");
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true" aria-label="Why reject this question?">
      <div className="w-full max-w-[460px] rounded-[20px] bg-white p-5 shadow-[0_24px_60px_rgba(0,0,0,0.32)]">
        <h2 className="text-lg font-bold text-[#111827]">Why reject this question?</h2>
        <p className="mt-2 line-clamp-2 text-[13px] text-[#64748B]">{question.question}</p>
        <label className="mt-4 grid gap-1.5 text-[11px] font-semibold text-[#1E293B]">
          Rejection reason
          <textarea
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            placeholder="For example: duplicate, inaccurate, or unclear"
            className="min-h-[92px] rounded-lg border border-[#CBD5E1] px-3 py-2 text-sm text-[#111827] outline-none focus:border-[#3B82F6]"
          />
        </label>
        {error ? <p role="alert" className="mt-2 text-xs font-semibold text-[#DC2626]">{error}</p> : null}
        <div className="mt-5 flex items-center justify-end gap-2">
          <button type="button" onClick={onCancel} className="px-3 py-2 text-sm font-semibold text-[#475569]">
            Cancel
          </button>
          <button
            type="button"
            onClick={() => {
              if (!reason.trim()) {
                setError("Please provide a reason before rejecting.");
                return;
              }
              void onConfirm(reason.trim());
            }}
            className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#B91C1C] px-4 text-sm font-semibold text-white"
          >
            Reject question
          </button>
        </div>
      </div>
    </div>
  );
}

function Chip({ label, color }: { label: string; color: string }) {
  return (
    <span
      className="inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-black uppercase tracking-[0.04em]"
      style={{ backgroundColor: `${color}1A`, color }}
    >
      {label}
    </span>
  );
}

export default TeacherQuizReviewPage;
