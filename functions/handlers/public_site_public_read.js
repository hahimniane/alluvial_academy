/**
 * Public read of marketing CMS docs (Admin SDK — bypasses client Firestore rules).
 * Used when the web app has no signed-in user but Firestore rules still require auth.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.getPublicSiteMarketingBundle = functions.https.onCall(async (_data, _context) => {
  // Auth may be null — callable still returns public marketing docs only.
  const db = admin.firestore();
  const [pricingSnap, socialSnap, landingSnap, teamSnap] = await Promise.all([
    db.collection('public_site_cms_pricing').doc('main').get(),
    db.collection('public_site_cms_social').doc('main').get(),
    db.collection('public_site_cms_landing').doc('main').get(),
    db.collection('public_site_cms_team').get(),
  ]);

  const teamMembers = teamSnap.docs
    .map((d) => ({
      id: d.id,
      ...d.data(),
    }))
    .filter((row) => {
      const active = row.active !== false;
      const name = row.name ? String(row.name).trim() : '';
      const link = row.linkedUserUid ? String(row.linkedUserUid).trim() : '';
      return active && name.length > 0 && link.length > 0;
    });

  return {
    pricing: pricingSnap.exists ? pricingSnap.data() : null,
    social: socialSnap.exists ? socialSnap.data() : null,
    landing: landingSnap.exists ? landingSnap.data() : null,
    teamMembers,
  };
});
