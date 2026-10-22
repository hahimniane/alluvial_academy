/**
 * Pure logic for the finance bank deposits screen: reading bank descriptions,
 * names, matching a deposit to invoices, matching a charge to a recurring
 * cost, WhatsApp payment-proof checks. No Firestore, no network, so it is all
 * covered by tests/finance_bank_match.test.js.
 *
 * Nothing here decides anything: every result is a SUGGESTION that an admin
 * confirms (docs/finance/SPEC.md, rule 15).
 */

const EPS = 0.005;

const r2 = (n) => Math.round((Number(n) + Number.EPSILON) * 100) / 100;
const sameMoney = (a, b) => Math.abs(Number(a) - Number(b)) < EPS;
const money = (n) => `$${Math.abs(Number(n)).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`;

/* ------------------------------------------------------------------ names -- */

const HONORIFICS = new Set(['mr', 'mrs', 'ms', 'miss', 'dr', 'mme', 'mlle', 'm', 'sr', 'jr']);

/** "  Séydou  SOW. " -> "seydou sow" */
const normalizeName = (value) =>
  String(value == null ? '' : value)
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const nameTokens = (value) =>
  normalizeName(value)
    .split(' ')
    .filter((t) => t && !(HONORIFICS.has(t) && t !== 'm'));

/**
 * Document id for known_payers: the name's words, sorted, joined by "_", so
 * "SEYDOU SOW", "Sow Seydou" and "Sow, Seydou" are one payer.
 */
const nameKey = (value) => nameTokens(value).slice().sort().join('_');

const titleCase = (value) =>
  String(value || '')
    .toLowerCase()
    .replace(/(^|[\s'-])([a-zà-ÿ])/g, (m, a, b) => a + b.toUpperCase());

/** Names a bank prints in capitals read better as "Seydou Sow". */
const prettyName = (value) => {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (!text) return '';
  return text === text.toUpperCase() || text === text.toLowerCase() ? titleCase(text) : text;
};

/* ---------------------------------------------------- bank descriptions -- */

const collapse = (value) => String(value == null ? '' : value).replace(/\s+/g, ' ').trim();

const CONFIRMATION_RE = /\b(?:conf(?:irmation)?|ref(?:erence)?|trace|trans(?:action)?\s*id)\b\s*(?:#|no\.?|number)?\s*[:#]?\s*([A-Za-z0-9]{5,})/i;

/** Where a name stops inside the text after "from". */
const NAME_END_RE = /\s+(?:for\b|on\s+\d|on\s+[A-Z][a-z]{2}\b|conf\b|confirmation\b|ref\b|reference\b|memo\b|note\b|trace\b|id\b|via\b|at\s+\d|dated\b)|[;:|"“(]|\s+#|\s+\d{4,}/i;

const OWN_TRANSFER_RE = /\b(?:online\s+)?(?:transfer|xfer)\s+(?:from|to)\s+(?:chk|sav|savings?|checking|acct|account)\b|\binternal\s+transfer\b|\bbook\s+transfer\b/i;

const unquote = (value) => collapse(String(value || '').replace(/^["“'‘\s]+|["”'’\s]+$/g, ''));

/**
 * Reads one bank line into what the matcher needs.
 *
 * Formats seen across US banks (and handled):
 *   "Zelle payment from SEYDOU SOW Conf# rtp8c2sh6"          (Bank of America)
 *   "Zelle payment from Seydou Sow for \"Oct tuition\"; Conf# 1abc2def" (Chase)
 *   "Zelle payment from SEYDOU SOW 28391002345"              (Chase, bare id)
 *   "ZELLE FROM SEYDOU SOW"                                  (generic)
 *   "Zelle From SEYDOU SOW on 10/20 Ref # WF1234567"         (Wells Fargo)
 *   "ZELLE CREDIT SEYDOU SOW"                                (credit unions)
 *   "Online Transfer from SOW, SEYDOU via Zelle"             (comma form)
 *   "Zelle Transfer Conf# 12345ab; SOW SEYDOU; INV-2026-0012" (semicolon form)
 *
 * @returns {{channel:'zelle'|'stripe'|'own_transfer'|'other', payer_name:string,
 *   memo:string, confirmation:string, auto:boolean}}
 */
const parseBankDescription = (description, memoField = '') => {
  const raw = collapse(description);
  const memoGiven = collapse(memoField);
  const out = {channel: 'other', payer_name: '', memo: memoGiven, confirmation: '', auto: false};

  if (/\bstripe\b/i.test(raw) && !/zelle/i.test(raw)) {
    return {...out, channel: 'stripe', payer_name: 'Stripe', auto: true};
  }
  if (!/zelle/i.test(raw) && OWN_TRANSFER_RE.test(raw)) {
    return {...out, channel: 'own_transfer', auto: true};
  }

  const isZelle = /zelle/i.test(raw);
  let text = raw;

  const conf = text.match(CONFIRMATION_RE);
  if (conf) {
    out.confirmation = conf[1].toUpperCase();
    text = collapse(text.replace(conf[0], ' '));
  }

  // "for "Oct tuition"" / "memo: ..." / "note: ..." / text after a semicolon.
  let memoFromText = '';
  const memoLabel = text.match(/\b(?:memo|note|message|reason)\s*[:\-]\s*(.+)$/i);
  if (memoLabel) {
    memoFromText = unquote(memoLabel[1]);
    text = collapse(text.replace(memoLabel[0], ' '));
  }
  const quoted = text.match(/["“]([^"”]+)["”]/);
  if (!memoFromText && quoted) {
    memoFromText = unquote(quoted[1]);
    text = collapse(text.replace(quoted[0], ' '));
  }
  if (text.includes(';')) {
    const parts = text.split(';').map(collapse).filter(Boolean);
    text = parts[0] || '';
    const rest = parts.slice(1).filter((p) => !/^\W*$/.test(p));
    if (!memoFromText && rest.length) memoFromText = rest.join(' ');
  }
  const forMemo = text.match(/\bfor\s+(.+)$/i);
  if (!memoFromText && forMemo) {
    memoFromText = unquote(forMemo[1]);
    text = collapse(text.replace(forMemo[0], ' '));
  }

  // A bare trailing bank reference after the name: "... SOW 28391002345".
  const bareId = text.match(/\s(\d{8,})\s*$/);
  if (bareId) {
    if (!out.confirmation) out.confirmation = bareId[1];
    text = collapse(text.replace(bareId[0], ' '));
  }

  text = text.replace(/\bvia\s+zelle\b/i, ' ').replace(/\bon\s+\d{1,2}\/\d{1,2}(?:\/\d{2,4})?/i, ' ');
  text = collapse(text);

  let name = '';
  const fromMatch = text.match(/\bfrom\b\s+(.+)$/i);
  if (fromMatch) {
    name = fromMatch[1];
  } else if (isZelle) {
    name = text.replace(/^.*?\bzelle\b/i, '').replace(/^\s*(?:payment|transfer|credit|deposit|received|recd)\b/i, '');
  }
  // Cut at the first thing that is clearly not part of a name.
  const end = name.search(NAME_END_RE);
  if (end > 0) name = name.slice(0, end);
  name = collapse(name.replace(/^\W+|\W+$/g, ''));

  // "SOW, SEYDOU" -> "SEYDOU SOW"
  const comma = name.split(',').map(collapse).filter(Boolean);
  if (comma.length === 2) name = `${comma[1]} ${comma[0]}`;
  else if (comma.length > 2) name = comma.join(' ');

  out.channel = isZelle ? 'zelle' : 'other';
  out.payer_name = prettyName(name);
  if (!out.memo) out.memo = memoFromText;
  else if (memoFromText && !out.memo.toLowerCase().includes(memoFromText.toLowerCase())) out.memo = `${out.memo} ${memoFromText}`;
  return out;
};

/* ----------------------------------------------------------------- months -- */

const MONTH_WORDS = {
  january: 1, jan: 1, janvier: 1, janv: 1,
  february: 2, feb: 2, fevrier: 2, fev: 2, fevr: 2,
  march: 3, mar: 3, mars: 3,
  april: 4, apr: 4, avril: 4, avr: 4,
  may: 5, mai: 5,
  june: 6, jun: 6, juin: 6,
  july: 7, jul: 7, juillet: 7, juil: 7,
  august: 8, aug: 8, aout: 8,
  september: 9, sep: 9, sept: 9, septembre: 9,
  october: 10, oct: 10, octobre: 10,
  november: 11, nov: 11, novembre: 11,
  december: 12, dec: 12, decembre: 12,
};

/** Month numbers named in a memo ("Sept + Oct" -> [9, 10]). */
const monthsNamedIn = (text) => {
  const found = [];
  for (const word of normalizeName(text).split(' ')) {
    const n = MONTH_WORDS[word];
    if (n && !found.includes(n)) found.push(n);
  }
  return found;
};

const monthNumber = (month) => Number(String(month || '').split('-')[1]) || 0;

const monthOfDateString = (date) => String(date || '').slice(0, 7);

const daysBetween = (a, b) => {
  const ms = (d) => {
    const [y, m, day] = String(d).slice(0, 10).split('-').map(Number);
    return Date.UTC(y, (m || 1) - 1, day || 1);
  };
  return Math.round((ms(a) - ms(b)) / 86400000);
};

/* ---------------------------------------------------------- invoice parts -- */

/** "INV-2026-0012", "inv 2026 12" and "INV20260012" are the same invoice. */
const invoiceKey = (value) => {
  const m = String(value || '').toUpperCase().match(/INV\W*(\d{4})\W*0*(\d{1,8})/);
  return m ? `INV${m[1]}-${parseInt(m[2], 10)}` : '';
};

const invoiceKeysIn = (text) => {
  const out = [];
  const re = /INV\W*\d{4}\W*\d{1,8}/gi;
  let m;
  while ((m = re.exec(String(text || ''))) !== null) {
    const key = invoiceKey(m[0]);
    if (key && !out.includes(key)) out.push(key);
  }
  return out;
};

const byOldest = (a, b) =>
  String(a.month || '').localeCompare(String(b.month || '')) || String(a.due || '').localeCompare(String(b.due || '')) || String(a.id).localeCompare(String(b.id));

/** Spreads `amount` across invoices in order, never above a balance. */
const allocateInOrder = (amount, invoices) => {
  let left = r2(amount);
  const allocations = [];
  for (const inv of invoices) {
    if (left <= EPS) break;
    const part = r2(Math.min(left, inv.balance));
    if (part <= EPS) continue;
    allocations.push({invoice_id: inv.id, amount: part});
    left = r2(left - part);
  }
  return {allocations, unallocated: Math.max(0, left)};
};

const labelOf = (inv) => `${inv.number || inv.id}`;

/* ------------------------------------------------------------- deposits -- */

const emptyMatch = (why, extra = {}) => ({
  status: 'none', level: 'none', kind: 'none', why, allocations: [], unallocated: 0,
  parent_id: null, new_payer: false, payer_key: '', candidates: [], ...extra,
});

/**
 * Suggests which invoices a deposit pays.
 *
 * @param {{amount:number, description:string, memo?:string, payer_name?:string, date?:string}} txn  amount > 0
 * @param {{
 *   invoices: Array<{id:string, number:string, parent_id:string, balance:number, month:string, due?:string, student_names?:string[]}>,
 *   parents: Record<string, {names:string[], surnames:string[]}>,
 *   knownPayers: Record<string, {parent_id:string}>,
 *   hintParentId?: string
 * }} ctx  `invoices` are the UNPAID ones.
 *
 * Levels: exact (invoice number in the memo, or a known payer paying exactly a
 * balance), split (one amount covering several months), likely (name and amount
 * agree), none.
 */
const matchDeposit = (txn, ctx) => {
  const amount = r2(txn.amount);
  const parsed = parseBankDescription(txn.description, txn.memo);
  const payerName = txn.payer_name || parsed.payer_name;
  const memo = txn.memo || parsed.memo || '';
  const text = `${txn.description || ''} ${memo}`;
  const payerKey = nameKey(payerName);
  const unpaid = (ctx.invoices || []).filter((i) => i.balance > EPS).sort(byOldest);
  const knownPayers = ctx.knownPayers || {};
  const parents = ctx.parents || {};
  const knownEntry = payerKey ? knownPayers[payerKey] : null;
  const isKnownPayer = Boolean(knownEntry && knownEntry.parent_id);
  const newPayerFlag = (parentId) => Boolean(payerKey) && !(isKnownPayer && knownEntry.parent_id === parentId);

  if (!(amount > EPS)) return emptyMatch('There is no amount to match');
  if (parsed.auto) return {...emptyMatch(parsed.channel === 'stripe' ? 'Card payments, already recorded from Stripe' : 'Transfer between Alluwal accounts'), status: 'auto', level: 'auto', kind: parsed.channel};

  /* 1. An invoice number in the memo is the strongest signal. */
  const named = invoiceKeysIn(text)
    .map((key) => unpaid.find((i) => invoiceKey(i.number) === key))
    .filter(Boolean);
  if (named.length) {
    const first = allocateInOrder(amount, named);
    let allocations = first.allocations;
    let unallocated = first.unallocated;
    let extended = false;
    if (unallocated > EPS && named.every((i) => i.parent_id === named[0].parent_id)) {
      const others = unpaid.filter((i) => i.parent_id === named[0].parent_id && !named.includes(i));
      const more = allocateInOrder(unallocated, others);
      if (more.allocations.length) {
        allocations = allocations.concat(more.allocations);
        unallocated = more.unallocated;
        extended = true;
      }
    }
    const coversNamedFully = !extended && unallocated <= EPS && allocations.every((a) => sameMoney(a.amount, named.find((i) => i.id === a.invoice_id).balance));
    const parentId = named[0].parent_id;
    if (coversNamedFully) {
      return {
        status: 'suggested', level: 'exact', kind: 'invoice_number', allocations, unallocated: 0, parent_id: parentId,
        new_payer: newPayerFlag(parentId), payer_key: payerKey, candidates: [],
        why: `The memo has the invoice number ${named.map(labelOf).join(' and ')}`,
      };
    }
    if (extended && unallocated <= EPS) {
      return {
        status: 'suggested', level: 'split', kind: 'invoice_number', allocations, unallocated: 0, parent_id: parentId,
        new_payer: newPayerFlag(parentId), payer_key: payerKey, candidates: [],
        why: `The memo has the invoice number ${named.map(labelOf).join(' and ')}, and the amount also covers the other unpaid months`,
      };
    }
    const part = unallocated > EPS
      ? `${money(unallocated)} more than ${labelOf(named[0])} and the family's other unpaid invoices`
      : `${money(amount)} is less than the ${money(named.reduce((s, i) => s + i.balance, 0))} balance`;
    return {
      status: 'suggested', level: 'likely', kind: 'invoice_number', allocations, unallocated, parent_id: parentId,
      new_payer: newPayerFlag(parentId), payer_key: payerKey, candidates: [],
      why: `The memo has the invoice number ${named.map(labelOf).join(' and ')}, but ${part}`,
    };
  }

  /* 2. Which family? A known payer (or a family linked by the parent's own
   *    WhatsApp number) is certain; a surname or a student's name is a guess. */
  let strength = null;
  let candidateParents = [];
  if (ctx.hintParentId) {
    strength = 'known';
    candidateParents = [ctx.hintParentId];
  } else if (isKnownPayer) {
    strength = 'known';
    candidateParents = [knownEntry.parent_id];
  } else {
    const payerTokens = new Set(nameTokens(payerName).filter((t) => t.length >= 3));
    const memoTokens = new Set(nameTokens(memo));
    const hits = [];
    for (const parentId of new Set(unpaid.map((i) => i.parent_id))) {
      const p = parents[parentId];
      if (!p) continue;
      const surnameHit = (p.surnames || []).some((s) => s.length >= 3 && payerTokens.has(s));
      const studentHit = unpaid
        .filter((i) => i.parent_id === parentId)
        .some((i) => (i.student_names || []).some((n) => {
          const toks = nameTokens(n);
          if (toks.length === 0) return false;
          const first = toks[0];
          const last = toks[toks.length - 1];
          return (first.length >= 3 && memoTokens.has(first) && (toks.length === 1 || memoTokens.has(last) || payerTokens.has(last))) ||
            (last.length >= 3 && payerTokens.has(last));
        }));
      if (surnameHit || studentHit) hits.push(parentId);
    }
    if (hits.length) {
      strength = 'name';
      candidateParents = hits;
    }
  }

  if (!candidateParents.length) {
    return emptyMatch(`No family with this name owes ${money(amount)}`, {payer_key: payerKey});
  }

  /* 3. For each candidate family, does the amount fit its unpaid invoices? */
  const memoMonths = monthsNamedIn(memo);
  const evaluate = (parentId) => {
    const mine = unpaid.filter((i) => i.parent_id === parentId);
    if (!mine.length) return null;
    // One invoice that equals the amount (prefer the month the memo names, else the oldest).
    const singles = mine.filter((i) => sameMoney(i.balance, amount));
    if (singles.length) {
      const byMemo = singles.find((i) => memoMonths.includes(monthNumber(i.month)));
      const pick = byMemo || singles[0];
      const ambiguous = singles.length > 1 && !byMemo;
      return {
        kind: 'balance', parentId, ambiguous,
        allocations: [{invoice_id: pick.id, amount}], unallocated: 0,
        detail: sameMoney(pick.balance, pick.total == null ? pick.balance : pick.total)
          ? `${money(amount)} is the ${pick.number || pick.id} amount`
          : `${money(amount)} is exactly the rest of the ${pick.number || pick.id} balance`,
        pick, singles,
      };
    }
    // Oldest-first runs that add up exactly ("Sept + Oct").
    let run = 0;
    for (let n = 0; n < mine.length; n++) {
      run = r2(run + mine[n].balance);
      if (n >= 1 && sameMoney(run, amount)) {
        const slice = mine.slice(0, n + 1);
        return {
          kind: 'split', parentId, ambiguous: false,
          allocations: slice.map((i) => ({invoice_id: i.id, amount: i.balance})), unallocated: 0,
          detail: `Covers ${slice.length} unpaid months, so it is split across their invoices`, pick: slice[0], singles: [],
        };
      }
    }
    // A known payer may pay part, or more than, what is open.
    if (strength === 'known') {
      const spread = allocateInOrder(amount, mine);
      if (spread.allocations.length) {
        return {
          kind: 'partial', parentId, ambiguous: false, allocations: spread.allocations, unallocated: spread.unallocated,
          detail: spread.unallocated > EPS
            ? `${money(spread.unallocated)} more than everything this family owes`
            : `${money(amount)} is less than the ${money(mine[0].balance)} balance of ${mine[0].number || mine[0].id}`,
          pick: mine[0], singles: [],
        };
      }
    }
    return null;
  };

  const results = candidateParents.map(evaluate).filter(Boolean);
  if (!results.length) {
    return emptyMatch(`No family with this name owes ${money(amount)}`, {payer_key: payerKey});
  }
  if (results.length > 1) {
    return emptyMatch(`More than one family with this name has ${money(amount)} to pay. Pick the right invoice.`, {
      payer_key: payerKey,
      candidates: results.flatMap((r) => r.allocations.map((a) => a.invoice_id)),
    });
  }

  const hit = results[0];
  const familyName = (parents[hit.parentId] && parents[hit.parentId].names[0]) || '';
  const family = familyName ? `the ${familyName} family` : 'this family';
  const payerLabel = prettyName(payerName) || 'The sender';
  const lower = (text) => `${text.charAt(0).toLowerCase()}${text.slice(1)}`;

  let level;
  if (hit.kind === 'split') level = 'split';
  else if (hit.kind === 'balance' && strength === 'known' && !hit.ambiguous) level = 'exact';
  else level = 'likely';

  let why;
  if (ctx.hintParentId && !isKnownPayer) {
    why = `The parent sent the payment screenshot from a number saved to ${family}. ${hit.detail}`;
  } else if (strength === 'known') {
    why = hit.kind === 'balance' && !hit.ambiguous
      ? `${payerLabel} is a known payer for ${family}, and ${lower(hit.detail)}`
      : `${payerLabel} is a known payer for ${family}. ${hit.ambiguous ? 'Two months have the same amount, so it goes to the oldest' : hit.detail}`;
  } else {
    const studentNamed = unpaid
      .filter((i) => i.parent_id === hit.parentId)
      .some((i) => (i.student_names || []).some((n) => nameTokens(memo).includes(nameTokens(n)[0] || '~')));
    why = hit.kind === 'split'
      ? `${hit.detail}. ${payerLabel} has not paid before.`
      : `The amount matches${studentNamed ? ' and the memo names the student' : ''}. ${payerLabel} has not paid before.`;
  }
  return {
    status: 'suggested', level, kind: hit.kind, why,
    allocations: hit.allocations, unallocated: hit.unallocated, parent_id: hit.parentId,
    new_payer: newPayerFlag(hit.parentId), payer_key: payerKey, candidates: [],
  };
};

/* --------------------------------------------------------------- charges -- */

const CHARGE_NOISE = new Set([
  'payment', 'purchase', 'pos', 'debit', 'card', 'recurring', 'www', 'http', 'https', 'inc', 'llc', 'ltd', 'the', 'online', 'autopay',
  'ach', 'web', 'id', 'com', 'net', 'org', 'io', 'us', 'co', 'pmt', 'ppd', 'ccd', 'chk', 'check', 'visa', 'mastercard', 'tst',
  'sq', 'paypal', 'checkcard', 'withdrawal',
]);
const COST_NOISE = new Set([
  'licence', 'licences', 'license', 'licenses', 'subscription', 'subscriptions', 'plan', 'monthly', 'annual', 'yearly', 'bill',
  'fee', 'fees', 'account', 'service', 'services', 'the', 'and', 'for', 'of', 'per', 'month', 'seats', 'seat', 'users', 'user',
]);

const chargeTokens = (description) =>
  normalizeName(String(description || '').replace(/\.(?:com|net|org|io|us|co)\b/gi, ' '))
    .split(' ')
    .filter((t) => t.length >= 3 && !/^\d+$/.test(t) && !CHARGE_NOISE.has(t));

const costTokens = (name) =>
  normalizeName(name)
    .split(' ')
    .filter((t) => t.length >= 3 && !/^\d+$/.test(t) && !COST_NOISE.has(t));

const tokenHit = (a, b) => a === b || (Math.min(a.length, b.length) >= 4 && (a.startsWith(b) || b.startsWith(a)));

/** 0..1: how much of a recurring cost's name appears in the bank line. */
const chargeNameScore = (description, costName) => {
  const want = costTokens(costName);
  if (!want.length) return 0;
  const have = chargeTokens(description);
  const hits = want.filter((w) => have.some((h) => tokenHit(h, w))).length;
  return hits / want.length;
};

/**
 * Suggests which recurring cost an outgoing charge pays.
 *
 * @param {{amount:number, date:string, description:string}} txn  amount < 0 or positive outflow size in `out`
 * @param {{costs: Array<{id:string, name:string, amount:number, start_month?:string, end_month?:string|null}>,
 *          confirmations?: Record<string, {amount:number}>}} ctx  confirmations keyed `${month}_${costId}`
 */
const matchCharge = (txn, ctx) => {
  const parsed = parseBankDescription(txn.description, txn.memo);
  if (parsed.auto) {
    return {...emptyMatch(parsed.channel === 'stripe' ? 'Stripe, already recorded' : 'Transfer between Alluwal accounts'), status: 'auto', level: 'auto', kind: parsed.channel};
  }
  const amount = r2(Math.abs(txn.amount));
  const month = monthOfDateString(txn.date);
  let best = null;
  for (const cost of ctx.costs || []) {
    if (cost.start_month && month && cost.start_month > month) continue;
    if (cost.end_month && month && cost.end_month < month) continue;
    const score = chargeNameScore(txn.description, cost.name);
    const need = costTokens(cost.name).length >= 2 ? 0.67 : 1;
    if (score + 1e-9 < need) continue;
    const amountClose = cost.amount ? 1 - Math.min(1, Math.abs(cost.amount - amount) / Math.max(cost.amount, 1)) : 0;
    const rank = score * 10 + amountClose;
    if (!best || rank > best.rank) best = {cost, score, rank};
  }
  if (!best) return emptyMatch('Not matched to a recurring cost', {kind: 'charge'});
  const confirmed = (ctx.confirmations || {})[`${month}_${best.cost.id}`];
  if (confirmed && sameMoney(confirmed.amount, amount)) {
    return {
      ...emptyMatch(`Matched to ${best.cost.name} for this month`), status: 'auto', level: 'auto', kind: 'recurring',
      recurring_cost_id: best.cost.id, recurring_cost_name: best.cost.name,
    };
  }
  const note = confirmed
    ? `${best.cost.name} is confirmed at ${money(confirmed.amount)}; the bank charged ${money(amount)}`
    : `Looks like the ${best.cost.name} bill for this month`;
  return {
    ...emptyMatch(note), status: 'suggested', level: 'likely', kind: 'recurring',
    recurring_cost_id: best.cost.id, recurring_cost_name: best.cost.name,
  };
};

/* -------------------------------------------------------- payment proofs -- */

/** What Gemini returns for a screenshot, made safe to store. */
const parseExtraction = (raw) => {
  let obj = raw;
  if (typeof raw === 'string') {
    const cleaned = raw.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
    try {
      obj = JSON.parse(cleaned);
    } catch (e) {
      const m = cleaned.match(/\{[\s\S]*\}/);
      try {
        obj = m ? JSON.parse(m[0]) : null;
      } catch (e2) {
        obj = null;
      }
    }
  }
  if (!obj || typeof obj !== 'object') return {is_payment: false, amount: null, date: '', sender: '', recipient: '', confirmation: ''};
  const amountRaw = typeof obj.amount === 'string' ? Number(obj.amount.replace(/[^0-9.\-]/g, '')) : Number(obj.amount);
  const amount = Number.isFinite(amountRaw) && amountRaw > 0 ? r2(amountRaw) : null;
  const dateText = String(obj.date || '').trim();
  const iso = dateText.match(/^(\d{4})-(\d{2})-(\d{2})/);
  const confirmation = String(obj.confirmation || '').replace(/[^A-Za-z0-9]/g, '').toUpperCase();
  const isPayment = (obj.is_payment === true || String(obj.is_payment).toLowerCase() === 'true') && amount != null;
  return {
    is_payment: isPayment,
    amount,
    date: iso ? `${iso[1]}-${iso[2]}-${iso[3]}` : '',
    sender: prettyName(collapse(obj.sender)),
    recipient: collapse(obj.recipient),
    confirmation,
  };
};

/**
 * The same screenshot sent twice. Same confirmation number is the test; with
 * no confirmation on either, same amount, date and sender.
 */
const findDuplicateProof = (extracted, others) => {
  const conf = String(extracted.confirmation || '').toUpperCase();
  for (const other of others || []) {
    const o = other.extracted || {};
    if (conf.length >= 4 && String(o.confirmation || '').toUpperCase() === conf) return other;
    if (!conf && !o.confirmation && extracted.amount != null && sameMoney(o.amount, extracted.amount) &&
        extracted.date && o.date === extracted.date && nameKey(o.sender) && nameKey(o.sender) === nameKey(extracted.sender)) {
      return other;
    }
  }
  return null;
};

const sharesName = (a, b) => {
  const A = new Set(nameTokens(a).filter((t) => t.length >= 3));
  return nameTokens(b).some((t) => t.length >= 3 && A.has(t));
};

/**
 * Looks for the bank deposit a screenshot is about.
 *
 * @returns {{txn:object|null, ambiguous:boolean}}
 */
const matchProofToTransaction = (extracted, txns, {sentOn} = {}) => {
  if (extracted.amount == null) return {txn: null, ambiguous: false};
  const anchor = extracted.date || sentOn || '';
  let candidates = (txns || []).filter((t) =>
    t.direction === 'in' && !t.proof_id && sameMoney(t.amount, extracted.amount) &&
    !['confirmed', 'manual', 'ignored'].includes(t.match && t.match.status) &&
    (!anchor || !t.date || Math.abs(daysBetween(t.date, anchor)) <= 5));
  if (candidates.length > 1 && extracted.sender) {
    const named = candidates.filter((t) => sharesName(t.payer_name || t.description, extracted.sender));
    if (named.length) candidates = named;
  }
  if (candidates.length === 1) return {txn: candidates[0], ambiguous: false};
  return {txn: null, ambiguous: candidates.length > 1};
};

/* ---------------------------------------------------------------- phones -- */

const phoneDigits = (value) => {
  let digits = String(value || '').replace(/\D/g, '');
  if (String(value || '').trim().startsWith('00')) digits = digits.slice(2);
  return digits;
};

/** US numbers arrive as 10 digits or 1 + 10; everything else is already international. */
const canonicalPhone = (value) => {
  const d = phoneDigits(value);
  return d.length === 10 ? `1${d}` : d;
};

const samePhone = (a, b) => {
  const x = canonicalPhone(a);
  const y = canonicalPhone(b);
  return Boolean(x) && x === y;
};

/** The ways a phone number might be written on a user document, for `in` queries. */
const phoneVariants = (value) => {
  const c = canonicalPhone(value);
  if (!c) return [];
  const out = new Set([c, `+${c}`]);
  if (c.length === 11 && c.startsWith('1')) {
    const n = c.slice(1);
    const a = n.slice(0, 3);
    const b = n.slice(3, 6);
    const d = n.slice(6);
    [n, `+1${n}`, `1${n}`, `${a}-${b}-${d}`, `(${a}) ${b}-${d}`, `(${a})${b}-${d}`, `${a} ${b} ${d}`, `${a}.${b}.${d}`, `+1 ${a} ${b} ${d}`, `+1 (${a}) ${b}-${d}`, `+1-${a}-${b}-${d}`, `1-${a}-${b}-${d}`].forEach((v) => out.add(v));
  }
  return [...out].slice(0, 30);
};

module.exports = {
  EPS,
  r2,
  sameMoney,
  money,
  normalizeName,
  nameTokens,
  nameKey,
  titleCase,
  prettyName,
  parseBankDescription,
  monthsNamedIn,
  monthOfDateString,
  daysBetween,
  invoiceKey,
  invoiceKeysIn,
  byOldest,
  allocateInOrder,
  matchDeposit,
  chargeNameScore,
  matchCharge,
  parseExtraction,
  findDuplicateProof,
  matchProofToTransaction,
  phoneDigits,
  canonicalPhone,
  samePhone,
  phoneVariants,
};
