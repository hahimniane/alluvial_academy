const {defineSecret} = require('firebase-functions/params');

const twilioAccountSid = defineSecret('TWILIO_ACCOUNT_SID');
const twilioApiKey = defineSecret('TWILIO_API_KEY');
const twilioApiSecret = defineSecret('TWILIO_API_SECRET');
const twilioPhoneNumber = defineSecret('TWILIO_PHONE_NUMBER');
const twilioWhatsappNumber = defineSecret('TWILIO_WHATSAPP_NUMBER');
const twilioWaInviteContentSid = defineSecret('TWILIO_WA_INVITE_CONTENT_SID');
const twilioWaReminderContentSid = defineSecret('TWILIO_WA_REMINDER_CONTENT_SID');

const twilioSecrets = [
  twilioAccountSid, twilioApiKey, twilioApiSecret,
  twilioPhoneNumber, twilioWhatsappNumber,
  twilioWaInviteContentSid, twilioWaReminderContentSid,
];

const APP_LINKS = {
  ios: 'https://apps.apple.com/us/app/alluwal-education/id6754095805',
  android: 'https://play.google.com/store/apps/details?id=org.alluvaleducationhub.academy',
  web: 'https://alluwaleducationhub.org',
};

const _getTwilioClient = () => {
  const accountSid = twilioAccountSid.value();
  const apiKey = twilioApiKey.value();
  const apiSecret = twilioApiSecret.value();
  if (!accountSid || !apiKey || !apiSecret) {
    throw new Error('Twilio credentials not configured');
  }
  const twilio = require('twilio');
  return twilio(apiKey, apiSecret, {accountSid});
};

const _buildInviteBody = (circleName, inviterName) => {
  const invitedBy = inviterName ? `*${inviterName}*` : 'Someone';
  return (
    `Assalamu Alaikum!\n\n` +
    `${invitedBy} has invited you to join *${circleName}* — a savings circle on Alluwal.\n\n` +
    `A savings circle (tontine) is a trusted way to save together: each member contributes a fixed amount every cycle, and one member receives the full pool. It rotates until everyone has received. No interest, no fees.\n\n` +
    `Download the app to join:\n` +
    `\u{1F34F} iOS: ${APP_LINKS.ios}\n` +
    `\u{1F916} Android: ${APP_LINKS.android}\n\n` +
    `Or visit: ${APP_LINKS.web}`
  );
};

const _buildReminderBody = (circleName, inviterName) => {
  const invitedBy = inviterName ? `from *${inviterName}* ` : '';
  return (
    `Reminder: You have a pending invitation ${invitedBy}to join *${circleName}* on Alluwal.\n\n` +
    `Download the app to accept:\n` +
    `\u{1F34F} iOS: ${APP_LINKS.ios}\n` +
    `\u{1F916} Android: ${APP_LINKS.android}\n\n` +
    `Or visit: ${APP_LINKS.web}`
  );
};

const _sendMessage = async (client, to, body, channel, contentSid, contentVariables) => {
  const waNumber = twilioWhatsappNumber.value();
  const smsNumber = twilioPhoneNumber.value();

  if (channel === 'whatsapp' && waNumber) {
    try {
      const sendParams = {
        from: `whatsapp:${waNumber}`,
        to: `whatsapp:${to}`,
      };
      if (contentSid) {
        sendParams.contentSid = contentSid;
        sendParams.contentVariables = JSON.stringify(contentVariables || {});
      } else {
        sendParams.body = body;
      }
      const msg = await client.messages.create(sendParams);
      console.log(`[WhatsApp] Sent to ${to}, SID: ${msg.sid}, template: ${contentSid ? 'yes' : 'no'}`);
      return {sent: true, channel: 'whatsapp'};
    } catch (error) {
      console.warn(`[WhatsApp] Failed for ${to}: ${error.message}. Falling back to SMS.`);
    }
  }

  if (smsNumber) {
    try {
      const msg = await client.messages.create({
        body: body.replace(/\*/g, ''),
        from: smsNumber,
        to,
      });
      console.log(`[SMS] Sent to ${to}, SID: ${msg.sid}`);
      return {sent: true, channel: 'sms'};
    } catch (error) {
      console.error(`[SMS] Failed for ${to}: ${error.message}`);
    }
  }

  return {sent: false, channel: null};
};

const sendCircleInviteMessage = async (phoneNumber, circleName, inviterName = '') => {
  const client = _getTwilioClient();
  const body = _buildInviteBody(circleName, inviterName);
  const contentSid = twilioWaInviteContentSid.value() || '';
  const contentVariables = {'1': inviterName || 'Someone', '2': circleName};
  return _sendMessage(client, phoneNumber, body, 'whatsapp', contentSid || null, contentVariables);
};

const sendCircleInviteReminderMessage = async (phoneNumber, circleName, inviterName = '') => {
  const client = _getTwilioClient();
  const body = _buildReminderBody(circleName, inviterName);
  const contentSid = twilioWaReminderContentSid.value() || '';
  const contentVariables = {'1': inviterName || 'Someone', '2': circleName};
  return _sendMessage(client, phoneNumber, body, 'whatsapp', contentSid || null, contentVariables);
};

module.exports = {
  twilioSecrets,
  sendCircleInviteMessage,
  sendCircleInviteReminderMessage,
  APP_LINKS,
};
