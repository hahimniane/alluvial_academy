/**
 * Drives the staged move of teachers from the Flutter dashboard to the Next.js
 * console by editing `settings/teacher_web_cutover`.
 *
 * Modes (CUTOVER_MODE):
 *   report              read-only: who is on the new console, and is it quiet
 *   allowlist-this-week put every teacher with a shift this week on it
 *   all                 put every teacher on it
 *   hold / resume       stop or restart the automatic Friday promotion
 *   off                 put everyone back on the Flutter dashboard
 *   scheduled           report; and on Friday, promote to `all` if it is safe
 *
 * "Safe" is not a feeling. Friday's promotion is refused when the document is
 * on hold, when nobody has been on the new console yet, or when a teacher who
 * is on it has clocked hours their audit does not reflect — the same
 * comparison the weekly pay check runs, because the way this migration could
 * hurt someone is by getting their pay wrong.
 */
import admin from "firebase-admin";
import { appendFileSync } from "node:fs";

const MODE = process.env.CUTOVER_MODE || "report";
const DOC = { collection: "settings", id: "teacher_web_cutover" };
const ZONE = "America/New_York";
const TOLERANCE_HOURS = 0.1;

const credential = process.env.FIREBASE_SERVICE_ACCOUNT
  ? admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT))
  : admin.credential.applicationDefault();
admin.initializeApp({ credential, projectId: "alluwal-academy" });
const db = admin.firestore();

const out = [];
const say = (line) => {
  console.log(line);
  out.push(line);
};

/** Monday 00:00 to next Monday 00:00, New York, as UTC instants. */
function thisWeek(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: ZONE, year: "numeric", month: "2-digit", day: "2-digit", weekday: "short",
  }).formatToParts(now);
  const get = (t) => parts.find((p) => p.type === t)?.value ?? "";
  const weekday = get("weekday");
  const days = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };
  const back = days[weekday] ?? 0;
  const midnight = new Date(`${get("year")}-${get("month")}-${get("day")}T00:00:00-04:00`);
  const start = new Date(midnight.getTime() - back * 86400000);
  return { start, end: new Date(start.getTime() + 7 * 86400000), weekday };
}

/** Teachers with at least one class this week — live and archived shifts. */
async function teachersWithShiftsThisWeek() {
  const { start, end } = thisWeek();
  const ts = admin.firestore.Timestamp;
  const ids = new Set();
  for (const col of ["teaching_shifts", "teaching_shifts_archive"]) {
    const snap = await db
      .collection(col)
      .where("shift_start", ">=", ts.fromDate(start))
      .where("shift_start", "<", ts.fromDate(end))
      .get();
    for (const d of snap.docs) {
      const t = String((d.data() || {}).teacher_id || "");
      if (t) ids.add(t);
    }
  }
  const eligible = [];
  for (const uid of ids) {
    const u = (await db.collection("users").doc(uid).get()).data();
    if (!u) continue;
    const type = String(u.user_type || u.role || "").toLowerCase();
    if (type !== "teacher" || u.is_active === false) continue;
    eligible.push(uid);
  }
  return eligible.sort();
}

const hoursOf = (value) => {
  if (typeof value === "number") return Number.isFinite(value) ? value : 0;
  const m = String(value ?? "").trim().match(/^(\d+):(\d{1,2}):(\d{1,2})$/);
  if (m) return Number(m[1]) + Number(m[2]) / 60 + Number(m[3]) / 3600;
  const n = parseFloat(String(value ?? ""));
  return Number.isFinite(n) ? n : 0;
};

/**
 * For the teachers already on the new console: does what they clocked this
 * month still match what their audit pays? A gap here is the signal that the
 * move has broken something that matters.
 */
async function payLooksRight(teacherIds) {
  if (teacherIds.length === 0) return { ok: true, checked: 0, problems: [] };
  const now = new Date();
  const ym = new Intl.DateTimeFormat("en-CA", { timeZone: ZONE, year: "numeric", month: "2-digit" })
    .format(now).slice(0, 7);
  const start = new Date(`${ym}-01T00:00:00-04:00`);
  const ts = admin.firestore.Timestamp;
  const entries = await db
    .collection("timesheet_entries")
    .where("scheduled_start", ">=", ts.fromDate(start))
    .get();
  const clocked = {};
  for (const d of entries.docs) {
    const e = d.data() || {};
    if (String(e.status || "").toLowerCase() !== "approved") continue;
    const uid = String(e.teacher_id || "");
    if (!uid) continue;
    clocked[uid] = (clocked[uid] || 0) + hoursOf(e.total_hours);
  }
  const problems = [];
  for (const uid of teacherIds) {
    const audit = (await db.collection("teacher_audits").doc(`${uid}_${ym}`).get()).data();
    if (!audit) continue; // no audit yet this month is normal, not a problem
    const gap = (clocked[uid] || 0) - (Number(audit.totalWorkedHours) || 0);
    if (gap > TOLERANCE_HOURS) {
      problems.push(`${audit.teacherName || uid}: clocked ${(clocked[uid] || 0).toFixed(2)}h, audit ${(Number(audit.totalWorkedHours) || 0).toFixed(2)}h`);
    }
  }
  return { ok: problems.length === 0, checked: teacherIds.length, problems };
}

async function readDoc() {
  const snap = await db.collection(DOC.collection).doc(DOC.id).get();
  return snap.exists ? snap.data() : { mode: "off", teacherIds: [], hold: false };
}

async function writeDoc(patch, note) {
  await db.collection(DOC.collection).doc(DOC.id).set(
    { ...patch, updatedAt: admin.firestore.FieldValue.serverTimestamp(), updatedBy: `ci:${MODE}`, note },
    { merge: true },
  );
}

const nameFor = async (uid) => {
  const u = (await db.collection("users").doc(uid).get()).data();
  return u ? `${u.first_name || ""} ${u.last_name || ""}`.trim() || uid : uid;
};

async function main() {
  const doc = await readDoc();
  const { weekday } = thisWeek();
  const onNow = doc.mode === "all" ? "everyone" : doc.mode === "allowlist" ? `${(doc.teacherIds || []).length} teachers` : "nobody";
  say(`### Teacher web cutover`);
  say(`- Mode: **${doc.mode || "off"}** (${onNow} on the Next.js console)`);
  if (doc.hold) say(`- **On hold** — the Friday promotion will not run.`);

  if (MODE === "hold" || MODE === "resume") {
    await writeDoc({ hold: MODE === "hold" }, `${MODE} via workflow_dispatch`);
    say(`- Set hold to **${MODE === "hold"}**.`);
    return;
  }

  if (MODE === "off") {
    await writeDoc({ mode: "off" }, "rolled back via workflow_dispatch");
    say(`- Rolled back: every teacher is on the Flutter dashboard again.`);
    return;
  }

  if (MODE === "allowlist-this-week") {
    const ids = await teachersWithShiftsThisWeek();
    await writeDoc({ mode: "allowlist", teacherIds: ids, hold: false }, "teachers with shifts this week");
    say(`- Put **${ids.length} teachers** with a class this week on the new console.`);
    return;
  }

  if (MODE === "all") {
    await writeDoc({ mode: "all" }, "promoted to everyone via workflow_dispatch");
    say(`- Promoted: **every teacher** is on the new console.`);
    return;
  }

  // report / scheduled
  const scope = doc.mode === "allowlist" ? (doc.teacherIds || []) : [];
  const pay = await payLooksRight(doc.mode === "all" ? await teachersWithShiftsThisWeek() : scope);
  if (pay.problems.length > 0) {
    say(`- ⚠️ **Pay does not match for ${pay.problems.length} teacher(s):**`);
    pay.problems.forEach((p) => say(`  - ${p}`));
  } else {
    say(`- Pay matches clocked hours for all ${pay.checked} teacher(s) checked.`);
  }

  if (MODE === "scheduled" && weekday === "Fri" && doc.mode === "allowlist") {
    if (doc.hold) {
      say(`- Friday promotion skipped: the rollout is on hold.`);
    } else if (scope.length === 0) {
      say(`- Friday promotion skipped: nobody has been on the new console yet.`);
    } else if (!pay.ok) {
      say(`- Friday promotion **refused**: a teacher's pay does not match their clocked hours. Fix that first.`);
    } else {
      await writeDoc({ mode: "all" }, "automatic Friday promotion after a clean week");
      say(`- ✅ Promoted to **everyone** after a clean week for ${scope.length} teachers.`);
    }
  }

  if (doc.mode === "allowlist" && scope.length > 0 && scope.length <= 40) {
    const names = [];
    for (const uid of scope) names.push(await nameFor(uid));
    say(`- On the new console: ${names.join(", ")}`);
  }
}

main()
  .then(() => {
    if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, out.join("\n") + "\n");
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
