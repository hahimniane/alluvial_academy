/** Rules for teachers handing a class to another teacher. */

export type TradableShift = {
  isPublished: boolean;
  status: string;
  start: Date | null;
  teacherId?: string;
};

/** A class can be offered once, and only before it starts. */
export function canOfferShift(shift: TradableShift, now = new Date()) {
  return !shift.isPublished && shift.status === "scheduled" && Boolean(shift.start && shift.start > now);
}

/** An offered class another teacher can still claim. */
export function canClaimShift(shift: TradableShift, uid: string, now = new Date()) {
  return shift.isPublished && shift.status === "scheduled" && shift.teacherId !== uid && Boolean(shift.start && shift.start > now);
}

/** An offer can be taken back while the class is still offered and has not started. */
export function canWithdrawOffer(shift: TradableShift, now = new Date()) {
  return shift.isPublished && shift.status === "scheduled" && Boolean(shift.start && shift.start > now);
}

/**
 * A leadership duty (or meeting) rather than a class that is taught. Only a
 * leader may take one, so the teacher site never lists them as available.
 * A shift with no category is a class.
 */
export function isLeadershipDuty(category: unknown) {
  const value = typeof category === "string" ? category.trim().toLowerCase() : "";
  return value !== "" && value !== "teaching";
}

// ---------------------------------------------------------------------------
// Offering several days of the same class
// ---------------------------------------------------------------------------

/** How far ahead a teacher can give days of a series away. */
export const OFFER_WINDOW_DAYS = 30;
/** The most classes the server accepts in one offer. */
export const MAX_OFFER_SHIFTS = 60;

/** A class as the offer flow sees it. `seriesId` is the template it was generated from. */
export type SeriesShift = TradableShift & { id: string; seriesId: string; end?: Date | null };

/** The series a class belongs to: the template that generated it. Empty for a one-off class. */
export function seriesIdOf(data: Record<string, unknown>) {
  const value = data.template_id ?? data.templateId;
  return typeof value === "string" ? value.trim() : "";
}

/** One day of a series in the offer list. An "offered" day is already up for grabs. */
export type OfferDay = { id: string; start: Date; end: Date | null; state: "open" | "offered" };

/**
 * The days a teacher can give away from the class they opened: that class,
 * plus the upcoming scheduled classes of the same series over the next
 * `windowDays`, in date order. A one-off class yields only itself.
 */
export function seriesOfferDays(opened: SeriesShift, shifts: SeriesShift[], now = new Date(), windowDays = OFFER_WINDOW_DAYS): OfferDay[] {
  const until = now.getTime() + windowDays * 24 * 60 * 60 * 1000;
  const byId = new Map<string, SeriesShift>();
  if (opened.seriesId) {
    for (const shift of shifts) {
      if (shift.seriesId !== opened.seriesId) continue;
      if (opened.teacherId && shift.teacherId && shift.teacherId !== opened.teacherId) continue;
      if (shift.status !== "scheduled" || !shift.start) continue;
      if (shift.start <= now || shift.start.getTime() > until) continue;
      byId.set(shift.id, shift);
    }
  }
  // What was just loaded is fresher than the class the dialog was opened from.
  if (!byId.has(opened.id) && opened.start) byId.set(opened.id, opened);
  return [...byId.values()]
    .sort((a, b) => a.start!.getTime() - b.start!.getTime())
    .map((shift) => ({ id: shift.id, start: shift.start!, end: shift.end ?? null, state: shift.isPublished ? "offered" : "open" }));
}

export type OfferQuickPick = { kind: "only" | "next" | "week"; label: string; vars?: Record<string, string | number>; ids: string[] };

function startOfWeek(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() - date.getDay());
}

/**
 * Shortcuts for ticking days: the opened class alone, it and the classes right
 * after it (three in all), and every class in its Sunday-to-Saturday week.
 * Days already offered are never part of a pick, and a shortcut that would tick
 * the same days as an earlier one is left out. Labels are English source text;
 * callers translate them.
 */
export function offerQuickPicks(days: OfferDay[], openedId: string): OfferQuickPick[] {
  const open = days.filter((day) => day.state === "open");
  const opened = open.find((day) => day.id === openedId);
  if (!opened || open.length < 2) return [];
  const next = open.filter((day) => day.start >= opened.start).slice(0, 3).map((day) => day.id);
  const weekStart = startOfWeek(opened.start);
  const weekEnd = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + 7);
  const week = open.filter((day) => day.start >= weekStart && day.start < weekEnd).map((day) => day.id);
  const picks: OfferQuickPick[] = [
    { kind: "only", label: "Only this class", ids: [opened.id] },
    { kind: "next", label: "Next {count}", vars: { count: next.length }, ids: next },
    { kind: "week", label: "This week", ids: week },
  ];
  const seen = new Set<string>();
  return picks.filter((pick) => {
    const key = [...pick.ids].sort().join("|");
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/** Whether a set of ticked days is exactly what a shortcut would tick. */
export function sameSelection(a: string[], b: string[]) {
  return a.length === b.length && a.every((id) => b.includes(id));
}

/** The ids to send: only days that are still open, in list order, capped at the server's limit. */
export function offerSelection(days: OfferDay[], ticked: string[]) {
  return days.filter((day) => day.state === "open" && ticked.includes(day.id)).map((day) => day.id).slice(0, MAX_OFFER_SHIFTS);
}

export type OfferResult = { shiftId: string; ok: boolean; reason?: string };
export type OfferFailure = { shiftId: string; text: string };

/**
 * The server's reason for refusing one class, in the teacher's words.
 * English source text; callers translate it.
 */
export function offerFailureText(reason: unknown, offered = true) {
  const value = typeof reason === "string" ? reason.trim().toLowerCase() : "";
  if (value === "this class has already started") return "This class has already started.";
  if (value === "only a class that has not started can be offered") return "This class is no longer scheduled.";
  if (value === "shift not found") return "This class could not be found.";
  if (value === "this is not your class") return "This class belongs to another teacher.";
  return offered ? "This class could not be offered." : "This offer could not be taken back.";
}

/**
 * Sort the server's per-class answers into what went through and what did not.
 * A class the server said nothing about counts as not done.
 */
export function offerOutcome(shiftIds: string[], results: unknown, offered = true): { okIds: string[]; failures: OfferFailure[] } {
  const byId = new Map<string, OfferResult>();
  if (Array.isArray(results)) {
    for (const entry of results) {
      if (entry && typeof entry === "object" && typeof (entry as OfferResult).shiftId === "string") byId.set((entry as OfferResult).shiftId, entry as OfferResult);
    }
  }
  const okIds: string[] = [];
  const failures: OfferFailure[] = [];
  for (const shiftId of shiftIds) {
    const result = byId.get(shiftId);
    if (result?.ok === true) okIds.push(shiftId);
    else failures.push({ shiftId, text: offerFailureText(result?.reason, offered) });
  }
  return { okIds, failures };
}

/** The note on the admin report: the teacher's own words, plus how many classes when it is more than one. */
export function offerReportNotes(notes: string, offeredCount: number) {
  const own = notes.trim();
  if (offeredCount <= 1) return own;
  const line = `Offered ${offeredCount} classes of this series.`;
  return own ? `${own}\n${line}` : line;
}

// ---------------------------------------------------------------------------
// The record of trades
// ---------------------------------------------------------------------------

export type TradeAction = "offered" | "withdrawn" | "claimed" | "assigned";

export type ShiftTrade = {
  id: string;
  shiftId: string;
  action: TradeAction;
  actorId: string;
  fromTeacherId: string;
  fromTeacherName: string;
  toTeacherId: string;
  toTeacherName: string;
  shiftName: string;
  shiftCategory: string;
  shiftStart: Date | null;
  shiftEnd: Date | null;
  createdAt: Date | null;
};

const text = (value: unknown) => (typeof value === "string" ? value.trim() : "");

function toDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (value && typeof value === "object" && typeof (value as { toDate?: unknown }).toDate === "function") {
    const date = (value as { toDate: () => unknown }).toDate();
    return date instanceof Date ? date : null;
  }
  return null;
}

/** Read one shift_trades row. Null when the action is not one this page knows. */
export function normalizeTrade(id: string, data: Record<string, unknown>): ShiftTrade | null {
  const action = text(data.action);
  if (action !== "offered" && action !== "withdrawn" && action !== "claimed" && action !== "assigned") return null;
  return {
    id,
    shiftId: text(data.shift_id),
    action,
    actorId: text(data.actor_id),
    fromTeacherId: text(data.from_teacher_id),
    fromTeacherName: text(data.from_teacher_name),
    toTeacherId: text(data.to_teacher_id),
    toTeacherName: text(data.to_teacher_name),
    shiftName: text(data.shift_name),
    shiftCategory: text(data.shift_category),
    shiftStart: toDate(data.shift_start),
    shiftEnd: toDate(data.shift_end),
    createdAt: toDate(data.created_at),
  };
}

/** How many trades the page shows. */
export const MAX_TRADES_SHOWN = 30;

/** Join the "from me" and "to me" rows: one of each trade, newest first. */
export function mergeTrades(lists: ShiftTrade[][], max = MAX_TRADES_SHOWN): ShiftTrade[] {
  const byId = new Map<string, ShiftTrade>();
  for (const list of lists) for (const trade of list) byId.set(trade.id, trade);
  return [...byId.values()].sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0)).slice(0, max);
}

/**
 * What to call the class in a sentence. Generated names read
 * "Teacher - Subject - Students"; the teacher is already named by the sentence
 * (and is out of date once the class changes hands), so it is dropped.
 */
export function tradeClassLabel(trade: Pick<ShiftTrade, "shiftName" | "fromTeacherName" | "toTeacherName">) {
  const parts = trade.shiftName.split(" - ").map((part) => part.trim()).filter(Boolean);
  if (parts.length > 1) {
    const lead = parts[0].toLowerCase();
    const teachers = [trade.fromTeacherName, trade.toTeacherName].map((name) => name.toLowerCase()).filter(Boolean);
    if (teachers.includes(lead)) return parts.slice(1).join(" – ");
  }
  return trade.shiftName;
}

/**
 * One trade as a plain sentence from the reader's side. `text` is English
 * source text with {class} and {name} placeholders; callers translate it and
 * fill them in. `vars.class` comes back empty when the row carries no class
 * name, for the caller to fill with its own word for "a class".
 */
export function tradeSentence(trade: ShiftTrade, uid: string): { text: string; vars: { class: string; name: string } } {
  const klass = tradeClassLabel(trade);
  const mine = trade.fromTeacherId === uid;
  const byMe = trade.actorId === uid;
  const sentence = (source: string, name = "") => ({ text: source, vars: { class: klass, name } });
  switch (trade.action) {
    case "offered":
      return byMe ? sentence("You offered {class}") : sentence("An admin offered {class} for you");
    case "withdrawn":
      return byMe ? sentence("You took your offer of {class} back") : sentence("An admin took the offer of {class} back");
    case "claimed":
      if (mine) return trade.toTeacherName ? sentence("{name} took {class} from you", trade.toTeacherName) : sentence("Another teacher took {class} from you");
      return trade.fromTeacherName ? sentence("You took {class} from {name}", trade.fromTeacherName) : sentence("You took {class}");
    case "assigned":
      if (mine) return trade.toTeacherName ? sentence("An admin gave {class} to {name}", trade.toTeacherName) : sentence("An admin gave {class} to another teacher");
      return trade.fromTeacherName ? sentence("An admin gave you {class} from {name}", trade.fromTeacherName) : sentence("An admin gave you {class}");
  }
}
