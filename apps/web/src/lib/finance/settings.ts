/**
 * Finance settings the page can change, with the ranges the server accepts
 * (functions/handlers/finance_settings.js).
 */

export type NumericSettingKey = "issue_day" | "due_day" | "first_invoice_due_days" | "reminder_days_before";

export const NUMERIC_SETTINGS: ReadonlyArray<{
  key: NumericSettingKey;
  label: string;
  hint: string;
  min: number;
  max: number;
}> = [
  { key: "issue_day", label: "Invoices are issued on day", hint: "Day of the month a family's monthly invoice is created.", min: 1, max: 28 },
  { key: "due_day", label: "Invoices are due on day", hint: "Day of the following month the invoice is due.", min: 1, max: 28 },
  { key: "first_invoice_due_days", label: "First invoice is due after (days)", hint: "Days between a student's first class and the due date of the first invoice.", min: 0, max: 30 },
  { key: "reminder_days_before", label: "Reminder before the due date (days)", hint: "Parents get a reminder this many days before the due date, and again on it.", min: 0, max: 14 },
];

export type NumericParse = { ok: true; value: number } | { ok: false; error: string };

/** Reads what was typed into a number box. */
export function parseNumericSetting(key: NumericSettingKey, raw: string): NumericParse {
  const spec = NUMERIC_SETTINGS.find((s) => s.key === key);
  if (!spec) return { ok: false, error: "Unknown setting." };
  const text = raw.trim();
  if (!/^\d+$/.test(text)) return { ok: false, error: `Enter a whole number from ${spec.min} to ${spec.max}.` };
  const value = Number(text);
  if (value < spec.min || value > spec.max) return { ok: false, error: `Enter a whole number from ${spec.min} to ${spec.max}.` };
  return { ok: true, value };
}

/** "1st", "2nd", "25th". */
export function ordinal(n: number): string {
  const mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return `${n}th`;
  switch (n % 10) {
    case 1:
      return `${n}st`;
    case 2:
      return `${n}nd`;
    case 3:
      return `${n}rd`;
    default:
      return `${n}th`;
  }
}
