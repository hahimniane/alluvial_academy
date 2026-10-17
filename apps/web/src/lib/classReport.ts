/**
 * Which classes a teacher can file a class (readiness) report for, and which
 * template that report uses.
 *
 * The dashboard lists classes still waiting on a report from the last 60 days
 * and the shift page offers "Fill Class Report" for any class that has ended,
 * so the picker has to accept the same set: a class that started inside the
 * rolling window, has ended (or was already closed as completed/missed), and
 * was not cancelled. A class still marked scheduled or active after its end
 * time is a class the teacher taught and must be able to report on.
 */

export const CLASS_REPORT_WINDOW_DAYS = 60;

const DAY_MS = 24 * 60 * 60 * 1000;
const CLOSED_STATUSES = new Set(["completed", "fullycompleted", "partiallycompleted", "missed"]);

export function classReportWindowStart(now: Date): Date {
  return new Date(now.getTime() - CLASS_REPORT_WINDOW_DAYS * DAY_MS);
}

function compactStatus(status: string) {
  return status.toLowerCase().replace(/[\s_-]+/g, "");
}

export function isCancelledShiftStatus(status: string) {
  const normalized = status.toLowerCase();
  return normalized.includes("cancel") || normalized.includes("deleted") || normalized.includes("void");
}

export type ClassReportCandidate = {
  start: Date | null;
  end: Date | null;
  status: string;
};

export function isClassReportEligible(shift: ClassReportCandidate, now: Date): boolean {
  const { start, end } = shift;
  if (!start || !end) return false;
  if (isCancelledShiftStatus(shift.status)) return false;
  if (start.getTime() < classReportWindowStart(now).getTime()) return false;
  if (start.getTime() >= now.getTime()) return false;
  return end.getTime() < now.getTime() || CLOSED_STATUSES.has(compactStatus(shift.status));
}

export type ClassReportTemplateCandidate = {
  id: string;
  name: string;
  frequency: string;
  isActive: boolean;
  version?: number;
  updatedAt?: Date | null;
};

function newestFirst(a: ClassReportTemplateCandidate, b: ClassReportTemplateCandidate) {
  const version = (b.version ?? 0) - (a.version ?? 0);
  if (version !== 0) return version;
  const updated = (b.updatedAt?.getTime() ?? 0) - (a.updatedAt?.getTime() ?? 0);
  if (updated !== 0) return updated;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

/**
 * The template a class report is filed on: the one `settings/form_config`
 * names as `dailyTemplateId` while it is active, else an active per-class
 * template called a daily class report, else the newest active per-class
 * template. Ties are broken the same way every time, so two teachers never get
 * different forms for the same class.
 */
export function chooseClassReportTemplate<T extends ClassReportTemplateCandidate>(templates: readonly T[], dailyTemplateId?: string | null): T | null {
  const perSession = templates.filter((template) => template.isActive && template.frequency === "perSession").sort(newestFirst);
  const configuredId = (dailyTemplateId ?? "").trim();
  if (configuredId) {
    const configured = perSession.find((template) => template.id === configuredId);
    if (configured) return configured;
  }
  const named = perSession.find((template) => {
    const name = template.name.toLowerCase();
    return name.includes("daily") && name.includes("class");
  });
  return named ?? perSession[0] ?? null;
}
