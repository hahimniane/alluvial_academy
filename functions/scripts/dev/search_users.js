#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function search() {
  console.log('='.repeat(80));
  console.log('Searching for users matching "ousman" or "cham"...\n');
  
  const usersSnap = await db.collection('users').get();
  
  console.log(`Total users: ${usersSnap.size}\n`);
  
  console.log('TEACHERS matching ousman/cham:');
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.firstName || ''} ${data.lastName || ''}`.toLowerCase();
    const email = (data.email || '').toLowerCase();
    
    if ((fullName.includes('ousman') || fullName.includes('cham') || email.includes('cham')) && data.role === 'teacher') {
      console.log(`  ${data.firstName} ${data.lastName} | Role: ${data.role} | Email: ${data.email} | ID: ${doc.id}`);
    }
  }
  
  console.log('\nSTUDENTS matching mariam/diallo:');
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.firstName || ''} ${data.lastName || ''}`.toLowerCase();
    const code = (data.studentCode || '').toLowerCase();
    
    if ((fullName.includes('mariam') || code.includes('mariam')) && data.role === 'student') {
      console.log(`  ${data.firstName} ${data.lastName} | Code: ${data.studentCode} | ID: ${doc.id}`);
    }
  }
  
  // Also search templates directly
  console.log('\n' + '='.repeat(80));
  console.log('TEMPLATES with teacher name containing "ousman" or "cham":\n');
  
  const templatesSnap = await db.collection('shift_templates').get();
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const teacherName = (data.teacher_name || '').toLowerCase();
    
    if (teacherName.includes('ousman') || teacherName.includes('cham')) {
      console.log(`Template: ${doc.id}`);
      console.log(`  Teacher: ${data.teacher_name} (${data.teacher_id})`);
      console.log(`  Time: ${data.start_time} - ${data.end_time}`);
      console.log(`  Students: ${(data.student_names || []).join(', ')}`);
      console.log(`  Active: ${data.is_active}`);
      console.log('');
    }
  }
  
  // Search shifts directly
  console.log('='.repeat(80));
  console.log('SHIFTS with teacher name containing "ousman" or "cham" (recent 20):\n');
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .orderBy('start_time', 'desc')
    .limit(500)
    .get();
  
  let count = 0;
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    const teacherName = (data.teacher_name || '').toLowerCase();
    
    if ((teacherName.includes('ousman') || teacherName.includes('cham')) && count < 20) {
      const start = data.start_time?.toDate ? data.start_time.toDate().toISOString() : 'N/A';
      console.log(`Shift: ${doc.id}`);
      console.log(`  Teacher: ${data.teacher_name}`);
      console.log(`  Start: ${start}`);
      console.log(`  Students: ${(data.student_names || []).join(', ')}`);
      console.log(`  Template: ${data.template_id || 'none'}`);
      console.log('');
      count++;
    }
  }
}

search()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
