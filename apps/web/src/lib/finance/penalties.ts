export const PENALTY_REASONS = [{code:'late_clock_in',label:'Late clock-in'},{code:'missed_class',label:'Missed a class without notice'},{code:'late_class_report',label:'Late class report'},{code:'left_class_early',label:'Left class early'},{code:'no_camera_or_setup',label:'Camera/setup not as required'},{code:'conduct',label:'Conduct'},{code:'other',label:'Other'}] as const;

export type PenaltyReason = typeof PENALTY_REASONS[number]['code'];

export function penaltyReasonLabel(code: string|undefined): string {
  const found = PENALTY_REASONS.find((r) => r.code === code);
  return found ? found.label : 'Other';
}
