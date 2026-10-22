#!/usr/bin/env node
'use strict';

/**
 * Seeds finance_recurring_costs with what Alluwal pays every month today.
 *
 *   node scripts/finance_seed_recurring.js            # dry run (default): prints the plan
 *   node scripts/finance_seed_recurring.js --apply    # writes the costs
 *   --skip="name one,name two"                        # leave these out
 *   --project=alluwal-academy                         # default project
 *
 * Where the costs come from (read-only until --apply):
 *   1. finance_expenses history: a vendor counts as recurring when it was paid
 *      in two or more different months, or a row is marked "Recurring
 *      subscriptions" or says "recurring" in its notes.
 *   2. Services Alluwal is known to pay: Zoom, Hostinger, Firebase / Google
 *      Cloud, Google Workspace. They are added at the amount of the latest
 *      matching expense; with no matching expense they are NOT added and are
 *      printed as "needs amount" so a person types the real bill in the app.
 *
 * A cost starts the month after the latest matching expense (so a month that
 * already has the one-off row is not counted twice), or this month when there
 * is none. No confirmations are written: each month's real amount is confirmed
 * on the Expenses page. Running it twice adds nothing (same-named running costs
 * are skipped).
 */

const admin = require('firebase-admin');
const math = require('../utils/finance_expense_math');

const KNOWN_SERVICES = [
  {name: 'Zoom', match: /zoom/i, category: 'software'},
  {name: 'Hostinger', match: /hostinger/i, category: 'software'},
  {name: 'Firebase / Google Cloud', match: /firebase|google\s*cloud|gcp/i, category: 'software'},
  {name: 'Google Workspace', match: /google\s*workspace|g\s*suite|gsuite/i, category: 'software'},
];

const MIN_NAME_LENGTH = 4;

const rowName = (row) => String((row && (row.name || row.vendor)) || '').replace(/\s+/g, ' ').trim();
const nameKey = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();

const dateOf = (row) => {
  const raw = row && row.expense_date;
  if (!raw) return null;
  const date = typeof raw.toDate === 'function' ? raw.toDate() : new Date(raw);
  return Number.isNaN(date.getTime()) ? null : date;
};

const looksRecurring = (row) =>
  row.subcategory === 'recurring_subscriptions' || /recurring/i.test(String(row.notes || ''));

/**
 * Builds the plan from the existing expense rows. Pure: no database access.
 *
 * @param {object[]} expenses  finance_expenses rows (deleted ones are ignored)
 * @param {object[]} costs     existing finance_recurring_costs rows
 * @param {string}   thisMonth yyyy-MM
 * @param {string[]} skip      names (any case) to leave out
 * @returns {{add: object[], needsAmount: string[], skipped: {name: string, why: string}[]}}
 */
const planSeed = (expenses, costs, thisMonth, skip = []) => {
  const skipKeys = new Set(skip.map((s) => nameKey(s)));
  const running = new Set(
    (costs || [])
      .filter((c) => !math.isMonth(c.end_month) || c.end_month >= thisMonth)
      .map((c) => nameKey(rowName(c)))
  );

  // Latest row per vendor, with the months it was paid in.
  const vendors = new Map();
  for (const row of expenses || []) {
    if (!row || row.deleted === true) continue;
    const name = rowName(row);
    const date = dateOf(row);
    if (!name || !date) continue;
    const key = nameKey(name);
    const entry = vendors.get(key) || {name, rows: [], months: new Set()};
    entry.rows.push({row, date});
    entry.months.add(math.monthOfDate(date));
    vendors.set(key, entry);
  }
  const latestOf = (entry) => entry.rows.reduce((a, b) => (b.date > a.date ? b : a));

  const add = [];
  const needsAmount = [];
  const skipped = [];
  const used = new Set();

  const push = (name, category, entry, why) => {
    const key = nameKey(name);
    if (skipKeys.has(key)) return skipped.push({name, why: 'left out with --skip'});
    if (running.has(key)) return skipped.push({name, why: 'already a running recurring cost'});
    const latest = latestOf(entry);
    const amount = math.parseAmount(latest.row.amount);
    if (amount === null) return needsAmount.push(name);
    const lastMonth = math.monthOfDate(latest.date);
    add.push({
      name,
      category,
      amount,
      day_of_month: Math.min(28, Number(math.dateStringOf(latest.date).slice(8, 10)) || 1),
      start_month: math.addMonths(lastMonth, 1),
      end_month: null,
      why,
      source_expense_month: lastMonth,
    });
  };

  for (const service of KNOWN_SERVICES) {
    const matches = [...vendors.entries()].filter(([, entry]) => service.match.test(entry.name));
    if (matches.length === 0) {
      const key = nameKey(service.name);
      if (skipKeys.has(key)) skipped.push({name: service.name, why: 'left out with --skip'});
      else if (running.has(key)) skipped.push({name: service.name, why: 'already a running recurring cost'});
      else needsAmount.push(service.name);
      continue;
    }
    // Several rows for one service: the one with the latest date wins.
    const [bestKey, best] = matches.reduce((a, b) => (latestOf(b[1]).date > latestOf(a[1]).date ? b : a));
    matches.forEach(([key]) => used.add(key));
    push(service.name, service.category, best, `known service; latest expense "${best.name}"`);
    used.add(bestKey);
  }

  for (const [key, entry] of vendors) {
    if (used.has(key)) continue;
    const repeated = entry.months.size >= 2;
    const flagged = entry.rows.some(({row}) => looksRecurring(row));
    if (!repeated && !flagged) continue;
    if (entry.name.replace(/[^a-z]/gi, '').length < MIN_NAME_LENGTH) {
      skipped.push({name: entry.name, why: 'name is too short to be a real vendor; check it'});
      continue;
    }
    const flaggedAsSubscription = entry.rows.some(({row}) => row.subcategory === 'recurring_subscriptions');
    const category = flaggedAsSubscription
      ? 'software'
      : math.normalizeLegacyCategory(latestOf(entry).row.category) || 'other';
    push(
      entry.name,
      math.ENTERED_CATEGORIES.includes(category) ? category : 'other',
      entry,
      repeated ? `paid in ${entry.months.size} different months` : 'marked as a recurring subscription'
    );
  }

  return {add, needsAmount, skipped};
};

const flag = (name) => {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : null;
};

const main = async () => {
  const apply = process.argv.includes('--apply');
  const skip = (flag('skip') || '').split(',').map((s) => s.trim()).filter(Boolean);
  admin.initializeApp({projectId: flag('project') || 'alluwal-academy'});
  const db = admin.firestore();

  console.log(`Mode: ${apply ? 'APPLY (writing finance_recurring_costs)' : 'DRY RUN (use --apply to write)'}\n`);

  const [expenseSnap, costSnap] = await Promise.all([
    db.collection('finance_expenses').get(),
    db.collection('finance_recurring_costs').get(),
  ]);
  const thisMonth = math.monthOfDate(new Date());
  const plan = planSeed(
    expenseSnap.docs.map((d) => ({id: d.id, ...d.data()})),
    costSnap.docs.map((d) => ({id: d.id, ...d.data()})),
    thisMonth,
    skip
  );

  console.log(`Read ${expenseSnap.size} expenses and ${costSnap.size} existing recurring costs.\n`);
  console.log('Will add:');
  if (plan.add.length === 0) console.log('  (nothing)');
  for (const c of plan.add) {
    console.log(
      `  ${c.name} | ${c.category} | $${c.amount.toFixed(2)} | day ${c.day_of_month} | from ${c.start_month} | ${c.why}`
    );
  }
  console.log('\nNeeds amount (no matching expense found; add them in the app with the real bill):');
  if (plan.needsAmount.length === 0) console.log('  (none)');
  for (const name of plan.needsAmount) console.log(`  ${name}`);
  console.log('\nSkipped:');
  if (plan.skipped.length === 0) console.log('  (none)');
  for (const s of plan.skipped) console.log(`  ${s.name}: ${s.why}`);

  if (!apply) {
    console.log('\nDry run only. Nothing was written.');
    return;
  }
  const batch = db.batch();
  for (const c of plan.add) {
    const {why, source_expense_month: _source, ...fields} = c;
    batch.set(db.collection('finance_recurring_costs').doc(), {
      ...fields,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_by: 'seed_script',
      created_by_name: 'Seed script',
      seeded_from: why,
    });
  }
  await batch.commit();
  console.log(`\nWrote ${plan.add.length} recurring costs.`);
};

module.exports = {planSeed, KNOWN_SERVICES};

if (require.main === module) {
  main().then(
    () => process.exit(0),
    (error) => {
      console.error(error);
      process.exit(1);
    }
  );
}
