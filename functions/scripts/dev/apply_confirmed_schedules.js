#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const Excel = require('exceljs');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const APPLY = process.argv.includes('--apply');

const ADMIN_TIMEZONE = 'America/New_York';
const CONFIRMED_OCCURRENCES = 10;
const MAX_DAYS_AHEAD = CONFIRMED_OCCURRENCES * 7;

const SCHEDULE_FILE = path.resolve(__dirname, '../..', 'salima_teachers.csv');
const STUDENT_OVERRIDES_PATH = path.resolve(__dirname, 'prod_student_overrides.json');
const TEACHER_OVERRIDES_PATH = path.resolve(__dirname, 'prod_teacher_overrides.json');

const normalizeHeader = (value) =>
  (value || '')
    .toString()
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();

const normalizeName = (value) =>
  (value || '')
    .toString()
    .replace(/[^a-zA-Z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();

const normalizeCode = (value) => (value || '').toString().trim().toLowerCase();

const normalizeSubjectKey = (value) =>
  (value || '')
    .toString()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');

const normalizeConfirmed = (value) => (value || '').toString().trim().toLowerCase();
const normalizeClassType = (value) => (value || '').toString().trim().toLowerCase();
const normalizeParentName = (value) => normalizeName(value);

const isConfirmedValue = (value) => {
  const normalized = normalizeConfirmed(value);
  return normalized === 'true' || normalized === 'yes' || normalized === 'y' || normalized === '1';
};

const isUnconfirmedValue = (value) => normalizeConfirmed(value) === 'unconfirmed';
const isMgcValue = (value) => {
  const normalized = normalizeClassType(value);
  return normalized === 'mgc' || normalized === 'fgc';
};

const DAY_MAP = new Map([
  ['monday', 1],
  ['tuesday', 2],
  ['wednesday', 3],
  ['thursday', 4],
  ['friday', 5],
  ['saturday', 6],
  ['sunday', 7],
]);

const mapSubjectToLegacy = (subjectName) => {
  const normalized = (subjectName || '').toString().toLowerCase().replace(/\s+/g, '_');
  switch (normalized) {
    case 'quran_studies':
      return 'quranStudies';
    case 'hadith_studies':
      return 'hadithStudies';
    case 'fiqh':
      return 'fiqh';
    case 'arabic_language':
      return 'arabicLanguage';
    case 'islamic_history':
      return 'islamicHistory';
    case 'aqeedah':
      return 'aqeedah';
    case 'tafseer':
      return 'tafseer';
    case 'seerah':
      return 'seerah';
    default:
      return 'other';
  }
};

const parseDurationMinutes = (value) => {
  const raw = (value || '').toString().toLowerCase();
  if (!raw) return null;
  const hourMatch = raw.match(/(\d+)\s*hr/);
  const hourMatchAlt = raw.match(/(\d+)\s*hour/);
  const minuteMatch = raw.match(/(\d+)\s*min/);
  const hours = hourMatch ? Number(hourMatch[1]) : hourMatchAlt ? Number(hourMatchAlt[1]) : 0;
  const minutes = minuteMatch ? Number(minuteMatch[1]) : 0;
  if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return null;
  const total = hours * 60 + minutes;
  return total > 0 ? total : null;
};

const parseTimeRange = (value) => {
  const raw = (value || '').toString().replace(/nyc/gi, '').replace(/est/gi, '').trim();
  if (!raw) return null;
  const timeRegex = /(\d{1,2})\s*(?::\s*(\d{2}))?\s*(am|pm)?/gi;
  const matches = Array.from(raw.matchAll(timeRegex));
  if (matches.length < 2) return null;

  const startMatch = matches[0];
  const endMatch = matches[1];

  const startHourRaw = Number(startMatch[1]);
  const startMinuteRaw = startMatch[2] ? Number(startMatch[2]) : 0;
  const startMeridiem = startMatch[3] ? startMatch[3].toLowerCase() : null;
  const endHourRaw = Number(endMatch[1]);
  const endMinuteRaw = endMatch[2] ? Number(endMatch[2]) : 0;
  const endMeridiem = endMatch[3] ? endMatch[3].toLowerCase() : null;

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
    startHour,
    startMinute: startMinuteRaw,
    endHour,
    endMinute: endMinuteRaw,
    startTime: `${pad(startHour)}:${pad(startMinuteRaw)}`,
    endTime: `${pad(endHour)}:${pad(endMinuteRaw)}`,
  };
};

const parseWeekdays = (value) => {
  const raw = (value || '').toString();
  if (!raw) return [];
  const replaced = raw
    .replace(/\band\b/gi, ',')
    .replace(/[&/]/g, ',')
    .replace(/;/g, ',');
  const parts = replaced
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);

  const dayAliases = new Map([
    ['mon', 1],
    ['monday', 1],
    ['tue', 2],
    ['tues', 2],
    ['tuesday', 2],
    ['wed', 3],
    ['wednesday', 3],
    ['thu', 4],
    ['thur', 4],
    ['thurs', 4],
    ['thursday', 4],
    ['fri', 5],
    ['friday', 5],
    ['sat', 6],
    ['saturday', 6],
    ['sun', 7],
    ['sunday', 7],
  ]);

  const results = [];
  for (const part of parts) {
    const key = part.toLowerCase().replace(/[^a-z]/g, '');
    if (!key) continue;
    const day = DAY_MAP.get(key) || dayAliases.get(key) || dayAliases.get(key.slice(0, 3));
    if (day) results.push(day);
  }
  return Array.from(new Set(results));
};

const loadStudentOverrides = () => {
  const overrides = new Map();
  if (!fs.existsSync(STUDENT_OVERRIDES_PATH)) {
    return overrides;
  }
  const raw = fs.readFileSync(STUDENT_OVERRIDES_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  Object.entries(parsed).forEach(([key, value]) => {
    const normalized = normalizeCode(key);
    if (!normalized || !value) return;
    overrides.set(normalized, normalizeCode(value));
  });
  return overrides;
};

const loadTeacherOverrides = () => {
  const overrides = new Map();
  if (!fs.existsSync(TEACHER_OVERRIDES_PATH)) {
    return overrides;
  }
  const raw = fs.readFileSync(TEACHER_OVERRIDES_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  Object.entries(parsed).forEach(([key, value]) => {
    const normalized = normalizeName(key);
    if (!normalized || !value) return;
    overrides.set(normalized, String(value));
  });
  return overrides;
};

const writeCsv = (filePath, headers, rows) => {
  const lines = [headers.join(',')];
  for (const row of rows) {
    const values = headers.map((key) => {
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

const loadConfirmedScheduleRows = async (filePath, studentOverrides) => {
  const rows = [];
  const blockMarkers = new Map();
  const mgcGroups = new Map();
  const workbook = new Excel.Workbook();
  const sheet = await workbook.csv.readFile(filePath);
  const headerRow = sheet.getRow(1).values;
  const headerMap = new Map();

  headerRow.forEach((value, index) => {
    if (!value || index === 0) return;
    headerMap.set(normalizeHeader(value), index);
  });

  const headerKey = (candidates) => {
    for (const candidate of candidates) {
      const idx = headerMap.get(candidate);
      if (idx) return idx;
    }
    return null;
  };

  const teacherIdx = headerKey(['teacher name']);
  const parentNameIdx = headerKey(['parent name']);
  const parentNumberIdx = headerKey(['parent number']);
  const studentIdx = headerKey(['student name']);
  const studentCodeIdx = headerKey(['student id (from the website)', 'student id']);
  const dayIdx = headerKey(['day']);
  const timeIdx = headerKey(['time']);
  const durationIdx = headerKey(['duration']);
  const programIdx = headerKey(['program']);
  const classTypeIdx = headerKey(['class type']);
  const confirmedIdx = headerKey(['confirmed']);

  if (!teacherIdx || !studentIdx || !studentCodeIdx || !dayIdx || !timeIdx || !confirmedIdx) {
    throw new Error(`Missing required headers in ${filePath}`);
  }

  let blockId = 0;
  let mgcGroupCounter = 0;
  let currentMgcGroupId = null;
  let current = {
    teacherName: '',
    parentName: '',
    parentNumber: '',
    studentName: '',
    studentCode: '',
    day: '',
    time: '',
    duration: '',
    program: '',
    classType: '',
  };

  for (let rowIndex = 2; rowIndex <= sheet.rowCount; rowIndex += 1) {
    const row = sheet.getRow(rowIndex);
    const teacherNameRaw = teacherIdx ? row.getCell(teacherIdx).text.trim() : '';
    const parentNameRaw = parentNameIdx ? row.getCell(parentNameIdx).text.trim() : '';
    const parentNumberRaw = parentNumberIdx ? row.getCell(parentNumberIdx).text.trim() : '';
    const studentNameRaw = studentIdx ? row.getCell(studentIdx).text.trim() : '';
    const studentCodeRaw = studentCodeIdx ? row.getCell(studentCodeIdx).text.trim() : '';
    const dayRaw = dayIdx ? row.getCell(dayIdx).text.trim() : '';
    const timeRaw = timeIdx ? row.getCell(timeIdx).text.trim() : '';
    const durationRaw = durationIdx ? row.getCell(durationIdx).text.trim() : '';
    const programRaw = programIdx ? row.getCell(programIdx).text.trim() : '';
    const classTypeRaw = classTypeIdx ? row.getCell(classTypeIdx).text.trim() : '';
    const confirmedRaw = confirmedIdx ? row.getCell(confirmedIdx).text.trim() : '';

    const rowHasValues = [
      teacherNameRaw,
      parentNameRaw,
      parentNumberRaw,
      studentNameRaw,
      studentCodeRaw,
      dayRaw,
      timeRaw,
      durationRaw,
      programRaw,
      classTypeRaw,
      confirmedRaw,
    ].some((value) => value && value.trim().length > 0);

    if (!rowHasValues) {
      continue;
    }

    if (teacherNameRaw) {
      blockId += 1;
      mgcGroupCounter = 0;
      currentMgcGroupId = null;
      current = {
        teacherName: teacherNameRaw,
        parentName: '',
        parentNumber: '',
        studentName: '',
        studentCode: '',
        day: '',
        time: '',
        duration: '',
        program: '',
        classType: '',
      };
    }
    if (!current.teacherName) {
      continue;
    }

    const previousParentName = current.parentName;
    const normalizedPreviousParent = normalizeParentName(previousParentName);
    const normalizedParentRaw = normalizeParentName(parentNameRaw);
    const parentChanged =
      parentNameRaw &&
      normalizedPreviousParent &&
      normalizedParentRaw &&
      normalizedParentRaw !== normalizedPreviousParent;

    if (classTypeRaw) {
      current.classType = classTypeRaw;
      if (isMgcValue(classTypeRaw)) {
        mgcGroupCounter += 1;
        currentMgcGroupId = `block-${blockId}-mgc-${mgcGroupCounter}`;
      } else {
        currentMgcGroupId = null;
      }
    } else if (parentChanged && normalizeClassType(current.classType) === 'fgc') {
      current.classType = '';
      currentMgcGroupId = null;
    }

    if (parentNameRaw) current.parentName = parentNameRaw;
    if (parentNumberRaw) current.parentNumber = parentNumberRaw;
    if (dayRaw) current.day = dayRaw;
    if (timeRaw) current.time = timeRaw;
    if (durationRaw) current.duration = durationRaw;
    if (programRaw) current.program = programRaw;

    if (studentNameRaw || studentCodeRaw) {
      current.studentName = studentNameRaw || '';
      current.studentCode = studentCodeRaw || '';
    }

    const teacherName = current.teacherName;
    const studentName = current.studentName;
    const studentCode = normalizeCode(current.studentCode);
    const dayValue = current.day;
    const timeValue = current.time;
    const durationValue = current.duration;
    const program = current.program;
    const classType = current.classType;
    const rowHasDayTime = Boolean(dayRaw || timeRaw);

    if (confirmedRaw) {
      const marker = blockMarkers.get(blockId) || {hasConfirmed: false, hasUnconfirmed: false};
      if (isConfirmedValue(confirmedRaw)) marker.hasConfirmed = true;
      if (isUnconfirmedValue(confirmedRaw)) marker.hasUnconfirmed = true;
      blockMarkers.set(blockId, marker);
    }

    const normalizedCode = normalizeCode(studentCode);
    const overrideCode = studentOverrides.get(normalizedCode) || normalizedCode;
    current.studentCode = overrideCode;

    const isMgc = isMgcValue(classType);
    if (isMgc && !currentMgcGroupId) {
      mgcGroupCounter += 1;
      currentMgcGroupId = `block-${blockId}-mgc-${mgcGroupCounter}`;
    }

    if (isMgc && currentMgcGroupId) {
      const group =
        mgcGroups.get(currentMgcGroupId) ||
        {
          blockId,
          teacherName,
          program,
          classType,
          students: new Map(),
          schedules: new Map(),
        };

      if (studentCode) {
        group.students.set(overrideCode, studentName || '');
      }

      if (rowHasDayTime && dayValue && timeValue) {
        const weekdays = parseWeekdays(dayValue);
        for (const weekday of weekdays) {
          const dayLabel = Array.from(DAY_MAP.entries()).find(([, v]) => v === weekday)?.[0] || dayValue;
          const key = `${weekday}|${timeValue}|${durationValue || ''}|${program || ''}`;
          if (!group.schedules.has(key)) {
            group.schedules.set(key, {
              day: dayLabel,
              weekday,
              time: timeValue,
              duration: durationValue,
              program,
              classType,
            });
          }
        }
      }

      mgcGroups.set(currentMgcGroupId, group);
      continue;
    }

    if (!teacherName || !studentCode || !dayValue || !timeValue || !rowHasDayTime) {
      continue;
    }

    const weekdays = parseWeekdays(dayValue);
    if (weekdays.length === 0) {
      continue;
    }

    for (const weekday of weekdays) {
      const dayLabel = Array.from(DAY_MAP.entries()).find(([, v]) => v === weekday)?.[0] || dayValue;
      rows.push({
        blockId,
        teacherName,
        studentName,
        studentCode: overrideCode,
        day: dayLabel,
        weekday,
        time: timeValue,
        duration: durationValue,
        program,
        classType,
        confirmed: confirmedRaw,
      });
    }
  }

  for (const group of mgcGroups.values()) {
    if (group.students.size === 0 || group.schedules.size === 0) {
      continue;
    }
    for (const schedule of group.schedules.values()) {
      for (const [code, name] of group.students.entries()) {
        rows.push({
          blockId: group.blockId,
          teacherName: group.teacherName,
          studentName: name,
          studentCode: code,
          day: schedule.day,
          weekday: schedule.weekday,
          time: schedule.time,
          duration: schedule.duration,
          program: schedule.program,
          classType: schedule.classType,
          confirmed: 'true',
        });
      }
    }
  }

  if (rows.length === 0) return rows;

  const confirmedBlocks = new Set();
  for (const [id, marker] of blockMarkers.entries()) {
    if (marker?.hasConfirmed) {
      confirmedBlocks.add(id);
    }
  }

  return rows.filter((row) => confirmedBlocks.has(row.blockId));
};

const buildTeacherMaps = (teachers) => {
  const byName = new Map();
  const byLastName = new Map();
  const byFirstName = new Map();
  const trackFirstKey = (key, teacher) => {
    if (!key) return;
    const existing = byFirstName.get(key);
    if (!existing) {
      byFirstName.set(key, teacher);
      return;
    }
    if (existing !== teacher) {
      byFirstName.set(key, null);
    }
  };

  for (const teacher of teachers) {
    const fullName = `${teacher.firstName} ${teacher.lastName}`.trim();
    const normalized = normalizeName(fullName);
    if (normalized) {
      byName.set(normalized, teacher);
    }

    const reversed = normalizeName(`${teacher.lastName} ${teacher.firstName}`);
    if (reversed) {
      byName.set(reversed, teacher);
    }

    const lastKey = normalizeName(teacher.lastName);
    if (lastKey) {
      const existing = byLastName.get(lastKey) || [];
      existing.push(teacher);
      byLastName.set(lastKey, existing);
    }

    const firstKey = normalizeName(teacher.firstName);
    trackFirstKey(firstKey, teacher);
    const firstToken = normalizeName((teacher.firstName || '').split(' ')[0]);
    if (firstToken && firstToken !== firstKey) {
      trackFirstKey(firstToken, teacher);
    }
  }

  return {byName, byLastName, byFirstName};
};

const pickTeacher = (teacherName, teacherMaps, teacherOverrides, teachersById) => {
  const normalized = normalizeName(teacherName);
  if (!normalized) return null;
  const overrideId = teacherOverrides.get(normalized);
  if (overrideId) {
    return teachersById.get(overrideId) || null;
  }
  const direct = teacherMaps.byName.get(normalized);
  if (direct) return direct;

  const tokens = normalized.split(' ').filter(Boolean);
  if (tokens.length >= 2) {
    const shortKey = `${tokens[0]} ${tokens[tokens.length - 1]}`;
    const shortMatch = teacherMaps.byName.get(shortKey);
    if (shortMatch) return shortMatch;
  }

  const lastToken = tokens[tokens.length - 1];
  if (lastToken) {
    const candidates = teacherMaps.byLastName.get(lastToken);
    if (candidates && candidates.length === 1) {
      return candidates[0];
    }
  }

  if (tokens.length === 1) {
    const candidate = teacherMaps.byFirstName.get(tokens[0]);
    if (candidate) return candidate;
  }

  return null;
};

const nextOccurrence = (weekday, hour, minute, zone) => {
  const now = DateTime.now().setZone(zone);
  const deltaDays = (weekday - now.weekday + 7) % 7;
  let candidate = now.plus({days: deltaDays}).set({
    hour,
    minute,
    second: 0,
    millisecond: 0,
  });
  if (candidate <= now) {
    candidate = candidate.plus({days: 7});
  }
  return candidate;
};

const findTemplateForGroup = (group, templatesByTeacher) => {
  const templates = templatesByTeacher.get(group.teacherId) || [];
  const studentKey = [...group.studentIds].sort().join(',');
  const candidates = templates.filter((tpl) => {
    if (tpl.studentKey !== studentKey) return false;
    if (!tpl.weekdays.includes(group.weekday)) return false;
    return true;
  });

  if (candidates.length === 0) return {template: null, ambiguous: false};
  if (candidates.length === 1) return {template: candidates[0], ambiguous: false};

  const exact = candidates.find(
    (tpl) => tpl.startTime === group.startTime && tpl.endTime === group.endTime,
  );
  if (exact) return {template: exact, ambiguous: false};

  return {template: null, ambiguous: true, candidates};
};

const isTruthy = (value) =>
  value === true ||
  value === 1 ||
  value === '1' ||
  (typeof value === 'string' && value.toLowerCase() === 'true');

const main = async () => {
  if (!admin.apps.length) {
    admin.initializeApp({projectId: PROJECT_ID});
  }
  const db = admin.firestore();

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Mode: ${APPLY ? 'APPLY' : 'AUDIT ONLY'}`);

  if (!fs.existsSync(SCHEDULE_FILE)) {
    throw new Error(`Schedule file not found: ${SCHEDULE_FILE}`);
  }

  const studentOverrides = loadStudentOverrides();
  const teacherOverrides = loadTeacherOverrides();
  const scheduleRows = await loadConfirmedScheduleRows(SCHEDULE_FILE, studentOverrides);

  console.log(`Confirmed schedule rows: ${scheduleRows.length}`);
  if (scheduleRows.length === 0) {
    return;
  }

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const confirmedRowsPath = path.join(OUTPUT_DIR, `prod_confirmed_salima_rows_${timestamp}.csv`);
  writeCsv(
    confirmedRowsPath,
    ['teacher_name', 'student_name', 'student_code', 'weekday', 'time', 'duration', 'program', 'class_type'],
    scheduleRows.map((row) => ({
      teacher_name: row.teacherName,
      student_name: row.studentName,
      student_code: row.studentCode,
      weekday: row.weekday,
      time: row.time,
      duration: row.duration,
      program: row.program,
      class_type: row.classType,
    })),
  );
  console.log(`Confirmed rows report: ${confirmedRowsPath}`);

  const teachersSnap = await db.collection('users').where('user_type', '==', 'teacher').get();
  const teachers = teachersSnap.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      uid: doc.id,
      firstName: data.first_name || '',
      lastName: data.last_name || '',
      timezone: data.timezone || data.time_zone || data.admin_timezone || ADMIN_TIMEZONE,
    };
  });
  const teachersById = new Map(teachers.map((teacher) => [teacher.uid, teacher]));
  const teacherMaps = buildTeacherMaps(teachers);

  const students = [];
  try {
    const snap = await db.collection('users').where('user_type', 'in', ['student', 'Student']).get();
    snap.docs.forEach((doc) => {
      const data = doc.data() || {};
      const code = normalizeCode(data.student_code || data.studentCode || data.student_id);
      if (!code) return;
      students.push({
        uid: doc.id,
        studentCode: code,
        firstName: data.first_name || '',
        lastName: data.last_name || '',
      });
    });
  } catch (err) {
    const snapA = await db.collection('users').where('user_type', '==', 'student').get();
    const snapB = await db.collection('users').where('user_type', '==', 'Student').get();
    [snapA, snapB].forEach((snap) => {
      snap.docs.forEach((doc) => {
        const data = doc.data() || {};
        const code = normalizeCode(data.student_code || data.studentCode || data.student_id);
        if (!code) return;
        students.push({
          uid: doc.id,
          studentCode: code,
          firstName: data.first_name || '',
          lastName: data.last_name || '',
        });
      });
    });
  }
  const studentsByCode = new Map(students.map((student) => [student.studentCode, student]));

  const missingTeachers = new Set();
  const missingStudents = new Set();
  const grouped = new Map();
  const teacherIds = new Set();

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

    const weekday = Number.isInteger(row.weekday) ? row.weekday : DAY_MAP.get(normalizeName(row.day));
    if (!weekday) continue;

    const timeRange = parseTimeRange(row.time);
    if (!timeRange) continue;

    const computedDuration = (() => {
      const startMinutes = timeRange.startHour * 60 + timeRange.startMinute;
      const endMinutes = timeRange.endHour * 60 + timeRange.endMinute;
      const delta = endMinutes - startMinutes;
      return delta > 0 ? delta : delta + 24 * 60;
    })();
    const parsedDuration = parseDurationMinutes(row.duration);
    const durationMinutes = Number.isFinite(computedDuration) ? computedDuration : parsedDuration;
    if (!durationMinutes) continue;

    const programKey = normalizeSubjectKey(row.program);
    const classTypeKey = normalizeSubjectKey(row.classType);

    const groupKey = [
      teacher.uid,
      weekday,
      timeRange.startTime,
      timeRange.endTime,
      programKey,
      classTypeKey,
    ].join('|');

    const group = grouped.get(groupKey) || {
      teacherId: teacher.uid,
      teacherName: `${teacher.firstName} ${teacher.lastName}`.trim(),
      teacherTimezone: teacher.timezone || ADMIN_TIMEZONE,
      weekday,
      startTime: timeRange.startTime,
      endTime: timeRange.endTime,
      durationMinutes,
      program: row.program,
      classType: row.classType,
      studentIds: [],
      studentNames: [],
    };

    if (!group.studentIds.includes(student.uid)) {
      group.studentIds.push(student.uid);
      const studentName = `${student.firstName} ${student.lastName}`.trim() || row.studentName;
      group.studentNames.push(studentName);
    }

    grouped.set(groupKey, group);
    teacherIds.add(teacher.uid);
  }

  if (missingTeachers.size > 0 || missingStudents.size > 0) {
    console.log(`Missing teachers: ${missingTeachers.size}`);
    if (missingTeachers.size > 0) {
      console.log(Array.from(missingTeachers).join(', '));
    }
    console.log(`Missing students: ${missingStudents.size}`);
    if (missingStudents.size > 0) {
      console.log(Array.from(missingStudents).join(', '));
    }
    if (APPLY) {
      throw new Error('Aborting apply mode due to missing schedule mappings.');
    }
  }

  const subjectsSnap = await db.collection('subjects').get();
  const subjects = subjectsSnap.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  const subjectByKey = new Map();
  for (const subject of subjects) {
    const nameKey = normalizeSubjectKey(subject.name);
    const displayKey = normalizeSubjectKey(subject.displayName || subject.display_name);
    if (nameKey) subjectByKey.set(nameKey, subject);
    if (displayKey) subjectByKey.set(displayKey, subject);
  }

  const teacherDefaults = new Map();
  for (const teacherId of teacherIds) {
    let snapshot = null;
    try {
      snapshot = await db
        .collection('teaching_shifts')
        .where('teacher_id', '==', teacherId)
        .orderBy('shift_start', 'desc')
        .limit(1)
        .get();
    } catch (err) {
      const fallback = await db.collection('teaching_shifts').where('teacher_id', '==', teacherId).limit(1).get();
      snapshot = fallback;
    }
    if (snapshot && !snapshot.empty) {
      const data = snapshot.docs[0].data() || {};
      teacherDefaults.set(teacherId, {
        subjectId: data.subject_id || null,
        subjectDisplayName: data.subject_display_name || null,
        subjectLegacy: data.subject || 'other',
        hourlyRate: data.hourly_rate ?? null,
        category: data.shift_category || data.category || 'teaching',
        leaderRole: data.leader_role || null,
        videoProvider: (data.video_provider || 'zoom').toString().trim().toLowerCase(),
      });
    }
  }

  const templatesSnap = await db.collection('shift_templates').get();
  const templatesByTeacher = new Map();
  templatesSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const teacherId = data.teacher_id;
    if (!teacherIds.has(teacherId)) return;
    const studentIds = Array.isArray(data.student_ids) ? data.student_ids : [];
    const studentKey = [...studentIds].sort().join(',');
    const weekdays = Array.isArray(data.enhanced_recurrence?.selectedWeekdays)
      ? data.enhanced_recurrence.selectedWeekdays
      : [];
    const entry = {
      id: doc.id,
      data,
      studentIds,
      studentKey,
      weekdays,
      startTime: data.start_time || '',
      endTime: data.end_time || '',
    };
    const existing = templatesByTeacher.get(teacherId) || [];
    existing.push(entry);
    templatesByTeacher.set(teacherId, existing);
  });

  const migrationAdmin = await db.collection('users').where('user_type', '==', 'admin').limit(1).get();
  const adminId = migrationAdmin.empty ? null : migrationAdmin.docs[0].id;

  const templatesToUpsert = [];
  const ambiguousMatches = [];

  for (const group of grouped.values()) {
    const {template, ambiguous, candidates} = findTemplateForGroup(group, templatesByTeacher);
    if (ambiguous) {
      ambiguousMatches.push({
        teacherName: group.teacherName,
        studentNames: group.studentNames.join('|'),
        weekday: group.weekday,
        startTime: group.startTime,
        endTime: group.endTime,
        candidateIds: candidates.map((candidate) => candidate.id).join('|'),
      });
    }

    const targetTemplate = template || null;
    const templateId = targetTemplate
      ? targetTemplate.id
      : `tpl_${crypto
          .createHash('sha1')
          .update(
            [
              group.teacherId,
              group.weekday,
              group.startTime,
              group.endTime,
              normalizeSubjectKey(group.program),
              normalizeSubjectKey(group.classType),
              [...group.studentIds].sort().join(','),
            ].join('|'),
          )
          .digest('hex')
          .slice(0, 16)}`;

    const subjectCandidate =
      subjectByKey.get(normalizeSubjectKey(group.program)) ||
      subjectByKey.get(normalizeSubjectKey(group.classType));

    const teacherDefault = teacherDefaults.get(group.teacherId) || {};
    const existingData = targetTemplate?.data || {};
    const subjectId = subjectCandidate?.id || existingData.subject_id || teacherDefault.subjectId || null;
    const subjectDisplayName =
      subjectCandidate?.displayName ||
      subjectCandidate?.display_name ||
      existingData.subject_display_name ||
      teacherDefault.subjectDisplayName ||
      group.program ||
      group.classType ||
      null;
    const subjectLegacy = subjectCandidate
      ? mapSubjectToLegacy(subjectCandidate.name || subjectCandidate.displayName)
      : existingData.subject || teacherDefault.subjectLegacy || mapSubjectToLegacy(subjectDisplayName);

    const hourlyRate =
      teacherDefault.hourlyRate ?? (existingData.hourly_rate !== undefined ? existingData.hourly_rate : null);
    const category =
      teacherDefault.category || existingData.shift_category || existingData.category || 'teaching';
    const leaderRole = teacherDefault.leaderRole || existingData.leader_role || null;
    const videoProvider =
      teacherDefault.videoProvider || (existingData.video_provider || 'zoom').toString().trim().toLowerCase();

    const now = DateTime.now().setZone(ADMIN_TIMEZONE);
    const baseStart = nextOccurrence(
      group.weekday,
      Number(group.startTime.split(':')[0]),
      Number(group.startTime.split(':')[1]),
      ADMIN_TIMEZONE,
    );
    const baseEnd = baseStart.plus({minutes: group.durationMinutes});
    const endDate = now.plus({days: 365});

    const subjectLabel = subjectDisplayName || 'Class';
    const studentLabel = group.studentNames.join(', ');
    const autoGeneratedName = `${group.teacherName} - ${subjectLabel} - ${studentLabel}`;
    const notes = [group.program, group.classType].filter(Boolean).join(' / ') || existingData.notes || null;

    const templateDoc = {
      teacher_id: group.teacherId,
      teacher_name: group.teacherName,
      student_ids: group.studentIds,
      student_names: group.studentNames,
      start_time: group.startTime,
      end_time: group.endTime,
      duration_minutes: group.durationMinutes,
      admin_timezone: ADMIN_TIMEZONE,
      teacher_timezone: group.teacherTimezone,
      enhanced_recurrence: {
        type: 'weekly',
        endDate: admin.firestore.Timestamp.fromDate(endDate.toJSDate()),
        excludedDates: [],
        excludedWeekdays: [],
        selectedWeekdays: [group.weekday],
        selectedMonthDays: [],
        selectedMonths: [],
      },
      recurrence: 'weekly',
      recurrence_series_id: templateId,
      recurrence_end_date: admin.firestore.Timestamp.fromDate(endDate.toJSDate()),
      recurrence_settings: null,
      subject: subjectLegacy,
      subject_id: subjectId,
      subject_display_name: subjectDisplayName,
      hourly_rate: hourlyRate,
      auto_generated_name: autoGeneratedName,
      custom_name: null,
      notes,
      category,
      leader_role: leaderRole,
      video_provider: videoProvider,
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
      is_active: true,
      last_generated_date: null,
      max_days_ahead: MAX_DAYS_AHEAD,
      base_shift_id: templateId,
      base_shift_start: admin.firestore.Timestamp.fromDate(baseStart.toJSDate()),
      base_shift_end: admin.firestore.Timestamp.fromDate(baseEnd.toJSDate()),
    };

    if (!targetTemplate) {
      templateDoc.created_by_admin_id = adminId;
      templateDoc.created_at = admin.firestore.FieldValue.serverTimestamp();
      templateDoc.series_created_at = admin.firestore.Timestamp.fromDate(now.toJSDate());
    }

    templatesToUpsert.push({templateId, templateDoc});
  }

  if (ambiguousMatches.length > 0) {
    const ambiguousPath = path.join(OUTPUT_DIR, `prod_confirmed_salima_ambiguous_${timestamp}.csv`);
    writeCsv(
      ambiguousPath,
      ['teacher_name', 'student_names', 'weekday', 'start_time', 'end_time', 'candidate_ids'],
      ambiguousMatches.map((match) => ({
        teacher_name: match.teacherName,
        student_names: match.studentNames,
        weekday: match.weekday,
        start_time: match.startTime,
        end_time: match.endTime,
        candidate_ids: match.candidateIds,
      })),
    );
    console.log(`Ambiguous template matches: ${ambiguousMatches.length}`);
    console.log(`Ambiguous report: ${ambiguousPath}`);
  }

  console.log(`Templates to upsert: ${templatesToUpsert.length}`);
  if (!APPLY) return;

  const desiredTemplateIds = new Set(templatesToUpsert.map((template) => template.templateId));
  const confirmedTeacherIds = new Set(templatesToUpsert.map((template) => template.templateDoc.teacher_id));

  let batch = db.batch();
  let opCount = 0;
  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  for (const template of templatesToUpsert) {
    batch.set(db.collection('shift_templates').doc(template.templateId), template.templateDoc, {merge: true});
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }
  await flush();

  let deactivatedTemplates = 0;
  let deletedLegacyShifts = 0;

  for (const teacherId of confirmedTeacherIds) {
    const templatesSnap = await db.collection('shift_templates').where('teacher_id', '==', teacherId).get();
    for (const doc of templatesSnap.docs) {
      if (desiredTemplateIds.has(doc.id)) continue;

      batch.set(
        doc.ref,
        {
          is_active: false,
          last_modified: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      opCount += 1;
      deactivatedTemplates += 1;
      if (opCount >= 450) {
        await flush();
      }

      const shiftsSnap = await db
        .collection('teaching_shifts')
        .where('template_id', '==', doc.id)
        .where('status', 'in', ['scheduled', 'pending'])
        .get();
      let deleteBatch = db.batch();
      let deleteOps = 0;
      for (const shiftDoc of shiftsSnap.docs) {
        const data = shiftDoc.data() || {};
        if (!isTruthy(data.generated_from_template)) continue;
        deleteBatch.delete(shiftDoc.ref);
        deleteOps += 1;
        deletedLegacyShifts += 1;
        if (deleteOps >= 450) {
          await deleteBatch.commit();
          deleteBatch = db.batch();
          deleteOps = 0;
        }
      }
      if (deleteOps > 0) {
        await deleteBatch.commit();
      }
    }
  }

  await flush();

  const shiftTemplateHandlers = require('../handlers/shift_templates');
  const templateIds = templatesToUpsert.map((template) => template.templateId);
  let deleted = 0;
  let generated = 0;

  for (const templateId of templateIds) {
    const shiftsSnap = await db
      .collection('teaching_shifts')
      .where('template_id', '==', templateId)
      .where('status', 'in', ['scheduled', 'pending'])
      .get();

    let deleteBatch = db.batch();
    let deleteOps = 0;
    for (const doc of shiftsSnap.docs) {
      const data = doc.data() || {};
      if (!isTruthy(data.generated_from_template)) continue;
      deleteBatch.delete(doc.ref);
      deleteOps += 1;
      deleted += 1;
      if (deleteOps >= 450) {
        await deleteBatch.commit();
        deleteBatch = db.batch();
        deleteOps = 0;
      }
    }
    if (deleteOps > 0) {
      await deleteBatch.commit();
    }

    const doc = await db.collection('shift_templates').doc(templateId).get();
    if (!doc.exists) continue;
    const result = await shiftTemplateHandlers._generateShiftsForTemplate({
      templateId,
      template: doc.data() || {},
    });
    generated += result.created || 0;
  }

  console.log(`Deactivated templates: ${deactivatedTemplates}`);
  console.log(`Deleted shifts from deactivated templates: ${deletedLegacyShifts}`);
  console.log(`Deleted generated shifts: ${deleted}`);
  console.log(`Generated shifts: ${generated}`);
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
