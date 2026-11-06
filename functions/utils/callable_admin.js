const functions = require('firebase-functions');
const admin = require('firebase-admin');

const _lower = (value) => String(value == null ? '' : value).trim().toLowerCase();

const _truthy = (value) => {
  if (value === true) return true;
  const text = _lower(value);
  return text === 'true' || text === 'yes' || text === '1';
};

const _normalizeRole = (value) => _lower(value).replace(/[\s-]+/g, '_');

/**
 * Read the caller's identity off a callable invocation, whichever shape it
 * arrives in.
 *
 * Identity can arrive two ways. Callables declared with the v2 `onCall` are
 * handed one request object carrying `auth`; the older `(data, context)` shape
 * puts it on `context`. Both are accepted so a handler reads the caller
 * correctly whichever way it happens to be wired up — reaching into an absent
 * `context` throws a TypeError, which surfaces to the client as `internal`
 * instead of the `unauthenticated` the caller should see.
 *
 * @returns {Promise<{uid: string, token: object}|null>} null when no identity
 *   could be established.
 */
const resolveCallableCallerAuth = async (data, context) => {
  const requestData = (data && data.data) || data || {};
  const authToken = requestData.authToken || requestData.idToken;

  const callerAuth = (context && context.auth) || (data && data.auth) || null;
  if (callerAuth && callerAuth.uid) {
    return callerAuth;
  }

  if (authToken) {
    try {
      const decoded = await admin.auth().verifyIdToken(String(authToken));
      return {uid: decoded.uid, token: decoded};
    } catch (e) {
      console.log('Failed to verify auth token:', e.message);
    }
  }

  return null;
};

/**
 * Require an authenticated caller and return their identity.
 *
 * @returns {Promise<{uid: string, token: object}>}
 */
const requireCallableCaller = async (data, context, message) => {
  const callerAuth = await resolveCallableCallerAuth(data, context);
  if (!callerAuth || !callerAuth.uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      message || 'Authentication required'
    );
  }
  return callerAuth;
};

/**
 * The single admin gate for callables that create or expose accounts.
 *
 * @returns {Promise<{callerUid: string, effectiveAdminEmail: string|null}>}
 */
const verifyCallableCallerIsAdmin = async (data, context) => {
  const requestData = (data && data.data) || data || {};
  const {adminEmail} = requestData;

  const callerAuth = await requireCallableCaller(data, context);

  const callerUid = callerAuth.uid;
  const token = callerAuth.token || {};
  const tokenEmail = token.email ? String(token.email).toLowerCase() : null;
  const tokenRole = _normalizeRole(token.role || token.user_type || token.userType);
  const tokenIsAdmin =
    tokenRole === 'admin' ||
    tokenRole === 'administrator' ||
    tokenRole === 'super_admin' ||
    tokenRole === 'superadmin' ||
    _truthy(token.isAdmin) ||
    _truthy(token.is_admin) ||
    _truthy(token.admin) ||
    _truthy(token.is_super_admin) ||
    _truthy(token.isSuperAdmin);

  const effectiveAdminEmail = tokenEmail || (adminEmail ? String(adminEmail).toLowerCase() : null);

  const usersRef = admin.firestore().collection('users');
  let callerData = null;

  const tryRead = async (label, read) => {
    if (callerData) return;
    try {
      const result = await read();
      if (result) callerData = result;
    } catch (e) {
      console.log(`Error looking up caller by ${label}:`, e.message);
    }
  };

  await tryRead('uid doc', async () => {
    const doc = await usersRef.doc(callerUid).get();
    return doc.exists ? doc.data() : null;
  });
  if (effectiveAdminEmail) {
    await tryRead('email doc id', async () => {
      const doc = await usersRef.doc(effectiveAdminEmail).get();
      return doc.exists ? doc.data() : null;
    });
    await tryRead('e-mail field', async () => {
      const q = await usersRef.where('e-mail', '==', effectiveAdminEmail).limit(1).get();
      return q.empty ? null : q.docs[0].data();
    });
  }
  await tryRead('uid field', async () => {
    const q = await usersRef.where('uid', '==', callerUid).limit(1).get();
    return q.empty ? null : q.docs[0].data();
  });
  if (effectiveAdminEmail) {
    await tryRead('email field', async () => {
      const q = await usersRef.where('email', '==', effectiveAdminEmail).limit(1).get();
      return q.empty ? null : q.docs[0].data();
    });
  }

  if (!callerData && !tokenIsAdmin) {
    console.log(`Caller not found in users collection. uid=${callerUid}, email=${effectiveAdminEmail}`);
    throw new functions.https.HttpsError('permission-denied', 'Caller not found in users collection');
  }

  const callerUserType = _normalizeRole(
    callerData ? callerData.user_type || callerData.role || callerData.userType || '' : ''
  );
  const isAdminFromFirestore =
    callerUserType === 'admin' ||
    callerUserType === 'administrator' ||
    callerUserType === 'super_admin' ||
    callerUserType === 'superadmin' ||
    _truthy(callerData?.is_admin_teacher) ||
    _truthy(callerData?.is_admin) ||
    _truthy(callerData?.isAdmin) ||
    _truthy(callerData?.is_super_admin) ||
    _truthy(callerData?.isSuperAdmin);

  if (!tokenIsAdmin && !isAdminFromFirestore) {
    console.log(`Caller ${effectiveAdminEmail || callerUid} is not an admin. user_type: ${callerUserType || 'n/a'}`);
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only administrators can perform this action'
    );
  }

  return {callerUid, effectiveAdminEmail};
};

module.exports = {
  verifyCallableCallerIsAdmin,
  resolveCallableCallerAuth,
  requireCallableCaller,
};
