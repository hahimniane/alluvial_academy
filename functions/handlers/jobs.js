const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { onCall } = require('firebase-functions/v2/https');

// NOTE: auto-scheduling (generateShifts) has been removed.
// Shifts will be created manually/assisted by Admin later.

/** Normalize client selectedTimes to a plain object (day -> time string). Ignores null, arrays, and non-string values. */
function normalizeSelectedTimes(value) {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) return null;
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (typeof k === 'string' && typeof v === 'string' && k.length > 0) out[k] = v;
  }
  return Object.keys(out).length ? out : null;
}

const acceptJob = async (request) => {
  const { jobId, selectedTimes: rawSelectedTimes } = request.data || {};
  const selectedTimes = normalizeSelectedTimes(rawSelectedTimes);
  const teacherId = request.auth?.uid;

  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in to accept a job.');
  }

  const db = admin.firestore();

  try {
    // 1. Get Job Reference
    const jobRef = db.collection('job_board').doc(jobId);
    
    // 2. Execute Transaction to safely lock the job
    await db.runTransaction(async (transaction) => {
      const jobDoc = await transaction.get(jobRef);
      
      if (!jobDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Job not found');
      }
      
      const jobData = jobDoc.data();
      if (jobData.status !== 'open') {
        throw new functions.https.HttpsError('failed-precondition', 'Job is no longer open');
      }

      const enrollmentId = jobData.enrollmentId;
      const enrollmentRef = db.collection('enrollments').doc(enrollmentId);
      
      // Verify enrollment exists
      const enrollmentDoc = await transaction.get(enrollmentRef);
      if (!enrollmentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Associated enrollment not found');
      }

      // Update Job Status with teacher's selected times
      const jobUpdate = {
        status: 'accepted',
        acceptedByTeacherId: teacherId,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      // Store teacher's time preferences when provided (from conflict picker or suggested times)
      if (selectedTimes) {
        jobUpdate.teacherSelectedTimes = selectedTimes;
      }
      
      transaction.update(jobRef, jobUpdate);

      // Get teacher name for tracking
      let teacherName = 'Unknown Teacher';
      try {
        const teacherDoc = await transaction.get(db.collection('users').doc(teacherId));
        if (teacherDoc.exists) {
          const teacherData = teacherDoc.data();
          teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim();
          if (!teacherName || teacherName === ' ') {
            teacherName = teacherData['e-mail'] || 'Unknown Teacher';
          }
        }
      } catch (e) {
        console.warn('Could not get teacher name:', e);
      }
      
      // Build action history entry (use ISO string since serverTimestamp doesn't work in arrayUnion)
      const teacherActionEntry = {
        action: 'teacher_accepted',
        status: 'matched',
        teacherId: teacherId,
        teacherName: teacherName,
        selectedTimes: selectedTimes || null,
        timestamp: new Date().toISOString(),
      };
      
      // Update Enrollment Status with teacher's preferences
      const enrollmentUpdate = {
        'metadata.status': 'matched',
        'metadata.matchedTeacherId': teacherId,
        'metadata.matchedTeacherName': teacherName,
        'metadata.matchedAt': admin.firestore.FieldValue.serverTimestamp(),
        'metadata.lastUpdated': admin.firestore.FieldValue.serverTimestamp(),
      };
      
      if (selectedTimes) {
        enrollmentUpdate['metadata.teacherSelectedTimes'] = selectedTimes;
      }
      
      // Add to action history
      enrollmentUpdate['metadata.actionHistory'] = admin.firestore.FieldValue.arrayUnion(teacherActionEntry);
      
      transaction.update(enrollmentRef, enrollmentUpdate);

      // Create Admin Notification with time details
      const notifRef = db.collection('admin_notifications').doc();
      const timeDetails = selectedTimes 
        ? Object.entries(selectedTimes).map(([day, time]) => `${day}: ${time}`).join(', ')
        : 'No specific times selected';
      
      transaction.set(notifRef, {
        type: 'job_accepted',
        jobId: jobId,
        teacherId: teacherId,
        enrollmentId: enrollmentId,
        studentName: jobData.studentName,
        subject: jobData.subject,
        teacherSelectedTimes: selectedTimes || null,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        message: `A teacher has accepted ${jobData.studentName} (${jobData.subject}). Selected times: ${timeDetails}`,
        action_required: true,
      });
    });

    console.log(`✅ Job ${jobId} accepted by ${teacherId}. Selected times: ${JSON.stringify(selectedTimes)}`);

    return { 
      success: true, 
      message: 'Job accepted! The admin will contact you to finalize the schedule.',
    };

  } catch (error) {
    console.error(`❌ Error accepting job ${jobId}:`, error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};

/**
 * Allows a teacher to withdraw from an accepted job.
 * This re-broadcasts the job to other teachers.
 */
const withdrawFromJob = async (request) => {
  const { jobId } = request.data;
  const teacherId = request.auth?.uid;

  // #region agent log
  const hasAuth = !!request.auth;
  const authUid = request.auth ? request.auth.uid : 'none';
  console.log(`[withdrawFromJob] Called with jobId=${jobId}, auth=${request.auth ? `uid=${request.auth.uid}` : 'null'}, hasAuth=${hasAuth}`);
  try {
    fetch('http://127.0.0.1:7242/ingest/63ac8384-4404-4220-b813-f04f5289394c', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'jobs.js:withdrawFromJob', message: 'handler', data: { jobId, hasAuth, authUid }, timestamp: Date.now(), sessionId: 'debug-session', hypothesisId: 'H2' }) }).catch(() => {});
  } catch (_) {}
  // #endregion

  if (!request.auth) {
    console.error('[withdrawFromJob] UNAUTHENTICATED: request.auth is null/undefined');
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in to withdraw from a job.');
  }

  const db = admin.firestore();

  try {
    const jobRef = db.collection('job_board').doc(jobId);
    
    await db.runTransaction(async (transaction) => {
      const jobDoc = await transaction.get(jobRef);
      
      if (!jobDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Job not found');
      }
      
      const jobData = jobDoc.data();
      
      // Only the teacher who accepted can withdraw
      if (jobData.acceptedByTeacherId !== teacherId) {
        throw new functions.https.HttpsError('permission-denied', 'You can only withdraw from jobs you accepted');
      }
      
      if (jobData.status !== 'accepted') {
        throw new functions.https.HttpsError('failed-precondition', 'Can only withdraw from accepted jobs');
      }

      const enrollmentId = jobData.enrollmentId;
      const enrollmentRef = db.collection('enrollments').doc(enrollmentId);
      
      // Get teacher info for notification
      const teacherDoc = await transaction.get(db.collection('users').doc(teacherId));
      const teacherName = teacherDoc.exists 
        ? `${teacherDoc.data().first_name || ''} ${teacherDoc.data().last_name || ''}`.trim() 
        : 'A teacher';

      // Re-open the job (remove teacher association, keep withdrawal history)
      transaction.update(jobRef, {
        status: 'open',
        acceptedByTeacherId: null,
        acceptedAt: null,
        teacherSelectedTimes: null, // Clear teacher's time selection
        withdrawnAt: admin.firestore.FieldValue.serverTimestamp(),
        withdrawnByTeacherId: teacherId,
        withdrawalHistory: admin.firestore.FieldValue.arrayUnion({
          teacherId: teacherId,
          teacherName: teacherName,
          withdrawnAt: new Date().toISOString(),
        }),
      });

      // Update Enrollment Status back to broadcasted
      const withdrawEntry = {
        action: 'teacher_withdrawn',
        status: 'broadcasted',
        teacherId: teacherId,
        teacherName: teacherName,
        timestamp: new Date().toISOString(),
      };
      
      transaction.update(enrollmentRef, {
        'metadata.status': 'broadcasted',
        'metadata.matchedTeacherId': null,
        'metadata.matchedTeacherName': null,
        'metadata.matchedAt': null,
        'metadata.teacherSelectedTimes': null,
        'metadata.lastWithdrawnBy': teacherId,
        'metadata.lastWithdrawnAt': admin.firestore.FieldValue.serverTimestamp(),
        'metadata.actionHistory': admin.firestore.FieldValue.arrayUnion(withdrawEntry),
      });

      // Create Admin Notification
      const notifRef = db.collection('admin_notifications').doc();
      transaction.set(notifRef, {
        type: 'job_withdrawn',
        jobId: jobId,
        teacherId: teacherId,
        teacherName: teacherName,
        enrollmentId: enrollmentId,
        studentName: jobData.studentName,
        subject: jobData.subject,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        message: `${teacherName} has withdrawn from teaching ${jobData.studentName} (${jobData.subject}). Job is now re-open.`,
        action_required: false,
      });
    });

    console.log(`✅ Teacher ${teacherId} withdrew from job ${jobId}. Job re-broadcasted.`);

    return { 
      success: true, 
      message: 'You have successfully withdrawn. The job is now available for other teachers.',
    };

  } catch (error) {
    console.error(`❌ Error withdrawing from job ${jobId}:`, error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};

module.exports = {
  acceptJob,
  withdrawFromJob,
};
