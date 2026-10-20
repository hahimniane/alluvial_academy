/**
 * republishEnrollmentJob puts a matched student back on the teacher job board.
 *
 * Expected behavior:
 * - Admin-only; only a matched application can be republished.
 * - Posts a fresh open job in the broadcast shape (no old teacher answers,
 *   no teacher targeting) and closes the posting the old match came from.
 * - Moves the application to broadcasted, clears the match fields into
 *   metadata.previousMatches and appends to metadata.actionHistory.
 * - Leaves the student account, the parent link and every other field alone,
 *   and writes nothing to teaching_shifts or shift_templates.
 * - Takes an exclusive family class back as one class.
 */

jest.mock('firebase-functions', () => {
  class MockHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {https: {HttpsError: MockHttpsError}};
});

const {
  republishEnrollmentJob,
  scheduleForRepublish,
  buildPreviousMatchEntry,
  normalizeReason,
} = require('../handlers/enrollment_republish');

const FieldValue = {
  serverTimestamp: () => ({__op: 'serverTimestamp'}),
  delete: () => ({__op: 'delete'}),
  arrayUnion: (...elements) => ({__op: 'arrayUnion', elements}),
};
const NOW = {seconds: 1760900000, nanoseconds: 0};
const Timestamp = {now: () => NOW};

const isSentinel = (v) => v && typeof v === 'object' && typeof v.__op === 'string';

/** Applies a Firestore update with dotted paths and sentinels. */
function applyUpdate(base, update) {
  const out = JSON.parse(JSON.stringify(base || {}));
  for (const [path, value] of Object.entries(update)) {
    const keys = path.split('.');
    let node = out;
    for (const key of keys.slice(0, -1)) {
      if (!node[key] || typeof node[key] !== 'object') node[key] = {};
      node = node[key];
    }
    const last = keys[keys.length - 1];
    if (isSentinel(value)) {
      if (value.__op === 'delete') delete node[last];
      else if (value.__op === 'serverTimestamp') node[last] = 'SERVER_TS';
      else if (value.__op === 'arrayUnion') node[last] = [...(node[last] || []), ...value.elements];
    } else {
      node[last] = value;
    }
  }
  return out;
}

function makeDb(seed) {
  const store = JSON.parse(JSON.stringify(seed));
  const writes = [];
  let autoId = 0;
  const ref = (collection, id) => ({
    id,
    path: `${collection}/${id}`,
    collection,
  });
  const snap = (r) => ({
    id: r.id,
    ref: r,
    exists: Boolean(store[r.collection] && store[r.collection][r.id]),
    data: () => JSON.parse(JSON.stringify(store[r.collection][r.id])),
  });
  const db = {
    store,
    writes,
    collection: (name) => ({
      doc: (id) => {
        const docId = id || `new_job_${++autoId}`;
        const r = ref(name, docId);
        r.get = async () => snap(r);
        return r;
      },
    }),
    runTransaction: async (fn) => {
      let wrote = false;
      const tx = {
        get: async (r) => {
          if (wrote) throw new Error('reads must come before writes');
          return snap(r);
        },
        set: (r, data) => {
          wrote = true;
          writes.push({op: 'set', path: r.path});
          store[r.collection] = store[r.collection] || {};
          store[r.collection][r.id] = applyUpdate({}, data);
        },
        update: (r, data) => {
          wrote = true;
          writes.push({op: 'update', path: r.path});
          if (!store[r.collection] || !store[r.collection][r.id]) throw new Error(`no doc ${r.path}`);
          store[r.collection][r.id] = applyUpdate(store[r.collection][r.id], data);
        },
      };
      return fn(tx);
    },
  };
  return db;
}

const matchedEnrollment = (over = {}) => ({
  subject: 'quran',
  programTitle: 'Quran Memorization',
  gradeLevel: 'Beginner',
  student: {name: 'Amina Diallo', age: '9', gender: 'Female'},
  contact: {email: 'parent@example.com', parentName: 'Fatou Diallo', guardianId: 'parent_1', city: 'Bronx'},
  preferences: {days: ['Mon', 'Wed'], timeSlots: ['5:00 PM'], timeZone: 'America/New_York'},
  program: {classType: 'One-on-One', sessionDuration: '60 minutes', sessionMinutes: 60},
  metadata: {
    status: 'matched',
    jobId: 'job_old',
    matchedTeacherId: 'teacher_1',
    matchedTeacherName: 'Mariama Bah',
    matchedAt: {seconds: 1750000000, nanoseconds: 0},
    matchedByAdminId: 'admin_0',
    teacherSelectedTimes: {Mon: '5:00 PM'},
    latestTeacherResponseSummary: {teacherId: 'teacher_1', availableAlternatives: ['Mon 5:00 PM']},
    studentUserId: 'student_1',
    parentUserId: 'parent_1',
    parentInviteStatus: 'linked',
    pricingPlanId: 'plan_a',
    lastBroadcastSnapshot: {
      days: ['Mon', 'Wed', 'Fri'],
      timeSlots: ['5:00 PM', '6:00 PM'],
      timeOfDayPreference: 'Evening',
      timezoneRef: 'America/New_York',
      adminNotesForTeachers: 'Gentle with beginners',
      targetTeacherIds: ['teacher_1'],
      targetTeacherNames: ['Mariama Bah'],
    },
    actionHistory: [{action: 'admin_confirmed_match', teacherName: 'Mariama Bah'}],
    ...over.metadata,
  },
  ...over.root,
});

const seed = () => ({
  users: {admin_1: {first_name: 'Hawa', last_name: 'Admin', user_type: 'admin'}},
  enrollments: {enr_1: matchedEnrollment()},
  job_board: {
    job_old: {
      enrollmentId: 'enr_1',
      status: 'accepted',
      acceptedByTeacherId: 'teacher_1',
      targetTeacherIds: ['teacher_1'],
    },
  },
  teaching_shifts: {shift_1: {teacher_id: 'teacher_1', student_ids: ['student_1']}},
});

const adminDeps = (db) => ({
  db,
  FieldValue,
  Timestamp,
  verifyAdmin: async () => ({callerUid: 'admin_1', effectiveAdminEmail: 'hawa@example.com'}),
});

const call = (db, data, deps = adminDeps(db)) =>
  republishEnrollmentJob({auth: {uid: 'admin_1'}, data}, deps);

describe('republishEnrollmentJob', () => {
  test('rejects a caller the admin gate refuses, writing nothing', async () => {
    const db = makeDb(seed());
    const deps = {
      ...adminDeps(db),
      verifyAdmin: async () => {
        const error = new Error('Only administrators can perform this action');
        error.code = 'permission-denied';
        throw error;
      },
    };
    await expect(call(db, {enrollmentId: 'enr_1'}, deps)).rejects.toMatchObject({code: 'permission-denied'});
    expect(db.writes).toHaveLength(0);
  });

  test('requires an enrollment id', async () => {
    const db = makeDb(seed());
    await expect(call(db, {})).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('refuses an application that is not matched', async () => {
    const data = seed();
    data.enrollments.enr_1.metadata.status = 'broadcasted';
    const db = makeDb(data);
    await expect(call(db, {enrollmentId: 'enr_1'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toHaveLength(0);
  });

  test('posts a fresh open job and closes the old posting', async () => {
    const db = makeDb(seed());
    const result = await call(db, {enrollmentId: 'enr_1', reason: '  Teacher   left '});

    expect(result).toMatchObject({success: true, enrollmentIds: ['enr_1']});
    const job = db.store.job_board[result.jobId];
    expect(result.jobId).not.toBe('job_old');
    expect(job).toMatchObject({
      enrollmentId: 'enr_1',
      status: 'open',
      studentName: 'Amina Diallo',
      subject: 'quran',
      subject_display_name: 'Quran Memorization',
      days: ['Mon', 'Wed', 'Fri'],
      timeSlots: ['5:00 PM', '6:00 PM'],
      timeOfDayPreference: 'Evening',
      timeZone: 'America/New_York',
      scheduleTimezoneRef: 'America/New_York',
      adminNotesForTeachers: 'Gentle with beginners',
      parentEmail: 'parent@example.com',
      republishedFromJobId: 'job_old',
    });
    // Open to every teacher, and nothing from the old match comes along.
    expect(job.targetTeacherIds).toBeUndefined();
    expect(job.broadcastSnapshot.targetTeacherIds).toBeUndefined();
    expect(job.acceptedByTeacherId).toBeUndefined();

    expect(db.store.job_board.job_old).toMatchObject({
      status: 'closed',
      closedReason: 'republished',
      republishedAsJobId: result.jobId,
      // Who accepted it stays on the closed posting as history.
      acceptedByTeacherId: 'teacher_1',
    });
  });

  test('moves the match into history and keeps account, parent and pricing', async () => {
    const db = makeDb(seed());
    const result = await call(db, {enrollmentId: 'enr_1', reason: 'Teacher left'});
    const meta = db.store.enrollments.enr_1.metadata;

    expect(meta.status).toBe('broadcasted');
    expect(meta.jobId).toBe(result.jobId);
    for (const cleared of [
      'matchedTeacherId',
      'matchedTeacherName',
      'matchedAt',
      'matchedByAdminId',
      'teacherSelectedTimes',
      'latestTeacherResponseSummary',
    ]) {
      expect(meta[cleared]).toBeUndefined();
    }
    expect(meta.previousMatches).toEqual([
      {
        teacherId: 'teacher_1',
        teacherName: 'Mariama Bah',
        matchedAt: {seconds: 1750000000, nanoseconds: 0},
        unmatchedAt: NOW,
        reason: 'Teacher left',
        by: 'admin_1',
        byName: 'Hawa Admin',
        jobId: 'job_old',
        republishedJobId: result.jobId,
      },
    ]);
    expect(meta.actionHistory).toHaveLength(2);
    expect(meta.actionHistory[1]).toMatchObject({
      action: 'republished',
      status: 'broadcasted',
      adminId: 'admin_1',
      adminName: 'Hawa Admin',
      jobId: result.jobId,
      previousJobId: 'job_old',
      teacherName: 'Mariama Bah',
      reason: 'Teacher left',
    });

    expect(meta.studentUserId).toBe('student_1');
    expect(meta.parentUserId).toBe('parent_1');
    expect(meta.parentInviteStatus).toBe('linked');
    expect(meta.pricingPlanId).toBe('plan_a');
    expect(db.store.enrollments.enr_1.contact.guardianId).toBe('parent_1');
  });

  test('never writes to classes or shifts', async () => {
    const db = makeDb(seed());
    const before = JSON.stringify(db.store.teaching_shifts);
    await call(db, {enrollmentId: 'enr_1'});
    expect(JSON.stringify(db.store.teaching_shifts)).toBe(before);
    const touched = db.writes.map((w) => w.path.split('/')[0]);
    expect(new Set(touched)).toEqual(new Set(['job_board', 'enrollments']));
  });

  test('a second republish adds a second history entry', async () => {
    const db = makeDb(seed());
    const first = await call(db, {enrollmentId: 'enr_1', reason: 'Teacher left'});
    // A new teacher is matched on the new posting.
    Object.assign(db.store.enrollments.enr_1.metadata, {
      status: 'matched',
      matchedTeacherId: 'teacher_2',
      matchedTeacherName: 'Ousmane Sow',
    });
    db.store.job_board[first.jobId].status = 'accepted';
    const second = await call(db, {enrollmentId: 'enr_1'});

    const meta = db.store.enrollments.enr_1.metadata;
    expect(meta.previousMatches.map((m) => m.teacherName)).toEqual(['Mariama Bah', 'Ousmane Sow']);
    expect(meta.previousMatches[1].reason).toBeUndefined();
    expect(db.store.job_board[first.jobId]).toMatchObject({status: 'closed', republishedAsJobId: second.jobId});
  });

  test('takes an exclusive family class back as one class', async () => {
    const data = seed();
    data.enrollments.enr_2 = matchedEnrollment();
    data.enrollments.enr_2.student = {name: 'Ibrahim Diallo', age: '7'};
    data.enrollments.enr_2.metadata.studentUserId = 'student_2';
    // Matched elsewhere already: stays where it is.
    data.enrollments.enr_3 = matchedEnrollment({metadata: {status: 'archived'}});
    data.job_board.job_old.classEnrollmentIds = ['enr_1', 'enr_2', 'enr_3'];
    const db = makeDb(data);

    const result = await call(db, {enrollmentId: 'enr_1'});

    expect(result.enrollmentIds).toEqual(['enr_1', 'enr_2']);
    const job = db.store.job_board[result.jobId];
    expect(job.classEnrollmentIds).toEqual(['enr_1', 'enr_2']);
    expect(job.studentName).toBe('Amina Diallo, Ibrahim Diallo');
    expect(job.studentCount).toBe(2);
    expect(db.store.enrollments.enr_2.metadata).toMatchObject({status: 'broadcasted', jobId: result.jobId, studentUserId: 'student_2'});
    expect(db.store.enrollments.enr_3.metadata.status).toBe('archived');
  });

  test('works when the old posting is gone', async () => {
    const data = seed();
    delete data.job_board.job_old;
    const db = makeDb(data);
    const result = await call(db, {enrollmentId: 'enr_1'});
    expect(db.store.job_board[result.jobId].status).toBe('open');
    expect(db.store.enrollments.enr_1.metadata.status).toBe('broadcasted');
  });
});

describe('scheduleForRepublish', () => {
  test('falls back from the last broadcast to the old posting to the family request', () => {
    const fromJob = scheduleForRepublish(
      {preferences: {days: ['Tue'], timeZone: 'Africa/Conakry'}, metadata: {}},
      {days: ['Sat'], timeSlots: ['9:00 AM'], scheduleTimezoneRef: 'Europe/Paris'}
    );
    expect(fromJob).toMatchObject({days: ['Sat'], timeSlots: ['9:00 AM'], timezoneRef: 'Europe/Paris', studentTimezone: 'Africa/Conakry'});

    const fromFamily = scheduleForRepublish({preferences: {days: ['Tue'], timeSlots: ['4:00 PM']}}, null);
    expect(fromFamily).toMatchObject({days: ['Tue'], timeSlots: ['4:00 PM'], timezoneRef: 'UTC', studentTimezone: 'UTC'});
  });
});

describe('history helpers', () => {
  test('normalizeReason trims, collapses spaces and caps length', () => {
    expect(normalizeReason('  Teacher \n left ')).toBe('Teacher left');
    expect(normalizeReason(undefined)).toBe('');
    expect(normalizeReason('x'.repeat(500))).toHaveLength(300);
  });

  test('buildPreviousMatchEntry drops empty fields', () => {
    const entry = buildPreviousMatchEntry({
      metadata: {matchedTeacherId: 't1'},
      previousJobId: '',
      newJobId: 'j2',
      reason: '',
      actor: {uid: 'a1', name: 'Admin'},
      now: NOW,
    });
    expect(entry).toEqual({teacherId: 't1', unmatchedAt: NOW, by: 'a1', byName: 'Admin', republishedJobId: 'j2'});
  });
});
