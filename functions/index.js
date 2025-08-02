const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configure email transporter (you'll need to set these in Firebase Functions config)
const createTransporter = () => {
  return nodemailer.createTransporter({
    service: 'gmail', // or your email service
    auth: {
      user: functions.config().email?.user || 'your-email@gmail.com',
      pass: functions.config().email?.password || 'your-app-password'
    }
  });
};

// Generate random password
const generateRandomPassword = (length = 12) => {
  const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
  let password = "";
  
  // Ensure at least one of each type
  password += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[Math.floor(Math.random() * 26)]; // uppercase
  password += "abcdefghijklmnopqrstuvwxyz"[Math.floor(Math.random() * 26)]; // lowercase
  password += "0123456789"[Math.floor(Math.random() * 10)]; // number
  password += "!@#$%^&*"[Math.floor(Math.random() * 8)]; // special char
  
  // Fill the rest randomly
  for (let i = 4; i < length; i++) {
    password += charset[Math.floor(Math.random() * charset.length)];
  }
  
  // Shuffle the password
  return password.split('').sort(() => Math.random() - 0.5).join('');
};

// Send welcome email with credentials
const sendWelcomeEmail = async (email, firstName, lastName, password, userType) => {
  try {
    const transporter = createTransporter();
    
    const mailOptions = {
      from: functions.config().email?.user || 'noreply@alluwalacademy.com',
      to: email,
      subject: 'Welcome to Alluwal Academy - Your Account Details',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #0386FF; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
            .credentials { background-color: white; padding: 15px; border-left: 4px solid #0386FF; margin: 20px 0; }
            .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            .password { font-family: monospace; font-size: 16px; color: #e53e3e; font-weight: bold; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Welcome to Alluwal Academy</h1>
            </div>
            <div class="content">
              <h2>Hello ${firstName} ${lastName},</h2>
              <p>Your account has been created successfully! You can now access the Alluwal Academy system with the credentials below.</p>
              
              <div class="credentials">
                <h3>Your Login Credentials:</h3>
                <p><strong>Email:</strong> ${email}</p>
                <p><strong>Temporary Password:</strong> <span class="password">${password}</span></p>
                <p><strong>Role:</strong> ${userType}</p>
              </div>
              
              <p><strong>Important Security Notes:</strong></p>
              <ul>
                <li>Please change your password after your first login</li>
                <li>Keep your credentials secure and do not share them</li>
                <li>Contact the administrator if you have any issues accessing your account</li>
              </ul>
              
              <p>If you have any questions or need assistance, please contact the system administrator.</p>
              
              <p>Best regards,<br>Alluwal Academy Team</p>
            </div>
            <div class="footer">
              <p>This is an automated message. Please do not reply to this email.</p>
            </div>
          </div>
        </body>
        </html>
      `
    };

    await transporter.sendMail(mailOptions);
    console.log(`Welcome email sent to ${email}`);
    return true;
  } catch (error) {
    console.error('Error sending welcome email:', error);
    return false;
  }
};

exports.createUserWithEmail = functions.https.onCall(async (data, context) => {
  console.log("--- NEW INVOCATION (v4) ---");
  try {
    // Validate input data
    if (!data || typeof data !== 'object') {
      console.error('Invalid data received:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Data must be an object');
    }

    // Extract the actual data
    const userData = data.data || data;
    console.log("Using userData:", JSON.stringify(userData, null, 2));
    
    const {
      email,
      firstName,
      lastName,
      phoneNumber,
      countryCode,
      userType,
      title,
      kioskCode
    } = userData;

    // Log extracted fields for debugging
    console.log('Extracted fields (v2):', {
      email: email || 'MISSING',
      firstName: firstName || 'MISSING', 
      lastName: lastName || 'MISSING',
      phoneNumber: phoneNumber || 'MISSING',
      countryCode: countryCode || 'MISSING',
      userType: userType || 'MISSING',
      title: title || 'MISSING',
      kioskCode: kioskCode || 'MISSING'
    });

    // Validate required fields with detailed error message
    const missingFields = [];
    if (!email || String(email).trim() === '') missingFields.push('email');
    if (!firstName || String(firstName).trim() === '') missingFields.push('firstName');
    if (!lastName || String(lastName).trim() === '') missingFields.push('lastName');

    if (missingFields.length > 0) {
      console.error('Missing required fields:', missingFields);
      console.error('Actual values:', { email, firstName, lastName });
      throw new functions.https.HttpsError('invalid-argument', `Missing required fields: ${missingFields.join(', ')}`);
    }

    console.log('All required fields validated successfully');

    // Generate random password
    const password = generateRandomPassword();
    console.log(`Generated password for ${email}`);

    // Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email: email.toLowerCase().trim(),
      password: password,
      displayName: `${firstName} ${lastName}`,
      emailVerified: false
    });
    console.log(`Auth user created with UID: ${userRecord.uid}`);

    // Prepare Firestore data
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
      last_login: null, // Set to null for new users who haven't logged in yet
      employment_start_date: admin.firestore.FieldValue.serverTimestamp(),
      is_active: true,
      email_verified: false,
      uid: userRecord.uid,
      created_by_admin: true,
      password_reset_required: true
    };

    // Create Firestore document
    await admin.firestore()
      .collection("users")
      .doc(userRecord.uid)
      .set(firestoreData);
    console.log(`Firestore document created for UID: ${userRecord.uid}`);

    // Send welcome email
    const emailSent = await sendWelcomeEmail(email, firstName, lastName, password, userType);

    return {
      success: true,
      uid: userRecord.uid,
      emailSent: emailSent,
      message: "User created, email status: " + emailSent
    };

  } catch (error) {
    console.error("--- FULL FUNCTION ERROR (v4) ---");
    console.error("ERROR MESSAGE:", error.message);
    console.error("ERROR STACK:", error.stack);
    // Re-throw a clean error to the client
    throw new functions.https.HttpsError('internal', error.message, error.stack);
  }
});

// Batch create users
exports.createMultipleUsers = functions.https.onCall(async (data, context) => {
  console.log("Creating multiple users:", JSON.stringify(data, null, 2));
  
  try {
    if (!data || !Array.isArray(data.users)) {
      console.error('Invalid batch data:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Users array is required');
    }

    console.log(`Processing ${data.users.length} users for batch creation`);
    const results = [];
    const errors = [];

    for (let i = 0; i < data.users.length; i++) {
      const userData = data.users[i];
      console.log(`Processing user ${i + 1}:`, JSON.stringify(userData, null, 2));
      
      try {
        // Create user directly using the same logic
        const {
          email,
          firstName,
          lastName,
          phoneNumber,
          countryCode,
          userType,
          title,
          kioskCode
        } = userData;

        // Validate required fields
        const missingFields = [];
        if (!email || email.trim() === '') missingFields.push('email');
        if (!firstName || firstName.trim() === '') missingFields.push('firstName');
        if (!lastName || lastName.trim() === '') missingFields.push('lastName');

        if (missingFields.length > 0) {
          throw new Error(`Missing required fields: ${missingFields.join(', ')}`);
        }

        // Generate random password
        const password = generateRandomPassword();

        // Create Firebase Auth user
        const userRecord = await admin.auth().createUser({
          email: email.toLowerCase().trim(),
          password: password,
          displayName: `${firstName} ${lastName}`,
          emailVerified: false
        });

        // Prepare Firestore data
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
          last_login: null, // Set to null for new users who haven't logged in yet
          employment_start_date: admin.firestore.FieldValue.serverTimestamp(),
          is_active: true,
          email_verified: false,
          uid: userRecord.uid,
          created_by_admin: true,
          password_reset_required: true
        };

        // Create Firestore document
        await admin.firestore()
          .collection("users")
          .doc(userRecord.uid)
          .set(firestoreData);

        // Send welcome email
        const emailSent = await sendWelcomeEmail(email, firstName, lastName, password, userType);

        const result = {
          success: true,
          uid: userRecord.uid,
          email: email.toLowerCase().trim(),
          emailSent: emailSent,
          message: emailSent 
            ? "User created successfully and welcome email sent"
            : "User created successfully but email sending failed"
        };

        results.push({
          email: userData.email,
          success: true,
          result: result
        });
        console.log(`User ${i + 1} created successfully`);
      } catch (error) {
        console.error(`User ${i + 1} creation failed:`, error.message);
        errors.push({
          email: userData.email || 'unknown',
          success: false,
          error: error.message
        });
      }
    }

    return {
      totalUsers: data.users.length,
      successful: results.length,
      failed: errors.length,
      results: results,
      errors: errors
    };

  } catch (error) {
    console.error('Error in createMultipleUsers:', error);
    throw new functions.https.HttpsError('internal', 'Batch user creation failed');
  }
});

// Keep the original createUser function for backward compatibility
exports.createUser = functions.https.onCall(async (data, context) => {
  console.log("received data:", data);
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
      'e-mail': email,
      employment_start_date: String(data.employmentStartDate || new Date().toISOString()),
      first_name: firstName,
      kiosk_code: String(data.kioskCode || "123"),
      last_login: null, // Set to null for new users who haven't logged in yet
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

// ===== Landing Page Content API =====
/**
 * HTTP Function: getLandingPageContent
 * Path: https://<REGION>-<PROJECT_ID>.cloudfunctions.net/getLandingPageContent
 * Method: GET
 *
 * Returns the landing page content stored at collection "landing_page_content" doc "main".
 * Adds Cache-Control header so browsers / CDNs cache for 5 minutes.
 * Adds Access-Control-Allow-Origin header ("*") so any site can fetch.
 */
exports.getLandingPageContent = functions.https.onRequest(async (req, res) => {
  // Allow only GET
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    const snapshot = await admin.firestore()
      .collection('landing_page_content')
      .doc('main')
      .get();

    if (!snapshot.exists) {
      return res.status(404).json({ error: 'Landing page content not found' });
    }

    const data = snapshot.data();

    // Cache for 5 minutes (public) to minimise function invocations
    res.set('Cache-Control', 'public, max-age=300, s-maxage=300');
    // CORS - allow any origin (adjust if you have specific domains)
    res.set('Access-Control-Allow-Origin', '*');

    return res.status(200).json(data);
  } catch (err) {
    console.error('getLandingPageContent error:', err);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});