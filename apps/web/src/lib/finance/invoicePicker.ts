/**
 * Pure rules for the New invoice dialog's month list and family search.
 */
import { addMonths } from "./months.ts";

/** How far back staff can bill: a family missed months ago can still be invoiced. */
export const MONTHS_BACK = 12;
export const MONTHS_AHEAD = 2;

export type MonthOption = { month: string; closed: boolean };

/** Newest first: the next two months, this month, then the past twelve. Closed months stay listed but can't be picked. */
export function invoiceMonthOptions(thisMonth: string, closed: ReadonlySet<string>, back = MONTHS_BACK, ahead = MONTHS_AHEAD): MonthOption[] {
  const out: MonthOption[] = [];
  for (let delta = ahead; delta >= -back; delta -= 1) {
    const month = addMonths(thisMonth, delta);
    out.push({ month, closed: closed.has(month) });
  }
  return out;
}

export type SearchableFamily = { id: string; name: string; email: string; phone: string; code: string };

export const digitsOf = (value: string) => value.replace(/\D/g, "");

/**
 * Families matching what staff typed: name or email anywhere, a phone number
 * by its digits (country code optional, 4+ digits), or a Student ID exactly.
 * `extraIds` are families found by a child's Student ID (looked up separately).
 */
export function matchFamilies<T extends SearchableFamily>(users: readonly T[], rawTerm: string, extraIds: ReadonlySet<string> = new Set(), max = 8): T[] {
  const term = rawTerm.trim().toLowerCase();
  if (!term) return [];
  const digits = digitsOf(term);
  const phoneSearch = digits.length >= 4 && digits.length >= term.replace(/[\s()+\-.]/g, "").length;
  const out: T[] = [];
  for (const u of users) {
    const text = `${u.name} ${u.email}`.toLowerCase().includes(term);
    const code = u.code !== "" && u.code.toLowerCase() === term;
    const phone = phoneSearch && u.phone !== "" && (u.phone.endsWith(digits) || digits.endsWith(u.phone) || u.phone.includes(digits));
    if (text || code || phone || extraIds.has(u.id)) out.push(u);
    if (out.length >= max) break;
  }
  return out;
}

/** Whether the text could be a Student ID worth an exact lookup (e.g. "amadou.diallo", "3boubacar.diallo"). */
export const looksLikeStudentCode = (term: string) => /^[a-z0-9][a-z0-9._-]{2,}$/i.test(term.trim()) && /[a-z]/i.test(term) && /[._\d]/.test(term);
