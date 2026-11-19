/**
 * Stripe Checkout must always receive both return addresses.
 *
 * Expected behavior:
 * - createCheckoutSession passes successUrl/cancelUrl through as
 *   success_url/cancel_url.
 * - It refuses to call Stripe when either address is missing, instead of
 *   letting Stripe reject the request.
 * - createPaymentSession maps checkoutReturnUrls' {success, cancel} onto
 *   successUrl/cancelUrl (spreading it in directly sent no success_url, which
 *   failed every in-app card payment).
 */
const fs = require('fs');
const path = require('path');
const {createCheckoutSession} = require('../services/stripe/checkout');
const {checkoutReturnUrls} = require('../utils/checkout_return');

const fakeStripe = () => {
  const calls = [];
  return {
    calls,
    checkout: {sessions: {create: async (p) => { calls.push(p); return {id: 'cs_1', url: 'https://x'}; }}},
  };
};

const args = {amountMajor: 200, currency: 'usd', paymentId: 'pay1', invoiceId: 'inv1', invoiceNumber: 'INV-1'};

test('return addresses reach Stripe for the parent web flow', async () => {
  const stripe = fakeStripe();
  const urls = checkoutReturnUrls({
    returnTo: 'parent', successUrl: 'https://alluwaleducationhub.org', cancelUrl: 'https://alluwaleducationhub.org/c',
    invoiceId: 'inv1', paymentId: 'pay1',
  });
  await createCheckoutSession({...args, stripe, successUrl: urls.success, cancelUrl: urls.cancel});
  expect(stripe.calls[0].success_url).toMatch(/^https:\/\/alluwaleducationhub\.org\/parent\/pay\/return\/\?.*result=success/);
  expect(stripe.calls[0].cancel_url).toMatch(/result=cancel/);
});

test('missing return address is refused before calling Stripe', async () => {
  const stripe = fakeStripe();
  await expect(createCheckoutSession({...args, stripe, successUrl: '', cancelUrl: 'https://a/c'}))
    .rejects.toThrow('Checkout return addresses are missing');
  await expect(createCheckoutSession({...args, stripe, success: 'https://a', cancel: 'https://a/c'}))
    .rejects.toThrow('Checkout return addresses are missing');
  expect(stripe.calls).toHaveLength(0);
});

test('createPaymentSession maps the return addresses explicitly', () => {
  const src = fs.readFileSync(path.join(__dirname, '../handlers/payments.js'), 'utf8');
  expect(src).not.toMatch(/\.\.\.checkoutReturnUrls\(/);
  expect(src).toMatch(/successUrl: returnUrls\.success/);
  expect(src).toMatch(/cancelUrl: returnUrls\.cancel/);
});
