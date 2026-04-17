const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onSchedule} = require('firebase-functions/v2/scheduler');

const {createPayoneerClient} = require('../services/payoneer/client');
const stripeCheckout = require('../services/stripe/checkout');
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

  // Parse optional access cutoff date (ISO string from client)
  const rawAccessCutoff = data.accessCutoffDate || data.access_cutoff_date;
  let accessCutoffTimestamp = null;
  if (rawAccessCutoff) {
    const parsed = new Date(rawAccessCutoff);
    if (!isNaN(parsed.getTime())) {
      accessCutoffTimestamp = admin.firestore.Timestamp.fromDate(parsed);
    }
  }

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
    const periodFromRequest = (data.period || data.period_label || '').toString().trim();

    // Accept an explicit due date from the client (ISO string); fall back to 7 days from now.
    const rawDueDate = data.dueDate || data.due_date;
    let dueDateTimestamp;
    if (rawDueDate) {
      const parsed = new Date(rawDueDate);
      dueDateTimestamp = isNaN(parsed.getTime())
        ? null
        : admin.firestore.Timestamp.fromDate(parsed);
    }

    invoicePayload = {
      parent_id: parentId,
      student_id: studentId,
      status: 'pending',
      total_amount: totalAmount,
      paid_amount: 0,
      currency,
      issued_date: admin.firestore.FieldValue.serverTimestamp(),
      due_date: dueDateTimestamp || null,
      access_cutoff_date: accessCutoffTimestamp || null,
      items,
      shift_ids: [],
      period: periodFromRequest || null,
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
        admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000)),
      access_cutoff_date: (() => {
        if (invoicePayload.access_cutoff_date) return invoicePayload.access_cutoff_date;
        // Default: due_date + 1 day
        const dueDate = invoicePayload.due_date
          ? invoicePayload.due_date.toDate()
          : new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
        return admin.firestore.Timestamp.fromDate(
          new Date(dueDate.getTime() + 24 * 60 * 60 * 1000)
        );
      })(),
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

/**
 * Shared Firestore transaction: update payment + invoice when a provider reports a final status.
 * @param {FirebaseFirestore.Transaction} tx
 * @param {FirebaseFirestore.Firestore} db
 * @param {FirebaseFirestore.DocumentReference} paymentRef
 * @param {{ status: string, extraPaymentFields?: Record<string, unknown> }} params
 */
const applyPaymentStatusInTransaction = async (tx, db, paymentRef, {status, extraPaymentFields = {}}) => {
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

  const normalized = (status || '').toString().trim().toLowerCase();

  if (currentPaymentStatus === 'completed' && normalized === 'completed') {
    return {alreadyProcessed: true};
  }

  if (normalized === 'completed') {
    const newPaid = Number((currentPaid + amount).toFixed(2));
    const invoiceStatus =
      newPaid >= total ? 'paid' : dueDate && dueDate.getTime() < Date.now() ? 'overdue' : 'pending';

    tx.set(
      paymentRef,
      {
        status: 'completed',
        ...extraPaymentFields,
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

  if (normalized === 'failed') {
    tx.set(
      paymentRef,
      {
        status: 'failed',
        ...extraPaymentFields,
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
      status: normalized,
      ...extraPaymentFields,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );

  return {updated: true};
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
  const invoiceNumber = (invoice.invoice_number || '').toString();
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

  if (stripeCheckout.isStripeConfigured()) {
    const {success: successUrl, cancel: cancelUrl} = stripeCheckout.getCheckoutUrls();
    if (!successUrl || !cancelUrl) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe is configured but STRIPE_CHECKOUT_SUCCESS_URL and STRIPE_CHECKOUT_CANCEL_URL must be set (absolute URLs, e.g. your Flutter web parent invoices page).'
      );
    }

    await paymentRef.set({
      invoice_id: invoiceId,
      parent_id: parentId,
      amount: remaining,
      status: 'pending',
      payment_method: 'stripe',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    const Stripe = require('stripe');
    const stripe = new Stripe(stripeCheckout.getStripeSecretKey());

    try {
      const session = await stripeCheckout.createCheckoutSession({
        stripe,
        amountMajor: remaining,
        currency,
        paymentId: paymentRef.id,
        invoiceId,
        invoiceNumber,
        successUrl,
        cancelUrl,
        customerEmail: request.auth.token?.email || undefined,
      });

      await paymentRef.set(
        {
          stripe_checkout_session_id: session.id,
          status: 'processing',
          checkout_url: session.url,
        },
        {merge: true}
      );

      return {
        success: true,
        paymentId: paymentRef.id,
        checkoutUrl: session.url,
        provider: 'stripe',
      };
    } catch (err) {
      console.error('createPaymentSession (Stripe) error:', err);
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
  }

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
      provider: 'payoneer',
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

/**
 * Creates a PaymentIntent for in-app (mobile) Payment Sheet.
 * Returns client_secret, ephemeralKey, customer, and publishableKey.
 */
const createPaymentIntent = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const data = request.data || {};
  const invoiceId = (data.invoiceId || data.invoice_id || '').toString().trim();
  if (!invoiceId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing invoiceId');
  }

  if (!stripeCheckout.isStripeConfigured()) {
    throw new functions.https.HttpsError('failed-precondition', 'Stripe is not configured');
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
    throw new functions.https.HttpsError('permission-denied', 'Cannot pay another user\'s invoice');
  }

  const Stripe = require('stripe');
  const stripe = new Stripe(stripeCheckout.getStripeSecretKey());

  // Get or create Stripe Customer
  const userDoc = await db.collection('users').doc(parentId).get();
  const userData = userDoc.exists ? userDoc.data() : {};
  const email = request.auth.token?.email || userData['e-mail'] || undefined;
  const name = [userData.first_name, userData.last_name].filter(Boolean).join(' ') || undefined;

  const customerId = await stripeCheckout.getOrCreateCustomer({
    stripe,
    parentId,
    email,
    name,
  });

  // Create payment record in Firestore
  const paymentRef = db.collection('payments').doc();
  await paymentRef.set({
    invoice_id: invoiceId,
    parent_id: parentId,
    amount: remaining,
    status: 'pending',
    payment_method: 'stripe',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    const {paymentIntent, ephemeralKey} = await stripeCheckout.createPaymentIntentForSheet({
      stripe,
      amountMajor: remaining,
      currency,
      customerId,
      paymentId: paymentRef.id,
      invoiceId,
    });

    await paymentRef.set(
      {
        stripe_payment_intent_id: paymentIntent.id,
        status: 'processing',
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    return {
      success: true,
      paymentId: paymentRef.id,
      paymentIntent: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customer: customerId,
      publishableKey: stripeCheckout.getStripePublishableKey(),
    };
  } catch (err) {
    console.error('createPaymentIntent error:', err);
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
      const extra = {
        payoneer_transaction_id: transactionId || payment.payoneer_transaction_id || null,
      };
      return applyPaymentStatusInTransaction(tx, db, paymentRef, {
        status,
        extraPaymentFields: extra,
      });
    });

    res.status(200).json({success: true, ...result});
  } catch (err) {
    console.error('handlePayoneerWebhook error:', err);
    res.status(500).json({error: err.message || String(err)});
  }
};

/**
 * Stripe sends signed webhook events. Configure the endpoint URL in the Stripe Dashboard
 * and set STRIPE_WEBHOOK_SECRET (from the Dashboard signing secret).
 * Requires raw body (Firebase v1 HTTP functions provide req.rawBody).
 */
const handleStripeWebhook = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const webhookSecret = (process.env.STRIPE_WEBHOOK_SECRET || '').trim();
  const stripeSecretKey = stripeCheckout.getStripeSecretKey();
  if (!webhookSecret || !stripeSecretKey) {
    console.error('Stripe webhook: STRIPE_WEBHOOK_SECRET or STRIPE_SECRET_KEY not set');
    res.status(500).send('Stripe webhook not configured');
    return;
  }

  const Stripe = require('stripe');
  const stripe = new Stripe(stripeSecretKey);
  const sig = req.headers['stripe-signature'];
  let event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error('Stripe webhook signature verification failed:', err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  const db = admin.firestore();

  const paymentIntentIdFromSession = (session) => {
    const pi = session.payment_intent;
    if (typeof pi === 'string') return pi;
    if (pi && typeof pi === 'object' && pi.id) return pi.id;
    return null;
  };

  try {
    if (event.type === 'checkout.session.expired') {
      const session = event.data.object;
      const paymentId = ((session.metadata && session.metadata.payment_id) || '').toString().trim();
      if (paymentId) {
        const paymentRef = db.collection('payments').doc(paymentId);
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(paymentRef);
          if (!snap.exists) return;
          const st = (snap.data().status || '').toString();
          if (st === 'completed') return;
          await applyPaymentStatusInTransaction(tx, db, paymentRef, {
            status: 'failed',
            extraPaymentFields: {stripe_checkout_session_id: session.id},
          });
        });
      }
      res.json({received: true});
      return;
    }

    if (
      event.type === 'checkout.session.async_payment_succeeded' ||
      (event.type === 'checkout.session.completed' && event.data.object.payment_status === 'paid')
    ) {
      const session = event.data.object;
      const paymentId = ((session.metadata && session.metadata.payment_id) || '').toString().trim();
      if (!paymentId) {
        console.warn('Stripe webhook: missing payment_id metadata on session', session.id);
        res.json({received: true, ignored: 'no payment_id'});
        return;
      }
      const paymentRef = db.collection('payments').doc(paymentId);
      const intentId = paymentIntentIdFromSession(session);
      const result = await db.runTransaction(async (tx) => {
        return applyPaymentStatusInTransaction(tx, db, paymentRef, {
          status: 'completed',
          extraPaymentFields: {
            stripe_checkout_session_id: session.id,
            ...(intentId ? {stripe_payment_intent_id: intentId} : {}),
          },
        });
      });
      res.json({received: true, ...result});
      return;
    }

    // Handle PaymentIntent succeeded (from mobile Payment Sheet)
    if (event.type === 'payment_intent.succeeded') {
      const intent = event.data.object;
      const paymentId = ((intent.metadata && intent.metadata.payment_id) || '').toString().trim();
      if (!paymentId) {
        console.warn('Stripe webhook: missing payment_id metadata on payment_intent', intent.id);
        res.json({received: true, ignored: 'no payment_id'});
        return;
      }
      const paymentRef = db.collection('payments').doc(paymentId);
      const result = await db.runTransaction(async (tx) => {
        return applyPaymentStatusInTransaction(tx, db, paymentRef, {
          status: 'completed',
          extraPaymentFields: {
            stripe_payment_intent_id: intent.id,
          },
        });
      });
      res.json({received: true, ...result});
      return;
    }

    // Handle PaymentIntent failed
    if (event.type === 'payment_intent.payment_failed') {
      const intent = event.data.object;
      const paymentId = ((intent.metadata && intent.metadata.payment_id) || '').toString().trim();
      if (paymentId) {
        const paymentRef = db.collection('payments').doc(paymentId);
        await db.runTransaction(async (tx) => {
          return applyPaymentStatusInTransaction(tx, db, paymentRef, {
            status: 'failed',
            extraPaymentFields: {stripe_payment_intent_id: intent.id},
          });
        });
      }
      res.json({received: true});
      return;
    }

    res.json({received: true, ignored: event.type});
  } catch (err) {
    console.error('handleStripeWebhook error:', err);
    res.status(500).send(err.message || String(err));
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
  createPaymentIntent,
  handlePayoneerWebhook,
  handleStripeWebhook,
  getPaymentHistory,
  generateInvoicesForPeriod,
};
