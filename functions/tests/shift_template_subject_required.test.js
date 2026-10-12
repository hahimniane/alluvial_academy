const shiftTemplates = require('../handlers/shift_templates');

const {_assertTeachingSubjectOrThrow, _isTeachingCategory} = shiftTemplates.__test;

describe('a class cannot be saved without a subject', () => {
  test('a teaching template with a subject passes', () => {
    expect(() => _assertTeachingSubjectOrThrow({category: 'teaching', subject: 'islamic'})).not.toThrow();
    expect(() => _assertTeachingSubjectOrThrow({category: undefined, subject: ' quranStudies '})).not.toThrow();
  });

  test('a blank, missing or null subject is rejected for a teaching class', () => {
    for (const subject of ['', '   ', null, undefined]) {
      expect(() => _assertTeachingSubjectOrThrow({category: 'teaching', subject})).toThrow(
        /Pick a subject for this class/,
      );
      // category defaults to teaching when the caller sends none
      expect(() => _assertTeachingSubjectOrThrow({category: undefined, subject})).toThrow();
    }
  });

  test('the error is an invalid-argument HttpsError the client can show', () => {
    let caught;
    try {
      _assertTeachingSubjectOrThrow({category: 'teaching', subject: ''});
    } catch (err) {
      caught = err;
    }
    expect(caught && caught.code).toBe('invalid-argument');
  });

  test('non-teaching categories carry no subject and are not checked', () => {
    for (const category of ['leadership', 'meeting', 'training', 'Meeting ']) {
      expect(_isTeachingCategory(category)).toBe(false);
      expect(() => _assertTeachingSubjectOrThrow({category, subject: ''})).not.toThrow();
    }
    expect(_isTeachingCategory('teaching')).toBe(true);
    expect(_isTeachingCategory(undefined)).toBe(true);
  });
});
