#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';
const MAX_DAYS_AHEAD = 70;

const DRY_RUN = !process.argv.includes('--apply');

async function fixTime() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to fix)' : 'APPLYING FIXES'}\n`);
  console.log('='.repeat(80));
  
  // 1. Find Arabieu Bah
  console.log('1. Finding teacher: Arabieu Bah...\n');
  
  const teachersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  
  let teacher = null;
  
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim().toLowerCase();
    
    if (fullName.includes('arabieu') || (fullName.includes('bah') && fullName.includes('arab'))) {
      teacher = {
        uid: doc.id,
        name: `${data.first_name} ${data.last_name}`,
        timezone: data.timezone || NYC_TZ,
      };
      break;
    }
  }
  
  if (!teacher) {
    // Try broader search
    for (const doc of teachersSnap.docs) {
      const data = doc.data();
      const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim().toLowerCase();
      if (fullName.includes('bah')) {
        console.log(`   Found teacher with 'Bah': ${data.first_name} ${data.last_name} (${doc.id})`);
      }
    }
    console.log('\n❌ Arabieu Bah not found!');
    return;
  }
  
  console.log(`✅ Found: ${teacher.name}`);
  console.log(`   UID: ${teacher.uid}\n`);
  
  // 2. Find student
  console.log('='.repeat(80));
  console.log('2. Finding student: 1mariam.diallo or 1mariama.diallo...\n');
  
  const studentsSnap = await db.collection('users')
    .where('user_type', '==', 'student')
    .get();
  
  let student = null;
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const code = data.student_code || data.studentId || data.student_id;
    
    if (code === '1mariam.diallo' || code === '1mariama.diallo') {
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
  
  // 3. Find template for Friday with old time
  console.log('='.repeat(80));
  console.log('3. Finding Friday template with 5:30 PM - 6:30 PM...\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', teacher.uid)
    .where('is_active', '==', true)
    .get();
  
  let templateToFix = null;
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    
    // Check if this template has the student and is on Friday (5)
    if (data.student_ids?.includes(student.uid) && weekdays.includes(5)) {
      console.log(`   Found template: ${doc.id}`);
      console.log(`   Current time: ${data.start_time} - ${data.end_time}`);
      console.log(`   Days: ${weekdays}`);
      
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
    console.log('\n❌ Template with 5:30 PM - 6:30 PM on Friday not found!');
    console.log('\nSearching all templates for this student...\n');
    
    for (const doc of templatesSnap.docs) {
      const data = doc.data();
      if (data.student_ids?.includes(student.uid)) {
        const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
        console.log(`   Template: ${doc.id}`);
        console.log(`   Time: ${data.start_time} - ${data.end_time}`);
        console.log(`   Days: ${weekdays}\n`);
      }
    }
    return;
  }
  
  // 4. Update template and regenerate shifts
  if (!DRY_RUN) {
    console.log('='.repeat(80));
    console.log('4. Updating template and regenerating shifts...\n');
    
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
    console.log(`\nChanged ${student.name} Friday class:`);
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
