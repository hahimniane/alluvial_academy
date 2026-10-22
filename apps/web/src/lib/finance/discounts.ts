/**
 * Pure logic behind the finance Discounts & credits page: which discounts are
 * active in a month and what each costs per month, and the family credit rows.
 * Discount rules (windows, percent vs fixed, family scope) are the existing
 * helpers in lib/studentDiscount.ts; nothing here re-implements them.
 */

import { coversPeriod, discountAmountFor, discountLabel, readDiscount, type StudentDiscount } from "../studentDiscount.ts";
import { r2 } from "./model.ts";
import { monthName, monthShort } from "./months.ts";
import { toDate } from "./expenses.ts";

type Raw = Record<string, unknown>;
const record = (value: unknown): Raw => (value && typeof value === "object" ? (value as Raw) : {});
const text = (value: unknown): string => (typeof value === "string" ? value.trim() : "");
const strings = (value: unknown): string[] => (Array.isArray(value) ? value.filter((v): v is string => typeof v === "string" && v.length > 0) : []);

/* --------------------------------------------------------------- people -- */

export type DiscountHolder = {
  id: string;
  userType: string;
  name: string;
  parentIds: string[];
  childrenIds: string[];
  discount: StudentDiscount;
};

export const fullName = (data: Raw, fallback = ""): string =>
  [text(data.first_name ?? data.firstName), text(data.last_name ?? data.lastName)].filter(Boolean).join(" ") || fallback;

/** A users document that carries a usable discount, or null. */
export function readHolder(id: string, raw: unknown): DiscountHolder | null {
  const data = record(raw);
  const discount = readDiscount(data.discount);
  if (!discount) return null;
  return {
    id,
    userType: text(data.user_type ?? data.userType),
    name: fullName(data, id),
    parentIds: strings(data.parent_ids ?? data.parentIds),
    childrenIds: strings(data.children_ids ?? data.childrenIds),
    discount,
  };
}

/** The first day of a `yyyy-MM` month as a UTC date (what discount windows count from). */
export function periodStartOf(month: string): Date {
  const [y, m] = month.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, 1));
}

/* ---------------------------------------------------------------- bases -- */

/** What each student pays a month, and what each family pays, where known. */
export type BillingBases = {
  byStudent: Map<string, number>;
  byFamily: Map<string, number>;
};

/**
 * Bases from active recurring billing plans (`base_items` carry student ids).
 * A family's monthly amount (`family_billing`) wins when present: the family
 * total is that amount and each of its students is an equal share of it.
 */
export function buildBases(
  plans: { parentId: string; items: { studentId: string; total: number }[] }[],
  familyBilling: { parentId: string; monthlyAmount: number; studentIds: string[] }[],
): BillingBases {
  const byStudent = new Map<string, number>();
  const byFamily = new Map<string, number>();
  for (const plan of plans) {
    for (const item of plan.items) {
      if (item.studentId) byStudent.set(item.studentId, r2((byStudent.get(item.studentId) ?? 0) + item.total));
      byFamily.set(plan.parentId, r2((byFamily.get(plan.parentId) ?? 0) + item.total));
    }
  }
  for (const f of familyBilling) {
    if (!(f.monthlyAmount > 0)) continue;
    byFamily.set(f.parentId, r2(f.monthlyAmount));
    const share = r2(f.monthlyAmount / Math.max(1, f.studentIds.length));
    for (const id of f.studentIds) byStudent.set(id, share);
  }
  return { byStudent, byFamily };
}

/* ---------------------------------------------------------- active rows -- */

export type ActiveDiscountRow = {
  key: string;
  familyId: string;
  family: string;
  appliesTo: string;
  reason: string;
  kind: string;
  /** Null when a percentage has no known monthly amount to apply to. */
  perMonth: number | null;
};

/**
 * Discounts that cover `month`, with what each takes off a month.
 *
 * A student discount comes off that student's charge. A family discount comes
 * off once, against what the family pays after its students' own discounts.
 */
export function buildActiveDiscounts(input: {
  month: string;
  holders: DiscountHolder[];
  /** Names of parents (family names), by parent id. */
  parentNames: Map<string, string>;
  bases: BillingBases;
}): ActiveDiscountRow[] {
  const { month, holders, parentNames, bases } = input;
  const start = periodStartOf(month);
  // Billing reads a household discount only from the parent's record and a
  // student discount only from the child's, so the page lists the same ones.
  const billed = holders.filter((h) => (h.discount.scope === "family" ? h.userType === "parent" : h.userType !== "parent"));
  const active = billed.filter((h) => coversPeriod(h.discount, start));

  const familyOf = (h: DiscountHolder): string => (h.discount.scope === "family" ? h.id : h.parentIds[0] || h.id);
  const nameOf = (parentId: string, fallback: string): string => parentNames.get(parentId) || fallback;

  const studentOff = new Map<string, number>();
  const rows: ActiveDiscountRow[] = [];

  for (const h of active.filter((x) => x.discount.scope !== "family")) {
    const base = bases.byStudent.get(h.id);
    const perMonth = base !== undefined ? discountAmountFor(h.discount, base) : h.discount.mode === "fixed" ? h.discount.value : null;
    const familyId = familyOf(h);
    if (perMonth !== null) studentOff.set(familyId, r2((studentOff.get(familyId) ?? 0) + perMonth));
    rows.push({
      key: `student_${h.id}`,
      familyId,
      family: nameOf(familyId, h.name),
      appliesTo: h.name,
      reason: h.discount.reason,
      kind: discountLabel(h.discount),
      perMonth,
    });
  }

  for (const h of active.filter((x) => x.discount.scope === "family")) {
    const familyBase = bases.byFamily.get(h.id);
    const remaining = familyBase !== undefined ? Math.max(0, familyBase - (studentOff.get(h.id) ?? 0)) : undefined;
    const perMonth = remaining !== undefined ? discountAmountFor(h.discount, remaining) : h.discount.mode === "fixed" ? h.discount.value : null;
    const kids = h.childrenIds.length;
    rows.push({
      key: `family_${h.id}`,
      familyId: h.id,
      family: nameOf(h.id, h.name),
      appliesTo: kids > 0 ? `Whole family (${kids} ${kids === 1 ? "child" : "children"})` : "Whole family",
      reason: h.discount.reason,
      kind: discountLabel(h.discount),
      perMonth,
    });
  }

  return rows.sort((a, b) => a.family.localeCompare(b.family) || a.appliesTo.localeCompare(b.appliesTo));
}

export function discountsCostPerMonth(rows: ActiveDiscountRow[]): { total: number; families: number; unknown: number } {
  return {
    total: r2(rows.reduce((sum, r) => sum + (r.perMonth ?? 0), 0)),
    families: new Set(rows.map((r) => r.familyId)).size,
    unknown: rows.filter((r) => r.perMonth === null).length,
  };
}

/* -------------------------------------------------------------- credits -- */

export type CreditStatus = "open" | "used" | "refunded" | "cancelled";

export type CreditRow = {
  id: string;
  parentId: string;
  studentId: string;
  amount: number;
  reason: string;
  status: CreditStatus;
  createdAt: Date | null;
};

export function readCredit(id: string, raw: unknown): CreditRow {
  const data = record(raw);
  const status = text(data.status);
  return {
    id,
    parentId: text(data.parent_id),
    studentId: text(data.student_id),
    amount: r2(Number(data.amount) || 0),
    reason: text(data.reason),
    status: status === "used" || status === "refunded" || status === "cancelled" ? status : "open",
    createdAt: toDate(data.created_at),
  };
}

export const creditStatusLabel = (status: CreditStatus): string =>
  status === "open" ? "Waiting for next invoice" : status === "used" ? "Used on an invoice" : status === "refunded" ? "Refunded" : "Cancelled";

/** Open credits first (newest first), then the rest. */
export function sortCredits(credits: CreditRow[]): CreditRow[] {
  return [...credits].sort((a, b) => {
    const open = Number(b.status === "open") - Number(a.status === "open");
    return open || (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0);
  });
}

export function creditsOwed(credits: CreditRow[]): { total: number; families: number } {
  const open = credits.filter((c) => c.status === "open");
  return { total: r2(open.reduce((sum, c) => sum + c.amount, 0)), families: new Set(open.map((c) => c.parentId)).size };
}

/* ---------------------------------------------------------------- cards -- */

/** Discounts given from January of the year through `month`, from per-month totals. */
export function discountsYearToDate(byMonth: Record<string, number>, month: string): number {
  return r2(Object.entries(byMonth).reduce((sum, [m, amount]) => (m <= month ? sum + amount : sum), 0));
}

export function yearSoFarSub(month: string): string {
  return month.slice(5) === "01" ? monthName(month) : `Jan – ${monthShort(month).slice(0, 3)}`;
}
