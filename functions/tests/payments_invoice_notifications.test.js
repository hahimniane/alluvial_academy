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
admin.firestore.Timestamp = {
  ...(admin.firestore.Timestamp || {}),
  fromDate: jest.fn((date) => ({__type: 'timestamp', date, toDate: () => date})),
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

const buildManualPaymentDb = ({users = {}, invoices = {}} = {}) => {
  const historyAdds = [];
  const writes = [];
  let paymentCounter = 0;

  const docRef = (collectionName, id) => ({collectionName, id});

  const db = {
    collection: jest.fn((name) => {
      if (name === 'users') {
        return {
          doc: (id) => ({
            ...docRef(name, id),
            get: async () => ({
              exists: Object.prototype.hasOwnProperty.call(users, id),
              data: () => users[id],
            }),
          }),
        };
      }

      if (name === 'invoices') {
        return {
          doc: (id) => docRef(name, id),
        };
      }

      if (name === 'payments') {
        return {
          doc: () => docRef(name, `payment_${++paymentCounter}`),
        };
      }

      if (name === 'notification_history') {
        return {
          add: async (data) => historyAdds.push(data),
        };
      }

      throw new Error(`Unexpected collection: ${name}`);
    }),
    runTransaction: async (handler) => {
      const tx = {
        get: async (ref) => {
          if (ref.collectionName === 'invoices') {
            return {
              exists: Object.prototype.hasOwnProperty.call(invoices, ref.id),
              data: () => invoices[ref.id],
            };
          }
          throw new Error(`Unexpected tx.get: ${ref.collectionName}/${ref.id}`);
        },
        set: (ref, data, options) => {
          writes.push({ref, data, options});
          if (ref.collectionName === 'invoices') {
            invoices[ref.id] = {...(invoices[ref.id] || {}), ...data};
          }
        },
      };
      return handler(tx);
    },
    historyAdds,
    writes,
    invoices,
  };

  return db;
};

const buildRecurringDb = ({plans = {}, invoices = {}, counters = {}} = {}) => {
  const writes = [];
  const docRef = (collectionName, id) => ({collectionName, id});

  const applySet = (ref, data, options) => {
    writes.push({ref, data, options});
    if (ref.collectionName === 'recurring_billing_plans') {
      plans[ref.id] =
        options?.merge === true ? {...(plans[ref.id] || {}), ...data} : data;
    }
    if (ref.collectionName === 'invoices') {
      invoices[ref.id] =
        options?.merge === true ? {...(invoices[ref.id] || {}), ...data} : data;
    }
    if (ref.collectionName === 'invoice_counters') {
      counters[ref.id] =
        options?.merge === true ? {...(counters[ref.id] || {}), ...data} : data;
    }
  };

  const db = {
    collection: jest.fn((name) => {
      if (name === 'recurring_billing_plans') {
        return {
          doc: (id) => ({
            ...docRef(name, id),
            set: async (data, options) =>
              applySet(docRef(name, id), data, options),
          }),
          where: () => ({
            limit: () => ({
              get: async () => ({
                docs: Object.entries(plans)
                  .filter(([, data]) => data.status === 'active')
                  .map(([id, data]) => ({
                    id,
                    data: () => data,
                  })),
              }),
            }),
          }),
        };
      }

      if (name === 'invoices' || name === 'invoice_counters') {
        return {
          doc: (id) => docRef(name, id),
        };
      }

      throw new Error(`Unexpected collection: ${name}`);
    }),
    runTransaction: async (handler) => {
      const tx = {
        get: async (ref) => {
          if (ref.collectionName === 'recurring_billing_plans') {
            return {
              exists: Object.prototype.hasOwnProperty.call(plans, ref.id),
              data: () => plans[ref.id],
            };
          }
          if (ref.collectionName === 'invoices') {
            return {
              exists: Object.prototype.hasOwnProperty.call(invoices, ref.id),
              data: () => invoices[ref.id],
            };
          }
          if (ref.collectionName === 'invoice_counters') {
            return {
              exists: Object.prototype.hasOwnProperty.call(counters, ref.id),
              data: () => counters[ref.id],
            };
          }
          throw new Error(`Unexpected tx.get: ${ref.collectionName}/${ref.id}`);
        },
        set: (ref, data, options) => applySet(ref, data, options),
      };
      return handler(tx);
    },
    writes,
    plans,
    invoices,
    counters,
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

  test('marks the invoice when notification sending fails', async () => {
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    sendInvoiceCreatedEmail.mockRejectedValueOnce(new Error('SMTP down'));
    admin.messaging.mockReturnValue({
      sendEachForMulticast: jest.fn(),
    });

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

    const writes = [];
    const {onInvoiceCreated} = require('../handlers/payments');
    await onInvoiceCreated({
      params: {invoiceId: 'invoice_failed'},
      data: {
        data: () => ({
          parent_id: 'parent_1',
          invoice_number: 'INV-2026-030',
          total_amount: 100,
          paid_amount: 0,
          currency: 'USD',
        }),
        ref: {
          set: async (data, options) => writes.push({data, options}),
        },
      },
    });

    expect(writes).toHaveLength(1);
    expect(writes[0].options).toEqual({merge: true});
    expect(writes[0].data.notification_status).toBe('failed');
    expect(writes[0].data.notification_result).toEqual(
      expect.objectContaining({
        success: true,
        email_sent: false,
        push_sent: false,
        errors: expect.arrayContaining(['email: SMTP down']),
      })
    );
    expect(errorSpy).toHaveBeenCalledWith(
      '[payments] Failed to send invoice email for invoice_failed:',
      expect.any(Error)
    );
    errorSpy.mockRestore();
  });

  test('records a manual Zelle payment and clears the invoice balance', async () => {
    const db = buildManualPaymentDb({
      users: {
        admin_1: {role: 'admin'},
        parent_1: {
          first_name: 'Amina',
          last_name: 'Diallo',
          email: 'parent@example.com',
        },
      },
      invoices: {
        invoice_1: {
          invoice_number: 'INV-2026-020',
          parent_id: 'parent_1',
          student_id: 'student_1',
          total_amount: 100,
          paid_amount: 40,
          currency: 'USD',
          status: 'overdue',
          due_date: {toDate: () => new Date('2026-07-01T00:00:00.000Z')},
        },
      },
    });
    admin.firestore.mockReturnValue(db);

    const {recordManualPayment} = require('../handlers/payments');
    const result = await recordManualPayment({
      auth: {uid: 'admin_1'},
      data: {
        invoiceId: 'invoice_1',
        amount: 60,
        paymentMethod: 'zelle',
        reference: 'ZELLE-123',
        receivedAt: '2026-07-04T00:00:00.000Z',
      },
    });

    expect(result.success).toBe(true);
    expect(result.invoiceStatus).toBe('paid');
    expect(db.invoices.invoice_1).toEqual(
      expect.objectContaining({
        paid_amount: 100,
        status: 'paid',
      })
    );
    expect(db.writes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          ref: expect.objectContaining({collectionName: 'payments'}),
          data: expect.objectContaining({
            invoice_id: 'invoice_1',
            parent_id: 'parent_1',
            amount: 60,
            status: 'completed',
            payment_method: 'zelle',
            payment_source: 'manual',
            reference_number: 'ZELLE-123',
            created_by: 'admin_1',
          }),
        }),
        expect.objectContaining({
          ref: expect.objectContaining({
            collectionName: 'invoices',
            id: 'invoice_1',
          }),
          data: expect.objectContaining({
            paid_amount: 100,
            status: 'paid',
          }),
          options: {merge: true},
        }),
      ])
    );
    expect(sendPaymentConfirmationEmail).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'parent@example.com',
        invoiceNumber: 'INV-2026-020',
        amountPaid: '$60.00',
        paymentMethod: 'Zelle',
      })
    );
  });

  test('generates due recurring invoices with the full billing period', async () => {
    const db = buildRecurringDb({
      counters: {
        2026: {next: 31},
      },
      plans: {
        plan_1: {
          parent_id: 'parent_1',
          student_id: 'student_1',
          status: 'active',
          currency: 'USD',
          next_period: '2026-08',
          billing_months: 2,
          due_day: 5,
          access_cutoff_days_after_due: 2,
          base_items: [
            {
              description: 'Tuition - Student One',
              quantity: 1,
              unit_price: 100,
              total: 100,
            },
          ],
          created_by: 'admin_1',
        },
      },
    });
    admin.firestore.mockReturnValue(db);

    const {_runRecurringInvoiceGeneration} = require('../handlers/payments');
    const result = await _runRecurringInvoiceGeneration({
      db,
      now: new Date('2026-08-01T00:00:00.000Z'),
    });

    expect(result.invoicesCreated).toBe(1);
    expect(db.plans.plan_1).toEqual(
      expect.objectContaining({
        next_period: '2026-10',
        last_invoice_id: 'recurring_plan_1_2026-08',
        last_invoice_number: 'INV-2026-031',
      })
    );
    expect(db.invoices['recurring_plan_1_2026-08']).toEqual(
      expect.objectContaining({
        invoice_number: 'INV-2026-031',
        parent_id: 'parent_1',
        student_id: 'student_1',
        total_amount: 200,
        period: '2026-08..2026-09',
        period_start: '2026-08',
        period_end: '2026-09',
        billing_months: 2,
        recurring_plan_id: 'plan_1',
        notification_status: 'pending',
      })
    );
    expect(db.invoices['recurring_plan_1_2026-08'].items[0]).toEqual(
      expect.objectContaining({
        description: 'Tuition - Student One · Aug 2026 - Sep 2026',
        total: 200,
      })
    );
  });
});
