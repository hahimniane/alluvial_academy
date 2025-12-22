const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Generate a unique kiosque code for parent/family identification
const generateKiosqueCode = async () => {
  let code;
  let isUnique = false;
  let attempts = 0;

  // Generate codes until we find a unique one
  while (!isUnique && attempts < 10) {
    // Generate a 6-character alphanumeric code (uppercase letters and numbers)
    code = '';
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    // Check if code already exists
    const existingCode = await admin.firestore()
      .collection('users')
      .where('kiosque_code', '==', code)
      .limit(1)
      .get();

    if (existingCode.empty) {
      isUnique = true;
    }
    attempts++;
  }

  if (!isUnique) {
    throw new Error('Unable to generate unique kiosque code after multiple attempts');
  }

  console.log(`Generated unique kiosque code: ${code}`);
  return code;
};

const migrateKiosqueCodes = functions.https.onCall(async (data, context) => {
  // Check if caller is admin (you may want to add proper authentication)
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  console.log('🚀 Starting kiosque code migration for existing parents...');

  try {
    const db = admin.firestore();
    const batchSize = 10; // Firestore batch size limit

    // Get all users with user_type = 'parent' who don't have kiosque_code AND have children
    const snapshot = await db.collection('users')
      .where('user_type', '==', 'parent')
      .where('kiosque_code', '==', null)
      .get();

    // Filter to only parents who have enrolled children
    const parentsWithChildren = [];
    for (const doc of snapshot.docs) {
      const userData = doc.data();
      const childrenIds = userData.children_ids || [];
      if (childrenIds.length > 0) {
        parentsWithChildren.push(doc);
      }
    }

    if (parentsWithChildren.length === 0) {
      console.log('✅ No parents found without kiosque codes who have enrolled children');
      return { success: true, message: 'No parents found without kiosque codes who have enrolled children', updated: 0 };
    }

    console.log(`📋 Found ${parentsWithChildren.length} parents without kiosque codes who have enrolled children`);

    // Generate unique kiosque codes for each parent
    const updates = [];
    const usedCodes = new Set();

    // First, collect all existing kiosque codes to avoid conflicts
    const existingCodesSnapshot = await db.collection('users')
      .where('kiosque_code', '!=', null)
      .select('kiosque_code')
      .get();

    existingCodesSnapshot.docs.forEach(doc => {
      const code = doc.data().kiosque_code;
      if (code) usedCodes.add(code);
    });

    console.log(`📋 Found ${usedCodes.size} existing kiosque codes to avoid conflicts`);

    // Generate codes for parents without them
    for (const doc of parentsWithChildren) {
      const userData = doc.data();
      const userId = doc.id;

      // Generate a unique 6-character alphanumeric code
      let kiosqueCode;
      let attempts = 0;

      do {
        kiosqueCode = '';
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        for (let i = 0; i < 6; i++) {
          kiosqueCode += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        attempts++;
      } while (usedCodes.has(kiosqueCode) && attempts < 50);

      if (attempts >= 50) {
        console.error(`❌ Failed to generate unique code for user ${userId} after 50 attempts`);
        continue;
      }

      usedCodes.add(kiosqueCode);
      updates.push({
        userId,
        kiosqueCode,
        userName: `${userData.first_name} ${userData.last_name}`,
        email: userData['e-mail'] || userData.email
      });
    }

    // Apply updates in batches
    let batch = db.batch();
    let batchCount = 0;
    let totalUpdated = 0;

    for (const update of updates) {
      const userRef = db.collection('users').doc(update.userId);
      batch.update(userRef, {
        kiosque_code: update.kiosqueCode,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });

      batchCount++;

      // Commit batch when it reaches the limit
      if (batchCount >= batchSize) {
        await batch.commit();
        console.log(`✅ Updated ${batchCount} parents with kiosque codes`);
        totalUpdated += batchCount;

        // Start new batch
        batch = db.batch();
        batchCount = 0;
      }
    }

    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
      totalUpdated += batchCount;
      console.log(`✅ Updated remaining ${batchCount} parents with kiosque codes`);
    }

    console.log(`🎉 Migration completed! Updated ${totalUpdated} parents with kiosque codes`);

    // Return summary (first 10 codes for reference)
    const sampleCodes = updates.slice(0, 10).map(update => ({
      name: update.userName,
      email: update.email,
      code: update.kiosqueCode
    }));

    return {
      success: true,
      message: `Migration completed! Updated ${totalUpdated} parents with kiosque codes`,
      updated: totalUpdated,
      sampleCodes,
      totalFound: updates.length
    };

  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw new functions.https.HttpsError('internal', `Migration failed: ${error.message}`);
  }
});

module.exports = {
  migrateKiosqueCodes
};
