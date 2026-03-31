#!/usr/bin/env node
'use strict';

/**
 * Match forms to database using:
 * 1. Teacher EMAILS for exact matching
 * 2. Existing shifts (Jan 23+) to identify student IDs
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

async function matchFormsByEmail() {
  console.log('='.repeat(80));
  console.log('MATCHING FORMS BY EMAIL + SHIFT-BASED STUDENT MATCHING');
  console.log('='.repeat(80));
  console.log('');

  // ============================================
  // STEP 1: Load all teachers by email
  // ============================================
  console.log('Loading teachers from database...');
  const teachersSnap = await db.collection('users').where('user_type', '==', 'teacher').get();
  const dbTeachersByEmail = new Map();
  const dbTeachersById = new Map();
  
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    const email = (data['e-mail'] || data.email || '').toLowerCase().trim();
    const teacher = { id: doc.id, name: fullName, email };
    
    if (email) {
      dbTeachersByEmail.set(email, teacher);
    }
    dbTeachersById.set(doc.id, teacher);
  }
  console.log(`Found ${teachersSnap.docs.length} teachers\n`);

  // ============================================
  // STEP 2: Load all students
  // ============================================
  console.log('Loading students from database...');
  const studentsSnap = await db.collection('users').where('user_type', '==', 'student').get();
  const dbStudents = new Map();
  const studentsByNormalizedName = new Map();
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    const student = { id: doc.id, name: fullName, firstName: data.first_name, lastName: data.last_name };
    dbStudents.set(doc.id, student);
    studentsByNormalizedName.set(normalizeName(fullName), student);
  }
  console.log(`Found ${dbStudents.size} students\n`);

  // ============================================
  // STEP 3: Load existing shifts (to get teacher-student relationships)
  // ============================================
  console.log('Loading all teaching shifts...');
  const shiftsSnap = await db.collection('teaching_shifts').get();
  
  // Build teacher -> students mapping from shifts
  const teacherStudentsMap = new Map(); // teacherId -> Set of {studentId, studentName}
  const shiftsByTeacherDate = new Map(); // `${teacherId}_${date}` -> shifts
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    const teacherId = data.teacher_id;
    const studentIds = data.student_ids || [];
    const studentNames = data.student_names || [];
    const shiftStart = data.shift_start?.toDate();
    
    if (!teacherId) continue;
    
    // Build teacher-students relationships
    if (!teacherStudentsMap.has(teacherId)) {
      teacherStudentsMap.set(teacherId, new Map());
    }
    const studentsForTeacher = teacherStudentsMap.get(teacherId);
    
    for (let i = 0; i < studentIds.length; i++) {
      const studentId = studentIds[i];
      const studentName = studentNames[i] || '';
      if (studentId && !studentsForTeacher.has(studentId)) {
        studentsForTeacher.set(studentId, studentName);
      }
    }
    
    // Index shifts by teacher and date
    if (shiftStart) {
      const dt = DateTime.fromJSDate(shiftStart).setZone(NYC_TZ);
      const key = `${teacherId}_${dt.toFormat('yyyy-MM-dd')}`;
      if (!shiftsByTeacherDate.has(key)) {
        shiftsByTeacherDate.set(key, []);
      }
      shiftsByTeacherDate.get(key).push({
        id: doc.id,
        studentIds,
        studentNames,
        start: dt.toFormat('HH:mm'),
      });
    }
  }
  console.log(`Loaded ${shiftsSnap.docs.length} shifts\n`);

  // ============================================
  // STEP 4: Parse CSV and match teachers by email
  // ============================================
  console.log('Parsing readiness form CSV...');
  const csvPath = path.join(__dirname, '../../Class Readiness Form_Formulaire de pr_paration aux cours - Khadijatu_submissions.csv');
  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  const rows = parseCSV(csvContent);

  const teacherCol = Object.keys(rows[0]).find(k => k.includes('Select your name below'));
  const studentsCol = Object.keys(rows[0]).find(k => k.includes('List the name of students who are present'));
  const submittedCol = 'Submitted At';
  const emailCol = 'Email';

  // Match teachers by email
  console.log('\n');
  console.log('='.repeat(80));
  console.log('TEACHER MATCHING BY EMAIL');
  console.log('='.repeat(80));
  console.log('');

  const formEmailToTeacher = new Map();
  const unmatchedEmails = [];
  
  // Get unique form teacher entries (name + email)
  const formTeacherEntries = new Map(); // email -> {name, email}
  for (const row of rows) {
    const email = (row[emailCol] || '').toLowerCase().trim();
    const name = row[teacherCol] || '';
    if (email && !formTeacherEntries.has(email)) {
      formTeacherEntries.set(email, { name, email });
    }
  }

  console.log('Form Email'.padEnd(40) + 'Form Name'.padEnd(25) + '→ DB Name'.padEnd(30) + 'DB ID');
  console.log('-'.repeat(120));
  
  for (const [email, entry] of Array.from(formTeacherEntries.entries()).sort((a, b) => a[1].name.localeCompare(b[1].name))) {
    const dbTeacher = dbTeachersByEmail.get(email);
    if (dbTeacher) {
      formEmailToTeacher.set(email, dbTeacher);
      console.log(`${email.substring(0, 38).padEnd(40)}${entry.name.padEnd(25)}→ ${dbTeacher.name.padEnd(30)}${dbTeacher.id.substring(0, 24)}`);
    } else {
      unmatchedEmails.push(entry);
      console.log(`${email.substring(0, 38).padEnd(40)}${entry.name.padEnd(25)}→ ❌ NOT FOUND IN DATABASE`);
    }
  }

  if (unmatchedEmails.length > 0) {
    console.log('\n⚠️  TEACHERS WITH UNMATCHED EMAILS:');
    for (const e of unmatchedEmails) {
      console.log(`   "${e.name}" (${e.email})`);
    }
  }

  // ============================================
  // STEP 5: Match students using teacher's existing shifts
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('STUDENT MATCHING USING EXISTING SHIFTS');
  console.log('='.repeat(80));
  console.log('');

  // Collect all form student names with their teacher
  const formStudentsByTeacher = new Map(); // teacherId -> Map(normalizedName -> {originalName, count})
  
  for (const row of rows) {
    const email = (row[emailCol] || '').toLowerCase().trim();
    const teacher = formEmailToTeacher.get(email);
    if (!teacher) continue;
    
    const students = parseStudentNames(row[studentsCol]);
    
    if (!formStudentsByTeacher.has(teacher.id)) {
      formStudentsByTeacher.set(teacher.id, new Map());
    }
    const studentMap = formStudentsByTeacher.get(teacher.id);
    
    for (const s of students) {
      const norm = normalizeName(s);
      if (!studentMap.has(norm)) {
        studentMap.set(norm, { originalName: s, count: 0 });
      }
      studentMap.get(norm).count++;
    }
  }

  // Now match each form student to database using teacher's known students
  const finalStudentMatches = new Map(); // normalizedFormName -> {studentId, studentName, matchMethod}
  const unmatchedStudentsByTeacher = new Map();

  for (const [teacherId, formStudents] of formStudentsByTeacher) {
    const teacherShiftStudents = teacherStudentsMap.get(teacherId) || new Map();
    const teacher = dbTeachersById.get(teacherId);
    
    console.log(`\n${teacher?.name || teacherId}:`);
    console.log(`  Students from shifts: ${teacherShiftStudents.size}`);
    console.log(`  Students from forms: ${formStudents.size}`);
    
    const matched = [];
    const unmatched = [];
    
    for (const [normFormName, formData] of formStudents) {
      let matchFound = false;
      
      // Try to match with teacher's shift students
      for (const [studentId, shiftStudentName] of teacherShiftStudents) {
        const normShiftName = normalizeName(shiftStudentName);
        
        // Exact match
        if (normFormName === normShiftName) {
          finalStudentMatches.set(normFormName, { studentId, studentName: shiftStudentName, matchMethod: 'exact' });
          matched.push({ form: formData.originalName, db: shiftStudentName, id: studentId, method: 'exact' });
          matchFound = true;
          break;
        }
        
        // Partial match (one contains the other)
        if (normFormName.includes(normShiftName) || normShiftName.includes(normFormName)) {
          finalStudentMatches.set(normFormName, { studentId, studentName: shiftStudentName, matchMethod: 'partial' });
          matched.push({ form: formData.originalName, db: shiftStudentName, id: studentId, method: 'partial' });
          matchFound = true;
          break;
        }
        
        // First name match
        const formWords = normFormName.split(' ').filter(w => w.length > 2);
        const shiftWords = normShiftName.split(' ').filter(w => w.length > 2);
        if (formWords.some(fw => shiftWords.some(sw => fw === sw))) {
          finalStudentMatches.set(normFormName, { studentId, studentName: shiftStudentName, matchMethod: 'firstName' });
          matched.push({ form: formData.originalName, db: shiftStudentName, id: studentId, method: 'firstName' });
          matchFound = true;
          break;
        }
      }
      
      // If not found in teacher's shifts, try global student database
      if (!matchFound) {
        const globalMatch = studentsByNormalizedName.get(normFormName);
        if (globalMatch) {
          finalStudentMatches.set(normFormName, { studentId: globalMatch.id, studentName: globalMatch.name, matchMethod: 'global' });
          matched.push({ form: formData.originalName, db: globalMatch.name, id: globalMatch.id, method: 'global' });
          matchFound = true;
        }
      }
      
      if (!matchFound) {
        unmatched.push({ name: formData.originalName, count: formData.count });
      }
    }
    
    // Print matched students for this teacher
    if (matched.length > 0) {
      console.log('  Matched:');
      for (const m of matched.slice(0, 15)) {
        console.log(`    "${m.form}" → "${m.db}" (${m.id.substring(0, 15)}...) [${m.method}]`);
      }
      if (matched.length > 15) {
        console.log(`    ... and ${matched.length - 15} more`);
      }
    }
    
    if (unmatched.length > 0) {
      console.log('  ⚠️ Unmatched:');
      for (const u of unmatched) {
        console.log(`    "${u.name}" (${u.count}x)`);
      }
      
      // Store for final report
      if (!unmatchedStudentsByTeacher.has(teacherId)) {
        unmatchedStudentsByTeacher.set(teacherId, []);
      }
      unmatchedStudentsByTeacher.get(teacherId).push(...unmatched);
    }
  }

  // ============================================
  // STEP 6: Final unmatched students report
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('FINAL UNMATCHED STUDENTS REPORT');
  console.log('='.repeat(80));
  console.log('');

  let totalUnmatched = 0;
  for (const [teacherId, students] of unmatchedStudentsByTeacher) {
    const teacher = dbTeachersById.get(teacherId);
    const teacherShiftStudents = teacherStudentsMap.get(teacherId) || new Map();
    
    console.log(`\n${teacher?.name || teacherId} (${students.length} unmatched):`);
    console.log(`  Available students in shifts: ${Array.from(teacherShiftStudents.values()).join(', ') || 'None'}`);
    
    for (const s of students) {
      console.log(`  - "${s.name}" (appears ${s.count}x)`);
      totalUnmatched++;
    }
  }
  
  console.log(`\nTotal unmatched student entries: ${totalUnmatched}`);

  // ============================================
  // STEP 7: Summary by date
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('FORMS VS EXISTING SHIFTS BY DATE (with correct teacher matching)');
  console.log('='.repeat(80));
  console.log('');

  const formsByDate = new Map();
  let totalMatched = 0;
  let totalMissing = 0;

  for (const row of rows) {
    const submittedDate = parseFormDate(row[submittedCol]);
    if (!submittedDate || submittedDate.month !== 1 || submittedDate.year !== 2026) continue;
    
    const dateStr = submittedDate.toFormat('yyyy-MM-dd');
    const email = (row[emailCol] || '').toLowerCase().trim();
    const teacher = formEmailToTeacher.get(email);
    
    if (!formsByDate.has(dateStr)) {
      formsByDate.set(dateStr, { total: 0, matched: 0, missing: [] });
    }
    
    const dayData = formsByDate.get(dateStr);
    dayData.total++;
    
    // Check if shift exists
    const shiftKey = teacher ? `${teacher.id}_${dateStr}` : null;
    const existingShifts = shiftKey ? (shiftsByTeacherDate.get(shiftKey) || []) : [];
    
    if (existingShifts.length > 0) {
      dayData.matched++;
      totalMatched++;
    } else {
      dayData.missing.push({
        teacher: teacher?.name || row[teacherCol],
        teacherId: teacher?.id,
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
  // FINAL SUMMARY
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('FINAL SUMMARY');
  console.log('='.repeat(80));
  console.log('');
  console.log(`Teachers matched by email: ${formEmailToTeacher.size}/${formTeacherEntries.size}`);
  console.log(`Students matched: ${finalStudentMatches.size}`);
  console.log(`Students unmatched: ${totalUnmatched}`);
  console.log('');
  console.log(`Forms with existing shifts: ${totalMatched}`);
  console.log(`Forms WITHOUT shifts: ${totalMissing}`);
}

matchFormsByEmail()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
