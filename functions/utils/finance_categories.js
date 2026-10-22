/**
 * Finance expense categories.
 *
 * Mirrors apps/web/src/lib/finance/model.ts (`normalizeLegacyCategory`) so the
 * server and the web pages read an old `finance_expenses.category` the same
 * way. See docs/finance/SPEC.md, money rule 4.
 */

/** Categories an admin can enter. Teacher and administrator pay are computed. */
const ENTERED_CATEGORIES = ['software', 'marketing', 'transfer_fees', 'other'];

/**
 * Old `finance_expenses.category` values written by the Flutter screen.
 * `null` means the row must not count toward totals: teacher and administrator
 * pay come from audits and Staff pay instead.
 */
const normalizeLegacyCategory = (raw) => {
  switch (String(raw == null ? '' : raw).trim()) {
    case 'software':
      return 'software';
    case 'marketing':
    case 'marketing_cost':
      return 'marketing';
    case 'transfer_fees':
      return 'transfer_fees';
    case 'teacher_payment':
    case 'teacher_pay':
    case 'leadership_cost':
    case 'admin_pay':
      return null;
    default:
      return 'other';
  }
};

module.exports = {ENTERED_CATEGORIES, normalizeLegacyCategory};
