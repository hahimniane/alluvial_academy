/**
 * Applying student discounts to invoices.
 *
 * A discount lives on `users/{studentId}.discount`, covers every program that
 * student takes, and comes off each monthly invoice whose period falls inside
 * its window. It reaches the invoice as its **own line item** so a parent can
 * see what came off and why, and so `total_amount` — which every invoice path
 * computes by summing item totals — follows automatically.
 *
 * Money is computed in whole cents. A percentage applied to a float total
 * produces values like 6.596700000000001, which then reaches Stripe and a PDF.
 */

/**
 * Whole calendar months from one to the other, ignoring the day.
 *
 * Billing periods are month-granular (`2026-08` becomes Aug 1), so the day of
 * the month a discount starts on must not shift the window. Comparing days
 * would let a discount that starts Aug 15 still apply in November — a fourth
 * month on a three-month discount.
 */
const _monthsBetween = (from, to) =>
  (to.getUTCFullYear() - from.getUTCFullYear()) * 12 + (to.getUTCMonth() - from.getUTCMonth());

const _toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') {
    const date = value.toDate();
    return Number.isNaN(date.getTime()) ? null : date;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

/**
 * A discount only counts when it is complete and well formed. A half-written
 * record bills at full price rather than at some guessed amount.
 */
const readDiscount = (raw) => {
  if (!raw || typeof raw !== 'object') return null;
  const mode = raw.mode === 'fixed' ? 'fixed' : raw.mode === 'percent' ? 'percent' : null;
  if (!mode) return null;
  const value = Number(raw.value);
  if (!Number.isFinite(value) || value <= 0) return null;
  if (mode === 'percent' && value > 100) return null;
  const startDate = _toDate(raw.startDate);
  if (!startDate) return null;
  const scope = raw.scope === 'family' ? 'family' : 'student';
  const duration = raw.duration === 'ongoing' ? 'ongoing' : 'months';
  const months = Number(raw.months);
  if (duration === 'months' && (!Number.isInteger(months) || months <= 0)) return null;
  return {
    mode,
    value,
    // Absent on discounts saved before family scope existed; those are
    // per-student, which is what they have always done.
    scope,
    duration,
    ...(duration === 'months' ? {months} : {}),
    startDate,
    reason: (raw.reason || '').toString(),
    note: (raw.note || '').toString()
  };
};

/**
 * Whether a billing period is inside the window.
 *
 * The start month counts as month 1 whatever day of it the period begins, so a
 * discount starting the 15th still applies to that month's invoice. Periods
 * before the start month never do — a discount is not applied retroactively to
 * an invoice already issued.
 */
const coversPeriod = (discount, periodStart) => {
  const start = _toDate(periodStart);
  if (!start || !discount) return false;
  const elapsed = _monthsBetween(discount.startDate, start);
  if (elapsed < 0) return false;
  if (discount.duration === 'ongoing') return true;
  return elapsed < discount.months;
};

/** What comes off a total, never more than the total itself. */
const discountAmountFor = (discount, total) => {
  if (!Number.isFinite(total) || total <= 0) return 0;
  const totalCents = Math.round(total * 100);
  const rawCents =
    discount.mode === 'percent'
      ? Math.round((totalCents * discount.value) / 100)
      : Math.round(discount.value * 100);
  return Math.min(Math.max(rawCents, 0), totalCents) / 100;
};

const _money = (amount) => `$${amount.toFixed(2).replace(/\.00$/, '')}`;

const discountLabel = (discount) => {
  const amount =
    discount.mode === 'percent' ? `${discount.value}% off` : `${_money(discount.value)} off`;
  if (discount.duration === 'ongoing') return `${amount} · ongoing`;
  return `${amount} · first ${discount.months} ${discount.months === 1 ? 'month' : 'months'}`;
};

/**
 * One discount line per student whose discount covers this period.
 *
 * Lines already marked `is_discount` are excluded from the totals they are
 * computed against, so running this over items that have been through it
 * cannot compound.
 */
const buildDiscountLines = (items, discountsByStudent, periodStart) => {
  const billable = (items || []).filter((item) => !item.is_discount);
  const totals = new Map();
  for (const item of billable) {
    const studentId = (item.student_id || '').toString().trim();
    if (!studentId) continue;
    totals.set(studentId, (totals.get(studentId) || 0) + Number(item.total || 0));
  }

  const lines = [];
  for (const [studentId, total] of totals) {
    const discount = discountsByStudent.get(studentId);
    if (!discount || !coversPeriod(discount, periodStart)) continue;
    const amount = discountAmountFor(discount, total);
    if (amount <= 0) continue;
    lines.push({
      description: `Discount — ${discountLabel(discount)}${discount.reason ? ` (${discount.reason})` : ''}`,
      quantity: 1,
      unit_price: -amount,
      total: -amount,
      student_id: studentId,
      shift_ids: [],
      is_discount: true,
      discount_reason: discount.reason || ''
    });
  }
  return lines;
};

/**
 * One line for a discount the whole household shares.
 *
 * A family discount comes off the invoice once however many children are on it
 * — the difference between "$10 off each student" and "$10 off for the family".
 * It is computed against what is left after the per-student lines, so the two
 * together can never take an invoice below zero, and a percentage reads as a
 * percentage of what the family would otherwise owe.
 */
const buildFamilyDiscountLine = (items, familyDiscount, periodStart) => {
  if (!familyDiscount || familyDiscount.scope !== 'family') return null;
  if (!coversPeriod(familyDiscount, periodStart)) return null;

  const remaining = (items || []).reduce((sum, item) => sum + Number(item.total || 0), 0);
  const amount = discountAmountFor(familyDiscount, remaining);
  if (amount <= 0) return null;

  return {
    description: `Family discount — ${discountLabel(familyDiscount)}${familyDiscount.reason ? ` (${familyDiscount.reason})` : ''}`,
    quantity: 1,
    unit_price: -amount,
    total: -amount,
    // Deliberately unattributed: it belongs to the household, not to a child.
    student_id: '',
    shift_ids: [],
    is_discount: true,
    is_family_discount: true,
    discount_reason: familyDiscount.reason || ''
  };
};

/**
 * Reads each billed student's discount and returns the items with any discount
 * lines appended.
 *
 * A line with no `student_id` cannot be attributed to a child, so it is never
 * discounted — the alternative is guessing which family member a charge
 * belongs to, on an invoice.
 *
 * Pass the transaction as `reader` when called inside one; reads must happen
 * before any write in that transaction.
 */
const applyStudentDiscounts = async (db, items, periodStart, reader = db, parentId = '') => {
  const source = (items || []).filter((item) => !item.is_discount);
  if (!periodStart) return source;

  const studentIds = [
    ...new Set(
      source.map((item) => (item.student_id || '').toString().trim()).filter(Boolean)
    )
  ];
  if (studentIds.length === 0) return source;

  // `reader` is the transaction when there is one. A plain db read inside a
  // transaction would see state the transaction is not holding, and would be
  // re-read rather than retried on contention.
  const snapshots = await reader.getAll(
    ...studentIds.map((id) => db.collection('users').doc(id))
  );
  const discounts = new Map();
  snapshots.forEach((snapshot, index) => {
    if (!snapshot.exists) return;
    const discount = readDiscount((snapshot.data() || {}).discount);
    if (discount) discounts.set(studentIds[index], discount);
  });
  if (discounts.size === 0) return source;

  return [...source, ...buildDiscountLines(source, discounts, periodStart)];
};

module.exports = {
  readDiscount,
  coversPeriod,
  discountAmountFor,
  discountLabel,
  buildDiscountLines,
  buildFamilyDiscountLine,
  applyStudentDiscounts
};
