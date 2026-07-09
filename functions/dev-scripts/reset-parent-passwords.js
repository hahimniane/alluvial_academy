/**
 * reset-parent-passwords.js
 *
 * One-off migration: set every existing parent's Firebase Auth password to the
 * standard default parent password (123456) and clear password_reset_required
 * on their Firestore users/* doc.
 *
 * Parents are identified by users/* docs with user_type == 'parent'. The Auth
 * UID is the Firestore doc id (that is how parent accounts are created).
 *
 * Run from the functions/ directory:
 *   DRY_RUN=true  node dev-scripts/reset-parent-passwords.js   # preview only
 *   DRY_RUN=false node dev-scripts/reset-parent-passwords.js   # apply changes
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS or Firebase Admin SDK / ADC
 * credentials with access to the target project. Set FIREBASE_PROJECT to
 * override the project id.
 */

const admin = require('firebase-admin');
const { DEFAULT_PARENT_PASSWORD } = require('../utils/password');

const PROJECT_ID = process.env.FIREBASE_PROJECT || 'alluwal-academy';
const DRY_RUN = process.env.DRY_RUN !== 'false'; // default: dry run

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

async function main() {
  console.log(`[reset-parent-passwords] project=${PROJECT_ID} dryRun=${DRY_RUN} password=${DEFAULT_PARENT_PASSWORD}`);

  const snap = await db.collection('users').where('user_type', '==', 'parent').get();
  console.log(`Found ${snap.size} parent docs.`);

  let updated = 0;
  let skipped = 0;
  const failures = [];

  for (const doc of snap.docs) {
    const uid = doc.id;
    const data = doc.data() || {};
    const email = data['e-mail'] || data.email || '(no email)';

    if (DRY_RUN) {
      console.log(`  [dry-run] would reset ${email} (uid=${uid})`);
      updated += 1;
      continue;
    }

    try {
      await auth.updateUser(uid, { password: DEFAULT_PARENT_PASSWORD });
      await doc.ref.set({ password_reset_required: false }, { merge: true });
      console.log(`  ✅ reset ${email} (uid=${uid})`);
      updated += 1;
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        console.warn(`  ⚠️  no Auth user for ${email} (uid=${uid}) — skipped`);
        skipped += 1;
      } else {
        console.error(`  ❌ failed for ${email} (uid=${uid}): ${e.message}`);
        failures.push({ uid, email, error: e.message });
      }
    }
  }

  console.log('---');
  console.log(`Done. ${DRY_RUN ? 'would update' : 'updated'}=${updated} skipped=${skipped} failed=${failures.length}`);
  if (failures.length) {
    console.log('Failures:', JSON.stringify(failures, null, 2));
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('Fatal:', e);
    process.exit(1);
  });
