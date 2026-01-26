#!/usr/bin/env node
'use strict';

/**
 * Create shifts for confirmed teachers from Kadija CSV
 * 
 * Usage:
 *   node functions/scripts/create_kadija_confirmed_shifts.js [--csv path/to/file.csv] [--apply]
 * 
 * Defaults to Kadija_confirmed_classes.csv in project root
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = 'alluwal-academy';
const APPLY = process.argv.includes('--apply');
const ADMIN_TIMEZONE = 'America/New_York';
const MAX_DAYS_AHEAD = 70; // 10 weeks = 10 occurrences for weekly classes

// Find --csv argument
const findCsvPath = () => {
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--csv' && args[i + 1]) {
      return args[i + 1];
    }
    if (args[i].startsWith('--csv=')) {
      return args[i].slice(6);
    }
  }
  return null;
};

const csvPath = findCsvPath();
const SCHEDULE_FILE = csvPath 
  ? path.resolve(csvPath)
  : path.resolve(__dirname, '../..', 'Kadija_confirmed_classes.csv');

// Confirmed teachers with their UIDs
const CONFIRMED_TEACHERS = {
  'Arabieu Bah': 'xxKjtk7NSNUWDXO268UOgK27z1E2',
  'Elham Shifa': 'BWfi0eUY2heSPC16V3c6Tz1BdPX2', // CSV name, maps to Elham Ahmed Shifa
  'Elham Ahmed Shifa': 'BWfi0eUY2heSPC16V3c6Tz1BdPX2',
  'Nasrullah Jalloh': 'yL01069U5zdjl10F5mvUBBJ665p1',
  'Habibu Barry': 'kjVbNRUjJoZRw3NTd3jIbREdYUu2',
};

// Subject mappings
const SUBJECT_MAP = {
  'islamic': {
    id: '5w7SXs0X7ydFRz8R2Wjf',
    name: 'islamic',
    displayName: 'Islamic',
    hourlyRate: 4,
  },
  'adult class': {
    id: 'CaqzMRVkfP69p3HnzyeL',
    name: 'adult_class',
    displayName: 'Adult Class',
    hourlyRate: 5,
  },
  'afrolingual': {
    id: '2G37mb9Ssvc4mwAsyvFh',
    name: 'afrolingual',
    displayName: 'AfroLingual',
    hourlyRate: 4,
  },
  'after learning': {
    id: '2YY9MrEHCBwhhx52Q88e',
    name: 'after_learning',
    displayName: 'After Learning',
    hourlyRate: 5,
  },
};

const DAY_MAP = new Map([
  ['monday', 1], ['tuesday', 2], ['wednesday', 3], ['thursday', 4],
  ['friday', 5], ['saturday', 6], ['sunday', 7],
]);

const DAY_NAMES = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const normalizeCode = (value) => (value || '').toString().trim().toLowerCase();

const parseTimeRange = (value) => {
  const raw = (value || '').toString().replace(/nyc/gi, '').replace(/time/gi, '').replace(/;/g, ':').trim();
  if (!raw) return null;
  const timeRegex = /(\d{1,2})\s*(?::\s*(\d{2}))?\s*(am|pm)?/gi;
  const matches = Array.from(raw.matchAll(timeRegex));
  if (matches.length < 2) return null;

  const [startMatch, endMatch] = matches;
  const startHourRaw = Number(startMatch[1]);
  const startMinuteRaw = startMatch[2] ? Number(startMatch[2]) : 0;
  const startMeridiem = startMatch[3]?.toLowerCase();
  const endHourRaw = Number(endMatch[1]);
  const endMinuteRaw = endMatch[2] ? Number(endMatch[2]) : 0;
  const endMeridiem = endMatch[3]?.toLowerCase();

  const resolvedStartMeridiem = startMeridiem || endMeridiem;
  const resolvedEndMeridiem = endMeridiem || startMeridiem;

  const to24h = (hour, meridiem) => {
    if (!meridiem) return hour;
    if (meridiem === 'am') return hour === 12 ? 0 : hour;
    return hour === 12 ? 12 : hour + 12;
  };

  const startHour = to24h(startHourRaw, resolvedStartMeridiem);
  const endHour = to24h(endHourRaw, resolvedEndMeridiem);
  if (!Number.isFinite(startHour) || !Number.isFinite(endHour)) return null;

  const pad = (n) => String(n).padStart(2, '0');
  return {
    startHour, startMinute: startMinuteRaw,
    endHour, endMinute: endMinuteRaw,
    startTime: `${pad(startHour)}:${pad(startMinuteRaw)}`,
    endTime: `${pad(endHour)}:${pad(endMinuteRaw)}`,
    durationMinutes: (endHour * 60 + endMinuteRaw) - (startHour * 60 + startMinuteRaw),
  };
};

const nextOccurrence = (weekday, hour, minute, zone) => {
  const now = DateTime.now().setZone(zone);
  const deltaDays = (weekday - now.weekday + 7) % 7;
  let candidate = now.plus({ days: deltaDays }).set({
    hour, minute, second: 0, millisecond: 0
  });
  if (candidate <= now) {
    candidate = candidate.plus({ days: 7 });
  }
  return candidate;
};

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

async function main() {
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`CSV: ${SCHEDULE_FILE}`);
  console.log(`Mode: ${APPLY ? 'APPLY' : 'DRY RUN'}\n`);

  // Read CSV
  const csvContent = fs.readFileSync(SCHEDULE_FILE, 'utf8');
  const lines = csvContent.split(/\r?\n/);
  const headers = lines[0].split(',').map(h => h.trim());
  
  console.log('CSV Headers:', headers);
  console.log('');

  // Get all students
  const studentsSnap = await db.collection('users')
    .where('user_type', 'in', ['student', 'Student'])
    .get();
  
  const studentsByCode = new Map();
  studentsSnap.docs.forEach(doc => {
    const data = doc.data() || {};
    const code = normalizeCode(data.student_code || data.studentCode || data.student_id);
    if (code) {
      studentsByCode.set(code, {
        uid: doc.id,
        firstName: data.first_name || '',
        lastName: data.last_name || '',
        code
      });
    }
  });

  console.log(`Loaded ${studentsByCode.size} students\n`);

  // Get teacher data
  const teachers = new Map();
  for (const [name, uid] of Object.entries(CONFIRMED_TEACHERS)) {
    const doc = await db.collection('users').doc(uid).get();
    if (doc.exists) {
      const data = doc.data();
      teachers.set(normalizeCode(name), {
        uid,
        firstName: data.first_name || '',
        lastName: data.last_name || '',
        fullName: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        timezone: data.timezone || data.time_zone || ADMIN_TIMEZONE,
      });
    }
  }

  console.log(`Loaded ${teachers.size} confirmed teachers\n`);

  // Parse CSV - tracking state per row
  const schedules = [];
  let currentTeacher = null;
  let currentConfirmed = false;
  let lastTimeRange = null;
  let lastClassType = null;
  let lastProgram = null;
  let lastStudentName = null;
  let lastStudentId = null;

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    const cols = line.split(',').map(c => c.trim());
    const teacherName = cols[0] || '';
    const parentName = cols[1] || '';
    const classType = cols[3] || '';
    const program = cols[4] || '';
    const studentName = cols[5] || '';
    const studentId = cols[6] || '';
    const day = cols[7] || '';
    const time = cols[8] || '';
    const confirmed = cols[10] || '';

    // Update current teacher and confirmed status if specified
    if (teacherName) {
      currentTeacher = teacherName;
      // Check if this teacher is confirmed
      const normalized = normalizeCode(teacherName);
      if (confirmed.toUpperCase() === 'TRUE' && (CONFIRMED_TEACHERS[teacherName] || teachers.has(normalized))) {
        currentConfirmed = true;
        console.log(`Processing teacher: ${currentTeacher} (CONFIRMED)`);
      } else if (confirmed.toUpperCase() === 'FALSE') {
        currentConfirmed = false;
        console.log(`Skipping teacher: ${currentTeacher} (NOT CONFIRMED)`);
      }
      // If confirmed column is empty, keep previous confirmed status for this teacher
    }

    // Skip if current teacher is not confirmed
    if (!currentConfirmed) continue;

    // Inherit values from previous row if not specified
    if (classType) lastClassType = classType;
    if (program) lastProgram = program;
    if (studentName) lastStudentName = studentName;
    if (studentId) lastStudentId = studentId;

    // Skip if no student ID (even after inheritance)
    if (!lastStudentId) continue;

    // Parse time (or inherit from last row)
    let timeRange = parseTimeRange(time);
    if (timeRange) {
      lastTimeRange = timeRange;
    } else {
      timeRange = lastTimeRange;
    }

    if (!timeRange) {
      console.log(`  ⚠️  No time for ${lastStudentName} (${lastStudentId}) on ${day}`);
      continue;
    }

    // Parse day
    const dayNum = DAY_MAP.get(normalizeCode(day));
    if (!dayNum) {
      console.log(`  ⚠️  Invalid day for ${lastStudentName} (${lastStudentId}): ${day}`);
      continue;
    }

    // Map program to subject
    const normalizedProgram = normalizeCode(lastProgram || '');
    let subject = null;
    if (normalizedProgram.includes('islamic')) {
      subject = SUBJECT_MAP['islamic'];
    } else if (normalizedProgram.includes('adult')) {
      subject = SUBJECT_MAP['adult class'];
    } else if (normalizedProgram.includes('afro')) {
      subject = SUBJECT_MAP['afrolingual'];
    } else if (normalizedProgram.includes('after')) {
      subject = SUBJECT_MAP['after learning'];
    } else {
      // Default to Islamic if not specified
      subject = SUBJECT_MAP['islamic'];
    }

    schedules.push({
      teacherName: currentTeacher,
      studentName: lastStudentName,
      studentId: normalizeCode(lastStudentId),
      classType: lastClassType || '',
      program: lastProgram || '',
      day: DAY_NAMES[dayNum],
      dayNum,
      time: `${timeRange.startTime}-${timeRange.endTime}`,
      timeRange,
      subject,
    });
  }

  console.log(`\nParsed ${schedules.length} class slots\n`);

  // Create one template per teacher+student+day+time combination
  const templates = [];
  
  for (const schedule of schedules) {
    const teacher = teachers.get(normalizeCode(schedule.teacherName));
    if (!teacher) {
      console.log(`⚠️  Teacher not found: ${schedule.teacherName}`);
      continue;
    }

    const student = studentsByCode.get(schedule.studentId);
    if (!student) {
      console.log(`⚠️  Student not found: ${schedule.studentId} (${schedule.studentName})`);
      continue;
    }

    // Create one template per day
    templates.push({
      teacher,
      student,
      timeRange: schedule.timeRange,
      subject: schedule.subject,
      classType: schedule.classType,
      dayNum: schedule.dayNum,
      dayName: schedule.day,
    });
  }

  console.log(`\nCreated ${templates.length} shift templates\n`);
  console.log('='.repeat(80));
  console.log('SHIFT TEMPLATES TO CREATE');
  console.log('='.repeat(80));

  templates.forEach((tpl, index) => {
    console.log(`\n${index + 1}. ${tpl.teacher.fullName} → ${tpl.student.firstName} ${tpl.student.lastName} (${tpl.student.code})`);
    console.log(`   Day: ${tpl.dayName}`);
    console.log(`   Time: ${tpl.timeRange.startTime}-${tpl.timeRange.endTime} (${tpl.timeRange.durationMinutes} min)`);
    console.log(`   Subject: ${tpl.subject.displayName} ($${tpl.subject.hourlyRate}/hr)`);
    console.log(`   Class Type: ${tpl.classType}`);
  });

  if (!APPLY) {
    console.log('\n💡 Run with --apply to create templates and generate shifts');
    return;
  }

  console.log('\n' + '='.repeat(80));
  console.log('CREATING SHIFT TEMPLATES');
  console.log('='.repeat(80));

  const createdTemplates = [];
  
  for (const tpl of templates) {
    const hashInput = [
      tpl.teacher.uid,
      tpl.student.uid,
      tpl.dayNum,
      tpl.timeRange.startTime,
      tpl.timeRange.endTime,
    ].join('|');
    const hash = crypto.createHash('sha1').update(hashInput).digest('hex').slice(0, 16);
    const templateId = `tpl_${hash}`;

    // Calculate base shift times
    const baseStart = nextOccurrence(tpl.dayNum, tpl.timeRange.startHour, tpl.timeRange.startMinute, ADMIN_TIMEZONE);
    const baseEnd = baseStart.plus({ minutes: tpl.timeRange.durationMinutes });
    const endDate = DateTime.now().setZone(ADMIN_TIMEZONE).plus({ days: 365 });

    const studentName = `${tpl.student.firstName} ${tpl.student.lastName}`.trim();
    const autoGeneratedName = `${tpl.teacher.fullName} - ${tpl.subject.displayName} - ${studentName}`;
    const notes = `${tpl.classType} / ${tpl.subject.displayName}`;

    const templateDoc = {
      teacher_id: tpl.teacher.uid,
      teacher_name: tpl.teacher.fullName,
      student_ids: [tpl.student.uid],
      student_names: [studentName],
      start_time: tpl.timeRange.startTime,
      end_time: tpl.timeRange.endTime,
      duration_minutes: tpl.timeRange.durationMinutes,
      admin_timezone: ADMIN_TIMEZONE,
      teacher_timezone: tpl.teacher.timezone,
      enhanced_recurrence: {
        type: 'weekly',
        endDate: admin.firestore.Timestamp.fromDate(endDate.toJSDate()),
        excludedDates: [],
        excludedWeekdays: [],
        selectedWeekdays: [tpl.dayNum],
        selectedMonthDays: [],
        selectedMonths: [],
      },
      recurrence: 'weekly',
      recurrence_series_id: templateId,
      recurrence_end_date: admin.firestore.Timestamp.fromDate(endDate.toJSDate()),
      recurrence_settings: null,
      subject: tpl.subject.name,
      subject_id: tpl.subject.id,
      subject_display_name: tpl.subject.displayName,
      hourly_rate: tpl.subject.hourlyRate,
      auto_generated_name: autoGeneratedName,
      custom_name: null,
      notes: notes,
      category: 'teaching',
      leader_role: null,
      video_provider: 'livekit',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
      is_active: true,
      last_generated_date: null,
      max_days_ahead: MAX_DAYS_AHEAD,
      base_shift_id: templateId,
      base_shift_start: admin.firestore.Timestamp.fromDate(baseStart.toJSDate()),
      base_shift_end: admin.firestore.Timestamp.fromDate(baseEnd.toJSDate()),
    };

    await db.collection('shift_templates').doc(templateId).set(templateDoc, { merge: true });
    createdTemplates.push({ templateId, templateDoc, studentName, dayName: tpl.dayName });
    
    console.log(`✅ Created: ${tpl.teacher.fullName} → ${studentName} (${tpl.dayName} ${tpl.timeRange.startTime}-${tpl.timeRange.endTime})`);
  }

  console.log(`\n✅ Created ${createdTemplates.length} shift templates`);

  // Generate shifts
  console.log('\n' + '='.repeat(80));
  console.log('GENERATING SHIFTS');
  console.log('='.repeat(80));

  const shiftTemplateHandlers = require('../handlers/shift_templates');
  let totalCreated = 0;

  for (const { templateId, templateDoc, studentName, dayName } of createdTemplates) {
    const result = await shiftTemplateHandlers._generateShiftsForTemplate({
      templateId,
      template: templateDoc,
    });
    const created = result.created || 0;
    totalCreated += created;
    console.log(`✅ Generated ${created} shifts for ${studentName} (${dayName})`);
  }

  console.log(`\n✅ Done! Created ${createdTemplates.length} templates and ${totalCreated} shifts.`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
