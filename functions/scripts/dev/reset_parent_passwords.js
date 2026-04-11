#!/usr/bin/env node
'use strict';

/**
 * One-time script: Reset all parent passwords to 123456 and send notification email.
 *
 * Usage:
 *   DRY RUN (default, no changes):
 *     node functions/scripts/dev/reset_parent_passwords.js
 *
 *   LIVE RUN (resets passwords + sends emails):
 *     node functions/scripts/dev/reset_parent_passwords.js --live
 *
 * Run from project root. Requires serviceAccountKey.json in functions/.
 */

const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// ---------------------------------------------------------------------------
// Firebase init
// ---------------------------------------------------------------------------
try {
  const serviceAccount = require('../../serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} catch (e) {
  try {
    admin.initializeApp({ projectId: 'alluwal-academy' });
  } catch (err) {
    console.error('Failed to initialize Firebase:', err.message);
    process.exit(1);
  }
}

const db = admin.firestore();
const NEW_PASSWORD = '123456';
const IS_LIVE = process.argv.includes('--live');

// ---------------------------------------------------------------------------
// Email transporter (same config as production)
// ---------------------------------------------------------------------------
const createTransporter = () =>
  nodemailer.createTransport({
    host: 'smtp.hostinger.com',
    port: 465,
    secure: true,
    auth: {
      user: 'support@alluwaleducationhub.org',
      pass: 'Kilopatra2025.',
    },
  });

// ---------------------------------------------------------------------------
// Email HTML builder
// ---------------------------------------------------------------------------
const buildEmailHtml = (displayName, email) => `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Password Update - Alluwal Academy</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
    <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 700;">Alluwal Academy</h1>
    <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">Parent Account Update</p>
  </div>

  <div style="background: #ffffff; padding: 40px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
    <h2 style="color: #2D3748; margin: 0 0 20px 0; font-size: 24px;">Assalamu Alaikum${displayName ? ` ${displayName}` : ''},</h2>

    <p style="margin: 0 0 20px 0; font-size: 16px; color: #4A5568;">
      Your parent account password has been reset by the administration. Please use the credentials below to log in to your account.
    </p>

    <div style="background: #F7FAFC; padding: 20px; border-left: 4px solid #0386FF; border-radius: 4px; margin: 25px 0;">
      <h3 style="color: #2D3748; margin: 0 0 12px 0; font-size: 18px;">Your Login Credentials</h3>
      <p style="margin: 5px 0;"><strong>Email:</strong> ${email}</p>
      <p style="margin: 5px 0;"><strong>Temporary Password:</strong> <span style="font-family: monospace; font-size: 16px; color: #e53e3e; font-weight: bold;">${NEW_PASSWORD}</span></p>
    </div>

    <div style="background: #FFF5F5; border: 1px solid #FEB2B2; padding: 15px; border-radius: 8px; margin: 25px 0;">
      <h3 style="color: #C53030; margin: 0 0 10px 0; font-size: 16px;">Important Security Notice</h3>
      <ul style="margin: 0; padding-left: 20px; color: #4A5568;">
        <li>Please change your password immediately after logging in</li>
        <li>Do not share your credentials with anyone</li>
      </ul>
    </div>

    <div style="background: #EBF8FF; padding: 20px; border-radius: 8px; margin: 25px 0;">
      <h3 style="color: #2B6CB0; margin: 0 0 10px 0; font-size: 16px;">What You Can Do as a Parent</h3>
      <ul style="margin: 0; padding-left: 20px; color: #4A5568;">
        <li><strong>Join your children's live classes</strong> — watch and listen to lessons in real time</li>
        <li><strong>Track your children's progress</strong> — view detailed analytics, attendance reports, and performance stats</li>
        <li><strong>Watch class recordings</strong> — replay any session your child attended</li>
        <li><strong>View class schedules</strong> — see upcoming classes for all your children</li>
        <li>Submit forms and manage your profile</li>
      </ul>
    </div>

    <div style="background: #F0FFF4; padding: 20px; border-radius: 8px; margin: 25px 0;">
      <h3 style="color: #276749; margin: 0 0 12px 0; font-size: 16px;">How to Access Your Account</h3>
      <p style="margin: 0 0 15px 0; font-size: 15px; color: #4A5568;">You can log in using our website or download the mobile app:</p>
      <div style="text-align: center; margin-bottom: 15px;">
        <a href="https://alluwaleducationhub.org" style="display: inline-block; background: #0386FF; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 15px;">Open Website</a>
      </div>
      <div style="text-align: center;">
        <a href="https://apps.apple.com/us/app/alluwal-education/id6754095805" style="display: inline-block; margin-right: 10px;">
          <img src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg" alt="Download on the App Store" height="40">
        </a>
        <a href="https://play.google.com/store/apps/details?id=org.alluvaleducationhub.academy" style="display: inline-block;">
          <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" alt="Get it on Google Play" height="40">
        </a>
      </div>
    </div>

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
</html>`;

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  console.log('='.repeat(60));
  console.log(IS_LIVE ? '  LIVE RUN — passwords WILL be changed, emails WILL be sent' : '  DRY RUN — no changes will be made (pass --live to execute)');
  console.log('='.repeat(60));
  console.log();

  // 1. Fetch all parents
  const parentsSnap = await db.collection('users').where('user_type', '==', 'parent').get();

  if (parentsSnap.empty) {
    console.log('No parents found in the database.');
    process.exit(0);
  }

  console.log(`Found ${parentsSnap.size} parent(s).\n`);

  const results = {
    passwordChanged: [],
    emailSent: [],
    passwordFailed: [],
    emailFailed: [],
    skippedNoEmail: [],
    skippedNoAuth: [],
  };

  let transporter = null;
  if (IS_LIVE) {
    transporter = createTransporter();
    // Verify SMTP connection before starting
    try {
      await transporter.verify();
      console.log('SMTP connection verified.\n');
    } catch (smtpErr) {
      console.error('SMTP connection FAILED. Aborting to prevent password changes without email delivery.');
      console.error(smtpErr);
      process.exit(1);
    }
  }

  for (const doc of parentsSnap.docs) {
    const data = doc.data();
    const uid = doc.id;
    const firstName = (data.first_name || data.firstName || '').trim();
    const lastName = (data.last_name || data.lastName || '').trim();
    const displayName = [firstName, lastName].filter(Boolean).join(' ') || 'Parent';
    const email = (data['e-mail'] || data.email || '').trim();

    console.log(`--- ${displayName} (UID: ${uid}, email: ${email || 'NONE'}) ---`);

    if (!email) {
      console.log('  SKIP: no email address on file.\n');
      results.skippedNoEmail.push({ uid, displayName });
      continue;
    }

    // -----------------------------------------------------------------------
    // Step 1: Reset password in Firebase Auth
    // -----------------------------------------------------------------------
    if (IS_LIVE) {
      try {
        // Check if Auth user exists
        try {
          await admin.auth().getUser(uid);
        } catch (authLookupErr) {
          if (authLookupErr.code === 'auth/user-not-found') {
            console.log('  SKIP: no Firebase Auth account for this UID.\n');
            results.skippedNoAuth.push({ uid, displayName, email });
            continue;
          }
          throw authLookupErr; // unexpected error — bubble up
        }

        await admin.auth().updateUser(uid, { password: NEW_PASSWORD });
        console.log('  Password changed.');
        results.passwordChanged.push({ uid, displayName, email });
      } catch (pwErr) {
        console.error(`  PASSWORD CHANGE FAILED: ${pwErr.message}`);
        results.passwordFailed.push({ uid, displayName, email, error: pwErr.message });
        // Do NOT send email — password was not changed
        console.log();
        continue;
      }

      // ---------------------------------------------------------------------
      // Step 2: Send email ONLY if password change succeeded
      // ---------------------------------------------------------------------
      try {
        await transporter.sendMail({
          from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
          to: email,
          subject: 'Your Alluwal Academy Password Has Been Updated',
          html: buildEmailHtml(displayName, email),
        });
        console.log('  Email sent.');
        results.emailSent.push({ uid, displayName, email });
      } catch (emailErr) {
        console.error(`  EMAIL SEND FAILED: ${emailErr.message}`);
        results.emailFailed.push({ uid, displayName, email, error: emailErr.message });
      }
    } else {
      console.log('  [dry-run] Would reset password and send email.');
    }

    console.log();
  }

  // -------------------------------------------------------------------------
  // Summary
  // -------------------------------------------------------------------------
  console.log('\n' + '='.repeat(60));
  console.log('  SUMMARY');
  console.log('='.repeat(60));
  console.log(`  Total parents found:      ${parentsSnap.size}`);
  console.log(`  Passwords changed:        ${results.passwordChanged.length}`);
  console.log(`  Emails sent:              ${results.emailSent.length}`);
  console.log(`  Skipped (no email):       ${results.skippedNoEmail.length}`);
  console.log(`  Skipped (no Auth user):   ${results.skippedNoAuth.length}`);
  console.log(`  Password change FAILED:   ${results.passwordFailed.length}`);
  console.log(`  Email send FAILED:        ${results.emailFailed.length}`);

  if (results.skippedNoEmail.length > 0) {
    console.log('\n  Parents skipped (no email on file):');
    for (const p of results.skippedNoEmail) {
      console.log(`    - ${p.displayName} (UID: ${p.uid})`);
    }
  }

  if (results.skippedNoAuth.length > 0) {
    console.log('\n  Parents skipped (no Firebase Auth account):');
    for (const p of results.skippedNoAuth) {
      console.log(`    - ${p.displayName} (UID: ${p.uid}, email: ${p.email})`);
    }
  }

  if (results.passwordFailed.length > 0) {
    console.log('\n  PASSWORD FAILURES (email was NOT sent for these):');
    for (const p of results.passwordFailed) {
      console.log(`    - ${p.displayName} (UID: ${p.uid}, email: ${p.email})`);
      console.log(`      Error: ${p.error}`);
    }
  }

  if (results.emailFailed.length > 0) {
    console.log('\n  EMAIL FAILURES (password WAS changed but email failed):');
    for (const p of results.emailFailed) {
      console.log(`    - ${p.displayName} (UID: ${p.uid}, email: ${p.email})`);
      console.log(`      Error: ${p.error}`);
    }
  }

  console.log('\n' + '='.repeat(60));

  if (!IS_LIVE) {
    console.log('\n  This was a DRY RUN. To execute for real, run:');
    console.log('  node functions/scripts/dev/reset_parent_passwords.js --live\n');
  }

  // Exit with error code if any failures occurred
  if (results.passwordFailed.length > 0 || results.emailFailed.length > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('\nFATAL ERROR:', err);
  process.exit(1);
});
