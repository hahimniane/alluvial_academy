/**
 * A cancelled invoice cannot be paid, and a payment that still arrives for one
 * (a checkout session opened before the cancel) never reopens or settles it.
 *
 * Expected behavior:
 * - createPaymentSession and createPaymentIntent refuse a cancelled invoice
 *   (failed-precondition, 'This invoice was cancelled.') before any payment
 *   document or Stripe session is created.
 * - applyPaymentStatusInTransaction on a cancelled invoice records the payment
 *   as completed with nothing applied, flags needs_refund on the payment and
 *   the invoice, and leaves the invoice cancelled and paid_amount untouched.
 * - A normal invoice is applied exactly as before.
 * - The pay link already answers 'invoice_cancelled' for a cancelled invoice.
 */
jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: (_path, fn) => fn,
}));
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (...args) => args[args.length - 1],
}));
jest.mock('../services/email/senders', () => ({
  sendInvoiceCreatedEmail: jest.fn(async () => true),
  sendPaymentConfirmationEmail: jest.fn(async () => true),
}));

jest.mock('../services/stripe/checkout', () => ({
  isStripeConfigured: () => true,
  assertStripeConfiguration: () => true,
  getStripeSecretKey: () => 'sk_test_x',
  getCheckoutUrls: () => ({success: 'https://x.test/ok', cancel: 'https://x.test/no'}),
  getOrCreateCustomer: jest.fn(async () => 'cus_1'),
  createCheckoutSession: jest.fn(),
  createPaymentIntentForSheet: jest.fn(),
}));

const admin = require('firebase-admin');
const {createFakeFirestore, installOnAdmin} = require('./helpers/fake_firestore');
const payLinks = require('../services/payment_links');

const invoice = (over = {}) => ({
  invoice_number: 'INV-2026-200',
  parent_id: 'parent_1',
  student_id: 'stu_1',
  status: 'cancelled',
  total_amount: 100,
  paid_amount: 0,
  currency: 'USD',
  period: '2026-10',
  pay_link_token: 'tok_1',
  ...over,
});

const seed = (invoiceOver) => ({
  users: {parent_1: {first_name: 'Mariama'}, admin_1: {user_type: 'admin'}},
  invoices: {inv_1: invoice(invoiceOver)},
  payments: {
    pay_1: {invoice_id: 'inv_1', parent_id: 'parent_1', amount: 100, status: 'processing', payment_method: 'stripe'},
  },
});

const setup = (data) => {
  const db = createFakeFirestore(data);
  installOnAdmin(admin, db);
  return db;
};

describe('payment sessions refuse a cancelled invoice', () => {
  test.each([['createPaymentSession'], ['createPaymentIntent']])('%s', async (name) => {
    const db = setup(seed());
    const handlers = require('../handlers/payments');
    await expect(handlers[name]({auth: {uid: 'parent_1'}, data: {invoiceId: 'inv_1'}})).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'This invoice was cancelled.',
    });
    // no new payment document
    expect(Object.keys(db.store.payments)).toEqual(['pay_1']);
  });

  test('the pay link already resolves a cancelled invoice to invoice_cancelled', async () => {
    const db = setup(seed());
    const resolved = await payLinks.resolvePayLink(db, 'tok_1');
    expect(resolved.state).toBe('invoice_cancelled');
  });
});

describe('applyPaymentStatusInTransaction on a cancelled invoice', () => {
  const apply = (db) => {
    const {applyPaymentStatusInTransaction} = require('../handlers/payments');
    return db.runTransaction((tx) =>
      applyPaymentStatusInTransaction(tx, db, db.collection('payments').doc('pay_1'), {
        status: 'completed',
        extraPaymentFields: {stripe_payment_intent_id: 'pi_1'},
      })
    );
  };

  test('records the payment, flags needs_refund, and leaves the invoice cancelled', async () => {
    const db = setup(seed());
    const result = await apply(db);

    expect(result).toMatchObject({updated: true, cancelledInvoice: true, needsRefund: true});
    expect(result.paymentCompleted).toBeUndefined(); // no receipt email for a cancelled invoice

    const stored = db.store.invoices.inv_1;
    expect(stored.status).toBe('cancelled');
    expect(stored.paid_amount).toBe(0);
    expect(stored.needs_refund).toBe(true);
    expect(stored.refund_due_amount).toBe(100);

    expect(db.store.payments.pay_1).toMatchObject({
      status: 'completed',
      needs_refund: true,
      applied_amount: 0,
      stripe_payment_intent_id: 'pi_1',
    });
  });

  test('a second delivery of the same event does nothing more', async () => {
    const db = setup(seed());
    await apply(db);
    const again = await apply(db);
    expect(again).toEqual({alreadyProcessed: true});
    expect(db.store.invoices.inv_1.refund_due_amount).toBe(100);
  });

  test('a failed payment on a cancelled invoice is just recorded as failed', async () => {
    const db = setup(seed());
    const {applyPaymentStatusInTransaction} = require('../handlers/payments');
    await db.runTransaction((tx) =>
      applyPaymentStatusInTransaction(tx, db, db.collection('payments').doc('pay_1'), {status: 'failed'})
    );
    expect(db.store.payments.pay_1.status).toBe('failed');
    expect(db.store.invoices.inv_1.needs_refund).toBeUndefined();
  });

  test('a normal invoice is still applied as before', async () => {
    const db = setup(seed({status: 'pending'}));
    const result = await apply(db);
    expect(result).toMatchObject({updated: true, invoiceStatus: 'paid', newPaid: 100, paymentCompleted: true});
    expect(db.store.invoices.inv_1).toMatchObject({status: 'paid', paid_amount: 100});
    expect(db.store.invoices.inv_1.needs_refund).toBeUndefined();
  });
});
