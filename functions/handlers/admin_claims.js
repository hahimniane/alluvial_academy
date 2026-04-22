/**
 * Syncs Firebase Auth custom claims used by Storage rules for public_site_assets uploads.
 * Callable by any signed-in user; sets admin/isAdmin for full admins and admin-teachers,
 * plus is_admin_teacher / isAdminTeacher for dual-role teachers.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

function isAdminFromUserData(data) {
  if (!data || typeof data !== 'object') return false;
  const role = String(data.role || '').toLowerCase().replace(/-/g, '_');
  const userType = String(data.user_type || data.userType || '')
    .toLowerCase()
    .replace(/-/g, '_');
  if (role === 'admin' || role === 'super_admin' || role === 'admin_teacher') return true;
  if (userType === 'admin' || userType === 'super_admin' || userType === 'admin_teacher') return true;
  if (data.is_admin === true || data.isAdmin === true) return true;
  if (data.is_super_admin === true || data.isSuperAdmin === true) return true;
  if (data.is_admin_teacher === true || data.isAdminTeacher === true) return true;
  return false;
}

/** True when user is the dual-role "admin teacher" (not necessarily full admin). */
function isAdminTeacherFromUserData(data) {
  if (!data || typeof data !== 'object') return false;
  const role = String(data.role || '').toLowerCase().replace(/-/g, '_');
  const userType = String(data.user_type || data.userType || '')
    .toLowerCase()
    .replace(/-/g, '_');
  return (
    data.is_admin_teacher === true ||
    data.isAdminTeacher === true ||
    role === 'admin_teacher' ||
    userType === 'admin_teacher'
  );
}

async function loadUserRecordForCaller(uid, email) {
  const db = admin.firestore();
  let snap = await db.collection('users').doc(uid).get();
  if (snap.exists) return snap.data();

  if (email && typeof email === 'string') {
    const lower = email.toLowerCase();
    snap = await db.collection('users').doc(lower).get();
    if (snap.exists) return snap.data();
    snap = await db.collection('users').doc(email).get();
    if (snap.exists) return snap.data();
  }
  return null;
}

const syncPublicSiteAdminClaim = onCall(
  { cors: true, invoker: 'public', region: 'us-central1' },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Sign in required');
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email || null;
    const data = await loadUserRecordForCaller(uid, email);
    const isAdmin = isAdminFromUserData(data);
    const isAdminTeacher = isAdminTeacherFromUserData(data);

    const userRecord = await admin.auth().getUser(uid);
    const prev =
      userRecord.customClaims && typeof userRecord.customClaims === 'object'
        ? { ...userRecord.customClaims }
        : {};

    await admin.auth().setCustomUserClaims(uid, {
      ...prev,
      admin: isAdmin,
      isAdmin: isAdmin,
      is_admin_teacher: isAdminTeacher,
      isAdminTeacher: isAdminTeacher,
    });

    return { ok: true, admin: isAdmin, isAdminTeacher };
  }
);

module.exports = {
  syncPublicSiteAdminClaim,
};
