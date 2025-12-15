/**
 * Script to delete all documents in enrollments collection
 * Run: node scripts/delete_all_enrollments.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteAllEnrollments() {
  console.log('🗑️  Starting to delete all enrollments from enrollments collection...\n');
  
  try {
    const snapshot = await db.collection('enrollments').get();
    
    if (snapshot.empty) {
      console.log('✅ No enrollments found in enrollments collection. Already clean!');
      return;
    }
    
    console.log(`Found ${snapshot.size} enrollment(s) to delete.\n`);
    
    // Delete in batches to avoid hitting Firestore limits
    const batchSize = 500;
    let deletedCount = 0;
    let batch = db.batch();
    let batchCount = 0;
    const batches = [];
    
    snapshot.docs.forEach((doc) => {
      console.log(`  - Deleting enrollment: ${doc.id} (${doc.data().subject || 'No subject'})`);
      batch.delete(doc.ref);
      batchCount++;
      deletedCount++;
      
      // Commit batch when it reaches the limit
      if (batchCount >= batchSize) {
        batches.push(batch.commit());
        batch = db.batch();
        batchCount = 0;
      }
    });
    
    // Commit any remaining documents
    if (batchCount > 0) {
      batches.push(batch.commit());
    }
    
    // Wait for all batches to complete
    await Promise.all(batches);
    
    console.log(`\n✅ Successfully deleted ${deletedCount} enrollment(s) from enrollments collection.`);
    console.log('\n🎉 Cleanup complete! Ready for fresh start.');
    
  } catch (error) {
    console.error('❌ Error deleting enrollments:', error);
  }
  
  process.exit(0);
}

deleteAllEnrollments();

