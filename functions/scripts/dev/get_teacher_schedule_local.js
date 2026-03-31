#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const normalizeSearchName = (name) => 
  (name || '').toString().toLowerCase().replace(/[^a-z0-9]/g, '');

async function getTeacherSchedule(searchName, displayTimezone = 'America/New_York') {
  console.log(`Searching for teacher: ${searchName}\n`);
  console.log('='.repeat(80));
  
  // Search for teacher by name
  const teachersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  
  let teacher = null;
  const normalizedSearch = normalizeSearchName(searchName);
  
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    const normalizedName = normalizeSearchName(fullName);
    
    if (normalizedName.includes(normalizedSearch) || normalizedSearch.includes(normalizedName)) {
      teacher = {
        uid: doc.id,
        firstName: data.first_name,
        lastName: data.last_name,
        fullName,
        email: data['e-mail'] || data.email,
        timezone: data.timezone || data.time_zone || 'America/New_York',
      };
      break;
    }
  }
  
  if (!teacher) {
    console.log('❌ Teacher not found!');
    return;
  }
  
  // If displayTimezone is 'local', use teacher's timezone
  if (displayTimezone === 'local') {
    displayTimezone = teacher.timezone;
  }
  
  console.log('👤 TEACHER FOUND');
  console.log('='.repeat(80));
  console.log(`Name: ${teacher.fullName}`);
  console.log(`UID: ${teacher.uid}`);
  console.log(`Email: ${teacher.email}`);
  console.log(`Teacher Timezone: ${teacher.timezone}`);
  console.log(`Display Timezone: ${displayTimezone}\n`);
  
  // Get all active templates
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', teacher.uid)
    .where('is_active', '==', true)
    .get();
  
  console.log('='.repeat(80));
  console.log('📋 SHIFT TEMPLATES');
  console.log('='.repeat(80));
  console.log(`Total Active Templates: ${templatesSnap.size}\n`);
  
  if (templatesSnap.size === 0) {
    console.log('No active templates found for this teacher.');
    return;
  }
  
  // Get student info
  const studentIds = new Set();
  templatesSnap.docs.forEach(doc => {
    const data = doc.data();
    (data.student_ids || []).forEach(id => studentIds.add(id));
  });
  
  const studentMap = new Map();
  for (const studentId of studentIds) {
    const studentDoc = await db.collection('users').doc(studentId).get();
    if (studentDoc.exists) {
      const data = studentDoc.data();
      studentMap.set(studentId, {
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        studentCode: data.student_code || data.studentId || data.student_id,
      });
    }
  }
  
  // Parse and organize templates by day
  const DAY_NAMES = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const scheduleByDay = new Map();
  
  templatesSnap.docs.forEach(doc => {
    const data = doc.data();
    const selectedWeekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    
    selectedWeekdays.forEach(dayNum => {
      const dayName = DAY_NAMES[dayNum];
      if (!scheduleByDay.has(dayName)) {
        scheduleByDay.set(dayName, []);
      }
      
      // Parse time and convert to display timezone
      const [startHour, startMin] = (data.start_time || '').split(':').map(Number);
      const [endHour, endMin] = (data.end_time || '').split(':').map(Number);
      
      // Create a sample date to convert times
      const sampleDate = DateTime.now().setZone(data.admin_timezone || 'America/New_York').set({
        hour: startHour,
        minute: startMin,
        second: 0,
        millisecond: 0,
      });
      
      const displayTime = sampleDate.setZone(displayTimezone);
      const displayStartHour = displayTime.hour;
      const displayStartMin = displayTime.minute;
      
      const endDate = DateTime.now().setZone(data.admin_timezone || 'America/New_York').set({
        hour: endHour,
        minute: endMin,
        second: 0,
        millisecond: 0,
      });
      
      const displayEndTime = endDate.setZone(displayTimezone);
      const displayEndHour = displayEndTime.hour;
      const displayEndMin = displayEndTime.minute;
      
      const formatTime = (hour, min) => {
        const meridiem = hour >= 12 ? 'PM' : 'AM';
        const displayHour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
        return `${displayHour}:${String(min).padStart(2, '0')} ${meridiem}`;
      };
      
      const studentNames = (data.student_ids || []).map(sid => {
        const student = studentMap.get(sid);
        return student ? `${student.name} (${student.studentCode})` : sid;
      }).join(', ');
      
      scheduleByDay.get(dayName).push({
        dayNum,
        startTime: formatTime(displayStartHour, displayStartMin),
        endTime: formatTime(displayEndHour, displayEndMin),
        duration: data.duration_minutes,
        students: studentNames,
        subject: data.subject_display_name || data.subject,
        classType: data.notes || '',
        hourlyRate: data.hourly_rate,
      });
    });
  });
  
  // Sort days and display
  const orderedDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  
  for (const day of orderedDays) {
    if (scheduleByDay.has(day)) {
      console.log(`\n${day}:`);
      console.log('-'.repeat(80));
      
      const classes = scheduleByDay.get(day);
      classes.sort((a, b) => {
        const aTime = a.startTime;
        const bTime = b.startTime;
        return aTime.localeCompare(bTime);
      });
      
      classes.forEach((cls, index) => {
        console.log(`  ${index + 1}. ${cls.startTime} - ${cls.endTime} (${cls.duration} min)`);
        console.log(`     Student(s): ${cls.students}`);
        console.log(`     Subject: ${cls.subject} ($${cls.hourlyRate || 0}/hr)`);
        if (cls.classType) console.log(`     Type: ${cls.classType}`);
        console.log('');
      });
    }
  }
  
  // Get upcoming shifts
  console.log('\n' + '='.repeat(80));
  console.log('📅 UPCOMING SHIFTS (Next 7 Days)');
  console.log('='.repeat(80));
  
  const now = DateTime.now().setZone(displayTimezone);
  const weekFromNow = now.plus({ days: 7 });
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', teacher.uid)
    .where('status', '==', 'scheduled')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(now.toJSDate()))
    .where('shift_start', '<=', admin.firestore.Timestamp.fromDate(weekFromNow.toJSDate()))
    .get();
  
  console.log(`\nTotal Upcoming Shifts: ${shiftsSnap.size}\n`);
  
  if (shiftsSnap.size > 0) {
    const shifts = [];
    shiftsSnap.docs.forEach(doc => {
      const data = doc.data();
      const start = DateTime.fromJSDate(data.shift_start.toDate()).setZone(displayTimezone);
      shifts.push({
        date: start.toFormat('EEE, MMM dd'),
        time: start.toFormat('h:mm a'),
        endTime: DateTime.fromJSDate(data.shift_end.toDate()).setZone(displayTimezone).toFormat('h:mm a'),
        students: (data.student_ids || []).map(sid => {
          const student = studentMap.get(sid);
          return student ? student.name : sid;
        }).join(', '),
      });
    });
    
    shifts.sort((a, b) => a.date.localeCompare(b.date));
    
    shifts.forEach(shift => {
      console.log(`${shift.date} | ${shift.time} - ${shift.endTime} | ${shift.students}`);
    });
  }
  
  // Summary
  console.log('\n' + '='.repeat(80));
  console.log('📊 SUMMARY');
  console.log('='.repeat(80));
  console.log(`Teacher: ${teacher.fullName}`);
  console.log(`Total Active Templates: ${templatesSnap.size}`);
  console.log(`Unique Students: ${studentIds.size}`);
  console.log(`Upcoming Shifts (7 days): ${shiftsSnap.size}`);
  console.log(`Display Timezone: ${displayTimezone}`);
}

const teacherName = process.argv[2] || 'Rahmatullaah Balde';
const timezone = process.argv[3] || 'local';
getTeacherSchedule(teacherName, timezone)
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
