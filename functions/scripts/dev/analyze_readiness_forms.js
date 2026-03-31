#!/usr/bin/env node
'use strict';

/**
 * Analyze Class Readiness Form CSV to extract class data
 * and compare with existing shifts in the database.
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
    
    // Handle CSV with quoted fields (commas inside quotes)
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

async function analyzeReadinessForms() {
  console.log('='.repeat(80));
  console.log('ANALYZING CLASS READINESS FORMS');
  console.log('='.repeat(80));
  console.log('');

  // Read the CSV file
  const csvPath = path.join(__dirname, '../../Class Readiness Form_Formulaire de pr_paration aux cours - Khadijatu_submissions.csv');
  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  const rows = parseCSV(csvContent);

  console.log(`Total readiness form submissions: ${rows.length}\n`);

  // Extract teacher names column (it's a long name)
  const teacherCol = Object.keys(rows[0]).find(k => k.includes('Select your name below'));
  const dayCol = Object.keys(rows[0]).find(k => k.includes('Class Day'));
  const durationCol = Object.keys(rows[0]).find(k => k.includes('How long'));
  const studentsCol = Object.keys(rows[0]).find(k => k.includes('List the name of students who are present'));
  const submittedCol = 'Submitted At';
  const classTypeCol = 'Class Type ';

  // Group by teacher
  const teacherMap = new Map();
  const byMonth = new Map();
  
  for (const row of rows) {
    const teacher = row[teacherCol] || 'Unknown';
    const submittedAt = row[submittedCol];
    const day = row[dayCol];
    const students = row[studentsCol];
    const classType = row[classTypeCol];
    const duration = row[durationCol];
    
    if (!teacherMap.has(teacher)) {
      teacherMap.set(teacher, {
        count: 0,
        classes: [],
        dates: [],
      });
    }
    
    const teacherData = teacherMap.get(teacher);
    teacherData.count++;
    
    // Parse date
    let parsedDate = null;
    if (submittedAt) {
      // Format: 01/01/2026 17:01
      const parts = submittedAt.split(' ')[0].split('/');
      if (parts.length === 3) {
        parsedDate = DateTime.fromObject({
          month: parseInt(parts[0]),
          day: parseInt(parts[1]),
          year: parseInt(parts[2])
        }, { zone: NYC_TZ });
        
        teacherData.dates.push(parsedDate);
        
        // Group by month
        const monthKey = parsedDate.toFormat('yyyy-MM');
        if (!byMonth.has(monthKey)) {
          byMonth.set(monthKey, 0);
        }
        byMonth.set(monthKey, byMonth.get(monthKey) + 1);
      }
    }
    
    teacherData.classes.push({
      date: submittedAt,
      day,
      students,
      classType,
      duration,
    });
  }

  console.log('READINESS FORMS BY MONTH:');
  console.log('-'.repeat(40));
  const sortedMonths = Array.from(byMonth.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  for (const [month, count] of sortedMonths) {
    console.log(`  ${month}: ${count} forms`);
  }
  console.log('');

  console.log('READINESS FORMS BY TEACHER:');
  console.log('-'.repeat(40));
  const sortedTeachers = Array.from(teacherMap.entries())
    .sort((a, b) => b[1].count - a[1].count);
  
  for (const [teacher, data] of sortedTeachers) {
    const earliest = data.dates.length > 0 
      ? DateTime.min(...data.dates).toFormat('MMM d')
      : '?';
    const latest = data.dates.length > 0
      ? DateTime.max(...data.dates).toFormat('MMM d')
      : '?';
    
    console.log(`${teacher}: ${data.count} forms (${earliest} - ${latest})`);
  }

  // Now compare with timesheets
  console.log('\n');
  console.log('='.repeat(80));
  console.log('COMPARING WITH TIMESHEETS:');
  console.log('='.repeat(80));
  
  // Get all timesheets
  const timesheetsSnap = await db.collection('timesheet_entries').get();
  const timesheetTeachers = new Map();
  
  for (const doc of timesheetsSnap.docs) {
    const data = doc.data();
    const teacher = data.teacher_name || 'Unknown';
    if (!timesheetTeachers.has(teacher)) {
      timesheetTeachers.set(teacher, 0);
    }
    timesheetTeachers.set(teacher, timesheetTeachers.get(teacher) + 1);
  }

  console.log('\nReadiness Forms vs Timesheets per Teacher:');
  console.log('-'.repeat(60));
  console.log('Teacher'.padEnd(30) + 'Forms'.padStart(10) + 'Timesheets'.padStart(12) + 'Gap'.padStart(8));
  console.log('-'.repeat(60));
  
  // Normalize teacher names for comparison
  const normalizeTeacher = (name) => {
    const lower = (name || '').toLowerCase().trim();
    // Handle variations
    const mappings = {
      'mama': 'mama s diallo',
      'habibu': 'habibu barry',
      'arabieu': 'arabieu bah',
      'aliou diallo': 'thierno aliou diallo',
      'iberahim bah': 'ibrahim bah',
      'al-hassan': 'al-hassan diallo',
      'korka': 'ahmed korka bah',
      'sheriff': 'muhammed yayal sheriff',
      'asma': 'asma mugtiu',
      'ibrahim balde': 'ibrahim baldee',
      'abdullah balde': 'abdullah baldee',
      'ustaz abdullah yahya': 'abdoullahi yaya',
      'abdoullahi yayah': 'abdoullahi yaya',
      'thiam': 'ousman a cham',
      'chernor ahmadu': 'rahmatullaah balde',
    };
    return mappings[lower] || lower;
  };

  const allTeachers = new Set([
    ...Array.from(teacherMap.keys()),
    ...Array.from(timesheetTeachers.keys())
  ]);

  const gaps = [];
  for (const teacher of allTeachers) {
    const normalizedForm = normalizeTeacher(teacher);
    
    // Find matching form count
    let formCount = 0;
    for (const [t, data] of teacherMap) {
      if (normalizeTeacher(t) === normalizedForm || t === teacher) {
        formCount += data.count;
      }
    }
    
    // Find matching timesheet count
    let timesheetCount = 0;
    for (const [t, count] of timesheetTeachers) {
      if (normalizeTeacher(t) === normalizedForm || t === teacher) {
        timesheetCount += count;
      }
    }
    
    if (formCount > 0 || timesheetCount > 0) {
      const gap = formCount - timesheetCount;
      gaps.push({ teacher, formCount, timesheetCount, gap });
    }
  }

  // Sort by gap (most missing timesheets first)
  gaps.sort((a, b) => b.gap - a.gap);
  
  for (const { teacher, formCount, timesheetCount, gap } of gaps) {
    if (formCount > 0) { // Only show teachers with forms
      console.log(
        teacher.substring(0, 28).padEnd(30) + 
        formCount.toString().padStart(10) + 
        timesheetCount.toString().padStart(12) +
        (gap > 0 ? `+${gap}` : gap.toString()).padStart(8)
      );
    }
  }

  // Summary
  const totalForms = rows.length;
  const totalTimesheets = timesheetsSnap.docs.length;
  console.log('-'.repeat(60));
  console.log(
    'TOTAL'.padEnd(30) + 
    totalForms.toString().padStart(10) + 
    totalTimesheets.toString().padStart(12) +
    (totalForms - totalTimesheets > 0 ? `+${totalForms - totalTimesheets}` : (totalForms - totalTimesheets).toString()).padStart(8)
  );

  console.log('\n');
  console.log('='.repeat(80));
  console.log('CLASSES WITHOUT TIMESHEETS (POTENTIAL MISSING SHIFTS):');
  console.log('='.repeat(80));
  console.log(`\nThere are ${totalForms - totalTimesheets} more readiness forms than timesheets.`);
  console.log('This suggests these classes were taught but may not have had shifts in the system.');
  console.log('\nThese readiness forms can be used to recreate the missing shifts!');
}

analyzeReadinessForms()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
