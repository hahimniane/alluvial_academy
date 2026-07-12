const stripeCheckout = require('../services/stripe/checkout');

const ORIGINAL_ENV = {...process.env};

const setStripeEnv = ({
  projectId = 'alluwal-dev',
  secretKey = 'sk_test_mock',
  publishableKey = 'pk_test_mock',
} = {}) => {
  process.env = {
    ...ORIGINAL_ENV,
    GCLOUD_PROJECT: projectId,
    GCP_PROJECT: projectId,
    GOOGLE_CLOUD_PROJECT: projectId,
    STRIPE_SECRET_KEY: secretKey,
    STRIPE_PUBLISHABLE_KEY: publishableKey,
  };
};

describe('stripe checkout configuration', () => {
  afterEach(() => {
    process.env = {...ORIGINAL_ENV};
  });

  test('allows test Stripe keys in dev', () => {
    setStripeEnv({projectId: 'alluwal-dev'});

    expect(stripeCheckout.assertStripeConfiguration()).toEqual(
      expect.objectContaining({
        projectId: 'alluwal-dev',
        requiresLive: false,
        secretMode: 'test',
        publishableMode: 'test',
      }),
    );
  });

  test('rejects test Stripe keys in production', () => {
    setStripeEnv({projectId: 'alluwal-academy'});

    expect(() => stripeCheckout.assertStripeConfiguration()).toThrow(
      /must use live Stripe keys/,
    );
  });

  test('allows live Stripe keys in production', () => {
    setStripeEnv({
      projectId: 'alluwal-academy',
      secretKey: 'sk_live_mock',
      publishableKey: 'pk_live_mock',
    });

    expect(stripeCheckout.assertStripeConfiguration()).toEqual(
      expect.objectContaining({
        projectId: 'alluwal-academy',
        requiresLive: true,
        secretMode: 'live',
        publishableMode: 'live',
      }),
    );
  });

  test('rejects mismatched secret and publishable key modes', () => {
    setStripeEnv({
      projectId: 'alluwal-dev',
      secretKey: 'sk_live_mock',
      publishableKey: 'pk_test_mock',
    });

    expect(() => stripeCheckout.assertStripeConfiguration()).toThrow(
      /same mode/,
    );
  });
});
