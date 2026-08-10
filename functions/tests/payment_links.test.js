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

const SERVER_TIMESTAMP = {__sentinel: 'serverTimestamp'};
const DELETE_SENTINEL = {__sentinel: 'delete'};

jest.mock('firebase-admin', () => {
  const firestore = jest.fn();
  firestore.FieldValue = {
    serverTimestamp: () => SERVER_TIMESTAMP,
    delete: () => DELETE_SENTINEL,
    increment: (value) => ({__sentinel: 'increment', value}),
  };
  firestore.Timestamp = {
    now: () => ({toDate: () => new Date('2026-08-09T12:00:00Z')}),
    fromDate: (date) => ({toDate: () => date}),
  };
  return {firestore, initializeApp: jest.fn()};
});

const payLinks = require('../services/payment_links');
const {_parsePath, _pageForState} = require('../handlers/payment_links');
const {applyPaymentStatusInTransaction} = require('../handlers/payments');

// ── Token + URL ──────────────────────────────────────────────────────────────

describe('payment link tokens', () => {
  test('mints URL-safe tokens with no collisions', () => {
    const tokens = new Set();
    for (let i = 0; i < 500; i += 1) {
      const token = payLinks.generatePayLinkToken();
      expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
      expect(token.length).toBeGreaterThanOrEqual(40);
      tokens.add(token);
    }
    expect(tokens.size).toBe(500);
  });

  test('builds a /pay/ URL and tolerates a trailing slash on APP_URL', () => {
    const original = process.env.APP_URL;
    process.env.APP_URL = 'https://example.org/';
    expect(payLinks.buildPayLinkUrl('abc')).toBe('https://example.org/pay/abc');
    process.env.APP_URL = original;
  });

  test('PAY_LINK_BASE_URL overrides the base so links can skip hosting', () => {
    const original = process.env.PAY_LINK_BASE_URL;
    process.env.PAY_LINK_BASE_URL =
      'https://us-central1-proj.cloudfunctions.net/handlePaymentLink/';
    expect(payLinks.buildPayLinkUrl('abc')).toBe(
      'https://us-central1-proj.cloudfunctions.net/handlePaymentLink/abc'
    );
    if (original === undefined) delete process.env.PAY_LINK_BASE_URL;
    else process.env.PAY_LINK_BASE_URL = original;
  });

  test('new invoices ship with an active link', () => {
    const fields = payLinks.newPayLinkFields('admin_1');
    expect(fields.pay_link_status).toBe(payLinks.PAY_LINK_ACTIVE);
    expect(fields.pay_link_created_by).toBe('admin_1');
    expect(fields.pay_link_token).toBeTruthy();
  });
});

// ── Link state resolution ────────────────────────────────────────────────────

const fakeDb = (...invoices) => ({
  collection: () => ({
    where: () => ({
      limit: () => ({
        get: async () =>
          invoices.length
            ? {
              empty: false,
              docs: invoices.map((invoice, index) => ({
                id: `inv_${index + 1}`,
                ref: {id: `inv_${index + 1}`},
                data: () => invoice,
              })),
            }
            : {empty: true, docs: []},
      }),
    }),
  }),
});

const baseInvoice = {
  invoice_number: 'INV-2026-0042',
  status: 'pending',
  total_amount: 420,
  paid_amount: 0,
  currency: 'USD',
  pay_link_token: 'tok',
  pay_link_status: 'active',
};

describe('resolvePayLink', () => {
  test('an unknown token is not found', async () => {
    const result = await payLinks.resolvePayLink(fakeDb(), 'nope');
    expect(result.state).toBe('not_found');
  });

  test('refuses to guess when a token matches more than one invoice', async () => {
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    const result = await payLinks.resolvePayLink(
      fakeDb(baseInvoice, {...baseInvoice, invoice_number: 'INV-2026-0099'}),
      'tok'
    );
    expect(result.state).toBe('not_found');
    expect(spy).toHaveBeenCalled();
    spy.mockRestore();
  });

  test('an empty token is not found without hitting the database', async () => {
    const result = await payLinks.resolvePayLink(fakeDb(baseInvoice), '   ');
    expect(result.state).toBe('not_found');
  });

  test('an outstanding balance is payable for the full remainder', async () => {
    const result = await payLinks.resolvePayLink(fakeDb(baseInvoice), 'tok');
    expect(result.state).toBe('payable');
    expect(result.remaining).toBe(420);
  });

  test('a partly paid invoice is payable for the remainder only', async () => {
    const result = await payLinks.resolvePayLink(
      fakeDb({...baseInvoice, paid_amount: 120}),
      'tok'
    );
    expect(result.state).toBe('payable');
    expect(result.remaining).toBe(300);
  });

  test('a fully paid invoice retires the link', async () => {
    const result = await payLinks.resolvePayLink(
      fakeDb({...baseInvoice, paid_amount: 420, status: 'paid'}),
      'tok'
    );
    expect(result.state).toBe('already_paid');
  });

  test('a balance under the Stripe minimum is not payable online', async () => {
    const result = await payLinks.resolvePayLink(
      fakeDb({...baseInvoice, paid_amount: 419.75}),
      'tok'
    );
    expect(result.state).toBe('amount_too_small');
    expect(result.remaining).toBe(0.25);
  });

  test('a cancelled invoice is not payable', async () => {
    const result = await payLinks.resolvePayLink(
      fakeDb({...baseInvoice, status: 'cancelled'}),
      'tok'
    );
    expect(result.state).toBe('invoice_cancelled');
  });

  test('a cancelled link is dead even though the invoice is unpaid', async () => {
    const result = await payLinks.resolvePayLink(
      fakeDb({...baseInvoice, pay_link_status: 'cancelled'}),
      'tok'
    );
    expect(result.state).toBe('link_cancelled');
  });

  test('an invoice with no link status is treated as active', async () => {
    const invoice = {...baseInvoice};
    delete invoice.pay_link_status;
    const result = await payLinks.resolvePayLink(fakeDb(invoice), 'tok');
    expect(result.state).toBe('payable');
  });
});

// ── Session reuse ────────────────────────────────────────────────────────────

describe('reusablePendingSession', () => {
  const pending = (over = {}) => ({
    pay_link_pending: {
      payment_id: 'pay_1',
      amount: 420,
      checkout_url: 'https://checkout.stripe.com/x',
      created_at: {toDate: () => new Date(Date.now() - 60 * 1000)},
      ...over,
    },
  });

  test('reuses a fresh session for the same balance', () => {
    expect(payLinks.reusablePendingSession(pending(), 420)).toEqual({
      paymentId: 'pay_1',
      checkoutUrl: 'https://checkout.stripe.com/x',
    });
  });

  test('does not reuse a session minted for a different balance', () => {
    expect(payLinks.reusablePendingSession(pending(), 300)).toBeNull();
  });

  test('does not reuse a session Stripe would have expired', () => {
    const stale = pending({
      created_at: {toDate: () => new Date(Date.now() - 25 * 60 * 60 * 1000)},
    });
    expect(payLinks.reusablePendingSession(stale, 420)).toBeNull();
  });

  test('handles an invoice with no pending session', () => {
    expect(payLinks.reusablePendingSession({}, 420)).toBeNull();
  });
});

// ── Routing ──────────────────────────────────────────────────────────────────

describe('payment link routing', () => {
  test('parses hosting-rewritten and direct function paths alike', () => {
    expect(_parsePath('/pay/tok')).toEqual({token: 'tok', action: ''});
    expect(_parsePath('/tok')).toEqual({token: 'tok', action: ''});
    expect(_parsePath('/pay/tok/checkout')).toEqual({
      token: 'tok',
      action: 'checkout',
    });
    expect(_parsePath('/pay/tok/done')).toEqual({token: 'tok', action: 'done'});
    expect(_parsePath('/pay/')).toEqual({token: '', action: ''});
  });
});

// ── Rendering ────────────────────────────────────────────────────────────────

describe('payment link pages', () => {
  const resolved = (state, over = {}) => ({
    state,
    invoiceId: 'inv_1',
    invoiceNumber: 'INV-2026-0042',
    currency: 'USD',
    total: 420,
    paid: 0,
    remaining: 420,
    invoice: {due_date: {toDate: () => new Date('2026-08-20')}, student_id: 's'},
    ...over,
  });

  test('the payable page shows the balance and posts to checkout', () => {
    const page = _pageForState(resolved('payable'), {
      studentName: 'Aisha',
      token: 'tok',
    });
    expect(page.statusCode).toBe(200);
    expect(page.html).toContain('$420.00');
    expect(page.html).toContain('method="POST"');
    expect(page.html).toContain('/pay/tok/checkout');
    expect(page.html).toContain('Aisha');
  });

  test('an unknown link renders a 404 and leaks nothing', () => {
    const page = _pageForState({state: 'not_found'}, {token: 'tok'});
    expect(page.statusCode).toBe(404);
    expect(page.html).not.toContain('INV-');
  });

  test('the already-paid page offers no way to pay again', () => {
    const page = _pageForState(
      resolved('already_paid', {paid: 420, remaining: 0}),
      {token: 'tok'}
    );
    expect(page.html).not.toContain('method="POST"');
    expect(page.html).toContain('fully paid');
  });

  test('escapes invoice and student values into inert text', () => {
    const page = _pageForState(
      resolved('payable', {invoiceNumber: '<script>alert(1)</script>'}),
      {studentName: '"><img src=x onerror=alert(1)>', token: 'tok'}
    );
    expect(page.html).not.toContain('<script>alert(1)</script>');
    expect(page.html).not.toContain('<img');
    expect(page.html).toContain('&lt;script&gt;');
  });

  test('pages reference no external resources', () => {
    const page = _pageForState(resolved('payable'), {token: 'tok'});
    const refs = [...page.html.matchAll(/(?:src|href)="([^"]+)"/g)]
      .map((m) => m[1])
      .filter((url) => !url.startsWith('mailto:'));
    expect(refs).toEqual([]);
  });
});

// ── Overpayment clamp ────────────────────────────────────────────────────────

describe('applyPaymentStatusInTransaction overpayment clamp', () => {
  const runTransaction = async ({payment, invoice}) => {
    const writes = [];
    const paymentRef = {id: 'pay_1'};
    const invoiceRef = {id: 'inv_1'};
    const tx = {
      get: async (ref) =>
        ref === paymentRef
          ? {exists: true, data: () => payment}
          : {exists: true, data: () => invoice},
      set: (ref, data) => writes.push({ref, data}),
    };
    const db = {collection: () => ({doc: () => invoiceRef})};
    const result = await applyPaymentStatusInTransaction(tx, db, paymentRef, {
      status: 'completed',
    });
    return {
      result,
      paymentWrite: writes.find((w) => w.ref === paymentRef)?.data,
      invoiceWrite: writes.find((w) => w.ref === invoiceRef)?.data,
    };
  };

  test('credits the full amount when it fits the balance', async () => {
    const {result, invoiceWrite} = await runTransaction({
      payment: {invoice_id: 'inv_1', amount: 420, status: 'processing'},
      invoice: {total_amount: 420, paid_amount: 0},
    });
    expect(invoiceWrite.paid_amount).toBe(420);
    expect(invoiceWrite.status).toBe('paid');
    expect(result.overpaidAmount).toBe(0);
  });

  test('clamps a second full-balance payment instead of double-crediting', async () => {
    const {result, paymentWrite, invoiceWrite} = await runTransaction({
      payment: {invoice_id: 'inv_1', amount: 420, status: 'processing'},
      invoice: {total_amount: 420, paid_amount: 420},
    });
    expect(invoiceWrite.paid_amount).toBe(420);
    expect(result.appliedAmount).toBe(0);
    expect(result.overpaidAmount).toBe(420);
    expect(paymentWrite.overpaid_amount).toBe(420);
  });

  test('clamps a payment that only partly fits after a manual payment', async () => {
    const {result, invoiceWrite} = await runTransaction({
      payment: {invoice_id: 'inv_1', amount: 420, status: 'processing'},
      invoice: {total_amount: 420, paid_amount: 300},
    });
    expect(invoiceWrite.paid_amount).toBe(420);
    expect(result.appliedAmount).toBe(120);
    expect(result.overpaidAmount).toBe(300);
  });

  test('the receipt reports what the card was charged, not what was applied', async () => {
    const {result} = await runTransaction({
      payment: {invoice_id: 'inv_1', amount: 420, status: 'processing'},
      invoice: {total_amount: 420, paid_amount: 300},
    });
    expect(result.paymentInfo.amount).toBe(420);
    expect(result.paymentInfo.appliedAmount).toBe(120);
  });

  test('clears the stale pending session so the next visit mints a fresh one', async () => {
    const {invoiceWrite} = await runTransaction({
      payment: {invoice_id: 'inv_1', amount: 100, status: 'processing'},
      invoice: {total_amount: 420, paid_amount: 0},
    });
    expect(invoiceWrite.pay_link_pending).toEqual(DELETE_SENTINEL);
  });

  test('an already-completed payment is not applied twice', async () => {
    const {result} = await runTransaction({
      payment: {invoice_id: 'inv_1', amount: 420, status: 'completed'},
      invoice: {total_amount: 420, paid_amount: 420},
    });
    expect(result).toEqual({alreadyProcessed: true});
  });
});
