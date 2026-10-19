/**
 * Finding the account a student already has.
 *
 * Many applicants are already students: a sibling's application, a child who
 * moved teacher, a family class set up by hand. Creating an account for them
 * makes a second login, so the card offers the accounts whose names match the
 * application and lets the admin pick the right one. Names are compared
 * without case, accents or punctuation. The first name must match exactly —
 * Amadou and Mamadou are different children — but one typo is allowed in the
 * other parts ("Dialo" finds "Diallo"), because applications are typed by
 * parents.
 */

export type StudentCandidate = { id: string; displayName: string; studentCode: string };

export const nameTokens = (value: string): string[] =>
  value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .split(/[^a-z]+/)
    .filter(Boolean);

/** At most one insertion, deletion or substitution apart. */
const nearlySame = (a: string, b: string): boolean => {
  if (a === b) return true;
  if (Math.min(a.length, b.length) < 4 || Math.abs(a.length - b.length) > 1) return false;
  let i = 0;
  let j = 0;
  let edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) {
      i += 1;
      j += 1;
      continue;
    }
    edits += 1;
    if (edits > 1) return false;
    if (a.length > b.length) i += 1;
    else if (b.length > a.length) j += 1;
    else {
      i += 1;
      j += 1;
    }
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
};

/** How well an account's name fits the application's; 0 means it does not. */
export const nameScore = (applicationName: string, accountName: string): number => {
  const wanted = nameTokens(applicationName);
  const theirs = nameTokens(accountName);
  if (!wanted.length || !theirs.length) return 0;
  if (wanted.join(" ") === theirs.join(" ")) return 100;
  const found = (token: string) => theirs.some((t) => nearlySame(token, t));
  if (!theirs.includes(wanted[0])) return 0;
  if (wanted.length === 1) return 40;
  const rest = wanted.slice(1);
  const matched = rest.filter(found).length;
  if (matched === rest.length) return 90;
  if (matched > 0) return 70;
  return 0;
};

/**
 * The accounts worth offering, best first. A typed search narrows by name or
 * student code instead, so the admin can still find a child whose account was
 * spelled differently.
 */
export const rankStudentMatches = <T extends StudentCandidate>(
  applicationName: string,
  students: T[],
  search = "",
  limit = 8,
): T[] => {
  const typed = nameTokens(search);
  const scored = students
    .map((student) => {
      if (typed.length) {
        const haystack = nameTokens(`${student.displayName} ${student.studentCode}`);
        const hit = typed.every((token) => haystack.some((t) => t.startsWith(token)));
        return { student, score: hit ? 1 + nameScore(applicationName, student.displayName) : 0 };
      }
      return { student, score: nameScore(applicationName, student.displayName) };
    })
    .filter((row) => row.score > 0)
    .sort((a, b) => b.score - a.score || a.student.displayName.localeCompare(b.student.displayName));
  return scored.slice(0, limit).map((row) => row.student);
};
