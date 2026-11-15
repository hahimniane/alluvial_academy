import assert from "node:assert/strict";
import { test } from "node:test";
import {
  UNKNOWN_STUDENT,
  appSearchMatches,
  callableErrorText,
  dateBuckets,
  dateKey,
  dateTime,
  displayDate,
  fragmentTitle,
  headerSubtitle,
  headerTitle,
  levelOf,
  longDate,
  parseRecording,
  peopleFromDoc,
  peopleToResolve,
  personName,
  playLabel,
  playerTime,
  readListAnswer,
  readPlaybackAnswer,
  recordingsForDate,
  recordingsForStudent,
  retentionChip,
  retentionColor,
  retentionText,
  searchHint,
  shiftBuckets,
  shiftSubtitle,
  shortDate,
  skipTo,
  statusColor,
  statusLabel,
  studentBuckets,
  teacherName,
  type People,
} from "../parentRecordings.ts";
import { BOOKS_TEXT, CURRICULUM_BOOKS, bookOpenUrl, parentLearningText } from "../parentLearning.ts";
import { PARENT_ROUTES, PARENT_WEB_SCREENS, activeParentItemId, isPushedParentPage } from "../parentWeb.ts";

const iso = (y: number, m: number, d: number, h = 10, min = 0) => new Date(y, m - 1, d, h, min).toISOString();

function rec(id: string, extra: Record<string, unknown> = {}) {
  return parseRecording({ recordingId: id, filePath: `class-recordings/${id}.mp4`, status: "ended", canPlay: true, ...extra });
}

test("parseRecording follows ClassRecordingItem.fromMap", () => {
  const r = parseRecording({ recordingId: "r1", shiftName: "  ", studentIds: [" a ", "a", "", null, "b"], filePath: "f" });
  assert.equal(r.shiftName, "Class Recording");
  assert.deepEqual(r.studentIds, ["a", "b"]);
  assert.equal(r.status, "unknown");
  assert.equal(r.canPlay, false);
  assert.equal(r.mergeStatus, null);
  assert.equal(r.teacherId, null);
});

test("displayDate is startedAt, then requestedAt, then shiftStart, then updatedAt", () => {
  const s = rec("x", { shiftStartIso: iso(2026, 11, 1), updatedAtIso: iso(2026, 11, 3) });
  assert.equal(displayDate(s)?.toISOString(), iso(2026, 11, 1));
  const q = rec("y", { requestedAtIso: iso(2026, 11, 2), shiftStartIso: iso(2026, 11, 1) });
  assert.equal(displayDate(q)?.toISOString(), iso(2026, 11, 2));
  assert.equal(displayDate(rec("z")), null);
});

test("list answer: non-map, success false, items without id or file are skipped", () => {
  assert.deepEqual(readListAnswer(null), { ok: false, error: "Unexpected response from server" });
  assert.deepEqual(readListAnswer({ success: false }), { ok: false, error: "Failed to load recordings" });
  const out = readListAnswer({
    success: true,
    role: "parent",
    recordings: [{ recordingId: "a", filePath: "x" }, { recordingId: "", filePath: "x" }, { recordingId: "b" }, "junk"],
  });
  assert.equal(out.ok, true);
  if (out.ok) {
    assert.equal(out.role, "parent");
    assert.deepEqual(out.recordings.map((r) => r.recordingId), ["a"]);
  }
});

test("playback answer and error texts match ClassRecordingService", () => {
  assert.deepEqual(readPlaybackAnswer(7), { ok: false, error: "Unexpected playback response from server" });
  assert.deepEqual(readPlaybackAnswer({ success: false }), { ok: false, error: "Unable to open recording" });
  assert.deepEqual(readPlaybackAnswer({ success: true, url: " " }), { ok: false, error: "Playback URL not available" });
  assert.deepEqual(readPlaybackAnswer({ success: true, url: " https://x " }), { ok: true, url: "https://x" });
  assert.equal(callableErrorText({ code: "functions/permission-denied", message: "You are not allowed to access this recording" }, "playback"), "You are not allowed to access this recording");
  assert.equal(callableErrorText({ code: "functions/internal", message: " " }, "list"), "internal: failed to load recordings");
  assert.equal(callableErrorText({ code: "functions/internal", message: "" }, "playback"), "internal: unable to open recording");
  assert.equal(callableErrorText(new TypeError("x"), "list"), "Failed to load recordings");
  assert.equal(callableErrorText(new TypeError("x"), "playback"), "Failed to open recording");
});

test("names: first + last, else name/displayName, else e-mail, else the id; one entry per alias", () => {
  assert.equal(personName("id1", { firstName: "Aa", last_name: "Bb" }), "Aa Bb");
  assert.equal(personName("id1", { displayName: "Dd" }), "Dd");
  assert.equal(personName("id1", { email: "e@x" }), "e@x");
  assert.equal(personName("id1", {}), "id1");
  const people = peopleFromDoc("doc", { first_name: "T", uid: "u1", authUid: "a1", "e-mail": "t@x", mobile_phone: "+1 555 0100 222" });
  assert.deepEqual(Object.keys(people).sort(), ["a1", "doc", "u1"]);
  assert.equal(people.u1.phone, "+1 555 0100 222");
  assert.deepEqual(peopleToResolve([rec("r", { teacherId: " t ", studentIds: ["a", "b"] }), rec("s", { studentIds: ["a"] })]), ["t", "a", "b"]);
});

test("AppSearch: name/e-mail contains, ids loosely, phone from 7 digits, extra values last", () => {
  assert.equal(appSearchMatches({ query: "  ", names: [] }), true);
  assert.equal(appSearchMatches({ query: "fat", names: ["Zz Teacher Fatou"] }), true);
  assert.equal(appSearchMatches({ query: "teach@", emails: ["zz.teach@x.org"] }), true);
  assert.equal(appSearchMatches({ query: "zz-rec", ids: ["zz_rec_shift_1"] }), true);
  assert.equal(appSearchMatches({ query: "555 0100", phones: ["+1 (555) 0100-222"] }), false);
  assert.equal(appSearchMatches({ query: "5550100222", phones: ["+1 (555) 0100-222"] }), true);
  assert.equal(appSearchMatches({ query: "0612345678", phones: ["612345678"] }), true);
  assert.equal(appSearchMatches({ query: "tajw", additionalValues: ["Tajweed"] }), true);
  assert.equal(appSearchMatches({ query: "nope", names: ["a"], additionalValues: ["b"] }), false);
});

const people: People = {
  ca: { id: "ca", name: "Zz Child Amadou", email: "amadou@x", phone: "" },
  cb: { id: "cb", name: "Zz Child Binta", email: "", phone: "" },
  t1: { id: "t1", name: "Zz Teacher Fatou", email: "fatou@x", phone: "+1 555 010 0222" },
};

const all = [
  rec("r1", { studentIds: ["ca"], shiftId: "s1", shiftName: "Quran", teacherId: "t1", startedAtIso: iso(2026, 11, 14, 9) }),
  rec("r2", { studentIds: ["ca"], shiftId: "s1", shiftName: "Quran", teacherId: "t1", startedAtIso: iso(2026, 11, 14, 8) }),
  rec("r3", { studentIds: ["ca", "cb"], shiftId: "s2", shiftName: "Family", subjectName: " Tajweed ", startedAtIso: iso(2026, 11, 13, 18) }),
  rec("r4", { studentIds: ["cb"], shiftStartIso: iso(2026, 11, 10, 7) }),
  rec("r5", { studentIds: [], startedAtIso: iso(2026, 11, 1) }),
];

test("level 1: one card per child, siblings both counted, newest first, unknown student", () => {
  const buckets = studentBuckets(all, people, "");
  assert.deepEqual(buckets.map((b) => [b.name, b.recordings.length]), [
    ["Zz Child Amadou", 3],
    ["Zz Child Binta", 2],
    ["Unknown Student", 1],
  ]);
  assert.equal(shortDate(buckets[0].latestDate!), "Nov 14, 2026");
  assert.deepEqual(studentBuckets(all, people, "binta").map((b) => b.id), ["cb"]);
  assert.deepEqual(studentBuckets(all, people, "amadou@").map((b) => b.id), ["ca"]);
  assert.deepEqual(studentBuckets(all, {}, "").map((b) => b.name), ["ca", "cb", "Unknown Student"]);
  assert.deepEqual(recordingsForStudent(all, UNKNOWN_STUDENT).map((r) => r.recordingId), ["r5"]);
});

test("ties on the date sort by name, lower-cased, code-unit order", () => {
  const same = iso(2026, 11, 14);
  const buckets = studentBuckets(
    [rec("a", { studentIds: ["x"], startedAtIso: same }), rec("b", { studentIds: ["y"], startedAtIso: same })],
    { x: { id: "x", name: "bob", email: "", phone: "" }, y: { id: "y", name: "Alice", email: "", phone: "" } },
    "",
  );
  assert.deepEqual(buckets.map((b) => b.name), ["Alice", "bob"]);
});

test("level 2: a card per local day, newest first, long or short date search", () => {
  const amadou = recordingsForStudent(all, "ca");
  const dates = dateBuckets(amadou, "");
  assert.deepEqual(dates.map((d) => d.key), ["2026-11-14", "2026-11-13"]);
  assert.equal(longDate(dates[0].date!), "Saturday, Nov 14, 2026");
  assert.deepEqual(dateBuckets(amadou, "friday").map((d) => d.key), ["2026-11-13"]);
  assert.deepEqual(dateBuckets(amadou, "nov 13, 2026").map((d) => d.key), ["2026-11-13"]);
  assert.deepEqual(dateBuckets([rec("u", { studentIds: ["ca"] })], "unknown").map((d) => d.key), ["__unknown_date__"]);
  assert.equal(dateKey(new Date(2026, 0, 5, 23, 59)), "2026-01-05");
  // shiftStart counts when nothing else is set (the student web page skipped it).
  assert.deepEqual(dateBuckets(recordingsForStudent(all, "cb"), "").map((d) => d.key), ["2026-11-13", "2026-11-10"]);
});

test("level 3: one card per class, fragments oldest first, Flutter's search fields", () => {
  const day = recordingsForDate(recordingsForStudent(all, "ca"), "2026-11-14");
  const shifts = shiftBuckets(day, people, "");
  assert.equal(shifts.length, 1);
  assert.deepEqual(shifts[0].fragments.map((f) => f.recordingId), ["r2", "r1"]);
  assert.equal(shifts[0].teacherName, "Zz Teacher Fatou");
  assert.equal(shiftSubtitle(shifts[0]), "2 fragments · Ready: 2");
  assert.equal(shiftBuckets(day, people, "fatou@").length, 1);
  assert.equal(shiftBuckets(day, people, "5550100222").length, 1);
  assert.equal(shiftBuckets(day, people, "s1").length, 1);
  assert.equal(shiftBuckets(day, people, "quran").length, 1);
  assert.equal(shiftBuckets(day, people, "arabic").length, 0);
  const fam = shiftBuckets(recordingsForDate(recordingsForStudent(all, "ca"), "2026-11-13"), people, "");
  assert.equal(fam[0].subjectName, "Tajweed");
  assert.equal(shiftSubtitle({ ...fam[0], readyCount: 0 }), "1 fragment · Ready: 0 · Tajweed");
  const loose = shiftBuckets([rec("p"), rec("q")], {}, "");
  assert.deepEqual(loose.map((b) => b.key).sort(), ["recording:p", "recording:q"]);
});

test("teacher name: looked up, else stored, else id, else Unknown Teacher", () => {
  assert.equal(teacherName(rec("a", { teacherId: "t1" }), people), "Zz Teacher Fatou");
  assert.equal(teacherName(rec("a", { teacherId: "t9", teacherName: " Stored " }), people), "Stored");
  assert.equal(teacherName(rec("a", { teacherId: "t9" }), people), "t9");
  assert.equal(teacherName(rec("a"), people), "Unknown Teacher");
});

test("header, subtitle and search hint per level", () => {
  assert.equal(levelOf({ studentId: null, dateKey: null, shiftKey: null }), "students");
  assert.equal(levelOf({ studentId: "a", dateKey: "d", shiftKey: "s" }), "fragments");
  assert.equal(headerTitle("students", null), "Students");
  assert.equal(headerTitle("fragments", null), "Recording Fragments");
  const counts = { students: 1, dates: 2, shifts: 1 };
  assert.equal(headerSubtitle("students", counts, null), "1 student");
  assert.equal(headerSubtitle("students", { ...counts, students: 0 }, null), "0 students");
  assert.equal(headerSubtitle("dates", counts, null), "2 dates with recordings");
  assert.equal(headerSubtitle("shifts", counts, null), "1 shift on this date");
  const shift = shiftBuckets(recordingsForDate(recordingsForStudent(all, "ca"), "2026-11-14"), people, "")[0];
  assert.equal(headerTitle("fragments", shift), "Quran");
  assert.equal(headerSubtitle("fragments", counts, shift), `2 fragments · ${dateTime(shift.date)}`);
  assert.equal(searchHint("students"), "Search student...");
  assert.equal(searchHint("dates"), "Search date...");
  assert.equal(searchHint("shifts"), "Search class or subject...");
});

test("dateTime is EEE, MMM d · h:mm a", () => {
  assert.equal(dateTime(new Date(2026, 10, 14, 9, 5)), "Sat, Nov 14 · 9:05 AM");
  assert.equal(dateTime(new Date(2026, 10, 14, 0, 30)), "Sat, Nov 14 · 12:30 AM");
  assert.equal(dateTime(new Date(2026, 10, 14, 12, 0)), "Sat, Nov 14 · 12:00 PM");
  assert.equal(dateTime(null), "Unknown date");
});

test("status chip: Processing / Ready / Failed / raw / Unknown and colours", () => {
  assert.equal(statusLabel({ status: "starting", mergeStatus: null }), "Processing");
  assert.equal(statusLabel({ status: "ended", mergeStatus: "merging" }), "Processing");
  assert.equal(statusLabel({ status: "COMPLETE", mergeStatus: null }), "Ready");
  assert.equal(statusLabel({ status: "failed", mergeStatus: null }), "Failed");
  assert.equal(statusLabel({ status: " paused ", mergeStatus: null }), "paused");
  assert.equal(statusLabel({ status: " ", mergeStatus: null }), "Unknown");
  assert.equal(statusColor({ status: "ended", mergeStatus: "pending" }), "#F59E0B");
  assert.equal(statusColor({ status: "active", mergeStatus: null }), "#10B981");
  assert.equal(statusColor({ status: "failed", mergeStatus: null }), "#EF4444");
  assert.equal(statusColor({ status: "paused", mergeStatus: null }), "#64748B");
});

test("auto-delete countdown, colour and date", () => {
  const now = new Date(2026, 10, 15, 12, 0);
  const plus = (ms: number) => new Date(now.getTime() + ms);
  const D = 86_400_000;
  assert.equal(retentionText(null, now), "Auto-delete schedule unavailable");
  assert.equal(retentionText(plus(-1), now), "Deleting soon");
  assert.equal(retentionText(plus(59 * D), now), "Auto-deletes in about 2 months");
  assert.equal(retentionText(plus(28 * D), now), "Auto-deletes in about 1 month");
  assert.equal(retentionText(plus(20 * D), now), "Auto-deletes in 2 weeks");
  assert.equal(retentionText(plus(14 * D), now), "Auto-deletes in 2 weeks");
  assert.equal(retentionText(plus(5 * D + 3600_000), now), "Auto-deletes in 5 days");
  assert.equal(retentionText(plus(20 * 3600_000), now), "Auto-deletes in 20 hours");
  assert.equal(retentionText(plus(30 * 60_000), now), "Auto-deletes in 30 minutes");
  assert.equal(retentionText(plus(90_000), now), "Auto-deletes in less than a minute");
  assert.equal(retentionColor(null, now), "#64748B");
  assert.equal(retentionColor(plus(-1), now), "#DC2626");
  assert.equal(retentionColor(plus(2 * D), now), "#DC2626");
  assert.equal(retentionColor(plus(3 * D), now), "#B45309");
  assert.equal(retentionColor(plus(14 * D), now), "#0E7490");
  assert.equal(retentionChip(new Date(2027, 0, 14, 12), now), "Auto-deletes in about 2 months · Jan 14, 2027");
  assert.equal(retentionChip(null, now), "Auto-delete schedule unavailable");
});

test("fragment title and play button", () => {
  assert.equal(fragmentTitle(1, 1), "Full Recording");
  assert.equal(fragmentTitle(2, 3), "Fragment 2");
  assert.equal(playLabel(rec("a"), true), "Loading...");
  assert.equal(playLabel(rec("a"), false), "Play Recording");
  assert.equal(playLabel(rec("a", { canPlay: false, status: "starting" }), false), "Processing...");
  assert.equal(playLabel(rec("a", { canPlay: false, status: "active" }), false), "Not Ready Yet");
});

test("player clock and ±10 s", () => {
  assert.equal(playerTime(0), "00:00");
  assert.equal(playerTime(75.9), "01:15");
  assert.equal(playerTime(3725), "01:02:05");
  assert.equal(playerTime(Number.NaN), "00:00");
  assert.equal(skipTo(4, 60, -10), 0);
  assert.equal(skipTo(55, 60, 10), 60);
  assert.equal(skipTo(20, 60, 10), 30);
});

test("curriculum books: Flutter's four books, order, files, colours and wording", () => {
  assert.deepEqual(
    CURRICULUM_BOOKS.map((b) => [b.subtitle, b.accent, b.pdfUrl.split("/").pop(), b.downloadUrl.split("/").pop()]),
    [
      ["Alphabet and open-vowel practice", "#0F766E", "alphabet_and_fatha.pdf", "alphabet_and_fatha.pptx"],
      ["Damma lessons", "#2563EB", "damma_lessons.pdf", "damma_lessons.pptx"],
      ["Open-vowel reading practice", "#D97706", "open_letters_practice.pdf", "open_letters_practice.pptx"],
      ["Kasra lessons", "#7C3AED", "kasra_lessons.pdf", "kasra_lessons.pptx"],
    ],
  );
  for (const book of CURRICULUM_BOOKS) {
    assert.ok(book.pdfUrl.startsWith("https://storage.googleapis.com/alluwal-academy.firebasestorage.app/curriculum/"));
  }
  assert.equal(bookOpenUrl(CURRICULUM_BOOKS[0]), `${CURRICULUM_BOOKS[0].pdfUrl}#view=Fit`);
  assert.deepEqual([...BOOKS_TEXT.chips], ["All roles", "PowerPoint files", "Arabic curriculum"]);
  assert.deepEqual(parentLearningText(true), { tryAgain: "Réessayer", download: "Télécharger" });
  assert.deepEqual(parentLearningText(false), { tryAgain: "Try Again", download: "Download" });
});

test("the three pages are listed, in the shell, and highlight their item", () => {
  for (const id of ["recordings", "curriculum_books", "quran"] as const) assert.equal(PARENT_WEB_SCREENS.has(id), true);
  for (const path of [PARENT_ROUTES.recordings, PARENT_ROUTES.curriculumBooks, PARENT_ROUTES.quran]) assert.equal(isPushedParentPage(path), false);
  assert.equal(activeParentItemId("/parent/recordings/"), "recordings");
  assert.equal(activeParentItemId("/parent/curriculum-books"), "curriculum_books");
  assert.equal(activeParentItemId("/parent/quran/"), "quran");
});
