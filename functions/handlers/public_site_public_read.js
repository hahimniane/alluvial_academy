/**
 * Public read of marketing CMS docs (Admin SDK — bypasses client Firestore rules).
 * Used when the web app has no signed-in user but Firestore rules still require auth.
 */
const { onCall, onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const _buildMarketingBundle = async () => {
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
};

exports.getPublicSiteMarketingBundle = onCall(
  { cors: true, invoker: 'public', region: 'us-central1' },
  async () => {
    // Auth may be null — callable still returns public marketing docs only.
    return _buildMarketingBundle();
  }
);

exports.getPublicSiteMarketingBundleHttp = onRequest(
  { invoker: 'public', region: 'us-central1' },
  async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Vary', 'Origin');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'GET') {
      res.status(405).json({ error: 'method-not-allowed' });
      return;
    }

    try {
      const bundle = await _buildMarketingBundle();
      res.set('Cache-Control', 'public, max-age=45');
      res.status(200).json(bundle);
    } catch (error) {
      console.error('[getPublicSiteMarketingBundleHttp] failed:', error);
      res.status(500).json({ error: 'internal' });
    }
  }
);

exports.__test__ = {
  _buildMarketingBundle,
};
