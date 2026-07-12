"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, documentId, getDocs, query, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useEffect, useMemo, useState } from "react";
import { CalendarDays, ChevronLeft, ChevronRight, CircleAlert, Clock3, GraduationCap, Menu, Play, PlaySquare, RefreshCw, Search, Shuffle, Video } from "lucide-react";
import { auth, db, functions } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;
type ViewLevel = "students" | "dates" | "shifts" | "fragments";

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type RecordingItem = {
  recordingId: string;
  shiftId: string;
  shiftName: string;
  subjectName: string;
  teacherId: string;
  teacherName: string;
  studentIds: string[];
  status: string;
  mergeStatus: string;
  error: string;
  filePath: string;
  startedAt: Date | null;
  requestedAt: Date | null;
  updatedAt: Date | null;
  deleteAfter: Date | null;
  canPlay: boolean;
};

type StudentBucket = {
  id: string;
  name: string;
  latestDate: Date | null;
  recordings: RecordingItem[];
};

type DateBucket = {
  key: string;
  date: Date | null;
  recordings: RecordingItem[];
};

type ShiftBucket = {
  key: string;
  shiftName: string;
  subjectName: string;
  date: Date | null;
  fragments: RecordingItem[];
};

export function TeacherRecordingsPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [recordings, setRecordings] = useState<RecordingItem[]>([]);
  const [nameCache, setNameCache] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [search, setSearch] = useState("");
  const [selectedStudentId, setSelectedStudentId] = useState<string | null>(null);
  const [selectedDateKey, setSelectedDateKey] = useState<string | null>(null);
  const [selectedShiftKey, setSelectedShiftKey] = useState<string | null>(null);
  const [playbackUrls, setPlaybackUrls] = useState<Record<string, string>>({});
  const [expandedRecordingId, setExpandedRecordingId] = useState<string | null>(null);
  const [loadingRecordingId, setLoadingRecordingId] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setMessage("");
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
        const loaded = await loadRecordings();
        const names = await resolveUserNames(loaded.recordings);
        if (!mounted) return;
        setRecordings(loaded.recordings);
        setNameCache(names);
        resetSelection(setSearch, setSelectedStudentId, setSelectedDateKey, setSelectedShiftKey, setExpandedRecordingId, setPlaybackUrls);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Failed to load recordings");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const students = useMemo(() => buildStudentBuckets(recordings, nameCache, search), [nameCache, recordings, search]);
  const selectedStudent = useMemo(() => students.find((student) => student.id === selectedStudentId) ?? null, [selectedStudentId, students]);
  const dates = useMemo(() => buildDateBuckets(selectedStudent?.recordings ?? [], search), [search, selectedStudent]);
  const selectedDate = useMemo(() => dates.find((date) => date.key === selectedDateKey) ?? null, [dates, selectedDateKey]);
  const shifts = useMemo(() => buildShiftBuckets(selectedDate?.recordings ?? [], search), [search, selectedDate]);
  const selectedShift = useMemo(() => shifts.find((shift) => shift.key === selectedShiftKey) ?? null, [selectedShiftKey, shifts]);

  const level: ViewLevel = selectedShiftKey ? "fragments" : selectedDateKey ? "shifts" : selectedStudentId ? "dates" : "students";
  const title = headerTitle(level);
  const subtitle = headerSubtitle(level, students, dates, shifts, selectedShift);
  const showSearch = recordings.length > 0 && level !== "fragments";

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <TeacherShell activeLabel="Recordings" breadcrumb="Communication / Recordings" summary={summary}>
      <main className="min-h-screen bg-[#F8FAFC] text-[#0F172A] lg:min-h-[calc(100vh-56px)]">
        <MobileTeacherTopBar summary={summary} />
        <section className="border-b border-[#F1F5F9] bg-white">
          <div className="flex min-h-[60px] items-center px-2 sm:px-4">
            {level === "students" ? (
              <span className="grid h-12 w-12 shrink-0 place-items-center text-[#1E293B]" />
            ) : (
              <button type="button" onClick={() => goBack(level, setSelectedStudentId, setSelectedDateKey, setSelectedShiftKey, setSearch, setExpandedRecordingId)} aria-label="Back" className="grid h-12 w-12 shrink-0 place-items-center rounded-xl text-[#1E293B] hover:bg-[#F8FAFC]">
                <ChevronLeft size={24} />
              </button>
            )}
            <div className="min-w-0 flex-1">
              <h1 className="truncate text-lg font-bold text-[#0F172A]">{title}</h1>
              {subtitle ? <p className="mt-0.5 text-xs text-[#64748B]">{subtitle}</p> : null}
            </div>
            <button type="button" onClick={() => void refresh(setLoading, setMessage, setRecordings, setNameCache, setSearch, setSelectedStudentId, setSelectedDateKey, setSelectedShiftKey, setExpandedRecordingId, setPlaybackUrls)} aria-label="Refresh recordings" className="grid h-11 w-11 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
              <RefreshCw size={22} />
            </button>
          </div>
        </section>

        {showSearch ? (
          <section className="px-4 py-3">
            <label className="relative block h-11 max-w-2xl">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={20} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder={searchHint(level)}
                aria-label="Search recordings"
                className="h-full w-full rounded-xl border border-[#E2E8F0] bg-white pl-11 pr-10 text-sm text-[#0F172A] outline-none placeholder:text-[#94A3B8] focus:border-[#0E72ED] focus:ring-2 focus:ring-[#BFDBFE]"
              />
            </label>
          </section>
        ) : null}

        {message ? <ErrorCard message={message} onRetry={() => void refresh(setLoading, setMessage, setRecordings, setNameCache, setSearch, setSelectedStudentId, setSelectedDateKey, setSelectedShiftKey, setExpandedRecordingId, setPlaybackUrls)} /> : null}

        {loading ? (
          <LoadingRecordings />
        ) : recordings.length === 0 ? (
          <NoRecordingsCard />
        ) : level === "students" ? (
          <StudentList students={students} onSelect={(id) => { setSelectedStudentId(id); setSearch(""); }} />
        ) : level === "dates" ? (
          <DateList dates={dates} onSelect={(key) => { setSelectedDateKey(key); setSearch(""); }} />
        ) : level === "shifts" ? (
          <ShiftList shifts={shifts} onSelect={(key) => { setSelectedShiftKey(key); setSearch(""); }} />
        ) : (
          <FragmentList
            shift={selectedShift}
            playbackUrls={playbackUrls}
            expandedRecordingId={expandedRecordingId}
            loadingRecordingId={loadingRecordingId}
            onToggle={(recording) => void toggleRecording(recording, playbackUrls, expandedRecordingId, setPlaybackUrls, setExpandedRecordingId, setLoadingRecordingId, setMessage)}
            onPlaybackError={() => setMessage("This recording could not be played. Refresh its playback link and try again.")}
          />
        )}
      </main>
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-14 grid-cols-[56px_1fr_96px] items-center bg-white px-4 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={24} />
      </button>
      <div className="min-w-0 text-center text-base font-bold text-[#111827]">Alluwal Academy</div>
      <div className="flex items-center justify-end gap-3">
        <Shuffle size={20} className="text-[#111827]" />
        <span className="grid h-9 w-9 place-items-center rounded-full bg-[#009688] text-xs font-black text-white">{summary.initials}</span>
      </div>
    </header>
  );
}

function StudentList({ students, onSelect }: { students: StudentBucket[]; onSelect: (id: string) => void }) {
  if (students.length === 0) return <SearchEmptyCard title="No students found" />;
  return (
    <section className="px-4 py-2">
      <div className="mx-auto grid max-w-5xl gap-2">
        {students.map((student) => (
          <LevelCard key={student.id} title={student.name} subtitle={`${student.recordings.length} recording${student.recordings.length === 1 ? "" : "s"}`} tertiary={student.latestDate ? `Latest: ${shortDate(student.latestDate)}` : undefined} icon={<GraduationCap size={20} />} iconColor="#2563EB" onClick={() => onSelect(student.id)} />
        ))}
      </div>
    </section>
  );
}

function DateList({ dates, onSelect }: { dates: DateBucket[]; onSelect: (key: string) => void }) {
  if (dates.length === 0) return <SearchEmptyCard title="No recording dates found" />;
  return (
    <section className="px-4 py-2">
      <div className="mx-auto grid max-w-5xl gap-2">
        {dates.map((date) => (
          <LevelCard key={date.key} title={date.date ? longDate(date.date) : "Unknown date"} subtitle={`${date.recordings.length} recording${date.recordings.length === 1 ? "" : "s"}`} icon={<CalendarDays size={20} />} iconColor="#0E7490" onClick={() => onSelect(date.key)} />
        ))}
      </div>
    </section>
  );
}

function ShiftList({ shifts, onSelect }: { shifts: ShiftBucket[]; onSelect: (key: string) => void }) {
  if (shifts.length === 0) return <SearchEmptyCard title="No shifts found" />;
  return (
    <section className="px-4 py-2">
      <div className="mx-auto grid max-w-5xl gap-2">
        {shifts.map((shift) => (
          <LevelCard key={shift.key} title={shift.shiftName} subtitle={`${shift.fragments.length} fragment${shift.fragments.length === 1 ? "" : "s"} · Ready: ${shift.fragments.filter((item) => item.canPlay).length}${shift.subjectName ? ` · ${shift.subjectName}` : ""}`} tertiary={shift.date ? dateTime(shift.date) : undefined} icon={<Video size={20} />} iconColor="#7C3AED" onClick={() => onSelect(shift.key)} />
        ))}
      </div>
    </section>
  );
}

function FragmentList({
  shift,
  playbackUrls,
  expandedRecordingId,
  loadingRecordingId,
  onToggle,
  onPlaybackError,
}: {
  shift: ShiftBucket | null;
  playbackUrls: Record<string, string>;
  expandedRecordingId: string | null;
  loadingRecordingId: string | null;
  onToggle: (recording: RecordingItem) => void;
  onPlaybackError: () => void;
}) {
  if (!shift) return <SearchEmptyCard title="Shift not found" subtitle="Refresh and try again." />;
  return (
    <section className="px-4 py-2">
      <div className="mx-auto grid max-w-5xl gap-3">
        <article className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5">
          <h2 className="text-[15px] font-bold text-[#0F172A]">{shift.shiftName}</h2>
          <div className="mt-3 flex flex-wrap gap-2 text-[11px] font-semibold">
            <span className="rounded-[10px] bg-[#E7F3FF] px-2 py-1 text-[#0E72ED]">{shift.fragments.length} fragments</span>
            <span className="rounded-[10px] bg-[#DCFCE7] px-2 py-1 text-[#10B981]">{shift.fragments.filter((item) => item.canPlay).length} ready</span>
            {shift.subjectName ? <span className="rounded-[10px] bg-[#F3E8FF] px-2 py-1 text-[#7C3AED]">{shift.subjectName}</span> : null}
          </div>
          {shift.date ? <p className="mt-2 text-xs text-[#64748B]">{dateTime(shift.date)}</p> : null}
        </article>
        {shift.fragments.map((recording, index) => (
          <RecordingCard key={recording.recordingId} recording={recording} index={index} total={shift.fragments.length} isExpanded={expandedRecordingId === recording.recordingId} isLoading={loadingRecordingId === recording.recordingId} playbackUrl={playbackUrls[recording.recordingId]} onToggle={() => onToggle(recording)} onPlaybackError={onPlaybackError} />
        ))}
      </div>
    </section>
  );
}

function LevelCard({
  title,
  subtitle,
  tertiary,
  icon,
  iconColor,
  onClick,
}: {
  title: string;
  subtitle: string;
  tertiary?: string;
  icon: React.ReactNode;
  iconColor: string;
  onClick: () => void;
}) {
  return (
    <button type="button" onClick={onClick} className="flex items-center gap-3 rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 text-left shadow-[0_2px_8px_rgba(15,23,42,0.03)]">
      <span className="grid h-[38px] w-[38px] shrink-0 place-items-center rounded-[10px]" style={{ backgroundColor: `${iconColor}1A`, color: iconColor }}>
        {icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-semibold text-[#0F172A]">{title}</span>
        <span className="mt-0.5 block truncate text-xs text-[#64748B]">{subtitle}</span>
        {tertiary ? <span className="mt-0.5 block truncate text-[11px] text-[#94A3B8]">{tertiary}</span> : null}
      </span>
      <ChevronRight className="text-[#94A3B8]" size={22} />
    </button>
  );
}

function RecordingCard({ recording, index, total, isExpanded, isLoading, playbackUrl, onToggle, onPlaybackError }: { recording: RecordingItem; index: number; total: number; isExpanded: boolean; isLoading: boolean; playbackUrl?: string; onToggle: () => void; onPlaybackError: () => void }) {
  const status = statusLabel(recording);
  return (
    <article className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5">
      <div className="flex items-start gap-3">
        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-[10px] bg-[#E7F3FF] text-[#0E72ED]">
          <PlaySquare size={19} />
        </span>
        <div className="min-w-0 flex-1">
          <h2 className="text-sm font-bold text-[#0F172A]">Recording {index + 1} of {total}</h2>
          <p className="mt-1 text-xs text-[#64748B]">{dateTime(displayDate(recording))}</p>
          <div className="mt-3 flex flex-wrap gap-2 text-[11px] font-semibold">
            <span className={`rounded-[10px] px-2 py-1 ${status === "Ready" ? "bg-[#DCFCE7] text-[#10B981]" : status === "Failed" ? "bg-[#FEE2E2] text-[#EF4444]" : "bg-[#FEF3C7] text-[#B45309]"}`}>{status}</span>
            <span className="rounded-[10px] bg-[#F8FAFC] px-2 py-1 text-[#64748B]">{retentionText(recording.deleteAfter)}</span>
          </div>
        </div>
        <button type="button" disabled={!recording.canPlay || isLoading} onClick={onToggle} className={`inline-flex min-h-9 shrink-0 items-center gap-2 rounded-xl px-3 text-xs font-bold ${recording.canPlay ? "bg-[#0E72ED] text-white hover:bg-[#0369F6]" : "cursor-not-allowed bg-[#E2E8F0] text-[#64748B]"}`}>
          {isLoading ? <RefreshCw className="animate-spin" size={14} /> : <Play size={14} />}
          {isExpanded ? "Hide" : recording.canPlay ? "Play" : "Unavailable"}
        </button>
      </div>
      {recording.error ? <p className="mt-3 rounded-xl bg-[#FEF2F2] px-3 py-2 text-xs font-semibold text-[#B91C1C]">{recording.error}</p> : null}
      {isExpanded && playbackUrl ? (
        <video className="mt-4 w-full rounded-xl bg-black" controls preload="metadata" src={playbackUrl} onError={onPlaybackError} />
      ) : null}
    </article>
  );
}

function NoRecordingsCard() {
  return (
    <section className="grid min-h-[calc(100vh-174px)] place-items-center px-8 py-10 lg:min-h-[calc(100vh-176px)]">
      <div className="w-full max-w-[480px] rounded-2xl bg-white px-6 py-8 text-center shadow-[0_4px_12px_rgba(15,23,42,0.04)]">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#E7F3FF] text-[#60A5FA]">
          <PlaySquare size={34} />
        </div>
        <h2 className="mt-5 text-base font-bold text-[#374151]">No recordings yet</h2>
        <p className="mt-3 text-sm leading-6 text-[#6B7280]">Class recordings will appear here after sessions are recorded.</p>
      </div>
    </section>
  );
}

function SearchEmptyCard({ title, subtitle = "Try a different search term." }: { title: string; subtitle?: string }) {
  return (
    <section className="grid min-h-[360px] place-items-center px-8 py-10">
      <div className="text-center">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#F1F5F9] text-[#94A3B8]">
          <Search size={30} />
        </div>
        <h2 className="mt-5 text-base font-bold text-[#374151]">{title}</h2>
        <p className="mt-2 text-sm text-[#6B7280]">{subtitle}</p>
      </div>
    </section>
  );
}

function LoadingRecordings() {
  return (
    <div className="grid min-h-[calc(100vh-160px)] place-items-center">
      <div className="h-11 w-11 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0E72ED]" />
    </div>
  );
}

function ErrorCard({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <section className="mx-auto mt-6 w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-sm">
      <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#FEE2E2] text-[#EF4444]">
        <CircleAlert size={28} />
      </div>
      <p className="mt-4 text-sm font-semibold text-[#374151]">{message}</p>
      <button type="button" onClick={onRetry} className="mt-5 inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#0E72ED] px-5 text-sm font-semibold text-white">
        <RefreshCw size={16} />
        Try Again
      </button>
    </section>
  );
}

async function refresh(
  setLoading: (value: boolean) => void,
  setMessage: (value: string) => void,
  setRecordings: (value: RecordingItem[]) => void,
  setNameCache: (value: Record<string, string>) => void,
  setSearch: (value: string) => void,
  setSelectedStudentId: (value: string | null) => void,
  setSelectedDateKey: (value: string | null) => void,
  setSelectedShiftKey: (value: string | null) => void,
  setExpandedRecordingId: (value: string | null) => void,
  setPlaybackUrls: (value: Record<string, string>) => void,
) {
  setLoading(true);
  setMessage("");
  try {
    const loaded = await loadRecordings();
    const names = await resolveUserNames(loaded.recordings);
    setRecordings(loaded.recordings);
    setNameCache(names);
    resetSelection(setSearch, setSelectedStudentId, setSelectedDateKey, setSelectedShiftKey, setExpandedRecordingId, setPlaybackUrls);
  } catch (error) {
    setMessage(error instanceof Error ? error.message : "Failed to load recordings");
  } finally {
    setLoading(false);
  }
}

async function loadRecordings() {
  const callable = httpsCallable(functions, "listClassRecordings");
  const result = await callable({ limit: 200, activeRole: "teacher" });
  const raw = result.data;
  if (!raw || typeof raw !== "object") throw new Error("Unexpected response from server");
  const data = raw as Record<string, unknown>;
  if (data.success !== true) throw new Error(stringValue(data.error) || "Failed to load recordings");
  const items = Array.isArray(data.recordings) ? data.recordings : [];
  return {
    recordings: items.map((item) => normalizeRecording(item)).filter((item): item is RecordingItem => item !== null),
  };
}

async function resolveUserNames(recordings: RecordingItem[]) {
  const ids = Array.from(new Set(recordings.flatMap((item) => item.studentIds).filter(Boolean)));
  const names: Record<string, string> = {};
  for (let index = 0; index < ids.length; index += 10) {
    const chunk = ids.slice(index, index + 10);
    try {
      const snap = await getDocs(query(collection(db, "users"), where(documentId(), "in", chunk)));
      snap.docs.forEach((entry) => {
        const data = entry.data() as Record<string, unknown>;
        const name = [stringValue(data.first_name ?? data["first-name"]), stringValue(data.last_name ?? data["last-name"])].filter(Boolean).join(" ") || stringValue(data.display_name ?? data.displayName ?? data.name);
        if (name) names[entry.id] = name;
      });
    } catch {
      chunk.forEach((id) => {
        names[id] = shortIdentifier(id);
      });
    }
  }
  return names;
}

function normalizeRecording(raw: unknown): RecordingItem | null {
  if (!raw || typeof raw !== "object") return null;
  const data = raw as Record<string, unknown>;
  const recordingId = stringValue(data.recordingId);
  const filePath = stringValue(data.filePath);
  if (!recordingId || !filePath) return null;
  return {
    recordingId,
    shiftId: stringValue(data.shiftId),
    shiftName: stringValue(data.shiftName) || "Class Recording",
    subjectName: stringValue(data.subjectName),
    teacherId: stringValue(data.teacherId),
    teacherName: stringValue(data.teacherName),
    studentIds: arrayOfStrings(data.studentIds),
    status: stringValue(data.status) || "unknown",
    mergeStatus: stringValue(data.mergeStatus),
    error: stringValue(data.error),
    filePath,
    startedAt: dateValue(data.startedAtIso),
    requestedAt: dateValue(data.requestedAtIso),
    updatedAt: dateValue(data.updatedAtIso),
    deleteAfter: dateValue(data.deleteAfterIso),
    canPlay: data.canPlay === true,
  };
}

function buildStudentBuckets(recordings: RecordingItem[], names: Record<string, string>, search: string): StudentBucket[] {
  const term = search.trim().toLowerCase();
  const buckets = new Map<string, RecordingItem[]>();
  for (const recording of recordings) {
    const ids = recording.studentIds.length ? recording.studentIds : ["unknown"];
    ids.forEach((id) => {
      const list = buckets.get(id) ?? [];
      list.push(recording);
      buckets.set(id, list);
    });
  }
  return Array.from(buckets.entries())
    .map(([id, items]) => ({ id, name: names[id] || (id === "unknown" ? "Unknown student" : shortIdentifier(id)), latestDate: latestRecordingDate(items), recordings: items }))
    .filter((bucket) => !term || bucket.name.toLowerCase().includes(term))
    .sort((a, b) => (b.latestDate?.getTime() ?? 0) - (a.latestDate?.getTime() ?? 0) || a.name.localeCompare(b.name));
}

function buildDateBuckets(recordings: RecordingItem[], search: string): DateBucket[] {
  const term = search.trim().toLowerCase();
  const buckets = new Map<string, RecordingItem[]>();
  for (const recording of recordings) {
    const date = displayDate(recording);
    const key = date ? `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}` : "unknown";
    const list = buckets.get(key) ?? [];
    list.push(recording);
    buckets.set(key, list);
  }
  return Array.from(buckets.entries())
    .map(([key, items]) => ({ key, date: displayDate(items[0]), recordings: items }))
    .filter((bucket) => !term || (bucket.date ? longDate(bucket.date).toLowerCase().includes(term) : "unknown date".includes(term)))
    .sort((a, b) => (b.date?.getTime() ?? 0) - (a.date?.getTime() ?? 0));
}

function buildShiftBuckets(recordings: RecordingItem[], search: string): ShiftBucket[] {
  const term = search.trim().toLowerCase();
  const buckets = new Map<string, RecordingItem[]>();
  for (const recording of recordings) {
    const key = recording.shiftId || `recording:${recording.recordingId}`;
    const list = buckets.get(key) ?? [];
    list.push(recording);
    buckets.set(key, list);
  }
  return Array.from(buckets.entries())
    .map(([key, items]) => ({ key, shiftName: items.find((item) => item.shiftName)?.shiftName || "Class Recording", subjectName: items.find((item) => item.subjectName)?.subjectName || "", date: latestRecordingDate(items), fragments: items.sort((a, b) => (displayDate(a)?.getTime() ?? 0) - (displayDate(b)?.getTime() ?? 0)) }))
    .filter((bucket) => !term || [bucket.shiftName, bucket.subjectName].some((value) => value.toLowerCase().includes(term)))
    .sort((a, b) => (b.date?.getTime() ?? 0) - (a.date?.getTime() ?? 0) || a.shiftName.localeCompare(b.shiftName));
}

async function toggleRecording(
  recording: RecordingItem,
  playbackUrls: Record<string, string>,
  expandedRecordingId: string | null,
  setPlaybackUrls: (value: Record<string, string>) => void,
  setExpandedRecordingId: (value: string | null) => void,
  setLoadingRecordingId: (value: string | null) => void,
  setMessage: (value: string) => void,
) {
  if (expandedRecordingId === recording.recordingId) {
    setExpandedRecordingId(null);
    return;
  }
  if (playbackUrls[recording.recordingId]) {
    setExpandedRecordingId(recording.recordingId);
    return;
  }
  setLoadingRecordingId(recording.recordingId);
  setMessage("");
  try {
    const callable = httpsCallable(functions, "getClassRecordingPlaybackUrl");
    const result = await callable({ recordingId: recording.recordingId, activeRole: "teacher" });
    const raw = result.data;
    if (!raw || typeof raw !== "object") throw new Error("Unexpected playback response from server");
    const data = raw as Record<string, unknown>;
    if (data.success !== true) throw new Error(stringValue(data.error) || "Unable to open recording");
    const url = stringValue(data.url);
    if (!url) throw new Error("Playback URL not available");
    setPlaybackUrls({ ...playbackUrls, [recording.recordingId]: url });
    setExpandedRecordingId(recording.recordingId);
  } catch (error) {
    setMessage(error instanceof Error ? error.message : "Unable to open recording");
  } finally {
    setLoadingRecordingId(null);
  }
}

function goBack(
  level: ViewLevel,
  setSelectedStudentId: (value: string | null) => void,
  setSelectedDateKey: (value: string | null) => void,
  setSelectedShiftKey: (value: string | null) => void,
  setSearch: (value: string) => void,
  setExpandedRecordingId: (value: string | null) => void,
) {
  if (level === "fragments") {
    setSelectedShiftKey(null);
    setExpandedRecordingId(null);
  } else if (level === "shifts") {
    setSelectedDateKey(null);
  } else if (level === "dates") {
    setSelectedStudentId(null);
  }
  setSearch("");
}

function resetSelection(
  setSearch: (value: string) => void,
  setSelectedStudentId: (value: string | null) => void,
  setSelectedDateKey: (value: string | null) => void,
  setSelectedShiftKey: (value: string | null) => void,
  setExpandedRecordingId: (value: string | null) => void,
  setPlaybackUrls: (value: Record<string, string>) => void,
) {
  setSearch("");
  setSelectedStudentId(null);
  setSelectedDateKey(null);
  setSelectedShiftKey(null);
  setExpandedRecordingId(null);
  setPlaybackUrls({});
}

function headerTitle(level: ViewLevel) {
  if (level === "fragments") return "Recording Fragments";
  if (level === "shifts") return "Shifts";
  if (level === "dates") return "Dates";
  return "Students";
}

function headerSubtitle(level: ViewLevel, students: StudentBucket[], dates: DateBucket[], shifts: ShiftBucket[], selectedShift: ShiftBucket | null) {
  if (level === "fragments" && selectedShift) return `${selectedShift.fragments.length} fragment${selectedShift.fragments.length === 1 ? "" : "s"} · ${dateTime(selectedShift.date)}`;
  if (level === "shifts") return `${shifts.length} shift${shifts.length === 1 ? "" : "s"} on this date`;
  if (level === "dates") return `${dates.length} date${dates.length === 1 ? "" : "s"} with recordings`;
  return `${students.length} student${students.length === 1 ? "" : "s"}`;
}

function searchHint(level: ViewLevel) {
  if (level === "students") return "Search student...";
  if (level === "dates") return "Search date...";
  return "Search class or subject...";
}

function statusLabel(recording: RecordingItem) {
  const mergeStatus = recording.mergeStatus.toLowerCase();
  const status = recording.status.toLowerCase();
  if (status === "starting" || mergeStatus === "pending" || mergeStatus === "merging") return "Processing";
  if (["active", "complete", "ended"].includes(status)) return "Ready";
  if (status === "failed") return "Failed";
  return recording.status.trim() || "Unknown";
}

function retentionText(deleteAfter: Date | null) {
  if (!deleteAfter) return "Auto-delete schedule unavailable";
  const diff = deleteAfter.getTime() - Date.now();
  if (diff <= 0) return "Deleting soon";
  const days = Math.floor(diff / 86_400_000);
  if (days >= 28) {
    const months = Math.max(1, Math.round(days / 30));
    return `Auto-deletes in about ${months} month${months === 1 ? "" : "s"}`;
  }
  if (days >= 14) {
    const weeks = Math.floor(days / 7);
    return `Auto-deletes in ${weeks} week${weeks === 1 ? "" : "s"}`;
  }
  if (days >= 2) return `Auto-deletes in ${days} days`;
  const hours = Math.floor(diff / 3_600_000);
  if (hours >= 2) return `Auto-deletes in ${hours} hours`;
  return "Auto-deletes soon";
}

function latestRecordingDate(items: RecordingItem[]) {
  let latest: Date | null = null;
  for (const item of items) {
    const date = displayDate(item);
    if (date && (!latest || date > latest)) latest = date;
  }
  return latest;
}

function displayDate(recording: RecordingItem) {
  return recording.startedAt ?? recording.requestedAt ?? recording.updatedAt;
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

function dateValue(value: unknown): Date | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function arrayOfStrings(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => stringValue(item)).filter(Boolean);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  return (parts[0]?.[0] ?? "T").concat(parts[1]?.[0] ?? parts[0]?.[1] ?? "E").toUpperCase();
}

function shortIdentifier(value: string) {
  return value.length > 8 ? `Student ${value.slice(0, 6)}` : value || "Unknown student";
}

function shortDate(date: Date) {
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric" }).format(date);
}

function longDate(date: Date) {
  return new Intl.DateTimeFormat("en", { weekday: "long", month: "short", day: "numeric", year: "numeric" }).format(date);
}

function dateTime(date: Date | null) {
  if (!date) return "Unknown date";
  return new Intl.DateTimeFormat("en", { weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }).format(date);
}
