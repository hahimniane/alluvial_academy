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
