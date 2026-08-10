const nodemailer = require('nodemailer');

/**
 * Outbound mail transport.
 *
 * Sending goes through Resend, not Hostinger. Hostinger is shared hosting: its
 * outbound scanner repeatedly blocked billing@ (535 AUTH failures) even at ~65
 * emails per 14 days, most likely on content — HTML, payment links, and a PDF
 * attached to every invoice. Volume was never the issue, so spreading load over
 * more Hostinger mailboxes would not have helped; all mailboxes there share one
 * server reputation.
 *
 * Receiving is unchanged — MX still points at Hostinger, the inboxes still work.
 * Only the sending path moved.
 *
 * Set RESEND_API_KEY in functions/.env to enable it. Without that key this falls
 * back to the old Hostinger SMTP path, so a deploy is never a flag day and
 * rolling back is just unsetting the variable.
 */

const MAILBOXES = {
  support: {
    user: 'support@alluwaleducationhub.org',
    passwordEnvVar: 'SUPPORT_EMAIL_PASSWORD',
  },
  billing: {
    user: 'billing@alluwaleducationhub.org',
    passwordEnvVar: 'BILLING_EMAIL_PASSWORD',
  },
};

const RESEND_HOST = 'smtp.resend.com';
const RESEND_PORT = 465;
/** Resend's SMTP username is the literal string "resend"; the API key is the password. */
const RESEND_SMTP_USER = 'resend';

const getResendApiKey = () => (process.env.RESEND_API_KEY || '').trim();

const isResendConfigured = () => Boolean(getResendApiKey());

const _hostingerTransport = (config) => {
  const pass = process.env[config.passwordEnvVar];
  if (!pass) {
    throw new Error(
      `Missing ${config.passwordEnvVar} in functions/.env — cannot send mail from ${config.user}`
    );
  }
  return nodemailer.createTransport({
    host: 'smtp.hostinger.com',
    port: 465,
    secure: true,
    auth: {
      user: config.user,
      pass,
    },
  });
};

const _resendTransport = () =>
  nodemailer.createTransport({
    host: RESEND_HOST,
    port: RESEND_PORT,
    secure: true,
    auth: {
      user: RESEND_SMTP_USER,
      pass: getResendApiKey(),
    },
  });

/**
 * @param {'support'|'billing'} mailbox selects the From identity. Each sender
 *   already sets its own `from:` header; this only validates the mailbox name
 *   and, on the Hostinger fallback, picks which credentials to authenticate with.
 */
const createTransporter = (mailbox = 'support') => {
  const config = MAILBOXES[mailbox];
  if (!config) {
    throw new Error(
      `Unknown mailbox "${mailbox}". Expected one of: ${Object.keys(MAILBOXES).join(', ')}`
    );
  }

  if (isResendConfigured()) {
    return _resendTransport();
  }

  return _hostingerTransport(config);
};

module.exports = {
  createTransporter,
  isResendConfigured,
  MAILBOXES,
};
