"use client";

import { onAuthStateChanged } from "firebase/auth";
import { collection, doc, getDoc, getDocs, query, serverTimestamp, setDoc, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useState } from "react";
import { ArrowRight, Check, Loader2, Play, RotateCcw, X } from "lucide-react";
import { auth, db, functions } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";

type Category = {
  id: string;
  name: string;
  nameAr: string;
  description: string;
  color: string;
  emoji: string;
};

type Question = {
  id: string;
  category: string;
  difficulty: string;
  question: string;
  options: string[];
  correctAnswer: number;
  explanation?: string;
};

/**
 * Mirrors QuizCategory.defaultCategories in
 * lib/features/quiz/models/quiz_category.dart — same ids, names, Arabic names,
 * descriptions and accent colours, in the same order. The ids matter: they key
 * the question asset, the Firestore question bank, and the competition.
 */
const CATEGORIES: Category[] = [
  { id: "five_pillars", name: "Five Pillars", nameAr: "أركان الإسلام", description: "Learn about the 5 pillars of Islam", color: "#4CAF50", emoji: "🕌" },
  { id: "prophets", name: "Prophets", nameAr: "الأنبياء", description: "Stories of the Prophets", color: "#2196F3", emoji: "📖" },
  { id: "quran_basics", name: "Quran Basics", nameAr: "أساسيات القرآن", description: "Learn about the Holy Quran", color: "#9C27B0", emoji: "📕" },
  { id: "daily_duas", name: "Daily Duas", nameAr: "أدعية يومية", description: "Everyday prayers and supplications", color: "#FF9800", emoji: "🤲" },
  { id: "islamic_history", name: "Islamic History", nameAr: "التاريخ الإسلامي", description: "Important events in Islamic history", color: "#795548", emoji: "🏛️" },
  { id: "arabic_basics", name: "Arabic Letters", nameAr: "الحروف العربية", description: "Learn Arabic letters and words", color: "#00BCD4", emoji: "🔤" },
  { id: "seerah", name: "Life of the Prophet", nameAr: "السيرة النبوية", description: "The life story of Prophet Muhammad ﷺ", color: "#009688", emoji: "⭐" },
  { id: "sahaba", name: "The Companions", nameAr: "الصحابة", description: "The companions of the Prophet ﷺ", color: "#3F51B5", emoji: "👥" },
  { id: "islamic_manners", name: "Islamic Manners", nameAr: "الآداب الإسلامية", description: "Good manners and character (adab)", color: "#E91E63", emoji: "💝" },
];

/**
 * Monthly Bayannah Challenge.
 *
 * Read from the same getQuizCompetitionLeaderboard callable the Flutter home
 * screen uses; the copy below is the app's own l10n strings verbatim so the two
 * banners read identically. Answers are already recorded per question by the
 * play flow — this only surfaces the standings.
 */
type Competition = {
  monthKey: string;
  countingStart: string;
  countingEnd: string;
  lifetimeWins: number;
  divisionId: string;
  requiresDivision: boolean;
  minimumQuestions: number;
  minimumActiveDays: number;
  minimumAccuracy: number;
  minimumEligibleParticipants: number;
  requiredCategoryCount: number;
  answeredCount: number;
  activeDays: number;
  categoriesAttempted: number;
  rank: number;
};

/** quizCompetitionDivision* in app_en.arb. */
const DIVISION_LABELS: Record<string, string> = {
  early_learners: "Early Learners (under age 8)",
  juniors: "Juniors (ages 8\u201311)",
  youth: "Youth (ages 12\u201317)",
  adults: "Adults (ages 18+)",
  unassigned: "Needs age-division assignment",
};

/** QuizService._shuffleQuestions takes 10 per session. */
const QUESTIONS_PER_SESSION = 10;

export default function StudentQuizPage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [uid, setUid] = useState("");
  const [active, setActive] = useState<Category | null>(null);
  const [competition, setCompetition] = useState<Competition | null>(null);

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setAccess("signedOut");
        return;
      }
      const session = await resolveStudentSession(nextUser);
      if (!session.isStudent) {
        setAccess("denied");
        return;
      }
      setSummary(session.summary);
      setIsAdultStudent(session.isAdultStudent);
      setUid(nextUser.uid);
      setAccess("allowed");
      setCompetition(await loadCompetition());
    });
  }, []);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  return (
    <StudentShell activeLabel="Quiz" breadcrumb="Learning / Quiz" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="mx-auto w-full max-w-[1180px] px-4 py-6 md:px-6">
        {active ? (
          <QuizPlay category={active} uid={uid} onExit={() => setActive(null)} />
        ) : (
          <CategoryBrowse onPlay={setActive} competition={competition} />
        )}
      </div>
    </StudentShell>
  );
}

function CategoryBrowse({ onPlay, competition }: { onPlay: (category: Category) => void; competition: Competition | null }) {
  return (
    <>
      <header className="flex items-center gap-4">
        <span className="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-[#7C3AED] text-2xl">🧠</span>
        <div>
          <h1 className="text-[28px] font-black leading-tight text-[#0F172A]">Islamic Quiz</h1>
          <p className="text-sm font-semibold text-[#64748B]">Test your knowledge</p>
        </div>
      </header>

      <div className="mt-5 flex items-center gap-3 rounded-2xl bg-[linear-gradient(120deg,#16A34A_0%,#22C55E_100%)] px-5 py-4 text-white">
        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white/25 text-sm font-black">?</span>
        <div>
          <p className="text-base font-black">Choose a Category</p>
          <p className="text-xs font-semibold text-white/90">{CATEGORIES.length} categories · 350+ questions</p>
        </div>
      </div>

      {competition ? <CompetitionBanner competition={competition} /> : null}

      <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {CATEGORIES.map((category) => (
          <article
            key={category.id}
            className="flex flex-col rounded-2xl border border-black/5 bg-white p-4 text-center shadow-[0_6px_18px_rgba(15,23,42,0.05)]"
          >
            <span
              className="mx-auto grid h-12 w-12 place-items-center rounded-2xl text-2xl"
              style={{ backgroundColor: `${category.color}1f` }}
              aria-hidden="true"
            >
              {category.emoji}
            </span>
            <h2 className="mt-3 text-sm font-black text-[#0F172A]">{category.name}</h2>
            <p className="mt-0.5 text-xs font-semibold text-[#64748B]" dir="rtl">
              {category.nameAr}
            </p>
            <p className="mt-2 text-[11px] leading-4 text-[#94A3B8]">{category.description}</p>
            <div className="flex-1" />
            <button
              type="button"
              onClick={() => onPlay(category)}
              className="mt-3 inline-flex min-h-9 items-center justify-center gap-1.5 self-center rounded-full px-4 text-xs font-black text-white"
              style={{ backgroundColor: category.color }}
            >
              <Play size={14} />
              Play
            </button>
          </article>
        ))}
      </div>
    </>
  );
}


function CompetitionBanner({ competition }: { competition: Competition }) {
  const division = DIVISION_LABELS[competition.divisionId] ?? DIVISION_LABELS.unassigned;
  const accuracyPct = Math.round(competition.minimumAccuracy * 100);

  return (
    <section className="mt-4 rounded-2xl bg-[linear-gradient(120deg,#6D28D9_0%,#7C3AED_55%,#8B5CF6_100%)] p-5 text-white">
      <div className="flex items-start gap-3">
        <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-white/15 text-xl" aria-hidden="true">
          🏆
        </span>
        <div className="min-w-0">
          <h2 className="text-lg font-black">Monthly Bayannah Challenge</h2>
          <p className="mt-0.5 text-xs font-semibold text-white/85">Competition month: {competition.monthKey}</p>
          {competition.countingStart && competition.countingEnd ? (
            <p className="text-xs font-semibold text-white/70">
              Answers count from {competition.countingStart} through {competition.countingEnd}.
            </p>
          ) : null}
        </div>
      </div>

      <p className="mt-3 text-sm font-black text-white">Lifetime wins: {competition.lifetimeWins}</p>
      <p className="mt-2 text-sm font-black text-[#FDE68A]">Division: {division}</p>

      {competition.requiresDivision ? (
        <p className="mt-2 text-sm font-semibold text-white/90">
          Your answers are being saved, but you cannot be ranked until your age division is set.
        </p>
      ) : (
        <p className="mt-2 text-sm leading-6 text-white/90">
          You compete only in your age division. Qualify with {competition.minimumQuestions} unique questions over{" "}
          {competition.minimumActiveDays} days and at least {accuracyPct}% accuracy. A division needs{" "}
          {competition.minimumEligibleParticipants} eligible students. Exact ties share the win.
        </p>
      )}

      <p className="mt-2 text-sm font-black text-[#FDE68A]">
        Explore every category to qualify: {competition.categoriesAttempted}/{competition.requiredCategoryCount} completed.
      </p>

      <div className="mt-4 grid grid-cols-3 gap-3">
        <Stat label="Questions" value={String(competition.answeredCount)} />
        <Stat label="Active days" value={String(competition.activeDays)} />
        <Stat label="Rank" value={competition.rank > 0 ? `#${competition.rank}` : "—"} />
      </div>
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-white/12 px-3 py-3 text-center">
      <div className="text-xl font-black leading-none">{value}</div>
      <div className="mt-1 text-[11px] font-semibold text-white/75">{label}</div>
    </div>
  );
}

/**
 * Best-effort: a student with no competition record yet, or a transient
 * failure, simply gets no banner rather than a broken quiz page.
 */
async function loadCompetition(): Promise<Competition | null> {
  try {
    const result = await httpsCallable(functions, "getQuizCompetitionLeaderboard")({});
    const data = (result.data ?? {}) as Record<string, unknown>;
    if (!data || Object.keys(data).length === 0) return null;
    const self = (data.self ?? {}) as Record<string, unknown>;
    return {
      monthKey: String(data.monthKey ?? ""),
      countingStart: String(data.countingStartDate ?? ""),
      countingEnd: String(data.countingEndDate ?? ""),
      lifetimeWins: Number(data.lifetimeWins ?? 0),
      divisionId: String(data.divisionId ?? "unassigned"),
      requiresDivision: data.requiresDivision === true,
      minimumQuestions: Number(data.minimumQuestions ?? 20),
      minimumActiveDays: Number(data.minimumActiveDays ?? 3),
      minimumAccuracy: Number(data.minimumAccuracy ?? 0.5),
      minimumEligibleParticipants: Number(data.minimumEligibleParticipants ?? 2),
      requiredCategoryCount: Number(data.requiredCategoryCount ?? CATEGORIES.length),
      answeredCount: Number(self.answeredCount ?? 0),
      activeDays: Number(self.activeDays ?? 0),
      categoriesAttempted: Number(self.categoriesAttemptedCount ?? 0),
      rank: Number(self.rank ?? 0),
    };
  } catch {
    return null;
  }
}

type PlayState = "loading" | "playing" | "finished" | "error";

function QuizPlay({ category, uid, onExit }: { category: Category; uid: string; onExit: () => void }) {
  const [state, setState] = useState<PlayState>("loading");
  const [questions, setQuestions] = useState<Question[]>([]);
  const [index, setIndex] = useState(0);
  const [selected, setSelected] = useState<number | null>(null);
  const [correctCount, setCorrectCount] = useState(0);
  const [error, setError] = useState("");
  const [seenIds, setSeenIds] = useState<Set<string>>(new Set());
  const [skillLevel, setSkillLevel] = useState("easy");
  const [poolSize, setPoolSize] = useState(0);

  const start = useCallback(async () => {
    setState("loading");
    setError("");
    try {
      const progress = await loadProgress(uid, category.id);
      setSeenIds(progress.seenIds);
      setSkillLevel(progress.skillLevel);

      const pool = await loadQuestionPool(category.id);
      setPoolSize(pool.length);
      if (pool.length === 0) throw new Error("No questions available for this category yet.");

      // Prefer unseen questions, exactly like the Flutter rotation, then top up
      // from the full pool if the student has nearly exhausted it.
      const unseen = pool.filter((question) => !progress.seenIds.has(question.id));
      const chosen = shuffle(unseen.length >= QUESTIONS_PER_SESSION ? unseen : pool).slice(0, QUESTIONS_PER_SESSION);

      setQuestions(chosen);
      setIndex(0);
      setSelected(null);
      setCorrectCount(0);
      setState("playing");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Could not start the quiz.");
      setState("error");
    }
  }, [category.id, uid]);

  useEffect(() => {
    void start();
  }, [start]);

  const question = questions[index];

  async function choose(option: number) {
    if (selected !== null || !question) return;
    setSelected(option);
    if (option === question.correctAnswer) setCorrectCount((current) => current + 1);

    // Every answer feeds the Monthly Bayannah Challenge. The Flutter play
    // screen calls the same callable per answer; skipping it would leave web
    // players silently unable to qualify. Best-effort, like Flutter: a failure
    // here must not interrupt the quiz.
    try {
      await httpsCallable(functions, "recordQuizCompetitionAnswer")({
        questionId: question.id,
        categoryId: category.id,
        selectedAnswerIndex: option,
      });
    } catch {}
  }

  async function next() {
    if (!question) return;
    if (index + 1 >= questions.length) {
      await saveProgress(uid, category.id, seenIds, questions.map((item) => item.id), skillLevel, poolSize);
      setState("finished");
      return;
    }
    setIndex((current) => current + 1);
    setSelected(null);
  }

  if (state === "loading") {
    return (
      <div className="grid min-h-[50vh] place-items-center text-[#64748B]">
        <span className="inline-flex items-center gap-2 text-sm font-bold">
          <Loader2 className="animate-spin" size={18} />
          Loading {category.name}…
        </span>
      </div>
    );
  }

  if (state === "error") {
    return (
      <div className="mx-auto max-w-md rounded-2xl border border-red-200 bg-red-50 p-6 text-center">
        <p className="text-sm font-bold text-red-700">{error}</p>
        <button type="button" onClick={onExit} className="mt-4 inline-flex min-h-10 items-center rounded-xl bg-white px-4 text-sm font-bold text-[#334155]">
          Back to categories
        </button>
      </div>
    );
  }

  if (state === "finished") {
    const pct = questions.length > 0 ? Math.round((correctCount / questions.length) * 100) : 0;
    return (
      <div className="mx-auto max-w-md rounded-3xl border border-black/5 bg-white p-8 text-center shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
        <span className="mx-auto grid h-16 w-16 place-items-center rounded-full text-3xl" style={{ backgroundColor: `${category.color}1f` }}>
          {category.emoji}
        </span>
        <h2 className="mt-4 text-2xl font-black text-[#0F172A]">
          {correctCount} / {questions.length}
        </h2>
        <p className="mt-1 text-sm font-bold text-[#64748B]">{pct}% correct in {category.name}</p>
        <div className="mt-6 flex justify-center gap-2">
          <button type="button" onClick={() => void start()} className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#7C3AED] px-4 text-sm font-black text-white">
            <RotateCcw size={16} />
            Play again
          </button>
          <button type="button" onClick={onExit} className="inline-flex min-h-10 items-center rounded-xl border border-[#E2E8F0] px-4 text-sm font-bold text-[#334155]">
            Categories
          </button>
        </div>
      </div>
    );
  }

  if (!question) return null;
  const answered = selected !== null;

  return (
    <div className="mx-auto max-w-2xl">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <span className="grid h-9 w-9 place-items-center rounded-xl text-lg" style={{ backgroundColor: `${category.color}1f` }}>
            {category.emoji}
          </span>
          <span className="text-sm font-black text-[#0F172A]">{category.name}</span>
        </div>
        <button type="button" onClick={onExit} aria-label="Leave quiz" className="grid h-9 w-9 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]">
          <X size={18} />
        </button>
      </div>

      <div className="mt-3 h-2 overflow-hidden rounded-full bg-[#E2E8F0]">
        <div className="h-full rounded-full transition-all" style={{ width: `${((index + 1) / questions.length) * 100}%`, backgroundColor: category.color }} />
      </div>
      <p className="mt-2 text-xs font-bold text-[#94A3B8]">
        Question {index + 1} of {questions.length}
      </p>

      <h2 className="mt-4 text-xl font-black leading-snug text-[#0F172A]">{question.question}</h2>

      <div className="mt-4 grid gap-2.5">
        {question.options.map((option, optionIndex) => {
          const isCorrect = optionIndex === question.correctAnswer;
          const isChosen = optionIndex === selected;
          let tone = "border-[#E2E8F0] bg-white text-[#0F172A] hover:border-[#CBD5E1]";
          if (answered && isCorrect) tone = "border-[#16A34A] bg-[#F0FDF4] text-[#166534]";
          else if (answered && isChosen) tone = "border-[#DC2626] bg-[#FEF2F2] text-[#991B1B]";
          else if (answered) tone = "border-[#E2E8F0] bg-white text-[#94A3B8]";
          return (
            <button
              key={optionIndex}
              type="button"
              disabled={answered}
              onClick={() => void choose(optionIndex)}
              className={`flex min-h-12 items-center justify-between gap-3 rounded-2xl border px-4 text-left text-sm font-bold transition ${tone}`}
            >
              <span>{option}</span>
              {answered && isCorrect ? <Check size={18} /> : answered && isChosen ? <X size={18} /> : null}
            </button>
          );
        })}
      </div>

      {answered && question.explanation ? (
        <p className="mt-4 rounded-2xl border border-[#E2E8F0] bg-[#F8FAFC] px-4 py-3 text-sm leading-6 text-[#475569]">{question.explanation}</p>
      ) : null}

      {answered ? (
        <button
          type="button"
          onClick={() => void next()}
          className="mt-4 inline-flex min-h-11 items-center gap-2 rounded-xl px-5 text-sm font-black text-white"
          style={{ backgroundColor: category.color }}
        >
          {index + 1 >= questions.length ? "Finish" : "Next question"}
          <ArrowRight size={16} />
        </button>
      ) : null}
    </div>
  );
}

/**
 * Bundled JSON bank merged with admin-approved Firestore questions, matching
 * QuizService._loadAllQuestions. The Firestore half is best-effort so a network
 * or rules problem still leaves a playable quiz.
 */
async function loadQuestionPool(categoryId: string): Promise<Question[]> {
  const byId = new Map<string, Question>();

  try {
    const response = await fetch(`/assets/quizzes/${categoryId}.json`, { cache: "force-cache" });
    if (response.ok) {
      const payload = (await response.json()) as { questions?: unknown };
      if (Array.isArray(payload.questions)) {
        payload.questions.forEach((raw) => {
          const question = normalizeQuestion(raw);
          if (question) byId.set(question.id, question);
        });
      }
    }
  } catch {}

  try {
    const snap = await getDocs(
      query(collection(db, "quiz_questions"), where("category", "==", categoryId), where("status", "==", "approved")),
    );
    snap.docs.forEach((entry) => {
      const question = normalizeQuestion({ id: entry.id, ...(entry.data() as Record<string, unknown>) });
      if (question && !byId.has(question.id)) byId.set(question.id, question);
    });
  } catch {}

  return [...byId.values()];
}

function normalizeQuestion(raw: unknown): Question | null {
  if (!raw || typeof raw !== "object") return null;
  const data = raw as Record<string, unknown>;
  const options = Array.isArray(data.options) ? data.options.map((item) => String(item)) : [];
  const correct = Number(data.correctAnswer);
  const id = stringValue(data.id);
  const text = stringValue(data.question);
  if (!id || !text || options.length === 0 || !Number.isInteger(correct)) return null;
  return {
    id,
    category: stringValue(data.category),
    difficulty: stringValue(data.difficulty) || "easy",
    question: text,
    options,
    correctAnswer: correct,
    explanation: stringValue(data.explanation) || undefined,
  };
}

async function loadProgress(uid: string, categoryId: string) {
  try {
    const snap = await getDoc(doc(db, "quiz_progress", uid));
    const categories = snap.data()?.categories as Record<string, unknown> | undefined;
    const entry = categories?.[categoryId] as Record<string, unknown> | undefined;
    const seen = Array.isArray(entry?.seen_ids) ? entry.seen_ids.map((item) => String(item)) : [];
    return { seenIds: new Set(seen), skillLevel: stringValue(entry?.skill_level) || "easy" };
  } catch {
    return { seenIds: new Set<string>(), skillLevel: "easy" };
  }
}

/**
 * Writes back the same shape QuizProgressService uses, including its rotation
 * rule: once the whole pool has been seen, start again from this session so
 * questions become available rather than repeating forever.
 *
 * skill_level is written back unchanged — the adaptive tier is Flutter's to
 * advance, and overwriting it here would regress a student's difficulty.
 */
async function saveProgress(
  uid: string,
  categoryId: string,
  previouslySeen: Set<string>,
  askedIds: string[],
  skillLevel: string,
  poolSize: number,
) {
  if (!uid) return;
  let seen = new Set([...previouslySeen, ...askedIds]);
  if (poolSize > 0 && seen.size >= poolSize) seen = new Set(askedIds);
  try {
    await setDoc(
      doc(db, "quiz_progress", uid),
      { categories: { [categoryId]: { seen_ids: [...seen], skill_level: skillLevel, updated_at: serverTimestamp() } } },
      { merge: true },
    );
  } catch {}
}

function shuffle<T>(items: T[]): T[] {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "ST";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
