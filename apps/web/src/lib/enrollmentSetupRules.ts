/**
 * The decisions in the setup steps that do not need Firebase — kept separate so
 * they can be tested without standing up an app.
 */

/** First and last name, preferring what was captured at submission. */
export const splitStudentName = (
  firstName: string,
  lastName: string,
  fullName: string,
): { firstName: string; lastName: string } => {
  let first = firstName.trim();
  let last = lastName.trim();
  if (!first || !last) {
    const parts = fullName.trim().split(/\s+/).filter(Boolean);
    if (!first && parts.length > 0) first = parts[0];
    if (!last && parts.length > 1) last = parts.slice(1).join(" ");
  }
  return { firstName: first || "Student", lastName: last || "Unknown" };
};

export type ParentInvite = {
  email: string;
  firstName: string;
  lastName: string;
  phone: string;
  countryCode: string;
};

/** Why an invite cannot be sent, or null when it can. */
export const parentInviteProblem = (invite: ParentInvite): string | null => {
  const email = invite.email.trim();
  if (!email) return "Enter the parent's email address.";
  if (!email.includes("@")) return "Enter a valid email address.";
  return null;
};

/**
 * Why a monthly amount cannot be saved yet, or null when it can. Mirrors the
 * setEnrollmentMonthlyAmount callable: above $0, and 1 to 62 classes in a
 * full month.
 */
export const monthlyAmountProblem = (amount: string, classesInMonth: string): string | null => {
  const amountValue = Number(amount);
  const classesValue = Number(classesInMonth);
  if (amount.trim() === "" || !Number.isFinite(amountValue) || !(amountValue > 0)) return "Enter the monthly amount.";
  if (classesInMonth.trim() === "" || !Number.isInteger(classesValue) || classesValue < 1 || classesValue > 62) {
    return "Enter how many classes a full month has.";
  }
  return null;
};

/** "$80", "$82.50". */
export const dollars = (n: number): string => `$${n.toFixed(2).replace(/\.00$/, "")}`;
