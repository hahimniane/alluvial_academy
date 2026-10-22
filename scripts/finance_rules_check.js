// Usage (no deploy, no production): firebase emulators:exec --only firestore --project demo-fin-rules "node scripts/finance_rules_check.js"
// Run inside `firebase emulators:exec --only firestore`: checks the finance rules over REST.
const HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-fin-rules';
const base = `http://${HOST}/v1/projects/${PROJECT}/databases/(default)/documents`;
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (claims) => `${b64({alg: 'none', typ: 'JWT'})}.${b64({iss: 'x', aud: PROJECT, sub: claims.user_id, ...claims})}.`;
const ADMIN = jwt({user_id: 'adm1', isAdmin: true});
const PARENT = jwt({user_id: 'p1'});
const field = {fields: {month: {stringValue: '2026-10'}, amount: {integerValue: '5'}}};

const call = async (token, method, path, body) => {
  const res = await fetch(`${base}/${path}`, {
    method,
    headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'},
    body: body ? JSON.stringify(body) : undefined,
  });
  return res.status;
};

let failed = 0;
const expectStatus = async (label, want, got) => {
  const ok = want === 'allow' ? got === 200 : got === 403;
  if (!ok) failed += 1;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}  (${want}, got ${got})`);
};

(async () => {
  for (const [col, id] of [['finance_private', 'plaid'], ['known_phones', 'x'], ['finance_settings', 'main'], ['finance_expenses', 'e1'], ['finance_months', '2026-10'], ['some_other', 'doc']]) {
    const s = await call('owner', 'PATCH', `${col}/${id}`, field);
    if (s !== 200) throw new Error(`seed ${col}/${id} failed: ${s}`);
  }
  await expectStatus('admin reads finance_private (fallback must not reach it)', 'deny', await call(ADMIN, 'GET', 'finance_private/plaid'));
  await expectStatus('admin reads known_phones', 'deny', await call(ADMIN, 'GET', 'known_phones/x'));
  await expectStatus('admin lists known_phones', 'deny', await call(ADMIN, 'GET', 'known_phones'));
  await expectStatus('admin lists finance_private', 'deny', await call(ADMIN, 'GET', 'finance_private'));
  await expectStatus('admin reads finance_settings', 'allow', await call(ADMIN, 'GET', 'finance_settings/main'));
  await expectStatus('admin reads finance_expenses', 'allow', await call(ADMIN, 'GET', 'finance_expenses/e1'));
  await expectStatus('admin reads an ordinary collection (fallback unchanged)', 'allow', await call(ADMIN, 'GET', 'some_other/doc'));
  await expectStatus('admin writes an ordinary collection (fallback unchanged)', 'allow', await call(ADMIN, 'PATCH', 'some_other/doc2', field));

  await expectStatus('admin CREATES finance_expenses (older app)', 'allow', await call(ADMIN, 'PATCH', 'finance_expenses/new1?currentDocument.exists=false', field));
  await expectStatus('admin UPDATES finance_expenses (callable only)', 'deny', await call(ADMIN, 'PATCH', 'finance_expenses/e1', field));
  await expectStatus('admin DELETES finance_expenses (callable only)', 'deny', await call(ADMIN, 'DELETE', 'finance_expenses/e1'));
  await expectStatus('a parent CREATES finance_expenses', 'deny', await call(PARENT, 'PATCH', 'finance_expenses/new2?currentDocument.exists=false', field));
  await expectStatus('admin writes finance_months (callable only)', 'deny', await call(ADMIN, 'PATCH', 'finance_months/2026-11', field));
  await expectStatus('admin writes finance_recurring_costs (callable only)', 'deny', await call(ADMIN, 'PATCH', 'finance_recurring_costs/c1', field));
  await expectStatus('admin writes finance_private', 'deny', await call(ADMIN, 'PATCH', 'finance_private/plaid', field));
  await expectStatus('a parent reads finance_settings', 'deny', await call(PARENT, 'GET', 'finance_settings/main'));
  console.log(failed === 0 ? 'ALL PASS' : `${failed} FAILED`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(2); });
