#!/usr/bin/env node
/**
 * Migration Script: Convert all Zoom shifts to LiveKit
 * 
 * This script updates all teaching_shifts and shift_templates that have
 * video_provider: "zoom" to use video_provider: "livekit" instead.
 * 
 * Usage:
 *   # Set your Firebase project credentials first:
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
 *   
 *   # Or use Firebase CLI login:
 *   firebase login
 *   
 *   # Then run:
 *   node functions/scripts/migrate_zoom_to_livekit.js [--dry-run]
 * 
 * Options:
 *   --dry-run    Preview changes without applying them
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin with credentials
function initializeFirebase() {
  if (admin.apps.length > 0) {
    return; // Already initialized
  }

  // Check for --prod flag to determine which project to use
  const args = process.argv.slice(2);
  const isProd = args.includes('--prod');
  const projectId = isProd ? 'alluwal-academy' : 'alluwal-dev';
  
  console.log(`📦 Target project: ${projectId}${isProd ? ' (PRODUCTION)' : ' (development)'}`);

  // Try different credential sources
  const possiblePaths = [
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    path.join(__dirname, '..', 'alluwal-academy-firebase-adminsdk.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json'),
    path.join(__dirname, '..', '..', 'serviceAccountKey.json'),
  ].filter(Boolean);

  for (const credPath of possiblePaths) {
    try {
      if (fs.existsSync(credPath)) {
        const serviceAccount = require(credPath);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: projectId,
        });
        console.log(`✅ Using credentials from: ${credPath}`);
        return;
      }
    } catch (err) {
      // Try next path
    }
  }

  // Fall back to application default credentials with explicit project ID
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: projectId,
    });
    console.log('✅ Using application default credentials');
  } catch (err) {
    console.error('❌ Failed to initialize Firebase. Please set GOOGLE_APPLICATION_CREDENTIALS or login with Firebase CLI.');
    console.error('   Run: export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"');
    process.exit(1);
  }
}

initializeFirebase();

const db = admin.firestore();

const SHIFTS_COLLECTION = 'teaching_shifts';
const TEMPLATES_COLLECTION = 'shift_templates';

async function migrateCollection(collectionName, isDryRun) {
  console.log(`\n📋 Processing ${collectionName}...`);
  
  // Query all documents with video_provider = 'zoom'
  const snapshot = await db.collection(collectionName)
    .where('video_provider', '==', 'zoom')
    .get();
  
  if (snapshot.empty) {
    console.log(`  ✅ No Zoom documents found in ${collectionName}`);
    return { total: 0, updated: 0 };
  }
  
  console.log(`  📊 Found ${snapshot.size} Zoom documents`);
  
  if (isDryRun) {
    console.log(`  🔍 DRY RUN - Would update ${snapshot.size} documents`);
    snapshot.docs.slice(0, 5).forEach(doc => {
      const data = doc.data();
      console.log(`    - ${doc.id} (teacher: ${data.teacher_name || data.teacher_id || 'unknown'})`);
    });
    if (snapshot.size > 5) {
      console.log(`    ... and ${snapshot.size - 5} more`);
    }
    return { total: snapshot.size, updated: 0 };
  }
  
  // Batch update in chunks of 450
  let updated = 0;
  const docs = snapshot.docs;
  
  for (let i = 0; i < docs.length; i += 450) {
    const chunk = docs.slice(i, i + 450);
    const batch = db.batch();
    
    for (const doc of chunk) {
      batch.update(doc.ref, {
        video_provider: 'livekit',
        livekit_room_name: `shift_${doc.id}`,
        // Clear Zoom-specific fields
        zoom_meeting_id: admin.firestore.FieldValue.delete(),
        zoomMeetingId: admin.firestore.FieldValue.delete(),
        zoom_encrypted_join_url: admin.firestore.FieldValue.delete(),
        zoomEncryptedJoinUrl: admin.firestore.FieldValue.delete(),
        zoom_meeting_created_at: admin.firestore.FieldValue.delete(),
        zoom_invite_sent_at: admin.firestore.FieldValue.delete(),
        hubMeetingId: admin.firestore.FieldValue.delete(),
        hub_meeting_id: admin.firestore.FieldValue.delete(),
        breakoutRoomName: admin.firestore.FieldValue.delete(),
        breakout_room_name: admin.firestore.FieldValue.delete(),
        breakoutRoomKey: admin.firestore.FieldValue.delete(),
        breakout_room_key: admin.firestore.FieldValue.delete(),
        zoomRoutingMode: admin.firestore.FieldValue.delete(),
        zoom_routing_mode: admin.firestore.FieldValue.delete(),
        routingRiskParticipants: admin.firestore.FieldValue.delete(),
        preAssignedParticipants: admin.firestore.FieldValue.delete(),
        hasRoutingRisk: admin.firestore.FieldValue.delete(),
        last_modified: admin.firestore.Timestamp.now(),
      });
    }
    
    await batch.commit();
    updated += chunk.length;
    console.log(`  ✏️  Updated ${updated}/${docs.length} documents...`);
  }
  
  console.log(`  ✅ Successfully migrated ${updated} documents in ${collectionName}`);
  return { total: docs.length, updated };
}

async function main() {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  
  console.log('🚀 Zoom to LiveKit Migration Script');
  console.log('====================================');
  
  if (isDryRun) {
    console.log('⚠️  DRY RUN MODE - No changes will be made');
  }
  
  try {
    // Migrate teaching_shifts
    const shiftsResult = await migrateCollection(SHIFTS_COLLECTION, isDryRun);
    
    // Migrate shift_templates
    const templatesResult = await migrateCollection(TEMPLATES_COLLECTION, isDryRun);
    
    console.log('\n📊 Migration Summary');
    console.log('====================');
    console.log(`Teaching Shifts: ${shiftsResult.updated}/${shiftsResult.total} migrated`);
    console.log(`Shift Templates: ${templatesResult.updated}/${templatesResult.total} migrated`);
    
    if (isDryRun) {
      console.log('\n💡 Run without --dry-run to apply changes');
    } else {
      console.log('\n✅ Migration complete!');
    }
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

main();
