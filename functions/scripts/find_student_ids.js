#!/usr/bin/env node
'use strict';

/**
 * Find exact student IDs for the unmatched spelling variations
 */

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function findStudentIds() {
  console.log('='.repeat(80));
  console.log('FINDING EXACT STUDENT IDS FOR SPELLING VARIATIONS');
  console.log('='.repeat(80));
  console.log('');

  // Load all students
  const studentsSnap = await db.collection('users').where('user_type', '==', 'student').get();
  
  const students = [];
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    students.push({
      id: doc.id,
      firstName: data.first_name || '',
      lastName: data.last_name || '',
      fullName: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
      email: data['e-mail'] || data.email || '',
    });
  }

  // Search patterns for unmatched students
  const searchTerms = [
    { form: 'Kadijah', searchPatterns: ['khadijah', 'kadijah', 'kadija'] },
    { form: 'Idrissatu', searchPatterns: ['idrissatou', 'idrissatu', 'idrissat'] },
    { form: 'nafisatou', searchPatterns: ['nafisatou', 'nafisatu', 'nafisa'] },
    { form: 'Binta', searchPatterns: ['binta'] },
    { form: 'fatima/FATIMAH', searchPatterns: ['fatima', 'fatimah', 'fatoumata', 'fatimatou'] },
    { form: 'mariatou', searchPatterns: ['mariatou', 'mariatu', 'mariam'] },
  ];

  for (const search of searchTerms) {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`Form name: "${search.form}"`);
    console.log(`${'='.repeat(60)}`);
    
    const matches = [];
    for (const student of students) {
      const nameLower = student.fullName.toLowerCase();
      const firstLower = student.firstName.toLowerCase();
      
      for (const pattern of search.searchPatterns) {
        if (nameLower.includes(pattern) || firstLower.includes(pattern)) {
          matches.push(student);
          break;
        }
      }
    }
    
    if (matches.length > 0) {
      console.log(`Found ${matches.length} potential matches:\n`);
      for (const m of matches) {
        console.log(`  ID: ${m.id}`);
        console.log(`  Name: ${m.fullName}`);
        console.log(`  Email: ${m.email}`);
        console.log('');
      }
    } else {
      console.log('  No matches found in database');
    }
  }

  // Now let's also check which students are assigned to each teacher in existing shifts
  console.log('\n');
  console.log('='.repeat(80));
  console.log('STUDENTS BY TEACHER (from existing shifts)');
  console.log('='.repeat(80));
  
  // Teacher IDs we care about
  const teachersToCheck = [
    { name: 'Mama S Diallo', id: 'KTEcG1j2qocbLphNr1MisQSCKOS2' },
    { name: 'Abdullah Baldee', id: 'XBm5dxyerccp49BgBLw8pW02T8R2' },
    { name: 'Abdulai Diallo', id: 'aWp1Yor06qRvv6ES9DkVp3YmVRs2' },
    { name: 'Ibrahim Baldee', id: 'zfMLKTXNFQdlPsVomdmYkSdNVqk2' },
    { name: 'Abdoullahi Yaya', id: 'SQetTfLDFGTir9WZ4ivWVRboHpZ2' },
  ];

  for (const teacher of teachersToCheck) {
    console.log(`\n${teacher.name} (${teacher.id}):`);
    console.log('-'.repeat(60));
    
    // Get shifts for this teacher
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('teacher_id', '==', teacher.id)
      .limit(50)
      .get();
    
    const studentSet = new Map();
    for (const doc of shiftsSnap.docs) {
      const data = doc.data();
      const studentIds = data.student_ids || [];
      const studentNames = data.student_names || [];
      
      for (let i = 0; i < studentIds.length; i++) {
        if (!studentSet.has(studentIds[i])) {
          studentSet.set(studentIds[i], studentNames[i] || 'Unknown');
        }
      }
    }
    
    console.log(`  Total unique students in shifts: ${studentSet.size}`);
    for (const [id, name] of studentSet) {
      console.log(`    ${name.padEnd(30)} | ${id}`);
    }
  }
}

findStudentIds()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
