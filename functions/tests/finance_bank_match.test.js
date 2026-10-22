/**
 * Pure bank-matching logic. The cases mirror the approved prototype's
 * "Bank deposits" screen: exact by invoice number, a new payer (spouse), a
 * split across September and October, an unknown $75, the Zoom charge, a
 * Stripe transfer and an already confirmed Google Workspace charge.
 */

const m = require('../utils/finance_bank_match');

/* ---- sample data (October 2026, families like the prototype's) ---------- */

const inv = (id, number, parent_id, month, balance, extra = {}) => ({
  id, number, parent_id, month, balance, total: 160, due: `${month}-01`, student_names: [], ...extra,
});

const INVOICES = [
  inv('i_sow_oct', 'INV-2026-0101', 'p_sow', 'Oct', 160),
  inv('i_jalloh_oct', 'INV-2026-0102', 'p_jalloh', '2026-10', 100, {total: 100, student_names: ['Oumar Jalloh']}),
  inv('i_conde_a_oct', 'INV-2026-0103', 'p_conde_a', '2026-10', 80, {total: 160, student_names: ['Fatou Conde']}),
  inv('i_conde_k_sep', 'INV-2026-0090', 'p_conde_k', '2026-09', 160, {student_names: ['Mariam Conde']}),
  inv('i_conde_k_oct', 'INV-2026-0104', 'p_conde_k', '2026-10', 160, {student_names: ['Mariam Conde']}),
  inv('i_diallo_oct', 'INV-2026-0105', 'p_diallo', '2026-10', 120, {student_names: ['Aissata Diallo']}),
].map((i) => (i.month === 'Oct' ? {...i, month: '2026-10'} : i));

const PARENTS = {
  p_sow: {names: ['Seydou Sow'], surnames: ['sow']},
  p_jalloh: {names: ['Ibrahima Jalloh'], surnames: ['jalloh']},
  p_conde_a: {names: ['Abdoulaye Conde'], surnames: ['conde']},
  p_conde_k: {names: ['Kadidia Conde'], surnames: ['conde']},
  p_diallo: {names: ['Mamadou Diallo'], surnames: ['diallo']},
};

const KNOWN = {
  [m.nameKey('Seydou Sow')]: {parent_id: 'p_sow'},
  [m.nameKey('Abdoulaye Conde')]: {parent_id: 'p_conde_a'},
  [m.nameKey('Kadidia Conde')]: {parent_id: 'p_conde_k'},
};

const ctx = (extra = {}) => ({invoices: INVOICES, parents: PARENTS, knownPayers: KNOWN, ...extra});

const dep = (amount, description, memo = '', extra = {}) => ({amount, description, memo, date: '2026-10-20', ...extra});

/* ---------------------------------------------------------------- names -- */

describe('names', () => {
  test('normalizeName drops accents, case and punctuation', () => {
    expect(m.normalizeName('  Séydou  SOW. ')).toBe('seydou sow');
  });

  test('nameKey ignores word order and comma form', () => {
    expect(m.nameKey('SEYDOU SOW')).toBe(m.nameKey('Sow, Seydou'));
    expect(m.nameKey('SEYDOU SOW')).toBe('seydou_sow');
  });

  test('prettyName fixes shouting but leaves a mixed-case name alone', () => {
    expect(m.prettyName('SEYDOU SOW')).toBe('Seydou Sow');
    expect(m.prettyName('McDonald Ba')).toBe('McDonald Ba');
  });
});

/* ------------------------------------------------------ description parse -- */

describe('parseBankDescription', () => {
  test.each([
    ['Zelle payment from SEYDOU SOW', 'Seydou Sow', '', ''],
    ['Zelle payment from SEYDOU SOW Conf# rtp8c2sh6', 'Seydou Sow', '', 'RTP8C2SH6'],
    ['Zelle payment from Seydou Sow for "Oct tuition"; Conf# 1abc2def', 'Seydou Sow', 'Oct tuition', '1ABC2DEF'],
    ['Zelle payment from SEYDOU SOW 28391002345', 'Seydou Sow', '', '28391002345'],
    ['ZELLE FROM SEYDOU SOW', 'Seydou Sow', '', ''],
    ['Zelle From SEYDOU SOW on 10/20 Ref # WF1234567', 'Seydou Sow', '', 'WF1234567'],
    ['ZELLE CREDIT SEYDOU SOW', 'Seydou Sow', '', ''],
    ['Online Transfer from SOW, SEYDOU via Zelle', 'Seydou Sow', '', ''],
    ['Zelle payment from HAWA JALLOH for Oumar tuition oct', 'Hawa Jalloh', 'Oumar tuition oct', ''],
  ])('%s', (line, payer, memo, conf) => {
    const p = m.parseBankDescription(line);
    expect(p.channel).toBe('zelle');
    expect(p.payer_name).toBe(payer);
    expect(p.memo).toBe(memo);
    expect(p.confirmation).toBe(conf);
  });

  test('semicolon form keeps the memo with the invoice number', () => {
    const p = m.parseBankDescription('Zelle Transfer Conf# 12345ab; SOW SEYDOU; INV-2026-0101');
    expect(p.channel).toBe('zelle');
    expect(p.confirmation).toBe('12345AB');
    expect(p.memo).toContain('INV-2026-0101');
  });

  test('a separate memo field is kept and joined', () => {
    const p = m.parseBankDescription('Zelle payment from HAWA JALLOH', 'Oumar tuition oct');
    expect(p.payer_name).toBe('Hawa Jalloh');
    expect(p.memo).toBe('Oumar tuition oct');
  });

  test('Stripe transfers and own-account transfers are automatic', () => {
    expect(m.parseBankDescription('STRIPE TRANSFER')).toMatchObject({channel: 'stripe', auto: true});
    expect(m.parseBankDescription('STRIPE ST-L8F2 PAYOUT')).toMatchObject({channel: 'stripe', auto: true});
    expect(m.parseBankDescription('Online Transfer from SAV 1234')).toMatchObject({channel: 'own_transfer', auto: true});
  });

  test('a plain card charge is not read as a Zelle payment', () => {
    const p = m.parseBankDescription('ZOOM.US 888-799-9666');
    expect(p.channel).toBe('other');
    expect(p.auto).toBe(false);
  });
});

/* ---------------------------------------------------------------- months -- */

describe('months in memos', () => {
  test('English and French month words', () => {
    expect(m.monthsNamedIn('Sept + Oct')).toEqual([9, 10]);
    expect(m.monthsNamedIn('scolarité octobre')).toEqual([10]);
    expect(m.monthsNamedIn('tuition')).toEqual([]);
  });
});

/* ------------------------------------------------------------- invoices -- */

describe('invoice numbers', () => {
  test('padding and punctuation do not matter', () => {
    expect(m.invoiceKey('INV-2026-0101')).toBe(m.invoiceKey('inv 2026 101'));
    expect(m.invoiceKeysIn('paid INV-2026-0101 and INV-2026-0090 thanks')).toEqual(['INV2026-101', 'INV2026-90']);
  });
});

/* ------------------------------------------------------ matching deposits -- */

describe('matchDeposit', () => {
  test('exact: the memo has the invoice number (prototype D1)', () => {
    const r = m.matchDeposit(dep(160, 'Zelle payment from SEYDOU SOW', 'INV-2026-0101'), ctx());
    expect(r).toMatchObject({status: 'suggested', level: 'exact', kind: 'invoice_number', parent_id: 'p_sow', new_payer: false});
    expect(r.allocations).toEqual([{invoice_id: 'i_sow_oct', amount: 160}]);
  });

  test('exact by memo even from an unknown payer, flagged as a new payer', () => {
    const r = m.matchDeposit(dep(160, 'Zelle payment from AMINATA SOW', 'inv-2026-101'), ctx());
    expect(r.level).toBe('exact');
    expect(r.new_payer).toBe(true);
    expect(r.payer_key).toBe('aminata_sow');
  });

  test('likely, new payer: the amount matches and the student is named (prototype D2)', () => {
    const r = m.matchDeposit(dep(100, 'Zelle payment from HAWA JALLOH', 'Oumar tuition oct'), ctx());
    expect(r).toMatchObject({status: 'suggested', level: 'likely', kind: 'balance', parent_id: 'p_jalloh', new_payer: true, payer_key: 'hawa_jalloh'});
    expect(r.allocations).toEqual([{invoice_id: 'i_jalloh_oct', amount: 100}]);
    expect(r.why).toMatch(/not paid before/);
  });

  test('exact: a known payer paying the rest of the balance (prototype D3)', () => {
    const r = m.matchDeposit(dep(80, 'Zelle payment from ABDOULAYE CONDE'), ctx());
    expect(r).toMatchObject({status: 'suggested', level: 'exact', parent_id: 'p_conde_a', new_payer: false});
    expect(r.allocations).toEqual([{invoice_id: 'i_conde_a_oct', amount: 80}]);
    expect(r.why).toMatch(/known payer/);
  });

  test('split: one amount covering September and October (prototype D4)', () => {
    const r = m.matchDeposit(dep(320, 'Zelle payment from KADIDIA CONDE', 'Sept + Oct'), ctx());
    expect(r).toMatchObject({status: 'suggested', level: 'split', kind: 'split', parent_id: 'p_conde_k'});
    expect(r.allocations).toEqual([
      {invoice_id: 'i_conde_k_sep', amount: 160},
      {invoice_id: 'i_conde_k_oct', amount: 160},
    ]);
  });

  test('split also works for a payer who is not known yet', () => {
    const noKnown = ctx({knownPayers: {}});
    const r = m.matchDeposit(dep(320, 'Zelle payment from KADIDIA CONDE'), noKnown);
    expect(r.level).toBe('split');
    expect(r.new_payer).toBe(true);
  });

  test('none: nobody with that name owes $75 (prototype D5)', () => {
    const r = m.matchDeposit(dep(75, 'Zelle payment from M DIALLO'), ctx());
    expect(r).toMatchObject({status: 'none', level: 'none', allocations: []});
    expect(r.why).toBe('No family with this name owes $75.00');
  });

  test('none: a name nobody has, whatever the amount', () => {
    const r = m.matchDeposit(dep(160, 'Zelle payment from PAUL MARTIN'), ctx());
    expect(r.status).toBe('none');
  });

  test('two families with the same surname and amount is not guessed', () => {
    const twins = [
      inv('a', 'INV-2026-0201', 'p_a', '2026-10', 100),
      inv('b', 'INV-2026-0202', 'p_b', '2026-10', 100),
    ];
    const r = m.matchDeposit(dep(100, 'Zelle payment from LUC BAH'), {
      invoices: twins,
      parents: {p_a: {names: ['Ali Bah'], surnames: ['bah']}, p_b: {names: ['Omar Bah'], surnames: ['bah']}},
      knownPayers: {},
    });
    expect(r.status).toBe('none');
    expect(r.candidates.sort()).toEqual(['a', 'b']);
  });

  test('two months with the same amount: the memo month wins, else the oldest', () => {
    const two = [
      inv('sep', 'INV-2026-0301', 'p_x', '2026-09', 160),
      inv('oct', 'INV-2026-0302', 'p_x', '2026-10', 160),
    ];
    const base = {invoices: two, parents: {p_x: {names: ['Ali Xa'], surnames: ['xa']}}, knownPayers: {[m.nameKey('Ali Xa')]: {parent_id: 'p_x'}}};
    const byMemo = m.matchDeposit(dep(160, 'Zelle payment from ALI XA', 'October'), base);
    expect(byMemo.allocations[0].invoice_id).toBe('oct');
    expect(byMemo.level).toBe('exact');
    const oldest = m.matchDeposit(dep(160, 'Zelle payment from ALI XA'), base);
    expect(oldest.allocations[0].invoice_id).toBe('sep');
    expect(oldest.level).toBe('likely');
  });

  test('a known payer paying less than the balance is a partial suggestion', () => {
    const r = m.matchDeposit(dep(50, 'Zelle payment from SEYDOU SOW'), ctx());
    expect(r).toMatchObject({status: 'suggested', level: 'likely', kind: 'partial'});
    expect(r.allocations).toEqual([{invoice_id: 'i_sow_oct', amount: 50}]);
  });

  test('a known payer paying more than everything owed leaves the rest unallocated', () => {
    const r = m.matchDeposit(dep(200, 'Zelle payment from SEYDOU SOW'), ctx());
    expect(r.allocations).toEqual([{invoice_id: 'i_sow_oct', amount: 160}]);
    expect(r.unallocated).toBe(40);
    expect(r.level).toBe('likely');
  });

  test('an invoice number with the wrong amount is likely, not exact', () => {
    const r = m.matchDeposit(dep(100, 'Zelle payment from SEYDOU SOW', 'INV-2026-0101'), ctx());
    expect(r.level).toBe('likely');
    expect(r.allocations).toEqual([{invoice_id: 'i_sow_oct', amount: 100}]);
  });

  test('a paid invoice number in the memo falls back to the name rules', () => {
    const r = m.matchDeposit(dep(160, 'Zelle payment from SEYDOU SOW', 'INV-2026-0999'), ctx());
    expect(r.level).toBe('exact');
    expect(r.kind).toBe('balance');
  });

  test('a family linked through the parent\'s own WhatsApp number counts like a known payer', () => {
    const r = m.matchDeposit(dep(160, 'Zelle payment from MOUSSA TRAORE'), ctx({hintParentId: 'p_sow', knownPayers: {}}));
    expect(r.level).toBe('exact');
    expect(r.parent_id).toBe('p_sow');
    expect(r.new_payer).toBe(true);
    expect(r.why).toMatch(/screenshot/);
  });

  test('Stripe transfers are automatic', () => {
    const r = m.matchDeposit(dep(612.4, 'STRIPE TRANSFER'), ctx());
    expect(r).toMatchObject({status: 'auto', level: 'auto'});
  });

  test('a zero amount is never matched', () => {
    expect(m.matchDeposit(dep(0, 'Zelle payment from SEYDOU SOW'), ctx()).status).toBe('none');
  });

  test('cents are compared exactly, not rounded away', () => {
    const r = m.matchDeposit(dep(159.99, 'Zelle payment from SEYDOU SOW'), ctx());
    expect(r.kind).toBe('partial');
  });
});

/* --------------------------------------------------- matching charges -- */

describe('matchCharge', () => {
  const costs = [
    {id: 'c_zoom', name: 'Zoom (3 licences)', amount: 149.9, start_month: '2026-01', end_month: null},
    {id: 'c_gws', name: 'Google Workspace', amount: 36, start_month: '2026-01', end_month: null},
    {id: 'c_old', name: 'Mailchimp', amount: 20, start_month: '2026-01', end_month: '2026-06'},
  ];

  test('the Zoom charge is suggested as the month\'s Zoom bill (prototype D6)', () => {
    const r = m.matchCharge({amount: -149.9, date: '2026-10-14', description: 'ZOOM.US 888-799-9666'}, {costs, confirmations: {}});
    expect(r).toMatchObject({status: 'suggested', recurring_cost_id: 'c_zoom'});
    expect(r.why).toMatch(/Zoom/);
  });

  test('a cost already confirmed at the same amount is automatic (prototype D8)', () => {
    const r = m.matchCharge(
      {amount: -36, date: '2026-10-05', description: 'GOOGLE *WORKSPACE'},
      {costs, confirmations: {'2026-10_c_gws': {amount: 36}}},
    );
    expect(r).toMatchObject({status: 'auto', recurring_cost_id: 'c_gws'});
  });

  test('a cost confirmed at a different amount is still suggested, and says so', () => {
    const r = m.matchCharge(
      {amount: -39.5, date: '2026-10-05', description: 'GOOGLE *WORKSPACE'},
      {costs, confirmations: {'2026-10_c_gws': {amount: 36}}},
    );
    expect(r.status).toBe('suggested');
    expect(r.why).toMatch(/confirmed at \$36\.00/);
  });

  test('a cost that ended before the month is not matched', () => {
    const r = m.matchCharge({amount: -20, date: '2026-10-02', description: 'MAILCHIMP*MONTHLY'}, {costs});
    expect(r.status).toBe('none');
  });

  test('an unknown charge is simply not matched', () => {
    const r = m.matchCharge({amount: -12, date: '2026-10-02', description: 'SHELL OIL 5712'}, {costs});
    expect(r).toMatchObject({status: 'none', level: 'none'});
  });

  test('name scoring needs the main word, not just the word "account"', () => {
    expect(m.chargeNameScore('BANK ACCOUNT FEE', 'Google Workspace account')).toBe(0);
    expect(m.chargeNameScore('GOOGLE *WORKSPACE', 'Google Workspace')).toBe(1);
  });

  test('a Stripe line is automatic even as an outgoing charge', () => {
    const r = m.matchCharge({amount: -3, date: '2026-10-02', description: 'STRIPE FEE'}, {costs});
    expect(r.status).toBe('auto');
  });
});

/* ------------------------------------------------------- allocation -- */

describe('allocateInOrder', () => {
  test('fills the oldest first and reports what is left', () => {
    const list = [{id: 'a', balance: 100}, {id: 'b', balance: 100}];
    expect(m.allocateInOrder(150, list)).toEqual({allocations: [{invoice_id: 'a', amount: 100}, {invoice_id: 'b', amount: 50}], unallocated: 0});
    expect(m.allocateInOrder(250, list).unallocated).toBe(50);
  });
});

/* --------------------------------------------------- payment proofs -- */

describe('payment proofs', () => {
  test('parseExtraction cleans what the model returns', () => {
    const r = m.parseExtraction('```json\n{"is_payment":true,"amount":"$1,160.50","date":"2026-10-20","sender":"SEYDOU SOW","recipient":"Alluwal","confirmation":"zl8h-2k"}\n```');
    expect(r).toEqual({is_payment: true, amount: 1160.5, date: '2026-10-20', sender: 'Seydou Sow', recipient: 'Alluwal', confirmation: 'ZL8H2K'});
  });

  test('a picture without an amount is not a payment', () => {
    expect(m.parseExtraction({is_payment: true, amount: null}).is_payment).toBe(false);
    expect(m.parseExtraction('not json at all').is_payment).toBe(false);
    expect(m.parseExtraction({is_payment: false, amount: 100}).is_payment).toBe(false);
  });

  test('a repeated confirmation number is a duplicate (prototype P4)', () => {
    const first = {id: 'p1', extracted: {confirmation: 'ZL8H2K', amount: 160, sender: 'Seydou Sow', date: '2026-10-20'}};
    expect(m.findDuplicateProof({confirmation: 'zl8h2k', amount: 160}, [first])).toBe(first);
    expect(m.findDuplicateProof({confirmation: 'ZQ41MP', amount: 160}, [first])).toBeNull();
  });

  test('without a confirmation number, amount + date + sender decide', () => {
    const first = {id: 'p1', extracted: {confirmation: '', amount: 160, sender: 'Seydou Sow', date: '2026-10-20'}};
    expect(m.findDuplicateProof({confirmation: '', amount: 160, sender: 'SOW, Seydou', date: '2026-10-20'}, [first])).toBe(first);
    expect(m.findDuplicateProof({confirmation: '', amount: 160, sender: 'Seydou Sow', date: '2026-10-21'}, [first])).toBeNull();
  });

  const txn = (id, amount, date, payer, extra = {}) => ({id, direction: 'in', amount, date, payer_name: payer, description: `Zelle payment from ${payer}`, match: {status: 'suggested'}, ...extra});

  test('a screenshot finds the deposit with the same amount close in date', () => {
    const r = m.matchProofToTransaction({amount: 160, date: '2026-10-20', sender: 'Seydou Sow'}, [txn('t1', 160, '2026-10-20', 'Seydou Sow'), txn('t2', 75, '2026-10-16', 'M Diallo')]);
    expect(r.txn.id).toBe('t1');
  });

  test('nothing in the bank yet means waiting', () => {
    const r = m.matchProofToTransaction({amount: 100, date: '2026-10-21', sender: 'Cheick Kone'}, [txn('t1', 160, '2026-10-20', 'Seydou Sow')]);
    expect(r).toEqual({txn: null, ambiguous: false});
  });

  test('two equal deposits are told apart by the sender, else left ambiguous', () => {
    const list = [txn('t1', 100, '2026-10-20', 'Cheick Kone'), txn('t2', 100, '2026-10-20', 'Hawa Jalloh')];
    expect(m.matchProofToTransaction({amount: 100, date: '2026-10-20', sender: 'CHEICK KONE'}, list).txn.id).toBe('t1');
    const same = [txn('t1', 100, '2026-10-20', 'A One'), txn('t2', 100, '2026-10-20', 'B Two')];
    expect(m.matchProofToTransaction({amount: 100, date: '2026-10-20', sender: 'Unknown Person'}, same)).toEqual({txn: null, ambiguous: true});
  });

  test('a deposit already tied to a proof or already decided is skipped', () => {
    const list = [txn('t1', 160, '2026-10-20', 'Seydou Sow', {proof_id: 'p9'}), txn('t2', 160, '2026-10-20', 'Seydou Sow', {match: {status: 'confirmed'}})];
    expect(m.matchProofToTransaction({amount: 160, date: '2026-10-20', sender: 'Seydou Sow'}, list).txn).toBeNull();
  });

  test('a deposit 20 days away is not the one', () => {
    const r = m.matchProofToTransaction({amount: 160, date: '2026-10-20', sender: 'Seydou Sow'}, [txn('t1', 160, '2026-09-28', 'Seydou Sow')]);
    expect(r.txn).toBeNull();
  });
});

/* --------------------------------------------------------------- phones -- */

describe('phones', () => {
  test('US numbers match with or without the country code', () => {
    expect(m.samePhone('+1 (646) 555-0143', '16465550143')).toBe(true);
    expect(m.samePhone('646-555-0143', '+16465550143')).toBe(true);
    expect(m.samePhone('+224 621 55 01 88', '224621550188')).toBe(true);
    expect(m.samePhone('+224 621 55 01 88', '+1 646 555 0143')).toBe(false);
    expect(m.samePhone('', '')).toBe(false);
  });

  test('variants cover the usual ways a number is typed', () => {
    const v = m.phoneVariants('16465550143');
    expect(v).toEqual(expect.arrayContaining(['16465550143', '+16465550143', '6465550143', '646-555-0143', '(646) 555-0143']));
    expect(v.length).toBeLessThanOrEqual(30);
  });
});
