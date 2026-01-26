#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const DAYS_BACK = Number(process.env.DAYS_BACK || 30);
const DAYS_AHEAD = Number(process.env.DAYS_AHEAD || 90);
const APPLY = process.argv.includes('--apply');

const STATUS_ALIASES = new Map([
  ['inprogress', 'in_progress'],
  ['in-progress', 'in_progress'],
  ['partiallycompleted', 'partiallycompleted'],
  ['fullycompleted', 'fullycompleted'],
]);

const normalizeStatus = (value) => {
  const raw = (value || '').toString().trim().toLowerCase();
  return STATUS_ALIASES.get(raw) || raw;
};

const writeCsv = (filePath, headers, rows) => {
  const escapeCell = (value) => {
    if (value === null || value === undefined) return '';
    const raw = String(value);
    if (raw.includes('"')) return `"${raw.replace(/"/g, '""')}"`;
    if (/[,\n]/.test(raw)) return `"${raw}"`;
    return raw;
  };

  const lines = [headers.join(',')];
  rows.forEach((row) => {
    lines.push(headers.map((header) => escapeCell(row[header])).join(','));
  });
  fs.writeFileSync(filePath, `${lines.join('\n')}\n`, 'utf8');
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

const toMillis = (value) => {
  if (!value) return null;
  if (typeof value.toDate === 'function') {
    const dt = value.toDate();
    return dt ? dt.getTime() : null;
  }
  if (value instanceof Date) return value.getTime();
  return null;
};

const rangesOverlap = (aStart, aEnd, bStart, bEnd) => aStart < bEnd && aEnd > bStart;

const parseTimeToMinutes = (value) => {
  if (!value) return null;
  const [hourRaw, minuteRaw] = value.split(':');
  const hour = Number(hourRaw);
  const minute = Number(minuteRaw ?? '0');
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  return hour * 60 + minute;
};

const main = async () => {
  if (!admin.apps.length) {
    admin.initializeApp({projectId: PROJECT_ID});
  }
  const db = admin.firestore();

  const nowUtc = DateTime.utc();
  const rangeStart = nowUtc.minus({days: DAYS_BACK}).toJSDate();
  const rangeEnd = nowUtc.plus({days: DAYS_AHEAD}).toJSDate();

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Window: ${rangeStart.toISOString()} -> ${rangeEnd.toISOString()}`);
  console.log(`Mode: ${APPLY ? 'APPLY' : 'AUDIT ONLY'}`);

  const shiftsSnap = await db
    .collection('teaching_shifts')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(rangeStart))
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(rangeEnd))
    .get();

  const shifts = shiftsSnap.docs.map((doc) => {
    const data = doc.data() || {};
    const studentIds = Array.isArray(data.student_ids) ? data.student_ids.map(String) : [];
    const studentNames = Array.isArray(data.student_names) ? data.student_names.map(String) : [];
    return {
      id: doc.id,
      status: normalizeStatus(data.status),
      shiftStartMs: toMillis(data.shift_start),
      shiftEndMs: toMillis(data.shift_end),
      shift_start: toIso(data.shift_start),
      shift_end: toIso(data.shift_end),
      teacher_id: data.teacher_id || '',
      teacher_name: data.teacher_name || '',
      admin_timezone: data.admin_timezone || '',
      teacher_timezone: data.teacher_timezone || '',
      student_ids: studentIds,
      student_names: studentNames,
      template_id: data.template_id || '',
      generated_from_template: data.generated_from_template === true,
    };
  }).filter((shift) => shift.shiftStartMs && shift.shiftEndMs);

  const templatesSnap = await db.collection('shift_templates').get();
  const groupTemplateIndex = new Map();
  templatesSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    if (data.active === false) return;
    const studentIds = Array.isArray(data.student_ids) ? data.student_ids : [];
    if (studentIds.length <= 1) return;
    const weekdays = Array.isArray(data.enhanced_recurrence?.selectedWeekdays)
      ? data.enhanced_recurrence.selectedWeekdays
      : [];
    const startTime = data.start_time || '';
    const endTime = data.end_time || '';
    const durationMinutes = Number(data.duration_minutes || 0);
    if (!startTime || weekdays.length === 0) return;

    const startMinutes = parseTimeToMinutes(startTime);
    const endMinutes =
      parseTimeToMinutes(endTime) ??
      (Number.isFinite(durationMinutes) && durationMinutes > 0 && startMinutes !== null
        ? startMinutes + durationMinutes
        : null);
    if (startMinutes === null || endMinutes === null) return;

    studentIds.forEach((studentId) => {
      weekdays.forEach((weekday) => {
        const key = `${studentId}|${weekday}`;
        if (!groupTemplateIndex.has(key)) {
          groupTemplateIndex.set(key, []);
        }
        groupTemplateIndex.get(key).push({
          template_id: doc.id,
          teacher_name: data.teacher_name || '',
          student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
          startTime,
          endTime,
          startMinutes,
          endMinutes,
        });
      });
    });
  });

  const userShifts = new Map();
  const addUserShift = (userId, shift) => {
    if (!userId) return;
    const list = userShifts.get(userId) || [];
    list.push(shift);
    userShifts.set(userId, list);
  };

  shifts.forEach((shift) => {
    shift.student_ids.forEach((studentId) => addUserShift(studentId, shift));
  });

  const deleteCandidates = new Map();
  const templateCandidates = new Map();
  const conflictRows = [];

  for (const [studentId, studentShifts] of userShifts.entries()) {
    if (studentShifts.length < 2) continue;

    studentShifts.sort((a, b) => a.shiftStartMs - b.shiftStartMs);

    for (let i = 0; i < studentShifts.length; i += 1) {
      const a = studentShifts[i];
      if (a.student_ids.length !== 1) continue;

      for (let j = 0; j < studentShifts.length; j += 1) {
        if (i === j) continue;
        const b = studentShifts[j];
        if (b.student_ids.length <= 1) continue;
        if (!rangesOverlap(a.shiftStartMs, a.shiftEndMs, b.shiftStartMs, b.shiftEndMs)) continue;

        const key = a.id;
        if (!deleteCandidates.has(key)) {
          deleteCandidates.set(key, a);
        }
        if (a.generated_from_template && a.template_id) {
          templateCandidates.set(a.template_id, a);
        }

        conflictRows.push({
          conflict_type: 'shift_overlap',
          student_id: studentId,
          single_shift_id: a.id,
          group_shift_id: b.id,
          single_status: a.status,
          group_status: b.status,
          single_shift_start: a.shift_start,
          single_shift_end: a.shift_end,
          group_shift_start: b.shift_start,
          group_shift_end: b.shift_end,
          single_teacher: a.teacher_name,
          group_teacher: b.teacher_name,
          group_student_names: b.student_names.join('|'),
          single_template_id: a.template_id,
          single_generated_from_template: a.generated_from_template ? 'true' : 'false',
        });
      }
    }

    if (groupTemplateIndex.size === 0) {
      continue;
    }

    for (const singleShift of studentShifts.filter((shift) => shift.student_ids.length === 1)) {
      const adminTimezone = singleShift.admin_timezone || singleShift.teacher_timezone || 'UTC';
      const start = DateTime.fromMillis(singleShift.shiftStartMs, {zone: adminTimezone});
      const end = DateTime.fromMillis(singleShift.shiftEndMs, {zone: adminTimezone});
      const startMinutes = start.hour * 60 + start.minute;
      const endMinutes = end.hour * 60 + end.minute;
      const shiftStart = startMinutes;
      const shiftEnd = endMinutes < startMinutes ? endMinutes + 24 * 60 : endMinutes;

      const key = `${studentId}|${start.weekday}`;
      const candidates = groupTemplateIndex.get(key);
      if (!candidates) continue;

      const matches = candidates.filter((template) => {
        const templateEnd =
          template.endMinutes < template.startMinutes ? template.endMinutes + 24 * 60 : template.endMinutes;
        return rangesOverlap(shiftStart, shiftEnd, template.startMinutes, templateEnd);
      });
      if (!matches || matches.length === 0) continue;

      if (!deleteCandidates.has(singleShift.id)) {
        deleteCandidates.set(singleShift.id, singleShift);
      }
      if (singleShift.generated_from_template && singleShift.template_id) {
        templateCandidates.set(singleShift.template_id, singleShift);
      }

      matches.forEach((match) => {
        conflictRows.push({
          conflict_type: 'template_overlap',
          student_id: studentId,
          single_shift_id: singleShift.id,
          group_shift_id: '',
          single_status: singleShift.status,
          group_status: '',
          single_shift_start: singleShift.shift_start,
          single_shift_end: singleShift.shift_end,
          group_shift_start: '',
          group_shift_end: '',
          single_teacher: singleShift.teacher_name,
          group_teacher: match.teacher_name,
          group_student_names: match.student_names,
          single_template_id: singleShift.template_id,
          single_generated_from_template: singleShift.generated_from_template ? 'true' : 'false',
        });
      });
    }
  }

  const shiftDeletes = Array.from(deleteCandidates.values());
  const templateIds = Array.from(templateCandidates.keys());

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const conflictsPath = path.join(OUTPUT_DIR, `prod_group_single_conflicts_${timestamp}.csv`);
  writeCsv(
    conflictsPath,
    [
      'conflict_type',
      'student_id',
      'single_shift_id',
      'group_shift_id',
      'single_status',
      'group_status',
      'single_shift_start',
      'single_shift_end',
      'group_shift_start',
      'group_shift_end',
      'single_teacher',
      'group_teacher',
      'group_student_names',
      'single_template_id',
      'single_generated_from_template',
    ],
    conflictRows,
  );

  const shiftSnapshotPath = path.join(OUTPUT_DIR, `prod_group_single_shift_deletes_${timestamp}.csv`);
  writeCsv(
    shiftSnapshotPath,
    [
      'shift_id',
      'status',
      'shift_start',
      'shift_end',
      'teacher_name',
      'student_names',
      'template_id',
      'generated_from_template',
    ],
    shiftDeletes.map((shift) => ({
      shift_id: shift.id,
      status: shift.status,
      shift_start: shift.shift_start,
      shift_end: shift.shift_end,
      teacher_name: shift.teacher_name,
      student_names: shift.student_names.join('|'),
      template_id: shift.template_id,
      generated_from_template: shift.generated_from_template ? 'true' : 'false',
    })),
  );

  console.log(`Conflicts found: ${conflictRows.length}`);
  console.log(`Single shifts to delete: ${shiftDeletes.length}`);
  console.log(`Templates to disable: ${templateIds.length}`);
  console.log(`Conflicts report: ${conflictsPath}`);
  console.log(`Shift delete snapshot: ${shiftSnapshotPath}`);

  if (!APPLY || shiftDeletes.length === 0) {
    return;
  }

  const templateSnapshotRows = [];
  if (templateIds.length > 0) {
    const templateRefs = templateIds.map((id) => db.collection('shift_templates').doc(id));
    const templateDocs = await db.getAll(...templateRefs);
    templateDocs.forEach((doc) => {
      if (!doc.exists) return;
      const data = doc.data() || {};
      templateSnapshotRows.push({
        template_id: doc.id,
        teacher_name: data.teacher_name || '',
        teacher_id: data.teacher_id || '',
        student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
        start_time: data.start_time || '',
        duration_minutes: data.duration_minutes || '',
        active: data.active === false ? 'false' : 'true',
      });
    });
  }

  const templateSnapshotPath = path.join(OUTPUT_DIR, `prod_group_single_templates_disabled_${timestamp}.csv`);
  writeCsv(
    templateSnapshotPath,
    [
      'template_id',
      'teacher_name',
      'teacher_id',
      'student_names',
      'start_time',
      'duration_minutes',
      'active',
    ],
    templateSnapshotRows,
  );

  let batch = db.batch();
  let opCount = 0;
  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  for (const shift of shiftDeletes) {
    const ref = db.collection('teaching_shifts').doc(shift.id);
    batch.delete(ref);
    opCount += 1;
    if (opCount >= 450) await flush();
  }
  await flush();

  if (templateIds.length > 0) {
    batch = db.batch();
    opCount = 0;
    templateIds.forEach((templateId) => {
      const ref = db.collection('shift_templates').doc(templateId);
      batch.update(ref, {
        active: false,
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
      });
      opCount += 1;
      if (opCount >= 450) {
        batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    });
    await flush();
  }

  console.log(`Applied: deleted ${shiftDeletes.length} shifts.`);
  console.log(`Template snapshot: ${templateSnapshotPath}`);
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
