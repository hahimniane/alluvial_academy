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

/** Loads the invoice and refuses a closed month before anything is written. */
const loadOpenInvoice = async (deps, invoiceId) => {
  const ref = deps.db.collection('invoices').doc(invoiceId);
  const snap = await ref.get();
  if (!snap.exists) throw httpsError('not-found', 'Invoice not found.');
  const invoice = snap.data() || {};
  const month = math.invoiceBillingMonth(invoice);
  if (month) await deps.assertMonthOpen(deps.db, month);
  return {ref, invoice, month};
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

    const credit = math.creditOnLower({total: newTotal, paid});
    const status = math.statusAfterEdit({total: newTotal, paid});
    const newDue = deps.Timestamp.fromDate(math.dueTimestampDate(edit.dueDate));
    const at = deps.Timestamp.fromDate(deps.now());
    const history = Array.isArray(invoice.edit_history) ? invoice.edit_history.slice() : [];
    history.push({
      at,
      by: callerUid,
      by_name: actor.name,
      reason: edit.reason,
      before: snapshotOf(invoice),
      after: {total_amount: newTotal, due_date: newDue, items, status},
      ...(credit > 0 ? {credit_id: creditRef.id, credit_amount: credit} : {}),
    });

    const patch = {
      items,
      total_amount: newTotal,
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
        credit_amount: credit,
        parent_id: parentIdOf(invoice),
      },
      eventId: `invoice_edited_${invoiceId}_${history.length}`,
    });

    return {
      invoice: summaryOf(invoiceId, {
        ...invoice,
        items,
        total_amount: newTotal,
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
    tx.update(ref, patch);

    deps.audit(tx, {
      db: deps.db,
      entityType: 'invoice',
      entityId: invoiceId,
      entityLabel: numberOf(invoice, invoiceId),
      action: 'invoice.cancelled',
      actor,
      source: 'cancelInvoice',
      metadata: {reason, parent_id: parentIdOf(invoice)},
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
