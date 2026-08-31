"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { httpsCallable } from "firebase/functions";
import { Mic, Square, X, CheckCircle2, RotateCcw, Volume2, Loader2 } from "lucide-react";
import { AyahFollowMatcher, alignSpokenToExpected, checkRecitation, normalizeArabic, tokenize, type AyahStatus } from "@/lib/arabicRecitation";
import { getSpeechRecognition, liveRecognitionSupported, type SpeechRecognitionLike, type SpeechResultEvent } from "@/lib/speechRecognition";
import { functions } from "@/lib/firebase";

type Translate = (key: string, vars?: Record<string, string | number>) => string;

type FollowWord = { text: string; imlaei?: string; audioUrl?: string; position: number };
type FollowVerse = { verseKey: string; verseNumber: number; audioUrl?: string; words: FollowWord[] };

type Phase = "idle" | "listening" | "recording" | "transcribing" | "done" | "unsupported" | "error";
type Mode = "live" | "record" | "none";

type TranscribeResponse = { text?: string; words?: { word: string; start: number; end: number }[] };
type PronVerdict = { word: string; status: "ok" | "ending" | "sound" | "missed"; expected_ending?: string | null; heard_ending?: string | null };
type PronResponse = { words?: PronVerdict[] };
type PronFlag = "ending" | "sound";

const HARAKAH_GLYPH: Record<string, string> = { fatha: "ـَ", damma: "ـُ", kasra: "ـِ" };

function supportsRecording(): boolean {
  return typeof window !== "undefined" && typeof MediaRecorder !== "undefined" && !!navigator.mediaDevices?.getUserMedia;
}

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const r = String(reader.result);
      resolve(r.slice(r.indexOf(",") + 1));
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

/**
 * Hands-free memorization ("recite the surah, flag a wrong ayah").
 *
 * Two engines behind one experience:
 *  - LIVE (Chrome/Edge desktop + Android): browser speech recognition streams
 *    words in real time; the AyahFollowMatcher beeps the moment you drift.
 *  - RECORD (iPhone/iPad — no live recognition there): you record the recitation,
 *    the Quran-tuned model transcribes it, then the analysis REPLAYS — words light
 *    up and it buzzes at each slip — using the same matcher.
 *
 * Same rules either way: repeat an ayah freely; skipping or jumping out of order
 * is a slip.
 */
export function RecitationFollowAlong({
  t,
  title,
  verses,
  onClose,
}: {
  t: Translate;
  title: string;
  verses: FollowVerse[];
  onClose: () => void;
}) {
  const mode: Mode = useMemo(() => (liveRecognitionSupported() ? "live" : supportsRecording() ? "record" : "none"), []);

  const [phase, setPhase] = useState<Phase>("idle");
  const [ayahStatus, setAyahStatus] = useState<AyahStatus[]>([]);
  const [wordDone, setWordDone] = useState<boolean[][]>([]);
  const [cur, setCur] = useState<{ ayah: number; pos: number }>({ ayah: 0, pos: 0 });
  const [slips, setSlips] = useState(0);
  const [interim, setInterim] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [muted, setMuted] = useState(false);

  const recRef = useRef<SpeechRecognitionLike | null>(null);
  const matcherRef = useRef<AyahFollowMatcher | null>(null);
  const processedRef = useRef(0);
  const allTokensRef = useRef<string[]>([]);
  const activeRef = useRef(false);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const lastBeepRef = useRef(0);
  const mutedRef = useRef(false);

  // Record mode.
  const mediaRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const streamRef = useRef<MediaStream | null>(null);
  const abortRef = useRef(false);

  // Pronunciation checking (phoneme model), live per-ayah segments + record-mode overlay.
  const [pronFlags, setPronFlags] = useState<Record<string, PronFlag>>({}); // `${vi}:${di}` -> flag
  const [pronNotes, setPronNotes] = useState<string[]>([]);
  const [pronPending, setPronPending] = useState(0);
  const [pronOff, setPronOff] = useState(false);
  const liveSegRef = useRef<{ rec: MediaRecorder; chunks: Blob[] } | null>(null);
  const segAyahRef = useRef(0);
  const segStartedRef = useRef(0);

  // Compare-playback: your audio per ayah + word timestamps within it.
  const segBlobsRef = useRef<Map<number, Blob>>(new Map()); // vi -> your recording of that ayah (live mode)
  const wholeBlobRef = useRef<Blob | null>(null); // record mode: the full recording
  const wordTimesRef = useRef<Map<string, [number, number]>>(new Map()); // `${vi}:${di}` -> [start,end] seconds
  const [pickWord, setPickWord] = useState<{ vi: number; di: number } | null>(null);
  const playbackRef = useRef<HTMLAudioElement | null>(null);
  const objectUrlRef = useRef<string | null>(null);

  useEffect(() => {
    mutedRef.current = muted;
  }, [muted]);

  const { ayahTokens, wordTok, flatExpected, flatToAyah } = useMemo(() => {
    const at: string[][] = [];
    const wt: number[][] = [];
    const flat: string[] = [];
    const toAyah: { vi: number; tok: number }[] = [];
    verses.forEach((v, vi) => {
      const toks: string[] = [];
      const map: number[] = [];
      v.words.forEach((w) => {
        const token = normalizeArabic(w.text);
        if (token) {
          map.push(toks.length);
          toks.push(token);
        } else {
          map.push(-1);
        }
      });
      toks.forEach((tk, ti) => {
        toAyah.push({ vi, tok: ti });
        flat.push(tk);
      });
      at.push(toks);
      wt.push(map);
    });
    return { ayahTokens: at, wordTok: wt, flatExpected: flat, flatToAyah: toAyah };
  }, [verses]);

  useEffect(() => {
    if (mode === "none") setPhase("unsupported");
  }, [mode]);

  // Wake the pronunciation service as soon as the overlay opens, so the first
  // ayah's check doesn't land on a cold instance (which 503s under a burst).
  useEffect(() => {
    if (mode === "none") return;
    const warm = httpsCallable<{ warm: boolean }, { warm?: boolean }>(functions, "checkPronunciation");
    warm({ warm: true }).catch(() => undefined);
  }, [mode]);

  const beep = useCallback((wrong: boolean) => {
    if (mutedRef.current) return;
    const now = Date.now();
    if (now - lastBeepRef.current < 500) return;
    lastBeepRef.current = now;
    try {
      const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!Ctx) return;
      const ctx = audioCtxRef.current ?? new Ctx();
      audioCtxRef.current = ctx;
      if (ctx.state === "suspended") void ctx.resume();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = wrong ? "square" : "sine";
      osc.frequency.value = wrong ? 200 : 660;
      osc.connect(gain);
      gain.connect(ctx.destination);
      const t0 = ctx.currentTime;
      gain.gain.setValueAtTime(0.0001, t0);
      gain.gain.exponentialRampToValueAtTime(wrong ? 0.35 : 0.25, t0 + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t0 + (wrong ? 0.34 : 0.18));
      osc.start(t0);
      osc.stop(t0 + (wrong ? 0.36 : 0.2));
    } catch {
      /* audio unavailable */
    }
  }, []);

  const syncFromMatcher = useCallback((m: AyahFollowMatcher) => {
    setAyahStatus([...m.ayahStatus]);
    setWordDone(m.wordDone.map((a) => [...a]));
    setCur({ ayah: m.currentAyah, pos: m.posInAyah });
    setSlips(m.slips);
  }, []);

  const freshMatcher = useCallback(() => {
    const m = new AyahFollowMatcher(ayahTokens);
    matcherRef.current = m;
    syncFromMatcher(m);
    return m;
  }, [ayahTokens, syncFromMatcher]);

  const stopStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((tr) => tr.stop());
    streamRef.current = null;
  }, []);

  // Distinct double-buzz for a pronunciation flag (vs the single slip beep).
  const beepDouble = useCallback(() => {
    if (mutedRef.current) return;
    try {
      const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!Ctx) return;
      const ctx = audioCtxRef.current ?? new Ctx();
      audioCtxRef.current = ctx;
      if (ctx.state === "suspended") void ctx.resume();
      [0, 0.22].forEach((off) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "triangle";
        osc.frequency.value = 330;
        osc.connect(gain);
        gain.connect(ctx.destination);
        const t0 = ctx.currentTime + off;
        gain.gain.setValueAtTime(0.0001, t0);
        gain.gain.exponentialRampToValueAtTime(0.3, t0 + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.16);
        osc.start(t0);
        osc.stop(t0 + 0.18);
      });
    } catch {
      /* audio unavailable */
    }
  }, []);

  // Word timestamps for YOUR audio: the Whisper service returns word timings;
  // align its transcript words onto the ayah's words so "play just this word"
  // can slice your recording. Fired only for ayahs that got flagged.
  const fetchWordTimings = useCallback(
    async (vi: number, audioBase64: string, filename: string) => {
      const verse = verses[vi];
      if (!verse) return;
      try {
        const callable = httpsCallable<{ audioBase64: string; filename: string }, TranscribeResponse>(functions, "transcribeRecitation");
        const resp = await callable({ audioBase64, filename });
        const spoken = resp.data?.words ?? [];
        const expectedSkels = verse.words.map((w) => normalizeArabic(w.text));
        const spokenSkels = spoken.map((w) => normalizeArabic(w.word));
        const pair = alignSpokenToExpected(expectedSkels, spokenSkels);
        pair.forEach((si, di) => {
          if (si != null && spoken[si]) wordTimesRef.current.set(`${vi}:${di}`, [spoken[si].start, spoken[si].end]);
        });
      } catch (err) {
        console.warn("word timing fetch failed", err);
      }
    },
    [verses],
  );

  /** Play a URL (reciter word/ayah, or an object URL of your recording). */
  const playUrl = useCallback((url: string) => {
    const el = playbackRef.current;
    if (!el) return;
    el.pause();
    el.src = url;
    void el.play().catch(() => undefined);
  }, []);

  const myBlobFor = useCallback(
    (vi: number): Blob | null => (mode === "record" ? wholeBlobRef.current : segBlobsRef.current.get(vi) ?? null),
    [mode],
  );

  /** Play just YOUR pronunciation of one word (slice of your recording). */
  const playMyWord = useCallback(
    async (vi: number, di: number) => {
      const blob = myBlobFor(vi);
      const span = wordTimesRef.current.get(`${vi}:${di}`);
      if (!blob || !span) return;
      try {
        const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
        if (!Ctx) return;
        const ctx = audioCtxRef.current ?? new Ctx();
        audioCtxRef.current = ctx;
        if (ctx.state === "suspended") void ctx.resume();
        const buf = await ctx.decodeAudioData(await blob.arrayBuffer());
        const start = Math.max(0, span[0] - 0.15);
        const dur = Math.max(0.2, Math.min(buf.duration - start, span[1] - span[0] + 0.3));
        const src = ctx.createBufferSource();
        src.buffer = buf;
        src.connect(ctx.destination);
        src.start(0, start, dur);
      } catch (err) {
        console.warn("word playback failed", err);
      }
    },
    [myBlobFor],
  );

  /** Play YOUR whole recording of one ayah. */
  const playMyAyah = useCallback(
    async (vi: number) => {
      const blob = myBlobFor(vi);
      if (!blob) return;
      if (mode === "record") {
        // Slice the ayah's span out of the full recording using word timings.
        const spans = (verses[vi]?.words ?? []).map((_, di) => wordTimesRef.current.get(`${vi}:${di}`)).filter(Boolean) as [number, number][];
        if (spans.length > 0) {
          try {
            const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
            if (!Ctx) return;
            const ctx = audioCtxRef.current ?? new Ctx();
            audioCtxRef.current = ctx;
            if (ctx.state === "suspended") void ctx.resume();
            const buf = await ctx.decodeAudioData(await blob.arrayBuffer());
            const start = Math.max(0, Math.min(...spans.map((s) => s[0])) - 0.2);
            const end = Math.min(buf.duration, Math.max(...spans.map((s) => s[1])) + 0.3);
            const src = ctx.createBufferSource();
            src.buffer = buf;
            src.connect(ctx.destination);
            src.start(0, start, Math.max(0.3, end - start));
            return;
          } catch {
            /* fall through to whole-blob playback */
          }
        }
      }
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = URL.createObjectURL(blob);
      playUrl(objectUrlRef.current);
    },
    [mode, myBlobFor, playUrl, verses],
  );

  // Send one ayah's audio to the phoneme checker; flag amber/orange words as
  // results come back (a few seconds behind the voice).
  const checkAyahPron = useCallback(
    async (vi: number, blob: Blob) => {
      const verse = verses[vi];
      if (!verse || verse.words.length === 0 || blob.size < 3000) return;
      setPronPending((n) => n + 1);
      try {
        const audioBase64 = await blobToBase64(blob);
        const filename = blob.type.includes("mp4") ? "seg.mp4" : blob.type.includes("ogg") ? "seg.ogg" : "seg.webm";
        const callable = httpsCallable<{ audioBase64: string; filename: string; words: string[] }, PronResponse>(functions, "checkPronunciation");
        // Include the NEXT ayah's words as context: the segment's tail often has
        // the first words of the following ayah (the cut lands after they start
        // it), and giving the aligner those slots keeps ayah vi's own verdicts
        // clean. Only ayah vi's verdicts are applied.
        const ownWords = verse.words.map((w) => w.imlaei || w.text);
        const contextWords = (verses[vi + 1]?.words ?? []).map((w) => w.imlaei || w.text);
        const resp = await callable({ audioBase64, filename, words: [...ownWords, ...contextWords] });
        const list = (resp.data?.words ?? []).slice(0, ownWords.length);
        const flags: Record<string, PronFlag> = {};
        const notes: string[] = [];
        const hl = (n?: string | null) => (n ? `${t(n)} (${HARAKAH_GLYPH[n] ?? ""})` : "");
        list.forEach((w, di) => {
          if (w.status === "ending") {
            flags[`${vi}:${di}`] = "ending";
            notes.push(`${w.word} — ${t("a harakah sounded like {heard} — it should be {expected}", { heard: hl(w.heard_ending), expected: hl(w.expected_ending) })}`);
          } else if (w.status === "sound") {
            flags[`${vi}:${di}`] = "sound";
            notes.push(`${w.word} — ${t("a sound in this word needs checking")}`);
          }
          // "missed" is the follow matcher's job (skips already beep) — no overlay.
        });
        if (Object.keys(flags).length > 0) {
          setPronFlags((prev) => ({ ...prev, ...flags }));
          setPronNotes((prev) => [...prev, ...notes]);
          beepDouble();
          // Keep your audio + fetch word timings so flagged words are replayable.
          segBlobsRef.current.set(vi, blob);
          void fetchWordTimings(vi, audioBase64, filename);
        }
      } catch (err) {
        console.warn("follow-along pronunciation check failed", err);
      } finally {
        setPronPending((n) => Math.max(0, n - 1));
      }
    },
    [verses, t, beepDouble, fetchWordTimings],
  );

  /** Start a fresh segment recorder with its own chunk store (closure). */
  const startSegmentRecorder = useCallback((stream: MediaStream): { rec: MediaRecorder; chunks: Blob[] } => {
    const chunks: Blob[] = [];
    const rec = new MediaRecorder(stream);
    rec.ondataavailable = (e) => {
      if (e.data.size > 0) chunks.push(e.data);
    };
    rec.start();
    return { rec, chunks };
  }, []);

  // Close the current live audio segment (one ayah) and send it for checking.
  // The NEXT recorder starts BEFORE the old one stops (both can record the same
  // stream), so there is no audio gap at the boundary — v1 gapped here and lost
  // the tail of every ayah, mangling the checks.
  const rotateSegment = useCallback(
    (nextAyah: number) => {
      const old = liveSegRef.current;
      const stream = streamRef.current;
      // Jitter guard: interim ASR flickers — never cut a segment shorter than 1.2s.
      if (Date.now() - segStartedRef.current < 1200) return;
      const finishedAyah = segAyahRef.current;
      segAyahRef.current = nextAyah;
      segStartedRef.current = Date.now();
      if (!stream || !stream.active) return;
      try {
        liveSegRef.current = startSegmentRecorder(stream);
      } catch {
        liveSegRef.current = null;
        return;
      }
      if (old && old.rec.state !== "inactive") {
        old.rec.onstop = () => {
          const blob = new Blob(old.chunks, { type: old.chunks[0]?.type || "audio/webm" });
          void checkAyahPron(finishedAyah, blob);
        };
        try {
          old.rec.stop();
        } catch {
          /* ignore */
        }
      }
    },
    [checkAyahPron, startSegmentRecorder],
  );

  /** Stop the live recorder, check the final segment, release the mic. */
  const finalizeLiveRecorder = useCallback(() => {
    const seg = liveSegRef.current;
    liveSegRef.current = null;
    if (seg && seg.rec.state !== "inactive") {
      const finishedAyah = segAyahRef.current;
      seg.rec.onstop = () => {
        const blob = new Blob(seg.chunks, { type: seg.chunks[0]?.type || "audio/webm" });
        void checkAyahPron(finishedAyah, blob);
        stopStream();
      };
      try {
        seg.rec.stop();
      } catch {
        stopStream();
      }
    } else {
      stopStream();
    }
  }, [checkAyahPron, stopStream]);

  // ---- LIVE mode ----

  const finishSession = useCallback(() => {
    activeRef.current = false;
    recRef.current?.abort();
    recRef.current = null;
    finalizeLiveRecorder();
    setPhase("done");
    beep(false);
  }, [beep, finalizeLiveRecorder]);

  const launchRecognition = useCallback(() => {
    const SR = getSpeechRecognition();
    if (!SR) return;
    const rec = new SR();
    rec.lang = "ar-SA";
    rec.continuous = true;
    rec.interimResults = true;
    rec.maxAlternatives = 1;
    processedRef.current = 0;

    rec.onresult = (event: SpeechResultEvent) => {
      const matcher = matcherRef.current;
      if (!matcher) return;
      let finalText = "";
      let live = "";
      for (let i = 0; i < event.results.length; i += 1) {
        const res = event.results[i];
        const text = res[0]?.transcript ?? "";
        if (res.isFinal) finalText += `${text} `;
        else live += text;
      }
      setInterim(live.trim());
      const instTokens = tokenize(finalText);
      let beeped = false;
      for (let i = processedRef.current; i < instTokens.length; i += 1) {
        allTokensRef.current.push(instTokens[i]);
        const outcome = matcher.push(instTokens[i]);
        if (outcome === "slip" && !beeped) {
          beep(true);
          beeped = true;
        }
      }
      processedRef.current = instTokens.length;

      // Live highlight by STATELESS alignment: align everything recited so far
      // (finalized words + the live interim) against the whole surah and light up
      // the matched words. Because it recomputes from scratch each update, it
      // keeps following after a mistake — unlike a forward pointer, which can get
      // stuck. Slip/beep decisions stay on the committed matcher (finals only).
      const recited = allTokensRef.current.concat(tokenize(live));
      let reachedEnd = matcher.done;
      if (flatExpected.length > 0 && flatExpected.length <= 600) {
        const res = checkRecitation(flatExpected, recited.join(" "));
        const wd = ayahTokens.map((toks) => toks.map(() => false));
        let last = -1;
        for (let i = 0; i < res.correct.length; i += 1) {
          if (res.correct[i]) {
            const m = flatToAyah[i];
            wd[m.vi][m.tok] = true;
            last = i;
          }
        }
        setWordDone(wd);
        const nextFlat = last + 1;
        const previewAyah = nextFlat < flatToAyah.length ? flatToAyah[nextFlat].vi : verses.length - 1;
        setCur(nextFlat < flatToAyah.length ? { ayah: previewAyah, pos: flatToAyah[nextFlat].tok } : { ayah: verses.length - 1, pos: -1 });
        setAyahStatus([...matcher.ayahStatus]);
        setSlips(matcher.slips);
        // Segment on the INTERIM position — it tracks the voice almost live,
        // unlike finalized text which lags a full ayah behind. Forward-only so
        // repeats keep accumulating into the same segment.
        if (previewAyah > segAyahRef.current) rotateSegment(previewAyah);
        // Finished once the alignment reaches the last word of the surah — robust
        // to slips that would otherwise leave the forward pointer stuck short.
        if (last >= flatExpected.length - 1) reachedEnd = true;
      } else {
        syncFromMatcher(matcher);
        if (matcher.currentAyah > segAyahRef.current) rotateSegment(matcher.currentAyah);
      }
      if (reachedEnd) finishSession();
    };
    rec.onerror = (event: { error?: string }) => {
      const code = event.error ?? "";
      if (code === "no-speech" || code === "aborted") return;
      if (code === "not-allowed" || code === "service-not-allowed") {
        activeRef.current = false;
        setErrorMsg(t("Microphone access was blocked. Allow the mic in your browser and try again."));
        setPhase("error");
      }
    };
    rec.onend = () => {
      if (activeRef.current && !(matcherRef.current?.done ?? true)) {
        try {
          launchRecognition();
        } catch {
          /* ignore */
        }
      }
    };
    recRef.current = rec;
    try {
      rec.start();
    } catch {
      /* ignore */
    }
  }, [beep, finishSession, rotateSegment, syncFromMatcher, t]);

  // Parallel mic recorder for live mode — feeds per-ayah pronunciation checks.
  // Non-fatal if unavailable: the follow-along works without it.
  const setupLiveRecorder = useCallback(async () => {
    if (!supportsRecording()) {
      setPronOff(true);
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      segAyahRef.current = 0;
      segStartedRef.current = Date.now();
      liveSegRef.current = startSegmentRecorder(stream);
      setPronOff(false);
    } catch {
      setPronOff(true);
    }
  }, [startSegmentRecorder]);

  const startLive = useCallback(() => {
    freshMatcher();
    allTokensRef.current = [];
    setInterim("");
    setErrorMsg("");
    setPronFlags({});
    setPronNotes([]);
    setPronPending(0);
    setPickWord(null);
    segBlobsRef.current.clear();
    wordTimesRef.current.clear();
    wholeBlobRef.current = null;
    activeRef.current = true;
    setPhase("listening");
    void setupLiveRecorder();
    launchRecognition();
  }, [freshMatcher, launchRecognition, setupLiveRecorder]);

  // ---- RECORD mode (iPhone/iPad) ----

  const replayAnalysis = useCallback(
    async (text: string) => {
      const matcher = freshMatcher();
      abortRef.current = false;
      setPhase("listening");
      const tokens = tokenize(text);
      for (let i = 0; i < tokens.length; i += 1) {
        if (abortRef.current) return;
        const outcome = matcher.push(tokens[i]);
        if (outcome === "slip") beep(true);
        syncFromMatcher(matcher);
        // eslint-disable-next-line no-await-in-loop
        await new Promise((r) => setTimeout(r, 130));
      }
      if (abortRef.current) return;
      setPhase("done");
      beep(false);
    },
    [beep, freshMatcher, syncFromMatcher],
  );

  const analyze = useCallback(
    async (blob: Blob) => {
      setPhase("transcribing");
      setPronFlags({});
      setPronNotes([]);
      setPickWord(null);
      wordTimesRef.current.clear();
      try {
        const audioBase64 = await blobToBase64(blob);
        const filename = blob.type.includes("mp4") ? "recitation.mp4" : blob.type.includes("ogg") ? "recitation.ogg" : "recitation.webm";
        const transcribe = httpsCallable<{ audioBase64: string; filename: string }, TranscribeResponse>(functions, "transcribeRecitation");
        const pron = httpsCallable<{ audioBase64: string; filename: string; words: string[] }, PronResponse>(functions, "checkPronunciation");
        const allWords = verses.flatMap((v) => v.words.map((w) => w.imlaei || w.text));
        const flatMap = verses.flatMap((v, vi) => v.words.map((_, di) => ({ vi, di })));
        const [trResp, prResp] = await Promise.allSettled([
          transcribe({ audioBase64, filename }),
          pron({ audioBase64, filename, words: allWords }),
        ]);
        // Pronunciation flags overlay the replay (non-fatal if this half failed).
        if (prResp.status === "fulfilled") {
          const list = prResp.value.data?.words ?? [];
          const flags: Record<string, PronFlag> = {};
          const notes: string[] = [];
          const hl = (n?: string | null) => (n ? `${t(n)} (${HARAKAH_GLYPH[n] ?? ""})` : "");
          list.forEach((w, i) => {
            const at = flatMap[i];
            if (!at) return;
            if (w.status === "ending") {
              flags[`${at.vi}:${at.di}`] = "ending";
              notes.push(`${w.word} — ${t("a harakah sounded like {heard} — it should be {expected}", { heard: hl(w.heard_ending), expected: hl(w.expected_ending) })}`);
            } else if (w.status === "sound") {
              flags[`${at.vi}:${at.di}`] = "sound";
              notes.push(`${w.word} — ${t("a sound in this word needs checking")}`);
            }
          });
          setPronFlags(flags);
          setPronNotes(notes);
          if (notes.length > 0) beepDouble();
        }
        if (trResp.status !== "fulfilled") throw new Error("transcription failed");
        // Keep the recording + map transcript word timings onto every ayah word,
        // so flagged words are replayable ("your word vs the reciter's").
        wholeBlobRef.current = blob;
        const spoken = trResp.value.data?.words ?? [];
        if (spoken.length > 0) {
          const expectedSkels = flatMap.map(({ vi, di }) => normalizeArabic(verses[vi].words[di].text));
          const spokenSkels = spoken.map((w) => normalizeArabic(w.word));
          const pair = alignSpokenToExpected(expectedSkels, spokenSkels);
          pair.forEach((si, fi) => {
            const at = flatMap[fi];
            if (si != null && spoken[si] && at) wordTimesRef.current.set(`${at.vi}:${at.di}`, [spoken[si].start, spoken[si].end]);
          });
        }
        await replayAnalysis(trResp.value.data?.text ?? "");
      } catch (err) {
        console.error("follow-along transcription failed", err);
        setErrorMsg(t("We couldn't check that recitation. Please try again."));
        setPhase("error");
      }
    },
    [beepDouble, replayAnalysis, t, verses],
  );

  const startRecord = useCallback(async () => {
    freshMatcher();
    setErrorMsg("");
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      chunksRef.current = [];
      const rec = new MediaRecorder(stream);
      rec.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };
      rec.onstop = () => {
        stopStream();
        const blob = new Blob(chunksRef.current, { type: chunksRef.current[0]?.type || "audio/webm" });
        void analyze(blob);
      };
      mediaRef.current = rec;
      rec.start();
      setPhase("recording");
    } catch (err) {
      stopStream();
      const name = (err as { name?: string })?.name;
      setErrorMsg(
        name === "NotAllowedError" || name === "SecurityError"
          ? t("Microphone access was blocked. Allow the mic in your browser and try again.")
          : t("We couldn't reach your microphone. Please try again."),
      );
      setPhase("error");
    }
  }, [analyze, freshMatcher, stopStream, t]);

  const stopRecord = useCallback(() => {
    if (mediaRef.current && mediaRef.current.state !== "inactive") mediaRef.current.stop();
  }, []);

  // ---- Shared controls ----

  const start = useCallback(() => {
    if (mode === "live") startLive();
    else if (mode === "record") void startRecord();
    else setPhase("unsupported");
  }, [mode, startLive, startRecord]);

  const stop = useCallback(() => {
    if (mode === "live") {
      activeRef.current = false;
      recRef.current?.abort();
      recRef.current = null;
      finalizeLiveRecorder();
      setPhase("done");
    } else if (phase === "recording") {
      stopRecord();
    } else {
      abortRef.current = true;
      setPhase("done");
    }
  }, [finalizeLiveRecorder, mode, phase, stopRecord]);

  useEffect(
    () => () => {
      activeRef.current = false;
      abortRef.current = true;
      recRef.current?.abort();
      recRef.current = null;
      if (mediaRef.current && mediaRef.current.state !== "inactive") mediaRef.current.stop();
      if (liveSegRef.current && liveSegRef.current.rec.state !== "inactive") {
        liveSegRef.current.rec.onstop = null;
        liveSegRef.current.rec.stop();
      }
      liveSegRef.current = null;
      streamRef.current?.getTracks().forEach((tr) => tr.stop());
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current);
      void audioCtxRef.current?.close();
    },
    [],
  );

  useEffect(() => {
    if (phase !== "listening") return;
    document.getElementById(`fa-v-${cur.ayah}`)?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [cur.ayah, phase]);

  const doneCount = useMemo(() => ayahStatus.filter((s) => s === "done").length, [ayahStatus]);
  const total = verses.length;
  const progressPct = total ? Math.round((Math.min(cur.ayah, total) / total) * 100) : 0;

  const wordClass = (vi: number, di: number): string => {
    const tok = wordTok[vi]?.[di] ?? -1;
    const isCurrent = phase === "listening" && cur.ayah === vi && cur.pos === tok && tok >= 0;
    if (isCurrent) return "bg-[#CFF3F0] text-[#0F172A] ring-2 ring-[#0E7490]";
    // Pronunciation flags outrank the green — a recited-but-mispronounced word.
    const flag = pronFlags[`${vi}:${di}`];
    if (flag === "ending") return "bg-[#FEF3C7] text-[#92400E]";
    if (flag === "sound") return "bg-[#FFEDD5] text-[#9A3412]";
    if (ayahStatus[vi] === "missed") return "text-[#B91C1C]";
    const isDone = tok >= 0 && (wordDone[vi]?.[tok] ?? false);
    if (isDone) return "text-[#166534]";
    return "text-[#94A3B8]";
  };

  const badgeClass = (vi: number): string => {
    switch (ayahStatus[vi]) {
      case "missed":
        return "border-[#DC2626] bg-[#FEE2E2] text-[#B91C1C]";
      case "done":
        return "border-[#16A34A] bg-[#DCFCE7] text-[#166534]";
      case "current":
        return "border-[#0E7490] bg-[#CFF3F0] text-[#0E7490]";
      default:
        return "border-[#0E7490]/30 text-[#0E7490]";
    }
  };

  return (
    <div className="fixed inset-0 z-40 flex flex-col bg-white">
      <audio ref={playbackRef} className="hidden" />
      <header className="flex items-center justify-between border-b border-[#F1F5F9] px-5 py-3.5">
        <div className="min-w-0">
          <h2 className="truncate text-base font-black text-[#0F172A]">{t("Recite from memory")}</h2>
          <p className="truncate text-xs font-bold text-[#64748B]">{title}</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setMuted((m) => !m)}
            aria-label={muted ? t("Unmute alerts") : t("Mute alerts")}
            className={`grid h-9 w-9 place-items-center rounded-full ${muted ? "bg-[#FEE2E2] text-[#B91C1C]" : "bg-[#F1F5F9] text-[#334155]"}`}
          >
            <Volume2 size={18} />
          </button>
          <button type="button" onClick={onClose} aria-label={t("Close")} className="grid h-9 w-9 place-items-center rounded-full bg-[#F1F5F9] text-[#334155] hover:bg-[#E2E8F0]">
            <X size={18} />
          </button>
        </div>
      </header>

      <div className="border-b border-[#F1F5F9] px-5 py-2.5">
        <div className="flex items-center justify-between text-xs font-black text-[#0F172A]">
          <span>{t("Ayah {n} of {total}", { n: Math.min(cur.ayah + 1, total), total })}</span>
          <span className="flex items-center gap-3">
            <span className="text-[#16A34A]">{t("{n} done", { n: doneCount })}</span>
            {slips > 0 ? <span className="text-[#DC2626]">{t("{n} slips", { n: slips })}</span> : null}
          </span>
        </div>
        <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-[#F1F5F9]">
          <div className="h-full rounded-full bg-[#0E7490] transition-all" style={{ width: `${progressPct}%` }} />
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto px-5 py-6">
        {phase === "unsupported" ? (
          <p className="mx-auto max-w-md rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-bold text-amber-800">
            {t("This browser can't record or recognize speech. Try Chrome, Edge, or Safari.")}
          </p>
        ) : null}
        {phase === "error" ? (
          <p className="mx-auto mb-4 max-w-md rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-bold text-red-700">{errorMsg}</p>
        ) : null}

        <div
          dir="rtl"
          className="mx-auto max-w-[820px] text-justify text-[30px] leading-[2.9]"
          style={{ fontFamily: "'Amiri','Scheherazade New','Traditional Arabic',serif", textAlignLast: "center" }}
        >
          {verses.map((verse, vi) => (
            <span key={verse.verseKey} id={`fa-v-${vi}`}>
              {verse.words.map((word, di) => {
                const flagged = Boolean(pronFlags[`${vi}:${di}`]);
                return (
                  <span
                    key={word.position}
                    onClick={flagged ? () => setPickWord({ vi, di }) : undefined}
                    className={`rounded px-0.5 transition ${wordClass(vi, di)} ${flagged ? "cursor-pointer underline decoration-dotted underline-offset-8" : ""}`}
                  >
                    {flagged ? <span className="mx-0.5 align-super text-[13px] text-[#B45309]">▶</span> : null}
                    {word.text}{" "}
                  </span>
                );
              })}
              <span dir="ltr" className={`mx-0.5 inline-flex h-7 w-7 items-center justify-center rounded-full border align-middle text-[13px] ${badgeClass(vi)}`}>
                {verse.verseNumber}
              </span>{" "}
            </span>
          ))}
        </div>

        {pronNotes.length > 0 ? (
          <div className="mx-auto mt-5 max-w-[820px] rounded-2xl border border-[#FDE68A] bg-[#FFFBEB] p-4">
            <p className="text-xs font-black text-[#92400E]">{t("Pronunciation to review")}</p>
            <ul className="mt-1 space-y-1">
              {pronNotes.map((note, k) => (
                <li key={`${note}-${k}`} dir="rtl" className="text-sm font-bold text-[#92400E]" style={{ fontFamily: "'Amiri',serif" }}>
                  {note}
                </li>
              ))}
            </ul>
            <p className="mt-2 text-[11px] font-bold text-[#B45309]">{t("Tap a highlighted word above to compare your pronunciation with the reciter's.")}</p>
          </div>
        ) : null}
      </div>

      {pickWord ? (
        <div className="border-t border-[#FDE68A] bg-[#FFFBEB] px-5 py-3">
          <div className="mx-auto flex max-w-[820px] items-center justify-between">
            <span dir="rtl" className="text-lg font-black text-[#92400E]" style={{ fontFamily: "'Amiri',serif" }}>
              {verses[pickWord.vi]?.words[pickWord.di]?.text}
            </span>
            <button type="button" onClick={() => setPickWord(null)} aria-label={t("Close")} className="grid h-8 w-8 place-items-center rounded-full bg-white text-[#92400E]">
              <X size={15} />
            </button>
          </div>
          <div className="mx-auto mt-2 grid max-w-[820px] grid-cols-2 gap-2 sm:grid-cols-4">
            <button
              type="button"
              onClick={() => void playMyWord(pickWord.vi, pickWord.di)}
              disabled={!wordTimesRef.current.has(`${pickWord.vi}:${pickWord.di}`) || !myBlobFor(pickWord.vi)}
              className="flex min-h-10 items-center justify-center gap-1.5 rounded-xl bg-white px-2 text-xs font-black text-[#92400E] shadow-sm disabled:opacity-40"
            >
              <Mic size={13} /> {t("You · word")}
            </button>
            <button
              type="button"
              onClick={() => {
                const url = verses[pickWord.vi]?.words[pickWord.di]?.audioUrl;
                if (url) playUrl(url);
              }}
              disabled={!verses[pickWord.vi]?.words[pickWord.di]?.audioUrl}
              className="flex min-h-10 items-center justify-center gap-1.5 rounded-xl bg-[#0E7490] px-2 text-xs font-black text-white disabled:opacity-40"
            >
              <Volume2 size={13} /> {t("Reciter · word")}
            </button>
            <button
              type="button"
              onClick={() => void playMyAyah(pickWord.vi)}
              disabled={!myBlobFor(pickWord.vi)}
              className="flex min-h-10 items-center justify-center gap-1.5 rounded-xl bg-white px-2 text-xs font-black text-[#92400E] shadow-sm disabled:opacity-40"
            >
              <Mic size={13} /> {t("You · ayah")}
            </button>
            <button
              type="button"
              onClick={() => {
                const url = verses[pickWord.vi]?.audioUrl;
                if (url) playUrl(url);
              }}
              disabled={!verses[pickWord.vi]?.audioUrl}
              className="flex min-h-10 items-center justify-center gap-1.5 rounded-xl bg-[#0E7490] px-2 text-xs font-black text-white disabled:opacity-40"
            >
              <Volume2 size={13} /> {t("Reciter · ayah")}
            </button>
          </div>
        </div>
      ) : null}

      <footer className="border-t border-[#F1F5F9] px-5 py-4">
        {phase === "listening" && mode === "live" && interim ? (
          <p className="mb-2 truncate text-center text-xs font-bold text-[#0E7490]" dir="rtl" style={{ fontFamily: "'Amiri',serif" }}>{interim}</p>
        ) : null}
        {pronPending > 0 ? (
          <p className="mb-1 flex items-center justify-center gap-1.5 text-center text-[11px] font-bold text-[#0E7490]">
            <Loader2 size={11} className="animate-spin" /> {t("Checking pronunciation…")}
          </p>
        ) : null}
        {phase === "listening" && mode === "live" && pronOff ? (
          <p className="mb-1 text-center text-[11px] font-bold text-[#94A3B8]">{t("Pronunciation check unavailable on this device.")}</p>
        ) : null}
        {phase === "recording" ? (
          <p className="mb-2 flex items-center justify-center gap-2 text-center text-xs font-black text-[#DC2626]">
            <span className="inline-block h-2.5 w-2.5 animate-pulse rounded-full bg-[#DC2626]" /> {t("Recording… recite the surah, then tap stop.")}
          </p>
        ) : null}
        {phase === "transcribing" ? (
          <p className="mb-2 flex items-center justify-center gap-2 text-center text-xs font-bold text-[#0E7490]">
            <Loader2 size={14} className="animate-spin" /> {t("Checking your recitation…")}
          </p>
        ) : null}

        <div className="mx-auto max-w-md">
          {phase === "recording" ? (
            <button type="button" onClick={stop} className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#DC2626] px-4 py-3.5 text-sm font-black text-white">
              <Square size={16} /> {t("Stop & check")}
            </button>
          ) : phase === "transcribing" ? (
            <button type="button" disabled className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#94A3B8] px-4 py-3.5 text-sm font-black text-white">
              <Loader2 size={16} className="animate-spin" /> {t("Checking…")}
            </button>
          ) : phase === "listening" ? (
            <button type="button" onClick={stop} className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#DC2626] px-4 py-3.5 text-sm font-black text-white">
              <Square size={16} /> {t("Stop")}
            </button>
          ) : phase === "done" ? (
            <div className="flex gap-2">
              <button type="button" onClick={start} className="flex flex-1 items-center justify-center gap-2 rounded-2xl bg-[#0E7490] px-4 py-3.5 text-sm font-black text-white">
                <RotateCcw size={16} /> {t("Start over")}
              </button>
              <button type="button" onClick={onClose} className="flex items-center justify-center gap-2 rounded-2xl bg-[#F1F5F9] px-5 py-3.5 text-sm font-black text-[#334155]">
                <CheckCircle2 size={16} /> {t("Done")}
              </button>
            </div>
          ) : phase === "unsupported" ? (
            <button type="button" onClick={onClose} className="w-full rounded-2xl bg-[#F1F5F9] px-4 py-3.5 text-sm font-black text-[#334155]">{t("Close")}</button>
          ) : (
            <button type="button" onClick={start} className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#0E7490] px-4 py-3.5 text-sm font-black text-white">
              <Mic size={16} /> {t("Start reciting")}
            </button>
          )}
        </div>
        <p className="mt-2 text-center text-[11px] font-bold text-[#94A3B8]">
          {mode === "record"
            ? t("Recite the surah, then it checks it and replays where you slipped.")
            : t("Repeat freely — skips beep right away, and pronunciation is checked ayah by ayah as you go.")}
        </p>
      </footer>
    </div>
  );
}
