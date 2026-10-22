/**
 * Reads the switches the billing engine obeys, shared by the new generator and
 * by the old recurring generator (which must step aside for families that have
 * moved over).
 */
const {shouldOldGeneratorSkip} = require('./finance_billing_math');

const DEFAULT_SETTINGS = {
  auto_billing_enabled: false,
  parent_messages_enabled: false,
  issue_day: 25,
  due_day: 1,
  first_invoice_due_days: 3,
  reminder_days_before: 3,
};

const loadBillingSettings = async (db) => {
  const snap = await db.collection('finance_settings').doc('main').get();
  const stored = snap && snap.exists ? snap.data() || {} : {};
  return {...DEFAULT_SETTINGS, ...stored};
};

/**
 * True when the old `recurring_billing_plans` generator must NOT bill this
 * plan's family: the new engine is on and the family has `family_billing`.
 * With the switch off (the default) this is always false, so the old
 * generator behaves exactly as it always did.
 */
const oldGeneratorShouldSkipFamily = async (db, parentId, settings) => {
  if (!settings || settings.auto_billing_enabled !== true) return false;
  const id = String(parentId || '').trim();
  if (!id) return false;
  const snap = await db.collection('family_billing').doc(id).get();
  return shouldOldGeneratorSkip({
    autoBillingEnabled: true,
    familyBilling: snap && snap.exists ? snap.data() || {} : null,
  });
};

module.exports = {DEFAULT_SETTINGS, loadBillingSettings, oldGeneratorShouldSkipFamily};
