#!/usr/bin/env node
'use strict';

/**
 * Match Class Readiness Forms to database records:
 * 1. Match teacher names (handle spelling variations)
 * 2. Match student names to student IDs
 * 3. Compare with existing shifts
 * 4. Report discrepancies
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

// Normalize name for matching
function normalizeName(name) {
  return (name || '')
    .toLowerCase()
    .replace(/[^a-z\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

// Calculate similarity between two strings (Levenshtein-based)
function similarity(s1, s2) {
  const n1 = normalizeName(s1);
  const n2 = normalizeName(s2);
  
  if (n1 === n2) return 1.0;
  if (!n1 || !n2) return 0;
  
  // Check if one contains the other
  if (n1.includes(n2) || n2.includes(n1)) return 0.9;
  
  // Check word overlap
  const words1 = n1.split(' ');
  const words2 = n2.split(' ');
  const commonWords = words1.filter(w => words2.some(w2 => w2.includes(w) || w.includes(w2)));
  const wordSimilarity = commonWords.length / Math.max(words1.length, words2.length);
  
  return wordSimilarity;
}

// Parse date from form format "01/01/2026 17:01"
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

// Parse day from form "[Wed/Mercredi]" format
function parseFormDay(dayStr) {
  if (!dayStr) return null;
  const dayMap = {
    'mon': 1, 'monday': 1, 'lundi': 1,
    'tue': 2, 'tuesday': 2, 'mardi': 2,
    'wed': 3, 'wednesday': 3, 'mercredi': 3,
    'thu': 4, 'thur': 4, 'thursday': 4, 'jeudi': 4,
    'fri': 5, 'friday': 5, 'vendredi': 5,
    'sat': 6, 'saturday': 6, 'samedi': 6,
    'sun': 7, 'sunday': 7, 'dimanche': 7,
  };
  
  const lower = dayStr.toLowerCase();
  for (const [key, value] of Object.entries(dayMap)) {
    if (lower.includes(key)) return value;
  }
  return null;
}

// Parse student names from form (comma or "and" separated)
function parseStudentNames(studentsStr) {
  if (!studentsStr) return [];
  
  // Skip obvious non-student entries
  const lower = studentsStr.toLowerCase();
  if (lower.includes('absent') || lower.includes('n/a') || lower === 'none' || lower === 'no one') {
    return [];
  }
  
  // Split by comma or "and"
  return studentsStr
    .replace(/\s+and\s+/gi, ',')
    .replace(/\s*,\s*/g, ',')
    .split(',')
    .map(s => s.trim())
    .filter(s => s && s.length > 1 && !s.toLowerCase().includes('absent'));
}

async function matchFormsToDatabase() {
  console.log('='.repeat(80));
  console.log('MATCHING READINESS FORMS TO DATABASE');
  console.log('='.repeat(80));
  console.log('');

  // ============================================
  // STEP 1: Load all teachers from database
  // ============================================
  console.log('Loading teachers from database...');
  const teachersSnap = await db.collection('users').where('role', '==', 'teacher').get();
  const dbTeachers = [];
  
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    dbTeachers.push({
      id: doc.id,
      name: data.displayName || data.name || '',
      email: data.email || '',
      firstName: data.firstName || '',
      lastName: data.lastName || '',
    });
  }
  console.log(`Found ${dbTeachers.length} teachers in database\n`);

  // ============================================
  // STEP 2: Load all students from database
  // ============================================
  console.log('Loading students from database...');
  const studentsSnap = await db.collection('users').where('role', '==', 'student').get();
  const dbStudents = [];
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    dbStudents.push({
      id: doc.id,
      name: data.displayName || data.name || '',
      email: data.email || '',
      firstName: data.firstName || '',
      lastName: data.lastName || '',
    });
  }
  console.log(`Found ${dbStudents.length} students in database\n`);

  // ============================================
  // STEP 3: Load existing January shifts
  // ============================================
  console.log('Loading existing January 2026 shifts...');
  const jan1 = DateTime.fromObject({ year: 2026, month: 1, day: 1 }, { zone: NYC_TZ }).startOf('day');
  const jan31 = DateTime.fromObject({ year: 2026, month: 1, day: 31 }, { zone: NYC_TZ }).endOf('day');
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('shiftStart', '>=', admin.firestore.Timestamp.fromDate(jan1.toJSDate()))
    .where('shiftStart', '<=', admin.firestore.Timestamp.fromDate(jan31.toJSDate()))
    .get();
  
  const dbShifts = [];
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    dbShifts.push({
      id: doc.id,
      teacherId: data.teacherId,
      teacherName: data.teacherName,
      studentIds: data.studentIds || [],
      studentNames: data.studentNames || [],
      shiftStart: data.shiftStart?.toDate(),
      shiftEnd: data.shiftEnd?.toDate(),
    });
  }
  console.log(`Found ${dbShifts.length} existing shifts for January 2026\n`);

  // Group shifts by date and teacher for easier lookup
  const shiftsByDateTeacher = new Map();
  for (const shift of dbShifts) {
    if (shift.shiftStart) {
      const dt = DateTime.fromJSDate(shift.shiftStart).setZone(NYC_TZ);
      const key = `${dt.toFormat('yyyy-MM-dd')}_${normalizeName(shift.teacherName)}`;
      if (!shiftsByDateTeacher.has(key)) {
        shiftsByDateTeacher.set(key, []);
      }
      shiftsByDateTeacher.get(key).push(shift);
    }
  }

  // ============================================
  // STEP 4: Parse readiness forms
  // ============================================
  console.log('Parsing readiness form CSV...');
  const csvPath = path.join(__dirname, '../../Class Readiness Form_Formulaire de pr_paration aux cours - Khadijatu_submissions.csv');
  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  const rows = parseCSV(csvContent);
  console.log(`Found ${rows.length} form submissions\n`);

  // Get column names
  const teacherCol = Object.keys(rows[0]).find(k => k.includes('Select your name below'));
  const dayCol = Object.keys(rows[0]).find(k => k.includes('Class Day'));
  const durationCol = Object.keys(rows[0]).find(k => k.includes('How long'));
  const studentsCol = Object.keys(rows[0]).find(k => k.includes('List the name of students who are present'));
  const submittedCol = 'Submitted At';
  const classTypeCol = 'Class Type ';
  const emailCol = 'Email';

  // ============================================
  // STEP 5: Match teacher names
  // ============================================
  console.log('='.repeat(80));
  console.log('TEACHER NAME MATCHING');
  console.log('='.repeat(80));
  console.log('');

  const formTeacherNames = new Set();
  for (const row of rows) {
    const teacher = row[teacherCol];
    if (teacher) formTeacherNames.add(teacher);
  }

  const teacherMatches = new Map();
  const unmatchedFormTeachers = [];

  for (const formName of formTeacherNames) {
    let bestMatch = null;
    let bestScore = 0;
    
    for (const dbTeacher of dbTeachers) {
      // Try matching against various name fields
      const scores = [
        similarity(formName, dbTeacher.name),
        similarity(formName, dbTeacher.firstName),
        similarity(formName, `${dbTeacher.firstName} ${dbTeacher.lastName}`),
      ];
      const maxScore = Math.max(...scores);
      
      if (maxScore > bestScore) {
        bestScore = maxScore;
        bestMatch = dbTeacher;
      }
    }
    
    if (bestScore >= 0.5) {
      teacherMatches.set(formName, {
        dbTeacher: bestMatch,
        score: bestScore,
        confident: bestScore >= 0.8
      });
    } else {
      unmatchedFormTeachers.push(formName);
    }
  }

  console.log('Form Name'.padEnd(25) + '→ ' + 'Database Name'.padEnd(30) + 'ID'.padEnd(30) + 'Confidence');
  console.log('-'.repeat(100));
  
  for (const [formName, match] of Array.from(teacherMatches.entries()).sort((a, b) => a[0].localeCompare(b[0]))) {
    const confidence = match.score >= 0.95 ? '✓ Exact' : match.score >= 0.8 ? '✓ High' : '? Medium';
    console.log(
      formName.substring(0, 23).padEnd(25) + '→ ' +
      match.dbTeacher.name.substring(0, 28).padEnd(30) +
      match.dbTeacher.id.substring(0, 28).padEnd(30) +
      confidence
    );
  }

  if (unmatchedFormTeachers.length > 0) {
    console.log('\n⚠️  UNMATCHED FORM TEACHERS (need manual mapping):');
    for (const name of unmatchedFormTeachers) {
      console.log(`   - "${name}"`);
    }
  }

  // ============================================
  // STEP 6: Match student names
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('STUDENT NAME MATCHING');
  console.log('='.repeat(80));
  console.log('');

  // Get all unique student names from forms
  const formStudentNames = new Set();
  for (const row of rows) {
    const students = parseStudentNames(row[studentsCol]);
    for (const s of students) {
      formStudentNames.add(s);
    }
  }

  const studentMatches = new Map();
  const unmatchedFormStudents = [];

  for (const formName of formStudentNames) {
    let bestMatch = null;
    let bestScore = 0;
    
    for (const dbStudent of dbStudents) {
      const scores = [
        similarity(formName, dbStudent.name),
        similarity(formName, `${dbStudent.firstName} ${dbStudent.lastName}`),
      ];
      const maxScore = Math.max(...scores);
      
      if (maxScore > bestScore) {
        bestScore = maxScore;
        bestMatch = dbStudent;
      }
    }
    
    if (bestScore >= 0.6) {
      studentMatches.set(formName, {
        dbStudent: bestMatch,
        score: bestScore,
        confident: bestScore >= 0.8
      });
    } else {
      unmatchedFormStudents.push(formName);
    }
  }

  // Show student matches
  console.log(`Matched ${studentMatches.size} student names, ${unmatchedFormStudents.length} unmatched\n`);
  
  console.log('Form Name'.padEnd(30) + '→ ' + 'Database Name'.padEnd(30) + 'ID'.padEnd(30) + 'Conf');
  console.log('-'.repeat(100));
  
  const sortedStudentMatches = Array.from(studentMatches.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  for (const [formName, match] of sortedStudentMatches.slice(0, 50)) {
    const confidence = match.score >= 0.95 ? '✓' : match.score >= 0.8 ? '~' : '?';
    console.log(
      formName.substring(0, 28).padEnd(30) + '→ ' +
      match.dbStudent.name.substring(0, 28).padEnd(30) +
      match.dbStudent.id.substring(0, 28).padEnd(30) +
      confidence
    );
  }
  if (sortedStudentMatches.length > 50) {
    console.log(`... and ${sortedStudentMatches.length - 50} more`);
  }

  if (unmatchedFormStudents.length > 0) {
    console.log('\n⚠️  UNMATCHED STUDENT NAMES (need manual mapping):');
    for (const name of unmatchedFormStudents.slice(0, 30)) {
      console.log(`   - "${name}"`);
    }
    if (unmatchedFormStudents.length > 30) {
      console.log(`   ... and ${unmatchedFormStudents.length - 30} more`);
    }
  }

  // ============================================
  // STEP 7: Compare forms to existing shifts
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('COMPARING FORMS TO EXISTING SHIFTS (January 2026)');
  console.log('='.repeat(80));
  console.log('');

  const formsWithShifts = [];
  const formsWithoutShifts = [];
  const formsByDate = new Map();

  for (const row of rows) {
    const formTeacher = row[teacherCol];
    const submittedAt = row[submittedCol];
    const formDay = row[dayCol];
    const students = parseStudentNames(row[studentsCol]);
    const classType = row[classTypeCol];
    const duration = row[durationCol];
    
    const submittedDate = parseFormDate(submittedAt);
    if (!submittedDate) continue;
    
    // Only process January
    if (submittedDate.month !== 1 || submittedDate.year !== 2026) continue;
    
    const dateStr = submittedDate.toFormat('yyyy-MM-dd');
    const teacherMatch = teacherMatches.get(formTeacher);
    const normalizedTeacher = teacherMatch ? normalizeName(teacherMatch.dbTeacher.name) : normalizeName(formTeacher);
    
    // Check if shift exists for this date and teacher
    const shiftKey = `${dateStr}_${normalizedTeacher}`;
    const existingShifts = shiftsByDateTeacher.get(shiftKey) || [];
    
    const formEntry = {
      date: dateStr,
      day: formDay,
      formTeacher,
      matchedTeacher: teacherMatch?.dbTeacher,
      students,
      matchedStudents: students.map(s => studentMatches.get(s)?.dbStudent).filter(Boolean),
      classType,
      duration,
      existingShifts: existingShifts.length,
    };
    
    if (existingShifts.length > 0) {
      formsWithShifts.push(formEntry);
    } else {
      formsWithoutShifts.push(formEntry);
    }
    
    // Group by date
    if (!formsByDate.has(dateStr)) {
      formsByDate.set(dateStr, { withShift: 0, withoutShift: 0 });
    }
    if (existingShifts.length > 0) {
      formsByDate.get(dateStr).withShift++;
    } else {
      formsByDate.get(dateStr).withoutShift++;
    }
  }

  console.log('SUMMARY BY DATE:');
  console.log('-'.repeat(60));
  console.log('Date'.padEnd(15) + 'Has Shift'.padStart(12) + 'Missing Shift'.padStart(15) + 'Total'.padStart(10));
  console.log('-'.repeat(60));
  
  const sortedDates = Array.from(formsByDate.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  for (const [date, counts] of sortedDates) {
    console.log(
      date.padEnd(15) +
      counts.withShift.toString().padStart(12) +
      counts.withoutShift.toString().padStart(15) +
      (counts.withShift + counts.withoutShift).toString().padStart(10)
    );
  }
  
  console.log('-'.repeat(60));
  console.log(
    'TOTAL'.padEnd(15) +
    formsWithShifts.length.toString().padStart(12) +
    formsWithoutShifts.length.toString().padStart(15) +
    (formsWithShifts.length + formsWithoutShifts.length).toString().padStart(10)
  );

  // ============================================
  // STEP 8: Show missing shifts by teacher
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('MISSING SHIFTS BY TEACHER');
  console.log('='.repeat(80));
  console.log('');

  const missingByTeacher = new Map();
  for (const form of formsWithoutShifts) {
    const key = form.formTeacher;
    if (!missingByTeacher.has(key)) {
      missingByTeacher.set(key, []);
    }
    missingByTeacher.get(key).push(form);
  }

  for (const [teacher, forms] of Array.from(missingByTeacher.entries()).sort((a, b) => b[1].length - a[1].length)) {
    const match = teacherMatches.get(teacher);
    const dbName = match ? match.dbTeacher.name : '❌ NO MATCH';
    const dbId = match ? match.dbTeacher.id : 'N/A';
    
    console.log(`\n${teacher} → ${dbName} (${dbId})`);
    console.log(`Missing ${forms.length} shifts:`);
    
    for (const form of forms.slice(0, 10)) {
      const studentList = form.students.length > 0 ? form.students.join(', ') : 'No students listed';
      console.log(`  - ${form.date} | ${form.day || '?'} | ${form.duration || '?'} | ${studentList.substring(0, 40)}`);
    }
    if (forms.length > 10) {
      console.log(`  ... and ${forms.length - 10} more`);
    }
  }

  // ============================================
  // STEP 9: Summary
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('FINAL SUMMARY');
  console.log('='.repeat(80));
  console.log('');
  console.log(`Total January forms: ${formsWithShifts.length + formsWithoutShifts.length}`);
  console.log(`Forms with existing shifts: ${formsWithShifts.length}`);
  console.log(`Forms WITHOUT shifts (need to create): ${formsWithoutShifts.length}`);
  console.log('');
  console.log(`Teachers matched: ${teacherMatches.size}/${formTeacherNames.size}`);
  console.log(`Students matched: ${studentMatches.size}/${formStudentNames.size}`);
  console.log('');
  console.log('Unmatched teachers:', unmatchedFormTeachers.length > 0 ? unmatchedFormTeachers.join(', ') : 'None');
  console.log(`Unmatched students: ${unmatchedFormStudents.length} names`);
}

matchFormsToDatabase()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
