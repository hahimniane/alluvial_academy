#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEACHER_ID = 'ndmMY0LP4MaXhXGs4KdTjAfmgTm2'; // Rahmatullaah Balde
const RUGIATU_ID = 'rugiatu.jalloh'; // Looking for this student code

async function checkTemplates() {
  console.log('Checking Rahmatullaah Balde templates for Rugiatu...\n');
  
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', TEACHER_ID)
    .where('is_active', '==', true)
    .get();
  
  console.log(`Found ${templatesSnap.size} active templates\n`);
  console.log('='.repeat(80));
  
  // Get all student IDs
  const studentIds = new Set();
  templatesSnap.docs.forEach(doc => {
    const data = doc.data();
    (data.student_ids || []).forEach(id => studentIds.add(id));
  });
  
  // Map student UIDs to codes
  const studentMap = new Map();
  for (const sid of studentIds) {
    const studentDoc = await db.collection('users').doc(sid).get();
    if (studentDoc.exists) {
      const data = studentDoc.data();
      const code = data.student_code || data.studentId || data.student_id;
      studentMap.set(sid, {
        uid: sid,
        code: code,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
      });
      console.log(`Student: ${code} -> ${studentMap.get(sid).name} (UID: ${sid})`);
    }
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('TEMPLATES:\n');
  
  const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const rugiatuTemplates = [];
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    const dayNames = weekdays.map(d => DAY_NAMES[d]).join(', ');
    
    // Find Rugiatu's UID from the map
    let rugiatuUID = null;
    for (const [uid, info] of studentMap) {
      if (info.code === RUGIATU_ID) {
        rugiatuUID = uid;
        break;
      }
    }
    
    const studentNames = (data.student_ids || []).map(sid => {
      const info = studentMap.get(sid);
      return info ? `${info.name} (${info.code})` : sid;
    }).join(', ');
    
    const hasRugiatu = rugiatuUID && data.student_ids?.includes(rugiatuUID);
    
    console.log(`Template: ${doc.id}`);
    console.log(`  Days: [${weekdays}] = ${dayNames}`);
    console.log(`  Time: ${data.start_time} - ${data.end_time} (${data.admin_timezone})`);
    console.log(`  Students: ${studentNames}`);
    console.log(`  Has Rugiatu: ${hasRugiatu ? '✓' : '✗'}`);
    
    if (hasRugiatu && (weekdays.includes(6) || weekdays.includes(7))) {
      console.log(`  >>> RUGIATU SAT/SUN TEMPLATE <<<`);
      rugiatuTemplates.push({
        id: doc.id,
        days: weekdays,
        dayNames: dayNames,
        time: `${data.start_time} - ${data.end_time}`,
        timezone: data.admin_timezone,
      });
    }
    
    console.log('');
  }
  
  console.log('='.repeat(80));
  console.log('\nRUGIATU SATURDAY/SUNDAY TEMPLATES TO FIX:\n');
  
  rugiatuTemplates.forEach(tpl => {
    console.log(`Template ID: ${tpl.id}`);
    console.log(`  Days: ${tpl.dayNames}`);
    console.log(`  Current time: ${tpl.time} (${tpl.timezone})`);
    console.log(`  Should be: 18:00 - 19:00 (6:00 PM - 7:00 PM Saudi time)`);
    console.log('');
  });
  
  if (rugiatuTemplates.length === 0) {
    console.log('No Rugiatu Saturday/Sunday templates found!');
  }
}

checkTemplates()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
