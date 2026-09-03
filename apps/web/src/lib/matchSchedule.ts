/**
 * Turns a confirmed match into a starting point for the shift editor.
 *
 * Everything here is a proposal the admin can change before saving. The
 * point is that nothing the family or the teacher already said has to be
 * typed a second time.
 */

import { shiftSubjectSlugForTrack } from "./enrollmentDomain.ts";

export type MatchSchedule = {
  teacherId: string;
  teacherName: string;
  /** Best first, as the teacher ranked them: "4:00 PM - 5:00 PM". */
  rankedSlots: string[];
  /** Family's days: "Mon", "Tue", … */
  days: string[];
  sessionMinutes: number;
  /** The zone the family's window — and so the ranked slots — are in. */
  familyTimeZone: string;
  trackId: string;
  programTitle: string;
};

export type ShiftPrefill = {
  staffId: string | null;
  date: Date | null;
  subjectId?: string;
  studentIds?: string[];
  startStr?: string;
  endStr?: string;
  recurrenceType?: "none" | "daily" | "weekly" | "monthly" | "yearly" | "onetime";
  weeklyDays?: number[];
  notes?: string;
};

const ISO_DAY: Record<string, number> = { mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6, sun: 7 };

/** "Mon" → 1 … "Sun" → 7; unknown names are dropped rather than guessed. */
export const isoWeekdaysFor = (days: string[]): number[] =>
  [...new Set(days.map((d) => ISO_DAY[d.trim().slice(0, 3).toLowerCase()]).filter((n): n is number => Boolean(n)))].sort();

/** "4:00 PM" → "16:00"; null when the text is not a time. */
export const toTimeInput = (text: string): string | null => {
  const m = text.trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
  if (!m) return null;
  let h = Number(m[1]) % 12;
  if (m[3].toUpperCase() === "PM") h += 12;
  return `${String(h).padStart(2, "0")}:${m[2]}`;
};

/** "4:00 PM - 5:00 PM" → { start: "16:00", end: "17:00" }; null when unreadable. */
export const slotToTimes = (slot: string): { start: string; end: string } | null => {
  const parts = slot.split(/\s*[-–]\s*/);
  if (parts.length !== 2) return null;
  const start = toTimeInput(parts[0]);
  const end = toTimeInput(parts[1]);
  return start && end ? { start, end } : null;
};

const addMinutes = (hhmm: string, minutes: number): string => {
  const [h, m] = hhmm.split(":").map(Number);
  const total = (h * 60 + m + minutes) % (24 * 60);
  return `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
};

/** The next calendar date (strictly after `from`) that falls on one of the ISO weekdays. */
export const nextDateOn = (isoDays: number[], from: Date = new Date()): Date | null => {
  if (isoDays.length === 0) return null;
  const wanted = new Set(isoDays);
  const d = new Date(from);
  d.setHours(12, 0, 0, 0);
  for (let i = 1; i <= 7; i++) {
    d.setDate(d.getDate() + 1);
    const iso = ((d.getDay() + 6) % 7) + 1;
    if (wanted.has(iso)) return new Date(d);
  }
  return null;
};

export const shiftPrefillFor = (
  match: MatchSchedule,
  /** Every child in the class — an exclusive family class books one shift. */
  studentIds: string[],
  subjects: { id: string; name: string }[],
  now: Date = new Date(),
): ShiftPrefill => {
  const weeklyDays = isoWeekdaysFor(match.days);
  const slug = shiftSubjectSlugForTrack(match.trackId);
  const subject = subjects.find((s) => s.name.toLowerCase() === slug);
  // The teacher's first choice, with the class length the family asked for.
  // A ranked slot already spans one session, so its own end wins when it
  // parses; the session length is the fallback for a slot without one.
  const first = match.rankedSlots[0] ?? "";
  const times = slotToTimes(first);
  const start = times?.start ?? toTimeInput(first) ?? undefined;
  const end = times?.end ?? (start ? addMinutes(start, match.sessionMinutes || 60) : undefined);

  return {
    staffId: match.teacherId || null,
    date: nextDateOn(weeklyDays, now),
    subjectId: subject?.id,
    studentIds,
    startStr: start,
    endStr: end,
    recurrenceType: weeklyDays.length > 0 ? "weekly" : "none",
    weeklyDays,
    notes: match.programTitle ? `From enrollment: ${match.programTitle}` : undefined,
  };
};
