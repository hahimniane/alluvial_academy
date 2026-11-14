"use client";

import { usePublicT } from "@/lib/publicI18n";

/** Shown while the enrollment form reads the page address. */
export function EnrollLoadingFallback() {
  const t = usePublicT();
  return <div className="container-shell py-16 text-slate-600">{t("Loading enrollment...")}</div>;
}

/** Shown while the program catalog reads the page address. */
export function ProgramsLoadingFallback() {
  const t = usePublicT();
  return <div className="container-shell py-16 text-slate-600">{t("Loading programs...")}</div>;
}
