#!/usr/bin/env node
/**
 * Diagnose audit push notifications for one teacher.
 *
 * What it does:
 * 1) Finds teacher by email
 * 2) Prints token state (fcmTokens[] + legacy fcmToken)
 * 3) Sends a test audit FCM directly via Admin SDK
 * 4) Prints per-token success/failure and common root-cause hints
 *
 * Usage:
 *   node scripts/diagnose_audit_notifications.mjs --email=aliou9716@gmail.com
 *   node scripts/diagnose_audit_notifications.mjs --email=... --yearMonth=2026-02 --status=coachSubmitted
 */

import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const out = {
    email: 'aliou9716@gmail.com',
    yearMonth: '2026-02',
    status: 'coachSubmitted',
    credentials: null,
    projectId: null,
  };
  for (const a of argv) {
    if (a.startsWith('--email=')) out.email = a.slice('--email='.length).trim();
    else if (a.startsWith('--yearMonth=')) out.yearMonth = a.slice('--yearMonth='.length).trim();
    else if (a.startsWith('--status=')) out.status = a.slice('--status='.length).trim();
    else if (a.startsWith('--credentials=')) out.credentials = a.slice('--credentials='.length).trim();
    else if (a.startsWith('--project=')) out.projectId = a.slice('--project='.length).trim();
  }
  return out;
}

function initFirebase(args) {
  if (admin.apps.length) return;
  const defaultProject =
    args.projectId ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    'alluwal-academy';

  const initWithJson = (jsonPath) => {
    const resolved = path.resolve(jsonPath);
    const serviceAccount = JSON.parse(fs.readFileSync(resolved, 'utf8'));
    process.env.GOOGLE_APPLICATION_CREDENTIALS = resolved;
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: args.projectId || serviceAccount.project_id || defaultProject,
    });
  };

  if (args.credentials && fs.existsSync(args.credentials)) {
    initWithJson(args.credentials);
    return;
  }

  const rootKey = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(rootKey)) {
    initWithJson(rootKey);
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: defaultProject,
  });
}

async function findTeacherByEmail(db, email) {
  let snap = await db.collection('users').where('e-mail', '==', email).limit(1).get();
  if (!snap.empty) return snap.docs[0];
  snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (!snap.empty) return snap.docs[0];
  return null;
}

function collectTokens(userData) {
  const tokens = [];
  const fromArray = userData?.fcmTokens;
  if (Array.isArray(fromArray)) {
    for (const t of fromArray) {
      if (t && typeof t.token === 'string' && t.token.trim()) {
        tokens.push({
          token: t.token.trim(),
          platform: t.platform || 'unknown',
          source: 'fcmTokens[]',
        });
      }
    }
  }
  if (tokens.length === 0 && typeof userData?.fcmToken === 'string' && userData.fcmToken.trim()) {
    tokens.push({
      token: userData.fcmToken.trim(),
      platform: 'legacy',
      source: 'fcmToken',
    });
  }
  return tokens;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  initFirebase(args);

  const db = admin.firestore();
  const teacherDoc = await findTeacherByEmail(db, args.email);
  if (!teacherDoc) {
    throw new Error(`Teacher not found for email: ${args.email}`);
  }

  const teacherId = teacherDoc.id;
  const userData = teacherDoc.data() || {};
  const teacherName = `${userData.first_name || ''} ${userData.last_name || ''}`.trim() || args.email;
  const tokens = collectTokens(userData);

  console.log('=== Audit Notification Diagnosis ===');
  console.log(`Project: ${admin.app().options.projectId}`);
  console.log(`Teacher: ${teacherName}`);
  console.log(`Teacher ID: ${teacherId}`);
  console.log(`Email: ${args.email}`);
  console.log(`Token entries in fcmTokens[]: ${Array.isArray(userData.fcmTokens) ? userData.fcmTokens.length : 0}`);
  console.log(`Legacy fcmToken present: ${typeof userData.fcmToken === 'string' && userData.fcmToken.trim() ? 'yes' : 'no'}`);
  console.log(`Usable tokens for send: ${tokens.length}`);

  if (tokens.length === 0) {
    console.log('\nResult: NO TOKENS => push cannot be delivered.');
    console.log('Action: open mobile app, login again, allow notifications, then retry.');
    return;
  }

  const tokenValues = tokens.map((t) => t.token);
  const messageData = {
    type: 'audit_notification',
    auditId: `diag_${teacherId}_${Date.now()}`,
    yearMonth: String(args.yearMonth),
    status: String(args.status),
    timestamp: new Date().toISOString(),
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  };

  const fcmMessage = {
    notification: {
      title: 'Audit notification diagnostic',
      body: `Test push for ${args.yearMonth} (${args.status})`,
    },
    data: messageData,
    tokens: tokenValues,
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'high_importance_channel',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };

  console.log('\nSending test multicast...');
  const resp = await admin.messaging().sendEachForMulticast(fcmMessage);
  console.log(`Success: ${resp.successCount}/${tokenValues.length}`);
  console.log(`Failure: ${resp.failureCount}/${tokenValues.length}`);

  resp.responses.forEach((r, i) => {
    const meta = tokens[i];
    if (r.success) {
      console.log(`  ✅ [${i}] ${meta.platform} (${meta.source}) messageId=${r.messageId}`);
    } else {
      const code = r.error?.code || 'unknown';
      const msg = r.error?.message || '';
      console.log(`  ❌ [${i}] ${meta.platform} (${meta.source}) code=${code} ${msg}`);
    }
  });

  if (resp.successCount === 0) {
    console.log('\nResult: send attempted but 0 delivered.');
    console.log('Most likely causes: invalid token(s), app not registered, or different Firebase project on mobile app.');
  } else {
    console.log('\nResult: FCM accepted at least one token.');
    console.log('If phone still shows nothing, check device-level notification permissions/channel settings.');
  }
}

main().catch((e) => {
  console.error('Diagnosis failed:', e.message || e);
  process.exit(1);
});

