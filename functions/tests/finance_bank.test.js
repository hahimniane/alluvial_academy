/**
 * Finance bank + WhatsApp handlers, against an in-memory Firestore.
 *
 * Expected behavior:
 * - With no Plaid / WhatsApp secret everything reports "not connected" and
 *   writes nothing.
 * - A sync stores deposits and charges (Plaid positive = money out), suggests
 *   matches (the prototype's cases) and is safe to repeat.
 * - decideBankMatch is the only way a deposit becomes payments: it checks the
 *   month is open, records one payment per allocation, can remember the payer.
 * - A WhatsApp screenshot never records a payment; it is stored, read, and
 *   linked to a bank deposit that already exists.
 * - Both webhooks reject anything not signed correctly.
 */

jest.mock('../utils/callable_admin', () => ({
  verifyCallableCallerIsAdmin: jest.fn(async () => ({callerUid: 'admin1', effectiveAdminEmail: 'a@x.org'})),
}));

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const admin = require('firebase-admin');
const {install} = require('./helpers/fake_firestore_bank');
const bank = require('../handlers/finance_bank');
const m = require('../utils/finance_bank_match');

/* ------------------------------------------------------------- fixtures -- */

const SECRETS = {
  PLAID_CLIENT_ID: 'cid', PLAID_SECRET: 'psecret', PLAID_ENV: 'sandbox', PLAID_WEBHOOK_URL: 'https://example.test/plaidWebhook',
  WHATSAPP_TOKEN: 'wtoken', WHATSAPP_PHONE_NUMBER_ID: '555', WHATSAPP_VERIFY_TOKEN: 'verify-me', WHATSAPP_APP_SECRET: 'appsecret',
  GEMINI_API_KEY: 'gkey',
};

const parent = (first, last, phone) => ({first_name: first, last_name: last, user_type: 'parent', phone_number: phone, country_code: '+1'});
const student = (first, last) => ({first_name: first, last_name: last, user_type: 'student'});

const invoice = (number, parentId, studentId, month, total, paid = 0) => ({
  invoice_number: number, parent_id: parentId, student_id: studentId, status: 'pending',
  total_amount: total, paid_amount: paid, billing_month: month, due_date: new Date(`${month}-01T15:00:00Z`),
});

const seed = () => ({
  finance_settings: {main: {parent_messages_enabled: false, whatsapp: {connected: false}, plaid: {connected: false}}},
  users: {
    p_sow: parent('Seydou', 'Sow', '646-555-0143'),
    p_jalloh: parent('Ibrahima', 'Jalloh', '+1 718 555 0177'),
    p_conde_a: parent('Abdoulaye', 'Conde', '3475550102'),
    p_conde_k: parent('Kadidia', 'Conde', '2125550188'),
    p_diallo: parent('Mamadou', 'Diallo', '9175550111'),
    p_kone: parent('Cheick', 'Kone', '+1 (718) 555-0199'),
    s_sow: student('Binta', 'Sow'),
    s_jalloh: student('Oumar', 'Jalloh'),
    s_conde_a: student('Fatou', 'Conde'),
    s_conde_k: student('Mariam', 'Conde'),
    s_diallo: student('Aissata', 'Diallo'),
    s_kone: student('Amadou', 'Kone'),
  },
  invoices: {
    i_sow: invoice('INV-2026-0101', 'p_sow', 's_sow', '2026-10', 160),
    i_jalloh: invoice('INV-2026-0102', 'p_jalloh', 's_jalloh', '2026-10', 100),
    i_conde_a: invoice('INV-2026-0103', 'p_conde_a', 's_conde_a', '2026-10', 160, 80),
    i_conde_k_sep: invoice('INV-2026-0090', 'p_conde_k', 's_conde_k', '2026-09', 160),
    i_conde_k_oct: invoice('INV-2026-0104', 'p_conde_k', 's_conde_k', '2026-10', 160),
    i_diallo: invoice('INV-2026-0105', 'p_diallo', 's_diallo', '2026-10', 120),
    i_kone: invoice('INV-2026-0106', 'p_kone', 's_kone', '2026-10', 100),
    i_paid: {...invoice('INV-2026-0050', 'p_sow', 's_sow', '2026-08', 160, 160), status: 'paid'},
  },
  known_payers: {
    [m.nameKey('Seydou Sow')]: {parent_id: 'p_sow', name: 'Seydou Sow'},
    [m.nameKey('Abdoulaye Conde')]: {parent_id: 'p_conde_a', name: 'Abdoulaye Conde'},
    [m.nameKey('Kadidia Conde')]: {parent_id: 'p_conde_k', name: 'Kadidia Conde'},
  },
  finance_recurring_costs: {
    c_zoom: {name: 'Zoom (3 licences)', category: 'software', amount: 149.9, start_month: '2026-01', end_month: null},
    c_gws: {name: 'Google Workspace', category: 'software', amount: 36, start_month: '2026-01', end_month: null},
  },
  finance_recurring_confirmations: {'2026-10_c_gws': {cost_id: 'c_gws', month: '2026-10', amount: 36, source: 'manual'}},
});

/** What Plaid's /transactions/sync returns for the prototype's October deposits. */
const plaidTxn = (id, date, amount, name, extra = {}) => ({
  transaction_id: id, account_id: 'acc1', date, amount, name, original_description: name, pending: false, iso_currency_code: 'USD', ...extra,
});
const PLAID_ADDED = [
  plaidTxn('t1', '2026-10-20', -160, 'Zelle payment from SEYDOU SOW', {payment_meta: {reason: 'INV-2026-0101'}}),
  plaidTxn('t2', '2026-10-19', -100, 'Zelle payment from HAWA JALLOH', {payment_meta: {reason: 'Oumar tuition oct'}}),
  plaidTxn('t3', '2026-10-18', -80, 'Zelle payment from ABDOULAYE CONDE'),
  plaidTxn('t4', '2026-10-17', -320, 'Zelle payment from KADIDIA CONDE', {payment_meta: {reason: 'Sept + Oct'}}),
  plaidTxn('t5', '2026-10-16', -75, 'Zelle payment from M DIALLO'),
  plaidTxn('t6', '2026-10-14', 149.9, 'ZOOM.US 888-799-9666'),
  plaidTxn('t7', '2026-10-12', -612.4, 'STRIPE TRANSFER'),
  plaidTxn('t8', '2026-10-05', 36, 'GOOGLE *WORKSPACE'),
  plaidTxn('t9', '2026-10-21', -50, 'Zelle payment from PENDING PERSON', {pending: true}),
];

const jsonResponse = (body, ok = true, status = 200) => ({ok, status, json: async () => body, text: async () => JSON.stringify(body), arrayBuffer: async () => Buffer.from(JSON.stringify(body))});

let fake;
let calls;
let routes;
const recordPayment = jest.fn();
const assertMonthOpen = jest.fn(async () => {});
const savedFiles = [];

const useDeps = (secretOverrides = SECRETS) => {
  calls = [];
  bank.__setDeps({
    fetch: async (url, opts = {}) => {
      calls.push({url, opts, body: opts.body ? safeParse(opts.body) : null});
      for (const [match, handler] of Object.entries(routes)) {
        if (url.includes(match)) return handler(url, opts);
      }
      throw new Error(`Unexpected fetch ${url}`);
    },
    getSecret: async (name) => secretOverrides[name] || '',
    now: () => new Date('2026-10-21T14:00:00Z'),
    assertMonthOpen,
    recordPayment,
    bucket: () => ({file: (path) => ({save: async (buf, o) => savedFiles.push({path, size: buf.length, ...o})})}),
  });
};

const safeParse = (s) => {
  try {
    return JSON.parse(s);
  } catch (e) {
    return null;
  }
};

const call = (fn, data) => fn({auth: {uid: 'admin1'}, data});

beforeEach(() => {
  jest.spyOn(console, 'error').mockImplementation(() => {});
  fake = install(admin, seed(), {now: () => new Date('2026-10-21T14:00:00Z').getTime()});
  savedFiles.length = 0;
  recordPayment.mockReset();
  assertMonthOpen.mockReset();
  assertMonthOpen.mockImplementation(async () => {});
  recordPayment.mockImplementation(async (db, o) => {
    await db.collection('payments').doc(o.paymentDocId).set({invoice_id: o.invoiceId, amount: o.amount, payment_method: o.paymentMethod, reference_number: o.reference, payment_source: o.paymentSource});
    const inv = db.collection('invoices').doc(o.invoiceId);
    const cur = (await inv.get()).data();
    await inv.update({paid_amount: cur.paid_amount + o.amount});
    return {success: true};
  });
  bank.__resetPhoneScan();
  bank.__clearJwkCache();
  routes = {};
  useDeps();
});

/* --------------------------------------------------- not connected at all -- */

describe('with no secrets', () => {
  beforeEach(() => useDeps({}));

  test('status says nothing is available', async () => {
    const out = await call(bank.linkBankAccount, {});
    expect(out).toMatchObject({plaid_available: false, plaid_connected: false, whatsapp_available: false, whatsapp_connected: false});
  });

  test('Link reports unavailable instead of failing', async () => {
    const out = await call(bank.linkBankAccount, {action: 'create_link_token'});
    expect(out.available).toBe(false);
    expect(out.message).toMatch(/not set up/);
    await expect(call(bank.linkBankAccount, {action: 'exchange', public_token: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(calls).toHaveLength(0);
  });

  test('sync does nothing and writes nothing', async () => {
    const before = fake.writes.length;
    expect(await call(bank.syncBankTransactions, {})).toEqual({connected: false, reason: 'plaid_not_configured'});
    expect(fake.writes.length).toBe(before);
    expect(calls).toHaveLength(0);
  });

  test('both webhooks answer 503 and write nothing', async () => {
    const res = fakeRes();
    await bank.handleWhatsappWebhook({method: 'POST', body: {}, headers: {}}, res);
    expect(res.statusCode).toBe(503);
    const res2 = fakeRes();
    await bank.handlePlaidWebhook({method: 'POST', body: {}, headers: {}}, res2);
    expect(res2.statusCode).toBe(503);
    expect(fake.writes).toHaveLength(0);
  });
});

function fakeRes() {
  const res = {statusCode: 200, body: undefined, headersSent: false};
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.send = (b) => { res.body = b; return res; };
  res.type = () => res;
  return res;
}

/* ----------------------------------------------------------- linking Plaid -- */

const syncRoute = (added = PLAID_ADDED, extra = {}) => ({
  '/transactions/sync': () => jsonResponse({added, modified: [], removed: [], next_cursor: 'cursor-1', has_more: false, ...extra}),
});

describe('linkBankAccount', () => {
  test('status shows what is configured', async () => {
    const out = await call(bank.linkBankAccount, {});
    expect(out).toMatchObject({plaid_available: true, plaid_env: 'sandbox', plaid_connected: false, whatsapp_available: true});
  });

  test('creates a link token with the webhook and the signed-in admin', async () => {
    routes = {'/link/token/create': () => jsonResponse({link_token: 'link-sandbox-1', expiration: '2026-10-21T18:00:00Z'})};
    const out = await call(bank.linkBankAccount, {action: 'create_link_token'});
    expect(out).toEqual({available: true, link_token: 'link-sandbox-1', expiration: '2026-10-21T18:00:00Z'});
    expect(calls[0].url).toBe('https://sandbox.plaid.com/link/token/create');
    expect(calls[0].body).toMatchObject({client_id: 'cid', secret: 'psecret', products: ['transactions'], webhook: 'https://example.test/plaidWebhook', user: {client_user_id: 'admin1'}});
  });

  test('exchange keeps the access token server-side and runs the first sync', async () => {
    routes = {
      '/item/public_token/exchange': () => jsonResponse({access_token: 'access-secret', item_id: 'item1'}),
      ...syncRoute(),
    };
    const out = await call(bank.linkBankAccount, {action: 'exchange', public_token: 'public-1', institution: 'Chase', mask: '••1234', account_ids: ['acc1']});
    expect(out).toMatchObject({connected: true, institution: 'Chase', mask: '1234'});
    expect(out.sync).toMatchObject({connected: true, added: 8});

    const priv = fake.peek('finance_private', 'plaid');
    expect(priv).toMatchObject({access_token: 'access-secret', item_id: 'item1', account_ids: ['acc1'], cursor: 'cursor-1'});
    const settings = fake.peek('finance_settings', 'main');
    expect(settings.plaid).toMatchObject({connected: true, institution: 'Chase', mask: '1234', linked_by: 'admin1'});
    expect(JSON.stringify(settings)).not.toMatch(/access-secret/);
    expect(JSON.stringify(out)).not.toMatch(/access-secret/);
  });

  test('a Plaid failure on exchange is a plain message', async () => {
    routes = {'/item/public_token/exchange': () => jsonResponse({error_message: 'invalid public_token'}, false, 400)};
    await expect(call(bank.linkBankAccount, {action: 'exchange', public_token: 'bad'})).rejects.toMatchObject({code: 'failed-precondition', message: expect.stringMatching(/invalid public_token/)});
    expect(fake.peek('finance_private', 'plaid')).toBeUndefined();
  });

  test('disconnect removes the item and the token', async () => {
    routes = {'/item/remove': () => jsonResponse({})};
    await fake.collection('finance_private').doc('plaid').set({access_token: 'a', item_id: 'i'});
    await call(bank.linkBankAccount, {action: 'disconnect'});
    expect(fake.peek('finance_private', 'plaid')).toBeUndefined();
    expect(fake.peek('finance_settings', 'main').plaid.connected).toBe(false);
  });
});

/* -------------------------------------------------------------- the sync -- */

const linked = async (opts = {}) => {
  routes = {...syncRoute(opts.added, opts.extra), ...(opts.routes || {})};
  await fake.collection('finance_private').doc('plaid').set({access_token: 'access-secret', item_id: 'item1', cursor: null, account_ids: [], mask: '1234'});
  await fake.collection('finance_settings').doc('main').set({plaid: {connected: true}}, {merge: true});
};

describe('sync', () => {
  test('stores every posted transaction with direction, parsed payer and the right suggestion', async () => {
    await linked();
    const out = await call(bank.syncBankTransactions, {});
    expect(out).toMatchObject({connected: true, added: 8});

    const t = fake.all('bank_transactions');
    expect(Object.keys(t)).toHaveLength(8); // the pending one waits until it posts
    const t1 = t.plaid_t1;
    expect(t1).toMatchObject({date: '2026-10-20', month: '2026-10', amount: 160, direction: 'in', payer_name: 'Seydou Sow', account_mask: '1234', channel: 'zelle'});
    expect(t1.match).toMatchObject({status: 'suggested', level: 'exact', kind: 'invoice_number', parent_id: 'p_sow'});
    expect(t1.match.allocations).toEqual([{invoice_id: 'i_sow', amount: 160, number: 'INV-2026-0101', month: '2026-10', family: 'Seydou Sow', student: 'Binta Sow'}]);
    expect(t1.needs_action).toBe(true);

    expect(t.plaid_t2.match).toMatchObject({status: 'suggested', level: 'likely', new_payer: true, payer_key: 'hawa_jalloh', parent_id: 'p_jalloh'});
    expect(t.plaid_t3.match).toMatchObject({status: 'suggested', level: 'exact', parent_id: 'p_conde_a'});
    expect(t.plaid_t3.match.allocations.map((a) => [a.invoice_id, a.amount])).toEqual([['i_conde_a', 80]]);
    expect(t.plaid_t4.match).toMatchObject({status: 'suggested', level: 'split'});
    expect(t.plaid_t4.match.allocations.map((a) => [a.invoice_id, a.amount, a.month])).toEqual([['i_conde_k_sep', 160, '2026-09'], ['i_conde_k_oct', 160, '2026-10']]);
    expect(t.plaid_t5.match).toMatchObject({status: 'none', level: 'none'});
    expect(t.plaid_t5.needs_action).toBe(true);
    expect(t.plaid_t5.match.why).toBe('No family with this name owes $75.00');

    expect(t.plaid_t6).toMatchObject({direction: 'out', amount: 149.9});
    expect(t.plaid_t6.match).toMatchObject({status: 'suggested', recurring_cost_id: 'c_zoom'});
    expect(t.plaid_t7.match).toMatchObject({status: 'ignored', level: 'auto', kind: 'stripe'});
    expect(t.plaid_t7.needs_action).toBe(false);
    expect(t.plaid_t8.match).toMatchObject({status: 'confirmed', level: 'auto', recurring_cost_id: 'c_gws'});

    expect(fake.peek('finance_private', 'plaid').cursor).toBe('cursor-1');
    expect(fake.peek('finance_settings', 'main').plaid.last_sync_at).toBeInstanceOf(Date);
    expect(recordPayment).not.toHaveBeenCalled();
  });

  test('sends the saved cursor, asks for original descriptions, and is safe to repeat', async () => {
    await linked();
    await call(bank.syncBankTransactions, {});
    await call(bank.syncBankTransactions, {});
    const syncCalls = calls.filter((c) => c.url.includes('/transactions/sync'));
    expect(syncCalls[0].body.cursor).toBeUndefined();
    expect(syncCalls[1].body.cursor).toBe('cursor-1');
    expect(syncCalls[0].body.options).toEqual({include_original_description: true});
    expect(Object.keys(fake.all('bank_transactions'))).toHaveLength(8);
  });

  test('a decision made by an admin survives a re-sync', async () => {
    await linked();
    await call(bank.syncBankTransactions, {});
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t5', action: 'ignore'});
    await call(bank.syncBankTransactions, {});
    expect(fake.peek('bank_transactions', 'plaid_t5').match.status).toBe('ignored');
  });

  test('only the linked accounts are read', async () => {
    await linked({added: [plaidTxn('x1', '2026-10-02', -50, 'Zelle payment from SEYDOU SOW', {account_id: 'savings'}), ...PLAID_ADDED.slice(0, 1)]});
    await fake.collection('finance_private').doc('plaid').update({account_ids: ['acc1']});
    await call(bank.syncBankTransactions, {});
    expect(Object.keys(fake.all('bank_transactions'))).toEqual(['plaid_t1']);
  });

  test('a run already in progress is skipped', async () => {
    await linked();
    await fake.collection('finance_private').doc('plaid').update({sync_lock_until: new Date('2026-10-21T14:02:00Z')});
    expect(await call(bank.syncBankTransactions, {})).toEqual({connected: true, skipped: 'busy'});
    expect(calls).toHaveLength(0);
  });

  test('a failure releases the lock and says so plainly', async () => {
    await linked({routes: {'/transactions/sync': () => jsonResponse({error_message: 'ITEM_LOGIN_REQUIRED'}, false, 400)}});
    await expect(call(bank.syncBankTransactions, {})).rejects.toMatchObject({code: 'unavailable', message: expect.stringMatching(/could not be read/)});
    expect(fake.peek('finance_private', 'plaid').sync_lock_until).toBeNull();
    expect(fake.peek('finance_private', 'plaid').cursor).toBeNull();
  });

  test('not linked yet reports so without calling Plaid', async () => {
    expect(await call(bank.syncBankTransactions, {})).toEqual({connected: false, reason: 'not_linked'});
  });

  test('a removed transaction that is still undecided is hidden', async () => {
    await linked();
    await call(bank.syncBankTransactions, {});
    routes['/transactions/sync'] = () => jsonResponse({added: [], modified: [], removed: [{transaction_id: 't5'}], next_cursor: 'c2', has_more: false});
    await call(bank.syncBankTransactions, {});
    expect(fake.peek('bank_transactions', 'plaid_t5')).toMatchObject({removed: true, needs_action: false});
  });

  test('re-suggesting picks up a payer learned since', async () => {
    await linked();
    await call(bank.syncBankTransactions, {});
    expect(fake.peek('bank_transactions', 'plaid_t2').match.new_payer).toBe(true);
    await fake.collection('known_payers').doc(m.nameKey('Hawa Jalloh')).set({parent_id: 'p_jalloh', name: 'Hawa Jalloh'});
    routes['/transactions/sync'] = () => jsonResponse({added: [], modified: [], removed: [], next_cursor: 'c2', has_more: false});
    await call(bank.syncBankTransactions, {rematch_month: '2026-10'});
    const again = fake.peek('bank_transactions', 'plaid_t2').match;
    expect(again).toMatchObject({level: 'exact', new_payer: false});
  });
});

/* -------------------------------------------------------- decideBankMatch -- */

const synced = async () => {
  await linked();
  await call(bank.syncBankTransactions, {});
};

describe('decideBankMatch', () => {
  beforeEach(synced);

  test('confirm records a Zelle payment with the transaction id as reference', async () => {
    const out = await call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'confirm'});
    expect(out).toMatchObject({ok: true, invoice_ids: ['i_sow']});
    expect(recordPayment).toHaveBeenCalledTimes(1);
    expect(recordPayment.mock.calls[0][1]).toMatchObject({
      invoiceId: 'i_sow', amount: 160, paymentMethod: 'zelle', reference: 'plaid_t1', actorUid: 'admin1',
      paymentDocId: 'bank_plaid_t1_i_sow', paymentSource: 'bank',
    });
    expect(assertMonthOpen).toHaveBeenCalledWith(expect.anything(), '2026-10');
    const t = fake.peek('bank_transactions', 'plaid_t1');
    expect(t.match).toMatchObject({status: 'confirmed', decided_by: 'admin1'});
    expect(t.match.allocations[0]).toMatchObject({invoice_id: 'i_sow', amount: 160, number: 'INV-2026-0101', month: '2026-10'});
    expect(t.needs_action).toBe(false);
    expect(fake.peek('invoices', 'i_sow').paid_amount).toBe(160);
  });

  test('confirming twice never pays twice', async () => {
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'confirm'});
    const again = await call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'confirm'});
    expect(again).toEqual({ok: true, already: true});
    expect(recordPayment).toHaveBeenCalledTimes(1);
  });

  test('a split deposit pays each invoice and checks every month', async () => {
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t4', action: 'confirm'});
    expect(recordPayment.mock.calls.map((c) => [c[1].invoiceId, c[1].amount])).toEqual([['i_conde_k_sep', 160], ['i_conde_k_oct', 160]]);
    expect(assertMonthOpen.mock.calls.map((c) => c[1]).sort()).toEqual(['2026-09', '2026-10']);
  });

  test('a closed month stops everything before any payment', async () => {
    assertMonthOpen.mockImplementation(async (db, month) => {
      if (month === '2026-09') throw Object.assign(new Error('2026-09 is closed'), {code: 'failed-precondition'});
    });
    await expect(call(bank.decideBankMatch, {transaction_id: 'plaid_t4', action: 'confirm'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(recordPayment).not.toHaveBeenCalled();
    expect(fake.peek('bank_transactions', 'plaid_t4').match.status).toBe('suggested');
  });

  test('remember_payer saves the new payer to the family', async () => {
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t2', action: 'confirm', remember_payer: true});
    expect(fake.peek('known_payers', 'hawa_jalloh')).toMatchObject({parent_id: 'p_jalloh', name: 'Hawa Jalloh', family_name: 'Ibrahima Jalloh', learned_by: 'admin1'});
  });

  test('without remember_payer nothing is learned', async () => {
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t2', action: 'confirm'});
    expect(fake.peek('known_payers', 'hawa_jalloh')).toBeUndefined();
  });

  test('reject drops the suggestion and keeps the deposit waiting', async () => {
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'reject'});
    const t = fake.peek('bank_transactions', 'plaid_t1');
    expect(t.match).toMatchObject({status: 'none', allocations: []});
    expect(t.needs_action).toBe(true);
    expect(recordPayment).not.toHaveBeenCalled();
  });

  test('manual pays the invoice the admin chose', async () => {
    const out = await call(bank.decideBankMatch, {transaction_id: 'plaid_t5', action: 'manual', allocations: [{invoice_id: 'i_diallo', amount: 75}]});
    expect(out.ok).toBe(true);
    expect(recordPayment.mock.calls[0][1]).toMatchObject({invoiceId: 'i_diallo', amount: 75});
    expect(fake.peek('bank_transactions', 'plaid_t5').match.status).toBe('manual');
  });

  test('manual refuses more than the deposit, and nothing', async () => {
    await expect(call(bank.decideBankMatch, {transaction_id: 'plaid_t5', action: 'manual', allocations: [{invoice_id: 'i_diallo', amount: 120}]})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(bank.decideBankMatch, {transaction_id: 'plaid_t5', action: 'manual', allocations: []})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(recordPayment).not.toHaveBeenCalled();
  });

  test('confirm without a suggestion is refused', async () => {
    await expect(call(bank.decideBankMatch, {transaction_id: 'plaid_t5', action: 'confirm'})).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('ignore marks it as not tuition', async () => {
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t5', action: 'ignore'});
    const t = fake.peek('bank_transactions', 'plaid_t5');
    expect(t.match.status).toBe('ignored');
    expect(t.needs_action).toBe(false);
  });

  test('a matched deposit cannot be ignored or rejected afterwards', async () => {
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'confirm'});
    await expect(call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'ignore'})).rejects.toMatchObject({code: 'failed-precondition'});
    await expect(call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'reject'})).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('confirming a charge writes the recurring confirmation with source bank', async () => {
    const out = await call(bank.decideBankMatch, {transaction_id: 'plaid_t6', action: 'confirm'});
    expect(out).toMatchObject({ok: true, recurring_cost_id: 'c_zoom', month: '2026-10'});
    expect(fake.peek('finance_recurring_confirmations', '2026-10_c_zoom')).toMatchObject({
      cost_id: 'c_zoom', month: '2026-10', amount: 149.9, source: 'bank', bank_transaction_id: 'plaid_t6', confirmed_by: 'admin1',
    });
    expect(assertMonthOpen).toHaveBeenCalledWith(expect.anything(), '2026-10');
    expect(recordPayment).not.toHaveBeenCalled();
  });

  test('a closed month blocks a recurring confirmation too', async () => {
    assertMonthOpen.mockRejectedValue(Object.assign(new Error('closed'), {code: 'failed-precondition'}));
    await expect(call(bank.decideBankMatch, {transaction_id: 'plaid_t6', action: 'confirm'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(fake.peek('finance_recurring_confirmations', '2026-10_c_zoom')).toBeUndefined();
  });

  test('unknown ids and actions are rejected plainly', async () => {
    await expect(call(bank.decideBankMatch, {transaction_id: 'nope', action: 'confirm'})).rejects.toMatchObject({code: 'not-found'});
    await expect(call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'delete'})).rejects.toMatchObject({code: 'invalid-argument'});
  });
});

/* ------------------------------------------------------------- WhatsApp -- */

const sign = (raw) => `sha256=${crypto.createHmac('sha256', SECRETS.WHATSAPP_APP_SECRET).update(raw).digest('hex')}`;

const webhookReq = (body, {signature, method = 'POST'} = {}) => {
  const raw = Buffer.from(JSON.stringify(body));
  return {
    method, body, rawBody: raw, headers: {},
    get: (h) => (h.toLowerCase() === 'x-hub-signature-256' ? (signature === undefined ? sign(raw) : signature) : undefined),
  };
};

const imageEvent = (id, from, ts = 1760900000) => ({
  object: 'whatsapp_business_account',
  entry: [{changes: [{value: {
    contacts: [{wa_id: from, profile: {name: 'Parent Name'}}],
    messages: [{id, from, timestamp: String(ts), type: 'image', image: {id: `media-${id}`, mime_type: 'image/jpeg'}}],
  }}]}],
});

const geminiReply = (obj) => () => jsonResponse({candidates: [{content: {parts: [{text: JSON.stringify(obj)}]}}]});

const whatsappRoutes = (extraction) => ({
  'graph.facebook.com/v21.0/media-': () => jsonResponse({url: 'https://lookaside.example/file', mime_type: 'image/jpeg', file_size: 1000}),
  'lookaside.example': () => jsonResponse({}),
  'generativelanguage.googleapis.com': geminiReply(extraction),
  '/messages': () => jsonResponse({messages: [{id: 'wamid.reply1'}]}),
});

const PAYMENT_SEYDOU = {is_payment: true, amount: 160, date: '2026-10-20', sender: 'SEYDOU SOW', recipient: 'Alluwal Education Hub', confirmation: 'ZL8H2K'};

describe('whatsapp webhook', () => {
  test('GET answers the subscription handshake only with the right token', async () => {
    const ok = fakeRes();
    await bank.handleWhatsappWebhook({method: 'GET', query: {'hub.mode': 'subscribe', 'hub.verify_token': 'verify-me', 'hub.challenge': '12345'}, headers: {}}, ok);
    expect(ok.statusCode).toBe(200);
    expect(ok.body).toBe('12345');
    expect(fake.peek('finance_settings', 'main').whatsapp.connected).toBe(true);

    const bad = fakeRes();
    await bank.handleWhatsappWebhook({method: 'GET', query: {'hub.mode': 'subscribe', 'hub.verify_token': 'wrong', 'hub.challenge': '1'}, headers: {}}, bad);
    expect(bad.statusCode).toBe(403);
  });

  test('POST with a bad or missing signature is refused and touches nothing', async () => {
    routes = whatsappRoutes(PAYMENT_SEYDOU);
    const res = fakeRes();
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143'), {signature: 'sha256=deadbeef'}), res);
    expect(res.statusCode).toBe(401);
    const res2 = fakeRes();
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143'), {signature: ''}), res2);
    expect(res2.statusCode).toBe(401);
    expect(calls).toHaveLength(0);
    expect(fake.all('payment_proofs')).toEqual({});
  });

  test('a screenshot with no bank deposit yet waits, finds the parent by phone, and never records a payment', async () => {
    routes = whatsappRoutes({...PAYMENT_SEYDOU, amount: 100, sender: 'CHEICK KONE', confirmation: 'ZQ41MP'});
    const res = fakeRes();
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('mk', '17185550199')), res);
    expect(res.statusCode).toBe(200);
    const proof = fake.peek('payment_proofs', 'wa_mk');
    expect(proof).toMatchObject({
      status: 'waiting_bank', from_phone: '+17185550199', image_path: 'payment-proofs/wa_mk.jpeg',
      extracted: {amount: 100, sender: 'Cheick Kone', confirmation: 'ZQ41MP'},
    });
    expect(proof.parent_id).toBe('p_kone');
    expect(savedFiles[0]).toMatchObject({path: 'payment-proofs/wa_mk.jpeg', contentType: 'image/jpeg'});
    expect(recordPayment).not.toHaveBeenCalled();
    expect(fake.all('payments')).toEqual({});
  });

  test('a screenshot that matches a deposit already in the bank is linked, not paid', async () => {
    await synced();
    routes = whatsappRoutes(PAYMENT_SEYDOU);
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    const proof = fake.peek('payment_proofs', 'wa_m1');
    expect(proof).toMatchObject({status: 'matched', parent_id: 'p_sow', bank_transaction_id: 'plaid_t1', invoice_id: 'i_sow'});
    expect(fake.peek('bank_transactions', 'plaid_t1').proof_id).toBe('wa_m1');
    expect(recordPayment).not.toHaveBeenCalled();
    expect(fake.peek('invoices', 'i_sow').paid_amount).toBe(0);
  });

  test('an unknown number is flagged and the same picture twice is a duplicate', async () => {
    routes = whatsappRoutes({...PAYMENT_SEYDOU, sender: 'MOUSSA TRAORE', confirmation: 'ZK7T3D', amount: 160});
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('mu', '224621550188')), fakeRes());
    expect(fake.peek('payment_proofs', 'wa_mu')).toMatchObject({status: 'unknown_sender'});
    expect(fake.peek('payment_proofs', 'wa_mu').parent_id).toBeUndefined();

    routes = whatsappRoutes(PAYMENT_SEYDOU);
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m2', '16465550143')), fakeRes());
    expect(fake.peek('payment_proofs', 'wa_m1').status).toBe('waiting_bank');
    expect(fake.peek('payment_proofs', 'wa_m2')).toMatchObject({status: 'duplicate', duplicate_of: 'wa_m1'});
  });

  test('a delivery repeated by Meta creates one proof', async () => {
    routes = whatsappRoutes(PAYMENT_SEYDOU);
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    const geminiCalls = () => calls.filter((c) => c.url.includes('generativelanguage')).length;
    const before = geminiCalls();
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    expect(Object.keys(fake.all('payment_proofs'))).toEqual(['wa_m1']);
    expect(geminiCalls()).toBe(before);
  });

  test('a picture that is not a payment is passed to the admins as a message', async () => {
    routes = whatsappRoutes({is_payment: false, amount: null, date: '', sender: '', recipient: '', confirmation: ''});
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('mt', '16465550143')), fakeRes());
    expect(fake.peek('payment_proofs', 'wa_mt').status).toBe('not_payment');
    const notes = Object.values(fake.all('admin_notifications'));
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({type: 'whatsapp_message', proof_id: 'wa_mt', read: false});
  });

  test('an unreadable picture is kept and the admins are told', async () => {
    routes = {...whatsappRoutes({}), 'generativelanguage.googleapis.com': () => jsonResponse({}, false, 503)};
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('mx', '16465550143')), fakeRes());
    expect(fake.peek('payment_proofs', 'wa_mx').status).toBe('unreadable');
    expect(Object.values(fake.all('admin_notifications'))).toHaveLength(1);
  });

  test('Gemini gets the image inline with the key from the secrets', async () => {
    routes = whatsappRoutes(PAYMENT_SEYDOU);
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    const g = calls.find((c) => c.url.includes('generativelanguage'));
    expect(g.opts.headers['x-goog-api-key']).toBe('gkey');
    expect(g.body.contents[0].parts[1].inline_data.mime_type).toBe('image/jpeg');
  });

  test('replies go out only when parent messages are on', async () => {
    routes = whatsappRoutes(PAYMENT_SEYDOU);
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    expect(calls.filter((c) => c.url.endsWith('/messages'))).toHaveLength(0);
    expect(fake.peek('payment_proofs', 'wa_m1').replies).toEqual([]);

    await fake.collection('finance_settings').doc('main').update({parent_messages_enabled: true});
    routes = whatsappRoutes({...PAYMENT_SEYDOU, confirmation: 'NEW999'});
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m2', '16465550143')), fakeRes());
    const sent = calls.filter((c) => c.url.endsWith('/messages'));
    expect(sent).toHaveLength(1);
    expect(sent[0].url).toBe('https://graph.facebook.com/v21.0/555/messages');
    expect(sent[0].opts.headers.Authorization).toBe('Bearer wtoken');
    expect(sent[0].body).toMatchObject({messaging_product: 'whatsapp', to: '16465550143', type: 'text'});
    expect(sent[0].body.text.body).toMatch(/We received your payment proof/);
    expect(fake.peek('payment_proofs', 'wa_m2').replies).toHaveLength(1);
  });
});

/* ------------------------------------------------------ decidePaymentProof -- */

describe('decidePaymentProof', () => {
  test('confirm without a bank deposit records nothing', async () => {
    routes = whatsappRoutes(PAYMENT_SEYDOU);
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    await expect(call(bank.decidePaymentProof, {proof_id: 'wa_m1', action: 'confirm'})).rejects.toMatchObject({
      code: 'failed-precondition', message: expect.stringMatching(/Nothing has reached the bank/),
    });
    expect(recordPayment).not.toHaveBeenCalled();
  });

  test('confirm with a linked deposit pays through the same path as the deposit', async () => {
    await synced();
    routes = whatsappRoutes(PAYMENT_SEYDOU);
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    const out = await call(bank.decidePaymentProof, {proof_id: 'wa_m1', action: 'confirm'});
    expect(out.ok).toBe(true);
    expect(recordPayment).toHaveBeenCalledTimes(1);
    expect(recordPayment.mock.calls[0][1]).toMatchObject({invoiceId: 'i_sow', amount: 160, paymentMethod: 'zelle', reference: 'plaid_t1'});
    expect(fake.peek('payment_proofs', 'wa_m1')).toMatchObject({status: 'confirmed', invoice_id: 'i_sow'});
    expect(fake.peek('bank_transactions', 'plaid_t1').match.status).toBe('confirmed');
  });

  test('confirming the deposit also closes its proof, and the parent hears it only when messages are on', async () => {
    await synced();
    await fake.collection('finance_settings').doc('main').update({parent_messages_enabled: true});
    routes = whatsappRoutes(PAYMENT_SEYDOU);
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('m1', '16465550143')), fakeRes());
    calls.length = 0;
    await call(bank.decideBankMatch, {transaction_id: 'plaid_t1', action: 'confirm'});
    expect(fake.peek('payment_proofs', 'wa_m1').status).toBe('confirmed');
    const sent = calls.filter((c) => c.url.endsWith('/messages'));
    expect(sent).toHaveLength(1);
    expect(sent[0].body.text.body).toBe('Your October invoice INV-2026-0101 is paid. Thank you!');
  });

  test('link_family saves the number, then matches the waiting screenshot to the family', async () => {
    routes = whatsappRoutes({...PAYMENT_SEYDOU, sender: 'MOUSSA TRAORE', confirmation: 'ZK7T3D', amount: 120});
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('mu', '224621550188')), fakeRes());
    expect(fake.peek('payment_proofs', 'wa_mu').status).toBe('unknown_sender');

    const out = await call(bank.decidePaymentProof, {proof_id: 'wa_mu', action: 'link_family', parent_id: 'p_diallo'});
    expect(out.proofs).toEqual([{proof_id: 'wa_mu', status: 'waiting_bank'}]);
    expect(fake.peek('known_phones', '224621550188')).toMatchObject({parent_id: 'p_diallo', source: 'admin', linked_by: 'admin1'});
    expect(fake.peek('payment_proofs', 'wa_mu')).toMatchObject({parent_id: 'p_diallo', status: 'waiting_bank', invoice_id: 'i_diallo'});

    // The next picture from that number needs no admin.
    routes = whatsappRoutes({...PAYMENT_SEYDOU, amount: 120, confirmation: 'ZK9999', sender: 'MOUSSA TRAORE'});
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('mu2', '224621550188')), fakeRes());
    expect(fake.peek('payment_proofs', 'wa_mu2')).toMatchObject({status: 'waiting_bank', parent_id: 'p_diallo'});
  });

  test('link_family re-runs matching: a deposit from an unrelated name now suggests the family', async () => {
    await linked({added: [plaidTxn('t20', '2026-10-19', -160, 'Zelle payment from MOUSSA TRAORE')]});
    await call(bank.syncBankTransactions, {});
    expect(fake.peek('bank_transactions', 'plaid_t20').match.status).toBe('none');

    routes = whatsappRoutes({...PAYMENT_SEYDOU, sender: 'MOUSSA TRAORE', confirmation: 'ZK7T3D', date: '2026-10-19', amount: 160});
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('mu', '224621550188')), fakeRes());
    expect(fake.peek('payment_proofs', 'wa_mu').status).toBe('unknown_sender');

    const out = await call(bank.decidePaymentProof, {proof_id: 'wa_mu', action: 'link_family', parent_id: 'p_sow'});
    expect(out.proofs[0].status).toBe('matched');
    const t = fake.peek('bank_transactions', 'plaid_t20');
    expect(t.proof_id).toBe('wa_mu');
    expect(t.match).toMatchObject({status: 'suggested', level: 'exact', parent_id: 'p_sow', new_payer: true});
    expect(recordPayment).not.toHaveBeenCalled();
  });

  test('link_family needs a real family', async () => {
    routes = whatsappRoutes({...PAYMENT_SEYDOU, sender: 'MOUSSA TRAORE', confirmation: 'ZK7T3D'});
    await bank.handleWhatsappWebhook(webhookReq(imageEvent('mu', '224621550188')), fakeRes());
    await expect(call(bank.decidePaymentProof, {proof_id: 'wa_mu', action: 'link_family'})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(bank.decidePaymentProof, {proof_id: 'wa_mu', action: 'link_family', parent_id: 'ghost'})).rejects.toMatchObject({code: 'not-found'});
  });
});

/* ------------------------------------------------------ Plaid webhook JWT -- */

describe('plaid webhook', () => {
  const {privateKey, publicKey} = crypto.generateKeyPairSync('ec', {namedCurve: 'P-256'});
  const jwk = publicKey.export({format: 'jwk'});
  const body = {webhook_type: 'TRANSACTIONS', webhook_code: 'SYNC_UPDATES_AVAILABLE', item_id: 'item1'};
  const raw = Buffer.from(JSON.stringify(body));

  const tokenFor = (rawBody, extra = {}, opts = {}) =>
    jwt.sign({request_body_sha256: crypto.createHash('sha256').update(rawBody).digest('hex'), ...extra}, privateKey, {algorithm: 'ES256', keyid: 'kid1', ...opts});

  const req = (token, b = body, r = raw) => ({method: 'POST', body: b, rawBody: r, headers: token ? {'plaid-verification': token} : {}});

  beforeEach(async () => {
    await linked();
    routes['/webhook_verification_key/get'] = () => jsonResponse({key: {...jwk, kid: 'kid1', alg: 'ES256', use: 'sig', expired_at: null}});
  });

  test('a validly signed webhook runs a sync', async () => {
    const res = fakeRes();
    await bank.handlePlaidWebhook(req(tokenFor(raw)), res);
    expect(res.statusCode).toBe(200);
    expect(Object.keys(fake.all('bank_transactions'))).toHaveLength(8);
  });

  test('a body that was changed after signing is refused', async () => {
    const tampered = Buffer.from(JSON.stringify({...body, webhook_code: 'DEFAULT_UPDATE'}));
    const res = fakeRes();
    await bank.handlePlaidWebhook(req(tokenFor(raw), JSON.parse(tampered), tampered), res);
    expect(res.statusCode).toBe(401);
    expect(fake.all('bank_transactions')).toEqual({});
  });

  test('a missing header, a stale token and a token from another key are refused', async () => {
    const none = fakeRes();
    await bank.handlePlaidWebhook(req(null), none);
    expect(none.statusCode).toBe(401);

    const stale = tokenFor(raw, {iat: Math.floor(Date.now() / 1000) - 3600});
    const r2 = fakeRes();
    await bank.handlePlaidWebhook(req(stale), r2);
    expect(r2.statusCode).toBe(401);

    const other = crypto.generateKeyPairSync('ec', {namedCurve: 'P-256'}).privateKey;
    const forged = jwt.sign({request_body_sha256: crypto.createHash('sha256').update(raw).digest('hex')}, other, {algorithm: 'ES256', keyid: 'kid1'});
    const r3 = fakeRes();
    await bank.handlePlaidWebhook(req(forged), r3);
    expect(r3.statusCode).toBe(401);
    expect(fake.all('bank_transactions')).toEqual({});
  });

  test('an HS256 token cannot be passed off (algorithm is pinned)', async () => {
    const weak = jwt.sign({request_body_sha256: crypto.createHash('sha256').update(raw).digest('hex')}, 'secret', {algorithm: 'HS256', keyid: 'kid1'});
    const res = fakeRes();
    await bank.handlePlaidWebhook(req(weak), res);
    expect(res.statusCode).toBe(401);
  });

  test('an item error flags the connection for attention', async () => {
    const b = {webhook_type: 'ITEM', webhook_code: 'PENDING_EXPIRATION', item_id: 'item1'};
    const r = Buffer.from(JSON.stringify(b));
    const res = fakeRes();
    await bank.handlePlaidWebhook(req(tokenFor(r), b, r), res);
    expect(res.statusCode).toBe(200);
    expect(fake.peek('finance_settings', 'main').plaid.needs_attention).toBe('PENDING_EXPIRATION');
  });

  test('a webhook for another item is ignored', async () => {
    const b = {...body, item_id: 'someone-else'};
    const r = Buffer.from(JSON.stringify(b));
    const res = fakeRes();
    await bank.handlePlaidWebhook(req(tokenFor(r), b, r), res);
    expect(res.body).toEqual({ok: true, ignored: true});
    expect(fake.all('bank_transactions')).toEqual({});
  });
});

/* ----------------------------------------------------------------- phones -- */

describe('findParentByPhone', () => {
  test('finds a parent by the usual spellings, learns the number, and ignores students', async () => {
    const hit = await bank.findParentByPhone(fake, '+1 (646) 555-0143');
    expect(hit).toMatchObject({parent_id: 'p_sow', name: 'Seydou Sow'});
    expect(fake.peek('known_phones', '16465550143')).toMatchObject({parent_id: 'p_sow', source: 'auto'});
    expect(await bank.findParentByPhone(fake, '12125550188')).toMatchObject({parent_id: 'p_conde_k'});
    expect(await bank.findParentByPhone(fake, '19998887777')).toBeNull();
  });

  test('a number shared by two accounts is left for an admin', async () => {
    await fake.collection('users').doc('p_jalloh2').set(parent('Hawa', 'Jalloh', '718-555-0177'));
    expect(await bank.findParentByPhone(fake, '17185550177')).toBeNull();
    expect(fake.peek('known_phones', '17185550177')).toBeUndefined();
  });

  test('an international number stored with its country code on the account', async () => {
    await fake.collection('users').doc('p_gn').set({first_name: 'Mariama', last_name: 'Bah', user_type: 'parent', phone_number: '621 55 01 88', country_code: '+224'});
    expect(await bank.findParentByPhone(fake, '224621550188')).toMatchObject({parent_id: 'p_gn'});
  });
});
