/**
 * A class pays its subject's rate:
 * - the rate is resolved from the subject (id, then name), never $0;
 * - the trigger fills a missing rate and follows a subject change on classes
 *   that have not ended, and leaves past classes alone;
 * - the template generator creates no class for a template without a subject.
 */

const mockSets = [];
const mockCollections = {};
jest.mock('firebase-admin', () => {
  const FieldValue = {serverTimestamp: () => 'SERVER_TS', delete: () => 'DELETE'};
  const firestore = () => ({
    collection: (name) => ({
      get: async () => ({docs: (mockCollections[name] || []).map(([id, data]) => ({id, data: () => data}))}),
      doc: (id) => ({
        get: async () => {
          const row = (mockCollections[name] || []).find(([docId]) => docId === id);
          return {exists: Boolean(row), data: () => (row ? row[1] : undefined)};
        },
        set: async (data, opts) => {
          mockSets.push({path: `${name}/${id}`, data, opts});
        },
      }),
    }),
  });
  firestore.FieldValue = FieldValue;
  firestore.Timestamp = {fromDate: (d) => ({toDate: () => d, toMillis: () => d.getTime()}), now: () => ({toMillis: () => Date.now()})};
  return {firestore, initializeApp: () => {}, apps: [{}]};
});

const admin = require('firebase-admin');
const subjectRate = require('../utils/subject_rate');
const {rateDecision, applySubjectRate} = require('../handlers/shift_rate_guard');
const shiftTemplates = require('../handlers/shift_templates');

const NOW = Date.parse('2026-10-25T12:00:00Z');
const at = (iso) => ({toMillis: () => Date.parse(iso), toDate: () => new Date(iso)});
const future = at('2026-10-26T15:00:00Z');
const past = at('2026-10-20T15:00:00Z');

beforeEach(() => {
  mockSets.length = 0;
  subjectRate._resetCache();
  mockCollections.subjects = [
    ['islamicId', {name: 'islamic', displayName: 'Islamic Studies', defaultWage: 4}],
    ['englishId', {name: 'english', displayName: 'English', defaultWage: 5}],
    ['brokenId', {name: 'unpaid', defaultWage: 0}],
  ];
  mockCollections.subject_hourly_rates = [['afro', {subjectName: 'AfroLingual', hourlyRate: 6, isActive: true}]];
  mockCollections.app_settings = [['global', {teacher_hourly_rate: 4}]];
});

describe('resolveSubjectRate', () => {
  const db = admin.firestore();

  test('uses the subject record named by subject_id', async () => {
    expect(await subjectRate.resolveSubjectRate(db, {subject_id: 'englishId', subject: 'other'})).toEqual({rate: 5, source: 'subject'});
  });

  test('matches by name when the id is missing or points at a deleted subject', async () => {
    expect((await subjectRate.resolveSubjectRate(db, {subject_id: 'deleted', subject: 'other', subject_display_name: 'Islamic'})).rate).toBe(4);
    expect((await subjectRate.resolveSubjectRate(db, {subject: 'english'})).rate).toBe(5);
    expect((await subjectRate.resolveSubjectRate(db, {subject_display_name: 'AfroLingual'})).rate).toBe(6);
  });

  test('a subject with no wage, or none at all, falls back to the global teacher rate, never $0', async () => {
    expect(await subjectRate.resolveSubjectRate(db, {subject_id: 'brokenId', subject: 'unpaid'})).toEqual({rate: 4, source: 'global_rate'});
    expect((await subjectRate.resolveSubjectRate(db, {subject: 'quranStudies', subject_display_name: 'Quran Studies'})).rate).toBe(4);
    mockCollections.app_settings = [];
    subjectRate._resetCache();
    expect((await subjectRate.resolveSubjectRate(db, {subject: ''})).rate).toBe(subjectRate.DEFAULT_RATE);
  });

  test('subject names compare loosely', () => {
    expect(subjectRate.normalizeSubjectName('quranStudies')).toBe(subjectRate.normalizeSubjectName('Quran Studies'));
    expect(subjectRate.normalizeSubjectName('quran_studies')).toBe('quran');
    expect(subjectRate.normalizeSubjectName('Islamic Studies')).toBe('islamic');
  });
});

describe('rateDecision', () => {
  const cls = (over) => ({subject: 'islamic', subject_id: 'islamicId', hourly_rate: 4, shift_end: future, status: 'scheduled', ...over});

  test('an upcoming class with no rate or $0 needs one', () => {
    expect(rateDecision(null, cls({hourly_rate: null}), NOW)).toBe('no_rate');
    expect(rateDecision(cls(), cls({hourly_rate: 0}), NOW)).toBe('no_rate');
  });

  test('a subject change brings the new subject rate unless the same edit set a rate', () => {
    expect(rateDecision(cls(), cls({subject: 'english', subject_id: 'englishId'}), NOW)).toBe('subject_changed');
    expect(rateDecision(cls(), cls({subject: 'english', subject_id: 'englishId', hourly_rate: 7}), NOW)).toBe(null);
  });

  test('past classes, non-teaching classes and deleted classes are never touched', () => {
    expect(rateDecision(null, cls({hourly_rate: 0, shift_end: past}), NOW)).toBe(null);
    expect(rateDecision(cls({shift_end: past}), cls({subject: 'english', shift_end: past}), NOW)).toBe(null);
    expect(rateDecision(null, cls({hourly_rate: 0, shift_category: 'meeting'}), NOW)).toBe(null);
    expect(rateDecision(null, cls({hourly_rate: 0, status: 'deleted'}), NOW)).toBe(null);
  });

  test('an unrelated edit to a paid class changes nothing', () => {
    expect(rateDecision(cls(), cls({status: 'active'}), NOW)).toBe(null);
    expect(rateDecision(null, cls(), NOW)).toBe(null);
  });
});

describe('applySubjectRate', () => {
  test('writes the subject rate and says why', async () => {
    const writes = [];
    const ref = {set: async (data) => writes.push(data)};
    const before = {subject: 'islamic', subject_id: 'islamicId', hourly_rate: 4, shift_end: future};
    const after = {...before, subject: 'english', subject_id: 'englishId'};
    const result = await applySubjectRate({db: admin.firestore(), ref, before, after, now: NOW});
    expect(result).toEqual({reason: 'subject_changed', rate: 5, source: 'subject'});
    expect(writes[0]).toMatchObject({hourly_rate: 5, hourly_rate_source: 'subject', hourly_rate_set_reason: 'subject_changed'});
  });

  test('does not write when the rate already matches (no trigger loop)', async () => {
    const writes = [];
    const ref = {set: async (data) => writes.push(data)};
    const before = {subject: 'english', subject_id: 'englishId', hourly_rate: 4, shift_end: future};
    const after = {...before, subject: 'islamic', subject_id: 'islamicId'};
    expect(await applySubjectRate({db: admin.firestore(), ref, before, after, now: NOW})).toBe(null);
    expect(writes).toHaveLength(0);
  });
});

describe('template generator', () => {
  const {_generateShiftsForTemplate} = shiftTemplates;

  test('creates no class for a teaching template without a subject, and flags it', async () => {
    const result = await _generateShiftsForTemplate({
      templateId: 'tplBlank',
      template: {subject: '', subject_id: null, start_time: '15:00', duration_minutes: 60, teacher_id: 't1'},
    });
    expect(result).toEqual({created: 0, skippedNoSubject: true});
    expect(mockSets).toEqual([expect.objectContaining({path: 'shift_templates/tplBlank', data: expect.objectContaining({generation_blocked_reason: 'no_subject'})})]);
  });
});
