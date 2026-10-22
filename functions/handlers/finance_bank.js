/**
 * Finance: bank deposits (Plaid) and WhatsApp payment proofs.
 *
 * Both features are INACTIVE until Alluwal opens the accounts. With no
 * Plaid / WhatsApp secret every entry point here reports "not connected" and
 * does nothing: no error, no write (utils/finance_secrets.js).
 *
 * Rule 15 of docs/finance/SPEC.md: a screenshot never marks an invoice paid; a
 * bank deposit confirmed by an admin does. Nothing in this file records a
 * payment except `confirmTransaction`, and only `decideBankMatch` /
 * `decidePaymentProof` (admin callables) reach it.
 *
 * Collections: bank_transactions, known_payers, payment_proofs (SPEC.md),
 * plus two server-only ones: finance_private/plaid (the Plaid access token and
 * sync cursor; rules deny every client) and known_phones/{digits} (a parent's
 * WhatsApp number -> parent_id).
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const {onRequest} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const secrets = require('../utils/finance_secrets');
const match = require('../utils/finance_bank_match');
const {invoiceMonthOf: sharedInvoiceMonthOf} = require('../utils/finance_invoice_month');
const {displayName} = require('../utils/parent_link');
const {normalizePhone} = require('./class_contacts');

const COL = {
  settings: 'finance_settings',
  private: 'finance_private',
  txns: 'bank_transactions',
  payers: 'known_payers',
  proofs: 'payment_proofs',
  phones: 'known_phones',
  invoices: 'invoices',
  recurringCosts: 'finance_recurring_costs',
  confirmations: 'finance_recurring_confirmations',
  users: 'users',
};

const GRAPH = 'https://graph.facebook.com/v21.0';
const GEMINI_MODELS = ['gemini-3.5-flash', 'gemini-flash-latest', 'gemini-3.1-flash-lite'];
const geminiUrl = (model) => `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const SYNC_LOCK_MS = 4 * 60 * 1000;
const SYNC_PAGE_LIMIT = 20;

/* ------------------------------------------------------------------ deps -- */

const deps = {
  fetch: (...args) => fetch(...args),
  getSecret: (name) => secrets.getSecret(name),
  now: () => new Date(),
  bucket: () => admin.storage().bucket(),
  assertMonthOpen: async (db, month) => {
    let lock = null;
    try {
      // Owned by the overview branch; used by path as agreed.
      lock = require('../utils/finance_lock');
    } catch (e) {
      if (e.code !== 'MODULE_NOT_FOUND') throw e;
    }
    if (lock && typeof lock.assertMonthOpen === 'function') return lock.assertMonthOpen(db, month);
    const snap = await db.collection('finance_months').doc(month).get();
    if (snap.exists && snap.data().status === 'closed') {
      throw new functions.https.HttpsError('failed-precondition', `${month} is closed. An owner has to reopen it first.`);
    }
    return undefined;
  },
  recordPayment: (db, opts) => require('./payments').recordManualPaymentCore(db, opts),
};

/** Tests replace the network, clock, storage and payment recorder. */
const __setDeps = (overrides) => Object.assign(deps, overrides);

/* --------------------------------------------------------------- helpers -- */

const HttpsError = (code, message) => new functions.https.HttpsError(code, message);

const db = () => admin.firestore();
const serverTime = () => admin.firestore.FieldValue.serverTimestamp();
const record = (v) => (v && typeof v === 'object' && !Array.isArray(v) ? v : {});
const text = (v) => (typeof v === 'string' ? v.trim() : '');
const num = (v) => {
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : 0;
};
const toDate = (v) => {
  if (!v) return null;
  if (typeof v.toDate === 'function') return v.toDate();
  if (v instanceof Date) return v;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};
const chunk = (arr, size) => {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
};

const NY = 'America/New_York';
const nyParts = (date) => {
  const parts = new Intl.DateTimeFormat('en-CA', {timeZone: NY, year: 'numeric', month: '2-digit', day: '2-digit'}).formatToParts(date);
  const pick = (t) => parts.find((p) => p.type === t).value;
  return {y: pick('year'), m: pick('month'), d: pick('day')};
};
const nyDate = (date) => {
  const p = nyParts(date);
  return `${p.y}-${p.m}-${p.d}`;
};
const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const monthName = (month) => MONTH_NAMES[Number(String(month).split('-')[1]) - 1] || String(month);

/** Shared month rule (utils/finance_invoice_month.js); '' when unknown. */
const invoiceMonthOf = (data) => sharedInvoiceMonthOf(data) || '';

const safeId = (value) => String(value).replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 120);

const settingsRef = (database) => database.collection(COL.settings).doc('main');
const privateRef = (database) => database.collection(COL.private).doc('plaid');

const loadSettings = async (database) => {
  const snap = await settingsRef(database).get();
  return snap.exists ? snap.data() || {} : {};
};

const safeEqual = (a, b) => {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
};

const verifyAdmin = (request) => verifyCallableCallerIsAdmin(request);

/* -------------------------------------------------------------- Plaid API -- */

const plaidCall = async (creds, path, body) => {
  const res = await deps.fetch(`${creds.host}${path}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({client_id: creds.clientId, secret: creds.secret, ...body}),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(json.error_message || `Plaid ${path} failed (${res.status})`);
    err.plaid = json;
    err.status = res.status;
    throw err;
  }
  return json;
};

const plaidCreds = () => secrets.plaidCredentials((n) => deps.getSecret(n));
const whatsappCreds = () => secrets.whatsappCredentials((n) => deps.getSecret(n));

const NOT_CONNECTED_PLAID = 'Bank connection is not set up yet. See docs/finance/BANK_AND_WHATSAPP_SETUP.md.';

/* ---------------------------------------------------------- match context -- */

const parentSurnames = (data) => {
  const last = match.nameTokens(data.last_name || '').filter((t) => t.length >= 3);
  if (last.length) return last;
  const all = match.nameTokens(displayName(data));
  return all.length > 1 ? [all[all.length - 1]].filter((t) => t.length >= 3) : [];
};

/**
 * Everything the matcher needs, read once per run: unpaid invoices with their
 * families, known payers, recurring costs and this/last month's confirmations.
 */
const loadMatchContext = async (database, {months = []} = {}) => {
  const invSnap = await database.collection(COL.invoices)
    .where('status', 'in', ['pending', 'overdue', 'partial', 'partially_paid', 'sent', 'unpaid'])
    .limit(2000)
    .get();
  const rows = [];
  const userIds = new Set();
  invSnap.forEach((doc) => {
    const d = doc.data() || {};
    const total = num(d.total_amount ?? d.totalAmount);
    const paid = num(d.paid_amount ?? d.paidAmount);
    const balance = match.r2(total - paid);
    if (balance <= match.EPS) return;
    const parentId = text(d.parent_id || d.parentId);
    if (!parentId) return;
    const studentIds = [text(d.student_id || d.studentId), ...(Array.isArray(d.student_ids) ? d.student_ids.map(text) : [])].filter(Boolean);
    userIds.add(parentId);
    studentIds.forEach((s) => userIds.add(s));
    const due = toDate(d.due_date);
    rows.push({
      id: doc.id,
      number: text(d.invoice_number || d.invoiceNumber) || doc.id,
      parent_id: parentId,
      balance,
      total,
      month: invoiceMonthOf(d),
      due: due ? nyDate(due) : '',
      student_ids: [...new Set(studentIds)],
      student_names: [],
    });
  });

  const users = {};
  for (const ids of chunk([...userIds], 300)) {
    const snaps = await database.getAll(...ids.map((id) => database.collection(COL.users).doc(id)));
    snaps.forEach((s) => {
      if (s.exists) users[s.id] = s.data() || {};
    });
  }
  rows.forEach((r) => {
    r.student_names = r.student_ids.map((id) => displayName(users[id])).filter(Boolean);
  });
  const parents = {};
  for (const r of rows) {
    if (parents[r.parent_id]) continue;
    const u = users[r.parent_id] || {};
    const full = displayName(u);
    parents[r.parent_id] = {names: [full || r.parent_id], surnames: parentSurnames(u)};
  }

  const knownPayers = {};
  const payersSnap = await database.collection(COL.payers).limit(2000).get();
  payersSnap.forEach((d) => {
    knownPayers[d.id] = d.data() || {};
  });

  const costs = [];
  const costsSnap = await database.collection(COL.recurringCosts).limit(300).get();
  costsSnap.forEach((d) => {
    const c = d.data() || {};
    costs.push({id: d.id, name: text(c.name), amount: num(c.amount), start_month: text(c.start_month), end_month: text(c.end_month) || null});
  });
  const confirmations = {};
  for (const month of [...new Set(months.filter(Boolean))]) {
    const snap = await database.collection(COL.confirmations).where('month', '==', month).get();
    snap.forEach((d) => {
      confirmations[d.id] = {amount: num(d.data().amount)};
    });
  }
  return {invoices: rows, parents, knownPayers, costs, confirmations};
};

/** Invoice number, month and family beside each allocation, for the page. */
const labelAllocations = (allocations, ctx) => {
  const byId = new Map(((ctx && ctx.invoices) || []).map((i) => [i.id, i]));
  return (allocations || []).map((a) => {
    const inv = byId.get(a.invoice_id);
    if (!inv) return a;
    const parent = (ctx.parents && ctx.parents[inv.parent_id]) || {names: []};
    return {...a, number: inv.number, month: inv.month, family: parent.names[0] || '', student: (inv.student_names || [])[0] || ''};
  });
};

/** The `match` field stored on a bank transaction, from the matcher's answer. */
const toMatchField = (r, ctx) => {
  const base = {
    status: r.status,
    level: r.level,
    kind: r.kind || 'none',
    why: r.why || '',
    allocations: labelAllocations(r.allocations, ctx),
    unallocated: r.unallocated || 0,
    parent_id: r.parent_id || null,
    new_payer: Boolean(r.new_payer),
    payer_key: r.payer_key || '',
    candidates: r.candidates || [],
    recurring_cost_id: r.recurring_cost_id || null,
    recurring_cost_name: r.recurring_cost_name || '',
  };
  if (r.status === 'auto') {
    // Nothing for a person to do: Stripe / own transfers are "not tuition";
    // a charge already confirmed as a recurring cost stays confirmed.
    return {...base, status: r.kind === 'recurring' ? 'confirmed' : 'ignored', level: 'auto'};
  }
  return base;
};

const needsAction = (m, direction) => m.status === 'suggested' || (m.status === 'none' && direction === 'in');

const suggest = (txn, ctx, extra = {}) =>
  txn.direction === 'out'
    ? match.matchCharge({amount: txn.amount, date: txn.date, description: txn.description, memo: txn.memo}, ctx)
    : match.matchDeposit({amount: txn.amount, description: txn.description, memo: txn.memo, payer_name: txn.payer_name, date: txn.date}, {...ctx, ...extra});

const isUndecided = (txn) => !txn.match || ['none', 'suggested'].includes(txn.match.status);

/** Runs the matcher on stored transactions and saves what it finds. */
const matchTransactions = async (database, docs, ctx) => {
  let changed = 0;
  for (const doc of docs) {
    const txn = doc.data();
    if (!isUndecided(txn) || txn.removed) continue;
    const hint = txn.proof_parent_id || undefined;
    const field = toMatchField(suggest(txn, ctx, hint ? {hintParentId: hint} : {}), ctx);
    await doc.ref.update({match: field, needs_action: needsAction(field, txn.direction), matched_at: serverTime()});
    changed += 1;
  }
  return changed;
};

/* ----------------------------------------------------------------- phones -- */

const PHONE_SCAN_MS = 10 * 60 * 1000;
let phoneScan = {at: 0, rows: []};

const isParentish = (u) => {
  const roles = [u.user_type, u.userType, u.role].map((r) => String(r || '').toLowerCase());
  return roles.includes('parent') || roles.includes('guardian') ||
    (Array.isArray(u.secondary_roles) && u.secondary_roles.map((r) => String(r).toLowerCase()).includes('parent'));
};

const phoneOf = (u) => {
  const p = normalizePhone(u);
  return p ? match.canonicalPhone(p.tel) : '';
};

/**
 * Which parent owns a WhatsApp number? known_phones first (learned or saved by
 * an admin), then the users' phone_number in its usual spellings, then a
 * cached scan of parent accounts.
 */
const findParentByPhone = async (database, rawFrom) => {
  const canonical = match.canonicalPhone(rawFrom);
  if (!canonical) return null;

  const known = await database.collection(COL.phones).doc(canonical).get();
  if (known.exists && known.data().parent_id) {
    const k = known.data();
    return {parent_id: k.parent_id, name: k.name || ''};
  }
  const found = (id, data, source) => ({parent_id: id, name: displayName(data), source});
  // A number shared by two accounts (a mother's phone on two profiles) is not
  // a safe guess: leave it for an admin to link.
  const settle = async (hits, source) => {
    const ids = [...new Set(hits.map((h) => h.id))];
    if (ids.length !== 1) return null;
    const hit = found(hits[0].id, hits[0].data, source);
    await rememberPhone(database, canonical, hit.parent_id, hit.name, 'auto').catch(() => {});
    return hit;
  };

  const variants = match.phoneVariants(canonical);
  if (variants.length) {
    const snap = await database.collection(COL.users).where('phone_number', 'in', variants).limit(20).get();
    const hits = snap.docs.map((d) => ({id: d.id, data: d.data() || {}})).filter((h) => isParentish(h.data) && phoneOf(h.data) === canonical);
    if (hits.length) return settle(hits, 'variants');
  }
  if (Date.now() - phoneScan.at > PHONE_SCAN_MS) {
    const rows = [];
    const snap = await database.collection(COL.users).where('user_type', 'in', ['parent', 'guardian']).limit(3000).get();
    snap.forEach((d) => {
      const u = d.data() || {};
      const phone = phoneOf(u);
      if (phone) rows.push({id: d.id, phone, data: u});
    });
    phoneScan = {at: Date.now(), rows};
  }
  const hits = phoneScan.rows.filter((r) => r.phone === canonical);
  return hits.length ? settle(hits, 'scan') : null;
};

const rememberPhone = async (database, rawFrom, parentId, name, source, byUid) =>
  database.collection(COL.phones).doc(match.canonicalPhone(rawFrom)).set({
    parent_id: parentId, name: name || '', source, phone: `+${match.canonicalPhone(rawFrom)}`,
    linked_at: serverTime(), ...(byUid ? {linked_by: byUid} : {}),
  });

/* -------------------------------------------------------------- WhatsApp -- */

const sendWhatsAppText = async (creds, to, body) => {
  const res = await deps.fetch(`${GRAPH}/${creds.phoneNumberId}/messages`, {
    method: 'POST',
    headers: {Authorization: `Bearer ${creds.token}`, 'Content-Type': 'application/json'},
    body: JSON.stringify({messaging_product: 'whatsapp', to: match.phoneDigits(to), type: 'text', text: {body}}),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`WhatsApp send failed (${res.status}): ${JSON.stringify(json).slice(0, 200)}`);
  return json.messages && json.messages[0] ? json.messages[0].id : '';
};

/**
 * Replies to a parent only when the owner turned parent messages on. The
 * reply is logged on the proof (the admin's chat panel shows what was sent).
 */
const replyToParent = async (database, proofRef, to, body) => {
  try {
    const settings = await loadSettings(database);
    if (settings.parent_messages_enabled !== true) return false;
    const creds = await whatsappCreds();
    if (!creds) return false;
    const id = await sendWhatsAppText(creds, to, body);
    await proofRef.update({
      replies: admin.firestore.FieldValue.arrayUnion({at: deps.now().toISOString(), text: body, wa_message_id: id || ''}),
    });
    return true;
  } catch (e) {
    console.error('[finance_bank] WhatsApp reply failed:', e.message);
    return false;
  }
};

const downloadMedia = async (creds, mediaId) => {
  const meta = await deps.fetch(`${GRAPH}/${mediaId}`, {headers: {Authorization: `Bearer ${creds.token}`}});
  if (!meta.ok) throw new Error(`Media lookup failed (${meta.status})`);
  const info = await meta.json();
  if (!info.url) throw new Error('Media has no download url');
  if (info.file_size && Number(info.file_size) > MAX_IMAGE_BYTES) throw new Error('Image is too large');
  const file = await deps.fetch(info.url, {headers: {Authorization: `Bearer ${creds.token}`}});
  if (!file.ok) throw new Error(`Media download failed (${file.status})`);
  const buffer = Buffer.from(await file.arrayBuffer());
  if (buffer.length > MAX_IMAGE_BYTES) throw new Error('Image is too large');
  return {buffer, mime: info.mime_type || 'image/jpeg'};
};

const EXTRACTION_PROMPT = (today) => [
  'A parent sent this picture to a school\'s WhatsApp number.',
  'Decide whether it is a screenshot or receipt of a money transfer (Zelle, bank app, Cash App, wire).',
  `Today is ${today}. Reply with JSON only, with these keys:`,
  '{"is_payment": boolean, "amount": number or null (US dollars, digits only), "date": "yyyy-MM-dd" or "" (the transfer date as shown; use the nearest year to today if the year is not shown),',
  '"sender": name of the person who SENT the money or "", "recipient": name of who received it or "", "confirmation": the confirmation / reference number exactly as printed or ""}.',
  'Never guess: use null or "" for anything you cannot read. A picture that is not a money transfer (a timetable, a photo, a chat) has is_payment false.',
].join(' ');

const extractFromImage = async (buffer, mime) => {
  const apiKey = await deps.getSecret('GEMINI_API_KEY');
  if (!apiKey) throw new Error('GEMINI_API_KEY is not configured');
  const body = JSON.stringify({
    contents: [{parts: [{text: EXTRACTION_PROMPT(nyDate(deps.now()))}, {inline_data: {mime_type: mime, data: buffer.toString('base64')}}]}],
    generationConfig: {temperature: 0, responseMimeType: 'application/json'},
  });
  let lastError = null;
  for (const model of GEMINI_MODELS) {
    const res = await deps.fetch(geminiUrl(model), {method: 'POST', headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey}, body});
    if (!res.ok) {
      lastError = new Error(`Gemini ${model} error ${res.status}`);
      continue;
    }
    const json = await res.json();
    const out = (json.candidates?.[0]?.content?.parts || []).filter((p) => !p.thought).map((p) => p.text || '').join('').trim();
    if (!out) {
      lastError = new Error(`Gemini ${model} returned nothing`);
      continue;
    }
    return match.parseExtraction(out);
  }
  throw lastError || new Error('No model answered');
};

const notifyAdmins = async (database, {message, proofId, fromPhone}) => {
  try {
    await database.collection('admin_notifications').add({
      type: 'whatsapp_message', message, proof_id: proofId, from_phone: fromPhone,
      read: false, createdAt: serverTime(), action_required: false,
    });
  } catch (e) {
    console.error('[finance_bank] admin notification failed:', e.message);
  }
};

/** Bank deposits that could be the one a screenshot shows. */
const findTransactionForProof = async (database, extracted, sentOn) => {
  if (extracted.amount == null) return {txn: null, ambiguous: false};
  const snap = await database.collection(COL.txns)
    .where('amount', '==', extracted.amount)
    .where('direction', '==', 'in')
    .limit(50)
    .get();
  const rows = snap.docs.map((d) => ({id: d.id, ...d.data()}));
  return match.matchProofToTransaction(extracted, rows, {sentOn});
};

const unpaidInvoiceForAmount = async (database, parentId, amount) => {
  const ctx = await loadMatchContext(database);
  const mine = ctx.invoices.filter((i) => i.parent_id === parentId).sort(match.byOldest);
  return mine.find((i) => match.sameMoney(i.balance, amount)) || null;
};

/** Ties a proof to a bank transaction and gives the transaction the family. */
const linkProofToTransaction = async (database, proofRef, proof, txn, ctx) => {
  const txnRef = database.collection(COL.txns).doc(txn.id);
  const update = {proof_id: proofRef.id};
  if (proof.parent_id) update.proof_parent_id = proof.parent_id;
  let allocations = (txn.match && txn.match.allocations) || [];
  if (isUndecided(txn)) {
    const field = toMatchField(suggest({...txn}, ctx, proof.parent_id ? {hintParentId: proof.parent_id} : {}), ctx);
    update.match = field;
    update.needs_action = needsAction(field, 'in');
    allocations = field.allocations;
  }
  await txnRef.update(update);
  return allocations[0] ? allocations[0].invoice_id : null;
};

const proofReplyText = {
  received: (first, inv, amount) =>
    `Thanks${first ? `, ${first}` : ''}. We received your payment proof${inv ? ` for ${inv}` : ''} (${match.money(amount)}). We'll confirm as soon as it reaches our account.`,
  unknown: () => 'Thank you. We couldn\'t match this number to a family yet; someone from Alluwal will check it shortly.',
  duplicate: (conf) => `We already have this payment proof${conf ? ` (Conf# ${conf})` : ''}. Nothing else to do.`,
  notPayment: () => 'Thanks, we\'ve passed this to the Alluwal team.',
  found: (family) => `We found it: this payment is for the ${family} family. We'll confirm once it reaches our account.`,
  paid: (month, inv) => `Your ${monthName(month)} invoice ${inv} is paid. Thank you!`,
};

const firstNameOf = (full) => String(full || '').trim().split(/\s+/)[0] || '';

const invoiceLabel = async (database, invoiceId) => {
  if (!invoiceId) return {number: '', month: ''};
  const snap = await database.collection(COL.invoices).doc(invoiceId).get();
  if (!snap.exists) return {number: '', month: ''};
  const d = snap.data();
  return {number: text(d.invoice_number || d.invoiceNumber) || invoiceId, month: invoiceMonthOf(d)};
};

/**
 * One WhatsApp image: store it, read it, decide what it is. Never records a
 * payment; the most it does is link the screenshot to a bank deposit that
 * already exists so the admin can confirm both together.
 */
const processInboundImage = async (database, creds, message, contact) => {
  const proofId = `wa_${safeId(message.id)}`;
  const proofRef = database.collection(COL.proofs).doc(proofId);
  if ((await proofRef.get()).exists) return {proof_id: proofId, duplicate_delivery: true};

  const fromDigits = match.phoneDigits(message.from);
  const fromPhone = `+${fromDigits}`;
  const sentAt = message.timestamp ? new Date(Number(message.timestamp) * 1000) : deps.now();
  const sentOn = nyDate(sentAt);
  const profileName = text(contact && contact.profile && contact.profile.name);

  const doc = {
    from_phone: fromPhone, wa_message_id: message.id, profile_name: profileName,
    received_at: sentAt, created_at: serverTime(), replies: [],
    caption: text(message.image && message.image.caption),
    extracted: {amount: null, date: '', sender: '', confirmation: ''},
    status: 'not_payment',
  };

  let media = null;
  try {
    media = await downloadMedia(creds, message.image.id);
    const ext = (media.mime.split('/')[1] || 'jpg').replace(/[^a-z0-9]/gi, '').slice(0, 5) || 'jpg';
    const path = `payment-proofs/${proofId}.${ext}`;
    await deps.bucket().file(path).save(media.buffer, {contentType: media.mime, resumable: false});
    doc.image_path = path;
    doc.image_mime = media.mime;
  } catch (e) {
    console.error('[finance_bank] could not fetch the image:', e.message);
    doc.status = 'unreadable';
    doc.detail = 'The picture could not be downloaded from WhatsApp.';
    await proofRef.create(doc).catch(() => {});
    await notifyAdmins(database, {message: `A picture from ${profileName || fromPhone} could not be downloaded.`, proofId, fromPhone});
    return {proof_id: proofId, status: doc.status};
  }

  let extracted;
  try {
    extracted = await extractFromImage(media.buffer, media.mime);
  } catch (e) {
    console.error('[finance_bank] could not read the image:', e.message);
    doc.status = 'unreadable';
    doc.detail = 'The picture could not be read automatically.';
    await proofRef.create(doc).catch(() => {});
    await notifyAdmins(database, {message: `A picture from ${profileName || fromPhone} could not be read automatically. Open it in Bank deposits.`, proofId, fromPhone});
    return {proof_id: proofId, status: doc.status};
  }
  doc.extracted = extracted;

  const parent = await findParentByPhone(database, fromDigits);
  if (parent) {
    doc.parent_id = parent.parent_id;
    doc.parent_name = parent.name;
  }

  let reply = null;
  let txnForLink = null;
  if (!extracted.is_payment) {
    doc.status = 'not_payment';
    reply = proofReplyText.notPayment();
  } else {
    const prior = await database.collection(COL.proofs)
      .where('extracted.confirmation', '==', extracted.confirmation || '__none__')
      .limit(10)
      .get();
    const others = prior.docs.map((d) => ({id: d.id, ...d.data()}));
    const dupe = match.findDuplicateProof(extracted, others.concat(extracted.confirmation ? [] : await recentProofs(database)));
    if (dupe) {
      doc.status = 'duplicate';
      doc.duplicate_of = dupe.id;
      reply = proofReplyText.duplicate(extracted.confirmation);
    } else if (!parent) {
      doc.status = 'unknown_sender';
      reply = proofReplyText.unknown();
    } else {
      const found = await findTransactionForProof(database, extracted, sentOn);
      doc.status = found.txn ? 'matched' : 'waiting_bank';
      txnForLink = found.txn;
    }
  }

  try {
    await proofRef.create(doc);
  } catch (e) {
    // A second delivery of the same message raced this one.
    return {proof_id: proofId, duplicate_delivery: true};
  }

  if (txnForLink) {
    const ctx = await loadMatchContext(database, {months: [txnForLink.date.slice(0, 7)]});
    const invoiceId = await linkProofToTransaction(database, proofRef, doc, txnForLink, ctx);
    await proofRef.update({bank_transaction_id: txnForLink.id, ...(invoiceId ? {invoice_id: invoiceId} : {})});
    const label = await invoiceLabel(database, invoiceId);
    reply = proofReplyText.received(firstNameOf(parent.name || profileName), label.number, extracted.amount);
  } else if (doc.status === 'waiting_bank') {
    const guess = await unpaidInvoiceForAmount(database, parent.parent_id, extracted.amount);
    if (guess) await proofRef.update({invoice_id: guess.id});
    reply = proofReplyText.received(firstNameOf(parent.name || profileName), guess ? guess.number : '', extracted.amount);
  }

  if (doc.status === 'not_payment') {
    await notifyAdmins(database, {message: `${parent ? parent.name : (profileName || fromPhone)} sent a picture on WhatsApp (not a payment).`, proofId, fromPhone});
  }
  if (reply) await replyToParent(database, proofRef, fromDigits, reply);
  return {proof_id: proofId, status: doc.status};
};

const recentProofs = async (database) => {
  const snap = await database.collection(COL.proofs).orderBy('created_at', 'desc').limit(60).get();
  return snap.docs.map((d) => ({id: d.id, ...d.data()}));
};

const markWhatsappConnected = (database, extra = {}) =>
  settingsRef(database).set({whatsapp: {connected: true, ...extra}}, {merge: true});

/**
 * Meta calls this URL. GET answers the one-time subscription handshake with
 * WHATSAPP_VERIFY_TOKEN. POST carries messages and is accepted only with a
 * valid X-Hub-Signature-256 (HMAC-SHA256 of the raw body with the app secret).
 */
const handleWhatsappWebhook = async (req, res) => {
  const creds = await whatsappCreds();
  if (!creds) {
    res.status(503).json({connected: false, message: 'WhatsApp is not connected yet.'});
    return;
  }
  const database = db();

  if (req.method === 'GET') {
    const q = req.query || {};
    if (q['hub.mode'] === 'subscribe' && safeEqual(q['hub.verify_token'] || '', creds.verifyToken)) {
      await markWhatsappConnected(database, {verified_at: serverTime(), phone_number_id: creds.phoneNumberId}).catch(() => {});
      res.status(200).type('text/plain').send(String(q['hub.challenge'] || ''));
      return;
    }
    res.status(403).send('Forbidden');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const raw = req.rawBody || Buffer.from(JSON.stringify(req.body || {}));
  const expected = `sha256=${crypto.createHmac('sha256', creds.appSecret).update(raw).digest('hex')}`;
  const given = (typeof req.get === 'function' ? req.get('x-hub-signature-256') : (req.headers || {})['x-hub-signature-256']) || '';
  if (!safeEqual(given, expected)) {
    res.status(401).send('Bad signature');
    return;
  }

  const body = record(req.body);
  const results = [];
  for (const entry of Array.isArray(body.entry) ? body.entry : []) {
    for (const change of Array.isArray(entry.changes) ? entry.changes : []) {
      const value = record(change.value);
      const contacts = Array.isArray(value.contacts) ? value.contacts : [];
      for (const message of Array.isArray(value.messages) ? value.messages : []) {
        try {
          const contact = contacts.find((c) => c.wa_id === message.from) || contacts[0];
          if (message.type === 'image' && message.image && message.image.id) {
            results.push(await processInboundImage(database, creds, message, contact));
          }
        } catch (e) {
          // Always answer 200 once the signature is good, or Meta retries forever.
          console.error('[finance_bank] WhatsApp message failed:', e);
        }
      }
    }
  }
  if (results.length) await markWhatsappConnected(database, {last_message_at: serverTime()}).catch(() => {});
  res.status(200).json({ok: true, processed: results.length});
};

/* ----------------------------------------------------------- bank sync -- */

const upsertPlaidTransactions = async (database, added, modified, removed, priv) => {
  const stored = [];
  const accountFilter = Array.isArray(priv.account_ids) && priv.account_ids.length ? new Set(priv.account_ids) : null;
  for (const t of [...added, ...modified]) {
    if (t.pending) continue;
    if (accountFilter && !accountFilter.has(t.account_id)) continue;
    const ref = database.collection(COL.txns).doc(`plaid_${safeId(t.transaction_id)}`);
    const existing = await ref.get();
    if (existing.exists && !isUndecided(existing.data())) continue;
    const signed = match.r2(-num(t.amount)); // Plaid: positive = money out
    if (!signed) continue;
    const description = text(t.original_description) || text(t.name) || text(t.merchant_name);
    const memo = text(t.payment_meta && (t.payment_meta.reason || t.payment_meta.reference_number));
    const parsed = match.parseBankDescription(description, memo);
    const fields = {
      plaid_transaction_id: t.transaction_id, account_id: t.account_id || '', account_mask: priv.mask || '',
      date: String(t.date).slice(0, 10), month: String(t.date).slice(0, 7),
      amount: Math.abs(signed), direction: signed > 0 ? 'in' : 'out', currency: t.iso_currency_code || 'USD',
      description, memo: parsed.memo || memo, payer_name: parsed.payer_name || text(t.payment_meta && t.payment_meta.payer),
      channel: parsed.channel, confirmation: parsed.confirmation, removed: false,
    };
    if (existing.exists) {
      await ref.update({...fields, updated_at: serverTime()});
    } else {
      await ref.set({...fields, match: {status: 'none', level: 'none', allocations: []}, needs_action: false, created_at: serverTime()});
    }
    stored.push(ref.id);
  }
  for (const t of removed) {
    const ref = database.collection(COL.txns).doc(`plaid_${safeId(t.transaction_id)}`);
    const snap = await ref.get();
    if (snap.exists && isUndecided(snap.data())) await ref.update({removed: true, needs_action: false, updated_at: serverTime()});
  }
  return stored;
};

/** Gives a proof waiting for the bank the deposit that just arrived. */
const linkWaitingProofs = async (database, txnDocs, ctx) => {
  const waiting = await database.collection(COL.proofs).where('status', '==', 'waiting_bank').limit(100).get();
  if (waiting.empty) return 0;
  const pool = txnDocs.map((d) => ({id: d.id, ...d.data()}));
  let linked = 0;
  for (const proofDoc of waiting.docs) {
    const proof = proofDoc.data();
    const found = match.matchProofToTransaction(proof.extracted || {}, pool, {sentOn: proof.received_at ? nyDate(toDate(proof.received_at)) : ''});
    if (!found.txn) continue;
    const invoiceId = await linkProofToTransaction(database, proofDoc.ref, proof, found.txn, ctx);
    await proofDoc.ref.update({status: 'matched', bank_transaction_id: found.txn.id, ...(invoiceId ? {invoice_id: invoiceId} : {})});
    found.txn.proof_id = proofDoc.id;
    linked += 1;
  }
  return linked;
};

const syncOnce = async (database, creds, priv) => {
  const startCursor = priv.cursor || null;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    let cursor = startCursor;
    const added = [];
    const modified = [];
    const removed = [];
    try {
      for (let page = 0; page < SYNC_PAGE_LIMIT; page += 1) {
        const res = await plaidCall(creds, '/transactions/sync', {
          access_token: priv.access_token, ...(cursor ? {cursor} : {}), count: 500,
          options: {include_original_description: true},
        });
        added.push(...(res.added || []));
        modified.push(...(res.modified || []));
        removed.push(...(res.removed || []));
        cursor = res.next_cursor;
        if (!res.has_more) return {added, modified, removed, cursor};
      }
      return {added, modified, removed, cursor};
    } catch (e) {
      // Plaid asks for a restart when data changes mid-pagination.
      if (!(e.plaid && e.plaid.error_code === 'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION') || attempt === 1) throw e;
    }
  }
  return {added: [], modified: [], removed: [], cursor: startCursor};
};

/**
 * Pulls new transactions, stores them and suggests matches. Safe to call from
 * the daily schedule, the Plaid webhook and the admin button at once: a lock
 * on finance_private/plaid lets one run at a time.
 */
const runBankSync = async ({rematchMonth} = {}) => {
  const creds = await plaidCreds();
  if (!creds) return {connected: false, reason: 'plaid_not_configured'};
  const database = db();
  const ref = privateRef(database);
  const first = await ref.get();
  if (!first.exists || !first.data().access_token) return {connected: false, reason: 'not_linked'};

  const nowMs = deps.now().getTime();
  const locked = await database.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const until = toDate(snap.data().sync_lock_until);
    if (until && until.getTime() > nowMs) return false;
    tx.update(ref, {sync_lock_until: new Date(nowMs + SYNC_LOCK_MS)});
    return true;
  });
  if (!locked) return {connected: true, skipped: 'busy'};

  try {
    const priv = (await ref.get()).data();
    const result = await syncOnce(database, creds, priv);
    const ids = await upsertPlaidTransactions(database, result.added, result.modified, result.removed, priv);
    const months = new Set();
    const txnDocs = [];
    for (const id of ids) {
      const snap = await database.collection(COL.txns).doc(id).get();
      txnDocs.push(snap);
      months.add(snap.data().month);
    }
    if (rematchMonth) {
      months.add(rematchMonth);
      const again = await database.collection(COL.txns).where('month', '==', rematchMonth).limit(500).get();
      again.forEach((d) => {
        if (!ids.includes(d.id)) txnDocs.push(d);
      });
    }
    let matched = 0;
    let linkedProofs = 0;
    if (txnDocs.length) {
      const ctx = await loadMatchContext(database, {months: [...months]});
      matched = await matchTransactions(database, txnDocs, ctx);
      const fresh = [];
      for (const d of txnDocs) fresh.push(await d.ref.get());
      linkedProofs = await linkWaitingProofs(database, fresh.filter((s) => s.data().direction === 'in'), ctx);
    }
    await ref.update({cursor: result.cursor, sync_lock_until: null, last_sync_at: serverTime()});
    await settingsRef(database).set({plaid: {last_sync_at: serverTime(), needs_attention: null}}, {merge: true});
    return {
      connected: true, added: ids.length, matched, linked_proofs: linkedProofs,
      removed: result.removed.length, checked_at: deps.now().toISOString(),
    };
  } catch (e) {
    await ref.update({sync_lock_until: null, last_error: String(e.message || e).slice(0, 300)}).catch(() => {});
    console.error('[finance_bank] sync failed:', e.message);
    throw HttpsError('unavailable', `The bank could not be read just now: ${e.message}`);
  }
};

/* ---------------------------------------------------------- linkBankAccount -- */

const publicStatus = async (database) => {
  const [plaid, wa, settings] = await Promise.all([plaidCreds(), whatsappCreds(), loadSettings(database)]);
  const p = record(settings.plaid);
  const w = record(settings.whatsapp);
  return {
    plaid_available: Boolean(plaid),
    plaid_env: plaid ? plaid.env : null,
    plaid_connected: p.connected === true && Boolean(plaid),
    institution: text(p.institution),
    mask: text(p.mask),
    last_sync_at: toDate(p.last_sync_at) ? toDate(p.last_sync_at).toISOString() : null,
    needs_attention: p.needs_attention || null,
    whatsapp_available: Boolean(wa),
    whatsapp_connected: w.connected === true && Boolean(wa),
    parent_messages_enabled: settings.parent_messages_enabled === true,
  };
};

/**
 * Admin callable. `action`:
 *  - "status" (default): what is available and connected.
 *  - "create_link_token": starts Plaid Link ({mode:"update"} repairs a broken login).
 *  - "exchange": {public_token, institution?, mask?, account_ids?} after Link succeeds.
 *  - "disconnect": removes the Plaid item.
 */
const linkBankAccount = async (request) => {
  const {callerUid} = await verifyAdmin(request);
  const data = record(request.data);
  const action = text(data.action) || 'status';
  const database = db();

  if (action === 'status') return publicStatus(database);

  const creds = await plaidCreds();
  if (!creds) {
    if (action === 'create_link_token') return {available: false, message: NOT_CONNECTED_PLAID};
    throw HttpsError('failed-precondition', NOT_CONNECTED_PLAID);
  }

  if (action === 'create_link_token') {
    const privSnap = await privateRef(database).get();
    const update = data.mode === 'update' && privSnap.exists && privSnap.data().access_token;
    const webhook = await deps.getSecret('PLAID_WEBHOOK_URL');
    try {
      const res = await plaidCall(creds, '/link/token/create', {
        client_name: 'Alluwal Education Hub', language: 'en', country_codes: ['US'],
        user: {client_user_id: callerUid},
        ...(update ? {access_token: privSnap.data().access_token} : {products: ['transactions'], transactions: {days_requested: 90}}),
        ...(webhook ? {webhook} : {}),
      });
      return {available: true, link_token: res.link_token, expiration: res.expiration};
    } catch (e) {
      throw HttpsError('failed-precondition', `Plaid said no: ${e.message}`);
    }
  }

  if (action === 'exchange') {
    const publicToken = text(data.public_token);
    if (!publicToken) throw HttpsError('invalid-argument', 'public_token is required');
    let exchanged;
    try {
      exchanged = await plaidCall(creds, '/item/public_token/exchange', {public_token: publicToken});
    } catch (e) {
      throw HttpsError('failed-precondition', `Plaid said no: ${e.message}`);
    }
    const institution = text(data.institution).slice(0, 80);
    const mask = text(data.mask).replace(/\D/g, '').slice(-4);
    const accountIds = (Array.isArray(data.account_ids) ? data.account_ids : []).map(text).filter(Boolean).slice(0, 10);
    await privateRef(database).set({
      access_token: exchanged.access_token, item_id: exchanged.item_id, env: creds.env, cursor: null,
      account_ids: accountIds, institution, mask, linked_at: serverTime(), linked_by: callerUid, sync_lock_until: null,
    });
    await settingsRef(database).set({plaid: {connected: true, institution, mask, linked_at: serverTime(), linked_by: callerUid, needs_attention: null}}, {merge: true});
    let sync = null;
    try {
      sync = await runBankSync();
    } catch (e) {
      sync = {connected: true, error: e.message};
    }
    return {connected: true, institution, mask, sync};
  }

  if (action === 'disconnect') {
    const privSnap = await privateRef(database).get();
    if (privSnap.exists && privSnap.data().access_token) {
      await plaidCall(creds, '/item/remove', {access_token: privSnap.data().access_token}).catch(() => {});
    }
    await privateRef(database).delete();
    await settingsRef(database).set({plaid: {connected: false, institution: '', mask: ''}}, {merge: true});
    return {connected: false};
  }

  throw HttpsError('invalid-argument', `Unknown action "${action}"`);
};

/** Admin callable: "Check the bank now" ({rematch_month?: 'yyyy-MM'} also re-suggests open ones). */
const syncBankTransactions = async (request) => {
  await verifyAdmin(request);
  const data = record(request.data);
  const month = /^\d{4}-\d{2}$/.test(text(data.rematch_month)) ? text(data.rematch_month) : undefined;
  return runBankSync({rematchMonth: month});
};

/* --------------------------------------------------- Plaid webhook (JWT) -- */

const jwkCache = new Map();

/**
 * Plaid signs every webhook with an ES256 JWT in the Plaid-Verification
 * header. We fetch the matching public key from Plaid, check the signature,
 * that the token is under five minutes old, and that its
 * `request_body_sha256` equals the SHA-256 of the raw body we received.
 */
const verifyPlaidWebhook = async (headers, rawBody, creds) => {
  const jwt = require('jsonwebtoken');
  const token = headers['plaid-verification'];
  if (!token) return false;
  const decoded = jwt.decode(token, {complete: true});
  if (!decoded || decoded.header.alg !== 'ES256' || !decoded.header.kid) return false;
  const kid = decoded.header.kid;
  let jwk = jwkCache.get(kid);
  if (!jwk) {
    const res = await plaidCall(creds, '/webhook_verification_key/get', {key_id: kid});
    jwk = res.key;
    jwkCache.set(kid, jwk);
  }
  if (!jwk) return false;
  const key = crypto.createPublicKey({key: {kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y}, format: 'jwk'});
  let payload;
  try {
    payload = jwt.verify(token, key, {algorithms: ['ES256'], maxAge: '5 minutes'});
  } catch (e) {
    return false;
  }
  const bodyHash = crypto.createHash('sha256').update(rawBody).digest('hex');
  return safeEqual(payload.request_body_sha256 || '', bodyHash);
};

const SYNC_CODES = new Set(['SYNC_UPDATES_AVAILABLE', 'INITIAL_UPDATE', 'HISTORICAL_UPDATE', 'DEFAULT_UPDATE']);

const handlePlaidWebhook = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }
  const creds = await plaidCreds();
  if (!creds) {
    res.status(503).json({connected: false});
    return;
  }
  const raw = req.rawBody || Buffer.from(JSON.stringify(req.body || {}));
  let valid = false;
  try {
    valid = await verifyPlaidWebhook(req.headers || {}, raw, creds);
  } catch (e) {
    console.error('[finance_bank] Plaid webhook verification error:', e.message);
  }
  if (!valid) {
    res.status(401).send('Bad signature');
    return;
  }

  const body = record(req.body);
  const database = db();
  const priv = await privateRef(database).get();
  if (!priv.exists || (body.item_id && priv.data().item_id !== body.item_id)) {
    res.status(200).json({ok: true, ignored: true});
    return;
  }
  const type = text(body.webhook_type);
  const code = text(body.webhook_code);
  try {
    if (type === 'TRANSACTIONS' && SYNC_CODES.has(code)) {
      await runBankSync();
    } else if (type === 'ITEM' && ['ERROR', 'PENDING_EXPIRATION', 'USER_PERMISSION_REVOKED'].includes(code)) {
      await settingsRef(database).set({plaid: {needs_attention: code}}, {merge: true});
    } else if (type === 'ITEM' && code === 'LOGIN_REPAIRED') {
      await settingsRef(database).set({plaid: {needs_attention: null}}, {merge: true});
    }
  } catch (e) {
    console.error('[finance_bank] webhook sync failed:', e.message);
  }
  res.status(200).json({ok: true});
};

/* ------------------------------------------------------ decide a deposit -- */

const loadInvoices = async (database, allocations) => {
  const out = [];
  for (const a of allocations) {
    const snap = await database.collection(COL.invoices).doc(a.invoice_id).get();
    if (!snap.exists) throw HttpsError('not-found', 'An invoice in this match no longer exists.');
    out.push({id: snap.id, data: snap.data()});
  }
  return out;
};

const cleanAllocations = (raw, txnAmount) => {
  const list = (Array.isArray(raw) ? raw : []).map((a) => ({invoice_id: text(a && a.invoice_id), amount: match.r2(num(a && a.amount))}));
  if (!list.length || list.some((a) => !a.invoice_id || !(a.amount > 0))) {
    throw HttpsError('invalid-argument', 'Choose at least one invoice and an amount for each.');
  }
  if (new Set(list.map((a) => a.invoice_id)).size !== list.length) throw HttpsError('invalid-argument', 'An invoice is listed twice.');
  const total = match.r2(list.reduce((s, a) => s + a.amount, 0));
  if (total > txnAmount + match.EPS) throw HttpsError('invalid-argument', `That is ${match.money(total)}, more than the deposit of ${match.money(txnAmount)}.`);
  return list;
};

const confirmRecurringCharge = async (database, txnId, txn, callerUid) => {
  const costId = text(txn.match && txn.match.recurring_cost_id);
  if (!costId) throw HttpsError('failed-precondition', 'This charge has no recurring cost to confirm.');
  const cost = await database.collection(COL.recurringCosts).doc(costId).get();
  if (!cost.exists) throw HttpsError('not-found', 'That recurring cost no longer exists.');
  const month = txn.month || txn.date.slice(0, 7);
  await deps.assertMonthOpen(database, month);
  await database.collection(COL.confirmations).doc(`${month}_${costId}`).set({
    cost_id: costId, month, amount: match.r2(txn.amount), confirmed_at: serverTime(), confirmed_by: callerUid,
    source: 'bank', bank_transaction_id: txnId,
  });
  return {recurring_cost_id: costId, month};
};

/**
 * The only place a bank deposit becomes payments. Checks the invoices' months
 * are open, then records one payment per allocation (idempotent per
 * transaction + invoice), then closes the match. Used by decideBankMatch and
 * decidePaymentProof.
 */
const confirmTransaction = async (database, txnRef, txn, allocations, {callerUid, status, rememberPayer}) => {
  const rows = await loadInvoices(database, allocations);
  for (const month of new Set(rows.map((r) => invoiceMonthOf(r.data)).filter(Boolean))) {
    await deps.assertMonthOpen(database, month);
  }
  const method = txn.channel === 'zelle' ? 'zelle' : 'bank_transfer';
  const received = new Date(`${txn.date}T12:00:00Z`);
  for (const a of allocations) {
    await deps.recordPayment(database, {
      invoiceId: a.invoice_id, amount: a.amount, paymentMethod: method, reference: txnRef.id,
      note: `${txn.date} ${match.money(a.amount)} ${method === 'zelle' ? 'Zelle' : 'bank deposit'}${txn.payer_name ? ` from ${txn.payer_name}` : ''} (bank deposit, confirmed by an admin)`,
      receivedDate: received, actorUid: callerUid, paymentDocId: `bank_${txnRef.id}_${a.invoice_id}`,
      paymentSource: 'bank', extraPaymentFields: {bank_transaction_id: txnRef.id},
    });
  }
  const parentId = text(rows[0].data.parent_id || rows[0].data.parentId);
  const previous = record(txn.match);
  const labelled = allocations.map((a) => {
    const row = rows.find((r) => r.id === a.invoice_id);
    return {...a, number: text(row.data.invoice_number || row.data.invoiceNumber) || a.invoice_id, month: invoiceMonthOf(row.data)};
  });
  await txnRef.update({
    match: {...previous, status, allocations: labelled, decided_at: serverTime(), decided_by: callerUid, parent_id: parentId || previous.parent_id || null},
    needs_action: false,
  });
  const key = match.nameKey(txn.payer_name);
  if (rememberPayer && key && parentId) {
    const parentDoc = await database.collection(COL.users).doc(parentId).get();
    await database.collection(COL.payers).doc(key).set({
      parent_id: parentId, name: txn.payer_name, family_name: parentDoc.exists ? displayName(parentDoc.data()) : '', learned_at: serverTime(), learned_by: callerUid, bank_transaction_id: txnRef.id,
    });
  }
  return {allocations, parent_id: parentId, invoice_ids: allocations.map((a) => a.invoice_id)};
};

const finishLinkedProof = async (database, txnId, txn, outcome) => {
  const proofId = text(txn.proof_id);
  if (!proofId) return;
  const proofRef = database.collection(COL.proofs).doc(proofId);
  const proof = await proofRef.get();
  if (!proof.exists) return;
  const invoiceId = outcome.invoice_ids[0];
  await proofRef.update({status: 'confirmed', bank_transaction_id: txnId, invoice_id: invoiceId, confirmed_at: serverTime()});
  const label = await invoiceLabel(database, invoiceId);
  await replyToParent(database, proofRef, proof.data().from_phone, proofReplyText.paid(label.month, label.number));
};

/**
 * Admin callable. `{transaction_id, action, allocations?, remember_payer?}`
 *  - confirm: records payments for the suggested allocations (or, for a
 *    charge, confirms the matched recurring cost with this amount).
 *  - reject: drops the suggestion; the deposit waits for a manual match.
 *  - manual: the admin picks invoices (`allocations: [{invoice_id, amount}]`).
 *  - ignore: not tuition (other income, or a charge to leave alone).
 */
const decideBankMatch = async (request) => {
  const {callerUid} = await verifyAdmin(request);
  const data = record(request.data);
  const txnId = text(data.transaction_id);
  const action = text(data.action);
  if (!txnId) throw HttpsError('invalid-argument', 'transaction_id is required');
  if (!['confirm', 'reject', 'manual', 'ignore'].includes(action)) throw HttpsError('invalid-argument', 'action must be confirm, reject, manual or ignore');

  const database = db();
  const txnRef = database.collection(COL.txns).doc(txnId);
  const snap = await txnRef.get();
  if (!snap.exists) throw HttpsError('not-found', 'That bank transaction was not found.');
  const txn = snap.data();
  const status = text(txn.match && txn.match.status);
  const decided = ['confirmed', 'manual'].includes(status);

  if (action === 'ignore') {
    if (decided) throw HttpsError('failed-precondition', 'This one is already matched.');
    await txnRef.update({match: {status: 'ignored', level: 'none', kind: 'none', allocations: [], decided_at: serverTime(), decided_by: callerUid}, needs_action: false});
    return {ok: true};
  }
  if (action === 'reject') {
    if (decided) throw HttpsError('failed-precondition', 'This one is already matched.');
    await txnRef.update({
      match: {status: 'none', level: 'none', kind: 'none', why: 'You said the suggestion was wrong. Pick the right invoice.', allocations: [], decided_at: serverTime(), decided_by: callerUid},
      needs_action: txn.direction === 'in',
    });
    return {ok: true};
  }
  if (decided) return {ok: true, already: true};

  if (txn.direction === 'out') {
    if (action !== 'confirm') throw HttpsError('invalid-argument', 'A charge can only be confirmed, rejected or ignored.');
    const out = await confirmRecurringCharge(database, txnId, txn, callerUid);
    await txnRef.update({match: {...record(txn.match), status: 'confirmed', decided_at: serverTime(), decided_by: callerUid}, needs_action: false});
    return {ok: true, ...out};
  }

  let allocations;
  if (action === 'confirm') {
    if (status !== 'suggested' || !(txn.match.allocations || []).length) throw HttpsError('failed-precondition', 'There is no suggestion to confirm. Pick an invoice instead.');
    allocations = cleanAllocations(txn.match.allocations, txn.amount);
  } else {
    allocations = cleanAllocations(data.allocations, txn.amount);
  }
  const outcome = await confirmTransaction(database, txnRef, txn, allocations, {
    callerUid, status: action === 'confirm' ? 'confirmed' : 'manual', rememberPayer: data.remember_payer === true,
  });
  await finishLinkedProof(database, txnId, txn, outcome);
  return {ok: true, ...outcome};
};

/* ------------------------------------------------------ decide a proof -- */

const findProofTransaction = async (database, proof) => {
  if (proof.bank_transaction_id) {
    const snap = await database.collection(COL.txns).doc(proof.bank_transaction_id).get();
    if (snap.exists) return {id: snap.id, ...snap.data()};
  }
  const found = await findTransactionForProof(database, proof.extracted || {}, proof.received_at ? nyDate(toDate(proof.received_at)) : '');
  return found.txn;
};

/**
 * Admin callable. `{proof_id, action: 'confirm'|'link_family', parent_id?}`
 *  - confirm: needs a linked bank deposit; records the payment the same way
 *    decideBankMatch does. Without a deposit nothing is recorded.
 *  - link_family: saves the sender's WhatsApp number to the family and re-runs
 *    matching for that number's waiting proofs.
 */
const decidePaymentProof = async (request) => {
  const {callerUid} = await verifyAdmin(request);
  const data = record(request.data);
  const proofId = text(data.proof_id);
  const action = text(data.action);
  if (!proofId) throw HttpsError('invalid-argument', 'proof_id is required');
  if (!['confirm', 'link_family'].includes(action)) throw HttpsError('invalid-argument', 'action must be confirm or link_family');

  const database = db();
  const proofRef = database.collection(COL.proofs).doc(proofId);
  const snap = await proofRef.get();
  if (!snap.exists) throw HttpsError('not-found', 'That payment proof was not found.');
  const proof = snap.data();

  if (action === 'confirm') {
    if (proof.status === 'confirmed') return {ok: true, already: true};
    if (!['matched', 'waiting_bank'].includes(proof.status)) throw HttpsError('failed-precondition', 'This picture is not a payment proof that can be confirmed.');
    const txn = await findProofTransaction(database, proof);
    if (!txn) {
      throw HttpsError('failed-precondition', 'Nothing has reached the bank yet. A screenshot alone never marks an invoice paid; confirm once the deposit shows up.');
    }
    const txnRef = database.collection(COL.txns).doc(txn.id);
    const fresh = (await txnRef.get()).data();
    if (['confirmed', 'manual'].includes(text(fresh.match && fresh.match.status))) {
      await proofRef.update({status: 'confirmed', bank_transaction_id: txn.id, confirmed_at: serverTime()});
      return {ok: true, already: true};
    }
    if (!(fresh.match && (fresh.match.allocations || []).length)) {
      throw HttpsError('failed-precondition', 'The bank deposit has no invoice match yet. Match it from the list above first.');
    }
    const outcome = await confirmTransaction(database, txnRef, fresh, cleanAllocations(fresh.match.allocations, fresh.amount), {
      callerUid, status: 'confirmed', rememberPayer: false,
    });
    await finishLinkedProof(database, txn.id, {...fresh, proof_id: proofId}, outcome);
    return {ok: true, ...outcome};
  }

  // link_family
  const parentId = text(data.parent_id);
  if (!parentId) throw HttpsError('invalid-argument', 'parent_id is required');
  const parentSnap = await database.collection(COL.users).doc(parentId).get();
  if (!parentSnap.exists) throw HttpsError('not-found', 'That family was not found.');
  const parentName = displayName(parentSnap.data());
  await rememberPhone(database, proof.from_phone, parentId, parentName, 'admin', callerUid);

  const mine = await database.collection(COL.proofs).where('from_phone', '==', proof.from_phone).limit(30).get();
  const results = [];
  for (const doc of mine.docs) {
    const p = doc.data();
    // The one clicked, plus any other picture from this number that was waiting for a family.
    if (doc.id !== proofId && p.status !== 'unknown_sender') continue;
    if (['confirmed', 'duplicate', 'not_payment', 'unreadable'].includes(p.status)) continue;
    const updated = {...p, parent_id: parentId, parent_name: parentName};
    const found = await findTransactionForProof(database, p.extracted || {}, p.received_at ? nyDate(toDate(p.received_at)) : '');
    let invoiceId = null;
    if (found.txn) {
      const ctx = await loadMatchContext(database, {months: [found.txn.date.slice(0, 7)]});
      invoiceId = await linkProofToTransaction(database, doc.ref, updated, found.txn, ctx);
    } else if (p.extracted && p.extracted.amount != null) {
      const guess = await unpaidInvoiceForAmount(database, parentId, p.extracted.amount);
      invoiceId = guess ? guess.id : null;
    }
    await doc.ref.update({
      parent_id: parentId, parent_name: parentName, status: found.txn ? 'matched' : 'waiting_bank',
      ...(found.txn ? {bank_transaction_id: found.txn.id} : {}), ...(invoiceId ? {invoice_id: invoiceId} : {}),
    });
    await replyToParent(database, doc.ref, p.from_phone, proofReplyText.found(parentName));
    results.push({proof_id: doc.id, status: found.txn ? 'matched' : 'waiting_bank'});
  }
  return {ok: true, proofs: results};
};

/* ------------------------------------------------------------- exports -- */

// Gemini already exists as a deployed secret, so only it is bound; the Plaid
// and WhatsApp secrets are read at run time (utils/finance_secrets.js) so a
// deploy never waits on them.
const whatsappWebhook = onRequest({timeoutSeconds: 120, memory: '512MiB', secrets: ['GEMINI_API_KEY']}, (req, res) =>
  handleWhatsappWebhook(req, res).catch((e) => {
    console.error('[finance_bank] whatsappWebhook failed:', e);
    if (!res.headersSent) res.status(500).send('error');
  }));

const plaidWebhook = onRequest({timeoutSeconds: 300, memory: '512MiB'}, (req, res) =>
  handlePlaidWebhook(req, res).catch((e) => {
    console.error('[finance_bank] plaidWebhook failed:', e);
    if (!res.headersSent) res.status(500).send('error');
  }));

const scheduledBankSync = onSchedule({schedule: 'every day 06:00', timeZone: NY, timeoutSeconds: 300, memory: '512MiB'}, async () => {
  try {
    const out = await runBankSync();
    console.log('[finance_bank] daily sync:', JSON.stringify(out));
  } catch (e) {
    console.error('[finance_bank] daily sync failed:', e.message);
  }
});

module.exports = {
  linkBankAccount,
  syncBankTransactions,
  decideBankMatch,
  decidePaymentProof,
  plaidWebhook,
  whatsappWebhook,
  scheduledBankSync,
  // exposed for tests
  runBankSync,
  handleWhatsappWebhook,
  handlePlaidWebhook,
  verifyPlaidWebhook,
  processInboundImage,
  confirmTransaction,
  loadMatchContext,
  findParentByPhone,
  __setDeps,
  __resetPhoneScan: () => {
    phoneScan = {at: 0, rows: []};
  },
  __clearJwkCache: () => jwkCache.clear(),
};
