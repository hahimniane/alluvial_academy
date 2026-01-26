#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const STUDENT_CODE = process.argv[2] || 'abdulai.bah';
const NYC_TZ = 'America/New_York';

async function checkStudentShifts() {
  console.log(`Checking shifts for student: ${STUDENT_CODE}\n`);
  console.log('='.repeat(80));
  
  // 1. Find student
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
  
  console.log(`\n✅ Student: ${student.name} (${student.code})`);
  console.log(`   UID: ${student.uid}\n`);
  
  // 2. Find all shifts for this student
  console.log('='.repeat(80));
  console.log('SHIFTS:\n');
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('student_ids', 'array-contains', student.uid)
    .get();
  
  const shifts = [];
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    shifts.push({
      id: doc.id,
      teacherId: data.teacher_id,
      teacherName: data.teacher_name,
      templateId: data.template_id,
      status: data.status,
      shiftStart: data.shift_start?.toDate(),
      shiftEnd: data.shift_end?.toDate(),
      generatedFromTemplate: data.generated_from_template,
      recurrence: data.recurrence,
      recurrenceSeriesId: data.recurrence_series_id,
    });
  }
  
  // Sort by start time
  shifts.sort((a, b) => (a.shiftStart || 0) - (b.shiftStart || 0));
  
  const withTemplate = shifts.filter(s => s.templateId);
  const withoutTemplate = shifts.filter(s => !s.templateId);
  
  console.log(`Total shifts: ${shifts.length}`);
  console.log(`With template_id: ${withTemplate.length}`);
  console.log(`Without template_id (old style): ${withoutTemplate.length}\n`);
  
  if (withoutTemplate.length > 0) {
    console.log('='.repeat(80));
    console.log('SHIFTS WITHOUT TEMPLATE (old style):\n');
    
    // Group by teacher
    const byTeacher = new Map();
    
    for (const shift of withoutTemplate) {
      const key = shift.teacherId || 'unknown';
      if (!byTeacher.has(key)) {
        byTeacher.set(key, {
          teacherName: shift.teacherName,
          shifts: [],
        });
      }
      byTeacher.get(key).shifts.push(shift);
    }
    
    for (const [teacherId, info] of byTeacher) {
      console.log(`\nTeacher: ${info.teacherName} (${teacherId})`);
      console.log(`  Shifts: ${info.shifts.length}`);
      
      // Analyze schedule pattern
      const patterns = new Map(); // day + time -> count
      
      for (const shift of info.shifts) {
        if (shift.shiftStart) {
          const dt = DateTime.fromJSDate(shift.shiftStart).setZone(NYC_TZ);
          const day = dt.weekdayLong;
          const time = dt.toFormat('h:mm a');
          const endDt = shift.shiftEnd ? DateTime.fromJSDate(shift.shiftEnd).setZone(NYC_TZ) : null;
          const endTime = endDt ? endDt.toFormat('h:mm a') : '?';
          const key = `${day} ${time} - ${endTime}`;
          patterns.set(key, (patterns.get(key) || 0) + 1);
        }
      }
      
      console.log('  Schedule patterns:');
      for (const [pattern, count] of patterns) {
        console.log(`    ${pattern}: ${count} occurrences`);
      }
    }
  }
  
  // 3. Check for existing templates
  console.log('\n' + '='.repeat(80));
  console.log('EXISTING TEMPLATES for this student:\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('student_ids', 'array-contains', student.uid)
    .get();
  
  if (templatesSnap.empty) {
    console.log('No templates found for this student.');
  } else {
    for (const doc of templatesSnap.docs) {
      const data = doc.data();
      console.log(`Template: ${doc.id}`);
      console.log(`  Teacher: ${data.teacher_name}`);
      console.log(`  Time: ${data.start_time} - ${data.end_time}`);
      console.log(`  Days: ${JSON.stringify(data.enhanced_recurrence?.selectedWeekdays)}`);
      console.log(`  Active: ${data.is_active}`);
      console.log('');
    }
  }
}

checkStudentShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
