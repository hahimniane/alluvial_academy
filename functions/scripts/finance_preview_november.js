#!/usr/bin/env node
/**
 * READ-ONLY preview of what the new monthly engine would bill for a month
 * (default 2026-11) against production, written to a CSV.
 *
 *   node scripts/finance_preview_november.js --key <service-account.json>
 *        [--month 2026-11] [--out ~/alluwal-scratch/november-billing-preview.csv]
 *
 * It runs the same logic as the previewMonthlyBilling callable. Production has
 * no family_billing yet, so families without one use the amount the backfill
 * would propose (see finance_backfill_family_billing.js). Every write method
 * of the Firestore client is disabled before anything runs.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const math = require('../utils/finance_billing_math');
const {proposeFamilyBilling} = require('./finance_backfill_family_billing');

const parseArgs = (argv) => {
  const out = {
    key: process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
    month: '2026-11',
    out: path.join(os.homedir(), 'alluwal-scratch', 'november-billing-preview.csv'),
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--key') out.key = argv[++i];
    else if (arg === '--month') out.month = argv[++i];
    else if (arg === '--out') out.out = path.resolve(argv[++i].replace(/^~(?=$|\/)/, os.homedir()));
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!math.isMonth(out.month)) throw new Error('--month must look like 2026-11');
  return out;
};

/** Makes every Firestore write throw, so this script cannot change production. */
const makeReadOnly = () => {
  const fs2 = require('@google-cloud/firestore');
  const refuse = (name) => () => {
    throw new Error(`Read-only script: ${name} is disabled.`);
  };
  for (const method of ['set', 'update', 'delete', 'create']) {
    fs2.DocumentReference.prototype[method] = refuse(`DocumentReference.${method}`);
    fs2.WriteBatch.prototype[method] = refuse(`WriteBatch.${method}`);
    fs2.Transaction.prototype[method] = refuse(`Transaction.${method}`);
  }
  fs2.CollectionReference.prototype.add = refuse('CollectionReference.add');
  fs2.WriteBatch.prototype.commit = refuse('WriteBatch.commit');
  fs2.Firestore.prototype.runTransaction = refuse('Firestore.runTransaction');
  fs2.Firestore.prototype.bulkWriter = refuse('Firestore.bulkWriter');
};

const csvCell = (v) => {
  const s = String(v ?? '');
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

const buildCsv = ({rows, notesById}) => {
  const header = ['family', 'parent email', 'students', 'monthly amount', 'discount', 'credit', 'total', 'existing invoice', 'notes'];
  const body = rows.map((r) => [
    r.parent_name,
    r.parent_email,
    r.students.join(' + '),
    r.monthly_amount.toFixed(2),
    r.discount.toFixed(2),
    r.credit.toFixed(2),
    r.total.toFixed(2),
    r.existing_invoice_id || '',
    (notesById[r.parent_id] || []).join('; '),
  ]);
  return [header, ...body].map((row) => row.map(csvCell).join(',')).join('\n') + '\n';
};

const main = async () => {
  const args = parseArgs(process.argv.slice(2));
  if (!args.key) throw new Error('Pass --key <service-account.json> (or set GOOGLE_APPLICATION_CREDENTIALS).');

  makeReadOnly();
  const admin = require('firebase-admin');
  admin.initializeApp({credential: admin.credential.cert(require(path.resolve(args.key)))});
  const db = admin.firestore();

  // Required after the read-only patch and after admin is initialised.
  const {computeMonthlyPlan} = require('../handlers/finance_billing');

  const {rows: proposalRows, proposals} = await proposeFamilyBilling({db, now: new Date()});
  const plan = await computeMonthlyPlan({db, month: args.month, proposals});

  const notesById = {};
  for (const r of plan.rows) {
    const notes = [];
    if (r.proposed) notes.push('from backfill proposal (no family_billing yet)');
    const proposal = proposalRows.find((p) => p.parent_id === r.parent_id);
    if (proposal) notes.push(...proposal.flags);
    if (r.existing_invoice_id) notes.push('already invoiced: would be skipped');
    notesById[r.parent_id] = notes;
  }

  fs.mkdirSync(path.dirname(args.out), {recursive: true});
  fs.writeFileSync(args.out, buildCsv({rows: plan.rows, notesById}));

  const review = plan.rows.filter((r) => proposalRows.find((p) => p.parent_id === r.parent_id && p.review));
  console.log(`Month: ${args.month}`);
  console.log(`Families: ${plan.totals.families}`);
  console.log(`Would be created: ${plan.totals.to_create}`);
  console.log(`Monthly amounts: ${plan.totals.monthly_amount.toFixed(2)}`);
  console.log(`Discounts: ${plan.totals.discount.toFixed(2)}`);
  console.log(`Credits: ${plan.totals.credit.toFixed(2)}`);
  console.log(`Total to bill: ${plan.totals.total.toFixed(2)}`);
  console.log(`Already invoiced for the month: ${plan.totals.already_invoiced} (${plan.totals.already_invoiced_total.toFixed(2)})`);
  const reviewIds = new Set(review.map((r) => r.parent_id));
  const clean = plan.rows.filter((r) => !r.existing_invoice_id && r.monthly_amount > 0 && !reviewIds.has(r.parent_id));
  const cleanTotal = math.fromCents(clean.reduce((s, r) => s + math.toCents(r.total), 0));
  console.log(`  of which no review needed: ${clean.length} families, ${cleanTotal.toFixed(2)}`);
  console.log(`Flagged for review: ${review.length}`);
  for (const r of review) {
    const p = proposalRows.find((x) => x.parent_id === r.parent_id);
    console.log(`  - ${r.parent_name} (${r.parent_id}): ${r.monthly_amount.toFixed(2)}  [${p.flags.join('; ')}]`);
  }
  console.log(`CSV: ${args.out}`);
};

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = {parseArgs, buildCsv, makeReadOnly};
