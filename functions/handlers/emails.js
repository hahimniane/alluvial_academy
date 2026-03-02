const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {
  sendPasswordResetEmail,
  sendTestEmail,
} = require('../services/email/senders');

const sendWelcomeEmailCallable = async () => {
  throw new functions.https.HttpsError(
    'failed-precondition',
    'sendWelcomeEmail callable is deprecated. Welcome emails are sent automatically by user creation functions.'
  );
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
