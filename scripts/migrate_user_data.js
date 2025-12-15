/**
 * Script de migration des données utilisateur pour ALIOU DIALLO
 * 
 * Problème: Le compte d'ALIOU DIALLO a été supprimé puis recréé.
 * Les anciennes données (shifts, timesheets, formulaires, etc.) font référence
 * à l'ancien UID, et ne sont donc plus liées au nouveau compte.
 * 
 * Ce script:
 * 1. Scanne toutes les collections pour trouver les données associées à l'email/nom
 * 2. Identifie l'ancien UID utilisé dans ces documents
 * 3. Peut mettre à jour tous les documents pour pointer vers le nouvel UID
 * 
 * Utilisation:
 * - Mode audit (dry run): node scripts/migrate_user_data.js
 * - Mode migration réelle: node scripts/migrate_user_data.js --execute
 */

const admin = require('firebase-admin');
const path = require('path');

// Configuration de l'utilisateur à migrer
const TARGET_USER = {
  email: 'aliou9716@gmail.com',
  firstName: 'Aliou',
  lastName: 'DIALLO',
  fullName: 'ALIOU DIALLO',
};

// Collections à scanner et leurs champs pertinents
const COLLECTIONS_CONFIG = [
  {
    name: 'users',
    idField: 'uid', // Le document ID est l'UID
    emailFields: ['e-mail', 'email'],
    nameFields: ['first_name', 'last_name', 'name'],
    updateFields: ['uid'],
  },
  {
    name: 'teaching_shifts',
    idField: 'teacher_id',
    emailFields: ['teacher_email'],
    nameFields: ['teacher_name'],
    updateFields: ['teacher_id', 'created_by_admin_id'],
  },
  {
    name: 'timesheet_entries',
    idField: 'teacher_id',
    emailFields: ['teacher_email'],
    nameFields: ['teacher_name'],
    updateFields: ['teacher_id', 'teacherId'],
  },
  {
    name: 'form_responses',
    idField: 'userId',
    emailFields: ['userEmail', 'user_email'],
    nameFields: ['userFirstName', 'userLastName', 'firstName', 'lastName'],
    updateFields: ['userId'],
  },
  {
    name: 'form_drafts',
    idField: 'createdBy',
    emailFields: ['userEmail'],
    nameFields: [],
    updateFields: ['createdBy'],
  },
  {
    name: 'tasks',
    idField: null, // Multiple fields
    emailFields: [],
    nameFields: [],
    updateFields: ['createdBy', 'assignedTo'], // assignedTo is an array
    specialHandling: 'tasks',
  },
  {
    name: 'teacher_profiles',
    idField: 'user_id',
    emailFields: ['user_email'],
    nameFields: ['full_name'],
    updateFields: ['user_id'],
    docIdIsUid: true, // Document ID is also the UID
  },
  {
    name: 'shift_modifications',
    idField: 'modified_by',
    emailFields: [],
    nameFields: [],
    updateFields: ['modified_by', 'teacher_id'],
  },
  {
    name: 'contact_messages',
    idField: 'userId',
    emailFields: ['email'],
    nameFields: ['firstName', 'lastName'],
    updateFields: ['userId'],
  },
  {
    name: 'teacher_applications',
    idField: 'userId',
    emailFields: ['email'],
    nameFields: ['firstName', 'lastName'],
    updateFields: ['userId'],
  },
  {
    name: 'enrollments',
    idField: 'userId',
    emailFields: ['parentEmail', 'email'],
    nameFields: ['parentName'],
    updateFields: ['userId'],
  },
  {
    name: 'notifications',
    idField: 'userId',
    emailFields: [],
    nameFields: [],
    updateFields: ['userId', 'recipientId', 'senderId'],
  },
  {
    name: 'chat_messages',
    idField: 'senderId',
    emailFields: [],
    nameFields: ['senderName'],
    updateFields: ['senderId', 'receiverId'],
  },
];

// Initialize Firebase Admin
let db;
try {
  const serviceAccountPath = path.join(__dirname, '../serviceAccountKey.json');
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'alluwal-academy',
  });
  db = admin.firestore();
  console.log('✅ Firebase Admin initialized successfully\n');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin:', error.message);
  console.log('\nMake sure serviceAccountKey.json exists in the project root.');
  process.exit(1);
}

// Results storage
const results = {
  oldUids: new Set(),
  newUid: null,
  collections: {},
  totalDocuments: 0,
};

/**
 * Check if a document matches the target user
 */
function matchesTargetUser(data, config) {
  // Check email fields
  for (const emailField of config.emailFields) {
    if (data[emailField] && data[emailField].toLowerCase() === TARGET_USER.email.toLowerCase()) {
      return true;
    }
  }

  // Check name fields
  for (const nameField of config.nameFields) {
    const value = data[nameField];
    if (!value) continue;

    const valueLower = value.toLowerCase();
    const firstNameLower = TARGET_USER.firstName.toLowerCase();
    const lastNameLower = TARGET_USER.lastName.toLowerCase();
    const fullNameLower = TARGET_USER.fullName.toLowerCase();

    if (
      valueLower === fullNameLower ||
      valueLower === `${firstNameLower} ${lastNameLower}` ||
      valueLower.includes(firstNameLower) && valueLower.includes(lastNameLower)
    ) {
      return true;
    }
  }

  return false;
}

/**
 * Extract potential UID from document
 */
function extractUid(doc, data, config) {
  // If document ID is the UID
  if (config.docIdIsUid) {
    return doc.id;
  }

  // Check the ID field
  if (config.idField && data[config.idField]) {
    return data[config.idField];
  }

  // For users collection, the document ID is the UID
  if (config.name === 'users') {
    return doc.id;
  }

  return null;
}

/**
 * Scan a collection for matching documents
 */
async function scanCollection(config) {
  console.log(`\n📂 Scanning collection: ${config.name}`);

  const collectionResults = {
    found: [],
    errors: [],
  };

  try {
    const collectionRef = db.collection(config.name);
    const snapshot = await collectionRef.get();

    console.log(`   Total documents in collection: ${snapshot.size}`);

    for (const doc of snapshot.docs) {
      const data = doc.data();

      // Special handling for tasks (assignedTo is an array)
      if (config.specialHandling === 'tasks') {
        const assignedTo = data.assignedTo || [];
        // We'll check if any of the found old UIDs are in assignedTo later
        // For now, check by name in description or title
        if (
          (data.createdBy && results.oldUids.has(data.createdBy)) ||
          (data.title && data.title.toLowerCase().includes(TARGET_USER.firstName.toLowerCase()))
        ) {
          collectionResults.found.push({
            docId: doc.id,
            data: data,
            matchedBy: 'createdBy or title',
          });
        }
        continue;
      }

      if (matchesTargetUser(data, config)) {
        const uid = extractUid(doc, data, config);

        collectionResults.found.push({
          docId: doc.id,
          data: data,
          extractedUid: uid,
          matchedBy: 'email/name',
        });

        if (uid) {
          results.oldUids.add(uid);
        }
      }
    }

    if (collectionResults.found.length > 0) {
      console.log(`   ✅ Found ${collectionResults.found.length} matching documents`);
    } else {
      console.log(`   ⚪ No matching documents found`);
    }

    results.totalDocuments += collectionResults.found.length;
  } catch (error) {
    console.log(`   ❌ Error scanning: ${error.message}`);
    collectionResults.errors.push(error.message);
  }

  results.collections[config.name] = collectionResults;
  return collectionResults;
}

/**
 * Find the new UID from the users collection
 */
async function findNewUid() {
  console.log('\n🔍 Looking for the NEW user account...');

  try {
    // Query by email
    const usersRef = db.collection('users');

    // Try e-mail field
    let query = await usersRef.where('e-mail', '==', TARGET_USER.email).get();
    if (query.empty) {
      // Try email field
      query = await usersRef.where('email', '==', TARGET_USER.email).get();
    }

    if (!query.empty) {
      // Find the most recently created one (should be the new account)
      const docs = query.docs;

      // Sort by date_added or created_at descending
      const sortedDocs = docs.sort((a, b) => {
        const aDate = a.data().date_added || a.data().created_at || '';
        const bDate = b.data().date_added || b.data().created_at || '';
        return String(bDate).localeCompare(String(aDate));
      });

      if (sortedDocs.length > 1) {
        console.log(`   Found ${sortedDocs.length} user documents for this email.`);
        console.log('   Listing all user documents:');
        sortedDocs.forEach((doc, idx) => {
          const data = doc.data();
          console.log(`     ${idx + 1}. UID: ${doc.id}`);
          console.log(`        Email: ${data['e-mail'] || data.email}`);
          console.log(`        Name: ${data.first_name} ${data.last_name}`);
          console.log(`        Added: ${data.date_added || data.created_at || 'Unknown'}`);
          console.log(`        Is Active: ${data.is_active}`);
          console.log(`        User Type: ${data.user_type || data.role}`);
        });
      }

      // The new UID should be the document ID of the most recently created user
      results.newUid = sortedDocs[0].id;
      console.log(`   ✅ New UID identified: ${results.newUid}`);

      // Check if it's different from old UIDs
      if (results.oldUids.has(results.newUid)) {
        console.log(`   ⚠️  Warning: New UID is same as one of the old UIDs found in data.`);
        console.log(`       This might mean the user document wasn't deleted, just the Auth account.`);
      }

      return results.newUid;
    } else {
      console.log('   ❌ No user document found with this email!');
      console.log('      Make sure the new account has been created.');
      return null;
    }
  } catch (error) {
    console.error('   ❌ Error finding new UID:', error.message);
    return null;
  }
}

/**
 * Second pass: Find documents by OLD UID
 */
async function scanByOldUids() {
  if (results.oldUids.size === 0) {
    console.log('\n⚠️  No old UIDs found in first pass.');
    return;
  }

  console.log('\n🔍 Second pass: Scanning for documents by OLD UIDs...');
  console.log(`   Old UIDs found: ${Array.from(results.oldUids).join(', ')}`);

  for (const config of COLLECTIONS_CONFIG) {
    if (!config.idField && config.specialHandling !== 'tasks') continue;

    try {
      const collectionRef = db.collection(config.name);

      for (const oldUid of results.oldUids) {
        // Skip if old UID is same as new UID
        if (oldUid === results.newUid) continue;

        if (config.idField) {
          const query = await collectionRef.where(config.idField, '==', oldUid).get();

          if (!query.empty) {
            console.log(`   📂 ${config.name}: Found ${query.docs.length} docs with ${config.idField}=${oldUid}`);

            // Add to results if not already there
            const existingDocIds = results.collections[config.name].found.map(f => f.docId);
            for (const doc of query.docs) {
              if (!existingDocIds.includes(doc.id)) {
                results.collections[config.name].found.push({
                  docId: doc.id,
                  data: doc.data(),
                  extractedUid: oldUid,
                  matchedBy: `${config.idField} query`,
                });
                results.totalDocuments++;
              }
            }
          }
        }

        // Special handling for tasks - check assignedTo array
        if (config.specialHandling === 'tasks') {
          const query = await collectionRef.where('assignedTo', 'array-contains', oldUid).get();

          if (!query.empty) {
            console.log(`   📂 ${config.name}: Found ${query.docs.length} docs with assignedTo containing ${oldUid}`);

            const existingDocIds = results.collections[config.name].found.map(f => f.docId);
            for (const doc of query.docs) {
              if (!existingDocIds.includes(doc.id)) {
                results.collections[config.name].found.push({
                  docId: doc.id,
                  data: doc.data(),
                  extractedUid: oldUid,
                  matchedBy: 'assignedTo array',
                });
                results.totalDocuments++;
              }
            }
          }

          // Also check createdBy
          const createdByQuery = await collectionRef.where('createdBy', '==', oldUid).get();
          if (!createdByQuery.empty) {
            console.log(`   📂 ${config.name}: Found ${createdByQuery.docs.length} docs with createdBy=${oldUid}`);

            const existingDocIds = results.collections[config.name].found.map(f => f.docId);
            for (const doc of createdByQuery.docs) {
              if (!existingDocIds.includes(doc.id)) {
                results.collections[config.name].found.push({
                  docId: doc.id,
                  data: doc.data(),
                  extractedUid: oldUid,
                  matchedBy: 'createdBy query',
                });
                results.totalDocuments++;
              }
            }
          }
        }
      }
    } catch (error) {
      console.log(`   ❌ Error in second pass for ${config.name}: ${error.message}`);
    }
  }
}

/**
 * Update documents with new UID
 */
async function migrateDocuments(dryRun = true) {
  if (!results.newUid) {
    console.log('\n❌ Cannot migrate: New UID not found!');
    return;
  }

  const oldUidsArray = Array.from(results.oldUids).filter(uid => uid !== results.newUid);
  if (oldUidsArray.length === 0) {
    console.log('\n⚠️  No old UIDs to migrate from.');
    return;
  }

  console.log(`\n${dryRun ? '🔍 DRY RUN' : '🚀 EXECUTING'}: Migrating data...`);
  console.log(`   From Old UIDs: ${oldUidsArray.join(', ')}`);
  console.log(`   To New UID: ${results.newUid}`);

  let updatedCount = 0;
  let errorCount = 0;

  for (const config of COLLECTIONS_CONFIG) {
    const collectionData = results.collections[config.name];
    if (!collectionData || collectionData.found.length === 0) continue;

    console.log(`\n   📂 Processing ${config.name}...`);

    for (const item of collectionData.found) {
      const docRef = db.collection(config.name).doc(item.docId);
      const updates = {};

      // Build updates based on config
      for (const field of config.updateFields) {
        const currentValue = item.data[field];

        if (field === 'assignedTo' && Array.isArray(currentValue)) {
          // Handle array field
          const newArray = currentValue.map(id =>
            oldUidsArray.includes(id) ? results.newUid : id
          );
          if (JSON.stringify(newArray) !== JSON.stringify(currentValue)) {
            updates[field] = newArray;
          }
        } else if (typeof currentValue === 'string' && oldUidsArray.includes(currentValue)) {
          updates[field] = results.newUid;
        }
      }

      // Special case: If document ID is the UID and needs to change
      if (config.docIdIsUid && oldUidsArray.includes(item.docId)) {
        console.log(`      ⚠️  Document ${item.docId} needs ID change (complex operation)`);
        // This requires creating a new doc and deleting the old one
        if (!dryRun) {
          try {
            const newDocRef = db.collection(config.name).doc(results.newUid);
            const updatedData = { ...item.data, ...updates };

            // Update any uid/user_id fields
            for (const field of config.updateFields) {
              if (oldUidsArray.includes(updatedData[field])) {
                updatedData[field] = results.newUid;
              }
            }

            await newDocRef.set(updatedData);
            await docRef.delete();
            console.log(`      ✅ Moved document from ${item.docId} to ${results.newUid}`);
            updatedCount++;
          } catch (error) {
            console.log(`      ❌ Error moving document: ${error.message}`);
            errorCount++;
          }
        } else {
          console.log(`      [DRY RUN] Would move document from ${item.docId} to ${results.newUid}`);
          updatedCount++;
        }
        continue;
      }

      // Regular field updates
      if (Object.keys(updates).length > 0) {
        updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
        updates._migration_note = `Migrated from old UID on ${new Date().toISOString()}`;

        if (dryRun) {
          console.log(`      [DRY RUN] Would update ${item.docId}:`, Object.keys(updates));
          updatedCount++;
        } else {
          try {
            await docRef.update(updates);
            console.log(`      ✅ Updated ${item.docId}`);
            updatedCount++;
          } catch (error) {
            console.log(`      ❌ Error updating ${item.docId}: ${error.message}`);
            errorCount++;
          }
        }
      }
    }
  }

  console.log(`\n   ${dryRun ? '[DRY RUN] ' : ''}Documents processed: ${updatedCount}`);
  if (errorCount > 0) {
    console.log(`   Errors: ${errorCount}`);
  }
}

/**
 * Print detailed summary
 */
function printSummary() {
  console.log('\n' + '='.repeat(70));
  console.log('📊 AUDIT SUMMARY');
  console.log('='.repeat(70));

  console.log(`\n🎯 Target User: ${TARGET_USER.fullName} (${TARGET_USER.email})`);
  console.log(`📧 Email: ${TARGET_USER.email}`);

  console.log('\n🔑 UIDs Found:');
  if (results.oldUids.size > 0) {
    console.log(`   Old UIDs in data: ${Array.from(results.oldUids).join(', ')}`);
  } else {
    console.log('   No old UIDs found in documents');
  }
  console.log(`   New UID: ${results.newUid || 'NOT FOUND'}`);

  console.log('\n📋 Collections Summary:');
  for (const [collectionName, data] of Object.entries(results.collections)) {
    if (data.found.length > 0) {
      console.log(`\n   📂 ${collectionName}: ${data.found.length} documents`);
      for (const item of data.found.slice(0, 5)) {
        console.log(`      - ${item.docId} (matched by: ${item.matchedBy})`);
        if (item.extractedUid) {
          console.log(`        UID in doc: ${item.extractedUid}`);
        }
      }
      if (data.found.length > 5) {
        console.log(`      ... and ${data.found.length - 5} more`);
      }
    }
  }

  console.log('\n' + '='.repeat(70));
  console.log(`📊 Total documents found: ${results.totalDocuments}`);
  console.log('='.repeat(70));
}

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);
  const executeMode = args.includes('--execute');

  console.log('🔄 User Data Migration Script');
  console.log('='.repeat(70));
  console.log(`Mode: ${executeMode ? '🚀 EXECUTE (will modify data)' : '🔍 DRY RUN (audit only)'}`);
  console.log(`Target: ${TARGET_USER.fullName} <${TARGET_USER.email}>`);
  console.log('='.repeat(70));

  // Phase 1: Scan all collections
  console.log('\n📋 PHASE 1: Scanning collections for matching documents...');
  for (const config of COLLECTIONS_CONFIG) {
    await scanCollection(config);
  }

  // Phase 2: Find the new UID
  console.log('\n📋 PHASE 2: Identifying NEW user account...');
  await findNewUid();

  // Phase 3: Second pass to find documents by old UIDs
  console.log('\n📋 PHASE 3: Second pass scan by old UIDs...');
  await scanByOldUids();

  // Print summary
  printSummary();

  // Phase 4: Migration (or dry run)
  if (results.newUid && results.oldUids.size > 0) {
    const hasOldUidsToMigrate = Array.from(results.oldUids).some(uid => uid !== results.newUid);

    if (hasOldUidsToMigrate) {
      await migrateDocuments(!executeMode);

      if (!executeMode) {
        console.log('\n' + '⚠️'.repeat(35));
        console.log('\n⚠️  This was a DRY RUN. No data was modified.');
        console.log('   To execute the migration, run:');
        console.log('   node scripts/migrate_user_data.js --execute');
        console.log('\n' + '⚠️'.repeat(35));
      } else {
        console.log('\n✅ Migration completed!');
        console.log('   Please verify the data in Firebase Console.');
      }
    } else {
      console.log('\n✅ No migration needed - UIDs already match or no old data found.');
    }
  } else {
    console.log('\n⚠️  Cannot proceed with migration:');
    if (!results.newUid) {
      console.log('   - New UID not found. Make sure the new account exists.');
    }
    if (results.oldUids.size === 0) {
      console.log('   - No old UIDs found in existing documents.');
    }
  }
}

// Run the script
main()
  .then(() => {
    console.log('\n✨ Script completed.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  });

