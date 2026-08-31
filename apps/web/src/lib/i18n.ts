"use client";

import { useSyncExternalStore } from "react";
import { doc, serverTimestamp, setDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { updateStudentSessionLanguage } from "@/lib/studentSession";
import { FR } from "@/lib/translations/fr";

/**
 * Lightweight i18n for the student dashboard.
 *
 * The Next app has no i18n framework, so this is a minimal external store:
 * strings are keyed by their English source text — t("No classes") returns the
 * French from the dictionary when the locale is fr, or the English itself
 * otherwise. Keying by source avoids inventing a key for every string while
 * retrofitting, and an untranslated string simply falls back to English rather
 * than showing a raw key.
 *
 * The locale mirrors the Flutter app: it is read from the user document's
 * language_preference and written back there, so switching language in either
 * client carries across.
 */
export type Locale = "en" | "fr";

const STORAGE_KEY = "student-locale";
let currentLocale: Locale = "en";
const listeners = new Set<() => void>();

function readStored(): Locale {
  if (typeof window === "undefined") return "en";
  try {
    return window.localStorage.getItem(STORAGE_KEY) === "fr" ? "fr" : "en";
  } catch {
    return "en";
  }
}

// Seed synchronously from localStorage so the first paint is in the right
// language on reload, before the user document has been read.
currentLocale = readStored();

export function getLocale(): Locale {
  return currentLocale;
}

/** Apply a locale everywhere and persist it locally (no Firestore write). */
export function applyLocale(next: Locale) {
  if (next === currentLocale) return;
  currentLocale = next;
  try {
    window.localStorage.setItem(STORAGE_KEY, next);
  } catch {}
  listeners.forEach((fn) => fn());
}

/** Change language: persist to the user document (Flutter reads the same field). */
export async function setLocale(uid: string | null, next: Locale) {
  applyLocale(next);
  // Mirror onto the cached session so a page remount adopts the same choice
  // instead of the pre-toggle value while the Firestore write is in flight.
  updateStudentSessionLanguage(next);
  if (!uid) return;
  try {
    await setDoc(doc(db, "users", uid), { language_preference: next, language_updated_at: serverTimestamp() }, { merge: true });
  } catch {
    // Local preference still applies even if the write fails.
  }
}

/**
 * Adopt the locale stored on the user document (called after sign-in).
 *
 * Only an explicit "en"/"fr" is adopted. When the field is absent — the common
 * case, since most user documents predate language_preference — we keep the
 * locally chosen locale instead of forcing English, so the in-app toggle isn't
 * reverted on every navigation before the preference has synced to Firestore.
 */
export function adoptRemoteLocale(value: unknown) {
  if (value !== "fr" && value !== "en") return;
  applyLocale(value);
}

function subscribe(callback: () => void) {
  listeners.add(callback);
  return () => listeners.delete(callback);
}

export function useLocale(): Locale {
  return useSyncExternalStore(subscribe, getLocale, () => "en");
}

/**
 * BCP-47 locale tag for date/time formatting that follows the current UI
 * language. French resolves to fr-FR, which formats times on a 24-hour clock
 * ("20:24") and dates with French month names ("11 août 2026"); English keeps
 * the US format the app has always shown. Pass this to toLocale*String /
 * Intl.DateTimeFormat instead of a hardcoded tag or undefined (which would
 * follow the browser locale rather than the in-app toggle).
 */
export function dateLocale(): string {
  return currentLocale === "fr" ? "fr-FR" : "en-US";
}

function interpolate(text: string, vars?: Record<string, string | number>) {
  if (!vars) return text;
  return Object.entries(vars).reduce((acc, [key, value]) => acc.replaceAll(`{${key}}`, String(value)), text);
}

/** Translate a source string for the current locale, with optional {var} interpolation. */
export function useT() {
  const locale = useLocale();
  return (en: string, vars?: Record<string, string | number>) => {
    const base = locale === "fr" ? FR[en] ?? en : en;
    return interpolate(base, vars);
  };
}
