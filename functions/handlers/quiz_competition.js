const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentUpdated} = require('firebase-functions/v2/firestore');

const bundledAnswerKey = require('../data/quiz_answer_key.json');

const TIME_ZONE = 'America/New_York';
const MINIMUM_QUESTIONS = 20;
const MINIMUM_ACTIVE_DAYS = 3;
const MINIMUM_ACCURACY = 0.5;
const MINIMUM_ELIGIBLE_PARTICIPANTS = 2;
const MAX_LEADERBOARD_SIZE = 10;
const UNASSIGNED_DIVISION = 'unassigned';
const REQUIRED_CATEGORY_IDS = Object.freeze(Object.keys(bundledAnswerKey).sort());
const DIVISIONS = Object.freeze([
  {id: 'early_learners', minimumAge: 0, maximumAge: 7},
  {id: 'juniors', minimumAge: 8, maximumAge: 11},
  {id: 'youth', minimumAge: 12, maximumAge: 17},
  {id: 'adults', minimumAge: 18, maximumAge: 120},
]);
const DIVISION_IDS = new Set(DIVISIONS.map((division) => division.id));

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

const dateKeyForDateTime = (value) => value.toFormat('yyyy-MM-dd');

const parseMonthKey = (value) => {
  const monthKey = String(value || '').trim();
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(monthKey)) return null;
  const start = DateTime.fromFormat(monthKey, 'yyyy-MM', {zone: TIME_ZONE});
  return start.isValid ? {monthKey, start, end: start.plus({months: 1})} : null;
};

const countingWindowForCompetition = (competition = {}, monthKey = monthKeyForDate()) => {
  const parsed = parseMonthKey(monthKey);
  if (!parsed) return null;
  const defaultStart = dateKeyForDateTime(parsed.start);
  const defaultEnd = dateKeyForDateTime(parsed.end.minus({days: 1}));
  const start = String(competition.rules?.counting_starts_on || defaultStart);
  const end = String(competition.rules?.counting_ends_on || defaultEnd);
  const valid = (value) => {
    const date = DateTime.fromFormat(value, 'yyyy-MM-dd', {zone: TIME_ZONE});
    return date.isValid && dateKeyForDateTime(date) === value &&
      value >= defaultStart && value <= defaultEnd;
  };
  if (!valid(start) || !valid(end) || start > end) {
    return {startDate: defaultStart, endDate: defaultEnd};
  }
  return {startDate: start, endDate: end};
};

const normalizeDivisionId = (value, {allowUnassigned = true} = {}) => {
  const divisionId = String(value || '').trim().toLowerCase();
  if (DIVISION_IDS.has(divisionId)) return divisionId;
  return allowUnassigned && divisionId === UNASSIGNED_DIVISION
    ? UNASSIGNED_DIVISION
    : null;
};

const divisionForAge = (value) => {
  if (value === null || value === undefined || String(value).trim() === '') return null;
  const age = Number(value);
  if (!Number.isFinite(age) || age < 0 || age > 120) return null;
  return DIVISIONS.find((division) =>
    age >= division.minimumAge && age <= division.maximumAge)?.id || null;
};

const dateTimeFromProfileValue = (value) => {
  if (!value) return null;
  if (typeof value.toDate === 'function') {
    return DateTime.fromJSDate(value.toDate(), {zone: TIME_ZONE});
  }
  if (value instanceof Date) return DateTime.fromJSDate(value, {zone: TIME_ZONE});
  const parsed = DateTime.fromISO(String(value), {zone: TIME_ZONE});
  return parsed.isValid ? parsed : null;
};

const ageAtMonthStart = (birthDateValue, monthKey) => {
  const parsedMonth = parseMonthKey(monthKey);
  const birthDate = dateTimeFromProfileValue(birthDateValue);
  if (!parsedMonth || !birthDate || birthDate > parsedMonth.start) return null;
  let age = parsedMonth.start.year - birthDate.year;
  if (parsedMonth.start.month < birthDate.month ||
      (parsedMonth.start.month === birthDate.month &&
       parsedMonth.start.day < birthDate.day)) age -= 1;
  return age >= 0 && age <= 120 ? age : null;
};

const ageAtMonthStartFromMonthYear = (birthMonthValue, birthYearValue, monthKey) => {
  const parsedMonth = parseMonthKey(monthKey);
  const birthMonth = Number(birthMonthValue);
  const birthYear = Number(birthYearValue);
  if (!parsedMonth || !Number.isInteger(birthMonth) || birthMonth < 1 ||
      birthMonth > 12 || !Number.isInteger(birthYear)) return null;
  let age = parsedMonth.start.year - birthYear;
  if (parsedMonth.start.month <= birthMonth) age -= 1;
  return age >= 0 && age <= 120 ? age : null;
};

const divisionForUser = (data = {}, monthKey = monthKeyForDate()) => {
  const explicit = normalizeDivisionId(
    data.quiz_competition_division || data.quizCompetitionDivision,
    {allowUnassigned: false},
  );
  const validThrough = String(
    data.quiz_competition_division_valid_through ||
    data.quizCompetitionDivisionValidThrough || '',
  );
  if (explicit && /^\d{4}-\d{2}$/.test(validThrough) && validThrough >= monthKey) {
    return {id: explicit, source: 'admin_assignment'};
  }

  const birthDate = data.date_of_birth || data.dateOfBirth ||
    data.birth_date || data.birthDate || data.dob;
  const birthDateAge = ageAtMonthStart(birthDate, monthKey);
  const birthDateDivision = divisionForAge(birthDateAge);
  if (birthDateDivision) {
    return {id: birthDateDivision, source: 'birth_date', age: birthDateAge};
  }

  const approximateAge = ageAtMonthStartFromMonthYear(
    data.quiz_competition_birth_month || data.quizCompetitionBirthMonth,
    data.quiz_competition_birth_year || data.quizCompetitionBirthYear,
    monthKey,
  );
  const approximateDivision = divisionForAge(approximateAge);
  if (approximateDivision) {
    return {
      id: approximateDivision,
      source: 'student_birth_month_year',
      age: approximateAge,
    };
  }

  const recordedAge = data.age ?? data.student_age ?? data.studentAge;
  const ageDivision = divisionForAge(recordedAge);
  if (ageDivision) {
    return {id: ageDivision, source: 'recorded_age', age: Number(recordedAge)};
  }
  if (data.is_adult_student === true || data.isAdultStudent === true) {
    return {id: 'adults', source: 'adult_account_flag'};
  }
  return {id: UNASSIGNED_DIVISION, source: 'unassigned'};
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

const accuracyForEntry = (entry) => {
  const answered = Number(entry.unique_answered_count || 0);
  return answered > 0 ? Number(entry.correct_answer_count || 0) / answered : 0;
};

const activeDayCount = (entry) => Array.isArray(entry.active_days)
  ? new Set(entry.active_days).size
  : Number(entry.active_day_count || 0);

const normalizedRequiredCategoryIds = (value) => {
  const ids = Array.isArray(value) ? value : [];
  const valid = new Set(ids.map((id) => String(id || '').trim())
    .filter((id) => REQUIRED_CATEGORY_IDS.includes(id)));
  return REQUIRED_CATEGORY_IDS.filter((id) => valid.has(id));
};

const requiredCategoryIdsForCompetition = (competition = {}) => {
  const stored = normalizedRequiredCategoryIds(
    competition.rules?.required_category_ids,
  );
  return stored.length > 0 ? stored : REQUIRED_CATEGORY_IDS;
};

const attemptedCategoryIds = (entry = {}) => new Set(
  (Array.isArray(entry.attempted_category_ids)
    ? entry.attempted_category_ids
    : [])
    .map((id) => String(id || '').trim())
    .filter((id) => REQUIRED_CATEGORY_IDS.includes(id)),
);

const hasRequiredCategoryCoverage = (entry, requiredCategoryIds = REQUIRED_CATEGORY_IDS) => {
  const attempted = attemptedCategoryIds(entry);
  return requiredCategoryIds.every((categoryId) => attempted.has(categoryId));
};

const categoryInsightsForAnswers = (answers = []) => {
  const totals = new Map(REQUIRED_CATEGORY_IDS.map((categoryId) => [categoryId, {
    categoryId,
    answeredCount: 0,
    correctCount: 0,
  }]));
  answers.forEach((answer) => {
    const data = typeof answer.data === 'function' ? answer.data() : answer;
    const categoryId = String(data?.category_id || '').trim();
    const total = totals.get(categoryId);
    if (!total) return;
    total.answeredCount += 1;
    total.correctCount += data?.is_correct === true ? 1 : 0;
  });
  return Array.from(totals.values()).map((total) => ({
    ...total,
    accuracy: total.answeredCount > 0 ? total.correctCount / total.answeredCount : 0,
  }));
};

const lifetimeWinsForCompetitions = (competitions = [], uid) => competitions.reduce(
  (wins, competition) => {
    const data = typeof competition.data === 'function' ? competition.data() : competition;
    const divisionResults = data?.division_results || {};
    const isWinner = Object.values(divisionResults).some((result) =>
      Array.isArray(result?.winners) && result.winners.some((winner) => winner?.uid === uid));
    return wins + (isWinner ? 1 : 0);
  },
  0,
);

const isEligibleEntry = (entry, requiredCategoryIds = REQUIRED_CATEGORY_IDS) => {
  const divisionId = normalizeDivisionId(entry.division_id);
  return DIVISION_IDS.has(divisionId) &&
    Number(entry.unique_answered_count || 0) >= MINIMUM_QUESTIONS &&
    activeDayCount(entry) >= MINIMUM_ACTIVE_DAYS &&
    accuracyForEntry(entry) >= MINIMUM_ACCURACY &&
    hasRequiredCategoryCoverage(entry, requiredCategoryIds) &&
    entry.disqualified !== true;
};

const compareScores = (a, b) =>
  Number(b.unique_answered_count || 0) - Number(a.unique_answered_count || 0) ||
  Number(b.correct_answer_count || 0) - Number(a.correct_answer_count || 0) ||
  activeDayCount(b) - activeDayCount(a);

const sameScore = (a, b) => compareScores(a, b) === 0;

const rankEntries = (entries, requiredCategoryIds = REQUIRED_CATEGORY_IDS) => {
  const sorted = entries
    .map((entry) => ({
      ...entry,
      eligible: isEligibleEntry(entry, requiredCategoryIds),
    }))
    .sort((a, b) => compareScores(a, b) ||
      String(a.display_name || '').localeCompare(String(b.display_name || '')) ||
      String(a.uid || '').localeCompare(String(b.uid || '')));
  let rank = 0;
  return sorted.map((entry, index) => {
    if (index === 0 || !sameScore(entry, sorted[index - 1])) rank = index + 1;
    return {...entry, rank};
  });
};

const publicEntry = (entry) => ({
  uid: entry.uid,
  displayName: entry.display_name || 'Student',
  answeredCount: Number(entry.unique_answered_count || 0),
  correctCount: Number(entry.correct_answer_count || 0),
  accuracy: accuracyForEntry(entry),
  activeDays: activeDayCount(entry),
  categoriesAttemptedCount: attemptedCategoryIds(entry).size,
  divisionId: normalizeDivisionId(entry.division_id) || UNASSIGNED_DIVISION,
  eligible: entry.eligible === true,
  rank: entry.rank,
});

const timestampMillis = (value) => {
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(String(value || ''));
  return Number.isFinite(parsed) ? parsed : null;
};

const engagementStatus = (
  entry,
  now = new Date(),
  requiredCategoryIds = REQUIRED_CATEGORY_IDS,
) => {
  if (!entry || Number(entry.unique_answered_count || 0) === 0) return 'not_started';
  if (isEligibleEntry(entry, requiredCategoryIds)) return 'qualified';
  const lastAnswered = timestampMillis(entry.last_answered_at);
  if (lastAnswered !== null && now.getTime() - lastAnswered >= 7 * 24 * 60 * 60 * 1000) {
    return 'needs_encouragement';
  }
  return 'participating';
};

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
  if (userData.is_active === false) {
    throw new HttpsError('permission-denied', 'Active student account required');
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
    const countingWindow = countingWindowForCompetition(
      competitionSnapshot.data() || {},
      monthKey,
    );
    if (dateKey < countingWindow.startDate || dateKey > countingWindow.endDate) {
      return {
        counted: false,
        outsideCompetitionWindow: true,
        countingStartDate: countingWindow.startDate,
        countingEndDate: countingWindow.endDate,
      };
    }
    const existing = entrySnapshot.data() || {};
    const requiredCategoryIds = requiredCategoryIdsForCompetition(
      competitionSnapshot.data() || {},
    );
    const existingDivision = normalizeDivisionId(existing.division_id);
    const resolvedDivision = existingDivision && existingDivision !== UNASSIGNED_DIVISION
      ? {id: existingDivision, source: existing.division_source || 'monthly_lock'}
      : divisionForUser(userData, monthKey);
    if (answerSnapshot.exists) {
      return {
        counted: false,
        answeredCount: Number(existing.unique_answered_count || 0),
        correctCount: Number(existing.correct_answer_count || 0),
        divisionId: resolvedDivision.id,
      };
    }

    const answeredCount = Number(existing.unique_answered_count || 0) + 1;
    const correctCount = Number(existing.correct_answer_count || 0) + (isCorrect ? 1 : 0);
    const activeDays = new Set(Array.isArray(existing.active_days) ? existing.active_days : []);
    activeDays.add(dateKey);
    const categories = attemptedCategoryIds(existing);
    categories.add(categoryId);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    transaction.set(competitionRef, {
      month_key: monthKey,
      status: 'open',
      timezone: TIME_ZONE,
      updated_at: timestamp,
      rules: {
        minimum_questions: MINIMUM_QUESTIONS,
        minimum_active_days: MINIMUM_ACTIVE_DAYS,
        minimum_accuracy: MINIMUM_ACCURACY,
        minimum_eligible_participants: MINIMUM_ELIGIBLE_PARTICIPANTS,
        unique_questions_only: true,
        required_category_ids: requiredCategoryIds,
        counting_starts_on: countingWindow.startDate,
        counting_ends_on: countingWindow.endDate,
        age_divisions: DIVISIONS,
        co_winners_for_exact_ties: true,
      },
    }, {merge: true});
    transaction.set(entryRef, {
      uid,
      display_name: displayNameForUser(userData),
      unique_answered_count: answeredCount,
      correct_answer_count: correctCount,
      active_days: Array.from(activeDays).sort(),
      active_day_count: activeDays.size,
      attempted_category_ids: Array.from(categories).sort(),
      division_id: resolvedDivision.id,
      division_source: resolvedDivision.source,
      division_age_snapshot: resolvedDivision.age ?? null,
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
    return {
      counted: true,
      answeredCount,
      correctCount,
      categoriesAttemptedCount: categories.size,
      divisionId: resolvedDivision.id,
    };
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

  const db = admin.firestore();
  const competitionRef = db.collection('quiz_competitions').doc(parsed.monthKey);
  const adminView = isAdminUser(userData);
  const [competitionSnapshot, entriesSnapshot, studentProfilesSnapshot] = await Promise.all([
    competitionRef.get(),
    competitionRef.collection('students').get(),
    adminView
      ? db.collection('users').where('user_type', '==', 'student').get()
      : Promise.resolve(null),
  ]);
  const entries = entriesSnapshot.docs.map((doc) => ({uid: doc.id, ...doc.data()}));
  const ownEntry = entries.find((entry) => entry.uid === uid);
  const [ownAnswersSnapshot, competitionsSnapshot] = adminView || !ownEntry
    ? [null, null]
    : await Promise.all([
      competitionRef.collection('students').doc(uid).collection('answers').get(),
      db.collection('quiz_competitions').get(),
    ]);
  const ownDivision = normalizeDivisionId(ownEntry?.division_id) ||
    divisionForUser(userData, parsed.monthKey).id;
  const requestedDivision = normalizeDivisionId(request.data?.divisionId);
  const divisionId = isAdminUser(userData)
    ? requestedDivision || DIVISIONS[0].id
    : ownDivision;
  const competition = competitionSnapshot.data() || {};
  const requiredCategoryIds = requiredCategoryIdsForCompetition(competition);
  const countingWindow = countingWindowForCompetition(competition, parsed.monthKey);
  const categoryInsights = ownAnswersSnapshot
    ? categoryInsightsForAnswers(ownAnswersSnapshot.docs)
    : [];
  const lifetimeWins = competitionsSnapshot
    ? lifetimeWinsForCompetitions(competitionsSnapshot.docs, uid)
    : 0;
  const ranked = rankEntries(entries.filter((entry) =>
    (normalizeDivisionId(entry.division_id) || UNASSIGNED_DIVISION) === divisionId,
  ), requiredCategoryIds);
  const self = divisionId === ownDivision
    ? ranked.find((entry) => entry.uid === uid)
    : null;
  const selfIndex = self ? ranked.findIndex((entry) => entry.uid === uid) : -1;
  const divisionResult = competition.division_results?.[divisionId] || {};
  const winners = Array.isArray(divisionResult.winners)
    ? divisionResult.winners
    : (competition.winner && competition.winner.divisionId === divisionId
        ? [competition.winner]
        : []);
  const divisionIds = [...DIVISIONS.map((division) => division.id), UNASSIGNED_DIVISION];
  const divisions = divisionIds.map((id) => {
    const divisionEntries = entries.filter((entry) =>
      (normalizeDivisionId(entry.division_id) || UNASSIGNED_DIVISION) === id);
    return {
      id,
      participantCount: divisionEntries.length,
      eligibleCount: divisionEntries.filter((entry) =>
        isEligibleEntry(entry, requiredCategoryIds)).length,
      winnerCount: Array.isArray(competition.division_results?.[id]?.winners)
        ? competition.division_results[id].winners.length
        : 0,
    };
  });
  const engagement = adminView
    ? studentProfilesSnapshot.docs
      .map((doc) => {
        const profile = doc.data() || {};
        const entry = entries.find((candidate) => candidate.uid === doc.id);
        const profileDivision = normalizeDivisionId(entry?.division_id) ||
          divisionForUser(profile, parsed.monthKey).id;
        return {
          uid: doc.id,
          displayName: [profile.first_name, profile.last_name]
            .map((part) => String(part || '').trim())
            .filter(Boolean)
            .join(' ') || displayNameForUser(profile),
          divisionId: profileDivision,
          answeredCount: Number(entry?.unique_answered_count || 0),
          correctCount: Number(entry?.correct_answer_count || 0),
          activeDays: activeDayCount(entry || {}),
          eligible: entry ? isEligibleEntry(entry, requiredCategoryIds) : false,
          status: engagementStatus(entry, new Date(), requiredCategoryIds),
          isActive: profile.is_active !== false,
        };
      })
      .filter((student) => student.isActive && student.divisionId === divisionId)
      .sort((a, b) => {
        const statusOrder = {
          needs_encouragement: 0,
          not_started: 1,
          participating: 2,
          qualified: 3,
        };
        return statusOrder[a.status] - statusOrder[b.status] ||
          a.displayName.localeCompare(b.displayName);
      })
    : [];
  return {
    monthKey: parsed.monthKey,
    timezone: TIME_ZONE,
    status: competition.status || 'open',
    divisionId,
    requiresDivision: divisionId === UNASSIGNED_DIVISION,
    divisions,
    minimumQuestions: MINIMUM_QUESTIONS,
    minimumActiveDays: MINIMUM_ACTIVE_DAYS,
    minimumAccuracy: MINIMUM_ACCURACY,
    minimumEligibleParticipants: MINIMUM_ELIGIBLE_PARTICIPANTS,
    requiredCategoryCount: requiredCategoryIds.length,
    countingStartDate: countingWindow.startDate,
    countingEndDate: countingWindow.endDate,
    lifetimeWins,
    categoryInsights,
    leaderboard: adminView ? ranked.slice(0, MAX_LEADERBOARD_SIZE).map(publicEntry) : [],
    self: self ? publicEntry(self) : null,
    nearby: self && !adminView ? {
      above: selfIndex > 0 ? publicEntry(ranked[selfIndex - 1]) : null,
      below: selfIndex >= 0 && selfIndex < ranked.length - 1
        ? publicEntry(ranked[selfIndex + 1])
        : null,
    } : null,
    winners,
    winner: winners[0] || null,
    engagement,
    engagementSummary: adminView ? {
      total: engagement.length,
      notStarted: engagement.filter((student) => student.status === 'not_started').length,
      needsEncouragement: engagement.filter((student) =>
        student.status === 'needs_encouragement').length,
      participating: engagement.filter((student) =>
        student.status === 'participating').length,
      qualified: engagement.filter((student) => student.status === 'qualified').length,
    } : null,
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
  const requiredCategoryIds = requiredCategoryIdsForCompetition(current);
  if (current.status === 'finalized' && reason.length < 10) {
    throw new HttpsError('already-exists', 'Competition is already finalized');
  }

  if (request.data?.overrideWinnerUid) {
    throw new HttpsError(
      'invalid-argument',
      'Manual winner overrides are disabled; correct divisions or eligibility instead',
    );
  }
  const entries = entriesSnapshot.docs.map((doc) => ({uid: doc.id, ...doc.data()}));
  const divisionResults = {};
  let eligibleCount = 0;
  let winnerCount = 0;
  for (const division of DIVISIONS) {
    const ranked = rankEntries(entries.filter((entry) =>
      normalizeDivisionId(entry.division_id) === division.id,
    ), requiredCategoryIds);
    const eligible = ranked.filter((entry) => entry.eligible);
    eligibleCount += eligible.length;
    const winners = eligible.length >= MINIMUM_ELIGIBLE_PARTICIPANTS
      ? eligible.filter((entry) => entry.rank === 1).map(publicEntry)
      : [];
    winnerCount += winners.length;
    divisionResults[division.id] = {
      winners,
      eligible_student_count: eligible.length,
      participant_count: ranked.length,
    };
  }
  divisionResults[UNASSIGNED_DIVISION] = {
    winners: [],
    eligible_student_count: 0,
    participant_count: entries.filter((entry) =>
      !normalizeDivisionId(entry.division_id) ||
      normalizeDivisionId(entry.division_id) === UNASSIGNED_DIVISION).length,
  };

  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  const revisionRef = competitionRef.collection('finalization_history').doc();
  const batch = db.batch();
  batch.set(revisionRef, {
    previous_division_results: current.division_results || null,
    division_results: divisionResults,
    reason: reason || null,
    finalized_by: uid,
    finalized_at: timestamp,
  });
  batch.set(competitionRef, {
    month_key: parsed.monthKey,
    status: 'finalized',
    timezone: TIME_ZONE,
    winner: null,
    division_results: divisionResults,
    eligible_student_count: eligibleCount,
    participant_count: entries.length,
    winner_count: winnerCount,
    finalized_by: uid,
    finalized_at: timestamp,
    finalization_reason: reason || null,
    rules: {
      minimum_questions: MINIMUM_QUESTIONS,
      minimum_active_days: MINIMUM_ACTIVE_DAYS,
      minimum_accuracy: MINIMUM_ACCURACY,
      minimum_eligible_participants: MINIMUM_ELIGIBLE_PARTICIPANTS,
      unique_questions_only: true,
      required_category_ids: requiredCategoryIds,
      age_divisions: DIVISIONS,
      co_winners_for_exact_ties: true,
      ranking_order: ['unique_answers', 'correct_answers', 'active_days'],
    },
  }, {merge: true});
  await batch.commit();
  return {
    monthKey: parsed.monthKey,
    divisionResults,
    eligibleCount,
    winnerCount,
  };
});

const setQuizCompetitionWindow = onCall({
  region: 'us-central1',
  memory: '256MiB',
}, async (request) => {
  const {uid, data: userData} = await requireUser(request);
  if (!isAdminUser(userData)) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }
  const parsed = parseMonthKey(request.data?.monthKey || monthKeyForDate());
  if (!parsed) throw new HttpsError('invalid-argument', 'Month must use YYYY-MM');
  const startDate = String(request.data?.startDate || '').trim();
  const endDate = String(request.data?.endDate || '').trim();
  const window = countingWindowForCompetition({
    rules: {counting_starts_on: startDate, counting_ends_on: endDate},
  }, parsed.monthKey);
  if (window.startDate !== startDate || window.endDate !== endDate) {
    throw new HttpsError(
      'invalid-argument',
      'Start and end dates must be ordered days in the selected competition month',
    );
  }

  const db = admin.firestore();
  const competitionRef = db.collection('quiz_competitions').doc(parsed.monthKey);
  const [competitionSnapshot, entriesSnapshot] = await Promise.all([
    competitionRef.get(),
    competitionRef.collection('students').limit(1).get(),
  ]);
  if (competitionSnapshot.data()?.status === 'finalized') {
    throw new HttpsError('failed-precondition', 'Finalized competition windows are locked');
  }
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  const historyRef = competitionRef.collection('window_history').doc();
  const previousWindow = countingWindowForCompetition(
    competitionSnapshot.data() || {},
    parsed.monthKey,
  );
  const batch = db.batch();
  batch.set(competitionRef, {
    month_key: parsed.monthKey,
    status: competitionSnapshot.data()?.status || 'open',
    timezone: TIME_ZONE,
    updated_at: timestamp,
    rules: {
      ...(competitionSnapshot.data()?.rules || {}),
      counting_starts_on: window.startDate,
      counting_ends_on: window.endDate,
      required_category_ids: requiredCategoryIdsForCompetition(
        competitionSnapshot.data() || {},
      ),
    },
  }, {merge: true});
  batch.set(historyRef, {
    month_key: parsed.monthKey,
    previous_start_date: previousWindow.startDate,
    previous_end_date: previousWindow.endDate,
    start_date: window.startDate,
    end_date: window.endDate,
    changed_by: uid,
    changed_at: timestamp,
    had_participants: !entriesSnapshot.empty,
  });
  await batch.commit();
  return {monthKey: parsed.monthKey, ...window};
});

const setQuizCompetitionDivision = onCall({
  region: 'us-central1',
  memory: '256MiB',
}, async (request) => {
  const {uid: adminUid, data: adminData} = await requireUser(request);
  if (!isAdminUser(adminData)) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }
  const studentUid = String(request.data?.studentUid || '').trim();
  const divisionId = normalizeDivisionId(request.data?.divisionId, {
    allowUnassigned: false,
  });
  const parsed = parseMonthKey(request.data?.monthKey || monthKeyForDate());
  const reason = String(request.data?.reason || '').trim();
  if (!studentUid || !divisionId || !parsed) {
    throw new HttpsError(
      'invalid-argument',
      'Student, valid division, and YYYY-MM month are required',
    );
  }
  if (reason.length < 10) {
    throw new HttpsError('invalid-argument', 'Division assignment requires a reason');
  }

  const db = admin.firestore();
  const studentRef = db.collection('users').doc(studentUid);
  const competitionRef = db.collection('quiz_competitions').doc(parsed.monthKey);
  const entryRef = competitionRef.collection('students').doc(studentUid);
  const [studentSnapshot, competitionSnapshot, entrySnapshot] = await Promise.all([
    studentRef.get(),
    competitionRef.get(),
    entryRef.get(),
  ]);
  if (!studentSnapshot.exists || !isStudentUser(studentSnapshot.data() || {})) {
    throw new HttpsError('not-found', 'Student profile not found');
  }
  if (competitionSnapshot.data()?.status === 'finalized') {
    throw new HttpsError('failed-precondition', 'Finalized competition divisions are locked');
  }

  const previousDivision = normalizeDivisionId(entrySnapshot.data()?.division_id) ||
    divisionForUser(studentSnapshot.data() || {}, parsed.monthKey).id;
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  const auditRef = competitionRef.collection('division_assignment_history').doc();
  const batch = db.batch();
  batch.set(studentRef, {
    quiz_competition_division: divisionId,
    quiz_competition_division_valid_through: parsed.monthKey,
    quiz_competition_division_updated_at: timestamp,
    quiz_competition_division_updated_by: adminUid,
  }, {merge: true});
  if (entrySnapshot.exists) {
    batch.set(entryRef, {
      division_id: divisionId,
      division_source: 'admin_assignment',
      division_assigned_at: timestamp,
      division_assigned_by: adminUid,
    }, {merge: true});
  }
  batch.set(auditRef, {
    student_uid: studentUid,
    month_key: parsed.monthKey,
    previous_division_id: previousDivision,
    division_id: divisionId,
    reason,
    assigned_by: adminUid,
    assigned_at: timestamp,
  });
  await batch.commit();
  return {studentUid, monthKey: parsed.monthKey, divisionId};
});

const setOwnQuizCompetitionAge = onCall({
  region: 'us-central1',
  memory: '256MiB',
}, async (request) => {
  const {uid, data: userData} = await requireUser(request);
  if (!isStudentUser(userData) || userData.is_active === false) {
    throw new HttpsError('permission-denied', 'Active student access required');
  }
  const birthMonth = Number(request.data?.birthMonth);
  const birthYear = Number(request.data?.birthYear);
  const monthKey = monthKeyForDate();
  const age = ageAtMonthStartFromMonthYear(birthMonth, birthYear, monthKey);
  if (!Number.isInteger(birthMonth) || birthMonth < 1 || birthMonth > 12 ||
      !Number.isInteger(birthYear) || age === null || age < 0 || age > 120) {
    throw new HttpsError('invalid-argument', 'Valid birth month and year are required');
  }
  const divisionId = divisionForAge(age);
  if (!divisionId) {
    throw new HttpsError('invalid-argument', 'Age is outside the supported range');
  }

  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  const competitionRef = db.collection('quiz_competitions').doc(monthKey);
  const entryRef = competitionRef.collection('students').doc(uid);
  const auditRef = competitionRef.collection('age_declaration_history').doc();
  await db.runTransaction(async (transaction) => {
    const [profileSnapshot, competitionSnapshot, entrySnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(competitionRef),
      transaction.get(entryRef),
    ]);
    const profile = profileSnapshot.data() || {};
    const existingEntryDivision = normalizeDivisionId(entrySnapshot.data()?.division_id);
    const existingProfileDivision = divisionForUser(profile, monthKey).id;
    if (existingProfileDivision !== UNASSIGNED_DIVISION ||
        (existingEntryDivision && existingEntryDivision !== UNASSIGNED_DIVISION)) {
      throw new HttpsError(
        'already-exists',
        'Age information is already recorded; ask an administrator to correct it',
      );
    }
    if (competitionSnapshot.data()?.status === 'finalized') {
      throw new HttpsError('failed-precondition', 'This monthly competition is closed');
    }
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    transaction.set(userRef, {
      quiz_competition_birth_month: birthMonth,
      quiz_competition_birth_year: birthYear,
      quiz_competition_age_declared_at: timestamp,
      quiz_competition_age_source: 'student_self_declaration',
    }, {merge: true});
    if (entrySnapshot.exists) {
      transaction.set(entryRef, {
        division_id: divisionId,
        division_source: 'student_birth_month_year',
        division_age_snapshot: age,
        division_assigned_at: timestamp,
      }, {merge: true});
    }
    transaction.create(auditRef, {
      student_uid: uid,
      month_key: monthKey,
      division_id: divisionId,
      age_at_month_start: age,
      declared_at: timestamp,
    });
  });
  return {monthKey, divisionId, age};
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
  if (before.status !== 'approved' && after.status === 'approved' &&
      !after.students_notified_at && !after.student_notification_pending_at) {
    await event.data.after.ref.update({
      student_notification_pending_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return null;
});

module.exports = {
  recordQuizCompetitionAnswer,
  getQuizCompetitionLeaderboard,
  finalizeQuizCompetition,
  setQuizCompetitionWindow,
  setQuizCompetitionDivision,
  setOwnQuizCompetitionAge,
  onQuizQuestionApproved,
  __test__: {
    MINIMUM_QUESTIONS,
    MINIMUM_ACTIVE_DAYS,
    MINIMUM_ACCURACY,
    MINIMUM_ELIGIBLE_PARTICIPANTS,
    REQUIRED_CATEGORY_IDS,
    TIME_ZONE,
    DIVISIONS,
    UNASSIGNED_DIVISION,
    monthKeyForDate,
    dateKeyForDate,
    parseMonthKey,
    countingWindowForCompetition,
    displayNameForUser,
    normalizeDivisionId,
    divisionForAge,
    ageAtMonthStart,
    ageAtMonthStartFromMonthYear,
    divisionForUser,
    resolveBundledAnswer,
    accuracyForEntry,
    activeDayCount,
    normalizedRequiredCategoryIds,
    requiredCategoryIdsForCompetition,
    attemptedCategoryIds,
    hasRequiredCategoryCoverage,
    categoryInsightsForAnswers,
    lifetimeWinsForCompetitions,
    isEligibleEntry,
    compareScores,
    sameScore,
    rankEntries,
    publicEntry,
    timestampMillis,
    engagementStatus,
    tokenGroupsForStudents,
    chunksOf,
  },
};
