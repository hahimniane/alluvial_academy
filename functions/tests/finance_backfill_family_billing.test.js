/**
 * The backfill proposes a starting family_billing document per billed family,
 * flags the ones a person must look at, and writes nothing by itself.
 */
const admin = require('firebase-admin');
const {createFakeFirestore, installOnAdmin, FakeTimestamp} = require('./helpers/fake_firestore');
const {proposeFamilyBilling, formatTable, toCsv, parseArgs} = require('../scripts/finance_backfill_family_billing');

const NOW = new Date('2026-10-22T15:00:00Z');
const ts = (iso) => FakeTimestamp.fromDate(new Date(iso));

const item = (studentId, total, over = {}) => ({description: `Tuition - ${studentId}`, quantity: 1, unit_price: total, total, student_id: studentId, ...over});
const plan = (parentId, items, over = {}) => ({
  parent_id: parentId,
  student_id: items[0].student_id,
  status: 'active',
  billing_months: 1,
  base_items: items,
  total_amount: items.reduce((s, i) => s + i.total, 0),
  ...over,
});
const invoice = (parentId, items, over = {}) => ({
  parent_id: parentId,
  student_id: items[0].student_id,
  status: 'pending',
  recurring_plan_id: 'p',
  period_start: '2026-10',
  billing_months: 1,
  items,
  total_amount: items.reduce((s, i) => s + i.total, 0),
  issued_date: ts('2026-10-01T00:00:00Z'),
  ...over,
});

const seed = () => ({
  users: {
    p1: {first_name: 'Fatou', last_name: 'Diallo', 'e-mail': 'f@example.com'},
    p2: {first_name: 'Ousmane', last_name: 'Bah'},
    p3: {first_name: 'Mariama', last_name: 'Sow'},
    p4: {first_name: 'Ibrahima', last_name: 'Camara'},
    p5: {first_name: 'Aissatou', last_name: 'Barry'},
    s1: {first_name: 'Amina', last_name: 'Diallo'},
    s2: {first_name: 'Omar', last_name: 'Bah'},
    s3: {first_name: 'Kadi', last_name: 'Sow'},
    s4: {first_name: 'Sekou', last_name: 'Sow'},
    s5: {first_name: 'Binta', last_name: 'Camara'},
    s6: {first_name: 'Alpha', last_name: 'Barry'},
  },
  recurring_billing_plans: {
    // p1: one clean plan, invoice agrees (invoice carries a discount line).
    plan_1: plan('p1', [item('s1', 80)]),
    // p2: two plans for the SAME student (a duplicate).
    plan_2a: plan('p2', [item('s2', 70)]),
    plan_2b: plan('p2', [item('s2', 70)]),
    // p3: two plans for different children.
    plan_3a: plan('p3', [item('s3', 60)]),
    plan_3b: plan('p3', [item('s4', 50)]),
    // p4: a plan that disagrees with its latest invoice.
    plan_4: plan('p4', [item('s5', 90)]),
    // inactive plan: ignored
    plan_off: plan('p5', [item('s6', 40)], {status: 'paused'}),
  },
  invoices: {
    i1: invoice('p1', [item('s1', 80), {description: 'Discount', total: -8, is_discount: true, student_id: 's1'}], {total_amount: 72}),
    i4: invoice('p4', [item('s5', 100)]),
    i5: invoice('p5', [item('s6', 40)], {recurring_plan_id: null}),
    old: invoice('p1', [item('s1', 50)], {issued_date: ts('2025-01-01T00:00:00Z')}),
    oneoff: invoice('p2', [item('s2', 15)], {kind: 'one_off', recurring_plan_id: null, period_start: null}),
    cancelled: invoice('p3', [item('s3', 999)], {status: 'cancelled'}),
  },
  family_billing: {},
});

const run = async (data = seed()) => {
  const db = createFakeFirestore(data);
  installOnAdmin(admin, db);
  const out = await proposeFamilyBilling({db, now: NOW});
  return {db, ...out, byId: Object.fromEntries(out.rows.map((r) => [r.parent_id, r]))};
};

describe('finance_backfill_family_billing', () => {
  test('a clean single plan proposes its per-month amount, before discounts', async () => {
    const {byId} = await run();
    expect(byId.p1).toMatchObject({proposed_monthly: 80, source: 'plan', review: false, parent_name: 'Fatou Diallo', parent_email: 'f@example.com'});
    expect(byId.p1.students).toEqual(['Amina Diallo']);
    expect(byId.p1.student_ids).toEqual(['s1']);
    expect(byId.p1.latest_invoice_id).toBe('i1');
    expect(byId.p1.flags).toEqual([]);
  });

  test('two plans for the same student are flagged as likely duplicates, not added together', async () => {
    const {byId} = await run();
    expect(byId.p2.review).toBe(true);
    expect(byId.p2.proposed_monthly).toBe(70);
    expect(byId.p2.flags.join(' ')).toMatch(/MULTIPLE_ACTIVE_PLANS\(2/);
    expect(byId.p2.flags.join(' ')).toMatch(/PLANS_SHARE_A_STUDENT/);
    expect(byId.p2.student_ids).toEqual(['s2']);
  });

  test('plans for different children are summed but still flagged', async () => {
    const {byId} = await run();
    expect(byId.p3).toMatchObject({proposed_monthly: 110, review: true});
    expect(byId.p3.flags.join(' ')).toMatch(/PLANS_FOR_DIFFERENT_STUDENTS/);
    expect(byId.p3.student_ids.sort()).toEqual(['s3', 's4']);
    // A cancelled invoice never counts as the latest.
    expect(byId.p3.latest_invoice_id).toBeNull();
  });

  test('a plan that differs from the latest invoice is flagged', async () => {
    const {byId} = await run();
    expect(byId.p4.proposed_monthly).toBe(90);
    expect(byId.p4.review).toBe(true);
    expect(byId.p4.flags.join(' ')).toMatch(/PLAN_DIFFERS_FROM_LATEST_INVOICE \(plan 90 vs invoice 100\)/);
  });

  test('a family with invoices but no active plan takes the invoice amount and is flagged', async () => {
    const {byId} = await run();
    expect(byId.p5).toMatchObject({proposed_monthly: 40, source: 'invoice', review: true});
    expect(byId.p5.flags.join(' ')).toMatch(/NO_ACTIVE_PLAN/);
  });

  test('old invoices and one-off charges do not create or change a proposal', async () => {
    const data = seed();
    data.recurring_billing_plans = {};
    data.invoices = {
      old: data.invoices.old,
      oneoff: data.invoices.oneoff,
    };
    const {rows} = await run(data);
    expect(rows).toEqual([]);
  });

  test('a multi-month plan is proposed per month', async () => {
    const data = seed();
    data.recurring_billing_plans = {q: plan('p1', [item('s1', 80)], {billing_months: 3})};
    data.invoices = {};
    const {byId} = await run(data);
    expect(byId.p1.proposed_monthly).toBe(80);
    expect(byId.p1.flags.join(' ')).toMatch(/MULTI_MONTH_PLAN/);
  });

  test('a plan with no base items falls back to total / months and is flagged', async () => {
    const data = seed();
    data.recurring_billing_plans = {q: {parent_id: 'p1', student_id: 's1', status: 'active', billing_months: 2, total_amount: 150}};
    data.invoices = {};
    const {byId} = await run(data);
    expect(byId.p1.proposed_monthly).toBe(75);
    expect(byId.p1.review).toBe(true);
  });

  test('a family with two children on one plan keeps each child amount', async () => {
    const data = seed();
    data.recurring_billing_plans = {q: plan('p1', [item('s1', 80), item('s2', 60)])};
    data.invoices = {};
    const {byId, proposals} = await run(data);
    expect(byId.p1.proposed_monthly).toBe(140);
    expect(byId.p1.student_amounts).toEqual({s1: 80, s2: 60});
    expect(proposals.p1).toMatchObject({monthly_amount: 140, student_ids: ['s1', 's2'], student_amounts: {s1: 80, s2: 60}, active: true});
  });

  test('families that already have family_billing get no proposal', async () => {
    const data = seed();
    data.family_billing = {p1: {monthly_amount: 80, student_ids: ['s1']}};
    const {byId, proposals} = await run(data);
    expect(byId.p1.already_exists).toBe(true);
    expect(proposals.p1).toBeUndefined();
    expect(proposals.p4).toBeDefined();
  });

  test('is read-only', async () => {
    const {db} = await run();
    expect(db.writes).toEqual([]);
  });

  test('prints a table and CSV', async () => {
    const {rows} = await run();
    const table = formatTable(rows);
    expect(table).toContain('Fatou Diallo');
    expect(table).toContain('REVIEW');
    const csv = toCsv(rows);
    expect(csv.split('\n')[0]).toBe('parent_id,parent,email,students,proposed_monthly,source,review,flags');
    expect(csv).toContain('p1,Fatou Diallo,f@example.com,Amina Diallo,80.00,plan,ok,');
  });

  test('defaults to a dry run; writing needs --apply', () => {
    expect(parseArgs([]).apply).toBe(false);
    expect(parseArgs(['--dry-run']).apply).toBe(false);
    expect(parseArgs(['--apply']).apply).toBe(true);
    expect(parseArgs(['--apply', '--include-review']).includeReview).toBe(true);
    expect(() => parseArgs(['--nope'])).toThrow();
  });
});
