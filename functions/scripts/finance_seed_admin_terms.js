#!/usr/bin/env node
/**
 * Backfill admin_pay_terms for every current administrator (users with
 * user_type admin or super_admin) that does not have a document yet.
 *
 *   node scripts/finance_seed_admin_terms.js            # dry run (default)
 *   node scripts/finance_seed_admin_terms.js --apply    # write
 *
 * Optional: --from-month=2026-01   first month the placeholder terms apply
 *           --key=/path/to/service-account.json
 *           (otherwise GOOGLE_APPLICATION_CREDENTIALS / default credentials)
 *
 * Each new document gets one term: fixed 0, pct 0, note 'Set up — enter real
 * pay'. Existing documents are never touched. Administrators whose account is
 * already deactivated also get an automatic pause from the same month (the
 * deactivation trigger only reacts to future changes). Tutorial/demo accounts
 * are skipped.
 */

const admin = require('firebase-admin');

const ADMIN_TYPES = ['admin', 'super_admin'];
const PLACEHOLDER_NOTE = 'Set up — enter real pay';

const arg = (name) => {
  const hit = process.argv.find((a) => a === `--${name}` || a.startsWith(`--${name}=`));
  if (!hit) return null;
  return hit.includes('=') ? hit.slice(hit.indexOf('=') + 1) : true;
};

const nyMonth = () => {
  const parts = new Intl.DateTimeFormat('en-CA', {timeZone: 'America/New_York', year: 'numeric', month: '2-digit'}).formatToParts(new Date());
  return `${parts.find((p) => p.type === 'year').value}-${parts.find((p) => p.type === 'month').value}`;
};

const displayName = (u) =>
  `${u.first_name || ''} ${u.last_name || ''}`.trim() || u.name || u['e-mail'] || u.email || '';

async function main() {
  const apply = arg('apply') === true;
  const fromMonth = typeof arg('from-month') === 'string' ? arg('from-month') : nyMonth();
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(fromMonth)) throw new Error('--from-month must look like 2026-10');

  const keyPath = typeof arg('key') === 'string' ? arg('key') : null;
  admin.initializeApp(keyPath ? {credential: admin.credential.cert(require(require('path').resolve(keyPath)))} : {});
  const db = admin.firestore();

  const users = [];
  for (const type of ADMIN_TYPES) {
    const snap = await db.collection('users').where('user_type', '==', type).get();
    snap.docs.forEach((d) => users.push({uid: d.id, ...d.data()}));
  }

  const plan = [];
  const skipped = [];
  for (const u of users) {
    if (u.tutorialMarker || u.tutorialSeed || u.uid.startsWith('codex_')) {
      skipped.push(u.uid);
      continue;
    }
    const existing = await db.collection('admin_pay_terms').doc(u.uid).get();
    plan.push({uid: u.uid, name: displayName(u), role_title: u.title || 'Administrator', active: u.is_active !== false, exists: existing.exists});
  }

  console.log(`${apply ? 'APPLY' : 'DRY RUN'}: ${plan.length} administrators, terms start ${fromMonth}`);
  if (skipped.length) console.log(`Skipped demo accounts: ${skipped.join(', ')}`);
  console.log('');
  for (const p of plan) {
    console.log(
      `${p.exists ? 'skip (has terms)' : apply ? 'write           ' : 'would write     '}  ${p.uid}  ${p.name}  [${p.role_title}]${p.active ? '' : '  (deactivated)'}`
    );
    if (!p.exists) {
      console.log(
        `    admin_pay_terms/${p.uid} = {name, role_title, terms:[{from_month:'${fromMonth}', fixed:0, pct:0, note:'${PLACEHOLDER_NOTE}'}], pauses:[${
          p.active ? '' : `{from_month:'${fromMonth}', until_month:null, reason:'Account deactivated', auto:true}`
        }]}`
      );
    }
  }

  const missing = plan.filter((p) => !p.exists);
  if (!apply) {
    console.log(`\n${missing.length} document(s) would be written. Re-run with --apply to write them.`);
    return;
  }
  for (const p of missing) {
    await db
      .collection('admin_pay_terms')
      .doc(p.uid)
      .create({
        name: p.name,
        role_title: p.role_title,
        terms: [
          {
            from_month: fromMonth,
            fixed: 0,
            pct: 0,
            note: PLACEHOLDER_NOTE,
            set_at: admin.firestore.Timestamp.now(),
            set_by: 'seed-script',
            set_by_name: 'Setup',
          },
        ],
        pauses: p.active
          ? []
          : [
              {
                from_month: fromMonth,
                until_month: null,
                reason: 'Account deactivated',
                auto: true,
                at: admin.firestore.Timestamp.now(),
                by: null,
                by_name: 'Setup',
              },
            ],
        updated_at: admin.firestore.Timestamp.now(),
      });
  }
  console.log(`\nWrote ${missing.length} document(s).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
