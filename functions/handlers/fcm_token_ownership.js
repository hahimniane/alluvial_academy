const admin = require('firebase-admin');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');

/**
 * A push token identifies a device, not a person.
 *
 * The app adds its token to `users/{uid}.fcmTokens` on sign-in but only removes
 * it on a clean sign-out — and most sign-out buttons call
 * FirebaseAuth.signOut() directly rather than AuthService.signOut(), so the
 * removal rarely happens. The result is one phone registered under every
 * account that has ever signed in on it, each able to push to it.
 *
 * This trigger enforces one owner per device: when a token appears on an
 * account, it is removed from whichever account held it before.
 *
 * Ownership is tracked in `fcm_token_owners/{tokenId}` so a sign-in costs one
 * read instead of a scan of every user. fcmTokens is an array of maps, which
 * Firestore cannot query by a single field, so the index is what makes the
 * previous owner findable at all.
 */

const OWNERS_COLLECTION = 'fcm_token_owners';

/** Firestore document ids cannot contain '/'; FCM tokens otherwise are safe. */
const tokenDocId = (token) => token.replace(/\//g, '_');

const tokenSet = (value) => {
  const tokens = new Set();
  if (!Array.isArray(value)) return tokens;
  value.forEach((entry) => {
    const token = entry && typeof entry === 'object' ? entry.token : null;
    if (typeof token === 'string' && token.trim()) tokens.add(token.trim());
  });
  return tokens;
};

/**
 * Drops a token from a user, in a transaction so a concurrent token save on
 * that same document cannot be clobbered.
 */
const removeTokenFromUser = async (uid, token) => {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    if (!snapshot.exists) return;
    const existing = snapshot.data().fcmTokens;
    if (!Array.isArray(existing) || existing.length === 0) return;
    const remaining = existing.filter(
      (entry) => !(entry && typeof entry === 'object' && entry.token === token),
    );
    if (remaining.length === existing.length) return;
    transaction.update(userRef, { fcmTokens: remaining });
  });
  console.log(`fcmTokenOwnership: removed token from previous owner ${uid}`);
};

const syncFcmTokenOwnership = onDocumentWritten(
  { document: 'users/{userId}', region: 'us-central1' },
  async (event) => {
    const uid = event.params.userId;
    const before = event.data?.before?.exists ? event.data.before.data() : {};
    const after = event.data?.after?.exists ? event.data.after.data() : {};

    const beforeTokens = tokenSet(before.fcmTokens);
    const afterTokens = tokenSet(after.fcmTokens);

    // Only newly added tokens matter. This is also what stops a cascade: the
    // removal below shrinks another user's array, and a write that only removes
    // tokens produces no additions, so that trigger run exits here.
    const added = [...afterTokens].filter((token) => !beforeTokens.has(token));
    if (added.length === 0) return;

    const db = admin.firestore();
    for (const token of added) {
      try {
        const ownerRef = db.collection(OWNERS_COLLECTION).doc(tokenDocId(token));
        const ownerDoc = await ownerRef.get();
        const previousOwner = ownerDoc.exists ? ownerDoc.data().uid : null;

        if (previousOwner && previousOwner !== uid) {
          await removeTokenFromUser(previousOwner, token);
        }

        await ownerRef.set({
          uid,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        // One bad token must not stop the others, and must never fail the
        // user write that triggered this.
        console.error(`fcmTokenOwnership: failed for ${uid}:`, error?.message || error);
      }
    }
  },
);

module.exports = { syncFcmTokenOwnership };
