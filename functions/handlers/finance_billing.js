/**
 * Finance billing engine (server side only).
 *
 * Decided by the owner (docs/finance/SPEC.md rules 7, 8, 9, 11, 12):
 *  - the family's monthly amount is set on the first invoice and reused every
 *    month until staff change it (reason required, history kept);
 *  - the first invoice is pro-rated by classes left and created when the
 *    student attends their first class;
 *  - one monthly invoice per family per month (`monthly_{parentId}_{yyyy-MM}`),
 *    issued on the 25th, due on the 1st, discounts first and then open family
 *    credit applied;
 *  - the monthly generator and the parent reminders stay OFF until the owner
 *    switches them on in `finance_settings/main`.
 *
 * Every handler takes `deps` (db, clock, gates) so the rules are tested against
 * an in-memory Firestore without touching production.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onDocumentUpdated} = require('firebase-functions/v2/firestore');

const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const {applyStudentDiscounts} = require('../utils/student_discounts');
const {shiftsInRange} = require('../utils/shifts_in_range');
const {loadBillingSettings} = require('../utils/finance_billing_gate');
const payLinks = require('../services/payment_links');
const math = require('../utils/finance_billing_math');

const COMPLETED_STATUSES = new Set(['completed', 'fullyCompleted', 'partiallyCompleted']);
const DAY_MS = 24 * 60 * 60 * 1000;
const SYSTEM_ACTOR = {
  created_by: 'system',
  created_by_name: 'System automation',
  created_by_email: '',
  created_by_kind: 'system',
};

// ---------------------------------------------------------------- small helpers

const str = (v) => (v == null ? '' : String(v)).trim();
const rec = (v) => (v && typeof v === 'object' && !Array.isArray(v) ? v : {});
const list = (v) => (Array.isArray(v) ? v : []);
const httpsError = (code, message) => new functions.https.HttpsError(code, message);

const toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const millisOf = (value) => {
  const d = toDate(value);
  return d ? d.getTime() : 0;
};

const displayName = (data) => {
  const d = rec(data);
  return (
    [d.first_name, d.last_name].map(str).filter(Boolean).join(' ') ||
    [d.firstName, d.lastName].map(str).filter(Boolean).join(' ') ||
    str(d.display_name) ||
    str(d.displayName) ||
    str(d.name) ||
    ''
  );
};

const emailOf = (data) => str(rec(data)['e-mail'] || rec(data).email);

const money = (n) => `$${Number(n).toFixed(2)}`;

const chunk = (arr, size) => {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
};

const monthStartUtc = (month) => {
  const [y, m] = month.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, 1));
};

// The month lock belongs to the overview branch (utils/finance_lock.js). It is
// required lazily so this module loads before that file lands, and so a
// missing lock fails closed (the call throws) rather than billing into a month
// nobody can check.
const assertMonthOpenDefault = (db, month) => require('../utils/finance_lock').assertMonthOpen(db, month);

const defaultDeps = () => ({
  db: admin.firestore(),
  FieldValue: admin.firestore.FieldValue,
  Timestamp: admin.firestore.Timestamp,
  verifyAdmin: verifyCallableCallerIsAdmin,
  assertMonthOpen: assertMonthOpenDefault,
  now: () => new Date(),
  applyDiscounts: applyStudentDiscounts,
  sendReminder: (args) => sendReminderDefault(args),
});

/** Reads a query through a transaction when given one, else directly. */
const readQuery = (reader, db, query) => (reader === db ? query.get() : reader.get(query));

const actorProfile = async (db, uid) => {
  try {
    const snap = await db.collection('users').doc(uid).get();
    const data = snap.exists ? snap.data() : null;
    return {uid, name: displayName(data) || emailOf(data) || 'Admin', email: emailOf(data)};
  } catch (_) {
    return {uid, name: 'Admin', email: ''};
  }
};

/** Same counter and format as payments.js so numbers never collide. */
const nextInvoiceNumber = async (tx, db, FieldValue, year) => {
  const counterRef = db.collection('invoice_counters').doc(String(year));
  const counterSnap = await tx.get(counterRef);
  const current = counterSnap.exists ? Number(counterSnap.data().next) || 1 : 1;
  tx.set(counterRef, {next: current + 1, updated_at: FieldValue.serverTimestamp()}, {merge: true});
  return `INV-${year}-${String(current).padStart(3, '0')}`;
};

/** A family's open credits, oldest first. */
const readOpenCredits = async (reader, db, parentId) => {
  const snap = await readQuery(
    reader,
    db,
    db.collection('family_credits').where('parent_id', '==', parentId).where('status', '==', 'open')
  );
  return snap.docs.map((d) => {
    const data = d.data() || {};
    return {
      id: d.id,
      amount: Number(data.amount) || 0,
      reason: str(data.reason),
      created_ms: millisOf(data.created_at),
      raw: data,
    };
  });
};

/** Marks credits used on an invoice; a part-used credit leaves its rest open. */
const writeCreditUses = ({tx, db, deps, uses, credits, invoiceId, actor}) => {
  const {FieldValue} = deps;
  const byId = new Map(credits.map((c) => [c.id, c]));
  for (const use of uses) {
    const credit = byId.get(use.credit_id);
    const ref = db.collection('family_credits').doc(use.credit_id);
    const closed = {
      status: 'used',
      used_on_invoice_id: invoiceId,
      closed_at: FieldValue.serverTimestamp(),
      closed_by: actor,
    };
    if (!use.partial) {
      tx.update(ref, closed);
      continue;
    }
    tx.update(ref, {...closed, amount: use.applied, original_amount: credit.amount});
    tx.set(db.collection('family_credits').doc(`${use.credit_id}__rest_${invoiceId}`), {
      ...credit.raw,
      amount: use.remaining,
      status: 'open',
      split_from: use.credit_id,
      used_on_invoice_id: null,
      closed_at: null,
      closed_by: null,
      created_at: credit.raw.created_at || FieldValue.serverTimestamp(),
      created_by: 'system',
    });
  }
};

// ---------------------------------------------------------------- the invoice document

const invoiceDocument = ({deps, number, parentId, studentIds, settle, kind, month, due, now, extra}) => {
  const {Timestamp} = deps;
  const accessCutoff = new Date(due.getTime() + DAY_MS);
  const total = settle.total;
  return {
    invoice_number: number,
    parent_id: parentId,
    student_id: studentIds[0] || null,
    ...(studentIds.length ? {student_ids: studentIds} : {}),
    status: total <= 0 ? 'paid' : 'pending',
    total_amount: total,
    paid_amount: 0,
    currency: 'USD',
    issued_date: Timestamp.fromDate(now),
    due_date: Timestamp.fromDate(due),
    access_cutoff_date: Timestamp.fromDate(accessCutoff),
    items: settle.items,
    shift_ids: [],
    period: month,
    period_start: month,
    period_end: month,
    billing_months: 1,
    kind,
    billing_month: month,
    source: 'family_billing',
    subtotal: settle.subtotal,
    discount_total: settle.discount,
    credit_applied: settle.credit_applied,
    credit_lines: settle.credit_lines,
    ...(total <= 0 ? {settled_by_credit: settle.credit_applied > 0} : {}),
    notification_status: 'pending',
    created_at: deps.FieldValue.serverTimestamp(),
    updated_at: deps.FieldValue.serverTimestamp(),
    ...SYSTEM_ACTOR,
    ...payLinks.newPayLinkFields('system'),
    ...extra,
  };
};

// ---------------------------------------------------------------- monthly invoice (one family)

/**
 * Creates `monthly_{parentId}_{month}` for one family inside a transaction.
 * Safe to call any number of times: the fixed document id plus the existence
 * check inside the transaction mean the second call changes nothing.
 */
const createMonthlyInvoice = async ({deps, parentId, month, settings}) => {
  const {db, FieldValue} = deps;
  const now = deps.now();
  const invoiceId = math.monthlyInvoiceId(parentId, month);
  const invoiceRef = db.collection('invoices').doc(invoiceId);
  const fbRef = db.collection('family_billing').doc(parentId);

  return db.runTransaction(async (tx) => {
    const [invoiceSnap, fbSnap] = await tx.getAll(invoiceRef, fbRef);
    if (invoiceSnap.exists) return {created: false, reason: 'invoice_exists', invoiceId};
    if (!fbSnap.exists) return {created: false, reason: 'no_family_billing', invoiceId};
    const fb = fbSnap.data() || {};
    if (fb.active === false) return {created: false, reason: 'inactive', invoiceId};
    const amount = math.amountForMonth(fb, month);
    if (!(amount > 0)) return {created: false, reason: 'no_amount', invoiceId};

    const studentIds = list(fb.student_ids).map(str).filter(Boolean);
    const studentSnaps = studentIds.length
      ? await tx.getAll(...studentIds.map((id) => db.collection('users').doc(id)))
      : [];
    const studentNames = {};
    studentSnaps.forEach((s, i) => {
      if (s.exists) studentNames[studentIds[i]] = displayName(s.data());
    });

    const credits = await readOpenCredits(tx, db, parentId);
    const tuition = math.monthlyTuitionLines({
      month,
      amount,
      studentIds,
      studentAmounts: fb.student_amounts,
      studentNames,
    });
    const withDiscounts = await deps.applyDiscounts(db, tuition, monthStartUtc(month), tx, parentId);
    const settle = math.settleInvoice({lines: withDiscounts, credits});
    const number = await nextInvoiceNumber(tx, db, FieldValue, now.getUTCFullYear());

    const due = math.startOfNyDay(math.monthlyDueDateString(month, settings.due_day));
    tx.set(
      invoiceRef,
      invoiceDocument({
        deps,
        number,
        parentId,
        studentIds,
        settle,
        kind: 'monthly',
        month,
        due,
        now,
        extra: {monthly_amount: amount, scheduled_issue_date: math.monthlyIssueDateString(month, settings.issue_day)},
      })
    );
    writeCreditUses({tx, db, deps, uses: settle.credit_uses, credits, invoiceId, actor: 'system'});

    return {created: true, invoiceId, invoiceNumber: number, total: settle.total, creditApplied: settle.credit_applied};
  });
};

// ---------------------------------------------------------------- first invoice

const invoiceInvolvesStudent = (invoice, studentId) =>
  invoice.student_id === studentId ||
  list(invoice.student_ids).includes(studentId) ||
  list(invoice.items).some((item) => rec(item).student_id === studentId);

/**
 * Creates the pro-rated first invoice for a student and records the family's
 * monthly amount. One first invoice per student (`first_{studentId}`).
 *
 * `monthlyAmount` is the NEW STUDENT's own monthly price. A family with no
 * monthly amount yet gets it as the family amount; a family that already has
 * one gets it added from the next invoice (history entry kept), whether or not
 * the student was already listed in the family's student_ids.
 *
 * @returns {{created:boolean, reason?:string, invoiceId?:string, ...}}
 */
const issueFirstInvoice = async ({
  deps,
  settings,
  parentId,
  studentId,
  monthlyAmount,
  classesInMonth,
  classesLeft,
  firstClassDate,
  actor,
  auto = false,
  consumePending = false,
}) => {
  const {db, FieldValue} = deps;
  const now = deps.now();
  const month = math.monthOfDateString(firstClassDate);
  await deps.assertMonthOpen(db, month);

  const amount = math.prorate({monthly: monthlyAmount, classesInMonth, classesLeft});
  const invoiceId = math.firstInvoiceId(studentId);
  const invoiceRef = db.collection('invoices').doc(invoiceId);
  const fbRef = db.collection('family_billing').doc(parentId);
  const dueDays = settings.first_invoice_due_days;

  const result = await db.runTransaction(async (tx) => {
    const [invoiceSnap, fbSnap, studentSnap] = await tx.getAll(
      invoiceRef,
      fbRef,
      db.collection('users').doc(studentId)
    );
    if (invoiceSnap.exists) {
      const cancelled = str(invoiceSnap.data().status).toLowerCase() === 'cancelled';
      return {created: false, reason: cancelled ? 'first_invoice_cancelled' : 'first_invoice_exists', invoiceId};
    }
    if (auto) {
      const familyInvoices = await tx.get(db.collection('invoices').where('parent_id', '==', parentId));
      const prior = familyInvoices.docs.find((d) => {
        const inv = d.data() || {};
        return str(inv.status).toLowerCase() !== 'cancelled' && invoiceInvolvesStudent(inv, studentId);
      });
      if (prior) return {created: false, reason: 'prior_invoice', invoiceId: prior.id};
    }

    const fb = fbSnap.exists ? fbSnap.data() || {} : null;
    const credits = await readOpenCredits(tx, db, parentId);
    const studentName = studentSnap.exists ? displayName(studentSnap.data()) : '';
    const tuition = [
      math.firstMonthLine({month, amount, classesLeft, classesInMonth, studentId, studentName}),
    ];
    const withDiscounts = await deps.applyDiscounts(db, tuition, monthStartUtc(month), tx, parentId);
    const settle = math.settleInvoice({lines: withDiscounts, credits});
    const number = await nextInvoiceNumber(tx, db, FieldValue, now.getUTCFullYear());

    const due = math.startOfNyDay(math.firstInvoiceDueDateString(firstClassDate, dueDays));
    const knownStudents = list(fb && fb.student_ids).map(str).filter(Boolean);
    const studentIds = [...new Set([...knownStudents, studentId])];
    tx.set(
      invoiceRef,
      invoiceDocument({
        deps,
        number,
        parentId,
        studentIds: [studentId],
        settle,
        kind: 'first_month',
        month,
        due,
        now,
        extra: {
          first_class_date: firstClassDate,
          monthly_amount: math.round2(monthlyAmount),
          classes_in_month: classesInMonth,
          classes_left: classesLeft,
          ...(actor.uid === 'system' ? {} : {created_by: actor.uid, created_by_name: actor.name, created_by_email: actor.email || '', created_by_kind: 'person'}),
        },
      })
    );

    // The family amount: set once, on the first invoice.
    const existingAmount = fb ? math.round2(fb.monthly_amount) : 0;
    const familyUpdate = {
      student_ids: studentIds,
      active: true,
      last_first_invoice: {invoice_id: invoiceId, student_id: studentId, at: FieldValue.serverTimestamp()},
    };
    if (!fb || !(existingAmount > 0)) {
      Object.assign(familyUpdate, {
        monthly_amount: math.round2(monthlyAmount),
        set_on_invoice_id: invoiceId,
        set_at: FieldValue.serverTimestamp(),
        history: list(fb && fb.history),
      });
    } else {
      // This is the student's first first-month invoice (the fixed id
      // first_{studentId} and the exists-check above make this run once per
      // student), so their price joins the family amount from the next invoice
      // even if the student was already listed in student_ids.
      const fromMonth = math.nextBillingMonth(now);
      const newAmount = math.round2(existingAmount + monthlyAmount);
      familyUpdate.monthly_amount = newAmount;
      familyUpdate.history = [
        ...list(fb.history),
        {
          from_month: fromMonth,
          old: existingAmount,
          new: newAmount,
          reason: `Added student at first invoice (${invoiceId})`,
          at: deps.Timestamp.fromDate(now),
          by: actor.uid,
        },
      ];
      const known = rec(fb.student_amounts);
      const sum = Object.values(known).reduce((s, v) => s + math.toCents(v), 0);
      familyUpdate.student_amounts =
        sum === math.toCents(existingAmount) && sum > 0
          ? {...known, [studentId]: math.round2((Number(known[studentId]) || 0) + monthlyAmount)}
          : FieldValue.delete();
    }
    if (consumePending) familyUpdate.pending_first_invoice = FieldValue.delete();
    tx.set(fbRef, familyUpdate, {merge: true});
    writeCreditUses({tx, db, deps, uses: settle.credit_uses, credits, invoiceId, actor: actor.uid});

    return {
      created: true,
      invoiceId,
      invoiceNumber: number,
      total: settle.total,
      amount,
      studentName,
      month,
      due,
      newFamily: !fb || !(existingAmount > 0),
    };
  });

  return result;
};

const notifyAdminsFirstInvoice = async ({deps, parentId, studentId, studentName, parentName, result, firstClassDate}) => {
  const {db, FieldValue} = deps;
  const who = studentName || 'A student';
  const dueText = math.nyDateString(result.due);
  await db.collection('admin_notifications').add({
    type: 'first_invoice_created',
    title: 'New student: first invoice created',
    parent_id: parentId,
    student_id: studentId,
    invoice_id: result.invoiceId,
    invoice_number: result.invoiceNumber,
    billing_month: result.month,
    amount: result.total,
    message:
      `${who}${parentName ? ` (family of ${parentName})` : ''} attended their first class on ${firstClassDate}. ` +
      `First invoice ${result.invoiceNumber} for ${money(result.total)} is due ${dueText}.`,
    read: false,
    action_required: false,
    createdAt: FieldValue.serverTimestamp(),
  });
};

// ---------------------------------------------------------------- callables

const validateFirstInvoiceInput = (data) => {
  const parentId = str(data.parent_id);
  const studentId = str(data.student_id);
  const monthlyAmount = Number(data.monthly_amount);
  const classesInMonth = Number(data.classes_in_month);
  const classesLeft = Number(data.classes_left);
  const firstClassDate = str(data.first_class_date);
  if (!parentId || !studentId) throw httpsError('invalid-argument', 'parent_id and student_id are required.');
  if (!Number.isFinite(monthlyAmount) || monthlyAmount <= 0) {
    throw httpsError('invalid-argument', 'The monthly amount must be greater than zero.');
  }
  if (!Number.isInteger(classesInMonth) || classesInMonth <= 0) {
    throw httpsError('invalid-argument', 'Classes in a full month must be a whole number above zero.');
  }
  if (!Number.isInteger(classesLeft) || classesLeft <= 0 || classesLeft > classesInMonth) {
    throw httpsError('invalid-argument', 'Classes left must be between 1 and the classes in a full month.');
  }
  if (!math.isDateString(firstClassDate)) {
    throw httpsError('invalid-argument', 'The first class date must look like 2026-10-20.');
  }
  return {parentId, studentId, monthlyAmount, classesInMonth, classesLeft, firstClassDate};
};

/** Manual first invoice: `{parent_id, student_id, monthly_amount, classes_in_month, classes_left, first_class_date}` -> `{invoice_id}`. */
const createFirstInvoice = async (request, deps = defaultDeps()) => {
  const {callerUid} = await deps.verifyAdmin(request);
  const input = validateFirstInvoiceInput(rec(request && request.data));
  const settings = await loadBillingSettings(deps.db);
  const actor = await actorProfile(deps.db, callerUid);

  const result = await issueFirstInvoice({deps, settings, ...input, actor, auto: false, consumePending: true});
  if (!result.created) {
    throw httpsError(
      'already-exists',
      result.reason === 'first_invoice_cancelled'
        ? 'This student’s first invoice was cancelled. Create a one-off invoice instead.'
        : 'This student already has a first invoice.'
    );
  }
  return {invoice_id: result.invoiceId, invoice_number: result.invoiceNumber, total: result.total};
};

/** `{parent_id, monthly_amount > 0, reason}` -> `{ok}`; applies from the next invoice. */
const setFamilyMonthlyAmount = async (request, deps = defaultDeps()) => {
  const {callerUid} = await deps.verifyAdmin(request);
  const data = rec(request && request.data);
  const parentId = str(data.parent_id);
  const amount = Number(data.monthly_amount);
  const reason = str(data.reason);
  if (!parentId) throw httpsError('invalid-argument', 'parent_id is required.');
  if (!Number.isFinite(amount) || amount <= 0) {
    throw httpsError('invalid-argument', 'The monthly amount must be greater than zero.');
  }
  if (!reason) throw httpsError('invalid-argument', 'A reason is required to change the monthly amount.');

  const {db, FieldValue} = deps;
  const now = deps.now();
  const actor = await actorProfile(db, callerUid);
  const newAmount = math.round2(amount);
  const fbRef = db.collection('family_billing').doc(parentId);

  // The change starts with the next invoice nobody has issued yet.
  const candidate = math.nextBillingMonth(now);
  await deps.assertMonthOpen(db, candidate);

  return db.runTransaction(async (tx) => {
    const fbSnap = await tx.get(fbRef);
    if (!fbSnap.exists) {
      throw httpsError(
        'failed-precondition',
        'This family has no monthly amount yet. It is set when the first invoice is created.'
      );
    }
    const fb = fbSnap.data() || {};
    const oldAmount = math.round2(fb.monthly_amount);
    if (oldAmount === newAmount) {
      throw httpsError('failed-precondition', 'The monthly amount is already that amount.');
    }
    const months = [candidate, math.addMonths(candidate, 1), math.addMonths(candidate, 2)];
    const issued = await tx.getAll(...months.map((m) => db.collection('invoices').doc(math.monthlyInvoiceId(parentId, m))));
    const existing = new Set(months.filter((_, i) => issued[i].exists));
    const fromMonth = math.changeStartMonth(now, existing);
    if (fromMonth !== candidate) await deps.assertMonthOpen(db, fromMonth);

    const entry = {from_month: fromMonth, old: oldAmount, new: newAmount, reason, at: deps.Timestamp.fromDate(now), by: callerUid, by_name: actor.name};
    tx.set(
      fbRef,
      {
        monthly_amount: newAmount,
        history: [...list(fb.history), entry],
        student_amounts: FieldValue.delete(),
        updated_at: FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    return {ok: true, from_month: fromMonth, old: oldAmount, new: newAmount};
  });
};

// ---------------------------------------------------------------- preview

const invoiceCoversMonth = (invoice, month) => {
  const kind = str(invoice.kind);
  if (kind === 'one_off' || kind === 'first_month') return false;
  if (str(invoice.status).toLowerCase() === 'cancelled') return false;
  const start = str(invoice.billing_month || invoice.period_start).slice(0, 7);
  if (!math.isMonth(start)) return false;
  const end = str(invoice.period_end).slice(0, 7);
  const last = math.isMonth(end) && end > start ? end : start;
  return start <= month && month <= last;
};

/** parentId -> an existing tuition invoice (either system) covering `month`. */
const findExistingMonthInvoices = async (db, month) => {
  const snap = await db
    .collection('invoices')
    .where('period_start', '>=', math.addMonths(month, -5))
    .where('period_start', '<=', month)
    .get();
  const byParent = new Map();
  for (const doc of snap.docs) {
    const inv = doc.data() || {};
    const parentId = str(inv.parent_id);
    if (!parentId || !invoiceCoversMonth(inv, month)) continue;
    const previous = byParent.get(parentId);
    // Prefer the new system's own invoice if somehow both exist.
    if (!previous || doc.id === math.monthlyInvoiceId(parentId, month)) byParent.set(parentId, {id: doc.id, ...inv});
  }
  return byParent;
};

const readUsers = async (db, ids) => {
  const unique = [...new Set(ids.map(str).filter(Boolean))];
  const out = new Map();
  for (const part of chunk(unique, 100)) {
    const snaps = await db.getAll(...part.map((id) => db.collection('users').doc(id)));
    snaps.forEach((s, i) => {
      if (s.exists) out.set(part[i], s.data() || {});
    });
  }
  return out;
};

/**
 * What the monthly generator WOULD bill for `month`. Read-only.
 *
 * `proposals` (parentId -> family_billing-shaped doc) lets a caller preview
 * families that have no `family_billing` yet, e.g. the backfill's proposals;
 * a real family_billing document always wins over a proposal.
 */
const computeMonthlyPlan = async ({db, month, applyDiscounts = applyStudentDiscounts, proposals = {}}) => {
  const [fbSnap, existing, creditSnap] = await Promise.all([
    db.collection('family_billing').get(),
    findExistingMonthInvoices(db, month),
    db.collection('family_credits').where('status', '==', 'open').get(),
  ]);

  const families = new Map();
  for (const doc of fbSnap.docs) families.set(doc.id, {...doc.data(), __proposed: false});
  for (const [parentId, proposal] of Object.entries(proposals)) {
    if (!families.has(parentId)) families.set(parentId, {...proposal, __proposed: true});
  }

  const creditsByParent = new Map();
  for (const doc of creditSnap.docs) {
    const data = doc.data() || {};
    const pid = str(data.parent_id);
    if (!pid) continue;
    if (!creditsByParent.has(pid)) creditsByParent.set(pid, []);
    creditsByParent.get(pid).push({
      id: doc.id,
      amount: Number(data.amount) || 0,
      reason: str(data.reason),
      created_ms: millisOf(data.created_at),
    });
  }

  const wanted = [];
  for (const [parentId, fb] of families) {
    wanted.push(parentId, ...list(fb.student_ids));
  }
  const users = await readUsers(db, wanted);

  const rows = [];
  for (const [parentId, fb] of families) {
    if (fb.active === false) continue;
    const amount = math.amountForMonth(fb, month);
    const studentIds = list(fb.student_ids).map(str).filter(Boolean);
    const studentNames = {};
    for (const id of studentIds) studentNames[id] = displayName(users.get(id)) || id;

    const tuition = amount > 0
      ? math.monthlyTuitionLines({month, amount, studentIds, studentAmounts: fb.student_amounts, studentNames})
      : [];
    const withDiscounts = tuition.length
      ? await applyDiscounts(db, tuition, monthStartUtc(month), db, parentId)
      : tuition;
    const settle = math.settleInvoice({lines: withDiscounts, credits: creditsByParent.get(parentId) || []});
    const existingInvoice = existing.get(parentId);
    const parent = users.get(parentId);

    rows.push({
      parent_id: parentId,
      parent_name: displayName(parent) || parentId,
      parent_email: emailOf(parent),
      students: studentIds.map((id) => studentNames[id]),
      student_ids: studentIds,
      monthly_amount: amount,
      discount: settle.discount,
      credit: settle.credit_applied,
      total: settle.total,
      ...(existingInvoice ? {existing_invoice_id: existingInvoice.id} : {}),
      proposed: fb.__proposed === true,
    });
  }
  rows.sort((a, b) => a.parent_name.localeCompare(b.parent_name));

  const toBill = rows.filter((r) => !r.existing_invoice_id && r.monthly_amount > 0);
  const sum = (items, key) => math.fromCents(items.reduce((s, r) => s + math.toCents(r[key]), 0));
  const already = rows.filter((r) => r.existing_invoice_id);
  const totals = {
    families: rows.length,
    to_create: toBill.length,
    monthly_amount: sum(toBill, 'monthly_amount'),
    discount: sum(toBill, 'discount'),
    credit: sum(toBill, 'credit'),
    total: sum(toBill, 'total'),
    already_invoiced: already.length,
    already_invoiced_total: sum(already, 'total'),
  };
  return {month, rows, totals};
};

/** `{month}` -> `{rows, totals}`: what the generator would bill for that month. */
const previewMonthlyBilling = async (request, deps = defaultDeps()) => {
  await deps.verifyAdmin(request);
  const month = str(rec(request && request.data).month);
  if (!math.isMonth(month)) throw httpsError('invalid-argument', 'month must look like 2026-11.');
  return computeMonthlyPlan({db: deps.db, month, applyDiscounts: deps.applyDiscounts});
};

// ---------------------------------------------------------------- scheduled generation

/**
 * Daily pass. Does nothing unless `auto_billing_enabled`; from the issue day it
 * creates next month's invoice for every family that has none yet.
 */
const runMonthlyGeneration = async (deps = defaultDeps()) => {
  const {db} = deps;
  const now = deps.now();
  const settings = await loadBillingSettings(db);
  if (settings.auto_billing_enabled !== true) return {skipped: 'auto_billing_off'};

  const month = math.monthToGenerate(now, settings.issue_day);
  if (!month) return {skipped: 'before_issue_day'};

  try {
    await deps.assertMonthOpen(db, month);
  } catch (error) {
    if (error && error.code === 'failed-precondition') return {skipped: 'month_closed', month};
    throw error;
  }

  const plan = await computeMonthlyPlan({db, month, applyDiscounts: deps.applyDiscounts});
  const results = {month, created: 0, existing: 0, failed: 0, skipped: 0, invoices: [], failures: []};
  for (const row of plan.rows) {
    if (row.existing_invoice_id) {
      results.existing += 1;
      continue;
    }
    if (!(row.monthly_amount > 0)) {
      results.skipped += 1;
      continue;
    }
    try {
      const outcome = await createMonthlyInvoice({deps, parentId: row.parent_id, month, settings});
      if (outcome.created) {
        results.created += 1;
        results.invoices.push(outcome.invoiceId);
      } else if (outcome.reason === 'invoice_exists') {
        results.existing += 1;
      } else {
        results.skipped += 1;
      }
    } catch (error) {
      results.failed += 1;
      results.failures.push({parent_id: row.parent_id, error: error.message || String(error)});
      console.error(`[finance_billing] monthly invoice failed for ${row.parent_id}/${month}:`, error);
    }
  }
  return results;
};

// ---------------------------------------------------------------- first class trigger

const classesLeftInMonth = async ({db, studentId, shiftStart, month}) => {
  const end = math.startOfNyDay(`${math.addMonths(month, 1)}-01`);
  const docs = await shiftsInRange(db, {start: shiftStart, end});
  return docs.filter((d) => {
    const s = d.data() || {};
    return list(s.student_ids).includes(studentId) && str(s.status).toLowerCase() !== 'cancelled';
  }).length;
};

/**
 * Called when a class changes. When a shift moves INTO a completed status and a
 * student on it has a family waiting on a first invoice
 * (`family_billing.pending_first_invoice`), creates that first invoice.
 * Never writes to the shift.
 */
const handleShiftChange = async ({deps, shiftId, before, after}) => {
  const {db} = deps;
  const b = rec(before);
  const a = rec(after);
  if (!COMPLETED_STATUSES.has(a.status) || COMPLETED_STATUSES.has(b.status)) {
    return {skipped: 'not_a_new_completion'};
  }
  const shiftStudents = list(a.student_ids).map(str).filter(Boolean);
  const shiftStart = toDate(a.shift_start);
  if (shiftStudents.length === 0 || !shiftStart) return {skipped: 'no_students_or_start'};

  const families = new Map();
  for (const part of chunk(shiftStudents, 10)) {
    const snap = await db.collection('family_billing').where('student_ids', 'array-contains-any', part).get();
    for (const doc of snap.docs) families.set(doc.id, doc.data() || {});
  }

  const settings = await loadBillingSettings(db);
  const outcomes = [];
  for (const [parentId, fb] of families) {
    const pending = rec(fb.pending_first_invoice);
    if (!fb.pending_first_invoice || !(Number(pending.monthly_amount) > 0)) continue;
    const studentId = str(pending.student_id) || list(fb.student_ids).map(str).find((id) => shiftStudents.includes(id));
    if (!studentId || !shiftStudents.includes(studentId)) continue;

    try {
      const classesInMonth = Number(pending.classes_in_month);
      if (!Number.isInteger(classesInMonth) || classesInMonth <= 0) {
        outcomes.push({parentId, studentId, skipped: 'bad_classes_in_month'});
        continue;
      }
      const firstClassDate = math.nyDateString(shiftStart);
      const month = math.monthOfDateString(firstClassDate);
      const counted = await classesLeftInMonth({db, studentId, shiftStart, month});
      const classesLeft = Math.min(classesInMonth, Math.max(1, counted));

      const result = await issueFirstInvoice({
        deps,
        settings,
        parentId,
        studentId,
        monthlyAmount: Number(pending.monthly_amount),
        classesInMonth,
        classesLeft,
        firstClassDate,
        actor: {uid: 'system', name: 'System automation', email: ''},
        auto: true,
        consumePending: true,
      });

      if (result.created) {
        const [studentSnap, parentSnap] = await Promise.all([
          db.collection('users').doc(studentId).get(),
          db.collection('users').doc(parentId).get(),
        ]);
        await notifyAdminsFirstInvoice({
          deps,
          parentId,
          studentId,
          studentName: result.studentName || displayName(studentSnap.exists ? studentSnap.data() : null),
          parentName: displayName(parentSnap.exists ? parentSnap.data() : null),
          result,
          firstClassDate,
        });
      } else if (result.reason === 'prior_invoice' || result.reason === 'first_invoice_exists') {
        // Already billed some other way: stop waiting, so later classes do not retry.
        await db.collection('family_billing').doc(parentId).set(
          {
            pending_first_invoice: deps.FieldValue.delete(),
            first_invoice_skipped: {reason: result.reason, student_id: studentId, at: deps.FieldValue.serverTimestamp()},
          },
          {merge: true}
        );
      }
      outcomes.push({parentId, studentId, ...result});
    } catch (error) {
      outcomes.push({parentId, studentId, error: error.message || String(error)});
      console.error(`[finance_billing] first invoice failed for ${parentId}/${studentId} (shift ${shiftId}):`, error);
      if (error && error.code === 'failed-precondition') {
        await db.collection('admin_notifications').add({
          type: 'first_invoice_blocked',
          title: 'First invoice not created',
          parent_id: parentId,
          student_id: studentId,
          message: `A student attended their first class but the first invoice could not be created: ${error.message}`,
          read: false,
          action_required: true,
          createdAt: deps.FieldValue.serverTimestamp(),
        }).catch(() => {});
      }
    }
  }
  return {outcomes};
};

// ---------------------------------------------------------------- reminders

const balanceOf = (invoice) => Math.max(0, (Number(invoice.total_amount) || 0) - (Number(invoice.paid_amount) || 0));

const tokensFor = (userData) => {
  const set = new Set();
  for (const entry of list(userData && userData.fcmTokens)) if (entry && entry.token) set.add(entry.token);
  if (userData && userData.fcmToken) set.add(userData.fcmToken);
  return [...set];
};

/** Email + push for one reminder. Returns which channels got through. */
const sendReminderDefault = async ({db, invoiceId, invoice, kind, daysUntil}) => {
  const recipientIds = [...new Set([str(invoice.parent_id), str(invoice.student_id)].filter(Boolean))];
  let payerId = null;
  let userData = null;
  for (const id of recipientIds) {
    const snap = await db.collection('users').doc(id).get();
    if (snap.exists) {
      payerId = id;
      userData = snap.data() || {};
      break;
    }
  }
  if (!payerId) return {email: false, push: false, reason: 'payer_not_found'};

  const number = str(invoice.invoice_number) || invoiceId;
  const amount = money(balanceOf(invoice));
  const dueText = math.nyDateString(toDate(invoice.due_date));
  const title = kind === 'due' ? `Invoice ${number} is due today` : `Invoice ${number} is due in ${daysUntil} days`;
  const body = `${amount} is due ${kind === 'due' ? 'today' : `on ${dueText}`}.`;
  const outcome = {email: false, push: false};

  const email = emailOf(userData);
  if (email) {
    try {
      const {createTransporter} = require('../services/email/transporter');
      const {brandedEmailHtml} = require('../services/email/branding');
      const payUrl = invoice.pay_link_token && str(invoice.pay_link_status) !== payLinks.PAY_LINK_CANCELLED
        ? payLinks.buildPayLinkUrl(invoice.pay_link_token)
        : '';
      await createTransporter('billing').sendMail({
        from: 'Alluwal Education Hub Billing <billing@alluwaleducationhub.org>',
        to: email,
        subject: title,
        html: brandedEmailHtml({
          heading: title,
          bodyHtml:
            `<p>Assalamu alaikum ${displayName(userData) || ''},</p><p>${body}</p>` +
            (payUrl ? `<p><a class="button" href="${payUrl}">Pay ${amount}</a></p>` : ''),
          footerNote: 'This is an automated billing reminder.',
        }),
      });
      outcome.email = true;
    } catch (error) {
      console.error(`[finance_billing] reminder email failed for ${invoiceId}:`, error.message);
    }
  }

  const tokens = tokensFor(userData);
  if (tokens.length) {
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {title, body},
        data: {type: 'invoice_reminder', invoiceId: String(invoiceId), click_action: 'FLUTTER_NOTIFICATION_CLICK'},
      });
      outcome.push = response.successCount > 0;
    } catch (error) {
      console.error(`[finance_billing] reminder push failed for ${invoiceId}:`, error.message);
    }
  }
  return outcome;
};

/**
 * Daily: a reminder N days before an invoice is due and another on the due
 * date, once each (`reminders_sent` on the invoice). Only while parent
 * messages are switched on.
 */
const runInvoiceReminders = async (deps = defaultDeps()) => {
  const {db, FieldValue, Timestamp} = deps;
  const now = deps.now();
  const settings = await loadBillingSettings(db);
  if (settings.parent_messages_enabled !== true) return {skipped: 'parent_messages_off'};

  const before = Math.max(0, Math.round(Number(settings.reminder_days_before) || 0));
  const today = math.nyDateString(now);
  const from = math.startOfNyDay(today);
  const until = math.startOfNyDay(math.addDaysToDateString(today, before + 1));
  const snap = await db
    .collection('invoices')
    .where('due_date', '>=', Timestamp.fromDate(from))
    .where('due_date', '<', Timestamp.fromDate(until))
    .get();

  const summary = {checked: snap.docs.length, sent: 0, skipped: 0, failed: 0};
  for (const doc of snap.docs) {
    const invoice = doc.data() || {};
    const status = str(invoice.status).toLowerCase();
    if (status === 'paid' || status === 'cancelled' || balanceOf(invoice) <= 0.004) {
      summary.skipped += 1;
      continue;
    }
    const daysUntil = math.daysUntilDue(toDate(invoice.due_date), now);
    const kind = daysUntil === 0 ? 'due' : daysUntil === before ? 'before' : null;
    if (!kind) {
      summary.skipped += 1;
      continue;
    }

    // Claim the reminder first, so a rerun (or two runs at once) cannot send it twice.
    const claimed = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(db.collection('invoices').doc(doc.id));
      const sent = rec(rec(fresh.data()).reminders_sent);
      if (sent[kind]) return false;
      tx.update(db.collection('invoices').doc(doc.id), {[`reminders_sent.${kind}`]: {at: FieldValue.serverTimestamp(), days_until_due: daysUntil}});
      return true;
    });
    if (!claimed) {
      summary.skipped += 1;
      continue;
    }

    try {
      const outcome = await deps.sendReminder({db, invoiceId: doc.id, invoice, kind, daysUntil});
      await db.collection('invoices').doc(doc.id).update({
        [`reminders_sent.${kind}.email`]: outcome.email === true,
        [`reminders_sent.${kind}.push`]: outcome.push === true,
      });
      summary.sent += 1;
    } catch (error) {
      summary.failed += 1;
      console.error(`[finance_billing] reminder failed for ${doc.id}:`, error);
    }
  }
  return summary;
};

// ---------------------------------------------------------------- exported functions

const generateMonthlyFamilyInvoices = onSchedule(
  {schedule: '0 6 * * *', timeZone: 'America/New_York'},
  async () => {
    const result = await runMonthlyGeneration();
    console.log('[finance_billing] monthly generation:', JSON.stringify(result));
    if (result.failed > 0) console.error('[finance_billing] monthly generation had failures:', result.failures);
  }
);

const sendInvoiceReminders = onSchedule(
  {schedule: '0 9 * * *', timeZone: 'America/New_York'},
  async () => {
    const result = await runInvoiceReminders();
    console.log('[finance_billing] invoice reminders:', JSON.stringify(result));
  }
);

const createFirstInvoiceOnFirstClass = onDocumentUpdated('teaching_shifts/{shiftId}', async (event) => {
  if (!event.data) return;
  await handleShiftChange({
    deps: defaultDeps(),
    shiftId: event.params.shiftId,
    before: event.data.before.data(),
    after: event.data.after.data(),
  });
});

module.exports = {
  createFirstInvoice,
  setFamilyMonthlyAmount,
  previewMonthlyBilling,
  generateMonthlyFamilyInvoices,
  sendInvoiceReminders,
  createFirstInvoiceOnFirstClass,
  // Exposed for tests and the read-only scripts.
  runMonthlyGeneration,
  runInvoiceReminders,
  handleShiftChange,
  computeMonthlyPlan,
  createMonthlyInvoice,
  issueFirstInvoice,
  findExistingMonthInvoices,
  COMPLETED_STATUSES,
};
