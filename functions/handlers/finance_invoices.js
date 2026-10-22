'use strict';

/**
 * Finance: invoice edit, cancel and reminder callables.
 *
 * Money mutations that must be atomic go through here, never through client
 * writes (the invoice rules reject edits to paid_amount and every delete):
 *
 *   editInvoice          { invoice_id, lines, discount, due_date, reason }
 *                        -> { invoice, credit_id? }
 *   cancelInvoice        { invoice_id, reason } -> { ok }
 *   sendInvoiceReminder  { invoice_id } -> { ok, ... }   (parent messages on only)
 *
 * Every callable is admin-only and refuses a closed month with
 * `failed-precondition` (assertMonthOpen lives in utils/finance_lock.js).
 * paid_amount is never written here: payments are recorded by
 * recordManualPayment and the payment webhooks only.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const {
  applyDecisionAuditWrites,
  buildDecisionAuditWrites,
  resolveDecisionActor,
} = require('../services/decision_audit');
const payLinks = require('../services/payment_links');
const math = require('../utils/finance_invoice_math');
const {invoiceMonthOf} = require('../utils/finance_invoice_month');
const {assertMonthOpenInTransaction} = require('../utils/finance_lock');

const httpsError = (code, message) => new functions.https.HttpsError(code, message);

const text = (value) => String(value == null ? '' : value).trim();

const SETTINGS_COLLECTION = 'finance_settings';

const money = (n) => `$${math.r2(n).toFixed(2)}`;

/**
 * Push + history entry for the parent. Mirrors the invoice push in
 * handlers/payments.js (_sendInvoicePushNotification), which is private to that
 * file and hard-wired to the "new invoice" wording.
 * TODO: add the e-mail once there is a sender for "invoice updated".
 */
const notifyParent = async (db, {parentId, title, body, data}) => {
  if (!parentId) return {sent: false, reason: 'no_parent'};
  const userSnap = await db.collection('users').doc(parentId).get();
  if (!userSnap.exists) return {sent: false, reason: 'parent_not_found'};
  const user = userSnap.data() || {};
  const tokens = new Set();
  for (const entry of Array.isArray(user.fcmTokens) ? user.fcmTokens : []) {
    if (entry && entry.token) tokens.add(entry.token);
  }
  if (user.fcmToken) tokens.add(user.fcmToken);

  let sent = false;
  if (tokens.size > 0) {
    const response = await admin.messaging().sendEachForMulticast({
      tokens: [...tokens],
      notification: {title, body},
      data: {...data, click_action: 'FLUTTER_NOTIFICATION_CLICK'},
      android: {
        priority: 'high',
        notification: {channelId: 'high_importance_channel', sound: 'default'},
      },
      apns: {payload: {aps: {sound: 'default', badge: 1}}},
    });
    sent = response.successCount > 0;
  }
  await db.collection('notification_history').add({
    sentBy: 'system',
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    recipientType: 'individual',
    recipientIds: [parentId],
    title,
    body,
    additionalData: data,
    emailRequested: false,
    results: {
      totalRecipients: 1,
      fcmSuccess: sent ? 1 : 0,
      fcmFailed: sent ? 0 : 1,
      emailsSent: 0,
      emailsFailed: 0,
    },
  });
  return {sent};
};

const defaultDeps = () => ({
  db: admin.firestore(),
  FieldValue: admin.firestore.FieldValue,
  Timestamp: admin.firestore.Timestamp,
  verifyAdmin: (request) => verifyCallableCallerIsAdmin(request),
  // Resolved lazily: the lock helper ships with the Overview branch.
  assertMonthOpen: (db, month) => require('../utils/finance_lock').assertMonthOpen(db, month),
  resolveActor: (db, uid) => resolveDecisionActor(db, uid),
  audit: (tx, params) => applyDecisionAuditWrites(tx, buildDecisionAuditWrites(params)),
  notifyParent: (db, params) => notifyParent(db, params),
  resendInvoiceNotice: (db, invoiceId, invoice) =>
    // eslint-disable-next-line global-require
    require('./payments')._notifyInvoiceRecipient(db, invoiceId, invoice),
  now: () => new Date(),
});

const parentMessagesOn = async (db) => {
  try {
    const snap = await db.collection(SETTINGS_COLLECTION).doc('main').get();
    return snap.exists && (snap.data() || {}).parent_messages_enabled === true;
  } catch (error) {
    console.warn('[finance_invoices] could not read finance settings', error && error.message);
    return false;
  }
};

const parentIdOf = (invoice) => text(invoice.parent_id || invoice.parentId);
const numberOf = (invoice, id) => text(invoice.invoice_number || invoice.invoiceNumber) || id;

const monthLabel = (month) => {
  const [y, m] = String(month || '').split('-').map(Number);
  if (!y || !m) return String(month || '');
  return new Intl.DateTimeFormat('en-US', {month: 'long', year: 'numeric', timeZone: 'UTC'}).format(
    new Date(Date.UTC(y, m - 1, 1))
  );
};

const snapshotOf = (invoice) => ({
  total_amount: math.invoiceTotal(invoice),
  paid_amount: math.invoicePaid(invoice),
  due_date: invoice.due_date || null,
  items: Array.isArray(invoice.items) ? invoice.items : [],
  status: text(invoice.status),
});

const summaryOf = (id, invoice) => {
  const due = math.toDate(invoice.due_date);
  return {
    id,
    invoice_number: numberOf(invoice, id),
    status: text(invoice.status),
    total_amount: math.invoiceTotal(invoice),
    paid_amount: math.invoicePaid(invoice),
    due_date: due ? due.toISOString() : null,
    items: Array.isArray(invoice.items) ? invoice.items : [],
  };
};

/**
 * Loads the invoice and refuses a closed month before anything is written.
 * An invoice whose month cannot be worked out fails closed: the month lock
 * cannot be checked, so nothing is changed.
 */
const loadOpenInvoice = async (deps, invoiceId) => {
  const ref = deps.db.collection('invoices').doc(invoiceId);
  const snap = await ref.get();
  if (!snap.exists) throw httpsError('not-found', 'Invoice not found.');
  const invoice = snap.data() || {};
  const month = invoiceMonthOf(invoice);
  if (!month) throw noMonthError();
  await deps.assertMonthOpen(deps.db, month);
  return {ref, invoice, month};
};

const noMonthError = () =>
  httpsError('failed-precondition', 'This invoice has no billing month, so it cannot be changed here.');

/** Inside the transaction: the month, from the invoice as it is now, must be open. */
const assertOpenInTx = async (tx, deps, invoice) => {
  const month = invoiceMonthOf(invoice);
  if (!month) throw noMonthError();
  await assertMonthOpenInTransaction(tx, deps.db, month);
  return month;
};

/**
 * Which open `invoice_edit` credits of this invoice give back `need` dollars,
 * newest first. A credit that is used, refunded or cancelled is left alone
 * (the family already had that money). Returns
 * [{id, amount, reduceBy, left, cancel}].
 */
const planCreditReductions = (credits, need) => {
  let remaining = math.r2(need);
  const open = credits
    .filter((c) => c.source === 'invoice_edit' && c.status === 'open' && Number(c.amount) > 0)
    .sort((a, b) => {
      const am = (a.created_at && typeof a.created_at.toMillis === 'function' ? a.created_at.toMillis() : 0);
      const bm = (b.created_at && typeof b.created_at.toMillis === 'function' ? b.created_at.toMillis() : 0);
      return bm - am || (a.id < b.id ? 1 : -1);
    });
  const out = [];
  for (const c of open) {
    if (remaining <= 0.004) break;
    const amount = math.r2(c.amount);
    const reduceBy = math.r2(Math.min(amount, remaining));
    const left = math.r2(amount - reduceBy);
    out.push({id: c.id, amount, reduceBy, left, cancel: left <= 0.004});
    remaining = math.r2(remaining - reduceBy);
  }
  return out;
};

/**
 * Edit lines, discount and due date of one invoice.
 * Request: { invoice_id, lines:[{description, amount, student_id?}], discount,
 *            due_date:'yyyy-MM-dd', reason }
 */
const editInvoice = async (request, deps = defaultDeps()) => {
  const {callerUid} = await deps.verifyAdmin(request);
  const payload = (request && request.data) || {};
  const invoiceId = text(payload.invoice_id || payload.invoiceId);
  if (!invoiceId) throw httpsError('invalid-argument', 'Missing invoice_id.');

  const checked = math.validateEdit({
    lines: payload.lines,
    discount: payload.discount,
    due_date: payload.due_date || payload.dueDate,
    reason: payload.reason,
  });
  if (!checked.ok) throw httpsError('invalid-argument', checked.error);
  const edit = checked.value;

  const {ref, month} = await loadOpenInvoice(deps, invoiceId);
  const actor = await deps.resolveActor(deps.db, callerUid);
  const creditRef = deps.db.collection('family_credits').doc();

  const result = await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw httpsError('not-found', 'Invoice not found.');
    const invoice = snap.data() || {};
    if (math.isCancelled(invoice)) {
      throw httpsError('failed-precondition', 'This invoice was cancelled and cannot be edited.');
    }
    await assertOpenInTx(tx, deps, invoice);

    const paid = math.invoicePaid(invoice);
    const oldTotal = math.invoiceTotal(invoice);
    const items = math.buildItems({
      lines: edit.lines,
      discount: edit.discount,
      previousItems: invoice.items,
    });
    const newTotal = edit.total;
    const oldDueKey = math.dueDayKey(invoice.due_date);
    const itemsChanged =
      JSON.stringify(
        math.splitItems(invoice.items).lines.map((l) => [l.description, math.r2(l.total)])
      ) !== JSON.stringify(edit.lines.map((l) => [l.description, l.amount])) ||
      math.splitItems(invoice.items).discountTotal !== edit.discount;
    if (!itemsChanged && newTotal === oldTotal && oldDueKey === edit.dueDate) {
      throw httpsError('failed-precondition', 'Nothing has changed.');
    }

    // Money paid beyond the old total is already a family credit (older
    // edits left it in paid_amount), so it is not paid on this invoice.
    const paidNow = math.r2(Math.min(paid, oldTotal));
    // Lowering below what was paid: the excess becomes a family credit and
    // paid_amount follows the new total, so Collected is what really stays.
    const credit = math.creditOnLower({total: newTotal, paid: paidNow});
    // Raising: take back what is still open of the credit an earlier edit
    // created, and put that money back on the invoice (never above the total).
    const takeBack = newTotal > oldTotal ? math.r2(newTotal - paidNow) : 0;
    let reductions = [];
    if (takeBack > 0.004) {
      const openSnap = await tx.get(deps.db.collection('family_credits').where('invoice_id', '==', invoiceId));
      reductions = planCreditReductions(
        openSnap.docs.map((d) => ({id: d.id, ...(d.data() || {})})),
        takeBack
      );
    }
    const reducedTotal = math.r2(reductions.reduce((sum, r) => sum + r.reduceBy, 0));
    const newPaid = newTotal === oldTotal ? paid : math.r2(Math.min(newTotal, paidNow + reducedTotal));
    const status = math.statusAfterEdit({total: newTotal, paid: newPaid});
    const newDue = deps.Timestamp.fromDate(math.dueTimestampDate(edit.dueDate));
    const at = deps.Timestamp.fromDate(deps.now());
    const history = Array.isArray(invoice.edit_history) ? invoice.edit_history.slice() : [];
    history.push({
      at,
      by: callerUid,
      by_name: actor.name,
      reason: edit.reason,
      before: snapshotOf(invoice),
      after: {total_amount: newTotal, paid_amount: newPaid, due_date: newDue, items, status},
      ...(credit > 0 ? {credit_id: creditRef.id, credit_amount: credit} : {}),
      ...(reductions.length
        ? {credit_reduced: reductions.map((r) => ({credit_id: r.id, amount: r.reduceBy, cancelled: r.cancel}))}
        : {}),
    });

    const patch = {
      items,
      total_amount: newTotal,
      ...(newPaid !== paid ? {paid_amount: newPaid} : {}),
      due_date: newDue,
      status,
      edit_history: history,
      last_edited_at: deps.FieldValue.serverTimestamp(),
      last_edited_by: callerUid,
      updated_at: deps.FieldValue.serverTimestamp(),
    };
    const cutoff = math.shiftedCutoff({
      oldDue: invoice.due_date,
      newDueKey: edit.dueDate,
      cutoff: invoice.access_cutoff_date,
    });
    if (cutoff) patch.access_cutoff_date = deps.Timestamp.fromDate(cutoff);
    tx.update(ref, patch);

    if (credit > 0) {
      const studentIds = Array.isArray(invoice.student_ids) ? invoice.student_ids.filter(Boolean) : [];
      const studentId = studentIds.length === 1 ? studentIds[0] : text(invoice.student_id);
      tx.set(creditRef, {
        parent_id: parentIdOf(invoice),
        ...(studentIds.length <= 1 && studentId ? {student_id: studentId} : {}),
        amount: credit,
        reason: `${numberOf(invoice, invoiceId)} lowered after payment: ${edit.reason}`,
        source: 'invoice_edit',
        status: 'open',
        used_on_invoice_id: null,
        invoice_id: invoiceId,
        created_at: deps.FieldValue.serverTimestamp(),
        created_by: callerUid,
        created_by_name: actor.name,
      });
    }

    for (const r of reductions) {
      const creditDoc = deps.db.collection('family_credits').doc(r.id);
      if (r.cancel) {
        tx.update(creditDoc, {
          status: 'cancelled',
          closed_at: deps.FieldValue.serverTimestamp(),
          closed_by: callerUid,
          cancel_reason: `${numberOf(invoice, invoiceId)} total raised again: ${edit.reason}`,
        });
      } else {
        tx.update(creditDoc, {
          amount: r.left,
          original_amount: r.amount,
          reduced_at: deps.FieldValue.serverTimestamp(),
          reduced_by: callerUid,
        });
      }
    }

    deps.audit(tx, {
      db: deps.db,
      entityType: 'invoice',
      entityId: invoiceId,
      entityLabel: numberOf(invoice, invoiceId),
      action: 'invoice.edited',
      actor,
      source: 'editInvoice',
      metadata: {
        reason: edit.reason,
        old_total: oldTotal,
        new_total: newTotal,
        old_paid: paid,
        new_paid: newPaid,
        credit_amount: credit,
        credit_taken_back: reducedTotal,
        parent_id: parentIdOf(invoice),
      },
      eventId: `invoice_edited_${invoiceId}_${history.length}`,
    });

    return {
      invoice: summaryOf(invoiceId, {
        ...invoice,
        items,
        total_amount: newTotal,
        paid_amount: newPaid,
        due_date: newDue,
        status,
      }),
      parentId: parentIdOf(invoice),
      number: numberOf(invoice, invoiceId),
      newTotal,
      credit,
    };
  });

  // Parent messages are OFF until the owner switches them on in Settings.
  if (await parentMessagesOn(deps.db)) {
    try {
      await deps.notifyParent(deps.db, {
        parentId: result.parentId,
        title: 'Invoice updated',
        body: `Your invoice ${result.number} was updated. New total ${money(result.newTotal)}.`,
        data: {type: 'invoice_updated', invoiceId, invoiceNumber: result.number},
      });
    } catch (error) {
      console.warn(`[editInvoice] parent notification failed for ${invoiceId}`, error && error.message);
    }
  }

  console.log(
    `[editInvoice] ${invoiceId} (${monthLabel(month)}) by ${callerUid}: ` +
      `total ${result.newTotal}${result.credit ? `, credit ${result.credit}` : ''}`
  );
  return {invoice: result.invoice, ...(result.credit > 0 ? {credit_id: creditRef.id} : {})};
};

/**
 * Cancel an invoice nothing has been paid on. Request: { invoice_id, reason }.
 * An open pay link is cancelled with it.
 */
const cancelInvoice = async (request, deps = defaultDeps()) => {
  const {callerUid} = await deps.verifyAdmin(request);
  const payload = (request && request.data) || {};
  const invoiceId = text(payload.invoice_id || payload.invoiceId);
  const reason = text(payload.reason);
  if (!invoiceId) throw httpsError('invalid-argument', 'Missing invoice_id.');
  if (!reason) throw httpsError('invalid-argument', 'Add a reason for cancelling.');

  const {ref} = await loadOpenInvoice(deps, invoiceId);
  const actor = await deps.resolveActor(deps.db, callerUid);

  const result = await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw httpsError('not-found', 'Invoice not found.');
    const invoice = snap.data() || {};
    if (math.isCancelled(invoice)) {
      throw httpsError('failed-precondition', 'This invoice is already cancelled.');
    }
    if (math.invoicePaid(invoice) > 0.004 || text(invoice.status).toLowerCase() === 'paid') {
      throw httpsError(
        'failed-precondition',
        'Only an invoice with nothing paid can be cancelled. Edit it to lower the total instead.'
      );
    }
    await assertOpenInTx(tx, deps, invoice);

    // Family credits this invoice used go back to the family. A credit used in
    // full is reopened as it was. A credit used in part was split when it was
    // applied: the used piece (amount = what this invoice took) is reopened
    // here and the remainder, a separate open credit, is left as it is, so the
    // family ends up with exactly the original amount in two open credits.
    const usedSnap = await tx.get(
      deps.db.collection('family_credits').where('used_on_invoice_id', '==', invoiceId)
    );
    const toReopen = usedSnap.docs.filter((d) => (d.data() || {}).status === 'used');

    const at = deps.Timestamp.fromDate(deps.now());
    const history = Array.isArray(invoice.edit_history) ? invoice.edit_history.slice() : [];
    history.push({
      at,
      by: callerUid,
      by_name: actor.name,
      action: 'cancelled',
      reason,
      before: snapshotOf(invoice),
      after: {status: 'cancelled'},
    });
    const patch = {
      status: 'cancelled',
      cancelled_at: deps.FieldValue.serverTimestamp(),
      cancelled_by: callerUid,
      cancelled_by_name: actor.name,
      cancel_reason: reason,
      edit_history: history,
      updated_at: deps.FieldValue.serverTimestamp(),
    };
    const linkStatus = text(invoice.pay_link_status).toLowerCase();
    if (text(invoice.pay_link_token) && linkStatus !== payLinks.PAY_LINK_CANCELLED) {
      patch.pay_link_status = payLinks.PAY_LINK_CANCELLED;
      patch.pay_link_cancelled_at = deps.FieldValue.serverTimestamp();
      patch.pay_link_cancelled_by = callerUid;
      patch.pay_link_pending = deps.FieldValue.delete();
    }
    if (toReopen.length) patch.credits_reopened = toReopen.map((d) => d.id);
    tx.update(ref, patch);
    for (const doc of toReopen) {
      tx.update(deps.db.collection('family_credits').doc(doc.id), {
        status: 'open',
        used_on_invoice_id: null,
        closed_at: deps.FieldValue.delete(),
        closed_by: deps.FieldValue.delete(),
        reopened_at: deps.FieldValue.serverTimestamp(),
        reopened_by: callerUid,
        reopened_because: `Invoice ${numberOf(invoice, invoiceId)} was cancelled`,
      });
    }

    deps.audit(tx, {
      db: deps.db,
      entityType: 'invoice',
      entityId: invoiceId,
      entityLabel: numberOf(invoice, invoiceId),
      action: 'invoice.cancelled',
      actor,
      source: 'cancelInvoice',
      metadata: {reason, parent_id: parentIdOf(invoice), credits_reopened: toReopen.length},
      eventId: `invoice_cancelled_${invoiceId}`,
    });
    return {parentId: parentIdOf(invoice), number: numberOf(invoice, invoiceId)};
  });

  if (await parentMessagesOn(deps.db)) {
    try {
      await deps.notifyParent(deps.db, {
        parentId: result.parentId,
        title: 'Invoice cancelled',
        body: `Your invoice ${result.number} was cancelled. Nothing is owed on it.`,
        data: {type: 'invoice_cancelled', invoiceId, invoiceNumber: result.number},
      });
    } catch (error) {
      console.warn(`[cancelInvoice] parent notification failed for ${invoiceId}`, error && error.message);
    }
  }
  return {ok: true};
};

/**
 * Re-send the invoice notice (amount due + pay link) to the parent now.
 * Works only while parent messages are on; nothing is sent otherwise.
 * Request: { invoice_id }
 */
const sendInvoiceReminder = async (request, deps = defaultDeps()) => {
  const {callerUid} = await deps.verifyAdmin(request);
  const payload = (request && request.data) || {};
  const invoiceId = text(payload.invoice_id || payload.invoiceId);
  if (!invoiceId) throw httpsError('invalid-argument', 'Missing invoice_id.');
  if (!(await parentMessagesOn(deps.db))) {
    throw httpsError('failed-precondition', 'Parent messages are off. Turn them on in Finance settings first.');
  }

  const ref = deps.db.collection('invoices').doc(invoiceId);
  const snap = await ref.get();
  if (!snap.exists) throw httpsError('not-found', 'Invoice not found.');
  const invoice = snap.data() || {};
  if (math.isCancelled(invoice) || math.balanceOf(invoice) <= 0.004) {
    throw httpsError('failed-precondition', 'Nothing is owed on this invoice.');
  }
  const actor = await deps.resolveActor(deps.db, callerUid);

  const outcome = await deps.resendInvoiceNotice(deps.db, invoiceId, {...invoice});
  const sent = Boolean(outcome && (outcome.emailSent || outcome.pushSent));

  const reminders = Array.isArray(invoice.reminders) ? invoice.reminders.slice() : [];
  reminders.push({
    at: deps.Timestamp.fromDate(deps.now()),
    kind: 'manual',
    by: callerUid,
    by_name: actor.name,
    sent,
  });
  await ref.update({reminders, updated_at: deps.FieldValue.serverTimestamp()});
  return {ok: true, sent};
};

module.exports = {
  editInvoice,
  cancelInvoice,
  sendInvoiceReminder,
  notifyParent,
};
