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

const admin = require('firebase-admin');
const {
  deleteInvoice,
  _invoiceDeletionBlockReason,
} = require('../handlers/payments');

const buildDb = ({invoice, payments = []}) => {
  const writes = [];
  const invoiceRef = {kind: 'invoice', id: 'invoice_1'};
  const auditRef = {kind: 'audit', id: 'audit_1'};
  const paymentsQuery = {kind: 'payments_query'};

  const db = {
    collection: jest.fn((name) => {
      if (name === 'users') {
        return {
          doc: (id) => ({
            get: async () => ({
              exists: id === 'admin_1',
              data: () => ({role: 'admin'}),
            }),
          }),
        };
      }
      if (name === 'invoices') {
        return {
          doc: () => invoiceRef,
        };
      }
      if (name === 'payments') {
        return {
          where: () => paymentsQuery,
        };
      }
      if (name === 'invoice_deletion_audits') {
        return {
          doc: () => auditRef,
        };
      }
      if (name === 'decision_audits') {
        return {
          doc: (id) => ({
            kind: 'decision_summary',
            id,
            collection: (subcollection) => {
              if (subcollection !== 'events') {
                throw new Error(`Unexpected subcollection: ${subcollection}`);
              }
              return {
                doc: (eventId) => ({
                  kind: 'decision_event',
                  id: eventId,
                }),
              };
            },
          }),
        };
      }
      if (name === 'decision_audit_events') {
        return {
          doc: (id) => ({
            kind: 'decision_global_event',
            id,
          }),
        };
      }
      throw new Error(`Unexpected collection: ${name}`);
    }),
    runTransaction: async (handler) => handler({
      get: async (ref) => {
        if (ref.kind === 'invoice') {
          return {
            exists: invoice != null,
            data: () => invoice,
          };
        }
        if (ref.kind === 'payments_query') {
          return {
            docs: payments.map((payment, index) => ({
              id: `payment_${index + 1}`,
              data: () => payment,
            })),
          };
        }
        throw new Error(`Unexpected transaction read: ${ref.kind}`);
      },
      set: (ref, data) => writes.push({operation: 'set', ref, data}),
      delete: (ref) => writes.push({operation: 'delete', ref}),
    }),
    writes,
  };

  return db;
};

describe('invoice deletion safeguards', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    admin.firestore.FieldValue = {
      ...(admin.firestore.FieldValue || {}),
      serverTimestamp: jest.fn(() => ({__type: 'serverTimestamp'})),
    };
  });

  test.each([
    [
      'paid status',
      {status: 'paid', paid_amount: 0},
      [],
      'paid_invoice',
    ],
    [
      'partial payment amount',
      {status: 'pending', paid_amount: 25},
      [],
      'paid_invoice',
    ],
    [
      'completed payment despite stale invoice fields',
      {status: 'pending', paid_amount: 0},
      [{status: 'completed', amount: 25}],
      'paid_invoice',
    ],
    [
      'applied payment despite stale payment status',
      {status: 'pending', paid_amount: 0},
      [{status: 'failed', applied_amount: 10}],
      'paid_invoice',
    ],
    [
      'payment in progress',
      {status: 'pending', paid_amount: 0},
      [{status: 'processing'}],
      'payment_in_progress',
    ],
    [
      'failed payment history',
      {status: 'pending', paid_amount: 0},
      [{status: 'failed'}],
      'payment_history',
    ],
  ])('blocks deletion for %s', (_, invoice, payments, expected) => {
    expect(_invoiceDeletionBlockReason({invoice, payments})).toBe(expected);
  });

  test('deletes only a payment-free unpaid invoice and writes an audit', async () => {
    const invoice = {
      status: 'pending',
      paid_amount: 0,
      invoice_number: 'INV-2026-041',
      parent_id: 'parent_1',
      student_id: 'student_1',
    };
    const db = buildDb({invoice});
    admin.firestore.mockReturnValue(db);

    await expect(deleteInvoice({
      auth: {uid: 'admin_1'},
      data: {invoiceId: 'invoice_1'},
    })).resolves.toEqual({
      success: true,
      invoiceId: 'invoice_1',
      auditId: 'audit_1',
    });

    expect(db.writes).toEqual(expect.arrayContaining([
      expect.objectContaining({
        operation: 'set',
        data: expect.objectContaining({
          invoice_id: 'invoice_1',
          invoice_number: 'INV-2026-041',
          deleted_by: 'admin_1',
          invoice_snapshot: invoice,
        }),
      }),
      expect.objectContaining({
        operation: 'set',
        ref: expect.objectContaining({kind: 'decision_event'}),
        data: expect.objectContaining({
          entity_type: 'invoice',
          entity_id: 'invoice_1',
          action: 'invoice.deleted',
          actor_uid: 'admin_1',
        }),
      }),
      {
        operation: 'delete',
        ref: expect.objectContaining({kind: 'invoice', id: 'invoice_1'}),
      },
    ]));
    expect(db.writes).toHaveLength(5);
  });

  test('rejects a paid invoice even when called by an admin', async () => {
    const db = buildDb({
      invoice: {status: 'paid', paid_amount: 100},
    });
    admin.firestore.mockReturnValue(db);

    await expect(deleteInvoice({
      auth: {uid: 'admin_1'},
      data: {invoiceId: 'invoice_1'},
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reason: 'paid_invoice'},
    });
    expect(db.writes).toHaveLength(0);
  });
});
