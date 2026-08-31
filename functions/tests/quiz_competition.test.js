jest.mock('firebase-functions/v2/https', () => ({
  onCall: (_config, fn) => fn,
  HttpsError: class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  },
}));
jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentUpdated: (_config, fn) => fn,
}));

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const answerKey = require('../data/quiz_answer_key.json');
const {
  recordQuizCompetitionAnswer,
  __test__,
} = require('../handlers/quiz_competition');

const {
  MINIMUM_QUESTIONS,
  MINIMUM_ACTIVE_DAYS,
  MINIMUM_ACCURACY,
  MINIMUM_ELIGIBLE_PARTICIPANTS,
  REQUIRED_CATEGORY_IDS,
  UNASSIGNED_DIVISION,
  monthKeyForDate,
  dateKeyForDate,
  parseMonthKey,
  countingWindowForCompetition,
  displayNameForUser,
  divisionForAge,
  ageAtMonthStart,
  ageAtMonthStartFromMonthYear,
  divisionForUser,
  resolveBundledAnswer,
  isEligibleEntry,
  hasRequiredCategoryCoverage,
  categoryInsightsForAnswers,
  lifetimeWinsForCompetitions,
  rankEntries,
  engagementStatus,
  tokenGroupsForStudents,
  chunksOf,
} = __test__;

describe('monthly competition dates', () => {
  test('uses America/New_York at a UTC month boundary', () => {
    const instant = new Date('2026-03-01T02:30:00.000Z');
    expect(monthKeyForDate(instant)).toBe('2026-02');
    expect(dateKeyForDate(instant)).toBe('2026-02-28');
  });

  test('defaults to the calendar month and validates an admin counting window', () => {
    expect(countingWindowForCompetition({}, '2026-07')).toEqual({
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    });
    expect(countingWindowForCompetition({rules: {
      counting_starts_on: '2026-07-05',
      counting_ends_on: '2026-07-20',
    }}, '2026-07')).toEqual({
      startDate: '2026-07-05',
      endDate: '2026-07-20',
    });
    expect(countingWindowForCompetition({rules: {
      counting_starts_on: '2026-07-21',
      counting_ends_on: '2026-07-20',
    }}, '2026-07')).toEqual({
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    });
  });

  test('summarizes category improvement and lifetime shared wins', () => {
    const insights = categoryInsightsForAnswers([
      {category_id: 'five_pillars', is_correct: true},
      {category_id: 'five_pillars', is_correct: false},
      {category_id: 'prophets', is_correct: true},
    ]);
    expect(insights.find((item) => item.categoryId === 'five_pillars'))
      .toMatchObject({answeredCount: 2, correctCount: 1, accuracy: 0.5});
    expect(lifetimeWinsForCompetitions([{
      division_results: {youth: {winners: [{uid: 'student-a'}]}},
    }, {
      division_results: {adults: {winners: [{uid: 'another'}]}},
    }], 'student-a')).toBe(1);
  });

  test('validates strict month keys and calculates the next month', () => {
    const parsed = parseMonthKey('2026-12');
    expect(parsed.monthKey).toBe('2026-12');
    expect(parsed.end.toFormat('yyyy-MM-dd')).toBe('2027-01-01');
    expect(parseMonthKey('2026-13')).toBeNull();
    expect(parseMonthKey('July 2026')).toBeNull();
  });
});

describe('age division safeguards', () => {
  test.each([
    [0, 'early_learners'],
    [4, 'early_learners'],
    [5, 'early_learners'],
    [7, 'early_learners'],
    [8, 'juniors'],
    [11, 'juniors'],
    [12, 'youth'],
    [17, 'youth'],
    [18, 'adults'],
    [70, 'adults'],
    [-1, null],
    [121, null],
  ])('assigns age %s to %s', (age, expected) => {
    expect(divisionForAge(age)).toBe(expected);
  });

  test('uses age on the first day of the month so birthdays do not move a student', () => {
    expect(ageAtMonthStart('2018-07-15', '2026-07')).toBe(7);
    expect(divisionForUser({date_of_birth: '2018-07-15'}, '2026-07')).toEqual({
      id: 'early_learners',
      source: 'birth_date',
      age: 7,
    });
  });

  test('uses birth month and year without storing a full birth date', () => {
    expect(ageAtMonthStartFromMonthYear(7, 2018, '2026-07')).toBe(7);
    expect(ageAtMonthStartFromMonthYear(7, 2018, '2026-08')).toBe(8);
    expect(divisionForUser({
      quiz_competition_birth_month: 7,
      quiz_competition_birth_year: 2018,
    }, '2026-08')).toEqual({
      id: 'juniors',
      source: 'student_birth_month_year',
      age: 8,
    });
  });

  test('does not guess a minor division when age data is missing', () => {
    expect(divisionForUser({is_adult_student: false}, '2026-07')).toEqual({
      id: UNASSIGNED_DIVISION,
      source: 'unassigned',
    });
    expect(divisionForUser({is_adult_student: true}, '2026-07').id).toBe('adults');
  });

  test('expires manual division assignments after their approved month', () => {
    const profile = {
      quiz_competition_division: 'juniors',
      quiz_competition_division_valid_through: '2026-07',
    };
    expect(divisionForUser(profile, '2026-07').id).toBe('juniors');
    expect(divisionForUser(profile, '2026-08').id).toBe(UNASSIGNED_DIVISION);
  });
});

describe('bundled answer validation', () => {
  test('resolves valid bundled question IDs and rejects mismatches', () => {
    expect(resolveBundledAnswer({
      questionId: 'fp_001',
      categoryId: 'five_pillars',
    })).toBe(2);
    expect(resolveBundledAnswer({
      questionId: 'fp_043',
      categoryId: 'five_pillars',
    })).toBeNull();
    expect(resolveBundledAnswer({
      questionId: 'fp_001',
      categoryId: 'prophets',
    })).toBeNull();
  });

  test('the deployed answer key stays in sync with every Flutter quiz asset', () => {
    for (const [category, bank] of Object.entries(answerKey)) {
      const assetPath = path.join(__dirname, '..', '..', 'assets', 'quizzes', `${category}.json`);
      const asset = JSON.parse(fs.readFileSync(assetPath, 'utf8'));
      expect(asset.questions).toHaveLength(bank.answers.length);
      asset.questions.forEach((question, index) => {
        expect(question.id).toBe(`${bank.prefix}_${String(index + 1).padStart(3, '0')}`);
        expect(question.correctAnswer).toBe(bank.answers[index]);
      });
    }
  });
});

describe('leaderboard rules', () => {
  const eligible = (overrides = {}) => ({
    uid: 'student-a',
    display_name: 'Amina B.',
    unique_answered_count: MINIMUM_QUESTIONS,
    correct_answer_count: 15,
    active_days: Array.from(
      {length: MINIMUM_ACTIVE_DAYS},
      (_, index) => `2026-07-0${index + 1}`,
    ),
    score_reached_at: new Date('2026-07-20T12:00:00Z'),
    division_id: 'youth',
    attempted_category_ids: REQUIRED_CATEGORY_IDS,
    ...overrides,
  });

  test('requires the question, active-day, accuracy, and category minimums', () => {
    expect(isEligibleEntry(eligible())).toBe(true);
    expect(isEligibleEntry(eligible({unique_answered_count: MINIMUM_QUESTIONS - 1}))).toBe(false);
    expect(isEligibleEntry(eligible({active_days: ['2026-07-01', '2026-07-02']}))).toBe(false);
    expect(isEligibleEntry(eligible({correct_answer_count:
      Math.floor(MINIMUM_QUESTIONS * MINIMUM_ACCURACY) - 1}))).toBe(false);
    expect(isEligibleEntry(eligible({attempted_category_ids: REQUIRED_CATEGORY_IDS.slice(1)})))
      .toBe(false);
    expect(hasRequiredCategoryCoverage(eligible())).toBe(true);
    expect(isEligibleEntry(eligible({division_id: UNASSIGNED_DIVISION}))).toBe(false);
    expect(MINIMUM_ELIGIBLE_PARTICIPANTS).toBe(2);
  });

  test('ranks unique answers, correctness, and active days', () => {
    const ranked = rankEntries([
      eligible({uid: 'few', unique_answered_count: 21, correct_answer_count: 21}),
      eligible({uid: 'late', unique_answered_count: 22, correct_answer_count: 18,
        score_reached_at: new Date('2026-07-21T12:00:00Z')}),
      eligible({uid: 'early', unique_answered_count: 22, correct_answer_count: 18,
        score_reached_at: new Date('2026-07-20T12:00:00Z')}),
      eligible({uid: 'accurate', unique_answered_count: 22, correct_answer_count: 19}),
    ]);
    expect(ranked.map((entry) => entry.uid)).toEqual([
      'accurate', 'early', 'late', 'few',
    ]);
    expect(ranked.map((entry) => entry.rank)).toEqual([1, 2, 2, 4]);
  });

  test('gives exact score ties the same rank regardless of finish time or uid', () => {
    const ranked = rankEntries([
      eligible({uid: 'z-student', display_name: 'Zayn A.',
        score_reached_at: new Date('2026-07-25T12:00:00Z')}),
      eligible({uid: 'a-student', display_name: 'Amina B.',
        score_reached_at: new Date('2026-07-10T12:00:00Z')}),
      eligible({uid: 'third', display_name: 'Musa C.', unique_answered_count: 19}),
    ]);
    expect(ranked.slice(0, 2).map((entry) => entry.rank)).toEqual([1, 1]);
    expect(ranked[2].rank).toBe(3);
  });

  test('identifies students who have not started or need encouragement', () => {
    const now = new Date('2026-07-20T12:00:00Z');
    expect(engagementStatus(null, now)).toBe('not_started');
    expect(engagementStatus(eligible({
      unique_answered_count: 5,
      correct_answer_count: 3,
      last_answered_at: new Date('2026-07-10T12:00:00Z'),
    }), now)).toBe('needs_encouragement');
    expect(engagementStatus(eligible({
      unique_answered_count: 5,
      correct_answer_count: 3,
      last_answered_at: new Date('2026-07-19T12:00:00Z'),
    }), now)).toBe('participating');
    expect(engagementStatus(eligible(), now)).toBe('qualified');
  });
});

describe('student notification helpers', () => {
  test('deduplicates tokens, respects opt-out, and groups French', () => {
    const docs = [
      {data: () => ({user_type: 'student', language_preference: 'fr',
        fcmTokens: [{token: 'fr-1'}, {token: 'fr-1'}]})},
      {data: () => ({user_type: 'student', fcmToken: 'en-1'})},
      {data: () => ({user_type: 'student', fcmToken: 'ignored',
        notificationPreferences: {quizEnabled: false}})},
      {data: () => ({user_type: 'teacher', fcmToken: 'teacher'})},
    ];
    expect(tokenGroupsForStudents(docs)).toEqual({
      en: ['en-1'],
      fr: ['fr-1'],
    });
  });

  test('chunks multicast recipients at the Firebase limit', () => {
    const chunks = chunksOf(Array.from({length: 1001}, (_, index) => `${index}`));
    expect(chunks.map((chunk) => chunk.length)).toEqual([500, 500, 1]);
  });
});

describe('privacy display names', () => {
  test('shows only a last initial', () => {
    expect(displayNameForUser({first_name: 'Amina', last_name: 'Diallo'}))
      .toBe('Amina D.');
  });
});

describe('recordQuizCompetitionAnswer', () => {
  const buildDb = ({answerExists}) => {
    const refs = {
      competition: {kind: 'competition'},
      entry: {kind: 'entry'},
      answer: {kind: 'answer'},
    };
    refs.competition.collection = () => ({doc: () => refs.entry});
    refs.entry.collection = () => ({doc: () => refs.answer});

    const transaction = {
      get: jest.fn(async (ref) => {
        if (ref.kind === 'competition') return {data: () => ({status: 'open'})};
        if (ref.kind === 'entry') {
          return {
            data: () => ({
              unique_answered_count: 4,
              correct_answer_count: 3,
              active_days: ['2026-07-01'],
              attempted_category_ids: ['five_pillars'],
            }),
          };
        }
        return {exists: answerExists};
      }),
      set: jest.fn(),
      create: jest.fn(),
    };
    const userRef = {
      get: jest.fn(async () => ({
        exists: true,
        data: () => ({
          user_type: 'student',
          first_name: 'Amina',
          last_name: 'Diallo',
        }),
      })),
    };
    const db = {
      collection: jest.fn((name) => {
        if (name === 'users') return {doc: () => userRef};
        if (name === 'quiz_competitions') return {doc: () => refs.competition};
        throw new Error(`Unexpected collection ${name}`);
      }),
      runTransaction: jest.fn((callback) => callback(transaction)),
    };
    return {db, transaction};
  };

  beforeEach(() => {
    admin.firestore.FieldValue = {serverTimestamp: () => 'server-time'};
  });

  test('creates one ledger answer and increments verified totals', async () => {
    const {db, transaction} = buildDb({answerExists: false});
    admin.firestore.mockReturnValue(db);

    const result = await recordQuizCompetitionAnswer({
      auth: {uid: 'student-1'},
      data: {
        questionId: 'fp_001',
        categoryId: 'five_pillars',
        selectedAnswerIndex: 2,
      },
    });

    expect(result.counted).toBe(true);
    expect(result.answeredCount).toBe(5);
    expect(result.correctCount).toBe(4);
    expect(result.categoriesAttemptedCount).toBe(1);
    expect(result.isCorrect).toBe(true);
    expect(transaction.create).toHaveBeenCalledTimes(1);
    expect(transaction.set).toHaveBeenCalledTimes(2);
    expect(transaction.set.mock.calls[1][1].attempted_category_ids)
      .toEqual(['five_pillars']);
  });

  test('does not count a replayed question twice', async () => {
    const {db, transaction} = buildDb({answerExists: true});
    admin.firestore.mockReturnValue(db);

    const result = await recordQuizCompetitionAnswer({
      auth: {uid: 'student-1'},
      data: {
        questionId: 'fp_001',
        categoryId: 'five_pillars',
        selectedAnswerIndex: 2,
      },
    });

    expect(result.counted).toBe(false);
    expect(result.answeredCount).toBe(4);
    expect(transaction.create).not.toHaveBeenCalled();
    expect(transaction.set).not.toHaveBeenCalled();
  });
});
