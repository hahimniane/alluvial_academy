/**
 * The admin side of shift trading: which classes can be offered, the rows of
 * the "Offered classes" panel and the wording of the trade history. Kept free
 * of Firestore so every rule here is unit-tested.
 */

import { canOfferShift } from "./shiftTrading.ts";

export type TradeAction = "offered" | "withdrawn" | "claimed" | "assigned";

const TRADE_ACTIONS = new Set<string>(["offered", "withdrawn", "claimed", "assigned"]);

const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");

/** Firestore Timestamps arrive with a toDate(); tests pass plain Dates. */
function toDate(v: unknown): Date | null {
  if (v instanceof Date) return Number.isNaN(v.getTime()) ? null : v;
  if (v && typeof v === "object" && typeof (v as { toDate?: unknown }).toDate === "function") {
    const date = (v as { toDate: () => unknown }).toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }
  return null;
}

/* ------------------------------- eligibility ------------------------------ */

/** A leadership duty or meeting, as opposed to a class that is taught. */
export function isDuty(category: string | null | undefined): boolean {
  const normalized = (category ?? "").trim().toLowerCase();
  return normalized !== "" && normalized !== "teaching";
}

export type OfferableShift = {
  isPublished: boolean;
  status: string;
  start: Date | null;
};

const isScheduled = (status: string) => status.trim().toLowerCase() === "scheduled";

/** An offer somebody can still take: offered, scheduled and not started. */
export function isOfferOpen(shift: OfferableShift, now = new Date()): boolean {
  return shift.isPublished && isScheduled(shift.status) && Boolean(shift.start && shift.start > now);
}

/** An admin may offer any class that is scheduled, upcoming and not offered. */
export function canAdminOffer(shift: OfferableShift, now = new Date()): boolean {
  return canOfferShift({ ...shift, status: shift.status.trim().toLowerCase() }, now);
}

export function offerActionLabel(category: string | null | undefined): string {
  return isDuty(category) ? "Offer to other leaders" : "Offer to other teachers";
}

export type AssignCandidate = { id: string; group: "teacher" | "leader" };

/**
 * Who an offered class can be given to. A class goes to any teacher or admin;
 * a leadership duty only to a leader — an admin, an admin-teacher, or a
 * teacher who already holds a duty. Never its current teacher.
 */
export function assignCandidates<T extends AssignCandidate>(
  staff: T[],
  offer: { teacherId: string; duty: boolean },
  dutyHolderIds: ReadonlySet<string>,
): T[] {
  return staff.filter(
    (member) =>
      member.id !== offer.teacherId && (!offer.duty || member.group === "leader" || dutyHolderIds.has(member.id)),
  );
}

/* ------------------------------- open offers ------------------------------ */

export type OpenOffer = {
  id: string;
  /** The class name without its leading teacher name. */
  name: string;
  start: Date;
  end: Date;
  teacherId: string;
  teacherName: string;
  duty: boolean;
  /** Who offered it: the teacher, or the admin who offered it for them. */
  offeredById: string;
  offeredAt: Date | null;
};

/** "Aisha Bah - Quran - Ali" reads as "Quran - Ali" beside the teacher's name. */
export function classLabel(name: string, teacherName: string): string {
  const full = name.trim();
  const teacher = teacherName.trim();
  if (teacher && full.toLowerCase().startsWith(`${teacher.toLowerCase()} - `)) {
    const rest = full.slice(teacher.length + 3).trim();
    if (rest) return rest;
  }
  return full;
}

/** Every class still on offer, soonest first. */
export function buildOpenOffers(docs: { id: string; data: Record<string, unknown> }[], now = new Date()): OpenOffer[] {
  const offers: OpenOffer[] = [];
  for (const { id, data } of docs) {
    const start = toDate(data.shift_start);
    const end = toDate(data.shift_end);
    if (!start || !end) continue;
    if (!isOfferOpen({ isPublished: data.is_published === true, status: str(data.status) || "scheduled", start }, now)) continue;
    const teacherId = str(data.teacher_id);
    const teacherName = str(data.teacher_name) || str(data.original_teacher_name) || "Unassigned";
    const duty = isDuty(str(data.shift_category));
    const rawName =
      str(data.custom_name) || str(data.auto_generated_name) || str(data.subject_display_name) || str(data.subject);
    offers.push({
      id,
      name: classLabel(rawName, teacherName) || (duty ? "Duty" : "Class"),
      start,
      end,
      teacherId,
      teacherName,
      duty,
      offeredById: str(data.published_by) || teacherId,
      offeredAt: toDate(data.published_at),
    });
  }
  return offers.sort((a, b) => a.start.getTime() - b.start.getTime() || a.id.localeCompare(b.id));
}

/** The teacher's own name, or the admin who offered the class for them. */
export function offeredByLabel(offer: OpenOffer, nameById: ReadonlyMap<string, string>): string {
  if (!offer.offeredById || offer.offeredById === offer.teacherId) return offer.teacherName;
  const name = nameById.get(offer.offeredById);
  return name ? `Admin ${name}` : "An admin";
}

/* --------------------------------- history -------------------------------- */

export type TradeEvent = {
  id: string;
  shiftId: string;
  action: TradeAction;
  actorId: string;
  fromTeacherId: string;
  fromTeacherName: string;
  toTeacherId: string;
  toTeacherName: string;
  shiftName: string;
  duty: boolean;
  shiftStart: Date | null;
  createdAt: Date | null;
};

/** One shift_trades row; null when its action is not one this screen knows. */
export function parseTradeEvent(id: string, data: Record<string, unknown>): TradeEvent | null {
  const action = str(data.action);
  if (!TRADE_ACTIONS.has(action)) return null;
  return {
    id,
    shiftId: str(data.shift_id),
    action: action as TradeAction,
    actorId: str(data.actor_id),
    fromTeacherId: str(data.from_teacher_id),
    fromTeacherName: str(data.from_teacher_name),
    toTeacherId: str(data.to_teacher_id),
    toTeacherName: str(data.to_teacher_name),
    shiftName: str(data.shift_name),
    duty: isDuty(str(data.shift_category)),
    shiftStart: toDate(data.shift_start),
    createdAt: toDate(data.created_at),
  };
}

/**
 * The people whose names the rows do not carry: an admin who offered, took
 * back or assigned a class is known only by id.
 */
export function idsNeedingNames(
  offers: OpenOffer[],
  events: TradeEvent[],
  known: ReadonlyMap<string, string>,
): string[] {
  const ids = new Set<string>();
  for (const offer of offers) {
    if (offer.offeredById && offer.offeredById !== offer.teacherId) ids.add(offer.offeredById);
  }
  for (const event of events) {
    if (event.actorId && event.actorId !== event.fromTeacherId && event.actorId !== event.toTeacherId) {
      ids.add(event.actorId);
    }
  }
  return [...ids].filter((id) => !known.has(id)).sort();
}

/** One history row as a plain sentence. */
export function tradeSentence(
  event: TradeEvent,
  options: { nameById: ReadonlyMap<string, string>; formatWhen: (date: Date) => string },
): string {
  const from = event.fromTeacherName;
  const to = event.toTeacherName;
  const kind = event.duty ? "duty" : "class";
  const when = event.shiftStart ? ` – ${options.formatWhen(event.shiftStart)}` : "";
  const named = classLabel(event.shiftName, from);
  const what = `${named || `a ${kind}`}${when}`;

  const actorIsFrom = !event.actorId || event.actorId === event.fromTeacherId;
  const actorIsTo = !actorIsFrom && event.actorId === event.toTeacherId;
  const adminName = options.nameById.get(event.actorId);
  const actor = actorIsFrom
    ? from || "A teacher"
    : actorIsTo
      ? to || "A teacher"
      : adminName
        ? `Admin ${adminName}`
        : "An admin";
  // An admin acts on somebody else's class, so the sentence says whose it is.
  const theirs = !actorIsFrom && from ? `${from}'s ${kind}${named ? ` ${named}` : ""}${when}` : what;

  switch (event.action) {
    case "offered":
      return `${actor} offered ${theirs}`;
    case "withdrawn":
      return `${actor} took back the offer of ${theirs}`;
    case "claimed":
      return `${to || "Another teacher"} claimed ${what}${from ? ` from ${from}` : ""}`;
    case "assigned":
      return `${actor} assigned ${what} to ${actorIsTo ? "themselves" : to || "another teacher"}${from ? ` (from ${from})` : ""}`;
  }
}

/** "5 minutes ago" — how long since something happened. */
export function timeAgo(date: Date | null, now = new Date()): string {
  if (!date) return "";
  const seconds = Math.max(0, Math.floor((now.getTime() - date.getTime()) / 1000));
  if (seconds < 60) return "just now";
  const plural = (count: number, unit: string) => `${count} ${unit}${count === 1 ? "" : "s"} ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return plural(minutes, "minute");
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return plural(hours, "hour");
  return plural(Math.floor(hours / 24), "day");
}

/* --------------------------------- errors --------------------------------- */

/**
 * What to show when a trade callable refuses. The server explains itself in
 * plain words (a clash with the teacher's own class, a duty only leaders can
 * take), so its message is shown as is; a bare status code is not.
 */
export function tradeErrorMessage(error: unknown, fallback: string): string {
  const code = typeof error === "object" && error && "code" in error ? String((error as { code: unknown }).code) : "";
  const message =
    typeof error === "object" && error && "message" in error ? String((error as { message: unknown }).message ?? "").trim() : "";
  if (code.endsWith("unauthenticated")) return "Please sign in again, then try again.";
  if (/no longer available for claiming/i.test(message)) return "This class is no longer on offer.";
  const explained =
    code.endsWith("failed-precondition") ||
    code.endsWith("permission-denied") ||
    code.endsWith("already-exists") ||
    code.endsWith("not-found") ||
    code.endsWith("invalid-argument");
  // "INTERNAL", "NOT_FOUND", "internal": a status, not an explanation.
  const bareStatus = !message || /^[A-Za-z]+([_-][A-Za-z]+)*$/.test(message);
  return explained && !bareStatus ? message : fallback;
}

/** Why setShiftOffers refused this class, or null when it went through. */
export function offerRefusal(result: unknown, shiftId: string, fallback: string): string | null {
  const data = (result ?? {}) as { success?: unknown; results?: unknown };
  const rows = Array.isArray(data.results) ? (data.results as { shiftId?: unknown; ok?: unknown; reason?: unknown }[]) : [];
  const row = rows.find((entry) => entry && entry.shiftId === shiftId);
  if (row) return row.ok === true ? null : str(row.reason) || fallback;
  return data.success === true ? null : fallback;
}
