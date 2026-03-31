#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';
const MAX_DAYS_AHEAD = 70;

const TEACHER_UID = 'xxKjtk7NSNUWDXO268UOgK27z1E2'; // Arabieu Bah
const STUDENT_CODE = '1mariam.diallo';

const DRY_RUN = !process.argv.includes('--apply');

async function fixTime() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to fix)' : 'APPLYING FIXES'}\n`);
  console.log('='.repeat(80));
  
  // 1. Find student
  console.log('1. Finding student: 1mariam.diallo...\n');
  
  const studentsSnap = await db.collection('users')
    .where('user_type', '==', 'student')
    .get();
  
  let student = null;
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const code = data.student_code || data.studentId || data.student_id;
    
    if (code === STUDENT_CODE) {
      student = {
        uid: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        code: code,
      };
      break;
    }
  }
  
  if (!student) {
    console.log('❌ Student not found!');
    return;
  }
  
  console.log(`✅ Found: ${student.name} (${student.code})`);
  console.log(`   UID: ${student.uid}\n`);
  
  // 2. Find Friday template with 5:30 PM - 6:30 PM
  console.log('='.repeat(80));
  console.log('2. Finding Friday template with 5:30 PM - 6:30 PM...\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', TEACHER_UID)
    .where('is_active', '==', true)
    .get();
  
  let templateToFix = null;
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    
    // Check if Friday (5) and has the student
    if (weekdays.includes(5) && data.student_ids?.includes(student.uid)) {
      console.log(`   Template: ${doc.id}`);
      console.log(`   Time: ${data.start_time} - ${data.end_time}`);
      console.log(`   Student: ${data.student_names?.join(', ')}`);
      
      if (data.start_time === '17:30' && data.end_time === '18:30') {
        templateToFix = {
          id: doc.id,
          data: data,
        };
        console.log(`   ✅ This is the template to fix!\n`);
      }
    }
  }
  
  if (!templateToFix) {
    console.log('\n❌ Template not found!');
    return;
  }
  
  // 3. Get teacher info
  const teacherDoc = await db.collection('users').doc(TEACHER_UID).get();
  const teacherData = teacherDoc.data();
  const teacher = {
    uid: TEACHER_UID,
    name: `${teacherData.first_name} ${teacherData.last_name}`,
    timezone: teacherData.timezone || NYC_TZ,
  };
  
  // 4. Update template and regenerate shifts
  if (!DRY_RUN) {
    console.log('='.repeat(80));
    console.log('3. Updating template and regenerating shifts...\n');
    
    // Update template time
    await db.collection('shift_templates').doc(templateToFix.id).update({
      start_time: '17:00',
      end_time: '18:00',
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`   ✅ Updated template time: 17:00 - 18:00 (5:00 PM - 6:00 PM)`);
    
    // Delete old shifts
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('template_id', '==', templateToFix.id)
      .get();
    
    for (const shiftDoc of shiftsSnap.docs) {
      await shiftDoc.ref.delete();
    }
    
    console.log(`   ✅ Deleted ${shiftsSnap.size} old shifts`);
    
    // Regenerate shifts
    const template = templateToFix.data;
    const selectedWeekdays = template.enhanced_recurrence?.selectedWeekdays || [];
    
    const nowLocal = DateTime.now().setZone(NYC_TZ);
    const endDate = nowLocal.plus({ days: MAX_DAYS_AHEAD });
    let currentDate = nowLocal.startOf('day');
    let shiftsCreated = 0;
    
    while (currentDate <= endDate) {
      const luxonDay = currentDate.weekday;
      
      if (selectedWeekdays.includes(luxonDay)) {
        const shiftStart = currentDate.set({ hour: 17, minute: 0, second: 0 });
        const shiftEnd = currentDate.set({ hour: 18, minute: 0, second: 0 });
        
        if (shiftStart > nowLocal) {
          const shiftId = `tpl_${templateToFix.id}_${Math.floor(shiftStart.toMillis() / 1000)}`;
          
          const shiftData = {
            id: shiftId,
            template_id: templateToFix.id,
            teacher_id: teacher.uid,
            teacher_name: teacher.name,
            student_ids: template.student_ids,
            student_names: template.student_names,
            shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
            shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
            duration_minutes: 60,
            status: 'scheduled',
            video_provider: 'livekit',
            livekit_room_name: `shift_${shiftId}`,
            subject: template.subject,
            subject_display_name: template.subject_display_name,
            hourly_rate: template.hourly_rate,
            notes: template.notes,
            admin_timezone: NYC_TZ,
            teacher_timezone: teacher.timezone,
            shift_category: 'teaching',
            auto_generated_name: `${teacher.name} - ${template.subject_display_name || template.subject} - ${template.student_names?.join(', ')}`,
            recurrence: 'weekly',
            recurrence_series_id: templateToFix.id,
            enhanced_recurrence: template.enhanced_recurrence,
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
    
    console.log(`   ✅ Created ${shiftsCreated} new shifts with correct time`);
  }
  
  // Summary
  console.log('\n' + '='.repeat(80));
  
  if (DRY_RUN) {
    console.log('\nDRY RUN COMPLETE - No changes made');
    console.log('Run with --apply to fix');
  } else {
    console.log('\n✅ DONE!');
    console.log(`\nChanged ${student.name} Friday class with Arabieu Bah:`);
    console.log(`  From: 5:30 PM - 6:30 PM NYC`);
    console.log(`  To:   5:00 PM - 6:00 PM NYC`);
  }
}

fixTime()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
