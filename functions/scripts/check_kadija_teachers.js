#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase
admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEACHER_OVERRIDES_PATH = path.resolve(__dirname, 'prod_teacher_overrides.json');

// Teachers to check
const TEACHERS_TO_CHECK = [
  'Arabieu Bah',
  'Elham Ahmed Shifa',
  'Nasrullah Jalloh',
  'Habibu Barry'
];

const normalizeName = (value) =>
  (value || '').toString().replace(/[^a-zA-Z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim().toLowerCase();

async function checkTeachers() {
  console.log('Checking if teachers exist in database...\n');

  // Load teacher overrides
  let teacherOverrides = {};
  try {
    const fs = require('fs');
    if (fs.existsSync(TEACHER_OVERRIDES_PATH)) {
      teacherOverrides = JSON.parse(fs.readFileSync(TEACHER_OVERRIDES_PATH, 'utf8'));
      console.log('Loaded teacher overrides:', Object.keys(teacherOverrides));
    }
  } catch (e) {
    console.warn('Could not load teacher overrides:', e.message);
  }

  // Get all teachers from database
  const teacherQuery = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();

  const teachers = [];
  teacherQuery.docs.forEach(doc => {
    const data = doc.data();
    const fullName = ((data.first_name || '') + ' ' + (data.last_name || '')).trim();
    teachers.push({
      uid: doc.id,
      firstName: data.first_name,
      lastName: data.last_name,
      fullName: fullName,
      normalizedName: normalizeName(fullName),
      email: data['e-mail'] || data.email
    });
  });

  console.log(`\nFound ${teachers.length} teachers in database\n`);

  // Check each teacher
  const results = [];
  for (const teacherName of TEACHERS_TO_CHECK) {
    console.log(`\nChecking: ${teacherName}`);
    
    // Check overrides first
    if (teacherOverrides[teacherName]) {
      const uid = teacherOverrides[teacherName];
      const teacher = teachers.find(t => t.uid === uid);
      if (teacher) {
        console.log(`  ✓ Found via override: ${teacher.fullName} (${uid})`);
        results.push({ csvName: teacherName, found: true, teacher });
        continue;
      }
    }

    // Try fuzzy match
    const normalized = normalizeName(teacherName);
    const matches = teachers.filter(t => {
      return t.normalizedName.includes(normalized) || normalized.includes(t.normalizedName);
    });

    if (matches.length === 1) {
      console.log(`  ✓ Found: ${matches[0].fullName} (${matches[0].uid})`);
      results.push({ csvName: teacherName, found: true, teacher: matches[0] });
    } else if (matches.length > 1) {
      console.log(`  ⚠ Multiple matches found:`);
      matches.forEach(m => console.log(`    - ${m.fullName} (${m.uid})`));
      results.push({ csvName: teacherName, found: false, matches });
    } else {
      console.log(`  ✗ NOT FOUND`);
      results.push({ csvName: teacherName, found: false });
    }
  }

  // Summary
  console.log('\n' + '='.repeat(80));
  console.log('SUMMARY');
  console.log('='.repeat(80));
  
  const found = results.filter(r => r.found);
  const notFound = results.filter(r => !r.found);

  console.log(`\nFound: ${found.length}/${TEACHERS_TO_CHECK.length}`);
  found.forEach(r => {
    console.log(`  ✓ ${r.csvName} → ${r.teacher.fullName} (${r.teacher.uid})`);
  });

  if (notFound.length > 0) {
    console.log(`\nNot Found: ${notFound.length}`);
    notFound.forEach(r => {
      console.log(`  ✗ ${r.csvName}`);
      if (r.matches && r.matches.length > 0) {
        console.log(`    Possible matches:`);
        r.matches.forEach(m => console.log(`      - ${m.fullName} (${m.uid})`));
      }
    });
  }
}

checkTeachers()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
