/**
 * Admin decisions on a form submission (form_responses.reviewStatus), written by
 * the Flutter review panel. Mirrors FormReviewStatus in
 * lib/features/forms/widgets/form_review_status_badge.dart.
 */
export type ReviewStatus = "" | "seen" | "in review" | "accepted" | "rejected";

const known: ReviewStatus[] = ["seen", "in review", "accepted", "rejected"];

export function normalizeReviewStatus(value: unknown): ReviewStatus {
  const normalized = typeof value === "string" ? value.trim().toLowerCase() : "";
  return (known as string[]).includes(normalized) ? (normalized as ReviewStatus) : "";
}

/** English source text; callers translate it. */
export function reviewStatusLabel(status: ReviewStatus): string {
  switch (status) {
    case "seen":
      return "Seen";
    case "in review":
      return "In review";
    case "accepted":
      return "Accepted";
    case "rejected":
      return "Rejected";
    default:
      return "Not reviewed";
  }
}

export function reviewStatusClasses(status: ReviewStatus): string {
  switch (status) {
    case "accepted":
      return "bg-[#DCFCE7] text-[#16A34A]";
    case "rejected":
      return "bg-[#FEE2E2] text-[#DC2626]";
    case "in review":
      return "bg-[#FEF3C7] text-[#B45309]";
    case "seen":
      return "bg-[#EFF6FF] text-[#0386FF]";
    default:
      return "bg-[#F1F5F9] text-[#64748B]";
  }
}

/** Accepted / rejected / still waiting, as the app's form cards count them. */
export function decisionCounts(statuses: ReviewStatus[]) {
  let accepted = 0;
  let rejected = 0;
  for (const status of statuses) {
    if (status === "accepted") accepted += 1;
    else if (status === "rejected") rejected += 1;
  }
  return { accepted, rejected, awaiting: statuses.length - accepted - rejected };
}
