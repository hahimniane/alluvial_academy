const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { onCall } = require('firebase-functions/v2/https');

// NOTE: auto-scheduling (generateShifts) has been removed.
// Shifts will be created manually/assisted by Admin later.

const acceptJob = async (request) => {
  const { jobId } = request.data;
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

      // Update Job Status
      transaction.update(jobRef, {
        status: 'accepted',
        acceptedByTeacherId: teacherId,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update Enrollment Status
      transaction.update(enrollmentRef, {
        'metadata.status': 'matched',
        'metadata.matchedTeacherId': teacherId,
        'metadata.matchedAt': admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create Admin Notification
      const notifRef = db.collection('admin_notifications').doc();
      transaction.set(notifRef, {
        type: 'job_accepted',
        jobId: jobId,
        teacherId: teacherId,
        enrollmentId: enrollmentId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        message: 'A teacher has accepted a new student. Please review and create the schedule.',
        action_required: true,
      });
    });

    console.log(`✅ Job ${jobId} accepted by ${teacherId}. Awaiting Admin scheduling.`);

    return { 
      success: true, 
      message: 'Job accepted! The admin will contact you to finalize the schedule.',
    };

  } catch (error) {
    console.error(`❌ Error accepting job ${jobId}:`, error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};

module.exports = {
  acceptJob,
};
