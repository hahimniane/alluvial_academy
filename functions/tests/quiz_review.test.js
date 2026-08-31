jest.mock('firebase-functions/v2/https', () => ({
  onCall: (_config, fn) => fn,
  HttpsError: class HttpsError extends Error {
    constructor(_code, message) {
      super(message);
    }
  },
}));
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (_config, fn) => fn,
}));

const {__test__} = require('../handlers/quiz_review');

describe('quiz review helpers', () => {
  test('normalizes selected teacher reviewer IDs', () => {
    expect(__test__.reviewerIdsFromSettings({
      reviewer_teacher_ids: ['teacher-1', 'teacher-1', '', 'teacher-2'],
    })).toEqual(['teacher-1', 'teacher-2']);
  });

  test('deduplicates FCM tokens and honors the relevant opt-out', () => {
    expect(__test__.tokenSetForUsers([
      {fcmToken: 'one'},
      {fcmTokens: [{token: 'one'}, {token: 'two'}]},
      {fcmToken: 'hidden', notificationPreferences: {quizReviewEnabled: false}},
    ], 'quizReviewEnabled')).toEqual(['one', 'two']);
  });

  test('chunks batch notifications at the FCM recipient limit', () => {
    expect(__test__.chunksOf(Array.from({length: 1001}, (_, index) => index))
      .map((chunk) => chunk.length)).toEqual([500, 500, 1]);
  });

  test('requires a concise reason for every rejection', () => {
    expect(() => __test__.rejectionReasonFor('rejected', '  ')).toThrow(
      'A rejection reason is required',
    );
    expect(() => __test__.rejectionReasonFor('rejected', 'x'.repeat(501)))
      .toThrow('500 characters or fewer');
    expect(__test__.rejectionReasonFor('rejected', ' Duplicate question '))
      .toBe('Duplicate question');
    expect(__test__.rejectionReasonFor('approved', '')).toBe('');
  });
});
