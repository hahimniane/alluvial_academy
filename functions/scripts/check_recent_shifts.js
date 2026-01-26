#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

async function check() {
  const now = DateTime.now().setZone(NYC_TZ);
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  console.log('='.repeat(80));
  console.log('MOST RECENTLY CREATED SHIFTS:\n');
  
  // Get most recent shifts
  const shiftsSnap = await db.collection('teaching_shifts')
    .orderBy('created_at', 'desc')
    .limit(15)
    .get();
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    const shiftStart = data.shift_start?.toDate();
    const shiftDt = shiftStart ? DateTime.fromJSDate(shiftStart).setZone(NYC_TZ) : null;
    const createdAt = data.created_at?.toDate();
    const createdDt = createdAt ? DateTime.fromJSDate(createdAt).setZone(NYC_TZ) : null;
    
    console.log(`Shift: ${doc.id}`);
    console.log(`  Teacher: ${data.teacher_name}`);
    console.log(`  Students: ${(data.student_names || []).join(', ')}`);
    console.log(`  Time: ${shiftDt?.toFormat('ccc MMM d, h:mm a') || 'unknown'}`);
    console.log(`  Status: ${data.status}`);
    console.log(`  Recurrence: ${data.recurrence}`);
    console.log(`  Template ID: ${data.template_id || 'NONE'}`);
    console.log(`  Created: ${createdDt?.toFormat('MMM d, h:mm:ss a') || 'unknown'}`);
    console.log('');
  }
  
  // Also check recent templates
  console.log('='.repeat(80));
  console.log('MOST RECENTLY CREATED TEMPLATES:\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .orderBy('created_at', 'desc')
    .limit(10)
    .get();
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const days = (data.enhanced_recurrence?.selectedWeekdays || []).map(d => dayNames[d]);
    const createdAt = data.created_at?.toDate();
    const createdDt = createdAt ? DateTime.fromJSDate(createdAt).setZone(NYC_TZ) : null;
    
    console.log(`Template: ${doc.id}`);
    console.log(`  Teacher: ${data.teacher_name}`);
    console.log(`  Students: ${(data.student_names || []).join(', ')}`);
    console.log(`  Time: ${data.start_time} - ${data.end_time}`);
    console.log(`  Days: ${days.join(', ') || 'none'}`);
    console.log(`  Recurrence type: ${data.enhanced_recurrence?.type || data.recurrence}`);
    console.log(`  Active: ${data.is_active}`);
    console.log(`  Max days ahead: ${data.max_days_ahead}`);
    console.log(`  Created: ${createdDt?.toFormat('MMM d, h:mm:ss a') || 'unknown'}`);
    console.log('');
  }
}

check()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
