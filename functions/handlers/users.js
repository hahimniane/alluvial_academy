const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {generateRandomPassword} = require('../utils/password');
const {sendWelcomeEmail} = require('../services/email/senders');

const createUserWithEmail = async (data) => {
  console.log('--- NEW INVOCATION (v4) ---');
  try {
    if (!data || typeof data !== 'object') {
      console.error('Invalid data received:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Data must be an object');
    }

    const userData = data.data || data;
    console.log('Using userData:', JSON.stringify(userData, null, 2));

    const {
      email,
      firstName,
      lastName,
      phoneNumber,
      countryCode,
      userType,
      title,
      kioskCode,
    } = userData;

    console.log('Extracted fields (v2):', {
      email: email || 'MISSING',
      firstName: firstName || 'MISSING',
      lastName: lastName || 'MISSING',
      phoneNumber: phoneNumber || 'MISSING',
      countryCode: countryCode || 'MISSING',
      userType: userType || 'MISSING',
      title: title || 'MISSING',
      kioskCode: kioskCode || 'MISSING',
    });

    const missingFields = [];
    if (!email || String(email).trim() === '') missingFields.push('email');
    if (!firstName || String(firstName).trim() === '') missingFields.push('firstName');
    if (!lastName || String(lastName).trim() === '') missingFields.push('lastName');

    if (missingFields.length > 0) {
      console.error('Missing required fields:', missingFields);
      console.error('Actual values:', {email, firstName, lastName});
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Missing required fields: ${missingFields.join(', ')}`
      );
    }

    console.log('All required fields validated successfully');

    const password = generateRandomPassword();
    console.log(`Generated password for ${email}`);

    const userRecord = await admin.auth().createUser({
      email: email.toLowerCase().trim(),
      password,
      displayName: `${firstName} ${lastName}`,
      emailVerified: false,
    });
    console.log(`Auth user created with UID: ${userRecord.uid}`);

    // Generate kiosque code for parent accounts
    let kiosqueCode = null;
    if (userType?.toLowerCase() === 'parent') {
      kiosqueCode = await generateKiosqueCode();
      console.log(`Generated kiosque code for parent: ${kiosqueCode}`);
    }

    const firestoreData = {
      first_name: firstName.trim(),
      last_name: lastName.trim(),
      'e-mail': email.toLowerCase().trim(),
      phone_number: phoneNumber || '',
      country_code: countryCode || '+1',
      user_type: userType?.toLowerCase() || 'teacher',
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
      password_reset_required: true,
    };

    await admin.firestore().collection('users').doc(userRecord.uid).set(firestoreData);
    console.log(`Firestore document created for UID: ${userRecord.uid}`);

    const emailSent = await sendWelcomeEmail(email, firstName, lastName, password, userType, kiosqueCode);

    return {
      success: true,
      uid: userRecord.uid,
      emailSent,
      message: `User created, email status: ${emailSent}`,
    };
  } catch (error) {
    console.error('--- FULL FUNCTION ERROR (v4) ---');
    console.error('ERROR MESSAGE:', error.message);
    console.error('ERROR STACK:', error.stack);
    throw new functions.https.HttpsError('internal', error.message, error.stack);
  }
};

const createMultipleUsers = async (data) => {
  console.log('Creating multiple users:', JSON.stringify(data, null, 2));

  try {
    if (!data || !Array.isArray(data.users)) {
      console.error('Invalid batch data:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Users array is required');
    }

    console.log(`Processing ${data.users.length} users for batch creation`);
    const results = [];
    const errors = [];

    for (let i = 0; i < data.users.length; i += 1) {
      const userData = data.users[i];
      console.log(`Processing user ${i + 1}:`, JSON.stringify(userData, null, 2));

      try {
        const {
          email,
          firstName,
          lastName,
          phoneNumber,
          countryCode,
          userType,
          title,
          kioskCode,
        } = userData;

        const missingFields = [];
        if (!email || email.trim() === '') missingFields.push('email');
        if (!firstName || firstName.trim() === '') missingFields.push('firstName');
        if (!lastName || lastName.trim() === '') missingFields.push('lastName');

        if (missingFields.length > 0) {
          throw new Error(`Missing required fields: ${missingFields.join(', ')}`);
        }

        const password = generateRandomPassword();

        const userRecord = await admin.auth().createUser({
          email: email.toLowerCase().trim(),
          password,
          displayName: `${firstName} ${lastName}`,
          emailVerified: false,
        });

        const firestoreData = {
          first_name: firstName.trim(),
          last_name: lastName.trim(),
          'e-mail': email.toLowerCase().trim(),
          phone_number: phoneNumber || '',
          country_code: countryCode || '+1',
          user_type: userType?.toLowerCase() || 'teacher',
          title: title || 'Teacher',
          kiosk_code: kioskCode || '123',
          date_added: admin.firestore.FieldValue.serverTimestamp(),
          last_login: null,
          employment_start_date: admin.firestore.FieldValue.serverTimestamp(),
          is_active: true,
          email_verified: false,
          uid: userRecord.uid,
          created_by_admin: true,
          password_reset_required: true,
        };

        await admin.firestore().collection('users').doc(userRecord.uid).set(firestoreData);

        const emailSent = await sendWelcomeEmail(email, firstName, lastName, password, userType);

        const result = {
          success: true,
          uid: userRecord.uid,
          email: email.toLowerCase().trim(),
          emailSent,
          message: emailSent
            ? 'User created successfully and welcome email sent'
            : 'User created successfully but email sending failed',
        };

        results.push({
          email: userData.email,
          success: true,
          result,
        });
        console.log(`User ${i + 1} created successfully`);
      } catch (error) {
        console.error(`User ${i + 1} creation failed:`, error.message);
        errors.push({
          email: userData.email || 'unknown',
          success: false,
          error: error.message,
        });
      }
    }

    return {
      totalUsers: data.users.length,
      successful: results.length,
      failed: errors.length,
      results,
      errors,
    };
  } catch (error) {
    console.error('Error in createMultipleUsers:', error);
    throw new functions.https.HttpsError('internal', 'Batch user creation failed');
  }
};

const createUser = async (data) => {
  console.log('received data:', data);
  try {
    console.log('Received data:', {
      email: data.email,
      firstName: data.firstName,
      lastName: data.lastName,
      hasPassword: !!data.password,
    });

    if (!data || typeof data !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'Data must be an object');
    }

    const email = String(data.email || '').trim();
    const password = String(data.password || '');
    const firstName = String(data.firstName || '').trim();
    const lastName = String(data.lastName || '').trim();

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
      country_code: String(data.countryCode || '+1'),
      date_added: String(data.dateAdded || new Date().toISOString()),
      'e-mail': email,
      employment_start_date: String(data.employmentStartDate || new Date().toISOString()),
      first_name: firstName,
      kiosk_code: String(data.kioskCode || '123'),
      last_login: null,
      last_name: lastName,
      phone_number: String(data.phoneNumber || ''),
      title: String(data.title || 'Teacher'),
      user_type: String(data.userType || 'teacher'),
      uid: userRecord.uid,
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

const _deleteShiftRelatedDocuments = async ({
  db,
  shiftId,
  queueDelete,
  summary,
}) => {
  // Delete timesheet entries linked to this shift
  for (const field of ['shift_id', 'shiftId']) {
    try {
      const snap = await db.collection('timesheet_entries').where(field, '==', shiftId).get();
      for (const doc of snap.docs) {
        await queueDelete(doc.ref);
        summary.timesheetEntriesDeleted += 1;
      }
    } catch (e) {
      console.log(`[DeleteUserAccount] Error querying timesheet_entries by ${field}:`, e.message);
    }
  }

  // Delete form responses linked to this shift
  for (const field of ['shift_id', 'shiftId']) {
    try {
      const snap = await db.collection('form_responses').where(field, '==', shiftId).get();
      for (const doc of snap.docs) {
        await queueDelete(doc.ref);
        summary.formResponsesDeleted += 1;
      }
    } catch (e) {
      console.log(`[DeleteUserAccount] Error querying form_responses by ${field}:`, e.message);
    }
  }
};

const _cleanupTeachingShiftsForDeletedUser = async ({
  db,
  userType,
  userIdsToRemove,
  userData,
}) => {
  const shiftsRef = db.collection('teaching_shifts');
  const idsToRemove = userIdsToRemove.map(String);
  const userFullName = `${userData?.first_name || ''} ${userData?.last_name || ''}`.trim();

  const summary = {
    shiftsDeleted: 0,
    shiftsUpdated: 0,
    timesheetEntriesDeleted: 0,
    formResponsesDeleted: 0,
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

      await queueDelete(doc.ref);
      summary.shiftsDeleted += 1;

      await _deleteShiftRelatedDocuments({
        db,
        shiftId: doc.id,
        queueDelete,
        summary,
      });
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

      const remainingIds = ids.filter((id) => !idsToRemove.includes(id));

      if (remainingIds.length === 0) {
        await queueDelete(doc.ref);
        summary.shiftsDeleted += 1;

        await _deleteShiftRelatedDocuments({
          db,
          shiftId: doc.id,
          queueDelete,
          summary,
        });
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

const deleteUserAccount = async (data, context) => {
  console.log('Raw data received - type:', typeof data);
  const requestData = (data && data.data) || data || {};
  console.log('Using requestData:', requestData);

  const {email, adminEmail} = requestData;
  const deleteClasses =
    requestData.deleteClasses === true ||
    requestData.delete_classes === true ||
    requestData.deleteAssociatedClasses === true;

  console.log('Extracted email:', email);
  console.log('Extracted adminEmail:', adminEmail);

  if (!email) {
    console.log('No email provided in request');
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }

  if (!context || !context.auth) {
    console.log('Unauthenticated request to deleteUserAccount');
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const callerUid = context.auth.uid;
  const token = context.auth.token || {};
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

  // For backward compatibility, accept adminEmail from the client, but never trust it over the auth token.
  const effectiveAdminEmail = tokenEmail || (adminEmail ? String(adminEmail).toLowerCase() : null);

  console.log(`Starting delete process for user: ${email} by caller uid: ${callerUid}`);

  try {
    const usersRef = admin.firestore().collection('users');
    let callerData = null;

    // Prefer UID-based lookup (most reliable).
    try {
      const callerByUid = await usersRef.doc(callerUid).get();
      if (callerByUid.exists) {
        callerData = callerByUid.data();
      }
    } catch (e) {
      console.log('Error looking up caller by UID:', e.message);
    }

    // Legacy: some deployments store docs keyed by email.
    if (!callerData && effectiveAdminEmail) {
      try {
        const callerByEmailId = await usersRef.doc(effectiveAdminEmail).get();
        if (callerByEmailId.exists) {
          callerData = callerByEmailId.data();
        }
      } catch (e) {
        console.log('Error looking up caller by email doc ID:', e.message);
      }
    }

    // Fallback: query by email field.
    if (!callerData && effectiveAdminEmail) {
      const callerQuery = await usersRef.where('e-mail', '==', effectiveAdminEmail).limit(1).get();
      if (!callerQuery.empty) {
        callerData = callerQuery.docs[0].data();
      }
    }

    // Fallback: query by uid field (some schemas use auto IDs but store uid in a field).
    if (!callerData) {
      try {
        const callerUidQuery = await usersRef.where('uid', '==', callerUid).limit(1).get();
        if (!callerUidQuery.empty) {
          callerData = callerUidQuery.docs[0].data();
        }
      } catch (e) {
        console.log('Error looking up caller by uid field:', e.message);
      }
    }

    // Fallback: some schemas use `email` field instead of `e-mail`.
    if (!callerData && effectiveAdminEmail) {
      try {
        const callerEmailFieldQuery = await usersRef
          .where('email', '==', effectiveAdminEmail)
          .limit(1)
          .get();
        if (!callerEmailFieldQuery.empty) {
          callerData = callerEmailFieldQuery.docs[0].data();
        }
      } catch (e) {
        console.log('Error looking up caller by email field:', e.message);
      }
    }

    if (!callerData) {
      console.log(`Caller not found in users collection. uid=${callerUid}, email=${effectiveAdminEmail}`);
      if (!tokenIsAdmin) {
        throw new functions.https.HttpsError('permission-denied', 'Caller not found in users collection');
      }
      console.log(
        'Caller user doc missing, but auth token indicates admin; proceeding with token-based authorization.'
      );
    }
    
    // Log caller data for debugging
    if (callerData) {
      console.log(`Caller data found:`, {
        uid: callerUid,
        email: effectiveAdminEmail,
        user_type: callerData.user_type,
        role: callerData.role,
        userType: callerData.userType,
        is_admin_teacher: callerData.is_admin_teacher,
        is_admin: callerData.is_admin,
        isAdmin: callerData.isAdmin,
        is_super_admin: callerData.is_super_admin,
        isSuperAdmin: callerData.isSuperAdmin,
      });
    } else {
      console.log(`Caller data not found; tokenIsAdmin=${tokenIsAdmin}`, {
        uid: callerUid,
        email: effectiveAdminEmail,
        tokenRole,
      });
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
    const isAdmin = tokenIsAdmin || isAdminFromFirestore;

    console.log(`Admin check result: isAdmin=${isAdmin}, callerUserType="${callerUserType}"`);

    if (!isAdmin) {
      console.log(
        `Caller ${effectiveAdminEmail || callerUid} is not an admin. user_type: ${callerData.user_type}, role: ${callerData.role}, userType: ${callerData.userType}, is_admin_teacher: ${callerData.is_admin_teacher}, is_admin: ${callerData.is_admin}, isAdmin: ${callerData.isAdmin}`
      );
      throw new functions.https.HttpsError('permission-denied', 'Only administrators can delete users');
    }

    console.log(`Admin ${effectiveAdminEmail || callerUid} (verified) attempting to delete user: ${email}`);

    const userQuery = await admin
      .firestore()
      .collection('users')
      .where('e-mail', '==', email.toLowerCase())
      .limit(1)
      .get();

    if (userQuery.empty) {
      throw new functions.https.HttpsError('not-found', 'User not found in database');
    }

    const userDoc = userQuery.docs[0];
    const userData = userDoc.data();
    const userId = userDoc.id;
    let canonicalUserId = userData && userData.uid ? String(userData.uid) : userId;

    const isActive = userData.is_active !== false;
    console.log(`User active status: ${userData.is_active} (isActive: ${isActive})`);

    if (isActive) {
      console.log(`User ${email} is still active, cannot delete`);
      throw new functions.https.HttpsError(
        'failed-precondition',
        'User must be deactivated (archived) before deletion'
      );
    }

    console.log(`Deleting user: ${email} (Firestore ID: ${userId}, canonical UID: ${canonicalUserId})`);

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
        const authUser = await admin.auth().getUserByEmail(email);
        console.log(`Found user in Firebase Auth by email: ${authUser.uid}`);
        canonicalUserId = authUser.uid || canonicalUserId;
        await admin.auth().deleteUser(authUser.uid);
        deletedFromAuth = true;
        console.log(`Successfully deleted user from Firebase Auth by email: ${email}`);
      } catch (authError) {
        console.log(`User not found in Firebase Auth or already deleted: ${email}`, authError.message);
      }
    }

    const userIdsToPurge = Array.from(new Set([userId, canonicalUserId].filter(Boolean)));

    const batch = admin.firestore().batch();
    batch.delete(userDoc.ref);
    // In case this project has duplicate user docs (legacy schemas), also delete the canonical UID doc.
    if (canonicalUserId && canonicalUserId !== userId) {
      batch.delete(admin.firestore().collection('users').doc(canonicalUserId));
    }

    // Best-effort cleanup for parent/student relationships and auxiliary collections.
    const userType = (userData.user_type || userData.userType || userData.role || '')
      .toString()
      .toLowerCase();

    if (userType === 'student') {
      // Remove from students collection (created by createStudentAccount).
      batch.delete(admin.firestore().collection('students').doc(canonicalUserId));

      const guardianIds = Array.isArray(userData.guardian_ids)
        ? userData.guardian_ids
        : Array.isArray(userData.guardianIds)
          ? userData.guardianIds
          : [];

      for (const guardianId of guardianIds) {
        try {
          const guardianRef = admin.firestore().collection('users').doc(String(guardianId));
          const guardianSnap = await guardianRef.get();
          if (!guardianSnap.exists) continue;

          const guardianData = guardianSnap.data() || {};
          const updates = {};
          if (guardianData.children_ids !== undefined) {
            updates.children_ids = admin.firestore.FieldValue.arrayRemove(canonicalUserId);
          }
          if (guardianData.childrenIds !== undefined) {
            updates.childrenIds = admin.firestore.FieldValue.arrayRemove(canonicalUserId);
          }
          if (Object.keys(updates).length === 0) {
            updates.children_ids = admin.firestore.FieldValue.arrayRemove(canonicalUserId);
          }
          updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
          batch.update(guardianRef, updates);
        } catch (e) {
          console.log(`Error removing student from guardian ${guardianId}:`, e.message);
        }
      }
    }

	    if (userType === 'parent') {
	      const childrenIds = Array.isArray(userData.children_ids)
	        ? userData.children_ids
	        : Array.isArray(userData.childrenIds)
	          ? userData.childrenIds
	          : [];

      for (const childId of childrenIds) {
        try {
          const childRef = admin.firestore().collection('users').doc(String(childId));
          const childSnap = await childRef.get();
          if (!childSnap.exists) continue;

          const childData = childSnap.data() || {};
          const updates = {};
          if (childData.guardian_ids !== undefined) {
            updates.guardian_ids = admin.firestore.FieldValue.arrayRemove(canonicalUserId);
          }
          if (childData.guardianIds !== undefined) {
            updates.guardianIds = admin.firestore.FieldValue.arrayRemove(canonicalUserId);
          }
          if (Object.keys(updates).length === 0) {
            updates.guardian_ids = admin.firestore.FieldValue.arrayRemove(canonicalUserId);
          }
          updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
          batch.update(childRef, updates);
        } catch (e) {
          console.log(`Error removing parent from student ${childId}:`, e.message);
	        }
	      }
	    }

	    if (deleteClasses && (userType === 'teacher' || userType === 'student')) {
	      console.log(
	        `[DeleteUserAccount] deleteClasses enabled for ${userType}; cleaning up teaching_shifts...`
	      );
	      const classesSummary = await _cleanupTeachingShiftsForDeletedUser({
	        db: admin.firestore(),
	        userType,
	        userIdsToRemove: userIdsToPurge,
	        userData,
	      });
	      console.log('[DeleteUserAccount] teaching_shifts cleanup summary:', classesSummary);
	    }

	    const collections = [
	      {name: 'timesheet_entries', field: 'userId'},
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

    await batch.commit();

    console.log(`Successfully deleted user and all associated data: ${email}`);

    return {
      success: true,
      message: `User ${email} and all associated data have been permanently deleted`,
      deletedFromAuth,
      deletedFromFirestore: true,
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

    // 1. Try finding by email (lowercase)
    let snapshot = await usersRef.where('e-mail', '==', identifierLower).limit(1).get();
    
    // 2. Try finding by kiosk_code (ACTUAL field name in database - exact match first)
    if (snapshot.empty) {
      snapshot = await usersRef.where('kiosk_code', '==', rawIdentifier).limit(1).get();
    }
    if (snapshot.empty && rawIdentifier !== identifierLower) {
      snapshot = await usersRef.where('kiosk_code', '==', identifierLower).limit(1).get();
    }

    // 3. Try finding by student_code (try exact match first, then lowercase)
    if (snapshot.empty) {
      snapshot = await usersRef.where('student_code', '==', rawIdentifier).limit(1).get();
    }
    if (snapshot.empty && rawIdentifier !== identifierLower) {
      snapshot = await usersRef.where('student_code', '==', identifierLower).limit(1).get();
    }

    // 4. Try finding by kiosque_code (alternate spelling - try exact match first, then lowercase)
    if (snapshot.empty) {
      snapshot = await usersRef.where('kiosque_code', '==', rawIdentifier).limit(1).get();
    }
    if (snapshot.empty && rawIdentifier !== identifierLower) {
      snapshot = await usersRef.where('kiosque_code', '==', identifierLower).limit(1).get();
    }

    // 5. Try finding by family_code (legacy field name)
    if (snapshot.empty) {
      snapshot = await usersRef.where('family_code', '==', rawIdentifier).limit(1).get();
    }

    if (snapshot.empty) {
      console.log(`❌ No user found for identifier: ${rawIdentifier}`);
      return { found: false };
    }

    const doc = snapshot.docs[0];
    const userData = doc.data();
    const userType = userData.user_type || '';
    const childrenIds = userData.children_ids || [];

    console.log(`✅ Found user: ${userData.first_name || ''} ${userData.last_name || ''} (${userType})`);

    // Only allow linking to parents who have enrolled children
    if (userType !== 'parent') {
      console.log(`❌ User is not a parent (${userType}), cannot link`);
      return { found: false };
    }

    if (!childrenIds || childrenIds.length === 0) {
      console.log(`❌ Parent has no children (${childrenIds.length}), cannot link`);
      return { found: false };
    }

    console.log(`✅ Valid parent with ${childrenIds.length} children - allowing link`);

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
  createUser,
  deleteUserAccount,
  findUserByEmailOrCode,
};
