import { PENALTY_REASONS, penaltyReasonLabel, type PenaltyReason } from "./penalties.ts";

/** One penalty or deduction on a teacher audit, as a teacher or Finance reads it. */
export type PenaltyEntry = {
  source: "coach_line" | "form_penalty" | "admin_adjustment";
  amount: number;
  reason: PenaltyReason;
  label: string;
  note: string;
};

function obj(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function num(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : value == null ? "" : String(value).trim();
}

function isCode(value: string): value is PenaltyReason {
  return PENALTY_REASONS.some((r) => r.code === value);
}

/**
 * Reads a stored reason. An entry without a valid code is "other" and its old
 * free text becomes the note.
 */
export function readPenaltyReason(code: unknown, note: unknown, legacyText: unknown): { reason: PenaltyReason; note: string } {
  const c = text(code);
  if (isCode(c)) return { reason: c, note: text(note) };
  const old = text(note) || text(legacyText);
  return { reason: "other", note: old === "—" ? "" : old };
}

/** Every penalty and deduction in an audit's `paymentSummary`, with its reason. */
export function readPenaltyEntries(paymentSummary: unknown): PenaltyEntry[] {
  const ps = obj(paymentSummary);
  const out: PenaltyEntry[] = [];
  const lines = Array.isArray(ps.coachAdjustmentLines) ? ps.coachAdjustmentLines : Array.isArray(ps.adjustmentLines) ? ps.adjustmentLines : [];
  for (const raw of lines) {
    const line = obj(raw);
    if (text(line.type) === "bonus") continue;
    const amount = Math.abs(num(line.amount));
    if (amount === 0) continue;
    const r = readPenaltyReason(line.penalty_reason, line.penalty_note, line.reason);
    out.push({ source: "coach_line", amount, reason: r.reason, label: penaltyReasonLabel(r.reason), note: r.note });
  }
  const formTotal = num(ps.formPenaltyTotal);
  if (formTotal > 0) {
    const r = readPenaltyReason(ps.formPenaltyReason, ps.formPenaltyNote, "");
    out.push({ source: "form_penalty", amount: formTotal, reason: r.reason, label: penaltyReasonLabel(r.reason), note: r.note });
  }
  const adjustment = num(ps.adminAdjustment);
  if (adjustment < 0) {
    const r = readPenaltyReason(ps.adjustmentPenaltyReason, ps.adjustmentPenaltyNote, ps.adjustmentReason);
    out.push({ source: "admin_adjustment", amount: Math.abs(adjustment), reason: r.reason, label: penaltyReasonLabel(r.reason), note: r.note });
  }
  return out;
}
