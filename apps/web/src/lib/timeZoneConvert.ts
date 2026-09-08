/**
 * Wall-clock conversion between IANA time zones, for the job board.
 *
 * Families give their availability in their own time zone. A teacher in
 * Conakry looking at a Bronx family's "10:00 AM - 11:00 AM" must be shown the
 * hour in their own day, or they accept a class they cannot teach. The Flutter
 * app does this with the `timezone` package (`_convertTimeSlot` in
 * `teacher_job_board_screen.dart`); this is the same conversion in the browser,
 * using `Intl` so no library is needed.
 *
 * Anything unparseable is returned untouched, exactly as the app does.
 */

/** How far `zone` is from UTC at that instant, in milliseconds. */
function zoneOffsetMs(instant: Date, zone: string): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: zone,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  })
    .formatToParts(instant)
    .filter((p) => p.type !== "literal");
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? "0");
  // "24" shows up at midnight in some locales' hourCycle; treat it as 0.
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour") % 24, get("minute"), get("second"));
  return asUtc - instant.getTime();
}

/** The instant at which `zone`'s wall clock reads the given date and time. */
export function instantForWallTime(
  y: number,
  m: number,
  d: number,
  hour: number,
  minute: number,
  zone: string,
): Date {
  const naive = Date.UTC(y, m - 1, d, hour, minute);
  let ts = naive;
  // Two passes settle the offset even across a DST boundary.
  for (let i = 0; i < 2; i += 1) ts = naive - zoneOffsetMs(new Date(ts), zone);
  return new Date(ts);
}

/** "10:00 AM" / "10:00" / "9:30 pm" → minutes past midnight, or null. */
export function parseTimeString(value: string): { hour: number; minute: number } | null {
  const text = String(value ?? "").trim();
  const m = text.match(/^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$/);
  if (!m) return null;
  let hour = Number(m[1]);
  const minute = Number(m[2] ?? "0");
  const meridiem = (m[3] ?? "").toLowerCase();
  if (Number.isNaN(hour) || Number.isNaN(minute) || minute > 59) return null;
  if (meridiem === "am") hour = hour === 12 ? 0 : hour;
  else if (meridiem === "pm") hour = hour === 12 ? 12 : hour + 12;
  if (hour > 23) return null;
  return { hour, minute };
}

const formatIn = (instant: Date, zone: string) =>
  new Intl.DateTimeFormat("en-US", { timeZone: zone, hour: "numeric", minute: "2-digit", hour12: true }).format(instant);

/**
 * "10:00 AM - 11:00 AM" read in `fromZone`, rewritten in `toZone`.
 * Returns the input unchanged when either zone is missing, they match, or the
 * slot is not a range this understands.
 */
export function convertTimeSlot(slot: string, fromZone: string, toZone: string): string {
  const text = String(slot ?? "").trim();
  if (!fromZone || !toZone || fromZone === toZone || !text) return text;
  const parts = text.split(/\s*[-–]\s*/);
  if (parts.length !== 2) return text;
  const start = parseTimeString(parts[0]);
  const end = parseTimeString(parts[1]);
  if (!start || !end) return text;
  try {
    const today = new Date();
    const y = today.getFullYear();
    const m = today.getMonth() + 1;
    const d = today.getDate();
    const startInstant = instantForWallTime(y, m, d, start.hour, start.minute, fromZone);
    const endInstant = instantForWallTime(y, m, d, end.hour, end.minute, fromZone);
    return `${formatIn(startInstant, toZone)} - ${formatIn(endInstant, toZone)}`;
  } catch {
    return text;
  }
}

/** Short label for a zone, e.g. "GMT", "EDT" — falls back to the zone name. */
export function zoneAbbreviation(zone: string, at: Date = new Date()): string {
  if (!zone) return "";
  try {
    const part = new Intl.DateTimeFormat("en-US", { timeZone: zone, timeZoneName: "short" })
      .formatToParts(at)
      .find((p) => p.type === "timeZoneName");
    return part?.value ?? zone;
  } catch {
    return zone;
  }
}
