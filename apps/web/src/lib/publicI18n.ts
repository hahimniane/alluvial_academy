"use client";

import { translate, useLocale } from "@/lib/localeStore";
import { FR_PUBLIC_SHARED } from "@/lib/translations/public/shared";
import { FR_PUBLIC_HOME } from "@/lib/translations/public/home";
import { FR_PUBLIC_ENROLL } from "@/lib/translations/public/enroll";
import { FR_PUBLIC_TEAM } from "@/lib/translations/public/team";

/**
 * French for the public website. Kept apart from the signed-in pages'
 * dictionary so a visitor reading the home page does not download the
 * student and teacher screens' text, and the other way round.
 */
export const FR_PUBLIC: Record<string, string> = {
  ...FR_PUBLIC_SHARED,
  ...FR_PUBLIC_HOME,
  ...FR_PUBLIC_ENROLL,
  ...FR_PUBLIC_TEAM,
};

/**
 * Translate a public-site string: `t("Enroll now")` gives the French when the
 * visitor chose French and an entry exists, the English otherwise. A hook, so
 * it is safe on the prerendered pages (the first paint matches the served
 * English and switches right after).
 */
export function usePublicT() {
  const locale = useLocale();
  return (en: string, vars?: Record<string, string | number>) => translate(FR_PUBLIC, locale, en, vars);
}
