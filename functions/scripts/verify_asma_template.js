#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEACHER_ID = 'eBtOThyk0rOwCXYey4kPfEpNxdT2'; // Asma Mugtiu
const FGC_TEMPLATE_ID = 'tpl_27c00dc8e6b6f766'; // Rasheed + Fatimah

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

async function verifyTemplates() {
  console.log('='.repeat(80));
  console.log('VERIFYING ASMA MUGTIU TEMPLATES');
  console.log('='.repeat(80));
  
  // 1. Check the FGC template (Rasheed + Fatimah) is on Friday
  console.log('\n1. FGC Template (Rasheed + Fatimah):');
  const fgcDoc = await db.collection('shift_templates').doc(FGC_TEMPLATE_ID).get();
  
  if (fgcDoc.exists) {
    const data = fgcDoc.data();
    const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    const dayNames = weekdays.map(d => DAY_NAMES[d]).join(', ');
    
    console.log(`   Template ID: ${FGC_TEMPLATE_ID}`);
    console.log(`   is_active: ${data.is_active}`);
    console.log(`   selectedWeekdays: [${weekdays}] = ${dayNames}`);
    console.log(`   Time: ${data.start_time} - ${data.end_time} (${data.admin_timezone})`);
    console.log(`   Students: ${data.student_ids?.length || 0}`);
    
    if (weekdays.includes(5) && !weekdays.includes(4)) {
      console.log('   ✅ CORRECT: Template is set to FRIDAY only');
    } else if (weekdays.includes(4)) {
      console.log('   ❌ ERROR: Template still has THURSDAY!');
    } else {
      console.log('   ⚠️ WARNING: Unexpected weekdays');
    }
  } else {
    console.log('   ❌ Template not found!');
  }
  
  // 2. Check Hadiatu templates are deactivated
  console.log('\n2. Hadiatu Templates (should be deactivated):');
  const hadiatuTemplates = ['tpl_043131b21cd48a2f', 'tpl_ffbe914c091db233'];
  
  for (const tplId of hadiatuTemplates) {
    const doc = await db.collection('shift_templates').doc(tplId).get();
    if (doc.exists) {
      const data = doc.data();
      if (data.is_active === false) {
        console.log(`   ✅ ${tplId}: DEACTIVATED (won't generate shifts)`);
      } else {
        console.log(`   ❌ ${tplId}: STILL ACTIVE! This will generate Hadiatu shifts!`);
      }
    }
  }
  
  // 3. List all active templates for Asma
  console.log('\n3. All Active Templates for Asma:');
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', TEACHER_ID)
    .where('is_active', '==', true)
    .get();
  
  console.log(`   Total active templates: ${templatesSnap.size}`);
  
  const templatesByDay = new Map();
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    
    for (const day of weekdays) {
      if (!templatesByDay.has(day)) {
        templatesByDay.set(day, []);
      }
      templatesByDay.get(day).push({
        id: doc.id,
        time: `${data.start_time}-${data.end_time}`,
        students: data.student_ids?.length || 0,
      });
    }
  }
  
  // Sort by day
  const sortedDays = [...templatesByDay.keys()].sort((a, b) => a - b);
  
  for (const day of sortedDays) {
    const dayName = DAY_NAMES[day];
    const templates = templatesByDay.get(day);
    console.log(`\n   ${dayName} (${day}):`);
    for (const tpl of templates) {
      console.log(`     - ${tpl.time} (${tpl.students} students) [${tpl.id}]`);
    }
  }
  
  // 4. Check for any Thursday templates
  console.log('\n4. Thursday Check:');
  let hasThursday = false;
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    if (weekdays.includes(4)) {
      hasThursday = true;
      console.log(`   ❌ Found Thursday template: ${doc.id}`);
    }
  }
  if (!hasThursday) {
    console.log('   ✅ No Thursday templates - automatic generation will NOT create Thursday shifts');
  }
  
  // 5. Check for any Hadiatu student in active templates
  console.log('\n5. Hadiatu Student Check:');
  const HADIATU_UID = 'jjA24y3yRYRJKozIUKfHvcKNoGX2';
  let hasHadiatu = false;
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    if (data.student_ids?.includes(HADIATU_UID)) {
      hasHadiatu = true;
      console.log(`   ❌ Found Hadiatu in template: ${doc.id}`);
    }
  }
  if (!hasHadiatu) {
    console.log('   ✅ Hadiatu not in any active template - automatic generation will NOT create her shifts');
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('VERIFICATION COMPLETE');
  console.log('='.repeat(80));
  
  if (!hasThursday && !hasHadiatu) {
    console.log('\n✅ ALL GOOD: Automatic shift generation will work correctly!');
    console.log('   - No Thursday shifts will be created');
    console.log('   - No Hadiatu shifts will be created');
    console.log('   - Friday FGC (Rasheed + Fatimah) will generate correctly');
  } else {
    console.log('\n⚠️ ISSUES FOUND - Please review above');
  }
}

verifyTemplates()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
