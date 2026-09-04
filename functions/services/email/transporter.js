const nodemailer = require('nodemailer');
const {partitionRecipients} = require('./undeliverable');

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
/**
 * Drop recipients that reach nobody before the message is handed to SMTP.
 *
 * Students created without an address of their own carry an alias at the
 * school's own domain, and every sender that addresses "the student" ends up
 * pointed at one. Filtering here rather than in each sender means a new sender
 * cannot reintroduce the problem, and a message whose every recipient is an
 * alias is never sent at all.
 */
const _filterUndeliverable = (transport) => {
  const sendMail = transport.sendMail.bind(transport);
  const hasRecipient = (value) => (Array.isArray(value) ? value.length > 0 : Boolean(value));

  return Object.assign(Object.create(transport), {
    sendMail: async (mailOptions = {}) => {
      const to = await partitionRecipients(mailOptions.to);
      const cc = await partitionRecipients(mailOptions.cc);
      const bcc = await partitionRecipients(mailOptions.bcc);
      const dropped = [...to.dropped, ...cc.dropped, ...bcc.dropped];

      if (dropped.length > 0) {
        console.log(`Mail: skipping ${dropped.length} address(es) with no mailbox: ${dropped.join(', ')}`);
      }

      if (!hasRecipient(to.deliverable) && !hasRecipient(cc.deliverable) && !hasRecipient(bcc.deliverable)) {
        console.log(`Mail: not sent, every recipient was an alias (${mailOptions.subject || 'no subject'})`);
        return {skipped: true, accepted: [], rejected: dropped, messageId: null};
      }

      return sendMail({
        ...mailOptions,
        to: to.deliverable,
        cc: cc.deliverable,
        bcc: bcc.deliverable,
      });
    },
  });
};

const createTransporter = (mailbox = 'support') => {
  const config = MAILBOXES[mailbox];
  if (!config) {
    throw new Error(
      `Unknown mailbox "${mailbox}". Expected one of: ${Object.keys(MAILBOXES).join(', ')}`
    );
  }

  if (isResendConfigured()) {
    return _filterUndeliverable(_resendTransport());
  }

  return _filterUndeliverable(_hostingerTransport(config));
};

module.exports = {
  createTransporter,
  isResendConfigured,
  MAILBOXES,
};
