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

export type PresenceReport = {
  uid: string;
  role: string | null;
  name: string | null;
  classes: number;
  classes_with_a_drop: number;
  counted: PresenceTally;
  by_cause?: Record<string, PresenceTally>;
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
