const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configure email transporter
const createTransporter = () =>
  nodemailer.createTransport({
    host: 'smtp.hostinger.com',
    port: 465,
    secure: true, // SSL
    auth: {
      user: 'support@alluwaleducationhub.org',
      pass: 'Kilopatra2025.',
    },
  });

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

// Send custom password reset email
const sendPasswordResetEmail = async (email, resetLink, displayName = '') => {
  try {
    const transporter = createTransporter();
    
    const mailOptions = {
      from: 'support@alluwaleducationhub.org',
      to: email,
      subject: 'Reset Your Alluwal Academy Password',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Password Reset - Alluwal Academy</title>
        </head>
        <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 700;">Alluwal Academy</h1>
            <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">Password Reset Request</p>
          </div>
          
          <div style="background: #ffffff; padding: 40px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
            <h2 style="color: #2D3748; margin: 0 0 20px 0; font-size: 24px;">Hello${displayName ? ' ' + displayName : ''},</h2>
            
            <p style="margin: 0 0 20px 0; font-size: 16px; color: #4A5568;">
              You requested to reset your password for your Alluwal Academy account. Click the secure link below to create a new password:
            </p>
            
            <div style="text-align: center; margin: 30px 0;">
              <a href="${resetLink}" style="display: inline-block; background: #0386FF; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; box-shadow: 0 2px 4px rgba(3,134,255,0.3);">
                Reset Password
              </a>
            </div>
            
            <div style="background: #F7FAFC; padding: 20px; border-radius: 8px; margin: 30px 0;">
              <h3 style="color: #2D3748; margin: 0 0 10px 0; font-size: 18px;">Security Notice</h3>
              <ul style="margin: 0; padding-left: 20px; color: #4A5568;">
                <li>This link will expire in 1 hour for your security</li>
                <li>If you didn't request this reset, please ignore this email</li>
                <li>Your account will remain secure and unchanged</li>
              </ul>
            </div>
            
            <p style="margin: 20px 0; font-size: 14px; color: #718096;">
              If the button above doesn't work, copy and paste this link into your browser:
              <br><span style="word-break: break-all; color: #0386FF;">${resetLink}</span>
            </p>
            
            <div style="border-top: 1px solid #E2E8F0; padding-top: 20px; margin-top: 30px;">
              <p style="margin: 0; font-size: 14px; color: #718096;">
                Need help? Contact our support team at 
                <a href="mailto:support@alluwaleducationhub.org" style="color: #0386FF;">support@alluwaleducationhub.org</a>
              </p>
              <p style="margin: 10px 0 0 0; font-size: 14px; color: #718096;">
                Best regards,<br>
                <strong>The Alluwal Academy Team</strong>
              </p>
            </div>
          </div>
        </body>
        </html>
      `
    };
    
    await transporter.sendMail(mailOptions);
    console.log(`Custom password reset email sent successfully to ${email}`);
    
    return { success: true, message: `Password reset email sent to ${email}` };
    
  } catch (error) {
    console.error('Error sending password reset email:', error);
    throw new functions.https.HttpsError('internal', `Failed to send password reset email: ${error.message}`);
  }
};

// Send welcome email with credentials
const sendWelcomeEmail = async (email, firstName, lastName, password, userType) => {
  try {
    const transporter = createTransporter();
    
    const mailOptions = {
      from: 'support@alluwaleducationhub.org',
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

// Send task assignment email notification
const sendTaskAssignmentEmail = async (
  assigneeEmail,
  assigneeName,
  taskTitle,
  taskDescription,
  dueDate,
  assignedByName
) => {
  try {
    const transporter = createTransporter();

    const formattedDueDate = dueDate
      ? new Date(dueDate).toLocaleDateString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        })
      : 'No due date';

    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: assigneeEmail,
      subject: `📋 New Task Assigned: ${taskTitle}`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>New Task Assigned</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            background-color: #f4f6f9;
            margin: 0;
            padding: 0;
            color: #333333;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
          }
          .header {
            background-color: #0386ff;
            color: #ffffff;
            padding: 24px;
            text-align: center;
          }
          .header h1 {
            margin: 0;
            font-size: 24px;
            letter-spacing: 0.5px;
          }
          .content {
            padding: 24px;
          }
          .task-card {
            background-color: #f9fbff;
            border-left: 4px solid #0386ff;
            padding: 16px;
            margin: 16px 0;
            border-radius: 4px;
          }
          .task-title {
            font-size: 18px;
            font-weight: bold;
            color: #0386ff;
            margin-bottom: 8px;
          }
          .task-detail {
            margin: 4px 0;
          }
          .btn {
            display: inline-block;
            background-color: #0386ff;
            color: #ffffff !important;
            padding: 12px 24px;
            border-radius: 4px;
            text-decoration: none;
            margin-top: 16px;
            font-weight: bold;
          }
          .footer {
            text-align: center;
            font-size: 12px;
            color: #888888;
            padding: 16px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Alluwal Education Hub</h1>
          </div>
          <div class="content">
            <p>Hi ${assigneeName},</p>
            <p>You have been assigned a new task by <strong>${assignedByName}</strong>.</p>

            <div class="task-card">
              <div class="task-title">${taskTitle}</div>
              <p class="task-detail"><strong>Description:</strong> ${
                taskDescription || 'No description provided.'
              }</p>
              <p class="task-detail"><strong>Due Date:</strong> ${formattedDueDate}</p>
            </div>

            <p>Please login to the Alluwal Education Hub portal to view more details and update your progress.</p>

            <a href="#" class="btn">Go to Tasks →</a>

            <p style="margin-top:24px;">Best regards,<br/>Alluwal Education Hub Team</p>
          </div>
          <div class="footer">
            This is an automated message. Please do not reply to this email.
          </div>
        </div>
      </body>
      </html>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`Task assignment email sent to ${assigneeEmail} for task: ${taskTitle}`);
    return true;
  } catch (error) {
    console.error('Error sending task assignment email:', error);
    return false;
  }
};

// Cloud Function to handle task assignment notifications
exports.sendTaskAssignmentNotification = functions.https.onCall(async (data, context) => {
  console.log("--- TASK ASSIGNMENT NOTIFICATION ---");
  console.log("Raw data received:", data);
  console.log("Data type:", typeof data);
  console.log("Data keys:", data ? Object.keys(data) : 'data is null/undefined');
  
  try {
    // The data is nested under data.data for callable functions
    const { taskId, taskTitle, taskDescription, dueDate, assignedUserIds, assignedByName } = data.data || {};
    
    console.log("Extracted fields:", {
      taskId,
      taskTitle, 
      taskDescription,
      dueDate,
      assignedUserIds,
      assignedByName
    });

    // Validate required fields
    if (!taskId || !taskTitle || !Array.isArray(assignedUserIds) || assignedUserIds.length === 0) {
      console.error('Invalid or missing fields:', { taskId, taskTitle, assignedUserIds });
      throw new functions.https.HttpsError('invalid-argument', 'Missing or invalid required fields: taskId, taskTitle, or assignedUserIds must be a non-empty array.');
    }

    console.log(`Processing task assignment notification for task: ${taskTitle}`);
    console.log(`Assigned to ${assignedUserIds.length} users`);

    const results = [];
    const errors = [];

    // Get user details from Firestore and send emails
    for (const userId of assignedUserIds) {
      try {
        // Get user document from Firestore
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();

        if (!userDoc.exists) {
          console.error(`User not found: ${userId}`);
          errors.push({
            userId,
            error: 'User not found'
          });
          continue;
        }

        const userData = userDoc.data();
        const userEmail = userData['e-mail'] || userData['email'];
        const userName = `${userData['first_name'] || ''} ${userData['last_name'] || ''}`.trim() || 'User';

        if (!userEmail) {
          console.error(`No email found for user: ${userId}`);
          errors.push({
            userId,
            error: 'No email address found'
          });
          continue;
        }

        // Send email notification
        const emailSent = await sendTaskAssignmentEmail(
          userEmail,
          userName,
          taskTitle,
          taskDescription,
          dueDate,
          assignedByName || 'System Administrator'
        );

        results.push({
          userId,
          email: userEmail,
          name: userName,
          emailSent
        });

        console.log(`Email notification processed for ${userName} (${userEmail}): ${emailSent ? 'SUCCESS' : 'FAILED'}`);

      } catch (error) {
        console.error(`Error processing notification for user ${userId}:`, error);
        errors.push({
          userId,
          error: error.message
        });
      }
    }

    return {
      success: true,
      taskId,
      taskTitle,
      totalAssignees: assignedUserIds.length,
      emailsSent: results.filter(r => r.emailSent).length,
      emailsFailed: results.filter(r => !r.emailSent).length,
      results,
      errors
    };

  } catch (error) {
    console.error("Error in sendTaskAssignmentNotification:", error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Welcome email function for new users
exports.sendWelcomeEmail = functions.https.onCall(async (data, context) => {
  console.log("--- WELCOME EMAIL FUNCTION ---");
  
  try {
    const { email, firstName, lastName, role } = data.data || {};
    
    if (!email || !firstName) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: email and firstName are required.');
    }
    
    const transporter = createTransporter();
    
    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: email,
      subject: `🎉 Welcome to Alluwal Education Hub, ${firstName}!`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Welcome to Alluwal Education Hub</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 600px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 30px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .welcome-box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .credentials-box { background-color: #fef3c7; border: 2px solid #f59e0b; padding: 20px; margin: 20px 0; border-radius: 8px; }
          .credentials-box h3 { margin-top: 0; color: #92400e; }
          .login-info { background-color: #ecfdf5; border: 1px solid #10b981; padding: 15px; margin: 15px 0; border-radius: 6px; }
          .cta-button { display: inline-block; background-color: #0386FF; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0; }
          .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          .important { color: #dc2626; font-weight: bold; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Welcome to Alluwal Education Hub!</h1>
            <p>Your account has been successfully created</p>
          </div>
          
          <div class="content">
            <div class="welcome-box">
              <h2>Hello ${firstName}${lastName ? ' ' + lastName : ''}! 👋</h2>
              <p>We're excited to have you join the Alluwal Education Hub team${role ? ' as a ' + role : ''}. Your account has been set up and you're ready to get started!</p>
            </div>
            
            <div class="credentials-box">
              <h3>🔐 Your Login Credentials</h3>
              <p><strong>Email:</strong> ${email}</p>
              <p><strong>Temporary Password:</strong> <span class="important">123456</span></p>
              <p class="important">⚠️ Please change your password immediately after your first login for security purposes.</p>
            </div>
            
            <div class="login-info">
              <h3>🚀 Getting Started</h3>
              <ol>
                <li><strong>Login:</strong> Visit the Alluwal Education Hub portal</li>
                <li><strong>Use your credentials:</strong> Email and password above</li>
                <li><strong>Change password:</strong> Go to your profile settings immediately</li>
                <li><strong>Explore:</strong> Familiarize yourself with the dashboard and features</li>
              </ol>
            </div>
            
            <div style="text-align: center;">
              <a href="https://alluwaleducationhub.org" class="cta-button">Access Your Account</a>
            </div>
            
            <div style="margin-top: 30px;">
              <h3>Need Help?</h3>
              <p>If you have any questions or need assistance:</p>
              <ul>
                <li>📧 Email us at: <a href="mailto:support@alluwaleducationhub.org">support@alluwaleducationhub.org</a></li>
                <li>📱 Contact your administrator</li>
                <li>💬 Use the chat feature in the portal</li>
              </ul>
            </div>
          </div>
          
          <div class="footer">
            <p>© ${new Date().getFullYear()} Alluwal Education Hub. All rights reserved.</p>
            <p>This email was sent to ${email}. Please do not reply to this automated message.</p>
          </div>
        </div>
      </body>
      </html>
      `
    };
    
    await transporter.sendMail(mailOptions);
    console.log(`Welcome email sent successfully to ${email}`);
    
    return { success: true, message: `Welcome email sent to ${email}` };
    
  } catch (error) {
    console.error('Error sending welcome email:', error);
    throw new functions.https.HttpsError('internal', `Failed to send welcome email: ${error.message}`);
  }
});

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
  // Set CORS headers for preflight requests
  res.set('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    res.set('Access-Control-Allow-Methods', 'GET');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Max-Age', '3600');
    res.status(204).send('');
    return;
  }
  
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

    return res.status(200).json(data);
  } catch (err) {
    console.error('getLandingPageContent error:', err);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Test email function
exports.sendTestEmail = functions.https.onCall(async (data, context) => {
  console.log("--- TEST EMAIL FUNCTION ---");
  
  try {
    const { to, subject, message } = data;
    const recipient = to || 'hassimiou.niane@maine.edu';
    const emailSubject = subject || 'Test Email from Alluwal Academy';
    const emailMessage = message || 'This is a test email from Alluwal Academy system.';
    
    const transporter = createTransporter();
    
    const mailOptions = {
      from: 'support@alluwaleducationhub.org',
      to: recipient,
      subject: emailSubject,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #0386FF; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🧪 Test Email from Alluwal Academy</h1>
            </div>
            <div class="content">
              <h2>Email Test Successful!</h2>
              <p>${emailMessage}</p>
              <hr>
              <p><strong>From:</strong> Alluwal Academy Debug System</p>
              <p><strong>Method:</strong> Firebase Cloud Function → Hostinger SMTP</p>
              <p><strong>Server:</strong> smtp.hostinger.com:465 (SSL)</p>
              <p><strong>Timestamp:</strong> ${new Date().toISOString()}</p>
            </div>
          </div>
        </body>
        </html>
      `
    };

    await transporter.sendMail(mailOptions);
    console.log(`Test email sent successfully to ${recipient}`);
    
    return {
      success: true,
      message: 'Test email sent successfully',
      recipient: recipient,
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    console.error('Error sending test email:', error);
    throw new functions.https.HttpsError('internal', `Failed to send test email: ${error.message}`);
  }
});

// Task status update notification function
exports.sendTaskStatusUpdateNotification = functions.https.onCall(async (data, context) => {
  console.log("--- TASK STATUS UPDATE NOTIFICATION ---");
  
  try {
    const { taskId, taskTitle, oldStatus, newStatus, updatedByName, createdBy } = data.data || {};
    
    if (!taskId || !taskTitle || !newStatus || !createdBy) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: taskId, taskTitle, newStatus, and createdBy are required.');
    }
    
    // Get the task creator's email from Firestore
    const admin = require('firebase-admin');
    const db = admin.firestore();
    
    let assignedByEmail;
    let assignedByName;
    
    // Handle test scenario
    if (createdBy === 'test-creator-id') {
      assignedByEmail = 'hassimiou.niane@maine.edu';
      assignedByName = 'Test Creator';
      console.log('Using test data for task status update notification');
    } else {
      // Real scenario - get creator from Firestore
      const creatorDoc = await db.collection('users').doc(createdBy).get();
      if (!creatorDoc.exists) {
        console.log(`Task creator ${createdBy} not found in database`);
        return { success: false, message: `Task creator ${createdBy} not found` };
      }
      
      const creatorData = creatorDoc.data();
      // Note: Email field is stored as 'e-mail' in Firestore user documents
      assignedByEmail = creatorData['e-mail'] || creatorData.email; // Try both field names for compatibility
      assignedByName = `${creatorData.first_name || ''} ${creatorData.last_name || ''}`.trim() || 'Task Creator';
      
      console.log('Creator data:', {
        createdBy,
        'e-mail': creatorData['e-mail'],
        email: creatorData.email,
        first_name: creatorData.first_name,
        last_name: creatorData.last_name
      });
      
      if (!assignedByEmail) {
        console.log('Task creator email not found. Available fields:', Object.keys(creatorData));
        return { success: false, message: 'Task creator email not found' };
      }
    }
    
    const transporter = createTransporter();
    
    const statusColors = {
      'pending': '#f59e0b',
      'in_progress': '#3b82f6', 
      'completed': '#10b981',
      'cancelled': '#ef4444',
      'todo': '#6b7280',
      'done': '#10b981'
    };
    
    const statusEmojis = {
      'pending': '⏳',
      'in_progress': '🔄',
      'completed': '✅',
      'cancelled': '❌',
      'todo': '📋',
      'done': '✅'
    };
    
    const statusColor = statusColors[newStatus] || '#6b7280';
    const statusEmoji = statusEmojis[newStatus] || '📋';
    
    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: assignedByEmail,
      subject: `${statusEmoji} Task Status Updated: ${taskTitle}`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Task Status Update</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 600px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 25px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 24px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .status-update { background-color: #f8fafc; border: 2px solid ${statusColor}; padding: 20px; margin: 20px 0; border-radius: 8px; text-align: center; }
          .status-badge { display: inline-block; background-color: ${statusColor}; color: white; padding: 8px 16px; border-radius: 20px; font-weight: bold; text-transform: uppercase; margin: 0 5px; }
          .task-info { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .cta-button { display: inline-block; background-color: #0386FF; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0; }
          .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          .arrow { font-size: 24px; color: #6b7280; margin: 0 10px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>${statusEmoji} Task Status Updated</h1>
            <p>One of your assigned tasks has been updated</p>
          </div>
          
          <div class="content">
            <div class="task-info">
              <h2>📋 Task Details</h2>
              <p><strong>Task:</strong> ${taskTitle}</p>
              <p><strong>Task ID:</strong> ${taskId}</p>
              <p><strong>Updated by:</strong> ${updatedByName || 'Unknown User'}</p>
              <p><strong>Updated:</strong> ${new Date().toLocaleString()}</p>
            </div>
            
            <div class="status-update">
              <h3>Status Change</h3>
              <div style="display: flex; align-items: center; justify-content: center; flex-wrap: wrap;">
                ${oldStatus ? `<span class="status-badge" style="background-color: #6b7280;">${oldStatus.replace('_', ' ')}</span>` : ''}
                <span class="arrow">→</span>
                <span class="status-badge">${newStatus.replace('_', ' ')}</span>
              </div>
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
              <p>You can view the complete task details and progress in your dashboard.</p>
              <a href="https://alluwaleducationhub.org/tasks" class="cta-button">View Task Details</a>
            </div>
            
            <div style="background-color: #ecfdf5; border: 1px solid #10b981; padding: 15px; margin: 20px 0; border-radius: 6px;">
              <h4 style="margin-top: 0;">💡 Quick Actions</h4>
              <ul>
                <li>Review task progress and details</li>
                <li>Add comments or feedback</li>
                <li>Update task priority if needed</li>
                <li>Check other pending tasks</li>
              </ul>
            </div>
          </div>
          
          <div class="footer">
            <p>© ${new Date().getFullYear()} Alluwal Education Hub. All rights reserved.</p>
            <p>This notification was sent to ${assignedByEmail}. You're receiving this because you assigned this task.</p>
          </div>
        </div>
      </body>
      </html>
      `
    };
    
    await transporter.sendMail(mailOptions);
    console.log(`Task status update email sent successfully to ${assignedByEmail}`);
    
    return { success: true, message: `Status update notification sent to ${assignedByEmail}` };
    
  } catch (error) {
    console.error('Error sending task status update email:', error);
    throw new functions.https.HttpsError('internal', `Failed to send status update email: ${error.message}`);
  }
});

// Custom password reset email function
exports.sendCustomPasswordResetEmail = functions.https.onCall(async (data, context) => {
  console.log("--- CUSTOM PASSWORD RESET EMAIL ---");
  console.log("Data type:", typeof data);
  console.log("Data keys:", data ? Object.keys(data) : 'null');
  
  try {
    // Validate input data
    if (!data || typeof data !== 'object') {
      console.error('Invalid data received:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Data must be an object');
    }

    // Extract the actual data (handle both data.data and direct data formats)
    const requestData = data.data || data;
    console.log("RequestData type:", typeof requestData);
    console.log("RequestData keys:", requestData ? Object.keys(requestData) : 'null');
    
    const { email, displayName } = requestData;

    // Log extracted fields for debugging
    console.log('Extracted fields:', {
      email: email || 'MISSING',
      displayName: displayName || 'MISSING'
    });

    // Validate required fields
    if (!email || String(email).trim() === '') {
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }

    console.log(`Generating password reset link for: ${email}`);
    
    // Generate Firebase password reset link
    // Note: Using default Firebase redirect URL to avoid domain allowlist issues
    const resetLink = await admin.auth().generatePasswordResetLink(email);
    console.log(`Password reset link generated: ${resetLink}`);

    // Send custom email using our branded template
    const result = await sendPasswordResetEmail(email, resetLink, displayName);
    
    console.log(`Custom password reset email sent successfully to ${email}`);
    return result;
    
  } catch (error) {
    console.error('Error in sendCustomPasswordResetEmail:', error);
    
    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'No user found with this email address');
    }
    
    throw new functions.https.HttpsError('internal', `Failed to send password reset email: ${error.message}`);
  }
});

// Delete user from Firebase Auth and Firestore
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  console.log("Raw data received - type:", typeof data);
  const requestData = data.data || data;
  console.log("Using requestData:", requestData);
  
  const { email, adminEmail } = requestData;

  console.log("Extracted email:", email);
  console.log("Extracted adminEmail:", adminEmail);

  if (!email) {
    console.log("No email provided in request");
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }

  if (!adminEmail) {
    console.log("No admin email provided in request");
    throw new functions.https.HttpsError('invalid-argument', 'Admin email is required');
  }
  
  console.log(`Starting delete process for user: ${email} by admin: ${adminEmail}`);

  try {
    // Verify the caller is an admin by checking their email in Firestore
    const callerDoc = await admin.firestore()
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
      console.log(`User ${adminEmail} is not an admin. user_type: ${callerData.user_type}, is_admin_teacher: ${callerData.is_admin_teacher}`);
      throw new functions.https.HttpsError('permission-denied', 'Only administrators can delete users');
    }

    console.log(`Admin ${adminEmail} (verified) attempting to delete user: ${email}`);

    // Find the user to delete in Firestore first
    const userQuery = await admin.firestore()
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

    // Safety check: only allow deletion of inactive users
    const isActive = userData.is_active !== false; // Default to active if field doesn't exist
    console.log(`User active status: ${userData.is_active} (isActive: ${isActive})`);
    
    if (isActive) {
      console.log(`User ${email} is still active, cannot delete`);
      throw new functions.https.HttpsError('failed-precondition', 'User must be deactivated (archived) before deletion');
    }

    console.log(`Deleting user: ${email} (ID: ${userId})`);

    // Try to find and delete from Firebase Auth
    let authUser = null;
    try {
      authUser = await admin.auth().getUserByEmail(email);
      console.log(`Found user in Firebase Auth: ${authUser.uid}`);
      
      // Delete from Firebase Authentication
      await admin.auth().deleteUser(authUser.uid);
      console.log(`Successfully deleted user from Firebase Auth: ${email}`);
    } catch (authError) {
      console.log(`User not found in Firebase Auth or already deleted: ${email}`, authError.message);
      // Continue with Firestore deletion even if auth user doesn't exist
    }

    // Begin batch deletion for Firestore data
    const batch = admin.firestore().batch();

    // Delete user document
    batch.delete(userDoc.ref);

    // Delete related data
    const collections = [
      { name: 'timesheet_entries', field: 'userId' },
      { name: 'form_submissions', field: 'submittedBy' },
      { name: 'form_drafts', field: 'createdBy' }
    ];

    for (const collection of collections) {
      try {
        const relatedQuery = await admin.firestore()
          .collection(collection.name)
          .where(collection.field, '==', userId)
          .get();
        
        console.log(`Found ${relatedQuery.size} documents in ${collection.name} to delete`);
        
        relatedQuery.docs.forEach(doc => {
          batch.delete(doc.ref);
        });
      } catch (error) {
        console.log(`Error querying ${collection.name}:`, error.message);
        // Continue with other collections
      }
    }

    // Handle tasks (remove user from assignedTo array or delete if empty)
    try {
      const taskQuery = await admin.firestore()
        .collection('tasks')
        .where('assignedTo', 'array-contains', userId)
        .get();

      console.log(`Found ${taskQuery.size} tasks assigned to user`);

      taskQuery.docs.forEach(doc => {
        const taskData = doc.data();
        const assignedTo = (taskData.assignedTo || []).filter(id => id !== userId);
        
        if (assignedTo.length === 0) {
          // Delete task if no one else is assigned
          batch.delete(doc.ref);
        } else {
          // Update task to remove this user
          batch.update(doc.ref, { assignedTo });
        }
      });
    } catch (error) {
      console.log(`Error handling tasks:`, error.message);
    }

    // Commit the batch
    await batch.commit();

    console.log(`Successfully deleted user and all associated data: ${email}`);

    return {
      success: true,
      message: `User ${email} and all associated data have been permanently deleted`,
      deletedFromAuth: authUser !== null,
      deletedFromFirestore: true
    };

  } catch (error) {
    console.error('Error in deleteUserAccount:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to delete user: ${error.message}`);
  }
});

// Generate a human-friendly, non-sequential student code
const generateStudentCode = (firstName, lastName) => {
  // Normalize names: remove spaces, special characters, convert to lowercase
  const normalizeString = (str) => {
    return str
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '') // Remove all non-alphanumeric characters
      .substring(0, 10); // Limit length
  };
  
  const firstNormalized = normalizeString(firstName);
  const lastNormalized = normalizeString(lastName);
  
  // Create base student ID: firstname.lastname
  const baseStudentId = `${firstNormalized}.${lastNormalized}`;
  
  return baseStudentId;
};

// Create student account with Student ID
exports.createStudentAccount = functions.https.onCall(async (data, context) => {
  console.log("--- CREATE STUDENT ACCOUNT ---");
  console.log("Raw data received:", data);
  
  try {
    // Validate input data
    if (!data || typeof data !== 'object') {
      console.error('Invalid data received:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Data must be an object');
    }

    // Extract the actual data
    const studentData = data.data || data;
    console.log("Using studentData:", JSON.stringify(studentData, null, 2));
    
    const {
      firstName,
      lastName,
      isAdultStudent,
      guardianIds, // Array of guardian user IDs
      phoneNumber,
      email,
      address,
      emergencyContact,
      notes
    } = studentData;

    // Log extracted fields for debugging
    console.log('Extracted fields:', {
      firstName: firstName || 'MISSING',
      lastName: lastName || 'MISSING', 
      isAdultStudent: isAdultStudent !== undefined ? isAdultStudent : 'MISSING',
      guardianIds: guardianIds || 'OPTIONAL',
      phoneNumber: phoneNumber || 'OPTIONAL',
      email: email || 'OPTIONAL',
      address: address || 'OPTIONAL',
      emergencyContact: emergencyContact || 'OPTIONAL',
      notes: notes || 'OPTIONAL'
    });

    // Validate required fields
    const missingFields = [];
    if (!firstName || String(firstName).trim() === '') missingFields.push('firstName');
    if (!lastName || String(lastName).trim() === '') missingFields.push('lastName');
    if (isAdultStudent === undefined || isAdultStudent === null) missingFields.push('isAdultStudent');

    if (missingFields.length > 0) {
      console.error('Missing required fields:', missingFields);
      throw new functions.https.HttpsError('invalid-argument', `Missing required fields: ${missingFields.join(', ')}`);
    }

    console.log('All required fields validated successfully');

    // Generate unique Student ID
    let studentCode;
    let attempts = 0;
    const maxAttempts = 10;
    
    do {
      // Generate base student code from names
      const baseStudentCode = generateStudentCode(firstName, lastName);
      
      // Add number prefix if this is not the first attempt (to handle duplicates)
      studentCode = attempts === 0 ? baseStudentCode : `${attempts}${baseStudentCode}`;
      attempts++;
      
      // Check if Student ID already exists in users collection
      const existingQuery = await admin.firestore()
        .collection('users')
        .where('student_code', '==', studentCode)
        .limit(1)
        .get();
        
      if (existingQuery.empty) {
        break; // Found unique ID
      }
      
      if (attempts >= maxAttempts) {
        throw new functions.https.HttpsError('internal', 'Failed to generate unique Student ID after multiple attempts');
      }
    } while (attempts < maxAttempts);

    console.log(`Generated unique Student ID: ${studentCode}`);

    let userRecord = null;
    let authUserId = null;

    // For minor students or adult students, create Firebase Auth account with alias email
    const aliasEmail = `${studentCode}@alluwaleducationhub.org`;
    const tempPassword = generateRandomPassword();
    
    console.log(`Creating Firebase Auth user with alias email: ${aliasEmail}`);
    
    userRecord = await admin.auth().createUser({
      email: aliasEmail,
      password: tempPassword,
      displayName: `${firstName} ${lastName}`,
      emailVerified: false
    });
    
    authUserId = userRecord.uid;
    console.log(`Auth user created with UID: ${authUserId}`);

    // Prepare Firestore data for users collection
    const firestoreUserData = {
      first_name: firstName.trim(),
      last_name: lastName.trim(),
      'e-mail': email || aliasEmail,
      user_type: 'student',
      student_code: studentCode,
      is_adult_student: isAdultStudent,
      phone_number: phoneNumber || '',
      address: address || '',
      emergency_contact: emergencyContact || '',
      guardian_ids: guardianIds || [],
      notes: notes || '',
      date_added: admin.firestore.FieldValue.serverTimestamp(),
      last_login: null,
      is_active: true,
      email_verified: false,
      uid: authUserId,
      created_by_admin: true,
      password_reset_required: true,
      temp_password: tempPassword // Store temp password for admin reference
    };

    // Create Firestore document in users collection
    await admin.firestore()
      .collection("users")
      .doc(authUserId)
      .set(firestoreUserData);
    console.log(`User document created for Student ID: ${studentCode}`);

    // Also create a separate students collection document for extended student data
    const studentDocData = {
      student_code: studentCode,
      auth_user_id: authUserId,
      first_name: firstName.trim(),
      last_name: lastName.trim(),
      is_adult_student: isAdultStudent,
      guardian_ids: guardianIds || [],
      phone_number: phoneNumber || '',
      email: email || aliasEmail,
      address: address || '',
      emergency_contact: emergencyContact || '',
      notes: notes || '',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      is_active: true
    };

    await admin.firestore()
      .collection("students")
      .doc(authUserId) // Use same ID as auth user for easy linking
      .set(studentDocData);
    console.log(`Student document created in students collection`);

    // Update guardian documents to include this student in their children_ids array
    if (guardianIds && Array.isArray(guardianIds) && guardianIds.length > 0) {
      const batch = admin.firestore().batch();
      
      for (const guardianId of guardianIds) {
        const guardianRef = admin.firestore().collection('users').doc(guardianId);
        
        // Add this student to guardian's children_ids array
        batch.update(guardianRef, {
          children_ids: admin.firestore.FieldValue.arrayUnion(authUserId)
        });
      }
      
      await batch.commit();
      console.log(`Updated ${guardianIds.length} guardian documents with new student`);
    }

    return {
      success: true,
      studentId: authUserId,
      studentCode: studentCode,
      aliasEmail: aliasEmail,
      tempPassword: tempPassword,
      message: "Student account created successfully",
      isAdultStudent: isAdultStudent,
      guardiansUpdated: guardianIds ? guardianIds.length : 0
    };

  } catch (error) {
    console.error("--- FULL FUNCTION ERROR ---");
    console.error("ERROR MESSAGE:", error.message);
    console.error("ERROR STACK:", error.stack);
    // Re-throw a clean error to the client
    throw new functions.https.HttpsError('internal', error.message, error.stack);
  }
});