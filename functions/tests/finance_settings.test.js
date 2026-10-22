/**
 * updateFinanceSettings (handlers/finance_settings.js).
 *
 * Expected behavior:
 * - Admin-only. Accepts only the two switches and the four numbers, each
 *   checked; anything else is refused and nothing is written.
 * - Writes finance_settings/main with who and when, and returns the stored
 *   settings over the defaults from the SPEC.
 */

jest.mock('firebase-functions', () => {
  class MockHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {https: {HttpsError: MockHttpsError}};
});

const {updateFinanceSettings, DEFAULT_SETTINGS} = require('../handlers/finance_settings');
const {makeDb, FakeTimestamp} = require('./helpers/finance_overview_db');

const deps = (db, over = {}) => ({
  db,
  Timestamp: FakeTimestamp,
  verifyAdmin: async () => ({callerUid: 'admin_1', effectiveAdminEmail: null}),
  ...over,
});
const update = (db, patch, over) => updateFinanceSettings({auth: {uid: 'admin_1'}, data: {patch}}, deps(db, over));

describe('updateFinanceSettings', () => {
  test('refuses a caller the admin gate refuses', async () => {
    const db = makeDb({});
    const refuse = async () => {
      const error = new Error('no');
      error.code = 'permission-denied';
      throw error;
    };
    await expect(update(db, {auto_billing_enabled: true}, {verifyAdmin: refuse})).rejects.toMatchObject({code: 'permission-denied'});
    expect(db.store.finance_settings).toBeUndefined();
  });

  test('turns a switch on and returns the settings with the defaults filled in', async () => {
    const db = makeDb({});
    const {settings} = await update(db, {parent_messages_enabled: true});
    expect(settings).toMatchObject({...DEFAULT_SETTINGS, parent_messages_enabled: true});
    expect(settings.auto_billing_enabled).toBe(false);
    expect(settings.updated_by).toBe('admin_1');
    expect(db.store.finance_settings.main.updated_by).toBe('admin_1');
  });

  test('defaults match the SPEC', () => {
    expect(DEFAULT_SETTINGS).toEqual({
      auto_billing_enabled: false, parent_messages_enabled: false, issue_day: 25, due_day: 1,
      first_invoice_due_days: 3, reminder_days_before: 3, plaid: {connected: false}, whatsapp: {connected: false},
    });
  });

  test('keeps what is stored, including the connection status', async () => {
    const db = makeDb({finance_settings: {main: {issue_day: 20, plaid: {connected: true, last_sync: 'x'}}}});
    const {settings} = await update(db, {due_day: 5});
    expect(settings).toMatchObject({issue_day: 20, due_day: 5, plaid: {connected: true, last_sync: 'x'}, whatsapp: {connected: false}});
  });

  test('accepts the numbers in their ranges', async () => {
    const db = makeDb({});
    const {settings} = await update(db, {issue_day: 15, due_day: 28, first_invoice_due_days: 0, reminder_days_before: 14});
    expect(settings).toMatchObject({issue_day: 15, due_day: 28, first_invoice_due_days: 0, reminder_days_before: 14});
  });

  test.each([
    [{auto_billing_enabled: 'yes'}],
    [{parent_messages_enabled: 1}],
    [{issue_day: 0}],
    [{issue_day: 29}],
    [{due_day: 1.5}],
    [{due_day: '5'}],
    [{first_invoice_due_days: 31}],
    [{reminder_days_before: -1}],
    [{plaid: {connected: true}}],
    [{updated_by: 'someone'}],
    [{}],
    [null],
    [['auto_billing_enabled']],
  ])('refuses %j and writes nothing', async (patch) => {
    const db = makeDb({});
    await expect(update(db, patch)).rejects.toMatchObject({code: 'invalid-argument'});
    expect(db.store.finance_settings).toBeUndefined();
  });

  test('one bad key spoils the whole patch', async () => {
    const db = makeDb({});
    await expect(update(db, {parent_messages_enabled: true, plaid: {connected: true}})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(db.store.finance_settings).toBeUndefined();
  });
});
