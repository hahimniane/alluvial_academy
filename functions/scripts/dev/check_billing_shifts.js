#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

async function check() {
  const now = DateTime.now().setZone(NYC_TZ);
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  console.log('='.repeat(80));
  
  // Find user by email
  const EMAIL = 'billing@alluwaleducationhub.org';
  
  console.log(`Looking for user: ${EMAIL}\n`);
  
  const usersSnap = await db.collection('users')
    .where('email', '==', EMAIL)
    .get();
  
  if (usersSnap.empty) {
    console.log('User not found by email, searching all users...');
    const allUsersSnap = await db.collection('users').get();
    for (const doc of allUsersSnap.docs) {
      const data = doc.data();
      if (data.email && data.email.toLowerCase().includes('billing')) {
        console.log(`Found: ${doc.id} - ${data.email} - ${data.first_name} ${data.last_name}`);
      }
    }
    return;
  }
  
  const userDoc = usersSnap.docs[0];
  const userData = userDoc.data();
  const userId = userDoc.id;
  
  console.log(`Found user: ${userData.first_name} ${userData.last_name}`);
  console.log(`  UID: ${userId}`);
  console.log(`  Type: ${userData.user_type}`);
  console.log(`  Email: ${userData.email}`);
  
  // Check shifts where this user is teacher
  console.log('\n' + '='.repeat(80));
  console.log('SHIFTS (as teacher):\n');
  
  const teacherShiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', userId)
    .orderBy('created_at', 'desc')
    .limit(20)
    .get();
  
  console.log(`Total shifts as teacher: ${teacherShiftsSnap.size}\n`);
  
  for (const doc of teacherShiftsSnap.docs) {
    const data = doc.data();
    const shiftStart = data.shift_start?.toDate();
    const shiftDt = shiftStart ? DateTime.fromJSDate(shiftStart).setZone(NYC_TZ) : null;
    const createdAt = data.created_at?.toDate();
    const createdDt = createdAt ? DateTime.fromJSDate(createdAt).setZone(NYC_TZ) : null;
    
    console.log(`Shift: ${doc.id}`);
    console.log(`  Students: ${(data.student_names || []).join(', ')}`);
    console.log(`  Time: ${shiftDt?.toFormat('ccc MMM d, h:mm a') || 'unknown'}`);
    console.log(`  Status: ${data.status}`);
    console.log(`  Recurrence: ${data.recurrence}`);
    console.log(`  Template ID: ${data.template_id || 'NONE'}`);
    console.log(`  Created: ${createdDt?.toFormat('MMM d, h:mm:ss a') || 'unknown'}`);
    console.log('');
  }
  
  // Check templates where this user is teacher
  console.log('='.repeat(80));
  console.log('TEMPLATES (as teacher):\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', userId)
    .get();
  
  console.log(`Total templates: ${templatesSnap.size}\n`);
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const days = (data.enhanced_recurrence?.selectedWeekdays || []).map(d => dayNames[d]);
    const createdAt = data.created_at?.toDate();
    const createdDt = createdAt ? DateTime.fromJSDate(createdAt).setZone(NYC_TZ) : null;
    
    console.log(`Template: ${doc.id}`);
    console.log(`  Students: ${(data.student_names || []).join(', ')}`);
    console.log(`  Time: ${data.start_time} - ${data.end_time}`);
    console.log(`  Days: ${days.join(', ') || 'none'}`);
    console.log(`  Recurrence type: ${data.enhanced_recurrence?.type || data.recurrence}`);
    console.log(`  Active: ${data.is_active}`);
    console.log(`  Max days ahead: ${data.max_days_ahead}`);
    console.log(`  End date: ${data.recurrence_end_date?.toDate?.()?.toISOString?.() || data.enhanced_recurrence?.endDate || 'none'}`);
    console.log(`  Created: ${createdDt?.toFormat('MMM d, h:mm:ss a') || 'unknown'}`);
    console.log('');
  }
  
  // Also check if user is a student in any shifts
  console.log('='.repeat(80));
  console.log('SHIFTS (as student):\n');
  
  const studentShiftsSnap = await db.collection('teaching_shifts')
    .where('student_ids', 'array-contains', userId)
    .orderBy('created_at', 'desc')
    .limit(10)
    .get();
  
  console.log(`Total shifts as student: ${studentShiftsSnap.size}`);
}

check()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
