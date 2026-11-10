/**
 * What the New students table shows beside each row: the student's ID code
 * and the family's monthly amount. Pure readers over the stored documents so
 * they can be tested without Firebase.
 */

type Rec = Record<string, unknown>;

const str = (v: unknown): string => (v === null || v === undefined ? "" : String(v).trim());
const rec = (v: unknown): Rec => (v && typeof v === "object" && !Array.isArray(v) ? (v as Rec) : {});

/** The Student ID a student signs in with (users.student_code, else the kiosk code). */
export function studentCodeOf(data: Rec): string {
  return str(data.student_code ?? data.studentCode) || str(data.kiosk_code);
}

/**
 * A family_billing document as the New students table needs it: the monthly
 * amount once the first invoice set it, and the amounts entered at
 * registration that wait for a student's first class.
 */
export type FamilyBillingLite = { monthly: number; pending: Record<string, number> };

export function readFamilyBillingLite(data: Rec): FamilyBillingLite {
  const monthly = Number(data.monthly_amount);
  const pending: Record<string, number> = {};
  for (const [studentId, entry] of Object.entries(rec(data.pending_first_invoices))) {
    const amount = Number(rec(entry).monthly_amount);
    const id = str(rec(entry).student_id) || studentId;
    if (id && Number.isFinite(amount) && amount > 0) pending[id] = amount;
  }
  return { monthly: Number.isFinite(monthly) && monthly > 0 ? monthly : 0, pending };
}

/**
 * The monthly amount to show for a row: the family's billed amount, else what
 * was entered at registration for these students (summed when a family class
 * has several). Null when nothing is set.
 */
export function rowMonthlyAmount(billing: FamilyBillingLite | undefined, studentIds: readonly string[]): number | null {
  if (!billing) return null;
  if (billing.monthly > 0) return billing.monthly;
  const waiting = studentIds.map((id) => billing.pending[id]).filter((n): n is number => typeof n === "number" && n > 0);
  if (waiting.length === 0) return null;
  return Math.round(waiting.reduce((s, n) => s + n, 0) * 100) / 100;
}
