const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {createTransporter} = require('../services/email/transporter');
const {
  sendPasswordResetEmail,
  sendWelcomeEmail,
  sendTestEmail,
} = require('../services/email/senders');

const sendWelcomeEmailCallable = async (data) => {
  console.log('--- WELCOME EMAIL FUNCTION ---');

  try {
    const {email, firstName, lastName, role} = data.data || {};

    if (!email || !firstName) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: email and firstName are required.'
      );
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
              <h2>Hello ${firstName}${lastName ? ` ${lastName}` : ''}! 👋</h2>
              <p>We're excited to have you join the Alluwal Education Hub team${
                role ? ` as a ${role}` : ''
              }. Your account has been set up and you're ready to get started!</p>
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
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`Welcome email sent successfully to ${email}`);

    return {success: true, message: `Welcome email sent to ${email}`};
  } catch (error) {
    console.error('Error sending welcome email:', error);
    throw new functions.https.HttpsError('internal', `Failed to send welcome email: ${error.message}`);
  }
};

const sendCustomPasswordResetEmail = async (data) => {
  console.log('--- CUSTOM PASSWORD RESET EMAIL ---');
  console.log('Data type:', typeof data);
  console.log('Data keys:', data ? Object.keys(data) : 'null');

  try {
    if (!data || typeof data !== 'object') {
      console.error('Invalid data received:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Data must be an object');
    }

    const requestData = data.data || data;
    console.log('RequestData type:', typeof requestData);
    console.log('RequestData keys:', requestData ? Object.keys(requestData) : 'null');

    const {email, displayName} = requestData;

    console.log('Extracted fields:', {
      email: email || 'MISSING',
      displayName: displayName || 'MISSING',
    });

    if (!email || String(email).trim() === '') {
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }

    console.log(`Generating password reset link for: ${email}`);

    const resetLink = await admin.auth().generatePasswordResetLink(email);
    console.log(`Password reset link generated: ${resetLink}`);

    const result = await sendPasswordResetEmail(email, resetLink, displayName);

    console.log(`Custom password reset email sent successfully to ${email}`);
    return result;
  } catch (error) {
    console.error('Error in sendCustomPasswordResetEmail:', error);

    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'No user found with this email address');
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send password reset email: ${error.message}`
    );
  }
};

const sendTestEmailCallable = async (data) => sendTestEmail(data);

module.exports = {
  sendWelcomeEmail: sendWelcomeEmailCallable,
  sendCustomPasswordResetEmail,
  sendTestEmail: sendTestEmailCallable,
};

