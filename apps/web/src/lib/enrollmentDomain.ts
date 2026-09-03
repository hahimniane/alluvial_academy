/**
 * The shared vocabulary of enrollment: tracks, class types, time blocks,
 * session lengths, and the slot maths that turns a family's window into the
 * concrete times a teacher can pick.
 *
 * This module is the single definition of these terms. The enrollment wizard,
 * the teacher job board and the admin screens all read from here, so a family's
 * "Evening" and a teacher's "Evening" can never drift apart.
 */

/* ---------------------------------------------------------------- tracks -- */

export type TrackId = "islamic" | "adlam" | "tutoring" | "group";

export type Track = {
  id: TrackId;
  title: string;
  /** Hex from the design handoff §2 — track chips and schedule headers. */
  color: string;
};

export const TRACKS: readonly Track[] = [
  { id: "islamic", title: "Religious Studies", color: "#4F46E5" },
  { id: "adlam", title: "Adlam", color: "#7C3AED" },
  { id: "tutoring", title: "Tutoring & Literacy", color: "#0EA5E9" },
  { id: "group", title: "Group Classes", color: "#059669" },
] as const;

export const trackById = (id: string): Track | undefined =>
  TRACKS.find((track) => track.id === id);

/**
 * Adlam has no entry in PublicSiteCmsPricingDoc / PricingPlanIds, so it bills
 * at the Tutoring rate until the school sets its own.
 *
 * TODO(pricing): give `adlam` its own plan and delete this alias.
 */
export const pricingTrackFor = (trackId: string): string =>
  trackId === "adlam" ? "tutoring" : trackId;

/* ------------------------------------------------------------ class type -- */

export type ClassTypeValue =
  | "One-on-One"
  | "Exclusive Family Class"
  | "With Other Students";

export type ClassType = {
  value: ClassTypeValue;
  label: string;
  hint: string;
  /** Whether the family is asked for days and a time block. */
  familyPicksTimes: boolean;
};

export const CLASS_TYPES: readonly ClassType[] = [
  {
    value: "One-on-One",
    label: "1-on-1",
    hint: "Just this student with the teacher.",
    familyPicksTimes: true,
  },
  {
    value: "Exclusive Family Class",
    label: "Exclusive family class",
    hint: "Only your children in the class, taught together.",
    familyPicksTimes: true,
  },
  {
    value: "With Other Students",
    label: "With other students on the platform",
    hint: "We place the student in a group and set the timetable.",
    familyPicksTimes: false,
  },
] as const;

/**
 * `'Both'` and `'Group'` are gone. Existing rows still carry them, so every
 * read normalises. `'Group'` becomes "With Other Students" as the handoff
 * specifies; `'Both'` meant "either suits us" and has no successor, so it falls
 * back to 1-on-1 — the narrower, safer reading of an ambiguous answer.
 */
export const normalizeClassType = (raw: unknown): ClassTypeValue => {
  const value = String(raw ?? "").trim();
  if (value === "Group") return "With Other Students";
  if (value === "Both") return "One-on-One";
  const known = CLASS_TYPES.find((type) => type.value === value);
  return known ? known.value : "One-on-One";
};

/* ---------------------------------------------------------- time blocks -- */

export type BlockId = "Morning" | "Afternoon" | "Evening" | "Night" | "Late night";

export type TimeBlock = {
  id: BlockId;
  label: string;
  /** Minutes from midnight. End is exclusive, so a slot never crosses midnight. */
  startMinutes: number;
  endMinutes: number;
  color: string;
};

export const TIME_BLOCKS: readonly TimeBlock[] = [
  { id: "Morning", label: "Morning", startMinutes: 300, endMinutes: 720, color: "#F59E0B" },
  { id: "Afternoon", label: "Afternoon", startMinutes: 720, endMinutes: 960, color: "#3B82F6" },
  { id: "Evening", label: "Evening", startMinutes: 960, endMinutes: 1260, color: "#6366F1" },
  { id: "Night", label: "Night", startMinutes: 1260, endMinutes: 1440, color: "#4F46E5" },
  { id: "Late night", label: "Late night", startMinutes: 0, endMinutes: 300, color: "#64748B" },
] as const;

export const blockById = (id: string): TimeBlock | undefined =>
  TIME_BLOCKS.find((block) => block.id === id);

/**
 * `'Flexible'` is dropped — the five blocks now cover all 24 hours, so it no
 * longer narrows anything. Existing rows become null and are re-asked.
 */
export const normalizeBlock = (raw: unknown): BlockId | null => {
  const value = String(raw ?? "").trim();
  if (!value || value === "Flexible") return null;
  return blockById(value)?.id ?? null;
};

/* ------------------------------------------------------ session lengths -- */

export const SESSION_MINUTES = [30, 60, 90, 120] as const;
export type SessionMinutes = (typeof SESSION_MINUTES)[number];

export const sessionLabel = (minutes: number): string => {
  if (minutes < 60) return `${minutes} min`;
  const hours = minutes / 60;
  if (Number.isInteger(hours)) return `${hours} hour${hours === 1 ? "" : "s"}`;
  return `${hours} hours`;
};

/**
 * Session duration used to be *derived* from weekly hours, which is why a
 * family asking for 4 hrs/week was offered a single "5:00 PM – 9:00 PM" slot.
 * It is now its own question, and this is the check that the two agree.
 */
export const weeklyHoursFor = (sessionsPerWeek: number, sessionMinutes: number): number =>
  Math.round(((sessionsPerWeek * sessionMinutes) / 60) * 100) / 100;

export const hoursMatchSessions = (
  hoursPerWeek: number,
  sessionsPerWeek: number,
  sessionMinutes: number,
): boolean => Math.abs(weeklyHoursFor(sessionsPerWeek, sessionMinutes) - hoursPerWeek) < 0.01;

/* --------------------------------------------------------- slot generation -- */

export const formatMinutes = (minutes: number): string => {
  const total = ((minutes % 1440) + 1440) % 1440;
  const hour24 = Math.floor(total / 60);
  const minute = total % 60;
  const suffix = hour24 < 12 ? "AM" : "PM";
  const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;
  return `${hour12}:${String(minute).padStart(2, "0")} ${suffix}`;
};

export const blockRangeLabel = (block: TimeBlock): string =>
  `${formatMinutes(block.startMinutes)} – ${formatMinutes(block.endMinutes - 1)}`;

/**
 * Every window of `sessionMinutes` that fits inside the block, advanced by
 * `step`.
 *
 * The step is the whole point. Teachers get a **sliding** window (step 30), so
 * Evening + 2 hours offers 4–6, 4:30–6:30, 5–7 … 7–9. Stepping by a full
 * session would only offer 4–6 and 6–8 and hide most of the teacher's real
 * availability — that was the original bug.
 */
export const slotsFor = (
  block: TimeBlock | null | undefined,
  sessionMinutes: number,
  step = 30,
): string[] => {
  if (!block || !Number.isFinite(sessionMinutes) || sessionMinutes <= 0) return [];
  if (!Number.isFinite(step) || step <= 0) return [];
  const slots: string[] = [];
  for (let t = block.startMinutes; t + sessionMinutes <= block.endMinutes; t += step) {
    slots.push(`${formatMinutes(t)} - ${formatMinutes(t + sessionMinutes)}`);
  }
  return slots;
};

/** Whether a session of this length fits inside the block at all. */
export const sessionFitsBlock = (
  block: TimeBlock | null | undefined,
  sessionMinutes: number,
): boolean => slotsFor(block, sessionMinutes, 30).length > 0;

/* ---------------------------------------------------------- programs -- */

export type ProgramSelection = {
  subject: string;
  /** Only when subject is AfroLanguages. */
  specificLanguage?: string;
  level: string;
  classType: ClassTypeValue;
  sessionMinutes: number;
  sessionsPerWeek: number;
  hoursPerWeek: number;
  days: string[];
  block: BlockId | null;
};

export const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] as const;

/** A program is schedulable when it has days, a block, and a session that fits. */
export const programScheduleIsComplete = (program: ProgramSelection): boolean => {
  const type = CLASS_TYPES.find((t) => t.value === program.classType);
  if (!type) return false;
  if (program.days.length === 0) return false;
  if (!program.block) return false;
  return sessionFitsBlock(blockById(program.block), program.sessionMinutes);
};

/* ------------------------------------------------------ legacy durations -- */

/**
 * Older enrollments store the class length as a label ("1 hr", "90 mins",
 * "60 minutes"). Newer ones carry `sessionMinutes`; this reads the label when
 * that is all there is.
 */
export const minutesFromDurationLabel = (label: string): number => {
  const text = label.toLowerCase();
  if (!text) return 60;
  const hourMatch = text.match(/(\d+(?:\.\d+)?)\s*(?:hr|hour)/);
  const minuteMatch = text.match(/(\d+)\s*(?:min)/);
  let minutes = 0;
  if (hourMatch) minutes += Math.round(Number.parseFloat(hourMatch[1]) * 60);
  if (minuteMatch) minutes += Number.parseInt(minuteMatch[1], 10);
  return minutes > 0 ? minutes : 60;
};

/* --------------------------------------------------- shift subject slugs -- */

/**
 * The `subjects` collection a shift is filed under uses short slugs; an
 * enrollment names a track. This is the default a scheduler starts from and
 * can change — Adlam has no subject of its own yet, so it files under the
 * African-languages subject.
 */
export const shiftSubjectSlugForTrack = (trackId: string): string => {
  if (trackId === "adlam") return "afrolingual";
  if (trackId === "tutoring") return "english";
  return "islamic";
};
