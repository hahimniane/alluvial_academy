#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const DRY_RUN = !process.argv.includes('--apply');

async function deleteOldShifts() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to delete)' : 'DELETING SHIFTS'}\n`);
  console.log('='.repeat(80));
  console.log('FINDING SHIFTS WITHOUT TEMPLATES...\n');
  
  // Get all scheduled shifts without template_id
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('status', '==', 'scheduled')
    .get();
  
  const shiftsWithoutTemplate = [];
  const shiftsByTeacher = new Map();
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    
    // Check if no template_id
    if (!data.template_id) {
      shiftsWithoutTemplate.push({
        id: doc.id,
        teacherId: data.teacher_id,
        teacherName: data.teacher_name,
        studentNames: data.student_names,
        shiftStart: data.shift_start?.toDate(),
      });
      
      const teacherName = data.teacher_name || data.teacher_id || 'Unknown';
      if (!shiftsByTeacher.has(teacherName)) {
        shiftsByTeacher.set(teacherName, []);
      }
      shiftsByTeacher.get(teacherName).push(doc.id);
    }
  }
  
  console.log(`Total scheduled shifts: ${shiftsSnap.size}`);
  console.log(`Shifts WITHOUT template_id: ${shiftsWithoutTemplate.length}\n`);
  
  // Summary by teacher
  console.log('SHIFTS WITHOUT TEMPLATES BY TEACHER:\n');
  
  for (const [teacher, shiftIds] of [...shiftsByTeacher.entries()].sort()) {
    console.log(`  ${teacher}: ${shiftIds.length} shifts`);
  }
  
  console.log('\n' + '='.repeat(80));
  
  if (shiftsWithoutTemplate.length === 0) {
    console.log('✅ No shifts without templates found. Nothing to delete.');
    return;
  }
  
  if (DRY_RUN) {
    console.log('\nDRY RUN - No shifts deleted');
    console.log('Run with --apply to delete these shifts');
    console.log('\n⚠️ WARNING: This will delete ' + shiftsWithoutTemplate.length + ' shifts!');
  } else {
    console.log('\nDELETING SHIFTS...\n');
    
    let deletedCount = 0;
    let errorCount = 0;
    
    for (const shift of shiftsWithoutTemplate) {
      try {
        await db.collection('teaching_shifts').doc(shift.id).delete();
        deletedCount++;
        
        if (deletedCount % 10 === 0) {
          console.log(`  Deleted ${deletedCount}/${shiftsWithoutTemplate.length}...`);
        }
      } catch (e) {
        console.error(`  Error deleting ${shift.id}: ${e.message}`);
        errorCount++;
      }
    }
    
    console.log('\n' + '='.repeat(80));
    console.log(`\n✅ DONE!`);
    console.log(`  Deleted: ${deletedCount} shifts`);
    console.log(`  Errors: ${errorCount}`);
  }
}

deleteOldShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
