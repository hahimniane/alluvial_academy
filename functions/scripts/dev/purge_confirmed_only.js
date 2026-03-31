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

const toIso = (value) => {
  if (!value) return '';
  if (typeof value.toDate === 'function') {
    const dt = value.toDate();
    return dt ? dt.toISOString() : '';
  }
  if (value instanceof Date) return value.toISOString();
  return '';
};

const parseTimeToMinutes = (value) => {
  if (!value) return null;
  const [hourRaw, minuteRaw] = value.split(':');
  const hour = Number(hourRaw);
  const minute = Number(minuteRaw ?? '0');
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  return hour * 60 + minute;
};

const formatMinutes = (value) => {
  const minutes = ((value % (24 * 60)) + 24 * 60) % (24 * 60);
  const hour = Math.floor(minutes / 60);
  const minute = minutes % 60;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
};

const computeTemplateKeys = (template) => {
  const weekdays = Array.isArray(template.weekdays) ? template.weekdays : [];
  if (weekdays.length === 0) return [];
  const studentIds = template.studentIds;
  if (!studentIds || studentIds.length === 0) return [];
  const startTime = template.startTime;
  let endTime = template.endTime;
  if (!startTime) return [];
  if (!endTime) {
    const startMinutes = parseTimeToMinutes(startTime);
    if (startMinutes === null || !Number.isFinite(template.durationMinutes) || template.durationMinutes <= 0) {
      return [];
    }
    endTime = formatMinutes(startMinutes + template.durationMinutes);
  }
  const studentKey = studentIds.slice().sort().join(',');
  return weekdays.map((weekday) =>
    `${template.teacherId}|${weekday}|${startTime}|${endTime}|${studentKey}`,
  );
};

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
    throw new Error('No confirmed schedule rows found. Aborting.');
  }

  const teachersSnap = await db.collection('users').where('user_type', '==', 'teacher').get();
  const teachers = teachersSnap.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      uid: doc.id,
      firstName: data.first_name || '',
      lastName: data.last_name || '',
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

  const grouped = new Map();
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
      weekday,
      startTime: timeRange.startTime,
      endTime: timeRange.endTime,
      durationMinutes,
      programKey,
      classTypeKey,
      studentIds: [],
    };

    if (!group.studentIds.includes(student.uid)) {
      group.studentIds.push(student.uid);
    }

    grouped.set(groupKey, group);
  }

  if (missingTeachers.size > 0) {
    console.log(`Missing teachers (not found): ${Array.from(missingTeachers).join(' | ')}`);
  }
  if (missingStudents.size > 0) {
    console.log(`Missing students (not found): ${Array.from(missingStudents).join(' | ')}`);
  }

  const desiredGroupKeys = new Set();
  const canonicalByKey = new Map();

  for (const group of grouped.values()) {
    const studentKey = group.studentIds.slice().sort().join(',');
    const simpleKey = `${group.teacherId}|${group.weekday}|${group.startTime}|${group.endTime}|${studentKey}`;
    desiredGroupKeys.add(simpleKey);

    const canonicalId = `tpl_${crypto
      .createHash('sha1')
      .update(
        [
          group.teacherId,
          group.weekday,
          group.startTime,
          group.endTime,
          group.programKey,
          group.classTypeKey,
          studentKey,
        ].join('|'),
      )
      .digest('hex')
      .slice(0, 16)}`;
    canonicalByKey.set(simpleKey, canonicalId);
  }

  const templatesSnap = await db.collection('shift_templates').get();
  const templateCandidatesByKey = new Map();
  const templateMeta = new Map();
  const templatesToDelete = [];

  templatesSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const template = {
      id: doc.id,
      teacherId: data.teacher_id || '',
      teacherName: data.teacher_name || '',
      studentIds: Array.isArray(data.student_ids) ? data.student_ids.map(String) : [],
      studentNames: Array.isArray(data.student_names) ? data.student_names.map(String) : [],
      weekdays: Array.isArray(data.enhanced_recurrence?.selectedWeekdays)
        ? data.enhanced_recurrence.selectedWeekdays
        : [],
      startTime: data.start_time || '',
      endTime: data.end_time || '',
      durationMinutes: Number(data.duration_minutes || 0),
      active: data.active === false ? 'false' : 'true',
      lastModified: data.last_modified || data.created_at || null,
    };

    const keys = computeTemplateKeys(template);
    if (keys.length === 0) {
      templatesToDelete.push({
        template_id: template.id,
        reason: 'missing_key_fields',
        teacher_name: template.teacherName,
        student_names: template.studentNames.join('|'),
        weekdays: template.weekdays.join('|'),
        start_time: template.startTime,
        end_time: template.endTime,
        duration_minutes: template.durationMinutes || '',
        active: template.active,
        last_modified: toIso(template.lastModified),
      });
      return;
    }

    const allKeysInDesired = keys.every((key) => desiredGroupKeys.has(key));
    if (!allKeysInDesired) {
      templatesToDelete.push({
        template_id: template.id,
        reason: 'not_in_confirmed_schedule',
        teacher_name: template.teacherName,
        student_names: template.studentNames.join('|'),
        weekdays: template.weekdays.join('|'),
        start_time: template.startTime,
        end_time: template.endTime,
        duration_minutes: template.durationMinutes || '',
        active: template.active,
        last_modified: toIso(template.lastModified),
      });
      return;
    }

    const lastModifiedMs = template.lastModified
      ? template.lastModified.toDate
        ? template.lastModified.toDate().getTime()
        : template.lastModified instanceof Date
          ? template.lastModified.getTime()
          : Date.parse(template.lastModified)
      : 0;

    templateMeta.set(template.id, {
      keys,
      lastModifiedMs: Number.isFinite(lastModifiedMs) ? lastModifiedMs : 0,
    });

    keys.forEach((key) => {
      if (!templateCandidatesByKey.has(key)) {
        templateCandidatesByKey.set(key, []);
      }
      templateCandidatesByKey.get(key).push(template.id);
    });
  });

  const keepTemplateIds = new Set();
  for (const [key, candidates] of templateCandidatesByKey.entries()) {
    const canonicalId = canonicalByKey.get(key);
    if (canonicalId && candidates.includes(canonicalId)) {
      keepTemplateIds.add(canonicalId);
      continue;
    }

    let bestId = candidates[0];
    let bestMs = templateMeta.get(bestId)?.lastModifiedMs ?? 0;
    for (const candidateId of candidates) {
      const ms = templateMeta.get(candidateId)?.lastModifiedMs ?? 0;
      if (ms > bestMs) {
        bestMs = ms;
        bestId = candidateId;
      }
    }
    keepTemplateIds.add(bestId);
  }

  for (const [templateId, meta] of templateMeta.entries()) {
    if (keepTemplateIds.has(templateId)) continue;
    const templateDoc = templatesSnap.docs.find((doc) => doc.id === templateId);
    const data = templateDoc?.data() || {};
    templatesToDelete.push({
      template_id: templateId,
      reason: 'duplicate_template',
      teacher_name: data.teacher_name || '',
      student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
      weekdays: Array.isArray(data.enhanced_recurrence?.selectedWeekdays)
        ? data.enhanced_recurrence.selectedWeekdays.join('|')
        : '',
      start_time: data.start_time || '',
      end_time: data.end_time || '',
      duration_minutes: data.duration_minutes || '',
      active: data.active === false ? 'false' : 'true',
      last_modified: toIso(data.last_modified || data.created_at),
    });
  }

  const shiftsSnap = await db.collection('teaching_shifts').get();
  const shiftsToDelete = [];

  shiftsSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const teacherId = data.teacher_id || '';
    const studentIds = Array.isArray(data.student_ids) ? data.student_ids.map(String) : [];
    const templateId = data.template_id || '';
    const shiftStart = data.shift_start;
    const shiftEnd = data.shift_end;
    if (!teacherId || studentIds.length === 0 || !shiftStart || !shiftEnd) {
      shiftsToDelete.push({
        shift_id: doc.id,
        reason: 'missing_key_fields',
        status: data.status || '',
        shift_start: toIso(shiftStart),
        shift_end: toIso(shiftEnd),
        teacher_name: data.teacher_name || '',
        student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
        template_id: templateId,
      });
      return;
    }

    if (templateId && keepTemplateIds.has(templateId)) {
      return;
    }

    const zone = data.admin_timezone || ADMIN_TIMEZONE;
    const startLocal = DateTime.fromJSDate(shiftStart.toDate(), {zone});
    const endLocal = DateTime.fromJSDate(shiftEnd.toDate(), {zone});
    const weekday = startLocal.weekday;
    const startTime = startLocal.toFormat('HH:mm');
    const endTime = endLocal.toFormat('HH:mm');
    const studentKey = studentIds.slice().sort().join(',');
    const simpleKey = `${teacherId}|${weekday}|${startTime}|${endTime}|${studentKey}`;

    if (desiredGroupKeys.has(simpleKey)) {
      return;
    }

    shiftsToDelete.push({
      shift_id: doc.id,
      reason: 'not_in_confirmed_schedule',
      status: data.status || '',
      shift_start: toIso(shiftStart),
      shift_end: toIso(shiftEnd),
      teacher_name: data.teacher_name || '',
      student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
      template_id: templateId,
    });
  });

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const templateSnapshotPath = path.join(OUTPUT_DIR, `prod_salima_templates_delete_${timestamp}.csv`);
  const shiftSnapshotPath = path.join(OUTPUT_DIR, `prod_salima_shifts_delete_${timestamp}.csv`);

  writeCsv(
    templateSnapshotPath,
    [
      'template_id',
      'reason',
      'teacher_name',
      'student_names',
      'weekdays',
      'start_time',
      'end_time',
      'duration_minutes',
      'active',
      'last_modified',
    ],
    templatesToDelete,
  );

  writeCsv(
    shiftSnapshotPath,
    ['shift_id', 'reason', 'status', 'shift_start', 'shift_end', 'teacher_name', 'student_names', 'template_id'],
    shiftsToDelete,
  );

  console.log(`Templates to delete: ${templatesToDelete.length}`);
  console.log(`Shifts to delete: ${shiftsToDelete.length}`);
  console.log(`Template snapshot: ${templateSnapshotPath}`);
  console.log(`Shift snapshot: ${shiftSnapshotPath}`);

  if (!APPLY) return;

  let batch = db.batch();
  let opCount = 0;
  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  for (const row of shiftsToDelete) {
    batch.delete(db.collection('teaching_shifts').doc(row.shift_id));
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }
  await flush();

  batch = db.batch();
  opCount = 0;
  for (const row of templatesToDelete) {
    batch.delete(db.collection('shift_templates').doc(row.template_id));
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }
  await flush();

  console.log('Deletion complete.');
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
