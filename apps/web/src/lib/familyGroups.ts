/**
 * Applications that are one class.
 *
 * "Exclusive family class" means only this family's children, taught
 * together. Enrollment writes one document per student per program, so a
 * family class arrives as several documents that describe a single class —
 * and shown separately they invite exactly the wrong thing: two broadcasts,
 * two teachers, two timetables for children who are meant to sit together.
 *
 * Grouping is deliberately narrow. Documents join only when they came from
 * the same submission, name the same program, and both say the class is
 * exclusive to the family. Siblings enrolled separately, or in different
 * programs, stay separate — because they are.
 */

export type GroupableApplicant = {
  id: string;
  parentLinkId: string;
  classType: string;
  subject: string;
  studentName: string;
};

export const FAMILY_CLASS_TYPE = "Exclusive Family Class";

export type ApplicantGroup<T> = {
  /** Stable across reloads: the shared submission and program, or the id. */
  key: string;
  members: T[];
  /** The document the card acts through for anything single-valued. */
  primary: T;
  /** More than one child in one class — the card says so and acts on all. */
  isFamilyClass: boolean;
  studentNames: string[];
};

const familyKey = (a: GroupableApplicant): string | null => {
  if (a.classType !== FAMILY_CLASS_TYPE) return null;
  const link = a.parentLinkId.trim();
  if (!link) return null;
  return `${link}::${a.subject.trim().toLowerCase()}`;
};

/**
 * Groups in the order members first appear, so whatever sort produced the
 * list still reads correctly.
 */
export const groupApplicants = <T extends GroupableApplicant>(applicants: T[]): ApplicantGroup<T>[] => {
  const byKey = new Map<string, T[]>();
  const order: string[] = [];

  for (const applicant of applicants) {
    const key = familyKey(applicant) ?? `solo::${applicant.id}`;
    const existing = byKey.get(key);
    if (existing) existing.push(applicant);
    else {
      byKey.set(key, [applicant]);
      order.push(key);
    }
  }

  return order.map((key) => {
    const members = byKey.get(key)!;
    return {
      key,
      members,
      primary: members[0],
      // A family class with one child in it is just a class.
      isFamilyClass: members.length > 1,
      studentNames: members.map((m) => m.studentName),
    };
  });
};

/** "test 1 and test 2", "a, b and c" — for the card heading and job posting. */
export const listNames = (names: string[]): string => {
  const clean = names.map((n) => n.trim()).filter(Boolean);
  if (clean.length === 0) return "";
  if (clean.length === 1) return clean[0];
  return `${clean.slice(0, -1).join(", ")} and ${clean[clean.length - 1]}`;
};

/** Every document the card's actions must apply to. */
export const groupIds = <T extends GroupableApplicant>(group: ApplicantGroup<T>): string[] =>
  group.members.map((m) => m.id);
