/**
 * The old recurring_billing_plans generator and the new monthly engine must
 * never both bill a family. While auto billing is OFF the old generator is
 * untouched; once it is ON the old generator steps aside for any family that
 * has family_billing.
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
const {createFakeFirestore, installOnAdmin} = require('./helpers/fake_firestore');

const plan = (parentId, studentId, over = {}) => ({
  parent_id: parentId,
  student_id: studentId,
  status: 'active',
  currency: 'USD',
  next_period: '2026-11',
  billing_months: 1,
  due_day: 1,
  base_items: [{description: `Tuition - ${studentId}`, quantity: 1, unit_price: 80, total: 80, student_id: studentId}],
  created_by: 'admin_1',
  ...over,
});

const seed = (autoBilling) => ({
  ...(autoBilling === undefined ? {} : {finance_settings: {main: {auto_billing_enabled: autoBilling}}}),
  users: {parent_a: {first_name: 'A'}, parent_b: {first_name: 'B'}, kid_a: {}, kid_b: {}},
  invoice_counters: {2026: {next: 10}},
  recurring_billing_plans: {
    plan_a: plan('parent_a', 'kid_a'),
    plan_b: plan('parent_b', 'kid_b'),
  },
  family_billing: {parent_a: {monthly_amount: 80, student_ids: ['kid_a'], history: [], active: true}},
});

const run = async (data) => {
  const db = createFakeFirestore(data, {now: () => new Date('2026-11-01T00:00:00Z')});
  installOnAdmin(admin, db);
  const {_runRecurringInvoiceGeneration} = require('../handlers/payments');
  const result = await _runRecurringInvoiceGeneration({db, now: new Date('2026-11-01T00:00:00Z')});
  return {db, result};
};

describe('old recurring generator and family_billing', () => {
  test('auto billing ON: skips a family that has family_billing, bills the rest', async () => {
    const {db, result} = await run(seed(true));

    expect(db.store.invoices['recurring_plan_a_2026-11']).toBeUndefined();
    expect(db.store.invoices['recurring_plan_b_2026-11']).toMatchObject({parent_id: 'parent_b', total_amount: 80});
    expect(result.invoicesCreated).toBe(1);
    expect(result.results).toEqual(
      expect.arrayContaining([expect.objectContaining({planId: 'plan_a', skipped: true, reason: 'family_billing'})])
    );
  });

  test('auto billing ON: the skipped plan moves on so switching the engine off cannot back-bill', async () => {
    const {db} = await run(seed(true));
    expect(db.store.recurring_billing_plans.plan_a.next_period).toBe('2026-12');
    expect(db.store.recurring_billing_plans.plan_a.skipped_for_family_billing_at).toBeTruthy();
    // The plan that was billed moved on the normal way.
    expect(db.store.recurring_billing_plans.plan_b.next_period).toBe('2026-12');
  });

  test('auto billing ON: a multi-month plan steps by its own length', async () => {
    const data = seed(true);
    data.recurring_billing_plans.plan_a = plan('parent_a', 'kid_a', {billing_months: 3, next_period: '2026-10'});
    const {db} = await run(data);
    expect(db.store.recurring_billing_plans.plan_a.next_period).toBe('2027-01');
    expect(db.store.invoices && db.store.invoices['recurring_plan_a_2026-10']).toBeUndefined();
  });

  test('auto billing OFF: the old generator bills every plan exactly as before', async () => {
    const {db, result} = await run(seed(false));
    expect(db.store.invoices['recurring_plan_a_2026-11']).toMatchObject({parent_id: 'parent_a', total_amount: 80});
    expect(db.store.invoices['recurring_plan_b_2026-11']).toBeDefined();
    expect(result.invoicesCreated).toBe(2);
    expect(db.store.recurring_billing_plans.plan_a.skipped_for_family_billing_at).toBeUndefined();
  });

  test('no settings document at all behaves as OFF', async () => {
    const {db, result} = await run(seed(undefined));
    expect(result.invoicesCreated).toBe(2);
    expect(db.store.invoices['recurring_plan_a_2026-11']).toBeDefined();
  });

  test('auto billing ON: a family whose family_billing is switched off is still billed by the old generator', async () => {
    const data = seed(true);
    data.family_billing.parent_a.active = false;
    const {db, result} = await run(data);
    expect(result.invoicesCreated).toBe(2);
    expect(db.store.invoices['recurring_plan_a_2026-11']).toBeDefined();
  });

  test('auto billing ON: a family_billing amount of zero for the month is still billed by the old plan', async () => {
    const data = seed(true);
    data.family_billing.parent_a.monthly_amount = 0;
    const {db, result} = await run(data);
    expect(db.store.invoices['recurring_plan_a_2026-11']).toMatchObject({parent_id: 'parent_a', total_amount: 80});
    expect(result.invoicesCreated).toBe(2);
    // billed the normal way, not "stood aside"
    expect(db.store.recurring_billing_plans.plan_a.skipped_for_family_billing_at).toBeUndefined();
    expect(db.store.recurring_billing_plans.plan_a.next_period).toBe('2026-12');
  });

  test('auto billing ON: the amount that applies to THAT month decides (history)', async () => {
    const data = seed(true);
    // today 0, but the amount in force for 2026-11 (before the change) was 80
    data.family_billing.parent_a.monthly_amount = 0;
    data.family_billing.parent_a.history = [{from_month: '2026-12', old: 80, new: 0, reason: 'x'}];
    const {db} = await run(data);
    expect(db.store.invoices && db.store.invoices['recurring_plan_a_2026-11']).toBeUndefined();
    expect(db.store.recurring_billing_plans.plan_a.skipped_for_family_billing_at).toBeTruthy();
  });

  test('auto billing ON: a family_billing with no amount at all keeps its old plan billing and next_period untouched until billed', async () => {
    const data = seed(true);
    delete data.family_billing.parent_a.monthly_amount;
    const {db} = await run(data);
    expect(db.store.invoices['recurring_plan_a_2026-11']).toBeDefined();
  });

  describe('onInvoiceCreated', () => {
    const attempt = async (settings, kind) => {
      const { onInvoiceCreated } = require('../handlers/payments');
      const written = [];
      const db = createFakeFirestore({
        ...(settings ? {finance_settings: {main: settings}} : {}),
        users: {parent_a: {first_name: 'A', 'e-mail': 'a@example.com'}},
      });
      installOnAdmin(admin, db);
      admin.messaging = jest.fn();
      await onInvoiceCreated({
        params: {invoiceId: 'inv_1'},
        data: {
          data: () => ({...(kind ? {kind} : {}), parent_id: 'parent_a', invoice_number: 'INV-1', total_amount: 80, paid_amount: 0}),
          ref: {set: async (data, options) => written.push({data, options})},
        },
      });
      return written;
    };

    test('holds back parent notices for engine invoices while parent messages are off', async () => {
      for (const kind of ['monthly', 'first_month']) {
        const written = await attempt({parent_messages_enabled: false}, kind);
        expect(written).toHaveLength(1);
        expect(written[0].data.notification_status).toBe('suppressed');
      }
      const none = await attempt(null, 'monthly');
      expect(none[0].data.notification_status).toBe('suppressed');
    });

    test('notifies for engine invoices once parent messages are on', async () => {
      const written = await attempt({parent_messages_enabled: true}, 'monthly');
      expect(written).toHaveLength(1);
      expect(written[0].data.notification_status).toBe('sent');
    });

    test('invoices from the older flows are notified exactly as before', async () => {
      const written = await attempt({parent_messages_enabled: false}, undefined);
      expect(written[0].data.notification_status).toBe('sent');
    });
  });
});
