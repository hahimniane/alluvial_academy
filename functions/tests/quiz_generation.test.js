jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (_config, fn) => fn,
}));
jest.mock('firebase-functions/v2/https', () => ({
  onCall: (_config, fn) => fn,
  HttpsError: class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  },
}));

const fs = require('fs');
const path = require('path');
const { __test__ } = require('../handlers/quiz_generation');
const bundledQuestionTexts = require('../data/quiz_question_texts.json');

const {
  buildPrompt,
  parseGeminiQuestions,
  validateGeneratedQuestion,
  normalizeQuestionText,
  isNearDuplicateQuestion,
  filterNewQuestions,
  CATEGORIES,
} = __test__;

const validQuestion = {
  difficulty: 'easy',
  question: 'How many pillars of Islam are there?',
  options: ['3', '4', '5', '6'],
  correctAnswer: 2,
  explanation: 'There are five pillars of Islam.',
};

describe('validateGeneratedQuestion', () => {
  test('accepts a well-formed question', () => {
    const result = validateGeneratedQuestion({
      ...validQuestion,
      difficulty: ' EASY ',
    });
    expect(result).not.toBeNull();
    expect(result.difficulty).toBe('easy');
    expect(result.options).toHaveLength(4);
  });

  test.each([
    ['missing question', { ...validQuestion, question: '' }],
    ['too-short question', { ...validQuestion, question: 'Hi?' }],
    ['bad difficulty', { ...validQuestion, difficulty: 'extreme' }],
    ['three options', { ...validQuestion, options: ['a', 'b', 'c'] }],
    ['five options', { ...validQuestion, options: ['a', 'b', 'c', 'd', 'e'] }],
    ['empty option', { ...validQuestion, options: ['a', '', 'c', 'd'] }],
    ['duplicate options', { ...validQuestion, options: ['a', 'a', 'c', 'd'] }],
    ['out-of-range answer', { ...validQuestion, correctAnswer: 4 }],
    ['non-integer answer', { ...validQuestion, correctAnswer: 1.5 }],
    ['missing explanation', { ...validQuestion, explanation: '' }],
    ['null input', null],
  ])('rejects %s', (_name, raw) => {
    expect(validateGeneratedQuestion(raw)).toBeNull();
  });
});

describe('parseGeminiQuestions', () => {
  const wrap = (text) => ({
    candidates: [{ content: { parts: [{ text }] } }],
  });

  test('parses a plain JSON array response', () => {
    const parsed = parseGeminiQuestions(wrap(JSON.stringify([validQuestion])));
    expect(parsed).toHaveLength(1);
    expect(parsed[0].question).toBe(validQuestion.question);
  });

  test('parses JSON wrapped in markdown fences', () => {
    const parsed = parseGeminiQuestions(
      wrap('```json\n' + JSON.stringify([validQuestion]) + '\n```'),
    );
    expect(parsed).toHaveLength(1);
  });

  test('returns empty array for garbage or missing content', () => {
    expect(parseGeminiQuestions(wrap('not json at all'))).toEqual([]);
    expect(parseGeminiQuestions({})).toEqual([]);
    expect(parseGeminiQuestions(undefined)).toEqual([]);
  });

  test('returns empty array when JSON is an object, not an array', () => {
    expect(parseGeminiQuestions(wrap('{"a":1}'))).toEqual([]);
  });
});

describe('filterNewQuestions', () => {
  test('drops questions that match existing ones ignoring case/punctuation', () => {
    const existing = ['How many pillars of Islam are there?'];
    const fresh = filterNewQuestions(
      [
        validQuestion,
        { ...validQuestion, question: 'how many PILLARS of islam are there' },
        { ...validQuestion, question: 'What is the first pillar of Islam?' },
      ],
      existing,
    );
    expect(fresh).toHaveLength(1);
    expect(fresh[0].question).toBe('What is the first pillar of Islam?');
  });

  test('drops duplicates within the same batch', () => {
    const fresh = filterNewQuestions(
      [
        { ...validQuestion, question: 'What is Zakat in Islam?' },
        { ...validQuestion, question: 'What is zakat in Islam??' },
      ],
      [],
    );
    expect(fresh).toHaveLength(1);
  });

  test('drops close rephrases of an existing question', () => {
    const fresh = filterNewQuestions(
      [
        {
          ...validQuestion,
          question: 'Who was the first muezzin caller to prayer in Islam?',
        },
        {...validQuestion, question: 'What is the purpose of giving Zakat?'},
      ],
      ['Who was the first Muezzin (caller to prayer)?'],
    );
    expect(fresh).toHaveLength(1);
    expect(fresh[0].question).toBe('What is the purpose of giving Zakat?');
  });
});

describe('normalizeQuestionText', () => {
  test('is stable across case, punctuation, and spacing', () => {
    expect(normalizeQuestionText('  What is   WUDU?! '))
      .toBe(normalizeQuestionText('what is wudu'));
  });
});

describe('isNearDuplicateQuestion', () => {
  test('recognizes a close rephrase but not a different question', () => {
    expect(isNearDuplicateQuestion(
      'Who was the first muezzin caller to prayer in Islam?',
      'Who was the first Muezzin (caller to prayer)?',
    )).toBe(true);
    expect(isNearDuplicateQuestion(
      'What is the purpose of giving Zakat?',
      'Who was the first Muezzin (caller to prayer)?',
    )).toBe(false);
  });
});

describe('buildPrompt', () => {
  test('includes topic, count, and existing questions', () => {
    const prompt = buildPrompt({
      topic: 'Test topic',
      existingQuestions: ['Existing Q1?'],
      count: 10,
    });
    expect(prompt).toContain('Test topic');
    expect(prompt).toContain('exactly 10 NEW questions');
    expect(prompt).toContain('- Existing Q1?');
  });
});

describe('CATEGORIES', () => {
  test('covers all nine app categories', () => {
    expect(CATEGORIES.map((c) => c.id).sort()).toEqual([
      'arabic_basics', 'daily_duas', 'five_pillars', 'islamic_history',
      'islamic_manners', 'prophets', 'quran_basics', 'sahaba', 'seerah',
    ]);
  });
});

describe('bundled question text catalog', () => {
  test('stays in sync with every Flutter quiz asset', () => {
    for (const category of CATEGORIES) {
      const assetPath = path.join(
        __dirname,
        '..',
        '..',
        'assets',
        'quizzes',
        `${category.id}.json`,
      );
      const asset = JSON.parse(fs.readFileSync(assetPath, 'utf8'));
      expect(bundledQuestionTexts[category.id])
        .toEqual(asset.questions.map((question) => question.question));
    }
  });
});
