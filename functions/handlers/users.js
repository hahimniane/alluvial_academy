const functions = require('firebase-functions');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const {onDocumentDeleted} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const {generateRandomPassword} = require('../utils/password');
const {credentialRef} = require('../services/student_credentials');
const {sendWelcomeEmail} = require('../services/email/senders');
const studentHandlers = require('./students');
const {
  applyDecisionAuditWrites,
  buildDecisionAuditWrites,
  resolveDecisionActor,
} = require('../services/decision_audit');

const STAFF_TYPES = new Set(['admin', 'teacher']);
const MAX_BATCH_USERS = 25;

const _badInput = (message) => new functions.https.HttpsError('invalid-argument', message);

/**
 * The hourly rate typed for a new admin or teacher, or null when none was
 * given. Saved as users.hourly_rate, which wage management and the tontine
 * eligibility read.
 */
const _hourlyRateOf = (value) => {
  if (value === undefined || value === null || String(value).trim() === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > 1000) {
    throw _badInput('Hourly rate must be a number from 0 to 1000.');
  }
  return Math.round(n * 100) / 100;
};

/**
 * Creates one admin, teacher or parent account with a real email: the Auth
 * user, the users/{uid} profile, a family code for a parent, and the welcome
 * email with a temporary password. `callerUid` must be a verified admin.
 */
const _createAccountWithEmail = async (userData, callerUid) => {
  const {
    email,
    firstName,
    lastName,
    phoneNumber,
    countryCode,
    userType,
    title,
    kioskCode,
    hourlyRate,
  } = userData || {};

  const missingFields = [];
  if (!email || String(email).trim() === '') missingFields.push('email');
  if (!firstName || String(firstName).trim() === '') missingFields.push('firstName');
  if (!lastName || String(lastName).trim() === '') missingFields.push('lastName');
  if (missingFields.length > 0) {
    throw _badInput(`Missing required fields: ${missingFields.join(', ')}`);
  }

  const type = String(userType || '').trim().toLowerCase() || 'teacher';
  const rate = STAFF_TYPES.has(type) ? _hourlyRateOf(hourlyRate) : null;
  const cleanEmail = String(email).toLowerCase().trim();
  const first = String(firstName).trim();
  const last = String(lastName).trim();

  const password = generateRandomPassword();
  const userRecord = await admin.auth().createUser({
    email: cleanEmail,
    password,
    displayName: `${first} ${last}`,
    emailVerified: false,
  });
  console.log(`Auth user created with UID: ${userRecord.uid}`);

  const kiosqueCode = type === 'parent' ? await generateKiosqueCode() : null;

  const firestoreData = {
    first_name: first,
    last_name: last,
    'e-mail': cleanEmail,
    phone_number: phoneNumber || '',
    country_code: countryCode || '+1',
    user_type: type,
    title: title || 'Teacher',
    kiosk_code: kioskCode || '123',
    kiosque_code: kiosqueCode, // Family/parent identifier code
    date_added: admin.firestore.FieldValue.serverTimestamp(),
    last_login: null,
    employment_start_date: admin.firestore.FieldValue.serverTimestamp(),
    is_active: true,
    email_verified: false,
    uid: userRecord.uid,
    created_by_admin: true,
    created_by_uid: callerUid,
    password_reset_required: true,
  };
  if (rate !== null) firestoreData.hourly_rate = rate;

  await admin.firestore().collection('users').doc(userRecord.uid).set(firestoreData);
  console.log(`Firestore document created for UID: ${userRecord.uid}`);

  // The account exists at this point. A mail failure is reported to the
  // caller as emailSent:false rather than thrown, so a transport outage
  // never leaves an admin believing no account was created.
  let emailSent = false;
  try {
    emailSent = await sendWelcomeEmail(cleanEmail, first, last, password, type, kiosqueCode);
  } catch (mailError) {
    console.error('Welcome email failed for', cleanEmail, '-', mailError.message);
  }

  return {success: true, uid: userRecord.uid, email: cleanEmail, emailSent};
};

const createUserWithEmail = async (data, context) => {
  console.log('--- NEW INVOCATION (v5) ---');
  const {callerUid} = await _verifyCallableCallerIsAdmin(data, context);
  try {
    if (!data || typeof data !== 'object') {
      throw _badInput('Data must be an object');
    }
    const userData = data.data || data;
    console.log('createUserWithEmail', {userType: userData.userType || 'MISSING'});
    const result = await _createAccountWithEmail(userData, callerUid);
    return {
      success: true,
      uid: result.uid,
      emailSent: result.emailSent,
      message: `User created, email status: ${result.emailSent}`,
    };
  } catch (error) {
    console.error('--- FULL FUNCTION ERROR (v5) ---');
    console.error('ERROR MESSAGE:', error.message);
    if (error instanceof functions.https.HttpsError && error.code === 'invalid-argument') throw error;
    throw new functions.https.HttpsError('internal', error.message, error.stack);
  }
};

const _truthyFlag = (value) =>
  value === true || (typeof value === 'string' && ['true', '1', 'yes', 'y'].includes(value.trim().toLowerCase()));

/**
 * One row of a batch that is a student. A minor needs a parent here: the Add
 * users screen only offers a minor with a parent picked, and the batch has
 * no later step that could link one.
 */
const _createBatchStudent = async (userData, callerUid) => {
  const {
    email,
    firstName,
    lastName,
    phoneNumber,
    kioskCode,
    isAdultStudent,
    guardianIds,
    guardianId,
    guardian_id: guardianIdSnake,
  } = userData;
  const hasEmail = typeof email === 'string' && email.trim().length > 0;
  const isAdult = typeof isAdultStudent === 'boolean' ? isAdultStudent
    : (typeof isAdultStudent === 'string' ? _truthyFlag(isAdultStudent) : hasEmail);

  let guardians = Array.isArray(guardianIds) ? guardianIds.map((g) => String(g || '').trim()).filter(Boolean) : [];
  const single = guardianId || guardianIdSnake;
  if (!guardians.length && typeof single === 'string' && single.trim()) guardians = [single.trim()];

  // Best-effort: a kiosk code given instead of a parent id names the parent.
  if (!guardians.length && typeof kioskCode === 'string' && kioskCode.trim()) {
    const code = kioskCode.trim();
    const usersRef = admin.firestore().collection('users');
    let parentSnap = await usersRef.where('kiosk_code', '==', code).limit(1).get();
    if (parentSnap.empty) parentSnap = await usersRef.where('kiosque_code', '==', code).limit(1).get();
    if (!parentSnap.empty) {
      const parentDoc = parentSnap.docs[0];
      if (String((parentDoc.data() || {}).user_type || '').toLowerCase() === 'parent') guardians = [parentDoc.id];
    }
  }

  if (!isAdult && !guardians.length) {
    throw _badInput('A minor student needs a parent or guardian.');
  }

  const payload = {firstName, lastName, phoneNumber, isAdultStudent: isAdult};
  if (hasEmail) payload.email = email;
  if (guardians.length) payload.guardianIds = guardians;
  return studentHandlers.createStudentAccountAsCaller(payload, callerUid);
};

/**
 * Creates several accounts in one call, in row order, and reports every row:
 * a failure on one row never stops or hides the others. Each result carries
 * the row's `index` so the caller can tell which person it is about.
 */
const createMultipleUsers = async (data, context) => {
  const {callerUid} = await _verifyCallableCallerIsAdmin(data, context);
  const payload = (data && data.data) || data || {};
  if (!Array.isArray(payload.users) || payload.users.length === 0) {
    throw _badInput('Users array is required');
  }
  if (payload.users.length > MAX_BATCH_USERS) {
    throw _badInput(`Add at most ${MAX_BATCH_USERS} people at a time.`);
  }
  console.log(`createMultipleUsers: ${payload.users.length} rows`);

  const results = [];
  const errors = [];
  for (let i = 0; i < payload.users.length; i += 1) {
    const userData = payload.users[i] && typeof payload.users[i] === 'object' ? payload.users[i] : {};
    const type = String(userData.userType || '').trim().toLowerCase();
    try {
      if (type === 'student') {
        const studentResult = await _createBatchStudent(userData, callerUid);
        results.push({
          index: i,
          userType: 'student',
          email: studentResult.aliasEmail || studentResult.studentCode || userData.email || 'student',
          success: true,
          existing: studentResult.existing === true,
          result: studentResult,
        });
        continue;
      }
      const result = await _createAccountWithEmail(userData, callerUid);
      results.push({
        index: i,
        userType: type || 'teacher',
        email: result.email,
        success: true,
        result: {
          ...result,
          message: result.emailSent
            ? 'User created successfully and welcome email sent'
            : 'User created successfully but email sending failed',
        },
      });
    } catch (error) {
      console.error(`Row ${i + 1} failed:`, error.message);
      errors.push({
        index: i,
        userType: type,
        email: userData.email || 'unknown',
        success: false,
        error: error.message || 'Could not create this account.',
      });
    }
  }

  return {
    totalUsers: payload.users.length,
    successful: results.length,
    failed: errors.length,
    results,
    errors,
  };
};

const createUser = async (data, context) => {
  // Support both callable shapes:
  // - v1: (data, context) where `data` is the payload
  // - v2-style wrapper sometimes passed through as `{ data: payload }`
  const {callerUid} = await _verifyCallableCallerIsAdmin(data, context);

  const requestData = (data && data.data) || data || {};
  console.log('received data:', requestData);
  try {
    console.log('Received data:', {
      email: requestData.email,
      firstName: requestData.firstName,
      lastName: requestData.lastName,
      hasPassword: !!requestData.password,
    });

    if (!requestData || typeof requestData !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'Data must be an object');
    }

    const email = String(requestData.email || '').trim();
    const password = String(requestData.password || '');
    const firstName = String(requestData.firstName || '').trim();
    const lastName = String(requestData.lastName || '').trim();

    const validationResults = {
      hasEmail: !!email,
      hasPassword: !!password,
      hasFirstName: !!firstName,
      hasLastName: !!lastName,
      email,
      firstName,
      lastName,
    };
    console.log('Validation results:', validationResults);

    if (!email || !password || !firstName || !lastName) {
      const missingFields = [];
      if (!email) missingFields.push('email');
      if (!password) missingFields.push('password');
      if (!firstName) missingFields.push('firstName');
      if (!lastName) missingFields.push('lastName');

      throw new functions.https.HttpsError(
        'invalid-argument',
        `Missing required fields: ${missingFields.join(', ')}`
      );
    }

    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: `${firstName} ${lastName}`,
        emailVerified: false,
      });
    } catch (authError) {
      const errorCode = authError.code || 'unknown';
      const errorMessage = authError.message || 'Authentication failed';

      if (errorCode === 'auth/email-already-exists') {
        throw new functions.https.HttpsError('already-exists', 'Email already registered');
      }

      throw new functions.https.HttpsError('internal', errorMessage);
    }

    const firestoreData = {
      country_code: String(requestData.countryCode || '+1'),
      date_added: admin.firestore.FieldValue.serverTimestamp(),
      'e-mail': email,
      employment_start_date: admin.firestore.FieldValue.serverTimestamp(),
      first_name: firstName,
      kiosk_code: String(requestData.kioskCode || '123'),
      last_login: null,
      last_name: lastName,
      phone_number: String(requestData.phoneNumber || ''),
      title: String(requestData.title || 'Teacher'),
      user_type: String(requestData.userType || 'teacher'),
      uid: userRecord.uid,
      is_active: true,
      created_by_uid: callerUid,
    };

    try {
      await admin.firestore().collection('users').doc(userRecord.uid).set(firestoreData);
    } catch (firestoreError) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
      } catch (cleanupError) {
        console.error('Cleanup failed for uid:', userRecord.uid);
      }

      throw new functions.https.HttpsError('internal', 'Failed to create user profile');
    }

    return {
      uid: userRecord.uid,
      email,
      message: 'User created successfully',
    };
  } catch (error) {
    console.error('Error in createUser:', {
      code: error.code,
      message: error.message,
      details: error.details,
    });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', 'An unexpected error occurred');
  }
};

const _isArray = (value) => Array.isArray(value);
const _asStringArray = (value) =>
  _isArray(value) ? value.map((v) => String(v)).filter((v) => v.trim().length > 0) : null;

const _lower = (value) => (value == null ? '' : String(value).trim().toLowerCase());
const _truthy = (value) => {
  if (value === true) return true;
  if (value === 1) return true;
  if (typeof value === 'string') {
    const v = value.trim().toLowerCase();
    return v === 'true' || v === '1' || v === 'yes';
  }
  return false;
};
const _normalizeRole = (value) => _lower(value).replace(/[\s-]+/g, '_');

const PUBLIC_SITE_CMS_TEAM = 'public_site_cms_team';

/** Decode Firebase Storage download URL and delete the object (best-effort). */
const _deleteFileByFirebaseDownloadURL = async (url) => {
  if (!url || typeof url !== 'string') return;
  try {
    const m = url.match(/\/o\/([^?]+)/);
    if (!m) return;
    const filePath = decodeURIComponent(m[1]);
    await admin.storage().bucket().file(filePath).delete({ignoreNotFound: true});
  } catch (e) {
    console.log('[Storage] Best-effort delete failed:', e.message);
  }
};

/**
 * Collect Firestore refs + image URLs for public team rows linked to any of the given user ids.
 * Caller adds refs to a write batch, then deletes Storage URLs after commit.
 */
const _collectPublicSiteTeamBatchDeletes = async (db, userIds) => {
  const ids = Array.from(new Set((userIds || []).map((u) => String(u).trim()).filter(Boolean)));
  const refs = [];
  const urls = [];
  for (const uid of ids) {
    try {
      const snap = await db.collection(PUBLIC_SITE_CMS_TEAM).where('linkedUserUid', '==', uid).get();
      for (const doc of snap.docs) {
        refs.push(doc.ref);
        const img = doc.data()?.imageUrl;
        if (img) urls.push(String(img));
      }
    } catch (e) {
      console.log(`[collectPublicSiteTeam] query failed for uid=${uid}:`, e.message);
    }
  }
  return {refs, urls};
};

/**
 * Delete public team CMS docs linked to any of the given user ids, then remove Storage images.
 * Used from the users/{userId} onDelete trigger (safety net if user doc is removed outside deleteUserAccount).
 */
const _purgePublicSiteTeamProfilesForUserIds = async (db, userIds) => {
  const ids = Array.from(new Set((userIds || []).map((u) => String(u).trim()).filter(Boolean)));
  const imageUrls = [];
  for (const uid of ids) {
    try {
      const snap = await db.collection(PUBLIC_SITE_CMS_TEAM).where('linkedUserUid', '==', uid).get();
      for (const doc of snap.docs) {
        const d = doc.data() || {};
        const img = d.imageUrl ? String(d.imageUrl) : '';
        if (img) imageUrls.push(img);
        await doc.ref.delete();
      }
    } catch (e) {
      console.log(`[purgePublicSiteTeam] query/delete failed for uid=${uid}:`, e.message);
    }
  }
  for (const url of imageUrls) {
    await _deleteFileByFirebaseDownloadURL(url);
  }
};

const _shiftStartMillis = (data) => {
  const raw = data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime;
  if (!raw) return null;
  if (typeof raw.toMillis === 'function') return raw.toMillis();
  if (raw instanceof Date) return raw.getTime();
  if (typeof raw === 'number') return raw;
  if (typeof raw === 'string') {
    const t = Date.parse(raw);
    return Number.isNaN(t) ? null : t;
  }
  if (typeof raw.seconds === 'number') return raw.seconds * 1000;
  if (typeof raw._seconds === 'number') return raw._seconds * 1000;
  return null;
};

/**
 * "Also delete classes" removes only classes that have not started yet. Past
 * and running classes stay, and so does every timesheet and class report:
 * they are the pay and attendance record (owner decision D3).
 */
const _isUpcomingShift = (data, nowMs) => {
  const start = _shiftStartMillis(data);
  return start != null && start > nowMs;
};

const _cleanupTeachingShiftsForDeletedUser = async ({
  db,
  userType,
  userIdsToRemove,
  userData,
  nowMs = Date.now(),
}) => {
  const shiftsRef = db.collection('teaching_shifts');
  const idsToRemove = userIdsToRemove.map(String);
  const userFullName = `${userData?.first_name || ''} ${userData?.last_name || ''}`.trim();

  const summary = {
    shiftsDeleted: 0,
    shiftsUpdated: 0,
    shiftsKept: 0,
  };

  // Write batching (keep margin under 500 ops)
  let batch = db.batch();
  let opCount = 0;

  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  const queueDelete = async (ref) => {
    batch.delete(ref);
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  };

  const queueUpdate = async (ref, data) => {
    batch.update(ref, data);
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  };

  const addQueryDocs = (into, snapshot) => {
    for (const doc of snapshot.docs) {
      into.set(doc.id, doc);
    }
  };

  const shiftDocs = new Map();

  if (userType === 'teacher') {
    for (const id of idsToRemove) {
      for (const field of ['teacher_id', 'teacherId']) {
        try {
          const snap = await shiftsRef.where(field, '==', id).get();
          addQueryDocs(shiftDocs, snap);
        } catch (e) {
          console.log(`[DeleteUserAccount] Error querying teaching_shifts by ${field}:`, e.message);
        }
      }
    }

    for (const doc of shiftDocs.values()) {
      const data = doc.data() || {};
      const assignedTeacherId = String(data.teacher_id || data.teacherId || '');
      if (!idsToRemove.includes(assignedTeacherId)) continue;
      if (!_isUpcomingShift(data, nowMs)) {
        summary.shiftsKept += 1;
        continue;
      }

      await queueDelete(doc.ref);
      summary.shiftsDeleted += 1;
    }

    await flush();
    return summary;
  }

  if (userType === 'student') {
    for (const id of idsToRemove) {
      for (const field of ['student_ids', 'studentIds']) {
        try {
          const snap = await shiftsRef.where(field, 'array-contains', id).get();
          addQueryDocs(shiftDocs, snap);
        } catch (e) {
          console.log(
            `[DeleteUserAccount] Error querying teaching_shifts array by ${field}:`,
            e.message
          );
        }
      }
    }

    const nameLower = _lower(userFullName);

    for (const doc of shiftDocs.values()) {
      const data = doc.data() || {};

      const idsSnake = _asStringArray(data.student_ids);
      const idsCamel = _asStringArray(data.studentIds);
      const ids = idsSnake || idsCamel || [];

      const hasTarget = ids.some((id) => idsToRemove.includes(id));
      if (!hasTarget) continue;
      if (!_isUpcomingShift(data, nowMs)) {
        summary.shiftsKept += 1;
        continue;
      }

      const remainingIds = ids.filter((id) => !idsToRemove.includes(id));

      if (remainingIds.length === 0) {
        await queueDelete(doc.ref);
        summary.shiftsDeleted += 1;
        continue;
      }

      const updates = {
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (idsSnake != null) {
        updates.student_ids = remainingIds;
      }
      if (idsCamel != null) {
        updates.studentIds = remainingIds;
      }

      // Best-effort: keep student names aligned with IDs.
      const namesSnake = _asStringArray(data.student_names);
      if (namesSnake != null) {
        let nextNames = namesSnake;
        if (idsSnake != null && namesSnake.length === idsSnake.length) {
          nextNames = namesSnake.filter((_, idx) => !idsToRemove.includes(idsSnake[idx]));
        } else if (nameLower) {
          nextNames = namesSnake.filter((n) => _lower(n) !== nameLower);
        }
        updates.student_names = nextNames;
      }

      const namesCamel = _asStringArray(data.studentNames);
      if (namesCamel != null) {
        let nextNames = namesCamel;
        if (idsCamel != null && namesCamel.length === idsCamel.length) {
          nextNames = namesCamel.filter((_, idx) => !idsToRemove.includes(idsCamel[idx]));
        } else if (nameLower) {
          nextNames = namesCamel.filter((n) => _lower(n) !== nameLower);
        }
        updates.studentNames = nextNames;
      }

      await queueUpdate(doc.ref, updates);
      summary.shiftsUpdated += 1;
    }

    await flush();
    return summary;
  }

  return summary;
};

/**
 * Verifies the callable caller is an admin (same logic as deleteUserAccount).
 * @returns {Promise<{callerUid: string, effectiveAdminEmail: string|null}>}
 */
const _verifyCallableCallerIsAdmin = (data, context) =>
  verifyCallableCallerIsAdmin(data, context);
/** Admin-only directory search for linking public team profiles to real users. */
const adminSearchDirectoryUsers = async (data, context) => {
  await _verifyCallableCallerIsAdmin(data, context);

  const requestData = (data && data.data) || data || {};
  const rawQ = String(requestData.query || '').trim();
  if (rawQ.length < 2) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Query must be at least 2 characters'
    );
  }
  const qLower = rawQ.toLowerCase();
  const limit = Math.min(25, Math.max(1, parseInt(requestData.limit, 10) || 25));

  const db = admin.firestore();
  const usersRef = db.collection('users');
  const out = [];
  const seen = new Set();

  const pushDoc = (doc) => {
    if (out.length >= limit) return;
    const d = doc.data() || {};
    if (d.is_active === false) return;
    const uidField = d.uid ? String(d.uid) : doc.id;
    const key = uidField || doc.id;
    if (seen.has(key)) return;
    seen.add(key);
    const email = (d['e-mail'] || d.email || '').toString();
    const fn = (d.first_name || d['first-name'] || '').toString();
    const ln = (d.last_name || d['last-name'] || '').toString();
    const displayName = `${fn} ${ln}`.trim() || email || doc.id;
    const userType = (d.user_type || d.userType || d.role || '').toString();
    out.push({
      uid: uidField || doc.id,
      docId: doc.id,
      email,
      displayName,
      userType,
    });
  };

  if (rawQ.length >= 20) {
    const byId = await usersRef.doc(rawQ).get();
    if (byId.exists) pushDoc(byId);
  }

  const exactEmail = await usersRef.where('e-mail', '==', qLower).limit(limit).get();
  exactEmail.docs.forEach(pushDoc);

  const prefixSnap = await usersRef
    .where('e-mail', '>=', qLower)
    .where('e-mail', '<=', `${qLower}\uf8ff`)
    .limit(limit)
    .get();
  prefixSnap.docs.forEach(pushDoc);

  return {users: out.slice(0, limit)};
};

const onUserDeletedCleanupPublicTeam = onDocumentDeleted(
  {document: 'users/{userId}', region: 'us-central1'},
  async (event) => {
    const userId = event.params.userId;
    try {
      await _purgePublicSiteTeamProfilesForUserIds(admin.firestore(), [userId]);
    } catch (e) {
      console.error('[onUserDeletedCleanupPublicTeam]', e);
    }
  }
);

const deleteUserAccount = async (data, context) => {
  console.log('Raw data received - type:', typeof data);
  const requestData = (data && data.data) || data || {};

  const {email, adminEmail} = requestData;
  const targetId = String(requestData.userId || requestData.uid || '').trim();
  const deleteClasses =
    requestData.deleteClasses === true ||
    requestData.delete_classes === true ||
    requestData.deleteAssociatedClasses === true;

  console.log('Extracted email:', email);
  console.log('Extracted adminEmail:', adminEmail);
  console.log('Delete classes flag:', deleteClasses);

  if (!targetId && !email) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required');
  }

  const {callerUid, effectiveAdminEmail} = await _verifyCallableCallerIsAdmin(data, context);

  try {
    // By document id. The email lookup stays for older app builds that only
    // send an email.
    let userDoc;
    if (targetId) {
      userDoc = await admin.firestore().collection('users').doc(targetId).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User not found in database');
      }
    } else {
      const userQuery = await admin
        .firestore()
        .collection('users')
        .where('e-mail', '==', String(email).toLowerCase())
        .limit(1)
        .get();
      if (userQuery.empty) {
        throw new functions.https.HttpsError('not-found', 'User not found in database');
      }
      userDoc = userQuery.docs[0];
    }

    const userData = userDoc.data() || {};
    const userId = userDoc.id;
    const canonicalUserId = userData.uid ? String(userData.uid) : userId;
    const targetEmail = String(userData['e-mail'] || userData.email || email || '').trim();

    if (userId === callerUid || canonicalUserId === callerUid) {
      throw new functions.https.HttpsError('failed-precondition', 'You cannot delete your own account');
    }

    console.log(`Admin ${callerUid} deleting user ${userId}`);

    const isActive = userData.is_active !== false;
    console.log(`User active status: ${userData.is_active} (isActive: ${isActive})`);

    if (isActive) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'User must be deactivated (archived) before deletion'
      );
    }

    let deletedFromAuth = false;
    try {
      // Prefer deleting by UID to support student accounts where Auth email may be an alias.
      if (!canonicalUserId) {
        throw new Error('No canonical UID available');
      }
      await admin.auth().deleteUser(canonicalUserId);
      deletedFromAuth = true;
      console.log(`Successfully deleted user from Firebase Auth by uid: ${canonicalUserId}`);
    } catch (authErrorByUid) {
      console.log(`Auth delete by uid failed (uid=${canonicalUserId}):`, authErrorByUid.message);
      try {
        if (!targetEmail) throw new Error('No email on the profile');
        const authUser = await admin.auth().getUserByEmail(targetEmail);
        // Only the sign-in account this profile belongs to, never another
        // person who shares the address (minors often carry a parent's).
        if (authUser.uid !== userId && authUser.uid !== canonicalUserId) {
          throw new Error('The sign-in account with this email belongs to another profile');
        }
        await admin.auth().deleteUser(authUser.uid);
        deletedFromAuth = true;
      } catch (authError) {
        console.log(`No sign-in account deleted for ${userId}:`, authError.message);
      }
    }

    const userIdsToPurge = Array.from(new Set([userId, canonicalUserId].filter(Boolean)));

    const batch = admin.firestore().batch();
    const deletionActor = await resolveDecisionActor(
      admin.firestore(),
      callerUid,
      {actor_email: effectiveAdminEmail}
    );
    const decisionWrites = buildDecisionAuditWrites({
      db: admin.firestore(),
      entityType: 'user',
      entityId: userId,
      entityLabel:
        `${userData.first_name || ''} ${userData.last_name || ''}`.trim() ||
        targetEmail ||
        userId,
      action: 'user.deleted',
      actor: deletionActor,
      source: 'deleteUserAccount',
      metadata: {
        deleted_user_email: targetEmail.toLowerCase(),
        deleted_user_type: (
          userData.user_type ||
          userData.userType ||
          userData.role ||
          ''
        ).toString(),
        delete_associated_classes: deleteClasses,
        delete_classes_scope: deleteClasses ? 'upcoming' : 'none',
      },
      eventId: `user_deleted_${userId}_${Date.now()}`,
    });
    applyDecisionAuditWrites(batch, decisionWrites);
    batch.delete(userDoc.ref);
    // In case this project has duplicate user docs (legacy schemas), also delete the canonical UID doc.
    if (canonicalUserId && canonicalUserId !== userId) {
      batch.delete(admin.firestore().collection('users').doc(canonicalUserId));
    }

    // Best-effort cleanup for parent/student relationships and auxiliary collections.
    const userType = (userData.user_type || userData.userType || userData.role || '')
      .toString()
      .trim()
      .toLowerCase();

    // Family links are read from BOTH sides and BOTH spellings: the student's
    // guardian_ids / guardianIds (and the legacy single guardian_id /
    // parent_id / parentId), and every account whose children_ids /
    // childrenIds names them. Reading only the deleted person's own list left
    // dangling ids on the other side whenever a link was one-sided.
    const usersCol = admin.firestore().collection('users');
    // Links may name the document id or the uid field (they differ only on old email-keyed docs).
    const selfIds = [...new Set([userId, canonicalUserId].filter(Boolean).map(String))];
    const idsOf = (...lists) => {
      const out = new Set();
      for (const list of lists) {
        for (const v of Array.isArray(list) ? list : [list]) {
          if (typeof v === 'string' && v.trim() && !selfIds.includes(v.trim())) out.add(v.trim());
        }
      }
      return out;
    };
    const idsWhere = async (field) => {
      const found = [];
      for (const id of selfIds) {
        try {
          const snap = await usersCol.where(field, 'array-contains', id).get();
          found.push(...snap.docs.map((d) => d.id));
        } catch (e) {
          console.log(`Link lookup on ${field} failed:`, e.message);
        }
      }
      return found;
    };
    const unlinkFrom = async (otherIds, arrayFields, singleFields) => {
      for (const otherId of otherIds) {
        try {
          const ref = usersCol.doc(String(otherId));
          const snap = await ref.get();
          if (!snap.exists) continue;
          const data = snap.data() || {};
          const updates = {};
          for (const field of arrayFields) {
            if (Array.isArray(data[field]) && data[field].some((v) => selfIds.includes(v))) {
              updates[field] = admin.firestore.FieldValue.arrayRemove(...selfIds);
            }
          }
          for (const field of singleFields) {
            if (selfIds.includes(data[field])) updates[field] = admin.firestore.FieldValue.delete();
          }
          if (Object.keys(updates).length === 0) continue;
          updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
          batch.update(ref, updates);
        } catch (e) {
          console.log(`Error removing the link from ${otherId}:`, e.message);
        }
      }
    };

    if (userType === 'student') {
      // Remove from students collection (created by createStudentAccount).
      batch.delete(admin.firestore().collection('students').doc(canonicalUserId));
      for (const id of userIdsToPurge) batch.delete(credentialRef(admin.firestore(), id));

      const guardianIds = idsOf(
        userData.guardian_ids, userData.guardianIds,
        userData.guardian_id, userData.parent_id, userData.parentId,
        await idsWhere('children_ids'), await idsWhere('childrenIds'),
      );
      await unlinkFrom(guardianIds, ['children_ids', 'childrenIds'], []);
    }

    if (userType === 'parent') {
      const childIds = idsOf(
        userData.children_ids, userData.childrenIds,
        await idsWhere('guardian_ids'), await idsWhere('guardianIds'),
      );
      await unlinkFrom(childIds, ['guardian_ids', 'guardianIds'], ['guardian_id', 'parent_id', 'parentId']);
    }

	    let classesSummary = null;
	    if (deleteClasses && (userType === 'teacher' || userType === 'student')) {
	      classesSummary = await _cleanupTeachingShiftsForDeletedUser({
	        db: admin.firestore(),
	        userType,
	        userIdsToRemove: userIdsToPurge,
	        userData,
	      });
	      console.log('[DeleteUserAccount] teaching_shifts cleanup summary:', classesSummary);
	    }

	    // Timesheets are kept: they are pay records (owner decision D3).
	    const collections = [
	      {name: 'form_submissions', field: 'submittedBy'},
	      {name: 'form_drafts', field: 'createdBy'},
	    ];

    for (const collection of collections) {
      for (const idToDelete of userIdsToPurge) {
        try {
          const relatedQuery = await admin
            .firestore()
            .collection(collection.name)
            .where(collection.field, '==', idToDelete)
            .get();

          console.log(
            `Found ${relatedQuery.size} documents in ${collection.name} to delete (userId=${idToDelete})`
          );

          relatedQuery.docs.forEach((doc) => {
            batch.delete(doc.ref);
          });
        } catch (error) {
          console.log(`Error querying ${collection.name}:`, error.message);
        }
      }
    }

    try {
      const processedTaskIds = new Set();
      for (const idToRemove of userIdsToPurge) {
        const taskQuery = await admin
          .firestore()
          .collection('tasks')
          .where('assignedTo', 'array-contains', idToRemove)
          .get();

        console.log(`Found ${taskQuery.size} tasks assigned to userId=${idToRemove}`);

        taskQuery.docs.forEach((doc) => {
          if (processedTaskIds.has(doc.id)) return;
          processedTaskIds.add(doc.id);

          const taskData = doc.data();
          const assignedTo = (taskData.assignedTo || []).filter(
            (id) => !userIdsToPurge.includes(id)
          );

          if (assignedTo.length === 0) {
            batch.delete(doc.ref);
          } else {
            batch.update(doc.ref, {assignedTo});
          }
        });
      }
    } catch (error) {
      console.log(`Error handling tasks:`, error.message);
    }

    let publicTeamCleanup = {refs: [], urls: []};
    try {
      publicTeamCleanup = await _collectPublicSiteTeamBatchDeletes(
        admin.firestore(),
        userIdsToPurge
      );
      for (const ref of publicTeamCleanup.refs) {
        batch.delete(ref);
      }
      console.log(
        `[DeleteUserAccount] Queued ${publicTeamCleanup.refs.length} public_site_cms_team doc(s) for deletion`
      );
    } catch (e) {
      console.log('[DeleteUserAccount] public_site_cms_team batch cleanup failed:', e.message);
    }

    await batch.commit();

    for (const url of publicTeamCleanup.urls) {
      await _deleteFileByFirebaseDownloadURL(url);
    }

    return {
      success: true,
      message: 'The user has been permanently deleted',
      userId,
      deletedFromAuth,
      deletedFromFirestore: true,
      upcomingClassesDeleted: classesSummary ? classesSummary.shiftsDeleted : 0,
      upcomingClassesUpdated: classesSummary ? classesSummary.shiftsUpdated : 0,
      classesKept: classesSummary ? classesSummary.shiftsKept : 0,
    };
  } catch (error) {
    console.error('Error in deleteUserAccount:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', `Failed to delete user: ${error.message}`);
  }
};

// Generate a unique kiosque code for parent/family identification
const generateKiosqueCode = async () => {
  const db = admin.firestore();
  let code;
  let isUnique = false;
  let attempts = 0;

  // Generate codes until we find a unique one
  while (!isUnique && attempts < 10) {
    // Generate a 6-character alphanumeric code (uppercase letters and numbers)
    code = '';
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    // Check if code already exists
    const existingCode = await db.collection('users')
      .where('kiosque_code', '==', code)
      .limit(1)
      .get();

    if (existingCode.empty) {
      isUnique = true;
    }
    attempts++;
  }

  if (!isUnique) {
    throw new Error('Unable to generate unique kiosque code after multiple attempts');
  }

  console.log(`Generated unique kiosque code: ${code}`);
  return code;
};

const findUserByEmailOrCode = async (data, context) => {
  try {
    // Debug: Log what we're receiving
    console.log(`🔍 findUserByEmailOrCode called`);
    console.log(`🔍 data type: ${typeof data}`);
    console.log(`🔍 data keys: ${data ? Object.keys(data).join(', ') : 'null'}`);
    
    // Handle both direct and nested data access (some callable functions wrap data)
    const requestData = data?.data || data || {};
    console.log(`🔍 requestData keys: ${Object.keys(requestData).join(', ')}`);
    console.log(`🔍 requestData.identifier: ${requestData.identifier}`);
    
    // Get identifier from requestData
    const identifier = requestData.identifier || '';
    const rawIdentifier = String(identifier).trim();
    const identifierLower = rawIdentifier.toLowerCase();
    
    console.log(`🔍 Processed identifier: '${rawIdentifier}' (length: ${rawIdentifier.length})`);

    if (!rawIdentifier || rawIdentifier.length === 0) {
      console.error('❌ Empty identifier received after processing');
      console.error(`❌ Original data:`, JSON.stringify(data, null, 2));
      throw new functions.https.HttpsError('invalid-argument', 'Identifier is required');
    }

    console.log(`Looking up user by identifier: ${rawIdentifier}`);
    const db = admin.firestore();
    const usersRef = db.collection('users');

    // Families share an email: a parent enrolling a child often puts their own
    // address on the child's account too, so one identifier can match several
    // user docs. Firestore returns equality matches in document-ID order, so
    // taking the first one linked whoever happened to sort first — usually the
    // child, which then failed the parent check below. Search every match.
    const codeValues = rawIdentifier === identifierLower
      ? [rawIdentifier]
      : [rawIdentifier, identifierLower];
    const lookups = [
      ['e-mail', [identifierLower]],
      ['kiosk_code', codeValues],
      ['student_code', codeValues],
      ['kiosque_code', codeValues],
      ['family_code', [rawIdentifier]],
    ];

    let doc = null;
    let matchedAnyUser = false;

    for (const [field, values] of lookups) {
      for (const value of values) {
        const snapshot = await usersRef.where(field, '==', value).limit(10).get();
        if (snapshot.empty) continue;
        matchedAnyUser = true;

        doc = snapshot.docs.find((candidate) => {
          const candidateData = candidate.data();
          const childrenIds = candidateData.children_ids;
          return (candidateData.user_type || '') === 'parent' &&
            Array.isArray(childrenIds) &&
            childrenIds.length > 0;
        }) || null;

        if (doc) break;

        console.log(
          `↷ ${snapshot.size} match(es) on ${field}, none a parent with children`
        );
      }
      if (doc) break;
    }

    if (!doc) {
      console.log(
        matchedAnyUser
          ? `❌ Matched a user for '${rawIdentifier}' but no linkable parent account`
          : `❌ No user found for identifier: ${rawIdentifier}`
      );
      return { found: false };
    }

    const userData = doc.data();
    console.log(
      `✅ Linking parent ${userData.first_name || ''} ${userData.last_name || ''} ` +
      `with ${userData.children_ids.length} children`
    );

    return {
      found: true,
      userId: doc.id,
      firstName: userData.first_name || '',
      lastName: userData.last_name || '',
      email: userData['e-mail'] || '',
      phone: userData.phone_number || '',
      kiosqueCode: userData.kiosk_code || userData.kiosque_code || userData.family_code,
    };
  } catch (error) {
    // Safely extract error message to avoid circular reference issues
    const errorMessage = error?.message || error?.toString() || 'Unknown error';
    console.error('Error in findUserByEmailOrCode:', errorMessage);
    throw new functions.https.HttpsError('internal', errorMessage);
  }
};

module.exports = {
  createUserWithEmail,
  createMultipleUsers,
  MAX_BATCH_USERS,
  createUser,
  deleteUserAccount,
  findUserByEmailOrCode,
  adminSearchDirectoryUsers,
  onUserDeletedCleanupPublicTeam,
};
