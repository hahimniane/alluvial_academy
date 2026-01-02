const {getPayoneerConfig} = require('./config');

const createPayoneerClient = () => {
  const config = getPayoneerConfig();

  const createCheckoutSession = async ({amount, currency, paymentId}) => {
    if (config.isMock) {
      const url = `https://example.com/payoneer-mock-checkout?paymentId=${encodeURIComponent(
        paymentId
      )}&amount=${encodeURIComponent(amount)}&currency=${encodeURIComponent(currency)}`;
      return {
        checkoutUrl: url,
        sessionId: `mock_${paymentId}`,
      };
    }

    // TODO: Implement real Payoneer checkout creation when API credentials/spec are available.
    throw new Error(
      'Payoneer is configured but createCheckoutSession is not implemented yet. Set PAYONEER_* env vars only when ready.'
    );
  };

  const verifyWebhook = (req) => {
    const secret = process.env.PAYONEER_WEBHOOK_SECRET;
    if (!secret) {
      return {ok: false, reason: 'PAYONEER_WEBHOOK_SECRET not set'};
    }
    const header = (req.get('x-webhook-secret') || '').toString();
    if (!header || header !== secret) {
      return {ok: false, reason: 'Invalid webhook secret'};
    }
    return {ok: true};
  };

  return {
    config,
    createCheckoutSession,
    verifyWebhook,
  };
};

module.exports = {
  createPayoneerClient,
};

