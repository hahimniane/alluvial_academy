'use strict';

const ZERO_DECIMAL_CURRENCIES = new Set([
  'bif',
  'clp',
  'djf',
  'gnf',
  'jpy',
  'kmf',
  'krw',
  'mga',
  'pyg',
  'rwf',
  'ugx',
  'vnd',
  'vuv',
  'xaf',
  'xof',
  'xpf',
]);

const getStripeSecretKey = () => (process.env.STRIPE_SECRET_KEY || '').trim();

const getStripePublishableKey = () => (process.env.STRIPE_PUBLISHABLE_KEY || '').trim();

const isStripeConfigured = () => Boolean(getStripeSecretKey());

const getCheckoutUrls = () => ({
  success: (process.env.STRIPE_CHECKOUT_SUCCESS_URL || '').trim(),
  cancel: (process.env.STRIPE_CHECKOUT_CANCEL_URL || '').trim(),
});

/**
 * @param {number} amountMajor e.g. 10.5 for $10.50
 * @param {string} currency ISO code e.g. USD
 * @returns {number} Stripe unit_amount (smallest currency unit)
 */
const toStripeUnitAmount = (amountMajor, currency) => {
  const c = (currency || 'usd').toLowerCase();
  if (ZERO_DECIMAL_CURRENCIES.has(c)) {
    return Math.round(amountMajor);
  }
  return Math.round(amountMajor * 100);
};

/**
 * @param {object} params
 * @param {import('stripe').default} params.stripe initialized Stripe SDK client
 */
const createCheckoutSession = async ({
  stripe,
  amountMajor,
  currency,
  paymentId,
  invoiceId,
  invoiceNumber,
  successUrl,
  cancelUrl,
  customerEmail,
}) => {
  const cur = (currency || 'usd').toLowerCase();
  const unitAmount = toStripeUnitAmount(amountMajor, cur);
  if (!Number.isFinite(unitAmount) || unitAmount <= 0) {
    throw new Error('Invalid payment amount for Stripe');
  }
  // USD-style minimums: Stripe enforces per-currency; common guard for USD
  if (cur === 'usd' && unitAmount < 50) {
    throw new Error('Amount must be at least $0.50 USD for card payments');
  }

  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    ...(customerEmail ? {customer_email: customerEmail} : {}),
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency: cur,
          unit_amount: unitAmount,
          product_data: {
            name: invoiceNumber ? `Invoice ${invoiceNumber}` : 'Invoice payment',
            description: 'Alluvial Academy — tuition / fees',
            metadata: {
              invoice_id: invoiceId,
              payment_id: paymentId,
            },
          },
        },
      },
    ],
    success_url: successUrl,
    cancel_url: cancelUrl,
    client_reference_id: paymentId,
    metadata: {
      payment_id: paymentId,
      invoice_id: invoiceId,
    },
  });

  return session;
};

/**
 * Create or retrieve a Stripe Customer for the given parent user.
 * Stores the stripe_customer_id on the Firestore user document for reuse.
 */
const getOrCreateCustomer = async ({stripe, parentId, email, name}) => {
  const admin = require('firebase-admin');
  const userRef = admin.firestore().collection('users').doc(parentId);
  const userSnap = await userRef.get();
  const userData = userSnap.exists ? userSnap.data() : {};

  const existingCustomerId = (userData.stripe_customer_id || '').toString().trim();
  if (existingCustomerId) {
    try {
      const customer = await stripe.customers.retrieve(existingCustomerId);
      if (!customer.deleted) return customer.id;
    } catch (_) {
      // Customer was deleted in Stripe — create a new one
    }
  }

  const customer = await stripe.customers.create({
    ...(email ? {email} : {}),
    ...(name ? {name} : {}),
    metadata: {firebase_uid: parentId},
  });

  await userRef.set({stripe_customer_id: customer.id}, {merge: true});
  return customer.id;
};

/**
 * Create a PaymentIntent + ephemeral key for the mobile Payment Sheet.
 */
const createPaymentIntentForSheet = async ({
  stripe,
  amountMajor,
  currency,
  customerId,
  paymentId,
  invoiceId,
}) => {
  const cur = (currency || 'usd').toLowerCase();
  const unitAmount = toStripeUnitAmount(amountMajor, cur);
  if (!Number.isFinite(unitAmount) || unitAmount <= 0) {
    throw new Error('Invalid payment amount for Stripe');
  }
  if (cur === 'usd' && unitAmount < 50) {
    throw new Error('Amount must be at least $0.50 USD for card payments');
  }

  const paymentIntent = await stripe.paymentIntents.create({
    amount: unitAmount,
    currency: cur,
    customer: customerId,
    automatic_payment_methods: {enabled: true},
    metadata: {
      payment_id: paymentId,
      invoice_id: invoiceId,
    },
  });

  const ephemeralKey = await stripe.ephemeralKeys.create(
    {customer: customerId},
    {apiVersion: '2024-06-20'}
  );

  return {paymentIntent, ephemeralKey};
};

module.exports = {
  isStripeConfigured,
  getStripeSecretKey,
  getStripePublishableKey,
  getCheckoutUrls,
  createCheckoutSession,
  getOrCreateCustomer,
  createPaymentIntentForSheet,
  toStripeUnitAmount,
};
