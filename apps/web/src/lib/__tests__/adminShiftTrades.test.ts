import test from "node:test";
import assert from "node:assert/strict";
import {
  type OpenOffer,
  type TradeEvent,
  assignCandidates,
  buildOpenOffers,
  canAdminOffer,
  classLabel,
  idsNeedingNames,
  isDuty,
  isOfferOpen,
  offerActionLabel,
  offerRefusal,
  offeredByLabel,
  parseTradeEvent,
  timeAgo,
  tradeErrorMessage,
  tradeSentence,
} from "../adminShiftTrades.ts";

const now = new Date("2026-11-13T12:00:00Z");
const later = new Date("2026-11-16T20:00:00Z");
const laterEnd = new Date("2026-11-16T21:00:00Z");
const earlier = new Date("2026-11-12T12:00:00Z");
/** Stands in for a Firestore Timestamp. */
const ts = (date: Date) => ({ toDate: () => date });

/* ------------------------------- eligibility ------------------------------ */

test("anything that is not a teaching class is a leadership duty", () => {
  assert.equal(isDuty("teaching"), false);
  assert.equal(isDuty(""), false);
  assert.equal(isDuty(undefined), false);
  assert.equal(isDuty("leadership"), true);
  assert.equal(isDuty("Meeting"), true);
});

test("an admin can offer an upcoming scheduled class that is not offered", () => {
  assert.equal(canAdminOffer({ isPublished: false, status: "scheduled", start: later }, now), true);
  assert.equal(canAdminOffer({ isPublished: false, status: "Scheduled", start: later }, now), true);
  assert.equal(canAdminOffer({ isPublished: true, status: "scheduled", start: later }, now), false);
  assert.equal(canAdminOffer({ isPublished: false, status: "scheduled", start: earlier }, now), false);
  assert.equal(canAdminOffer({ isPublished: false, status: "completed", start: later }, now), false);
});

test("an offer is open only while the class is offered, scheduled and upcoming", () => {
  assert.equal(isOfferOpen({ isPublished: true, status: "scheduled", start: later }, now), true);
  assert.equal(isOfferOpen({ isPublished: false, status: "scheduled", start: later }, now), false);
  // A missed class keeps its flag; it is not on offer any more.
  assert.equal(isOfferOpen({ isPublished: true, status: "missed", start: earlier }, now), false);
  assert.equal(isOfferOpen({ isPublished: true, status: "scheduled", start: earlier }, now), false);
});

test("a duty is offered to leaders, a class to teachers", () => {
  assert.equal(offerActionLabel("teaching"), "Offer to other teachers");
  assert.equal(offerActionLabel(null), "Offer to other teachers");
  assert.equal(offerActionLabel("leadership"), "Offer to other leaders");
});

test("a class can go to anyone on staff but its current teacher", () => {
  const staff = [
    { id: "t1", group: "teacher" as const },
    { id: "t2", group: "teacher" as const },
    { id: "a1", group: "leader" as const },
  ];
  const picked = assignCandidates(staff, { teacherId: "t1", duty: false }, new Set());
  assert.deepEqual(picked.map((m) => m.id), ["t2", "a1"]);
});

test("a duty goes only to leaders and to teachers who already hold a duty", () => {
  const staff = [
    { id: "t1", group: "teacher" as const },
    { id: "t2", group: "teacher" as const },
    { id: "a1", group: "leader" as const },
    { id: "a2", group: "leader" as const },
  ];
  const picked = assignCandidates(staff, { teacherId: "a1", duty: true }, new Set(["t2"]));
  assert.deepEqual(picked.map((m) => m.id), ["t2", "a2"]);
});

/* ------------------------------- open offers ------------------------------ */

test("the class label drops a leading teacher name and nothing else", () => {
  assert.equal(classLabel("Aisha Bah - Quran - Ali", "Aisha Bah"), "Quran - Ali");
  assert.equal(classLabel("aisha bah - Quran", "Aisha Bah"), "Quran");
  assert.equal(classLabel("Friday revision", "Aisha Bah"), "Friday revision");
  assert.equal(classLabel("Aisha Bah - ", "Aisha Bah"), "Aisha Bah -");
  assert.equal(classLabel("Quran", ""), "Quran");
});

const offeredDoc = (overrides: Record<string, unknown> = {}) => ({
  is_published: true,
  status: "scheduled",
  shift_start: ts(later),
  shift_end: ts(laterEnd),
  teacher_id: "t1",
  teacher_name: "Aisha Bah",
  auto_generated_name: "Aisha Bah - Quran - Ali",
  published_by: "t1",
  published_at: ts(earlier),
  ...overrides,
});

test("open offers keep only scheduled upcoming classes, soonest first", () => {
  const sooner = new Date("2026-11-14T10:00:00Z");
  const offers = buildOpenOffers(
    [
      { id: "late", data: offeredDoc() },
      { id: "missed", data: offeredDoc({ status: "missed", shift_start: ts(earlier) }) },
      { id: "started", data: offeredDoc({ shift_start: ts(earlier) }) },
      { id: "cancelled", data: offeredDoc({ status: "cancelled" }) },
      { id: "notOffered", data: offeredDoc({ is_published: false }) },
      { id: "noTimes", data: offeredDoc({ shift_start: null }) },
      { id: "soon", data: offeredDoc({ shift_start: ts(sooner), shift_end: ts(later) }) },
    ],
    now,
  );
  assert.deepEqual(offers.map((offer) => offer.id), ["soon", "late"]);
});

test("an open offer carries the class, its teacher, who offered it and when", () => {
  const [offer] = buildOpenOffers([{ id: "s1", data: offeredDoc({ published_by: "admin1" }) }], now);
  assert.deepEqual(offer, {
    id: "s1",
    name: "Quran - Ali",
    start: later,
    end: laterEnd,
    teacherId: "t1",
    teacherName: "Aisha Bah",
    duty: false,
    offeredById: "admin1",
    offeredAt: earlier,
  });
});

test("an offer with no offerer on record counts as the teacher's own, and a duty is tagged", () => {
  const [offer] = buildOpenOffers(
    [
      {
        id: "d1",
        data: offeredDoc({
          published_by: null,
          published_at: null,
          shift_category: "leadership",
          custom_name: "Weekly coordination",
        }),
      },
    ],
    now,
  );
  assert.equal(offer.offeredById, "t1");
  assert.equal(offer.offeredAt, null);
  assert.equal(offer.duty, true);
  assert.equal(offer.name, "Weekly coordination");
});

const offer = (overrides: Partial<OpenOffer> = {}): OpenOffer => ({
  id: "s1",
  name: "Quran - Ali",
  start: later,
  end: laterEnd,
  teacherId: "t1",
  teacherName: "Aisha Bah",
  duty: false,
  offeredById: "t1",
  offeredAt: earlier,
  ...overrides,
});

test("offered-by names the teacher, or the admin who offered it for them", () => {
  const names = new Map([["admin1", "Chernor Diallo"]]);
  assert.equal(offeredByLabel(offer(), names), "Aisha Bah");
  assert.equal(offeredByLabel(offer({ offeredById: "admin1" }), names), "Admin Chernor Diallo");
  assert.equal(offeredByLabel(offer({ offeredById: "ghost" }), names), "An admin");
  assert.equal(offeredByLabel(offer({ offeredById: "blank" }), new Map([["blank", ""]])), "An admin");
});

/* --------------------------------- history -------------------------------- */

const tradeDoc = (overrides: Record<string, unknown> = {}) => ({
  shift_id: "s1",
  action: "offered",
  actor_id: "t1",
  from_teacher_id: "t1",
  from_teacher_name: "Aisha Bah",
  to_teacher_id: null,
  to_teacher_name: "",
  shift_name: "Aisha Bah - Quran - Ali",
  shift_category: "teaching",
  shift_start: ts(later),
  shift_end: ts(laterEnd),
  created_at: ts(earlier),
  ...overrides,
});

const event = (overrides: Record<string, unknown> = {}): TradeEvent => {
  const parsed = parseTradeEvent("e1", tradeDoc(overrides));
  assert.ok(parsed);
  return parsed;
};

const wording = { nameById: new Map([["admin1", "Chernor Diallo"]]), formatWhen: () => "Mon, Nov 16, 3:00 PM" };

test("a trade row is read from its document; an unknown action is skipped", () => {
  assert.deepEqual(parseTradeEvent("e1", tradeDoc()), {
    id: "e1",
    shiftId: "s1",
    action: "offered",
    actorId: "t1",
    fromTeacherId: "t1",
    fromTeacherName: "Aisha Bah",
    toTeacherId: "",
    toTeacherName: "",
    shiftName: "Aisha Bah - Quran - Ali",
    duty: false,
    shiftStart: later,
    createdAt: earlier,
  });
  assert.equal(parseTradeEvent("e2", tradeDoc({ action: "swapped" })), null);
  assert.equal(parseTradeEvent("e3", {}), null);
});

test("a teacher offering their own class", () => {
  assert.equal(tradeSentence(event(), wording), "Aisha Bah offered Quran - Ali – Mon, Nov 16, 3:00 PM");
});

test("an admin offering a teacher's class says whose class it is", () => {
  assert.equal(
    tradeSentence(event({ actor_id: "admin1" }), wording),
    "Admin Chernor Diallo offered Aisha Bah's class Quran - Ali – Mon, Nov 16, 3:00 PM",
  );
  assert.equal(
    tradeSentence(event({ actor_id: "admin1", shift_category: "leadership", shift_name: "Weekly coordination" }), wording),
    "Admin Chernor Diallo offered Aisha Bah's duty Weekly coordination – Mon, Nov 16, 3:00 PM",
  );
});

test("a teacher claiming an offered class", () => {
  assert.equal(
    tradeSentence(event({ action: "claimed", actor_id: "t2", to_teacher_id: "t2", to_teacher_name: "Bilal Sow" }), wording),
    "Bilal Sow claimed Quran - Ali – Mon, Nov 16, 3:00 PM from Aisha Bah",
  );
});

test("an admin assigning an offered class", () => {
  assert.equal(
    tradeSentence(event({ action: "assigned", actor_id: "admin1", to_teacher_id: "t2", to_teacher_name: "Bilal Sow" }), wording),
    "Admin Chernor Diallo assigned Quran - Ali – Mon, Nov 16, 3:00 PM to Bilal Sow (from Aisha Bah)",
  );
  // An admin who teaches can give the class to themselves.
  assert.equal(
    tradeSentence(event({ action: "assigned", actor_id: "t2", to_teacher_id: "t2", to_teacher_name: "Bilal Sow" }), wording),
    "Bilal Sow assigned Quran - Ali – Mon, Nov 16, 3:00 PM to themselves (from Aisha Bah)",
  );
});

test("an offer taken back by the teacher or by an admin", () => {
  assert.equal(
    tradeSentence(event({ action: "withdrawn" }), wording),
    "Aisha Bah took back the offer of Quran - Ali – Mon, Nov 16, 3:00 PM",
  );
  assert.equal(
    tradeSentence(event({ action: "withdrawn", actor_id: "admin1" }), wording),
    "Admin Chernor Diallo took back the offer of Aisha Bah's class Quran - Ali – Mon, Nov 16, 3:00 PM",
  );
});

test("a row with gaps still reads as a sentence", () => {
  assert.equal(
    tradeSentence(event({ actor_id: "ghost", shift_start: null, shift_name: "" }), wording),
    "An admin offered Aisha Bah's class",
  );
  assert.equal(
    tradeSentence(event({ actor_id: null, from_teacher_id: null, from_teacher_name: "", shift_start: null }), wording),
    "A teacher offered Aisha Bah - Quran - Ali",
  );
  assert.equal(
    tradeSentence(event({ action: "claimed", actor_id: "t2", to_teacher_id: "t2", from_teacher_name: "" }), wording),
    "Another teacher claimed Aisha Bah - Quran - Ali – Mon, Nov 16, 3:00 PM",
  );
  assert.equal(
    tradeSentence(event({ action: "assigned", actor_id: "admin1", shift_name: "" }), wording),
    "Admin Chernor Diallo assigned a class – Mon, Nov 16, 3:00 PM to another teacher (from Aisha Bah)",
  );
});

test("only people the rows know by id alone need a name looked up", () => {
  const events = [
    event(),
    event({ action: "assigned", actor_id: "admin2", to_teacher_id: "t2" }),
    event({ action: "withdrawn", actor_id: "admin1" }),
    event({ action: "claimed", actor_id: "t2", to_teacher_id: "t2" }),
  ];
  const offers = [offer(), offer({ id: "s2", offeredById: "admin3" }), offer({ id: "s3", offeredById: "admin2" })];
  assert.deepEqual(idsNeedingNames(offers, events, new Map()), ["admin1", "admin2", "admin3"]);
  assert.deepEqual(idsNeedingNames(offers, events, new Map([["admin1", "Chernor Diallo"], ["admin3", ""]])), ["admin2"]);
  assert.deepEqual(idsNeedingNames([offer()], [event()], new Map()), []);
});

test("how long ago, in plain words", () => {
  const ago = (ms: number) => timeAgo(new Date(now.getTime() - ms), now);
  assert.equal(ago(20e3), "just now");
  assert.equal(ago(60e3), "1 minute ago");
  assert.equal(ago(45 * 60e3), "45 minutes ago");
  assert.equal(ago(60 * 60e3), "1 hour ago");
  assert.equal(ago(23 * 3600e3), "23 hours ago");
  assert.equal(ago(24 * 3600e3), "1 day ago");
  assert.equal(ago(9 * 24 * 3600e3), "9 days ago");
  // A clock a little ahead of the server never reads as the future.
  assert.equal(ago(-5e3), "just now");
  assert.equal(timeAgo(null, now), "");
});

/* --------------------------------- errors --------------------------------- */

test("the server's own explanation is shown when it refuses", () => {
  const clash = { code: "functions/failed-precondition", message: 'This teacher already has "Quran - Ali" during this time' };
  assert.equal(tradeErrorMessage(clash, "fallback"), 'This teacher already has "Quran - Ali" during this time');
  const leadersOnly = { code: "functions/permission-denied", message: "Only leaders can take a leadership duty" };
  assert.equal(tradeErrorMessage(leadersOnly, "fallback"), "Only leaders can take a leadership duty");
  const already = { code: "functions/already-exists", message: "This teacher already has this shift" };
  assert.equal(tradeErrorMessage(already, "fallback"), "This teacher already has this shift");
});

test("a class somebody else took reads as no longer on offer", () => {
  const gone = { code: "functions/failed-precondition", message: "Shift is no longer available for claiming" };
  assert.equal(tradeErrorMessage(gone, "fallback"), "This class is no longer on offer.");
});

test("a bare status or an unexpected failure falls back to plain words", () => {
  assert.equal(tradeErrorMessage({ code: "functions/internal", message: "INTERNAL" }, "fallback"), "fallback");
  assert.equal(tradeErrorMessage({ code: "functions/internal", message: "Failed to assign shift: boom" }, "fallback"), "fallback");
  assert.equal(tradeErrorMessage({ code: "functions/not-found", message: "NOT_FOUND" }, "fallback"), "fallback");
  assert.equal(tradeErrorMessage({ code: "functions/permission-denied", message: "permission-denied" }, "fallback"), "fallback");
  assert.equal(tradeErrorMessage(new Error("Network down"), "fallback"), "fallback");
  assert.equal(tradeErrorMessage(null, "fallback"), "fallback");
  assert.equal(
    tradeErrorMessage({ code: "functions/unauthenticated", message: "Authentication required" }, "fallback"),
    "Please sign in again, then try again.",
  );
});

test("setShiftOffers reports each class; a refusal carries its reason", () => {
  assert.equal(offerRefusal({ success: true, results: [{ shiftId: "s1", ok: true }] }, "s1", "fallback"), null);
  assert.equal(
    offerRefusal({ success: false, results: [{ shiftId: "s1", ok: false, reason: "This class has already started" }] }, "s1", "fallback"),
    "This class has already started",
  );
  assert.equal(offerRefusal({ success: false, results: [{ shiftId: "s1", ok: false }] }, "s1", "fallback"), "fallback");
  // No row for this class: trust the overall flag.
  assert.equal(offerRefusal({ success: true, results: [] }, "s1", "fallback"), null);
  assert.equal(offerRefusal({ success: false, results: [{ shiftId: "other", ok: true }] }, "s1", "fallback"), "fallback");
  assert.equal(offerRefusal(undefined, "s1", "fallback"), "fallback");
});
