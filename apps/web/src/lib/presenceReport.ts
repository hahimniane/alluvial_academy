/**
 * Reading a connection report.
 *
 * The figures come from the hub bot watching each class from the inside. Only
 * drops we could not trace to ourselves reach a teacher's number — a hub
 * handover or a bot restart is our doing and is kept separately — so what a
 * teacher sees here is their own connection, not our faults wearing their name.
 *
 * The wording matters as much as the arithmetic. This exists so somebody can
 * move rooms or get a hotspot before their next lesson, not to accuse them of
 * anything, so nothing here is phrased as a failing.
 */

export type PresenceTally = {
  drops: number;
  secondsLost: number;
  longestSeconds: number;
  neverReturned: number;
};

/** One absence, with the clock times it is claiming. */
export type PresenceSpell = {
  from: number | null;
  to: number | null;
  seconds: number | null;
  returned: boolean;
  cause: string;
};

/** One class somebody dropped out of: the day, the class, and who it was with. */
export type PresenceOccasion = {
  shiftId: string | null;
  className: string | null;
  students: string[];
  /** The hours the class was scheduled to run. */
  startedAt: number | null;
  endedAt: number | null;
  drops: number;
  secondsLost: number;
  longestSeconds: number;
  neverReturned: number;
  spells: PresenceSpell[];
};

export type PresenceReport = {
  uid: string;
  role: string | null;
  name: string | null;
  classes: number;
  classes_with_a_drop: number;
  counted: PresenceTally;
  by_cause?: Record<string, PresenceTally>;
  occasions?: PresenceOccasion[];
};

const EMPTY: PresenceTally = { drops: 0, secondsLost: 0, longestSeconds: 0, neverReturned: 0 };

/** A tally we can rely on, whatever shape came back. */
export function tallyOf(report: PresenceReport | null | undefined): PresenceTally {
  const counted = report?.counted;
  if (!counted || typeof counted !== "object") return EMPTY;
  return {
    drops: Number(counted.drops) || 0,
    secondsLost: Number(counted.secondsLost) || 0,
    longestSeconds: Number(counted.longestSeconds) || 0,
    neverReturned: Number(counted.neverReturned) || 0,
  };
}

/**
 * A duration somebody reads at a glance. Seconds below a minute stay seconds,
 * because "0m" for a forty-second drop reads as nothing happening.
 */
export function formatDuration(totalSeconds: number): string {
  const seconds = Math.max(0, Math.round(totalSeconds));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    const rest = seconds % 60;
    return rest === 0 ? `${minutes}m` : `${minutes}m ${rest}s`;
  }
  const hours = Math.floor(minutes / 60);
  const restMinutes = minutes % 60;
  return restMinutes === 0 ? `${hours}h` : `${hours}h ${restMinutes}m`;
}

/**
 * How settled a connection looks, for colour only.
 *
 * Deliberately coarse. A precise-looking score would invite treating this as a
 * rating, which it is not: it cannot tell a failing router from a Zoom hiccup
 * or a closed laptop.
 */
export type ConnectionStanding = "steady" | "unsettled" | "struggling";

export function standingOf(report: PresenceReport | null | undefined): ConnectionStanding {
  const tally = tallyOf(report);
  if (tally.drops === 0) return "steady";
  const classes = Math.max(1, Number(report?.classes) || 1);
  const dropsPerClass = tally.drops / classes;
  if (dropsPerClass >= 2 || tally.neverReturned > 0) return "struggling";
  return "unsettled";
}

/**
 * One sentence describing the period, in plain words.
 *
 * Returns null when there is nothing to say, so a caller can leave the space
 * empty rather than print a reassurance nobody asked for.
 */
export function describeConnection(
  report: PresenceReport | null | undefined,
  t: (en: string, vars?: Record<string, string | number>) => string,
): string | null {
  const tally = tallyOf(report);
  const classes = Number(report?.classes) || 0;
  if (classes === 0) return null;
  if (tally.drops === 0) {
    return t("Your connection held for every class this period.");
  }
  const affected = Number(report?.classes_with_a_drop) || 0;
  return t("You dropped out {drops} times across {affected} of {classes} classes, losing {lost} of lesson time.", {
    drops: tally.drops,
    affected,
    classes,
    lost: formatDuration(tally.secondsLost),
  });
}

/** What we caused, kept apart from what the teacher is shown as theirs. */
export function platformDrops(report: PresenceReport | null | undefined): number {
  const byCause = report?.by_cause;
  if (!byCause) return 0;
  const ours = Number(byCause.platform?.drops) || 0;
  const together = Number(byCause.simultaneous?.drops) || 0;
  return ours + together;
}

/** The classes behind the totals, newest first, with nothing malformed in them. */
export function occasionsOf(report: PresenceReport | null | undefined): PresenceOccasion[] {
  const raw = report?.occasions;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((occasion): occasion is PresenceOccasion => !!occasion && typeof occasion === "object")
    .map((occasion) => ({
      shiftId: occasion.shiftId ?? null,
      className: occasion.className ?? null,
      students: Array.isArray(occasion.students) ? occasion.students.filter(Boolean) : [],
      startedAt: Number(occasion.startedAt) || null,
      endedAt: Number(occasion.endedAt) || null,
      drops: Number(occasion.drops) || 0,
      secondsLost: Number(occasion.secondsLost) || 0,
      longestSeconds: Number(occasion.longestSeconds) || 0,
      neverReturned: Number(occasion.neverReturned) || 0,
      spells: Array.isArray(occasion.spells) ? occasion.spells : [],
    }));
}

/** "Mon 14 Sep, 9:00 am", in the reader's own locale and time zone. */
export function formatOccasionDate(startedAt: number | null, locale?: string): string {
  if (!startedAt) return "";
  return new Date(startedAt).toLocaleString(locale, {
    weekday: "short", day: "numeric", month: "short",
    hour: "numeric", minute: "2-digit",
  });
}

/** "9:00 am – 10:00 am", the hours a class was meant to run. */
export function formatClassWindow(
  startedAt: number | null,
  endedAt: number | null,
  locale?: string,
): string {
  if (!endedAt) return "";
  const from = formatSpellTime(startedAt ?? endedAt, locale);
  const to = formatSpellTime(endedAt, locale);
  return from && to ? `${from} – ${to}` : "";
}

/** "9:14 am", the moment a drop began. */
export function formatSpellTime(at: number | null, locale?: string): string {
  if (!at) return "";
  return new Date(at).toLocaleTimeString(locale, { hour: "numeric", minute: "2-digit" });
}

/**
 * Who a class was with, as a reader would say it.
 *
 * Returns an empty string when the class has no students recorded, so a caller
 * can leave the line out rather than print an empty label.
 */
export function describeStudents(students: string[]): string {
  const names = students.filter(Boolean);
  if (names.length === 0) return "";
  if (names.length <= 2) return names.join(" and ");
  return `${names.slice(0, 2).join(", ")} and ${names.length - 2} more`;
}
