#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const WRONG_STUDENT_CODE = 'abubakar.diallo';
const CORRECT_STUDENT_CODE = 'boubacar.diallo';
const MAX_DAYS_AHEAD = 70;

const DRY_RUN = !process.argv.includes('--apply');

async function fixStudent() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to fix)' : 'APPLYING FIXES'}\n`);
  console.log('='.repeat(80));
  
  // 1. Find Ibrahim Baldee
  console.log('1. Finding Ibrahim Baldee...\n');
  
  const teachersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  
  let ibrahimBaldee = null;
  
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim().toLowerCase();
    
    if (fullName.includes('ibrahim') && fullName.includes('baldee')) {
      ibrahimBaldee = {
        uid: doc.id,
        name: `${data.first_name} ${data.last_name}`,
        timezone: data.timezone || 'America/New_York',
      };
      break;
    }
  }
  
  if (!ibrahimBaldee) {
    console.log('❌ Ibrahim Baldee not found!');
    return;
  }
  
  console.log(`✅ Found: ${ibrahimBaldee.name}`);
  console.log(`   UID: ${ibrahimBaldee.uid}\n`);
  
  // 2. Find both students
  console.log('2. Finding students...\n');
  
  const studentsSnap = await db.collection('users')
    .where('user_type', '==', 'student')
    .get();
  
  let wrongStudent = null;
  let correctStudent = null;
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const code = data.student_code || data.studentId || data.student_id;
    
    if (code === WRONG_STUDENT_CODE) {
      wrongStudent = {
        uid: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        code: code,
      };
    }
    
    if (code === CORRECT_STUDENT_CODE) {
      correctStudent = {
        uid: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        code: code,
      };
    }
  }
  
  console.log(`Wrong student (to replace): ${wrongStudent ? `${wrongStudent.name} (${wrongStudent.code}) - UID: ${wrongStudent.uid}` : 'NOT FOUND'}`);
  console.log(`Correct student: ${correctStudent ? `${correctStudent.name} (${correctStudent.code}) - UID: ${correctStudent.uid}` : 'NOT FOUND'}\n`);
  
  if (!wrongStudent) {
    console.log('❌ Wrong student not found!');
    return;
  }
  
  if (!correctStudent) {
    console.log('❌ Correct student not found!');
    return;
  }
  
  // 3. Find templates with the wrong student
  console.log('='.repeat(80));
  console.log('3. Finding templates with wrong student...\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', ibrahimBaldee.uid)
    .where('is_active', '==', true)
    .get();
  
  const templatesToFix = [];
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    
    if (data.student_ids && data.student_ids.includes(wrongStudent.uid)) {
      const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
      templatesToFix.push({
        id: doc.id,
        days: weekdays,
        time: `${data.start_time} - ${data.end_time}`,
        data: data,
      });
      
      console.log(`   Template: ${doc.id}`);
      console.log(`   Days: ${weekdays}`);
      console.log(`   Time: ${data.start_time} - ${data.end_time}`);
      console.log(`   Current student: ${wrongStudent.name} (${wrongStudent.code})`);
      console.log(`   Will change to: ${correctStudent.name} (${correctStudent.code})`);
      console.log('');
    }
  }
  
  console.log(`\nFound ${templatesToFix.length} templates to fix.\n`);
  
  if (templatesToFix.length === 0) {
    console.log('✅ No templates need fixing.');
    return;
  }
  
  // 4. Fix templates and regenerate shifts
  if (!DRY_RUN) {
    console.log('='.repeat(80));
    console.log('4. Fixing templates and regenerating shifts...\n');
    
    for (const template of templatesToFix) {
      // Update student in template
      const newStudentIds = template.data.student_ids.map(id => 
        id === wrongStudent.uid ? correctStudent.uid : id
      );
      const newStudentNames = [correctStudent.name];
      
      await db.collection('shift_templates').doc(template.id).update({
        student_ids: newStudentIds,
        student_names: newStudentNames,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`   ✅ Updated template: ${template.id}`);
      
      // Delete old shifts for this template
      const shiftsSnap = await db.collection('teaching_shifts')
        .where('template_id', '==', template.id)
        .get();
      
      for (const shiftDoc of shiftsSnap.docs) {
        await shiftDoc.ref.delete();
      }
      
      console.log(`   ✅ Deleted ${shiftsSnap.size} old shifts`);
      
      // Regenerate shifts with correct student
      const updatedTemplateDoc = await db.collection('shift_templates').doc(template.id).get();
      const updatedTemplate = updatedTemplateDoc.data();
      
      const selectedWeekdays = updatedTemplate.enhanced_recurrence?.selectedWeekdays || [];
      const adminTz = updatedTemplate.admin_timezone || 'America/New_York';
      
      const nowLocal = DateTime.now().setZone(adminTz);
      const endDate = nowLocal.plus({ days: MAX_DAYS_AHEAD });
      let currentDate = nowLocal.startOf('day');
      let shiftsCreated = 0;
      
      while (currentDate <= endDate) {
        const luxonDay = currentDate.weekday;
        
        if (selectedWeekdays.includes(luxonDay)) {
          const [startHour, startMin] = updatedTemplate.start_time.split(':').map(Number);
          const [endHour, endMin] = updatedTemplate.end_time.split(':').map(Number);
          
          const shiftStart = currentDate.set({ hour: startHour, minute: startMin, second: 0 });
          const shiftEnd = currentDate.set({ hour: endHour, minute: endMin, second: 0 });
          
          if (shiftStart >= DateTime.now().setZone(adminTz)) {
            const shiftId = `tpl_${template.id}_${Math.floor(shiftStart.toMillis() / 1000)}`;
            
            const shiftData = {
              id: shiftId,
              template_id: template.id,
              teacher_id: ibrahimBaldee.uid,
              teacher_name: ibrahimBaldee.name,
              student_ids: newStudentIds,
              student_names: newStudentNames,
              shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
              shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
              duration_minutes: updatedTemplate.duration_minutes,
              status: 'scheduled',
              video_provider: 'livekit',
              livekit_room_name: `shift_${shiftId}`,
              subject: updatedTemplate.subject,
              subject_display_name: updatedTemplate.subject_display_name,
              hourly_rate: updatedTemplate.hourly_rate,
              notes: updatedTemplate.notes,
              admin_timezone: adminTz,
              teacher_timezone: ibrahimBaldee.timezone,
              shift_category: 'teaching',
              auto_generated_name: `${ibrahimBaldee.name} - ${updatedTemplate.subject_display_name || updatedTemplate.subject} - ${newStudentNames.join(', ')}`,
              recurrence: 'weekly',
              recurrence_series_id: template.id,
              enhanced_recurrence: updatedTemplate.enhanced_recurrence,
              generated_from_template: true,
              created_at: admin.firestore.FieldValue.serverTimestamp(),
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
              last_modified: admin.firestore.FieldValue.serverTimestamp(),
            };
            
            await db.collection('teaching_shifts').doc(shiftId).set(shiftData);
            shiftsCreated++;
          }
        }
        
        currentDate = currentDate.plus({ days: 1 });
      }
      
      console.log(`   ✅ Created ${shiftsCreated} new shifts with correct student\n`);
    }
  }
  
  // Summary
  console.log('='.repeat(80));
  
  if (DRY_RUN) {
    console.log('\nDRY RUN COMPLETE - No changes made');
    console.log('Run with --apply to fix these templates');
  } else {
    console.log('\n✅ DONE!');
    console.log(`\nFixed ${templatesToFix.length} templates:`);
    console.log(`  Changed: ${wrongStudent.name} (${wrongStudent.code})`);
    console.log(`  To: ${correctStudent.name} (${correctStudent.code})`);
  }
}

fixStudent()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
