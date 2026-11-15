"use client";

import { collection, documentId, getDocs, query, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import {
  AlertCircle,
  ArrowLeft,
  BookOpen,
  CalendarDays,
  CheckCircle2,
  ChevronRight,
  Clapperboard,
  GraduationCap,
  Loader2,
  Play,
  RefreshCw,
  Search,
  SearchX,
  Trash2,
  VideoOff,
  X,
  type LucideIcon,
} from "lucide-react";
import { db, functions } from "@/lib/firebase";
import { useLocale } from "@/lib/i18n";
import { ParentRecordingPlayer } from "@/components/ParentRecordingPlayer";
import { useNow } from "@/components/ParentUi";
import { parentLearningText } from "@/lib/parentLearning";
import {
  callableErrorText,
  chunk,
  dateBuckets,
  dateTime,
  displayDate,
  fragmentTitle,
  headerSubtitle,
  headerTitle,
  levelOf,
  longDate,
  peopleFromDoc,
  peopleToResolve,
  playLabel,
  readListAnswer,
  readPlaybackAnswer,
  recordingCountText,
  recordingsForDate,
  recordingsForStudent,
  retentionChip,
  retentionColor,
  searchHint,
  shiftBuckets,
  shiftSubtitle,
  shortDate,
  statusColor,
  statusLabel,
  studentBuckets,
  type ParentRecording,
  type People,
  type ShiftBucket,
} from "@/lib/parentRecordings";

/** The role this page asks for; the server lists the children's recordings for it (C-202, C-203). */
const ACTIVE_ROLE = "parent";

type Load = { state: "loading" } | { state: "error"; message: string } | { state: "ready"; recordings: ParentRecording[]; people: People };

/**
 * Recordings (ClassRecordingsScreen as a parent sees it, C-200…C-226): the
 * children's class recordings, drilled from child → day → class → fragments,
 * with Flutter's grouping, search, labels, retention chip, play button and
 * player. Recordings come only from `listClassRecordings` with the parent
 * role; links only from `getClassRecordingPlaybackUrl`.
 */
export default function ParentRecordingsPage() {
  const fr = useLocale() === "fr";
  const words = parentLearningText(fr);
  const now = useNow(60_000);
  const [load, setLoad] = useState<Load>({ state: "loading" });
  const [search, setSearch] = useState("");
  const [studentId, setStudentId] = useState<string | null>(null);
  const [dateKey, setDateKey] = useState<string | null>(null);
  const [shiftKey, setShiftKey] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [loadingId, setLoadingId] = useState<string | null>(null);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [snack, setSnack] = useState<string | null>(null);
  const run = useRef(0);

  // C-202 / C-222: load (or reload) everything and go back to the first level.
  const reload = useCallback(async () => {
    const mine = ++run.current;
    setLoad({ state: "loading" });
    let outcome: ReturnType<typeof readListAnswer>;
    try {
      const result = await httpsCallable(functions, "listClassRecordings")({ limit: 200, activeRole: ACTIVE_ROLE });
      outcome = readListAnswer(result.data);
    } catch (error) {
      outcome = { ok: false, error: callableErrorText(error, "list") };
    }
    if (mine !== run.current) return;
    if (!outcome.ok) {
      setLoad({ state: "error", message: outcome.error });
      return;
    }
    const people = await resolvePeople(outcome.recordings);
    if (mine !== run.current) return;
    setLoad({ state: "ready", recordings: outcome.recordings, people });
    setStudentId(null);
    setDateKey(null);
    setShiftKey(null);
    setSearch("");
    setExpandedId(null);
    setLoadingId(null);
    setUrls({});
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  useEffect(() => {
    if (!snack) return;
    const timer = window.setTimeout(() => setSnack(null), 4000);
    return () => window.clearTimeout(timer);
  }, [snack]);

  const recordings = load.state === "ready" ? load.recordings : [];
  const people = load.state === "ready" ? load.people : {};
  const level = levelOf({ studentId, dateKey, shiftKey });
  const students = useMemo(() => studentBuckets(recordings, people, level === "students" ? search : ""), [recordings, people, level, search]);
  const forStudent = useMemo(() => recordingsForStudent(recordings, studentId), [recordings, studentId]);
  const dates = useMemo(() => dateBuckets(forStudent, level === "dates" ? search : ""), [forStudent, level, search]);
  const forDate = useMemo(() => recordingsForDate(forStudent, dateKey), [forStudent, dateKey]);
  const shifts = useMemo(() => shiftBuckets(forDate, people, level === "shifts" ? search : ""), [forDate, people, level, search]);
  const selectedShift = shiftKey ? shifts.find((s) => s.key === shiftKey) ?? null : null;

  // C-223: up one level, clearing the search; leaving the fragments closes the player.
  const back = () => {
    if (shiftKey !== null) {
      setShiftKey(null);
      setExpandedId(null);
    } else if (dateKey !== null) setDateKey(null);
    else if (studentId !== null) setStudentId(null);
    setSearch("");
  };

  // C-217…C-221: fetch the link once, then open it in the card.
  const togglePlayer = async (recording: ParentRecording) => {
    if (expandedId === recording.recordingId) {
      setExpandedId(null);
      return;
    }
    if (urls[recording.recordingId]) {
      setExpandedId(recording.recordingId);
      return;
    }
    setLoadingId(recording.recordingId);
    let outcome: ReturnType<typeof readPlaybackAnswer>;
    if (!recording.recordingId.trim()) outcome = { ok: false, error: "Invalid recording ID" };
    else {
      try {
        const result = await httpsCallable(functions, "getClassRecordingPlaybackUrl")({ recordingId: recording.recordingId.trim(), activeRole: ACTIVE_ROLE });
        outcome = readPlaybackAnswer(result.data);
      } catch (error) {
        outcome = { ok: false, error: callableErrorText(error, "playback") };
      }
    }
    setLoadingId(null);
    if (!outcome.ok) {
      setSnack(outcome.error || "Unable to load recording");
      return;
    }
    const url = outcome.url;
    setUrls((current) => ({ ...current, [recording.recordingId]: url }));
    setExpandedId(recording.recordingId);
  };

  if (load.state === "loading") {
    return (
      <div className="grid min-h-full place-items-center bg-[#F8FAFC] py-16" role="status" aria-label="Loading recordings">
        <Loader2 size={36} className="animate-spin text-[#0E72ED]" />
      </div>
    );
  }

  if (load.state === "error") {
    // C-206: the error card replaces the page.
    return (
      <div className="grid min-h-full place-items-center bg-[#F8FAFC] p-6">
        <div className="w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-[0_4px_10px_rgba(0,0,0,0.04)]" role="alert">
          <span className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#EF4444]/10 text-[#EF4444]">
            <AlertCircle size={28} />
          </span>
          <p className="mt-4 text-[15px] font-semibold text-[#374151]">{load.message}</p>
          <button type="button" onClick={() => void reload()} className="mt-4 inline-flex items-center gap-2 rounded-[10px] bg-[#0E72ED] px-6 py-3 text-sm text-white hover:bg-[#0C63CF]">
            <RefreshCw size={18} />
            {words.tryAgain}
          </button>
        </div>
      </div>
    );
  }

  const title = headerTitle(level, selectedShift);
  const subtitle = headerSubtitle(level, { students: students.length, dates: dates.length, shifts: shifts.length }, selectedShift);
  const showSearch = recordings.length > 0 && level !== "fragments";

  return (
    <div className="flex min-h-full flex-col bg-[#F8FAFC] text-[#0F172A]">
      <header className="flex items-center bg-white px-2 pb-2.5 pt-1.5">
        {level !== "students" ? (
          <button type="button" onClick={back} aria-label="Back" className="grid h-12 w-12 shrink-0 place-items-center rounded-full text-[#1E293B] hover:bg-black/5">
            <ArrowLeft size={24} />
          </button>
        ) : (
          <span className="w-12 shrink-0" />
        )}
        <div className="min-w-0 flex-1">
          <h1 className="text-lg font-bold text-[#0F172A]">{title}</h1>
          {subtitle ? <p className="text-xs text-[#64748B]">{subtitle}</p> : null}
        </div>
        <button type="button" onClick={() => void reload()} aria-label="Refresh" className="grid h-12 w-12 shrink-0 place-items-center rounded-full text-[#64748B] hover:bg-black/5">
          <RefreshCw size={22} />
        </button>
      </header>

      {showSearch ? (
        <div className="px-4 pb-2 pt-2.5">
          <label className="relative block">
            <Search size={20} className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[#94A3B8]" aria-hidden="true" />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder={searchHint(level)}
              aria-label={searchHint(level)}
              className="h-12 w-full rounded-xl border border-[#E2E8F0] bg-white pl-11 pr-3.5 text-sm outline-none placeholder:text-[#94A3B8] focus:border-[1.5px] focus:border-[#0E72ED]"
            />
          </label>
        </div>
      ) : null}

      <div className="flex flex-1 flex-col">
        {recordings.length === 0 ? (
          <EmptyState icon={Clapperboard} title="No recordings yet" subtitle="Class recordings will appear here after sessions are recorded." />
        ) : level === "fragments" ? (
          selectedShift ? (
            <Fragments shift={selectedShift} now={now} expandedId={expandedId} loadingId={loadingId} urls={urls} onToggle={(r) => void togglePlayer(r)} onClose={() => setExpandedId(null)} />
          ) : (
            <EmptyState icon={VideoOff} title="Shift not found" subtitle="Refresh and try again." />
          )
        ) : level === "shifts" ? (
          shifts.length === 0 ? (
            <EmptyState icon={SearchX} title="No shifts found" subtitle="Try a different search term." />
          ) : (
            <List>
              {shifts.map((shift) => (
                <LevelCard
                  key={shift.key}
                  title={shift.shiftName}
                  subtitle={shiftSubtitle(shift)}
                  tertiary={shift.date ? dateTime(shift.date) : null}
                  icon={BookOpen}
                  color="#7C3AED"
                  onClick={() => {
                    setShiftKey(shift.key);
                    setSearch("");
                  }}
                />
              ))}
            </List>
          )
        ) : level === "dates" ? (
          dates.length === 0 ? (
            <EmptyState icon={SearchX} title="No recording dates found" subtitle="Try a different search term." />
          ) : (
            <List>
              {dates.map((bucket) => (
                <LevelCard
                  key={bucket.key}
                  title={bucket.date ? longDate(bucket.date) : "Unknown date"}
                  subtitle={recordingCountText(bucket.recordings.length)}
                  icon={CalendarDays}
                  color="#0E7490"
                  onClick={() => {
                    setDateKey(bucket.key);
                    setShiftKey(null);
                    setSearch("");
                  }}
                />
              ))}
            </List>
          )
        ) : students.length === 0 ? (
          <EmptyState icon={SearchX} title="No students found" subtitle="Try a different search term." />
        ) : (
          <List>
            {students.map((student) => (
              <LevelCard
                key={student.id}
                title={student.name}
                subtitle={recordingCountText(student.recordings.length)}
                tertiary={student.latestDate ? `Latest: ${shortDate(student.latestDate)}` : null}
                icon={GraduationCap}
                color="#2563EB"
                onClick={() => {
                  setStudentId(student.id);
                  setDateKey(null);
                  setShiftKey(null);
                  setSearch("");
                }}
              />
            ))}
          </List>
        )}
      </div>

      {snack ? (
        <div role="alert" className="fixed bottom-6 left-1/2 z-[120] flex w-[min(560px,calc(100%-32px))] -translate-x-1/2 items-center gap-3 rounded-[10px] bg-[#EF4444] px-4 py-3 text-sm text-white shadow-xl">
          <p className="min-w-0 flex-1">{snack}</p>
          <button type="button" onClick={() => setSnack(null)} aria-label="Dismiss" className="grid h-7 w-7 shrink-0 place-items-center rounded-md hover:bg-white/15">
            <X size={16} />
          </button>
        </div>
      ) : null}
    </div>
  );
}

/** C-205: names (and e-mail / phone for search) of every teacher and child, ten ids per read. */
async function resolvePeople(recordings: ParentRecording[]): Promise<People> {
  const people: People = {};
  try {
    for (const ids of chunk(peopleToResolve(recordings), 10)) {
      const snap = await getDocs(query(collection(db, "users"), where(documentId(), "in", ids)));
      for (const entry of snap.docs) Object.assign(people, peopleFromDoc(entry.id, entry.data() as Record<string, unknown>));
    }
  } catch {
    // Names fall back to ids, as in Flutter.
  }
  return people;
}

function List({ children }: { children: ReactNode }) {
  return <div className="grid gap-2.5 px-4 pb-6 pt-2">{children}</div>;
}

function LevelCard({ title, subtitle, tertiary, icon: Icon, color, onClick }: { title: string; subtitle: string; tertiary?: string | null; icon: LucideIcon; color: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-3 rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 text-left shadow-[0_2px_8px_rgba(0,0,0,0.03)] hover:bg-[#F8FAFC]"
    >
      <span className="grid h-[38px] w-[38px] shrink-0 place-items-center rounded-[10px]" style={{ backgroundColor: `${color}1A`, color }}>
        <Icon size={20} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-semibold text-[#0F172A]">{title}</span>
        <span className="mt-0.5 line-clamp-2 block text-xs text-[#64748B]">{subtitle}</span>
        {tertiary && tertiary.trim() ? <span className="mt-0.5 block truncate text-[11px] text-[#94A3B8]">{tertiary}</span> : null}
      </span>
      <ChevronRight size={22} className="shrink-0 text-[#94A3B8]" />
    </button>
  );
}

function Fragments({
  shift,
  now,
  expandedId,
  loadingId,
  urls,
  onToggle,
  onClose,
}: {
  shift: ShiftBucket;
  now: Date;
  expandedId: string | null;
  loadingId: string | null;
  urls: Record<string, string>;
  onToggle: (r: ParentRecording) => void;
  onClose: () => void;
}) {
  const total = shift.fragments.length;
  return (
    <div className="px-4 pb-6 pt-2">
      <section className="mb-3 rounded-[14px] border border-[#E2E8F0] bg-white p-3.5">
        <h2 className="text-[15px] font-bold text-[#0F172A]">{shift.shiftName}</h2>
        <div className="mt-1 flex flex-wrap gap-x-2 gap-y-1">
          <Badge icon={Clapperboard} color="#0E72ED">{`${total} fragments`}</Badge>
          <Badge icon={CheckCircle2} color="#10B981">{`${shift.readyCount} ready`}</Badge>
          {shift.subjectName ? <Badge icon={BookOpen} color="#7C3AED">{shift.subjectName}</Badge> : null}
        </div>
        {shift.date ? <p className="mt-2 text-xs text-[#64748B]">{dateTime(shift.date)}</p> : null}
      </section>
      <div className="grid gap-2.5">
        {shift.fragments.map((recording, index) => {
          const number = index + 1;
          const name = fragmentTitle(number, total);
          const expanded = expandedId === recording.recordingId;
          const url = urls[recording.recordingId];
          const loading = loadingId === recording.recordingId;
          const status = statusColor(recording);
          const retention = retentionColor(recording.deleteAfter, now);
          return (
            <article key={recording.recordingId} className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5">
              <div className="flex items-center gap-3">
                <span className="grid h-9 w-9 shrink-0 place-items-center rounded-[10px] bg-[#0E72ED]/10 text-sm font-bold text-[#0E72ED]">{number}</span>
                <div className="min-w-0 flex-1">
                  <h3 className="text-sm font-semibold text-[#111827]">{name}</h3>
                  <p className="mt-0.5 text-xs text-[#64748B]">{dateTime(displayDate(recording))}</p>
                </div>
                <span className="shrink-0 rounded-full px-2.5 py-1 text-[11px] font-bold" style={{ backgroundColor: `${status}1F`, color: status }}>
                  {statusLabel(recording)}
                </span>
              </div>
              <span className="mt-2 inline-flex items-center gap-1.5 rounded-[18px] px-2.5 py-[5px] text-[11px] font-semibold" style={{ backgroundColor: `${retention}1F`, color: retention }}>
                <Trash2 size={14} />
                {retentionChip(recording.deleteAfter, now)}
              </span>
              {(recording.error ?? "").trim() ? <p className="mt-2 line-clamp-2 text-[11px] text-[#DC2626]">{recording.error}</p> : null}
              <div className="mt-2.5">
                {expanded && url ? (
                  <>
                    <ParentRecordingPlayer url={url} title={name} />
                    <button type="button" onClick={onClose} className="mt-2 inline-flex w-full items-center justify-center gap-2 rounded-[10px] py-2.5 text-sm font-semibold text-[#6B7280] hover:bg-black/5">
                      <X size={18} />
                      Close Player
                    </button>
                  </>
                ) : (
                  <button
                    type="button"
                    disabled={!recording.canPlay || loading}
                    onClick={() => onToggle(recording)}
                    className="inline-flex w-full items-center justify-center gap-2 rounded-[10px] bg-[#0E72ED] py-3 text-sm font-semibold text-white hover:bg-[#0C63CF] disabled:bg-[#CBD5E1] disabled:text-white/70"
                  >
                    {loading ? <Loader2 size={14} className="animate-spin" /> : <Play size={20} fill="currentColor" />}
                    {playLabel(recording, loading)}
                  </button>
                )}
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}

function Badge({ icon: Icon, color, children }: { icon: LucideIcon; color: string; children: ReactNode }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-[10px] px-2 py-1 text-[11px] font-semibold" style={{ backgroundColor: `${color}1F`, color }}>
      <Icon size={12} />
      {children}
    </span>
  );
}

function EmptyState({ icon: Icon, title, subtitle }: { icon: LucideIcon; title: string; subtitle: string }) {
  return (
    <div className="flex flex-1 items-center justify-center p-8">
      <div className="flex flex-col items-center rounded-2xl bg-white p-7 text-center shadow-[0_4px_10px_rgba(0,0,0,0.04)]">
        <span className="grid h-16 w-16 place-items-center rounded-2xl bg-[#0E72ED]/[0.08] text-[#0E72ED]/50">
          <Icon size={32} />
        </span>
        <p className="mt-4 text-base font-semibold text-[#374151]">{title}</p>
        <p className="mt-1.5 text-sm text-[#6B7280]">{subtitle}</p>
      </div>
    </div>
  );
}

