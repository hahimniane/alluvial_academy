jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: (_path, fn) => fn,
}));

jest.mock('../services/email/senders', () => ({
  sendInvoiceCreatedEmail: jest.fn(async () => true),
  sendPaymentConfirmationEmail: jest.fn(async () => true),
}));

const admin = require('firebase-admin');
const {
  sendInvoiceCreatedEmail,
  sendPaymentConfirmationEmail,
} = require('../services/email/senders');

admin.messaging = jest.fn();
admin.firestore.FieldValue = {
  ...(admin.firestore.FieldValue || {}),
  serverTimestamp: jest.fn(() => ({__type: 'serverTimestamp'})),
  delete: jest.fn(() => ({__type: 'delete'})),
};

const buildDb = ({users = {}} = {}) => {
  const historyAdds = [];
  const userSets = [];

  const db = {
    collection: jest.fn((name) => {
      if (name === 'users') {
        return {
          doc: (id) => ({
            get: async () => ({
              exists: Object.prototype.hasOwnProperty.call(users, id),
              data: () => users[id],
            }),
            set: async (data, options) => userSets.push({id, data, options}),
          }),
        };
      }

      if (name === 'notification_history') {
        return {
          add: async (data) => historyAdds.push(data),
        };
      }

      throw new Error(`Unexpected collection: ${name}`);
    }),
    historyAdds,
    userSets,
  };

  return db;
};

describe('payments invoice notifications', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('emails and sends an app notification to the invoice payer', async () => {
    const sendEachForMulticast = jest.fn(async () => ({
      successCount: 2,
      failureCount: 0,
      responses: [{success: true}, {success: true}],
    }));
    admin.messaging.mockReturnValue({sendEachForMulticast});

    const db = buildDb({
      users: {
        parent_1: {
          first_name: 'Amina',
          last_name: 'Diallo',
          email: 'parent@example.com',
          fcmTokens: [{token: 'token-a'}],
          fcmToken: 'token-b',
        },
      },
    });
    admin.firestore.mockReturnValue(db);

    const {_notifyInvoiceRecipient} = require('../handlers/payments');

    const result = await _notifyInvoiceRecipient(db, 'invoice_1', {
      parent_id: 'parent_1',
      invoice_number: 'INV-2026-010',
      total_amount: 100,
      paid_amount: 24.5,
      currency: 'USD',
      due_date: {toDate: () => new Date('2026-06-01T12:00:00.000Z')},
      access_cutoff_date: {toDate: () => new Date('2026-06-02T12:00:00.000Z')},
      items: [
        {
          description: 'Quran class',
          quantity: 2,
          unit_price: 50,
          total: 100,
        },
      ],
    });

    expect(result.emailSent).toBe(true);
    expect(result.pushSent).toBe(true);
    expect(sendInvoiceCreatedEmail).toHaveBeenCalledWith(expect.objectContaining({
      email: 'parent@example.com',
      displayName: 'Amina Diallo',
      invoiceNumber: 'INV-2026-010',
      amountDue: '$75.50',
      dueDate: 'Jun 1, 2026',
      accessCutoffDate: 'Jun 2, 2026',
      appUrl: 'https://alluwaleducationhub.org',
      attachments: [
        expect.objectContaining({
          filename: 'INV-2026-010.pdf',
          contentType: 'application/pdf',
          content: expect.any(Buffer),
        }),
      ],
    }));
    const attachment = sendInvoiceCreatedEmail.mock.calls[0][0].attachments[0];
    expect(attachment.content.toString('utf8')).toContain('%PDF-1.4');
    expect(sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({
        tokens: ['token-a', 'token-b'],
        notification: {
          title: 'New invoice available',
          body: 'INV-2026-010 is ready. Amount due: $75.50.',
        },
        data: expect.objectContaining({
          type: 'invoice_created',
          invoiceId: 'invoice_1',
          invoiceNumber: 'INV-2026-010',
        }),
      })
    );
    expect(db.historyAdds).toHaveLength(1);
    expect(db.historyAdds[0].results).toEqual({
      totalRecipients: 1,
      fcmSuccess: 1,
      fcmFailed: 0,
      emailsSent: 1,
      emailsFailed: 0,
    });
  });

  test('skips notifications when the invoice payer is missing', async () => {
    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    admin.messaging.mockReturnValue({
      sendEachForMulticast: jest.fn(),
    });

    const db = buildDb({users: {}});
    admin.firestore.mockReturnValue(db);

    const {_notifyInvoiceRecipient} = require('../handlers/payments');
    const result = await _notifyInvoiceRecipient(db, 'invoice_2', {
      parent_id: 'missing_parent',
      total_amount: 50,
    });

    expect(result).toEqual({success: false, reason: 'payer_not_found'});
    expect(sendInvoiceCreatedEmail).not.toHaveBeenCalled();
    expect(warnSpy).toHaveBeenCalledWith(
      '[payments] Invoice invoice_2 payer not found; checked missing_parent.'
    );
    warnSpy.mockRestore();
  });

  test('falls back to the student when the invoice has no parent', async () => {
    const sendEachForMulticast = jest.fn(async () => ({
      successCount: 1,
      failureCount: 0,
      responses: [{success: true}],
    }));
    admin.messaging.mockReturnValue({sendEachForMulticast});

    const db = buildDb({
      users: {
        student_1: {
          first_name: 'Mamadou',
          last_name: 'Bah',
          email: 'adult.student@example.com',
          fcmTokens: [{token: 'student-token'}],
        },
      },
    });
    admin.firestore.mockReturnValue(db);

    const {_notifyInvoiceRecipient} = require('../handlers/payments');
    const result = await _notifyInvoiceRecipient(db, 'invoice_3', {
      student_id: 'student_1',
      invoice_number: 'INV-2026-011',
      total_amount: 80,
      paid_amount: 0,
      currency: 'USD',
    });

    expect(result.payerId).toBe('student_1');
    expect(result.emailSent).toBe(true);
    expect(result.pushSent).toBe(true);
    expect(sendInvoiceCreatedEmail).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'adult.student@example.com',
        displayName: 'Mamadou Bah',
        invoiceNumber: 'INV-2026-011',
        amountDue: '$80.00',
      })
    );
    expect(sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({
        tokens: ['student-token'],
        data: expect.objectContaining({
          type: 'invoice_created',
          invoiceId: 'invoice_3',
        }),
      })
    );
  });

  test('sends a thank-you email when payment is completed', async () => {
    const db = buildDb({
      users: {
        parent_1: {
          first_name: 'Amina',
          last_name: 'Diallo',
          email: 'parent@example.com',
        },
      },
    });
    admin.firestore.mockReturnValue(db);

    const {_notifyPaymentCompleted} = require('../handlers/payments');
    const result = await _notifyPaymentCompleted(db, 'payment_1', {
      invoiceId: 'invoice_1',
      invoiceNumber: 'INV-2026-010',
      parentId: 'parent_1',
      studentId: 'student_1',
      amount: 75.5,
      currency: 'USD',
      paymentMethod: 'stripe',
    });

    expect(result).toEqual({
      success: true,
      payerId: 'parent_1',
      emailSent: true,
    });
    expect(sendPaymentConfirmationEmail).toHaveBeenCalledWith({
      email: 'parent@example.com',
      displayName: 'Amina Diallo',
      invoiceNumber: 'INV-2026-010',
      amountPaid: '$75.50',
      paymentDate: expect.any(String),
      paymentMethod: 'Card / Stripe',
      appUrl: 'https://alluwaleducationhub.org',
    });
    expect(db.historyAdds).toHaveLength(1);
    expect(db.historyAdds[0]).toEqual(
      expect.objectContaining({
        title: 'Payment received',
        additionalData: expect.objectContaining({
          type: 'payment_completed',
          paymentId: 'payment_1',
          invoiceId: 'invoice_1',
        }),
      })
    );
  });
});
