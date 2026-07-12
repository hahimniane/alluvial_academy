const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

const { createPayoneerClient } = require('../services/payoneer/client');
const stripeCheckout = require('../services/stripe/checkout');
const { generateInvoiceFromShifts } = require('../utils/invoice_generator');
const { generateInvoicePdfBuffer } = require('../utils/invoice_pdf');
const {
  sendInvoiceCreatedEmail,
  sendPaymentConfirmationEmail
} = require('../services/email/senders');

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

const _invoiceAccessIds = (invoice = {}) => ({
  parentId: (invoice.parent_id || invoice.parentId || '').toString().trim(),
  studentId: (invoice.student_id || invoice.studentId || '').toString().trim(),
  payerId: (invoice.payer_id || invoice.payerId || '').toString().trim(),
});

const _canUserPayInvoice = ({uid, isAdmin = false, invoice = {}}) => {
  if (isAdmin) return true;
  const normalizedUid = (uid || '').toString().trim();
  if (!normalizedUid) return false;

  const {parentId, studentId, payerId} = _invoiceAccessIds(invoice);
  return [parentId, studentId, payerId].some((id) => id === normalizedUid);
};

const _assertStripeConfiguration = () => {
  try {
    return stripeCheckout.assertStripeConfiguration();
  } catch (error) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      error.message || String(error)
    );
  }
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

const _normalizeBillingMonths = (value) => {
  const parsed = Math.round(_toNumber(value) || 1);
  return Math.min(24, Math.max(1, parsed));
};

const _normalizeInvoiceItems = (rawItems) => {
  if (!Array.isArray(rawItems)) return [];
  return rawItems.map((i) => {
    const quantity = _toNumber(i.quantity) || 1;
    const unitPrice = _toNumber(i.unit_price ?? i.unitPrice);
    const explicitTotal = _toNumber(i.total);
    const total = explicitTotal || Number((quantity * unitPrice).toFixed(2));
    return {
      description: (i.description || '').toString(),
      quantity,
      unit_price: unitPrice,
      total,
      shift_ids: Array.isArray(i.shift_ids || i.shiftIds)
        ? i.shift_ids || i.shiftIds
        : []
    };
  });
};

const _normalizePeriod = (value) => {
  const raw = (value || '').toString().trim();
  const match = raw.match(/(\d{4})-(\d{2})/);
  if (!match) return null;
  const month = Number(match[2]);
  if (month < 1 || month > 12) return null;
  return `${match[1]}-${String(month).padStart(2, '0')}`;
};

const _periodToDate = (period) => {
  const normalized = _normalizePeriod(period);
  if (!normalized) return null;
  const [year, month] = normalized.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, 1));
};

const _formatPeriodDate = (date) =>
  `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;

const _addMonthsToPeriod = (period, months) => {
  const date = _periodToDate(period);
  if (!date) return null;
  return _formatPeriodDate(
    new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1))
  );
};

const _comparePeriods = (a, b) => {
  const aDate = _periodToDate(a);
  const bDate = _periodToDate(b);
  if (!aDate || !bDate) return 0;
  return aDate.getTime() - bDate.getTime();
};

const _periodMonthLabel = (period) => {
  const date = _periodToDate(period);
  if (!date) return period || '';
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC'
  }).format(date);
};

const _periodRangeLabel = (periodStart, periodEnd) => {
  if (!periodStart || !periodEnd || periodStart === periodEnd) {
    return _periodMonthLabel(periodStart || periodEnd);
  }
  return `${_periodMonthLabel(periodStart)} - ${_periodMonthLabel(periodEnd)}`;
};

const _dateForPeriodDay = (period, day) => {
  const date = _periodToDate(period);
  if (!date) return new Date();
  const safeDay = Math.min(
    Math.max(1, Math.round(_toNumber(day) || 1)),
    new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate()
  );
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), safeDay)
  );
};

const _itemsForBillingPeriod = ({
  items,
  billingMonths,
  periodLabel,
  alreadyExpanded = false
}) => {
  return _normalizeInvoiceItems(items).map((item) => {
    const baseTotal = _toNumber(item.total);
    const total = alreadyExpanded
      ? baseTotal
      : Number((baseTotal * billingMonths).toFixed(2));
    return {
      ...item,
      description: periodLabel
        ? `${item.description} · ${periodLabel}`
        : item.description,
      unit_price: total,
      total
    };
  });
};

const _toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return isNaN(parsed.getTime()) ? null : parsed;
};

const _displayNameForUser = (data) =>
  [data?.first_name, data?.last_name].filter(Boolean).join(' ').trim() ||
  [data?.firstName, data?.lastName].filter(Boolean).join(' ').trim() ||
  data?.display_name ||
  data?.displayName ||
  data?.name ||
  'Parent / Guardian';

const _displayNameById = async (db, userId) => {
  const id = (userId || '').toString().trim();
  if (!id) return null;
  const snap = await db.collection('users').doc(id).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  const name = _displayNameForUser(data);
  return name === 'Parent / Guardian' ? null : name;
};

const _formatMoney = (amount, currency) => {
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: (currency || 'USD').toString().toUpperCase()
    }).format(amount);
  } catch (error) {
    return `${currency || 'USD'} ${amount.toFixed(2)}`;
  }
};

const _formatDueDate = (value) => {
  const dueDate = _toDate(value);
  if (!dueDate) return '';
  return dueDate.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
};

const _appUrl = () =>
  (
    process.env.APP_URL ||
    process.env.PUBLIC_APP_URL ||
    'https://alluwaleducationhub.org'
  ).trim();

const _invoicePdfAttachment = ({
  invoiceNumber,
  invoice,
  parentName,
  studentName
}) => {
  const filename = `${invoiceNumber || 'invoice'}.pdf`.replace(
    /[^a-zA-Z0-9._-]/g,
    '_'
  );
  const content = generateInvoicePdfBuffer({
    ...invoice,
    id: invoice?.id,
    invoiceNumber,
    parentName,
    studentName
  });

  return {
    filename,
    content,
    contentType: 'application/pdf'
  };
};

const _paymentMethodLabel = (value) => {
  const method = (value || '').toString().trim().toLowerCase();
  if (method === 'stripe') return 'Card / Stripe';
  if (method === 'payoneer') return 'Payoneer';
  if (method === 'zelle') return 'Zelle';
  if (method === 'cash_app' || method === 'cashapp') return 'Cash App';
  if (method === 'bank_transfer') return 'Bank transfer';
  if (method === 'moneygram') return 'MoneyGram';
  if (method === 'western_union') return 'Western Union';
  if (method === 'cash') return 'Cash';
  if (method === 'check') return 'Check';
  if (!method) return '';
  return method.charAt(0).toUpperCase() + method.slice(1);
};

const _normalizeManualPaymentMethod = (value) => {
  const raw = (value || '').toString().trim().toLowerCase();
  const compact = raw.replace(/[\s-]+/g, '_');
  switch (compact) {
    case 'zelle':
      return 'zelle';
    case 'cashapp':
    case 'cash_app':
      return 'cash_app';
    case 'bank':
    case 'bank_transfer':
    case 'wire':
    case 'wire_transfer':
      return 'bank_transfer';
    case 'moneygram':
      return 'moneygram';
    case 'westernunion':
    case 'western_union':
      return 'western_union';
    case 'cash':
      return 'cash';
    case 'check':
    case 'cheque':
      return 'check';
    case 'other':
      return 'other';
    default:
      return raw ? 'other' : '';
  }
};

const _notifyPaymentCompleted = async (db, paymentId, paymentInfo) => {
  const parentId = (paymentInfo.parentId || '').toString().trim();
  const studentId = (paymentInfo.studentId || '').toString().trim();
  const recipientIds = [...new Set([parentId, studentId].filter(Boolean))];

  if (recipientIds.length === 0) {
    console.warn(
      `[payments] Payment ${paymentId} has no parent or student id; skipping confirmation email.`
    );
    return { success: false, reason: 'missing_recipient_id' };
  }

  let payerId = null;
  let userSnap = null;
  for (const candidateId of recipientIds) {
    const candidateSnap = await db.collection('users').doc(candidateId).get();
    if (candidateSnap.exists) {
      payerId = candidateId;
      userSnap = candidateSnap;
      break;
    }
  }

  if (!payerId || !userSnap) {
    console.warn(
      `[payments] Payment ${paymentId} recipient not found; checked ${recipientIds.join(', ')}.`
    );
    return { success: false, reason: 'recipient_not_found' };
  }

  const userData = userSnap.data() || {};
  const email = (userData['e-mail'] || userData.email || '').toString().trim();
  if (!email) {
    return { success: false, reason: 'recipient_has_no_email', payerId };
  }

  await sendPaymentConfirmationEmail({
    email,
    displayName: _displayNameForUser(userData),
    invoiceNumber: paymentInfo.invoiceNumber,
    amountPaid: _formatMoney(paymentInfo.amount, paymentInfo.currency),
    paymentDate: _formatDueDate(new Date()),
    paymentMethod: _paymentMethodLabel(paymentInfo.paymentMethod),
    appUrl: _appUrl()
  });

  try {
    await db.collection('notification_history').add({
      sentBy: 'system',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      recipientType: 'individual',
      recipientIds: [payerId],
      title: 'Payment received',
      body: `Payment received for ${paymentInfo.invoiceNumber}. Amount: ${_formatMoney(paymentInfo.amount, paymentInfo.currency)}.`,
      additionalData: {
        type: 'payment_completed',
        paymentId,
        invoiceId: paymentInfo.invoiceId,
        invoiceNumber: paymentInfo.invoiceNumber
      },
      emailRequested: true,
      results: {
        totalRecipients: 1,
        fcmSuccess: 0,
        fcmFailed: 0,
        emailsSent: 1,
        emailsFailed: 0
      }
    });
  } catch (error) {
    console.error(
      `[payments] Failed to save payment confirmation history for ${paymentId}:`,
      error
    );
  }

  return { success: true, payerId, emailSent: true };
};

const _tokensForUser = (userData) => {
  const tokenSet = new Set();
  const fcmTokens = Array.isArray(userData?.fcmTokens)
    ? userData.fcmTokens
    : [];
  for (const tokenData of fcmTokens) {
    if (tokenData?.token) tokenSet.add(tokenData.token);
  }
  if (userData?.fcmToken) tokenSet.add(userData.fcmToken);
  return [...tokenSet];
};

const _sendInvoicePushNotification = async ({
  userId,
  userData,
  invoiceId,
  invoiceNumber,
  amountDue
}) => {
  const tokens = _tokensForUser(userData);
  if (tokens.length === 0) {
    return { sent: false, reason: 'no_fcm_tokens' };
  }

  const title = 'New invoice available';
  const body = `${invoiceNumber} is ready. Amount due: ${amountDue}.`;
  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      type: 'invoice_created',
      invoiceId: String(invoiceId),
      invoiceNumber: String(invoiceNumber),
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'high_importance_channel',
        sound: 'default'
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1
        }
      }
    }
  });

  const tokensToRemove = [];
  response.responses.forEach((result, index) => {
    const code = result.error?.code;
    if (
      !result.success &&
      (code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered')
    ) {
      tokensToRemove.push(tokens[index]);
    }
  });

  if (tokensToRemove.length > 0) {
    const currentTokens = Array.isArray(userData.fcmTokens)
      ? userData.fcmTokens
      : [];
    const update = {
      fcmTokens: currentTokens.filter(
        (entry) => entry?.token && !tokensToRemove.includes(entry.token)
      )
    };
    if (userData.fcmToken && tokensToRemove.includes(userData.fcmToken)) {
      update.fcmToken = admin.firestore.FieldValue.delete();
    }
    await admin
      .firestore()
      .collection('users')
      .doc(userId)
      .set(update, { merge: true });
  }

  return {
    sent: response.successCount > 0,
    successCount: response.successCount,
    failureCount: response.failureCount
  };
};

const _notifyInvoiceRecipient = async (db, invoiceId, invoice) => {
  const parentId = (
    invoice?.parent_id ||
    invoice?.parentId ||
    invoice?.payer_id ||
    invoice?.payerId ||
    ''
  )
    .toString()
    .trim();
  const studentId = (invoice?.student_id || invoice?.studentId || '')
    .toString()
    .trim();
  const recipientIds = [...new Set([parentId, studentId].filter(Boolean))];

  if (recipientIds.length === 0) {
    console.warn(
      `[payments] Invoice ${invoiceId} has no parent or student id; skipping notification.`
    );
    return { success: false, reason: 'missing_payer_id' };
  }

  let payerId = null;
  let userSnap = null;
  for (const candidateId of recipientIds) {
    const candidateSnap = await db.collection('users').doc(candidateId).get();
    if (candidateSnap.exists) {
      payerId = candidateId;
      userSnap = candidateSnap;
      break;
    }
  }

  if (!payerId || !userSnap) {
    console.warn(
      `[payments] Invoice ${invoiceId} payer not found; checked ${recipientIds.join(', ')}.`
    );
    return { success: false, reason: 'payer_not_found' };
  }

  const userData = userSnap.data() || {};
  const email = (userData['e-mail'] || userData.email || '').toString().trim();
  const displayName = _displayNameForUser(userData);
  const parentName = parentId ? await _displayNameById(db, parentId) : null;
  const studentName = studentId ? await _displayNameById(db, studentId) : null;
  const invoiceNumber = (
    invoice.invoice_number ||
    invoice.invoiceNumber ||
    invoiceId
  ).toString();
  const totalAmount = _toNumber(invoice.total_amount ?? invoice.totalAmount);
  const paidAmount = _toNumber(invoice.paid_amount ?? invoice.paidAmount);
  const currency = (invoice.currency || 'USD').toString();
  const amountDue = _formatMoney(
    Math.max(0, totalAmount - paidAmount),
    currency
  );
  const dueDate = _formatDueDate(invoice.due_date || invoice.dueDate);
  const accessCutoffDate = _formatDueDate(
    invoice.access_cutoff_date || invoice.accessCutoffDate
  );

  const result = {
    success: true,
    payerId,
    emailSent: false,
    pushSent: false,
    errors: []
  };

  if (email) {
    try {
      const attachment = _invoicePdfAttachment({
        invoiceNumber,
        invoice,
        parentName: parentName || (parentId ? displayName : null),
        studentName: studentName || studentId
      });
      await sendInvoiceCreatedEmail({
        email,
        displayName,
        invoiceNumber,
        amountDue,
        dueDate,
        accessCutoffDate,
        appUrl: _appUrl(),
        attachments: [attachment]
      });
      result.emailSent = true;
    } catch (error) {
      console.error(
        `[payments] Failed to send invoice email for ${invoiceId}:`,
        error
      );
      result.errors.push(`email: ${error.message}`);
    }
  } else {
    result.errors.push('email: payer has no email');
  }

  try {
    const pushResult = await _sendInvoicePushNotification({
      userId: payerId,
      userData,
      invoiceId,
      invoiceNumber,
      amountDue
    });
    result.pushSent = pushResult.sent === true;
    result.push = pushResult;
  } catch (error) {
    console.error(
      `[payments] Failed to send invoice app notification for ${invoiceId}:`,
      error
    );
    result.errors.push(`push: ${error.message}`);
  }

  try {
    await db.collection('notification_history').add({
      sentBy: 'system',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      recipientType: 'individual',
      recipientIds: [payerId],
      title: 'New invoice available',
      body: `${invoiceNumber} is ready. Amount due: ${amountDue}.`,
      additionalData: {
        type: 'invoice_created',
        invoiceId,
        invoiceNumber
      },
      emailRequested: true,
      results: {
        totalRecipients: 1,
        fcmSuccess: result.pushSent ? 1 : 0,
        fcmFailed: result.pushSent ? 0 : 1,
        emailsSent: result.emailSent ? 1 : 0,
        emailsFailed: result.emailSent ? 0 : 1
      }
    });
  } catch (error) {
    console.error(
      `[payments] Failed to save invoice notification history for ${invoiceId}:`,
      error
    );
  }

  return result;
};

const _invoiceNotificationSucceeded = (result) =>
  result?.success === true &&
  (result.emailSent === true || result.pushSent === true);

const _invoiceNotificationUpdate = (result) => {
  const succeeded = _invoiceNotificationSucceeded(result);
  return {
    notification_status: succeeded ? 'sent' : 'failed',
    notification_result: {
      success: result?.success === true,
      reason: result?.reason || null,
      payer_id: result?.payerId || null,
      email_sent: result?.emailSent === true,
      push_sent: result?.pushSent === true,
      errors: Array.isArray(result?.errors) ? result.errors : [],
      push: result?.push || null
    },
    notification_sent_at: succeeded
      ? admin.firestore.FieldValue.serverTimestamp()
      : null,
    notification_failed_at: succeeded
      ? null
      : admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp()
  };
};

const _nextInvoiceNumber = async (tx, year) => {
  const counterRef = admin
    .firestore()
    .collection('invoice_counters')
    .doc(String(year));
  const counterSnap = await tx.get(counterRef);
  const currentNext = counterSnap.exists
    ? _toNumber(counterSnap.data().next)
    : 1;
  const next = currentNext + 1;
  tx.set(
    counterRef,
    {
      next,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );
  const padded = String(currentNext).padStart(3, '0');
  return `INV-${year}-${padded}`;
};

const createInvoice = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const uid = request.auth.uid;
  const isAdmin = await _isAdminUid(uid);
  if (!isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Admin access required'
    );
  }

  const data = request.data || {};
  const parentId = (data.parentId || data.parent_id || '').toString().trim();
  const studentId = (data.studentId || data.student_id || '').toString().trim();
  const currency = (data.currency || 'USD').toString().trim();
  const shiftIds = Array.isArray(data.shiftIds || data.shift_ids)
    ? data.shiftIds || data.shift_ids
    : [];
  const billingMonths = _normalizeBillingMonths(
    data.billingMonths || data.billing_months
  );
  const baseItems = _normalizeInvoiceItems(data.baseItems || data.base_items);
  const recurringConfig =
    data.recurring && typeof data.recurring === 'object'
      ? data.recurring
      : {};
  const shouldCreateRecurringPlan =
    recurringConfig.enabled === true ||
    data.createRecurringPlan === true ||
    data.create_recurring_plan === true;

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

  if (shouldCreateRecurringPlan && shiftIds.length > 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Recurring billing requires explicit invoice items'
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
        shifts.push({ id: doc.id, ...doc.data() });
      }
    }

    invoicePayload = generateInvoiceFromShifts({
      shifts,
      parentId,
      studentId,
      period: data.period,
      currency
    });
  } else if (Array.isArray(data.items) && data.items.length > 0) {
    const items = _normalizeInvoiceItems(data.items);
    const totalAmount = Number(
      items.reduce((sum, i) => sum + _toNumber(i.total), 0).toFixed(2)
    );
    const periodFromRequest = (data.period || data.period_label || '')
      .toString()
      .trim();
    const periodStart =
      _normalizePeriod(data.periodStart || data.period_start) ||
      _normalizePeriod(periodFromRequest);
    const periodEnd =
      _normalizePeriod(data.periodEnd || data.period_end) ||
      (periodStart
        ? _addMonthsToPeriod(periodStart, billingMonths - 1)
        : null);

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
      base_items: baseItems,
      shift_ids: [],
      period: periodFromRequest || null,
      period_start: periodStart,
      period_end: periodEnd,
      billing_months: billingMonths
    };
  } else {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Provide shiftIds or items to create an invoice'
    );
  }

  const db = admin.firestore();
  const invoiceRef = db.collection('invoices').doc();
  const recurringPlanRef = shouldCreateRecurringPlan
    ? db.collection('recurring_billing_plans').doc()
    : null;

  const result = await db.runTransaction(async (tx) => {
    const now = new Date();
    const invoiceNumber = await _nextInvoiceNumber(tx, now.getUTCFullYear());
    const dueDate =
      invoicePayload.due_date ||
      admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000)
      );
    const dueDateValue = _toDate(dueDate) || now;
    const accessCutoffDate =
      invoicePayload.access_cutoff_date ||
      admin.firestore.Timestamp.fromDate(
        new Date(dueDateValue.getTime() + 24 * 60 * 60 * 1000)
      );
    const accessCutoffValue = _toDate(accessCutoffDate);
    const planBaseItems =
      invoicePayload.base_items && invoicePayload.base_items.length > 0
        ? invoicePayload.base_items
        : invoicePayload.items || [];
    const nextPeriod = invoicePayload.period_start
      ? _addMonthsToPeriod(
          invoicePayload.period_start,
          invoicePayload.billing_months || 1
        )
      : null;

    const invoiceData = {
      invoice_number: invoiceNumber,
      parent_id: invoicePayload.parent_id,
      student_id: invoicePayload.student_id,
      status: invoicePayload.status,
      total_amount: invoicePayload.total_amount,
      paid_amount: invoicePayload.paid_amount,
      currency: invoicePayload.currency,
      issued_date:
        invoicePayload.issued_date || admin.firestore.Timestamp.fromDate(now),
      due_date: dueDate,
      access_cutoff_date: accessCutoffDate,
      items: invoicePayload.items || [],
      shift_ids: invoicePayload.shift_ids || [],
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      created_by: uid,
      period: invoicePayload.period || null,
      period_start: invoicePayload.period_start || null,
      period_end: invoicePayload.period_end || null,
      billing_months: invoicePayload.billing_months || 1,
      notification_status: 'pending',
      recurring_plan_id: recurringPlanRef ? recurringPlanRef.id : null
    };

    tx.set(invoiceRef, invoiceData);

    if (recurringPlanRef) {
      tx.set(recurringPlanRef, {
        parent_id: invoicePayload.parent_id,
        student_id: invoicePayload.student_id,
        status: 'active',
        currency: invoicePayload.currency,
        interval: recurringConfig.interval || 'monthly',
        billing_months: invoicePayload.billing_months || 1,
        base_items: planBaseItems,
        total_amount: invoicePayload.total_amount,
        period_start: invoicePayload.period_start || null,
        period_end: invoicePayload.period_end || null,
        next_period: nextPeriod,
        due_day: dueDateValue.getUTCDate(),
        access_cutoff_days_after_due: accessCutoffValue
          ? Math.max(
              0,
              Math.round(
                (accessCutoffValue.getTime() - dueDateValue.getTime()) /
                  (24 * 60 * 60 * 1000)
              )
            )
          : 1,
        last_invoice_id: invoiceRef.id,
        last_invoice_number: invoiceNumber,
        last_generated_at: admin.firestore.FieldValue.serverTimestamp(),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: uid,
        last_error: null
      });
    }

    return {
      invoiceId: invoiceRef.id,
      invoiceNumber,
      recurringPlanId: recurringPlanRef ? recurringPlanRef.id : null
    };
  });

  return { success: true, ...result };
};

const onInvoiceCreated = onDocumentCreated(
  'invoices/{invoiceId}',
  async (event) => {
    const invoice = event.data?.data();
    if (!invoice) return;

    const result = await _notifyInvoiceRecipient(
      admin.firestore(),
      event.params.invoiceId,
      invoice
    );
    await event.data.ref.set(_invoiceNotificationUpdate(result), {
      merge: true
    });
  }
);

const getParentInvoices = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const data = request.data || {};
  const parentId = (data.parentId || data.parent_id || request.auth.uid || '')
    .toString()
    .trim();
  const status = (data.status || '').toString().trim();
  const limit = Math.min(100, Math.max(1, _toNumber(data.limit) || 50));

  if (!parentId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing parentId'
    );
  }

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!isAdmin && request.auth.uid !== parentId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Cannot read invoices for another user'
    );
  }

  const invoicesCollection = admin.firestore().collection('invoices');
  let query = invoicesCollection.where('parent_id', '==', parentId);
  if (status) {
    query = query.where('status', '==', status);
  }

  const snap = await query.orderBy('due_date', 'desc').limit(limit).get();
  const invoiceById = new Map(
    snap.docs.map((d) => [d.id, { id: d.id, ...d.data() }])
  );

  if (!isAdmin && request.auth.uid === parentId) {
    const studentSnap = await invoicesCollection
      .where('student_id', '==', parentId)
      .limit(limit)
      .get();
    studentSnap.docs.forEach((d) => {
      const invoice = { id: d.id, ...d.data() };
      if (status && invoice.status !== status) return;
      invoiceById.set(d.id, invoice);
    });
  }

  const invoices = Array.from(invoiceById.values())
    .sort((a, b) => {
      const aDue = _toDate(a.due_date || a.dueDate)?.getTime() || 0;
      const bDue = _toDate(b.due_date || b.dueDate)?.getTime() || 0;
      return bDue - aDue;
    })
    .slice(0, limit);
  return { success: true, invoices };
};

/**
 * Shared Firestore transaction: update payment + invoice when a provider reports a final status.
 * @param {FirebaseFirestore.Transaction} tx
 * @param {FirebaseFirestore.Firestore} db
 * @param {FirebaseFirestore.DocumentReference} paymentRef
 * @param {{ status: string, extraPaymentFields?: Record<string, unknown> }} params
 */
const applyPaymentStatusInTransaction = async (
  tx,
  db,
  paymentRef,
  { status, extraPaymentFields = {} }
) => {
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
    return { alreadyProcessed: true };
  }

  if (normalized === 'completed') {
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
        ...extraPaymentFields,
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    tx.set(
      invoiceRef,
      {
        paid_amount: newPaid,
        status: invoiceStatus,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    return {
      updated: true,
      invoiceStatus,
      newPaid,
      paymentCompleted: true,
      paymentId: paymentRef.id,
      paymentInfo: {
        invoiceId,
        invoiceNumber: (
          invoice.invoice_number ||
          invoice.invoiceNumber ||
          invoiceId
        ).toString(),
        parentId: (
          payment.parent_id ||
          invoice.parent_id ||
          invoice.parentId ||
          ''
        ).toString(),
        studentId: (invoice.student_id || invoice.studentId || '').toString(),
        amount,
        currency: (invoice.currency || 'USD').toString(),
        paymentMethod: (
          payment.payment_method ||
          payment.paymentMethod ||
          ''
        ).toString()
      }
    };
  }

  if (normalized === 'failed') {
    tx.set(
      paymentRef,
      {
        status: 'failed',
        ...extraPaymentFields,
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
    return { updated: true };
  }

  tx.set(
    paymentRef,
    {
      status: normalized,
      ...extraPaymentFields,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

  return { updated: true };
};

const _sendPaymentCompletedEmailIfNeeded = async (db, result) => {
  if (!result?.paymentCompleted || !result.paymentId || !result.paymentInfo) {
    return result;
  }

  try {
    const confirmation = await _notifyPaymentCompleted(
      db,
      result.paymentId,
      result.paymentInfo
    );
    return { ...result, paymentConfirmation: confirmation };
  } catch (error) {
    console.error(
      `[payments] Failed to send payment confirmation for ${result.paymentId}:`,
      error
    );
    return {
      ...result,
      paymentConfirmation: {
        success: false,
        reason: error.message || String(error)
      }
    };
  }
};

const recordManualPayment = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Admin access required'
    );
  }

  const data = request.data || {};
  const invoiceId = (data.invoiceId || data.invoice_id || '').toString().trim();
  const amount = _toNumber(data.amount);
  const paymentMethod = _normalizeManualPaymentMethod(
    data.paymentMethod || data.payment_method
  );
  const reference = (data.reference || data.reference_number || '')
    .toString()
    .trim();
  const note = (data.note || data.notes || '').toString().trim();
  const receivedDate =
    _toDate(data.receivedAt || data.received_at) || new Date();

  if (!invoiceId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing invoiceId'
    );
  }
  if (!paymentMethod) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing payment method'
    );
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Payment amount must be greater than zero'
    );
  }

  const db = admin.firestore();
  const invoiceRef = db.collection('invoices').doc(invoiceId);
  const paymentRef = db.collection('payments').doc();

  const result = await db.runTransaction(async (tx) => {
    const invoiceSnap = await tx.get(invoiceRef);
    if (!invoiceSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Invoice not found');
    }

    const invoice = invoiceSnap.data();
    const status = (invoice.status || '').toString().trim().toLowerCase();
    if (status === 'cancelled') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cannot record payment on a cancelled invoice'
      );
    }

    const total = _toNumber(invoice.total_amount, invoice.totalAmount);
    const currentPaid = _toNumber(invoice.paid_amount, invoice.paidAmount);
    const remaining = Number((total - currentPaid).toFixed(2));
    if (remaining <= 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Invoice is already paid'
      );
    }
    if (amount > remaining + 0.005) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Payment exceeds remaining balance of ${remaining.toFixed(2)}`
      );
    }

    const newPaid = Number((currentPaid + amount).toFixed(2));
    const dueDate = invoice.due_date?.toDate
      ? invoice.due_date.toDate()
      : _toDate(invoice.due_date);
    const invoiceStatus =
      newPaid >= total
        ? 'paid'
        : dueDate && dueDate.getTime() < Date.now()
          ? 'overdue'
          : 'pending';
    const receivedTimestamp = admin.firestore.Timestamp.fromDate(receivedDate);

    tx.set(paymentRef, {
      invoice_id: invoiceId,
      parent_id: (invoice.parent_id || invoice.parentId || '').toString(),
      amount,
      applied_amount: amount,
      status: 'completed',
      payment_method: paymentMethod,
      payment_source: 'manual',
      reference_number: reference || null,
      notes: note || null,
      received_at: receivedTimestamp,
      completed_at: receivedTimestamp,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      created_by: request.auth.uid
    });

    tx.set(
      invoiceRef,
      {
        paid_amount: newPaid,
        status: invoiceStatus,
        last_payment_at: receivedTimestamp,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    return {
      updated: true,
      invoiceStatus,
      newPaid,
      paymentCompleted: true,
      paymentId: paymentRef.id,
      paymentInfo: {
        invoiceId,
        invoiceNumber: (
          invoice.invoice_number ||
          invoice.invoiceNumber ||
          invoiceId
        ).toString(),
        parentId: (invoice.parent_id || invoice.parentId || '').toString(),
        studentId: (invoice.student_id || invoice.studentId || '').toString(),
        amount,
        currency: (invoice.currency || 'USD').toString(),
        paymentMethod
      }
    };
  });

  const resultWithEmail = await _sendPaymentCompletedEmailIfNeeded(db, result);
  return { success: true, ...resultWithEmail };
};

const getPaymentHistory = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const data = request.data || {};
  const parentId = (data.parentId || data.parent_id || request.auth.uid || '')
    .toString()
    .trim();
  const limit = Math.min(100, Math.max(1, _toNumber(data.limit) || 50));

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!isAdmin && request.auth.uid !== parentId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Cannot read payments for another user'
    );
  }

  const snap = await admin
    .firestore()
    .collection('payments')
    .where('parent_id', '==', parentId)
    .orderBy('created_at', 'desc')
    .limit(limit)
    .get();

  const payments = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return { success: true, payments };
};

const createPaymentSession = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const data = request.data || {};
  const invoiceId = (data.invoiceId || data.invoice_id || '').toString().trim();
  if (!invoiceId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing invoiceId'
    );
  }

  const db = admin.firestore();
  const invoiceRef = db.collection('invoices').doc(invoiceId);
  const invoiceSnap = await invoiceRef.get();
  if (!invoiceSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Invoice not found');
  }

  const invoice = invoiceSnap.data();
  const {parentId, studentId} = _invoiceAccessIds(invoice);
  const billingAccountId = parentId || studentId || request.auth.uid;
  const currency = (invoice.currency || 'USD').toString();
  const invoiceNumber = (invoice.invoice_number || '').toString();
  const totalAmount = _toNumber(invoice.total_amount);
  const paidAmount = _toNumber(invoice.paid_amount);
  const remaining = Number((totalAmount - paidAmount).toFixed(2));

  if (remaining <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Invoice is already paid'
    );
  }

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!_canUserPayInvoice({uid: request.auth.uid, isAdmin, invoice})) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Cannot pay another user’s invoice'
    );
  }

  const paymentRef = db.collection('payments').doc();

  if (stripeCheckout.isStripeConfigured()) {
    _assertStripeConfiguration();

    const { success: successUrl, cancel: cancelUrl } =
      stripeCheckout.getCheckoutUrls();
    if (!successUrl || !cancelUrl) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe is configured but STRIPE_CHECKOUT_SUCCESS_URL and STRIPE_CHECKOUT_CANCEL_URL must be set (absolute URLs, e.g. your Flutter web parent invoices page).'
      );
    }

    await paymentRef.set({
      invoice_id: invoiceId,
      parent_id: billingAccountId,
      student_id: studentId || null,
      payer_id: request.auth.uid,
      amount: remaining,
      status: 'pending',
      payment_method: 'stripe',
      created_at: admin.firestore.FieldValue.serverTimestamp()
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
        customerEmail: request.auth.token?.email || undefined
      });

      await paymentRef.set(
        {
          stripe_checkout_session_id: session.id,
          status: 'processing',
          checkout_url: session.url
        },
        { merge: true }
      );

      return {
        success: true,
        paymentId: paymentRef.id,
        checkoutUrl: session.url,
        provider: 'stripe'
      };
    } catch (err) {
      console.error('createPaymentSession (Stripe) error:', err);
      await paymentRef.set(
        {
          status: 'failed',
          error_message: err.message || String(err),
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        },
        { merge: true }
      );
      throw new functions.https.HttpsError(
        'internal',
        err.message || String(err)
      );
    }
  }

  await paymentRef.set({
    invoice_id: invoiceId,
    parent_id: billingAccountId,
    student_id: studentId || null,
    payer_id: request.auth.uid,
    amount: remaining,
    status: 'pending',
    payment_method: 'payoneer',
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });

  const payoneer = createPayoneerClient();

  try {
    const session = await payoneer.createCheckoutSession({
      amount: remaining,
      currency,
      paymentId: paymentRef.id
    });

    await paymentRef.set(
      {
        payoneer_session_id: session.sessionId,
        status: 'processing',
        checkout_url: session.checkoutUrl
      },
      { merge: true }
    );

    return {
      success: true,
      paymentId: paymentRef.id,
      checkoutUrl: session.checkoutUrl,
      provider: 'payoneer',
      mock: payoneer.config.isMock
    };
  } catch (err) {
    await paymentRef.set(
      {
        status: 'failed',
        error_message: err.message || String(err),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    throw new functions.https.HttpsError(
      'internal',
      err.message || String(err)
    );
  }
};

/**
 * Creates a PaymentIntent for in-app (mobile) Payment Sheet.
 * Returns client_secret, ephemeralKey, customer, and publishableKey.
 */
const createPaymentIntent = async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const data = request.data || {};
  const invoiceId = (data.invoiceId || data.invoice_id || '').toString().trim();
  if (!invoiceId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing invoiceId'
    );
  }

  if (!stripeCheckout.isStripeConfigured()) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Stripe is not configured'
    );
  }
  _assertStripeConfiguration();

  const db = admin.firestore();
  const invoiceRef = db.collection('invoices').doc(invoiceId);
  const invoiceSnap = await invoiceRef.get();
  if (!invoiceSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Invoice not found');
  }

  const invoice = invoiceSnap.data();
  const {parentId, studentId} = _invoiceAccessIds(invoice);
  const billingAccountId = parentId || studentId || request.auth.uid;
  const currency = (invoice.currency || 'USD').toString();
  const totalAmount = _toNumber(invoice.total_amount);
  const paidAmount = _toNumber(invoice.paid_amount);
  const remaining = Number((totalAmount - paidAmount).toFixed(2));

  if (remaining <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Invoice is already paid'
    );
  }

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!_canUserPayInvoice({uid: request.auth.uid, isAdmin, invoice})) {
    throw new functions.https.HttpsError(
      'permission-denied',
      "Cannot pay another user's invoice"
    );
  }

  const Stripe = require('stripe');
  const stripe = new Stripe(stripeCheckout.getStripeSecretKey());

  // Get or create Stripe Customer
  const customerOwnerId = request.auth.uid;
  const userDoc = await db.collection('users').doc(customerOwnerId).get();
  const userData = userDoc.exists ? userDoc.data() : {};
  const email = request.auth.token?.email || userData['e-mail'] || undefined;
  const name =
    [userData.first_name, userData.last_name].filter(Boolean).join(' ') ||
    undefined;

  const customerId = await stripeCheckout.getOrCreateCustomer({
    stripe,
    parentId: customerOwnerId,
    email,
    name
  });

  // Create payment record in Firestore
  const paymentRef = db.collection('payments').doc();
  await paymentRef.set({
    invoice_id: invoiceId,
    parent_id: billingAccountId,
    student_id: studentId || null,
    payer_id: request.auth.uid,
    amount: remaining,
    status: 'pending',
    payment_method: 'stripe',
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });

  try {
    const { paymentIntent, ephemeralKey } =
      await stripeCheckout.createPaymentIntentForSheet({
        stripe,
        amountMajor: remaining,
        currency,
        customerId,
        paymentId: paymentRef.id,
        invoiceId
      });

    await paymentRef.set(
      {
        stripe_payment_intent_id: paymentIntent.id,
        status: 'processing',
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    return {
      success: true,
      paymentId: paymentRef.id,
      paymentIntent: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customer: customerId,
      publishableKey: stripeCheckout.getStripePublishableKey()
    };
  } catch (err) {
    console.error('createPaymentIntent error:', err);
    await paymentRef.set(
      {
        status: 'failed',
        error_message: err.message || String(err),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
    throw new functions.https.HttpsError(
      'internal',
      err.message || String(err)
    );
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
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  const payoneer = createPayoneerClient();
  const verification = payoneer.verifyWebhook(req);
  if (!verification.ok) {
    res
      .status(401)
      .json({ error: 'Unauthorized', reason: verification.reason });
    return;
  }

  const body = req.body || {};
  const paymentId = (body.paymentId || body.payment_id || '').toString().trim();
  const status = (body.status || '').toString().trim().toLowerCase();
  const transactionId = (body.transactionId || body.transaction_id || '')
    .toString()
    .trim();

  if (!paymentId || !status) {
    res.status(400).json({ error: 'Missing paymentId or status' });
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
        payoneer_transaction_id:
          transactionId || payment.payoneer_transaction_id || null
      };
      return applyPaymentStatusInTransaction(tx, db, paymentRef, {
        status,
        extraPaymentFields: extra
      });
    });

    const resultWithEmail = await _sendPaymentCompletedEmailIfNeeded(
      db,
      result
    );
    res.status(200).json({ success: true, ...resultWithEmail });
  } catch (err) {
    console.error('handlePayoneerWebhook error:', err);
    res.status(500).json({ error: err.message || String(err) });
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
    console.error(
      'Stripe webhook: STRIPE_WEBHOOK_SECRET or STRIPE_SECRET_KEY not set'
    );
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
      const paymentId = (
        (session.metadata && session.metadata.payment_id) ||
        ''
      )
        .toString()
        .trim();
      if (paymentId) {
        const paymentRef = db.collection('payments').doc(paymentId);
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(paymentRef);
          if (!snap.exists) return;
          const st = (snap.data().status || '').toString();
          if (st === 'completed') return;
          await applyPaymentStatusInTransaction(tx, db, paymentRef, {
            status: 'failed',
            extraPaymentFields: { stripe_checkout_session_id: session.id }
          });
        });
      }
      res.json({ received: true });
      return;
    }

    if (
      event.type === 'checkout.session.async_payment_succeeded' ||
      (event.type === 'checkout.session.completed' &&
        event.data.object.payment_status === 'paid')
    ) {
      const session = event.data.object;
      const paymentId = (
        (session.metadata && session.metadata.payment_id) ||
        ''
      )
        .toString()
        .trim();
      if (!paymentId) {
        console.warn(
          'Stripe webhook: missing payment_id metadata on session',
          session.id
        );
        res.json({ received: true, ignored: 'no payment_id' });
        return;
      }
      const paymentRef = db.collection('payments').doc(paymentId);
      const intentId = paymentIntentIdFromSession(session);
      const result = await db.runTransaction(async (tx) => {
        return applyPaymentStatusInTransaction(tx, db, paymentRef, {
          status: 'completed',
          extraPaymentFields: {
            stripe_checkout_session_id: session.id,
            ...(intentId ? { stripe_payment_intent_id: intentId } : {})
          }
        });
      });
      const resultWithEmail = await _sendPaymentCompletedEmailIfNeeded(
        db,
        result
      );
      res.json({ received: true, ...resultWithEmail });
      return;
    }

    // Handle PaymentIntent succeeded (from mobile Payment Sheet)
    if (event.type === 'payment_intent.succeeded') {
      const intent = event.data.object;
      const paymentId = ((intent.metadata && intent.metadata.payment_id) || '')
        .toString()
        .trim();
      if (!paymentId) {
        console.warn(
          'Stripe webhook: missing payment_id metadata on payment_intent',
          intent.id
        );
        res.json({ received: true, ignored: 'no payment_id' });
        return;
      }
      const paymentRef = db.collection('payments').doc(paymentId);
      const result = await db.runTransaction(async (tx) => {
        return applyPaymentStatusInTransaction(tx, db, paymentRef, {
          status: 'completed',
          extraPaymentFields: {
            stripe_payment_intent_id: intent.id
          }
        });
      });
      const resultWithEmail = await _sendPaymentCompletedEmailIfNeeded(
        db,
        result
      );
      res.json({ received: true, ...resultWithEmail });
      return;
    }

    // Handle PaymentIntent failed
    if (event.type === 'payment_intent.payment_failed') {
      const intent = event.data.object;
      const paymentId = ((intent.metadata && intent.metadata.payment_id) || '')
        .toString()
        .trim();
      if (paymentId) {
        const paymentRef = db.collection('payments').doc(paymentId);
        await db.runTransaction(async (tx) => {
          return applyPaymentStatusInTransaction(tx, db, paymentRef, {
            status: 'failed',
            extraPaymentFields: { stripe_payment_intent_id: intent.id }
          });
        });
      }
      res.json({ received: true });
      return;
    }

    res.json({ received: true, ignored: event.type });
  } catch (err) {
    console.error('handleStripeWebhook error:', err);
    res.status(500).send(err.message || String(err));
  }
};

const _recurringInvoiceDocId = (planId, periodStart) =>
  `recurring_${planId}_${periodStart}`.replace(/[^a-zA-Z0-9_-]/g, '_');

const _createRecurringInvoiceForPeriod = async ({
  db,
  planId,
  periodStart,
  now = new Date()
}) => {
  const planRef = db.collection('recurring_billing_plans').doc(planId);

  try {
    return await db.runTransaction(async (tx) => {
      const planSnap = await tx.get(planRef);
      if (!planSnap.exists) {
        return { success: false, planId, periodStart, reason: 'plan_not_found' };
      }

      const plan = planSnap.data() || {};
      if ((plan.status || '').toString() !== 'active') {
        return { success: true, created: false, planId, periodStart, reason: 'inactive' };
      }

      const expectedPeriod = _normalizePeriod(plan.next_period);
      if (!expectedPeriod || expectedPeriod !== periodStart) {
        return {
          success: true,
          created: false,
          planId,
          periodStart,
          nextPeriod: expectedPeriod,
          reason: 'not_current_period'
        };
      }

      const billingMonths = _normalizeBillingMonths(plan.billing_months);
      const periodEnd = _addMonthsToPeriod(periodStart, billingMonths - 1);
      const nextPeriod = _addMonthsToPeriod(periodStart, billingMonths);
      const invoiceRef = db
        .collection('invoices')
        .doc(_recurringInvoiceDocId(planId, periodStart));
      const existingInvoice = await tx.get(invoiceRef);

      if (existingInvoice.exists) {
        tx.set(
          planRef,
          {
            next_period: nextPeriod,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          },
          { merge: true }
        );
        return {
          success: true,
          created: false,
          skipped: true,
          planId,
          invoiceId: invoiceRef.id,
          periodStart,
          nextPeriod,
          reason: 'invoice_exists'
        };
      }

      const invoiceNumber = await _nextInvoiceNumber(tx, now.getUTCFullYear());
      const dueDateValue = _dateForPeriodDay(periodStart, plan.due_day || 1);
      const cutoffDays = Math.max(
        0,
        Math.round(_toNumber(plan.access_cutoff_days_after_due) || 1)
      );
      const accessCutoffValue = new Date(
        dueDateValue.getTime() + cutoffDays * 24 * 60 * 60 * 1000
      );
      const sourceItems =
        Array.isArray(plan.base_items) && plan.base_items.length > 0
          ? plan.base_items
          : plan.items || [];
      const items = _itemsForBillingPeriod({
        items: sourceItems,
        billingMonths,
        periodLabel: _periodRangeLabel(periodStart, periodEnd),
        alreadyExpanded: !(Array.isArray(plan.base_items) && plan.base_items.length > 0)
      });
      const totalAmount = Number(
        items.reduce((sum, item) => sum + _toNumber(item.total), 0).toFixed(2)
      );
      const period =
        billingMonths === 1 ? periodStart : `${periodStart}..${periodEnd}`;

      tx.set(invoiceRef, {
        invoice_number: invoiceNumber,
        parent_id: plan.parent_id || null,
        student_id: plan.student_id || null,
        status: 'pending',
        total_amount: totalAmount,
        paid_amount: 0,
        currency: plan.currency || 'USD',
        issued_date: admin.firestore.FieldValue.serverTimestamp(),
        due_date: admin.firestore.Timestamp.fromDate(dueDateValue),
        access_cutoff_date: admin.firestore.Timestamp.fromDate(accessCutoffValue),
        items,
        shift_ids: [],
        period,
        period_start: periodStart,
        period_end: periodEnd,
        billing_months: billingMonths,
        recurring_plan_id: planId,
        recurring_source: 'scheduled',
        notification_status: 'pending',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: plan.created_by || 'system'
      });

      tx.set(
        planRef,
        {
          next_period: nextPeriod,
          last_invoice_id: invoiceRef.id,
          last_invoice_number: invoiceNumber,
          last_generated_at: admin.firestore.FieldValue.serverTimestamp(),
          last_error: null,
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        },
        { merge: true }
      );

      return {
        success: true,
        created: true,
        planId,
        invoiceId: invoiceRef.id,
        invoiceNumber,
        periodStart,
        periodEnd,
        nextPeriod
      };
    });
  } catch (error) {
    const message = error.message || String(error);
    console.error(
      `[payments] Failed to generate recurring invoice for ${planId}/${periodStart}:`,
      error
    );
    await planRef.set(
      {
        last_error: message,
        last_failed_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
    return { success: false, created: false, planId, periodStart, error: message };
  }
};

const _runRecurringInvoiceGeneration = async ({
  db = admin.firestore(),
  now = new Date(),
  limit = 200
} = {}) => {
  const targetPeriod = _formatPeriodDate(now);
  const snap = await db
    .collection('recurring_billing_plans')
    .where('status', '==', 'active')
    .limit(limit)
    .get();
  const results = [];

  for (const planDoc of snap.docs) {
    let nextPeriod = _normalizePeriod(planDoc.data()?.next_period);
    if (!nextPeriod) {
      results.push({
        success: false,
        created: false,
        planId: planDoc.id,
        reason: 'missing_next_period'
      });
      continue;
    }

    let guard = 0;
    while (_comparePeriods(nextPeriod, targetPeriod) <= 0 && guard < 24) {
      const result = await _createRecurringInvoiceForPeriod({
        db,
        planId: planDoc.id,
        periodStart: nextPeriod,
        now
      });
      results.push(result);
      if (!result.success || !result.nextPeriod) break;
      nextPeriod = result.nextPeriod;
      guard += 1;
    }
  }

  return {
    success: true,
    targetPeriod,
    processedPlans: snap.docs.length,
    invoicesCreated: results.filter((result) => result.created === true).length,
    results
  };
};

const generateInvoicesForPeriod = onSchedule(
  // Cloud Scheduler accepts cron syntax; this runs at 00:00 UTC on day 1 of every month.
  { schedule: '0 0 1 * *', timeZone: 'Etc/UTC' },
  async () => {
    if (process.env.ENABLE_INVOICE_GENERATION !== 'true') {
      console.log(
        'Invoice generation is disabled. Set ENABLE_INVOICE_GENERATION=true to enable.'
      );
      return;
    }

    const result = await _runRecurringInvoiceGeneration();
    console.log('Recurring invoice generation complete:', result);
  }
);

module.exports = {
  createInvoice,
  onInvoiceCreated,
  getParentInvoices,
  createPaymentSession,
  createPaymentIntent,
  recordManualPayment,
  handlePayoneerWebhook,
  handleStripeWebhook,
  getPaymentHistory,
  generateInvoicesForPeriod,
  _notifyInvoiceRecipient,
  _notifyPaymentCompleted,
  _invoiceNotificationUpdate,
  _runRecurringInvoiceGeneration,
  _canUserPayInvoice
};
