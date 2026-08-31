import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

/**
 * Subject management, ported from the Flutter SubjectService +
 * SubjectManagementDialog: admins add/edit/retire the subjects that shifts are
 * scheduled against, each with an optional default hourly wage that prefills
 * the shift editor.
 */

export type SubjectRecord = {
  id: string;
  /** Internal slug — generated from the display name, unique. */
  name: string;
  displayName: string;
  arabicName: string;
  description: string;
  defaultWage: number | null;
  sortOrder: number;
  isActive: boolean;
};

const str = (v: unknown) => (typeof v === "string" ? v : v == null ? "" : String(v));
const numOrNull = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : null);

function toRecord(id: string, data: Record<string, unknown>): SubjectRecord {
  const name = str(data.name) || id;
  return {
    id,
    name,
    displayName: str(data.displayName) || str(data.display_name) || name,
    arabicName: str(data.arabicName),
    description: str(data.description),
    defaultWage: numOrNull(data.defaultWage),
    sortOrder: typeof data.sortOrder === "number" ? data.sortOrder : 0,
    isActive: data.isActive !== false && data.is_active !== false,
  };
}

/** Every subject, including retired ones (the manager shows both). */
export async function loadAllSubjects(): Promise<SubjectRecord[]> {
  const snap = await getDocs(collection(db, "subjects"));
  const rows: SubjectRecord[] = [];
  snap.forEach((docSnap) => rows.push(toRecord(docSnap.id, docSnap.data() as Record<string, unknown>)));
  return rows.sort((a, b) => a.sortOrder - b.sortOrder || a.displayName.localeCompare(b.displayName));
}

/** Slugify the display name and make it unique, exactly like Flutter does. */
async function uniqueInternalName(displayName: string): Promise<string> {
  let slug = displayName
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");
  if (!slug) slug = "subject";
  let candidate = slug;
  for (let i = 1; ; i += 1) {
    const dup = await getDocs(query(collection(db, "subjects"), where("name", "==", candidate), limit(1)));
    if (dup.empty) return candidate;
    candidate = `${slug}_${i}`;
  }
}

export type SubjectInput = {
  displayName: string;
  arabicName: string;
  description: string;
  defaultWage: number | null;
};

export async function addSubject(input: SubjectInput): Promise<string> {
  const displayName = input.displayName.trim();
  if (!displayName) throw new Error("Enter a subject name.");
  const existing = await loadAllSubjects();
  if (existing.some((s) => s.displayName.toLowerCase() === displayName.toLowerCase())) {
    throw new Error(`"${displayName}" already exists.`);
  }
  const maxSortOrder = existing.reduce((max, s) => Math.max(max, s.sortOrder), 0);
  const name = await uniqueInternalName(displayName);
  const ref = await addDoc(collection(db, "subjects"), {
    name,
    displayName,
    description: input.description.trim() || null,
    arabicName: input.arabicName.trim() || null,
    sortOrder: maxSortOrder + 1,
    defaultWage: input.defaultWage,
    isActive: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return ref.id;
}

export async function updateSubject(id: string, input: SubjectInput): Promise<void> {
  const displayName = input.displayName.trim();
  if (!displayName) throw new Error("Enter a subject name.");
  await updateDoc(doc(db, "subjects", id), {
    displayName,
    description: input.description.trim() || null,
    arabicName: input.arabicName.trim() || null,
    defaultWage: input.defaultWage,
    updatedAt: serverTimestamp(),
  });
}

/** Retire/restore a subject — retired ones disappear from the shift editor. */
export async function setSubjectActive(id: string, isActive: boolean): Promise<void> {
  await updateDoc(doc(db, "subjects", id), { isActive, updatedAt: serverTimestamp() });
}

export async function deleteSubject(id: string): Promise<void> {
  await deleteDoc(doc(db, "subjects", id));
}
