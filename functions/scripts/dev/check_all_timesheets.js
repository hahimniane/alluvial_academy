#!/usr/bin/env node
'use strict';

/**
 * Check ALL timesheet entries in the database (no date filter)
 * to understand the full picture of what timesheets exist.
 */

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

async function checkAllTimesheets() {
  console.log('='.repeat(80));
  console.log('CHECKING ALL TIMESHEET ENTRIES (NO DATE FILTER)');
  console.log('='.repeat(80));
  console.log('');

  // Get ALL timesheet entries
  const timesheetsSnap = await db.collection('timesheet_entries').get();

  console.log(`Total timesheet entries in database: ${timesheetsSnap.docs.length}\n`);

  // Group by teacher
  const teacherMap = new Map();
  const byMonth = new Map();
  let withShiftId = 0;
  let withoutShiftId = 0;
  let withScheduledStart = 0;
  let withoutScheduledStart = 0;

  for (const doc of timesheetsSnap.docs) {
    const data = doc.data();
    
    // Count shift_id presence
    if (data.shift_id) {
      withShiftId++;
    } else {
      withoutShiftId++;
    }

    // Count scheduled_start presence
    if (data.scheduled_start) {
      withScheduledStart++;
    } else {
      withoutScheduledStart++;
    }

    // Group by teacher
    const teacherName = data.teacher_name || 'Unknown';
    if (!teacherMap.has(teacherName)) {
      teacherMap.set(teacherName, {
        count: 0,
        entries: [],
        earliestDate: null,
        latestDate: null,
      });
    }
    const teacherData = teacherMap.get(teacherName);
    teacherData.count++;
    
    // Track dates
    const dateField = data.scheduled_start || data.created_at || data.clock_in_timestamp;
    if (dateField) {
      const date = dateField.toDate ? dateField.toDate() : new Date(dateField);
      if (!teacherData.earliestDate || date < teacherData.earliestDate) {
        teacherData.earliestDate = date;
      }
      if (!teacherData.latestDate || date > teacherData.latestDate) {
        teacherData.latestDate = date;
      }
      
      // Group by month
      const monthKey = DateTime.fromJSDate(date).toFormat('yyyy-MM');
      if (!byMonth.has(monthKey)) {
        byMonth.set(monthKey, 0);
      }
      byMonth.set(monthKey, byMonth.get(monthKey) + 1);
    }

    // Store a few entries for sample
    if (teacherData.entries.length < 3) {
      teacherData.entries.push({
        id: doc.id,
        date: data.date,
        studentName: data.student_name,
        shiftId: data.shift_id,
        status: data.status,
        scheduledStart: data.scheduled_start?.toDate(),
        createdAt: data.created_at?.toDate(),
      });
    }
  }

  console.log('FIELD STATISTICS:');
  console.log('-'.repeat(40));
  console.log(`With shift_id: ${withShiftId}`);
  console.log(`Without shift_id: ${withoutShiftId}`);
  console.log(`With scheduled_start: ${withScheduledStart}`);
  console.log(`Without scheduled_start: ${withoutScheduledStart}`);
  console.log('');

  console.log('TIMESHEETS BY MONTH:');
  console.log('-'.repeat(40));
  const sortedMonths = Array.from(byMonth.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  for (const [month, count] of sortedMonths) {
    console.log(`  ${month}: ${count} entries`);
  }
  console.log('');

  console.log('TIMESHEETS BY TEACHER:');
  console.log('-'.repeat(40));
  const sortedTeachers = Array.from(teacherMap.entries())
    .sort((a, b) => b[1].count - a[1].count);
  
  for (const [teacher, data] of sortedTeachers) {
    const earliest = data.earliestDate 
      ? DateTime.fromJSDate(data.earliestDate).setZone(NYC_TZ).toFormat('MMM d, yyyy')
      : '?';
    const latest = data.latestDate
      ? DateTime.fromJSDate(data.latestDate).setZone(NYC_TZ).toFormat('MMM d, yyyy')
      : '?';
    
    console.log(`\n${teacher}: ${data.count} timesheets (${earliest} - ${latest})`);
    
    // Show sample entries
    for (const entry of data.entries) {
      console.log(`  - ${entry.date || 'no date'} | ${entry.studentName || 'no student'} | shift_id: ${entry.shiftId ? 'YES' : 'NO'} | status: ${entry.status}`);
    }
  }

  // Now check how many unique shifts are referenced
  console.log('\n');
  console.log('='.repeat(80));
  console.log('CHECKING REFERENCED SHIFTS:');
  console.log('='.repeat(80));
  
  const uniqueShiftIds = new Set();
  for (const doc of timesheetsSnap.docs) {
    const shiftId = doc.data().shift_id;
    if (shiftId) {
      uniqueShiftIds.add(shiftId);
    }
  }
  
  console.log(`\nUnique shift IDs referenced in timesheets: ${uniqueShiftIds.size}`);
  
  // Check how many of these shifts exist
  let existingShifts = 0;
  let deletedShifts = 0;
  const deletedShiftIds = [];
  
  for (const shiftId of uniqueShiftIds) {
    const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
    if (shiftDoc.exists) {
      existingShifts++;
    } else {
      deletedShifts++;
      deletedShiftIds.push(shiftId);
    }
  }
  
  console.log(`Shifts that still exist: ${existingShifts}`);
  console.log(`Shifts that were DELETED: ${deletedShifts}`);
  
  if (deletedShiftIds.length > 0) {
    console.log('\nDELETED SHIFT IDs:');
    for (const id of deletedShiftIds.slice(0, 20)) {
      console.log(`  - ${id}`);
    }
    if (deletedShiftIds.length > 20) {
      console.log(`  ... and ${deletedShiftIds.length - 20} more`);
    }
  }
}

checkAllTimesheets()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
