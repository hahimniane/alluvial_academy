/**
 * Script de migration COMPLETE pour ALIOU DIALLO
 * 
 * Ce script migre TOUS les champs contenant l'ancien UID dans toutes les collections
 * 
 * Usage:
 * - Audit: node scripts/complete_migration_aliou.js
 * - Execute: node scripts/complete_migration_aliou.js --execute
 */

const admin = require('firebase-admin');
const path = require('path');

const OLD_UID = 'E72q1gYxDSMKA8Kwf4eBgII4XI72';
const NEW_UID = 'Thz8PIVUGpS5cjlIYBJAemjoQxw1';

// Collections et tous les champs qui peuvent contenir des UIDs
const COLLECTIONS_CONFIG = [
  {
    name: 'teaching_shifts',
    fields: ['teacher_id', 'created_by_admin_id', 'original_teacher_id', 'published_by', 'teacher_modified_by'],
    arrayFields: ['student_ids'],
  },
  {
    name: 'timesheet_entries',
    fields: ['teacher_id', 'teacherId', 'edited_by', 'approved_by', 'created_by'],
  },
  {
    name: 'form_responses',
    fields: ['userId', 'user_id', 'submittedBy'],
  },
  {
    name: 'form_drafts',
    fields: ['createdBy', 'userId'],
  },
  {
    name: 'tasks',
    fields: ['createdBy', 'completedBy'],
    arrayFields: ['assignedTo'],
  },
  {
    name: 'teacher_profiles',
    fields: ['user_id', 'userId'],
    docIdIsUid: true,
  },
  {
    name: 'chats',
    arrayFields: ['participants'],
    docIdContainsUid: true,
  },
  {
    name: 'chat_messages',
    fields: ['senderId', 'receiverId', 'sender_id', 'receiver_id'],
  },
  {
    name: 'notifications',
    fields: ['userId', 'recipientId', 'senderId', 'user_id'],
  },
  {
    name: 'assignments',
    fields: ['teacher_id', 'student_id', 'created_by', 'graded_by'],
    nestedFields: ['attachments.uploadedBy'],
  },
  {
    name: 'enrollments',
    fields: ['userId', 'teacher_id', 'assigned_teacher_id'],
    nestedFields: ['metadata.assignedBy', 'metadata.createdBy'],
  },
  {
    name: 'shift_modifications',
    fields: ['teacher_id', 'modified_by', 'original_teacher_id'],
  },
  {
    name: 'schedule_issue_reports',
    fields: ['reporter_id', 'teacher_id', 'resolved_by'],
  },
  {
    name: 'contact_messages',
    fields: ['userId'],
  },
  {
    name: 'teacher_applications',
    fields: ['userId'],
  },
  {
    name: 'job_opportunities',
    fields: ['created_by', 'accepted_by', 'teacher_id'],
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
  console.log('✅ Firebase Admin initialized\n');
} catch (error) {
  console.error('❌ Failed to initialize Firebase:', error.message);
  process.exit(1);
}

const args = process.argv.slice(2);
const EXECUTE_MODE = args.includes('--execute');

// Stats
const stats = {
  scanned: 0,
  found: 0,
  updated: 0,
  errors: 0,
};

/**
 * Replace OLD_UID with NEW_UID in any value (string, array, or nested object)
 */
function replaceUidInValue(value) {
  if (typeof value === 'string') {
    if (value === OLD_UID) return NEW_UID;
    if (value.includes(OLD_UID)) return value.replace(new RegExp(OLD_UID, 'g'), NEW_UID);
    return value;
  }
  
  if (Array.isArray(value)) {
    return value.map(item => replaceUidInValue(item));
  }
  
  if (value && typeof value === 'object' && !(value instanceof admin.firestore.Timestamp)) {
    const newObj = {};
    for (const [key, val] of Object.entries(value)) {
      newObj[key] = replaceUidInValue(val);
    }
    return newObj;
  }
  
  return value;
}

/**
 * Process a single collection
 */
async function processCollection(config) {
  console.log(`\n📂 Processing ${config.name}...`);
  
  let collectionFound = 0;
  let collectionUpdated = 0;
  
  try {
    const snapshot = await db.collection(config.name).get();
    stats.scanned += snapshot.size;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const jsonStr = JSON.stringify(data);
      
      // Check if this document contains the OLD_UID
      if (!jsonStr.includes(OLD_UID)) continue;
      
      collectionFound++;
      stats.found++;
      
      // Find all fields that need updating
      const updates = {};
      
      // Check regular fields
      if (config.fields) {
        for (const field of config.fields) {
          if (data[field] === OLD_UID) {
            updates[field] = NEW_UID;
          }
        }
      }
      
      // Check array fields
      if (config.arrayFields) {
        for (const field of config.arrayFields) {
          if (Array.isArray(data[field]) && data[field].includes(OLD_UID)) {
            updates[field] = data[field].map(id => id === OLD_UID ? NEW_UID : id);
          }
        }
      }
      
      // Check nested fields (like attachments.uploadedBy)
      if (config.nestedFields) {
        for (const nestedPath of config.nestedFields) {
          const parts = nestedPath.split('.');
          const parentField = parts[0];
          const childField = parts[1];
          
          if (Array.isArray(data[parentField])) {
            let needsUpdate = false;
            const newArray = data[parentField].map(item => {
              if (item && item[childField] === OLD_UID) {
                needsUpdate = true;
                return { ...item, [childField]: NEW_UID };
              }
              return item;
            });
            if (needsUpdate) {
              updates[parentField] = newArray;
            }
          } else if (data[parentField] && data[parentField][childField] === OLD_UID) {
            updates[parentField] = { ...data[parentField], [childField]: NEW_UID };
          }
        }
      }
      
      // Handle any remaining fields with OLD_UID that weren't explicitly configured
      for (const [key, value] of Object.entries(data)) {
        if (updates[key]) continue; // Already handled
        
        const valueStr = JSON.stringify(value);
        if (valueStr && valueStr.includes(OLD_UID)) {
          const newValue = replaceUidInValue(value);
          if (JSON.stringify(newValue) !== valueStr) {
            updates[key] = newValue;
          }
        }
      }
      
      if (Object.keys(updates).length > 0) {
        updates._migration_complete = new Date().toISOString();
        
        if (EXECUTE_MODE) {
          try {
            await doc.ref.update(updates);
            console.log(`   ✅ Updated ${doc.id} (${Object.keys(updates).filter(k => !k.startsWith('_')).join(', ')})`);
            collectionUpdated++;
            stats.updated++;
          } catch (e) {
            console.log(`   ❌ Error updating ${doc.id}: ${e.message}`);
            stats.errors++;
          }
        } else {
          console.log(`   [DRY RUN] Would update ${doc.id}: ${Object.keys(updates).filter(k => !k.startsWith('_')).join(', ')}`);
          collectionUpdated++;
        }
      }
      
      // Handle document ID containing OLD_UID (like chats)
      if (config.docIdContainsUid && doc.id.includes(OLD_UID)) {
        const newDocId = doc.id.replace(new RegExp(OLD_UID, 'g'), NEW_UID);
        console.log(`   ⚠️  Document ID contains OLD_UID: ${doc.id}`);
        console.log(`      Would need to create: ${newDocId} and delete old`);
        
        if (EXECUTE_MODE) {
          try {
            // Create new document with updated ID
            const newData = replaceUidInValue(data);
            newData._migrated_from_doc_id = doc.id;
            newData._migration_complete = new Date().toISOString();
            
            await db.collection(config.name).doc(newDocId).set(newData);
            await doc.ref.delete();
            console.log(`   ✅ Moved document from ${doc.id} to ${newDocId}`);
            stats.updated++;
          } catch (e) {
            console.log(`   ❌ Error moving document: ${e.message}`);
            stats.errors++;
          }
        }
      }
    }
    
    if (collectionFound > 0) {
      console.log(`   Found: ${collectionFound}, ${EXECUTE_MODE ? 'Updated' : 'Would update'}: ${collectionUpdated}`);
    } else {
      console.log(`   No documents with OLD_UID found`);
    }
    
  } catch (e) {
    if (!e.message.includes('NOT_FOUND')) {
      console.log(`   ❌ Error: ${e.message}`);
    }
  }
}

async function main() {
  console.log('🔄 Complete Migration Script for ALIOU DIALLO');
  console.log('='.repeat(60));
  console.log(`Mode: ${EXECUTE_MODE ? '🚀 EXECUTE' : '🔍 DRY RUN'}`);
  console.log(`Old UID: ${OLD_UID}`);
  console.log(`New UID: ${NEW_UID}`);
  console.log('='.repeat(60));
  
  // Process all collections
  for (const config of COLLECTIONS_CONFIG) {
    await processCollection(config);
  }
  
  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 SUMMARY');
  console.log('='.repeat(60));
  console.log(`Documents scanned: ${stats.scanned}`);
  console.log(`Documents with OLD_UID: ${stats.found}`);
  console.log(`Documents ${EXECUTE_MODE ? 'updated' : 'to update'}: ${stats.updated}`);
  console.log(`Errors: ${stats.errors}`);
  
  if (!EXECUTE_MODE && stats.found > 0) {
    console.log('\n⚠️  This was a DRY RUN. No data was modified.');
    console.log('   To execute: node scripts/complete_migration_aliou.js --execute');
  } else if (EXECUTE_MODE && stats.updated > 0) {
    console.log('\n✅ Migration completed!');
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });

