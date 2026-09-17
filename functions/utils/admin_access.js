'use strict';

/**
 * Is the caller an administrator.
 *
 * The same few lines had been written inline in five handlers, each free to
 * drift from the others — which for an access check means one of them quietly
 * becoming wrong. New code uses this; the existing copies are left alone rather
 * than churning five working files at once.
 *
 * A custom claim is trusted without a read, because it is signed. Otherwise the
 * user document decides, and the shapes accepted here are the ones that exist in
 * the data: `role`, `user_type`, and the assorted is_admin flags.
 */

const admin = require('firebase-admin');

const ADMIN_ROLES = new Set(['admin', 'super_admin']);

const _role = (source = {}) => String(
  source.role || source.user_type || source.userType || '',
).trim().toLowerCase();

/** An admin by their user document. */
const isAdminUser = (data = {}) =>
  ADMIN_ROLES.has(_role(data)) ||
  data.is_admin === true ||
  data.isAdmin === true ||
  data.is_super_admin === true ||
  data.isSuperAdmin === true;

/** An admin by signed token claim, which needs no lookup. */
const hasAdminClaims = (token = {}) => {
  if (!token || typeof token !== 'object') return false;
  return token.admin === true || token.is_admin === true || ADMIN_ROLES.has(_role(token));
};

/** An admin either way. Reads the user document only when the claim is absent. */
const isAdminRequester = async ({ uid, authToken, db = null }) => {
  if (!uid) return false;
  if (hasAdminClaims(authToken)) return true;
  const firestore = db || admin.firestore();
  const doc = await firestore.collection('users').doc(uid).get();
  return doc.exists && isAdminUser(doc.data() || {});
};

module.exports = { isAdminUser, hasAdminClaims, isAdminRequester };
