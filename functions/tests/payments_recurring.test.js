jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: jest.fn((_, handler) => handler),
}));

jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: jest.fn((_, handler) => handler),
}));

jest.mock('firebase-functions', () => ({
  https: {
    HttpsError: class HttpsError extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
    },
    onCall: jest.fn((handler) => handler),
    onRequest: jest.fn((handler) => handler),
  },
}));

jest.mock('firebase-admin', () => ({
  firestore: Object.assign(
    jest.fn(() => ({})),
    {
      FieldValue: {
        serverTimestamp: jest.fn(() => ({serverTimestamp: true})),
        delete: jest.fn(() => ({delete: true})),
      },
      Timestamp: {
        fromDate: jest.fn((date) => ({toDate: () => date})),
      },
    },
  ),
  messaging: jest.fn(() => ({})),
}));

jest.mock('../services/payoneer/client', () => ({
  createPayoneerClient: jest.fn(() => ({
    config: {isMock: true},
    createCheckoutSession: jest.fn(async () => ({
      sessionId: 'payoneer_session_1',
      checkoutUrl: 'https://checkout.example/session_1',
    })),
  })),
}));

jest.mock('../services/stripe/checkout', () => ({
  isStripeConfigured: jest.fn(() => false),
  getCheckoutUrls: jest.fn(() => ({success: '', cancel: ''})),
}));

jest.mock('../utils/invoice_pdf', () => ({
  generateInvoicePdfBuffer: jest.fn(() => Buffer.from('pdf')),
}));

jest.mock('../services/email/senders', () => ({
  sendInvoiceCreatedEmail: jest.fn(),
  sendPaymentConfirmationEmail: jest.fn(),
}));

const admin = require('firebase-admin');

const snap = (id, data) => ({
  id,
  exists: data !== undefined,
  data: () => data,
});

const buildDb = ({extraInvoices = {}} = {}) => {
  const invoices = {
    paid_inv: {
      invoice_number: 'INV-2026-001',
      parent_id: 'parent_1',
      student_id: 'student_1',
      status: 'paid',
      total_amount: 125,
      paid_amount: 125,
      currency: 'USD',
      period: '2026-01',
      items: [{description: 'Tuition', quantity: 1, unit_price: 125, total: 125}],
      recurring_enabled: true,
      reusable_payment_link: 'https://app.example/?invoiceId=paid_inv',
    },
    ...extraInvoices,
  };
  const payments = [];

  const invoiceRef = (id) => ({
    id,
    get: async () => snap(id, invoices[id]),
  });

  const db = {
    collection: jest.fn((name) => {
      if (name === 'users') {
        return {
          doc: (id) => ({
            get: async () => snap(id, id === 'parent_1' ? {user_type: 'parent'} : undefined),
          }),
        };
      }

      if (name === 'invoice_counters') {
        return {
          doc: (id) => ({id, path: `invoice_counters/${id}`}),
        };
      }

      if (name === 'invoices') {
        return {
          doc: (id) => invoiceRef(id || 'next_inv'),
          where: (field, op, value) => ({
            where: (field2, op2, value2) => ({
              where: (field3, op3, value3) => ({
                limit: () => ({
                  get: async () => {
                    const docs = Object.entries(invoices)
                      .filter(([, data]) =>
                        data[field] === value &&
                        data[field2] === value2 &&
                        data[field3] === value3)
                      .map(([id, data]) => ({id, ref: invoiceRef(id), data: () => data}));
                    return {empty: docs.length === 0, docs};
                  },
                }),
              }),
            }),
          }),
        };
      }

      if (name === 'payments') {
        return {
          doc: () => ({
            id: 'payment_1',
            set: async (data, options) => payments.push({data, options}),
          }),
        };
      }

      throw new Error(`Unexpected collection: ${name}`);
    }),
    runTransaction: async (callback) => callback({
      get: async () => snap('2026', {next: 7}),
      set: (ref, data) => {
        if (ref.id === 'next_inv') {
          invoices[ref.id] = data;
        }
      },
    }),
    invoices,
    payments,
  };

  return db;
};

describe('payments recurring invoices', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('calculates the next billing period from yyyy-MM', () => {
    const {_nextMonthPeriod} = require('../handlers/payments');

    expect(_nextMonthPeriod('2026-01')).toBe('2026-02');
    expect(_nextMonthPeriod('2026-12')).toBe('2027-01');
  });

  test('reused paid invoice link creates a payable next-month invoice', async () => {
    const db = buildDb();
    admin.firestore.mockReturnValue(db);

    const {createPaymentSession} = require('../handlers/payments');

    const result = await createPaymentSession({
      auth: {uid: 'parent_1', token: {email: 'parent@example.com'}},
      data: {invoiceId: 'paid_inv'},
    });

    expect(result).toMatchObject({
      success: true,
      checkoutUrl: 'https://checkout.example/session_1',
      provider: 'payoneer',
    });
    expect(db.invoices.next_inv).toMatchObject({
      parent_id: 'parent_1',
      student_id: 'student_1',
      status: 'pending',
      total_amount: 125,
      paid_amount: 0,
      period: '2026-02',
      recurring_enabled: true,
      recurring_template_invoice_id: 'paid_inv',
      payment_link: 'https://app.example/?invoiceId=paid_inv',
      reusable_payment_link: 'https://app.example/?invoiceId=paid_inv',
    });
    expect(db.payments[0].data).toMatchObject({
      invoice_id: 'next_inv',
      parent_id: 'parent_1',
      amount: 125,
      status: 'pending',
      payment_method: 'payoneer',
    });
  });

  test('reused paid invoice link uses an existing unpaid next-month invoice', async () => {
    const db = buildDb({
      extraInvoices: {
        feb_unpaid: {
          invoice_number: 'INV-2026-007',
          parent_id: 'parent_1',
          student_id: 'student_1',
          status: 'pending',
          total_amount: 125,
          paid_amount: 25,
          currency: 'USD',
          period: '2026-02',
          items: [{description: 'Tuition', quantity: 1, unit_price: 125, total: 125}],
          recurring_enabled: true,
          recurring_template_invoice_id: 'paid_inv',
          reusable_payment_link: 'https://app.example/?invoiceId=paid_inv',
        },
      },
    });
    admin.firestore.mockReturnValue(db);

    const {createPaymentSession} = require('../handlers/payments');

    await createPaymentSession({
      auth: {uid: 'parent_1', token: {email: 'parent@example.com'}},
      data: {invoiceId: 'paid_inv'},
    });

    expect(db.invoices.next_inv).toBeUndefined();
    expect(db.payments[0].data).toMatchObject({
      invoice_id: 'feb_unpaid',
      parent_id: 'parent_1',
      amount: 100,
      status: 'pending',
      payment_method: 'payoneer',
    });
  });

  test('reused paid invoice link skips paid recurring invoices and creates the next month', async () => {
    const db = buildDb({
      extraInvoices: {
        feb_paid: {
          invoice_number: 'INV-2026-007',
          parent_id: 'parent_1',
          student_id: 'student_1',
          status: 'paid',
          total_amount: 125,
          paid_amount: 125,
          currency: 'USD',
          period: '2026-02',
          items: [{description: 'Tuition', quantity: 1, unit_price: 125, total: 125}],
          recurring_enabled: true,
          recurring_template_invoice_id: 'paid_inv',
          reusable_payment_link: 'https://app.example/?invoiceId=paid_inv',
        },
      },
    });
    admin.firestore.mockReturnValue(db);

    const {createPaymentSession} = require('../handlers/payments');

    await createPaymentSession({
      auth: {uid: 'parent_1', token: {email: 'parent@example.com'}},
      data: {invoiceId: 'paid_inv'},
    });

    expect(db.invoices.next_inv).toMatchObject({
      period: '2026-03',
      status: 'pending',
      recurring_template_invoice_id: 'paid_inv',
      reusable_payment_link: 'https://app.example/?invoiceId=paid_inv',
    });
    expect(db.payments[0].data.invoice_id).toBe('next_inv');
  });
});
