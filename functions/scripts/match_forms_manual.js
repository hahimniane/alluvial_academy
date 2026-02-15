#!/usr/bin/env node
'use strict';

/**
 * Match Class Readiness Forms with MANUAL teacher mappings
 */

const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const fs = require('fs');
const path = require('path');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

// Parse CSV
function parseCSV(content) {
  const lines = content.split('\n');
  const headers = lines[0].split(',');
  const rows = [];
  
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    
    const values = [];
    let current = '';
    let inQuotes = false;
    
    for (const char of lines[i]) {
      if (char === '"') {
        inQuotes = !inQuotes;
      } else if (char === ',' && !inQuotes) {
        values.push(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    values.push(current.trim());
    
    const row = {};
    headers.forEach((header, idx) => {
      row[header.trim()] = values[idx] || '';
    });
    rows.push(row);
  }
  
  return rows;
}

function normalizeName(name) {
  return (name || '').toLowerCase().replace(/[^a-z\s]/g, '').replace(/\s+/g, ' ').trim();
}

function parseFormDate(dateStr) {
  if (!dateStr) return null;
  const parts = dateStr.split(' ')[0].split('/');
  if (parts.length !== 3) return null;
  return DateTime.fromObject({
    month: parseInt(parts[0]),
    day: parseInt(parts[1]),
    year: parseInt(parts[2])
  }, { zone: NYC_TZ });
}

function parseStudentNames(studentsStr) {
  if (!studentsStr) return [];
  const lower = studentsStr.toLowerCase();
  if (lower.includes('absent') || lower === 'n/a' || lower === 'none' || lower === 'no one' || lower === 'na' || lower === 'n\\a') {
    return [];
  }
  return studentsStr
    .replace(/\s+and\s+/gi, ',')
    .replace(/\s*,\s*/g, ',')
    .split(',')
    .map(s => s.trim())
    .filter(s => s && s.length > 2 && !s.toLowerCase().includes('absent') && s.toLowerCase() !== 'na' && s.toLowerCase() !== 'n/a');
}

async function matchFormsManual() {
  console.log('='.repeat(80));
  console.log('MATCHING READINESS FORMS WITH MANUAL TEACHER MAPPINGS');
  console.log('='.repeat(80));
  console.log('');

  // Load all teachers
  const teachersSnap = await db.collection('users').where('user_type', '==', 'teacher').get();
  const dbTeachers = new Map();
  
  console.log('DATABASE TEACHERS:');
  console.log('-'.repeat(80));
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    const email = data['e-mail'] || data.email || '';
    dbTeachers.set(doc.id, { id: doc.id, name: fullName, email });
    console.log(`  ${doc.id.substring(0, 20).padEnd(22)} | ${fullName.padEnd(30)} | ${email}`);
  }
  console.log('');

  // Load all students
  const studentsSnap = await db.collection('users').where('user_type', '==', 'student').get();
  const dbStudents = new Map();
  const studentsByName = new Map(); // For fuzzy matching
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    dbStudents.set(doc.id, { id: doc.id, name: fullName });
    studentsByName.set(normalizeName(fullName), { id: doc.id, name: fullName });
  }
  console.log(`Loaded ${dbStudents.size} students from database\n`);

  // Load existing January shifts
  const jan1 = DateTime.fromObject({ year: 2026, month: 1, day: 1 }, { zone: NYC_TZ }).startOf('day');
  const jan31 = DateTime.fromObject({ year: 2026, month: 1, day: 31 }, { zone: NYC_TZ }).endOf('day');
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(jan1.toJSDate()))
    .where('shift_start', '<=', admin.firestore.Timestamp.fromDate(jan31.toJSDate()))
    .get();
  
  const dbShifts = new Map();
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    const start = data.shift_start?.toDate();
    if (start) {
      const dt = DateTime.fromJSDate(start).setZone(NYC_TZ);
      const key = `${dt.toFormat('yyyy-MM-dd')}_${data.teacher_id}`;
      if (!dbShifts.has(key)) {
        dbShifts.set(key, []);
      }
      dbShifts.get(key).push({
        id: doc.id,
        teacherId: data.teacher_id,
        teacherName: data.teacher_name,
        studentNames: data.student_names || [],
        studentIds: data.student_ids || [],
        start: dt.toFormat('HH:mm'),
      });
    }
  }
  console.log(`Loaded ${shiftsSnap.docs.length} existing January shifts\n`);

  // MANUAL TEACHER MAPPINGS based on known aliases
  // Form Name -> Database Teacher ID
  const TEACHER_MAPPINGS = {};

  // First, let's find the actual teacher IDs by searching names
  for (const [id, teacher] of dbTeachers) {
    const lower = teacher.name.toLowerCase();
    const email = teacher.email.toLowerCase();
    
    // Map based on name patterns
    if (lower.includes('mama') && lower.includes('diallo')) {
      TEACHER_MAPPINGS['Mama'] = id;
    }
    if (lower.includes('habibu') && lower.includes('barry')) {
      TEACHER_MAPPINGS['Habibu'] = id;
    }
    if (lower.includes('arabieu') && lower.includes('bah')) {
      TEACHER_MAPPINGS['Arabieu'] = id;
    }
    if (lower.includes('ibrahim') && lower.includes('baldee')) {
      TEACHER_MAPPINGS['Ibrahim Balde'] = id;
    }
    if (lower.includes('ibrahim') && lower.includes('bah')) {
      TEACHER_MAPPINGS['Iberahim Bah'] = id;
    }
    if (lower.includes('abdullah') && lower.includes('baldee')) {
      TEACHER_MAPPINGS['Abdullah Balde'] = id;
    }
    if (lower.includes('al-hassan') && lower.includes('diallo')) {
      TEACHER_MAPPINGS['Al-hassan'] = id;
    }
    if (lower.includes('thierno') && lower.includes('aliou')) {
      TEACHER_MAPPINGS['Aliou Diallo'] = id;
    }
    if (lower.includes('abdoullahi') && lower.includes('yaya')) {
      TEACHER_MAPPINGS['Abdoullahi Yayah'] = id;
      TEACHER_MAPPINGS['Ustaz Abdullah Yahya'] = id;
    }
    if (lower.includes('ahmed') && lower.includes('korka')) {
      TEACHER_MAPPINGS['Korka'] = id;
    }
    if (lower.includes('muhammed') && lower.includes('sheriff')) {
      TEACHER_MAPPINGS['Sheriff'] = id;
    }
    if (lower.includes('asma') && lower.includes('mugtiu')) {
      TEACHER_MAPPINGS['Asma'] = id;
    }
    if (lower.includes('ousman') && lower.includes('cham')) {
      TEACHER_MAPPINGS['Thiam'] = id;
    }
    if (lower.includes('cherno') && lower.includes('ahmadu')) {
      TEACHER_MAPPINGS['Chernor Ahmadu'] = id;
    }
    if (lower.includes('mamadou') && lower.includes('saidou')) {
      TEACHER_MAPPINGS['Saidou'] = id;
    }
    if (lower.includes('nasrullah') && lower.includes('jalloh')) {
      TEACHER_MAPPINGS['NasrulAllah'] = id;
    }
    if (lower.includes('rahmatullaah') && lower.includes('balde')) {
      TEACHER_MAPPINGS['Rahmatulah'] = id;
    }
    if (lower.includes('thierno') && lower.includes('abdoul') && lower.includes('diallo')) {
      TEACHER_MAPPINGS['Thierno Abdoul'] = id;
    }
    if (lower.includes('abdulai') && lower.includes('diallo')) {
      TEACHER_MAPPINGS['Abdulai Diallo'] = id;
    }
    if (email.includes('test') || lower.includes('test')) {
      TEACHER_MAPPINGS['Teacher 1'] = id;
    }
  }

  console.log('='.repeat(80));
  console.log('TEACHER MAPPING RESULTS');
  console.log('='.repeat(80));
  console.log('');
  console.log('Form Name'.padEnd(25) + '→ ' + 'Database ID'.padEnd(30) + 'Database Name');
  console.log('-'.repeat(90));
  
  // Parse CSV
  const csvPath = path.join(__dirname, '../../Class Readiness Form_Formulaire de pr_paration aux cours - Khadijatu_submissions.csv');
  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  const rows = parseCSV(csvContent);

  const teacherCol = Object.keys(rows[0]).find(k => k.includes('Select your name below'));
  const studentsCol = Object.keys(rows[0]).find(k => k.includes('List the name of students who are present'));
  const submittedCol = 'Submitted At';

  // Get unique form teachers
  const formTeachers = new Set(rows.map(r => r[teacherCol]).filter(Boolean));
  const unmappedTeachers = [];
  
  for (const formName of Array.from(formTeachers).sort()) {
    const dbId = TEACHER_MAPPINGS[formName];
    if (dbId) {
      const teacher = dbTeachers.get(dbId);
      console.log(`${formName.padEnd(25)}→ ${dbId.substring(0, 28).padEnd(30)} ${teacher?.name || '?'}`);
    } else {
      unmappedTeachers.push(formName);
      console.log(`${formName.padEnd(25)}→ ❌ NOT MAPPED`);
    }
  }

  if (unmappedTeachers.length > 0) {
    console.log('\n⚠️  TEACHERS NOT MAPPED - Need manual assignment:');
    for (const name of unmappedTeachers) {
      console.log(`   "${name}"`);
    }
  }

  // ============================================
  // STUDENT MATCHING
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('STUDENT NAME ANALYSIS');
  console.log('='.repeat(80));
  console.log('');

  // Get unique students from forms
  const formStudentSet = new Map(); // name -> count
  for (const row of rows) {
    const students = parseStudentNames(row[studentsCol]);
    for (const s of students) {
      formStudentSet.set(s, (formStudentSet.get(s) || 0) + 1);
    }
  }

  // Try to match each
  const studentMatches = new Map();
  const unmatchedStudents = [];
  
  for (const [formName, count] of formStudentSet) {
    const normalized = normalizeName(formName);
    
    // Try exact match first
    let match = studentsByName.get(normalized);
    
    // Try partial matches
    if (!match) {
      for (const [dbNorm, student] of studentsByName) {
        if (dbNorm.includes(normalized) || normalized.includes(dbNorm)) {
          match = student;
          break;
        }
        // Try first name match
        const formWords = normalized.split(' ');
        const dbWords = dbNorm.split(' ');
        if (formWords.some(fw => dbWords.some(dw => fw === dw && fw.length > 3))) {
          match = student;
          break;
        }
      }
    }
    
    if (match) {
      studentMatches.set(formName, match);
    } else {
      unmatchedStudents.push({ name: formName, count });
    }
  }

  console.log(`Matched ${studentMatches.size}/${formStudentSet.size} unique student names\n`);
  
  console.log('MATCHED STUDENTS:');
  console.log('-'.repeat(100));
  console.log('Form Name'.padEnd(35) + '→ ' + 'Database Name'.padEnd(35) + 'ID');
  console.log('-'.repeat(100));
  
  for (const [formName, match] of Array.from(studentMatches.entries()).sort((a, b) => a[0].localeCompare(b[0]))) {
    console.log(`${formName.substring(0, 33).padEnd(35)}→ ${match.name.substring(0, 33).padEnd(35)} ${match.id.substring(0, 25)}`);
  }

  if (unmatchedStudents.length > 0) {
    console.log('\n⚠️  UNMATCHED STUDENTS (by frequency):');
    unmatchedStudents.sort((a, b) => b.count - a.count);
    for (const { name, count } of unmatchedStudents.slice(0, 50)) {
      console.log(`   "${name}" (appears ${count}x)`);
    }
    if (unmatchedStudents.length > 50) {
      console.log(`   ... and ${unmatchedStudents.length - 50} more`);
    }
  }

  // ============================================
  // COMPARE FORMS TO SHIFTS BY DATE
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('FORMS VS EXISTING SHIFTS BY DATE');
  console.log('='.repeat(80));
  console.log('');

  const formsByDate = new Map();
  let totalMatched = 0;
  let totalMissing = 0;

  for (const row of rows) {
    const submittedDate = parseFormDate(row[submittedCol]);
    if (!submittedDate || submittedDate.month !== 1 || submittedDate.year !== 2026) continue;
    
    const dateStr = submittedDate.toFormat('yyyy-MM-dd');
    const formTeacher = row[teacherCol];
    const teacherId = TEACHER_MAPPINGS[formTeacher];
    
    if (!formsByDate.has(dateStr)) {
      formsByDate.set(dateStr, { total: 0, matched: 0, missing: [] });
    }
    
    const dayData = formsByDate.get(dateStr);
    dayData.total++;
    
    // Check if shift exists
    const shiftKey = `${dateStr}_${teacherId}`;
    const existingShifts = dbShifts.get(shiftKey) || [];
    
    if (existingShifts.length > 0) {
      dayData.matched++;
      totalMatched++;
    } else {
      dayData.missing.push({
        teacher: formTeacher,
        teacherId,
        students: parseStudentNames(row[studentsCol]),
      });
      totalMissing++;
    }
  }

  console.log('Date'.padEnd(15) + 'Total'.padStart(8) + 'Matched'.padStart(10) + 'Missing'.padStart(10));
  console.log('-'.repeat(45));
  
  for (const [date, data] of Array.from(formsByDate.entries()).sort()) {
    console.log(`${date.padEnd(15)}${data.total.toString().padStart(8)}${data.matched.toString().padStart(10)}${(data.total - data.matched).toString().padStart(10)}`);
  }
  
  console.log('-'.repeat(45));
  console.log(`${'TOTAL'.padEnd(15)}${(totalMatched + totalMissing).toString().padStart(8)}${totalMatched.toString().padStart(10)}${totalMissing.toString().padStart(10)}`);

  // ============================================
  // MISSING SHIFTS DETAIL
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('MISSING SHIFTS BY TEACHER');
  console.log('='.repeat(80));
  console.log('');

  const missingByTeacher = new Map();
  for (const [date, data] of formsByDate) {
    for (const missing of data.missing) {
      if (!missingByTeacher.has(missing.teacher)) {
        missingByTeacher.set(missing.teacher, []);
      }
      missingByTeacher.get(missing.teacher).push({
        date,
        students: missing.students,
      });
    }
  }

  for (const [teacher, entries] of Array.from(missingByTeacher.entries()).sort((a, b) => b[1].length - a[1].length)) {
    const teacherId = TEACHER_MAPPINGS[teacher];
    const dbTeacher = teacherId ? dbTeachers.get(teacherId) : null;
    
    console.log(`\n${teacher} (${entries.length} missing shifts)`);
    console.log(`  Database ID: ${teacherId || 'NOT MAPPED'}`);
    console.log(`  Database Name: ${dbTeacher?.name || 'N/A'}`);
    console.log('  Missing dates:');
    
    const byDate = new Map();
    for (const e of entries) {
      if (!byDate.has(e.date)) {
        byDate.set(e.date, []);
      }
      byDate.get(e.date).push(e.students.join(', ') || 'No students');
    }
    
    for (const [date, classes] of Array.from(byDate.entries()).sort()) {
      console.log(`    ${date}: ${classes.length} class(es)`);
    }
  }

  // ============================================
  // FINAL SUMMARY
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('FINAL SUMMARY');
  console.log('='.repeat(80));
  console.log('');
  console.log(`Total form submissions: ${rows.length}`);
  console.log(`January 2026 forms: ${totalMatched + totalMissing}`);
  console.log(`Forms with existing shifts: ${totalMatched}`);
  console.log(`Forms WITHOUT shifts: ${totalMissing}`);
  console.log('');
  console.log(`Teachers mapped: ${Object.keys(TEACHER_MAPPINGS).length}/${formTeachers.size}`);
  console.log(`Unmapped teachers: ${unmappedTeachers.join(', ') || 'None'}`);
  console.log('');
  console.log(`Students matched: ${studentMatches.size}/${formStudentSet.size}`);
  console.log(`Unmatched students: ${unmatchedStudents.length}`);
}

matchFormsManual()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
