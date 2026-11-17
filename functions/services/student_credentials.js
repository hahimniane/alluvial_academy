/**
 * Student login passwords, kept where only admins and the student's own
 * guardians can read them (firestore.rules `student_credentials`).
 *
 * `users/{uid}` is readable by every signed-in user, so a password must never
 * be written there. Older accounts still carry one in `users/{uid}.temp_password`
 * until `dev-scripts/migrate_student_credentials.js` moves it; readers fall back
 * to it until then.
 */

const admin = require('firebase-admin');

const STUDENT_CREDENTIALS = 'student_credentials';
const LEGACY_PASSWORD_FIELD = 'temp_password';

const _text = (value) => (typeof value === 'string' ? value : '');

/**
 * The document written for a student's password. `source` says where it came
 * from: created | reset | self | migrated.
 */
const credentialData = (password, {source, actorUid = null} = {}) => ({
  password: String(password),
  source: String(source || 'reset'),
  updated_by: actorUid || null,
  updated_at: admin.firestore.FieldValue.serverTimestamp(),
});

const credentialRef = (db, studentId) => db.collection(STUDENT_CREDENTIALS).doc(String(studentId));

/** Queues the credential write on `batch`. */
const queueCredentialWrite = (db, batch, studentId, password, meta) => {
  batch.set(credentialRef(db, studentId), credentialData(password, meta));
};

/** The field update that removes the legacy plaintext copy from a user doc. */
const legacyPasswordRemoval = () => ({[LEGACY_PASSWORD_FIELD]: admin.firestore.FieldValue.delete()});

/** The stored password: the credential store first, else the legacy user-doc field, else ''. */
const pickStoredPassword = (credentialDoc, userData) => {
  const stored = credentialDoc && credentialDoc.exists ? _text((credentialDoc.data() || {}).password) : '';
  if (stored.trim()) return stored;
  const legacy = _text((userData || {})[LEGACY_PASSWORD_FIELD]);
  return legacy.trim() ? legacy : '';
};

const readStudentPassword = async (db, studentId, userData) =>
  pickStoredPassword(await credentialRef(db, studentId).get(), userData);

/** Firebase Auth's limits, as the reset dialog states them. */
const validatePassword = (password) => {
  if (typeof password !== 'string') return 'Password is required';
  if (password !== password.trim()) return 'Password cannot start or end with spaces';
  if (password.length < 6) return 'Password must be at least 6 characters';
  if (password.length > 128) return 'Password must be 128 characters or less';
  return null;
};

module.exports = {
  STUDENT_CREDENTIALS,
  LEGACY_PASSWORD_FIELD,
  credentialData,
  credentialRef,
  queueCredentialWrite,
  legacyPasswordRemoval,
  pickStoredPassword,
  readStudentPassword,
  validatePassword,
};
