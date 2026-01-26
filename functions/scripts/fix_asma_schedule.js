#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

// Specific template IDs found from inspection
const THURSDAY_FGC_TEMPLATE_ID = 'tpl_27c00dc8e6b6f766'; // Rasheed + Fatimah
const HADIATU_TEMPLATE_IDS = [
  'tpl_043131b21cd48a2f', // Sunday 6-7am
  'tpl_ffbe914c091db233', // Saturday 5-6am
];

const DRY_RUN = !process.argv.includes('--apply');

async function fixAsmaSchedule() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to make changes)' : 'APPLYING CHANGES'}\n`);
  console.log('='.repeat(80));
  
  // 1. Fix Thursday -> Friday for Rasheed/Fatimah FGC
  console.log('\n1. Move Rasheed + Fatimah FGC from Thursday to Friday:');
  console.log('   Template: ' + THURSDAY_FGC_TEMPLATE_ID);
  
  const thursdayDoc = await db.collection('shift_templates').doc(THURSDAY_FGC_TEMPLATE_ID).get();
  if (thursdayDoc.exists) {
    const data = thursdayDoc.data();
    const currentWeekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    console.log(`   Current days: [${currentWeekdays}] (4 = Thursday)`);
    console.log(`   New days: [5] (5 = Friday)`);
    console.log(`   Time: ${data.start_time} - ${data.end_time}`);
    
    if (!DRY_RUN) {
      // Update template to Friday
      await db.collection('shift_templates').doc(THURSDAY_FGC_TEMPLATE_ID).update({
        'enhanced_recurrence.selectedWeekdays': [5], // Friday
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('   ✅ Template updated to Friday');
      
      // Delete all existing shifts for this template (they'll regenerate on Friday)
      const shiftsSnap = await db.collection('teaching_shifts')
        .where('template_id', '==', THURSDAY_FGC_TEMPLATE_ID)
        .get();
      
      for (const shiftDoc of shiftsSnap.docs) {
        await shiftDoc.ref.delete();
      }
      console.log(`   ✅ Deleted ${shiftsSnap.size} old shifts (will regenerate on Friday)`);
    }
  } else {
    console.log('   ⚠️ Template not found!');
  }
  
  // 2. Remove Hadiatu templates and shifts
  console.log('\n2. Remove Hadiatu Diallo classes:');
  
  for (const templateId of HADIATU_TEMPLATE_IDS) {
    console.log(`\n   Template: ${templateId}`);
    
    const tplDoc = await db.collection('shift_templates').doc(templateId).get();
    if (tplDoc.exists) {
      const data = tplDoc.data();
      console.log(`   Days: ${data.enhanced_recurrence?.selectedWeekdays}`);
      console.log(`   Time: ${data.start_time} - ${data.end_time}`);
      
      if (!DRY_RUN) {
        // Deactivate template
        await db.collection('shift_templates').doc(templateId).update({
          is_active: false,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('   ✅ Template deactivated');
        
        // Delete all shifts for this template
        const shiftsSnap = await db.collection('teaching_shifts')
          .where('template_id', '==', templateId)
          .get();
        
        for (const shiftDoc of shiftsSnap.docs) {
          await shiftDoc.ref.delete();
        }
        console.log(`   ✅ Deleted ${shiftsSnap.size} shifts`);
      }
    } else {
      console.log('   ⚠️ Template not found!');
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
    console.log('- Rasheed + Fatimah FGC moved from Thursday to Friday');
    console.log('- Hadiatu Diallo classes removed');
    console.log('- New Friday shifts will generate automatically via daily scheduled function');
  }
}

fixAsmaSchedule()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
