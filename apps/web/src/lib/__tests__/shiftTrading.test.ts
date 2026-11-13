import test from "node:test";
import assert from "node:assert/strict";
import {
  MAX_OFFER_SHIFTS,
  canClaimShift,
  canOfferShift,
  canWithdrawOffer,
  isLeadershipDuty,
  mergeTrades,
  normalizeTrade,
  offerFailureText,
  offerOutcome,
  offerQuickPicks,
  offerReportNotes,
  offerSelection,
  sameSelection,
  seriesIdOf,
  seriesOfferDays,
  tradeClassLabel,
  tradeSentence,
  type SeriesShift,
} from "../shiftTrading.ts";
import { FR } from "../translations/fr.ts";

const now = new Date("2026-11-10T12:00:00Z");
const later = new Date("2026-11-11T12:00:00Z");
const earlier = new Date("2026-11-09T12:00:00Z");

test("an upcoming scheduled class can be offered", () => {
  assert.equal(canOfferShift({ isPublished: false, status: "scheduled", start: later }, now), true);
});

test("a class that started, is not scheduled, or is already offered cannot be offered", () => {
  assert.equal(canOfferShift({ isPublished: false, status: "scheduled", start: earlier }, now), false);
  assert.equal(canOfferShift({ isPublished: false, status: "cancelled", start: later }, now), false);
  assert.equal(canOfferShift({ isPublished: true, status: "scheduled", start: later }, now), false);
  assert.equal(canOfferShift({ isPublished: false, status: "scheduled", start: null }, now), false);
});

test("another teacher can claim an offered upcoming class", () => {
  assert.equal(canClaimShift({ isPublished: true, status: "scheduled", start: later, teacherId: "a" }, "b", now), true);
});

test("a teacher cannot claim their own, a started, or an unoffered class", () => {
  assert.equal(canClaimShift({ isPublished: true, status: "scheduled", start: later, teacherId: "a" }, "a", now), false);
  assert.equal(canClaimShift({ isPublished: true, status: "scheduled", start: earlier, teacherId: "a" }, "b", now), false);
  assert.equal(canClaimShift({ isPublished: false, status: "scheduled", start: later, teacherId: "a" }, "b", now), false);
});

// --- Taking back, leadership duties ---

test("an offer can be taken back until the class starts", () => {
  assert.equal(canWithdrawOffer({ isPublished: true, status: "scheduled", start: later }, now), true);
  assert.equal(canWithdrawOffer({ isPublished: false, status: "scheduled", start: later }, now), false);
  assert.equal(canWithdrawOffer({ isPublished: true, status: "scheduled", start: earlier }, now), false);
  assert.equal(canWithdrawOffer({ isPublished: true, status: "completed", start: later }, now), false);
});

test("a shift with a category other than teaching is a leadership duty", () => {
  assert.equal(isLeadershipDuty("leadership"), true);
  assert.equal(isLeadershipDuty("Meeting"), true);
  assert.equal(isLeadershipDuty("teaching"), false);
  assert.equal(isLeadershipDuty(" Teaching "), false);
  assert.equal(isLeadershipDuty(""), false);
  assert.equal(isLeadershipDuty(undefined), false);
});

// --- Series ---

// Monday 16 Nov 2026, 3 PM local; the series meets every day.
const at = (day: number, hour = 15) => new Date(2026, 10, day, hour);
const today = at(15, 9);
const klass = (id: string, day: number, over: Partial<SeriesShift> = {}): SeriesShift => ({
  id,
  seriesId: "tplA",
  isPublished: false,
  status: "scheduled",
  start: at(day),
  end: at(day, 16),
  teacherId: "t1",
  ...over,
});

test("the series a class belongs to is its template", () => {
  assert.equal(seriesIdOf({ template_id: " tplA " }), "tplA");
  assert.equal(seriesIdOf({ templateId: "tplB" }), "tplB");
  assert.equal(seriesIdOf({}), "");
  assert.equal(seriesIdOf({ template_id: 7 }), "");
});

test("the offer list is the upcoming scheduled classes of the same series, in date order", () => {
  const opened = klass("mon", 16);
  const days = seriesOfferDays(
    opened,
    [
      klass("wed", 18),
      klass("mon", 16),
      klass("tue", 17, { isPublished: true }),
      klass("other-series", 17, { seriesId: "tplB" }),
      klass("cancelled", 19, { status: "cancelled" }),
      klass("past", 14),
      klass("other-teacher", 20, { teacherId: "t2" }),
      klass("too-far", 16, { start: new Date(2026, 11, 20, 15) }),
      klass("no-start", 21, { start: null }),
    ],
    today,
  );
  assert.deepEqual(days.map((day) => [day.id, day.state]), [["mon", "open"], ["tue", "offered"], ["wed", "open"]]);
});

test("a one-off class offers only itself", () => {
  const opened = klass("solo", 16, { seriesId: "" });
  const days = seriesOfferDays(opened, [klass("a", 17, { seriesId: "" }), klass("b", 18)], today);
  assert.deepEqual(days.map((day) => day.id), ["solo"]);
});

test("the opened class is listed even when the fresh load missed it", () => {
  const days = seriesOfferDays(klass("mon", 16), [klass("tue", 17)], today);
  assert.deepEqual(days.map((day) => day.id), ["mon", "tue"]);
});

test("quick picks: only this class, the next three, the class's week", () => {
  // Mon 16 … Sat 21, then Sun 22 and Mon 23 fall in the following week.
  const days = seriesOfferDays(klass("d16", 16), [16, 17, 18, 19, 20, 21, 22, 23].map((day) => klass(`d${day}`, day)), today);
  const picks = offerQuickPicks(days, "d18");
  assert.deepEqual(picks.map((pick) => pick.kind), ["only", "next", "week"]);
  assert.deepEqual(picks[0].ids, ["d18"]);
  assert.deepEqual(picks[1].ids, ["d18", "d19", "d20"]);
  assert.deepEqual(picks[1].vars, { count: 3 });
  assert.deepEqual(picks[2].ids, ["d16", "d17", "d18", "d19", "d20", "d21"]);
});

test("quick picks skip days already offered and drop a pick that repeats another", () => {
  const days = seriesOfferDays(klass("d16", 16), [klass("d16", 16), klass("d17", 17, { isPublished: true }), klass("d23", 23)], today);
  const picks = offerQuickPicks(days, "d16");
  // "This week" would tick the same single day as "Only this class".
  assert.deepEqual(picks.map((pick) => [pick.kind, pick.ids]), [["only", ["d16"]], ["next", ["d16", "d23"]]]);
  assert.deepEqual(picks[1].vars, { count: 2 });
});

test("there are no quick picks without a second open day, or from an offered class", () => {
  assert.deepEqual(offerQuickPicks(seriesOfferDays(klass("d16", 16), [], today), "d16"), []);
  const days = seriesOfferDays(klass("d16", 16, { isPublished: true }), [klass("d17", 17), klass("d18", 18)], today);
  assert.deepEqual(offerQuickPicks(days, "d16"), []);
});

test("only ticked days that are still open are sent, in date order", () => {
  const days = seriesOfferDays(klass("d16", 16), [klass("d17", 17, { isPublished: true }), klass("d18", 18)], today);
  assert.deepEqual(offerSelection(days, ["d18", "d17", "d16", "gone"]), ["d16", "d18"]);
  assert.equal(sameSelection(["a", "b"], ["b", "a"]), true);
  assert.equal(sameSelection(["a"], ["a", "b"]), false);
});

test("at most sixty classes go in one offer", () => {
  const many = Array.from({ length: 70 }, (_, index) => ({ id: `s${index}`, start: at(16), end: null, state: "open" as const }));
  assert.equal(offerSelection(many, many.map((day) => day.id)).length, MAX_OFFER_SHIFTS);
});

// --- What the server answered ---

test("per-class answers are split into done and not done, with a plain reason", () => {
  const outcome = offerOutcome(["a", "b", "c", "d"], [
    { shiftId: "a", ok: true },
    { shiftId: "b", ok: false, reason: "This class has already started" },
    { shiftId: "c", ok: false, reason: "Something odd" },
  ]);
  assert.deepEqual(outcome.okIds, ["a"]);
  assert.deepEqual(outcome.failures, [
    { shiftId: "b", text: "This class has already started." },
    { shiftId: "c", text: "This class could not be offered." },
    { shiftId: "d", text: "This class could not be offered." },
  ]);
  assert.deepEqual(offerOutcome(["a"], undefined).failures.length, 1);
});

test("refusals read in the teacher's words", () => {
  assert.equal(offerFailureText("Only a class that has not started can be offered"), "This class is no longer scheduled.");
  assert.equal(offerFailureText("Shift not found"), "This class could not be found.");
  assert.equal(offerFailureText("This is not your class", false), "This class belongs to another teacher.");
  assert.equal(offerFailureText(undefined, false), "This offer could not be taken back.");
});

test("the admin report says how many classes when it is more than one", () => {
  assert.equal(offerReportNotes("  Travelling ", 1), "Travelling");
  assert.equal(offerReportNotes("Travelling", 3), "Travelling\nOffered 3 classes of this series.");
  assert.equal(offerReportNotes("", 2), "Offered 2 classes of this series.");
});

// --- The record of trades ---

const stamp = (date: Date) => ({ toDate: () => date });
const row = (over: Record<string, unknown> = {}) => ({
  shift_id: "s1",
  action: "offered",
  actor_id: "me",
  from_teacher_id: "me",
  from_teacher_name: "Aisha Bah",
  to_teacher_id: null,
  to_teacher_name: "",
  shift_name: "Quran",
  shift_category: "teaching",
  shift_start: stamp(at(16)),
  shift_end: stamp(at(16, 16)),
  created_at: stamp(at(10)),
  ...over,
});
const trade = (over: Record<string, unknown> = {}, id = "x") => normalizeTrade(id, row(over))!;
const say = (over: Record<string, unknown>) => {
  const { text, vars } = tradeSentence(trade(over), "me");
  return text.replace("{class}", vars.class).replace("{name}", vars.name);
};

test("a trade row is read into dates and trimmed text", () => {
  const read = trade();
  assert.equal(read.action, "offered");
  assert.equal(read.toTeacherId, "");
  assert.equal(read.shiftStart?.getTime(), at(16).getTime());
  assert.equal(read.createdAt?.getTime(), at(10).getTime());
  assert.equal(normalizeTrade("y", row({ action: "swapped" })), null);
});

test("each trade reads as a sentence from the teacher's side", () => {
  assert.equal(say({}), "You offered Quran");
  assert.equal(say({ action: "withdrawn" }), "You took your offer of Quran back");
  assert.equal(say({ action: "claimed", actor_id: "b", to_teacher_id: "b", to_teacher_name: "Bilal Sow" }), "Bilal Sow took Quran from you");
  assert.equal(say({ action: "claimed", actor_id: "me", from_teacher_id: "a", to_teacher_id: "me", to_teacher_name: "Me" }), "You took Quran from Aisha Bah");
  assert.equal(say({ action: "assigned", actor_id: "adm", from_teacher_id: "a", to_teacher_id: "me", to_teacher_name: "Me" }), "An admin gave you Quran from Aisha Bah");
  assert.equal(say({ action: "assigned", actor_id: "adm", to_teacher_id: "b", to_teacher_name: "Bilal Sow" }), "An admin gave Quran to Bilal Sow");
});

test("an admin acting for the teacher, and rows without names, still read well", () => {
  assert.equal(say({ actor_id: "adm" }), "An admin offered Quran for you");
  assert.equal(say({ action: "withdrawn", actor_id: "adm" }), "An admin took the offer of Quran back");
  assert.equal(say({ action: "claimed", actor_id: "b", to_teacher_id: "b" }), "Another teacher took Quran from you");
  assert.equal(say({ action: "claimed", from_teacher_id: "a", from_teacher_name: "", to_teacher_id: "me" }), "You took Quran");
  assert.equal(say({ action: "assigned", actor_id: "adm", from_teacher_id: "a", from_teacher_name: "", to_teacher_id: "me" }), "An admin gave you Quran");
  assert.equal(say({ action: "assigned", actor_id: "adm", to_teacher_id: "b" }), "An admin gave Quran to another teacher");
  assert.equal(tradeSentence(trade({ shift_name: "" }), "me").vars.class, "");
});

test("a generated class name drops the teacher it starts with", () => {
  assert.equal(tradeClassLabel({ shiftName: "Aisha Bah - Quran - Musa D, Awa D", fromTeacherName: "Aisha Bah", toTeacherName: "" }), "Quran – Musa D, Awa D");
  assert.equal(tradeClassLabel({ shiftName: "Bilal Sow - Quran - Musa D", fromTeacherName: "Aisha Bah", toTeacherName: "bilal sow" }), "Quran – Musa D");
  assert.equal(tradeClassLabel({ shiftName: "Quran - Musa D", fromTeacherName: "Aisha Bah", toTeacherName: "" }), "Quran - Musa D");
  assert.equal(tradeClassLabel({ shiftName: "Quran", fromTeacherName: "Quran", toTeacherName: "" }), "Quran");
});

test("trades from both queries are joined once each, newest first, capped", () => {
  const a = trade({ created_at: stamp(at(10)) }, "a");
  const b = trade({ created_at: stamp(at(12)) }, "b");
  const c = trade({ created_at: stamp(at(11)) }, "c");
  assert.deepEqual(mergeTrades([[a, b], [b, c]]).map((entry) => entry.id), ["b", "c", "a"]);
  assert.deepEqual(mergeTrades([[a, b], [c]], 2).map((entry) => entry.id), ["b", "c"]);
  const undated = trade({ created_at: null }, "u");
  assert.deepEqual(mergeTrades([[undated, a]]).map((entry) => entry.id), ["a", "u"]);
});

test("every sentence, shortcut and refusal has a French translation", () => {
  const sources = new Set<string>();
  const actions = ["offered", "withdrawn", "claimed", "assigned"];
  for (const action of actions) {
    for (const actor_id of ["me", "adm"]) {
      for (const mine of [true, false]) {
        for (const name of ["Aisha Bah", ""]) {
          const over = mine
            ? { action, actor_id, to_teacher_id: "b", to_teacher_name: name }
            : { action, actor_id, from_teacher_id: "a", from_teacher_name: name, to_teacher_id: "me" };
          sources.add(tradeSentence(trade(over), "me").text);
        }
      }
    }
  }
  const days = seriesOfferDays(klass("d16", 16), [16, 17, 18, 19, 23].map((day) => klass(`d${day}`, day)), today);
  for (const pick of offerQuickPicks(days, "d16")) sources.add(pick.label);
  for (const reason of ["This class has already started", "Only a class that has not started can be offered", "Shift not found", "This is not your class", ""]) {
    sources.add(offerFailureText(reason, true));
    sources.add(offerFailureText(reason, false));
  }
  assert.ok(sources.size >= 20);
  for (const source of sources) assert.ok(FR[source], `no French for "${source}"`);
});
