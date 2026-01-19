const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onSchedule} = require('firebase-functions/v2/scheduler');

const {createPayoneerClient} = require('../services/payoneer/client');
const {generateInvoiceFromShifts} = require('../utils/invoice_generator');

const _isAdminRole = (data) => {
  if (!data) return false;
  return (
    data.role === 'admin' ||
    data.user_type === 'admin' ||
    data.userType === 'admin' ||
    data.is_admin === true ||
    data.isAdmin === true ||
    data.is_admin_teacher === true
  );
};

const _isAdminUid = async (uid) => {
  if (!uid) return false;
  const doc = await admin.firestore().collection('users').doc(uid).get();
  if (!doc.exists) return false;
  return _isAdminRole(doc.data());
};

const _toNumber = (value) => {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  const parsed = Number(value);
  return isNaN(parsed) ? 0 : parsed;
};

const _chunk = (arr, size) => {
  const out = [];
  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }
  return out;
};

const _nextInvoiceNumber = async (tx, year) => {
  const counterRef = admin.firestore().collection('invoice_counters').doc(String(year));
  const counterSnap = await tx.get(counterRef);
  const currentNext = counterSnap.exists ? _toNumber(counterSnap.data().next) : 1;
  const next = currentNext + 1;
  tx.set(
    counterRef,
    {
      next,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );
  const padded = String(currentNext).padStart(3, '0');
  return `INV-${year}-${padded}`;
};

const createInvoice = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const uid = request.auth.uid;
  const isAdmin = await _isAdminUid(uid);
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const data = request.data || {};
  const parentId = (data.parentId || data.parent_id || '').toString().trim();
  const studentId = (data.studentId || data.student_id || '').toString().trim();
  const currency = (data.currency || 'USD').toString().trim();
  const shiftIds = Array.isArray(data.shiftIds || data.shift_ids) ? data.shiftIds || data.shift_ids : [];

  if (!parentId || !studentId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: parentId, studentId'
    );
  }

  let invoicePayload = null;

  if (shiftIds.length > 0) {
    const shifts = [];
    const db = admin.firestore();
    for (const batch of _chunk(shiftIds, 10)) {
      const snap = await db
        .collection('teaching_shifts')
        .where(admin.firestore.FieldPath.documentId(), 'in', batch)
        .get();
      for (const doc of snap.docs) {
        shifts.push({id: doc.id, ...doc.data()});
      }
    }

    invoicePayload = generateInvoiceFromShifts({
      shifts,
      parentId,
      studentId,
      period: data.period,
      currency,
    });
  } else if (Array.isArray(data.items) && data.items.length > 0) {
    const items = data.items.map((i) => ({
      description: (i.description || '').toString(),
      quantity: _toNumber(i.quantity) || 1,
      unit_price: _toNumber(i.unit_price ?? i.unitPrice),
      total: _toNumber(i.total),
      shift_ids: Array.isArray(i.shift_ids || i.shiftIds) ? i.shift_ids || i.shiftIds : [],
    }));
    const totalAmount = Number(items.reduce((sum, i) => sum + _toNumber(i.total), 0).toFixed(2));
    invoicePayload = {
      parent_id: parentId,
      student_id: studentId,
      status: 'pending',
      total_amount: totalAmount,
      paid_amount: 0,
      currency,
      issued_date: admin.firestore.FieldValue.serverTimestamp(),
      due_date: admin.firestore.FieldValue.serverTimestamp(),
      items,
      shift_ids: [],
    };
  } else {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Provide shiftIds or items to create an invoice'
    );
  }

  const db = admin.firestore();
  const invoiceRef = db.collection('invoices').doc();

  const result = await db.runTransaction(async (tx) => {
    const now = new Date();
    const invoiceNumber = await _nextInvoiceNumber(tx, now.getUTCFullYear());
    tx.set(invoiceRef, {
      invoice_number: invoiceNumber,
      parent_id: invoicePayload.parent_id,
      student_id: invoicePayload.student_id,
      status: invoicePayload.status,
      total_amount: invoicePayload.total_amount,
      paid_amount: invoicePayload.paid_amount,
      currency: invoicePayload.currency,
      issued_date: invoicePayload.issued_date || admin.firestore.Timestamp.fromDate(now),
      due_date:
        invoicePayload.due_date ||
        admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000)),
      items: invoicePayload.items || [],
      shift_ids: invoicePayload.shift_ids || [],
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      created_by: uid,
      period: invoicePayload.period || null,
    });
    return {invoiceId: invoiceRef.id, invoiceNumber};
  });

  return {success: true, ...result};
};

const getParentInvoices = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const data = request.data || {};
  const parentId = (data.parentId || data.parent_id || request.auth.uid || '').toString().trim();
  const status = (data.status || '').toString().trim();
  const limit = Math.min(100, Math.max(1, _toNumber(data.limit) || 50));

  if (!parentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing parentId');
  }

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!isAdmin && request.auth.uid !== parentId) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot read invoices for another user');
  }

  let query = admin.firestore().collection('invoices').where('parent_id', '==', parentId);
  if (status) {
    query = query.where('status', '==', status);
  }

  const snap = await query.orderBy('due_date', 'desc').limit(limit).get();
  const invoices = snap.docs.map((d) => ({id: d.id, ...d.data()}));
  return {success: true, invoices};
};

const getPaymentHistory = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const data = request.data || {};
  const parentId = (data.parentId || data.parent_id || request.auth.uid || '').toString().trim();
  const limit = Math.min(100, Math.max(1, _toNumber(data.limit) || 50));

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!isAdmin && request.auth.uid !== parentId) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot read payments for another user');
  }

  const snap = await admin
    .firestore()
    .collection('payments')
    .where('parent_id', '==', parentId)
    .orderBy('created_at', 'desc')
    .limit(limit)
    .get();

  const payments = snap.docs.map((d) => ({id: d.id, ...d.data()}));
  return {success: true, payments};
};

const createPaymentSession = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const data = request.data || {};
  const invoiceId = (data.invoiceId || data.invoice_id || '').toString().trim();
  if (!invoiceId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing invoiceId');
  }

  const db = admin.firestore();
  const invoiceRef = db.collection('invoices').doc(invoiceId);
  const invoiceSnap = await invoiceRef.get();
  if (!invoiceSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Invoice not found');
  }

  const invoice = invoiceSnap.data();
  const parentId = (invoice.parent_id || '').toString();
  const currency = (invoice.currency || 'USD').toString();
  const totalAmount = _toNumber(invoice.total_amount);
  const paidAmount = _toNumber(invoice.paid_amount);
  const remaining = Number((totalAmount - paidAmount).toFixed(2));

  if (remaining <= 0) {
    throw new functions.https.HttpsError('failed-precondition', 'Invoice is already paid');
  }

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!isAdmin && request.auth.uid !== parentId) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot pay another user’s invoice');
  }

  const paymentRef = db.collection('payments').doc();
  await paymentRef.set({
    invoice_id: invoiceId,
    parent_id: parentId,
    amount: remaining,
    status: 'pending',
    payment_method: 'payoneer',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  const payoneer = createPayoneerClient();

  try {
    const session = await payoneer.createCheckoutSession({
      amount: remaining,
      currency,
      paymentId: paymentRef.id,
    });

    await paymentRef.set(
      {
        payoneer_session_id: session.sessionId,
        status: 'processing',
        checkout_url: session.checkoutUrl,
      },
      {merge: true}
    );

    return {
      success: true,
      paymentId: paymentRef.id,
      checkoutUrl: session.checkoutUrl,
      mock: payoneer.config.isMock,
    };
  } catch (err) {
    await paymentRef.set(
      {
        status: 'failed',
        error_message: err.message || String(err),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    throw new functions.https.HttpsError('internal', err.message || String(err));
  }
};

const handlePayoneerWebhook = async (req, res) => {
  // CORS preflight support
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, x-webhook-secret');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({error: 'Method Not Allowed'});
    return;
  }

  const payoneer = createPayoneerClient();
  const verification = payoneer.verifyWebhook(req);
  if (!verification.ok) {
    res.status(401).json({error: 'Unauthorized', reason: verification.reason});
    return;
  }

  const body = req.body || {};
  const paymentId = (body.paymentId || body.payment_id || '').toString().trim();
  const status = (body.status || '').toString().trim().toLowerCase();
  const transactionId = (body.transactionId || body.transaction_id || '').toString().trim();

  if (!paymentId || !status) {
    res.status(400).json({error: 'Missing paymentId or status'});
    return;
  }

  const db = admin.firestore();
  const paymentRef = db.collection('payments').doc(paymentId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const paymentSnap = await tx.get(paymentRef);
      if (!paymentSnap.exists) {
        throw new Error('Payment not found');
      }
      const payment = paymentSnap.data();
      const invoiceId = (payment.invoice_id || '').toString();
      const invoiceRef = db.collection('invoices').doc(invoiceId);
      const invoiceSnap = await tx.get(invoiceRef);
      if (!invoiceSnap.exists) {
        throw new Error('Invoice not found');
      }

      const currentPaymentStatus = (payment.status || '').toString();
      const amount = _toNumber(payment.amount);
      const invoice = invoiceSnap.data();
      const currentPaid = _toNumber(invoice.paid_amount);
      const total = _toNumber(invoice.total_amount);
      const dueDate = invoice.due_date?.toDate ? invoice.due_date.toDate() : null;

      if (currentPaymentStatus === 'completed' && status === 'completed') {
        return {alreadyProcessed: true};
      }

      if (status === 'completed') {
        const newPaid = Number((currentPaid + amount).toFixed(2));
        const invoiceStatus =
          newPaid >= total
            ? 'paid'
            : dueDate && dueDate.getTime() < Date.now()
            ? 'overdue'
            : 'pending';

        tx.set(
          paymentRef,
          {
            status: 'completed',
            payoneer_transaction_id: transactionId || payment.payoneer_transaction_id || null,
            completed_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );

        tx.set(
          invoiceRef,
          {
            paid_amount: newPaid,
            status: invoiceStatus,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );

        return {updated: true, invoiceStatus, newPaid};
      }

      if (status === 'failed') {
        tx.set(
          paymentRef,
          {
            status: 'failed',
            payoneer_transaction_id: transactionId || payment.payoneer_transaction_id || null,
            completed_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
        return {updated: true};
      }

      tx.set(
        paymentRef,
        {
          status,
          payoneer_transaction_id: transactionId || payment.payoneer_transaction_id || null,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );

      return {updated: true};
    });

    res.status(200).json({success: true, ...result});
  } catch (err) {
    console.error('handlePayoneerWebhook error:', err);
    res.status(500).json({error: err.message || String(err)});
  }
};

const generateInvoicesForPeriod = onSchedule(
  // Cloud Scheduler accepts cron syntax; this runs at 00:00 UTC on day 1 of every month.
  {schedule: '0 0 1 * *', timeZone: 'Etc/UTC'},
  async () => {
    if (process.env.ENABLE_INVOICE_GENERATION !== 'true') {
      console.log('Invoice generation is disabled. Set ENABLE_INVOICE_GENERATION=true to enable.');
      return;
    }

    // Intentionally conservative: invoice generation rules are business-critical.
    // Implement full shift→invoice logic once billing requirements are finalized.
    console.log('Invoice generation is enabled, but automated logic is not implemented yet.');
  }
);

module.exports = {
  createInvoice,
  getParentInvoices,
  createPaymentSession,
  handlePayoneerWebhook,
  getPaymentHistory,
  generateInvoicesForPeriod,
};
