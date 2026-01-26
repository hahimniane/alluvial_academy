#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEMPLATE_ID = 'tpl_27c00dc8e6b6f766';

async function fixShifts() {
  console.log('Fixing Friday shifts with missing fields...\n');
  
  // Get the template for reference
  const templateDoc = await db.collection('shift_templates').doc(TEMPLATE_ID).get();
  const template = templateDoc.data();
  
  // Get all shifts for this template
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('template_id', '==', TEMPLATE_ID)
    .get();
  
  console.log(`Found ${shiftsSnap.size} shifts to fix\n`);
  
  let fixedCount = 0;
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    
    // Check if missing key display fields
    if (!data.teacher_name || !data.student_names) {
      const updates = {
        teacher_name: 'Asma Mugtiu',
        student_names: ['Fatimah Diallo', 'Rasheed Diallo'],
        auto_generated_name: 'Asma Mugtiu - Quran Studies - Fatimah Diallo, Rasheed Diallo',
        livekit_room_name: `shift_${doc.id}`,
        shift_category: 'teaching',
        teacher_timezone: 'Europe/Istanbul',
        recurrence: 'weekly',
        recurrence_series_id: TEMPLATE_ID,
        enhanced_recurrence: template.enhanced_recurrence,
        series_created_at: template.created_at,
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      await doc.ref.update(updates);
      console.log(`✅ Fixed: ${doc.id}`);
      fixedCount++;
    } else {
      console.log(`⏭️ Already OK: ${doc.id}`);
    }
  }
  
  console.log(`\nFixed ${fixedCount} shifts`);
}

fixShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
