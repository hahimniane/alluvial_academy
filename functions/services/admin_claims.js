/**
 * Admin custom claims on Firebase Auth tokens.
 *
 * `syncPublicSiteAdminClaim` writes `admin` / `isAdmin` (and the admin-teacher
 * pair) onto a person's token so Storage rules let them upload site images.
 * Firestore rules `isAdmin()` also trust `token.isAdmin`, `token.is_admin` and
 * an admin `token.role`. A claim stays on the account until something rewrites
 * it, so a person demoted on their user document kept admin rights through
 * their token. `clearDemotedAdminClaims` removes them when the user document
 * stops making the person an admin.
 *
 * A token already issued keeps its claims until it refreshes (at most an
 * hour); the next token has none.
 */

const ADMIN_LIKE = new Set(['admin', 'super_admin', 'admin_teacher']);

const normalized = (value) => String(value == null ? '' : value).toLowerCase().replace(/-/g, '_');

/** Whether a user document makes the person an admin (full admin, super admin or admin-teacher). */
function isAdminFromUserData(data) {
  if (!data || typeof data !== 'object') return false;
  const role = normalized(data.role);
  const userType = normalized(data.user_type || data.userType);
  if (ADMIN_LIKE.has(role) || ADMIN_LIKE.has(userType)) return true;
  if (data.is_admin === true || data.isAdmin === true) return true;
  if (data.is_super_admin === true || data.isSuperAdmin === true) return true;
  if (data.is_admin_teacher === true || data.isAdminTeacher === true) return true;
  return false;
}

/** True when the user is the dual-role "admin teacher" (not necessarily a full admin). */
function isAdminTeacherFromUserData(data) {
  if (!data || typeof data !== 'object') return false;
  const role = normalized(data.role);
  const userType = normalized(data.user_type || data.userType);
  return (
    data.is_admin_teacher === true ||
    data.isAdminTeacher === true ||
    role === 'admin_teacher' ||
    userType === 'admin_teacher'
  );
}

const ADMIN_FLAG_CLAIMS = ['admin', 'isAdmin', 'is_admin', 'is_admin_teacher', 'isAdminTeacher'];

const truthyClaim = (value) => value === true || normalized(value) === 'true';

/** Claims with every admin grant turned off; other claims are kept as they are. */
function claimsWithoutAdmin(claims) {
  const current = claims && typeof claims === 'object' ? claims : {};
  const next = { ...current };
  let changed = false;
  for (const key of ADMIN_FLAG_CLAIMS) {
    if (truthyClaim(current[key])) {
      next[key] = false;
      changed = true;
    }
  }
  if (ADMIN_LIKE.has(normalized(current.role)) || normalized(current.role) === 'superadmin') {
    delete next.role;
    changed = true;
  }
  return { changed, next };
}

/** The user document went from "admin" to "not admin" (a deletion is not a demotion). */
const demotedFromAdmin = (before, after) => !!before && !!after && isAdminFromUserData(before) && !isAdminFromUserData(after);

/**
 * Called by the users write trigger. Does nothing unless this write demoted
 * the person; then clears admin claims on their Auth account, if any.
 */
async function clearDemotedAdminClaims({ before, after, docId, auth }) {
  if (!demotedFromAdmin(before, after)) return { demoted: false, cleared: false };
  const uid = String((after && after.uid) || (before && before.uid) || docId || '').trim();
  if (!uid) return { demoted: true, cleared: false };
  let user;
  try {
    user = await auth.getUser(uid);
  } catch (e) {
    if (e && e.code === 'auth/user-not-found') return { demoted: true, cleared: false };
    throw e;
  }
  const { changed, next } = claimsWithoutAdmin(user.customClaims);
  if (!changed) return { demoted: true, cleared: false };
  await auth.setCustomUserClaims(uid, next);
  return { demoted: true, cleared: true, uid };
}

module.exports = {
  isAdminFromUserData,
  isAdminTeacherFromUserData,
  claimsWithoutAdmin,
  demotedFromAdmin,
  clearDemotedAdminClaims,
};
