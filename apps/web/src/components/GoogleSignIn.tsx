"use client";

import { useState } from "react";
import { GoogleAuthProvider, signInWithPopup } from "firebase/auth";
import { ArrowLeft } from "lucide-react";
import { ensureAuthPersistence, requireAuth } from "@/lib/firebase";
import { dashboardPathForUser } from "@/lib/userRoles";
import { afterSignIn, requireRegistered } from "@/lib/signInChecks";
import { googleErrorText } from "@/lib/googleSignInErrors";
import { flutterLoginUrl } from "@/lib/flutterApp";
import { usePublicT } from "@/lib/publicI18n";

export function GoogleSignIn() {
  const t = usePublicT();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  async function signIn() {
    setBusy(true);
    setMessage("");
    try {
      await ensureAuthPersistence();
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: "select_account" });
      const { user } = await signInWithPopup(requireAuth(), provider);
      await requireRegistered(user);
      await afterSignIn(user);
      window.location.replace(await dashboardPathForUser(user));
    } catch (error) {
      const text = googleErrorText(error);
      if (text) setMessage(t(text));
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#F8FAFC] px-4 py-8">
      <div className="grid w-full max-w-[420px] gap-5 rounded-2xl bg-white p-6 text-center shadow-[0_8px_24px_rgba(15,23,42,0.08)]">
        <div className="mx-auto flex h-[88px] w-[88px] items-center justify-center rounded-[18px] bg-[#F8FAFC] p-3 shadow-[0_6px_20px_rgba(15,23,42,0.08)]">
          <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="Alluwal Education Hub" className="h-full w-full object-contain" />
        </div>
        <h1 className="text-xl font-bold tracking-[-0.02em] text-[#111827]">{t("Sign in with your Google account")}</h1>
        <button
          type="button"
          onClick={signIn}
          disabled={busy}
          className="flex min-h-12 items-center justify-center gap-3 rounded-xl border border-[#D1D5DB] bg-white px-5 text-base font-semibold text-[#374151] transition hover:bg-[#F9FAFB] disabled:cursor-wait disabled:opacity-70"
        >
          <span className="text-lg font-bold text-[#4285F4]" aria-hidden>G</span>
          {busy ? t("Signing in…") : t("Continue with Google")}
        </button>
        {message ? (
          <p role="alert" className="rounded-xl bg-[#FEF2F2] px-4 py-3 text-sm font-medium text-[#B91C1C]">
            {message}
          </p>
        ) : null}
        <a href={flutterLoginUrl} className="inline-flex items-center justify-center gap-2 text-sm font-medium text-[#0386FF]">
          <ArrowLeft size={16} />
          {t("Back to sign in")}
        </a>
      </div>
    </main>
  );
}
