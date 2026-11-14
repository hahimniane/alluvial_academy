"use client";

import { useEffect } from "react";
import { applyLocale, browserPrefersFrench, hasStoredLocale, useLocale } from "@/lib/localeStore";
import { usePublicT } from "@/lib/publicI18n";

/**
 * EN / FR choice for the public site. A visitor who has never chosen gets
 * French when their browser asks for French; after that their own choice
 * wins, on every page of the site including the student and teacher pages.
 */
export function LanguageSwitch({ tone = "light" }: { tone?: "light" | "dark" }) {
  const locale = useLocale();
  const t = usePublicT();

  useEffect(() => {
    if (!hasStoredLocale() && browserPrefersFrench(navigator.languages, navigator.language)) applyLocale("fr");
  }, []);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  const base = "px-2.5 py-1 text-xs font-bold transition";
  const on = tone === "dark" ? "bg-white text-[#001E4E]" : "bg-[#001E4E] text-white";
  const off = tone === "dark" ? "text-white/80 hover:text-white" : "text-[#475569] hover:text-[#001E4E]";
  return (
    <div
      role="group"
      aria-label={t("Language")}
      className={`inline-flex overflow-hidden rounded-full border ${tone === "dark" ? "border-white/30" : "border-[#CBD5E1]"}`}
    >
      <button type="button" lang="en" aria-pressed={locale === "en"} aria-label={t("Switch to English")} onClick={() => applyLocale("en")} className={`${base} ${locale === "en" ? on : off}`}>
        EN
      </button>
      <button type="button" lang="fr" aria-pressed={locale === "fr"} aria-label={t("Switch to French")} onClick={() => applyLocale("fr")} className={`${base} ${locale === "fr" ? on : off}`}>
        FR
      </button>
    </div>
  );
}
