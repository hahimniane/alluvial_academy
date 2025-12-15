/**
 * Script de migration directe par UID
 * 
 * Utiliser ce script si vous connaissez déjà l'ancien et le nouvel UID
 * 
 * Utilisation:
 * - Mode audit: node scripts/migrate_user_by_uid.js OLD_UID NEW_UID
 * - Mode exécution: node scripts/migrate_user_by_uid.js OLD_UID NEW_UID --execute
 * 
 * Exemple:
 * node scripts/migrate_user_by_uid.js abc123 xyz789 --execute
 */

const admin = require('firebase-admin');
const path = require('path');

// Get command line arguments
const args = process.argv.slice(2);
const OLD_UID = args[0];
const NEW_UID = args[1];
const EXECUTE_MODE = args.includes('--execute');

if (!OLD_UID || !NEW_UID) {
  console.log('❌ Usage: node scripts/migrate_user_by_uid.js OLD_UID NEW_UID [--execute]');
  console.log('');
  console.log('Example:');
  console.log('  Audit mode:   node scripts/migrate_user_by_uid.js abc123old xyz789new');
  console.log('  Execute mode: node scripts/migrate_user_by_uid.js abc123old xyz789new --execute');
  process.exit(1);
}

if (OLD_UID === NEW_UID) {
  console.log('❌ Old UID and New UID are the same!');
  process.exit(1);
}

// Collections and their UID fields to update
const COLLECTIONS = [
  {
    name: 'teaching_shifts',
    fields: ['teacher_id', 'created_by_admin_id'],
  },
  {
    name: 'timesheet_entries',
    fields: ['teacher_id', 'teacherId'],
  },
  {
    name: 'form_responses',
    fields: ['userId'],
  },
  {
    name: 'form_drafts',
    fields: ['createdBy'],
  },
  {
    name: 'tasks',
    fields: ['createdBy'],
    arrayFields: ['assignedTo'],
  },
  {
    name: 'teacher_profiles',
    fields: ['user_id'],
    docIdIsUid: true,
  },
  {
    name: 'shift_modifications',
    fields: ['modified_by', 'teacher_id'],
  },
  {
    name: 'notifications',
    fields: ['userId', 'recipientId', 'senderId'],
  },
  {
    name: 'chat_messages',
    fields: ['senderId', 'receiverId'],
  },
];

// Initialize Firebase
let db;
try {
  const serviceAccount = require(path.join(__dirname, '../serviceAccountKey.json'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'alluwal-academy',
  });
  db = admin.firestore();
} catch (error) {
  console.error('❌ Failed to initialize Firebase:', error.message);
  process.exit(1);
}

// Stats
const stats = {
  total: 0,
  updated: 0,
  errors: 0,
};

async function migrateCollection(config) {
  console.log(`\n📂 Processing ${config.name}...`);

  let collectionUpdated = 0;
  let collectionErrors = 0;

  try {
    // Query by each field
    for (const field of config.fields) {
      const query = await db.collection(config.name)
        .where(field, '==', OLD_UID)
        .get();

      if (!query.empty) {
        console.log(`   Found ${query.docs.length} documents with ${field}=${OLD_UID}`);

        for (const doc of query.docs) {
          const updates = { [field]: NEW_UID };
          updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
          updates._migrated_from_uid = OLD_UID;
          updates._migrated_at = new Date().toISOString();

          if (EXECUTE_MODE) {
            try {
              await doc.ref.update(updates);
              console.log(`   ✅ Updated ${doc.id}`);
              collectionUpdated++;
            } catch (e) {
              console.log(`   ❌ Error updating ${doc.id}: ${e.message}`);
              collectionErrors++;
            }
          } else {
            console.log(`   [DRY RUN] Would update ${doc.id}: ${field} = ${NEW_UID}`);
            collectionUpdated++;
          }
        }
      }
    }

    // Handle array fields (like assignedTo in tasks)
    if (config.arrayFields) {
      for (const field of config.arrayFields) {
        const query = await db.collection(config.name)
          .where(field, 'array-contains', OLD_UID)
          .get();

        if (!query.empty) {
          console.log(`   Found ${query.docs.length} documents with ${field} containing ${OLD_UID}`);

          for (const doc of query.docs) {
            const data = doc.data();
            const currentArray = data[field] || [];
            const newArray = currentArray.map(id => id === OLD_UID ? NEW_UID : id);

            const updates = {
              [field]: newArray,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
              _migrated_from_uid: OLD_UID,
              _migrated_at: new Date().toISOString(),
            };

            if (EXECUTE_MODE) {
              try {
                await doc.ref.update(updates);
                console.log(`   ✅ Updated ${doc.id} (array field ${field})`);
                collectionUpdated++;
              } catch (e) {
                console.log(`   ❌ Error updating ${doc.id}: ${e.message}`);
                collectionErrors++;
              }
            } else {
              console.log(`   [DRY RUN] Would update ${doc.id}: ${field} array`);
              collectionUpdated++;
            }
          }
        }
      }
    }

    // Handle document ID migration (like teacher_profiles)
    if (config.docIdIsUid) {
      const oldDoc = await db.collection(config.name).doc(OLD_UID).get();

      if (oldDoc.exists) {
        console.log(`   Found document with ID = ${OLD_UID}`);

        if (EXECUTE_MODE) {
          try {
            const data = oldDoc.data();
            // Update UID fields in the data
            for (const field of config.fields) {
              if (data[field] === OLD_UID) {
                data[field] = NEW_UID;
              }
            }
            data._migrated_from_uid = OLD_UID;
            data._migrated_at = new Date().toISOString();

            // Create new document with new UID as ID
            await db.collection(config.name).doc(NEW_UID).set(data);
            // Delete old document
            await oldDoc.ref.delete();

            console.log(`   ✅ Moved document from ${OLD_UID} to ${NEW_UID}`);
            collectionUpdated++;
          } catch (e) {
            console.log(`   ❌ Error migrating document ID: ${e.message}`);
            collectionErrors++;
          }
        } else {
          console.log(`   [DRY RUN] Would move document from ${OLD_UID} to ${NEW_UID}`);
          collectionUpdated++;
        }
      }
    }

  } catch (error) {
    console.log(`   ❌ Error processing collection: ${error.message}`);
    collectionErrors++;
  }

  stats.total += collectionUpdated;
  stats.updated += collectionUpdated;
  stats.errors += collectionErrors;

  if (collectionUpdated === 0) {
    console.log(`   ⚪ No documents found`);
  }
}

async function updateUserDocument() {
  console.log('\n📋 Checking users collection...');

  try {
    // Check if old user document exists
    const oldUserDoc = await db.collection('users').doc(OLD_UID).get();

    if (oldUserDoc.exists) {
      console.log(`   Found old user document (${OLD_UID})`);

      // Check if new user document exists
      const newUserDoc = await db.collection('users').doc(NEW_UID).get();

      if (newUserDoc.exists) {
        console.log(`   New user document (${NEW_UID}) already exists`);
        console.log(`   ⚠️  Will need to merge data manually or delete old document`);

        // Show comparison
        const oldData = oldUserDoc.data();
        const newData = newUserDoc.data();

        console.log('\n   📊 Comparison:');
        console.log(`   Old (${OLD_UID}):`);
        console.log(`      Email: ${oldData['e-mail'] || oldData.email}`);
        console.log(`      Name: ${oldData.first_name} ${oldData.last_name}`);
        console.log(`      Type: ${oldData.user_type}`);
        console.log(`      Active: ${oldData.is_active}`);

        console.log(`   New (${NEW_UID}):`);
        console.log(`      Email: ${newData['e-mail'] || newData.email}`);
        console.log(`      Name: ${newData.first_name} ${newData.last_name}`);
        console.log(`      Type: ${newData.user_type}`);
        console.log(`      Active: ${newData.is_active}`);

        if (EXECUTE_MODE) {
          // Optionally delete old user document
          console.log('\n   🗑️  Deleting old user document...');
          await oldUserDoc.ref.delete();
          console.log(`   ✅ Deleted old user document (${OLD_UID})`);
        } else {
          console.log('\n   [DRY RUN] Would delete old user document');
        }
      } else {
        // Move old user document to new ID
        console.log(`   New user document (${NEW_UID}) does not exist`);

        if (EXECUTE_MODE) {
          const data = oldUserDoc.data();
          data.uid = NEW_UID;
          data._migrated_from_uid = OLD_UID;
          data._migrated_at = new Date().toISOString();

          await db.collection('users').doc(NEW_UID).set(data);
          await oldUserDoc.ref.delete();

          console.log(`   ✅ Moved user document from ${OLD_UID} to ${NEW_UID}`);
        } else {
          console.log(`   [DRY RUN] Would move user document from ${OLD_UID} to ${NEW_UID}`);
        }
      }
    } else {
      console.log(`   Old user document (${OLD_UID}) not found`);
    }
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
  }
}

async function main() {
  console.log('🔄 Direct UID Migration Script');
  console.log('='.repeat(60));
  console.log(`Mode: ${EXECUTE_MODE ? '🚀 EXECUTE' : '🔍 DRY RUN'}`);
  console.log(`Old UID: ${OLD_UID}`);
  console.log(`New UID: ${NEW_UID}`);
  console.log('='.repeat(60));

  // Process user document first
  await updateUserDocument();

  // Process all collections
  for (const config of COLLECTIONS) {
    await migrateCollection(config);
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 SUMMARY');
  console.log('='.repeat(60));
  console.log(`Documents found/updated: ${stats.updated}`);
  console.log(`Errors: ${stats.errors}`);

  if (!EXECUTE_MODE) {
    console.log('\n⚠️  This was a DRY RUN. No data was modified.');
    console.log('   To execute: node scripts/migrate_user_by_uid.js ' + OLD_UID + ' ' + NEW_UID + ' --execute');
  } else {
    console.log('\n✅ Migration completed!');
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });

