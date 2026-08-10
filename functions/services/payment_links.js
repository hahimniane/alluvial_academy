'use strict';

/**
 * Payment links — pay an invoice from a URL, without signing in.
 *
 * A link is an opaque token stored on the invoice document. The token never
 * carries the amount: the balance is recomputed from the invoice on every
 * visit, so a link cannot go stale and cannot be tampered with.
 *
 * A link stays valid until one of exactly two things happens: the invoice is
 * paid in full, or an admin cancels the link. Nothing expires on a timer.
 * That is why we never hand out a raw Stripe Checkout URL (those die 24h
 * after minting) — we mint a fresh session on each visit instead.
 */

const crypto = require('crypto');
const admin = require('firebase-admin');

const PAY_LINK_ACTIVE = 'active';
const PAY_LINK_CANCELLED = 'cancelled';

/**
 * Stripe's minimum charge for USD. Mirrors the guard in
 * services/stripe/checkout.js so the landing page never offers a button that
 * would throw at session creation.
 */
const MIN_CHARGE_USD = 0.5;

/** How long a minted Checkout Session is reused before we mint a new one. */
const SESSION_REUSE_WINDOW_MS = 23 * 60 * 60 * 1000;

const appUrl = () =>
  (
    process.env.APP_URL ||
    process.env.PUBLIC_APP_URL ||
    'https://alluwaleducationhub.org'
  )
    .trim()
    .replace(/\/+$/, '');

/**
 * Where payment links live. Defaults to `<APP_URL>/pay`, which needs the
 * `/pay/**` hosting rewrite deployed. Set PAY_LINK_BASE_URL to point links
 * straight at the function URL when hosting hasn't been deployed yet, e.g.
 * https://us-central1-<project>.cloudfunctions.net/handlePaymentLink
 */
const payLinkBase = () => {
  const override = (process.env.PAY_LINK_BASE_URL || '').trim();
  if (override) return override.replace(/\/+$/, '');
  return `${appUrl()}/pay`;
};

const generatePayLinkToken = () => crypto.randomBytes(32).toString('base64url');

const buildPayLinkUrl = (token) =>
  token ? `${payLinkBase()}/${encodeURIComponent(token)}` : '';

const _toNumber = (...values) => {
  for (const value of values) {
    const number = Number(value);
    if (Number.isFinite(number)) return number;
  }
  return 0;
};

const _normalize = (value) => (value || '').toString().trim().toLowerCase();

/**
 * Fields to stamp on a newly created invoice so it ships with a live link.
 */
const newPayLinkFields = (actorUid = 'system') => ({
  pay_link_token: generatePayLinkToken(),
  pay_link_status: PAY_LINK_ACTIVE,
  pay_link_created_at: admin.firestore.FieldValue.serverTimestamp(),
  pay_link_created_by: actorUid || 'system',
});

/**
 * Returns the invoice's token, minting and persisting one if it has none.
 * Older invoices predate payment links, so this backfills on first use.
 */
const ensurePayLinkToken = async (db, invoiceId, invoice = {}, actorUid = 'system') => {
  const existing = (invoice.pay_link_token || '').toString().trim();
  if (existing) return existing;

  const fields = newPayLinkFields(actorUid);
  await db.collection('invoices').doc(invoiceId).set(fields, {merge: true});
  return fields.pay_link_token;
};

/**
 * Resolves a token to what the visitor should actually see.
 *
 * States:
 *   not_found          — no such token (also used for anything we won't explain)
 *   link_cancelled     — an admin killed this link
 *   invoice_cancelled  — the invoice itself was cancelled
 *   already_paid       — nothing left to pay; this is how a link retires
 *   amount_too_small   — balance below Stripe's floor, needs a human
 *   payable            — go ahead
 */
const resolvePayLink = async (db, rawToken) => {
  const token = (rawToken || '').toString().trim();
  if (!token) return {state: 'not_found'};

  // Fetch two: a token must identify exactly one invoice. If it somehow
  // matches more, resolving to an arbitrary one could charge a payer for a
  // different invoice's balance, so refuse rather than guess.
  const snap = await db
    .collection('invoices')
    .where('pay_link_token', '==', token)
    .limit(2)
    .get();

  if (snap.empty) return {state: 'not_found'};

  if (snap.docs.length > 1) {
    console.error(
      `[payment_links] Token matched ${snap.docs.length} invoices ` +
        `(${snap.docs.map((d) => d.id).join(', ')}). Refusing to resolve.`
    );
    return {state: 'not_found'};
  }

  const doc = snap.docs[0];
  const invoice = doc.data() || {};

  const base = {
    invoiceId: doc.id,
    invoiceRef: doc.ref,
    invoice,
    token,
    invoiceNumber: (
      invoice.invoice_number ||
      invoice.invoiceNumber ||
      doc.id
    ).toString(),
    currency: (invoice.currency || 'USD').toString(),
  };

  const linkStatus = _normalize(invoice.pay_link_status) || PAY_LINK_ACTIVE;
  if (linkStatus === PAY_LINK_CANCELLED) {
    return {...base, state: 'link_cancelled'};
  }

  if (_normalize(invoice.status) === 'cancelled') {
    return {...base, state: 'invoice_cancelled'};
  }

  const total = _toNumber(invoice.total_amount, invoice.totalAmount);
  const paid = _toNumber(invoice.paid_amount, invoice.paidAmount);
  const remaining = Number((total - paid).toFixed(2));

  const withAmounts = {...base, total, paid, remaining};

  if (remaining <= 0) return {...withAmounts, state: 'already_paid'};

  if (base.currency.toLowerCase() === 'usd' && remaining < MIN_CHARGE_USD) {
    return {...withAmounts, state: 'amount_too_small'};
  }

  return {...withAmounts, state: 'payable'};
};

/**
 * A previously minted session is reusable only if it is for the exact same
 * balance and is still young enough that Stripe has not expired it.
 */
const reusablePendingSession = (invoice = {}, remaining = 0) => {
  const pending = invoice.pay_link_pending;
  if (!pending || typeof pending !== 'object') return null;

  const paymentId = (pending.payment_id || '').toString().trim();
  const checkoutUrl = (pending.checkout_url || '').toString().trim();
  if (!paymentId || !checkoutUrl) return null;

  if (Number(_toNumber(pending.amount).toFixed(2)) !== Number(remaining.toFixed(2))) {
    return null;
  }

  const createdAt = pending.created_at?.toDate
    ? pending.created_at.toDate()
    : null;
  if (!createdAt) return null;
  if (Date.now() - createdAt.getTime() > SESSION_REUSE_WINDOW_MS) return null;

  return {paymentId, checkoutUrl};
};

module.exports = {
  PAY_LINK_ACTIVE,
  PAY_LINK_CANCELLED,
  MIN_CHARGE_USD,
  appUrl,
  payLinkBase,
  generatePayLinkToken,
  buildPayLinkUrl,
  newPayLinkFields,
  ensurePayLinkToken,
  resolvePayLink,
  reusablePendingSession,
};
