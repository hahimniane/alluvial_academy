/**
 * Create or update a minimal CTO weekly engineering report template in Firestore.
 *
 * Purpose:
 * - Keep CTO reporting separate from Zoom hosting / classroom operations forms
 * - Minimize required fields so future automation can summarize GitHub work cleanly
 *
 * Usage:
 *   node scripts/create_cto_weekly_engineering_template.js
 *
 * Notes:
 * - Uses a fixed document ID for stable automation targeting
 * - Does NOT touch global weekly template config
 * - Safe to rerun; it will update the existing template and bump the version
 */

const path = require('path');
const fs = require('fs');
let admin;

try {
  admin = require('firebase-admin');
} catch (_) {
  admin = require(path.join('..', 'functions', 'node_modules', 'firebase-admin'));
}

const TEMPLATE_ID = 'cto_weekly_engineering_report';
const TEMPLATE_NAME = 'CTO Weekly Engineering Report';

function initFirebase() {
  if (admin.apps.length) return;

  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'alluwal-academy',
    });
    console.log('✅ Initialized Firebase Admin with service account key');
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId:
      process.env.GCLOUD_PROJECT ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      'alluwal-academy',
  });
  console.log('✅ Initialized Firebase Admin with application default credentials');
}

function buildField(id, label, type, order, extra = {}) {
  return {
    id,
    label,
    type,
    required: extra.required === true,
    order,
    ...(extra.placeholder ? {placeholder: extra.placeholder} : {}),
    ...(extra.options ? {options: extra.options} : {}),
    ...(extra.validation ? {validation: extra.validation} : {}),
  };
}

async function createOrUpdateTemplate() {
  initFirebase();
  const db = admin.firestore();
  const docRef = db.collection('form_templates').doc(TEMPLATE_ID);
  const existing = await docRef.get();
  const existingData = existing.data() || {};
  const nextVersion =
    typeof existingData.version === 'number' ? existingData.version + 1 : 1;

  const payload = {
    name: TEMPLATE_NAME,
    description:
      'Short weekly software work summary for CTO updates. Focus on what was worked on, not hours or activity counts.',
    frequency: 'weekly',
    category: 'administrative',
    version: nextVersion,
    allowedRoles: ['admin', 'super_admin'],
    themeColor: '#0F766E',
    fields: {
      report_date: buildField('report_date', 'Week ending date', 'date', 1, {
        required: true,
      }),
      reporter_name: buildField('reporter_name', 'Name', 'text', 2, {
        required: true,
        placeholder: 'e.g. Hassimiou Niane',
      }),
      work_summary: buildField(
        'work_summary',
        'What was worked on this week?',
        'long_text',
        3,
        {
          required: true,
          placeholder:
            'Keep it high level. Focus on the main software work completed or in progress.',
        },
      ),
      follow_up: buildField(
        'follow_up',
        'Anything to note for follow-up?',
        'text',
        4,
        {
          required: false,
          placeholder:
            'Optional blockers, next focus, or anything leadership should know.',
        },
      ),
    },
    autoFillRules: [],
    isActive: true,
    createdBy: 'scripts/create_cto_weekly_engineering_template.js',
    createdAt:
      existing.exists && existingData.createdAt
        ? existingData.createdAt
        : admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await docRef.set(payload, {merge: false});

  console.log(existing.exists ? '✅ Updated template' : '✅ Created template');
  console.log(`- id: ${TEMPLATE_ID}`);
  console.log(`- name: ${TEMPLATE_NAME}`);
  console.log(`- version: ${nextVersion}`);
  console.log('- frequency: weekly');
  console.log('- allowedRoles: admin, super_admin');
  console.log('- fields: report_date, reporter_name, work_summary, follow_up');
  console.log('- global weekly template config unchanged');
}

createOrUpdateTemplate().catch((error) => {
  console.error('❌ Failed to create/update CTO weekly engineering template');
  console.error(error);
  process.exit(1);
});
