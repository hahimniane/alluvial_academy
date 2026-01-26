#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const THIERNO_UID = 'Thz8PIVUGpS5cjlIYBJAemjoQxw1';

async function investigate() {
  console.log('Investigating Thierno Aliou Diallo duplicate shifts...\n');
  console.log('='.repeat(80));
  
  // 1. Check all active templates
  console.log('1. ACTIVE TEMPLATES:\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', THIERNO_UID)
    .where('is_active', '==', true)
    .get();
  
  console.log(`Total active templates: ${templatesSnap.size}\n`);
  
  const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const templatesByDayTime = new Map();
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    
    for (const day of weekdays) {
      const key = `Day ${day} (${DAY_NAMES[day] || day}) - ${data.start_time} to ${data.end_time}`;
      
      if (!templatesByDayTime.has(key)) {
        templatesByDayTime.set(key, []);
      }
      templatesByDayTime.get(key).push({
        id: doc.id,
        students: data.student_ids,
        notes: data.notes,
      });
    }
    
    console.log(`Template: ${doc.id}`);
    console.log(`  Days: ${weekdays.map(d => DAY_NAMES[d] || d).join(', ')}`);
    console.log(`  Time: ${data.start_time} - ${data.end_time}`);
    console.log(`  Students: ${data.student_ids?.length || 0}`);
    console.log('');
  }
  
  // 2. Check for duplicate templates (same day/time)
  console.log('='.repeat(80));
  console.log('2. CHECKING FOR DUPLICATE TEMPLATES (same day/time):\n');
  
  let hasDuplicateTemplates = false;
  for (const [key, templates] of templatesByDayTime) {
    if (templates.length > 1) {
      hasDuplicateTemplates = true;
      console.log(`⚠️ DUPLICATE: ${key}`);
      for (const t of templates) {
        console.log(`   - Template ID: ${t.id}`);
        console.log(`     Students: ${t.students?.join(', ')}`);
      }
      console.log('');
    }
  }
  
  if (!hasDuplicateTemplates) {
    console.log('✅ No duplicate templates found (each day/time has only one template).\n');
  }
  
  // 3. Check shifts for this week
  console.log('='.repeat(80));
  console.log('3. CHECKING SHIFTS (this week):\n');
  
  const now = DateTime.now().setZone('America/New_York').startOf('week');
  const endOfWeek = now.plus({ days: 7 });
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', THIERNO_UID)
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(now.toJSDate()))
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(endOfWeek.toJSDate()))
    .get();
  
  console.log(`Total shifts this week: ${shiftsSnap.size}\n`);
  
  const shiftsByDayTime = new Map();
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    const startTime = DateTime.fromJSDate(data.shift_start.toDate()).setZone('America/New_York');
    const key = `${startTime.toFormat('EEE MMM dd')} - ${startTime.toFormat('h:mm a')}`;
    
    if (!shiftsByDayTime.has(key)) {
      shiftsByDayTime.set(key, []);
    }
    shiftsByDayTime.get(key).push({
      id: doc.id,
      templateId: data.template_id,
      status: data.status,
      students: data.student_ids,
    });
  }
  
  // 4. Check for duplicate shifts (same day/time)
  console.log('='.repeat(80));
  console.log('4. CHECKING FOR DUPLICATE SHIFTS (same day/time):\n');
  
  let hasDuplicateShifts = false;
  for (const [key, shifts] of shiftsByDayTime) {
    if (shifts.length > 1) {
      hasDuplicateShifts = true;
      console.log(`⚠️ DUPLICATE SHIFTS: ${key}`);
      for (const s of shifts) {
        console.log(`   - Shift ID: ${s.id}`);
        console.log(`     Template: ${s.templateId}`);
        console.log(`     Status: ${s.status}`);
        console.log(`     Students: ${s.students?.join(', ')}`);
      }
      console.log('');
    } else {
      console.log(`✅ ${key}: 1 shift`);
    }
  }
  
  if (!hasDuplicateShifts) {
    console.log('\n✅ No duplicate shifts found.\n');
  }
  
  // 5. Check for shifts without templates or from different templates
  console.log('='.repeat(80));
  console.log('5. ALL SHIFTS DETAILS:\n');
  
  const allShiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', THIERNO_UID)
    .where('status', '==', 'scheduled')
    .get();
  
  console.log(`Total scheduled shifts: ${allShiftsSnap.size}\n`);
  
  // Group by template ID
  const shiftsByTemplate = new Map();
  
  for (const doc of allShiftsSnap.docs) {
    const data = doc.data();
    const templateId = data.template_id || 'NO_TEMPLATE';
    
    if (!shiftsByTemplate.has(templateId)) {
      shiftsByTemplate.set(templateId, []);
    }
    shiftsByTemplate.get(templateId).push(doc.id);
  }
  
  console.log('Shifts grouped by template:\n');
  for (const [templateId, shiftIds] of shiftsByTemplate) {
    console.log(`Template: ${templateId}`);
    console.log(`  Total shifts: ${shiftIds.length}`);
    console.log('');
  }
}

investigate()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
