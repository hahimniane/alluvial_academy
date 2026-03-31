#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

async function checkSchedulerWorking() {
  const now = DateTime.now().setZone(NYC_TZ);
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  console.log('='.repeat(80));
  
  // Find templates created before today
  const today = now.startOf('day');
  const yesterday = today.minus({ days: 1 });
  
  console.log('CHECKING IF DAILY SCHEDULER IS GENERATING SHIFTS:\n');
  
  // Get a few templates that were created a while ago
  const templatesSnap = await db.collection('shift_templates')
    .where('is_active', '==', true)
    .limit(20)
    .get();
  
  let olderTemplates = [];
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const createdAt = data.created_at?.toDate();
    if (createdAt) {
      const createdDt = DateTime.fromJSDate(createdAt).setZone(NYC_TZ);
      if (createdDt < yesterday) {
        olderTemplates.push({
          id: doc.id,
          teacherName: data.teacher_name,
          studentNames: data.student_names || [],
          createdAt: createdDt,
          maxDaysAhead: data.max_days_ahead,
        });
      }
    }
  }
  
  console.log(`Found ${olderTemplates.length} templates created before yesterday\n`);
  
  if (olderTemplates.length === 0) {
    console.log('No older templates found. Checking all templates...');
    return;
  }
  
  // Pick a template and check its shifts
  const testTemplate = olderTemplates[0];
  console.log(`Checking template: ${testTemplate.id}`);
  console.log(`  Teacher: ${testTemplate.teacherName}`);
  console.log(`  Students: ${testTemplate.studentNames.join(', ')}`);
  console.log(`  Created: ${testTemplate.createdAt.toFormat('fff')}`);
  console.log(`  Max days ahead: ${testTemplate.maxDaysAhead}`);
  
  // Get shifts for this template
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('template_id', '==', testTemplate.id)
    .get();
  
  const shifts = [];
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    shifts.push({
      id: doc.id,
      shiftStart: data.shift_start?.toDate(),
      createdAt: data.created_at?.toDate(),
      status: data.status,
    });
  }
  
  // Sort by shift start
  shifts.sort((a, b) => (a.shiftStart || 0) - (b.shiftStart || 0));
  
  // Find the furthest shift
  const scheduledShifts = shifts.filter(s => s.status === 'scheduled');
  
  if (scheduledShifts.length > 0) {
    const furthest = scheduledShifts[scheduledShifts.length - 1];
    const furthestDt = DateTime.fromJSDate(furthest.shiftStart).setZone(NYC_TZ);
    const daysAhead = Math.floor(furthestDt.diff(now, 'days').days);
    
    console.log(`\n  Scheduled shifts: ${scheduledShifts.length}`);
    console.log(`  Furthest shift: ${furthestDt.toFormat('ccc MMM d, yyyy')}`);
    console.log(`  Days ahead: ${daysAhead} days`);
    
    // Check if it's close to max_days_ahead (meaning scheduler is keeping up)
    if (daysAhead >= testTemplate.maxDaysAhead - 7) {
      console.log('\n  ✅ SCHEDULER IS WORKING - shifts are being generated up to max_days_ahead');
    } else {
      console.log('\n  ⚠️ SCHEDULER MAY NOT BE RUNNING - shifts are not at max_days_ahead');
    }
    
    // Show recent shifts and when they were created
    console.log('\n  Recently scheduled shifts:');
    for (const shift of scheduledShifts.slice(-5)) {
      const shiftDt = DateTime.fromJSDate(shift.shiftStart).setZone(NYC_TZ);
      const createdDt = shift.createdAt ? DateTime.fromJSDate(shift.createdAt).setZone(NYC_TZ) : null;
      console.log(`    ${shiftDt.toFormat('ccc MMM d')} - created: ${createdDt?.toFormat('MMM d, h:mm a') || 'unknown'}`);
    }
  }
  
  // Extra check: look at multiple templates
  console.log('\n' + '='.repeat(80));
  console.log('SUMMARY OF MULTIPLE TEMPLATES:\n');
  
  for (const template of olderTemplates.slice(0, 5)) {
    const templateShiftsSnap = await db.collection('teaching_shifts')
      .where('template_id', '==', template.id)
      .get();
    
    let furthestDate = null;
    let scheduledCount = 0;
    
    for (const doc of templateShiftsSnap.docs) {
      const data = doc.data();
      if (data.status === 'scheduled') {
        scheduledCount++;
        const shiftStart = data.shift_start?.toDate();
        if (shiftStart && (!furthestDate || shiftStart > furthestDate)) {
          furthestDate = shiftStart;
        }
      }
    }
    
    const furthestDt = furthestDate ? DateTime.fromJSDate(furthestDate).setZone(NYC_TZ) : null;
    const daysAhead = furthestDt ? Math.floor(furthestDt.diff(now, 'days').days) : 0;
    
    console.log(`${template.teacherName} → ${template.studentNames.join(', ')}`);
    console.log(`  Scheduled: ${scheduledCount}, Furthest: ${daysAhead} days ahead (max: ${template.maxDaysAhead})`);
  }
}

checkSchedulerWorking()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
