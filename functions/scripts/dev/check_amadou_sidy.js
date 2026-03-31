#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const THIERNO_UID = 'Thz8PIVUGpS5cjlIYBJAemjoQxw1';

async function checkAmadouSidy() {
  console.log('Checking for Amadou Sidy in Thierno\'s shifts...\n');
  console.log('='.repeat(80));
  
  // Get all shifts for Thierno
  const allShiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', THIERNO_UID)
    .where('status', '==', 'scheduled')
    .get();
  
  // Collect all student IDs
  const allStudentIds = new Set();
  const oldShiftStudents = new Set();
  const newShiftStudents = new Set();
  
  for (const doc of allShiftsSnap.docs) {
    const data = doc.data();
    const studentIds = data.student_ids || [];
    const hasTemplate = !!data.template_id;
    
    for (const sid of studentIds) {
      allStudentIds.add(sid);
      if (hasTemplate) {
        newShiftStudents.add(sid);
      } else {
        oldShiftStudents.add(sid);
      }
    }
  }
  
  // Get student details
  console.log('STUDENTS IN OLD SHIFTS (no template, 9:00 PM):\n');
  
  for (const sid of oldShiftStudents) {
    const studentDoc = await db.collection('users').doc(sid).get();
    if (studentDoc.exists) {
      const data = studentDoc.data();
      const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
      const code = data.student_code || data.studentId || data.student_id || sid;
      console.log(`  - ${fullName} (${code})`);
    } else {
      console.log(`  - Unknown student: ${sid}`);
    }
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('STUDENTS IN NEW SHIFTS (with template, 6:00-7:00 PM):\n');
  
  for (const sid of newShiftStudents) {
    const studentDoc = await db.collection('users').doc(sid).get();
    if (studentDoc.exists) {
      const data = studentDoc.data();
      const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
      const code = data.student_code || data.studentId || data.student_id || sid;
      console.log(`  - ${fullName} (${code})`);
    } else {
      console.log(`  - Unknown student: ${sid}`);
    }
  }
  
  // Search for Amadou Sidy specifically
  console.log('\n' + '='.repeat(80));
  console.log('SEARCHING FOR "AMADOU SIDY":\n');
  
  const usersSnap = await db.collection('users').get();
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim().toLowerCase();
    
    if (fullName.includes('amadou') && fullName.includes('sidy')) {
      console.log(`Found: ${data.first_name} ${data.last_name}`);
      console.log(`  UID: ${doc.id}`);
      console.log(`  Student Code: ${data.student_code || data.studentId || 'N/A'}`);
      console.log(`  In old shifts: ${oldShiftStudents.has(doc.id) ? 'YES ⚠️' : 'NO'}`);
      console.log(`  In new shifts: ${newShiftStudents.has(doc.id) ? 'YES' : 'NO'}`);
    }
  }
  
  // Also check by searching in student names stored in shifts
  console.log('\n' + '='.repeat(80));
  console.log('CHECKING STUDENT NAMES IN SHIFT DATA:\n');
  
  for (const doc of allShiftsSnap.docs) {
    const data = doc.data();
    const studentNames = data.student_names || [];
    const hasTemplate = !!data.template_id;
    
    for (const name of studentNames) {
      if (name && name.toLowerCase().includes('amadou') && name.toLowerCase().includes('sidy')) {
        const shiftType = hasTemplate ? 'NEW (template)' : 'OLD (no template)';
        const startTime = DateTime.fromJSDate(data.shift_start.toDate()).setZone('America/New_York');
        console.log(`Found "${name}" in ${shiftType} shift:`);
        console.log(`  Shift: ${startTime.toFormat('EEE, MMM dd h:mm a')}`);
        console.log(`  Shift ID: ${doc.id}`);
        console.log('');
      }
    }
  }
}

checkAmadouSidy()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
