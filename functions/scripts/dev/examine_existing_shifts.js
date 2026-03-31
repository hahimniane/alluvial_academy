#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

// Initialize Firebase
admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function examineShifts() {
  console.log('Examining existing shift patterns in database...\n');
  console.log('='.repeat(80));
  
  // 1. Get a few active shift templates
  console.log('📋 SHIFT TEMPLATES (sample)');
  console.log('='.repeat(80));
  
  const templatesSnap = await db.collection('shift_templates')
    .where('is_active', '==', true)
    .limit(3)
    .get();
  
  const templates = [];
  templatesSnap.docs.forEach(doc => {
    const data = doc.data();
    templates.push({ id: doc.id, ...data });
    
    console.log(`\nTemplate ID: ${doc.id}`);
    console.log(`  Teacher ID: ${data.teacher_id}`);
    console.log(`  Teacher Name: ${data.teacher_name}`);
    console.log(`  Student IDs: ${JSON.stringify(data.student_ids || [])}`);
    console.log(`  Student Names: ${JSON.stringify(data.student_names || [])}`);
    console.log(`  Start Time: ${data.start_time}`);
    console.log(`  End Time: ${data.end_time}`);
    console.log(`  Duration: ${data.duration_minutes} minutes`);
    console.log(`  Recurrence: ${data.recurrence}`);
    console.log(`  Enhanced Recurrence: ${JSON.stringify(data.enhanced_recurrence?.selectedWeekdays || [])}`);
    console.log(`  Video Provider: ${data.video_provider}`);
    console.log(`  Subject: ${data.subject}`);
    console.log(`  Subject ID: ${data.subject_id}`);
    console.log(`  Subject Display: ${data.subject_display_name}`);
    console.log(`  Category: ${data.category}`);
    console.log(`  Hourly Rate: ${data.hourly_rate}`);
    console.log(`  Max Days Ahead: ${data.max_days_ahead}`);
    console.log(`  Admin Timezone: ${data.admin_timezone}`);
    console.log(`  Teacher Timezone: ${data.teacher_timezone}`);
    console.log(`  Auto Generated Name: ${data.auto_generated_name}`);
    console.log(`  Custom Name: ${data.custom_name}`);
    console.log(`  Notes: ${data.notes}`);
    console.log(`  Is Active: ${data.is_active}`);
    console.log(`  Base Shift ID: ${data.base_shift_id}`);
    console.log(`  Recurrence Series ID: ${data.recurrence_series_id}`);
  });
  
  // 2. Get generated shifts for one of these templates (skip orderBy to avoid index requirement)
  if (templates.length > 0) {
    const sampleTemplate = templates[0];
    console.log('\n\n' + '='.repeat(80));
    console.log(`🗓️  GENERATED SHIFTS for template: ${sampleTemplate.id}`);
    console.log('='.repeat(80));
    
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('generated_from_template_id', '==', sampleTemplate.id)
      .limit(5)
      .get();
    
    console.log(`\nFound ${shiftsSnap.size} shifts (showing first 5):\n`);
    
    shiftsSnap.docs.forEach((doc, index) => {
      const data = doc.data();
      const start = data.shift_start?.toDate() || new Date();
      const end = data.shift_end?.toDate() || new Date();
      
      console.log(`\nShift ${index + 1}: ${doc.id}`);
      console.log(`  Teacher ID: ${data.teacher_id}`);
      console.log(`  Student IDs: ${JSON.stringify(data.student_ids || [])}`);
      console.log(`  Start: ${start.toISOString()}`);
      console.log(`  End: ${end.toISOString()}`);
      console.log(`  Status: ${data.status}`);
      console.log(`  Video Provider: ${data.video_provider}`);
      console.log(`  Subject: ${data.subject}`);
      console.log(`  Subject ID: ${data.subject_id}`);
      console.log(`  Subject Display: ${data.subject_display_name}`);
      console.log(`  Category: ${data.shift_category || data.category}`);
      console.log(`  Hourly Rate: ${data.hourly_rate}`);
      console.log(`  Generated From Template: ${data.generated_from_template}`);
      console.log(`  Generated From Template ID: ${data.generated_from_template_id}`);
      console.log(`  Recurrence Series ID: ${data.recurrence_series_id}`);
      console.log(`  Is Recurring: ${data.is_recurring}`);
    });
  }
  
  // 3. Check the 4 teachers we're about to create shifts for
  console.log('\n\n' + '='.repeat(80));
  console.log('👥 CHECKING TARGET TEACHERS');
  console.log('='.repeat(80));
  
  const targetTeachers = [
    { name: 'Arabieu Bah', uid: 'xxKjtk7NSNUWDXO268UOgK27z1E2' },
    { name: 'Elham Ahmed Shifa', uid: 'BWfi0eUY2heSPC16V3c6Tz1BdPX2' },
    { name: 'Nasrullah Jalloh', uid: 'yL01069U5zdjl10F5mvUBBJ665p1' },
    { name: 'Habibu Barry', uid: 'kjVbNRUjJoZRw3NTd3jIbREdYUu2' },
  ];
  
  for (const teacher of targetTeachers) {
    console.log(`\n${teacher.name} (${teacher.uid}):`);
    
    const teacherDoc = await db.collection('users').doc(teacher.uid).get();
    if (!teacherDoc.exists) {
      console.log('  ❌ Teacher not found!');
      continue;
    }
    
    const teacherData = teacherDoc.data();
    console.log(`  Name: ${teacherData.first_name} ${teacherData.last_name}`);
    console.log(`  Email: ${teacherData['e-mail'] || teacherData.email}`);
    console.log(`  User Type: ${teacherData.user_type}`);
    console.log(`  Timezone: ${teacherData.timezone || teacherData.time_zone || 'N/A'}`);
    
    // Check existing templates for this teacher
    const existingTemplates = await db.collection('shift_templates')
      .where('teacher_id', '==', teacher.uid)
      .where('is_active', '==', true)
      .get();
    
    console.log(`  Existing Active Templates: ${existingTemplates.size}`);
    
    // Get one template to see their typical settings
    if (existingTemplates.size > 0) {
      const sampleData = existingTemplates.docs[0].data();
      console.log(`  Sample Template Settings:`);
      console.log(`    - Subject: ${sampleData.subject}`);
      console.log(`    - Subject ID: ${sampleData.subject_id}`);
      console.log(`    - Subject Display: ${sampleData.subject_display_name}`);
      console.log(`    - Hourly Rate: ${sampleData.hourly_rate}`);
      console.log(`    - Category: ${sampleData.category}`);
      console.log(`    - Max Days Ahead: ${sampleData.max_days_ahead}`);
      console.log(`    - Admin Timezone: ${sampleData.admin_timezone}`);
      console.log(`    - Teacher Timezone: ${sampleData.teacher_timezone}`);
    }
  }
  
  // 4. Summary of pattern
  console.log('\n\n' + '='.repeat(80));
  console.log('📝 PATTERN SUMMARY');
  console.log('='.repeat(80));
  console.log(`
Key Fields for shift_templates:
  ✓ teacher_id (string)
  ✓ teacher_name (string)
  ✓ student_ids (array)
  ✓ student_names (array)
  ✓ start_time (string, HH:MM format)
  ✓ end_time (string, HH:MM format)
  ✓ duration_minutes (number)
  ✓ enhanced_recurrence (object with selectedWeekdays array)
  ✓ recurrence ('weekly')
  ✓ video_provider ('livekit')
  ✓ subject (string, legacy field)
  ✓ subject_id (string or null)
  ✓ subject_display_name (string)
  ✓ category (string, e.g., 'teaching')
  ✓ hourly_rate (number or null)
  ✓ max_days_ahead (number, typically 70 for 10 weekly occurrences)
  ✓ admin_timezone ('America/New_York')
  ✓ teacher_timezone (string)
  ✓ is_active (true)
  ✓ auto_generated_name (string)
  ✓ notes (string)
  ✓ base_shift_id (string, usually same as template ID)
  ✓ recurrence_series_id (string, usually same as template ID)
  ✓ base_shift_start (timestamp)
  ✓ base_shift_end (timestamp)
  ✓ recurrence_end_date (timestamp, far future)
  
Key Fields for teaching_shifts (generated):
  ✓ teacher_id (string)
  ✓ student_ids (array)
  ✓ shift_start (timestamp)
  ✓ shift_end (timestamp)
  ✓ status ('scheduled')
  ✓ video_provider ('livekit')
  ✓ subject (string)
  ✓ subject_id (string or null)
  ✓ subject_display_name (string)
  ✓ shift_category or category (string)
  ✓ hourly_rate (number or null)
  ✓ generated_from_template (true)
  ✓ generated_from_template_id (string)
  ✓ recurrence_series_id (string)
  ✓ is_recurring (true)
  `);
}

examineShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
