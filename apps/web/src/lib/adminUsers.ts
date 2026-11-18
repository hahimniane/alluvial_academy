/**
 * Rules for the admin Users page, ported from the Flutter screen
 * (lib/features/user_management/screens/user_management_screen.dart,
 * lib/core/models/employee_model.dart). Pure so they can be tested without
 * Firestore; the page and its data hooks only wire them up.
 *
 * Sensitive: a user document is read field by field into a UserRow. Nothing
 * else of the document is kept, so a stored password or any other field that
 * is not listed here never reaches React state.
 */

import {
  EMAIL_KEYS,
  FIRST_NAME_KEYS,
  ID_KEYS,
  LAST_NAME_KEYS,
  NAME_KEYS,
  PHONE_KEYS,
  appSearchMatches,
  digitsOnly,
  firstTextValue,
  searchFieldsOfMap,
  type SearchFields,
} from "./appSearch.ts";

type Data = Record<string, unknown>;

// ─── Values ────────────────────────────────────────────────────────────────

/** Text of a value that should be a string; numbers are kept as text, anything else is empty. */
const text = (value: unknown): string => {
  if (typeof value === "string") return value;
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  return "";
};

type TimestampLike = { seconds: number; nanoseconds: number; toDate: () => Date };

const isTimestamp = (value: unknown): value is TimestampLike =>
  !!value &&
  typeof value === "object" &&
  typeof (value as TimestampLike).toDate === "function" &&
  typeof (value as TimestampLike).seconds === "number" &&
  typeof (value as TimestampLike).nanoseconds === "number";

const pad = (n: number, width: number) => String(n).padStart(width, "0");

/**
 * Dart `DateTime.toString()` in the viewer's time zone, which is what Flutter
 * shows and exports for a Firestore Timestamp: `2026-11-15 14:03:22.123`, plus
 * three more digits when the value has microseconds.
 */
export function dartDateTimeText(date: Date, microsecond = 0): string {
  const y = date.getFullYear();
  const year = y >= 0 && y < 10000 ? pad(y, 4) : String(y);
  const us = microsecond === 0 ? "" : pad(microsecond, 3);
  return (
    `${year}-${pad(date.getMonth() + 1, 2)}-${pad(date.getDate(), 2)} ` +
    `${pad(date.getHours(), 2)}:${pad(date.getMinutes(), 2)}:${pad(date.getSeconds(), 2)}.${pad(date.getMilliseconds(), 3)}${us}`
  );
}

/** Employee.formatTimestamp: a Timestamp as Dart text, missing as "Never", anything else as its text. */
export function storedDateText(value: unknown): string {
  if (isTimestamp(value)) {
    const micro = Math.floor(value.nanoseconds / 1000) % 1000;
    return dartDateTimeText(value.toDate(), micro);
  }
  if (value === null || value === undefined) return "Never";
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return String(value);
}

const dateOf = (value: unknown): Date | null => {
  if (!isTimestamp(value)) return null;
  const d = value.toDate();
  return Number.isNaN(d.getTime()) ? null : d;
};

/** Employee._parseTimestamp: a Timestamp or an ISO-like string. */
const looseDateOf = (value: unknown): Date | null => {
  const d = dateOf(value);
  if (d) return d;
  if (typeof value === "string" && value.trim()) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
};

const firstText = (data: Data, keys: readonly string[]): string => {
  for (const key of keys) {
    const v = data[key];
    if (v !== undefined && v !== null) return String(v);
  }
  return "";
};

const stringList = (value: unknown): string[] =>
  Array.isArray(value) ? value.map((v) => (v === null || v === undefined ? "" : String(v).trim())).filter(Boolean) : [];

const unionLists = (...lists: string[][]): string[] => [...new Set(lists.flat())];

// ─── Rows ──────────────────────────────────────────────────────────────────

export type ParentPickFields = {
  /** buildParentSearchRecord: stored name, else first + last. */
  name: string;
  email: string;
  search: SearchFields;
};

export type UserRow = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  /** The `email` field some documents carry beside `e-mail` (duplicate check only). */
  otherEmail: string;
  countryCode: string;
  phone: string;
  /** Raw `user_type`, as stored (case kept). */
  userType: string;
  title: string;
  /** `kiosk_code`, or the document id for a student without one (Flutter rule). */
  kioskCode: string;
  /** Students only: student_code → studentCode → student_id → kiosk code. */
  studentCode: string;
  /** `student_code` as stored, for the login email (no fallback). */
  storedStudentCode: string;
  dateAdded: Date | null;
  dateAddedText: string;
  lastLogin: Date | null;
  lastLoginText: string;
  isAdminTeacher: boolean;
  isActive: boolean;
  aiTutorEnabled: boolean;
  tontineEnabled: boolean;
  useZoom: boolean;
  zoomHostAccount: string;
  isAdultStudent: boolean;
  secondaryRoles: string[];
  guardianIds: string[];
  childrenIds: string[];
  firstClassAt: Date | null;
  /** `merged_into`: set on a duplicate student folded into another account. */
  mergedInto: string;
  /** Decision-history fallbacks (EditUserScreen's DecisionAuditFallback): who created / archived / restored, and when. */
  createdByUid: string;
  deactivatedByUid: string;
  deactivatedAt: Date | null;
  activatedByUid: string;
  activatedAt: Date | null;
  /** Only for documents whose user_type is exactly "parent". */
  parentPick: ParentPickFields | null;
};

const PARENT_PICK_KEYS: readonly string[] = [
  ...NAME_KEYS,
  ...FIRST_NAME_KEYS,
  ...LAST_NAME_KEYS,
  ...EMAIL_KEYS,
  ...PHONE_KEYS,
  ...ID_KEYS,
  "country_code",
  "countryCode",
];

/** parent_search.dart _withCountryCode. */
export function withCountryCode(countryCode: string, phone: string): string {
  if (!countryCode || !phone) return phone;
  const countryDigits = digitsOnly(countryCode);
  const phoneDigits = digitsOnly(phone);
  if (!countryDigits || phoneDigits.startsWith(countryDigits)) return phone;
  return `${countryCode}${phone}`;
}

function parentPickOf(id: string, data: Data): ParentPickFields {
  const record: Data = {};
  for (const key of PARENT_PICK_KEYS) if (data[key] !== undefined) record[key] = data[key];
  const firstName = firstTextValue(data, FIRST_NAME_KEYS);
  const lastName = firstTextValue(data, LAST_NAME_KEYS);
  const storedName = firstTextValue(data, NAME_KEYS);
  const email = firstTextValue(data, EMAIL_KEYS);
  const phone = firstTextValue(data, ["phone_number", "phoneNumber", "mobile_phone", "mobilePhone", "phone", "userPhone", "user_phone"]);
  const countryCode = firstTextValue(data, ["country_code", "countryCode"]);
  record.id = id;
  record.name = storedName || `${firstName} ${lastName}`.trim();
  record.email = email;
  record.phone_number = withCountryCode(countryCode, phone);
  return { name: String(record.name), email, search: searchFieldsOfMap(record, id) };
}

/** EmployeeDataSource.mapSnapshotToEmployeeList for one document, named fields only. */
export function mapUserDoc(id: string, data: Data): UserRow {
  const userType = text(data.user_type);
  const kioskRaw = text(data.kiosk_code);
  const kioskCode = userType === "student" && kioskRaw === "" ? id : kioskRaw;
  const storedStudentCode = text(data.student_code).trim();
  let studentCode = "";
  if (userType === "student") {
    const raw = data.student_code ?? data.studentCode ?? data.student_id;
    const code = raw === null || raw === undefined ? "" : String(raw).trim();
    studentCode = code || kioskCode;
  }
  const adult = data.is_adult_student ?? data.isAdultStudent;
  return {
    id,
    firstName: text(data.first_name),
    lastName: text(data.last_name),
    email: text(data["e-mail"]),
    otherEmail: text(data.email),
    countryCode: text(data.country_code),
    phone: text(data.phone_number),
    userType,
    title: text(data.title),
    kioskCode,
    studentCode,
    storedStudentCode,
    dateAdded: dateOf(data.date_added),
    dateAddedText: storedDateText(data.date_added),
    lastLogin: dateOf(data.last_login),
    lastLoginText: storedDateText(data.last_login),
    isAdminTeacher: data.is_admin_teacher === true,
    isActive: typeof data.is_active === "boolean" ? data.is_active : true,
    aiTutorEnabled: data.ai_tutor_enabled === true,
    tontineEnabled: data.tontine_enabled === true,
    useZoom: data.use_zoom === true,
    zoomHostAccount: String(data.zoom_host_account ?? data.zoomHostAccount ?? data.zoom_host_email ?? ""),
    isAdultStudent: adult === true,
    secondaryRoles: stringList(data.secondary_roles),
    guardianIds: unionLists(stringList(data.guardian_ids), stringList(data.guardianIds)),
    childrenIds: unionLists(stringList(data.children_ids), stringList(data.childrenIds)),
    firstClassAt: dateOf(data.first_class_at),
    mergedInto: text(data.merged_into),
    createdByUid: firstText(data, ["created_by_uid", "created_by", "createdBy", "created_by_admin_id"]),
    deactivatedByUid: firstText(data, ["deactivated_by_uid", "archived_by_uid", "archivedByUid"]),
    deactivatedAt: looseDateOf(data.deactivated_at ?? data.archived_at ?? data.archivedAt),
    activatedByUid: firstText(data, ["activated_by_uid", "restored_by_uid", "restoredByUid"]),
    activatedAt: looseDateOf(data.activated_at ?? data.restored_at ?? data.restoredAt),
    parentPick: userType === "parent" ? parentPickOf(id, data) : null,
  };
}

/** Field-by-field equality, so a snapshot that only touched unlisted fields (presence heartbeats) changes nothing. */
export function sameRow(a: UserRow, b: UserRow): boolean {
  for (const key of Object.keys(a) as (keyof UserRow)[]) {
    const x = a[key];
    const y = b[key];
    if (x === y) continue;
    if (x instanceof Date && y instanceof Date) {
      if (x.getTime() !== y.getTime()) return false;
      continue;
    }
    if (Array.isArray(x) && Array.isArray(y)) {
      if (x.length !== y.length || x.some((v, i) => v !== y[i])) return false;
      continue;
    }
    if (key === "parentPick" && x && y) {
      if (JSON.stringify(x) !== JSON.stringify(y)) return false;
      continue;
    }
    return false;
  }
  return true;
}

export const isStudentType = (row: UserRow) => row.userType.toLowerCase() === "student";

/** Admins tab: admin / super_admin, or an admin-teacher of any type. */
export function isAdminRow(row: UserRow): boolean {
  const type = row.userType.toLowerCase();
  return type === "admin" || type === "super_admin" || row.isAdminTeacher;
}

/** _displayNameForEmployee: full name → student code → email → id. */
export function displayNameOf(row: UserRow): string {
  const full = `${row.firstName} ${row.lastName}`.trim();
  if (full) return full;
  if (row.studentCode.trim()) return row.studentCode.trim();
  if (row.email.trim()) return row.email.trim();
  return row.id;
}

/** _hasNeverLoggedIn on the Last Login text. */
export function isNeverLoggedIn(row: Pick<UserRow, "lastLoginText">): boolean {
  const t = row.lastLoginText.trim().toLowerCase();
  return (
    t === "" ||
    t === "never" ||
    t === "n/a" ||
    t === "-" ||
    t === "null" ||
    t === "none" ||
    t.includes("null") ||
    t.includes("1970-01-01") ||
    t.startsWith("instance of")
  );
}

// ─── Parent links (U-007) ──────────────────────────────────────────────────

export type ParentLinks = {
  /** parent id → students whose guardian_ids/guardianIds name them (parents' children_ids are not used). */
  studentsByParent: Map<string, string[]>;
  /** student id → their FIRST guardian, as the Parent / Parent Email columns show. */
  firstParentByStudent: Map<string, { id: string; name: string; email: string }>;
};

/** _loadParentStudentRelationships, from the one live list instead of a second query. */
export function buildParentLinks(rows: readonly UserRow[]): ParentLinks {
  const byId = new Map(rows.map((r) => [r.id, r]));
  const studentsByParent = new Map<string, string[]>();
  const firstParentByStudent = new Map<string, { id: string; name: string; email: string }>();
  for (const student of rows) {
    if (student.userType !== "student") continue;
    for (const parentId of student.guardianIds) {
      const list = studentsByParent.get(parentId) ?? [];
      if (!list.includes(student.id)) list.push(student.id);
      studentsByParent.set(parentId, list);
      if (!firstParentByStudent.has(student.id)) {
        const parent = byId.get(parentId);
        firstParentByStudent.set(student.id, {
          id: parentId,
          name: parent ? displayNameOf(parent) : "",
          email: parent ? parent.email.trim() : "",
        });
      }
    }
  }
  return { studentsByParent, firstParentByStudent };
}

// ─── This week's classes (U-008, U-019) ────────────────────────────────────

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Monday 00:00 (viewer's time zone) to seven exact days later, as Flutter
 * computes it (`today.subtract(Duration(days: weekday - 1))`, `+ 7 days`).
 */
export function weekBounds(now: Date): { start: Date; end: Date } {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const daysSinceMonday = (now.getDay() + 6) % 7;
  const start = new Date(today.getTime() - daysSinceMonday * DAY_MS);
  return { start, end: new Date(start.getTime() + 7 * DAY_MS) };
}

const toDateLoose = (value: unknown): Date | null => {
  if (isTimestamp(value)) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
};

const toNumber = (value: unknown, fallback = 0): number => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const n = Number(value);
    if (Number.isFinite(n)) return n;
  }
  return fallback;
};

/** ShiftSessionAggregator.getScheduledHours. */
export function scheduledHours(data: Data): number {
  const start = toDateLoose(data.shift_start ?? data.start);
  const end = toDateLoose(data.shift_end ?? data.end);
  if (start && end && end.getTime() > start.getTime()) return Math.floor((end.getTime() - start.getTime()) / 1000) / 3600;
  const mins = toNumber(data.duration_minutes);
  if (mins > 0) return mins / 60;
  return toNumber(data.duration);
}

export type WeekShift = { studentIds: string[]; teacherName: string; hours: number; counts: boolean };

/** The few fields of a this-week shift the page uses. */
export function mapWeekShift(data: Data): WeekShift {
  const category = String(data.category ?? data.shift_category ?? "teaching").toLowerCase();
  const status = String(data.status ?? "").toLowerCase();
  const studentIds = Array.isArray(data.student_ids) ? data.student_ids.map((id) => String(id ?? "").trim()) : [];
  return {
    studentIds,
    teacherName: String(data.teacher_name ?? "").trim(),
    hours: scheduledHours(data),
    counts: category === "teaching" && status !== "cancelled",
  };
}

export type StudentWeek = { hours: number; teachers: string };

/** _loadStudentScheduleInfo: each student's share of this week's classes and their teachers. */
export function buildWeekSchedule(shifts: readonly WeekShift[]): Map<string, StudentWeek> {
  const hours = new Map<string, number>();
  const teachers = new Map<string, Set<string>>();
  for (const shift of shifts) {
    if (!shift.counts || shift.studentIds.length === 0 || shift.hours <= 0) continue;
    const ids = shift.studentIds.filter(Boolean);
    const share = ids.length > 0 ? shift.hours / ids.length : shift.hours;
    for (const id of ids) {
      hours.set(id, (hours.get(id) ?? 0) + share);
      if (shift.teacherName) {
        const set = teachers.get(id) ?? new Set<string>();
        set.add(shift.teacherName);
        teachers.set(id, set);
      }
    }
  }
  const out = new Map<string, StudentWeek>();
  for (const [id, h] of hours) out.set(id, { hours: h, teachers: [...(teachers.get(id) ?? [])].sort().join(", ") });
  return out;
}

/** _formatWeeklyHours: one decimal, none when whole, e.g. "3 hrs", "1.5 hrs"; blank when 0. */
export function weeklyHoursLabel(hours: number | undefined): string {
  if (hours === undefined || !(hours > 0)) return "";
  const rounded = Math.round(hours * 10) / 10;
  const whole = rounded === Math.round(rounded);
  return `${whole ? rounded.toFixed(0) : rounded.toFixed(1)} hrs`;
}

// ─── Enriched rows ─────────────────────────────────────────────────────────

export type ListRow = UserRow & {
  parentId: string;
  parentName: string;
  parentEmail: string;
  teacherNames: string;
  weeklyHours: number;
  weeklyHoursLabel: string;
};

/** _enrichWithScheduleInfo: Parent / Teacher / Weekly Hours for students, blank for everyone else. */
export function enrichRow(row: UserRow, links: ParentLinks, week: Map<string, StudentWeek>): ListRow {
  if (!isStudentType(row)) {
    return { ...row, parentId: "", parentName: "", parentEmail: "", teacherNames: "", weeklyHours: 0, weeklyHoursLabel: "" };
  }
  const parent = links.firstParentByStudent.get(row.id);
  const w = week.get(row.id);
  return {
    ...row,
    parentId: parent?.id ?? "",
    parentName: parent?.name ?? "",
    parentEmail: parent?.email ?? "",
    teacherNames: w?.teachers ?? "",
    weeklyHours: w?.hours ?? 0,
    weeklyHoursLabel: weeklyHoursLabel(w?.hours),
  };
}

// ─── Search and filters ────────────────────────────────────────────────────

/** _matchesSearchTerm. */
export function matchesUserSearch(row: UserRow, query: string): boolean {
  return appSearchMatches(query.toLowerCase(), {
    names: [`${row.firstName} ${row.lastName}`, `${row.lastName} ${row.firstName}`],
    emails: [row.email],
    phones: [row.phone, `${row.countryCode}${row.phone}`],
    ids: [row.id, row.studentCode, row.kioskCode],
    additionalValues: [row.userType, row.title],
  });
}

export type UsersTab = "users" | "admins";
export type TypeFilter = "all" | "teacher" | "student" | "parent";
export type KindFilter = "all" | "minor" | "adult";
export type StatusFilter = "any" | "active" | "archived" | "never";

export type UserFilters = {
  type: TypeFilter;
  kind: KindFilter;
  status: StatusFilter;
  parentId: string | null;
  search: string;
};

export const NO_FILTERS: UserFilters = { type: "all", kind: "all", status: "any", parentId: null, search: "" };

export const hasActiveFilters = (f: UserFilters): boolean =>
  f.type !== "all" || f.kind !== "all" || f.status !== "any" || f.parentId !== null || f.search.trim() !== "";

const statusMatches = (row: UserRow, status: StatusFilter): boolean => {
  if (status === "active") return row.isActive;
  if (status === "archived") return !row.isActive;
  if (status === "never") return isNeverLoggedIn(row);
  return true;
};

/**
 * _applyFilters with the design's combinable filters: type, minor/adult and
 * parent narrow the Users tab only; status and search narrow both tabs.
 * Rows keep their input order; sort afterwards.
 */
export function filterRows<T extends UserRow>(
  rows: readonly T[],
  filters: UserFilters,
  links: ParentLinks,
): { users: T[]; admins: T[] } {
  let users = rows.filter((r) => !isAdminRow(r));
  let admins = rows.filter((r) => isAdminRow(r));
  if (filters.type !== "all") users = users.filter((r) => r.userType.toLowerCase() === filters.type);
  if (filters.status !== "any") {
    users = users.filter((r) => statusMatches(r, filters.status));
    admins = admins.filter((r) => statusMatches(r, filters.status));
  }
  if (filters.parentId !== null) {
    const ids = links.studentsByParent.get(filters.parentId) ?? [];
    users = users.filter((r) => isStudentType(r) && ids.includes(r.id));
  }
  if (filters.type === "student" && filters.kind !== "all") {
    const wantAdult = filters.kind === "adult";
    users = users.filter((r) => isStudentType(r) && r.isAdultStudent === wantAdult);
  }
  if (filters.search.trim() !== "") {
    users = users.filter((r) => matchesUserSearch(r, filters.search));
    admins = admins.filter((r) => matchesUserSearch(r, filters.search));
  }
  return { users, admins };
}

/** Name order (A→Z or Z→A), ties by document id so the order never jumps. */
export function sortByName<T extends UserRow>(rows: readonly T[], ascending: boolean): T[] {
  const key = (r: UserRow) => displayNameOf(r).toLocaleLowerCase();
  return [...rows].sort((a, b) => {
    const c = key(a).localeCompare(key(b), undefined, { sensitivity: "base" }) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
    return ascending ? c : -c;
  });
}

// ─── Parent picker (U-031, U-032) ──────────────────────────────────────────

export type ParentChoice = { id: string; name: string; email: string; studentCount: number; isActive: boolean; search: SearchFields };

/** Parents for the picker: every `user_type == 'parent'` (archived too), most students first, then name. */
export function parentChoices(rows: readonly UserRow[], links: ParentLinks): ParentChoice[] {
  const out: ParentChoice[] = [];
  for (const row of rows) {
    if (!row.parentPick) continue;
    out.push({
      id: row.id,
      name: row.parentPick.name,
      email: row.parentPick.email,
      studentCount: links.studentsByParent.get(row.id)?.length ?? 0,
      isActive: row.isActive,
      search: row.parentPick.search,
    });
  }
  return out.sort((a, b) => b.studentCount - a.studentCount || compareDartStrings(a.name.toLowerCase(), b.name.toLowerCase()));
}

/** Dart String.compareTo: UTF-16 code unit order. */
const compareDartStrings = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

export const parentMatches = (choice: ParentChoice, query: string) => appSearchMatches(query, choice.search);

// ─── Export (U-029, U-030) ─────────────────────────────────────────────────

export const EXPORT_FILE_BASE = "employees";

export const EXPORT_HEADERS = [
  "First Name",
  "Last Name",
  "Email",
  "Mobile Phone",
  "User Type",
  "Student ID",
  "Kiosk Code",
  "Parent",
  "Parent Email",
  "Teacher",
  "Weekly Hours",
  "Date Added",
  "Last Login",
] as const;

export function exportRow(row: ListRow): string[] {
  return [
    row.firstName,
    row.lastName,
    row.email,
    row.phone,
    row.userType,
    row.studentCode,
    row.kioskCode,
    row.parentName,
    row.parentEmail,
    row.teacherNames,
    row.weeklyHoursLabel,
    row.dateAddedText,
    row.lastLoginText,
  ];
}

const csvField = (value: string): string => (/[",\r\n]/.test(value) ? `"${value.replace(/"/g, '""')}"` : value);

/** The csv package's ListToCsvConverter defaults: comma, double quotes only when needed, CRLF between rows, no BOM. */
export function toCsv(headers: readonly string[], rows: readonly string[][]): string {
  return [headers, ...rows].map((r) => r.map(csvField).join(",")).join("\r\n");
}

// ─── Display ───────────────────────────────────────────────────────────────

/** Phone with its country code, unless the number already starts with it. */
export function phoneDisplay(row: Pick<UserRow, "countryCode" | "phone">): string {
  const phone = row.phone.trim();
  if (!phone) return "";
  const cc = digitsOnly(row.countryCode);
  if (!cc || digitsOnly(phone).startsWith(cc) || phone.startsWith("+")) return phone;
  return `+${cc} ${phone}`;
}

export type TypeTone = "student" | "teacher" | "parent" | "admin" | "other";

export function typeInfo(row: UserRow): { label: string; tone: TypeTone } {
  const type = row.userType.toLowerCase();
  if (type === "student") return { label: row.isAdultStudent ? "Adult student" : "Student", tone: "student" };
  if (type === "teacher") return { label: "Teacher", tone: "teacher" };
  if (type === "parent") return { label: "Parent", tone: "parent" };
  if (type === "admin") return { label: "Admin", tone: "admin" };
  if (type === "super_admin") return { label: "Super admin", tone: "admin" };
  if (!type) return { label: "No type", tone: "other" };
  const words = row.userType.replace(/_/g, " ").trim();
  return { label: words.charAt(0).toUpperCase() + words.slice(1), tone: "other" };
}

export const adminTypeLabel = (row: UserRow) => (row.isAdminTeacher ? "Admin-teacher" : "Full admin");

export function initialsOf(row: UserRow): string {
  const a = row.firstName.trim().charAt(0);
  const b = row.lastName.trim().charAt(0);
  const both = `${a}${b}`.toUpperCase();
  return both || displayNameOf(row).charAt(0).toUpperCase() || "?";
}

const DATE_FMT = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" });
const SHORT_FMT = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" });

export const formatDay = (date: Date) => DATE_FMT.format(date);

/** Date column text: "Sep 4, 2026", the stored text for a value that is not a date, or "Never". */
export function dayOrText(date: Date | null, storedText: string): string {
  if (date) return formatDay(date);
  return storedText;
}

/** Card corner: "Today", "Nov 12", "Nov 12, 2025" for another year, or "Never". */
export function shortDay(date: Date | null, now: Date): string {
  if (!date) return "Never";
  if (date.toDateString() === now.toDateString()) return "Today";
  return date.getFullYear() === now.getFullYear() ? SHORT_FMT.format(date) : DATE_FMT.format(date);
}

export const STUDENT_LOGIN_DOMAIN = "alluwaleducationhub.org";

/** "Email (for app)" of the credentials dialog: student_code@domain, when a code is stored. */
export const loginEmailOf = (row: UserRow) => (row.storedStudentCode ? `${row.storedStudentCode}@${STUDENT_LOGIN_DOMAIN}` : "");

/** First class column: date of the first attended class, "Not yet" for a student without one. */
export const firstClassText = (row: UserRow) => (isStudentType(row) ? (row.firstClassAt ? formatDay(row.firstClassAt) : "Not yet") : "");

// ─── Cutover switch ────────────────────────────────────────────────────────

export const ADMIN_USERS_CUTOVER_DOC = { collection: "settings", id: "admin_users_web_cutover" } as const;

/**
 * settings/admin_users_web_cutover { mode: off | allowlist | all, adminIds }.
 * Fails closed: no document, an unknown mode or an empty uid keeps the admin
 * on the Flutter Users screen. Mirrors AdminUsersWebCutover.allows in Dart.
 */
export function adminUsersCutoverAllows(data: Data | null | undefined, uid: string): boolean {
  if (!data || !uid) return false;
  const mode = String(data.mode ?? "off").trim().toLowerCase();
  if (mode === "all") return true;
  if (mode !== "allowlist") return false;
  const ids = data.adminIds;
  return Array.isArray(ids) && ids.map(String).includes(uid);
}
