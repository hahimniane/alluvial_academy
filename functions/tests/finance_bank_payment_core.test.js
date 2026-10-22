/**
 * recordManualPaymentCore is what a confirmed bank deposit pays through.
 *
 * Expected behavior:
 * - Records one completed payment and raises the invoice's paid amount.
 * - With a paymentDocId it is idempotent: a second call writes nothing, so a
 *   retried confirmation never pays an invoice twice.
 * - Still refuses a cancelled invoice, an already paid one, and an amount above
 *   the balance (same rules as the admin callable).
 */

jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: (_path, fn) => fn,
}));

jest.mock('../services/email/senders', () => ({
  sendInvoiceCreatedEmail: jest.fn(async () => true),
  sendPaymentConfirmationEmail: jest.fn(async () => true),
}));

const admin = require('firebase-admin');
const {install} = require('./helpers/fake_firestore');
const {sendPaymentConfirmationEmail} = require('../services/email/senders');
const {recordManualPaymentCore} = require('../handlers/payments');

let fake;

const invoice = (extra = {}) => ({
  invoice_number: 'INV-2026-0101', parent_id: 'p1', student_id: 's1', total_amount: 160, paid_amount: 0, currency: 'USD',
  status: 'pending', due_date: new Date('2026-10-01T15:00:00Z'), ...extra,
});

const pay = (over = {}) => recordManualPaymentCore(fake, {
  invoiceId: 'inv1', amount: 160, paymentMethod: 'zelle', reference: 'plaid_t1', note: 'Zelle',
  receivedDate: new Date('2026-10-20T12:00:00Z'), actorUid: 'admin1', paymentDocId: 'bank_plaid_t1_inv1',
  paymentSource: 'bank', extraPaymentFields: {bank_transaction_id: 'plaid_t1'}, ...over,
});

beforeEach(() => {
  sendPaymentConfirmationEmail.mockClear();
  fake = install(admin, {
    users: {admin1: {role: 'admin', first_name: 'Ada', last_name: 'Min'}, p1: {first_name: 'Seydou', last_name: 'Sow', email: 'p@example.com'}},
    invoices: {inv1: invoice()},
  });
});

test('records the payment with the bank reference and updates the invoice', async () => {
  const out = await pay();
  expect(out.success).toBe(true);
  expect(fake.peek('payments', 'bank_plaid_t1_inv1')).toMatchObject({
    invoice_id: 'inv1', parent_id: 'p1', amount: 160, status: 'completed', payment_method: 'zelle',
    payment_source: 'bank', reference_number: 'plaid_t1', bank_transaction_id: 'plaid_t1', created_by: 'admin1',
  });
  expect(fake.peek('invoices', 'inv1')).toMatchObject({paid_amount: 160, status: 'paid', last_payment_by_uid: 'admin1'});
  expect(sendPaymentConfirmationEmail).toHaveBeenCalledTimes(1);
});

test('a second call for the same payment id changes nothing', async () => {
  await pay();
  const again = await pay();
  expect(again.alreadyRecorded).toBe(true);
  expect(fake.peek('invoices', 'inv1').paid_amount).toBe(160);
  expect(Object.keys(fake.all('payments'))).toEqual(['bank_plaid_t1_inv1']);
  expect(sendPaymentConfirmationEmail).toHaveBeenCalledTimes(1);
});

test('keeps the callable\'s rules: balance, cancelled, already paid', async () => {
  await expect(pay({amount: 200, paymentDocId: 'x1'})).rejects.toMatchObject({code: 'invalid-argument'});
  await fake.collection('invoices').doc('inv1').update({status: 'cancelled'});
  await expect(pay({paymentDocId: 'x2'})).rejects.toMatchObject({code: 'failed-precondition'});
  await fake.collection('invoices').doc('inv1').update({status: 'pending', paid_amount: 160});
  await expect(pay({paymentDocId: 'x3'})).rejects.toMatchObject({code: 'failed-precondition'});
  expect(fake.all('payments')).toEqual({});
});

test('without a payment id it still works like before (a fresh document each time)', async () => {
  await pay({paymentDocId: null, amount: 60});
  await pay({paymentDocId: null, amount: 100});
  expect(Object.keys(fake.all('payments'))).toHaveLength(2);
  expect(fake.peek('invoices', 'inv1').status).toBe('paid');
});
