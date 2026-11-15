/**
 * Pure rules for the parent Recordings page — a line-for-line port of the
 * Flutter `ClassRecordingsScreen` (lib/features/recordings/screens/
 * class_recordings_screen.dart) and `ClassRecordingService`
 * (…/services/class_recording_service.dart) as a parent sees them: the
 * levels Students → Dates → Shifts → Fragments (the Teachers level is
 * admin-only), the same grouping, sorting, search, labels, colours and error
 * texts. No Firebase here, so every rule is unit-tested.
 *
 * Dates are formatted the way Flutter's DateFormat formats them with no locale
 * set (US English), in the browser's local time.
 */

type Data = Record<string, unknown>;

// ─── Recording (ClassRecordingItem.fromMap) ────────────────────────────────

export type ParentRecording = {
  recordingId: string;
  shiftId: string | null;
  shiftName: string;
  subjectName: string;
  teacherId: string | null;
  teacherName: string;
  studentIds: string[];
  status: string;
  mergeStatus: string | null;
  error: string | null;
  filePath: string;
  shiftStart: Date | null;
  requestedAt: Date | null;
  startedAt: Date | null;
  updatedAt: Date | null;
  deleteAfter: Date | null;
  canPlay: boolean;
};

const str = (value: unknown): string | null => (value === null || value === undefined ? null : String(value));

function parseDate(value: unknown): Date | null {
  if (value === null || value === undefined) return null;
  const parsed = new Date(String(value));
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

/** `_parseStringList`: trimmed, empty and repeated ids dropped, order kept. */
function stringList(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const item of raw) {
    const value = item === null || item === undefined ? "" : String(item).trim();
    if (!value || seen.has(value)) continue;
    seen.add(value);
    out.push(value);
  }
  return out;
}

export function parseRecording(data: Data): ParentRecording {
  const shiftName = str(data.shiftName)?.trim() ?? "";
  return {
    recordingId: str(data.recordingId) ?? "",
    shiftId: str(data.shiftId),
    shiftName: shiftName || "Class Recording",
    subjectName: str(data.subjectName) ?? "",
    teacherId: str(data.teacherId),
    teacherName: str(data.teacherName) ?? "",
    studentIds: stringList(data.studentIds),
    status: str(data.status) ?? "unknown",
    mergeStatus: str(data.mergeStatus),
    error: str(data.error),
    filePath: str(data.filePath) ?? "",
    shiftStart: parseDate(data.shiftStartIso),
    requestedAt: parseDate(data.requestedAtIso),
    startedAt: parseDate(data.startedAtIso),
    updatedAt: parseDate(data.updatedAtIso),
    deleteAfter: parseDate(data.deleteAfterIso),
    canPlay: data.canPlay === true,
  };
}

/** `ClassRecordingItem.displayDate`. */
export const displayDate = (r: Pick<ParentRecording, "startedAt" | "requestedAt" | "shiftStart" | "updatedAt">) =>
  r.startedAt ?? r.requestedAt ?? r.shiftStart ?? r.updatedAt;

// ─── Callable answers (ClassRecordingService) ──────────────────────────────

export type ListOutcome = { ok: true; role: string | null; recordings: ParentRecording[] } | { ok: false; error: string };

/**
 * `listRecordings` after the call returned: a non-map answer is an error, items
 * without an id or a file are skipped, and `success != true` with no error
 * text falls back to the screen's "Failed to load recordings".
 */
export function readListAnswer(raw: unknown): ListOutcome {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return { ok: false, error: "Unexpected response from server" };
  const data = raw as Data;
  const items = Array.isArray(data.recordings) ? data.recordings : [];
  const recordings: ParentRecording[] = [];
  for (const item of items) {
    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
    const parsed = parseRecording(item as Data);
    if (parsed.recordingId && parsed.filePath) recordings.push(parsed);
  }
  if (data.success !== true) return { ok: false, error: "Failed to load recordings" };
  return { ok: true, role: str(data.role), recordings };
}

export type PlaybackOutcome = { ok: true; url: string } | { ok: false; error: string };

export function readPlaybackAnswer(raw: unknown): PlaybackOutcome {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return { ok: false, error: "Unexpected playback response from server" };
  const data = raw as Data;
  if (data.success !== true) return { ok: false, error: str(data.error) ?? "Unable to open recording" };
  const url = str(data.url)?.trim() ?? "";
  if (!url) return { ok: false, error: "Playback URL not available" };
  return { ok: true, url };
}

/**
 * The text Flutter shows for a thrown error: a callable error's message when it
 * has one, else "<code>: <fallback>"; any other error the generic sentence.
 * The JS SDK prefixes codes with "functions/", which Dart does not.
 */
export function callableErrorText(error: unknown, kind: "list" | "playback"): string {
  const e = error as { code?: unknown; message?: unknown } | null;
  const code = typeof e?.code === "string" ? e.code : "";
  if (code.startsWith("functions/")) {
    const message = typeof e?.message === "string" ? e.message.trim() : "";
    if (message) return message;
    return `${code.slice("functions/".length)}: ${kind === "list" ? "failed to load recordings" : "unable to open recording"}`;
  }
  return kind === "list" ? "Failed to load recordings" : "Failed to open recording";
}

// ─── People (getUserSearchDataByIds) ───────────────────────────────────────

export type RecordingPerson = { id: string; name: string; email: string; phone: string };

const text = (value: unknown) => (value === null || value === undefined ? "" : String(value));

/** Name: first + last, else name / displayName, else e-mail, else the id. */
export function personName(fallbackId: string, data: Data) {
  const first = text(data.first_name ?? data.firstName).trim();
  const last = text(data.last_name ?? data.lastName).trim();
  const full = [first, last].filter(Boolean).join(" ").trim();
  if (full) return full;
  const direct = text(data.name ?? data.displayName).trim();
  if (direct) return direct;
  const email = text(data["e-mail"] ?? data.email).trim();
  if (email) return email;
  return fallbackId;
}

/** Every id a user document answers to (doc id, uid, auth uid fields). */
export function personAliases(docId: string, data: Data) {
  const ids = new Set([
    docId.trim(),
    text(data.uid).trim(),
    text(data.auth_uid ?? data.authUid).trim(),
    text(data.auth_user_id ?? data.authUserId).trim(),
  ]);
  ids.delete("");
  return [...ids];
}

/** One user document → an entry per alias, as Flutter fills its search cache. */
export function peopleFromDoc(docId: string, data: Data): Record<string, RecordingPerson> {
  const name = personName(docId, data);
  const email = text(data["e-mail"] ?? data.email);
  const phone = text(data.phone_number ?? data.phoneNumber ?? data.mobile_phone ?? data.mobilePhone ?? data.phone);
  const out: Record<string, RecordingPerson> = {};
  for (const alias of personAliases(docId, data)) out[alias] = { id: alias, name, email, phone };
  return out;
}

/** The users to look up: every teacher and every (visible) student id. */
export function peopleToResolve(recordings: ParentRecording[]) {
  const ids = new Set<string>();
  for (const r of recordings) {
    const teacher = r.teacherId?.trim() ?? "";
    if (teacher) ids.add(teacher);
    for (const id of r.studentIds) {
      const trimmed = id.trim();
      if (trimmed) ids.add(trimmed);
    }
  }
  return [...ids];
}

export function chunk<T>(list: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

// ─── Search (AppSearch.matches) ────────────────────────────────────────────

export const normalizeText = (value: string) => value.trim().toLowerCase().replace(/\s+/g, " ");
const digitsOnly = (value: string) => value.replace(/[^0-9]/g, "");
const normalizeIdentifier = (value: string) => normalizeText(value).replace(/[^a-z0-9]/g, "");
const looksLikePhone = (value: string) => /^[\d\s()+.-]+$/.test(value.trim());
const phoneVariants = (digits: string) => {
  const set = new Set([digits]);
  if (digits.startsWith("0") && digits.length > 7) set.add(digits.slice(1));
  return [...set];
};

export function appSearchMatches(p: {
  query: string;
  names?: string[];
  emails?: string[];
  phones?: string[];
  ids?: string[];
  additionalValues?: string[];
}) {
  const q = normalizeText(p.query);
  if (!q) return true;
  if ((p.names ?? []).some((name) => normalizeText(name).includes(q))) return true;
  if ((p.emails ?? []).some((email) => normalizeText(email).includes(q))) return true;
  const idQuery = normalizeIdentifier(p.query);
  if ((p.ids ?? []).some((id) => normalizeText(id).includes(q) || (idQuery !== "" && normalizeIdentifier(id).includes(idQuery)))) return true;
  const queryDigits = digitsOnly(p.query);
  if (looksLikePhone(p.query) && queryDigits.length >= 7) {
    const queryForms = phoneVariants(queryDigits);
    const phoneMatch = (p.phones ?? []).some((phone) => {
      const phoneDigits = digitsOnly(phone);
      if (phoneDigits.length < 7) return false;
      const phoneForms = phoneVariants(phoneDigits);
      return queryForms.some((qv) => phoneForms.some((pv) => pv === qv || pv.endsWith(qv) || qv.endsWith(pv)));
    });
    if (phoneMatch) return true;
  }
  return (p.additionalValues ?? []).some((value) => normalizeText(value).includes(q));
}

// ─── Levels ────────────────────────────────────────────────────────────────

export const UNKNOWN_STUDENT = "__unknown_student__";
export const UNKNOWN_DATE = "__unknown_date__";

export type People = Record<string, RecordingPerson>;

/** Dart String.compareTo: plain code-unit order. */
const compare = (a: string, b: string) => (a === b ? 0 : a < b ? -1 : 1);

function latestDate(items: ParentRecording[]) {
  let latest: Date | null = null;
  for (const item of items) {
    const d = displayDate(item);
    if (d && (!latest || d > latest)) latest = d;
  }
  return latest;
}

/** Newest first, undated last, then by name (lower-cased). */
function byDateThenName<T>(dateOf: (x: T) => Date | null, nameOf: (x: T) => string) {
  return (a: T, b: T) => {
    const ad = dateOf(a);
    const bd = dateOf(b);
    if (!ad && !bd) return compare(nameOf(a).toLowerCase(), nameOf(b).toLowerCase());
    if (!ad) return 1;
    if (!bd) return -1;
    const diff = bd.getTime() - ad.getTime();
    if (diff !== 0) return diff;
    return compare(nameOf(a).toLowerCase(), nameOf(b).toLowerCase());
  };
}

export function studentName(id: string, people: People) {
  if (id === UNKNOWN_STUDENT) return "Unknown Student";
  const cached = people[id]?.name;
  return cached && cached.trim() ? cached : id;
}

export type StudentBucket = { id: string; name: string; recordings: ParentRecording[]; latestDate: Date | null };

/**
 * Level 1: one card per child that has a recording (a class shared by two
 * siblings counts under each), filtered by the search box, newest first.
 */
export function studentBuckets(recordings: ParentRecording[], people: People, query: string): StudentBucket[] {
  const grouped = new Map<string, ParentRecording[]>();
  for (const r of recordings) {
    if (r.studentIds.length === 0) {
      grouped.set(UNKNOWN_STUDENT, [...(grouped.get(UNKNOWN_STUDENT) ?? []), r]);
      continue;
    }
    for (const raw of r.studentIds) {
      const id = raw.trim();
      if (!id) continue;
      grouped.set(id, [...(grouped.get(id) ?? []), r]);
    }
  }
  let buckets = [...grouped.entries()].map(([id, items]) => ({ id, name: studentName(id, people), recordings: items, latestDate: latestDate(items) }));
  if (query.trim()) {
    buckets = buckets.filter((b) => {
      const person = people[b.id];
      return appSearchMatches({ query, names: [b.name], emails: [person?.email ?? ""], phones: [person?.phone ?? ""], ids: [b.id, person?.id ?? ""] });
    });
  }
  return buckets.sort(byDateThenName((b) => b.latestDate, (b) => b.name));
}

export function recordingsForStudent(recordings: ParentRecording[], studentId: string | null) {
  if (studentId === null) return [];
  if (studentId === UNKNOWN_STUDENT) return recordings.filter((r) => r.studentIds.length === 0);
  return recordings.filter((r) => r.studentIds.includes(studentId));
}

/** `_dateKey`: the local calendar day, yyyy-mm-dd. */
export function dateKey(date: Date | null) {
  if (!date) return UNKNOWN_DATE;
  const y = String(date.getFullYear()).padStart(4, "0");
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function dateFromKey(key: string) {
  if (key === UNKNOWN_DATE) return null;
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export type DateBucket = { key: string; date: Date | null; recordings: ParentRecording[] };

/** Level 2: a card per local day, newest first; search matches the long or short date. */
export function dateBuckets(source: ParentRecording[], query: string): DateBucket[] {
  const grouped = new Map<string, ParentRecording[]>();
  for (const r of source) {
    const key = dateKey(displayDate(r));
    grouped.set(key, [...(grouped.get(key) ?? []), r]);
  }
  let buckets = [...grouped.entries()].map(([key, items]) => ({ key, date: dateFromKey(key), recordings: items }));
  const q = query.trim().toLowerCase();
  if (q) {
    buckets = buckets.filter((b) => {
      if (!b.date) return "unknown date".includes(q);
      return longDate(b.date).toLowerCase().includes(q) || shortDate(b.date).toLowerCase().includes(q);
    });
  }
  return buckets.sort((a, b) => {
    if (!a.date && !b.date) return 0;
    if (!a.date) return 1;
    if (!b.date) return -1;
    return b.date.getTime() - a.date.getTime();
  });
}

export function recordingsForDate(source: ParentRecording[], key: string | null) {
  if (key === null) return [];
  return source.filter((r) => dateKey(displayDate(r)) === key);
}

/** `_teacherNameForRecording`: the looked-up name, else the stored one, else the id. */
export function teacherName(r: ParentRecording, people: People) {
  const id = r.teacherId?.trim() ?? "";
  if (id) {
    const cached = people[id]?.name;
    if (cached && cached.trim()) return cached;
  }
  const stored = r.teacherName.trim();
  if (stored) return stored;
  return id || "Unknown Teacher";
}

export type ShiftBucket = {
  key: string;
  shiftId: string;
  shiftName: string;
  subjectName: string;
  teacherName: string;
  date: Date | null;
  fragments: ParentRecording[];
  readyCount: number;
};

/**
 * Level 3: one card per class session on that day (grouped by shift id, or one
 * per recording without one), fragments oldest first. Search matches the
 * teacher's name, e-mail and phone, the class and teacher ids, the class name
 * and the subject — exactly the fields Flutter searches.
 */
export function shiftBuckets(source: ParentRecording[], people: People, query: string): ShiftBucket[] {
  const grouped = new Map<string, ParentRecording[]>();
  for (const r of source) {
    const shiftId = r.shiftId?.trim();
    const key = shiftId ? `shift:${shiftId}` : `recording:${r.recordingId}`;
    grouped.set(key, [...(grouped.get(key) ?? []), r]);
  }
  let buckets = [...grouped.entries()].map(([key, items]) => {
    const fragments = [...items].sort((a, b) => {
      const ad = displayDate(a);
      const bd = displayDate(b);
      if (!ad && !bd) return compare(a.recordingId, b.recordingId);
      if (!ad) return 1;
      if (!bd) return -1;
      const diff = ad.getTime() - bd.getTime();
      if (diff !== 0) return diff;
      return compare(a.recordingId, b.recordingId);
    });
    const first = fragments[0];
    return {
      key,
      shiftId: first.shiftId?.trim() ?? "",
      shiftName: first.shiftName.trim() || "Class Recording",
      subjectName: first.subjectName.trim(),
      teacherName: teacherName(first, people),
      date: latestDate(fragments),
      fragments,
      readyCount: fragments.filter((f) => f.canPlay).length,
    };
  });
  if (query.trim()) {
    buckets = buckets.filter((b) => {
      const teacherId = b.fragments[0].teacherId?.trim() ?? "";
      const teacher = people[teacherId];
      return appSearchMatches({
        query,
        names: [b.teacherName],
        emails: [teacher?.email ?? ""],
        phones: [teacher?.phone ?? ""],
        ids: [b.shiftId, teacherId],
        additionalValues: [b.shiftName, b.subjectName],
      });
    });
  }
  return buckets.sort(byDateThenName((b) => b.date, (b) => b.shiftName));
}

// ─── Header, search hint, cards ────────────────────────────────────────────

export type Level = "students" | "dates" | "shifts" | "fragments";

export function levelOf(sel: { studentId: string | null; dateKey: string | null; shiftKey: string | null }): Level {
  if (sel.shiftKey !== null) return "fragments";
  if (sel.dateKey !== null) return "shifts";
  if (sel.studentId !== null) return "dates";
  return "students";
}

const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? "" : "s"}`;

export function headerTitle(level: Level, shift: ShiftBucket | null) {
  if (level === "fragments") return shift?.shiftName ?? "Recording Fragments";
  if (level === "shifts") return "Shifts";
  if (level === "dates") return "Dates";
  return "Students";
}

export function headerSubtitle(level: Level, counts: { students: number; dates: number; shifts: number }, shift: ShiftBucket | null) {
  if (level === "fragments") return shift ? `${plural(shift.fragments.length, "fragment")} · ${dateTime(shift.date)}` : "";
  if (level === "shifts") return `${plural(counts.shifts, "shift")} on this date`;
  if (level === "dates") return `${plural(counts.dates, "date")} with recordings`;
  return plural(counts.students, "student");
}

export function searchHint(level: Level) {
  if (level === "students") return "Search student...";
  if (level === "dates") return "Search date...";
  return "Search class or subject...";
}

export const recordingCountText = (n: number) => plural(n, "recording");

export function shiftSubtitle(b: ShiftBucket) {
  const parts = [plural(b.fragments.length, "fragment"), `Ready: ${b.readyCount}`];
  if (b.subjectName) parts.push(b.subjectName);
  return parts.join(" · ");
}

export const fragmentTitle = (index: number, total: number) => (total > 1 ? `Fragment ${index}` : "Full Recording");

// ─── Status, retention, play button ────────────────────────────────────────

export function isProcessing(r: Pick<ParentRecording, "status" | "mergeStatus">) {
  const merge = r.mergeStatus?.trim().toLowerCase();
  return r.status.trim().toLowerCase() === "starting" || merge === "pending" || merge === "merging";
}

export function statusLabel(r: Pick<ParentRecording, "status" | "mergeStatus">) {
  if (isProcessing(r)) return "Processing";
  switch (r.status.toLowerCase()) {
    case "active":
    case "complete":
    case "ended":
      return "Ready";
    case "starting":
      return "Processing";
    case "failed":
      return "Failed";
    default:
      return r.status.trim() || "Unknown";
  }
}

export function statusColor(r: Pick<ParentRecording, "status" | "mergeStatus">) {
  if (isProcessing(r)) return "#F59E0B";
  switch (r.status.toLowerCase()) {
    case "active":
    case "complete":
    case "ended":
      return "#10B981";
    case "starting":
      return "#F59E0B";
    case "failed":
      return "#EF4444";
    default:
      return "#64748B";
  }
}

const DAY = 86_400_000;
const HOUR = 3_600_000;
const MINUTE = 60_000;

/** `_formatRetentionCountdown`. */
export function retentionText(deleteAfter: Date | null, now: Date) {
  if (!deleteAfter) return "Auto-delete schedule unavailable";
  const diff = deleteAfter.getTime() - now.getTime();
  if (diff <= 0) return "Deleting soon";
  const days = Math.floor(diff / DAY);
  if (days >= 28) {
    const months = Math.min(24, Math.max(1, Math.round(days / 30)));
    return `Auto-deletes in about ${months} month${months === 1 ? "" : "s"}`;
  }
  if (days >= 14) {
    const weeks = Math.floor(days / 7);
    return `Auto-deletes in ${weeks} week${weeks === 1 ? "" : "s"}`;
  }
  if (days >= 2) return `Auto-deletes in ${days} days`;
  const hours = Math.floor(diff / HOUR);
  if (hours >= 2) return `Auto-deletes in ${hours} hours`;
  const minutes = Math.floor(diff / MINUTE);
  if (minutes >= 2) return `Auto-deletes in ${minutes} minutes`;
  return "Auto-deletes in less than a minute";
}

/** `_retentionCountdownColor`: red under 3 days, amber under 14, teal otherwise. */
export function retentionColor(deleteAfter: Date | null, now: Date) {
  if (!deleteAfter) return "#64748B";
  const diff = deleteAfter.getTime() - now.getTime();
  const days = Math.trunc(diff / DAY);
  if (diff <= 0 || days < 3) return "#DC2626";
  if (days < 14) return "#B45309";
  return "#0E7490";
}

/** The chip text: the countdown plus " · MMM d, yyyy" when the date is known. */
export function retentionChip(deleteAfter: Date | null, now: Date) {
  const countdown = retentionText(deleteAfter, now);
  return deleteAfter ? `${countdown} · ${shortDate(deleteAfter)}` : countdown;
}

export function playLabel(r: ParentRecording, loading: boolean) {
  if (loading) return "Loading...";
  if (r.canPlay) return "Play Recording";
  return isProcessing(r) ? "Processing..." : "Not Ready Yet";
}

// ─── Dates (DateFormat, en_US) ─────────────────────────────────────────────

const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** 'MMM d, yyyy' */
export const shortDate = (d: Date) => `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;

/** 'EEEE, MMM d, yyyy' */
export const longDate = (d: Date) => `${WEEKDAYS[d.getDay()]}, ${shortDate(d)}`;

/** 'EEE, MMM d · h:mm a', or "Unknown date". */
export function dateTime(d: Date | null) {
  if (!d) return "Unknown date";
  const hour = d.getHours() % 12 || 12;
  const minute = String(d.getMinutes()).padStart(2, "0");
  return `${WEEKDAYS[d.getDay()].slice(0, 3)}, ${MONTHS[d.getMonth()]} ${d.getDate()} · ${hour}:${minute} ${d.getHours() < 12 ? "AM" : "PM"}`;
}

/** The player's clock: mm:ss, or hh:mm:ss past an hour. */
export function playerTime(seconds: number) {
  const total = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0;
  const h = Math.floor(total / 3600);
  const m = Math.floor(total / 60) % 60;
  const s = total % 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  return h > 0 ? `${pad(h)}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
}

/** The ±10 s buttons, kept inside the video. */
export function skipTo(position: number, duration: number, delta: number) {
  const next = position + delta;
  if (next < 0) return 0;
  if (Number.isFinite(duration) && duration > 0 && next > duration) return duration;
  return next;
}
