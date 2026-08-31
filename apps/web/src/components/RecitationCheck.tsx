"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { httpsCallable } from "firebase/functions";
import { Mic, Square, X, Loader2, RotateCcw, CheckCircle2, Play, Volume2 } from "lucide-react";
import { checkRecitationDetailed, normalizeArabic, type WordCheck } from "@/lib/arabicRecitation";
import { functions } from "@/lib/firebase";

type Translate = (key: string, vars?: Record<string, string | number>) => string;

type Phase = "idle" | "recording" | "transcribing" | "done" | "unsupported" | "error";
type CheckMode = "words" | "pronunciation";

type TranscribeResponse = { text?: string; words?: { word: string; start: number; end: number }[] };

type PronWord = {
  word: string;
  status: "ok" | "ending" | "sound" | "missed";
  expected_ending?: string | null;
  heard_ending?: string | null;
};
type PronResponse = { heard_phonemes?: string; words?: PronWord[] };

const HARAKAH_GLYPH: Record<string, string> = { fatha: "ـَ", damma: "ـُ", kasra: "ـِ" };

function supportsRecording(): boolean {
  return typeof window !== "undefined" && typeof MediaRecorder !== "undefined" && !!navigator.mediaDevices?.getUserMedia;
}

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const result = String(reader.result);
      resolve(result.slice(result.indexOf(",") + 1));
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

/**
 * Per-ayah recitation check, powered by the Quran-tuned model.
 *
 * Records the student (MediaRecorder — works on every modern browser incl. iOS
 * Safari), sends the clip through the auth-checked `transcribeRecitation` callable
 * to our private Cloud Run model, then does a diacritic-aware comparison: right
 * word (green), wrong/missed word (red), and — EXPERIMENT — right word but wrong
 * case ending like اللَّهُ→اللَّهَ (amber). Also plays YOUR recitation next to the
 * reciter's so you can hear the difference.
 */
export function RecitationCheck({
  t,
  label,
  words,
  audioUrl,
  onClose,
}: {
  t: Translate;
  label: string;
  words: { text: string; imlaei?: string }[];
  audioUrl?: string;
  onClose: () => void;
}) {
  const [phase, setPhase] = useState<Phase>("idle");
  const [mode, setMode] = useState<CheckMode>("words");
  const [checks, setChecks] = useState<WordCheck[] | null>(null);
  const [pron, setPron] = useState<PronWord[] | null>(null);
  const [heard, setHeard] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [myRecordingUrl, setMyRecordingUrl] = useState<string | null>(null);

  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const streamRef = useRef<MediaStream | null>(null);
  const playbackRef = useRef<HTMLAudioElement | null>(null);

  const realWordIdx = useMemo(() => words.map((w) => normalizeArabic(w.text) !== ""), [words]);

  useEffect(() => {
    if (!supportsRecording()) setPhase("unsupported");
  }, []);

  const cleanupStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
  }, []);

  const lastBlobRef = useRef<Blob | null>(null);

  const transcribe = useCallback(
    async (blob: Blob, useMode: CheckMode) => {
      lastBlobRef.current = blob;
      setPhase("transcribing");
      try {
        const audioBase64 = await blobToBase64(blob);
        const filename = blob.type.includes("mp4") ? "recitation.mp4" : blob.type.includes("ogg") ? "recitation.ogg" : "recitation.webm";
        if (useMode === "pronunciation") {
          const callable = httpsCallable<{ audioBase64: string; filename: string; words: string[] }, PronResponse>(functions, "checkPronunciation");
          const response = await callable({ audioBase64, filename, words: words.map((w) => w.imlaei || w.text) });
          setPron(response.data?.words ?? []);
          setChecks(null);
          setHeard("");
        } else {
          const callable = httpsCallable<{ audioBase64: string; filename: string }, TranscribeResponse>(functions, "transcribeRecitation");
          const response = await callable({ audioBase64, filename });
          const text = response.data?.text ?? "";
          setHeard(text);
          setChecks(checkRecitationDetailed(words.map((w) => w.text), text));
          setPron(null);
        }
        setPhase("done");
      } catch (err) {
        console.error("recitation check failed", err);
        setErrorMsg(t("We couldn't check that recitation. Please try again."));
        setPhase("error");
      }
    },
    [t, words],
  );

  const switchMode = useCallback(
    (next: CheckMode) => {
      setMode(next);
      // Re-analyze the same recording under the other checker, if we have one.
      if (phase === "done" && lastBlobRef.current) void transcribe(lastBlobRef.current, next);
    },
    [phase, transcribe],
  );

  const start = useCallback(async () => {
    if (!supportsRecording()) {
      setPhase("unsupported");
      return;
    }
    setErrorMsg("");
    setChecks(null);
    setPron(null);
    setHeard("");
    if (myRecordingUrl) {
      URL.revokeObjectURL(myRecordingUrl);
      setMyRecordingUrl(null);
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      chunksRef.current = [];
      const recorder = new MediaRecorder(stream);
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) chunksRef.current.push(event.data);
      };
      recorder.onstop = () => {
        cleanupStream();
        const blob = new Blob(chunksRef.current, { type: chunksRef.current[0]?.type || "audio/webm" });
        setMyRecordingUrl(URL.createObjectURL(blob));
        void transcribe(blob, mode);
      };
      recorderRef.current = recorder;
      recorder.start();
      setPhase("recording");
    } catch (err) {
      cleanupStream();
      const name = (err as { name?: string })?.name;
      if (name === "NotAllowedError" || name === "SecurityError") {
        setErrorMsg(t("Microphone access was blocked. Allow the mic in your browser and try again."));
      } else {
        setErrorMsg(t("We couldn't reach your microphone. Please try again."));
      }
      setPhase("error");
    }
  }, [cleanupStream, mode, myRecordingUrl, t, transcribe]);

  const stop = useCallback(() => {
    if (recorderRef.current && recorderRef.current.state !== "inactive") {
      recorderRef.current.stop();
    }
  }, []);

  const playUrl = useCallback((url: string) => {
    if (!playbackRef.current) return;
    playbackRef.current.pause();
    playbackRef.current.src = url;
    void playbackRef.current.play().catch(() => undefined);
  }, []);

  useEffect(
    () => () => {
      if (recorderRef.current && recorderRef.current.state !== "inactive") recorderRef.current.stop();
      streamRef.current?.getTracks().forEach((track) => track.stop());
      if (myRecordingUrl) URL.revokeObjectURL(myRecordingUrl);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [],
  );

  const total = useMemo(() => realWordIdx.filter(Boolean).length, [realWordIdx]);
  const correctCount = useMemo(
    () => (checks ? checks.filter((c, i) => realWordIdx[i] && c.status === "correct").length : 0),
    [checks, realWordIdx],
  );
  const endingIssues = useMemo(
    () => (checks ? checks.filter((c) => c.status === "ending") : []),
    [checks],
  );
  const accuracyPct = total ? Math.round((correctCount / total) * 100) : 0;
  const scoreTone = accuracyPct >= 90 ? "#16A34A" : accuracyPct >= 60 ? "#CA8A04" : "#DC2626";

  const pronIssues = useMemo(() => (pron ? pron.filter((w) => w.status !== "ok") : []), [pron]);

  const wordClass = (i: number): string => {
    if (mode === "pronunciation") {
      const st = pron?.[i]?.status;
      if (!pron || !st) return "text-[#0F172A]";
      if (st === "ok") return "bg-[#DCFCE7] text-[#166534]";
      if (st === "ending") return "bg-[#FEF3C7] text-[#92400E]";
      if (st === "sound") return "bg-[#FFEDD5] text-[#9A3412]";
      return "bg-[#FEE2E2] text-[#B91C1C]";
    }
    const st = checks?.[i]?.status;
    if (!checks || !realWordIdx[i] || !st) return "text-[#0F172A]";
    if (st === "correct") return "bg-[#DCFCE7] text-[#166534]";
    if (st === "ending") return "bg-[#FEF3C7] text-[#92400E]";
    return "bg-[#FEE2E2] text-[#B91C1C]";
  };

  const harakahLabel = (name?: string | null): string => {
    if (!name) return "";
    const glyph = HARAKAH_GLYPH[name] ?? "";
    return glyph ? `${t(name)} (${glyph})` : t(name);
  };

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/40 p-0 sm:items-center sm:p-4" role="dialog" aria-modal="true">
      <audio ref={playbackRef} className="hidden" />
      <div className="flex max-h-[92vh] w-full max-w-lg flex-col overflow-hidden rounded-t-3xl bg-white shadow-2xl sm:rounded-3xl">
        <header className="flex items-center justify-between border-b border-[#F1F5F9] px-5 py-4">
          <div>
            <h2 className="text-base font-black text-[#0F172A]">{t("Check your recitation")}</h2>
            <p className="text-xs font-bold text-[#64748B]">{t("Verse {key}", { key: label })}</p>
          </div>
          <button type="button" onClick={onClose} aria-label={t("Close")} className="grid h-9 w-9 place-items-center rounded-full bg-[#F1F5F9] text-[#334155] hover:bg-[#E2E8F0]">
            <X size={18} />
          </button>
        </header>

        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-5">
          {/* Checker mode */}
          <div className="mb-3 flex items-center gap-1 rounded-xl bg-[#F1F5F9] p-1">
            <button
              type="button"
              onClick={() => switchMode("words")}
              className={`min-h-9 flex-1 rounded-lg text-xs font-black ${mode === "words" ? "bg-white text-[#0F172A] shadow-sm" : "text-[#64748B]"}`}
            >
              {t("Words")}
            </button>
            <button
              type="button"
              onClick={() => switchMode("pronunciation")}
              className={`min-h-9 flex-1 rounded-lg text-xs font-black ${mode === "pronunciation" ? "bg-white text-[#0F172A] shadow-sm" : "text-[#64748B]"}`}
            >
              {t("Pronunciation")} <span className="ml-1 rounded bg-[#CFF3F0] px-1 text-[10px] text-[#0E7490]">β</span>
            </button>
          </div>

          {/* The ayah — words recolor once scored. */}
          <div
            dir="rtl"
            className="flex flex-wrap justify-center gap-x-2 gap-y-3 rounded-2xl border border-[#F1F5F9] bg-[#FAFAF9] px-4 py-6 leading-[2.4]"
            style={{ fontFamily: "'Amiri','Scheherazade New','Traditional Arabic',serif" }}
          >
            {words.map((word, i) => (
              <span key={`${word.text}-${i}`} className={`rounded-lg px-1 text-[26px] transition ${wordClass(i)}`}>
                {word.text}
              </span>
            ))}
          </div>

          {/* Correct reciter — available any time to hear how it should sound. */}
          {audioUrl ? (
            <button
              type="button"
              onClick={() => playUrl(audioUrl)}
              className="mt-3 flex w-full items-center justify-center gap-2 rounded-2xl border border-[#CFF3F0] bg-[#ECFEFF] px-4 py-2.5 text-sm font-black text-[#0E7490]"
            >
              <Volume2 size={16} /> {t("Hear the correct recitation")}
            </button>
          ) : null}

          {phase === "done" && mode === "pronunciation" && pron ? (
            <div className="mt-4 rounded-2xl border border-[#F1F5F9] bg-white p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm font-black text-[#0F172A]">
                  {pronIssues.length === 0
                    ? t("No pronunciation issues caught. Ma sha Allah!")
                    : t("{n} word(s) to review", { n: pronIssues.length })}
                </span>
                {pronIssues.length === 0 ? <CheckCircle2 size={18} className="text-[#16A34A]" /> : null}
              </div>
              {pronIssues.length > 0 ? (
                <ul className="mt-2 space-y-1.5">
                  {pronIssues.map((w, k) => (
                    <li key={`${w.word}-${k}`} className="rounded-xl bg-[#FFFBEB] px-3 py-2 text-sm font-bold text-[#92400E]">
                      <span dir="rtl" className="font-black" style={{ fontFamily: "'Amiri',serif" }}>{w.word}</span>
                      {" — "}
                      {w.status === "ending"
                        ? t("a harakah sounded like {heard} — it should be {expected}", {
                            heard: harakahLabel(w.heard_ending),
                            expected: harakahLabel(w.expected_ending),
                          })
                        : w.status === "sound"
                          ? t("a sound in this word needs checking")
                          : t("this word wasn't heard clearly")}
                    </li>
                  ))}
                </ul>
              ) : null}
              {myRecordingUrl ? (
                <button
                  type="button"
                  onClick={() => playUrl(myRecordingUrl)}
                  className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-[#F1F5F9] px-4 py-2.5 text-sm font-black text-[#334155]"
                >
                  <Play size={15} /> {t("Play your recitation")}
                </button>
              ) : null}
              <p className="mt-3 text-[11px] font-bold text-[#94A3B8]">
                {t("Beta — catches clear vowel/ending mistakes. It's a practice aid, not a substitute for a teacher.")}
              </p>
            </div>
          ) : null}

          {phase === "done" && mode === "words" && checks ? (
            <div className="mt-4 rounded-2xl border border-[#F1F5F9] bg-white p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm font-black text-[#0F172A]">{t("You recited {done} of {total} words", { done: correctCount, total })}</span>
                <span className="text-lg font-black" style={{ color: scoreTone }}>{accuracyPct}%</span>
              </div>
              <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-[#F1F5F9]">
                <div className="h-full rounded-full transition-all" style={{ width: `${accuracyPct}%`, backgroundColor: scoreTone }} />
              </div>

              {/* EXPERIMENT: case-ending corrections */}
              {endingIssues.length > 0 ? (
                <div className="mt-3 rounded-xl border border-[#FDE68A] bg-[#FFFBEB] p-3">
                  <p className="text-xs font-black text-[#92400E]">{t("Ending to check")}</p>
                  <ul className="mt-1 space-y-1">
                    {endingIssues.map((c, k) => (
                      <li key={`${c.expected}-${k}`} className="text-sm font-bold text-[#92400E]" dir="rtl" style={{ fontFamily: "'Amiri',serif" }}>
                        <span className="text-[#B91C1C]">{c.heard}</span> → <span className="text-[#166534]">{c.expected}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null}

              {myRecordingUrl ? (
                <button
                  type="button"
                  onClick={() => playUrl(myRecordingUrl)}
                  className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-[#F1F5F9] px-4 py-2.5 text-sm font-black text-[#334155]"
                >
                  <Play size={15} /> {t("Play your recitation")}
                </button>
              ) : null}
              {heard ? (
                <p className="mt-3 text-xs font-bold text-[#94A3B8]">
                  {t("Heard")}: <span dir="rtl" className="font-black text-[#64748B]">{heard}</span>
                </p>
              ) : null}
            </div>
          ) : null}

          {phase === "error" ? (
            <p className="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-bold text-red-700">{errorMsg}</p>
          ) : null}

          {phase === "unsupported" ? (
            <p className="mt-4 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-bold text-amber-800">
              {t("Recording isn't available in this browser. Try Chrome, Edge, or Safari.")}
            </p>
          ) : null}

          {phase === "recording" ? (
            <p className="mt-4 flex items-center justify-center gap-2 text-center text-sm font-black text-[#DC2626]">
              <span className="inline-block h-2.5 w-2.5 animate-pulse rounded-full bg-[#DC2626]" /> {t("Recording… recite the verse, then tap stop.")}
            </p>
          ) : null}
          {phase === "transcribing" ? (
            <p className="mt-4 flex items-center justify-center gap-2 text-center text-sm font-bold text-[#0E7490]">
              <Loader2 size={16} className="animate-spin" /> {t("Checking your recitation…")}
            </p>
          ) : null}
        </div>

        <footer className="border-t border-[#F1F5F9] px-5 py-4">
          {phase === "recording" ? (
            <button type="button" onClick={stop} className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#DC2626] px-4 py-3.5 text-sm font-black text-white">
              <Square size={16} /> {t("Stop & check")}
            </button>
          ) : phase === "transcribing" ? (
            <button type="button" disabled className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#94A3B8] px-4 py-3.5 text-sm font-black text-white">
              <Loader2 size={16} className="animate-spin" /> {t("Checking…")}
            </button>
          ) : phase === "done" ? (
            <div className="flex gap-2">
              <button type="button" onClick={start} className="flex flex-1 items-center justify-center gap-2 rounded-2xl bg-[#0E7490] px-4 py-3.5 text-sm font-black text-white">
                <RotateCcw size={16} /> {t("Try again")}
              </button>
              <button type="button" onClick={onClose} className="flex items-center justify-center gap-2 rounded-2xl bg-[#F1F5F9] px-5 py-3.5 text-sm font-black text-[#334155]">
                <CheckCircle2 size={16} /> {t("Done")}
              </button>
            </div>
          ) : phase === "unsupported" ? (
            <button type="button" onClick={onClose} className="w-full rounded-2xl bg-[#F1F5F9] px-4 py-3.5 text-sm font-black text-[#334155]">{t("Close")}</button>
          ) : (
            <button type="button" onClick={start} className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#0E7490] px-4 py-3.5 text-sm font-black text-white">
              {phase === "error" ? <RotateCcw size={16} /> : <Mic size={16} />} {phase === "error" ? t("Try again") : t("Start reciting")}
            </button>
          )}
          <p className="mt-2 text-center text-[11px] font-bold text-[#94A3B8]">{t("Green = right · amber = check the ending · red = wrong word.")}</p>
        </footer>
      </div>
    </div>
  );
}
