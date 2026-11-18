/**
 * "This person may already be here" (F3): before new accounts are created,
 * the people typed are compared with everyone the Users page already holds
 * (its one live listener has every user's name, email and phone), so the
 * check costs no extra reads.
 *
 * Matching is deliberately loose, because it only warns: a name matches with
 * accents, case, spacing and punctuation ignored and in either order; a phone
 * matches in any of the shapes numbers are stored in; an email matches
 * without case or surrounding spaces.
 */

import { storedPhoneForms } from "./phoneNumbers.ts";

/** Letters and digits only, accents dropped, lower case. Non-Latin letters are kept. */
export function normalizePersonName(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]/gu, "");
}

/** First + last as one key, so "Mamadou Saliou | Diallo" equals "Mamadou | Saliou Diallo". */
export function personNameKeys(firstName: string, lastName: string): string[] {
  const first = normalizePersonName(firstName);
  const last = normalizePersonName(lastName);
  if (!first || !last) return [];
  return [...new Set([first + last, last + first])];
}

export const normalizeEmail = (value: string): string => value.trim().toLowerCase();

export type ExistingPerson = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  /** The `email` field some documents carry beside `e-mail`. */
  otherEmail: string;
  phone: string;
  countryCode: string;
  label: string;
  typeLabel: string;
  isActive: boolean;
};

export type NewPerson = { firstName: string; lastName: string; email: string; phoneE164: string };

export type MatchReason = "name" | "email" | "phone";

export type DuplicateMatch = { id: string; label: string; typeLabel: string; isActive: boolean; detail: string; reasons: MatchReason[] };

export type DuplicateIndex = {
  byName: Map<string, ExistingPerson[]>;
  byEmail: Map<string, ExistingPerson[]>;
  byPhone: Map<string, ExistingPerson[]>;
  byTail: Map<string, ExistingPerson[]>;
};

const add = (map: Map<string, ExistingPerson[]>, key: string, person: ExistingPerson) => {
  if (!key) return;
  const list = map.get(key);
  if (!list) map.set(key, [person]);
  else if (!list.includes(person)) list.push(person);
};

const TAIL = 9;
const tailOf = (e164: string) => {
  const digits = e164.replace(/\D/g, "");
  return digits.length >= TAIL ? digits.slice(-TAIL) : "";
};

/** One pass over everyone, so each check is a few map lookups. */
export function buildDuplicateIndex(people: readonly ExistingPerson[]): DuplicateIndex {
  const index: DuplicateIndex = { byName: new Map(), byEmail: new Map(), byPhone: new Map(), byTail: new Map() };
  for (const person of people) {
    for (const key of personNameKeys(person.firstName, person.lastName)) add(index.byName, key, person);
    add(index.byEmail, normalizeEmail(person.email), person);
    add(index.byEmail, normalizeEmail(person.otherEmail), person);
    for (const form of storedPhoneForms(person.phone, person.countryCode)) {
      add(index.byPhone, form, person);
      add(index.byTail, tailOf(form), person);
    }
  }
  return index;
}

const REASON_ORDER: MatchReason[] = ["email", "phone", "name"];

/** Existing people who look like this new person, strongest match first. */
export function findDuplicates(person: NewPerson, index: DuplicateIndex, limit = 5): DuplicateMatch[] {
  const found = new Map<string, { person: ExistingPerson; reasons: Set<MatchReason> }>();
  const note = (list: ExistingPerson[] | undefined, reason: MatchReason) => {
    for (const p of list ?? []) {
      const hit = found.get(p.id) ?? { person: p, reasons: new Set<MatchReason>() };
      hit.reasons.add(reason);
      found.set(p.id, hit);
    }
  };
  const email = normalizeEmail(person.email);
  if (email) note(index.byEmail.get(email), "email");
  if (person.phoneE164) {
    note(index.byPhone.get(person.phoneE164), "phone");
    const tail = tailOf(person.phoneE164);
    if (tail) note(index.byTail.get(tail), "phone");
  }
  for (const key of personNameKeys(person.firstName, person.lastName)) note(index.byName.get(key), "name");

  const score = (reasons: Set<MatchReason>) => (reasons.has("email") ? 4 : 0) + (reasons.has("phone") ? 2 : 0) + (reasons.has("name") ? 1 : 0);
  return [...found.values()]
    .sort((a, b) => score(b.reasons) - score(a.reasons) || a.person.label.localeCompare(b.person.label))
    .slice(0, limit)
    .map(({ person: p, reasons }) => ({
      id: p.id,
      label: p.label,
      typeLabel: p.typeLabel,
      isActive: p.isActive,
      detail: [p.email || p.otherEmail, p.phone].filter(Boolean).join(" · "),
      reasons: REASON_ORDER.filter((r) => reasons.has(r)),
    }));
}

export function reasonText(reasons: readonly MatchReason[]): string {
  const words = reasons.map((r) => (r === "email" ? "same email" : r === "phone" ? "same phone" : "same name"));
  return words.join(", ");
}
