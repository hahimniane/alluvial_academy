/**
 * Whether an existing account may be linked to a child as its parent.
 *
 * Linking stamps `user_type: 'parent'` on the account, so it is only allowed
 * on an account that already is a parent (or has no role yet, or carries
 * "parent" as a secondary role). Applied to an admin, teacher or student it
 * would silently rewrite who that person is — an admin enrolling their own
 * child would lose the admin console.
 *
 * Pure so both the pre-flight lookup and the invite itself share one answer.
 */
const parentAccountDecision = (data) => {
  const record = data && typeof data === 'object' ? data : {};
  const role = String(record.user_type || record.role || '').trim().toLowerCase();
  const secondary = Array.isArray(record.secondary_roles)
    ? record.secondary_roles.map((r) => String(r).trim().toLowerCase())
    : [];
  const canLink = role === '' || role === 'parent' || role === 'guardian' || secondary.includes('parent');
  return {canLink, role};
};

const displayName = (data) =>
  [(data || {}).first_name, (data || {}).last_name].map((v) => String(v || '').trim()).filter(Boolean).join(' ');

module.exports = {parentAccountDecision, displayName};
