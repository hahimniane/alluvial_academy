/**
 * TypeScript port of the Flutter app's search (lib/core/utils/app_search.dart),
 * so a Next screen finds exactly the people the Flutter screen it replaces
 * finds. Keep the two in step.
 */

export const normalizeText = (value: string): string => value.trim().toLowerCase().replace(/\s+/g, " ");
export const digitsOnly = (value: string): string => value.replace(/[^0-9]/g, "");
export const normalizeIdentifier = (value: string): string => normalizeText(value).replace(/[^a-z0-9]/g, "");
export const looksLikePhone = (value: string): boolean => /^[\d\s()+.-]+$/.test(value.trim());

const phoneVariants = (digits: string): string[] => {
  const set = new Set([digits]);
  if (digits.startsWith("0") && digits.length > 7) set.add(digits.slice(1));
  return [...set];
};

export type SearchFields = {
  names?: readonly string[];
  emails?: readonly string[];
  phones?: readonly string[];
  ids?: readonly string[];
  additionalValues?: readonly string[];
};

/** AppSearch.matches with SearchNameMode.contains. */
export function appSearchMatches(query: string, fields: SearchFields): boolean {
  const q = normalizeText(query);
  if (!q) return true;
  if ((fields.names ?? []).some((name) => normalizeText(name).includes(q))) return true;
  if ((fields.emails ?? []).some((email) => normalizeText(email).includes(q))) return true;

  const idQuery = normalizeIdentifier(query);
  if (
    (fields.ids ?? []).some(
      (id) => normalizeText(id).includes(q) || (idQuery !== "" && normalizeIdentifier(id).includes(idQuery)),
    )
  ) {
    return true;
  }

  const queryDigits = digitsOnly(query);
  if (looksLikePhone(query) && queryDigits.length >= 7) {
    const queryForms = phoneVariants(queryDigits);
    const phoneMatch = (fields.phones ?? []).some((phone) => {
      const phoneDigits = digitsOnly(phone);
      if (phoneDigits.length < 7) return false;
      const phoneForms = phoneVariants(phoneDigits);
      return queryForms.some((qv) => phoneForms.some((pv) => pv === qv || pv.endsWith(qv) || qv.endsWith(pv)));
    });
    if (phoneMatch) return true;
  }

  return (fields.additionalValues ?? []).some((value) => normalizeText(value).includes(q));
}

type Data = Record<string, unknown>;

/** Dart `value.toString()` for the values a user document holds; null/undefined skipped by the caller. */
const asText = (value: unknown): string => {
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") return String(value);
  if (Array.isArray(value)) return `[${value.map(asText).join(", ")}]`;
  return String(value);
};

const values = (data: Data, keys: readonly string[]): string[] => {
  const out: string[] = [];
  for (const key of keys) {
    const value = data[key];
    if (value !== null && value !== undefined) out.push(asText(value));
  }
  return out;
};

const firstValue = (data: Data, keys: readonly string[]): string => {
  for (const key of keys) {
    const value = data[key];
    const text = value === null || value === undefined ? "" : asText(value).trim();
    if (text) return text;
  }
  return "";
};

export const NAME_KEYS = ["name", "displayName", "display_name", "fullName", "full_name", "userName"] as const;
export const FIRST_NAME_KEYS = ["first_name", "firstName", "userFirstName"] as const;
export const LAST_NAME_KEYS = ["last_name", "lastName", "userLastName"] as const;
export const EMAIL_KEYS = ["email", "e-mail", "userEmail", "user_email"] as const;
export const PHONE_KEYS = ["phone", "phone_number", "phoneNumber", "mobile_phone", "mobilePhone", "userPhone", "user_phone"] as const;
export const ID_KEYS = [
  "id",
  "uid",
  "documentId",
  "document_id",
  "authUid",
  "auth_uid",
  "userId",
  "user_id",
  "teacherId",
  "teacher_id",
  "studentId",
  "student_id",
  "studentCode",
  "student_code",
  "kioskCode",
  "kiosk_code",
  "kiosqueCode",
] as const;

/** The fields AppSearch.matchesMap reads from a record, gathered once. */
export function searchFieldsOfMap(data: Data, documentId?: string): SearchFields {
  const firstName = firstValue(data, FIRST_NAME_KEYS);
  const lastName = firstValue(data, LAST_NAME_KEYS);
  return {
    names: [...values(data, NAME_KEYS), `${firstName} ${lastName}`.trim(), `${lastName} ${firstName}`.trim()],
    emails: values(data, EMAIL_KEYS),
    phones: values(data, PHONE_KEYS),
    ids: [...(documentId !== undefined ? [documentId] : []), ...values(data, ID_KEYS)],
  };
}

export { firstValue as firstTextValue };
