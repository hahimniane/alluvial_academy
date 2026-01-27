/**
 * Script to clean up duplicate FCM tokens in user documents
 * Run with: node scripts/cleanup_duplicate_tokens.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function cleanupDuplicateTokens() {
  console.log('🧹 Starting FCM token cleanup...\n');
  
  try {
    // Get all users with fcmTokens
    const usersSnapshot = await db.collection('users').get();
    
    let usersProcessed = 0;
    let tokensCleaned = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmTokens = userData.fcmTokens;
      
      if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length <= 1) {
        continue;
      }
      
      // Group tokens by platform, keeping only the most recent one
      const tokensByPlatform = {};
      
      for (const tokenObj of fcmTokens) {
        if (!tokenObj || !tokenObj.token || !tokenObj.platform) continue;
        
        const platform = tokenObj.platform;
        const lastUpdated = tokenObj.lastUpdated?.toDate?.() || new Date(0);
        
        if (!tokensByPlatform[platform] || 
            lastUpdated > (tokensByPlatform[platform].lastUpdated?.toDate?.() || new Date(0))) {
          tokensByPlatform[platform] = tokenObj;
        }
      }
      
      // Convert back to array
      const cleanedTokens = Object.values(tokensByPlatform);
      
      if (cleanedTokens.length < fcmTokens.length) {
        const removed = fcmTokens.length - cleanedTokens.length;
        console.log(`👤 User ${userDoc.id}: ${fcmTokens.length} → ${cleanedTokens.length} tokens (removed ${removed} duplicates)`);
        
        await userDoc.ref.update({
          fcmTokens: cleanedTokens,
          lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        tokensCleaned += removed;
        usersProcessed++;
      }
    }
    
    console.log(`\n✅ Cleanup complete!`);
    console.log(`   Users processed: ${usersProcessed}`);
    console.log(`   Duplicate tokens removed: ${tokensCleaned}`);
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    process.exit(1);
  }
}

cleanupDuplicateTokens()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
