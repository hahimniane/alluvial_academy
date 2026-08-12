const admin = require('firebase-admin');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');

const SETTINGS_COLLECTION = 'quiz_review_settings';
const SETTINGS_DOCUMENT = 'default';
const QUESTIONS_COLLECTION = 'quiz_questions';
const MAX_REJECTION_REASON_LENGTH = 500;

const roleValue = (data = {}) => String(
  data.user_type || data.userType || data.role || '',
).trim().toLowerCase();

const isAdminUser = (data = {}) => {
  const role = roleValue(data);
  return role === 'admin' || role === 'super_admin' ||
    data.is_admin === true || data.isAdmin === true;
};

const isTeacherUser = (data = {}) => roleValue(data) === 'teacher';

const displayNameForUser = (data = {}) => {
  const first = String(data.first_name || data.firstName || '').trim();
  const last = String(data.last_name || data.lastName || '').trim();
  return [first, last].filter(Boolean).join(' ') ||
    String(data.display_name || data.displayName || data.email || 'Reviewer').trim();
};

const reviewerIdsFromSettings = (settings = {}) => Array.from(new Set(
  (Array.isArray(settings.reviewer_teacher_ids)
    ? settings.reviewer_teacher_ids
    : [])
    .map((uid) => String(uid || '').trim())
    .filter(Boolean),
));

const rejectionReasonFor = (status, value) => {
  if (status !== 'rejected') return '';
  const reason = String(value || '').trim();
  if (!reason) {
    throw new HttpsError('invalid-argument', 'A rejection reason is required');
  }
  if (reason.length > MAX_REJECTION_REASON_LENGTH) {
    throw new HttpsError('invalid-argument', 'A rejection reason must be 500 characters or fewer');
  }
  return reason;
};

const tokenSetForUsers = (docs, preferenceKey) => {
  const tokens = new Set();
  docs.forEach((doc) => {
    const data = typeof doc.data === 'function' ? doc.data() : doc;
    if (data?.notificationPreferences?.[preferenceKey] === false) return;
    const values = Array.isArray(data?.fcmTokens)
      ? data.fcmTokens.map((entry) => entry?.token).filter(Boolean)
      : [];
    if (values.length === 0 && data?.fcmToken) values.push(data.fcmToken);
    values.forEach((token) => tokens.add(String(token)));
  });
  return Array.from(tokens);
};

const chunksOf = (values, size = 500) => {
  const chunks = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
};

const sendToTokens = async ({tokens, title, body, data}) => {
  let successCount = 0;
  let failureCount = 0;
  for (const chunk of chunksOf(tokens)) {
    if (chunk.length === 0) continue;
    const response = await admin.messaging().sendEachForMulticast({
      notification: {title, body},
      data,
      tokens: chunk,
      android: {priority: 'high', notification: {sound: 'default', channelId: 'high_importance_channel'}},
      apns: {payload: {aps: {sound: 'default', badge: 1}}},
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
  }
  return {successCount, failureCount};
};

const requireReviewer = async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required');
  const db = admin.firestore();
  const [userSnapshot, settingsSnapshot] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection(SETTINGS_COLLECTION).doc(SETTINGS_DOCUMENT).get(),
  ]);
  if (!userSnapshot.exists) {
    throw new HttpsError('permission-denied', 'User profile not found');
  }
  const user = userSnapshot.data() || {};
  const isAdmin = isAdminUser(user);
  const selected = reviewerIdsFromSettings(settingsSnapshot.data() || {}).includes(uid);
  if (!isAdmin && (!isTeacherUser(user) || !selected || user.is_active === false)) {
    throw new HttpsError('permission-denied', 'Selected quiz reviewer access required');
  }
  return {db, uid, user, isAdmin, settings: settingsSnapshot.data() || {}};
};

const getQuizReviewQueue = onCall({region: 'us-central1', memory: '256MiB'}, async (request) => {
  const {db, isAdmin, settings} = await requireReviewer(request);
  const [snapshot, recentSnapshot] = await Promise.all([
    db.collection(QUESTIONS_COLLECTION).where('status', '==', 'pending').get(),
    isAdmin ? db.collection(QUESTIONS_COLLECTION).get() : Promise.resolve(null),
  ]);
  const questions = snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  const recentReviews = recentSnapshot
    ? recentSnapshot.docs
      .map((doc) => ({id: doc.id, ...doc.data()}))
      .filter((question) => ['approved', 'rejected'].includes(question.status))
      .sort((a, b) => (b.reviewed_at?.toMillis?.() || 0) -
        (a.reviewed_at?.toMillis?.() || 0))
      .slice(0, 12)
      .map((question) => ({
        id: question.id,
        question: question.question || '',
        status: question.status,
        reviewerName: question.reviewed_by_name || 'Reviewer',
        reviewerRole: question.reviewed_by_role || 'admin',
        rejectionReason: question.rejection_reason || '',
      }))
    : [];
  return {
    questions,
    recentReviews,
    canManageReviewers: isAdmin,
    reviewerTeacherIds: isAdmin ? reviewerIdsFromSettings(settings) : [],
  };
});

const reviewQuizQuestion = onCall({region: 'us-central1', memory: '256MiB'}, async (request) => {
  const {db, uid, user, isAdmin} = await requireReviewer(request);
  const questionId = String(request.data?.questionId || '').trim();
  const status = String(request.data?.status || '').trim();
  if (!questionId || !['approved', 'rejected'].includes(status)) {
    throw new HttpsError('invalid-argument', 'Question and supported review status are required');
  }
  const rejectionReason = rejectionReasonFor(status, request.data?.rejectionReason);
  const questionRef = db.collection(QUESTIONS_COLLECTION).doc(questionId);
  const reviewRef = questionRef.collection('review_history').doc();
  await db.runTransaction(async (transaction) => {
    const question = await transaction.get(questionRef);
    if (!question.exists || question.data()?.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Question is no longer awaiting review');
    }
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const reviewer = {
      reviewed_by: uid,
      reviewed_by_name: displayNameForUser(user),
      reviewed_by_role: isAdmin ? 'admin' : 'teacher',
      reviewed_at: timestamp,
    };
    transaction.update(questionRef, {
      status,
      ...reviewer,
      ...(status === 'approved' ? {
        approved_by: uid,
        approved_by_name: displayNameForUser(user),
        approved_by_role: isAdmin ? 'admin' : 'teacher',
        approved_at: timestamp,
        student_notification_pending_at: timestamp,
      } : {
        rejected_by: uid,
        rejected_by_name: displayNameForUser(user),
        rejected_by_role: isAdmin ? 'admin' : 'teacher',
        rejected_at: timestamp,
        rejection_reason: rejectionReason,
      }),
    });
    transaction.create(reviewRef, {
      question_id: questionId,
      status,
      reviewer_uid: uid,
      reviewer_name: displayNameForUser(user),
      reviewer_role: isAdmin ? 'admin' : 'teacher',
      reviewed_at: timestamp,
      ...(status === 'rejected' ? {rejection_reason: rejectionReason} : {}),
    });
  });
  return {questionId, status, reviewerUid: uid, reviewerRole: isAdmin ? 'admin' : 'teacher'};
});

const setQuizReviewers = onCall({region: 'us-central1', memory: '256MiB'}, async (request) => {
  const {db, uid, isAdmin} = await requireReviewer(request);
  if (!isAdmin) throw new HttpsError('permission-denied', 'Admin access required');
  const reviewerTeacherIds = reviewerIdsFromSettings({
    reviewer_teacher_ids: request.data?.reviewerTeacherIds,
  });
  const profiles = await Promise.all(reviewerTeacherIds.map((id) =>
    db.collection('users').doc(id).get()));
  if (profiles.some((profile) => !profile.exists ||
    !isTeacherUser(profile.data() || {}) || profile.data()?.is_active === false)) {
    throw new HttpsError('invalid-argument', 'Every reviewer must be an active teacher');
  }
  await db.collection(SETTINGS_COLLECTION).doc(SETTINGS_DOCUMENT).set({
    reviewer_teacher_ids: reviewerTeacherIds,
    updated_by: uid,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {reviewerTeacherIds};
});

const sendPendingReviewBatch = async () => {
  const db = admin.firestore();
  const [settingsSnapshot, questionsSnapshot] = await Promise.all([
    db.collection(SETTINGS_COLLECTION).doc(SETTINGS_DOCUMENT).get(),
    db.collection(QUESTIONS_COLLECTION).where('status', '==', 'pending').get(),
  ]);
  const reviewerIds = reviewerIdsFromSettings(settingsSnapshot.data() || {});
  const questions = questionsSnapshot.docs.filter((doc) => !doc.data().reviewer_notification_sent_at);
  if (reviewerIds.length === 0 || questions.length === 0) {
    return {questionCount: questions.length, recipientCount: 0};
  }
  const reviewers = await Promise.all(reviewerIds.map((uid) => db.collection('users').doc(uid).get()));
  const tokens = tokenSetForUsers(reviewers, 'quizReviewEnabled');
  const delivery = await sendToTokens({
    tokens,
    title: 'Quiz questions ready for review',
    body: `${questions.length} new question${questions.length === 1 ? '' : 's'} need your review.`,
    data: {type: 'quiz_review_batch', questionCount: String(questions.length)},
  });
  const batch = db.batch();
  questions.forEach((doc) => batch.update(doc.ref, {
    reviewer_notification_sent_at: admin.firestore.FieldValue.serverTimestamp(),
    reviewer_notification_success_count: delivery.successCount,
  }));
  await batch.commit();
  return {questionCount: questions.length, recipientCount: tokens.length, ...delivery};
};

const sendStudentApprovalBatch = async () => {
  const db = admin.firestore();
  const [questionsSnapshot, studentsSnapshot] = await Promise.all([
    db.collection(QUESTIONS_COLLECTION).where('status', '==', 'approved').get(),
    db.collection('users').where('user_type', '==', 'student').get(),
  ]);
  const questions = questionsSnapshot.docs.filter((doc) => !doc.data().students_notified_at);
  if (questions.length === 0) return {questionCount: 0, recipientCount: 0};
  const tokens = tokenSetForUsers(studentsSnapshot.docs, 'quizEnabled');
  const delivery = await sendToTokens({
    tokens,
    title: 'New quiz questions are ready',
    body: `${questions.length} new question${questions.length === 1 ? '' : 's'} are ready for this month’s Bayannah challenge.`,
    data: {type: 'quiz_questions_approved_batch', questionCount: String(questions.length)},
  });
  const batch = db.batch();
  questions.forEach((doc) => batch.update(doc.ref, {
    students_notified_at: admin.firestore.FieldValue.serverTimestamp(),
    student_notification_success_count: delivery.successCount,
    student_notification_failure_count: delivery.failureCount,
  }));
  await batch.commit();
  return {questionCount: questions.length, recipientCount: tokens.length, ...delivery};
};

const sendQuizReviewBatchNow = onCall({region: 'us-central1', memory: '256MiB'}, async (request) => {
  const {isAdmin} = await requireReviewer(request);
  if (!isAdmin) throw new HttpsError('permission-denied', 'Admin access required');
  return sendPendingReviewBatch();
});

const sendQuizStudentApprovalBatchNow = onCall({region: 'us-central1', memory: '256MiB'}, async (request) => {
  const {isAdmin} = await requireReviewer(request);
  if (!isAdmin) throw new HttpsError('permission-denied', 'Admin access required');
  return sendStudentApprovalBatch();
});

const sendQuizReviewBatchesHourly = onSchedule({
  schedule: 'every 60 minutes',
  timeZone: 'America/New_York',
  region: 'us-central1',
}, async () => sendPendingReviewBatch());

const sendQuizStudentApprovalBatchesHourly = onSchedule({
  schedule: 'every 60 minutes',
  timeZone: 'America/New_York',
  region: 'us-central1',
}, async () => sendStudentApprovalBatch());

module.exports = {
  getQuizReviewQueue,
  reviewQuizQuestion,
  setQuizReviewers,
  sendQuizReviewBatchNow,
  sendQuizStudentApprovalBatchNow,
  sendQuizReviewBatchesHourly,
  sendQuizStudentApprovalBatchesHourly,
  __test__: {
    reviewerIdsFromSettings,
    rejectionReasonFor,
    tokenSetForUsers,
    chunksOf,
  },
};
