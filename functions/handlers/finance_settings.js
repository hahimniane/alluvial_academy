/**
 * updateFinanceSettings: the finance switches and numbers in
 * `finance_settings/main` (docs/finance/SPEC.md).
 *
 * Only the keys below can be changed from the page. The Plaid and WhatsApp
 * connection status is written by their own callables.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const math = require('../utils/finance_math');

const DEFAULT_SETTINGS = {
  auto_billing_enabled: false,
  parent_messages_enabled: false,
  issue_day: 25,
  due_day: 1,
  first_invoice_due_days: 3,
  reminder_days_before: 3,
  plaid: {connected: false},
  whatsapp: {connected: false},
};

const BOOLEAN_KEYS = ['auto_billing_enabled', 'parent_messages_enabled'];
/** Whole numbers and the range each may take. */
const INTEGER_RANGES = {
  issue_day: [1, 28],
  due_day: [1, 28],
  first_invoice_due_days: [0, 30],
  reminder_days_before: [0, 14],
};

const defaultDeps = () => ({
  db: admin.firestore(),
  Timestamp: admin.firestore.Timestamp,
  verifyAdmin: verifyCallableCallerIsAdmin,
});

/** Checks a patch and returns only what may be written. */
const cleanPatch = (patch) => {
  if (!patch || typeof patch !== 'object' || Array.isArray(patch)) {
    throw new functions.https.HttpsError('invalid-argument', 'Nothing to change.');
  }
  const clean = {};
  for (const [key, value] of Object.entries(patch)) {
    if (BOOLEAN_KEYS.includes(key)) {
      if (typeof value !== 'boolean') {
        throw new functions.https.HttpsError('invalid-argument', `${key} must be on or off.`);
      }
      clean[key] = value;
    } else if (key in INTEGER_RANGES) {
      const [min, max] = INTEGER_RANGES[key];
      if (typeof value !== 'number' || !Number.isInteger(value) || value < min || value > max) {
        throw new functions.https.HttpsError('invalid-argument', `${key} must be a whole number from ${min} to ${max}.`);
      }
      clean[key] = value;
    } else {
      throw new functions.https.HttpsError('invalid-argument', `${key} cannot be changed here.`);
    }
  }
  if (Object.keys(clean).length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Nothing to change.');
  }
  return clean;
};

/** Stored settings over the defaults, as plain values the page can read. */
const mergedSettings = (stored) => {
  const data = stored || {};
  const at = math.toDate(data.updated_at);
  return {
    ...DEFAULT_SETTINGS,
    ...data,
    plaid: {...DEFAULT_SETTINGS.plaid, ...(data.plaid || {})},
    whatsapp: {...DEFAULT_SETTINGS.whatsapp, ...(data.whatsapp || {})},
    updated_at: at ? at.toISOString() : null,
  };
};

/**
 * Admin-only callable.
 *
 * Accepts: { patch: { auto_billing_enabled?, parent_messages_enabled?, issue_day?,
 *            due_day?, first_invoice_due_days?, reminder_days_before? } }
 * Returns: { settings } with the defaults filled in.
 */
const updateFinanceSettings = async (request, deps = defaultDeps()) => {
  const {db, Timestamp} = deps;
  const {callerUid} = await deps.verifyAdmin(request);
  const patch = cleanPatch(request && request.data && request.data.patch);

  const ref = db.collection('finance_settings').doc('main');
  await ref.set({...patch, updated_at: Timestamp.now(), updated_by: callerUid}, {merge: true});
  const snap = await ref.get();
  return {settings: mergedSettings(snap.exists ? snap.data() : {})};
};

module.exports = {updateFinanceSettings, DEFAULT_SETTINGS, INTEGER_RANGES, _cleanPatch: cleanPatch};
