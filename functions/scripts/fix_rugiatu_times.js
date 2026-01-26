#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEMPLATES_TO_FIX = [
  { id: 'tpl_874363d2afe65f70', day: 'Saturday' },
  { id: 'tpl_f3a686a6393e8c3a', day: 'Sunday' },
];

const DRY_RUN = !process.argv.includes('--apply');

async function fixTimes() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to make changes)' : 'APPLYING CHANGES'}\n`);
  console.log('='.repeat(80));
  console.log('FIXING RUGIATU SATURDAY/SUNDAY TIMES');
  console.log('='.repeat(80));
  
  for (const tpl of TEMPLATES_TO_FIX) {
    console.log(`\n${tpl.day} Template: ${tpl.id}`);
    
    const doc = await db.collection('shift_templates').doc(tpl.id).get();
    if (!doc.exists) {
      console.log('  ❌ Template not found!');
      continue;
    }
    
    const data = doc.data();
    console.log(`  Current time: ${data.start_time} - ${data.end_time} (${data.admin_timezone})`);
    console.log(`  Current in Saudi: 6:00 AM - 7:00 AM ❌`);
    console.log(`  New time: 10:00 - 11:00 (${data.admin_timezone})`);
    console.log(`  New in Saudi: 6:00 PM - 7:00 PM ✅`);
    
    if (!DRY_RUN) {
      // Update template time
      await db.collection('shift_templates').doc(tpl.id).update({
        start_time: '10:00',
        end_time: '11:00',
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('  ✅ Template updated');
      
      // Delete all existing shifts for this template (they'll regenerate with correct time)
      const shiftsSnap = await db.collection('teaching_shifts')
        .where('template_id', '==', tpl.id)
        .get();
      
      for (const shiftDoc of shiftsSnap.docs) {
        await shiftDoc.ref.delete();
      }
      console.log(`  ✅ Deleted ${shiftsSnap.size} old shifts (will regenerate with correct time)`);
    }
  }
  
  if (DRY_RUN) {
    console.log('\n' + '='.repeat(80));
    console.log('DRY RUN COMPLETE - No changes made');
    console.log('Run with --apply to make these changes');
    console.log('='.repeat(80));
  } else {
    console.log('\n' + '='.repeat(80));
    console.log('✅ ALL CHANGES APPLIED');
    console.log('='.repeat(80));
    console.log('\nSummary:');
    console.log('- Rugiatu Saturday: 10:00 PM NYC → 10:00 AM NYC (6:00 PM Saudi)');
    console.log('- Rugiatu Sunday: 10:00 PM NYC → 10:00 AM NYC (6:00 PM Saudi)');
    console.log('- Old shifts deleted, new shifts will regenerate automatically');
  }
}

fixTimes()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
