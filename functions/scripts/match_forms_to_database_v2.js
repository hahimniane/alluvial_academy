#!/usr/bin/env node
'use strict';

/**
 * Match Class Readiness Forms to database records (FIXED field names):
 * - user_type instead of role
 * - e-mail instead of email
 * - first_name/last_name instead of displayName
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

// Calculate similarity between two strings
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

// Parse student names from form
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
    .filter(s => s && s.length > 1 && !s.toLowerCase().includes('absent') && s.toLowerCase() !== 'na' && s.toLowerCase() !== 'n/a');
}

async function matchFormsToDatabase() {
  console.log('='.repeat(80));
  console.log('MATCHING READINESS FORMS TO DATABASE (v2 - Fixed Field Names)');
  console.log('='.repeat(80));
  console.log('');

  // ============================================
  // STEP 1: Load all teachers from database (user_type = 'teacher')
  // ============================================
  console.log('Loading teachers from database...');
  const teachersSnap = await db.collection('users').where('user_type', '==', 'teacher').get();
  const dbTeachers = [];
  
  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    dbTeachers.push({
      id: doc.id,
      name: fullName,
      email: data['e-mail'] || data.email || '',
      firstName: data.first_name || '',
      lastName: data.last_name || '',
    });
  }
  console.log(`Found ${dbTeachers.length} teachers in database\n`);

  // ============================================
  // STEP 2: Load all students from database (user_type = 'student')
  // ============================================
  console.log('Loading students from database...');
  const studentsSnap = await db.collection('users').where('user_type', '==', 'student').get();
  const dbStudents = [];
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    dbStudents.push({
      id: doc.id,
      name: fullName,
      email: data['e-mail'] || data.email || '',
      firstName: data.first_name || '',
      lastName: data.last_name || '',
    });
  }
  console.log(`Found ${dbStudents.length} students in database\n`);

  // ============================================
  // STEP 3: Load existing January shifts
  // ============================================
  console.log('Loading existing January 2026 shifts...');
  
  // First, let's check what fields exist on shifts
  const sampleShift = await db.collection('teaching_shifts').limit(1).get();
  if (sampleShift.docs.length > 0) {
    console.log('Shift fields:', Object.keys(sampleShift.docs[0].data()).join(', '));
  }
  
  // Try different possible field names for the start time
  let shiftsSnap;
  const jan1 = DateTime.fromObject({ year: 2026, month: 1, day: 1 }, { zone: NYC_TZ }).startOf('day');
  const jan31 = DateTime.fromObject({ year: 2026, month: 1, day: 31 }, { zone: NYC_TZ }).endOf('day');
  
  // Try shiftStart first
  shiftsSnap = await db.collection('teaching_shifts')
    .where('shiftStart', '>=', admin.firestore.Timestamp.fromDate(jan1.toJSDate()))
    .where('shiftStart', '<=', admin.firestore.Timestamp.fromDate(jan31.toJSDate()))
    .get();
  
  if (shiftsSnap.docs.length === 0) {
    // Try shift_start
    shiftsSnap = await db.collection('teaching_shifts')
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(jan1.toJSDate()))
      .where('shift_start', '<=', admin.firestore.Timestamp.fromDate(jan31.toJSDate()))
      .get();
  }
  
  if (shiftsSnap.docs.length === 0) {
    // Try start_time
    shiftsSnap = await db.collection('teaching_shifts')
      .where('start_time', '>=', admin.firestore.Timestamp.fromDate(jan1.toJSDate()))
      .where('start_time', '<=', admin.firestore.Timestamp.fromDate(jan31.toJSDate()))
      .get();
  }
  
  const dbShifts = [];
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    // Try various field names
    const shiftStart = data.shiftStart || data.shift_start || data.start_time;
    const teacherName = data.teacherName || data.teacher_name;
    const teacherId = data.teacherId || data.teacher_id;
    const studentNames = data.studentNames || data.student_names || [];
    
    dbShifts.push({
      id: doc.id,
      teacherId,
      teacherName,
      studentIds: data.studentIds || data.student_ids || [],
      studentNames,
      shiftStart: shiftStart?.toDate(),
    });
  }
  console.log(`Found ${dbShifts.length} existing shifts for January 2026\n`);

  // If still 0 shifts, get all shifts to see what exists
  if (dbShifts.length === 0) {
    console.log('Checking all shifts to understand date range...');
    const allShiftsSnap = await db.collection('teaching_shifts').limit(20).get();
    for (const doc of allShiftsSnap.docs) {
      const data = doc.data();
      const start = data.shiftStart || data.shift_start || data.start_time;
      if (start) {
        console.log(`  Shift ${doc.id}: ${start.toDate()}`);
      }
    }
  }

  // Group shifts by date and teacher
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
  console.log('\nParsing readiness form CSV...');
  const csvPath = path.join(__dirname, '../../Class Readiness Form_Formulaire de pr_paration aux cours - Khadijatu_submissions.csv');
  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  const rows = parseCSV(csvContent);
  console.log(`Found ${rows.length} form submissions\n`);

  const teacherCol = Object.keys(rows[0]).find(k => k.includes('Select your name below'));
  const dayCol = Object.keys(rows[0]).find(k => k.includes('Class Day'));
  const durationCol = Object.keys(rows[0]).find(k => k.includes('How long'));
  const studentsCol = Object.keys(rows[0]).find(k => k.includes('List the name of students who are present'));
  const submittedCol = 'Submitted At';
  const classTypeCol = 'Class Type ';

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
      const scores = [
        similarity(formName, dbTeacher.name),
        similarity(formName, dbTeacher.firstName),
        similarity(formName, `${dbTeacher.firstName} ${dbTeacher.lastName}`),
        similarity(formName, dbTeacher.lastName),
      ];
      const maxScore = Math.max(...scores);
      
      if (maxScore > bestScore) {
        bestScore = maxScore;
        bestMatch = dbTeacher;
      }
    }
    
    if (bestScore >= 0.4) {
      teacherMatches.set(formName, {
        dbTeacher: bestMatch,
        score: bestScore,
        confident: bestScore >= 0.7
      });
    } else {
      unmatchedFormTeachers.push(formName);
    }
  }

  console.log('Form Name'.padEnd(25) + '→ ' + 'Database Name'.padEnd(30) + 'ID'.padEnd(30) + 'Score');
  console.log('-'.repeat(100));
  
  for (const [formName, match] of Array.from(teacherMatches.entries()).sort((a, b) => a[0].localeCompare(b[0]))) {
    const confidence = match.score >= 0.95 ? '✓ Exact' : match.score >= 0.7 ? '✓ High' : match.score >= 0.5 ? '~ Medium' : '? Low';
    console.log(
      formName.substring(0, 23).padEnd(25) + '→ ' +
      match.dbTeacher.name.substring(0, 28).padEnd(30) +
      match.dbTeacher.id.substring(0, 28).padEnd(30) +
      `${(match.score * 100).toFixed(0)}% ${confidence}`
    );
  }

  if (unmatchedFormTeachers.length > 0) {
    console.log('\n⚠️  UNMATCHED FORM TEACHERS (need manual mapping):');
    for (const name of unmatchedFormTeachers) {
      console.log(`   - "${name}"`);
      // Show closest matches
      let closest = null;
      let closestScore = 0;
      for (const t of dbTeachers) {
        const score = similarity(name, t.name);
        if (score > closestScore) {
          closestScore = score;
          closest = t;
        }
      }
      if (closest) {
        console.log(`     Closest: "${closest.name}" (${(closestScore * 100).toFixed(0)}%)`);
      }
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

  const formStudentNames = new Set();
  for (const row of rows) {
    const students = parseStudentNames(row[studentsCol]);
    for (const s of students) {
      formStudentNames.add(s);
    }
  }
  
  // Remove garbage entries
  const validStudentNames = Array.from(formStudentNames).filter(n => {
    const lower = n.toLowerCase();
    return n.length > 2 && 
           !lower.includes('absent') && 
           lower !== 'na' && 
           lower !== 'n/a' &&
           lower !== 'none' &&
           !lower.includes('n\\a');
  });

  const studentMatches = new Map();
  const unmatchedFormStudents = [];

  for (const formName of validStudentNames) {
    let bestMatch = null;
    let bestScore = 0;
    
    for (const dbStudent of dbStudents) {
      const scores = [
        similarity(formName, dbStudent.name),
        similarity(formName, `${dbStudent.firstName} ${dbStudent.lastName}`),
        similarity(formName, dbStudent.firstName),
      ];
      const maxScore = Math.max(...scores);
      
      if (maxScore > bestScore) {
        bestScore = maxScore;
        bestMatch = dbStudent;
      }
    }
    
    if (bestScore >= 0.5) {
      studentMatches.set(formName, {
        dbStudent: bestMatch,
        score: bestScore,
        confident: bestScore >= 0.7
      });
    } else {
      unmatchedFormStudents.push({ name: formName, closestScore: bestScore, closest: bestMatch });
    }
  }

  console.log(`Matched ${studentMatches.size}/${validStudentNames.length} student names\n`);
  
  console.log('Form Name'.padEnd(35) + '→ ' + 'Database Name'.padEnd(35) + 'ID'.padEnd(25) + 'Score');
  console.log('-'.repeat(110));
  
  const sortedStudentMatches = Array.from(studentMatches.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  for (const [formName, match] of sortedStudentMatches) {
    const confidence = match.score >= 0.9 ? '✓' : match.score >= 0.7 ? '~' : '?';
    console.log(
      formName.substring(0, 33).padEnd(35) + '→ ' +
      match.dbStudent.name.substring(0, 33).padEnd(35) +
      match.dbStudent.id.substring(0, 23).padEnd(25) +
      `${(match.score * 100).toFixed(0)}% ${confidence}`
    );
  }

  if (unmatchedFormStudents.length > 0) {
    console.log('\n⚠️  UNMATCHED STUDENT NAMES:');
    for (const item of unmatchedFormStudents.slice(0, 40)) {
      const closestInfo = item.closest ? ` (closest: "${item.closest.name}" ${(item.closestScore * 100).toFixed(0)}%)` : '';
      console.log(`   - "${item.name}"${closestInfo}`);
    }
    if (unmatchedFormStudents.length > 40) {
      console.log(`   ... and ${unmatchedFormStudents.length - 40} more`);
    }
  }

  // ============================================
  // STEP 7: Summary by date
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('FORMS BY DATE (January 2026)');
  console.log('='.repeat(80));
  console.log('');

  const formsByDate = new Map();
  for (const row of rows) {
    const submittedDate = parseFormDate(row[submittedCol]);
    if (!submittedDate || submittedDate.month !== 1 || submittedDate.year !== 2026) continue;
    
    const dateStr = submittedDate.toFormat('yyyy-MM-dd');
    if (!formsByDate.has(dateStr)) {
      formsByDate.set(dateStr, []);
    }
    
    const formTeacher = row[teacherCol];
    const students = parseStudentNames(row[studentsCol]);
    const match = teacherMatches.get(formTeacher);
    
    formsByDate.get(dateStr).push({
      formTeacher,
      matchedTeacherId: match?.dbTeacher?.id,
      matchedTeacherName: match?.dbTeacher?.name,
      students,
      hasShift: shiftsByDateTeacher.has(`${dateStr}_${normalizeName(match?.dbTeacher?.name || formTeacher)}`),
    });
  }

  console.log('Date'.padEnd(15) + 'Forms'.padStart(8) + '  Existing Shifts'.padStart(18));
  console.log('-'.repeat(45));
  
  const sortedDates = Array.from(formsByDate.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  let totalForms = 0;
  let formsWithShifts = 0;
  
  for (const [date, forms] of sortedDates) {
    const withShift = forms.filter(f => f.hasShift).length;
    totalForms += forms.length;
    formsWithShifts += withShift;
    console.log(
      date.padEnd(15) +
      forms.length.toString().padStart(8) +
      withShift.toString().padStart(18)
    );
  }
  
  console.log('-'.repeat(45));
  console.log(
    'TOTAL'.padEnd(15) +
    totalForms.toString().padStart(8) +
    formsWithShifts.toString().padStart(18)
  );
  
  console.log(`\nForms needing shifts: ${totalForms - formsWithShifts}`);

  // ============================================
  // FINAL SUMMARY
  // ============================================
  console.log('\n');
  console.log('='.repeat(80));
  console.log('FINAL SUMMARY');
  console.log('='.repeat(80));
  console.log('');
  console.log(`Total teachers in DB: ${dbTeachers.length}`);
  console.log(`Total students in DB: ${dbStudents.length}`);
  console.log(`Total January shifts in DB: ${dbShifts.length}`);
  console.log('');
  console.log(`Form teachers matched: ${teacherMatches.size}/${formTeacherNames.size}`);
  console.log(`Form students matched: ${studentMatches.size}/${validStudentNames.length}`);
  console.log('');
  console.log(`Forms with existing shifts: ${formsWithShifts}`);
  console.log(`Forms WITHOUT shifts (need to create): ${totalForms - formsWithShifts}`);
}

matchFormsToDatabase()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
