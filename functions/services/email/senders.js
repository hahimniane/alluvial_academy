const {createTransporter} = require('./transporter');

const sendPasswordResetEmail = async (email, resetLink, displayName = '') => {
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
          <h2 style="color: #2D3748; margin: 0 0 20px 0; font-size: 24px;">Hello${displayName ? ` ${displayName}` : ''},</h2>
          
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
    `,
  };

  await transporter.sendMail(mailOptions);
  return {success: true, message: `Password reset email sent to ${email}`};
};

const sendWelcomeEmail = async (email, firstName, lastName, password, userType, kiosqueCode = null) => {
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
              ${kiosqueCode ? `<p><strong>Family Code:</strong> <span style="font-family: monospace; font-size: 16px; color: #0386FF; font-weight: bold;">${kiosqueCode}</span></p>` : ''}
            </div>

            ${kiosqueCode ? `
            <div style="background-color: #ecfdf5; border: 1px solid #10b981; padding: 15px; margin: 15px 0; border-radius: 6px;">
              <h3 style="color: #065f46; margin-top: 0;">📋 Important: Save Your Family Code</h3>
              <p style="margin-bottom: 0;"><strong>${kiosqueCode}</strong> is your unique family code. Save this code for future enrollments of your children. You can use this code to link multiple students to your parent account.</p>
            </div>
            ` : ''}
            
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
    `,
  };

  await transporter.sendMail(mailOptions);
  return true;
};

const sendStudentNotificationEmail = async (parentEmail, parentName, studentData, credentials) => {
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
    `,
  };

  await transporter.sendMail(mailOptions);
  return true;
};

const sendTaskAssignmentEmail = async (
  assigneeEmail,
  assigneeName,
  taskTitle,
  taskDescription,
  dueDate,
  assignedByName
) => {
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
  return true;
};

const sendTestEmail = async ({to, subject, message}) => {
  const transporter = createTransporter();
  const recipient = to || 'hassimiou.niane@maine.edu';
  const emailSubject = subject || 'Test Email from Alluwal Academy';
  const emailMessage = message || 'This is a test email from Alluwal Academy system.';

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
    `,
  };

  await transporter.sendMail(mailOptions);
  return {
    success: true,
    message: 'Test email sent successfully',
    recipient,
    timestamp: new Date().toISOString(),
  };
};

module.exports = {
  sendPasswordResetEmail,
  sendWelcomeEmail,
  sendStudentNotificationEmail,
  sendTaskAssignmentEmail,
  sendTestEmail,
};

