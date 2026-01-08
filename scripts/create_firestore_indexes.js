/**
 * Script to create required Firestore composite indexes
 * 
 * This script creates the composite indexes needed for:
 * 1. form_responses queries (by formType, userId, submittedDate)
 * 2. teaching_shifts queries (by teacherId, shift_start)
 * 
 * Note: Firestore indexes must be created via the Firebase Console or CLI.
 * This script provides the index definitions in the correct format.
 * 
 * Run: node scripts/create_firestore_indexes.js
 * 
 * Or manually create via Firebase Console using the URLs provided in the error messages.
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('✅ Initialized with service account key');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error.message);
  console.log('\n⚠️  Note: Index creation requires Firebase CLI or Console.');
  console.log('   This script will show you the index definitions.\n');
}

console.log('\n📋 Required Firestore Composite Indexes\n');
console.log('═══════════════════════════════════════════════════════════════\n');

// Index 1: form_responses
console.log('1️⃣  Index for: form_responses');
console.log('   Collection: form_responses');
console.log('   Query: where formType == ? AND userId == ? AND submittedAt >= ? order by submittedAt DESC');
console.log('   Fields (order matters!):');
console.log('     - formType (Ascending) - MUST be first');
console.log('     - userId (Ascending) - MUST be second');
console.log('     - submittedAt (Ascending) - MUST be third');
console.log('   Create URL:');
console.log('   https://console.firebase.google.com/v1/r/project/alluwal-academy/firestore/indexes?create_composite=ClZwcm9qZWN0cy9hbGx1d2FsLWFjYWRlbXkvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2Zvcm1fcmVzcG9uc2VzL2luZGV4ZXMvXxABGgwKCGZvcm1UeXBlEAEaCgoGdXNlcklkEAEaEQoNc3VibWl0dGVkRGF0ZRABGgwKCF9fbmFtZV9fEAE\n');

// Index 2: teaching_shifts
console.log('2️⃣  Index for: teaching_shifts');
console.log('   Collection: teaching_shifts');
console.log('   Query: where teacherId == ? AND shift_start >= ? order by shift_start DESC');
console.log('   Fields:');
console.log('     - teacherId (Ascending)');
console.log('     - shift_start (Ascending)');
console.log('   Create URL:');
console.log('   https://console.firebase.google.com/v1/r/project/alluwal-academy/firestore/indexes?create_composite=Cldwcm9qZWN0cy9hbGx1d2FsLWFjYWRlbXkvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3RlYWNoaW5nX3NoaWZ0cy9pbmRleGVzL18QARoNCgl0ZWFjaGVySWQQARoPCgtzaGlmdF9zdGFydBACGgwKCF9fbmFtZV9fEAI\n');

console.log('═══════════════════════════════════════════════════════════════\n');
console.log('📝 Instructions:');
console.log('   1. Click on the Create URL above for each index');
console.log('   2. Or use Firebase CLI:');
console.log('      firebase deploy --only firestore:indexes\n');
console.log('   3. Wait for indexes to build (can take a few minutes)');
console.log('   4. Check status in Firebase Console → Firestore → Indexes\n');

// Alternative: Create firestore.indexes.json for Firebase CLI
const fs = require('fs');
const indexesConfig = {
  indexes: [
    {
      collectionGroup: 'form_responses',
      queryScope: 'COLLECTION',
      fields: [
        {
          fieldPath: 'formType',
          order: 'ASCENDING'
        },
        {
          fieldPath: 'userId',
          order: 'ASCENDING'
        },
        {
          fieldPath: 'submittedAt',
          order: 'ASCENDING' // Changed to ASCENDING to match where clause, orderBy can be DESCENDING
        }
      ]
    },
    {
      collectionGroup: 'teaching_shifts',
      queryScope: 'COLLECTION',
      fields: [
        {
          fieldPath: 'teacherId',
          order: 'ASCENDING'
        },
        {
          fieldPath: 'shift_start',
          order: 'ASCENDING'
        }
      ]
    }
  ],
  fieldOverrides: []
};

const indexesPath = path.join(__dirname, '..', 'firestore.indexes.json');
fs.writeFileSync(indexesPath, JSON.stringify(indexesConfig, null, 2));
console.log(`✅ Created firestore.indexes.json at: ${indexesPath}`);
console.log('   You can now deploy with: firebase deploy --only firestore:indexes\n');

console.log('✨ Done!');
