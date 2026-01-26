#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const crypto = require('crypto');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';
const MAX_DAYS_AHEAD = 70; // 10 weeks

const DRY_RUN = !process.argv.includes('--apply');

async function migrate() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to migrate)' : 'APPLYING MIGRATION'}\n`);
  console.log('='.repeat(80));
  
  // 1. Find student
  const STUDENT_CODE = 'abdulai.bah';
  
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
    console.log(`❌ Student ${STUDENT_CODE} not found!`);
    return;
  }
  
  console.log(`✅ Student: ${student.name} (${student.code})`);
  console.log(`   UID: ${student.uid}\n`);
  
  // 2. Find teacher
  const TEACHER_ID = 'SQetTfLDFGTir9WZ4ivWVRboHpZ2';
  
  const teacherDoc = await db.collection('users').doc(TEACHER_ID).get();
  if (!teacherDoc.exists) {
    console.log('❌ Teacher not found!');
    return;
  }
  
  const teacherData = teacherDoc.data();
  const teacher = {
    uid: TEACHER_ID,
    name: `${teacherData.first_name} ${teacherData.last_name}`,
    timezone: teacherData.timezone || NYC_TZ,
  };
  
  console.log(`✅ Teacher: ${teacher.name}`);
  console.log(`   UID: ${teacher.uid}\n`);
  
  // 3. Find old shifts to delete
  console.log('='.repeat(80));
  console.log('Finding old shifts...\n');
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('student_ids', 'array-contains', student.uid)
    .where('teacher_id', '==', TEACHER_ID)
    .get();
  
  const oldShifts = [];
  const now = DateTime.now().setZone(NYC_TZ);
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    // Only delete future scheduled shifts without template
    if (!data.template_id && data.status === 'scheduled') {
      const shiftStart = data.shift_start?.toDate();
      if (shiftStart && DateTime.fromJSDate(shiftStart) > now) {
        oldShifts.push({
          id: doc.id,
          shiftStart: shiftStart,
        });
      }
    }
  }
  
  console.log(`Found ${oldShifts.length} future old-style shifts to delete\n`);
  
  // 4. Schedule to create
  const SCHEDULES = [
    {
      day: 6, // Saturday
      startTime: '09:00',
      endTime: '10:00',
      durationMinutes: 60,
    },
    {
      day: 7, // Sunday
      startTime: '09:00',
      endTime: '10:00',
      durationMinutes: 60,
    },
  ];
  
  if (DRY_RUN) {
    console.log('='.repeat(80));
    console.log('Would create:\n');
    console.log('Templates:');
    for (const schedule of SCHEDULES) {
      const dayName = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][schedule.day];
      console.log(`  - ${dayName} ${schedule.startTime} - ${schedule.endTime}`);
    }
    console.log(`\nWould delete ${oldShifts.length} old shifts`);
    console.log('\nRun with --apply to migrate');
    return;
  }
  
  // 5. Delete old shifts
  console.log('='.repeat(80));
  console.log('Deleting old shifts...\n');
  
  let deleted = 0;
  for (const shift of oldShifts) {
    await db.collection('teaching_shifts').doc(shift.id).delete();
    deleted++;
  }
  console.log(`✅ Deleted ${deleted} old shifts\n`);
  
  // 6. Create templates and generate new shifts
  console.log('='.repeat(80));
  console.log('Creating templates and shifts...\n');
  
  let totalTemplates = 0;
  let totalShifts = 0;
  
  for (const schedule of SCHEDULES) {
    const dayName = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][schedule.day];
    
    const templateId = `tpl_${crypto.randomBytes(8).toString('hex')}`;
    
    const templateData = {
      id: templateId,
      teacher_id: teacher.uid,
      teacher_name: teacher.name,
      student_ids: [student.uid],
      student_names: [student.name],
      subject: 'islamic',
      subject_display_name: 'Islamic',
      hourly_rate: 4,
      start_time: schedule.startTime,
      end_time: schedule.endTime,
      duration_minutes: schedule.durationMinutes,
      admin_timezone: NYC_TZ,
      teacher_timezone: teacher.timezone,
      recurrence: 'weekly',
      enhanced_recurrence: {
        type: 'weekly',
        selectedWeekdays: [schedule.day],
      },
      max_days_ahead: MAX_DAYS_AHEAD,
      is_active: true,
      video_provider: 'livekit',
      shift_category: 'teaching',
      notes: 'IC - Islamic',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    await db.collection('shift_templates').doc(templateId).set(templateData);
    totalTemplates++;
    console.log(`✅ Created template: ${templateId} (${dayName} ${schedule.startTime})`);
    
    // Generate shifts
    const endDate = now.plus({ days: MAX_DAYS_AHEAD });
    let currentDate = now.startOf('day');
    let shiftsCreated = 0;
    
    while (currentDate <= endDate) {
      const luxonDay = currentDate.weekday;
      
      if (luxonDay === schedule.day) {
        const [startHour, startMin] = schedule.startTime.split(':').map(Number);
        const [endHour, endMin] = schedule.endTime.split(':').map(Number);
        
        const shiftStart = currentDate.set({ hour: startHour, minute: startMin, second: 0 });
        const shiftEnd = currentDate.set({ hour: endHour, minute: endMin, second: 0 });
        
        if (shiftStart > now) {
          const shiftId = `tpl_${templateId}_${Math.floor(shiftStart.toMillis() / 1000)}`;
          
          const shiftData = {
            id: shiftId,
            template_id: templateId,
            teacher_id: teacher.uid,
            teacher_name: teacher.name,
            student_ids: [student.uid],
            student_names: [student.name],
            shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
            shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
            duration_minutes: schedule.durationMinutes,
            status: 'scheduled',
            video_provider: 'livekit',
            livekit_room_name: `shift_${shiftId}`,
            subject: 'islamic',
            subject_display_name: 'Islamic',
            hourly_rate: 4,
            notes: 'IC - Islamic',
            admin_timezone: NYC_TZ,
            teacher_timezone: teacher.timezone,
            shift_category: 'teaching',
            auto_generated_name: `${teacher.name} - Islamic - ${student.name}`,
            recurrence: 'weekly',
            recurrence_series_id: templateId,
            enhanced_recurrence: templateData.enhanced_recurrence,
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
    
    totalShifts += shiftsCreated;
    console.log(`   ✅ Created ${shiftsCreated} shifts for ${dayName}\n`);
  }
  
  // Summary
  console.log('='.repeat(80));
  console.log('\n✅ MIGRATION COMPLETE!');
  console.log(`   Deleted old shifts: ${deleted}`);
  console.log(`   Created templates: ${totalTemplates}`);
  console.log(`   Created new shifts: ${totalShifts}`);
}

migrate()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
