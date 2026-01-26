#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

async function checkAutoGeneration() {
  const now = DateTime.now().setZone(NYC_TZ);
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  console.log('='.repeat(80));
  
  // 1. Check all active templates
  console.log('ACTIVE TEMPLATES:\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('is_active', '==', true)
    .get();
  
  console.log(`Total active templates: ${templatesSnap.size}\n`);
  
  // 2. Specific check for abdulai.bah - this is the template we just created
  console.log('='.repeat(80));
  console.log('ABDULAI BAH SCHEDULE CHECK:\n');
  
  const studentUid = 'v6xRIFMbZvdQp9tAiM35dmyrtx72';
  
  // Get all shifts for this student
  const abdulaiShifts = await db.collection('teaching_shifts')
    .where('student_ids', 'array-contains', studentUid)
    .get();
  
  const scheduled = [];
  const completed = [];
  
  for (const doc of abdulaiShifts.docs) {
    const data = doc.data();
    const shift = {
      id: doc.id,
      templateId: data.template_id,
      status: data.status,
      shiftStart: data.shift_start?.toDate(),
      createdAt: data.created_at?.toDate(),
      generatedFromTemplate: data.generated_from_template,
    };
    
    if (data.status === 'scheduled') {
      scheduled.push(shift);
    } else {
      completed.push(shift);
    }
  }
  
  // Sort scheduled by start time
  scheduled.sort((a, b) => (a.shiftStart || 0) - (b.shiftStart || 0));
  
  console.log(`Total shifts: ${abdulaiShifts.size}`);
  console.log(`  Scheduled: ${scheduled.length}`);
  console.log(`  Completed/Other: ${completed.length}`);
  
  if (scheduled.length > 0) {
    const first = scheduled[0];
    const last = scheduled[scheduled.length - 1];
    
    const firstDt = DateTime.fromJSDate(first.shiftStart).setZone(NYC_TZ);
    const lastDt = DateTime.fromJSDate(last.shiftStart).setZone(NYC_TZ);
    
    console.log(`\nFirst scheduled: ${firstDt.toFormat('ccc MMM d, h:mm a')}`);
    console.log(`Last scheduled: ${lastDt.toFormat('ccc MMM d, h:mm a')}`);
    console.log(`Days covered: ${Math.floor(lastDt.diff(now, 'days').days)} days ahead`);
    
    // Check if all have template_id
    const withTemplate = scheduled.filter(s => s.templateId).length;
    console.log(`\nWith template: ${withTemplate}/${scheduled.length}`);
    
    // Show upcoming shifts
    console.log('\nUpcoming shifts:');
    for (const shift of scheduled.slice(0, 6)) {
      const dt = DateTime.fromJSDate(shift.shiftStart).setZone(NYC_TZ);
      console.log(`  ${dt.toFormat('ccc MMM d, h:mm a')} - template: ${shift.templateId ? 'YES' : 'NO'}`);
    }
  }
  
  // 3. Check templates for this student
  console.log('\n' + '='.repeat(80));
  console.log('TEMPLATES FOR ABDULAI BAH:\n');
  
  const templatesForStudent = await db.collection('shift_templates')
    .where('student_ids', 'array-contains', studentUid)
    .get();
  
  for (const doc of templatesForStudent.docs) {
    const data = doc.data();
    const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const days = (data.enhanced_recurrence?.selectedWeekdays || []).map(d => dayNames[d]);
    
    console.log(`Template: ${doc.id}`);
    console.log(`  Teacher: ${data.teacher_name}`);
    console.log(`  Time: ${data.start_time} - ${data.end_time}`);
    console.log(`  Days: ${days.join(', ')}`);
    console.log(`  Active: ${data.is_active}`);
    console.log(`  Max days ahead: ${data.max_days_ahead}`);
    console.log(`  Created: ${data.created_at?.toDate()?.toISOString() || 'unknown'}`);
    console.log('');
  }
  
  // 4. Check furthest scheduled shift overall
  console.log('='.repeat(80));
  console.log('FURTHEST SCHEDULED SHIFT (system-wide):\n');
  
  const furthestSnap = await db.collection('teaching_shifts')
    .where('status', '==', 'scheduled')
    .orderBy('shift_start', 'desc')
    .limit(1)
    .get();
  
  if (!furthestSnap.empty) {
    const data = furthestSnap.docs[0].data();
    const shiftStart = data.shift_start?.toDate();
    const shiftDt = shiftStart ? DateTime.fromJSDate(shiftStart).setZone(NYC_TZ) : null;
    const daysAhead = shiftDt ? Math.floor(shiftDt.diff(now, 'days').days) : 0;
    
    console.log(`Teacher: ${data.teacher_name}`);
    console.log(`Students: ${(data.student_names || []).join(', ')}`);
    console.log(`Date: ${shiftDt?.toFormat('cccc, MMMM d, yyyy')}`);
    console.log(`Time: ${shiftDt?.toFormat('h:mm a')} NYC`);
    console.log(`Days ahead: ${daysAhead} days`);
    console.log(`Has template: ${data.template_id ? 'YES' : 'NO'}`);
  }
}

checkAutoGeneration()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
