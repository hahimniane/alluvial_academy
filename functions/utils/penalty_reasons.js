/**
 * Penalty reason codes for teacher audits (docs/finance/SPEC.md, "Penalty
 * reasons (structured)"). Mirrors lib/core/constants/penalty_reasons.dart and
 * apps/web/src/lib/finance/penalties.ts.
 */

const PENALTY_REASONS = Object.freeze([
  {code: 'late_clock_in', label: 'Late clock-in'},
  {code: 'missed_class', label: 'Missed a class without notice'},
  {code: 'late_class_report', label: 'Late class report'},
  {code: 'left_class_early', label: 'Left class early'},
  {code: 'no_camera_or_setup', label: 'Camera/setup not as required'},
  {code: 'conduct', label: 'Conduct'},
  {code: 'other', label: 'Other'},
]);

const PENALTY_REASON_CODES = Object.freeze(PENALTY_REASONS.map((r) => r.code));

/** Audit issue types the system raises, and the code each carries as a penalty. */
const PENALTY_REASON_BY_ISSUE_TYPE = Object.freeze({
  missed_classes: 'missed_class',
  late_clock_ins: 'late_clock_in',
  missing_forms: 'late_class_report',
});

function isPenaltyReason(code) {
  return typeof code === 'string' && PENALTY_REASON_CODES.includes(code);
}

/** Label for a code; unknown or missing reads as "Other". */
function penaltyReasonLabel(code) {
  const found = PENALTY_REASONS.find((r) => r.code === code);
  return found ? found.label : 'Other';
}

/**
 * Reads the reason of a stored penalty entry. An entry without a valid code is
 * "other" and its old free text becomes the note.
 * @param {Object} entry penalty entry ({penalty_reason, penalty_note, reason})
 * @returns {{reason: string, note: string}}
 */
function readPenaltyReason(entry) {
  const e = entry || {};
  if (isPenaltyReason(e.penalty_reason)) {
    return {reason: e.penalty_reason, note: String(e.penalty_note || '').trim()};
  }
  const old = String(e.penalty_note || e.reason || '').trim();
  return {reason: 'other', note: old === '—' ? '' : old};
}

/**
 * Whether a reason/note pair can be saved: a valid code is required, and
 * "other" needs a note.
 * @returns {string|null} the problem, or null when it can be saved
 */
function penaltyReasonProblem(code, note) {
  if (!isPenaltyReason(code)) return 'reason_missing';
  if (code === 'other' && !String(note || '').trim()) return 'note_missing';
  return null;
}

/** Plain-text reason older readers show: label plus the note. */
function composePenaltyReasonText(code, note) {
  const label = penaltyReasonLabel(code);
  const n = String(note || '').trim();
  return n ? `${label} — ${n}` : label;
}

module.exports = {
  PENALTY_REASONS,
  PENALTY_REASON_CODES,
  PENALTY_REASON_BY_ISSUE_TYPE,
  isPenaltyReason,
  penaltyReasonLabel,
  readPenaltyReason,
  penaltyReasonProblem,
  composePenaltyReasonText,
};
