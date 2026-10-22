const {
  PENALTY_REASON_CODES,
  PENALTY_REASON_BY_ISSUE_TYPE,
  penaltyReasonLabel,
  readPenaltyReason,
  penaltyReasonProblem,
  composePenaltyReasonText,
} = require('../utils/penalty_reasons');

describe('penalty reasons', () => {
  test('codes match the finance spec', () => {
    expect(PENALTY_REASON_CODES).toEqual([
      'late_clock_in',
      'missed_class',
      'late_class_report',
      'left_class_early',
      'no_camera_or_setup',
      'conduct',
      'other',
    ]);
  });

  test('labels fall back to Other', () => {
    expect(penaltyReasonLabel('late_clock_in')).toBe('Late clock-in');
    expect(penaltyReasonLabel('bogus')).toBe('Other');
    expect(penaltyReasonLabel(undefined)).toBe('Other');
  });

  test('an entry without a code reads as other with its text as the note', () => {
    expect(readPenaltyReason({reason: 'For missing class work'})).toEqual({
      reason: 'other',
      note: 'For missing class work',
    });
    expect(readPenaltyReason({reason: '—'})).toEqual({reason: 'other', note: ''});
    expect(readPenaltyReason(undefined)).toEqual({reason: 'other', note: ''});
  });

  test('a coded entry keeps its code and note', () => {
    expect(readPenaltyReason({penalty_reason: 'conduct', penalty_note: ' rude ', reason: 'x'})).toEqual({
      reason: 'conduct',
      note: 'rude',
    });
  });

  test('a reason is required and Other needs a note', () => {
    expect(penaltyReasonProblem(undefined, '')).toBe('reason_missing');
    expect(penaltyReasonProblem('other', '  ')).toBe('note_missing');
    expect(penaltyReasonProblem('other', 'why')).toBeNull();
    expect(penaltyReasonProblem('conduct', '')).toBeNull();
  });

  test('the plain text keeps the label and the note', () => {
    expect(composePenaltyReasonText('missed_class', 'twice')).toBe('Missed a class without notice — twice');
    expect(composePenaltyReasonText('conduct', '')).toBe('Conduct');
  });

  test('system issue types map to codes', () => {
    expect(PENALTY_REASON_BY_ISSUE_TYPE).toEqual({
      missed_classes: 'missed_class',
      late_clock_ins: 'late_clock_in',
      missing_forms: 'late_class_report',
    });
  });
});
