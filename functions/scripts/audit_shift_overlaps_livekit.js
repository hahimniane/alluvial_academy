#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const DAYS_AHEAD = Number(process.env.DAYS_AHEAD || 90);
const START_OFFSET_DAYS = Number(process.env.START_OFFSET_DAYS || -1);
const INCLUDE_ALL_STATUSES = process.argv.includes('--all-statuses');

const DEFAULT_STATUSES = new Set(['scheduled', 'active', 'in_progress', 'pending']);
const STATUS_ALIASES = new Map([
  ['inprogress', 'in_progress'],
  ['in-progress', 'in_progress'],
  ['partiallycompleted', 'partiallycompleted'],
  ['fullycompleted', 'fullycompleted'],
  ['cancelled', 'cancelled'],
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

const normalizeProvider = (value) => {
  if (!value) return '';
  return value.toString().trim().toLowerCase();
};

const hasZoomData = (data) => {
  const fields = [
    data.zoom_meeting_id,
    data.zoomMeetingId,
    data.zoom_encrypted_join_url,
    data.zoomEncryptedJoinUrl,
    data.hub_meeting_id,
    data.hubMeetingId,
    data.hubMeetingID,
  ];
  return fields.some((field) => typeof field === 'string' && field.trim().length > 0);
};

const main = async () => {
  if (!admin.apps.length) {
    admin.initializeApp({projectId: PROJECT_ID});
  }
  const db = admin.firestore();

  const nowUtc = DateTime.utc();
  const rangeStart = nowUtc.plus({days: START_OFFSET_DAYS}).toJSDate();
  const rangeEnd = nowUtc.plus({days: DAYS_AHEAD}).toJSDate();

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Window: ${rangeStart.toISOString()} -> ${rangeEnd.toISOString()}`);
  console.log(`Statuses: ${INCLUDE_ALL_STATUSES ? 'ALL' : Array.from(DEFAULT_STATUSES).join(', ')}`);

  const snapshot = await db
    .collection('teaching_shifts')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(rangeStart))
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(rangeEnd))
    .get();

  const shifts = [];
  const userNameById = new Map();
  const userRoles = new Map();
  const livekitIssues = [];

  snapshot.docs.forEach((doc) => {
    const data = doc.data() || {};
    const status = normalizeStatus(data.status);
    if (!INCLUDE_ALL_STATUSES && !DEFAULT_STATUSES.has(status)) return;

    const shiftStartMs = toMillis(data.shift_start);
    const shiftEndMs = toMillis(data.shift_end);
    if (!shiftStartMs || !shiftEndMs) return;

    const teacherId = data.teacher_id || '';
    const teacherName = data.teacher_name || '';
    if (teacherId && teacherName && !userNameById.has(teacherId)) {
      userNameById.set(teacherId, teacherName);
    }
    if (teacherId) {
      const roles = userRoles.get(teacherId) || new Set();
      roles.add('teacher');
      userRoles.set(teacherId, roles);
    }

    const studentIds = Array.isArray(data.student_ids) ? data.student_ids.map(String) : [];
    const studentNames = Array.isArray(data.student_names) ? data.student_names.map(String) : [];
    studentIds.forEach((studentId, index) => {
      const name = studentNames[index];
      if (studentId && name && !userNameById.has(studentId)) {
        userNameById.set(studentId, name);
      }
      if (studentId) {
        const roles = userRoles.get(studentId) || new Set();
        roles.add('student');
        userRoles.set(studentId, roles);
      }
    });

    const videoProvider = normalizeProvider(data.video_provider || data.videoProvider);
    const livekitRoomName = (data.livekit_room_name || '').toString().trim();
    const zoomDataPresent = hasZoomData(data);
    const shiftCategory = (data.shift_category || data.category || '').toString().trim().toLowerCase();

    if (!videoProvider) {
      livekitIssues.push({
        issue_type: 'missing_video_provider',
        shift_id: doc.id,
        status,
        shift_start: toIso(data.shift_start),
        shift_end: toIso(data.shift_end),
        teacher_id: teacherId,
        teacher_name: teacherName,
        student_ids: studentIds.join('|'),
        student_names: studentNames.join('|'),
        template_id: data.template_id || '',
        video_provider: '',
        livekit_room_name: livekitRoomName,
        shift_category: shiftCategory,
        zoom_data_present: zoomDataPresent ? 'true' : 'false',
        expected_livekit_room_name: `shift_${doc.id}`,
        livekit_room_matches: livekitRoomName === `shift_${doc.id}` ? 'true' : 'false',
      });
    }

    if (videoProvider === 'livekit' && !livekitRoomName) {
      livekitIssues.push({
        issue_type: 'livekit_missing_room',
        shift_id: doc.id,
        status,
        shift_start: toIso(data.shift_start),
        shift_end: toIso(data.shift_end),
        teacher_id: teacherId,
        teacher_name: teacherName,
        student_ids: studentIds.join('|'),
        student_names: studentNames.join('|'),
        template_id: data.template_id || '',
        video_provider: videoProvider,
        livekit_room_name: livekitRoomName,
        shift_category: shiftCategory,
        zoom_data_present: zoomDataPresent ? 'true' : 'false',
        expected_livekit_room_name: `shift_${doc.id}`,
        livekit_room_matches: livekitRoomName === `shift_${doc.id}` ? 'true' : 'false',
      });
    }

    if (videoProvider && videoProvider !== 'livekit' && livekitRoomName) {
      livekitIssues.push({
        issue_type: 'non_livekit_has_room',
        shift_id: doc.id,
        status,
        shift_start: toIso(data.shift_start),
        shift_end: toIso(data.shift_end),
        teacher_id: teacherId,
        teacher_name: teacherName,
        student_ids: studentIds.join('|'),
        student_names: studentNames.join('|'),
        template_id: data.template_id || '',
        video_provider: videoProvider,
        livekit_room_name: livekitRoomName,
        shift_category: shiftCategory,
        zoom_data_present: zoomDataPresent ? 'true' : 'false',
        expected_livekit_room_name: `shift_${doc.id}`,
        livekit_room_matches: livekitRoomName === `shift_${doc.id}` ? 'true' : 'false',
      });
    }

    if (videoProvider === 'livekit' && zoomDataPresent) {
      livekitIssues.push({
        issue_type: 'livekit_with_zoom_data',
        shift_id: doc.id,
        status,
        shift_start: toIso(data.shift_start),
        shift_end: toIso(data.shift_end),
        teacher_id: teacherId,
        teacher_name: teacherName,
        student_ids: studentIds.join('|'),
        student_names: studentNames.join('|'),
        template_id: data.template_id || '',
        video_provider: videoProvider,
        livekit_room_name: livekitRoomName,
        shift_category: shiftCategory,
        zoom_data_present: 'true',
        expected_livekit_room_name: `shift_${doc.id}`,
        livekit_room_matches: livekitRoomName === `shift_${doc.id}` ? 'true' : 'false',
      });
    }

    shifts.push({
      id: doc.id,
      status,
      shiftStartMs,
      shiftEndMs,
      shift_start: toIso(data.shift_start),
      shift_end: toIso(data.shift_end),
      teacher_id: teacherId,
      teacher_name: teacherName,
      student_ids: studentIds,
      student_names: studentNames,
      video_provider: videoProvider,
      livekit_room_name: livekitRoomName,
      template_id: data.template_id || '',
      generated_from_template: data.generated_from_template === true,
      shift_category: shiftCategory,
      subject_display_name: data.subject_display_name || '',
    });
  });

  const userShifts = new Map();
  const addUserShift = (userId, role, shift) => {
    if (!userId) return;
    const list = userShifts.get(userId) || [];
    list.push({role, shift});
    userShifts.set(userId, list);
  };

  shifts.forEach((shift) => {
    addUserShift(shift.teacher_id, 'teacher', shift);
    shift.student_ids.forEach((studentId) => addUserShift(studentId, 'student', shift));
  });

  const overlapRows = [];
  for (const [userId, entries] of userShifts.entries()) {
    if (entries.length < 2) continue;

    entries.sort((a, b) => a.shift.shiftStartMs - b.shift.shiftStartMs);
    const active = [];

    for (const entry of entries) {
      const {shift} = entry;
      const start = shift.shiftStartMs;
      const end = shift.shiftEndMs;

      for (let i = active.length - 1; i >= 0; i -= 1) {
        if (active[i].shift.shiftEndMs <= start) {
          active.splice(i, 1);
        }
      }

      for (const prior of active) {
        const overlapStart = Math.max(start, prior.shift.shiftStartMs);
        const overlapEnd = Math.min(end, prior.shift.shiftEndMs);
        const overlapMinutes = Math.max(0, Math.round((overlapEnd - overlapStart) / 60000));

        overlapRows.push({
          user_id: userId,
          user_name: userNameById.get(userId) || '',
          user_roles: Array.from(userRoles.get(userId) || []).join('|'),
          role_a: prior.role,
          role_b: entry.role,
          shift_id_a: prior.shift.id,
          shift_id_b: shift.id,
          status_a: prior.shift.status,
          status_b: shift.status,
          shift_start_a: prior.shift.shift_start,
          shift_end_a: prior.shift.shift_end,
          shift_start_b: shift.shift_start,
          shift_end_b: shift.shift_end,
          overlap_minutes: overlapMinutes,
          teacher_a: prior.shift.teacher_name,
          teacher_b: shift.teacher_name,
          students_a: prior.shift.student_names.join('|'),
          students_b: shift.student_names.join('|'),
          video_provider_a: prior.shift.video_provider,
          video_provider_b: shift.video_provider,
          template_id_a: prior.shift.template_id,
          template_id_b: shift.template_id,
          category_a: prior.shift.shift_category,
          category_b: shift.shift_category,
        });
      }

      active.push(entry);
    }
  }

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const overlapPath = path.join(OUTPUT_DIR, `prod_shift_overlaps_${timestamp}.csv`);
  writeCsv(
    overlapPath,
    [
      'user_id',
      'user_name',
      'user_roles',
      'role_a',
      'role_b',
      'shift_id_a',
      'shift_id_b',
      'status_a',
      'status_b',
      'shift_start_a',
      'shift_end_a',
      'shift_start_b',
      'shift_end_b',
      'overlap_minutes',
      'teacher_a',
      'teacher_b',
      'students_a',
      'students_b',
      'video_provider_a',
      'video_provider_b',
      'template_id_a',
      'template_id_b',
      'category_a',
      'category_b',
    ],
    overlapRows,
  );

  const livekitPath = path.join(OUTPUT_DIR, `prod_livekit_consistency_${timestamp}.csv`);
  writeCsv(
    livekitPath,
    [
      'issue_type',
      'shift_id',
      'status',
      'shift_start',
      'shift_end',
      'teacher_id',
      'teacher_name',
      'student_ids',
      'student_names',
      'template_id',
      'video_provider',
      'livekit_room_name',
      'shift_category',
      'zoom_data_present',
      'expected_livekit_room_name',
      'livekit_room_matches',
    ],
    livekitIssues,
  );

  console.log(`Loaded shifts: ${shifts.length}`);
  console.log(`Overlap rows: ${overlapRows.length}`);
  console.log(`LiveKit issues: ${livekitIssues.length}`);
  console.log(`Overlap report: ${overlapPath}`);
  console.log(`LiveKit report: ${livekitPath}`);
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
