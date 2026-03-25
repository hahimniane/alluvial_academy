/**
 * Read-only Firestore inspection script for recent form submissions.
 *
 * Usage:
 *   node scripts/find_recent_form_submission.js "Hassimiou Niane"
 *   node scripts/find_recent_form_submission.js "Hassimiou Niane" 240
 *
 * Notes:
 * - Searches recent documents in `form_responses`
 * - Tries to resolve matching users from `users`
 * - Prints form definition presence in both `form` and `form_templates`
 * - Does not write, update, or delete anything
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

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
    projectId:
      process.env.GCLOUD_PROJECT ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      'alluwal-academy',
  });
  console.log('✅ Initialized Firebase Admin with application default credentials');
}

function normalize(value) {
  return (value || '')
    .toString()
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function formatDate(value) {
  if (!value) return 'N/A';
  if (value.toDate) {
    return value.toDate().toLocaleString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  }
  return value.toString();
}

function chunk(array, size) {
  const result = [];
  for (let i = 0; i < array.length; i += size) {
    result.push(array.slice(i, i + size));
  }
  return result;
}

async function findCandidateUsers(db, searchText) {
  const normalizedSearch = normalize(searchText);
  const tokens = normalizedSearch.split(' ').filter(Boolean);
  const usersSnapshot = await db.collection('users').get();
  const users = [];

  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    const displayName = normalize(data.displayName);
    const firstName = normalize(data.first_name || data.firstName);
    const lastName = normalize(data.last_name || data.lastName);
    const fullName = normalize(`${firstName} ${lastName}`);
    const email = normalize(data.email || data['e-mail']);

    const haystacks = [displayName, firstName, lastName, fullName, email];
    const matches =
      haystacks.includes(normalizedSearch) ||
      tokens.every((token) => haystacks.some((haystack) => haystack.includes(token)));

    if (!matches) continue;

    users.push({
      uid: doc.id,
      displayName: data.displayName || `${data.first_name || data.firstName || ''} ${data.last_name || data.lastName || ''}`.trim(),
      email: data.email || data['e-mail'] || '',
      role: data.role || '',
    });
  }

  return users;
}

function matchesSubmission(searchText, data, candidateUserIds) {
  const normalizedSearch = normalize(searchText);
  const tokens = normalizedSearch.split(' ').filter(Boolean);

  const firstName = normalize(data.firstName || data.userFirstName);
  const lastName = normalize(data.lastName || data.userLastName);
  const fullName = normalize(`${firstName} ${lastName}`);
  const userEmail = normalize(data.userEmail || data.email);
  const formName = normalize(data.formName || data.form_title || data.title);
  const responseText = normalize(
    Object.values(data.responses || {})
      .map((value) => (value == null ? '' : String(value)))
      .join(' ')
  );
  const userId = (data.userId || data.teacherId || data.submittedBy || '').toString();

  if (candidateUserIds.has(userId)) return true;

  const haystacks = [firstName, lastName, fullName, userEmail, formName, responseText];
  return (
    haystacks.includes(normalizedSearch) ||
    tokens.every((token) => haystacks.some((haystack) => haystack.includes(token)))
  );
}

async function enrichFormTargets(db, docs) {
  const uniqueIds = [...new Set(
    docs.flatMap(({ data }) =>
      [data.formId, data.templateId].filter((value) => value && value.toString().trim())
    )
  )];

  const results = {};
  for (const formId of uniqueIds) {
    const [legacyDoc, templateDoc] = await Promise.all([
      db.collection('form').doc(formId).get(),
      db.collection('form_templates').doc(formId).get(),
    ]);

    results[formId] = {
      form: legacyDoc.exists
        ? {
            exists: true,
            title: legacyDoc.data().title || legacyDoc.data().name || '',
            status: legacyDoc.data().status || '',
          }
        : { exists: false },
      form_templates: templateDoc.exists
        ? {
            exists: true,
            title: templateDoc.data().name || templateDoc.data().title || '',
            isActive: templateDoc.data().isActive,
            frequency: templateDoc.data().frequency || '',
          }
        : { exists: false },
    };
  }

  return results;
}

async function main() {
  const searchText = process.argv[2] || 'Hassimiou Niane';
  const lookbackMinutes = Number(process.argv[3] || '180');
  const lookbackMs = lookbackMinutes * 60 * 1000;

  initFirebase();
  const db = admin.firestore();

  console.log('='.repeat(100));
  console.log('RECENT FORM SUBMISSION INSPECTION');
  console.log('='.repeat(100));
  console.log(`Search text: ${searchText}`);
  console.log(`Lookback window: last ${lookbackMinutes} minutes`);
  console.log(`Started at: ${new Date().toISOString()}`);
  console.log('');

  const candidateUsers = await findCandidateUsers(db, searchText);
  const candidateUserIds = new Set(candidateUsers.map((user) => user.uid));

  if (candidateUsers.length > 0) {
    console.log('Candidate users:');
    for (const user of candidateUsers) {
      console.log(
        `  - uid=${user.uid} | name=${user.displayName || 'N/A'} | email=${user.email || 'N/A'} | role=${user.role || 'N/A'}`
      );
    }
  } else {
    console.log('Candidate users: none found in users collection');
  }
  console.log('');

  const cutoff = Date.now() - lookbackMs;
  const recentSnapshot = await db
    .collection('form_responses')
    .orderBy('submittedAt', 'desc')
    .limit(400)
    .get();

  const recentDocs = [];
  for (const doc of recentSnapshot.docs) {
    const data = doc.data();
    const submittedAt = data.submittedAt?.toDate ? data.submittedAt.toDate().getTime() : 0;
    if (submittedAt && submittedAt < cutoff) continue;
    if (!matchesSubmission(searchText, data, candidateUserIds)) continue;

    recentDocs.push({
      id: doc.id,
      data,
    });
  }

  if (recentDocs.length === 0) {
    console.log('No recent matching form_responses found in the lookback window.');
    process.exit(0);
  }

  const formTargets = await enrichFormTargets(db, recentDocs);
  const groupsByTitle = {};

  console.log(`Found ${recentDocs.length} matching form_responses:\n`);
  for (const { id, data } of recentDocs) {
    const title = data.formName || data.form_title || data.title || data.formId || 'Untitled Form';
    const normalizedTitle = normalize(title);
    groupsByTitle[normalizedTitle] = groupsByTitle[normalizedTitle] || [];
    groupsByTitle[normalizedTitle].push(id);

    const userId = data.userId || data.teacherId || data.submittedBy || 'N/A';
    const firstName = data.firstName || data.userFirstName || '';
    const lastName = data.lastName || data.userLastName || '';
    const fullName = `${firstName} ${lastName}`.trim() || 'N/A';
    const targetInfo = formTargets[data.formId] || {};

    console.log('-'.repeat(100));
    console.log(`docId:          ${id}`);
    console.log(`submittedAt:    ${formatDate(data.submittedAt)}`);
    console.log(`fullName:       ${fullName}`);
    console.log(`userEmail:      ${data.userEmail || 'N/A'}`);
    console.log(`userId:         ${userId}`);
    console.log(`formName:       ${title}`);
    console.log(`formId:         ${data.formId || 'N/A'}`);
    console.log(`templateId:     ${data.templateId || 'N/A'}`);
    console.log(`formType:       ${data.formType || 'N/A'}`);
    console.log(`yearMonth:      ${data.yearMonth || 'N/A'}`);
    console.log(`status:         ${data.status || 'N/A'}`);
    console.log(`responsesKeys:  ${Object.keys(data.responses || {}).join(', ') || 'none'}`);
    console.log(`savedIn:        form_responses/${id}`);
    console.log(
      `legacy form doc: ${targetInfo.form?.exists ? `yes (${targetInfo.form.title || 'untitled'})` : 'no'}`
    );
    console.log(
      `template doc:    ${targetInfo.form_templates?.exists ? `yes (${targetInfo.form_templates.title || 'untitled'})` : 'no'}`
    );
  }

  console.log('\nGrouped by normalized title:');
  for (const [title, docIds] of Object.entries(groupsByTitle)) {
    console.log(`  - ${title || '(empty title)'} => ${docIds.length} doc(s): ${docIds.join(', ')}`);
  }
}

main().catch((error) => {
  console.error('\n❌ Script failed');
  console.error(error);
  process.exit(1);
});
