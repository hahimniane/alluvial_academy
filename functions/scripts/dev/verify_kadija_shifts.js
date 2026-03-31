#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const CONFIRMED_TEACHERS = {
  'Arabieu Bah': 'xxKjtk7NSNUWDXO268UOgK27z1E2',
  'Elham Ahmed Shifa': 'BWfi0eUY2heSPC16V3c6Tz1BdPX2',
  'Nasrullah Jalloh': 'yL01069U5zdjl10F5mvUBBJ665p1',
  'Habibu Barry': 'kjVbNRUjJoZRw3NTd3jIbREdYUu2',
};

async function verify() {
  console.log('Verifying Kadija confirmed shifts in database...\n');
  console.log('='.repeat(80));
  
  // Check templates
  console.log('📋 SHIFT TEMPLATES');
  console.log('='.repeat(80));
  
  for (const [teacherName, teacherId] of Object.entries(CONFIRMED_TEACHERS)) {
    const templatesSnap = await db.collection('shift_templates')
      .where('teacher_id', '==', teacherId)
      .where('is_active', '==', true)
      .get();
    
    console.log(`\n${teacherName} (${teacherId}):`);
    console.log(`  Templates: ${templatesSnap.size}`);
    
    if (templatesSnap.size > 0) {
      const studentIds = new Set();
      templatesSnap.docs.forEach(doc => {
        const data = doc.data();
        (data.student_ids || []).forEach(id => studentIds.add(id));
      });
      console.log(`  Unique Students: ${studentIds.size}`);
      console.log(`  Students: ${Array.from(studentIds).join(', ')}`);
      
      // Sample template
      const sample = templatesSnap.docs[0].data();
      console.log(`  Sample Template:`);
      console.log(`    - Subject: ${sample.subject_display_name} ($${sample.hourly_rate}/hr)`);
      console.log(`    - Video Provider: ${sample.video_provider}`);
      console.log(`    - Max Days Ahead: ${sample.max_days_ahead}`);
      console.log(`    - Student: ${sample.student_names?.[0] || 'N/A'}`);
    }
  }
  
  // Check generated shifts
  console.log('\n\n' + '='.repeat(80));
  console.log('🗓️  GENERATED SHIFTS');
  console.log('='.repeat(80));
  
  let totalShifts = 0;
  for (const [teacherName, teacherId] of Object.entries(CONFIRMED_TEACHERS)) {
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('teacher_id', '==', teacherId)
      .where('generated_from_template', '==', true)
      .get();
    
    console.log(`\n${teacherName}:`);
    console.log(`  Generated Shifts: ${shiftsSnap.size}`);
    totalShifts += shiftsSnap.size;
    
    if (shiftsSnap.size > 0) {
      // Group by student
      const byStudent = new Map();
      shiftsSnap.docs.forEach(doc => {
        const data = doc.data();
        const studentIds = data.student_ids || [];
        studentIds.forEach(sid => {
          if (!byStudent.has(sid)) byStudent.set(sid, []);
          byStudent.get(sid).push(data);
        });
      });
      
      console.log(`  Shifts by Student:`);
      byStudent.forEach((shifts, studentId) => {
        console.log(`    - ${studentId}: ${shifts.length} shifts`);
      });
      
      // Sample shift
      const sample = shiftsSnap.docs[0].data();
      const start = sample.shift_start?.toDate();
      console.log(`  Sample Shift:`);
      console.log(`    - Start: ${start?.toISOString()}`);
      console.log(`    - Status: ${sample.status}`);
      console.log(`    - Video Provider: ${sample.video_provider}`);
    }
  }
  
  console.log(`\n\nTotal Generated Shifts: ${totalShifts}`);
  
  // Check for any issues
  console.log('\n\n' + '='.repeat(80));
  console.log('⚠️  POTENTIAL ISSUES');
  console.log('='.repeat(80));
  
  if (totalShifts === 0) {
    console.log('\n❌ NO SHIFTS WERE GENERATED!');
    console.log('   This means the _generateShiftsForTemplate function did not create any shifts.');
    console.log('   Possible reasons:');
    console.log('   1. base_shift_start is in the past beyond max_days_ahead window');
    console.log('   2. Error in shift generation logic');
    console.log('   3. Templates were not properly saved');
    
    // Check one template in detail
    const anyTemplate = await db.collection('shift_templates')
      .where('is_active', '==', true)
      .limit(1)
      .get();
    
    if (!anyTemplate.empty) {
      const tpl = anyTemplate.docs[0].data();
      const baseStart = tpl.base_shift_start?.toDate();
      const now = new Date();
      const maxDays = tpl.max_days_ahead || 0;
      const cutoff = new Date(now.getTime() + maxDays * 24 * 60 * 60 * 1000);
      
      console.log('\n   Checking template:', anyTemplate.docs[0].id);
      console.log(`   - base_shift_start: ${baseStart?.toISOString()}`);
      console.log(`   - max_days_ahead: ${maxDays}`);
      console.log(`   - Current time: ${now.toISOString()}`);
      console.log(`   - Cutoff date: ${cutoff.toISOString()}`);
      console.log(`   - Base start is ${baseStart > cutoff ? 'AFTER' : 'BEFORE'} cutoff`);
    }
  }
  
  // Check for cross-contamination (students seeing other students' classes)
  console.log('\n\n' + '='.repeat(80));
  console.log('🔒 STUDENT ISOLATION CHECK');
  console.log('='.repeat(80));
  
  // Get all templates
  const allTemplates = await db.collection('shift_templates')
    .where('is_active', '==', true)
    .get();
  
  const templatesByStudent = new Map();
  allTemplates.docs.forEach(doc => {
    const data = doc.data();
    const teacherId = data.teacher_id;
    const teacherName = Object.keys(CONFIRMED_TEACHERS).find(k => CONFIRMED_TEACHERS[k] === teacherId);
    
    if (teacherName) {
      (data.student_ids || []).forEach(sid => {
        if (!templatesByStudent.has(sid)) {
          templatesByStudent.set(sid, []);
        }
        templatesByStudent.get(sid).push({
          templateId: doc.id,
          teacher: teacherName,
          studentIds: data.student_ids || [],
        });
      });
    }
  });
  
  console.log(`\nChecking ${templatesByStudent.size} students...\n`);
  
  let issuesFound = 0;
  templatesByStudent.forEach((templates, studentId) => {
    const multiStudentTemplates = templates.filter(t => t.studentIds.length > 1);
    
    if (multiStudentTemplates.length > 0) {
      console.log(`⚠️  Student ${studentId} is in ${multiStudentTemplates.length} group class(es):`);
      multiStudentTemplates.forEach(t => {
        console.log(`  - Template ${t.templateId}: ${t.teacher} → ${t.studentIds.join(', ')}`);
      });
      issuesFound++;
    }
  });
  
  if (issuesFound === 0) {
    console.log('✅ All templates are for individual students (IC classes)');
    console.log('   Students will only see their own classes.');
  } else {
    console.log(`\n⚠️  Found ${issuesFound} students in group classes.`);
    console.log('   Group classes (FGC/MGC) are expected - students share the same class time.');
  }
}

verify()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
