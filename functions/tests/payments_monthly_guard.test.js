/**
 * createInvoice: one monthly tuition invoice per family per month.
 *
 * Expected behavior:
 * - A request that says kind 'monthly' is rejected with already-exists, naming
 *   the invoice number, when a non-cancelled monthly / first_month invoice (or
 *   one from the scheduled generator) already bills that parent + month.
 * - A cancelled invoice, another month, another family or a one-off charge does
 *   not block it.
 * - A request that says no kind behaves as before: no lookup, no kind stored.
 * - A created invoice records its kind and billing_month.
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

const admin = require('firebase-admin');
const {createInvoice} = require('../handlers/payments');

const buildDb = ({existing = []}) => {
  const writes = [];
  const invoiceQueries = [];
  const invoiceRef = {kind: 'invoice', id: 'new_invoice'};
  const counterRef = {kind: 'counter'};
  const parentQuery = {kind: 'parent_invoices'};

  const db = {
    getAll: async (...refs) => refs.map(() => ({exists: false, data: () => ({})})),
    collection: jest.fn((name) => {
      if (name === 'users') {
        return {
          doc: (id) => ({get: async () => ({exists: id === 'admin_1', data: () => ({role: 'admin', first_name: 'Hawa'})})}),
          where: () => ({limit: () => ({get: async () => ({empty: true, docs: []})})}),
        };
      }
      if (name === 'invoices') {
        return {
          doc: () => invoiceRef,
          where: (field, op, value) => {
            invoiceQueries.push([field, op, value]);
            return parentQuery;
          },
        };
      }
      if (name === 'invoice_counters') return {doc: () => counterRef};
      if (name === 'recurring_billing_plans') return {doc: () => ({kind: 'plan'}), where: () => ({where: () => ({kind: 'plans_q'})})};
      if (name === 'decision_audits') {
        return {
          doc: (id) => ({id, kind: 'decision_summary', collection: () => ({doc: (e) => ({kind: 'decision_event', id: e})})}),
        };
      }
      if (name === 'decision_audit_events') return {doc: (id) => ({kind: 'decision_global_event', id})};
      throw new Error(`Unexpected collection: ${name}`);
    }),
    runTransaction: async (handler) =>
      handler({
        get: async (ref) => {
          if (ref === parentQuery) {
            return {docs: existing.map((inv) => ({id: inv.id, data: () => inv}))};
          }
          if (ref.kind === 'counter') return {exists: true, data: () => ({next: 477})};
          if (ref.kind === 'plans_q') return {docs: []};
          throw new Error(`Unexpected transaction read: ${ref.kind}`);
        },
        set: (ref, data) => writes.push({ref, data}),
      }),
    writes,
    invoiceQueries,
  };
  return db;
};

const monthlyRequest = (over = {}) => ({
  auth: {uid: 'admin_1'},
  data: {
    parentId: 'parent_1',
    studentId: 'stu_1',
    kind: 'monthly',
    period: '2026-11',
    dueDate: '2026-11-01T12:00:00Z',
    items: [{description: 'Tuition - Amina', quantity: 1, unit_price: 80, total: 80, student_id: 'stu_1'}],
    ...over,
  },
});

const existing = (over = {}) => ({
  id: 'inv_old',
  parent_id: 'parent_1',
  invoice_number: 'INV-2026-410',
  status: 'pending',
  kind: 'monthly',
  billing_month: '2026-11',
  ...over,
});

describe('createInvoice monthly duplicate guard', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    admin.firestore.FieldValue = {
      ...(admin.firestore.FieldValue || {}),
      serverTimestamp: jest.fn(() => ({__type: 'serverTimestamp'})),
    };
    admin.firestore.Timestamp = {fromDate: (d) => ({toDate: () => d, iso: d.toISOString()})};
  });

  test.each([
    ['a monthly invoice', existing()],
    ['a first-month invoice', existing({kind: 'first_month', invoice_number: 'INV-2026-411'})],
    ['a scheduled-generator invoice', existing({id: 'recurring_plan_2026-11', kind: undefined, billing_month: undefined, period: '2026-11', invoice_number: 'INV-2026-412'})],
  ])('rejects when %s already bills the month, naming it', async (_, inv) => {
    const db = buildDb({existing: [inv]});
    admin.firestore.mockReturnValue(db);
    await expect(createInvoice(monthlyRequest())).rejects.toMatchObject({
      code: 'already-exists',
      message: expect.stringContaining(inv.invoice_number),
    });
    expect(db.writes).toHaveLength(0);
  });

  test.each([
    ['cancelled', existing({status: 'cancelled'})],
    ['another month', existing({billing_month: '2026-12'})],
    ['a one-off charge', existing({kind: 'one_off'})],
  ])('does not block on %s', async (_, inv) => {
    const db = buildDb({existing: [inv]});
    admin.firestore.mockReturnValue(db);
    const out = await createInvoice(monthlyRequest());
    expect(out).toMatchObject({success: true, invoiceNumber: 'INV-2026-477'});
    const created = db.writes.find((w) => w.ref.kind === 'invoice').data;
    expect(created).toMatchObject({kind: 'monthly', billing_month: '2026-11', parent_id: 'parent_1'});
  });

  test('the check is limited to the same parent', async () => {
    const db = buildDb({existing: []});
    admin.firestore.mockReturnValue(db);
    await createInvoice(monthlyRequest());
    expect(db.invoiceQueries).toEqual([['parent_id', '==', 'parent_1']]);
  });

  test('monthly tuition with no month is invalid', async () => {
    const db = buildDb({existing: []});
    admin.firestore.mockReturnValue(db);
    await expect(createInvoice(monthlyRequest({period: undefined, billingMonth: undefined}))).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('a one-off charge is never checked and records its month', async () => {
    const db = buildDb({existing: [existing()]});
    admin.firestore.mockReturnValue(db);
    await createInvoice(monthlyRequest({kind: 'one_off', period: undefined, billingMonth: '2026-11'}));
    expect(db.invoiceQueries).toEqual([]);
    const created = db.writes.find((w) => w.ref.kind === 'invoice').data;
    expect(created).toMatchObject({kind: 'one_off', billing_month: '2026-11'});
  });

  test('a request that says no kind behaves as before', async () => {
    const db = buildDb({existing: [existing()]});
    admin.firestore.mockReturnValue(db);
    await createInvoice(monthlyRequest({kind: undefined}));
    expect(db.invoiceQueries).toEqual([]);
    const created = db.writes.find((w) => w.ref.kind === 'invoice').data;
    expect(created.kind).toBeUndefined();
    expect(created.billing_month).toBeUndefined();
  });
});
