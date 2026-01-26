#!/usr/bin/env node
'use strict';

/**
 * Audit Script: Compare CSV schedule with database shifts and templates
 * 
 * Usage:
 *   node functions/scripts/audit_schedule_vs_database.js [--csv path/to/file.csv]
 * 
 * Defaults to salima_confirmed_teachers.csv in project root
 */

const fs = require('fs');
const path = require('path');
const Excel = require('exceljs');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const ADMIN_TIMEZONE = 'America/New_York';

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
  : path.resolve(__dirname, '../..', 'salima_confirmed_teachers.csv');

const STUDENT_OVERRIDES_PATH = path.resolve(__dirname, 'prod_student_overrides.json');
const TEACHER_OVERRIDES_PATH = path.resolve(__dirname, 'prod_teacher_overrides.json');

// Normalization helpers
const normalizeHeader = (value) =>
  (value || '').toString().replace(/\s+/g, ' ').trim().toLowerCase();

const normalizeName = (value) =>
  (value || '').toString().replace(/[^a-zA-Z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim().toLowerCase();

const normalizeCode = (value) => (value || '').toString().trim().toLowerCase();

const DAY_MAP = new Map([
  ['monday', 1], ['tuesday', 2], ['wednesday', 3], ['thursday', 4],
  ['friday', 5], ['saturday', 6], ['sunday', 7],
]);

const DAY_NAMES = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const parseTimeRange = (value) => {
  const raw = (value || '').toString().replace(/nyc/gi, '').replace(/est/gi, '').trim();
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
  };
};

const parseWeekdays = (value) => {
  const raw = (value || '').toString();
  if (!raw) return [];
  const replaced = raw.replace(/\band\b/gi, ',').replace(/[&/;]/g, ',');
  const parts = replaced.split(',').map(p => p.trim()).filter(Boolean);

  const dayAliases = new Map([
    ['mon', 1], ['monday', 1], ['tue', 2], ['tues', 2], ['tuesday', 2],
    ['wed', 3], ['wednesday', 3], ['thu', 4], ['thur', 4], ['thurs', 4], ['thursday', 4],
    ['fri', 5], ['friday', 5], ['sat', 6], ['saturday', 6], ['sun', 7], ['sunday', 7],
  ]);

  const results = [];
  for (const part of parts) {
    const key = part.toLowerCase().replace(/[^a-z]/g, '');
    const day = DAY_MAP.get(key) || dayAliases.get(key) || dayAliases.get(key.slice(0, 3));
    if (day) results.push(day);
  }
  return Array.from(new Set(results));
};

const loadOverrides = (filePath) => {
  const overrides = new Map();
  if (!fs.existsSync(filePath)) return overrides;
  const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  Object.entries(parsed).forEach(([key, value]) => {
    if (key && value) overrides.set(normalizeCode(key), normalizeCode(value));
  });
  return overrides;
};

const loadTeacherOverrides = () => {
  const overrides = new Map();
  if (!fs.existsSync(TEACHER_OVERRIDES_PATH)) return overrides;
  const parsed = JSON.parse(fs.readFileSync(TEACHER_OVERRIDES_PATH, 'utf8'));
  Object.entries(parsed).forEach(([key, value]) => {
    if (key && value) overrides.set(normalizeName(key), String(value));
  });
  return overrides;
};

const writeCsv = (filePath, headers, rows) => {
  const lines = [headers.join(',')];
  for (const row of rows) {
    const values = headers.map(key => {
      const raw = row[key] == null ? '' : String(row[key]);
      if (raw.includes('"') || raw.includes(',') || raw.includes('\n')) {
        return `"${raw.replace(/"/g, '""')}"`;
      }
      return raw;
    });
    lines.push(values.join(','));
  }
  fs.writeFileSync(filePath, lines.join('\n'));
};

const isMgcOrFgc = (classType) => {
  const normalized = (classType || '').toString().trim().toLowerCase();
  return normalized === 'mgc' || normalized === 'fgc';
};

const isConfirmedValue = (value) => {
  const normalized = (value || '').toString().trim().toLowerCase();
  return normalized === 'true' || normalized === 'yes' || normalized === 'y' || normalized === '1';
};

// Load and parse CSV schedule with proper MGC/FGC group handling
const loadScheduleRows = async (filePath, studentOverrides) => {
  const rows = [];
  const mgcGroups = new Map(); // Track group classes
  const blockMarkers = new Map(); // Track confirmed blocks
  
  const workbook = new Excel.Workbook();
  const sheet = await workbook.csv.readFile(filePath);
  const headerRow = sheet.getRow(1).values;
  const headerMap = new Map();

  headerRow.forEach((value, index) => {
    if (value && index > 0) headerMap.set(normalizeHeader(value), index);
  });

  const headerKey = (candidates) => {
    for (const c of candidates) {
      const idx = headerMap.get(c);
      if (idx) return idx;
    }
    return null;
  };

  const teacherIdx = headerKey(['teacher name']);
  const parentNameIdx = headerKey(['parent name']);
  const studentIdx = headerKey(['student name']);
  const studentCodeIdx = headerKey(['student id (from the website)', 'student id']);
  const dayIdx = headerKey(['day']);
  const timeIdx = headerKey(['time']);
  const classTypeIdx = headerKey(['class type']);
  const confirmedIdx = headerKey(['confirmed']);

  if (!teacherIdx || !studentCodeIdx || !dayIdx || !timeIdx) {
    throw new Error(`Missing required headers in ${filePath}`);
  }

  let blockId = 0;
  let mgcGroupCounter = 0;
  let currentMgcGroupId = null;
  
  let current = {
    teacherName: '',
    parentName: '',
    studentName: '',
    studentCode: '',
    day: '',
    time: '',
    classType: '',
  };

  for (let rowIndex = 2; rowIndex <= sheet.rowCount; rowIndex++) {
    const row = sheet.getRow(rowIndex);
    const teacherNameRaw = teacherIdx ? row.getCell(teacherIdx).text.trim() : '';
    const parentNameRaw = parentNameIdx ? row.getCell(parentNameIdx).text.trim() : '';
    const studentNameRaw = studentIdx ? row.getCell(studentIdx).text.trim() : '';
    const studentCodeRaw = studentCodeIdx ? row.getCell(studentCodeIdx).text.trim() : '';
    const dayRaw = dayIdx ? row.getCell(dayIdx).text.trim() : '';
    const timeRaw = timeIdx ? row.getCell(timeIdx).text.trim() : '';
    const classTypeRaw = classTypeIdx ? row.getCell(classTypeIdx).text.trim() : '';
    const confirmedRaw = confirmedIdx ? row.getCell(confirmedIdx).text.trim() : '';

    const hasValues = [teacherNameRaw, parentNameRaw, studentNameRaw, studentCodeRaw, dayRaw, timeRaw, classTypeRaw, confirmedRaw].some(v => v);
    if (!hasValues) continue;

    // New teacher block starts
    if (teacherNameRaw) {
      blockId++;
      mgcGroupCounter = 0;
      currentMgcGroupId = null;
      current = {
        teacherName: teacherNameRaw,
        parentName: '',
        studentName: '',
        studentCode: '',
        day: '',
        time: '',
        classType: '',
      };
    }

    if (!current.teacherName) continue;

    // Check for parent change (may signal end of FGC group)
    const previousParent = current.parentName;
    const parentChanged = parentNameRaw && 
      normalizeName(parentNameRaw) !== normalizeName(previousParent) &&
      normalizeName(previousParent) !== '';

    // Track class type changes
    if (classTypeRaw) {
      current.classType = classTypeRaw;
      if (isMgcOrFgc(classTypeRaw)) {
        mgcGroupCounter++;
        currentMgcGroupId = `block-${blockId}-mgc-${mgcGroupCounter}`;
      } else {
        currentMgcGroupId = null;
      }
    } else if (parentChanged) {
      // Parent changed without new class type - end current FGC group
      // (FGC = Family Group Class, same parent's students grouped together)
      if (current.classType.toLowerCase() === 'fgc') {
        current.classType = '';
        currentMgcGroupId = null;
      }
      // MGC continues across different parents (it's a manual group)
    }

    // Update current values (carry forward)
    if (parentNameRaw) current.parentName = parentNameRaw;
    if (dayRaw) current.day = dayRaw;
    if (timeRaw) current.time = timeRaw;
    if (studentNameRaw || studentCodeRaw) {
      current.studentName = studentNameRaw || '';
      current.studentCode = studentCodeRaw || '';
    }

    // Track confirmed status for the block
    if (confirmedRaw) {
      const marker = blockMarkers.get(blockId) || { hasConfirmed: false };
      if (isConfirmedValue(confirmedRaw)) marker.hasConfirmed = true;
      blockMarkers.set(blockId, marker);
    }

    const studentCode = normalizeCode(current.studentCode);
    const overrideCode = studentOverrides.get(studentCode) || studentCode;
    
    const rowHasDayTime = Boolean(dayRaw || timeRaw);
    const isMgc = isMgcOrFgc(current.classType);

    // Handle MGC/FGC group classes
    if (isMgc && currentMgcGroupId) {
      const group = mgcGroups.get(currentMgcGroupId) || {
        blockId,
        teacherName: current.teacherName,
        classType: current.classType,
        students: new Map(), // studentCode -> studentName
        schedules: new Map(), // key -> {weekday, startTime, endTime}
      };

      // Add student to group if we have a student code
      if (overrideCode) {
        group.students.set(overrideCode, current.studentName || '');
      }

      // Add schedule to group if we have day/time
      if (rowHasDayTime && current.day && current.time) {
        const weekdays = parseWeekdays(current.day);
        const timeRange = parseTimeRange(current.time);
        if (timeRange) {
          for (const weekday of weekdays) {
            const schedKey = `${weekday}|${timeRange.startTime}|${timeRange.endTime}`;
            if (!group.schedules.has(schedKey)) {
              group.schedules.set(schedKey, {
                weekday,
                dayName: DAY_NAMES[weekday],
                startTime: timeRange.startTime,
                endTime: timeRange.endTime,
              });
            }
          }
        }
      }

      mgcGroups.set(currentMgcGroupId, group);
      continue; // Don't add individual rows for MGC - we'll expand later
    }

    // Individual class (IC) - add directly
    if (!current.teacherName || !overrideCode || !current.day || !current.time || !rowHasDayTime) continue;

    const weekdays = parseWeekdays(current.day);
    if (weekdays.length === 0) continue;

    const timeRange = parseTimeRange(current.time);
    if (!timeRange) continue;

    for (const weekday of weekdays) {
      rows.push({
        blockId,
        classType: current.classType || 'IC',
        teacherName: current.teacherName,
        studentName: current.studentName,
        studentCode: overrideCode,
        weekday,
        dayName: DAY_NAMES[weekday],
        startTime: timeRange.startTime,
        endTime: timeRange.endTime,
      });
    }
  }

  // Expand MGC/FGC groups: each student gets ALL schedules in the group
  for (const group of mgcGroups.values()) {
    if (group.students.size === 0 || group.schedules.size === 0) continue;
    
    for (const [studentCode, studentName] of group.students.entries()) {
      for (const schedule of group.schedules.values()) {
        rows.push({
          blockId: group.blockId,
          classType: group.classType,
          teacherName: group.teacherName,
          studentName,
          studentCode,
          weekday: schedule.weekday,
          dayName: schedule.dayName,
          startTime: schedule.startTime,
          endTime: schedule.endTime,
        });
      }
    }
  }

  // A TRUE anywhere in a teacher's block confirms ALL students under that teacher
  const confirmedBlocks = new Set();
  for (const [id, marker] of blockMarkers.entries()) {
    if (marker.hasConfirmed) confirmedBlocks.add(id);
  }

  // If no blocks are explicitly confirmed, include all rows (audit mode)
  if (confirmedBlocks.size === 0) {
    return rows;
  }

  // Return all rows from confirmed teacher blocks
  return rows.filter(row => confirmedBlocks.has(row.blockId));
};

const buildTeacherMaps = (teachers) => {
  const byName = new Map();
  for (const t of teachers) {
    const full = normalizeName(`${t.firstName} ${t.lastName}`);
    const rev = normalizeName(`${t.lastName} ${t.firstName}`);
    if (full) byName.set(full, t);
    if (rev) byName.set(rev, t);
  }
  return { byName };
};

const pickTeacher = (name, maps, overrides, byId) => {
  const norm = normalizeName(name);
  if (!norm) return null;
  const overrideId = overrides.get(norm);
  if (overrideId) return byId.get(overrideId) || null;
  return maps.byName.get(norm) || null;
};

const main = async () => {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Schedule file: ${SCHEDULE_FILE}`);

  if (!fs.existsSync(SCHEDULE_FILE)) {
    throw new Error(`Schedule file not found: ${SCHEDULE_FILE}`);
  }

  const studentOverrides = loadOverrides(STUDENT_OVERRIDES_PATH);
  const teacherOverrides = loadTeacherOverrides();
  const scheduleRows = await loadScheduleRows(SCHEDULE_FILE, studentOverrides);

  console.log(`\nLoaded ${scheduleRows.length} schedule entries from CSV`);

  // Load teachers from DB
  const teachersSnap = await db.collection('users').where('user_type', '==', 'teacher').get();
  const teachers = teachersSnap.docs.map(doc => {
    const d = doc.data() || {};
    return { uid: doc.id, firstName: d.first_name || '', lastName: d.last_name || '' };
  });
  const teachersById = new Map(teachers.map(t => [t.uid, t]));
  const teacherMaps = buildTeacherMaps(teachers);

  // Load students from DB
  const studentsSnap = await db.collection('users').where('user_type', 'in', ['student', 'Student']).get();
  const studentsByCode = new Map();
  studentsSnap.docs.forEach(doc => {
    const d = doc.data() || {};
    const code = normalizeCode(d.student_code || d.studentCode || d.student_id);
    if (code) {
      studentsByCode.set(code, { 
        uid: doc.id, 
        name: `${d.first_name || ''} ${d.last_name || ''}`.trim(),
        code 
      });
    }
  });

  // Load templates from DB
  const templatesSnap = await db.collection('shift_templates').where('is_active', '==', true).get();
  const templates = templatesSnap.docs.map(doc => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      teacherId: d.teacher_id,
      teacherName: d.teacher_name,
      studentIds: d.student_ids || [],
      studentNames: d.student_names || [],
      weekdays: d.enhanced_recurrence?.selectedWeekdays || [],
      startTime: d.start_time,
      endTime: d.end_time,
    };
  });

  console.log(`\nLoaded from database:`);
  console.log(`  - ${teachers.length} teachers`);
  console.log(`  - ${studentsByCode.size} students`);
  console.log(`  - ${templates.length} active templates`);

  // Build comparison
  const discrepancies = [];
  const csvSchedules = new Map(); // key -> CSV entry
  const dbSchedules = new Map();  // key -> template entry

  // Process CSV entries
  const missingTeachers = new Set();
  const missingStudents = new Set();

  for (const row of scheduleRows) {
    const teacher = pickTeacher(row.teacherName, teacherMaps, teacherOverrides, teachersById);
    if (!teacher) {
      missingTeachers.add(row.teacherName);
      continue;
    }

    const student = studentsByCode.get(row.studentCode);
    if (!student) {
      missingStudents.add(row.studentCode);
      continue;
    }

    // Create a key for this schedule entry
    const key = `${teacher.uid}|${student.uid}|${row.weekday}`;
    const existing = csvSchedules.get(key) || {
      teacherId: teacher.uid,
      teacherName: row.teacherName,
      studentId: student.uid,
      studentName: student.name,
      studentCode: row.studentCode,
      weekday: row.weekday,
      dayName: row.dayName,
      startTime: row.startTime,
      endTime: row.endTime,
      confirmed: row.confirmed,
    };
    csvSchedules.set(key, existing);
  }

  // Process DB templates
  for (const tpl of templates) {
    for (const studentId of tpl.studentIds) {
      for (const weekday of tpl.weekdays) {
        const key = `${tpl.teacherId}|${studentId}|${weekday}`;
        dbSchedules.set(key, {
          templateId: tpl.id,
          teacherId: tpl.teacherId,
          teacherName: tpl.teacherName,
          studentId,
          weekday,
          dayName: DAY_NAMES[weekday],
          startTime: tpl.startTime,
          endTime: tpl.endTime,
        });
      }
    }
  }

  // Compare
  const inCsvOnly = [];
  const inDbOnly = [];
  const timeMismatches = [];

  for (const [key, csv] of csvSchedules) {
    const db = dbSchedules.get(key);
    if (!db) {
      inCsvOnly.push({
        issue: 'IN_CSV_ONLY',
        teacher_name: csv.teacherName,
        student_name: csv.studentName,
        student_code: csv.studentCode,
        day: csv.dayName,
        csv_time: `${csv.startTime}-${csv.endTime}`,
        db_time: '',
        confirmed: csv.confirmed ? 'Yes' : 'No',
      });
    } else if (csv.startTime !== db.startTime || csv.endTime !== db.endTime) {
      timeMismatches.push({
        issue: 'TIME_MISMATCH',
        teacher_name: csv.teacherName,
        student_name: csv.studentName,
        student_code: csv.studentCode,
        day: csv.dayName,
        csv_time: `${csv.startTime}-${csv.endTime}`,
        db_time: `${db.startTime}-${db.endTime}`,
        template_id: db.templateId,
        confirmed: csv.confirmed ? 'Yes' : 'No',
      });
    }
  }

  for (const [key, db] of dbSchedules) {
    if (!csvSchedules.has(key)) {
      const student = studentsSnap.docs.find(d => d.id === db.studentId);
      const studentData = student?.data() || {};
      const studentName = `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim();
      const studentCode = studentData.student_code || studentData.studentCode || '';
      
      inDbOnly.push({
        issue: 'IN_DB_ONLY',
        teacher_name: db.teacherName,
        student_name: studentName,
        student_code: studentCode,
        day: db.dayName,
        csv_time: '',
        db_time: `${db.startTime}-${db.endTime}`,
        template_id: db.templateId,
        confirmed: '',
      });
    }
  }

  // Output results
  console.log('\n========== AUDIT RESULTS ==========\n');
  
  if (missingTeachers.size > 0) {
    console.log(`⚠️  Missing teachers (in CSV but not in DB): ${missingTeachers.size}`);
    for (const t of missingTeachers) console.log(`   - ${t}`);
  }

  if (missingStudents.size > 0) {
    console.log(`\n⚠️  Missing students (in CSV but not in DB): ${missingStudents.size}`);
    for (const s of missingStudents) console.log(`   - ${s}`);
  }

  console.log(`\n📊 Schedule Comparison:`);
  console.log(`   CSV schedules: ${csvSchedules.size}`);
  console.log(`   DB schedules:  ${dbSchedules.size}`);
  console.log(`\n   ✅ In CSV only (missing from DB): ${inCsvOnly.length}`);
  console.log(`   ⚠️  In DB only (not in CSV):       ${inDbOnly.length}`);
  console.log(`   🔄 Time mismatches:                ${timeMismatches.length}`);

  // Write detailed reports
  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const allDiscrepancies = [...inCsvOnly, ...inDbOnly, ...timeMismatches];

  if (allDiscrepancies.length > 0) {
    const reportPath = path.join(OUTPUT_DIR, `schedule_audit_${timestamp}.csv`);
    writeCsv(reportPath, 
      ['issue', 'teacher_name', 'student_name', 'student_code', 'day', 'csv_time', 'db_time', 'template_id', 'confirmed'],
      allDiscrepancies
    );
    console.log(`\n📄 Full report: ${reportPath}`);
  }

  // Print sample discrepancies
  if (inCsvOnly.length > 0) {
    console.log('\n--- Sample: In CSV but missing from DB ---');
    inCsvOnly.slice(0, 10).forEach(d => {
      console.log(`   ${d.teacher_name} → ${d.student_name} (${d.student_code}) | ${d.day} ${d.csv_time}`);
    });
    if (inCsvOnly.length > 10) console.log(`   ... and ${inCsvOnly.length - 10} more`);
  }

  if (inDbOnly.length > 0) {
    console.log('\n--- Sample: In DB but not in CSV ---');
    inDbOnly.slice(0, 10).forEach(d => {
      console.log(`   ${d.teacher_name} → ${d.student_name} | ${d.day} ${d.db_time} (${d.template_id})`);
    });
    if (inDbOnly.length > 10) console.log(`   ... and ${inDbOnly.length - 10} more`);
  }

  if (timeMismatches.length > 0) {
    console.log('\n--- Sample: Time mismatches ---');
    timeMismatches.slice(0, 10).forEach(d => {
      console.log(`   ${d.teacher_name} → ${d.student_name} | ${d.day}`);
      console.log(`      CSV: ${d.csv_time} vs DB: ${d.db_time}`);
    });
    if (timeMismatches.length > 10) console.log(`   ... and ${timeMismatches.length - 10} more`);
  }

  if (allDiscrepancies.length === 0 && missingTeachers.size === 0 && missingStudents.size === 0) {
    console.log('\n✅ All schedules are in sync!');
  }
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
