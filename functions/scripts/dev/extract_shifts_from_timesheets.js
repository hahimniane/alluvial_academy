#!/usr/bin/env node
'use strict';

/**
 * Extract unique shift data from timesheet_entries collection.
 * Timesheets contain references to the original shifts with scheduled times.
 * This can be used to recover shift information after deletion.
 * 
 * Usage: node extract_shifts_from_timesheets.js [--start-date YYYY-MM-DD] [--end-date YYYY-MM-DD] [--export]
 */

const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const fs = require('fs');
const path = require('path');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

// Parse command line arguments
const args = process.argv.slice(2);
const startDateArg = args.find(a => a.startsWith('--start-date='))?.split('=')[1] || '2026-01-01';
const endDateArg = args.find(a => a.startsWith('--end-date='))?.split('=')[1] || '2026-01-31';
const shouldExport = args.includes('--export');

async function extractShiftsFromTimesheets() {
  console.log('='.repeat(80));
  console.log('EXTRACTING SHIFT DATA FROM TIMESHEETS');
  console.log(`Date range: ${startDateArg} to ${endDateArg}`);
  console.log('='.repeat(80));
  console.log('');

  const startDate = DateTime.fromISO(startDateArg, { zone: NYC_TZ }).startOf('day');
  const endDate = DateTime.fromISO(endDateArg, { zone: NYC_TZ }).endOf('day');

  // Query timesheet_entries within the date range
  const timesheetsSnap = await db.collection('timesheet_entries')
    .where('scheduled_start', '>=', admin.firestore.Timestamp.fromDate(startDate.toJSDate()))
    .where('scheduled_start', '<=', admin.firestore.Timestamp.fromDate(endDate.toJSDate()))
    .get();

  console.log(`Found ${timesheetsSnap.docs.length} timesheet entries in date range\n`);

  // Group by shift_id to get unique shifts
  const shiftMap = new Map();
  const shiftsWithoutId = [];

  for (const doc of timesheetsSnap.docs) {
    const data = doc.data();
    const shiftId = data.shift_id;
    
    if (!shiftId) {
      shiftsWithoutId.push({
        timesheetId: doc.id,
        teacherName: data.teacher_name,
        studentName: data.student_name,
        date: data.date,
        scheduledStart: data.scheduled_start?.toDate(),
        scheduledEnd: data.scheduled_end?.toDate(),
      });
      continue;
    }

    // Collect all timesheet entries for this shift
    if (!shiftMap.has(shiftId)) {
      shiftMap.set(shiftId, {
        shiftId,
        teacherId: data.teacher_id,
        teacherName: data.teacher_name,
        teacherEmail: data.teacher_email,
        studentName: data.student_name,
        scheduledStart: data.scheduled_start?.toDate(),
        scheduledEnd: data.scheduled_end?.toDate(),
        scheduledDurationMinutes: data.scheduled_duration_minutes,
        hourlyRate: data.hourly_rate,
        shiftTitle: data.shift_title,
        description: data.description,
        timesheetCount: 0,
        timesheetIds: [],
      });
    }
    
    const shiftData = shiftMap.get(shiftId);
    shiftData.timesheetCount++;
    shiftData.timesheetIds.push(doc.id);
  }

  // Convert to array and sort by date
  const uniqueShifts = Array.from(shiftMap.values())
    .sort((a, b) => (a.scheduledStart || 0) - (b.scheduledStart || 0));

  console.log(`Found ${uniqueShifts.length} unique shifts with shift_id`);
  console.log(`Found ${shiftsWithoutId.length} timesheets without shift_id\n`);

  // Group by teacher for summary
  const teacherMap = new Map();
  for (const shift of uniqueShifts) {
    const teacherKey = shift.teacherName || 'Unknown';
    if (!teacherMap.has(teacherKey)) {
      teacherMap.set(teacherKey, []);
    }
    teacherMap.get(teacherKey).push(shift);
  }

  console.log('='.repeat(80));
  console.log('SHIFTS BY TEACHER:');
  console.log('='.repeat(80));
  console.log('');

  for (const [teacher, shifts] of teacherMap) {
    console.log(`\n${teacher} (${shifts.length} shifts):`);
    console.log('-'.repeat(40));
    
    for (const shift of shifts.slice(0, 10)) { // Show first 10 per teacher
      const dt = shift.scheduledStart 
        ? DateTime.fromJSDate(shift.scheduledStart).setZone(NYC_TZ)
        : null;
      const endDt = shift.scheduledEnd
        ? DateTime.fromJSDate(shift.scheduledEnd).setZone(NYC_TZ)
        : null;
      
      console.log(`  ${dt?.toFormat('ccc MMM d') || 'unknown'} | ${dt?.toFormat('h:mm a') || '?'} - ${endDt?.toFormat('h:mm a') || '?'} | ${shift.studentName || 'No students'}`);
    }
    
    if (shifts.length > 10) {
      console.log(`  ... and ${shifts.length - 10} more shifts`);
    }
  }

  // Check if these shifts still exist in teaching_shifts collection
  console.log('\n');
  console.log('='.repeat(80));
  console.log('CHECKING WHICH SHIFTS STILL EXIST:');
  console.log('='.repeat(80));
  console.log('');

  let existingCount = 0;
  let deletedCount = 0;
  const deletedShifts = [];

  for (const shift of uniqueShifts) {
    const shiftDoc = await db.collection('teaching_shifts').doc(shift.shiftId).get();
    if (shiftDoc.exists) {
      existingCount++;
    } else {
      deletedCount++;
      deletedShifts.push(shift);
    }
  }

  console.log(`Shifts still in database: ${existingCount}`);
  console.log(`Shifts DELETED (recoverable from timesheets): ${deletedCount}`);
  console.log('');

  if (deletedShifts.length > 0) {
    console.log('='.repeat(80));
    console.log('DELETED SHIFTS (CAN BE RECOVERED):');
    console.log('='.repeat(80));
    
    for (const shift of deletedShifts) {
      const dt = shift.scheduledStart 
        ? DateTime.fromJSDate(shift.scheduledStart).setZone(NYC_TZ)
        : null;
      const endDt = shift.scheduledEnd
        ? DateTime.fromJSDate(shift.scheduledEnd).setZone(NYC_TZ)
        : null;
      
      console.log(`\nShift ID: ${shift.shiftId}`);
      console.log(`  Teacher: ${shift.teacherName} (${shift.teacherId})`);
      console.log(`  Students: ${shift.studentName}`);
      console.log(`  Date: ${dt?.toFormat('cccc, MMMM d, yyyy') || 'unknown'}`);
      console.log(`  Time: ${dt?.toFormat('h:mm a') || '?'} - ${endDt?.toFormat('h:mm a') || '?'}`);
      console.log(`  Duration: ${shift.scheduledDurationMinutes} minutes`);
      console.log(`  Hourly Rate: $${shift.hourlyRate}`);
      console.log(`  Title: ${shift.shiftTitle}`);
      console.log(`  Timesheet count: ${shift.timesheetCount}`);
    }
  }

  // Export to JSON if requested
  if (shouldExport && deletedShifts.length > 0) {
    const exportData = deletedShifts.map(s => ({
      shift_id: s.shiftId,
      teacher_id: s.teacherId,
      teacher_name: s.teacherName,
      teacher_email: s.teacherEmail,
      student_names: s.studentName?.split(', ') || [],
      scheduled_start: s.scheduledStart?.toISOString(),
      scheduled_end: s.scheduledEnd?.toISOString(),
      scheduled_duration_minutes: s.scheduledDurationMinutes,
      hourly_rate: s.hourlyRate,
      shift_title: s.shiftTitle,
      description: s.description,
    }));

    const timestamp = DateTime.now().toFormat('yyyyMMdd_HHmmss');
    const outputPath = path.join('/tmp', `deleted_shifts_from_timesheets_${timestamp}.json`);
    fs.writeFileSync(outputPath, JSON.stringify(exportData, null, 2));
    console.log(`\nExported ${deletedShifts.length} deleted shifts to: ${outputPath}`);
  }

  return { uniqueShifts, deletedShifts, shiftsWithoutId };
}

extractShiftsFromTimesheets()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
