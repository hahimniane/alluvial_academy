/**
 * dev-script: test-no-show-notification.js
 * Sends a FAKE no-show email + push to one admin to verify delivery.
 * Uses the same sendNoShowEmail/sendNoShowPushNotification code as production,
 * and logs who the current settings/admin config would notify.
 *
 * Usage: node dev-scripts/test-no-show-notification.js "hassimiou"
 *        (argument matches admin first/last name or e-mail, case-insensitive)
 */

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });

const { __test__ } = require('../handlers/no_show');

const db = admin.firestore();
const query = (process.argv[2] || 'hassimiou').toLowerCase();

async function findAdminUser() {
  const [primary, secondary, adminTeachers] = await Promise.all([
    db.collection('users').where('user_type', '==', 'admin').get(),
    db.collection('users').where('secondary_roles', 'array-contains', 'admin').get(),
    db.collection('users').where('is_admin_teacher', '==', true).get(),
  ]);
  const byId = new Map();
  [primary, secondary, adminTeachers].forEach((snap) =>
    snap.docs.forEach((doc) => byId.set(doc.id, doc.data()))
  );
  for (const [id, data] of byId) {
    const name = `${data.first_name || ''} ${data.last_name || ''}`.toLowerCase();
    const email = (data['e-mail'] || data.email || '').toLowerCase();
    if (name.includes(query) || email.includes(query)) {
      return { id, data };
    }
  }
  console.log('Admins found:', [...byId.values()].map((d) =>
    `${d.first_name || ''} ${d.last_name || ''} <${d['e-mail'] || d.email || 'no-email'}>`));
  return null;
}

async function main() {
  const target = await findAdminUser();
  if (!target) {
    console.error(`❌ No admin matching "${query}" found (see list above).`);
    process.exit(1);
  }

  const name = `${target.data.first_name || ''} ${target.data.last_name || ''}`.trim();
  const email = target.data['e-mail'] || target.data.email;
  const tokens = [];
  if (Array.isArray(target.data.fcmTokens)) {
    target.data.fcmTokens.forEach((entry) => {
      const token = typeof entry === 'string' ? entry : entry && entry.token;
      if (token) tokens.push(token);
    });
  }
  if (target.data.fcmToken) tokens.push(target.data.fcmToken);

  console.log(`🎯 Target admin: ${name} <${email}> (uid ${target.id}), ${tokens.length} FCM token(s)`);

  const { emails, tokens: settingsTokens } = await __test__.resolveNoShowRecipients();
  console.log(`⚙️ Current settings would notify: ${emails.join(', ')} (${settingsTokens.length} tokens)`);

  const reportData = {
    reportType: 'no_show',
    shiftId: 'TEST_FAKE_SHIFT',
    shiftName: '🧪 TEST — Fake Class (please ignore)',
    reporterName: 'Notification Test Script',
    teacherName: 'Test Teacher',
    isTeacherNoShow: true,
  };

  if (email) {
    console.log('📧 Sending test email...');
    await __test__.sendNoShowEmail([email], reportData, true);
  } else {
    console.warn('⚠️ Target has no e-mail field; skipping email.');
  }

  if (tokens.length > 0) {
    console.log('📱 Sending test push notification...');
    await __test__.sendNoShowPushNotification(tokens, reportData, true);
  } else {
    console.warn('⚠️ Target has no FCM tokens; skipping push (log into the app to register one).');
  }

  console.log('✅ Done.');
  process.exit(0);
}

main().catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
