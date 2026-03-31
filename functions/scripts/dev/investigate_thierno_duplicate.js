#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function investigate() {
  console.log('Investigating Thierno Aliou Diallo duplicates...\n');
  console.log('='.repeat(80));
  
  // 1. Search for all teachers with "Thierno" in their name
  const usersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  
  const thiernoTeachers = [];
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    
    if (fullName.toLowerCase().includes('thierno')) {
      thiernoTeachers.push({
        uid: doc.id,
        firstName: data.first_name,
        lastName: data.last_name,
        fullName: fullName,
        email: data['e-mail'] || data.email,
        timezone: data.timezone || data.time_zone,
        createdAt: data.created_at,
      });
    }
  }
  
  console.log(`Found ${thiernoTeachers.length} teacher(s) with "Thierno" in name:\n`);
  
  for (const teacher of thiernoTeachers) {
    console.log(`Teacher UID: ${teacher.uid}`);
    console.log(`  Name: ${teacher.fullName}`);
    console.log(`  Email: ${teacher.email}`);
    console.log(`  Timezone: ${teacher.timezone}`);
    console.log(`  Created: ${teacher.createdAt ? new Date(teacher.createdAt._seconds * 1000).toISOString() : 'N/A'}`);
    console.log('');
  }
  
  // 2. Check templates for each Thierno teacher
  console.log('='.repeat(80));
  console.log('SHIFT TEMPLATES:\n');
  
  for (const teacher of thiernoTeachers) {
    const templatesSnap = await db.collection('shift_templates')
      .where('teacher_id', '==', teacher.uid)
      .get();
    
    console.log(`\nTeacher: ${teacher.fullName} (${teacher.uid})`);
    console.log(`Total templates: ${templatesSnap.size}`);
    
    const activeTemplates = templatesSnap.docs.filter(doc => doc.data().is_active === true);
    const inactiveTemplates = templatesSnap.docs.filter(doc => doc.data().is_active !== true);
    
    console.log(`  Active: ${activeTemplates.length}`);
    console.log(`  Inactive: ${inactiveTemplates.length}`);
    
    if (activeTemplates.length > 0) {
      console.log('\n  Active Templates:');
      for (const doc of activeTemplates) {
        const data = doc.data();
        const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
        console.log(`    - ${doc.id}`);
        console.log(`      Days: ${weekdays}`);
        console.log(`      Time: ${data.start_time} - ${data.end_time}`);
        console.log(`      Students: ${data.student_ids?.length || 0}`);
        console.log(`      Created: ${data.created_at ? new Date(data.created_at._seconds * 1000).toISOString() : 'N/A'}`);
      }
    }
  }
  
  // 3. Check for duplicate schedules
  console.log('\n' + '='.repeat(80));
  console.log('CHECKING FOR DUPLICATE SCHEDULES:\n');
  
  if (thiernoTeachers.length > 1) {
    console.log('⚠️ MULTIPLE TEACHER ACCOUNTS FOUND!');
    console.log('\nThis could be causing duplicate entries in the UI.');
    console.log('\nPossible reasons:');
    console.log('1. Duplicate teacher account created by mistake');
    console.log('2. Same person registered twice with different emails');
    console.log('3. Data migration issue');
  } else if (thiernoTeachers.length === 1) {
    // Check if there are duplicate templates with same schedule
    const teacher = thiernoTeachers[0];
    const templatesSnap = await db.collection('shift_templates')
      .where('teacher_id', '==', teacher.uid)
      .where('is_active', '==', true)
      .get();
    
    const scheduleMap = new Map();
    
    for (const doc of templatesSnap.docs) {
      const data = doc.data();
      const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
      
      for (const day of weekdays) {
        const key = `${day}-${data.start_time}-${data.end_time}-${data.student_ids?.join(',')}`;
        
        if (!scheduleMap.has(key)) {
          scheduleMap.set(key, []);
        }
        scheduleMap.get(key).push(doc.id);
      }
    }
    
    let hasDuplicates = false;
    for (const [key, templateIds] of scheduleMap) {
      if (templateIds.length > 1) {
        hasDuplicates = true;
        console.log(`⚠️ DUPLICATE TEMPLATES FOUND:`);
        console.log(`  Schedule: ${key}`);
        console.log(`  Template IDs: ${templateIds.join(', ')}`);
        console.log('');
      }
    }
    
    if (!hasDuplicates) {
      console.log('✅ No duplicate templates found for this teacher.');
    }
  }
  
  // 4. Check shifts in calendar
  console.log('\n' + '='.repeat(80));
  console.log('CHECKING SHIFTS IN CALENDAR:\n');
  
  for (const teacher of thiernoTeachers) {
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('teacher_id', '==', teacher.uid)
      .where('status', '==', 'scheduled')
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(now))
      .where('shift_start', '<', admin.firestore.Timestamp.fromDate(tomorrow))
      .get();
    
    console.log(`Teacher: ${teacher.fullName} (${teacher.uid})`);
    console.log(`  Shifts today: ${shiftsSnap.size}`);
  }
}

investigate()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
