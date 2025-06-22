const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.createUser = functions.https.onCall(async (data, context) => {
  print("received data:", data);
  try {
    // Debug log the incoming data
    console.log('Received data:', {
      email: data.email,
      firstName: data.firstName,
      lastName: data.lastName,
      hasPassword: !!data.password
    });

    // Basic validation
    if (!data || typeof data !== 'object') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Data must be an object'
      );
    }

    // Extract and validate fields with detailed logging
    const email = String(data.email || '').trim();
    const password = String(data.password || '');
    const firstName = String(data.firstName || '').trim();
    const lastName = String(data.lastName || '').trim();

    // Log validation results
    const validationResults = {
      hasEmail: !!email,
      hasPassword: !!password,
      hasFirstName: !!firstName,
      hasLastName: !!lastName,
      email,
      firstName,
      lastName
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
        emailVerified: false
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
      country_code: String(data.countryCode || "+1"),
      date_added: String(data.dateAdded || new Date().toISOString()),
      email,
      employment_start_date: String(data.employmentStartDate || new Date().toISOString()),
      first_name: firstName,
      kiosk_code: String(data.kioskCode || "123"),
      last_login: String(data.lastLogin || new Date().toISOString()),
      last_name: lastName,
      phone_number: String(data.phoneNumber || ""),
      title: String(data.title || "Teacher"),
      user_type: String(data.userType || "teacher"),
      uid: userRecord.uid
    };

    try {
      await admin.firestore().collection("users").doc(userRecord.uid).set(firestoreData);
    } catch (firestoreError) {
      // Clean up auth user if Firestore fails
      try {
        await admin.auth().deleteUser(userRecord.uid);
      } catch (cleanupError) {
        // Just log cleanup errors, don't throw
        console.error('Cleanup failed for uid:', userRecord.uid);
      }
      
      throw new functions.https.HttpsError(
        'internal',
        'Failed to create user profile'
      );
    }

    return {
      uid: userRecord.uid,
      email,
      message: "User created successfully"
    };

  } catch (error) {
    // Only log safe properties
    console.error('Error in createUser:', {
      code: error.code,
      message: error.message,
      details: error.details
    });
    
    // If it's already an HttpsError, rethrow it
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    // Wrap unknown errors
    throw new functions.https.HttpsError(
      'internal',
      'An unexpected error occurred'
    );
  }
});


// const functions = require("firebase-functions");
// const admin = require("firebase-admin");

// admin.initializeApp();

// exports.createUser = functions.https.onCall(async (data, context) => {
//   console.log('Raw received data:', JSON.stringify(data, null, 2));

//   try {
//     // Set default values
//     const userData = {
//       email: 'test@example.com',
//       password: '123456',
//       firstName: 'Test',
//       lastName: 'User',
//       phoneNumber: '+11234567890',
//       countryCode: '1',
//       userType: 'teacher',
//       title: 'Teacher'
//     };

//     console.log('Using user data:', JSON.stringify(userData, null, 2));

//     // Create auth user
//     let userRecord;
//     try {
//       userRecord = await admin.auth().createUser({
//         email: userData.email,
//         password: userData.password,
//         displayName: `${userData.firstName} ${userData.lastName}`,
//         emailVerified: false
//       });
//       console.log('Auth user created:', userRecord.uid);
//     } catch (authError) {
//       console.error('Auth creation error:', authError);
//       throw new functions.https.HttpsError('internal', authError.message || 'Auth creation failed');
//     }

//     // Create Firestore profile
//     const firestoreData = {
//       country_code: userData.countryCode,
//       date_added: new Date().toISOString(),
//       email: userData.email,
//       employment_start_date: new Date().toISOString(),
//       first_name: userData.firstName,
//       kiosk_code: "123",
//       last_login: new Date().toISOString(),
//       last_name: userData.lastName,
//       phone_number: userData.phoneNumber,
//       title: userData.title,
//       user_type: userData.userType,
//       uid: userRecord.uid
//     };

//     try {
//       await admin.firestore()
//         .collection("users")
//         .doc(userRecord.uid)
//         .set(firestoreData);
//       console.log('Firestore profile created');
//     } catch (firestoreError) {
//       console.error('Firestore error:', firestoreError);
//       // Clean up auth user if Firestore fails
//       try {
//         await admin.auth().deleteUser(userRecord.uid);
//         console.log('Cleaned up auth user after Firestore error');
//       } catch (cleanupError) {
//         console.error('Cleanup failed:', cleanupError);
//       }
//       throw new functions.https.HttpsError('internal', 'Failed to create user profile');
//     }

//     return {
//       uid: userRecord.uid,
//       email: userData.email,
//       message: "User created successfully"
//     };

//   } catch (error) {
//     console.error('Function error:', error);
//     throw new functions.https.HttpsError(
//       'internal',
//       error.message || 'An unexpected error occurred'
//     );
//   }
// });