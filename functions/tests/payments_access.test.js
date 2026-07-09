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

const {
  _canUserPayInvoice,
} = require('../handlers/payments');

describe('payment invoice access', () => {
  test('allows a parent to pay an invoice by parent_id', () => {
    expect(_canUserPayInvoice({
      uid: 'parent_1',
      invoice: {
        parent_id: 'parent_1',
        student_id: 'student_1',
      },
    })).toBe(true);
  });

  test('allows an adult student to pay an invoice by student_id', () => {
    expect(_canUserPayInvoice({
      uid: 'adult_student_1',
      invoice: {
        parent_id: '',
        student_id: 'adult_student_1',
      },
    })).toBe(true);
  });

  test('allows explicit payer_id access', () => {
    expect(_canUserPayInvoice({
      uid: 'payer_1',
      invoice: {
        parent_id: 'parent_1',
        student_id: 'student_1',
        payer_id: 'payer_1',
      },
    })).toBe(true);
  });

  test('allows admins to pay any invoice', () => {
    expect(_canUserPayInvoice({
      uid: 'admin_1',
      isAdmin: true,
      invoice: {
        parent_id: 'parent_1',
        student_id: 'student_1',
      },
    })).toBe(true);
  });

  test('denies unrelated users', () => {
    expect(_canUserPayInvoice({
      uid: 'other_user',
      invoice: {
        parent_id: 'parent_1',
        student_id: 'student_1',
      },
    })).toBe(false);
  });
});
