#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const crypto = require('crypto');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const THIERNO_UID = 'Thz8PIVUGpS5cjlIYBJAemjoQxw1';
const AMADOU_STUDENT_CODE = '7amadou.sidy';
const ADMIN_TZ = 'America/New_York';
const MAX_DAYS_AHEAD = 70; // 10 weeks

const DRY_RUN = !process.argv.includes('--apply');

async function createTemplate() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to create)' : 'CREATING TEMPLATE AND SHIFTS'}\n`);
  console.log('='.repeat(80));
  
  // 1. Find Amadou Sidy student
  console.log('1. Finding student 7amadou.sidy...\n');
  
  const studentsSnap = await db.collection('users')
    .where('user_type', '==', 'student')
    .get();
  
  let amadouStudent = null;
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const code = data.student_code || data.studentId || data.student_id;
    
    if (code === AMADOU_STUDENT_CODE) {
      amadouStudent = {
        uid: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        code: code,
      };
      break;
    }
  }
  
  if (!amadouStudent) {
    console.log('❌ Student 7amadou.sidy not found!');
    return;
  }
  
  console.log(`✅ Found: ${amadouStudent.name} (${amadouStudent.code})`);
  console.log(`   UID: ${amadouStudent.uid}\n`);
  
  // 2. Get teacher info
  console.log('2. Getting teacher info...\n');
  
  const teacherDoc = await db.collection('users').doc(THIERNO_UID).get();
  if (!teacherDoc.exists) {
    console.log('❌ Teacher not found!');
    return;
  }
  
  const teacherData = teacherDoc.data();
  const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim();
  const teacherTimezone = teacherData.timezone || ADMIN_TZ;
  
  console.log(`✅ Teacher: ${teacherName}`);
  console.log(`   UID: ${THIERNO_UID}`);
  console.log(`   Timezone: ${teacherTimezone}\n`);
  
  // 3. Define the schedule - Mon-Thu at 9:00 PM NYC
  const schedule = {
    days: [1, 2, 3, 4], // Mon=1, Tue=2, Wed=3, Thu=4
    dayNames: ['Monday', 'Tuesday', 'Wednesday', 'Thursday'],
    startTime: '21:00', // 9:00 PM
    endTime: '22:00',   // 10:00 PM
    duration: 60,
  };
  
  console.log('3. Schedule to create:\n');
  console.log(`   Days: ${schedule.dayNames.join(', ')}`);
  console.log(`   Time: ${schedule.startTime} - ${schedule.endTime} (${ADMIN_TZ})`);
  console.log(`   Student: ${amadouStudent.name} (${amadouStudent.code})`);
  console.log(`   Duration: ${schedule.duration} min\n`);
  
  // 4. Create template for each day
  console.log('='.repeat(80));
  console.log('4. Creating templates...\n');
  
  const createdTemplates = [];
  
  for (let i = 0; i < schedule.days.length; i++) {
    const dayNum = schedule.days[i];
    const dayName = schedule.dayNames[i];
    
    const templateId = `tpl_${crypto.randomBytes(8).toString('hex')}`;
    
    const templateData = {
      id: templateId,
      teacher_id: THIERNO_UID,
      teacher_name: teacherName,
      student_ids: [amadouStudent.uid],
      student_names: [amadouStudent.name],
      start_time: schedule.startTime,
      end_time: schedule.endTime,
      duration_minutes: schedule.duration,
      admin_timezone: ADMIN_TZ,
      teacher_timezone: teacherTimezone,
      subject: 'islamicStudies',
      subject_display_name: 'Islamic Studies',
      hourly_rate: 4,
      notes: `IC / Islamic`,
      is_active: true,
      video_provider: 'livekit',
      max_days_ahead: MAX_DAYS_AHEAD,
      enhanced_recurrence: {
        type: 'weekly',
        selectedWeekdays: [dayNum],
        excludedWeekdays: [],
        excludedDates: [],
        selectedMonths: [],
        selectedMonthDays: [],
      },
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    console.log(`   ${dayName}: Template ${templateId}`);
    
    if (!DRY_RUN) {
      await db.collection('shift_templates').doc(templateId).set(templateData);
      console.log(`     ✅ Created`);
    }
    
    createdTemplates.push({
      id: templateId,
      dayNum: dayNum,
      dayName: dayName,
      data: templateData,
    });
  }
  
  // 5. Generate shifts from templates
  if (!DRY_RUN) {
    console.log('\n' + '='.repeat(80));
    console.log('5. Generating shifts...\n');
    
    let totalShifts = 0;
    
    for (const template of createdTemplates) {
      let shiftsCreated = 0;
      
      const nowLocal = DateTime.now().setZone(ADMIN_TZ);
      const endDate = nowLocal.plus({ days: MAX_DAYS_AHEAD });
      let currentDate = nowLocal.startOf('day');
      
      while (currentDate <= endDate) {
        const luxonDay = currentDate.weekday; // 1=Mon, 2=Tue, ..., 7=Sun
        
        if (luxonDay === template.dayNum) {
          const [startHour, startMin] = template.data.start_time.split(':').map(Number);
          const [endHour, endMin] = template.data.end_time.split(':').map(Number);
          
          const shiftStart = currentDate.set({ hour: startHour, minute: startMin, second: 0 });
          const shiftEnd = currentDate.set({ hour: endHour, minute: endMin, second: 0 });
          
          // Skip if shift is in the past
          if (shiftStart < DateTime.now().setZone(ADMIN_TZ)) {
            currentDate = currentDate.plus({ days: 1 });
            continue;
          }
          
          const shiftId = `tpl_${template.id}_${Math.floor(shiftStart.toMillis() / 1000)}`;
          
          const shiftData = {
            id: shiftId,
            template_id: template.id,
            teacher_id: THIERNO_UID,
            teacher_name: teacherName,
            student_ids: [amadouStudent.uid],
            student_names: [amadouStudent.name],
            shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
            shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
            duration_minutes: schedule.duration,
            status: 'scheduled',
            video_provider: 'livekit',
            livekit_room_name: `shift_${shiftId}`,
            subject: 'islamicStudies',
            subject_display_name: 'Islamic Studies',
            hourly_rate: 4,
            notes: 'IC / Islamic',
            admin_timezone: ADMIN_TZ,
            teacher_timezone: teacherTimezone,
            shift_category: 'teaching',
            auto_generated_name: `${teacherName} - Islamic Studies - ${amadouStudent.name}`,
            recurrence: 'weekly',
            recurrence_series_id: template.id,
            enhanced_recurrence: template.data.enhanced_recurrence,
            series_created_at: admin.firestore.FieldValue.serverTimestamp(),
            generated_from_template: true,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
            last_modified: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          await db.collection('teaching_shifts').doc(shiftId).set(shiftData);
          shiftsCreated++;
        }
        
        currentDate = currentDate.plus({ days: 1 });
      }
      
      console.log(`   ${template.dayName}: ${shiftsCreated} shifts created`);
      totalShifts += shiftsCreated;
    }
    
    console.log(`\n   Total shifts created: ${totalShifts}`);
  }
  
  // Summary
  console.log('\n' + '='.repeat(80));
  
  if (DRY_RUN) {
    console.log('DRY RUN COMPLETE - No changes made');
    console.log('Run with --apply to create templates and shifts');
  } else {
    console.log('✅ DONE!');
    console.log(`\nCreated:`);
    console.log(`  - 4 templates (Mon, Tue, Wed, Thu)`);
    console.log(`  - Shifts for the next ${MAX_DAYS_AHEAD} days (~10 weeks)`);
    console.log(`\nSchedule:`);
    console.log(`  Teacher: ${teacherName}`);
    console.log(`  Student: ${amadouStudent.name} (${amadouStudent.code})`);
    console.log(`  Days: Mon, Tue, Wed, Thu`);
    console.log(`  Time: 9:00 PM - 10:00 PM NYC`);
  }
}

createTemplate()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
