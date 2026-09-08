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

/**
 * Whether the client has taken over from the prerendered HTML.
 *
 * The site is a static export: every page is built in English, so a translated
 * first client render would not match the served markup and React would throw
 * away the tree. useT() sidesteps this through its server snapshot; tr() is not
 * a hook and needs the same discipline, so it returns English until the shell
 * reports that hydration is done and re-renders everything below it.
 */
let hydrated = false;

/** Called once from a mount effect, after hydration has finished. */
export function markLocaleHydrated() {
  if (hydrated) return;
  hydrated = true;
  listeners.forEach((fn) => fn());
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
  return hydrated && currentLocale === "fr" ? "fr-FR" : "en-US";
}

/**
 * Split a source key into the text to show and its disambiguating context.
 *
 * The dictionary is keyed by English source text, which breaks when one
 * English word has two meanings — "End" is a column header in a timesheet and
 * a verb on a button, and French needs "Fin" for one and "Terminer" for the
 * other. Writing the key as "End|timesheet" keeps them apart: the part after
 * the pipe selects the translation and never reaches the screen, so English
 * still reads "End" whether or not anyone has translated it.
 */
function splitKey(key: string): { key: string; english: string } {
  const bar = key.indexOf("|");
  return bar === -1 ? { key, english: key } : { key, english: key.slice(0, bar) };
}

function interpolate(text: string, vars?: Record<string, string | number>) {
  if (!vars) return text;
  return Object.entries(vars).reduce((acc, [key, value]) => acc.replaceAll(`{${key}}`, String(value)), text);
}

/** Translate a source string for the current locale, with optional {var} interpolation. */
export function useT() {
  const locale = useLocale();
  return (en: string, vars?: Record<string, string | number>) => {
    const { key, english } = splitKey(en);
    const base = locale === "fr" ? FR[key] ?? english : english;
    return interpolate(base, vars);
  };
}

/**
 * Translate outside a component, for the same source-keyed dictionary as
 * useT().
 *
 * The locale lives in a module variable, so this needs no hook and can be
 * called from nested render helpers that are not components in their own
 * right. It does not subscribe: a locale change re-renders the shell, and the
 * page tree under it re-renders with it. Reach for useT() in a component that
 * can render independently of the shell.
 */
export function tr(en: string, vars?: Record<string, string | number>) {
  const { key, english } = splitKey(en);
  const base = hydrated && currentLocale === "fr" ? FR[key] ?? english : english;
  return interpolate(base, vars);
}
