/**
 * Pure money and calendar maths for the finance billing engine.
 *
 * No Firestore, no clock: every function takes what it needs, so the rules the
 * owner decided (docs/finance/SPEC.md rules 7-9, 11) are unit-tested directly.
 *
 * Money is held in whole cents while it is being added up, then returned as
 * dollars rounded to 2 places. Months are `yyyy-MM` strings and calendar
 * decisions (the 25th, the 1st, "3 days after the first class") are made in
 * America/New_York, which is where the school bills.
 */
const {DateTime} = require('luxon');

const ZONE = 'America/New_York';
const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;
const DATE_RE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;

// ---------------------------------------------------------------- money

const toCents = (value) => Math.round(Number(value) * 100);
const fromCents = (cents) => Math.round(cents) / 100;
const round2 = (value) => fromCents(toCents(value));

/**
 * monthly x left / classes in a full month, to the cent.
 * Oct 20 start with 3 of 8 classes left at $80 -> $30.
 */
const prorate = ({monthly, classesInMonth, classesLeft}) => {
  const monthlyCents = toCents(monthly);
  const total = Number(classesInMonth);
  const left = Number(classesLeft);
  if (!Number.isFinite(monthlyCents) || monthlyCents <= 0) {
    throw new RangeError('monthly amount must be greater than zero');
  }
  if (!Number.isInteger(total) || total <= 0) {
    throw new RangeError('classes in a full month must be a whole number above zero');
  }
  if (!Number.isInteger(left) || left <= 0 || left > total) {
    throw new RangeError('classes left must be a whole number between 1 and the classes in a full month');
  }
  return fromCents((monthlyCents * left) / total);
};

// ---------------------------------------------------------------- calendar

const isMonth = (value) => typeof value === 'string' && MONTH_RE.test(value);
const isDateString = (value) => {
  if (typeof value !== 'string' || !DATE_RE.test(value)) return false;
  return DateTime.fromISO(value, {zone: ZONE}).isValid;
};

const addMonths = (month, n) => {
  if (!isMonth(month)) throw new RangeError(`not a month: ${month}`);
  const [year, mon] = month.split('-').map(Number);
  return DateTime.utc(year, mon, 1).plus({months: n}).toFormat('yyyy-MM');
};

const monthOfDate = (date) => DateTime.fromJSDate(date, {zone: ZONE}).toFormat('yyyy-MM');
const nyDateString = (date) => DateTime.fromJSDate(date, {zone: ZONE}).toFormat('yyyy-MM-dd');
const monthOfDateString = (dateString) => dateString.slice(0, 7);

/** The month after the one `now` falls in (New York). */
const nextBillingMonth = (now) => addMonths(monthOfDate(now), 1);

const daysInMonth = (month) => {
  const [year, mon] = month.split('-').map(Number);
  return DateTime.utc(year, mon, 1).daysInMonth;
};

/** Midnight at the start of a `yyyy-MM-dd` day in New York, as a JS Date. */
const startOfNyDay = (dateString) => DateTime.fromISO(dateString, {zone: ZONE}).startOf('day').toJSDate();

const addDaysToDateString = (dateString, days) =>
  DateTime.fromISO(dateString, {zone: ZONE}).plus({days}).toFormat('yyyy-MM-dd');

/** The day a month's invoice is issued: `issueDay` of the PREVIOUS month. */
const monthlyIssueDateString = (month, issueDay = 25) => {
  const previous = addMonths(month, -1);
  const day = Math.min(Math.max(1, Math.round(Number(issueDay) || 25)), daysInMonth(previous));
  return `${previous}-${String(day).padStart(2, '0')}`;
};

/** The day a month's invoice is due: `dueDay` of the month itself. */
const monthlyDueDateString = (month, dueDay = 1) => {
  const day = Math.min(Math.max(1, Math.round(Number(dueDay) || 1)), daysInMonth(month));
  return `${month}-${String(day).padStart(2, '0')}`;
};

/** First class date + N days (default 3). Oct 20 + 3 = Oct 23. */
const firstInvoiceDueDateString = (firstClassDate, dueDays = 3) => {
  const days = Number.isFinite(Number(dueDays)) ? Math.max(0, Math.round(Number(dueDays))) : 3;
  return addDaysToDateString(firstClassDate, days);
};

/**
 * Which month the monthly generator should be creating invoices for at `now`:
 * from the issue day onward, the NEXT month; before it, nothing.
 */
const monthToGenerate = (now, issueDay = 25) => {
  const ny = DateTime.fromJSDate(now, {zone: ZONE});
  const month = ny.toFormat('yyyy-MM');
  const day = Math.min(Math.max(1, Math.round(Number(issueDay) || 25)), daysInMonth(month));
  return ny.day >= day ? addMonths(month, 1) : null;
};

/** Whole New York calendar days from `now` to `due` (negative once past). */
const daysUntilDue = (due, now) => {
  const dueDay = DateTime.fromJSDate(due, {zone: ZONE}).startOf('day');
  const today = DateTime.fromJSDate(now, {zone: ZONE}).startOf('day');
  return Math.round(dueDay.diff(today, 'days').days);
};

const monthLabel = (month) => {
  const [year, mon] = month.split('-').map(Number);
  return DateTime.utc(year, mon, 1).setLocale('en-US').toFormat('LLLL yyyy');
};

// ---------------------------------------------------------------- ids

const safeId = (value) => String(value).replace(/[^a-zA-Z0-9_-]/g, '_');

/** One monthly invoice per family per month: the id itself forbids a second. */
const monthlyInvoiceId = (parentId, month) => `monthly_${safeId(parentId)}_${month}`;

/** One first invoice per student. */
const firstInvoiceId = (studentId) => `first_${safeId(studentId)}`;

// ---------------------------------------------------------------- family amount

/**
 * The monthly amount in force for `month`.
 *
 * `monthly_amount` is always the latest amount. A history entry says "from
 * `from_month` the amount was `old` -> `new`", so for a month BEFORE a change
 * the amount is the `old` of the earliest change that starts after it.
 */
const amountForMonth = (familyBilling, month) => {
  const fb = familyBilling || {};
  const history = Array.isArray(fb.history) ? fb.history : [];
  const later = history
    .filter((h) => h && isMonth(h.from_month) && h.from_month > month && Number.isFinite(Number(h.old)))
    .sort((a, b) => (a.from_month < b.from_month ? -1 : a.from_month > b.from_month ? 1 : 0));
  if (later.length > 0) return round2(later[0].old);
  return round2(fb.monthly_amount);
};

/** Today's change takes effect on the next invoice nobody has issued yet. */
const changeStartMonth = (now, existingMonths = new Set()) => {
  let month = nextBillingMonth(now);
  while (existingMonths.has(month)) month = addMonths(month, 1);
  return month;
};

/**
 * The old recurring generator steps aside for a family once the new engine is
 * switched on and the family has family_billing, so nobody is billed twice.
 */
const shouldOldGeneratorSkip = ({autoBillingEnabled, familyBilling, month = null}) => {
  if (!(autoBillingEnabled === true && Boolean(familyBilling) && familyBilling.active !== false)) {
    return false;
  }
  // The new engine bills nothing for a family whose amount for that month is
  // zero (createMonthlyInvoice returns 'no_amount'), so stepping aside then
  // would leave the family unbilled by BOTH systems. Only skip when the new
  // engine will really bill `month`.
  if (month != null) return amountForMonth(familyBilling, month) > 0;
  return true;
};

// ---------------------------------------------------------------- invoice lines

/**
 * Splits the family amount across its children in whole cents. Uses the
 * per-child amounts when they add up to the family amount exactly; otherwise
 * splits evenly, the odd cents going to the first children.
 */
const splitAmount = ({amount, studentIds = [], studentAmounts = null}) => {
  const totalCents = toCents(amount);
  const ids = [...new Set((studentIds || []).map((s) => String(s || '').trim()).filter(Boolean))];
  if (ids.length === 0) return [{studentId: '', cents: totalCents}];

  if (studentAmounts && typeof studentAmounts === 'object') {
    const parts = ids.map((id) => toCents(studentAmounts[id]));
    const usable = parts.every((c) => Number.isFinite(c) && c >= 0);
    if (usable && parts.reduce((a, b) => a + b, 0) === totalCents) {
      return ids.map((id, i) => ({studentId: id, cents: parts[i]})).filter((p) => p.cents > 0);
    }
  }

  const base = Math.floor(totalCents / ids.length);
  let extra = totalCents - base * ids.length;
  return ids.map((id) => {
    const cents = base + (extra > 0 ? 1 : 0);
    if (extra > 0) extra -= 1;
    return {studentId: id, cents};
  });
};

const line = ({description, cents, studentId = '', extra = {}}) => ({
  description,
  quantity: 1,
  unit_price: fromCents(cents),
  total: fromCents(cents),
  ...(studentId ? {student_id: studentId} : {student_id: ''}),
  shift_ids: [],
  ...extra,
});

/** Tuition lines for a monthly invoice, one per child. */
const monthlyTuitionLines = ({month, amount, studentIds, studentAmounts, studentNames = {}}) => {
  const parts = splitAmount({amount, studentIds, studentAmounts});
  return parts.map((p) =>
    line({
      description: `Monthly tuition — ${monthLabel(month)}${studentNames[p.studentId] ? ` · ${studentNames[p.studentId]}` : ''}`,
      cents: p.cents,
      studentId: p.studentId,
    })
  );
};

/** The pro-rated tuition line of a first invoice. */
const firstMonthLine = ({month, amount, classesLeft, classesInMonth, studentId, studentName}) =>
  line({
    description: `First month tuition — ${monthLabel(month)} (${classesLeft} of ${classesInMonth} classes)${studentName ? ` · ${studentName}` : ''}`,
    cents: toCents(amount),
    studentId,
  });

// ---------------------------------------------------------------- settle

/**
 * Takes tuition lines (plus any discount lines already worked out, negative
 * and flagged `is_discount`) and applies open family credits to what is left.
 *
 * Order is fixed by the owner: discount first, then credit. Credits are used
 * oldest first; one larger than what is left is used in part, and the rest
 * stays open (`remaining_cents`).
 *
 * @returns {{items, credit_lines, subtotal, discount, credit_applied, total, credit_uses}}
 */
const settleInvoice = ({lines, credits = []}) => {
  const items = (lines || []).map((l) => ({...l}));
  const subtotalCents = items.filter((l) => !l.is_discount).reduce((s, l) => s + toCents(l.total), 0);
  const discountCents = -items.filter((l) => l.is_discount).reduce((s, l) => s + toCents(l.total), 0);
  let remaining = Math.max(0, subtotalCents - Math.max(0, discountCents));

  const ordered = [...(credits || [])]
    .filter((c) => c && c.id && toCents(c.amount) > 0)
    .sort((a, b) => {
      const at = Number(a.created_ms) || 0;
      const bt = Number(b.created_ms) || 0;
      if (at !== bt) return at - bt;
      return String(a.id) < String(b.id) ? -1 : 1;
    });

  const creditLines = [];
  const creditUses = [];
  let creditCents = 0;
  for (const credit of ordered) {
    if (remaining <= 0) break;
    const available = toCents(credit.amount);
    const applied = Math.min(available, remaining);
    remaining -= applied;
    creditCents += applied;
    creditLines.push({credit_id: credit.id, amount: fromCents(applied), reason: credit.reason || ''});
    creditUses.push({
      credit_id: credit.id,
      applied: fromCents(applied),
      remaining: fromCents(available - applied),
      remaining_cents: available - applied,
      partial: applied < available,
    });
    items.push(
      line({
        description: `Family credit applied${credit.reason ? ` (${credit.reason})` : ''}`,
        cents: -applied,
        extra: {is_credit: true, credit_id: credit.id},
      })
    );
  }

  return {
    items,
    credit_lines: creditLines,
    credit_uses: creditUses,
    subtotal: fromCents(subtotalCents),
    discount: fromCents(Math.max(0, discountCents)),
    credit_applied: fromCents(creditCents),
    total: fromCents(remaining),
  };
};

/** Tuition lines + discounts + credits for one family's month, in one call. */
const buildMonthlyInvoice = ({
  month,
  amount,
  studentIds,
  studentAmounts,
  studentNames,
  discountLines = [],
  credits = [],
}) => {
  const tuition = monthlyTuitionLines({month, amount, studentIds, studentAmounts, studentNames});
  return settleInvoice({lines: [...tuition, ...discountLines], credits});
};

module.exports = {
  ZONE,
  toCents,
  fromCents,
  round2,
  prorate,
  isMonth,
  isDateString,
  addMonths,
  monthOfDate,
  nyDateString,
  monthOfDateString,
  nextBillingMonth,
  daysInMonth,
  startOfNyDay,
  addDaysToDateString,
  monthlyIssueDateString,
  monthlyDueDateString,
  firstInvoiceDueDateString,
  monthToGenerate,
  daysUntilDue,
  monthLabel,
  safeId,
  monthlyInvoiceId,
  firstInvoiceId,
  amountForMonth,
  changeStartMonth,
  shouldOldGeneratorSkip,
  splitAmount,
  monthlyTuitionLines,
  firstMonthLine,
  settleInvoice,
  buildMonthlyInvoice,
};
