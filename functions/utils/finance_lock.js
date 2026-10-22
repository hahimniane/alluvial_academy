/**
 * The closed-month lock. Every finance callable that changes a month's money
 * (invoice edits and cancels, payouts, expense changes, confirmations) calls
 * this first, so a closed month stays as it was until an owner reopens it.
 */

const functions = require('firebase-functions');

const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const labelOf = (month) => {
  const [year, number] = String(month).split('-').map(Number);
  return `${MONTH_NAMES[number - 1]} ${year}`;
};

/**
 * Throws `failed-precondition` when `finance_months/{month}` is closed.
 * A month with no record is open.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} month yyyy-MM
 */
async function assertMonthOpen(db, month) {
  if (typeof month !== 'string' || !MONTH_PATTERN.test(month)) {
    throw new functions.https.HttpsError('invalid-argument', 'A month (yyyy-MM) is required.');
  }
  const snap = await db.collection('finance_months').doc(month).get();
  if (snap.exists && snap.data() && snap.data().status === 'closed') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `${labelOf(month)} is closed. Reopen it to change it.`
    );
  }
}

/**
 * The same check, read INSIDE a transaction. A close that commits while a
 * money change is in flight conflicts with it (both touch finance_months/{month}),
 * so the change is retried and sees "closed" instead of slipping into a month
 * that was just locked. Callers keep the early `assertMonthOpen` as well, for
 * the quick plain-language message before any work is done.
 *
 * @param {FirebaseFirestore.Transaction} tx
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} month yyyy-MM
 */
async function assertMonthOpenInTransaction(tx, db, month) {
  if (typeof month !== 'string' || !MONTH_PATTERN.test(month)) {
    throw new functions.https.HttpsError('invalid-argument', 'A month (yyyy-MM) is required.');
  }
  const snap = await tx.get(db.collection('finance_months').doc(month));
  if (snap.exists && snap.data() && snap.data().status === 'closed') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `${labelOf(month)} is closed. Reopen it to change it.`
    );
  }
}

module.exports = {assertMonthOpen, assertMonthOpenInTransaction};
