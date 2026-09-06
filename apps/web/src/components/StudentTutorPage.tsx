"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Bot, CalendarClock, Loader2, Menu, Mic, MicOff, Square, Volume2 } from "lucide-react";
import { auth, functions } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell, openStudentMobileMenu } from "@/components/StudentDashboardHome";

/**
 * The student AI tutor, hands-free.
 *
 * The phone (or laptop) does the listening and the speaking through the
 * browser's own speech engines, so nothing is billed per minute. The student
 * starts a session and simply talks: when they pause, what they said goes to
 * the tutor, the answer is read aloud, and listening resumes. Tapping the
 * big button while the tutor is talking interrupts it. There is no
 * push-to-talk — the only button ends the session.
 */

type Slot = { slotKey: string; startIso: string; endIso: string; seatsLeft: number; mine: boolean };
type Booking = { id: string; slotKey: string; startIso: string };
type Availability = {
  settings: { enabled: boolean; seats: number; sessionMinutes: number; maxBookingsPerDay: number; windowStart: string; windowEnd: string; timezone: string };
  studentName: string;
  slots: Slot[];
  myBookings: Booking[];
  canStartNow: boolean;
  seatsFreeNow: number;
  seatsTotal: number;
  activeSession: { id: string; expiresAt: string | null } | null;
};
type Message = { role: "user" | "assistant"; text: string };
type Phase = "idle" | "listening" | "thinking" | "speaking";
type Lang = "en" | "fr" | "ar";

// The browser's speech recognizer is not in TypeScript's DOM lib; this is the
// slice of it we use (Chrome, Edge, Safari expose it as webkitSpeechRecognition).
type Recognizer = {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  maxAlternatives: number;
  onresult: ((ev: SpeechRecognitionEvent) => void) | null;
  onerror: ((ev: { error: string }) => void) | null;
  onend: (() => void) | null;
  start: () => void;
  abort: () => void;
};
type RecognizerCtor = new () => Recognizer;

const LANGS: { id: Lang; label: string; bcp47: string }[] = [
  { id: "en", label: "English", bcp47: "en-US" },
  { id: "fr", label: "Français", bcp47: "fr-FR" },
  { id: "ar", label: "العربية", bcp47: "ar-SA" },
];

const call = <I, O>(name: string) => httpsCallable<I, O>(functions, name);

const speechCtor = (): RecognizerCtor | null => {
  if (typeof window === "undefined") return null;
  const w = window as unknown as { SpeechRecognition?: RecognizerCtor; webkitSpeechRecognition?: RecognizerCtor };
  return w.SpeechRecognition || w.webkitSpeechRecognition || null;
};

// Browsers list dozens of voices per language and put the poor ones first.
// Prefer the natural network voices (Chrome's Google voices, Edge's Microsoft
// Natural voices), then the good built-in Apple voices, and never a novelty.
const NOVELTY = /albert|bad news|bahh|bells|boing|bubbles|cellos|eddy|flo\b|fred|good news|grandma|grandpa|jester|junior|kathy|organ|ralph|reed|rocko|sandy|shelley|superstar|trinoids|whisper|wobble|zarvox/i;
const PREFERRED: Record<Lang, RegExp[]> = {
  en: [/google us english/i, /google uk english female/i, /microsoft .*(aria|jenny|guy|ryan|sonia).*natural/i, /natural|neural|premium|enhanced/i, /^samantha$/i, /^daniel$/i, /^karen$/i, /^moira$/i, /^tessa$/i, /^rishi$/i],
  fr: [/google français/i, /microsoft .*(denise|henri|vivienne).*natural/i, /natural|neural|premium|enhanced/i, /^thomas$/i, /^audrey/i, /^aur[ée]lie/i, /^am[ée]lie$/i, /^jacques$/i],
  ar: [/google/i, /microsoft .*(salma|shakir|hamed|zariyah).*natural/i, /natural|neural|premium|enhanced/i, /^majed$/i, /^maged$/i, /^tarik$/i, /^laila$/i],
};
const pickVoice = (lang: Lang): SpeechSynthesisVoice | null => {
  const prefix = lang === "ar" ? "ar" : lang === "fr" ? "fr" : "en";
  const candidates = (window.speechSynthesis?.getVoices() ?? []).filter((v) => v.lang.toLowerCase().startsWith(prefix) && !NOVELTY.test(v.name));
  for (const pattern of PREFERRED[lang]) {
    const hit = candidates.find((v) => pattern.test(v.name));
    if (hit) return hit;
  }
  return candidates.find((v) => !v.localService) || candidates[0] || null;
};

// Chrome hands back an empty voice list until it has loaded them once.
const voicesReady = (): Promise<void> => new Promise((resolve) => {
  const synth = window.speechSynthesis;
  if (!synth || synth.getVoices().length) { resolve(); return; }
  const done = () => { synth.removeEventListener("voiceschanged", done); resolve(); };
  synth.addEventListener("voiceschanged", done);
  window.setTimeout(done, 1500);
});

const fmtHour = (iso: string, tz: string) =>
  new Date(iso).toLocaleTimeString("en-US", { hour: "numeric", timeZone: tz });
const fmtDay = (iso: string, tz: string) =>
  new Date(iso).toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric", timeZone: tz });

export function StudentTutorPage() {
  const [user, setUser] = useState<User | null>(null);
  const [access, setAccess] = useState<"checking" | "signedOut" | "allowed" | "denied">("checking");
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [avail, setAvail] = useState<Availability | null>(null);
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  // Session state
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [expiresAt, setExpiresAt] = useState<Date | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [phase, setPhase] = useState<Phase>("idle");
  const [lang, setLang] = useState<Lang>("en");
  const [heard, setHeard] = useState("");
  const [typed, setTyped] = useState("");
  const [now, setNow] = useState(() => Date.now());
  const recRef = useRef<Recognizer | null>(null);
  const aliveRef = useRef(false);
  const phaseRef = useRef<Phase>("idle");
  const langRef = useRef<Lang>("en");
  const messagesRef = useRef<Message[]>([]);
  const sessionRef = useRef<string | null>(null);
  const supported = useMemo(() => Boolean(speechCtor()), []);

  useEffect(() => { phaseRef.current = phase; }, [phase]);
  useEffect(() => { langRef.current = lang; }, [lang]);
  useEffect(() => { messagesRef.current = messages; }, [messages]);
  useEffect(() => { sessionRef.current = sessionId; }, [sessionId]);

  const loadAvailability = useCallback(async () => {
    try {
      const res = await call<{ days: number }, Availability>("aiTutorGetAvailability")({ days: 2 });
      setAvail(res.data);
    } catch (e) {
      setNotice(e instanceof Error ? e.message : "Could not load the tutor.");
    }
  }, []);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (!u) { setAccess("signedOut"); return; }
      try {
        const session = await resolveStudentSession(u);
        setSummary(session.summary);
        setIsAdultStudent(session.isAdultStudent);
        setAccess("allowed");
        await loadAvailability();
      } catch {
        setAccess("denied");
      }
    });
    return unsub;
  }, [loadAvailability]);

  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, []);

  /* ---------------------------------------------------- the voice loop -- */

  const stopListening = useCallback(() => {
    try { recRef.current?.abort(); } catch { /* already stopped */ }
    recRef.current = null;
  }, []);

  const speak = useCallback((text: string, replyLang: Lang, onDone: () => void) => {
    if (!window.speechSynthesis) { onDone(); return; }
    window.speechSynthesis.cancel();
    void voicesReady().then(() => {
      if (!aliveRef.current) { onDone(); return; }
      const utter = new SpeechSynthesisUtterance(text);
      const voice = pickVoice(replyLang);
      if (voice) utter.voice = voice;
      utter.lang = voice?.lang || (LANGS.find((l) => l.id === replyLang)?.bcp47 ?? "en-US");
      utter.rate = 1;
      utter.pitch = 1;
      utter.onend = onDone;
      utter.onerror = onDone;
      window.speechSynthesis.speak(utter);
    });
  }, []);

  const listen = useCallback(() => {
    const Ctor = speechCtor();
    if (!Ctor || !aliveRef.current) return;
    stopListening();
    const rec = new Ctor();
    rec.lang = LANGS.find((l) => l.id === langRef.current)?.bcp47 ?? "en-US";
    rec.interimResults = true;
    rec.continuous = false; // one utterance, then we answer
    rec.maxAlternatives = 1;
    let finalText = "";
    rec.onresult = (ev: SpeechRecognitionEvent) => {
      let interim = "";
      for (let i = ev.resultIndex; i < ev.results.length; i += 1) {
        const r = ev.results[i];
        if (r.isFinal) finalText += r[0].transcript; else interim += r[0].transcript;
      }
      setHeard(finalText || interim);
    };
    rec.onerror = (ev) => {
      if (ev.error === "not-allowed" || ev.error === "service-not-allowed") {
        setNotice("Microphone access is blocked. Allow the microphone for this site, or type below.");
        aliveRef.current = false;
        setPhase("idle");
      }
    };
    rec.onend = () => {
      recRef.current = null;
      if (!aliveRef.current) return;
      const text = finalText.trim();
      if (text) void submit(text); // eslint-disable-line @typescript-eslint/no-use-before-define
      else if (phaseRef.current === "listening") window.setTimeout(listen, 250); // silence: keep listening
    };
    recRef.current = rec;
    setPhase("listening");
    setHeard("");
    try { rec.start(); } catch { window.setTimeout(listen, 500); }
  }, [stopListening]);

  const submit = useCallback(async (text: string) => {
    const sid = sessionRef.current;
    if (!sid || !text.trim()) return;
    stopListening();
    setHeard("");
    setPhase("thinking");
    const next: Message[] = [...messagesRef.current, { role: "user", text: text.trim() }];
    setMessages(next);
    try {
      const res = await call<{ sessionId: string; messages: Message[] }, { reply: string; language: Lang; expiresAt: string }>("aiTutorTurn")({ sessionId: sid, messages: next });
      const reply = res.data.reply;
      setMessages([...next, { role: "assistant", text: reply }]);
      setExpiresAt(new Date(res.data.expiresAt));
      if (!aliveRef.current) return;
      setPhase("speaking");
      speak(reply, res.data.language, () => { if (aliveRef.current) listen(); });
    } catch (e) {
      const msg = e instanceof Error ? e.message : "The tutor could not answer.";
      setNotice(msg);
      if (/hour is up|has ended/i.test(msg)) { aliveRef.current = false; setSessionId(null); setPhase("idle"); void loadAvailability(); return; }
      if (aliveRef.current) listen();
    }
  }, [listen, speak, stopListening, loadAvailability]);

  const startSession = useCallback(async () => {
    setBusy("start"); setNotice("");
    try {
      const res = await call<Record<string, never>, { sessionId: string; expiresAt: string; resumed: boolean; studentName: string }>("aiTutorStartSession")({});
      setSessionId(res.data.sessionId);
      setExpiresAt(new Date(res.data.expiresAt));
      aliveRef.current = true;
      const greeting = `Assalamu alaikum ${res.data.studentName}. I'm Alluwal, your tutor. What are we working on today?`;
      setMessages([{ role: "assistant", text: greeting }]);
      if (supported) {
        setPhase("speaking");
        speak(greeting, "en", () => { if (aliveRef.current) listen(); });
      } else {
        setPhase("idle");
      }
    } catch (e) {
      setNotice(e instanceof Error ? e.message : "Could not start.");
      await loadAvailability();
    } finally {
      setBusy(null);
    }
  }, [listen, speak, supported, loadAvailability]);

  const endSession = useCallback(async () => {
    aliveRef.current = false;
    stopListening();
    window.speechSynthesis?.cancel();
    const sid = sessionRef.current;
    setPhase("idle");
    setSessionId(null);
    if (sid) { try { await call<{ sessionId: string }, unknown>("aiTutorEndSession")({ sessionId: sid }); } catch { /* the sweeper closes it */ } }
    await loadAvailability();
  }, [stopListening, loadAvailability]);

  // Tapping while the tutor speaks interrupts it and hands the floor back.
  const interrupt = useCallback(() => {
    if (phaseRef.current === "speaking") { window.speechSynthesis?.cancel(); listen(); }
  }, [listen]);

  useEffect(() => () => { aliveRef.current = false; stopListening(); window.speechSynthesis?.cancel(); }, [stopListening]);

  // The clock runs out server-side too; this just stops the loop politely.
  useEffect(() => {
    if (sessionId && expiresAt && expiresAt.getTime() <= now) { setNotice("Your hour is up. Book another one to continue."); void endSession(); }
  }, [now, expiresAt, sessionId, endSession]);

  /* ---------------------------------------------------------- booking -- */

  const book = async (slotKey: string) => {
    setBusy(slotKey); setNotice("");
    try { await call<{ slotKey: string }, unknown>("aiTutorBookSlot")({ slotKey }); await loadAvailability(); }
    catch (e) { setNotice(e instanceof Error ? e.message : "Could not book."); }
    finally { setBusy(null); }
  };
  const cancel = async (bookingId: string) => {
    setBusy(bookingId);
    try { await call<{ bookingId: string }, unknown>("aiTutorCancelBooking")({ bookingId }); await loadAvailability(); }
    finally { setBusy(null); }
  };

  /* ----------------------------------------------------------- render -- */

  if (access === "checking") {
    return <div className="grid min-h-screen place-items-center bg-[#F5F5F5]"><Loader2 className="animate-spin text-[#0E72ED]" size={36} /></div>;
  }
  if (access !== "allowed" || !user) return <StudentAccessPrompt access={access} />;

  const tz = avail?.settings.timezone ?? "America/New_York";
  const remaining = expiresAt ? Math.max(0, Math.floor((expiresAt.getTime() - now) / 1000)) : 0;
  const mm = String(Math.floor(remaining / 60)).padStart(2, "0");
  const ss = String(remaining % 60).padStart(2, "0");
  const byDay = new Map<string, Slot[]>();
  (avail?.slots ?? []).forEach((s) => { const d = fmtDay(s.startIso, tz); byDay.set(d, [...(byDay.get(d) ?? []), s]); });

  return (
    <StudentShell activeLabel="AI Tutor" breadcrumb="Learning / AI Tutor" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="flex min-h-full flex-col bg-[#F8FAFC]">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] bg-white px-4 py-3 lg:hidden">
          <button type="button" aria-label="Open menu" onClick={openStudentMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl"><Menu size={22} /></button>
          <Bot className="text-[#0E72ED]" />
          <h1 className="min-w-0 flex-1 truncate text-lg font-extrabold">AI Tutor</h1>
        </header>

        <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-4 p-4 sm:p-6">
          {notice ? <p role="status" className="rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm font-semibold text-amber-900">{notice}</p> : null}

          {sessionId ? (
            <>
              <div className="flex items-center gap-3 rounded-2xl border border-[#E2E8F0] bg-white p-3">
                <span className="relative grid h-12 w-12 shrink-0 place-items-center rounded-full bg-gradient-to-br from-[#0E72ED] to-[#6366F1] text-white"><Bot size={24} /><span className={`absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-white ${phase === "listening" ? "bg-emerald-500" : phase === "speaking" ? "bg-[#0E72ED]" : "bg-amber-400"}`} /></span>
                <div className="min-w-0 flex-1">
                  <p className="font-extrabold">Alluwal</p>
                  <p className="text-sm text-[#64748B]">{phase === "listening" ? "Listening…" : phase === "thinking" ? "Thinking…" : phase === "speaking" ? "Speaking — tap to interrupt" : "Ready"}</p>
                </div>
                <span className="rounded-lg bg-[#F1F5F9] px-2.5 py-1 text-sm font-black tabular-nums text-[#334155]">{mm}:{ss}</span>
              </div>

              <button type="button" onClick={interrupt} aria-label="Tutor status" className="min-h-64 flex-1 space-y-3 overflow-y-auto rounded-2xl border border-[#E2E8F0] bg-white p-4 text-left">
                {messages.map((m, i) => (
                  <div key={i} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
                    <div className={`max-w-[84%] rounded-2xl px-4 py-3 text-sm ${m.role === "user" ? "bg-[#0E72ED] text-white" : "bg-[#F1F5F9] text-[#334155]"}`}>{m.text}</div>
                  </div>
                ))}
                {heard ? <div className="flex justify-end"><div className="max-w-[84%] rounded-2xl border border-dashed border-[#93C5FD] px-4 py-3 text-sm text-[#1D4ED8]">{heard}</div></div> : null}
              </button>

              <div className="flex flex-wrap items-center gap-2">
                <div className="flex items-center gap-1 rounded-xl bg-[#F1F5F9] p-1">
                  {LANGS.map((l) => (
                    <button key={l.id} type="button" onClick={() => { setLang(l.id); if (phaseRef.current === "listening") listen(); }} className={`min-h-9 rounded-lg px-3 text-xs font-black ${lang === l.id ? "bg-white text-[#0E72ED] shadow" : "text-[#64748B]"}`}>{l.label}</button>
                  ))}
                </div>
                <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#64748B]">{supported ? <><Mic size={14} /> Hands-free</> : <><MicOff size={14} /> Voice not supported here — type instead</>}</span>
                <button type="button" onClick={() => void endSession()} className="ml-auto inline-flex min-h-11 items-center gap-2 rounded-xl border border-red-200 px-4 font-bold text-red-600"><Square size={16} /> End</button>
              </div>

              <form className="flex gap-2" onSubmit={(e) => { e.preventDefault(); const t = typed.trim(); if (t) { setTyped(""); void submit(t); } }}>
                <input value={typed} onChange={(e) => setTyped(e.target.value)} placeholder="Or type a question…" className="h-12 min-w-0 flex-1 rounded-xl border border-[#CBD5E1] bg-white px-4 outline-none focus:border-[#0E72ED]" />
                <button type="submit" disabled={!typed.trim()} className="grid h-12 w-12 place-items-center rounded-xl bg-[#0E72ED] text-white disabled:opacity-40"><Volume2 size={20} /></button>
              </form>
            </>
          ) : (
            <>
              <section className="rounded-3xl bg-gradient-to-br from-[#0E72ED] to-[#6366F1] p-6 text-white shadow-[0_18px_40px_rgba(14,114,237,0.22)]">
                <p className="text-sm font-bold text-white/80">Hands-free tutoring</p>
                <h2 className="mt-1 text-2xl font-black">Just talk. Alluwal listens and answers.</h2>
                <p className="mt-2 text-sm text-white/90">Ask about a lesson, practise a surah, get help with homework — in English, French or Arabic. Sessions are up to {avail?.settings.sessionMinutes ?? 60} minutes.</p>
                <div className="mt-5 flex flex-wrap items-center gap-3">
                  <button type="button" disabled={!avail || (!avail.canStartNow && !avail.activeSession) || busy === "start"} onClick={() => void startSession()} className="inline-flex min-h-12 items-center gap-2 rounded-2xl bg-white px-5 font-black text-[#0E72ED] disabled:opacity-60">
                    {busy === "start" ? <Loader2 className="animate-spin" size={18} /> : <Mic size={18} />}
                    {avail?.activeSession ? "Continue session" : "Start now"}
                  </button>
                  <span className="inline-flex items-center gap-2 text-sm font-semibold text-white/85">
                    {avail ? <span className="rounded-lg bg-white/15 px-2.5 py-1 text-base font-black tabular-nums text-white">{avail.seatsFreeNow} / {avail.seatsTotal}</span> : null}
                    {!avail ? "Checking seats…" : avail.activeSession ? "Your session is still open." : avail.canStartNow ? "seats free right now" : avail.seatsFreeNow > 0 ? "seats free — the tutor opens at " + avail.settings.windowStart : "seats free — book an hour below."}
                  </span>
                </div>
              </section>

              {avail?.myBookings.length ? (
                <section className="rounded-2xl border border-[#E2E8F0] bg-white p-4">
                  <h3 className="text-sm font-black">Your booked hours</h3>
                  <ul className="mt-2 grid gap-2">
                    {avail.myBookings.map((b) => (
                      <li key={b.id} className="flex items-center justify-between gap-3 rounded-xl bg-[#F8FAFC] px-3 py-2.5 text-sm">
                        <span className="inline-flex items-center gap-2 font-bold"><CalendarClock size={16} className="text-[#0E72ED]" />{fmtDay(b.startIso, tz)} · {fmtHour(b.startIso, tz)}</span>
                        <button type="button" disabled={busy === b.id} onClick={() => void cancel(b.id)} className="text-xs font-bold text-red-600">Cancel</button>
                      </li>
                    ))}
                  </ul>
                </section>
              ) : null}

              <section className="rounded-2xl border border-[#E2E8F0] bg-white p-4">
                <div className="flex items-baseline justify-between gap-3">
                  <h3 className="text-sm font-black">Book an hour</h3>
                  <p className="text-xs font-semibold text-[#64748B]">{avail ? `${avail.settings.windowStart}–${avail.settings.windowEnd} · up to ${avail.settings.maxBookingsPerDay} a day` : ""}</p>
                </div>
                {[...byDay.entries()].map(([day, slots]) => (
                  <div key={day} className="mt-3">
                    <p className="text-xs font-black uppercase tracking-wide text-[#94A3B8]">{day}</p>
                    <div className="mt-2 grid grid-cols-3 gap-2 sm:grid-cols-4">
                      {slots.map((s) => (
                        <button key={s.slotKey} type="button" disabled={s.mine || s.seatsLeft === 0 || busy === s.slotKey} onClick={() => void book(s.slotKey)}
                          className={`rounded-xl border px-2 py-2 text-center text-sm font-bold ${s.mine ? "border-[#0E72ED] bg-[#EFF6FF] text-[#0E72ED]" : s.seatsLeft === 0 ? "border-[#E2E8F0] bg-[#F8FAFC] text-[#94A3B8]" : "border-[#E2E8F0] bg-white text-[#0F172A] hover:border-[#0E72ED]"}`}>
                          {fmtHour(s.startIso, tz)}
                          <span className="block text-[11px] font-semibold text-[#64748B]">{s.mine ? "Booked" : s.seatsLeft === 0 ? "Full" : `${s.seatsLeft} seats`}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
                {avail && avail.slots.length === 0 ? <p className="mt-3 text-sm text-[#64748B]">No hours left to book in the next two days.</p> : null}
              </section>
            </>
          )}
        </main>
      </div>
    </StudentShell>
  );
}
