#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const THIERNO_UID = 'Thz8PIVUGpS5cjlIYBJAemjoQxw1';

async function analyze() {
  console.log('Analyzing Thierno schedule patterns...\n');
  console.log('='.repeat(80));
  
  const allShiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', THIERNO_UID)
    .where('status', '==', 'scheduled')
    .get();
  
  // Separate old shifts (no template) from new shifts (with template)
  const oldShifts = [];
  const newShifts = [];
  
  for (const doc of allShiftsSnap.docs) {
    const data = doc.data();
    const startTime = DateTime.fromJSDate(data.shift_start.toDate()).setZone('America/New_York');
    
    const shiftInfo = {
      id: doc.id,
      dayOfWeek: startTime.weekdayLong,
      time: startTime.toFormat('h:mm a'),
      date: startTime.toFormat('MMM dd'),
      fullDate: startTime.toFormat('EEE, MMM dd yyyy h:mm a'),
      students: data.student_ids,
      studentNames: data.student_names,
    };
    
    if (data.template_id) {
      newShifts.push({ ...shiftInfo, templateId: data.template_id });
    } else {
      oldShifts.push(shiftInfo);
    }
  }
  
  // Analyze patterns
  console.log('OLD SHIFTS (no template_id): ' + oldShifts.length + '\n');
  
  const oldByDayTime = new Map();
  for (const shift of oldShifts) {
    const key = `${shift.dayOfWeek} ${shift.time}`;
    if (!oldByDayTime.has(key)) {
      oldByDayTime.set(key, 0);
    }
    oldByDayTime.set(key, oldByDayTime.get(key) + 1);
  }
  
  console.log('Schedule pattern (day + time):');
  for (const [key, count] of [...oldByDayTime.entries()].sort()) {
    console.log(`  ${key}: ${count} shifts`);
  }
  
  console.log('\nSample old shifts:');
  for (let i = 0; i < Math.min(5, oldShifts.length); i++) {
    console.log(`  - ${oldShifts[i].fullDate}`);
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('NEW SHIFTS (with template_id): ' + newShifts.length + '\n');
  
  const newByDayTime = new Map();
  for (const shift of newShifts) {
    const key = `${shift.dayOfWeek} ${shift.time}`;
    if (!newByDayTime.has(key)) {
      newByDayTime.set(key, 0);
    }
    newByDayTime.set(key, newByDayTime.get(key) + 1);
  }
  
  console.log('Schedule pattern (day + time):');
  for (const [key, count] of [...newByDayTime.entries()].sort()) {
    console.log(`  ${key}: ${count} shifts`);
  }
  
  console.log('\nSample new shifts:');
  for (let i = 0; i < Math.min(5, newShifts.length); i++) {
    console.log(`  - ${newShifts[i].fullDate}`);
  }
  
  // Compare patterns
  console.log('\n' + '='.repeat(80));
  console.log('PATTERN COMPARISON:\n');
  
  const allDayTimes = new Set([...oldByDayTime.keys(), ...newByDayTime.keys()]);
  
  console.log('Day/Time              | Old Shifts | New Shifts | DUPLICATE?');
  console.log('-'.repeat(70));
  
  for (const key of [...allDayTimes].sort()) {
    const oldCount = oldByDayTime.get(key) || 0;
    const newCount = newByDayTime.get(key) || 0;
    const isDuplicate = oldCount > 0 && newCount > 0 ? '⚠️ YES' : '';
    console.log(`${key.padEnd(22)}| ${String(oldCount).padEnd(11)}| ${String(newCount).padEnd(11)}| ${isDuplicate}`);
  }
  
  // Check for this specific week
  console.log('\n' + '='.repeat(80));
  console.log('THIS WEEK SHIFTS (Mon Jan 19 - Sun Jan 25):\n');
  
  const weekStart = DateTime.fromObject({ year: 2026, month: 1, day: 19 }, { zone: 'America/New_York' });
  const weekEnd = weekStart.plus({ days: 7 });
  
  const thisWeekShifts = allShiftsSnap.docs.filter(doc => {
    const data = doc.data();
    const startTime = DateTime.fromJSDate(data.shift_start.toDate());
    return startTime >= weekStart && startTime < weekEnd;
  });
  
  console.log(`Total shifts this week: ${thisWeekShifts.length}\n`);
  
  for (const doc of thisWeekShifts) {
    const data = doc.data();
    const startTime = DateTime.fromJSDate(data.shift_start.toDate()).setZone('America/New_York');
    const hasTemplate = data.template_id ? 'TPL' : 'OLD';
    console.log(`[${hasTemplate}] ${startTime.toFormat('EEE, MMM dd h:mm a')} - ${doc.id.substring(0, 30)}...`);
  }
}

analyze()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
