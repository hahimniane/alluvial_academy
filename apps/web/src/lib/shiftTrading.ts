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
