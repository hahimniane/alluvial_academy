/**
 * Finds Auth accounts whose custom claims still grant admin while their user
 * document no longer makes them an admin (demoted before the users trigger
 * cleared claims), and clears those claims.
 *
 *   node dev-scripts/clear_stale_admin_claims.js --project alluwal-dev            dry run
 *   node dev-scripts/clear_stale_admin_claims.js --project alluwal-dev --apply    clear them
 *
 * The user document is found by the Auth uid, then by a `uid` field. An
 * account with admin claims and no user document is counted, never changed
 * (nothing says who they are). Other claims are kept. Prints counts only —
 * never names, emails or ids.
 */
const admin = require('firebase-admin');
const { claimsWithoutAdmin, isAdminFromUserData } = require('../services/admin_claims');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const projectFlag = args.indexOf('--project');
const projectId = projectFlag >= 0 ? args[projectFlag + 1] : '';
if (!projectId) throw new Error('Pass an explicit Firebase project with --project <id>');

admin.initializeApp({ projectId });
const db = admin.firestore();
const auth = admin.auth();

async function userDocFor(uid) {
  const byId = await db.collection('users').doc(uid).get();
  if (byId.exists) return byId.data() || {};
  const byField = await db.collection('users').where('uid', '==', uid).limit(1).get();
  return byField.empty ? null : byField.docs[0].data() || {};
}

(async () => {
  const counts = { authAccounts: 0, withAdminClaims: 0, stillAdmin: 0, noUserDoc: 0, stale: 0, cleared: 0 };
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      counts.authAccounts += 1;
      const { changed, next } = claimsWithoutAdmin(user.customClaims);
      if (!changed) continue;
      counts.withAdminClaims += 1;
      const data = await userDocFor(user.uid);
      if (!data) {
        counts.noUserDoc += 1;
        continue;
      }
      if (isAdminFromUserData(data)) {
        counts.stillAdmin += 1;
        continue;
      }
      counts.stale += 1;
      if (apply) {
        await auth.setCustomUserClaims(user.uid, next);
        counts.cleared += 1;
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);

  console.log(JSON.stringify({ project: projectId, mode: apply ? 'apply' : 'dry-run', ...counts }, null, 2));
})().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
