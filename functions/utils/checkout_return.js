'use strict';

/**
 * Where Stripe Checkout sends the browser back after a web payment.
 *
 * By default every caller gets the two global addresses from settings
 * (STRIPE_CHECKOUT_SUCCESS_URL / STRIPE_CHECKOUT_CANCEL_URL). The parent web
 * area asks for `returnTo: 'parent'` and lands on its own return page instead,
 * on the SAME site as the configured success address — so no address ever
 * comes from the client, and nothing changes for any other caller.
 *
 *   https://<site>/parent/pay/return/?invoiceId=…&paymentId=…&result=success|cancel
 */
const PARENT_RETURN_PATH = '/parent/pay/return/';

const checkoutReturnUrls = ({returnTo, successUrl, cancelUrl, invoiceId, paymentId}) => {
  const fallback = {success: successUrl, cancel: cancelUrl};
  if (returnTo !== 'parent') return fallback;
  let origin;
  try {
    origin = new URL(successUrl).origin;
  } catch (_) {
    return fallback;
  }
  if (!origin || origin === 'null') return fallback;
  const build = (result) => {
    const url = new URL(PARENT_RETURN_PATH, origin);
    url.searchParams.set('invoiceId', String(invoiceId));
    url.searchParams.set('paymentId', String(paymentId));
    url.searchParams.set('result', result);
    return url.toString();
  };
  return {success: build('success'), cancel: build('cancel')};
};

module.exports = {checkoutReturnUrls, PARENT_RETURN_PATH};
