#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

async function checkShifts() {
  const now = DateTime.now().setZone(NYC_TZ);
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  console.log('='.repeat(80));
  
  // Find students
  const studentCodes = ['mamady.kaba', 'djenabou.kaba'];
  const students = [];
  
  const studentsSnap = await db.collection('users')
    .where('user_type', '==', 'student')
    .get();
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const code = data.student_code || data.studentId || data.student_id;
    if (studentCodes.includes(code)) {
      students.push({
        uid: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        code: code,
      });
    }
  }
  
  console.log('STUDENTS FOUND:\n');
  for (const student of students) {
    console.log(`  ${student.name} (${student.code}) - ${student.uid}`);
  }
  
  if (students.length === 0) {
    console.log('No students found!');
    return;
  }
  
  // Find shifts for these students (use first student to find group class)
  const studentUid = students[0].uid;
  
  console.log('\n' + '='.repeat(80));
  console.log('SHIFTS FOR TODAY:\n');
  
  const todayStart = now.startOf('day');
  const todayEnd = now.endOf('day');
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('student_ids', 'array-contains', studentUid)
    .get();
  
  const allShifts = [];
  const todayShifts = [];
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    const shiftStart = data.shift_start?.toDate();
    const shiftDt = shiftStart ? DateTime.fromJSDate(shiftStart).setZone(NYC_TZ) : null;
    
    const shift = {
      id: doc.id,
      templateId: data.template_id,
      teacherName: data.teacher_name,
      studentNames: data.student_names || [],
      shiftStart: shiftStart,
      shiftEnd: data.shift_end?.toDate(),
      shiftDt: shiftDt,
      status: data.status,
      generatedFromTemplate: data.generated_from_template,
      lastModified: data.last_modified?.toDate(),
      updatedAt: data.updated_at?.toDate(),
    };
    
    allShifts.push(shift);
    
    if (shiftDt && shiftDt >= todayStart && shiftDt <= todayEnd) {
      todayShifts.push(shift);
    }
  }
  
  if (todayShifts.length === 0) {
    console.log('No shifts found for today.');
  } else {
    for (const shift of todayShifts) {
      const startTime = shift.shiftDt?.toFormat('h:mm a');
      const endTime = shift.shiftEnd ? DateTime.fromJSDate(shift.shiftEnd).setZone(NYC_TZ).toFormat('h:mm a') : '?';
      const lastMod = shift.lastModified ? DateTime.fromJSDate(shift.lastModified).setZone(NYC_TZ).toFormat('MMM d, h:mm a') : 'unknown';
      
      console.log(`Shift ID: ${shift.id}`);
      console.log(`  Teacher: ${shift.teacherName}`);
      console.log(`  Students: ${shift.studentNames.join(', ')}`);
      console.log(`  Time: ${startTime} - ${endTime}`);
      console.log(`  Status: ${shift.status}`);
      console.log(`  Template ID: ${shift.templateId || 'NONE'}`);
      console.log(`  Generated from template: ${shift.generatedFromTemplate ? 'YES' : 'NO'}`);
      console.log(`  Last modified: ${lastMod}`);
      console.log('');
    }
  }
  
  // Check templates
  console.log('='.repeat(80));
  console.log('TEMPLATES FOR THESE STUDENTS:\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('student_ids', 'array-contains', studentUid)
    .get();
  
  if (templatesSnap.empty) {
    console.log('No templates found!');
  } else {
    for (const doc of templatesSnap.docs) {
      const data = doc.data();
      const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const days = (data.enhanced_recurrence?.selectedWeekdays || []).map(d => dayNames[d]);
      const excludedDates = data.enhanced_recurrence?.excludedDates || [];
      
      console.log(`Template: ${doc.id}`);
      console.log(`  Teacher: ${data.teacher_name}`);
      console.log(`  Students: ${(data.student_names || []).join(', ')}`);
      console.log(`  Time: ${data.start_time} - ${data.end_time}`);
      console.log(`  Days: ${days.join(', ')}`);
      console.log(`  Active: ${data.is_active}`);
      console.log(`  Excluded dates: ${excludedDates.length}`);
      
      if (excludedDates.length > 0) {
        console.log('  Excluded dates list:');
        for (const exDate of excludedDates) {
          const dt = exDate?.toDate ? DateTime.fromJSDate(exDate.toDate()).setZone(NYC_TZ) : null;
          console.log(`    - ${dt?.toFormat('ccc MMM d, yyyy') || 'invalid'}`);
        }
      }
      console.log('');
    }
  }
  
  // Check upcoming shifts
  console.log('='.repeat(80));
  console.log('UPCOMING SHIFTS (next 7 days):\n');
  
  const upcomingEnd = now.plus({ days: 7 });
  const upcomingShifts = allShifts
    .filter(s => s.shiftDt && s.shiftDt > now && s.shiftDt < upcomingEnd && s.status === 'scheduled')
    .sort((a, b) => a.shiftStart - b.shiftStart);
  
  for (const shift of upcomingShifts) {
    const startTime = shift.shiftDt?.toFormat('ccc MMM d, h:mm a');
    const endTime = shift.shiftEnd ? DateTime.fromJSDate(shift.shiftEnd).setZone(NYC_TZ).toFormat('h:mm a') : '?';
    console.log(`  ${startTime} - ${endTime} | Template: ${shift.templateId ? 'YES' : 'NO'} | ${shift.teacherName}`);
  }
  
  // Summary
  console.log('\n' + '='.repeat(80));
  console.log('ANALYSIS:\n');
  
  const shiftsWithTemplate = allShifts.filter(s => s.templateId);
  const shiftsWithoutTemplate = allShifts.filter(s => !s.templateId);
  
  console.log(`Total shifts: ${allShifts.length}`);
  console.log(`  With template: ${shiftsWithTemplate.length}`);
  console.log(`  Without template: ${shiftsWithoutTemplate.length}`);
  
  if (shiftsWithoutTemplate.length > 0) {
    console.log('\n⚠️ Shifts without template:');
    for (const shift of shiftsWithoutTemplate) {
      const dt = shift.shiftDt?.toFormat('ccc MMM d, h:mm a') || 'unknown';
      console.log(`  - ${dt} | Status: ${shift.status}`);
    }
  }
}

checkShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
