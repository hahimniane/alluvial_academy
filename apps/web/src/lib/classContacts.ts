/**
 * Phone contacts from the getClassContacts callable: a teacher's students with
 * their parents, a parent's children with their teachers, a student's own
 * teachers. Parsed defensively so a malformed entry is dropped, not rendered.
 */
export type ContactRelationship = "parent" | "student" | "teacher";

export type ClassContact = {
  name: string;
  relationship: ContactRelationship;
  phone: string;
  tel: string;
};

export type ClassContactGroup = {
  studentName: string;
  contacts: ClassContact[];
};

export type ClassContacts = {
  students: ClassContactGroup[];
  children: ClassContactGroup[];
  teachers: ClassContact[];
};

const RELATIONSHIPS = new Set<ContactRelationship>(["parent", "student", "teacher"]);

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function parseContact(raw: unknown): ClassContact | null {
  if (!raw || typeof raw !== "object") return null;
  const record = raw as Record<string, unknown>;
  const tel = text(record.tel).replace(/[^\d+]/g, "");
  const phone = text(record.phone) || tel;
  const relationship = text(record.relationship) as ContactRelationship;
  if (!tel || tel.replace(/\D/g, "").length < 6 || !RELATIONSHIPS.has(relationship)) return null;
  return { name: text(record.name), relationship, phone, tel };
}

function parseContacts(raw: unknown): ClassContact[] {
  return Array.isArray(raw) ? raw.map(parseContact).filter((c): c is ClassContact => c !== null) : [];
}

function parseGroups(raw: unknown): ClassContactGroup[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((g): g is Record<string, unknown> => !!g && typeof g === "object")
    .map((g) => ({ studentName: text(g.studentName), contacts: parseContacts(g.contacts) }));
}

export function parseClassContacts(raw: unknown): ClassContacts {
  const record = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : {};
  return {
    students: parseGroups(record.students),
    children: parseGroups(record.children),
    teachers: parseContacts(record.teachers),
  };
}

export function telHref(contact: Pick<ClassContact, "tel">): string {
  return `tel:${contact.tel}`;
}
