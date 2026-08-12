const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentUpdated} = require('firebase-functions/v2/firestore');

const bundledAnswerKey = require('../data/quiz_answer_key.json');

const TIME_ZONE = 'America/New_York';
const MINIMUM_QUESTIONS = 20;
const MINIMUM_ACTIVE_DAYS = 3;
const MAX_LEADERBOARD_SIZE = 10;

const roleValue = (data = {}) => String(
  data.user_type || data.userType || data.role || '',
).trim().toLowerCase();

const isAdminUser = (data = {}) => {
  const role = roleValue(data);
  return role === 'admin' || role === 'super_admin' ||
    data.is_admin === true || data.isAdmin === true;
};

const isStudentUser = (data = {}) => roleValue(data) === 'student';

const monthKeyForDate = (date = new Date()) => DateTime
  .fromJSDate(date, {zone: 'utc'})
  .setZone(TIME_ZONE)
  .toFormat('yyyy-MM');

const dateKeyForDate = (date = new Date()) => DateTime
  .fromJSDate(date, {zone: 'utc'})
  .setZone(TIME_ZONE)
  .toFormat('yyyy-MM-dd');

const parseMonthKey = (value) => {
  const monthKey = String(value || '').trim();
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(monthKey)) return null;
  const start = DateTime.fromFormat(monthKey, 'yyyy-MM', {zone: TIME_ZONE});
  return start.isValid ? {monthKey, start, end: start.plus({months: 1})} : null;
};

const displayNameForUser = (data = {}) => {
  const first = String(data.first_name || data.firstName || '').trim();
  const last = String(data.last_name || data.lastName || '').trim();
  if (first && last) return `${first} ${last.charAt(0).toUpperCase()}.`;
  return first || String(data.display_name || data.displayName || 'Student').trim();
};

const resolveBundledAnswer = ({questionId, categoryId}) => {
  const bank = bundledAnswerKey[categoryId];
  if (!bank) return null;
  const match = String(questionId || '').match(/^([a-z]{2})_(\d{3})$/);
  if (!match || match[1] !== bank.prefix) return null;
  const index = Number(match[2]) - 1;
  if (index < 0 || index >= bank.answers.length) return null;
  return bank.answers[index];
};

0
const accuracyForEntry = (entry) => {
  const answered = Number(entry.unique_answered_count || 0);
  return answered > 0 ? Number(entry.correct_answer_count || 0) / answered : 0;
};

const activeDayCount = (entry) => Array.isArray(entry.active_days)
  ? new Set(entry.active_days).size
  : Number(entry.active_day_count || 0);

const isEligibleEntry = (entry) =>
  Number(entry.unique_answered_count || 0) >= MINIMUM_QUESTIONS &&
  activeDayCount(entry) >= MINIMUM_ACTIVE_DAYS;

const timeMillis = (value) => {
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(String(value || ''));
  return Number.isFinite(parsed) ? parsed : Number.MAX_SAFE_INTEGER;
};

const rankEntries = (entries) => entries
  .map((entry) => ({...entry, eligible: isEligibleEntry(entry)}))
  .sort((a, b) =>
    Number(b.unique_answered_count || 0) - Number(a.unique_answered_count || 0) ||
    Number(b.correct_answer_count || 0) - Number(a.correct_answer_count || 0) ||
    accuracyForEntry(b) - accuracyForEntry(a) ||
    activeDayCount(b) - activeDayCount(a) ||
    timeMillis(a.score_reached_at) - timeMillis(b.score_reached_at) ||
    String(a.uid || '').localeCompare(String(b.uid || '')))
  .map((entry, index) => ({...entry, rank: index + 1}));

const publicEntry = (entry) => ({
  uid: entry.uid,
  displayName: entry.display_name || 'Student',
  answeredCount: Number(entry.unique_answered_count || 0),
  correctCount: Number(entry.correct_answer_count || 0),
  accuracy: accuracyForEntry(entry),
  activeDays: activeDayCount(entry),
  eligible: entry.eligible === true,
  rank: entry.rank,
});

const requireUser = async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required');
  const snapshot = await admin.firestore().collection('users').doc(uid).get();
  if (!snapshot.exists) throw new HttpsError('permission-denied', 'User profile not found');
  return {uid, data: snapshot.data() || {}};
};

const resolveCorrectAnswer = async ({db, questionId, categoryId}) => {
  const bundled = resolveBundledAnswer({questionId, categoryId});
  if (bundled !== null) return bundled;

  const snapshot = await db.collection('quiz_questions').doc(questionId).get();
  const data = snapshot.data() || {};
  if (!snapshot.exists || data.status !== 'approved' || data.category !== categoryId) {
    return null;
  }
  const answer = Number(data.correctAnswer);
  return Number.isInteger(answer) && answer >= 0 && answer <= 3 ? answer : null;
};

const recordQuizCompetitionAnswer = onCall({
  region: 'us-central1',
  memory: '256MiB',
}, async (request) => {
  const {uid, data: userData} = await requireUser(request);
  if (!isStudentUser(userData)) {
    throw new HttpsError('permission-denied', 'Student access required');
  }

  const questionId = String(request.data?.questionId || '').trim();
  const categoryId = String(request.data?.categoryId || '').trim();
  const selectedAnswerIndex = Number(request.data?.selectedAnswerIndex);
  if (!questionId || !categoryId || !Number.isInteger(selectedAnswerIndex) ||
      selectedAnswerIndex < 0 || selectedAnswerIndex > 3) {
    throw new HttpsError('invalid-argument', 'Valid question and answer are required');
  }

  const db = admin.firestore();
  const correctAnswer = await resolveCorrectAnswer({db, questionId, categoryId});
  if (correctAnswer === null) {
    throw new HttpsError('failed-precondition', 'Question is not available for competition');
  }

  const now = new Date();
  const monthKey = monthKeyForDate(now);
  const dateKey = dateKeyForDate(now);
  const competitionRef = db.collection('quiz_competitions').doc(monthKey);
  const entryRef = competitionRef.collection('students').doc(uid);
  const answerRef = entryRef.collection('answers').doc(questionId);
  const isCorrect = selectedAnswerIndex === correctAnswer;

  const result = await db.runTransaction(async (transaction) => {
    const [competitionSnapshot, entrySnapshot, answerSnapshot] = await Promise.all([
      transaction.get(competitionRef),
      transaction.get(entryRef),
      transaction.get(answerRef),
    ]);
    if (competitionSnapshot.data()?.status === 'finalized') {
      throw new HttpsError('failed-precondition', 'This monthly competition is closed');
    }
    const existing = entrySnapshot.data() || {};
    if (answerSnapshot.exists) {
      return {
        counted: false,
        answeredCount: Number(existing.unique_answered_count || 0),
        correctCount: Number(existing.correct_answer_count || 0),
      };
    }

    const answeredCount = Number(existing.unique_answered_count || 0) + 1;
    const correctCount = Number(existing.correct_answer_count || 0) + (isCorrect ? 1 : 0);
    const activeDays = new Set(Array.isArray(existing.active_days) ? existing.active_days : []);
    activeDays.add(dateKey);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    transaction.set(competitionRef, {
      month_key: monthKey,
      status: 'open',
      timezone: TIME_ZONE,
      updated_at: timestamp,
      rules: {
        minimum_questions: MINIMUM_QUESTIONS,
        minimum_active_days: MINIMUM_ACTIVE_DAYS,
        unique_questions_only: true,
      },
    }, {merge: true});
    transaction.set(entryRef, {
      uid,
      display_name: displayNameForUser(userData),
      unique_answered_count: answeredCount,
      correct_answer_count: correctCount,
      active_days: Array.from(activeDays).sort(),
      active_day_count: activeDays.size,
      score_reached_at: timestamp,
      first_answered_at: existing.first_answered_at || timestamp,
      last_answered_at: timestamp,
    }, {merge: true});
    transaction.create(answerRef, {
      question_id: questionId,
      category_id: categoryId,
      selected_answer_index: selectedAnswerIndex,
      correct_answer_index: correctAnswer,
      is_correct: isCorrect,
      answered_at: timestamp,
      date_key: dateKey,
    });
    return {counted: true, answeredCount, correctCount};
  });

  return {...result, isCorrect, monthKey};
});

const getQuizCompetitionLeaderboard = onCall({
  region: 'us-central1',
  memory: '256MiB',
}, async (request) => {
  const {uid, data: userData} = await requireUser(request);
  if (!isStudentUser(userData) && !isAdminUser(userData)) {
    throw new HttpsError('permission-denied', 'Student or admin access required');
  }
  const parsed = parseMonthKey(request.data?.monthKey || monthKeyForDate());
  if (!parsed) throw new HttpsError('invalid-argument', 'Month must use YYYY-MM');

  const competitionRef = admin.firestore().collection('quiz_competitions').doc(parsed.monthKey);
  const [competitionSnapshot, entriesSnapshot] = await Promise.all([
    competitionRef.get(),
    competitionRef.collection('students').get(),
  ]);
  const ranked = rankEntries(entriesSnapshot.docs.map((doc) => ({uid: doc.id, ...doc.data()})));
  const self = ranked.find((entry) => entry.uid === uid);
  const competition = competitionSnapshot.data() || {};
  return {
    monthKey: parsed.monthKey,
    timezone: TIME_ZONE,
    status: competition.status || 'open',
    minimumQuestions: MINIMUM_QUESTIONS,
    minimumActiveDays: MINIMUM_ACTIVE_DAYS,
    leaderboard: ranked.slice(0, MAX_LEADERBOARD_SIZE).map(publicEntry),
    self: self ? publicEntry(self) : null,
    winner: competition.winner || null,
  };
});

const finalizeQuizCompetition = onCall({
  region: 'us-central1',
  memory: '256MiB',
}, async (request) => {
  const {uid, data: userData} = await requireUser(request);
  if (!isAdminUser(userData)) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }
  const parsed = parseMonthKey(request.data?.monthKey);
  if (!parsed) throw new HttpsError('invalid-argument', 'Month must use YYYY-MM');

  const now = DateTime.now().setZone(TIME_ZONE);
  const reason = String(request.data?.overrideReason || '').trim();
  if (now < parsed.end && reason.length < 10) {
    throw new HttpsError(
      'failed-precondition',
      'Closing a competition before month end requires a reason',
    );
  }

  const db = admin.firestore();
  const competitionRef = db.collection('quiz_competitions').doc(parsed.monthKey);
  const [competitionSnapshot, entriesSnapshot] = await Promise.all([
    competitionRef.get(),
    competitionRef.collection('students').get(),
  ]);
  const current = competitionSnapshot.data() || {};
  if (current.status === 'finalized' && reason.length < 10) {
    throw new HttpsError('already-exists', 'Competition is already finalized');
  }

  const ranked = rankEntries(entriesSnapshot.docs.map((doc) => ({uid: doc.id, ...doc.data()})));
  const eligible = ranked.filter((entry) => entry.eligible);
  const requestedWinnerUid = String(request.data?.overrideWinnerUid || '').trim();
  let winner = eligible[0] || null;
  if (requestedWinnerUid) {
    winner = eligible.find((entry) => entry.uid === requestedWinnerUid) || null;
    if (!winner) {
      throw new HttpsError('failed-precondition', 'Override winner is not eligible');
    }
    if (reason.length < 10) {
      throw new HttpsError('invalid-argument', 'Winner override requires a reason');
    }
  }

  const winnerData = winner ? publicEntry(winner) : null;
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  const revisionRef = competitionRef.collection('finalization_history').doc();
  const batch = db.batch();
  batch.set(revisionRef, {
    previous_winner: current.winner || null,
    winner: winnerData,
    reason: reason || null,
    finalized_by: uid,
    finalized_at: timestamp,
  });
  batch.set(competitionRef, {
    month_key: parsed.monthKey,
    status: 'finalized',
    timezone: TIME_ZONE,
    winner: winnerData,
    eligible_student_count: eligible.length,
    participant_count: ranked.length,
    finalized_by: uid,
    finalized_at: timestamp,
    finalization_reason: reason || null,
    rules: {
      minimum_questions: MINIMUM_QUESTIONS,
      minimum_active_days: MINIMUM_ACTIVE_DAYS,
      unique_questions_only: true,
      ranking_order: ['unique_answers', 'correct_answers', 'accuracy', 'active_days', 'earliest_score'],
    },
  }, {merge: true});
  await batch.commit();
  return {monthKey: parsed.monthKey, winner: winnerData, eligibleCount: eligible.length};
});

const tokenGroupsForStudents = (docs) => {
  const groups = {en: new Set(), fr: new Set()};
  for (const doc of docs) {
    const data = typeof doc.data === 'function' ? doc.data() : doc;
    if (!isStudentUser(data) || data.notificationPreferences?.quizEnabled === false) continue;
    const language = data.language_preference === 'fr' ? 'fr' : 'en';
    const tokens = Array.isArray(data.fcmTokens)
      ? data.fcmTokens.map((entry) => entry?.token).filter(Boolean)
      : [];
    if (tokens.length === 0 && data.fcmToken) tokens.push(data.fcmToken);
    tokens.forEach((token) => groups[language].add(String(token)));
  }
  return {en: Array.from(groups.en), fr: Array.from(groups.fr)};
};

const chunksOf = (values, size = 500) => {
  const chunks = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
};

const onQuizQuestionApproved = onDocumentUpdated({
  document: 'quiz_questions/{questionId}',
  region: 'us-central1',
  memory: '256MiB',
}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (before.status === 'approved' || after.status !== 'approved' ||
      after.students_notified_at) return null;

  const users = await admin.firestore().collection('users')
    .where('user_type', '==', 'student').get();
  const groups = tokenGroupsForStudents(users.docs);
  const category = String(after.category || 'quiz');
  const messages = {
    en: {
      title: 'New quiz question available',
      body: 'A new question was added. Play this month’s Bayannah challenge!',
    },
    fr: {
      title: 'Nouvelle question de quiz',
      body: 'Une nouvelle question a été ajoutée. Participe au défi Bayannah du mois !',
    },
  };

  let successCount = 0;
  let failureCount = 0;
  for (const language of Object.keys(groups)) {
    for (const tokens of chunksOf(groups[language])) {
      if (tokens.length === 0) continue;
      const response = await admin.messaging().sendEachForMulticast({
        notification: messages[language],
        data: {
          type: 'quiz_question_added',
          questionId: String(event.params.questionId),
          category,
        },
        tokens,
        android: {
          priority: 'high',
          notification: {sound: 'default', channelId: 'high_importance_channel'},
        },
        apns: {payload: {aps: {sound: 'default', badge: 1}}},
      });
      successCount += response.successCount;
      failureCount += response.failureCount;
    }
  }

  await event.data.after.ref.update({
    students_notified_at: admin.firestore.FieldValue.serverTimestamp(),
    student_notification_success_count: successCount,
    student_notification_failure_count: failureCount,
  });
  return {successCount, failureCount};
});

module.exports = {
  recordQuizCompetitionAnswer,
  getQuizCompetitionLeaderboard,
  finalizeQuizCompetition,
  onQuizQuestionApproved,
  __test__: {
    MINIMUM_QUESTIONS,
    MINIMUM_ACTIVE_DAYS,
    TIME_ZONE,
    monthKeyForDate,
    dateKeyForDate,
    parseMonthKey,
    displayNameForUser,
    resolveBundledAnswer,
    accuracyForEntry,
    activeDayCount,
    isEligibleEntry,
    rankEntries,
    publicEntry,
    tokenGroupsForStudents,
    chunksOf,
  },
};
