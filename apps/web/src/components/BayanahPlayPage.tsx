"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { doc, onSnapshot, collection, query, orderBy, limit } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { onAuthStateChanged, type User } from "firebase/auth";
import { auth, db, functions } from "@/lib/firebase";

/**
 * Bayanah live player.
 *
 * Watches ONE event document, so every phone flips to the next question at the
 * same moment without polling. Timing is measured locally: a monotonic clock
 * starts when the question actually becomes answerable (after the short "get
 * ready" beat that lets any image decode), so a slow connection never costs a
 * student points — the server only checks the number is possible.
 */

type LiveQuestion = {
  question_id: string;
  question: string;
  options: string[];
  duration_ms: number;
  points: number;
  index: number;
  total: number;
  image_url?: string | null;
  prep_ms?: number;
};

type Reveal = {
  question_id: string;
  correct_index: number;
  counts: number[];
  explanation?: string | null;
};

type EventDoc = {
  title?: string;
  status?: string;
  join_code?: string;
  current_question?: LiveQuestion | null;
  reveal?: Reveal | null;
  player_count?: number;
};

type Player = { uid: string; display_name: string; total_points: number; bonus_points: number };

/** Two rising notes, synthesised — no audio file to load on game day. */
function playCorrectChime() {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    [
      { freq: 784, at: 0, dur: 0.11 },    // G5
      { freq: 1046.5, at: 0.1, dur: 0.22 }, // C6
    ].forEach(({ freq, at, dur }) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.value = freq;
      osc.connect(gain);
      gain.connect(ctx.destination);
      const t0 = ctx.currentTime + at;
      gain.gain.setValueAtTime(0.0001, t0);
      gain.gain.exponentialRampToValueAtTime(0.3, t0 + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
      osc.start(t0);
      osc.stop(t0 + dur + 0.02);
    });
  } catch {
    /* sound is a nicety, never a blocker */
  }
}

// Kahoot-style shapes: young players track colour and shape far faster than text.
const CHOICE_STYLES = [
  { bg: "#E21B3C", shape: "▲", label: "triangle" },
  { bg: "#1368CE", shape: "◆", label: "diamond" },
  { bg: "#D89E00", shape: "●", label: "circle" },
  { bg: "#26890C", shape: "■", label: "square" },
];

export function BayanahPlayPage() {
  const [user, setUser] = useState<User | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [eventId, setEventId] = useState<string | null>(null);
  const [event, setEvent] = useState<EventDoc | null>(null);
  const [players, setPlayers] = useState<Player[]>([]);
  const [code, setCode] = useState("");
  const [joining, setJoining] = useState(false);
  const [error, setError] = useState("");
  const [bonus, setBonus] = useState<number | null>(null);

  // Per-question local state
  const [answered, setAnswered] = useState<number | null>(null);
  const [awardedPoints, setAwardedPoints] = useState<number | null>(null);
  const [ready, setReady] = useState(false);
  const [remaining, setRemaining] = useState(0);
  const startedAtRef = useRef<number | null>(null);
  const questionIdRef = useRef<string | null>(null);
  const chimedForRef = useRef<string | null>(null);

  useEffect(() => onAuthStateChanged(auth, (u) => { setUser(u); setAuthReady(true); }), []);

  // Restore the game we were in if the phone locks or the page reloads.
  useEffect(() => {
    const saved = typeof window !== "undefined" ? window.localStorage.getItem("bayanah_event") : null;
    if (saved) setEventId(saved);
  }, []);

  useEffect(() => {
    if (!eventId) return;
    const unsub = onSnapshot(doc(db, "bayanah_events", eventId), (snap) => {
      setEvent((snap.data() as EventDoc) ?? null);
    });
    return unsub;
  }, [eventId]);

  useEffect(() => {
    if (!eventId) return;
    const q = query(
      collection(db, "bayanah_events", eventId, "players"),
      orderBy("total_points", "desc"),
      limit(50),
    );
    return onSnapshot(q, (snap) => {
      setPlayers(snap.docs.map((d) => ({ uid: d.id, ...(d.data() as Omit<Player, "uid">) })));
    });
  }, [eventId]);

  const question = event?.current_question ?? null;
  const reveal = event?.reveal ?? null;

  // New question → hold briefly (image decodes), then start the local clock.
  useEffect(() => {
    if (!question) {
      setReady(false);
      return;
    }
    if (questionIdRef.current === question.question_id) return;
    questionIdRef.current = question.question_id;
    setAnswered(null);
    setAwardedPoints(null);
    setReady(false);
    startedAtRef.current = null;

    const prep = question.prep_ms ?? 1500;
    const timer = window.setTimeout(() => {
      startedAtRef.current = performance.now(); // monotonic: immune to clock changes
      setReady(true);
      setRemaining(question.duration_ms);
    }, prep);
    return () => window.clearTimeout(timer);
  }, [question]);

  // Countdown purely for display.
  useEffect(() => {
    if (!ready || !question || answered !== null || reveal) return;
    const id = window.setInterval(() => {
      const started = startedAtRef.current;
      if (started == null) return;
      const left = question.duration_ms - (performance.now() - started);
      setRemaining(left > 0 ? left : 0);
    }, 100);
    return () => window.clearInterval(id);
  }, [ready, question, answered, reveal]);

  const join = useCallback(async () => {
    setError("");
    setJoining(true);
    try {
      const callable = httpsCallable<{ joinCode: string }, { eventId: string; bonusPoints: number }>(
        functions, "joinBayanah",
      );
      const res = await callable({ joinCode: code.trim() });
      setEventId(res.data.eventId);
      setBonus(res.data.bonusPoints ?? 0);
      window.localStorage.setItem("bayanah_event", res.data.eventId);
    } catch (e) {
      setError((e as { message?: string })?.message || "Could not join that game.");
    } finally {
      setJoining(false);
    }
  }, [code]);

  const answer = useCallback(async (index: number) => {
    if (!eventId || !question || answered !== null || !ready) return;
    const started = startedAtRef.current;
    const elapsedMs = started == null ? 0 : Math.round(performance.now() - started);
    setAnswered(index); // lock the UI immediately; the call can take a moment
    try {
      const callable = httpsCallable<
        { eventId: string; questionId: string; selectedIndex: number; elapsedMs: number },
        { counted: boolean; isCorrect: boolean; points: number }
      >(functions, "submitBayanahAnswer");
      const res = await callable({
        eventId,
        questionId: question.question_id,
        selectedIndex: index,
        elapsedMs,
      });
      setAwardedPoints(res.data.points ?? 0);
    } catch {
      /* keep the choice on screen; the reveal will show the truth */
    }
  }, [eventId, question, answered, ready]);

  const me = useMemo(
    () => players.find((p) => p.uid === user?.uid) ?? null,
    [players, user],
  );
  const myRank = useMemo(
    () => (me ? players.findIndex((p) => p.uid === me.uid) + 1 : 0),
    [players, me],
  );

  if (!authReady) return <Shell><p style={{ color: "#94A3B8" }}>Loading…</p></Shell>;

  if (!user) {
    return (
      <Shell>
        <h1 style={h1}>Bayanah Live</h1>
        <p style={{ color: "#CBD5E1", marginBottom: 18 }}>Sign in with your student account to play.</p>
        <a href="/student/login/" style={primaryBtn}>Sign in</a>
      </Shell>
    );
  }

  // ── Join screen ──
  if (!eventId || !event) {
    return (
      <Shell>
        <h1 style={h1}>Bayanah Live</h1>
        <p style={{ color: "#CBD5E1", marginBottom: 18 }}>Enter the game code your teacher shows.</p>
        <input
          value={code}
          onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
          inputMode="numeric"
          placeholder="123456"
          style={codeInput}
        />
        {error && <p style={{ color: "#FCA5A5", marginTop: 10 }}>{error}</p>}
        <button onClick={join} disabled={code.length !== 6 || joining} style={{ ...primaryBtn, marginTop: 14, opacity: code.length === 6 ? 1 : 0.5 }}>
          {joining ? "Joining…" : "Join game"}
        </button>
      </Shell>
    );
  }

  // ── Game over: leave the game interface the moment the host ends it ──
  if (event.status === "ended") {
    return (
      <Shell>
        <div style={{ fontSize: 52 }}>🏁</div>
        <h1 style={{ ...h1, fontSize: 30 }}>Game over</h1>
        <p style={{ color: "#94A3B8" }}>{event.title || "Bayanah"}</p>
        <Standings players={players} meUid={user.uid} />
        <button
          onClick={() => {
            window.localStorage.removeItem("bayanah_event");
            setEventId(null);
            setEvent(null);
            setCode("");
            setBonus(null);
          }}
          style={{ ...primaryBtn, marginTop: 20 }}
        >
          Done
        </button>
      </Shell>
    );
  }

  // ── Lobby ──
  if (event.status === "lobby" || !question) {
    return (
      <Shell>
        <h1 style={h1}>{event.title || "Bayanah"}</h1>
        <p style={{ color: "#CBD5E1" }}>You&apos;re in. Wait for your teacher to start.</p>
        {bonus !== null && bonus > 0 && (
          <div style={bonusCard}>
            <div style={{ fontSize: 13, color: "#FDE68A" }}>Head start for playing this month</div>
            <div style={{ fontSize: 34, fontWeight: 900 }}>+{bonus}</div>
          </div>
        )}
        <p style={{ color: "#64748B", marginTop: 18 }}>{event.player_count ?? 0} players joined</p>
      </Shell>
    );
  }

  // ── Reveal ──
  if (reveal && reveal.question_id === question.question_id) {
    const gotIt = answered !== null && answered === reveal.correct_index;
    if (gotIt && chimedForRef.current !== reveal.question_id) {
      chimedForRef.current = reveal.question_id;
      playCorrectChime();
    }
    return (
      <Shell>
        <div style={{ fontSize: 64, marginBottom: 8 }}>{gotIt ? "🎉" : answered === null ? "⏱️" : "❌"}</div>
        <h1 style={{ ...h1, fontSize: 30 }}>
          {gotIt ? "Correct!" : answered === null ? "Too slow" : "Not this time"}
        </h1>
        {gotIt && awardedPoints !== null && (
          <div style={{ fontSize: 40, fontWeight: 900, color: "#FDE68A" }}>+{awardedPoints}</div>
        )}
        <div style={{ width: "100%", maxWidth: 460, marginTop: 14 }}>
          {question.options.map((opt, i) => {
            const style = CHOICE_STYLES[i % CHOICE_STYLES.length];
            const isCorrect = i === reveal.correct_index;
            const isMine = answered === i;
            return (
              <div
                key={i}
                style={{
                  display: "flex", alignItems: "center", gap: 8,
                  background: style.bg, opacity: isCorrect ? 1 : 0.3,
                  border: isMine ? "3px solid #fff" : "3px solid transparent",
                  borderRadius: 12, padding: "10px 12px", marginBottom: 6,
                  fontWeight: isCorrect ? 900 : 600, textAlign: "left",
                }}
              >
                <span style={{ fontSize: 18 }}>{style.shape}</span>
                <span style={{ flex: 1 }}>{opt}</span>
                <span>{isCorrect ? "✓" : "✕"}</span>
              </div>
            );
          })}
        </div>
        {reveal.explanation && <p style={{ color: "#94A3B8", marginTop: 8, maxWidth: 460 }}>{reveal.explanation}</p>}
        <Standings players={players} meUid={user.uid} />
      </Shell>
    );
  }

  // ── Question ──
  const pct = Math.max(0, Math.min(1, remaining / Math.max(1, question.duration_ms)));
  return (
    <Shell>
      <div style={{ width: "100%", maxWidth: 620 }}>
        <div style={{ display: "flex", justifyContent: "space-between", color: "#94A3B8", fontSize: 13, fontWeight: 700 }}>
          <span>Question {question.index + 1} of {question.total}</span>
          <span>{me ? `${me.total_points} pts` : ""}{myRank ? ` · #${myRank}` : ""}</span>
        </div>

        <h1 style={{ ...h1, fontSize: 26, margin: "12px 0 14px" }}>{question.question}</h1>

        {question.image_url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={question.image_url}
            alt=""
            style={{ width: "100%", maxHeight: 240, objectFit: "contain", borderRadius: 14, marginBottom: 14 }}
          />
        )}

        {!ready ? (
          <p style={{ fontSize: 22, fontWeight: 800, color: "#FDE68A" }}>Get ready…</p>
        ) : (
          <>
            <div style={{ height: 10, background: "#1E293B", borderRadius: 99, overflow: "hidden", marginBottom: 16 }}>
              <div style={{ height: "100%", width: `${pct * 100}%`, background: pct > 0.3 ? "#22C55E" : "#EF4444", transition: "width .1s linear" }} />
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              {question.options.map((opt, i) => {
                const style = CHOICE_STYLES[i % CHOICE_STYLES.length];
                const chosen = answered === i;
                const dimmed = answered !== null && !chosen;
                return (
                  <button
                    key={i}
                    onClick={() => answer(i)}
                    disabled={answered !== null}
                    aria-label={`${style.label}: ${opt}`}
                    style={{
                      background: style.bg,
                      opacity: dimmed ? 0.35 : 1,
                      border: chosen ? "4px solid #fff" : "4px solid transparent",
                      color: "#fff",
                      fontWeight: 800,
                      fontSize: 17,
                      padding: "22px 14px",
                      borderRadius: 16,
                      cursor: answered === null ? "pointer" : "default",
                      display: "flex",
                      alignItems: "center",
                      gap: 10,
                      textAlign: "left",
                      minHeight: 78,
                    }}
                  >
                    <span style={{ fontSize: 22 }}>{style.shape}</span>
                    <span>{opt}</span>
                  </button>
                );
              })}
            </div>
            {answered !== null && (
              <p style={{ color: "#94A3B8", marginTop: 14, textAlign: "center" }}>
                Answer locked — waiting for everyone…
              </p>
            )}
          </>
        )}
      </div>
    </Shell>
  );
}

function Standings({ players, meUid }: { players: Player[]; meUid: string }) {
  if (players.length === 0) return null;
  return (
    <div style={{ width: "100%", maxWidth: 460, marginTop: 22 }}>
      <div style={{ color: "#94A3B8", fontSize: 12, fontWeight: 800, marginBottom: 6 }}>LEADERBOARD</div>
      {players.slice(0, 8).map((p, i) => (
        <div
          key={p.uid}
          style={{
            display: "flex", alignItems: "center", gap: 10, padding: "8px 12px", borderRadius: 10,
            background: p.uid === meUid ? "#0E7490" : "#111827", marginBottom: 6,
          }}
        >
          <span style={{ width: 20, fontWeight: 800, color: i < 3 ? "#FDE68A" : "#94A3B8" }}>{i + 1}</span>
          <span style={{ flex: 1, fontWeight: 600, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
            {p.display_name}
          </span>
          <span style={{ fontWeight: 900 }}>{p.total_points}</span>
        </div>
      ))}
    </div>
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <main
      style={{
        minHeight: "100dvh", background: "#0B1220", color: "#fff",
        display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
        padding: 20, fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
        textAlign: "center",
      }}
    >
      {children}
    </main>
  );
}

const h1: React.CSSProperties = { fontSize: 34, fontWeight: 900, margin: "0 0 6px" };
const primaryBtn: React.CSSProperties = {
  background: "#0E7490", color: "#fff", border: "none", borderRadius: 14,
  padding: "16px 28px", fontSize: 17, fontWeight: 800, cursor: "pointer", textDecoration: "none",
};
const codeInput: React.CSSProperties = {
  fontSize: 40, fontWeight: 900, letterSpacing: 8, textAlign: "center", width: 240,
  padding: "14px 10px", borderRadius: 14, border: "2px solid #334155",
  background: "#0F172A", color: "#fff",
};
const bonusCard: React.CSSProperties = {
  marginTop: 20, padding: "14px 22px", borderRadius: 16,
  background: "linear-gradient(135deg,#0E7490,#155E75)",
};
