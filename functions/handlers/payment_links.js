'use strict';

/**
 * Public payment-link endpoint.
 *
 * GET  /pay/:token           landing page showing the live balance
 * POST /pay/:token/checkout  mints a fresh Stripe session and redirects
 * GET  /pay/:token/done      Stripe's return URL
 *
 * The session is minted on POST, never on GET, so email security scanners
 * and link previewers that follow the URL don't create Stripe sessions.
 *
 * Settlement is not handled here: the Checkout Session carries payment_id in
 * its metadata, so handleStripeWebhook credits the invoice exactly as it does
 * for an in-app payment.
 */

const admin = require('firebase-admin');
const {HttpsError} = require('firebase-functions/v2/https');

const stripeCheckout = require('../services/stripe/checkout');
const payLinks = require('../services/payment_links');

const SUPPORT_EMAIL = 'support@alluwaleducationhub.org';

const _escapeHtml = (value) =>
  String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const _formatMoney = (amount, currency = 'USD') => {
  const value = Number(amount);
  const safe = Number.isFinite(value) ? value : 0;
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: (currency || 'USD').toUpperCase(),
    }).format(safe);
  } catch (_) {
    return `${(currency || 'USD').toUpperCase()} ${safe.toFixed(2)}`;
  }
};

const _formatDate = (value) => {
  const date = value?.toDate ? value.toDate() : value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return '';
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
};

const _isAdminRole = (data) => {
  if (!data) return false;
  const role = (data.role || '').toString().trim().toLowerCase();
  const userType = (data.user_type || data.userType || '')
    .toString()
    .trim()
    .toLowerCase();
  return (
    role === 'admin' ||
    role === 'super_admin' ||
    userType === 'admin' ||
    userType === 'super_admin' ||
    data.is_admin === true ||
    data.isAdmin === true ||
    data.is_super_admin === true ||
    data.isSuperAdmin === true ||
    data.is_admin_teacher === true
  );
};

const _isAdminUid = async (uid) => {
  if (!uid) return false;
  const doc = await admin.firestore().collection('users').doc(uid).get();
  return doc.exists && _isAdminRole(doc.data());
};

/** First name only — a payment link is a semi-public URL. */
const _studentFirstName = async (db, studentId) => {
  const id = (studentId || '').toString().trim();
  if (!id) return '';
  try {
    const snap = await db.collection('users').doc(id).get();
    if (!snap.exists) return '';
    const data = snap.data() || {};
    const first = (data.first_name || data.firstName || '').toString().trim();
    if (first) return first;
    const full = (data.name || data.display_name || '').toString().trim();
    return full ? full.split(/\s+/)[0] : '';
  } catch (_) {
    return '';
  }
};

// ── Page shell ───────────────────────────────────────────────────────────────

const _page = ({title, body, statusCode = 200}) => ({
  statusCode,
  html: `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="robots" content="noindex, nofollow" />
<title>${_escapeHtml(title)} — Alluwal Education Hub</title>
<style>
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 24px 16px 48px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    background: #f1f5f9;
    color: #0f172a;
    -webkit-font-smoothing: antialiased;
  }
  .card {
    max-width: 460px;
    margin: 0 auto;
    background: #ffffff;
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(15, 23, 42, .08), 0 12px 32px rgba(15, 23, 42, .08);
  }
  .head {
    background: #0386FF;
    color: #fff;
    padding: 22px 24px;
    text-align: center;
  }
  .head h1 { margin: 0; font-size: 19px; font-weight: 700; letter-spacing: -.01em; }
  .head p { margin: 4px 0 0; font-size: 13px; opacity: .85; }
  .body { padding: 24px; }
  .amount {
    text-align: center;
    font-size: 40px;
    font-weight: 700;
    letter-spacing: -.03em;
    margin: 4px 0 2px;
  }
  .amount-label {
    text-align: center;
    font-size: 13px;
    color: #64748b;
    margin: 0 0 22px;
  }
  dl { margin: 0 0 22px; font-size: 14px; }
  .row {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    padding: 10px 0;
    border-bottom: 1px solid #e2e8f0;
  }
  .row:last-child { border-bottom: 0; }
  dt { color: #64748b; margin: 0; }
  dd { margin: 0; font-weight: 600; text-align: right; }
  button {
    width: 100%;
    padding: 15px 20px;
    font-size: 16px;
    font-weight: 700;
    font-family: inherit;
    color: #fff;
    background: #0386FF;
    border: 0;
    border-radius: 10px;
    cursor: pointer;
  }
  button:hover { background: #0272db; }
  button[disabled] { opacity: .6; cursor: progress; }
  .note {
    margin: 14px 0 0;
    font-size: 12px;
    line-height: 1.6;
    color: #64748b;
    text-align: center;
  }
  .msg { font-size: 15px; line-height: 1.65; color: #334155; margin: 0 0 14px; }
  .msg:last-child { margin-bottom: 0; }
  .icon { font-size: 34px; text-align: center; margin: 0 0 12px; }
  a { color: #0386FF; }
  .foot {
    max-width: 460px;
    margin: 18px auto 0;
    text-align: center;
    font-size: 12px;
    color: #64748b;
  }
  @media (prefers-color-scheme: dark) {
    body { background: #0b1220; color: #e2e8f0; }
    .card { background: #111a2b; box-shadow: 0 1px 3px rgba(0,0,0,.5), 0 12px 32px rgba(0,0,0,.4); }
    .row { border-bottom-color: #1e293b; }
    dt, .amount-label, .note, .foot { color: #94a3b8; }
    .msg { color: #cbd5e1; }
  }
</style>
</head>
<body>
  <div class="card">
    <div class="head">
      <h1>Alluwal Education Hub</h1>
      <p>Invoice payment</p>
    </div>
    <div class="body">
${body}
    </div>
  </div>
  <p class="foot">Questions? <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a></p>
</body>
</html>`,
});

const _messagePage = ({title, icon, lines, statusCode = 200}) =>
  _page({
    title,
    statusCode,
    body: `      <p class="icon">${icon}</p>
${lines.map((line) => `      <p class="msg">${line}</p>`).join('\n')}`,
  });

const _notFoundPage = () =>
  _messagePage({
    title: 'Link not found',
    icon: '🔗',
    statusCode: 404,
    lines: [
      'This payment link is not valid.',
      `It may have been replaced by a newer one. Please contact <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> and we will send you a new link.`,
    ],
  });

const _payPage = ({resolved, studentName, actionUrl}) => {
  const {invoice, invoiceNumber, remaining, currency, paid} = resolved;
  const amount = _formatMoney(remaining, currency);
  const dueDate = _formatDate(invoice.due_date || invoice.dueDate);
  const partiallyPaid = Number(paid) > 0;

  const rows = [
    ['Invoice', _escapeHtml(invoiceNumber)],
    studentName ? ['Student', _escapeHtml(studentName)] : null,
    dueDate ? ['Due date', _escapeHtml(dueDate)] : null,
    partiallyPaid
      ? ['Already paid', _escapeHtml(_formatMoney(paid, currency))]
      : null,
  ].filter(Boolean);

  return _page({
    title: `Pay ${invoiceNumber}`,
    body: `      <p class="amount">${_escapeHtml(amount)}</p>
      <p class="amount-label">Balance due${partiallyPaid ? ' (remaining)' : ''}</p>
      <dl>
${rows
    .map(
      ([label, value]) =>
        `        <div class="row"><dt>${label}</dt><dd>${value}</dd></div>`
    )
    .join('\n')}
      </dl>
      <form method="POST" action="${_escapeHtml(actionUrl)}" onsubmit="this.querySelector('button').disabled=true;this.querySelector('button').textContent='Opening secure checkout…';">
        <button type="submit">Pay ${_escapeHtml(amount)}</button>
      </form>
      <p class="note">You'll be taken to Stripe to pay securely by card. The full balance is charged in one payment — partial amounts can't be paid here.</p>`,
  });
};

// ── Request handling ─────────────────────────────────────────────────────────

/**
 * Hosting rewrites preserve the full path (/pay/:token/...), but a direct call
 * to the function URL does not include the /pay prefix. Accept both.
 */
const _parsePath = (rawPath) => {
  const segments = (rawPath || '')
    .split('?')[0]
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean);

  if (segments[0] === 'pay') segments.shift();

  return {token: segments[0] ? decodeURIComponent(segments[0]) : '', action: segments[1] || ''};
};

const _send = (res, {statusCode, html}) => {
  res
    .status(statusCode)
    .set('Content-Type', 'text/html; charset=utf-8')
    .set('Cache-Control', 'no-store')
    .set('Referrer-Policy', 'no-referrer')
    .set('X-Robots-Tag', 'noindex, nofollow')
    .send(html);
};

const _pageForState = (resolved, {studentName, token}) => {
  switch (resolved.state) {
    case 'payable':
      return _payPage({
        resolved,
        studentName,
        actionUrl: `${payLinks.payLinkBase()}/${encodeURIComponent(token)}/checkout`,
      });

    case 'already_paid':
      return _messagePage({
        title: 'Already paid',
        icon: '✅',
        lines: [
          `<strong>Invoice ${_escapeHtml(resolved.invoiceNumber)} is fully paid.</strong>`,
          'There is nothing left to pay. Thank you.',
        ],
      });

    case 'amount_too_small':
      return _messagePage({
        title: 'Balance too small',
        icon: '💬',
        lines: [
          `The remaining balance on invoice ${_escapeHtml(resolved.invoiceNumber)} is ${_escapeHtml(_formatMoney(resolved.remaining, resolved.currency))}.`,
          `That is below the minimum we can charge online. Please contact <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> to settle it.`,
        ],
      });

    case 'invoice_cancelled':
      return _messagePage({
        title: 'Invoice cancelled',
        icon: '🚫',
        lines: [
          `Invoice ${_escapeHtml(resolved.invoiceNumber)} has been cancelled. No payment is due.`,
        ],
      });

    case 'link_cancelled':
      return _messagePage({
        title: 'Link no longer active',
        icon: '🔗',
        lines: [
          'This payment link is no longer active.',
          `Please contact <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> for a current link.`,
        ],
      });

    default:
      return _notFoundPage();
  }
};

const _createLinkCheckoutSession = async (db, resolved) => {
  if (!stripeCheckout.isStripeConfigured()) {
    throw new Error('Stripe is not configured');
  }
  stripeCheckout.assertStripeConfiguration();

  const {invoice, invoiceId, invoiceRef, invoiceNumber, remaining, currency, token} =
    resolved;

  const reusable = payLinks.reusablePendingSession(invoice, remaining);
  if (reusable) {
    const paymentSnap = await db
      .collection('payments')
      .doc(reusable.paymentId)
      .get();
    const status = (paymentSnap.data()?.status || '').toString();
    if (paymentSnap.exists && status === 'processing') {
      return reusable.checkoutUrl;
    }
  }

  const parentId = (invoice.parent_id || invoice.parentId || '').toString().trim();
  const studentId = (invoice.student_id || invoice.studentId || '').toString().trim();
  const paymentRef = db.collection('payments').doc();

  await paymentRef.set({
    invoice_id: invoiceId,
    parent_id: parentId || studentId || null,
    student_id: studentId || null,
    payer_id: null,
    amount: remaining,
    status: 'pending',
    payment_method: 'stripe',
    payment_source: 'payment_link',
    pay_link_token: token,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  const base = payLinks.payLinkBase();
  const encoded = encodeURIComponent(token);

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
      successUrl: `${base}/${encoded}/done`,
      cancelUrl: `${base}/${encoded}`,
    });

    await paymentRef.set(
      {
        stripe_checkout_session_id: session.id,
        status: 'processing',
        checkout_url: session.url,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    await invoiceRef.set(
      {
        pay_link_pending: {
          payment_id: paymentRef.id,
          amount: remaining,
          checkout_url: session.url,
          created_at: admin.firestore.Timestamp.now(),
        },
      },
      {merge: true}
    );

    return session.url;
  } catch (err) {
    await paymentRef.set(
      {
        status: 'failed',
        error_message: err.message || String(err),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    throw err;
  }
};

const handlePaymentLink = async (req, res) => {
  const db = admin.firestore();
  const {token, action} = _parsePath(req.path || req.url || '');

  if (!token) {
    _send(res, _notFoundPage());
    return;
  }

  try {
    const resolved = await payLinks.resolvePayLink(db, token);

    if (resolved.state === 'not_found') {
      _send(res, _notFoundPage());
      return;
    }

    if (action === 'done') {
      // Stripe's return URL. The webhook may not have landed yet, so we report
      // what we can see without asserting a balance that may still be updating.
      _send(
        res,
        _messagePage({
          title: 'Payment received',
          icon: '✅',
          lines: [
            '<strong>Thank you — your payment was submitted.</strong>',
            `A receipt for invoice ${_escapeHtml(resolved.invoiceNumber)} is on its way by email. It can take a moment to show up on the account.`,
          ],
        })
      );
      return;
    }

    if (action === 'checkout') {
      if (req.method !== 'POST') {
        // Never mint a session on GET — bounce back to the page.
        res.redirect(
          303,
          `${payLinks.payLinkBase()}/${encodeURIComponent(token)}`
        );
        return;
      }

      if (resolved.state !== 'payable') {
        const studentName = await _studentFirstName(
          db,
          resolved.invoice?.student_id || resolved.invoice?.studentId
        );
        _send(res, _pageForState(resolved, {studentName, token}));
        return;
      }

      const checkoutUrl = await _createLinkCheckoutSession(db, {
        ...resolved,
        token,
      });
      res.redirect(303, checkoutUrl);
      return;
    }

    const studentName = await _studentFirstName(
      db,
      resolved.invoice?.student_id || resolved.invoice?.studentId
    );
    _send(res, _pageForState(resolved, {studentName, token}));
  } catch (err) {
    console.error('[payment_links] handlePaymentLink error:', err);
    _send(
      res,
      _messagePage({
        title: 'Something went wrong',
        icon: '⚠️',
        statusCode: 500,
        lines: [
          'We could not open the payment page just now.',
          `Please try again in a moment, or contact <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.`,
        ],
      })
    );
  }
};

// ── Admin callables ──────────────────────────────────────────────────────────

/**
 * Returns the invoice's payment link, minting one if it doesn't have a token
 * yet, and reactivating it if it was previously cancelled.
 */
const getInvoicePaymentLink = async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }
  if (!(await _isAdminUid(request.auth.uid))) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }

  const data = request.data || {};
  const invoiceId = (data.invoiceId || data.invoice_id || '').toString().trim();
  if (!invoiceId) {
    throw new HttpsError('invalid-argument', 'Missing invoiceId');
  }

  const db = admin.firestore();
  const invoiceRef = db.collection('invoices').doc(invoiceId);
  const snap = await invoiceRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Invoice not found');
  }

  const invoice = snap.data() || {};
  const token = await payLinks.ensurePayLinkToken(
    db,
    invoiceId,
    invoice,
    request.auth.uid
  );

  const wasCancelled =
    (invoice.pay_link_status || '').toString().trim().toLowerCase() ===
    payLinks.PAY_LINK_CANCELLED;

  if (wasCancelled) {
    await invoiceRef.set(
      {
        pay_link_status: payLinks.PAY_LINK_ACTIVE,
        pay_link_cancelled_at: null,
        pay_link_cancelled_by: null,
        pay_link_reactivated_at: admin.firestore.FieldValue.serverTimestamp(),
        pay_link_reactivated_by: request.auth.uid,
      },
      {merge: true}
    );
  }

  return {
    success: true,
    invoiceId,
    token,
    url: payLinks.buildPayLinkUrl(token),
    status: payLinks.PAY_LINK_ACTIVE,
    reactivated: wasCancelled,
  };
};

/**
 * Kills a link. The invoice is untouched — only the link stops working.
 */
const cancelInvoicePaymentLink = async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }
  if (!(await _isAdminUid(request.auth.uid))) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }

  const data = request.data || {};
  const invoiceId = (data.invoiceId || data.invoice_id || '').toString().trim();
  if (!invoiceId) {
    throw new HttpsError('invalid-argument', 'Missing invoiceId');
  }

  const db = admin.firestore();
  const invoiceRef = db.collection('invoices').doc(invoiceId);
  const snap = await invoiceRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Invoice not found');
  }

  await invoiceRef.set(
    {
      pay_link_status: payLinks.PAY_LINK_CANCELLED,
      pay_link_cancelled_at: admin.firestore.FieldValue.serverTimestamp(),
      pay_link_cancelled_by: request.auth.uid,
      pay_link_pending: admin.firestore.FieldValue.delete(),
    },
    {merge: true}
  );

  return {success: true, invoiceId, status: payLinks.PAY_LINK_CANCELLED};
};

module.exports = {
  handlePaymentLink,
  getInvoicePaymentLink,
  cancelInvoicePaymentLink,
  // exported for tests
  _parsePath,
  _pageForState,
};
