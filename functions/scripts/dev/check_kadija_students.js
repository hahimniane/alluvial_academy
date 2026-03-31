#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

// Initialize Firebase
admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

// Students to check (from 4 confirmed teachers only)
const STUDENTS_TO_CHECK = [
  // Arabieu Bah's students
  { name: 'Yacuba', id: 'yacouba.barry', teacher: 'Arabieu Bah' },
  { name: 'Djenabou Diallo', id: 'djenabou.diallo', teacher: 'Arabieu Bah' },
  { name: 'Mariama Diallo', id: '1mariam.diallo', teacher: 'Arabieu Bah' },
  { name: 'Maya Fofana', id: 'maya.fofana', teacher: 'Arabieu Bah' },
  { name: 'Allen Syron', id: 'allen.syron', teacher: 'Arabieu Bah' },
  
  // Elham Ahmed Shifa's students
  { name: 'Abdul Rahman', id: 'abdurahman.diallo', teacher: 'Elham Ahmed Shifa' },
  { name: 'Adama', id: 'adama.diallo', teacher: 'Elham Ahmed Shifa' },
  { name: 'Goundo', id: 'goundo.diarra', teacher: 'Elham Ahmed Shifa' },
  
  // Nasrullah Jalloh's students
  { name: 'Mariam Bah', id: '2mariam.diallo', teacher: 'Nasrullah Jalloh' },
  { name: 'Hawa Diallo', id: '1hawa.diallo', teacher: 'Nasrullah Jalloh' },
  
  // Habibu Barry's students
  { name: 'Aissata Diallo', id: '1aissata.diallo', teacher: 'Habibu Barry' },
  { name: 'Hadiyatou Diallo', id: 'hadiatu.diallo', teacher: 'Habibu Barry' },
  { name: 'Mamadou Bobo', id: 'mamadoubob.diallo', teacher: 'Habibu Barry' },
  { name: 'Abdul Rahman Diallo', id: 'abdulrahma.diallo', teacher: 'Habibu Barry' },
  { name: 'Assatu Barry', id: 'aissata.barry', teacher: 'Habibu Barry' },
  { name: 'Fatumata Barry', id: 'fatumata.barry', teacher: 'Habibu Barry' },
];

async function checkStudents() {
  console.log(`Checking ${STUDENTS_TO_CHECK.length} students in database...\n`);

  // Get all users from database
  const usersQuery = await db.collection('users').get();
  
  const usersById = new Map();
  usersQuery.docs.forEach(doc => {
    const data = doc.data();
    const studentId = data.student_id || data.studentId || data.student_code;
    if (studentId) {
      usersById.set(studentId.toLowerCase().trim(), {
        uid: doc.id,
        firstName: data.first_name,
        lastName: data.last_name,
        studentId: studentId,
        userType: data.user_type,
        email: data['e-mail'] || data.email
      });
    }
  });

  console.log(`Found ${usersById.size} users with student IDs in database\n`);

  // Check each student
  const results = [];
  const notFound = [];
  
  for (const student of STUDENTS_TO_CHECK) {
    const found = usersById.get(student.id.toLowerCase().trim());
    
    if (found) {
      console.log(`✓ ${student.name} (${student.id})`);
      console.log(`  → ${found.firstName} ${found.lastName} [${found.uid}]`);
      console.log(`  → User Type: ${found.userType || 'N/A'}`);
      results.push({ 
        csvName: student.name, 
        csvId: student.id, 
        found: true, 
        user: found,
        teacher: student.teacher
      });
    } else {
      console.log(`✗ ${student.name} (${student.id}) - NOT FOUND`);
      notFound.push(student);
    }
    console.log('');
  }

  // Summary
  console.log('='.repeat(80));
  console.log('SUMMARY');
  console.log('='.repeat(80));
  
  console.log(`\nFound: ${results.length}/${STUDENTS_TO_CHECK.length}`);
  
  if (notFound.length > 0) {
    console.log(`\n❌ NOT FOUND: ${notFound.length} students`);
    notFound.forEach(s => {
      console.log(`  ✗ ${s.name} (${s.id}) - Teacher: ${s.teacher}`);
    });
    console.log('\nThese students need to be created or their IDs need to be corrected before creating shifts.');
  } else {
    console.log('\n✅ All students found! Ready to create shifts.');
  }

  // Group by teacher
  console.log('\n' + '='.repeat(80));
  console.log('BY TEACHER');
  console.log('='.repeat(80));
  
  const teachers = ['Arabieu Bah', 'Elham Ahmed Shifa', 'Nasrullah Jalloh', 'Habibu Barry'];
  teachers.forEach(teacherName => {
    const teacherStudents = results.filter(r => r.teacher === teacherName);
    const teacherMissing = notFound.filter(s => s.teacher === teacherName);
    
    console.log(`\n${teacherName}:`);
    console.log(`  Found: ${teacherStudents.length} students`);
    teacherStudents.forEach(s => {
      console.log(`    ✓ ${s.csvName} (${s.csvId})`);
    });
    
    if (teacherMissing.length > 0) {
      console.log(`  Missing: ${teacherMissing.length} students`);
      teacherMissing.forEach(s => {
        console.log(`    ✗ ${s.name} (${s.id})`);
      });
    }
  });
}

checkStudents()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
