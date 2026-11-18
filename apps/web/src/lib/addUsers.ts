/**
 * Rules for "Add users" and "Enroll a family" on the admin Users page
 * (slice C), ported from lib/features/user_management/screens/add_user_screen.dart
 * with the owner's fixes: several people per save works, the hourly rate is
 * saved, every message says what really happened. Pure so it can be tested;
 * addUsersData.ts makes the calls.
 *
 * Sensitive: no password ever passes through here. The callables no longer
 * return one; an admin sees a student's password only with Show in the panel.
 */

import { displayNameOf, typeInfo, type UserRow } from "./adminUsers.ts";
import { dialCodeOf, phoneProblem, toE164 } from "./phoneNumbers.ts";
import { normalizeEmail, type ExistingPerson } from "./userDuplicates.ts";

export type NewUserType = "admin" | "teacher" | "student" | "parent";

export const USER_TYPES: [NewUserType, string][] = [
  ["admin", "Admin"],
  ["teacher", "Teacher"],
  ["student", "Student"],
  ["parent", "Parent"],
];

export type DraftRow = {
  key: number;
  type: NewUserType;
  firstName: string;
  lastName: string;
  email: string;
  countryIso: string;
  phone: string;
  hourlyRate: string;
  adult: boolean;
  parentId: string | null;
  kioskCode: string;
};

export const MAX_ROWS = 25;

export function emptyRow(key: number, type: NewUserType, countryIso = "US"): DraftRow {
  return { key, type, firstName: "", lastName: "", email: "", countryIso, phone: "", hourlyRate: "", adult: false, parentId: null, kioskCode: "" };
}

export const isStaffType = (t: NewUserType) => t === "admin" || t === "teacher";
export const isMinorRow = (r: Pick<DraftRow, "type" | "adult">) => r.type === "student" && !r.adult;

/** U-077: a row counts once any of first name, last name, phone or email has text. */
export const rowCounts = (r: DraftRow) => !!(r.firstName.trim() || r.lastName.trim() || r.phone.trim() || r.email.trim());

// ─── Student ID (mirror of functions/handlers/students.js) ─────────────────

export const STUDENT_LOGIN_DOMAIN = "alluwaleducationhub.org";
const MAX_CODE_ATTEMPTS = 10;

/** students.js normalizeString: lower case, only a-z and 0-9, ten at most. Accents are dropped, not translated. */
export const studentIdPart = (value: string): string => value.toLowerCase().replace(/[^a-z0-9]/g, "").substring(0, 10);

export const baseStudentCode = (firstName: string, lastName: string) => `${studentIdPart(firstName)}.${studentIdPart(lastName)}`;

/** The server refuses a name whose first or last part has no Latin letter or digit. */
export const studentIdProblem = (firstName: string, lastName: string): string | null =>
  firstName.trim() && lastName.trim() && (!studentIdPart(firstName) || !studentIdPart(lastName))
    ? "The Student ID uses the Latin letters of the name. Add the name in Latin letters."
    : null;

/**
 * The Student ID the server will give: `first.last`, else `1first.last` …
 * `9first.last` when taken. `taken` holds every stored student_code; codes
 * predicted for earlier rows of the same save are added as they are used,
 * because the server creates the rows in order. "" when all ten are taken.
 * (A sign-in account with no profile also blocks a code; only the server sees
 * those, so the result shows the real ID.)
 */
export function predictStudentCode(firstName: string, lastName: string, taken: Set<string>): string {
  const base = baseStudentCode(firstName, lastName);
  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt += 1) {
    const code = attempt === 0 ? base : `${attempt}${base}`;
    if (!taken.has(code)) return code;
  }
  return "";
}

export const loginEmailFor = (code: string) => (code ? `${code}@${STUDENT_LOGIN_DOMAIN}` : "");

export function takenStudentCodes(rows: readonly UserRow[]): Set<string> {
  const set = new Set<string>();
  for (const r of rows) if (r.storedStudentCode) set.add(r.storedStudentCode);
  return set;
}

/** utils/student_identity.js normalizeName: accents, case, spaces and punctuation ignored, letters only. */
export const childNameKey = (value: string) =>
  value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z]/g, "");

/**
 * The child the server will return instead of creating one (createStudentAccount's
 * dedupe): an active, unmerged student under one of these guardians with the
 * same first name and the same last name (or no last name typed).
 */
export function existingChildOf(guardianIds: readonly string[], firstName: string, lastName: string, rows: readonly UserRow[]): UserRow | null {
  const guardians = new Set(guardianIds.filter(Boolean));
  if (!guardians.size) return null;
  const first = childNameKey(firstName);
  const last = childNameKey(lastName);
  for (const r of rows) {
    if (r.userType.toLowerCase() !== "student" || !r.isActive || r.mergedInto) continue;
    if (!r.guardianIds.some((g) => guardians.has(g))) continue;
    if (childNameKey(r.firstName) !== first) continue;
    if (last && childNameKey(r.lastName) !== last) continue;
    return r;
  }
  return null;
}

// ─── Kiosk code (U-069) ────────────────────────────────────────────────────

const TYPE_CODES: Record<NewUserType, string> = { admin: "AD", teacher: "TC", student: "ST", parent: "PR" };

const randomBelow = (n: number): number => {
  const c = (globalThis as { crypto?: Crypto }).crypto;
  if (c?.getRandomValues) {
    const buf = new Uint32Array(1);
    c.getRandomValues(buf);
    return buf[0] % n;
  }
  return Math.floor(Math.random() * n);
};

/** Initials + type code + 3 random digits (000-998) + digits 9-13 of the epoch-ms clock, as Flutter makes it. */
export function makeKioskCode(firstName: string, lastName: string, type: NewUserType, nowMs = Date.now(), random = randomBelow(999)): string {
  const first = firstName.trim();
  const last = lastName.trim();
  if (!first || !last) return "";
  const initials = `${first.charAt(0)}${last.charAt(0)}`.toUpperCase();
  return `${initials}${TYPE_CODES[type]}${String(random).padStart(3, "0")}${String(nowMs).substring(8, 13)}`;
}

/** Whether the code still fits the row (same initials and type), so typing the rest of a name keeps it. */
export function kioskCodeFits(code: string, firstName: string, lastName: string, type: NewUserType): boolean {
  const first = firstName.trim();
  const last = lastName.trim();
  if (!code || !first || !last) return false;
  return code.startsWith(`${first.charAt(0)}${last.charAt(0)}`.toUpperCase() + TYPE_CODES[type]);
}

// ─── Checks ────────────────────────────────────────────────────────────────

export type RowErrors = Partial<Record<"firstName" | "lastName" | "email" | "phone" | "hourlyRate" | "parent" | "studentId", string>>;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function hourlyRateProblem(value: string): string | null {
  const t = value.trim();
  if (!t) return null;
  if (!/^\d+(\.\d{1,2})?$/.test(t)) return "Use a number like 4 or 4.50.";
  const n = Number(t);
  if (n > 1000) return "Use a rate of 1000 or less.";
  return null;
}

/** U-078 / U-079: required fields per type, phone for its country, email shape. */
export function rowProblems(r: DraftRow): RowErrors {
  const e: RowErrors = {};
  if (!r.firstName.trim()) e.firstName = "Add a first name.";
  if (!r.lastName.trim()) e.lastName = "Add a last name.";
  const minor = isMinorRow(r);
  const email = r.email.trim();
  if (!email && !minor) e.email = r.type === "student" ? "Add an email (an adult student needs one)." : "Add an email.";
  else if (email && !EMAIL_RE.test(email)) e.email = "This email doesn't look right.";
  const phone = phoneProblem(r.countryIso, r.phone);
  if (phone) e.phone = phone;
  if (isStaffType(r.type)) {
    const rate = hourlyRateProblem(r.hourlyRate);
    if (rate) e.hourlyRate = rate;
  }
  if (minor && !r.parentId) e.parent = "Pick the parent or guardian.";
  if (r.type === "student") {
    const sid = studentIdProblem(r.firstName, r.lastName);
    if (sid) e.studentId = sid;
  }
  return e;
}

/** Rows (by position) whose email repeats an earlier row's: the second account would be refused. */
export function repeatedEmails(rows: readonly DraftRow[]): Map<number, number> {
  const seen = new Map<string, number>();
  const out = new Map<number, number>();
  rows.forEach((r, i) => {
    const email = normalizeEmail(r.email);
    if (!email) return;
    const first = seen.get(email);
    if (first === undefined) seen.set(email, i);
    else out.set(i, first);
  });
  return out;
}

// ─── Payloads ──────────────────────────────────────────────────────────────

const TITLES: Record<NewUserType, string> = { admin: "Admin", teacher: "Teacher", student: "Student", parent: "Parent" };

export type CallPayload = Record<string, unknown>;

/** createUserWithEmail / one createMultipleUsers row for an admin, teacher or parent. */
export function accountPayload(r: DraftRow): CallPayload {
  const payload: CallPayload = {
    email: normalizeEmail(r.email),
    firstName: r.firstName.trim(),
    lastName: r.lastName.trim(),
    phoneNumber: toE164(r.countryIso, r.phone),
    countryCode: dialCodeOf(r.countryIso),
    userType: r.type,
    title: TITLES[r.type],
    kioskCode: r.kioskCode,
  };
  if (isStaffType(r.type) && r.hourlyRate.trim()) payload.hourlyRate = Number(r.hourlyRate.trim());
  return payload;
}

/** createStudentAccount / one createMultipleUsers row for a student. A minor's typed email is kept, as today (U-102). */
export function studentPayload(r: DraftRow): CallPayload {
  const email = normalizeEmail(r.email);
  return {
    userType: "student",
    firstName: r.firstName.trim(),
    lastName: r.lastName.trim(),
    phoneNumber: toE164(r.countryIso, r.phone),
    isAdultStudent: r.adult,
    ...(email ? { email } : {}),
    ...(r.parentId ? { guardianIds: [r.parentId] } : {}),
  };
}

export const payloadOf = (r: DraftRow) => (r.type === "student" ? studentPayload(r) : accountPayload(r));

// ─── Results ───────────────────────────────────────────────────────────────

export type RowOutcome =
  | { kind: "created"; userId: string; type: NewUserType; name: string; email: string; emailSent: boolean }
  | {
      kind: "student";
      userId: string;
      name: string;
      studentCode: string;
      adult: boolean;
      existing: boolean;
      guardianEmails: number;
      guardianEmailsSent: number;
    }
  | { kind: "failed"; name: string; reason: string };

type Data = Record<string, unknown>;
const rec = (v: unknown): Data => (v && typeof v === "object" && !Array.isArray(v) ? (v as Data) : {});
const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);

export const draftName = (r: DraftRow) => `${r.firstName.trim()} ${r.lastName.trim()}`.trim() || "This person";

/** A createStudentAccount result (on its own or inside a batch row) as an outcome. */
export function studentOutcome(r: DraftRow, data: unknown): RowOutcome {
  const d = rec(data);
  return {
    kind: "student",
    userId: str(d.studentId),
    name: draftName(r),
    studentCode: str(d.studentCode),
    adult: r.adult,
    existing: d.existing === true,
    guardianEmails: num(d.emailsToGuardians),
    guardianEmailsSent: num(d.emailsSent),
  };
}

export function accountOutcome(r: DraftRow, data: unknown): RowOutcome {
  const d = rec(data);
  return { kind: "created", userId: str(d.uid), type: r.type, name: draftName(r), email: normalizeEmail(r.email), emailSent: d.emailSent === true };
}

/** createMultipleUsers' answer, one outcome per row in row order. Rows the answer does not mention are reported as unknown. */
export function batchOutcomes(rows: readonly DraftRow[], data: unknown, reasonOf: (message: string) => string): RowOutcome[] {
  const d = rec(data);
  const byIndex = new Map<number, RowOutcome>();
  for (const entry of Array.isArray(d.results) ? d.results : []) {
    const e = rec(entry);
    const i = typeof e.index === "number" ? e.index : -1;
    const row = rows[i];
    if (!row) continue;
    byIndex.set(i, row.type === "student" ? studentOutcome(row, e.result) : accountOutcome(row, e.result));
  }
  for (const entry of Array.isArray(d.errors) ? d.errors : []) {
    const e = rec(entry);
    const i = typeof e.index === "number" ? e.index : -1;
    const row = rows[i];
    if (!row) continue;
    byIndex.set(i, { kind: "failed", name: draftName(row), reason: reasonOf(str(e.error)) });
  }
  return rows.map((row, i) => byIndex.get(i) ?? { kind: "failed", name: draftName(row), reason: "No answer came back for this person. Check the list before trying again." });
}

/** Server messages in the admin's words. */
export function createFailureReason(message: string): string {
  const m = message.trim();
  if (/already in use|email-already-exists|already exists/i.test(m)) return "This email already belongs to an account.";
  if (/improperly formatted|invalid-email/i.test(m)) return "This email doesn't look right.";
  if (/minor student needs a parent/i.test(m)) return "A minor needs a parent or guardian.";
  if (/Latin letters/i.test(m)) return "The Student ID uses the Latin letters of the name. Add the name in Latin letters.";
  if (/^Missing required fields/i.test(m)) return m.replace("firstName", "first name").replace("lastName", "last name") + ".";
  if (/Hourly rate/i.test(m)) return m;
  if (!m || /^internal$/i.test(m)) return "Something went wrong. Try again.";
  return m.endsWith(".") ? m : `${m}.`;
}

/** One line per person, saying exactly what happened and who was emailed. */
export function outcomeLine(o: RowOutcome): string {
  if (o.kind === "failed") return `${o.name}: not created. ${o.reason}`;
  if (o.kind === "created") {
    const type = TITLES[o.type].toLowerCase();
    return o.emailSent
      ? `${o.name} added as ${type === "admin" ? "an admin" : `a ${type}`}. Welcome email with their login sent to ${o.email}.`
      : `${o.name} added as ${type === "admin" ? "an admin" : `a ${type}`}, but the welcome email could not be sent, so they have no login details yet.`;
  }
  if (o.existing) return `${o.name} is already this parent's child (Student ID ${o.studentCode || "unknown"}). Nothing new was created.`;
  const id = o.studentCode ? `Student ID ${o.studentCode}` : "Student account created";
  if (o.adult) return `${o.name} added as an adult student, ${id}. No email is sent to adult students: give them this Student ID. Their password is under Show in their panel.`;
  if (o.guardianEmails === 0) return `${o.name} added, ${id}. The parent has no email, so no one was emailed. The password is under Show in the student's panel.`;
  if (o.guardianEmailsSent === o.guardianEmails) return `${o.name} added, ${id}. The login was emailed to the parent.`;
  if (o.guardianEmailsSent === 0) return `${o.name} added, ${id}, but the email to the parent could not be sent. The password is under Show in the student's panel.`;
  return `${o.name} added, ${id}. The login was emailed to ${o.guardianEmailsSent} of ${o.guardianEmails} guardians.`;
}

export const outcomeTone = (o: RowOutcome): "ok" | "warn" | "error" =>
  o.kind === "failed"
    ? "error"
    : (o.kind === "created" && !o.emailSent) || (o.kind === "student" && (o.existing || (!o.adult && o.guardianEmails > 0 && o.guardianEmailsSent < o.guardianEmails)))
      ? "warn"
      : "ok";

export function outcomeSummary(outcomes: readonly RowOutcome[]): string {
  const done = outcomes.filter((o) => o.kind !== "failed").length;
  const failed = outcomes.length - done;
  if (failed === 0) return outcomes.length === 1 ? "Done." : `All ${outcomes.length} done.`;
  if (done === 0) return outcomes.length === 1 ? "Not created." : `None of the ${outcomes.length} were created.`;
  return `${done} of ${outcomes.length} done, ${failed} not created.`;
}

/** The login note under a student row. */
export function loginNote(r: DraftRow, parentHasEmail: boolean | null): string {
  if (r.adult) return "No email is sent to adult students. Give them this Student ID; their password will be under Show in their panel.";
  if (!r.parentId) return "Pick the parent: they get this Student ID and a password by email.";
  if (parentHasEmail === false) return "This parent has no email, so no one is emailed. The password will be under Show in the student's panel.";
  return "The parent is emailed this Student ID and a password.";
}

// ─── Existing people for the duplicate check ───────────────────────────────

export function existingPeople(rows: readonly UserRow[]): ExistingPerson[] {
  return rows.map((r) => ({
    id: r.id,
    firstName: r.firstName,
    lastName: r.lastName,
    email: r.email,
    otherEmail: r.otherEmail,
    phone: r.phone,
    countryCode: r.countryCode,
    label: displayNameOf(r),
    typeLabel: typeInfo(r).label,
    isActive: r.isActive,
  }));
}

/** Every kiosk code already stored (Flutter checked `kiosk_code` with one read per code; the list already has them). */
export function takenKioskCodes(rows: readonly UserRow[]): Set<string> {
  const set = new Set<string>();
  for (const r of rows) if (r.kioskCode && r.kioskCode !== r.id) set.add(r.kioskCode);
  return set;
}

export const createLabel = (n: number) => (n === 1 ? "Create 1 user" : `Create ${n} users`);
