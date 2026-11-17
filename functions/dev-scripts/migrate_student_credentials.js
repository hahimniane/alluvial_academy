/**
 * Moves student passwords off the world-readable users/{uid}.temp_password
 * into student_credentials/{uid} (admins + the student's own guardians only).
 *
 *   node dev-scripts/migrate_student_credentials.js --project alluwal-dev                     dry run
 *   node dev-scripts/migrate_student_credentials.js --project alluwal-dev --apply             copy
 *   node dev-scripts/migrate_student_credentials.js --project alluwal-dev --apply --delete-legacy
 *                                                                                              copy, then delete the field
 *   ... --include-non-students   also delete the field from non-student docs (nothing is copied for them)
 *
 * Copy never overwrites a password already in the store: the store is newer
 * (a reset or the student's own change since). A student's legacy field is
 * deleted only once the store holds a password for them.
 *
 * Run --delete-legacy on production only after the phone app release that
 * reads the store is in use: older admin builds read only the legacy field.
 * Prints counts only — never passwords, names, emails or ids.
 */
const admin = require('firebase-admin');
const {
  LEGACY_PASSWORD_FIELD,
  STUDENT_CREDENTIALS,
  credentialData,
} = require('../services/student_credentials');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const deleteLegacy = args.includes('--delete-legacy');
const includeNonStudents = args.includes('--include-non-students');
const projectFlag = args.indexOf('--project');
const projectId = projectFlag >= 0 ? args[projectFlag + 1] : '';
if (!projectId) throw new Error('Pass an explicit Firebase project with --project <id>');
if (deleteLegacy && !apply) throw new Error('--delete-legacy needs --apply');

admin.initializeApp({projectId});
const db = admin.firestore();
const {FieldValue} = admin.firestore;

const text = (value) => (typeof value === 'string' ? value : '');

(async () => {
  const [users, credentials] = await Promise.all([
    db.collection('users').get(),
    db.collection(STUDENT_CREDENTIALS).get(),
  ]);
  const stored = new Map(credentials.docs.map((d) => [d.id, text((d.data() || {}).password)]));

  const counts = {
    users: users.size,
    withLegacy: 0,
    studentsWithLegacy: 0,
    nonStudentsWithLegacy: 0,
    toCopy: 0,
    alreadyStoredSame: 0,
    alreadyStoredDifferent: 0,
    legacyToDelete: 0,
    nonStudentLegacyToDelete: 0,
  };
  const copies = [];
  const deletions = [];

  for (const doc of users.docs) {
    const data = doc.data() || {};
    if (!(LEGACY_PASSWORD_FIELD in data)) continue;
    counts.withLegacy += 1;
    const legacy = text(data[LEGACY_PASSWORD_FIELD]);
    const isStudent = String(data.user_type || '').trim().toLowerCase() === 'student';

    if (!isStudent) {
      counts.nonStudentsWithLegacy += 1;
      if (includeNonStudents) {
        counts.nonStudentLegacyToDelete += 1;
        deletions.push(doc.ref);
      }
      continue;
    }

    counts.studentsWithLegacy += 1;
    const inStore = stored.get(doc.id) || '';
    let willHaveStore = !!inStore.trim();
    if (inStore.trim()) {
      if (inStore === legacy) counts.alreadyStoredSame += 1;
      else counts.alreadyStoredDifferent += 1;
    } else if (legacy.trim()) {
      counts.toCopy += 1;
      copies.push({id: doc.id, password: legacy});
      willHaveStore = true;
    }
    // An empty legacy value has nothing to keep; a real one only goes once copied.
    if (willHaveStore || !legacy.trim()) {
      counts.legacyToDelete += 1;
      deletions.push(doc.ref);
    }
  }

  console.log(JSON.stringify({mode: apply ? (deleteLegacy ? 'apply+delete' : 'apply') : 'dry-run', ...counts}));
  if (!apply) return process.exit(0);

  let batch = db.batch();
  let ops = 0;
  const flush = async () => {
    if (ops === 0) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };
  for (const copy of copies) {
    batch.set(db.collection(STUDENT_CREDENTIALS).doc(copy.id), credentialData(copy.password, {source: 'migrated'}));
    ops += 1;
    if (ops >= 400) await flush();
  }
  await flush();
  console.log(JSON.stringify({copied: copies.length}));

  if (deleteLegacy) {
    for (const ref of deletions) {
      batch.update(ref, {[LEGACY_PASSWORD_FIELD]: FieldValue.delete()});
      ops += 1;
      if (ops >= 400) await flush();
    }
    await flush();
    console.log(JSON.stringify({legacyDeleted: deletions.length}));
  }
  process.exit(0);
})().catch((e) => {
  console.error('ERR', e.message);
  process.exit(1);
});
