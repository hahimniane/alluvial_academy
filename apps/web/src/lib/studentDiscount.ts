/**
 * Student discounts: one per student, covering every program that student
 * takes, applied to each monthly invoice inside its window.
 *
 * Two things here are deliberate.
 *
 * **The window is anchored to a stored date, not an inferred one.** Nothing in
 * the data records when a student's enrollment starts — not on the user, not
 * on the enrollment. Rather than have billing code guess, the discount carries
 * its own `startDate`: the dialog proposes one from the best signal available
 * and shows it, and an admin can correct it before saving. A wrong guess here
 * would be wrong money.
 *
 * **Money is computed in whole cents.** Percentages on floats drift, and a
 * discount that renders as $19.99 on the invoice and 19.990000000000002 in the
 * total is a support ticket.
 */

export type DiscountMode = "percent" | "fixed";
export type DiscountDuration = "months" | "ongoing";

export const DISCOUNT_REASONS = [
  "Sibling discount",
  "Financial hardship",
  "Referral",
  "Returning family",
  "Promotion",
  "Other",
] as const;

export type DiscountReason = (typeof DISCOUNT_REASONS)[number];

export type StudentDiscount = {
  mode: DiscountMode;
  /** 20 means 20% when mode is percent, or $20 a month when fixed. */
  value: number;
  duration: DiscountDuration;
  /** Required when duration is "months". */
  months?: number;
  startDate: Date;
  reason: DiscountReason | string;
  note?: string;
};

/* ----------------------------------------------------------- validation -- */

export type DiscountDraft = {
  mode: DiscountMode;
  value: string;
  duration: DiscountDuration;
  months: string;
  startDate: string;
  reason: string;
  note: string;
};

export const emptyDiscountDraft = (startDate: Date): DiscountDraft => ({
  mode: "percent",
  value: "",
  duration: "months",
  months: "3",
  startDate: toDateInput(startDate),
  reason: DISCOUNT_REASONS[0],
  note: "",
});

/** The first problem with the draft, or null when it is savable. */
export const validateDiscount = (draft: DiscountDraft): string | null => {
  const value = Number(draft.value);
  if (!draft.value.trim() || !Number.isFinite(value)) return "Enter the discount amount.";
  if (value <= 0) return "The discount must be more than zero.";
  if (draft.mode === "percent" && value > 100) return "A percentage discount cannot be more than 100%.";

  if (draft.duration === "months") {
    const months = Number(draft.months);
    if (!draft.months.trim() || !Number.isFinite(months)) return "Enter how many months the discount lasts.";
    if (!Number.isInteger(months) || months <= 0) return "The number of months must be a whole number above zero.";
  }

  if (!draft.startDate.trim() || Number.isNaN(fromDateInput(draft.startDate).getTime())) {
    return "Enter the date the discount starts from.";
  }
  if (!draft.reason.trim()) return "Choose a reason for the discount.";
  return null;
};

export const draftToDiscount = (draft: DiscountDraft): StudentDiscount => ({
  mode: draft.mode,
  value: Number(draft.value),
  duration: draft.duration,
  ...(draft.duration === "months" ? { months: Number(draft.months) } : {}),
  startDate: fromDateInput(draft.startDate),
  reason: draft.reason.trim(),
  ...(draft.note.trim() ? { note: draft.note.trim() } : {}),
});

export const discountToDraft = (discount: StudentDiscount): DiscountDraft => ({
  mode: discount.mode,
  value: String(discount.value),
  duration: discount.duration,
  months: discount.months ? String(discount.months) : "3",
  startDate: toDateInput(discount.startDate),
  reason: discount.reason,
  note: discount.note ?? "",
});

/* ---------------------------------------------------------------- dates -- */

/** `yyyy-mm-dd` in UTC, so a date input never shifts a day across timezones. */
export const toDateInput = (date: Date): string => {
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
};

export const fromDateInput = (value: string): Date => new Date(`${value}T00:00:00.000Z`);

/**
 * Whole calendar months from one to the other, ignoring the day.
 *
 * Billing periods are month-granular, so the day a discount starts on must not
 * shift the window: comparing days would let a discount starting Aug 15 still
 * apply in November, a fourth month on a three-month discount.
 */
const monthsBetween = (from: Date, to: Date): number =>
  (to.getUTCFullYear() - from.getUTCFullYear()) * 12 + (to.getUTCMonth() - from.getUTCMonth());

/**
 * Whether a billing period is inside the discount window.
 *
 * A period counts as covered when it *begins* on or after the start date, so a
 * discount added mid-month starts with the next full billing period rather
 * than retroactively crediting one already issued.
 */
export const coversPeriod = (discount: StudentDiscount, periodStart: Date): boolean => {
  if (Number.isNaN(periodStart.getTime()) || Number.isNaN(discount.startDate.getTime())) return false;
  const elapsed = monthsBetween(discount.startDate, periodStart);
  if (elapsed < 0) return false;
  if (discount.duration === "ongoing") return true;
  const months = discount.months ?? 0;
  return months > 0 && elapsed < months;
};

/* ----------------------------------------------------------------- money -- */

const toCents = (amount: number): number => Math.round(amount * 100);

/**
 * What comes off a monthly total, in the invoice's own currency units.
 *
 * Never more than the total: a $30 discount on a $20 month brings it to zero
 * rather than issuing $10 of credit nobody asked for.
 */
export const discountAmountFor = (discount: StudentDiscount, monthlyTotal: number): number => {
  if (!Number.isFinite(monthlyTotal) || monthlyTotal <= 0) return 0;
  const totalCents = toCents(monthlyTotal);
  const rawCents =
    discount.mode === "percent"
      ? Math.round((totalCents * discount.value) / 100)
      : toCents(discount.value);
  return Math.min(Math.max(rawCents, 0), totalCents) / 100;
};

/* ---------------------------------------------------------------- labels -- */

const formatMoney = (amount: number): string =>
  `$${amount.toFixed(2).replace(/\.00$/, "")}`;

/** "20% off · first 3 months" — the chip and the invoice line both use this. */
export const discountLabel = (discount: StudentDiscount): string => {
  const amount = discount.mode === "percent" ? `${discount.value}% off` : `${formatMoney(discount.value)} off`;
  if (discount.duration === "ongoing") return `${amount} · ongoing`;
  const months = discount.months ?? 0;
  return `${amount} · first ${months} ${months === 1 ? "month" : "months"}`;
};

export const formatStartDate = (date: Date): string =>
  Number.isNaN(date.getTime())
    ? ""
    : new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(date);
