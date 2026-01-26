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

// Schedule to create
const SCHEDULES = [
  {
    studentCodes: ['fatumata.kaba'],
    classType: 'IC',
    program: 'Islamic',
    days: [1, 2, 3], // Mon, Tue, Wed
    startTime: '18:00',
    endTime: '18:30',
    durationMinutes: 30,
  },
  {
    studentCodes: ['1mariama.barry'],
    classType: 'IC',
    program: 'Islamic',
    days: [5, 6, 7], // Fri, Sat, Sun
    startTime: '17:00',
    endTime: '18:00',
    durationMinutes: 60,
  },
  {
    studentCodes: ['1famata.momo'],
    classType: 'IC',
    program: 'Islamic',
    days: [6, 7], // Sat, Sun
    startTime: '05:00',
    endTime: '05:30',
    durationMinutes: 30,
  },
  {
    studentCodes: ['elias.kouyateh', 'ousman.kouyateh'],
    classType: 'FGC',
    program: 'Islamic',
    days: [5], // Friday only
    startTime: '16:00',
    endTime: '17:00',
    durationMinutes: 60,
  },
  {
    studentCodes: ['elias.kouyateh', 'ousman.kouyateh'],
    classType: 'FGC',
    program: 'Islamic',
    days: [6], // Saturday only
    startTime: '11:00',
    endTime: '12:00',
    durationMinutes: 60,
  },
  {
    studentCodes: ['1djenabou.diallo'],
    classType: 'IC',
    program: 'Islamic',
    days: [5, 6, 7], // Fri, Sat, Sun
    startTime: '18:00',
    endTime: '19:00',
    durationMinutes: 60,
  },
];

const DAY_NAMES = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

async function createShifts() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to create)' : 'CREATING SHIFTS'}\n`);
  console.log('='.repeat(80));
  
  // 1. Find Abdulai Diallo
  console.log('1. Finding teacher: Abdulai Diallo...\n');
  
  const teachersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  
  let teacher = null;
  
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim().toLowerCase();
    
    if (fullName.includes('abdulai') && fullName.includes('diallo')) {
      teacher = {
        uid: doc.id,
        name: `${data.first_name} ${data.last_name}`,
        timezone: data.timezone || NYC_TZ,
      };
      break;
    }
  }
  
  if (!teacher) {
    console.log('❌ Teacher not found!');
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
  
  // 3. Get subject
  console.log('\n' + '='.repeat(80));
  console.log('3. Getting subject...\n');
  
  const subjectsSnap = await db.collection('subjects')
    .where('isActive', '==', true)
    .get();
  
  let islamicSubject = null;
  for (const doc of subjectsSnap.docs) {
    const data = doc.data();
    if (data.name === 'islamic' || data.displayName?.toLowerCase().includes('quran')) {
      islamicSubject = {
        id: doc.id,
        name: data.name,
        displayName: data.displayName,
        hourlyRate: data.defaultWage || 4,
      };
      break;
    }
  }
  
  if (!islamicSubject) {
    // Use default
    islamicSubject = {
      id: 'quran_studies',
      name: 'quran_studies',
      displayName: 'Quran Studies',
      hourlyRate: 4,
    };
  }
  
  console.log(`   Subject: ${islamicSubject.displayName} ($${islamicSubject.hourlyRate}/hr)\n`);
  
  // 4. Create templates and shifts
  console.log('='.repeat(80));
  console.log('4. Creating templates and shifts...\n');
  
  let totalTemplates = 0;
  let totalShifts = 0;
  
  for (const schedule of SCHEDULES) {
    const students = schedule.studentCodes.map(code => studentMap.get(code));
    const studentNames = students.map(s => s.name);
    const studentIds = students.map(s => s.uid);
    const daysStr = schedule.days.map(d => DAY_NAMES[d]).join(', ');
    
    console.log(`\n   ${studentNames.join(' & ')} (${schedule.classType})`);
    console.log(`   Days: ${daysStr}`);
    console.log(`   Time: ${schedule.startTime} - ${schedule.endTime}`);
    
    if (DRY_RUN) {
      console.log(`   Would create: 1 template, ~10 shifts per day`);
      totalTemplates++;
      totalShifts += schedule.days.length * 10;
      continue;
    }
    
    // Create template
    const templateId = `tpl_${crypto.randomBytes(8).toString('hex')}`;
    
    const templateData = {
      id: templateId,
      teacher_id: teacher.uid,
      teacher_name: teacher.name,
      student_ids: studentIds,
      student_names: studentNames,
      subject: islamicSubject.name,
      subject_display_name: islamicSubject.displayName,
      hourly_rate: islamicSubject.hourlyRate,
      start_time: schedule.startTime,
      end_time: schedule.endTime,
      duration_minutes: schedule.durationMinutes,
      admin_timezone: NYC_TZ,
      teacher_timezone: teacher.timezone,
      recurrence: 'weekly',
      enhanced_recurrence: {
        type: 'weekly',
        selectedWeekdays: schedule.days,
      },
      max_days_ahead: MAX_DAYS_AHEAD,
      is_active: true,
      video_provider: 'livekit',
      shift_category: 'teaching',
      notes: `${schedule.classType} - ${schedule.program}`,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    await db.collection('shift_templates').doc(templateId).set(templateData);
    totalTemplates++;
    console.log(`   ✅ Template created: ${templateId}`);
    
    // Generate shifts
    const nowLocal = DateTime.now().setZone(NYC_TZ);
    const endDate = nowLocal.plus({ days: MAX_DAYS_AHEAD });
    let currentDate = nowLocal.startOf('day');
    let shiftsCreated = 0;
    
    while (currentDate <= endDate) {
      const luxonDay = currentDate.weekday;
      
      if (schedule.days.includes(luxonDay)) {
        const [startHour, startMin] = schedule.startTime.split(':').map(Number);
        const [endHour, endMin] = schedule.endTime.split(':').map(Number);
        
        const shiftStart = currentDate.set({ hour: startHour, minute: startMin, second: 0 });
        const shiftEnd = currentDate.set({ hour: endHour, minute: endMin, second: 0 });
        
        // Only create future shifts
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
            duration_minutes: schedule.durationMinutes,
            status: 'scheduled',
            video_provider: 'livekit',
            livekit_room_name: `shift_${shiftId}`,
            subject: islamicSubject.name,
            subject_display_name: islamicSubject.displayName,
            hourly_rate: islamicSubject.hourlyRate,
            notes: `${schedule.classType} - ${schedule.program}`,
            admin_timezone: NYC_TZ,
            teacher_timezone: teacher.timezone,
            shift_category: 'teaching',
            auto_generated_name: `${teacher.name} - ${islamicSubject.displayName} - ${studentNames.join(', ')}`,
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
    console.log(`   ✅ Created ${shiftsCreated} shifts`);
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
