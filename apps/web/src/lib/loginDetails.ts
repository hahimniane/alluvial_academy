/**
 * Sending a student's login details (F2): the WhatsApp message, the guardian
 * contacts it can go to, and the printed login card. Pure; the email goes
 * through the sendStudentLoginDetails callable (usersExtrasData.ts), which
 * reads the password on the server.
 *
 * WhatsApp opens on the admin's own device with the text filled in. Nothing is
 * sent until the admin presses send there.
 */

import { displayNameOf, loginEmailOf, type UserRow } from "./adminUsers.ts";
import { guardiansOfStudent } from "./guardians.ts";
import { storedPhoneForms } from "./phoneNumbers.ts";

export const SCHOOL_NAME = "Alluwal Education Hub";
export const SIGN_IN_ADDRESS = "alluwaleducationhub.org/student/login";
export const SCHOOL_LOGO = "/assets/Alluwal_Education_Hub_Logo.png";

const STUDENT_ALIAS_DOMAIN = "@alluwaleducationhub.org";

/**
 * The number wa.me wants: country code and number, digits only. A number
 * stored without its `+` uses the profile's country code. null when there is
 * no usable number.
 */
export function whatsAppNumber(phone: string, countryCode: string): string | null {
  const forms = storedPhoneForms(phone, countryCode);
  const digits = (forms[0] ?? "").replace(/\D/g, "");
  return digits.length >= 8 && digits.length <= 15 ? digits : null;
}

/** A guardian's real email (`e-mail`, else `email`); the school's student aliases reach nobody. */
export function guardianEmail(row: Pick<UserRow, "email" | "otherEmail">): string {
  for (const value of [row.email, row.otherEmail]) {
    const e = value.trim().toLowerCase();
    if (e && e.includes("@") && !e.endsWith(STUDENT_ALIAS_DOMAIN)) return e;
  }
  return "";
}

export type GuardianContact = {
  id: string;
  name: string;
  /** Digits for wa.me, or null. */
  whatsApp: string | null;
  email: string;
  isActive: boolean;
  /** The server emails only guardians listed on the student's own document. */
  onStudentDoc: boolean;
};

/** The student's guardians that have an account, with how each can be reached. */
export function guardianContacts(student: UserRow, rows: readonly UserRow[], byId: Map<string, UserRow>): GuardianContact[] {
  const onDoc = new Set([...student.guardianIds]);
  return guardiansOfStudent(student, rows, byId)
    .filter((g) => g.row)
    .map((g) => {
      const row = g.row!;
      return {
        id: g.id,
        name: displayNameOf(row),
        whatsApp: whatsAppNumber(row.phone, row.countryCode),
        email: guardianEmail(row),
        isActive: row.isActive,
        onStudentDoc: onDoc.has(g.id),
      };
    });
}

export type MessageLanguage = "en" | "fr";

export type LoginFacts = {
  studentName: string;
  studentCode: string;
  loginEmail: string;
  password: string;
};

export function loginFactsOf(student: UserRow, password: string): LoginFacts {
  return { studentName: displayNameOf(student), studentCode: student.storedStudentCode, loginEmail: loginEmailOf(student), password };
}

/** The WhatsApp text. Names keep their accents. */
export function loginMessage(facts: LoginFacts, guardianName: string, language: MessageLanguage): string {
  const greetingName = guardianName.trim();
  if (language === "fr") {
    return [
      greetingName ? `Bonjour ${greetingName},` : "Bonjour,",
      "",
      `Voici les identifiants de ${facts.studentName} pour ${SCHOOL_NAME} :`,
      `Identifiant élève : ${facts.studentCode}`,
      `Mot de passe : ${facts.password}`,
      "",
      `Connexion : ${SIGN_IN_ADDRESS} ou l'application Alluwal, avec l'identifiant élève et le mot de passe.`,
      "Merci de garder ces informations confidentielles.",
    ].join("\n");
  }
  return [
    greetingName ? `Hello ${greetingName},` : "Hello,",
    "",
    `Here are ${facts.studentName}'s login details for ${SCHOOL_NAME}:`,
    `Student ID: ${facts.studentCode}`,
    `Password: ${facts.password}`,
    "",
    `Sign in at ${SIGN_IN_ADDRESS} or in the Alluwal app, with the Student ID and password.`,
    "Please keep these details private.",
  ].join("\n");
}

/** wa.me link with the text filled in; with no number, WhatsApp asks whom to send it to. */
export function whatsAppUrl(number: string | null, text: string): string {
  return `https://wa.me/${number ?? ""}?text=${encodeURIComponent(text)}`;
}

/** Why a student's details cannot be sent yet, or null when they can. */
export function loginDetailsProblem(student: Pick<UserRow, "storedStudentCode">, password: string | null): string | null {
  if (!student.storedStudentCode) return "This student has no Student ID yet. Reset the password to make one.";
  if (password !== null && !password) return "No password is stored for this student. Reset the password first.";
  return null;
}

/** sendStudentLoginDetails's answer in the admin's words. */
export function emailResultText(result: { sentTo: string[]; failed: string[]; noEmail: string[] }): { text: string; tone: "ok" | "error" } {
  const join = (names: string[]) => (names.length <= 1 ? names[0] ?? "" : `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`);
  const parts: string[] = [];
  if (result.sentTo.length > 0) parts.push(`Login details emailed to ${join(result.sentTo)}.`);
  if (result.failed.length > 0) parts.push(`Could not email ${join(result.failed)}.`);
  if (result.noEmail.length > 0) parts.push(`${join(result.noEmail)} ${result.noEmail.length > 1 ? "have" : "has"} no email address.`);
  return { text: parts.join(" "), tone: result.failed.length > 0 ? "error" : "ok" };
}
