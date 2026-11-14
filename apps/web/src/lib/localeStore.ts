"use client";

import { useSyncExternalStore } from "react";

/**
 * The site's language choice, shared by every page: the public site, the
 * student pages and the teacher pages all read and change the same value. It
 * holds no dictionary and no Firebase, so a public page can use it without
 * pulling either in.
 */
export type Locale = "en" | "fr";

const STORAGE_KEY = "student-locale";
let currentLocale: Locale = "en";
const listeners = new Set<() => void>();

function readStored(): Locale | null {
  if (typeof window === "undefined") return null;
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    return stored === "fr" || stored === "en" ? stored : null;
  } catch {
    return null;
  }
}

// Seed synchronously from localStorage so the first paint is in the right
// language on reload, before the user document has been read.
currentLocale = readStored() ?? "en";

export function getLocale(): Locale {
  return currentLocale;
}

/** True once the visitor (or their account) has picked a language. */
export function hasStoredLocale(): boolean {
  return readStored() !== null;
}

/** Apply a locale everywhere and persist it locally (no Firestore write). */
export function applyLocale(next: Locale) {
  if (next === currentLocale && hasStoredLocale()) return;
  currentLocale = next;
  try {
    window.localStorage.setItem(STORAGE_KEY, next);
  } catch {}
  listeners.forEach((fn) => fn());
}

/**
 * Whether the client has taken over from the prerendered HTML.
 *
 * The site is a static export: every page is built in English, so a translated
 * first client render would not match the served markup and React would throw
 * away the tree. The hooks sidestep this through their server snapshot; plain
 * functions need the same discipline, so they return English until the shell
 * reports that hydration is done and re-renders everything below it.
 */
let hydrated = false;

/** Called once from a mount effect, after hydration has finished. */
export function markLocaleHydrated() {
  if (hydrated) return;
  hydrated = true;
  listeners.forEach((fn) => fn());
}

export function isLocaleHydrated(): boolean {
  return hydrated;
}

function subscribe(callback: () => void) {
  listeners.add(callback);
  return () => listeners.delete(callback);
}

export function useLocale(): Locale {
  return useSyncExternalStore(subscribe, getLocale, () => "en");
}

/**
 * Split a source key into the text to show and its disambiguating context.
 *
 * The dictionaries are keyed by English source text, which breaks when one
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

/**
 * The text to show for an English source string: its French from `dictionary`
 * when the locale is French and an entry exists, the English otherwise, with
 * {var} placeholders filled in.
 */
export function translate(dictionary: Record<string, string>, locale: Locale, en: string, vars?: Record<string, string | number>) {
  const { key, english } = splitKey(en);
  const base = locale === "fr" ? dictionary[key] ?? english : english;
  return interpolate(base, vars);
}

/** Whether the browser asks for French first (fr, fr-FR, fr-CA, ...). */
export function browserPrefersFrench(languages: readonly string[] | undefined, fallback?: string): boolean {
  const first = (languages && languages.length > 0 ? languages[0] : fallback) ?? "";
  return first.toLowerCase().startsWith("fr");
}
