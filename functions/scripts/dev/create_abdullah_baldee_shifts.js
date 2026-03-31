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

// Schedules to create
const SCHEDULES = [
  // idrissatou.diallo - Islamic
  {
    studentCodes: ['idrissatou.diallo'],
    classType: 'IC',
    subject: 'islamic',
    subjectDisplay: 'Islamic',
    days: [5, 6, 7], // Fri, Sat, Sun
    sessions: [
      { day: 5, startTime: '17:00', endTime: '18:00', durationMinutes: 60 }, // Fri 5-6 PM
      { day: 6, startTime: '15:00', endTime: '16:00', durationMinutes: 60 }, // Sat 3-4 PM
      { day: 7, startTime: '16:00', endTime: '17:00', durationMinutes: 60 }, // Sun 4-5 PM
    ],
  },
  // tahirou.bah - Adult class
  {
    studentCodes: ['tahirou.bah'],
    classType: 'IC',
    subject: 'adult_class',
    subjectDisplay: 'Adult Class',
    sessions: [
      { day: 5, startTime: '15:30', endTime: '16:30', durationMinutes: 60 }, // Fri 3:30-4:30 PM
      { day: 7, startTime: '16:00', endTime: '17:00', durationMinutes: 60 }, // Sun 4-5 PM
    ],
  },
  // housainato.mariam - Adult class
  {
    studentCodes: ['housainato.mariam'],
    classType: 'IC',
    subject: 'adult_class',
    subjectDisplay: 'Adult Class',
    sessions: [
      { day: 1, startTime: '12:00', endTime: '13:00', durationMinutes: 60 }, // Mon 12-1 PM
    ],
  },
  // housainato.mariama - Islamic
  {
    studentCodes: ['housainato.mariama'],
    classType: 'IC',
    subject: 'islamic',
    subjectDisplay: 'Islamic',
    sessions: [
      { day: 2, startTime: '12:00', endTime: '13:00', durationMinutes: 60 }, // Tue 12-1 PM
    ],
  },
  // fatimatou.diallo - Adult class
  {
    studentCodes: ['fatimatou.diallo'],
    classType: 'IC',
    subject: 'adult_class',
    subjectDisplay: 'Adult Class',
    sessions: [
      { day: 1, startTime: '09:00', endTime: '10:30', durationMinutes: 90 }, // Mon 9-10:30 AM
      { day: 2, startTime: '09:00', endTime: '10:30', durationMinutes: 90 }, // Tue 9-10:30 AM
    ],
  },
];

const DAY_NAMES = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

async function createShifts() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to create)' : 'CREATING SHIFTS'}\n`);
  console.log('='.repeat(80));
  
  // 1. Find Abdullah Baldee
  console.log('1. Finding teacher: Abdullah Baldee...\n');
  
  const teachersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  
  let teacher = null;
  
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim().toLowerCase();
    
    if (fullName.includes('abdullah') && fullName.includes('baldee')) {
      teacher = {
        uid: doc.id,
        name: `${data.first_name} ${data.last_name}`,
        timezone: data.timezone || NYC_TZ,
      };
      break;
    }
  }
  
  if (!teacher) {
    console.log('Teachers with similar names:');
    for (const doc of teachersSnap.docs) {
      const data = doc.data();
      const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim().toLowerCase();
      if (fullName.includes('abdull') || fullName.includes('baldee')) {
        console.log(`   ${data.first_name} ${data.last_name} (${doc.id})`);
      }
    }
    console.log('\n❌ Teacher not found!');
    return;
  }
  
  console.log(`✅ Found: ${teacher.name}`);
  console.log(`   UID: ${teacher.uid}`);
  console.log(`   Timezone: ${teacher.timezone}\n`);
  
  // 2. Find all students
  console.log('='.repeat(80));
  console.log('2. Finding students...\n');
  
  const studentsSnap = await db.collection('users')
    .where('user_type', '==', 'student')
    .get();
  
  const studentMap = new Map();
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const code = data.student_code || data.studentId || data.student_id;
    if (code) {
      studentMap.set(code, {
        uid: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        code: code,
      });
    }
  }
  
  // Check all required students exist
  const allStudentCodes = new Set();
  for (const schedule of SCHEDULES) {
    for (const code of schedule.studentCodes) {
      allStudentCodes.add(code);
    }
  }
  
  let allFound = true;
  for (const code of allStudentCodes) {
    const student = studentMap.get(code);
    if (student) {
      console.log(`   ✅ ${student.name} (${code})`);
    } else {
      console.log(`   ❌ NOT FOUND: ${code}`);
      allFound = false;
    }
  }
  
  if (!allFound) {
    console.log('\n❌ Some students not found. Aborting.');
    return;
  }
  
  // 3. Create templates and shifts
  console.log('\n' + '='.repeat(80));
  console.log('3. Creating templates and shifts...\n');
  
  let totalTemplates = 0;
  let totalShifts = 0;
  
  for (const schedule of SCHEDULES) {
    const students = schedule.studentCodes.map(code => studentMap.get(code));
    const studentNames = students.map(s => s.name);
    const studentIds = students.map(s => s.uid);
    
    console.log(`\n   ${studentNames.join(' & ')} (${schedule.classType}) - ${schedule.subjectDisplay}`);
    
    for (const session of schedule.sessions) {
      const dayName = DAY_NAMES[session.day];
      console.log(`   ${dayName}: ${session.startTime} - ${session.endTime}`);
      
      if (DRY_RUN) {
        totalTemplates++;
        totalShifts += 10;
        continue;
      }
      
      // Create template for this session
      const templateId = `tpl_${crypto.randomBytes(8).toString('hex')}`;
      
      const templateData = {
        id: templateId,
        teacher_id: teacher.uid,
        teacher_name: teacher.name,
        student_ids: studentIds,
        student_names: studentNames,
        subject: schedule.subject,
        subject_display_name: schedule.subjectDisplay,
        hourly_rate: 4,
        start_time: session.startTime,
        end_time: session.endTime,
        duration_minutes: session.durationMinutes,
        admin_timezone: NYC_TZ,
        teacher_timezone: teacher.timezone,
        recurrence: 'weekly',
        enhanced_recurrence: {
          type: 'weekly',
          selectedWeekdays: [session.day],
        },
        max_days_ahead: MAX_DAYS_AHEAD,
        is_active: true,
        video_provider: 'livekit',
        shift_category: 'teaching',
        notes: `${schedule.classType} - ${schedule.subjectDisplay}`,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      await db.collection('shift_templates').doc(templateId).set(templateData);
      totalTemplates++;
      
      // Generate shifts
      const nowLocal = DateTime.now().setZone(NYC_TZ);
      const endDate = nowLocal.plus({ days: MAX_DAYS_AHEAD });
      let currentDate = nowLocal.startOf('day');
      let shiftsCreated = 0;
      
      while (currentDate <= endDate) {
        const luxonDay = currentDate.weekday;
        
        if (luxonDay === session.day) {
          const [startHour, startMin] = session.startTime.split(':').map(Number);
          const [endHour, endMin] = session.endTime.split(':').map(Number);
          
          const shiftStart = currentDate.set({ hour: startHour, minute: startMin, second: 0 });
          const shiftEnd = currentDate.set({ hour: endHour, minute: endMin, second: 0 });
          
          if (shiftStart > nowLocal) {
            const shiftId = `tpl_${templateId}_${Math.floor(shiftStart.toMillis() / 1000)}`;
            
            const shiftData = {
              id: shiftId,
              template_id: templateId,
              teacher_id: teacher.uid,
              teacher_name: teacher.name,
              student_ids: studentIds,
              student_names: studentNames,
              shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
              shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
              duration_minutes: session.durationMinutes,
              status: 'scheduled',
              video_provider: 'livekit',
              livekit_room_name: `shift_${shiftId}`,
              subject: schedule.subject,
              subject_display_name: schedule.subjectDisplay,
              hourly_rate: 4,
              notes: `${schedule.classType} - ${schedule.subjectDisplay}`,
              admin_timezone: NYC_TZ,
              teacher_timezone: teacher.timezone,
              shift_category: 'teaching',
              auto_generated_name: `${teacher.name} - ${schedule.subjectDisplay} - ${studentNames.join(', ')}`,
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
    }
    
    if (!DRY_RUN) {
      console.log(`   ✅ Created templates and shifts`);
    }
  }
  
  // Summary
  console.log('\n' + '='.repeat(80));
  console.log('\nSUMMARY');
  console.log('='.repeat(80));
  
  if (DRY_RUN) {
    console.log('\nDRY RUN - No changes made');
    console.log(`Would create: ${totalTemplates} templates, ~${totalShifts} shifts`);
    console.log('\nRun with --apply to create');
  } else {
    console.log(`\n✅ DONE!`);
    console.log(`   Templates created: ${totalTemplates}`);
    console.log(`   Shifts created: ${totalShifts}`);
  }
}

createShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
