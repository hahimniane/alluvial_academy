import {
  Timestamp,
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";

/**
 * Pause every class for one student — or for a whole family at once, since a
 * trip usually takes all the siblings with it. Siblings are resolved through
 * `guardian_ids` on the student record (the production link; `parent_id` is
 * unused). Everything a pause touches is recorded as a batch so it can be
 * lifted again in a single action.
 */

const str = (v: unknown) => (typeof v === "string" ? v : v == null ? "" : String(v));
const strArr = (v: unknown) => (Array.isArray(v) ? v.map(str).filter(Boolean) : []);

export type FamilyStudent = {
  id: string;
  name: string;
  /** student_code / kiosk_code — names repeat, so this is what identifies them. */
  code: string;
  guardianIds: string[];
};

export type Guardian = { id: string; name: string };

export type StudentFamily = {
  guardians: Guardian[];
  /** The picked student plus everyone sharing a guardian with them. */
  members: FamilyStudent[];
};

function toStudent(id: string, d: Record<string, unknown>): FamilyStudent {
  const name = [str(d.first_name), str(d.last_name)].filter(Boolean).join(" ") || str(d["e-mail"]) || id;
  return {
    id,
    name,
    code: str(d.student_code) || str(d.kiosk_code),
    guardianIds: strArr(d.guardian_ids),
  };
}

/** The student's family: their guardians and every child under those guardians. */
export async function loadStudentFamily(studentId: string): Promise<StudentFamily> {
  const snap = await getDoc(doc(db, "users", studentId));
  if (!snap.exists()) return { guardians: [], members: [] };
  const self = toStudent(snap.id, snap.data() as Record<string, unknown>);
  if (self.guardianIds.length === 0) return { guardians: [], members: [self] };

  const byId = new Map<string, FamilyStudent>([[self.id, self]]);
  for (const guardianId of self.guardianIds) {
    const siblings = await getDocs(
      query(collection(db, "users"), where("guardian_ids", "array-contains", guardianId)),
    );
    siblings.forEach((docSnap) => {
      const data = docSnap.data() as Record<string, unknown>;
      if (str(data.user_type) !== "student") return;
      if (data.is_active === false) return;
      byId.set(docSnap.id, toStudent(docSnap.id, data));
    });
  }

  const guardians: Guardian[] = [];
  for (const guardianId of self.guardianIds) {
    const g = await getDoc(doc(db, "users", guardianId));
    if (!g.exists()) continue;
    const gd = g.data() as Record<string, unknown>;
    guardians.push({
      id: g.id,
      name: [str(gd.first_name), str(gd.last_name)].filter(Boolean).join(" ") || str(gd["e-mail"]) || g.id,
    });
  }

  return {
    guardians,
    members: [...byId.values()].sort((a, b) => a.name.localeCompare(b.name)),
  };
}

export type PausePreview = {
  /** Series that will be paused (every one of their students is going away). */
  templates: { id: string; teacherName: string; studentNames: string[]; time: string }[];
  /** Hand-made classes that will be cancelled. */
  oneOffs: { id: string; start: Date; title: string; teacherName: string }[];
  /** Classes shared with children who are NOT away — deliberately left running. */
  shared: { id: string; start: Date; title: string; teacherName: string; otherStudents: string[] }[];
};

function dayKey(date: Date, zone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" }).format(
    date,
  );
}

/**
 * What a pause would do, before doing it. A class is only paused when EVERY
 * student on it is in the pause set — a class shared with a sibling who is
 * staying keeps running, and is reported so the admin can see why.
 */
export async function previewFamilyPause(
  studentIds: string[],
  startDay: string,
  endDay: string,
  zone: string,
): Promise<PausePreview> {
  const selected = new Set(studentIds);
  const lastDay = endDay || startDay;
  const preview: PausePreview = { templates: [], oneOffs: [], shared: [] };
  if (selected.size === 0 || !startDay) return preview;

  // Templates whose roster is fully inside the pause set.
  const templateSnap = await getDocs(collection(db, "shift_templates"));
  templateSnap.forEach((docSnap) => {
    const d = docSnap.data() as Record<string, unknown>;
    if (d.is_active === false) return;
    const ids = strArr(d.student_ids);
    if (ids.length === 0 || !ids.some((id) => selected.has(id))) return;
    if (!ids.every((id) => selected.has(id))) return; // shared — leave running
    preview.templates.push({
      id: docSnap.id,
      teacherName: str(d.teacher_name),
      studentNames: strArr(d.student_names),
      time: `${str(d.start_time)}–${str(d.end_time)}`,
    });
  });

  // Individual classes in the window, for each selected student.
  const seen = new Set<string>();
  for (const studentId of studentIds) {
    const snap = await getDocs(
      query(collection(db, "teaching_shifts"), where("student_ids", "array-contains", studentId)),
    );
    snap.forEach((docSnap) => {
      if (seen.has(docSnap.id)) return;
      const d = docSnap.data() as Record<string, unknown>;
      if (str(d.status).toLowerCase() !== "scheduled") return;
      const start = (d.shift_start as { toDate?: () => Date })?.toDate?.();
      if (!start) return;
      // Never reach into the past: a class that already started is a record.
      if (start <= new Date()) return;
      const key = dayKey(start, zone);
      if (key < startDay || key > lastDay) return;
      seen.add(docSnap.id);
      const ids = strArr(d.student_ids);
      const names = strArr(d.student_names);
      const row = {
        id: docSnap.id,
        start,
        title: str(d.custom_name) || str(d.auto_generated_name) || str(d.subject_display_name) || "Class",
        teacherName: str(d.teacher_name),
      };
      if (!ids.every((id) => selected.has(id))) {
        preview.shared.push({
          ...row,
          otherStudents: names.filter((_, i) => !selected.has(ids[i] ?? "")),
        });
        return;
      }
      preview.oneOffs.push(row);
    });
  }
  preview.oneOffs.sort((a, b) => a.start.getTime() - b.start.getTime());
  preview.shared.sort((a, b) => a.start.getTime() - b.start.getTime());
  return preview;
}

export type PauseBatch = {
  id: string;
  studentNames: string[];
  studentCodes: string[];
  startDay: string;
  endDay: string;
  templateIds: string[];
  shiftIds: string[];
  createdBy: string;
  createdAt: Date | null;
  liftedAt: Date | null;
};

/** Noon in `zone` on that calendar day — unambiguous across every DST rule. */
function dayInstant(day: string, zone: string): string {
  const [y, m, d] = day.split("-").map(Number);
  const guess = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
  const seen = dayKey(guess, zone);
  if (seen === day) return guess.toISOString();
  return new Date(guess.getTime() + (seen < day ? 1 : -1) * 24 * 3600e3).toISOString();
}

/**
 * Apply the break: pause the fully-affected templates for the window and
 * cancel the individual classes. Records one batch so the whole thing can be
 * lifted later in a single click.
 */
export async function applyFamilyPause(input: {
  students: FamilyStudent[];
  startDay: string;
  endDay: string;
  zone: string;
  preview: PausePreview;
  adminName: string;
  onProgress?: (done: number, total: number) => void;
}): Promise<string> {
  const { students, startDay, endDay, zone, preview, adminName, onProgress } = input;
  const total = preview.templates.length + preview.oneOffs.length;
  let done = 0;
  if (!startDay) throw new Error("Pick the first day of the break.");
  if (endDay && endDay < startDay) throw new Error("The break has to end on or after it starts.");

  const batchRef = await addDoc(collection(db, "shift_pause_batches"), {
    student_ids: students.map((s) => s.id),
    student_names: students.map((s) => s.name),
    student_codes: students.map((s) => s.code),
    start_day: startDay,
    end_day: endDay || null,
    timezone: zone,
    template_ids: preview.templates.map((t) => t.id),
    shift_ids: preview.oneOffs.map((s) => s.id),
    created_by_name: adminName,
    created_at: serverTimestamp(),
    lifted_at: null,
  });

  const call = httpsCallable(functions, "updateShiftTemplate");
  for (const template of preview.templates) {
    onProgress?.(done, total);
    await call({
      templateId: template.id,
      pause_start: dayInstant(startDay, zone),
      pause_end: endDay ? dayInstant(endDay, zone) : null,
    });
    done += 1;
  }

  for (const shift of preview.oneOffs) {
    onProgress?.(done, total);
    await updateDoc(doc(db, "teaching_shifts", shift.id), {
      status: "cancelled",
      pre_pause_status: "scheduled",
      pause_batch_id: batchRef.id,
      paused_at: serverTimestamp(),
      paused_by_name: adminName,
      cancellation_reason: "Paused for a scheduled break",
      last_modified: serverTimestamp(),
    });
    done += 1;
  }
  return batchRef.id;
}

/** Breaks that are still in force, newest first. */
export async function loadPauseBatches(): Promise<PauseBatch[]> {
  const snap = await getDocs(query(collection(db, "shift_pause_batches"), orderBy("created_at", "desc")));
  const rows: PauseBatch[] = [];
  snap.forEach((docSnap) => {
    const d = docSnap.data() as Record<string, unknown>;
    rows.push({
      id: docSnap.id,
      studentNames: strArr(d.student_names),
      studentCodes: strArr(d.student_codes),
      startDay: str(d.start_day),
      endDay: str(d.end_day),
      templateIds: strArr(d.template_ids),
      shiftIds: strArr(d.shift_ids),
      createdBy: str(d.created_by_name),
      createdAt: (d.created_at as { toDate?: () => Date })?.toDate?.() ?? null,
      liftedAt: (d.lifted_at as { toDate?: () => Date })?.toDate?.() ?? null,
    });
  });
  return rows.filter((row) => !row.liftedAt);
}

/** Undo a break: templates generate again and cancelled classes come back. */
export async function liftPauseBatch(
  batchId: string,
  onProgress?: (done: number, total: number) => void,
): Promise<void> {
  const snap = await getDoc(doc(db, "shift_pause_batches", batchId));
  if (!snap.exists()) throw new Error("That break no longer exists.");
  const d = snap.data() as Record<string, unknown>;
  const call = httpsCallable(functions, "updateShiftTemplate");
  const templateIds = strArr(d.template_ids);
  const shiftIds = strArr(d.shift_ids);
  const total = templateIds.length + shiftIds.length;
  let done = 0;
  for (const templateId of templateIds) {
    onProgress?.(done, total);
    await call({ templateId, pause_start: null, pause_end: null }).catch(() => {});
    done += 1;
  }
  for (const shiftId of shiftIds) {
    onProgress?.(done, total);
    done += 1;
    const shiftSnap = await getDoc(doc(db, "teaching_shifts", shiftId));
    if (!shiftSnap.exists()) continue;
    const sd = shiftSnap.data() as Record<string, unknown>;
    if (str(sd.status).toLowerCase() !== "cancelled") continue;
    await updateDoc(shiftSnap.ref, {
      status: str(sd.pre_pause_status) || "scheduled",
      pause_batch_id: null,
      pre_pause_status: null,
      cancellation_reason: null,
      last_modified: serverTimestamp(),
    });
  }
  await updateDoc(snap.ref, { lifted_at: serverTimestamp() });
}

export const _internal = { dayKey, dayInstant, Timestamp };
