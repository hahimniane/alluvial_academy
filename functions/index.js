const {onCall, onRequest} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
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

/**
 * Helper to get notification recipients (email from settings or all admins)
 * Returns array of { email, name }
 */
const getNotificationRecipients = async () => {
  try {
    // 1. Check settings first
    const settingsDoc = await admin.firestore().collection('settings').doc('admin').get();
    if (settingsDoc.exists) {
      const data = settingsDoc.data();
      const email = data.notification_email;
      
      if (email && typeof email === 'string' && email.trim() !== '') {
        console.log(`Using configured notification email: ${email}`);
        return [{ email: email.trim(), name: 'Admin' }];
      }
    }

    // 2. Fallback to all admins
    console.log('No notification email configured, fetching all admin users...');
    const adminUsersSnapshot = await admin.firestore()
      .collection('users')
      .where('is_active', '==', true)
      .get();
    
    const recipients = [];
    // Use Map to deduplicate by ID if needed, but here we want unique emails
    const seenEmails = new Set();

    for (const doc of adminUsersSnapshot.docs) {
      const data = doc.data();
      if (data['user_type'] === 'admin' || data['role'] === 'admin') {
        const email = data['e-mail'] || data['email'];
        const name = `${data['first_name'] || ''} ${data['last_name'] || ''}`.trim() || 'Admin';
        
        if (email && !seenEmails.has(email)) {
          seenEmails.add(email);
          recipients.push({ email, name });
        }
      }
    }
    
    console.log(`Found ${recipients.length} admin(s) to notify`);
    return recipients;
  } catch (error) {
    console.error('Error getting notification recipients:', error);
    return [];
  }
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

// Send student creation notification email to parent/guardian
const sendStudentNotificationEmail = async (parentEmail, parentName, studentData, credentials) => {
  try {
    const transporter = createTransporter();
    
    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: parentEmail,
      subject: `🎓 Student Account Created for ${studentData.firstName} ${studentData.lastName}`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8" />
          <title>Student Account Created</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
            .container { max-width: 600px; margin: 0 auto; background-color: white; }
            .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 30px 20px; text-align: center; }
            .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
            .content { padding: 30px 20px; }
            .student-info-box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
            .credentials-box { background-color: #fef3c7; border: 2px solid #f59e0b; padding: 20px; margin: 20px 0; border-radius: 8px; }
            .credentials-box h3 { margin-top: 0; color: #92400e; }
            .important-note { background-color: #fee2e2; border: 1px solid #ef4444; padding: 15px; margin: 15px 0; border-radius: 6px; }
            .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
            .student-code { font-family: monospace; font-size: 18px; color: #0386FF; font-weight: bold; }
            .password { font-family: monospace; font-size: 16px; color: #e53e3e; font-weight: bold; }
            .info-row { display: flex; justify-content: space-between; margin: 10px 0; padding: 5px 0; border-bottom: 1px solid #e5e7eb; }
            .info-label { font-weight: bold; color: #374151; }
            .info-value { color: #6b7280; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🎓 Student Account Created</h1>
              <p>Your child has been successfully enrolled</p>
            </div>
            
            <div class="content">
              <h2>Dear ${parentName},</h2>
              <p>We're pleased to inform you that a student account has been successfully created for your child at Alluwal Academy.</p>
              
              <div class="student-info-box">
                <h3>📋 Student Information</h3>
                <div class="info-row">
                  <span class="info-label">Name:</span>
                  <span class="info-value">${studentData.firstName} ${studentData.lastName}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Student ID:</span>
                  <span class="student-code">${studentData.studentCode}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Email:</span>
                  <span class="info-value">${studentData.email || 'System generated alias'}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Phone:</span>
                  <span class="info-value">${studentData.phoneNumber || 'Not provided'}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Student Type:</span>
                  <span class="info-value">${studentData.isAdultStudent ? 'Adult Student' : 'Minor Student'}</span>
                </div>
              </div>
              
              ${!studentData.isAdultStudent ? `
              <div class="credentials-box">
                <h3>🔐 Student Login Credentials</h3>
                <p><strong>Email/Username:</strong> ${credentials.email}</p>
                <p><strong>Temporary Password:</strong> <span class="password">${credentials.tempPassword}</span></p>
                <p><strong>Student ID:</strong> <span class="student-code">${studentData.studentCode}</span></p>
              </div>
              ` : ''}
              
              <div class="important-note">
                <h3>⚠️ Important Notes:</h3>
                <ul>
                  <li>Please keep the Student ID safe - it will be needed for future reference</li>
                  ${!studentData.isAdultStudent ? '<li>The temporary password should be changed during the first login</li>' : ''}
                  <li>If you have any questions, please contact the school administration</li>
                  <li>You will receive additional information about class schedules and requirements separately</li>
                </ul>
              </div>
              
              <p>We look forward to working with you and ${studentData.firstName} throughout their educational journey at Alluwal Academy.</p>
              
              <p>Best regards,<br>
              Alluwal Academy Administration Team</p>
            </div>
            
            <div class="footer">
              <p>This is an automated notification. For questions, please contact the school office.</p>
              <p>Alluwal Academy - Excellence in Islamic Education</p>
            </div>
          </div>
        </body>
        </html>
      `
    };

    await transporter.sendMail(mailOptions);
    console.log(`Student notification email sent to ${parentEmail} for student ${studentData.firstName} ${studentData.lastName}`);
    return true;
  } catch (error) {
    console.error('Error sending student notification email:', error);
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

// Task status update notification function (v2)
exports.sendTaskStatusUpdateNotification = onCall(async (request) => {
  console.log("--- TASK STATUS UPDATE NOTIFICATION ---");
  
  try {
    const { taskId, taskTitle, oldStatus, newStatus, updatedByName, createdBy } = request.data || {};
    
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
    let guardianEmails = [];
    console.log(`=== GUARDIAN PROCESSING DEBUG ===`);
    console.log(`Guardian IDs received: ${JSON.stringify(guardianIds)}`);
    console.log(`Guardian IDs type: ${typeof guardianIds}`);
    console.log(`Guardian IDs is array: ${Array.isArray(guardianIds)}`);
    console.log(`Guardian IDs length: ${guardianIds ? guardianIds.length : 'null/undefined'}`);
    
    if (guardianIds && Array.isArray(guardianIds) && guardianIds.length > 0) {
      const batch = admin.firestore().batch();
      console.log(`Processing ${guardianIds.length} guardian(s)...`);
      
      for (const guardianId of guardianIds) {
        console.log(`\n--- Processing guardian ID: ${guardianId} ---`);
        const guardianRef = admin.firestore().collection('users').doc(guardianId);
        
        // Get guardian information for email notification
        try {
          const guardianDoc = await guardianRef.get();
          console.log(`Guardian document exists: ${guardianDoc.exists}`);
          
          if (guardianDoc.exists) {
            const guardianData = guardianDoc.data();
            console.log(`Guardian data:`, JSON.stringify(guardianData, null, 2));
            
            const guardianEmail = guardianData['e-mail'] || guardianData['email'];
            const guardianName = `${guardianData['first_name'] || ''} ${guardianData['last_name'] || ''}`.trim() || 'Guardian';
            
            console.log(`Extracted guardian email: ${guardianEmail}`);
            console.log(`Extracted guardian name: ${guardianName}`);
            
            if (guardianEmail) {
              guardianEmails.push({
                email: guardianEmail,
                name: guardianName
              });
              console.log(`✅ Added guardian email to notification list`);
            } else {
              console.log(`❌ No email found for guardian ${guardianId}`);
            }
          } else {
            console.log(`❌ Guardian document ${guardianId} does not exist`);
          }
        } catch (error) {
          console.error(`❌ Error getting guardian ${guardianId} data:`, error);
        }
        
        // Add this student to guardian's children_ids array
        batch.update(guardianRef, {
          children_ids: admin.firestore.FieldValue.arrayUnion(authUserId)
        });
        console.log(`Added student to guardian's children_ids array`);
      }
      
      await batch.commit();
      console.log(`Updated ${guardianIds.length} guardian documents with new student`);
    } else {
      console.log(`⚠️ No guardian IDs to process (empty, null, or not an array)`);
    }
    
    console.log(`=== GUARDIAN PROCESSING SUMMARY ===`);
    console.log(`Guardian emails collected: ${guardianEmails.length}`);
    console.log(`Guardian emails list:`, JSON.stringify(guardianEmails, null, 2));
    console.log(`=== END GUARDIAN DEBUG ===\n`);

    // Send email notifications to guardians/parents
    let emailsSent = 0;
    console.log(`=== EMAIL NOTIFICATION DEBUG ===`);
    console.log(`Guardian emails found: ${guardianEmails.length}`);
    console.log(`Guardian emails array:`, JSON.stringify(guardianEmails, null, 2));
    console.log(`isAdultStudent: ${isAdultStudent}`);
    
    if (guardianEmails.length > 0) {
      const studentData = {
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        studentCode: studentCode,
        email: email || aliasEmail,
        phoneNumber: phoneNumber,
        isAdultStudent: isAdultStudent
      };
      
      const credentials = {
        email: email || aliasEmail,
        tempPassword: tempPassword
      };
      
      console.log(`Student data for email:`, JSON.stringify(studentData, null, 2));
      console.log(`Credentials for email:`, { email: credentials.email, tempPassword: '[HIDDEN]' });
      
      for (const guardian of guardianEmails) {
        console.log(`\n--- Attempting to send email to guardian ---`);
        console.log(`Guardian name: ${guardian.name}`);
        console.log(`Guardian email: ${guardian.email}`);
        
        try {
          const emailSent = await sendStudentNotificationEmail(
            guardian.email,
            guardian.name,
            studentData,
            credentials
          );
          console.log(`Email send result: ${emailSent}`);
          
          if (emailSent) {
            emailsSent++;
            console.log(`✅ Student notification email sent to ${guardian.name} (${guardian.email})`);
          } else {
            console.log(`❌ Failed to send email to ${guardian.name} (${guardian.email}) - sendStudentNotificationEmail returned false`);
          }
        } catch (error) {
          console.error(`❌ Exception while sending student notification email to ${guardian.email}:`, error);
          console.error(`Error stack:`, error.stack);
        }
      }
    } else {
      console.log(`⚠️ No guardian emails found - skipping email notifications`);
      if (guardianIds && guardianIds.length > 0) {
        console.log(`Guardian IDs were provided: ${JSON.stringify(guardianIds)}`);
        console.log(`But no valid email addresses were found for these guardians`);
      } else {
        console.log(`No guardian IDs were provided in the request`);
      }
    }
    
    console.log(`=== EMAIL NOTIFICATION SUMMARY ===`);
    console.log(`Total guardian emails: ${guardianEmails.length}`);
    console.log(`Emails sent successfully: ${emailsSent}`);
    console.log(`=== END EMAIL DEBUG ===\n`);

    return {
      success: true,
      studentId: authUserId,
      studentCode: studentCode,
      aliasEmail: aliasEmail,
      tempPassword: tempPassword,
      message: "Student account created successfully",
      isAdultStudent: isAdultStudent,
      guardiansUpdated: guardianIds ? guardianIds.length : 0,
      emailsToGuardians: guardianEmails.length,
      emailsSent: emailsSent
    };

  } catch (error) {
    console.error("--- FULL FUNCTION ERROR ---");
    console.error("ERROR MESSAGE:", error.message);
    console.error("ERROR STACK:", error.stack);
    // Re-throw a clean error to the client
    throw new functions.https.HttpsError('internal', error.message, error.stack);
  }
});

// Email template for task comment notifications
const getTaskCommentEmailTemplate = (data) => {
  const {
    taskTitle,
    taskDescription,
    commentAuthor,
    commentText,
    taskDueDate,
    taskPriority,
    taskStatus,
    commentDate
  } = data;

  const formattedDueDate = new Date(taskDueDate).toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

  const formattedCommentDate = new Date(commentDate).toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

  const priorityColor = taskPriority === 'High' ? '#DC2626' : 
                       taskPriority === 'Medium' ? '#F59E0B' : '#10B981';
  
  const statusColor = taskStatus === 'Completed' ? '#10B981' : 
                     taskStatus === 'In Progress' ? '#8B5CF6' : '#3B82F6';

  return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>New Task Comment - Alluwal Academy</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
            .container { max-width: 600px; margin: 0 auto; background-color: white; }
            .header { background: linear-gradient(135deg, #0386FF 0%, #0369C9 100%); padding: 40px 30px; text-align: center; }
            .header h1 { color: white; margin: 0; font-size: 28px; font-weight: 600; }
            .header p { color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px; }
            .content { padding: 40px 30px; }
            .comment-card { background: #f8fafc; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 8px; }
            .task-info { background: #f1f5f9; padding: 20px; border-radius: 8px; margin: 20px 0; }
            .task-title { font-size: 20px; font-weight: 600; color: #1e293b; margin: 0 0 10px 0; }
            .task-meta { display: flex; gap: 15px; margin: 15px 0; flex-wrap: wrap; }
            .badge { padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 500; }
            .priority { background-color: ${priorityColor}; color: white; }
            .status { background-color: ${statusColor}; color: white; }
            .comment-author { font-weight: 600; color: #0386FF; margin-bottom: 8px; }
            .comment-text { font-size: 15px; line-height: 1.6; color: #374151; }
            .comment-date { font-size: 13px; color: #6b7280; margin-top: 10px; }
            .task-description { font-size: 14px; color: #6b7280; margin: 10px 0; line-height: 1.5; }
            .due-date { font-size: 14px; color: #dc2626; font-weight: 500; }
            .footer { background: #f1f5f9; padding: 30px; text-align: center; border-top: 1px solid #e2e8f0; }
            .footer p { margin: 0; color: #6b7280; font-size: 14px; }
            .logo { width: 120px; height: auto; margin-bottom: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>💬 New Task Comment</h1>
                <p>Someone commented on a task you're involved with</p>
            </div>
            
            <div class="content">
                <div class="comment-card">
                    <div class="comment-author">${commentAuthor} commented:</div>
                    <div class="comment-text">"${commentText}"</div>
                    <div class="comment-date">🕒 ${formattedCommentDate}</div>
                </div>

                <div class="task-info">
                    <div class="task-title">📋 ${taskTitle}</div>
                    ${taskDescription ? `<div class="task-description">${taskDescription}</div>` : ''}
                    
                    <div class="task-meta">
                        <span class="badge priority">🔥 ${taskPriority} Priority</span>
                        <span class="badge status">📊 ${taskStatus}</span>
                    </div>
                    
                    <div class="due-date">⏰ Due: ${formattedDueDate}</div>
                </div>

                <p style="margin-top: 30px; font-size: 15px; color: #374151;">
                    You're receiving this notification because you're either assigned to this task or created it. 
                    Log into your Alluwal Academy dashboard to view the full conversation and respond.
                </p>
            </div>
            
            <div class="footer">
                <p>
                    <strong>Alluwal Education Hub</strong><br>
                    Islamic Education Management System<br>
                    <a href="mailto:support@alluwaleducationhub.org" style="color: #0386FF;">support@alluwaleducationhub.org</a>
                </p>
            </div>
        </div>
    </body>
    </html>
  `;
};

// Process email queue for task comment notifications
exports.processTaskCommentEmail = onDocumentCreated('mail/{emailId}', async (event) => {
  const snap = event.data;
    const emailData = snap.data();
    
    // Check if this is a task comment notification
    if (emailData.template?.name !== 'task_comment_notification') {
      return null;
    }

    try {
      const transporter = createTransporter();
      const templateData = emailData.template.data;
      const recipients = emailData.to;

      console.log('Processing task comment notification for:', recipients);

      const mailOptions = {
        from: 'support@alluwaleducationhub.org',
        to: recipients.join(', '),
        subject: `💬 New comment on task: ${templateData.taskTitle}`,
        html: getTaskCommentEmailTemplate(templateData),
      };

      await transporter.sendMail(mailOptions);
      console.log('Task comment notification sent successfully to:', recipients);

      // Mark email as sent
      await snap.ref.update({ 
        delivered: true, 
        deliveredAt: admin.firestore.FieldValue.serverTimestamp() 
      });

    } catch (error) {
      console.error('Error sending task comment notification:', error);
      
      // Mark email as failed
      await snap.ref.update({ 
        failed: true, 
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp() 
      });
    }

    return null;
});

// Send task comment notification via HTTPS callable (direct send, no Firestore queue)
exports.sendTaskCommentNotification = onCall(async (request) => {
  try {
    const {
      taskId,
      commentAuthorId,
      commentAuthorName,
      commentText,
      commentDate,
    } = request.data || {};

    if (!taskId || !commentAuthorId || !commentAuthorName || !commentText) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: taskId, commentAuthorId, commentAuthorName, commentText'
      );
    }

    const taskSnap = await admin.firestore().collection('tasks').doc(taskId).get();
    if (!taskSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Task not found');
    }

    const task = taskSnap.data();

    // Extract task fields with fallbacks
    const createdBy = task.createdBy;
    const assignedToRaw = task.assignedTo;
    const assignedTo = Array.isArray(assignedToRaw)
      ? assignedToRaw
      : (assignedToRaw ? [assignedToRaw] : []);

    // Determine recipients per business rule
    const recipientUserIdsSet = new Set();
    if (commentAuthorId === createdBy) {
      // Creator commented -> notify all assignees
      assignedTo.forEach((uid) => recipientUserIdsSet.add(uid));
    } else if (assignedTo.includes(commentAuthorId)) {
      // Assignee commented -> notify creator
      if (createdBy) recipientUserIdsSet.add(createdBy);
    } else {
      // Other user commented -> notify creator + assignees
      if (createdBy) recipientUserIdsSet.add(createdBy);
      assignedTo.forEach((uid) => recipientUserIdsSet.add(uid));
    }
    recipientUserIdsSet.delete(commentAuthorId);

    const recipientUserIds = Array.from(recipientUserIdsSet);

    if (recipientUserIds.length === 0) {
      return { success: false, reason: 'No recipients to notify' };
    }

    // Resolve recipient emails and names
    const recipients = [];
    const recipientNames = [];
    for (const uid of recipientUserIds) {
      try {
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data() || {};
          const email = userData['e-mail'];
          const firstName = userData['first_name'] || '';
          const lastName = userData['last_name'] || '';
          const fullName = `${firstName} ${lastName}`.trim();
          if (email) {
            recipients.push(email);
            recipientNames.push(fullName || email);
          }
        }
      } catch (err) {
        console.error('Error resolving user email for uid', uid, err);
      }
    }

    if (recipients.length === 0) {
      return { success: false, reason: 'No recipient emails found' };
    }

    // Prepare template data using robust mappings
    const toIsoString = (ts) => {
      if (!ts) return new Date().toISOString();
      // Firestore Timestamp
      if (ts && ts.toDate) return ts.toDate().toISOString();
      // String
      if (typeof ts === 'string') return new Date(ts).toISOString();
      // Number (ms)
      if (typeof ts === 'number') return new Date(ts).toISOString();
      return new Date().toISOString();
    };

    const mapPriority = (p) => {
      if (typeof p === 'string') {
        const v = p.toLowerCase();
        if (v.includes('high')) return 'High';
        if (v.includes('medium')) return 'Medium';
        return 'Low';
      }
      if (typeof p === 'number') {
        return ['Low', 'Medium', 'High'][p] || 'Medium';
      }
      return 'Medium';
    };

    const mapStatus = (s) => {
      if (typeof s === 'string') {
        const v = s.toLowerCase();
        if (v.includes('done') || v.includes('completed')) return 'Completed';
        if (v.includes('progress')) return 'In Progress';
        return 'To Do';
      }
      if (typeof s === 'number') {
        return ['To Do', 'In Progress', 'Completed'][s] || 'To Do';
      }
      return 'To Do';
    };

    const templateData = {
      taskTitle: task.title || 'Untitled Task',
      taskDescription: task.description || '',
      commentAuthor: commentAuthorName,
      commentText,
      taskDueDate: toIsoString(task.dueDate),
      taskPriority: mapPriority(task.priority),
      taskStatus: mapStatus(task.status),
      taskId,
      commentDate: commentDate || new Date().toISOString(),
      recipients: recipientNames,
    };

    const transporter = createTransporter();
    const mailOptions = {
      from: 'support@alluwaleducationhub.org',
      to: recipients.join(', '),
      subject: `💬 New comment on task: ${templateData.taskTitle}`,
      html: getTaskCommentEmailTemplate(templateData),
    };

    console.log('Sending task comment notification to:', recipients);
    await transporter.sendMail(mailOptions);
    console.log('Task comment notification sent successfully');

    return { success: true, recipients };
  } catch (error) {
    console.error('sendTaskCommentNotification error:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Unknown error');
  }
});

// ===== SHIFT NOTIFICATION FUNCTIONS =====

// Helper function to send FCM notification to a teacher
const sendFCMNotificationToTeacher = async (teacherId, notification, data) => {
  try {
    console.log(`Sending FCM notification to teacher: ${teacherId}`);
    
    // Get teacher's FCM tokens from Firestore
    const teacherDoc = await admin.firestore()
      .collection('users')
      .doc(teacherId)
      .get();
    
    if (!teacherDoc.exists) {
      console.log(`Teacher ${teacherId} not found`);
      return { success: false, reason: 'Teacher not found' };
    }
    
    const teacherData = teacherDoc.data();
    const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim();
    const fcmTokens = teacherData.fcmTokens || [];
    
    console.log(`\n=== Shift Notification for: ${teacherName} (${teacherId}) ===`);
    console.log(`FCM Tokens found: ${fcmTokens.length}`);
    
    if (fcmTokens.length === 0) {
      console.log(`⚠️ No FCM tokens found for teacher ${teacherId}`);
      return { success: false, reason: 'No FCM tokens' };
    }
    
    // Extract just the token strings from the array
    const tokens = fcmTokens.map(tokenObj => tokenObj.token).filter(t => t);
    console.log(`Valid tokens extracted: ${tokens.length}`);
    
    // Log detailed token information
    fcmTokens.forEach((tokenData, idx) => {
      console.log(`  Token ${idx}:`);
      console.log(`    Platform: ${tokenData.platform || 'unknown'}`);
      console.log(`    Token: ${tokenData.token ? tokenData.token.substring(0, 30) + '...' : 'null'}`);
      console.log(`    Last Updated: ${tokenData.lastUpdated || 'unknown'}`);
    });
    
    if (tokens.length === 0) {
      console.log(`⚠️ No valid tokens found for teacher ${teacherId}`);
      return { success: false, reason: 'No valid tokens' };
    }
    
    console.log(`\nAttempting to send shift notification to ${tokens.length} token(s)...`);
    
    // Send to all devices
    const message = {
      notification: notification,
      data: data,
      tokens: tokens,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };
    
    const response = await admin.messaging().sendEachForMulticast(message);
    
    console.log(`\n📱 Shift Notification Result for ${teacherName}:`);
    console.log(`  Success: ${response.successCount}/${tokens.length}`);
    console.log(`  Failed: ${response.failureCount}/${tokens.length}`);
    
    // Log individual responses
    response.responses.forEach((resp, idx) => {
      if (resp.success) {
        console.log(`  ✅ Token ${idx}: SUCCESS - Message ID: ${resp.messageId}`);
      } else {
        console.log(`  ❌ Token ${idx}: FAILED - Error: ${resp.error?.code} - ${resp.error?.message}`);
      }
    });
    
    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount
    };
  } catch (error) {
    console.error('Error sending FCM notification:', error);
    return { success: false, error: error.message };
  }
};

// Helper function to format date/time for notifications
const formatShiftDateTime = (timestamp) => {
  try {
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit'
    });
  } catch (error) {
    return 'Unknown date';
  }
};

// 1. On Shift Created - Send notification when new shift is assigned
exports.onShiftCreated = onDocumentCreated('teaching_shifts/{shiftId}', async (event) => {
    try {
      const shiftData = event.data.data();
      const shiftId = event.params.shiftId;
      
      console.log(`🎓 New shift created: ${shiftId}`);
      
      const teacherId = shiftData.teacher_id;
      const teacherName = shiftData.teacher_name || 'Teacher';
      const studentNames = (shiftData.student_names || []).join(', ') || 'students';
      const subject = shiftData.subject_display_name || shiftData.subject || 'Class';
      const shiftStart = shiftData.shift_start;
      const shiftDateTime = formatShiftDateTime(shiftStart);
      
      const notification = {
        title: '🎓 New Shift Assigned',
        body: `${subject} with ${studentNames} on ${shiftDateTime}`
      };
      
      const data = {
        type: 'shift',
        action: 'created',
        shiftId: shiftId,
        teacherId: teacherId,
        shiftStart: shiftStart.toDate().toISOString()
      };
      
      await sendFCMNotificationToTeacher(teacherId, notification, data);
      
      console.log(`✅ Shift created notification sent to ${teacherName}`);
    } catch (error) {
      console.error('Error in onShiftCreated:', error);
      // Don't throw - we don't want to fail the shift creation
    }
  });

// 2. On Shift Updated - Send notification when shift details change
exports.onShiftUpdated = onDocumentUpdated('teaching_shifts/{shiftId}', async (event) => {
    try {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const shiftId = event.params.shiftId;
      
      // Skip if shift was cancelled (handled by onShiftCancelled)
      if (afterData.status === 'cancelled' && beforeData.status !== 'cancelled') {
        console.log('Shift cancelled - skipping onShiftUpdated');
        return;
      }
      
      // Skip if only status changed (to avoid duplicate notifications)
      if (afterData.status !== beforeData.status) {
        console.log('Only status changed - skipping onShiftUpdated');
        return;
      }
      
      console.log(`📝 Shift updated: ${shiftId}`);
      
      const teacherId = afterData.teacher_id;
      const displayName = afterData.custom_name || afterData.auto_generated_name || 'Your shift';
      const shiftDateTime = formatShiftDateTime(afterData.shift_start);
      
      // Detect what changed
      const changes = [];
      if (beforeData.shift_start?.toDate().getTime() !== afterData.shift_start?.toDate().getTime()) {
        changes.push('time changed');
      }
      if (JSON.stringify(beforeData.student_ids) !== JSON.stringify(afterData.student_ids)) {
        changes.push('students changed');
      }
      if (beforeData.subject !== afterData.subject) {
        changes.push('subject changed');
      }
      
      const changesText = changes.length > 0 ? changes.join(', ') : 'details updated';
      
      const notification = {
        title: '📝 Shift Updated',
        body: `${displayName} on ${shiftDateTime} - ${changesText}`
      };
      
      const data = {
        type: 'shift',
        action: 'updated',
        shiftId: shiftId,
        teacherId: teacherId,
        changes: changesText
      };
      
      await sendFCMNotificationToTeacher(teacherId, notification, data);
      
      console.log(`✅ Shift updated notification sent`);
    } catch (error) {
      console.error('Error in onShiftUpdated:', error);
    }
  });

// 3. On Shift Cancelled - Send notification when shift is cancelled
exports.onShiftCancelled = onDocumentUpdated('teaching_shifts/{shiftId}', async (event) => {
    try {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const shiftId = event.params.shiftId;
      
      // Only trigger if status changed to cancelled
      if (afterData.status === 'cancelled' && beforeData.status !== 'cancelled') {
        console.log(`⚠️ Shift cancelled: ${shiftId}`);
        
        const teacherId = afterData.teacher_id;
        const displayName = afterData.custom_name || afterData.auto_generated_name || 'Your shift';
        const shiftDateTime = formatShiftDateTime(afterData.shift_start);
        
        const notification = {
          title: '⚠️ Shift Cancelled',
          body: `${displayName} on ${shiftDateTime} has been cancelled`
        };
        
        const data = {
          type: 'shift',
          action: 'cancelled',
          shiftId: shiftId,
          teacherId: teacherId
        };
        
        await sendFCMNotificationToTeacher(teacherId, notification, data);
        
        console.log(`✅ Shift cancelled notification sent`);
      }
    } catch (error) {
      console.error('Error in onShiftCancelled:', error);
    }
  });

// 4. On Shift Deleted - Send notification when shift is completely deleted
exports.onShiftDeleted = onDocumentDeleted('teaching_shifts/{shiftId}', async (event) => {
    try {
      const shiftData = event.data.data();
      const shiftId = event.params.shiftId;
      
      console.log(`🗑️ Shift deleted: ${shiftId}`);
      
      const teacherId = shiftData.teacher_id;
      const displayName = shiftData.custom_name || shiftData.auto_generated_name || 'A shift';
      const shiftDateTime = formatShiftDateTime(shiftData.shift_start);
      
      const notification = {
        title: '🗑️ Shift Deleted',
        body: `${displayName} on ${shiftDateTime} has been removed`
      };
      
      const data = {
        type: 'shift',
        action: 'deleted',
        shiftId: shiftId,
        teacherId: teacherId
      };
      
      await sendFCMNotificationToTeacher(teacherId, notification, data);
      
      console.log(`✅ Shift deleted notification sent`);
    } catch (error) {
      console.error('Error in onShiftDeleted:', error);
    }
  });

// 5. Scheduled Shift Reminders - Runs every 5 minutes to send reminders
exports.sendScheduledShiftReminders = onSchedule('every 5 minutes', async (event) => {
    try {
      console.log('🔔 Running scheduled shift reminders check...');
      
      const now = admin.firestore.Timestamp.now();
      const oneHourFromNow = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 60 * 60 * 1000)
      );
      
      // Get all upcoming shifts in the next hour
      const upcomingShiftsSnapshot = await admin.firestore()
        .collection('teaching_shifts')
        .where('shift_start', '>', now)
        .where('shift_start', '<=', oneHourFromNow)
        .where('status', '==', 'scheduled')
        .get();
      
      console.log(`Found ${upcomingShiftsSnapshot.size} upcoming shifts in next hour`);
      
      if (upcomingShiftsSnapshot.empty) {
        console.log('No upcoming shifts - skipping reminders');
        return;
      }
      
      let remindersSent = 0;
      
      for (const shiftDoc of upcomingShiftsSnapshot.docs) {
        try {
          const shift = shiftDoc.data();
          const shiftId = shiftDoc.id;
          const teacherId = shift.teacher_id;
          const shiftStart = shift.shift_start.toDate();
          const minutesUntilShift = Math.floor((shiftStart.getTime() - Date.now()) / 1000 / 60);
          
          // Get teacher's notification preferences
          const teacherDoc = await admin.firestore()
            .collection('users')
            .doc(teacherId)
            .get();
          
          if (!teacherDoc.exists) continue;
          
          const teacherData = teacherDoc.data();
          const notifPrefs = teacherData.notificationPreferences || {};
          const isEnabled = notifPrefs.shiftEnabled !== false; // Default true
          const reminderMinutes = notifPrefs.shiftMinutes || 15; // Default 15 mins
          
          if (!isEnabled) {
            console.log(`Shift reminders disabled for teacher ${teacherId}`);
            continue;
          }
          
          // Check if it's time to send reminder (within 1 minute window)
          const shouldSendReminder = Math.abs(minutesUntilShift - reminderMinutes) <= 2;
          
          if (!shouldSendReminder) {
            console.log(`Not time yet for shift ${shiftId} (${minutesUntilShift} mins vs ${reminderMinutes} mins preference)`);
            continue;
          }
          
          // Check if we already sent a reminder (to avoid duplicates)
          const reminderSentKey = `reminder_sent_${reminderMinutes}min`;
          if (shift[reminderSentKey] === true) {
            console.log(`Reminder already sent for shift ${shiftId}`);
            continue;
          }
          
          // Send the reminder
          const displayName = shift.custom_name || shift.auto_generated_name || 'Your shift';
          const shiftDateTime = formatShiftDateTime(shift.shift_start);
          
          const notification = {
            title: '🔔 Shift Reminder',
            body: `${displayName} starts in ${minutesUntilShift} minutes at ${shiftDateTime}`
          };
          
          const data = {
            type: 'shift',
            action: 'reminder',
            shiftId: shiftId,
            teacherId: teacherId,
            minutesUntilShift: minutesUntilShift.toString()
          };
          
          const result = await sendFCMNotificationToTeacher(teacherId, notification, data);
          
          if (result.success) {
            // Mark reminder as sent
            await shiftDoc.ref.update({
              [reminderSentKey]: true
            });
            remindersSent++;
            console.log(`✅ Reminder sent for shift ${shiftId}`);
          }
          
        } catch (error) {
          console.error(`Error processing shift reminder:`, error);
          // Continue with next shift
        }
      }
      
      console.log(`✅ Scheduled reminders completed: ${remindersSent} reminders sent`);
    } catch (error) {
      console.error('Error in sendScheduledShiftReminders:', error);
    }
  });

// ===== ADMIN NOTIFICATION SENDER =====

/**
 * Send custom notifications to users
 * Allows admin to send notifications to:
 * - Individual users
 * - All users of a specific role (teachers, students, parents, admins)
 * - Selected users from a specific role
 */
exports.sendAdminNotification = functions.https.onCall(async (data, context) => {
  console.log("--- ADMIN NOTIFICATION SENDER ---");
  
  try {
    // Extract data (handle both data.data and direct data formats)
    const requestData = data.data || data;
    
    const {
      recipientType, // 'individual', 'role', 'selected'
      recipientRole, // 'teacher', 'student', 'parent', 'admin' (when recipientType is 'role')
      recipientIds, // Array of user IDs
      notificationTitle,
      notificationBody,
      notificationData, // Optional additional data
      sendEmail, // Optional: also send email notification
      adminId, // Admin user ID who is sending the notification
    } = requestData;
    
    console.log('Notification request:', {
      recipientType,
      recipientRole,
      recipientIds: recipientIds?.length || 0,
      title: notificationTitle,
      sendEmail,
      adminId
    });
    
    // Validate required fields
    if (!notificationTitle || !notificationBody) {
      throw new functions.https.HttpsError('invalid-argument', 'Notification title and body are required');
    }
    
    if (!recipientType) {
      throw new functions.https.HttpsError('invalid-argument', 'Recipient type is required');
    }
    
    // Verify admin if adminId is provided
    if (adminId) {
      const adminDoc = await admin.firestore()
        .collection('users')
        .doc(adminId)
        .get();
      
      if (!adminDoc.exists) {
        throw new functions.https.HttpsError('permission-denied', 'Admin user not found');
      }
      
      const adminData = adminDoc.data();
      const isAdmin = adminData.user_type === 'admin' || adminData.is_admin_teacher === true;
      
      if (!isAdmin) {
        throw new functions.https.HttpsError('permission-denied', 'Only administrators can send notifications');
      }
      
      console.log(`Admin ${adminData['e-mail']} (${adminId}) is sending notifications`);
    }
    
    // Get target user IDs based on recipient type
    let targetUserIds = [];
    
    if (recipientType === 'individual' || recipientType === 'selected') {
      if (!recipientIds || !Array.isArray(recipientIds) || recipientIds.length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Recipient IDs are required for individual/selected notifications');
      }
      targetUserIds = recipientIds;
    } else if (recipientType === 'role') {
      if (!recipientRole) {
        throw new functions.https.HttpsError('invalid-argument', 'Recipient role is required when sending to a role');
      }
      
      // Query users by role
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('user_type', '==', recipientRole)
        .where('is_active', '==', true) // Only send to active users
        .get();
      
      targetUserIds = usersSnapshot.docs.map(doc => doc.id);
      console.log(`Found ${targetUserIds.length} active ${recipientRole}s`);
    }
    
    if (targetUserIds.length === 0) {
      return {
        success: false,
        message: 'No recipients found',
        totalRecipients: 0
      };
    }
    
    // Prepare notification data
    const notification = {
      title: notificationTitle,
      body: notificationBody
    };
    
    const messageData = {
      type: 'admin_notification',
      timestamp: new Date().toISOString(),
      ...(notificationData || {})
    };
    
    // Send notifications
    const results = {
      totalRecipients: targetUserIds.length,
      fcmSuccess: 0,
      fcmFailed: 0,
      emailsSent: 0,
      emailsFailed: 0,
      details: []
    };
    
    // Process each recipient
    for (const userId of targetUserIds) {
      const recipientResult = {
        userId,
        fcmSent: false,
        emailSent: false,
        errors: []
      };
      
      try {
        // Get user data
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();
        
        if (!userDoc.exists) {
          recipientResult.errors.push('User not found');
          results.details.push(recipientResult);
          continue;
        }
        
            const userData = userDoc.data();
            const userEmail = userData['e-mail'] || userData.email;
            const userName = `${userData.first_name || ''} ${userData.last_name || ''}`.trim();
            
            console.log(`\n=== Processing user: ${userName} (${userId}) ===`);
            console.log(`Email: ${userEmail}`);
            
            // Send FCM notification
            const fcmTokens = userData.fcmTokens || [];
            console.log(`FCM Tokens found: ${fcmTokens.length}`);
        if (fcmTokens.length > 0) {
          const tokens = fcmTokens.map(t => t.token).filter(t => t);
          console.log(`Valid tokens extracted: ${tokens.length}`);
          
          // Log detailed token information
          fcmTokens.forEach((tokenData, idx) => {
            console.log(`  Token ${idx}:`);
            console.log(`    Platform: ${tokenData.platform || 'unknown'}`);
            console.log(`    Token: ${tokenData.token ? tokenData.token.substring(0, 30) + '...' : 'null'}`);
            console.log(`    Last Updated: ${tokenData.lastUpdated || 'unknown'}`);
          });
          
          if (tokens.length > 0) {
            try {
              console.log(`\nAttempting to send FCM message to ${tokens.length} token(s)...`);
              const fcmMessage = {
                notification: notification,
                data: messageData,
                tokens: tokens,
                android: {
                  priority: 'high',
                  notification: {
                    sound: 'default',
                    channelId: 'high_importance_channel'
                  }
                },
                apns: {
                  payload: {
                    aps: {
                      sound: 'default',
                      badge: 1
                    }
                  }
                }
              };
              
              const response = await admin.messaging().sendEachForMulticast(fcmMessage);
              
              console.log(`\n📱 FCM Send Result for ${userName}:`);
              console.log(`  Success: ${response.successCount}/${tokens.length}`);
              console.log(`  Failed: ${response.failureCount}/${tokens.length}`);
              
              // Log individual responses
              response.responses.forEach((resp, idx) => {
                if (resp.success) {
                  console.log(`  ✅ Token ${idx}: SUCCESS - Message ID: ${resp.messageId}`);
                } else {
                  console.log(`  ❌ Token ${idx}: FAILED - Error: ${resp.error?.code} - ${resp.error?.message}`);
                }
              });
              
              if (response.successCount > 0) {
                recipientResult.fcmSent = true;
                results.fcmSuccess++;
              } else {
                results.fcmFailed++;
                recipientResult.errors.push('FCM send failed');
              }
              
              console.log(`FCM sent to ${userName}: ${response.successCount}/${tokens.length} success`);
            } catch (fcmError) {
              console.error(`FCM error for ${userId}:`, fcmError);
              recipientResult.errors.push(`FCM error: ${fcmError.message}`);
              results.fcmFailed++;
            }
          }
        } else {
          recipientResult.errors.push('No FCM tokens');
        }
        
        // Send email if requested
        if (sendEmail && userEmail) {
          try {
            const transporter = createTransporter();
            
            const mailOptions = {
              from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
              to: userEmail,
              subject: `📢 ${notificationTitle}`,
              html: `
                <!DOCTYPE html>
                <html>
                <head>
                  <meta charset="UTF-8" />
                  <title>${notificationTitle}</title>
                  <style>
                    body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
                    .container { max-width: 600px; margin: 0 auto; background-color: white; }
                    .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 30px 20px; text-align: center; }
                    .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
                    .content { padding: 30px 20px; }
                    .notification-box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
                    .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
                  </style>
                </head>
                <body>
                  <div class="container">
                    <div class="header">
                      <h1>📢 Important Notification</h1>
                      <p>From Alluwal Education Hub</p>
                    </div>
                    
                    <div class="content">
                      <p>Dear ${userName || 'User'},</p>
                      
                      <div class="notification-box">
                        <h2 style="margin-top: 0; color: #0386FF;">${notificationTitle}</h2>
                        <p style="margin: 0; white-space: pre-wrap;">${notificationBody}</p>
                      </div>
                      
                      <p>This notification was sent by the Alluwal Academy administration. If you have any questions, please contact us.</p>
                      
                      <p>Best regards,<br>
                      Alluwal Academy Team</p>
                    </div>
                    
                    <div class="footer">
                      <p>© ${new Date().getFullYear()} Alluwal Education Hub. All rights reserved.</p>
                      <p>This is an automated notification. Please do not reply to this email.</p>
                    </div>
                  </div>
                </body>
                </html>
              `
            };
            
            await transporter.sendMail(mailOptions);
            recipientResult.emailSent = true;
            results.emailsSent++;
            console.log(`Email sent to ${userName} (${userEmail})`);
          } catch (emailError) {
            console.error(`Email error for ${userId}:`, emailError);
            recipientResult.errors.push(`Email error: ${emailError.message}`);
            results.emailsFailed++;
          }
        }
        
      } catch (error) {
        console.error(`Error processing recipient ${userId}:`, error);
        recipientResult.errors.push(error.message);
      }
      
      results.details.push(recipientResult);
    }
    
    // Save notification record in Firestore
    try {
      await admin.firestore().collection('notification_history').add({
        sentBy: adminId || 'system',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        recipientType,
        recipientRole,
        recipientIds: targetUserIds,
        title: notificationTitle,
        body: notificationBody,
        additionalData: notificationData || {},
        emailRequested: sendEmail || false,
        results: {
          totalRecipients: results.totalRecipients,
          fcmSuccess: results.fcmSuccess,
          fcmFailed: results.fcmFailed,
          emailsSent: results.emailsSent,
          emailsFailed: results.emailsFailed
        }
      });
    } catch (error) {
      console.error('Error saving notification history:', error);
    }
    
    console.log('Notification sending completed:', {
      totalRecipients: results.totalRecipients,
      fcmSuccess: results.fcmSuccess,
      fcmFailed: results.fcmFailed,
      emailsSent: results.emailsSent,
      emailsFailed: results.emailsFailed
    });
    
    return {
      success: true,
      message: `Notifications sent to ${results.totalRecipients} recipients`,
      results
    };
    
  } catch (error) {
    console.error('Error in sendAdminNotification:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to send notifications: ${error.message}`);
  }
});

// ===== ENROLLMENT NOTIFICATION EMAIL TEMPLATE =====

/**
 * Send enrollment notification email to admins
 */
const sendEnrollmentNotificationEmail = async (
  adminEmail,
  adminName,
  enrollmentData
) => {
  try {
    const transporter = createTransporter();

    // Format enrollment details
    const subject = enrollmentData.subject || 'Not specified';
    const specificLanguage = enrollmentData.specificLanguage ? ` (${enrollmentData.specificLanguage})` : '';
    const gradeLevel = enrollmentData.gradeLevel || 'Not specified';
    const email = enrollmentData.contact?.email || 'Not provided';
    const phone = enrollmentData.contact?.phone || 'Not provided';
    const country = enrollmentData.contact?.country?.name || 'Not specified';
    const preferredDays = enrollmentData.preferences?.days?.join(', ') || 'Not specified';
    const preferredTimeSlots = enrollmentData.preferences?.timeSlots?.join(', ') || 'Not specified';
    const timeZone = enrollmentData.preferences?.timeZone || 'Not specified';
    
    // Handle Firestore Timestamp for submittedAt
    let submittedAt = 'Just now';
    if (enrollmentData.metadata?.submittedAt) {
      const timestamp = enrollmentData.metadata.submittedAt;
      // Check if it's a Firestore Timestamp (has toDate method)
      if (timestamp && typeof timestamp.toDate === 'function') {
        submittedAt = timestamp.toDate().toLocaleString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        });
      } else if (timestamp && timestamp.seconds) {
        // Handle Timestamp object with seconds property
        submittedAt = new Date(timestamp.seconds * 1000).toLocaleString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        });
      }
    }

    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: adminEmail,
      subject: `🎓 New Enrollment Application: ${subject}${specificLanguage}`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>New Enrollment Application</title>
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
            background: linear-gradient(135deg, #10B981 0%, #059669 100%);
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
          .enrollment-card {
            background-color: #f0fdf4;
            border-left: 4px solid #10B981;
            padding: 20px;
            margin: 16px 0;
            border-radius: 4px;
          }
          .info-row {
            display: flex;
            justify-content: space-between;
            margin: 8px 0;
            padding: 8px 0;
            border-bottom: 1px solid #e5e7eb;
          }
          .info-label {
            font-weight: bold;
            color: #374151;
            min-width: 150px;
          }
          .info-value {
            color: #6b7280;
            text-align: right;
            flex: 1;
          }
          .btn {
            display: inline-block;
            background-color: #10B981;
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
            background-color: #f9fafb;
          }
          .highlight {
            background-color: #fef3c7;
            padding: 2px 6px;
            border-radius: 3px;
            font-weight: 600;
            color: #92400e;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🎓 New Enrollment Application</h1>
            <p style="margin: 8px 0 0 0; opacity: 0.9;">Alluwal Education Hub</p>
          </div>
          <div class="content">
            <p>Hi ${adminName},</p>
            <p>A new enrollment application has been submitted and requires your review.</p>

            <div class="enrollment-card">
              <h2 style="margin-top: 0; color: #10B981; font-size: 20px;">Application Details</h2>
              
              <div class="info-row">
                <span class="info-label">Subject:</span>
                <span class="info-value"><span class="highlight">${subject}${specificLanguage}</span></span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Grade Level:</span>
                <span class="info-value">${gradeLevel}</span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Contact Email:</span>
                <span class="info-value">${email}</span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Phone Number:</span>
                <span class="info-value">${phone}</span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Country:</span>
                <span class="info-value">${country}</span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Preferred Days:</span>
                <span class="info-value">${preferredDays}</span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Preferred Time Slots:</span>
                <span class="info-value">${preferredTimeSlots}</span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Timezone:</span>
                <span class="info-value">${timeZone}</span>
              </div>
              
              <div class="info-row" style="border-bottom: none;">
                <span class="info-label">Submitted:</span>
                <span class="info-value">${submittedAt}</span>
              </div>
            </div>

            <p style="margin-top: 24px;">Please login to the Alluwal Education Hub admin dashboard to review and process this enrollment application.</p>

            <p style="margin-top: 24px;">Best regards,<br/>Alluwal Education Hub Team</p>
          </div>
          <div class="footer">
            This is an automated notification. Please do not reply to this email.
          </div>
        </div>
      </body>
      </html>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`Enrollment notification email sent to ${adminEmail} for subject: ${subject}`);
    return true;
  } catch (error) {
    console.error('Error sending enrollment notification email:', error);
    return false;
  }
};

// ===== FIRESTORE TRIGGER: NEW ENROLLMENT NOTIFICATION =====

/**
 * Firestore trigger that sends email notifications to all admins
 * when a new enrollment application is created
 */
exports.onEnrollmentCreated = onDocumentCreated('enrollments/{enrollmentId}', async (event) => {
  try {
    const enrollmentData = event.data.data();
    const enrollmentId = event.params.enrollmentId;
    
    console.log(`🎓 New enrollment created: ${enrollmentId}`);
    console.log(`Subject: ${enrollmentData.subject || 'N/A'}`);
    
    // Get notification recipients
    const recipients = await getNotificationRecipients();
    
    if (recipients.length === 0) {
      console.log('⚠️ No notification recipients found - skipping email notifications');
      return;
    }
    
    let emailsSent = 0;
    let emailsFailed = 0;
    
    // Send email notification to each recipient
    for (const recipient of recipients) {
      try {
        const emailSent = await sendEnrollmentNotificationEmail(
          recipient.email,
          recipient.name,
          enrollmentData
        );
        
        if (emailSent) {
          emailsSent++;
          console.log(`✅ Enrollment notification email sent to ${recipient.name} (${recipient.email})`);
        } else {
          emailsFailed++;
          console.log(`❌ Failed to send email to ${recipient.name} (${recipient.email})`);
        }
      } catch (error) {
        emailsFailed++;
        console.error(`Error sending email to ${recipient.email}:`, error);
      }
    }
    
    console.log(`✅ Enrollment notification process completed:`);
    console.log(`   - Total recipients: ${recipients.length}`);
    console.log(`   - Emails sent: ${emailsSent}`);
    console.log(`   - Emails failed: ${emailsFailed}`);
    
  } catch (error) {
    console.error('Error in onEnrollmentCreated:', error);
    // Don't throw - we don't want to fail the enrollment creation if email fails
  }
});

// ===== CONTACT MESSAGE NOTIFICATION =====

/**
 * Send contact message notification email to admins
 */
const sendContactMessageNotificationEmail = async (
  adminEmail,
  adminName,
  messageData
) => {
  try {
    const transporter = createTransporter();

    const name = messageData.name || 'Not specified';
    const email = messageData.email || 'Not provided';
    const message = messageData.message || 'No message content';
    const submittedAt = messageData.submittedAt 
      ? new Date(messageData.submittedAt.toDate()).toLocaleString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        })
      : 'Just now';

    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: adminEmail,
      subject: `📬 New Contact Message from ${name}`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>New Contact Message</title>
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
            background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%);
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
          .message-card {
            background-color: #eff6ff;
            border-left: 4px solid #3B82F6;
            padding: 20px;
            margin: 16px 0;
            border-radius: 4px;
          }
          .info-row {
            margin-bottom: 12px;
          }
          .info-label {
            font-weight: bold;
            color: #374151;
            display: block;
            margin-bottom: 4px;
          }
          .info-value {
            color: #1f2937;
          }
          .message-content {
            background-color: white;
            padding: 12px;
            border-radius: 4px;
            border: 1px solid #d1d5db;
            margin-top: 4px;
            white-space: pre-wrap;
          }
          .footer {
            text-align: center;
            font-size: 12px;
            color: #888888;
            padding: 16px;
            background-color: #f9fafb;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>📬 New Contact Message</h1>
            <p style="margin: 8px 0 0 0; opacity: 0.9;">Alluwal Education Hub</p>
          </div>
          <div class="content">
            <p>Hi ${adminName},</p>
            <p>A new message has been submitted through the contact form.</p>

            <div class="message-card">
              <div class="info-row">
                <span class="info-label">From:</span>
                <span class="info-value"><strong>${name}</strong> (${email})</span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Submitted:</span>
                <span class="info-value">${submittedAt}</span>
              </div>
              
              <div class="info-row">
                <span class="info-label">Message:</span>
                <div class="message-content">${message}</div>
              </div>
            </div>

            <p style="margin-top: 24px;">You can reply directly to the sender at <a href="mailto:${email}">${email}</a>.</p>
          </div>
          <div class="footer">
            This is an automated notification. Please do not reply to this email address directly.
          </div>
        </div>
      </body>
      </html>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`Contact message notification email sent to ${adminEmail}`);
    return true;
  } catch (error) {
    console.error('Error sending contact message notification email:', error);
    return false;
  }
};

/**
 * Firestore trigger for new contact messages
 */
exports.onContactMessageCreated = onDocumentCreated('contact_messages/{messageId}', async (event) => {
  try {
    const messageData = event.data.data();
    const messageId = event.params.messageId;
    
    console.log(`📬 New contact message created: ${messageId}`);
    
    // Get notification recipients
    const recipients = await getNotificationRecipients();
    
    if (recipients.length === 0) {
      console.log('⚠️ No notification recipients found - skipping email notifications');
      return;
    }
    
    let emailsSent = 0;
    
    // Send email notification to each recipient
    for (const recipient of recipients) {
      try {
        await sendContactMessageNotificationEmail(recipient.email, recipient.name, messageData);
        emailsSent++;
      } catch (error) {
        console.error(`Error sending email to ${recipient.email}:`, error);
      }
    }
    
    console.log(`✅ Contact message notifications sent: ${emailsSent}`);
    
  } catch (error) {
    console.error('Error in onContactMessageCreated:', error);
  }
});

// ===== TEACHER APPLICATION NOTIFICATION =====

/**
 * Send confirmation email to teacher applicant
 */
const sendTeacherApplicationConfirmationEmail = async (
  applicantEmail,
  applicantName,
  applicationData
) => {
  try {
    const transporter = createTransporter();

    const languages = Array.isArray(applicationData.languages) 
      ? applicationData.languages.join(', ') 
      : 'Not specified';
    
    const teachingProgramsArray = Array.isArray(applicationData.teaching_programs) 
      ? applicationData.teaching_programs 
      : (applicationData.teaching_programs ? [applicationData.teaching_programs] : []);
    const teachingPrograms = teachingProgramsArray.length > 0 
      ? teachingProgramsArray.map(p => {
          const programNames = {
            'english': 'English Tutoring',
            'islamic_studies': 'Islamic Studies',
            'adult_literacy': 'Adult Literacy',
            'adlam': 'AdLaM',
            'other': 'Other'
          };
          return programNames[p] || p;
        }).join(', ')
      : 'Not specified';

    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: applicantEmail,
      subject: '✅ We Received Your Teacher Application',
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Application Received</title>
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
            background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%);
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
          .success-icon {
            text-align: center;
            font-size: 48px;
            margin: 20px 0;
          }
          .info-box {
            background-color: #faf5ff;
            border-left: 4px solid #8B5CF6;
            padding: 16px;
            margin: 16px 0;
            border-radius: 4px;
          }
          .footer {
            text-align: center;
            font-size: 12px;
            color: #888888;
            padding: 16px;
            background-color: #f9fafb;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>✅ Application Received</h1>
            <p style="margin: 8px 0 0 0; opacity: 0.9;">Alluwal Education Hub</p>
          </div>
          <div class="content">
            <div class="success-icon">🎓</div>
            <p>Dear ${applicantName},</p>
            <p>Thank you for your interest in joining the Alluwal Education Hub team! We have successfully received your teacher application.</p>

            <div class="info-box">
              <p style="margin: 0; font-weight: bold; color: #7c3aed;">Application Summary:</p>
              <p style="margin: 8px 0 0 0;"><strong>Teaching Programs:</strong> ${teachingPrograms}</p>
              <p style="margin: 8px 0 0 0;"><strong>Languages:</strong> ${languages}</p>
            </div>

            <p>Our team will carefully review your application and get back to you within 5-7 business days. We appreciate your patience during this process.</p>

            <p>If you have any questions or need to update your application, please don't hesitate to contact us at <a href="mailto:support@alluwaleducationhub.org">support@alluwaleducationhub.org</a>.</p>

            <p style="margin-top: 24px;">Best regards,<br/>The Alluwal Education Hub Team</p>
          </div>
          <div class="footer">
            This is an automated confirmation email. Please do not reply to this email address directly.
          </div>
        </div>
      </body>
      </html>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`Teacher application confirmation email sent to ${applicantEmail}`);
    return true;
  } catch (error) {
    console.error('Error sending teacher application confirmation email:', error);
    return false;
  }
};

/**
 * Send teacher application notification email to admins
 */
const sendTeacherApplicationNotificationEmail = async (
  adminEmail,
  adminName,
  applicationData
) => {
  try {
    const transporter = createTransporter();

    const firstName = applicationData.first_name || 'Not specified';
    const lastName = applicationData.last_name || 'Not specified';
    const fullName = `${firstName} ${lastName}`;
    const email = applicationData.email || 'Not provided';
    const phone = applicationData.phone_number || 'Not provided';
    const countryCode = applicationData.country_code || '';
    const currentLocation = applicationData.current_location || applicationData.country_of_origin || 'Not specified';
    const gender = applicationData.gender || 'Not specified';
    const nationality = applicationData.nationality || 'Not specified';
    const currentStatus = applicationData.current_status || 'Not specified';
    const teachingProgramsArray = Array.isArray(applicationData.teaching_programs) 
      ? applicationData.teaching_programs 
      : (applicationData.teaching_programs ? [applicationData.teaching_programs] : []);
    const teachingPrograms = teachingProgramsArray.join(', ');
    const englishSubjects = applicationData.english_subjects 
      ? (Array.isArray(applicationData.english_subjects) ? applicationData.english_subjects.join(', ') : applicationData.english_subjects)
      : 'N/A';
    const languages = Array.isArray(applicationData.languages) 
      ? applicationData.languages.join(', ') 
      : 'Not specified';
    const timeDiscipline = applicationData.time_discipline || 'Not specified';
    const scheduleBalance = applicationData.schedule_balance || 'Not specified';
    const interestReason = applicationData.interest_reason || 'Not provided';
    const electricityAccess = applicationData.electricity_access || 'Not specified';
    const teachingComfort = applicationData.teaching_comfort || 'Not specified';
    const studentInteractionGuarantee = applicationData.student_interaction_guarantee || 'Not specified';
    const availabilityStart = applicationData.availability_start || 'Not specified';
    const teachingDevice = applicationData.teaching_device || 'Not specified';
    const internetAccess = applicationData.internet_access || 'Not specified';
    const scenarioNonParticipating = applicationData.scenario_non_participating_student || 'Not provided';
    const feedbackOnForm = applicationData.feedback_on_form || 'None';
    
    // Islamic Studies specific
    const tajwidLevel = applicationData.tajwid_level || 'N/A';
    const quranMemorization = applicationData.quran_memorization || 'N/A';
    const arabicProficiency = applicationData.arabic_proficiency || 'N/A';
    
    // Handle Firestore Timestamp for submittedAt
    let submittedAt = 'Just now';
    if (applicationData.submitted_at) {
      const timestamp = applicationData.submitted_at;
      if (timestamp && typeof timestamp.toDate === 'function') {
        submittedAt = timestamp.toDate().toLocaleString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        });
      } else if (timestamp && timestamp.seconds) {
        submittedAt = new Date(timestamp.seconds * 1000).toLocaleString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        });
      }
    }

    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: adminEmail,
      subject: `👨‍🏫 New Teacher Application from ${fullName}`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>New Teacher Application</title>
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
            background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%);
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
          .application-card {
            background-color: #faf5ff;
            border-left: 4px solid #8B5CF6;
            padding: 20px;
            margin: 16px 0;
            border-radius: 4px;
          }
          .info-row {
            margin-bottom: 12px;
            padding-bottom: 8px;
            border-bottom: 1px solid #e5e7eb;
          }
          .info-row:last-child {
            border-bottom: none;
            margin-bottom: 0;
            padding-bottom: 0;
          }
          .info-label {
            font-weight: bold;
            color: #374151;
            display: block;
            margin-bottom: 4px;
          }
          .info-value {
            color: #1f2937;
          }
          .languages-badge {
            display: inline-block;
            background-color: #ede9fe;
            color: #7c3aed;
            padding: 4px 8px;
            border-radius: 4px;
            margin: 2px;
            font-size: 12px;
          }
          .footer {
            text-align: center;
            font-size: 12px;
            color: #888888;
            padding: 16px;
            background-color: #f9fafb;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>👨‍🏫 New Teacher Application</h1>
            <p style="margin: 8px 0 0 0; opacity: 0.9;">Alluwal Education Hub</p>
          </div>
          <div class="content">
            <p>Hi ${adminName},</p>
            <p>A new teacher application has been submitted and requires your review.</p>

            <div class="application-card">
              <h3 style="margin-top: 0; color: #8B5CF6; font-size: 18px;">Personal Information</h3>
              <div class="info-row">
                <span class="info-label">Applicant Name:</span>
                <span class="info-value"><strong>${fullName}</strong></span>
              </div>
              <div class="info-row">
                <span class="info-label">Email:</span>
                <span class="info-value">${email}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Phone (WhatsApp):</span>
                <span class="info-value">${phone} ${countryCode ? `(${countryCode})` : ''}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Current Location:</span>
                <span class="info-value">${currentLocation}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Gender:</span>
                <span class="info-value">${gender}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Nationality:</span>
                <span class="info-value">${nationality}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Current Status:</span>
                <span class="info-value">${currentStatus}</span>
              </div>
            </div>

            <div class="application-card" style="margin-top: 16px;">
              <h3 style="margin-top: 0; color: #8B5CF6; font-size: 18px;">Teaching Program & Qualifications</h3>
              <div class="info-row">
                <span class="info-label">Teaching Programs:</span>
                <span class="info-value"><strong>${teachingPrograms}</strong></span>
              </div>
              ${teachingProgramsArray.includes('islamic_studies') ? `
              <div class="info-row">
                <span class="info-label">Tajwid Level:</span>
                <span class="info-value">${tajwidLevel}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Quran Memorization:</span>
                <span class="info-value">${quranMemorization}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Arabic Proficiency:</span>
                <span class="info-value">${arabicProficiency}</span>
              </div>
              ` : ''}
              ${teachingProgramsArray.includes('english') ? `
              <div class="info-row">
                <span class="info-label">English Subjects:</span>
                <span class="info-value">${englishSubjects}</span>
              </div>
              ` : ''}
              <div class="info-row">
                <span class="info-label">Languages Spoken:</span>
                <span class="info-value">${languages}</span>
              </div>
            </div>

            <div class="application-card" style="margin-top: 16px;">
              <h3 style="margin-top: 0; color: #8B5CF6; font-size: 18px;">Commitment & Experience</h3>
              <div class="info-row">
                <span class="info-label">Time Discipline:</span>
                <span class="info-value">${timeDiscipline}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Schedule Balance:</span>
                <span class="info-value">${scheduleBalance}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Interest Reason:</span>
                <div class="info-value" style="margin-top: 4px; white-space: pre-wrap;">${interestReason}</div>
              </div>
              <div class="info-row">
                <span class="info-label">Electricity Access:</span>
                <span class="info-value">${electricityAccess}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Teaching Comfort:</span>
                <span class="info-value">${teachingComfort}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Student Interaction Guarantee:</span>
                <span class="info-value">${studentInteractionGuarantee}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Availability to Start:</span>
                <span class="info-value">${availabilityStart}</span>
              </div>
            </div>

            <div class="application-card" style="margin-top: 16px;">
              <h3 style="margin-top: 0; color: #8B5CF6; font-size: 18px;">Technical Requirements</h3>
              <div class="info-row">
                <span class="info-label">Teaching Device:</span>
                <span class="info-value">${teachingDevice}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Internet Access:</span>
                <span class="info-value">${internetAccess}</span>
              </div>
            </div>

            <div class="application-card" style="margin-top: 16px;">
              <h3 style="margin-top: 0; color: #8B5CF6; font-size: 18px;">Teaching Scenario</h3>
              <div class="info-row">
                <span class="info-label">Scenario Response:</span>
                <div class="info-value" style="margin-top: 4px; white-space: pre-wrap;">${scenarioNonParticipating}</div>
              </div>
            </div>

            <div class="application-card" style="margin-top: 16px;">
              <h3 style="margin-top: 0; color: #8B5CF6; font-size: 18px;">Additional Information</h3>
              <div class="info-row">
                <span class="info-label">Feedback on Form:</span>
                <div class="info-value" style="margin-top: 4px;">${feedbackOnForm}</div>
              </div>
              <div class="info-row">
                <span class="info-label">Submitted:</span>
                <span class="info-value">${submittedAt}</span>
              </div>
            </div>

            <p style="margin-top: 24px;">Please login to the Alluwal Education Hub admin dashboard to review this teacher application.</p>
          </div>
          <div class="footer">
            This is an automated notification. Please do not reply to this email address directly.
          </div>
        </div>
      </body>
      </html>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`Teacher application notification email sent to ${adminEmail}`);
    return true;
  } catch (error) {
    console.error('Error sending teacher application notification email:', error);
    return false;
  }
};

/**
 * Firestore trigger for new teacher applications
 */
exports.onTeacherApplicationCreated = onDocumentCreated('teacher_applications/{applicationId}', async (event) => {
  try {
    const applicationData = event.data.data();
    const applicationId = event.params.applicationId;
    
    console.log(`👨‍🏫 New teacher application created: ${applicationId}`);
    
    // Extract applicant information
    const applicantEmail = applicationData.email;
    const applicantFirstName = applicationData.first_name || '';
    const applicantLastName = applicationData.last_name || '';
    const applicantName = `${applicantFirstName} ${applicantLastName}`.trim() || 'Applicant';
    
    // Send confirmation email to applicant
    if (applicantEmail) {
      try {
        const confirmationSent = await sendTeacherApplicationConfirmationEmail(
          applicantEmail,
          applicantName,
          applicationData
        );
        if (confirmationSent) {
          console.log(`✅ Confirmation email sent to applicant: ${applicantEmail}`);
        } else {
          console.log(`❌ Failed to send confirmation email to applicant: ${applicantEmail}`);
        }
      } catch (error) {
        console.error(`Error sending confirmation email to applicant:`, error);
      }
    } else {
      console.log(`⚠️ No applicant email found - skipping confirmation email`);
    }
    
    // Get notification recipients
    const recipients = await getNotificationRecipients();
    
    let emailsSent = 0;
    let emailsFailed = 0;
    
    if (recipients.length === 0) {
      console.log('⚠️ No notification recipients found - skipping admin email notifications');
    } else {
      console.log(`Found ${recipients.length} recipient(s) to notify`);
      
      // Send email notification to each recipient
      for (const recipient of recipients) {
        try {
          const emailSent = await sendTeacherApplicationNotificationEmail(
            recipient.email,
            recipient.name,
            applicationData
          );
          
          if (emailSent) {
            emailsSent++;
            console.log(`✅ Teacher application notification email sent to ${recipient.name} (${recipient.email})`);
          } else {
            emailsFailed++;
            console.log(`❌ Failed to send email to ${recipient.name} (${recipient.email})`);
          }
        } catch (error) {
          emailsFailed++;
          console.error(`Error sending email to ${recipient.email}:`, error);
        }
      }
    }
    
    console.log(`✅ Teacher application notification process completed:`);
    console.log(`   - Applicant confirmation: ${applicantEmail ? 'sent' : 'skipped'}`);
    console.log(`   - Total recipients: ${recipients.length}`);
    console.log(`   - Admin emails sent: ${emailsSent}`);
    console.log(`   - Admin emails failed: ${emailsFailed}`);
    
  } catch (error) {
    console.error('Error in onTeacherApplicationCreated:', error);
  }
});