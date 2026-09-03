/**
 * The time-slot rules the broadcast dialog enforces before an enrollment is
 * shown to teachers.
 *
 * These live apart from the dialog because they are the part that can be wrong
 * in a way nobody notices: two overlapping slots reach teachers as a schedule
 * that cannot be taught, and the family finds out when the match falls through.
 */

/** "4:00 PM" -> minutes from midnight, or null when unparseable. */
export const parseSlotTime = (value: string): number | null => {
  const match = value.trim().match(/^(\d{1,2}):(\d{2})\s*([AaPp])\.?[Mm]\.?$/);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 1 || hour > 12 || minute > 59) return null;
  const pm = match[3].toLowerCase() === "p";
  const base = hour % 12;
  return (pm ? base + 12 : base) * 60 + minute;
};

export type SlotRange = { start: number; end: number };

/** "4:00 PM - 5:00 PM" -> {start, end}. */
export const parseSlot = (slot: string): SlotRange | null => {
  const parts = slot.split(/\s*-\s*/);
  if (parts.length !== 2) return null;
  const start = parseSlotTime(parts[0]);
  const end = parseSlotTime(parts[1]);
  if (start === null || end === null) return null;
  return { start, end };
};

export const formatSlotTime = (minutes: number): string => {
  const total = ((minutes % 1440) + 1440) % 1440;
  const hour24 = Math.floor(total / 60);
  const minute = total % 60;
  const suffix = hour24 < 12 ? "AM" : "PM";
  const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;
  return `${hour12}:${String(minute).padStart(2, "0")} ${suffix}`;
};

export const formatSlot = (start: number, end: number): string =>
  `${formatSlotTime(start)} - ${formatSlotTime(end)}`;

/**
 * Why a slot cannot be added, or null when it can.
 *
 * Overlap is checked against the slots already added rather than only against
 * exact duplicates: 4–6 and 5–7 are two different strings describing one
 * impossible schedule.
 */
export const slotProblem = (
  startMinutes: number | null,
  endMinutes: number | null,
  existing: string[],
): string | null => {
  if (startMinutes === null || endMinutes === null) {
    return "Pick start and end time to add a slot.";
  }
  if (endMinutes <= startMinutes) return "End time must be after start time.";

  const candidate = formatSlot(startMinutes, endMinutes);
  if (existing.includes(candidate)) return "This time slot already exists.";

  for (const slot of existing) {
    const parsed = parseSlot(slot);
    // A slot we cannot read is left alone rather than treated as free time.
    if (!parsed) continue;
    if (startMinutes < parsed.end && parsed.start < endMinutes) {
      return `This overlaps with "${slot}". Pick a non-overlapping time.`;
    }
  }
  return null;
};

/** Slots in start order, so teachers read a day top to bottom. */
export const sortSlots = (slots: string[]): string[] =>
  [...slots].sort((a, b) => {
    const left = parseSlot(a);
    const right = parseSlot(b);
    if (!left || !right) return 0;
    return left.start - right.start;
  });

/** What blocks a broadcast, or null when it is ready to send. */
export const broadcastProblem = (days: string[], slots: string[]): string | null => {
  if (days.length === 0) return "Select at least one day before broadcasting.";
  if (slots.length === 0) return "Add at least one time slot before broadcasting.";
  return null;
};
