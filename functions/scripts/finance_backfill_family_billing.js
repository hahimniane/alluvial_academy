#!/usr/bin/env node
/**
 * Proposes a `family_billing/{parentId}` document for every family that is
 * billed today, so the new monthly engine has a starting amount for each.
 *
 *   node scripts/finance_backfill_family_billing.js --key <service-account.json>
 *        dry run (default): reads production, prints the proposal table, writes nothing
 *   ... --apply            writes the proposals that need no review (never overwrites)
 *   ... --apply --include-review   also writes the flagged ones (decide each first)
 *   ... --csv out.csv      also saves the table to a local file
 *
 * Where the amount comes from, per parent:
 *   - an active recurring_billing_plans doc: its base_items per month (the
 *     plan's total_amount can already contain a discount line, so it is only
 *     the fallback);
 *   - otherwise the latest monthly invoice of the last 3 months, before
 *     discounts.
 *
 * Flagged for review (not written by --apply on its own): more than one active
 * plan, two plans for the same student, a plan that disagrees with the latest
 * invoice, no active plan, no students, or no parent account.
 */
const math = require('../utils/finance_billing_math');

const str = (v) => (v == null ? '' : String(v)).trim();
const list = (v) => (Array.isArray(v) ? v : []);
const toDate = (v) => {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') return v.toDate();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};
const nameOf = (u) => {
  const d = u || {};
  return (
    [d.first_name, d.last_name].map(str).filter(Boolean).join(' ') ||
    str(d.display_name) ||
    str(d.displayName) ||
    ''
  );
};
const emailOf = (u) => str((u || {})['e-mail'] || (u || {}).email);
const lineTotal = (item) => {
  const total = Number(item && item.total);
  if (Number.isFinite(total) && total !== 0) return total;
  const q = Number(item && item.quantity) || 1;
  return q * (Number(item && (item.unit_price ?? item.unitPrice)) || 0);
};

/** What a plan bills per month, from its per-month base items. */
const planMonthly = (plan) => {
  const items = list(plan.base_items).filter((i) => i && !i.is_discount);
  if (items.length) {
    const cents = items.reduce((s, i) => s + math.toCents(lineTotal(i)), 0);
    const perStudent = {};
    let attributed = true;
    for (const item of items) {
      const id = str(item.student_id);
      if (!id) {
        attributed = false;
        break;
      }
      perStudent[id] = math.fromCents((perStudent[id] ? math.toCents(perStudent[id]) : 0) + math.toCents(lineTotal(item)));
    }
    return {amount: math.fromCents(cents), perStudent: attributed ? perStudent : null, from: 'base_items'};
  }
  const months = Math.max(1, Math.round(Number(plan.billing_months) || 1));
  return {amount: math.round2((Number(plan.total_amount) || 0) / months), perStudent: null, from: 'total_amount'};
};

const planStudents = (plan) => {
  const ids = list(plan.base_items).map((i) => str(i && i.student_id)).filter(Boolean);
  if (ids.length) return [...new Set(ids)];
  return str(plan.student_id) ? [str(plan.student_id)] : [];
};

/** What an invoice billed per month before discounts. */
const invoiceMonthly = (invoice) => {
  const items = list(invoice.items);
  const gross = items.filter((i) => i && !i.is_discount).reduce((s, i) => s + math.toCents(lineTotal(i)), 0);
  const cents = items.length ? gross : math.toCents(invoice.total_amount);
  const months = Math.max(1, Math.round(Number(invoice.billing_months) || 1));
  return math.fromCents(cents / months);
};

const intersects = (a, b) => a.some((x) => b.includes(x));

const readUsers = async (db, ids) => {
  const unique = [...new Set(ids.map(str).filter(Boolean))];
  const out = new Map();
  for (let i = 0; i < unique.length; i += 100) {
    const part = unique.slice(i, i + 100);
    const snaps = await db.getAll(...part.map((id) => db.collection('users').doc(id)));
    snaps.forEach((s, j) => {
      if (s.exists) out.set(part[j], s.data() || {});
    });
  }
  return out;
};

/**
 * Read-only. One row per parent with an active recurring plan or a tuition
 * invoice in the last 3 months. `proposals` maps parentId -> a
 * family_billing-shaped document for the preview.
 */
const proposeFamilyBilling = async ({db, now = new Date()}) => {
  const since = new Date(now.getTime() - 92 * 24 * 60 * 60 * 1000);
  const Timestamp = require('firebase-admin').firestore.Timestamp;
  const [planSnap, invoiceSnap, existingSnap] = await Promise.all([
    db.collection('recurring_billing_plans').where('status', '==', 'active').get(),
    db.collection('invoices').where('issued_date', '>=', Timestamp.fromDate(since)).get(),
    db.collection('family_billing').get(),
  ]);
  const alreadyHave = new Set(existingSnap.docs.map((d) => d.id));

  const plansByParent = new Map();
  for (const doc of planSnap.docs) {
    const plan = {id: doc.id, ...doc.data()};
    const pid = str(plan.parent_id);
    if (!pid) continue;
    if (!plansByParent.has(pid)) plansByParent.set(pid, []);
    plansByParent.get(pid).push(plan);
  }

  const latestByParent = new Map();
  for (const doc of invoiceSnap.docs) {
    const inv = {id: doc.id, ...doc.data()};
    const pid = str(inv.parent_id);
    const kind = str(inv.kind);
    if (!pid || str(inv.status).toLowerCase() === 'cancelled') continue;
    if (kind === 'one_off' || kind === 'first_month') continue;
    // Only tuition: generated from a plan, or carrying a billing period.
    if (!inv.recurring_plan_id && !inv.period_start) continue;
    const when = (toDate(inv.issued_date) || new Date(0)).getTime();
    const prev = latestByParent.get(pid);
    if (!prev || when > prev.when) latestByParent.set(pid, {inv, when});
  }

  const parentIds = [...new Set([...plansByParent.keys(), ...latestByParent.keys()])];
  const studentIds = new Set();
  for (const plans of plansByParent.values()) plans.forEach((p) => planStudents(p).forEach((s) => studentIds.add(s)));
  for (const {inv} of latestByParent.values()) {
    list(inv.student_ids).forEach((s) => studentIds.add(str(s)));
    if (str(inv.student_id)) studentIds.add(str(inv.student_id));
  }
  const users = await readUsers(db, [...parentIds, ...studentIds]);

  const rows = [];
  for (const parentId of parentIds) {
    const plans = plansByParent.get(parentId) || [];
    const latest = latestByParent.get(parentId);
    const flags = [];
    let proposed = 0;
    let source = '';
    let students = [];
    let studentAmounts = null;

    if (plans.length) {
      const computed = plans.map((p) => ({plan: p, ...planMonthly(p), students: planStudents(p)}));
      source = plans.length === 1 ? 'plan' : 'plans';
      const sets = computed.map((c) => c.students);
      const overlap = sets.some((a, i) => sets.some((b, j) => j > i && (a.length === 0 || b.length === 0 || intersects(a, b))));
      students = [...new Set(sets.flat())];

      if (plans.length > 1) {
        flags.push(`MULTIPLE_ACTIVE_PLANS(${plans.length}: ${computed.map((c) => `${c.plan.id}=${c.amount}`).join(', ')})`);
        if (overlap) {
          flags.push('PLANS_SHARE_A_STUDENT (likely duplicates; largest proposed)');
          proposed = Math.max(...computed.map((c) => c.amount));
        } else {
          flags.push('PLANS_FOR_DIFFERENT_STUDENTS (summed)');
          proposed = math.fromCents(computed.reduce((s, c) => s + math.toCents(c.amount), 0));
        }
      } else {
        proposed = computed[0].amount;
        if (computed[0].perStudent && Object.keys(computed[0].perStudent).length > 1) studentAmounts = computed[0].perStudent;
      }
      if (computed.some((c) => c.from === 'total_amount')) flags.push('AMOUNT_FROM_PLAN_TOTAL (no base items)');
      const multi = plans.filter((p) => Number(p.billing_months) > 1);
      if (multi.length) flags.push(`MULTI_MONTH_PLAN (${multi.map((p) => p.billing_months).join('/')} months; amount per month)`);

      if (latest) {
        const invoiceAmount = invoiceMonthly(latest.inv);
        if (Math.abs(invoiceAmount - proposed) > 0.01 && plans.length === 1) {
          flags.push(`PLAN_DIFFERS_FROM_LATEST_INVOICE (plan ${proposed} vs invoice ${invoiceAmount})`);
        }
      }
    } else if (latest) {
      source = 'invoice';
      proposed = invoiceMonthly(latest.inv);
      students = list(latest.inv.student_ids).map(str).filter(Boolean);
      if (!students.length && str(latest.inv.student_id)) students = [str(latest.inv.student_id)];
      flags.push('NO_ACTIVE_PLAN (amount from latest invoice)');
    }

    if (!students.length) flags.push('NO_STUDENTS');
    if (!users.has(parentId)) flags.push('NO_PARENT_ACCOUNT');
    if (!(proposed > 0)) flags.push('NO_AMOUNT');
    if (alreadyHave.has(parentId)) flags.push('FAMILY_BILLING_ALREADY_EXISTS (not touched)');

    const review = flags.some((f) => /^(MULTIPLE_ACTIVE_PLANS|PLAN_DIFFERS|NO_ACTIVE_PLAN|NO_STUDENTS|NO_PARENT_ACCOUNT|NO_AMOUNT|AMOUNT_FROM_PLAN_TOTAL)/.test(f));
    rows.push({
      parent_id: parentId,
      parent_name: nameOf(users.get(parentId)) || parentId,
      parent_email: emailOf(users.get(parentId)),
      students: students.map((id) => nameOf(users.get(id)) || id),
      student_ids: students,
      proposed_monthly: math.round2(proposed),
      student_amounts: studentAmounts,
      source,
      plan_ids: plans.map((p) => p.id),
      latest_invoice_id: latest ? latest.inv.id : null,
      latest_invoice_amount: latest ? invoiceMonthly(latest.inv) : null,
      flags,
      review,
      already_exists: alreadyHave.has(parentId),
    });
  }
  rows.sort((a, b) => a.parent_name.localeCompare(b.parent_name));

  // family_billing-shaped documents for families that have none yet.
  const proposals = {};
  for (const r of rows) {
    if (r.already_exists || !(r.proposed_monthly > 0) || !r.student_ids.length) continue;
    proposals[r.parent_id] = {
      monthly_amount: r.proposed_monthly,
      student_ids: r.student_ids,
      ...(r.student_amounts ? {student_amounts: r.student_amounts} : {}),
      history: [],
      active: true,
    };
  }
  return {rows, proposals};
};

const pad = (v, n) => String(v).padEnd(n).slice(0, Math.max(n, String(v).length));

const formatTable = (rows) => {
  const header = ['parent', 'email', 'students', 'monthly', 'source', 'review', 'flags'];
  const lines = rows.map((r) => [
    r.parent_name,
    r.parent_email,
    r.students.join(' + '),
    r.proposed_monthly.toFixed(2),
    r.source,
    r.review ? 'REVIEW' : 'ok',
    r.flags.join('; '),
  ]);
  const widths = header.map((h, i) => Math.min(48, Math.max(h.length, ...lines.map((l) => String(l[i]).length))));
  const fmt = (cols) => cols.map((c, i) => pad(c, widths[i])).join('  ');
  return [fmt(header), fmt(widths.map((w) => '-'.repeat(w))), ...lines.map(fmt)].join('\n');
};

const csvCell = (v) => {
  const s = String(v ?? '');
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

const toCsv = (rows) =>
  [
    ['parent_id', 'parent', 'email', 'students', 'proposed_monthly', 'source', 'review', 'flags'],
    ...rows.map((r) => [
      r.parent_id,
      r.parent_name,
      r.parent_email,
      r.students.join(' + '),
      r.proposed_monthly.toFixed(2),
      r.source,
      r.review ? 'REVIEW' : 'ok',
      r.flags.join('; '),
    ]),
  ]
    .map((row) => row.map(csvCell).join(','))
    .join('\n') + '\n';

const parseArgs = (argv) => {
  const out = {apply: false, includeReview: false, key: process.env.GOOGLE_APPLICATION_CREDENTIALS || '', csv: ''};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--apply') out.apply = true;
    else if (arg === '--include-review') out.includeReview = true;
    else if (arg === '--dry-run') out.apply = false;
    else if (arg === '--key') out.key = argv[++i];
    else if (arg === '--csv') out.csv = argv[++i];
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return out;
};

const main = async () => {
  const args = parseArgs(process.argv.slice(2));
  if (!args.key) throw new Error('Pass --key <service-account.json> (or set GOOGLE_APPLICATION_CREDENTIALS).');

  const admin = require('firebase-admin');
  admin.initializeApp({credential: admin.credential.cert(require(require('path').resolve(args.key)))});
  const db = admin.firestore();

  const {rows} = await proposeFamilyBilling({db, now: new Date()});
  console.log(formatTable(rows));
  const review = rows.filter((r) => r.review);
  console.log(`\n${rows.length} families, ${review.length} need review.`);

  if (args.csv) {
    require('fs').writeFileSync(args.csv, toCsv(rows));
    console.log(`Saved ${args.csv}`);
  }

  if (!args.apply) {
    console.log('\nDRY RUN: nothing was written. Re-run with --apply to write the rows that need no review.');
    return;
  }

  let written = 0;
  let skipped = 0;
  for (const row of rows) {
    if (row.review && !args.includeReview) continue;
    if (!(row.proposed_monthly > 0)) continue;
    try {
      await db.collection('family_billing').doc(row.parent_id).create({
        monthly_amount: row.proposed_monthly,
        student_ids: row.student_ids,
        ...(row.student_amounts ? {student_amounts: row.student_amounts} : {}),
        set_on_invoice_id: row.latest_invoice_id || null,
        set_at: admin.firestore.FieldValue.serverTimestamp(),
        history: [],
        active: true,
        source: 'backfill',
      });
      written += 1;
    } catch (error) {
      if (error && (error.code === 6 || /already exists/i.test(error.message || ''))) {
        skipped += 1;
        console.log(`Skipped ${row.parent_id}: family_billing already exists.`);
      } else {
        throw error;
      }
    }
  }
  console.log(`\nWrote ${written} family_billing documents (${skipped} already existed).`);
};

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = {parseArgs, proposeFamilyBilling, formatTable, toCsv, planMonthly, invoiceMonthly};
