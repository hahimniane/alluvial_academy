/**
 * Script to delete all documents in job_board collection
 * Run: node scripts/delete_all_jobs.js
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

async function deleteAllJobs() {
  console.log('🗑️  Starting to delete all jobs from job_board collection...\n');
  
  try {
    const snapshot = await db.collection('job_board').get();
    
    if (snapshot.empty) {
      console.log('✅ No jobs found in job_board collection. Already clean!');
      return;
    }
    
    console.log(`Found ${snapshot.size} job(s) to delete.\n`);
    
    const batch = db.batch();
    let count = 0;
    
    snapshot.docs.forEach((doc) => {
      console.log(`  - Deleting job: ${doc.id} (${doc.data().subject || 'No subject'})`);
      batch.delete(doc.ref);
      count++;
    });
    
    await batch.commit();
    
    console.log(`\n✅ Successfully deleted ${count} job(s) from job_board collection.`);
    
    // Also reset enrollment statuses that were "broadcasted" back to "pending"
    console.log('\n📝 Resetting broadcasted enrollments back to pending...\n');
    
    const enrollmentsSnapshot = await db.collection('enrollments')
      .where('metadata.status', '==', 'broadcasted')
      .get();
    
    if (enrollmentsSnapshot.empty) {
      console.log('✅ No broadcasted enrollments to reset.');
    } else {
      const enrollmentBatch = db.batch();
      let enrollmentCount = 0;
      
      enrollmentsSnapshot.docs.forEach((doc) => {
        console.log(`  - Resetting enrollment: ${doc.id}`);
        enrollmentBatch.update(doc.ref, {
          'metadata.status': 'pending',
          'metadata.jobId': admin.firestore.FieldValue.delete(),
          'metadata.broadcastedAt': admin.firestore.FieldValue.delete(),
        });
        enrollmentCount++;
      });
      
      await enrollmentBatch.commit();
      console.log(`\n✅ Reset ${enrollmentCount} enrollment(s) to pending status.`);
    }
    
    console.log('\n🎉 Cleanup complete! Ready for fresh start.');
    
  } catch (error) {
    console.error('❌ Error deleting jobs:', error);
  }
  
  process.exit(0);
}

deleteAllJobs();

