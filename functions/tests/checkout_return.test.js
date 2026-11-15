/**
 * Stripe return addresses for web checkout.
 *
 * Expected behavior:
 * - Callers that do not ask for the parent return page keep the two global
 *   addresses from settings, unchanged.
 * - `returnTo: 'parent'` sends both success and cancel to /parent/pay/return/
 *   on the same site as the configured success address, carrying the invoice
 *   id, the payment id and the result. No address comes from the client.
 * - A malformed configured address falls back to the global addresses.
 */
const {checkoutReturnUrls} = require('../utils/checkout_return');

const base = {
  successUrl: 'https://alluwaleducationhub.org',
  cancelUrl: 'https://alluwaleducationhub.org/cancel',
  invoiceId: 'inv 1',
  paymentId: 'pay1',
};

test('other callers keep the configured addresses', () => {
  expect(checkoutReturnUrls({...base, returnTo: ''})).toEqual({
    success: 'https://alluwaleducationhub.org',
    cancel: 'https://alluwaleducationhub.org/cancel',
  });
  expect(checkoutReturnUrls({...base, returnTo: 'https://evil.test'})).toEqual({
    success: base.successUrl,
    cancel: base.cancelUrl,
  });
});

test('the parent area returns to its own page on the configured site', () => {
  const urls = checkoutReturnUrls({...base, returnTo: 'parent'});
  expect(urls.success).toBe('https://alluwaleducationhub.org/parent/pay/return/?invoiceId=inv+1&paymentId=pay1&result=success');
  expect(urls.cancel).toBe('https://alluwaleducationhub.org/parent/pay/return/?invoiceId=inv+1&paymentId=pay1&result=cancel');
});

test('a malformed configured address falls back to the global addresses', () => {
  expect(checkoutReturnUrls({...base, successUrl: 'not a url', returnTo: 'parent'})).toEqual({
    success: 'not a url',
    cancel: base.cancelUrl,
  });
});
