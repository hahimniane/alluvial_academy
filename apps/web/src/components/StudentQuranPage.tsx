"use client";

import { onAuthStateChanged } from "firebase/auth";
import { arrayRemove, arrayUnion, deleteField, doc, getDoc, increment, serverTimestamp, setDoc } from "firebase/firestore";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CheckCircle2, ChevronDown, Circle, Flame, Loader2, Mic, Pause, Play, Repeat, Search, Square, Target, X } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { useT } from "@/lib/i18n";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";
import { RecitationCheck } from "@/components/RecitationCheck";
import { RecitationFollowAlong } from "@/components/RecitationFollowAlong";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";

/**
 * Quran reader powered by the open quran.com API (api.quran.com/api/v4): word-by-
 * word text, translations, per-ayah + per-word recitation audio, and word-timing
 * segments — all with CORS and no auth, so it runs entirely in the browser.
 * Reading (mushaf) mode, tap-a-word to hear + read it, full playback with word
 * highlighting, surah/juz navigation with search, and ayah/range repeat.
 */
const API = "https://api.quran.com/api/v4";
const AUDIO_CDN = "https://verses.quran.com/";
const TRANSLATION_ID = 20; // Saheeh International (English)

const FALLBACK_RECITERS: { id: number; name: string }[] = [
  { id: 7, name: "Mishary Rashid Alafasy" },
  { id: 2, name: "AbdulBaset AbdulSamad (Murattal)" },
  { id: 3, name: "Abdur-Rahman as-Sudais" },
];

const REPEAT_OPTIONS = [1, 2, 3, 5, 7, 10, Infinity];

type Chapter = {
  id: number;
  nameSimple: string;
  nameArabic: string;
  translatedName: string;
  versesCount: number;
};

type QuranWord = {
  position: number;
  text: string;
  imlaei: string; // standard-orthography diacritized form (for the pronunciation checker)
  translation: string;
  transliteration: string;
  audioUrl: string;
};

type Verse = {
  verseKey: string;
  chapterId: number;
  verseNumber: number;
  words: QuranWord[];
  translation: string;
  audioUrl: string;
  segments: number[][];
};

function stripHtml(value: string) {
  return value.replace(/<[^>]*>/g, "").trim();
}

/** A word-timing segment is [segmentIndex, wordPosition, startMs, endMs] (or the
 * shorter [wordPosition, startMs, endMs]); normalize to {pos, start, end}. */
function readSegment(seg: number[]) {
  if (seg.length >= 4) return { pos: seg[1], start: seg[2], end: seg[3] };
  return { pos: seg[0], start: seg[1], end: seg[2] };
}

/** Latin digits → Arabic-Indic, for the mushaf ayah-end markers. */
function toArabicNumber(n: number) {
  return String(n).replace(/[0-9]/g, (d) => "٠١٢٣٤٥٦٧٨٩"[Number(d)]);
}

function repeatLabel(n: number) {
  return n === Infinity ? "∞" : String(n);
}

/** First verse (surah, ayah) of each juz 1..30, plus a sentinel end. */
const JUZ_START: [number, number][] = [
  [1, 1], [2, 142], [2, 253], [3, 93], [4, 24], [4, 148], [5, 82], [6, 111], [7, 88], [8, 41],
  [9, 93], [11, 6], [12, 53], [15, 1], [17, 1], [18, 75], [21, 1], [23, 1], [25, 21], [27, 56],
  [29, 46], [33, 31], [36, 28], [39, 32], [41, 47], [46, 1], [51, 31], [58, 1], [67, 1], [78, 1],
  [115, 1],
];

type AyahRef = { surahId: number; ayah: number };
type PlanScope = { kind: "quran" | "surah" | "juz"; id: number };

function parseScope(value: string): PlanScope {
  if (value === "quran") return { kind: "quran", id: 0 };
  const [kind, id] = value.split(":");
  return { kind: kind === "juz" ? "juz" : "surah", id: Number(id) || 1 };
}
function scopeToString(s: PlanScope) {
  return s.kind === "quran" ? "quran" : `${s.kind}:${s.id}`;
}

/** The ordered list of ayahs in a plan's scope, using chapter verse counts. */
function scopeSequence(scope: PlanScope, chapters: Chapter[]): AyahRef[] {
  const versesOf = (id: number) => chapters.find((c) => c.id === id)?.versesCount ?? 0;
  const out: AyahRef[] = [];
  if (scope.kind === "surah") {
    for (let a = 1; a <= versesOf(scope.id); a += 1) out.push({ surahId: scope.id, ayah: a });
    return out;
  }
  if (scope.kind === "juz") {
    const [startS, startA] = JUZ_START[scope.id - 1] ?? [1, 1];
    const [endS, endA] = JUZ_START[scope.id] ?? [115, 1];
    for (let s = startS; s <= endS; s += 1) {
      const count = versesOf(s);
      const from = s === startS ? startA : 1;
      const to = s === endS ? endA - 1 : count;
      for (let a = from; a <= Math.min(to, count); a += 1) out.push({ surahId: s, ayah: a });
    }
    return out;
  }
  // whole Quran
  for (let s = 1; s <= 114; s += 1) {
    for (let a = 1; a <= versesOf(s); a += 1) out.push({ surahId: s, ayah: a });
  }
  return out;
}

function todayStr() {
  return new Date().toLocaleDateString("en-CA"); // YYYY-MM-DD, local
}
function addDaysStr(days: number) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" });
}

/** A human-friendly span: days under a month, months under two years, else years. */
function humanDuration(days: number, t: (en: string, vars?: Record<string, string | number>) => string) {
  if (days < 30) return t(days === 1 ? "{n} day" : "{n} days", { n: days });
  if (days < 730) {
    const m = Math.max(1, Math.round(days / 30.44));
    return t(m === 1 ? "{n} month" : "{n} months", { n: m });
  }
  const years = days / 365.25;
  const rounded = Math.round(years * 10) / 10;
  return t("{n} years", { n: Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1) });
}

export default function StudentQuranPage() {
  const t = useT();
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);

  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [reciters, setReciters] = useState(FALLBACK_RECITERS);
  const [nav, setNav] = useState<{ kind: "surah" | "juz" | "goal"; id: number }>({ kind: "surah", id: 1 });
  const [goalRefs, setGoalRefs] = useState<AyahRef[]>([]);
  const [reciter, setReciter] = useState(7);
  const [verses, setVerses] = useState<Verse[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [mode, setMode] = useState<"reading" | "translation">("reading");
  const [pickerOpen, setPickerOpen] = useState(false);
  const [repeatOpen, setRepeatOpen] = useState(false);

  // Memorization: surahId -> set of memorized ayah numbers, saved per student.
  const [uid, setUid] = useState<string | null>(null);
  const [memorized, setMemorized] = useState<Record<number, Set<number>>>({});
  const [plan, setPlan] = useState<{ scope: PlanScope; perDay: number; startDate: string } | null>(null);
  const [dailyLog, setDailyLog] = useState<Record<string, number>>({});
  const [planOpen, setPlanOpen] = useState(false);

  // Repeat settings (rangeFrom/rangeTo are 1-based positions within the loaded list).
  const [repeatEach, setRepeatEach] = useState(1);
  const [repeatRange, setRepeatRange] = useState(1);
  const [rangeFrom, setRangeFrom] = useState(1);
  const [rangeTo, setRangeTo] = useState(1);

  // Playback
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const wordAudioRef = useRef<HTMLAudioElement | null>(null);
  const [playingIndex, setPlayingIndex] = useState<number | null>(null);
  const [isPaused, setIsPaused] = useState(false);
  const [currentWordPos, setCurrentWordPos] = useState<number | null>(null);
  const [selectedWord, setSelectedWord] = useState<QuranWord | null>(null);
  const [reciteVerse, setReciteVerse] = useState<Verse | null>(null);
  const [followOpen, setFollowOpen] = useState(false);

  const versesRef = useRef<Verse[]>([]);
  versesRef.current = verses;
  const playingIndexRef = useRef<number | null>(null);
  const repeatEachRef = useRef(1);
  const repeatRangeRef = useRef(1);
  const rangeFromIdxRef = useRef(0);
  const rangeToIdxRef = useRef(0);
  const eachPlayedRef = useRef(0);
  const rangeLoopedRef = useRef(0);
  useEffect(() => {
    repeatEachRef.current = repeatEach;
  }, [repeatEach]);
  useEffect(() => {
    repeatRangeRef.current = repeatRange;
  }, [repeatRange]);
  useEffect(() => {
    rangeFromIdxRef.current = Math.max(0, rangeFrom - 1);
    rangeToIdxRef.current = Math.max(0, rangeTo - 1);
  }, [rangeFrom, rangeTo]);

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setAccess("signedOut");
        setUid(null);
        return;
      }
      try {
        const session = await resolveStudentSession(nextUser);
        if (!session.isStudent) {
          setAccess("denied");
          return;
        }
        setSummary(session.summary);
        setIsAdultStudent(session.isAdultStudent);
        setAccess("allowed");
        setUid(nextUser.uid);
      } catch {
        setAccess("denied");
      }
    });
  }, []);

  // Load this student's memorization progress once signed in.
  useEffect(() => {
    if (!uid) return;
    let cancelled = false;
    void (async () => {
      try {
        const snap = await getDoc(doc(db, "quran_memorization", uid));
        if (cancelled || !snap.exists()) return;
        const data = snap.data();
        const raw = (data.memorized ?? {}) as Record<string, unknown>;
        const next: Record<number, Set<number>> = {};
        for (const [surahId, ayahs] of Object.entries(raw)) {
          if (Array.isArray(ayahs)) next[Number(surahId)] = new Set(ayahs.map(Number));
        }
        setMemorized(next);
        if (data.plan?.scope) {
          setPlan({ scope: parseScope(String(data.plan.scope)), perDay: Number(data.plan.perDay) || 1, startDate: String(data.plan.startDate || todayStr()) });
        }
        if (data.daily_log && typeof data.daily_log === "object") setDailyLog(data.daily_log as Record<string, number>);
      } catch {
        // Progress just shows empty if this read fails.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [uid]);

  const toggleMemorized = useCallback(
    (surahId: number, ayah: number) => {
      const already = memorized[surahId]?.has(ayah) ?? false;
      // Optimistic local update.
      setMemorized((current) => {
        const next = { ...current };
        const set = new Set(next[surahId] ?? []);
        if (already) set.delete(ayah);
        else set.add(ayah);
        next[surahId] = set;
        return next;
      });
      // Count newly-memorized ayahs toward today's goal (unmark undoes it).
      const day = todayStr();
      setDailyLog((current) => {
        const nextCount = Math.max(0, (current[day] ?? 0) + (already ? -1 : 1));
        return { ...current, [day]: nextCount };
      });
      if (!uid) return;
      void setDoc(
        doc(db, "quran_memorization", uid),
        {
          memorized: { [surahId]: already ? arrayRemove(ayah) : arrayUnion(ayah) },
          [`daily_log.${day}`]: increment(already ? -1 : 1),
          updated_at: serverTimestamp(),
        },
        { merge: true },
      ).catch(() => undefined);
    },
    [memorized, uid],
  );

  const savePlan = useCallback(
    (scope: PlanScope, perDay: number) => {
      const nextPlan = { scope, perDay, startDate: todayStr() };
      setPlan(nextPlan);
      if (uid) {
        void setDoc(
          doc(db, "quran_memorization", uid),
          { plan: { scope: scopeToString(scope), perDay, startDate: nextPlan.startDate }, updated_at: serverTimestamp() },
          { merge: true },
        ).catch(() => undefined);
      }
    },
    [uid],
  );

  const clearPlan = useCallback(() => {
    setPlan(null);
    setGoalRefs([]);
    setNav((n) => (n.kind === "goal" ? { kind: "surah", id: 1 } : n));
    if (uid) {
      void setDoc(doc(db, "quran_memorization", uid), { plan: deleteField(), updated_at: serverTimestamp() }, { merge: true }).catch(() => undefined);
    }
  }, [uid]);

  // Enter the daily practice: load today's target ayahs into the full reader
  // (so play/repeat/word-tap/tick all work on exactly the goal ayahs).
  const enterGoalModeFor = useCallback(
    (scope: PlanScope, perDay: number) => {
      const seq = scopeSequence(scope, chapters);
      const targets = seq.filter((r) => !(memorized[r.surahId]?.has(r.ayah) ?? false)).slice(0, Math.max(1, perDay));
      setGoalRefs(targets);
      setNav({ kind: "goal", id: 0 });
      setPlanOpen(false);
    },
    [chapters, memorized],
  );

  const startPlan = useCallback(
    (scope: PlanScope, perDay: number) => {
      savePlan(scope, perDay);
      enterGoalModeFor(scope, perDay);
    },
    [savePlan, enterGoalModeFor],
  );

  const totalMemorized = useMemo(
    () => Object.values(memorized).reduce((sum, set) => sum + set.size, 0),
    [memorized],
  );
  const memorizedInView = useMemo(
    () => verses.filter((v) => memorized[v.chapterId]?.has(v.verseNumber)).length,
    [verses, memorized],
  );

  const planStats = useMemo(() => {
    if (!plan || chapters.length === 0) return null;
    const seq = scopeSequence(plan.scope, chapters);
    const total = seq.length;
    const isMem = (r: AyahRef) => memorized[r.surahId]?.has(r.ayah) ?? false;
    const done = seq.filter(isMem).length;
    const remaining = total - done;
    const todayCount = dailyLog[todayStr()] ?? 0;
    // Today's list counts down toward the daily goal (what's still left today).
    const remainingToday = Math.max(0, plan.perDay - todayCount);
    const targets = seq.filter((r) => !isMem(r)).slice(0, remainingToday);
    const daysLeft = plan.perDay > 0 ? Math.ceil(remaining / plan.perDay) : 0;
    let streak = 0;
    const d = new Date();
    if ((dailyLog[todayStr()] ?? 0) < plan.perDay) d.setDate(d.getDate() - 1);
    for (;;) {
      const k = d.toLocaleDateString("en-CA");
      if ((dailyLog[k] ?? 0) >= plan.perDay) {
        streak += 1;
        d.setDate(d.getDate() - 1);
      } else break;
    }
    return { total, done, remaining, targets, daysLeft, todayCount, streak };
  }, [plan, chapters, memorized, dailyLog]);

  // Chapters + reciters (once).
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const [chapRes, recRes] = await Promise.all([
          fetch(`${API}/chapters?language=en`),
          fetch(`${API}/resources/recitations?language=en`),
        ]);
        const chapData = await chapRes.json();
        const recData = await recRes.json();
        if (cancelled) return;
        setChapters(
          (chapData.chapters ?? []).map((c: Record<string, unknown>) => ({
            id: Number(c.id),
            nameSimple: String(c.name_simple ?? ""),
            nameArabic: String(c.name_arabic ?? ""),
            translatedName: String((c.translated_name as { name?: string })?.name ?? ""),
            versesCount: Number(c.verses_count ?? 0),
          })),
        );
        const list = (recData.recitations ?? [])
          .map((r: Record<string, unknown>) => ({
            id: Number(r.id),
            name: `${r.reciter_name}${r.style ? ` (${r.style})` : ""}`,
          }))
          .filter((r: { id: number; name: string }) => r.id && r.name);
        if (list.length) setReciters(list);
      } catch {
        // Fallbacks keep the reader usable if resource lists fail.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const stopAudio = useCallback(() => {
    const audio = audioRef.current;
    if (audio) {
      audio.pause();
      audio.removeAttribute("src");
    }
    playingIndexRef.current = null;
    setPlayingIndex(null);
    setIsPaused(false);
    setCurrentWordPos(null);
  }, []);

  // Load the selected surah or juz whenever the selection or reciter changes.
  useEffect(() => {
    let cancelled = false;
    stopAudio();
    setLoading(true);
    setLoadError("");
    setVerses([]);
    void (async () => {
      try {
        const mapVerse = (v: Record<string, unknown>): Verse => {
          const rawWords = Array.isArray(v.words) ? v.words : [];
          const words: QuranWord[] = rawWords
            .filter((w: Record<string, unknown>) => w.char_type_name === "word")
            .map((w: Record<string, unknown>) => ({
              position: Number(w.position),
              text: String(w.text_uthmani ?? w.text ?? ""),
              imlaei: String(w.text_imlaei ?? ""),
              translation: String((w.translation as { text?: string })?.text ?? ""),
              transliteration: String((w.transliteration as { text?: string })?.text ?? ""),
              audioUrl: w.audio_url ? `${AUDIO_CDN}${w.audio_url}` : "",
            }));
          const audio = (v.audio ?? {}) as { url?: string; segments?: number[][] };
          const key = String(v.verse_key ?? "");
          return {
            verseKey: key,
            chapterId: Number(key.split(":")[0] || 0),
            verseNumber: Number(v.verse_number ?? 0),
            words,
            translation: stripHtml(String(((v.translations as { text?: string }[])?.[0]?.text as string) ?? "")),
            audioUrl: audio.url ? `${AUDIO_CDN}${audio.url}` : "",
            segments: Array.isArray(audio.segments) ? audio.segments : [],
          };
        };
        const wordParams = `words=true&word_fields=text_uthmani,text_imlaei,audio_url&fields=text_uthmani&translations=${TRANSLATION_ID}&audio=${reciter}`;
        const all: Verse[] = [];
        if (nav.kind === "goal") {
          // Today's memorization set: fetch exactly the target ayahs, in order.
          for (const ref of goalRefs) {
            const res = await fetch(`${API}/verses/by_key/${ref.surahId}:${ref.ayah}?${wordParams}`);
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = await res.json();
            if (data.verse) all.push(mapVerse(data.verse));
            if (cancelled) break;
          }
        } else {
          let page = 1;
          const path = nav.kind === "surah" ? `by_chapter/${nav.id}` : `by_juz/${nav.id}`;
          for (;;) {
            const res = await fetch(`${API}/verses/${path}?${wordParams}&per_page=50&page=${page}`);
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = await res.json();
            for (const v of data.verses ?? []) all.push(mapVerse(v));
            const pg = data.pagination ?? {};
            if (!pg.next_page || cancelled) break;
            page = pg.next_page;
          }
        }
        if (cancelled) return;
        setVerses(all);
        setRangeFrom(1);
        setRangeTo(all.length || 1);
        setLoading(false);
      } catch (error) {
        if (cancelled) return;
        setLoadError(error instanceof Error ? error.message : "Could not load this selection.");
        setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [nav, reciter, goalRefs, stopAudio]);

  const handleTimeUpdate = useCallback(() => {
    const audio = audioRef.current;
    if (!audio || playingIndex == null) return;
    const verse = versesRef.current[playingIndex];
    if (!verse) return;
    const ms = audio.currentTime * 1000;
    let pos: number | null = null;
    for (const seg of verse.segments) {
      const s = readSegment(seg);
      if (ms >= s.start && ms < s.end) {
        pos = s.pos;
        break;
      }
    }
    setCurrentWordPos(pos);
  }, [playingIndex]);

  const playFrom = useCallback((index: number) => {
    const list = versesRef.current;
    if (index < 0 || index >= list.length) return;
    const audio = audioRef.current;
    const verse = list[index];
    if (!audio || !verse.audioUrl) return;
    audio.src = verse.audioUrl;
    audio.currentTime = 0;
    playingIndexRef.current = index;
    setPlayingIndex(index);
    setIsPaused(false);
    setCurrentWordPos(null);
    void audio.play().catch(() => setIsPaused(true));
  }, []);

  // Start playback honoring the repeat range + reset counters.
  const startPlayback = useCallback(() => {
    eachPlayedRef.current = 0;
    rangeLoopedRef.current = 0;
    const start = Math.min(rangeFromIdxRef.current, versesRef.current.length - 1);
    playFrom(Math.max(0, start));
  }, [playFrom]);

  const handleEnded = useCallback(() => {
    const idx = playingIndexRef.current;
    if (idx == null) return;
    // Repeat this ayah until its repeat count is spent.
    if (eachPlayedRef.current + 1 < repeatEachRef.current) {
      eachPlayedRef.current += 1;
      playFrom(idx);
      return;
    }
    eachPlayedRef.current = 0;
    const next = idx + 1;
    // At the end of the range, loop it until its repeat count is spent.
    if (next > rangeToIdxRef.current || next >= versesRef.current.length) {
      if (rangeLoopedRef.current + 1 < repeatRangeRef.current) {
        rangeLoopedRef.current += 1;
        playFrom(rangeFromIdxRef.current);
        return;
      }
      stopAudio();
      return;
    }
    playFrom(next);
  }, [playFrom, stopAudio]);

  const togglePauseResume = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    if (audio.paused) {
      void audio.play().catch(() => undefined);
      setIsPaused(false);
    } else {
      audio.pause();
      setIsPaused(true);
    }
  }, []);

  const selectWord = useCallback((word: QuranWord) => {
    setSelectedWord(word);
    const audio = wordAudioRef.current;
    if (audio && word.audioUrl) {
      audio.src = word.audioUrl;
      void audio.play().catch(() => undefined);
    }
  }, []);

  useEffect(() => {
    if (playingIndex == null) return;
    document.getElementById(`v-${playingIndex}`)?.scrollIntoView({ block: "center", behavior: "smooth" });
  }, [playingIndex]);

  const chapterName = useCallback(
    (id: number) => chapters.find((c) => c.id === id)?.nameSimple || `Surah ${id}`,
    [chapters],
  );

  const headerTitle = useMemo(() => {
    if (nav.kind === "goal") return { arabic: "", en: t("Today's goal"), sub: "", count: verses.length };
    if (nav.kind === "juz") return { arabic: "", en: t("Juz {n}", { n: nav.id }), sub: "", count: verses.length };
    const c = chapters.find((ch) => ch.id === nav.id);
    return {
      arabic: c?.nameArabic ?? "",
      en: c?.nameSimple ?? `Surah ${nav.id}`,
      sub: c?.translatedName ?? "",
      count: c?.versesCount ?? verses.length,
    };
  }, [nav, chapters, verses.length, t]);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;
  const isPlaying = playingIndex != null && !isPaused;
  const pickerLabel = nav.kind === "goal" ? t("Today's goal") : nav.kind === "surah" ? `${nav.id}. ${chapterName(nav.id)}` : t("Juz {n}", { n: nav.id });

  return (
    <StudentShell activeLabel="Quran" breadcrumb="Learning / Quran" summary={summary} isAdultStudent={isAdultStudent}>
      <main className="min-h-screen bg-[#F8FAFC] pb-28 text-[#0F172A] lg:min-h-[calc(100vh-56px)]">
        <audio ref={audioRef} onTimeUpdate={handleTimeUpdate} onEnded={handleEnded} onPause={() => setIsPaused(true)} onPlay={() => setIsPaused(false)} className="hidden" />
        <audio ref={wordAudioRef} className="hidden" />

        {/* Controls */}
        <div className="sticky top-0 z-10 border-b border-[#E2E8F0] bg-white/95 backdrop-blur">
          <div className="mx-auto flex w-full max-w-[900px] flex-wrap items-center gap-2 px-4 py-3">
            <button
              type="button"
              onClick={() => setPickerOpen(true)}
              className="inline-flex min-h-10 flex-1 items-center justify-between gap-2 rounded-xl border border-[#E2E8F0] bg-white px-3 text-sm font-bold text-[#0F172A] hover:bg-[#F8FAFC]"
            >
              <span className="truncate">{pickerLabel}</span>
              <ChevronDown size={16} className="shrink-0 text-[#94A3B8]" />
            </button>
            <select
              value={reciter}
              onChange={(event) => setReciter(Number(event.target.value))}
              aria-label={t("Reciter")}
              className="min-h-10 max-w-[200px] rounded-xl border border-[#E2E8F0] bg-white px-2 text-sm font-bold text-[#0F172A] outline-none focus:border-[#0E7490]"
            >
              {reciters.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name}
                </option>
              ))}
            </select>
            <button
              type="button"
              onClick={() => (playingIndex == null ? startPlayback() : stopAudio())}
              disabled={loading || verses.length === 0}
              className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#0E7490] px-4 text-sm font-black text-white hover:bg-[#0C6478] disabled:opacity-50"
            >
              {playingIndex == null ? <Play size={16} /> : <Square size={16} />}
              {playingIndex == null ? t("Play") : t("Stop")}
            </button>
            <div className="relative">
              <button
                type="button"
                onClick={() => setRepeatOpen((v) => !v)}
                aria-label={t("Repeat")}
                className={`inline-flex min-h-10 items-center gap-1.5 rounded-xl border px-3 text-sm font-bold ${
                  repeatEach > 1 || repeatRange > 1 || rangeFrom > 1 || rangeTo < verses.length
                    ? "border-[#0E7490] bg-[#ECFEFF] text-[#0E7490]"
                    : "border-[#E2E8F0] bg-white text-[#334155] hover:bg-[#F8FAFC]"
                }`}
              >
                <Repeat size={15} /> {t("Repeat")}
              </button>
              {repeatOpen ? (
                <RepeatPanel
                  t={t}
                  verseCount={verses.length}
                  repeatEach={repeatEach}
                  setRepeatEach={setRepeatEach}
                  repeatRange={repeatRange}
                  setRepeatRange={setRepeatRange}
                  rangeFrom={rangeFrom}
                  setRangeFrom={setRangeFrom}
                  rangeTo={rangeTo}
                  setRangeTo={setRangeTo}
                  onClose={() => setRepeatOpen(false)}
                />
              ) : null}
            </div>
            <button
              type="button"
              onClick={() => (plan ? enterGoalModeFor(plan.scope, plan.perDay) : setPlanOpen(true))}
              className={`inline-flex min-h-10 items-center gap-1.5 rounded-xl border px-3 text-sm font-bold ${
                plan ? "border-[#16A34A] bg-[#DCFCE7] text-[#166534]" : "border-[#E2E8F0] bg-white text-[#334155] hover:bg-[#F8FAFC]"
              }`}
            >
              <Target size={15} />
              {plan && planStats ? t("Today {done}/{total}", { done: planStats.todayCount, total: plan.perDay }) : t("Goal")}
            </button>
            <div className="flex items-center gap-1 rounded-xl bg-[#F1F5F9] p-1">
              <ToggleChip active={mode === "reading"} onClick={() => setMode("reading")} label={t("Reading")} />
              <ToggleChip active={mode === "translation"} onClick={() => setMode("translation")} label={t("Translation")} />
            </div>
          </div>
        </div>

        <div className="mx-auto w-full max-w-[900px] px-4 py-6">
          <header className="mb-5 text-center">
            {headerTitle.arabic ? (
              <h1 className="text-3xl font-black text-[#0F172A]" dir="rtl" style={{ fontFamily: "'Amiri','Scheherazade New',serif" }}>
                {headerTitle.arabic}
              </h1>
            ) : (
              <h1 className="text-2xl font-black text-[#0F172A]">{headerTitle.en}</h1>
            )}
            {headerTitle.arabic ? <p className="mt-1 text-sm font-bold text-[#0E7490]">{headerTitle.en} · {headerTitle.sub}</p> : null}
            <p className="mt-0.5 text-xs font-semibold text-[#94A3B8]">{t("{n} verses", { n: headerTitle.count })}</p>
            {verses.length > 0 ? (
              <div className="mx-auto mt-3 max-w-sm">
                <div className="flex items-center justify-between text-xs font-black text-[#0F172A]">
                  <span className="inline-flex items-center gap-1.5">
                    <CheckCircle2 size={14} className="text-[#16A34A]" />
                    {t("Memorized {done}/{total}", { done: memorizedInView, total: verses.length })}
                  </span>
                  <span className="text-[#94A3B8]">{t("{n} ayahs total", { n: totalMemorized })}</span>
                </div>
                <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-[#E2E8F0]">
                  <div className="h-full rounded-full bg-[#16A34A] transition-all" style={{ width: `${verses.length ? (memorizedInView / verses.length) * 100 : 0}%` }} />
                </div>
              </div>
            ) : null}
            {verses.length > 0 ? (
              <div className="mt-4 flex justify-center">
                <button
                  type="button"
                  onClick={() => setFollowOpen(true)}
                  className="inline-flex items-center gap-2 rounded-2xl bg-[#0E7490] px-5 py-3 text-sm font-black text-white shadow-sm transition hover:bg-[#0C647B]"
                >
                  <Mic size={16} /> {t("Recite from memory")}
                </button>
              </div>
            ) : null}
          </header>

          {nav.kind === "goal" && plan && planStats ? (
            <div className="mb-4 rounded-2xl border border-[#BBF7D0] bg-[#F0FDF4] p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <p className="inline-flex items-center gap-1.5 text-sm font-black text-[#166534]">
                    <Target size={15} /> {t("Today's memorization")} · {t("{done}/{total} today", { done: planStats.todayCount, total: plan.perDay })}
                  </p>
                  <p className="mt-0.5 text-xs font-semibold text-[#15803D]">
                    {planStats.remaining > 0
                      ? t("{done} of {total} ayahs · ~{duration} left", { done: planStats.done, total: planStats.total, duration: humanDuration(planStats.daysLeft, t) })
                      : t("You've memorized this whole selection. Ma sha Allah! 🎉")}
                    {planStats.streak > 0 ? ` · 🔥 ${t("{n} day streak", { n: planStats.streak })}` : ""}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <button type="button" onClick={() => setPlanOpen(true)} className="rounded-xl bg-white px-3 py-1.5 text-xs font-black text-[#166534] hover:bg-[#DCFCE7]">{t("Change goal")}</button>
                  <button type="button" onClick={() => setNav({ kind: "surah", id: 1 })} className="rounded-xl bg-white px-3 py-1.5 text-xs font-black text-[#334155] hover:bg-[#F1F5F9]">{t("Browse Quran")}</button>
                </div>
              </div>
              <p className="mt-2 text-xs font-semibold text-[#15803D]">{t("Read, listen, and repeat the ayahs below — tick each one once you've memorized it.")}</p>
            </div>
          ) : null}

          {!loading && !loadError && nav.kind === "goal" && verses.length === 0 ? (
            <p className="rounded-2xl border border-[#BBF7D0] bg-[#F0FDF4] px-4 py-10 text-center text-sm font-black text-[#166534]">{t("You've memorized this whole selection. Ma sha Allah! 🎉")}</p>
          ) : null}

          {loading ? (
            <div className="grid min-h-[40vh] place-items-center text-[#64748B]">
              <span className="inline-flex items-center gap-2 text-sm font-bold">
                <Loader2 className="animate-spin" size={18} />
                {t("Loading the Quran…")}
              </span>
            </div>
          ) : loadError ? (
            <p className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-bold text-red-700">{loadError}</p>
          ) : mode === "reading" ? (
            <section
              dir="rtl"
              className="rounded-2xl border border-black/5 bg-white px-5 py-8 text-justify shadow-[0_4px_12px_rgba(15,23,42,0.04)]"
              style={{ fontFamily: "'Amiri','Scheherazade New','Traditional Arabic',serif", lineHeight: 2.9, textAlignLast: "center" }}
            >
              <p className="text-[30px] text-[#0F172A]">
                {verses.map((verse, index) => {
                  const showSurahBreak = nav.kind === "juz" && (index === 0 || verses[index - 1].chapterId !== verse.chapterId);
                  return (
                    <span key={verse.verseKey} id={`v-${index}`}>
                      {showSurahBreak ? (
                        <span dir="ltr" className="my-2 block text-center text-sm font-black text-[#0E7490]" style={{ fontFamily: "inherit" }}>
                          ﴾ {chapterName(verse.chapterId)} ﴿
                        </span>
                      ) : null}
                      {verse.words.map((word) => {
                        const highlighted = playingIndex === index && currentWordPos === word.position;
                        const selected = selectedWord === word;
                        return (
                          <span
                            key={word.position}
                            role="button"
                            tabIndex={0}
                            onClick={() => selectWord(word)}
                            className={`cursor-pointer rounded px-0.5 transition ${
                              highlighted ? "bg-[#FEF08A]" : selected ? "bg-[#ECFEFF] text-[#0E7490]" : "hover:bg-[#F1F5F9]"
                            }`}
                          >
                            {word.text}{" "}
                          </span>
                        );
                      })}
                      <span
                        role="button"
                        tabIndex={0}
                        onClick={() => playFrom(index)}
                        aria-label={t("Play verse")}
                        className={`mx-0.5 inline-flex h-8 w-8 cursor-pointer select-none items-center justify-center rounded-full border align-middle text-[15px] transition ${
                          playingIndex === index ? "border-[#0E7490] bg-[#0E7490] text-white" : "border-[#0E7490]/40 text-[#0E7490] hover:bg-[#ECFEFF]"
                        }`}
                      >
                        {toArabicNumber(verse.verseNumber)}
                      </span>
                      <span
                        role="button"
                        tabIndex={0}
                        onClick={() => toggleMemorized(verse.chapterId, verse.verseNumber)}
                        aria-label={t("Mark memorized")}
                        className="mx-0.5 inline-flex h-6 w-6 cursor-pointer items-center justify-center align-middle"
                      >
                        {memorized[verse.chapterId]?.has(verse.verseNumber) ? (
                          <CheckCircle2 size={18} className="text-[#16A34A]" />
                        ) : (
                          <Circle size={18} className="text-[#CBD5E1]" />
                        )}
                      </span>
                      <span
                        role="button"
                        tabIndex={0}
                        onClick={() => setReciteVerse(verse)}
                        aria-label={t("Check your recitation")}
                        className="mx-0.5 inline-flex h-6 w-6 cursor-pointer items-center justify-center align-middle text-[#94A3B8] hover:text-[#0E7490]"
                      >
                        <Mic size={16} />
                      </span>{" "}
                    </span>
                  );
                })}
              </p>
            </section>
          ) : (
            <div className="space-y-3">
              {verses.map((verse, index) => {
                const active = playingIndex === index;
                return (
                  <article key={verse.verseKey} id={`v-${index}`} className={`rounded-2xl border bg-white p-4 shadow-[0_4px_12px_rgba(15,23,42,0.04)] transition ${active ? "border-[#0E7490] ring-2 ring-[#CFF3F0]" : "border-black/5"}`}>
                    <div className="flex items-center justify-between">
                      <span className="grid h-8 min-w-8 place-items-center rounded-full bg-[#ECFEFF] px-2 text-xs font-black text-[#0E7490]">
                        {nav.kind === "juz" ? verse.verseKey : verse.verseNumber}
                      </span>
                      <div className="flex items-center gap-1">
                        <button
                          type="button"
                          onClick={() => toggleMemorized(verse.chapterId, verse.verseNumber)}
                          aria-label={t("Mark memorized")}
                          className={`inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-black transition ${
                            memorized[verse.chapterId]?.has(verse.verseNumber)
                              ? "bg-[#DCFCE7] text-[#166534]"
                              : "bg-[#F1F5F9] text-[#64748B] hover:bg-[#E2E8F0]"
                          }`}
                        >
                          {memorized[verse.chapterId]?.has(verse.verseNumber) ? <CheckCircle2 size={14} /> : <Circle size={14} />}
                          {memorized[verse.chapterId]?.has(verse.verseNumber) ? t("Memorized") : t("Memorize")}
                        </button>
                        <button
                          type="button"
                          onClick={() => (active ? togglePauseResume() : playFrom(index))}
                          aria-label={active && !isPaused ? t("Pause") : t("Play verse")}
                          className="grid h-9 w-9 place-items-center rounded-full text-[#0E7490] hover:bg-[#ECFEFF]"
                        >
                          {active && !isPaused ? <Pause size={18} /> : <Play size={18} />}
                        </button>
                        <button
                          type="button"
                          onClick={() => setReciteVerse(verse)}
                          aria-label={t("Check your recitation")}
                          className="grid h-9 w-9 place-items-center rounded-full text-[#0E7490] hover:bg-[#ECFEFF]"
                        >
                          <Mic size={18} />
                        </button>
                      </div>
                    </div>
                    <div dir="rtl" className="mt-3 flex flex-wrap justify-end gap-x-2 gap-y-3 leading-[2.4]" style={{ fontFamily: "'Amiri','Scheherazade New','Traditional Arabic',serif" }}>
                      {verse.words.map((word) => {
                        const highlighted = active && currentWordPos === word.position;
                        const selected = selectedWord === word;
                        return (
                          <button key={word.position} type="button" onClick={() => selectWord(word)} className={`rounded-lg px-1 text-[26px] transition ${highlighted ? "bg-[#FEF08A] text-[#0F172A]" : selected ? "bg-[#ECFEFF] text-[#0E7490]" : "text-[#0F172A] hover:bg-[#F1F5F9]"}`}>
                            {word.text}
                          </button>
                        );
                      })}
                    </div>
                    <p className="mt-2 text-sm italic text-[#64748B]">{verse.words.map((w) => w.transliteration).filter(Boolean).join(" ")}</p>
                    {verse.translation ? <p className="mt-2 text-[15px] leading-7 text-[#334155]">{verse.translation}</p> : null}
                  </article>
                );
              })}
            </div>
          )}
        </div>

        {/* Tapped-word meaning bar */}
        {selectedWord ? (
          <div className="fixed bottom-4 left-1/2 z-20 w-[calc(100%-2rem)] max-w-md -translate-x-1/2 rounded-2xl border border-[#E2E8F0] bg-white p-4 shadow-xl">
            <div className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <div className="text-2xl font-black text-[#0F172A]" dir="rtl" style={{ fontFamily: "'Amiri',serif" }}>{selectedWord.text}</div>
                <div className="mt-0.5 text-sm font-bold text-[#0E7490]">{selectedWord.transliteration}</div>
                <div className="text-sm font-semibold text-[#64748B]">{selectedWord.translation}</div>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <button type="button" onClick={() => selectWord(selectedWord)} aria-label={t("Play verse")} className="grid h-10 w-10 place-items-center rounded-full bg-[#ECFEFF] text-[#0E7490]">
                  <Play size={16} />
                </button>
                <button type="button" onClick={() => setSelectedWord(null)} className="rounded-xl bg-[#F1F5F9] px-3 py-2 text-xs font-black text-[#334155] hover:bg-[#E2E8F0]">{t("Close")}</button>
              </div>
            </div>
          </div>
        ) : null}

        {/* Now-playing bar */}
        {playingIndex != null && !selectedWord ? (
          <div className="fixed bottom-4 left-1/2 z-20 flex w-[calc(100%-2rem)] max-w-md -translate-x-1/2 items-center gap-3 rounded-2xl border border-[#E2E8F0] bg-white p-3 shadow-xl">
            <button type="button" onClick={togglePauseResume} aria-label={isPlaying ? t("Pause") : t("Play verse")} className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-[#0E7490] text-white">
              {isPlaying ? <Pause size={18} /> : <Play size={18} />}
            </button>
            <div className="min-w-0 flex-1 text-sm font-bold text-[#0F172A]">{t("Playing verse {key}", { key: verses[playingIndex]?.verseKey ?? "" })}</div>
            <button type="button" onClick={stopAudio} aria-label={t("Stop")} className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-[#F1F5F9] text-[#334155]">
              <Square size={16} />
            </button>
          </div>
        ) : null}

        {pickerOpen ? (
          <SurahJuzPicker
            t={t}
            chapters={chapters}
            current={nav}
            onSelect={(next) => {
              setNav(next);
              setPickerOpen(false);
            }}
            onClose={() => setPickerOpen(false)}
          />
        ) : null}

        {planOpen ? (
          <QuranPlanModal
            t={t}
            chapters={chapters}
            currentNav={nav}
            plan={plan}
            onStart={startPlan}
            onClear={clearPlan}
            onClose={() => setPlanOpen(false)}
          />
        ) : null}

        {reciteVerse ? (
          <RecitationCheck
            t={t}
            label={reciteVerse.verseKey}
            words={reciteVerse.words.map((w) => ({ text: w.text, imlaei: w.imlaei }))}
            audioUrl={reciteVerse.audioUrl}
            onClose={() => setReciteVerse(null)}
          />
        ) : null}

        {followOpen ? (
          <RecitationFollowAlong
            t={t}
            title={headerTitle.arabic || headerTitle.en}
            verses={verses.map((v) => ({
              verseKey: v.verseKey,
              verseNumber: v.verseNumber,
              audioUrl: v.audioUrl,
              words: v.words.map((w) => ({ text: w.text, imlaei: w.imlaei, audioUrl: w.audioUrl, position: w.position })),
            }))}
            onClose={() => setFollowOpen(false)}
          />
        ) : null}
      </main>
    </StudentShell>
  );
}

function ToggleChip({ active, onClick, label }: { active: boolean; onClick: () => void; label: string }) {
  return (
    <button type="button" onClick={onClick} aria-pressed={active} className={`min-h-8 rounded-lg px-2.5 text-xs font-black transition ${active ? "bg-white text-[#0E7490] shadow" : "text-[#64748B]"}`}>
      {label}
    </button>
  );
}

type Translate = (en: string, vars?: Record<string, string | number>) => string;

function RepeatPanel(props: {
  t: Translate;
  verseCount: number;
  repeatEach: number;
  setRepeatEach: (n: number) => void;
  repeatRange: number;
  setRepeatRange: (n: number) => void;
  rangeFrom: number;
  setRangeFrom: (n: number) => void;
  rangeTo: number;
  setRangeTo: (n: number) => void;
  onClose: () => void;
}) {
  const { t, verseCount } = props;
  const ayahOptions = Array.from({ length: Math.max(1, verseCount) }, (_, i) => i + 1);
  return (
    <>
      <button type="button" aria-label={t("Close")} onClick={props.onClose} className="fixed inset-0 z-10 cursor-default" />
      <div className="absolute right-0 top-12 z-20 w-72 rounded-2xl border border-[#E2E8F0] bg-white p-4 shadow-2xl">
        <h3 className="text-sm font-black text-[#0F172A]">{t("Repeat")}</h3>
        <label className="mt-3 block text-xs font-black uppercase tracking-wide text-[#94A3B8]">{t("Repeat each ayah")}</label>
        <select value={props.repeatEach} onChange={(e) => props.setRepeatEach(Number(e.target.value))} className="mt-1 min-h-10 w-full rounded-xl border border-[#E2E8F0] bg-white px-3 text-sm font-bold outline-none">
          {REPEAT_OPTIONS.map((n) => (
            <option key={n} value={n}>{repeatLabel(n)}{n === 1 ? ` (${t("No repeat")})` : ` ×`}</option>
          ))}
        </select>
        <label className="mt-3 block text-xs font-black uppercase tracking-wide text-[#94A3B8]">{t("Play from ayah")}</label>
        <div className="mt-1 flex items-center gap-2">
          <select value={props.rangeFrom} onChange={(e) => props.setRangeFrom(Math.min(Number(e.target.value), props.rangeTo))} className="min-h-10 flex-1 rounded-xl border border-[#E2E8F0] bg-white px-2 text-sm font-bold outline-none">
            {ayahOptions.map((n) => <option key={n} value={n}>{n}</option>)}
          </select>
          <span className="text-xs font-black text-[#94A3B8]">{t("to")}</span>
          <select value={props.rangeTo} onChange={(e) => props.setRangeTo(Math.max(Number(e.target.value), props.rangeFrom))} className="min-h-10 flex-1 rounded-xl border border-[#E2E8F0] bg-white px-2 text-sm font-bold outline-none">
            {ayahOptions.map((n) => <option key={n} value={n}>{n}</option>)}
          </select>
        </div>
        <label className="mt-3 block text-xs font-black uppercase tracking-wide text-[#94A3B8]">{t("Repeat this range")}</label>
        <select value={props.repeatRange} onChange={(e) => props.setRepeatRange(Number(e.target.value))} className="mt-1 min-h-10 w-full rounded-xl border border-[#E2E8F0] bg-white px-3 text-sm font-bold outline-none">
          {REPEAT_OPTIONS.map((n) => (
            <option key={n} value={n}>{repeatLabel(n)}{n === 1 ? ` (${t("No repeat")})` : ` ×`}</option>
          ))}
        </select>
        <button type="button" onClick={props.onClose} className="mt-4 min-h-10 w-full rounded-xl bg-[#0E7490] text-sm font-black text-white">{t("Done")}</button>
      </div>
    </>
  );
}

function QuranPlanModal(props: {
  t: Translate;
  chapters: Chapter[];
  currentNav: { kind: "surah" | "juz" | "goal"; id: number };
  plan: { scope: PlanScope; perDay: number; startDate: string } | null;
  onStart: (scope: PlanScope, perDay: number) => void;
  onClear: () => void;
  onClose: () => void;
}) {
  const { t, chapters, currentNav, plan } = props;
  const initialKind = plan?.scope.kind ?? (currentNav.kind === "goal" ? "surah" : currentNav.kind);
  const [scopeKind, setScopeKind] = useState<"quran" | "surah" | "juz">(initialKind);
  const [surahId, setSurahId] = useState(plan?.scope.kind === "surah" ? plan.scope.id : currentNav.kind === "surah" ? currentNav.id : 1);
  const [juzId, setJuzId] = useState(plan?.scope.kind === "juz" ? plan.scope.id : currentNav.kind === "juz" ? currentNav.id : 1);
  const [perDay, setPerDay] = useState(plan?.perDay ?? 3);

  const chosenScope: PlanScope = scopeKind === "quran" ? { kind: "quran", id: 0 } : scopeKind === "surah" ? { kind: "surah", id: surahId } : { kind: "juz", id: juzId };
  const projTotal = scopeSequence(chosenScope, chapters).length;
  const projDays = perDay > 0 ? Math.ceil(projTotal / perDay) : 0;

  return (
    <div className="fixed inset-0 z-30 grid place-items-end bg-black/40 sm:place-items-center sm:p-6" role="dialog" aria-modal="true">
      <button type="button" aria-label={t("Close")} onClick={props.onClose} className="absolute inset-0 cursor-default" />
      <section className="relative flex max-h-[88vh] w-full flex-col overflow-hidden rounded-t-3xl bg-white shadow-2xl sm:max-w-lg sm:rounded-2xl">
        <header className="flex items-center justify-between border-b border-[#E2E8F0] p-4">
          <h2 className="inline-flex items-center gap-2 text-lg font-black text-[#0F172A]"><Target size={18} className="text-[#16A34A]" /> {t("Memorization plan")}</h2>
          <button type="button" onClick={props.onClose} aria-label={t("Close")} className="grid h-9 w-9 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]"><X size={18} /></button>
        </header>
        <div className="overflow-y-auto p-4">
          <p className="text-sm font-semibold text-[#64748B]">{t("Pick what to memorize and your daily pace — we'll estimate how long it takes and show you a little each day.")}</p>
          <label className="mt-4 block text-xs font-black uppercase tracking-wide text-[#94A3B8]">{t("What to memorize")}</label>
          <div className="mt-1 flex gap-1 rounded-xl bg-[#F1F5F9] p-1">
            <ToggleChip active={scopeKind === "quran"} onClick={() => setScopeKind("quran")} label={t("Whole Quran")} />
            <ToggleChip active={scopeKind === "surah"} onClick={() => setScopeKind("surah")} label={t("Surah")} />
            <ToggleChip active={scopeKind === "juz"} onClick={() => setScopeKind("juz")} label={t("Juz")} />
          </div>
          {scopeKind === "surah" ? (
            <select value={surahId} onChange={(e) => setSurahId(Number(e.target.value))} className="mt-2 min-h-10 w-full rounded-xl border border-[#E2E8F0] bg-white px-3 text-sm font-bold outline-none">
              {chapters.map((c) => <option key={c.id} value={c.id}>{c.id}. {c.nameSimple} ({c.versesCount})</option>)}
            </select>
          ) : null}
          {scopeKind === "juz" ? (
            <select value={juzId} onChange={(e) => setJuzId(Number(e.target.value))} className="mt-2 min-h-10 w-full rounded-xl border border-[#E2E8F0] bg-white px-3 text-sm font-bold outline-none">
              {Array.from({ length: 30 }, (_, i) => i + 1).map((n) => <option key={n} value={n}>{t("Juz {n}", { n })}</option>)}
            </select>
          ) : null}

          <label className="mt-4 block text-xs font-black uppercase tracking-wide text-[#94A3B8]">{t("Ayahs per day")}</label>
          <div className="mt-1 flex items-center gap-3">
            <button type="button" onClick={() => setPerDay((n) => Math.max(1, n - 1))} className="grid h-10 w-10 place-items-center rounded-xl bg-[#F1F5F9] text-lg font-black text-[#334155]">−</button>
            <span className="min-w-10 text-center text-xl font-black text-[#0F172A]">{perDay}</span>
            <button type="button" onClick={() => setPerDay((n) => Math.min(50, n + 1))} className="grid h-10 w-10 place-items-center rounded-xl bg-[#F1F5F9] text-lg font-black text-[#334155]">+</button>
          </div>

          <div className="mt-4 rounded-2xl bg-[#ECFEFF] p-4 text-center">
            <p className="text-sm font-bold text-[#0E7490]">{t("At {perDay} ayahs/day", { perDay })}</p>
            <p className="mt-1 text-2xl font-black text-[#0F172A]">{t("about {duration}", { duration: humanDuration(projDays, t) })}</p>
            <p className="mt-0.5 text-xs font-semibold text-[#64748B]">{t("{total} ayahs · finish around {date}", { total: projTotal, date: addDaysStr(projDays) })}</p>
          </div>

          <button type="button" onClick={() => props.onStart(chosenScope, perDay)} className="mt-4 min-h-11 w-full rounded-xl bg-[#16A34A] text-sm font-black text-white hover:bg-[#15803D]">
            {plan ? t("Update goal") : t("Start memorizing")}
          </button>
          {plan ? <button type="button" onClick={() => { props.onClear(); props.onClose(); }} className="mt-2 min-h-10 w-full rounded-xl text-sm font-black text-[#DC2626] hover:bg-[#FEE2E2]">{t("Stop plan")}</button> : null}
        </div>
      </section>
    </div>
  );
}

function SurahJuzPicker(props: {
  t: Translate;
  chapters: Chapter[];
  current: { kind: "surah" | "juz" | "goal"; id: number };
  onSelect: (next: { kind: "surah" | "juz"; id: number }) => void;
  onClose: () => void;
}) {
  const { t, chapters } = props;
  const [tab, setTab] = useState<"surah" | "juz">(props.current.kind === "juz" ? "juz" : "surah");
  const [query, setQuery] = useState("");
  const q = query.trim().toLowerCase();
  const filtered = chapters.filter(
    (c) => !q || c.nameSimple.toLowerCase().includes(q) || c.translatedName.toLowerCase().includes(q) || c.nameArabic.includes(q) || String(c.id) === q,
  );
  return (
    <div className="fixed inset-0 z-30 grid place-items-end bg-black/40 sm:place-items-center sm:p-6" role="dialog" aria-modal="true">
      <button type="button" aria-label={t("Close")} onClick={props.onClose} className="absolute inset-0 cursor-default" />
      <section className="relative flex h-[80vh] w-full flex-col overflow-hidden rounded-t-3xl bg-white shadow-2xl sm:h-[70vh] sm:max-w-md sm:rounded-2xl">
        <header className="flex items-center gap-2 border-b border-[#E2E8F0] p-3">
          <div className="flex items-center gap-1 rounded-xl bg-[#F1F5F9] p-1">
            <ToggleChip active={tab === "surah"} onClick={() => setTab("surah")} label={t("Surah")} />
            <ToggleChip active={tab === "juz"} onClick={() => setTab("juz")} label={t("Juz")} />
          </div>
          <div className="ml-auto" />
          <button type="button" onClick={props.onClose} aria-label={t("Close")} className="grid h-9 w-9 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </header>
        {tab === "surah" ? (
          <>
            <div className="p-3">
              <label className="relative block">
                <Search className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={16} />
                <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t("Search surah…")} aria-label={t("Search surah…")} className="h-11 w-full rounded-xl border border-[#E2E8F0] bg-white pl-9 pr-3 text-sm outline-none focus:border-[#0E7490]" />
              </label>
            </div>
            <div className="flex-1 overflow-y-auto px-3 pb-3">
              {filtered.map((c) => (
                <button key={c.id} type="button" onClick={() => props.onSelect({ kind: "surah", id: c.id })} className={`flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left hover:bg-[#F8FAFC] ${props.current.kind === "surah" && props.current.id === c.id ? "bg-[#ECFEFF]" : ""}`}>
                  <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-[#F1F5F9] text-xs font-black text-[#0E7490]">{c.id}</span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-black text-[#0F172A]">{c.nameSimple}</span>
                    <span className="block truncate text-xs font-semibold text-[#64748B]">{c.translatedName} · {t("{n} verses", { n: c.versesCount })}</span>
                  </span>
                  <span dir="rtl" className="text-lg text-[#0F172A]" style={{ fontFamily: "'Amiri',serif" }}>{c.nameArabic}</span>
                </button>
              ))}
              {filtered.length === 0 ? <p className="px-3 py-6 text-center text-sm font-semibold text-[#94A3B8]">{t("No surah found")}</p> : null}
            </div>
          </>
        ) : (
          <div className="flex-1 overflow-y-auto p-3">
            <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
              {Array.from({ length: 30 }, (_, i) => i + 1).map((n) => (
                <button key={n} type="button" onClick={() => props.onSelect({ kind: "juz", id: n })} className={`min-h-14 rounded-xl border text-sm font-black transition ${props.current.kind === "juz" && props.current.id === n ? "border-[#0E7490] bg-[#ECFEFF] text-[#0E7490]" : "border-[#E2E8F0] bg-white text-[#334155] hover:bg-[#F8FAFC]"}`}>
                  {t("Juz {n}", { n })}
                </button>
              ))}
            </div>
          </div>
        )}
      </section>
    </div>
  );
}
