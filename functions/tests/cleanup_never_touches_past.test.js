'use strict';

/**
 * Regeneration and deactivation must never reach backwards. Stopping a
 * repeating class, moving its time, or pausing it all run the same cleanup —
 * and a class that already happened is a record: a missed one carries
 * attendance history, a finished one carries pay. Caught live 2026-08-27 when
 * "delete upcoming" from a past class also removed a past missed class.
 */

const {__test__} = require('../handlers/shift_templates');
const {_cleanupCandidateFilter} = __test__;

const NOW = Date.parse('2026-08-27T12:00:00Z');
const at = (iso) => ({toDate: () => new Date(Date.parse(iso))});
const doc = (extra) => ({template_id: 'T1', status: 'scheduled', shift_start: at('2026-09-01T20:00:00Z'), ...extra});

describe('cleanup candidate filter', () => {
  test('deletes an upcoming scheduled class', () => {
    expect(_cleanupCandidateFilter(doc(), {templateId: 'T1', now: NOW})).toBe(true);
  });

  test('never deletes a class that already started', () => {
    expect(_cleanupCandidateFilter(doc({shift_start: at('2026-08-20T20:00:00Z')}), {templateId: 'T1', now: NOW})).toBe(false);
  });

  test('never deletes a PAST MISSED class — attendance history', () => {
    const past = doc({status: 'missed', shift_start: at('2026-08-17T20:00:00Z')});
    expect(_cleanupCandidateFilter(past, {templateId: 'T1', now: NOW})).toBe(false);
  });

  test('a future missed class is still removable', () => {
    expect(_cleanupCandidateFilter(doc({status: 'missed'}), {templateId: 'T1', now: NOW})).toBe(true);
  });

  test('never deletes completed or active classes, future or not', () => {
    for (const status of ['completed', 'fullyCompleted', 'partiallyCompleted', 'active']) {
      expect(_cleanupCandidateFilter(doc({status}), {templateId: 'T1', now: NOW})).toBe(false);
    }
  });

  test('a class starting exactly now counts as started', () => {
    expect(_cleanupCandidateFilter(doc({shift_start: at('2026-08-27T12:00:00Z')}), {templateId: 'T1', now: NOW})).toBe(false);
  });

  test('leaves other templates alone', () => {
    expect(_cleanupCandidateFilter(doc({template_id: 'OTHER'}), {templateId: 'T1', now: NOW})).toBe(false);
  });
});
