/**
 * Republishing a matched application to the teacher job board.
 *
 * A teacher stops teaching a student and the admin needs another teacher to
 * pick the student up. Broadcasting refuses a matched application, and the
 * older "revoke" path reopened the same posting — still carrying the previous
 * teacher's answers and with no record of who had taught the student.
 *
 * This posts a fresh job in the same shape broadcasting writes (so the Next.js
 * teacher job board, the Flutter TeacherJobBoardScreen and acceptJob read it
 * unchanged), closes the posting the old match came from, moves the
 * application back to `broadcasted`, and keeps the old match as a
 * `metadata.previousMatches` entry.
 *
 * What it never touches: the student account (`metadata.studentUserId`), the
 * parent link (`contact.guardianId`, `metadata.parentUserId`,
 * `metadata.parentInviteStatus`) and every class or shift. Admins move the
 * timetable themselves; a later match finds the account and parent steps
 * already done.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');

/** Set on the posting a republish replaced. */
const CLOSED_REASON_REPUBLISHED = 'republished';
const MAX_REASON_LENGTH = 300;

const record = (value) =>
  value && typeof value === 'object' && !Array.isArray(value) ? value : {};
const text = (value) => (typeof value === 'string' ? value.trim() : '');
const list = (value) =>
  Array.isArray(value) ? value.filter((item) => typeof item === 'string') : [];
const firstList = (...candidates) => {
  for (const candidate of candidates) {
    const values = list(candidate);
    if (values.length > 0) return values;
  }
  return [];
};
const firstText = (...candidates) => {
  for (const candidate of candidates) {
    const value = text(candidate);
    if (value) return value;
  }
  return '';
};

const withoutEmpty = (object) => {
  const out = {};
  for (const [key, value] of Object.entries(object)) {
    if (value === null || value === undefined || value === '') continue;
    out[key] = value;
  }
  return out;
};

const normalizeReason = (raw) => text(raw).replace(/\s+/g, ' ').slice(0, MAX_REASON_LENGTH);

/**
 * What teachers see for days and times: the last thing an admin sent them,
 * then what the previous posting carried, then what the family asked for.
 */
const scheduleForRepublish = (enrollmentData, previousJob) => {
  const data = record(enrollmentData);
  const metadata = record(data.metadata);
  const preferences = record(data.preferences);
  const snapshot = record(metadata.lastBroadcastSnapshot);
  const job = record(previousJob);
  const studentTimezone = firstText(preferences.timeZone, data.timeZone) || 'UTC';
  return {
    days: firstList(snapshot.days, job.days, preferences.days, data.preferredDays),
    timeSlots: firstList(snapshot.timeSlots, job.timeSlots, preferences.timeSlots, data.preferredTimeSlots),
    timeOfDay: firstText(
      snapshot.timeOfDayPreference,
      job.timeOfDayPreference,
      preferences.timeOfDayPreference,
      data.timeOfDayPreference
    ),
    timezoneRef: firstText(
      snapshot.timezoneRef,
      job.scheduleTimezoneRef,
      metadata.scheduleTimezoneRef
    ) || studentTimezone,
    adminNotesForTeachers: firstText(
      snapshot.adminNotesForTeachers,
      job.adminNotesForTeachers,
      metadata.adminNotesForTeachers
    ),
    studentTimezone,
  };
};

const studentNameOf = (data) => {
  const student = record(record(data).student);
  return firstText(student.name, record(data).studentName) || 'Student';
};

/**
 * The job_board document, field for field what broadcastEnrollment() in
 * apps/web/src/lib/jobBoardAdmin.ts writes. Teacher targeting is not carried
 * over: the point is that any teacher can pick the student up.
 */
const buildRepublishedJob = ({
  enrollmentId,
  enrollmentData,
  schedule,
  classmates = [],
  broadcastSnapshot,
  createdAt,
}) => {
  const data = record(enrollmentData);
  const contact = record(data.contact);
  const country = record(contact.country);
  const preferences = record(data.preferences);
  const metadata = record(data.metadata);
  const student = record(data.student);
  const program = record(data.program);

  const job = {
    enrollmentId,
    studentName: studentNameOf(data),
    studentAge: firstText(student.age, data.studentAge) || 'N/A',
    gender: firstText(student.gender, data.gender) || 'Not specified',
    subject: text(data.subject) || 'General',
    subject_display_name: firstText(data.programTitle, data.subject) || 'General',
    specificLanguage: text(data.specificLanguage) || null,
    gradeLevel: text(data.gradeLevel),
    days: schedule.days,
    timeSlots: schedule.timeSlots,
    timeZone: schedule.studentTimezone,
    sessionDuration: firstText(program.sessionDuration, data.sessionDuration) || '60 minutes',
    block: firstText(data.block, preferences.timeOfDayPreference),
    sessionMinutes: Number(program.sessionMinutes) || null,
    sessionsPerWeek: Number(program.sessionsPerWeek) || null,
    timeOfDayPreference: schedule.timeOfDay,
    countryName: firstText(country.name, data.countryName),
    countryCode: firstText(country.code, data.countryCode),
    city: firstText(contact.city, data.city),
    classType: firstText(program.classType, data.classType),
    preferredLanguage: firstText(preferences.preferredLanguage, data.preferredLanguage),
    knowsZoom: student.knowsZoom ?? data.knowsZoom ?? null,
    isAdult: metadata.isAdult ?? data.isAdult ?? false,
    status: 'open',
    createdAt,
    parentEmail: text(contact.email) || null,
    parentName: text(contact.parentName) || null,
    parentLinkId: metadata.parentLinkId ?? null,
    studentIndex: metadata.studentIndex ?? null,
    totalStudents: metadata.totalStudents ?? null,
    broadcastSnapshot,
    scheduleTimezoneRef: schedule.timezoneRef,
    ...(schedule.adminNotesForTeachers ? {adminNotesForTeachers: schedule.adminNotesForTeachers} : {}),
  };
  for (const key of Object.keys(job)) {
    if (job[key] === null || job[key] === undefined) delete job[key];
  }

  if (classmates.length > 0) {
    const roster = [
      {enrollmentId, name: studentNameOf(data), age: firstText(student.age, data.studentAge), level: text(data.gradeLevel)},
      ...classmates.map((mate) => {
        const mateData = record(mate.data);
        const mateStudent = record(mateData.student);
        return {
          enrollmentId: mate.id,
          name: studentNameOf(mateData),
          age: firstText(mateStudent.age, mateData.studentAge),
          level: text(mateData.gradeLevel),
        };
      }),
    ];
    job.classRoster = roster;
    job.classEnrollmentIds = roster.map((entry) => entry.enrollmentId);
    job.studentName = roster.map((entry) => entry.name).join(', ');
    job.studentCount = roster.length;
  }
  return job;
};

/** The old match, as the card shows it later: who, from when, until when, why. */
const buildPreviousMatchEntry = ({metadata, previousJobId, newJobId, reason, actor, now}) => {
  const meta = record(metadata);
  return withoutEmpty({
    teacherId: text(meta.matchedTeacherId),
    teacherName: text(meta.matchedTeacherName),
    matchedAt: meta.matchedAt || null,
    unmatchedAt: now,
    reason,
    by: actor.uid,
    byName: actor.name,
    jobId: previousJobId,
    republishedJobId: newJobId,
  });
};

/**
 * The enrollment write. Only match fields are cleared, and only into history;
 * account, parent and pricing fields are left exactly as they are.
 */
const buildRepublishEnrollmentUpdate = ({
  metadata,
  newJobId,
  reason,
  actor,
  broadcastSnapshot,
  timezoneRef,
  now,
  FieldValue,
}) => {
  const meta = record(metadata);
  const previousJobId = text(meta.jobId);
  const previousMatch = buildPreviousMatchEntry({
    metadata: meta,
    previousJobId,
    newJobId,
    reason,
    actor,
    now,
  });
  const historyEntry = withoutEmpty({
    action: 'republished',
    status: 'broadcasted',
    adminId: actor.uid,
    adminName: actor.name,
    adminEmail: actor.email,
    jobId: newJobId,
    previousJobId,
    teacherId: text(meta.matchedTeacherId),
    teacherName: text(meta.matchedTeacherName),
    reason,
    timestamp: now,
  });

  return {
    'metadata.status': 'broadcasted',
    'metadata.jobId': newJobId,
    'metadata.broadcastedAt': FieldValue.serverTimestamp(),
    'metadata.broadcastedBy': actor.uid,
    'metadata.broadcastedByName': actor.name,
    'metadata.lastUpdated': FieldValue.serverTimestamp(),
    'metadata.updatedBy': actor.uid,
    'metadata.updatedByName': actor.name,
    'metadata.scheduleTimezoneRef': timezoneRef,
    'metadata.lastBroadcastSnapshot': broadcastSnapshot,
    'metadata.matchedTeacherId': FieldValue.delete(),
    'metadata.matchedTeacherName': FieldValue.delete(),
    'metadata.matchedAt': FieldValue.delete(),
    'metadata.matchedByAdminId': FieldValue.delete(),
    'metadata.teacherSelectedTimes': FieldValue.delete(),
    'metadata.latestTeacherResponseSummary': FieldValue.delete(),
    'metadata.previousMatches': FieldValue.arrayUnion(previousMatch),
    'metadata.actionHistory': FieldValue.arrayUnion(historyEntry),
  };
};

const actorName = (profile, email) => {
  const data = record(profile);
  const full = `${text(data.first_name)} ${text(data.last_name)}`.trim();
  return full || text(data['e-mail']) || email || 'Admin';
};

const defaultDeps = () => ({
  db: admin.firestore(),
  FieldValue: admin.firestore.FieldValue,
  Timestamp: admin.firestore.Timestamp,
  verifyAdmin: verifyCallableCallerIsAdmin,
});

/**
 * Admin-only callable.
 *
 * Accepts: { enrollmentId: string, classmateIds?: string[], reason?: string }
 * Returns: { success: true, jobId, enrollmentIds }
 *
 * `classmateIds` are the other children of an exclusive family class as the
 * admin's screen groups them; the previous posting's own roster is added, so
 * a family class goes back on the board as the one class it was.
 */
const republishEnrollmentJob = async (request, deps = defaultDeps()) => {
  const {db, FieldValue, Timestamp, verifyAdmin} = deps;
  const {callerUid, effectiveAdminEmail} = await verifyAdmin(request);

  const payload = record(request && request.data);
  const enrollmentId = text(payload.enrollmentId);
  if (!enrollmentId) {
    throw new functions.https.HttpsError('invalid-argument', 'enrollmentId is required');
  }
  const requestedMates = list(payload.classmateIds).map((id) => id.trim()).filter(Boolean);
  const reason = normalizeReason(payload.reason);

  let profile = null;
  try {
    const snap = await db.collection('users').doc(callerUid).get();
    profile = snap.exists ? snap.data() : null;
  } catch (_) {
    // The name is for the history line only; it must not block the action.
  }
  const actor = {
    uid: callerUid,
    email: effectiveAdminEmail || text(record(profile).email) || text(record(profile)['e-mail']),
  };
  actor.name = actorName(profile, actor.email);

  const result = await db.runTransaction(async (tx) => {
    const primaryRef = db.collection('enrollments').doc(enrollmentId);
    const primarySnap = await tx.get(primaryRef);
    if (!primarySnap.exists) {
      throw new functions.https.HttpsError('not-found', 'This application no longer exists.');
    }
    const primaryData = primarySnap.data() || {};
    const primaryMeta = record(primaryData.metadata);
    const status = text(primaryMeta.status);
    if (status !== 'matched') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        status === 'broadcasted'
          ? 'This student is already on the job board.'
          : 'Only a matched application can be put back on the job board.'
      );
    }

    const previousJobId = text(primaryMeta.jobId);
    const previousJobRef = previousJobId ? db.collection('job_board').doc(previousJobId) : null;
    const previousJobSnap = previousJobRef ? await tx.get(previousJobRef) : null;
    const previousJob = previousJobSnap && previousJobSnap.exists ? previousJobSnap.data() || {} : null;

    const mateIds = [...new Set([...requestedMates, ...list(record(previousJob).classEnrollmentIds)])]
      .filter((id) => id !== enrollmentId);
    const mateSnaps = await Promise.all(
      mateIds.map((id) => tx.get(db.collection('enrollments').doc(id)))
    );
    // A classmate goes back with the class only while it is still matched;
    // one already moved on is left where the admin put it.
    const classmates = mateSnaps
      .filter((snap) => snap.exists && text(record(record(snap.data()).metadata).status) === 'matched')
      .map((snap) => ({id: snap.id, ref: snap.ref, data: snap.data() || {}}));

    // Every posting the old matches came from is closed, so no teacher is
    // left holding an accepted job for a student who is back on the board.
    const otherJobIds = [...new Set(
      classmates.map((mate) => text(record(mate.data.metadata).jobId)).filter((id) => id && id !== previousJobId)
    )];
    const otherJobSnaps = await Promise.all(
      otherJobIds.map((id) => tx.get(db.collection('job_board').doc(id)))
    );
    const jobsToClose = [
      ...(previousJobSnap && previousJobSnap.exists ? [previousJobSnap] : []),
      ...otherJobSnaps.filter((snap) => snap.exists),
    ];

    const now = Timestamp.now();
    const schedule = scheduleForRepublish(primaryData, previousJob);
    const broadcastSnapshot = withoutEmpty({
      days: schedule.days,
      timeSlots: schedule.timeSlots,
      timeOfDayPreference: schedule.timeOfDay,
      timezoneRef: schedule.timezoneRef,
      adminNotesForTeachers: schedule.adminNotesForTeachers,
      broadcastedBy: actor.uid,
      broadcastedAt: now,
    });

    const newJobRef = db.collection('job_board').doc();
    const jobData = buildRepublishedJob({
      enrollmentId,
      enrollmentData: primaryData,
      schedule,
      classmates,
      broadcastSnapshot,
      createdAt: FieldValue.serverTimestamp(),
    });
    jobData.republishedFromJobId = previousJobId || null;
    if (!jobData.republishedFromJobId) delete jobData.republishedFromJobId;
    tx.set(newJobRef, jobData);

    for (const jobSnap of jobsToClose) {
      const closing = {
        republishedAsJobId: newJobRef.id,
        republishedAt: FieldValue.serverTimestamp(),
        republishedByAdminId: actor.uid,
      };
      if (text(record(jobSnap.data()).status) !== 'closed') {
        closing.status = 'closed';
        closing.closedReason = CLOSED_REASON_REPUBLISHED;
        closing.closedAt = FieldValue.serverTimestamp();
      }
      tx.update(jobSnap.ref, closing);
    }

    const members = [{id: enrollmentId, ref: primaryRef, data: primaryData}, ...classmates];
    for (const member of members) {
      tx.update(member.ref, buildRepublishEnrollmentUpdate({
        metadata: record(member.data).metadata,
        newJobId: newJobRef.id,
        reason,
        actor,
        broadcastSnapshot,
        timezoneRef: schedule.timezoneRef,
        now,
        FieldValue,
      }));
    }

    return {jobId: newJobRef.id, enrollmentIds: members.map((member) => member.id)};
  });

  console.log(
    `[republishEnrollmentJob] ${result.enrollmentIds.join(',')} -> job ${result.jobId} by ${callerUid}`
  );
  return {success: true, ...result};
};

module.exports = {
  CLOSED_REASON_REPUBLISHED,
  republishEnrollmentJob,
  scheduleForRepublish,
  buildRepublishedJob,
  buildPreviousMatchEntry,
  buildRepublishEnrollmentUpdate,
  normalizeReason,
};
