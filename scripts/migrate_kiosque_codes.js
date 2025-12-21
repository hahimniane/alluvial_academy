const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID || 'alluwal-academy'
  });
}

async function migrateKiosqueCodes() {
  console.log('🚀 Starting kiosque code migration for existing parents...');

  try {
    const db = admin.firestore();
    const batchSize = 10; // Firestore batch size limit

    // Get all users with user_type = 'parent' who don't have kiosque_code
    const snapshot = await db.collection('users')
      .where('user_type', '==', 'parent')
      .where('kiosque_code', '==', null)
      .get();

    if (snapshot.empty) {
      console.log('✅ No parents found without kiosque codes');
      return;
    }

    console.log(`📋 Found ${snapshot.docs.length} parents without kiosque codes`);

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
    for (const doc of snapshot.docs) {
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
        userName: `${userData.first_name} ${userData.last_name}`
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

    // Log the codes for reference (first 10)
    console.log('\n📋 Sample kiosque codes assigned:');
    updates.slice(0, 10).forEach(update => {
      console.log(`   ${update.userName}: ${update.kiosqueCode}`);
    });

    if (updates.length > 10) {
      console.log(`   ... and ${updates.length - 10} more`);
    }

  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  }
}

// Run the migration if this script is executed directly
if (require.main === module) {
  migrateKiosqueCodes()
    .then(() => {
      console.log('✅ Migration script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Migration script failed:', error);
      process.exit(1);
    });
}

module.exports = { migrateKiosqueCodes };
