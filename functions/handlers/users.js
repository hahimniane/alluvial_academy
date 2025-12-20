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
    console.log(`Firestore document created for UID: ${userRecord.uid}`);

    const emailSent = await sendWelcomeEmail(email, firstName, lastName, password, userType);

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

const deleteUserAccount = async (data) => {
  console.log('Raw data received - type:', typeof data);
  const requestData = data.data || data;
  console.log('Using requestData:', requestData);

  const {email, adminEmail} = requestData;

  console.log('Extracted email:', email);
  console.log('Extracted adminEmail:', adminEmail);

  if (!email) {
    console.log('No email provided in request');
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }

  if (!adminEmail) {
    console.log('No admin email provided in request');
    throw new functions.https.HttpsError('invalid-argument', 'Admin email is required');
  }

  console.log(`Starting delete process for user: ${email} by admin: ${adminEmail}`);

  try {
    const callerDoc = await admin
      .firestore()
      .collection('users')
      .where('e-mail', '==', adminEmail.toLowerCase())
      .limit(1)
      .get();

    if (callerDoc.empty) {
      console.log(`Admin not found in users collection: ${adminEmail}`);
      throw new functions.https.HttpsError('permission-denied', 'Admin not found in users collection');
    }

    const callerData = callerDoc.docs[0].data();
    const isAdmin = callerData.user_type === 'admin' || callerData.is_admin_teacher === true;

    if (!isAdmin) {
      console.log(
        `User ${adminEmail} is not an admin. user_type: ${callerData.user_type}, is_admin_teacher: ${callerData.is_admin_teacher}`
      );
      throw new functions.https.HttpsError('permission-denied', 'Only administrators can delete users');
    }

    console.log(`Admin ${adminEmail} (verified) attempting to delete user: ${email}`);

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

    const isActive = userData.is_active !== false;
    console.log(`User active status: ${userData.is_active} (isActive: ${isActive})`);

    if (isActive) {
      console.log(`User ${email} is still active, cannot delete`);
      throw new functions.https.HttpsError(
        'failed-precondition',
        'User must be deactivated (archived) before deletion'
      );
    }

    console.log(`Deleting user: ${email} (ID: ${userId})`);

    let authUser = null;
    try {
      authUser = await admin.auth().getUserByEmail(email);
      console.log(`Found user in Firebase Auth: ${authUser.uid}`);

      await admin.auth().deleteUser(authUser.uid);
      console.log(`Successfully deleted user from Firebase Auth: ${email}`);
    } catch (authError) {
      console.log(`User not found in Firebase Auth or already deleted: ${email}`, authError.message);
    }

    const batch = admin.firestore().batch();
    batch.delete(userDoc.ref);

    const collections = [
      {name: 'timesheet_entries', field: 'userId'},
      {name: 'form_submissions', field: 'submittedBy'},
      {name: 'form_drafts', field: 'createdBy'},
    ];

    for (const collection of collections) {
      try {
        const relatedQuery = await admin
          .firestore()
          .collection(collection.name)
          .where(collection.field, '==', userId)
          .get();

        console.log(`Found ${relatedQuery.size} documents in ${collection.name} to delete`);

        relatedQuery.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
      } catch (error) {
        console.log(`Error querying ${collection.name}:`, error.message);
      }
    }

    try {
      const taskQuery = await admin
        .firestore()
        .collection('tasks')
        .where('assignedTo', 'array-contains', userId)
        .get();

      console.log(`Found ${taskQuery.size} tasks assigned to user`);

      taskQuery.docs.forEach((doc) => {
        const taskData = doc.data();
        const assignedTo = (taskData.assignedTo || []).filter((id) => id !== userId);

        if (assignedTo.length === 0) {
          batch.delete(doc.ref);
        } else {
          batch.update(doc.ref, {assignedTo});
        }
      });
    } catch (error) {
      console.log(`Error handling tasks:`, error.message);
    }

    await batch.commit();

    console.log(`Successfully deleted user and all associated data: ${email}`);

    return {
      success: true,
      message: `User ${email} and all associated data have been permanently deleted`,
      deletedFromAuth: authUser !== null,
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

module.exports = {
  createUserWithEmail,
  createMultipleUsers,
  createUser,
  deleteUserAccount,
};

