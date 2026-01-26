#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const STUDENT_CODES_TO_CHECK = [
  'mariamdian.bah',
  'mariatudia.bah',
  'fatoumatad.bah',
  'mohamed.conteh',
  'ibrahim.conteh',
  'abdoulmash.diallo',
  'alpha.barry',
];

async function checkStudents() {
  console.log('Checking if all students exist in the database...\n');
  console.log('='.repeat(80));
  
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
        email: data.email || 'N/A',
      });
    }
  }
  
  console.log('\nResults:\n');
  
  let allFound = true;
  
  for (const code of STUDENT_CODES_TO_CHECK) {
    const student = studentMap.get(code);
    if (student) {
      console.log(`✅ ${code}`);
      console.log(`   Name: ${student.name}`);
      console.log(`   UID: ${student.uid}`);
      console.log(`   Email: ${student.email}`);
      console.log('');
    } else {
      console.log(`❌ ${code} - NOT FOUND`);
      console.log('');
      allFound = false;
    }
  }
  
  console.log('='.repeat(80));
  
  if (allFound) {
    console.log('\n✅ All students exist in the system!');
  } else {
    console.log('\n❌ Some students are missing!');
  }
}

checkStudents()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
