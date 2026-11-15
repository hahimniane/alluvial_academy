"use client";

import { EmailAuthProvider, reauthenticateWithCredential, updatePassword } from "firebase/auth";
import { useEffect, useState } from "react";
import { CheckCircle2, Eye, EyeOff, Globe2, KeyRound, Loader2, Settings } from "lucide-react";
import { auth } from "@/lib/firebase";
import { useParentSession, useUpdateParentSession } from "@/components/ParentArea";
import { setLocale, useLocale, type Locale } from "@/lib/i18n";
import { parentFormsText } from "@/lib/parentFormsText";

/** Set at build time when the deploy stamps a version; the line is left out otherwise. */
const BUILD_VERSION = process.env.NEXT_PUBLIC_WEB_BUILD_VERSION ?? "";

/**
 * Settings (RoleSettingsScreen "Parent Settings", A-091…A-095): language,
 * change password and the build version. Nothing else, as in the app.
 */
export default function ParentSettingsPage() {
  const session = useParentSession();
  const updateSession = useUpdateParentSession();
  const locale = useLocale();
  const text = parentFormsText(locale === "fr");
  const [passwordOpen, setPasswordOpen] = useState(false);
  const [toast, setToast] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 3500);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const choose = (next: Locale) => {
    if (next === locale) return;
    // Saved on this browser and on the account, so the app and other devices follow.
    void setLocale(session.uid, next);
    updateSession({ language: next });
  };

  return (
    <div className="min-h-full bg-[#F8FAFC]">
      <div className="mx-auto grid w-full max-w-[860px] gap-4 p-6 max-[600px]:p-4">
        <section className="flex items-center gap-4 rounded-2xl bg-[#1E293B] p-6 text-white">
          <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-white/10">
            <Settings size={26} />
          </span>
          <div className="min-w-0">
            <h1 className="text-xl font-bold">{text.settingsTitle}</h1>
            <p className="mt-1 text-sm text-white/70">{text.settingsSubtitle}</p>
          </div>
        </section>

        <section className="flex flex-wrap items-center gap-4 rounded-2xl border border-[#E5E7EB] bg-white p-5">
          <Badge icon={<Globe2 size={22} />} />
          <div className="min-w-0 flex-1">
            <h2 className="text-base font-bold text-[#111827]">{text.language}</h2>
            <p className="mt-0.5 text-sm text-[#6B7280]">{text.chooseLanguage}</p>
          </div>
          <div role="group" aria-label={text.language} className="inline-flex overflow-hidden rounded-xl border border-[#CBD5E1]">
            {(
              [
                ["en", "English"],
                ["fr", "Français"],
              ] as const
            ).map(([code, label]) => (
              <button
                key={code}
                type="button"
                lang={code}
                aria-pressed={locale === code}
                onClick={() => choose(code)}
                className={`min-h-10 px-4 text-sm font-semibold ${locale === code ? "bg-[#0386FF] text-white" : "bg-white text-[#334155] hover:bg-[#F1F5F9]"}`}
              >
                {label}
              </button>
            ))}
          </div>
        </section>

        <section className="flex flex-wrap items-center gap-4 rounded-2xl border border-[#E5E7EB] bg-white p-5">
          <Badge icon={<KeyRound size={22} />} />
          <div className="min-w-0 flex-1">
            <h2 className="text-base font-bold text-[#111827]">Change Password</h2>
            <p className="mt-0.5 text-sm text-[#6B7280]">Update your account password</p>
          </div>
          <button type="button" onClick={() => setPasswordOpen(true)} className="min-h-10 rounded-xl bg-[#0386FF] px-5 text-sm font-semibold text-white">
            Change
          </button>
        </section>

        {BUILD_VERSION ? (
          <section className="flex items-center gap-4 rounded-2xl border border-[#E5E7EB] bg-white p-5 text-sm">
            <span className="w-[110px] shrink-0 font-semibold text-[#6B7280]">{text.version}</span>
            <span className="min-w-0 flex-1 truncate font-medium text-[#111827]">{BUILD_VERSION}</span>
          </section>
        ) : null}
      </div>

      {passwordOpen ? (
        <PasswordDialog
          onClose={() => setPasswordOpen(false)}
          onResult={(ok, message) => {
            if (ok) setPasswordOpen(false);
            setToast({ ok, text: message });
          }}
          cancelLabel={locale === "fr" ? "Annuler" : "Cancel"}
        />
      ) : null}

      {toast ? (
        <div role="status" className={`fixed bottom-6 left-1/2 z-[95] flex max-w-[92vw] -translate-x-1/2 items-center gap-2 rounded-lg px-4 py-3 text-sm font-medium text-white shadow-lg ${toast.ok ? "bg-[#10B981]" : "bg-[#EF4444]"}`}>
          {toast.ok ? <CheckCircle2 size={18} /> : null}
          {toast.text}
        </div>
      ) : null}
    </div>
  );
}

function Badge({ icon }: { icon: React.ReactNode }) {
  return <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-[#EFF6FF] text-[#0386FF]">{icon}</span>;
}

/**
 * The app's Change Password dialog: current, new and confirm, each with a
 * show/hide eye; re-authenticate, then update. No Firestore write.
 */
function PasswordDialog({ onClose, onResult, cancelLabel }: { onClose: () => void; onResult: (ok: boolean, message: string) => void; cancelLabel: string }) {
  const [values, setValues] = useState({ current: "", next: "", confirm: "" });
  const [errors, setErrors] = useState<{ current?: string; next?: string; confirm?: string }>({});
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    const nextErrors = {
      current: values.current ? undefined : "Enter your current password",
      next: !values.next ? "Enter a new password" : values.next.length < 6 ? "Password must be at least 6 characters" : undefined,
      confirm: values.confirm !== values.next ? "Passwords do not match" : undefined,
    };
    setErrors(nextErrors);
    if (nextErrors.current || nextErrors.next || nextErrors.confirm) return;
    const user = auth.currentUser;
    if (!user?.email) {
      onResult(false, "This account has no email address, so its password cannot be changed here.");
      return;
    }
    setBusy(true);
    try {
      await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, values.current));
      await updatePassword(user, values.next);
      onResult(true, "Password changed successfully.");
    } catch (error) {
      const code = typeof error === "object" && error && "code" in error ? String((error as { code: unknown }).code) : "";
      if (code.includes("wrong-password") || code.includes("invalid-credential")) onResult(false, "Current password is incorrect.");
      else if (code.includes("weak-password")) onResult(false, "New password is too weak.");
      else onResult(false, "Failed to change password.");
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[90] grid place-items-center bg-black/45 p-4" role="dialog" aria-modal="true" aria-label="Change Password">
      <form
        noValidate
        onSubmit={(event) => {
          event.preventDefault();
          void submit();
        }}
        className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl"
      >
        <h2 className="text-xl font-bold text-[#111827]">Change Password</h2>
        <div className="mt-5 grid gap-4">
          <PasswordField label="Current Password" value={values.current} error={errors.current} autoComplete="current-password" onChange={(current) => setValues({ ...values, current })} />
          <PasswordField label="New Password" value={values.next} error={errors.next} autoComplete="new-password" onChange={(next) => setValues({ ...values, next })} />
          <PasswordField label="Confirm New Password" value={values.confirm} error={errors.confirm} autoComplete="new-password" onChange={(confirm) => setValues({ ...values, confirm })} />
        </div>
        <div className="mt-6 flex justify-end gap-3">
          <button type="button" disabled={busy} onClick={onClose} className="min-h-11 rounded-xl px-4 text-sm font-semibold text-[#6B7280] hover:bg-[#F3F4F6]">
            {cancelLabel}
          </button>
          <button type="submit" disabled={busy} className="inline-flex min-h-11 min-w-[150px] items-center justify-center rounded-xl bg-[#0386FF] px-5 text-sm font-semibold text-white disabled:opacity-70">
            {busy ? <Loader2 size={18} className="animate-spin" aria-label="Updating password" /> : "Update Password"}
          </button>
        </div>
      </form>
    </div>
  );
}

function PasswordField({ label, value, error, autoComplete, onChange }: { label: string; value: string; error?: string; autoComplete: string; onChange: (value: string) => void }) {
  const [shown, setShown] = useState(false);
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-medium text-[#374151]">{label}</span>
      <span className="relative block">
        <input
          type={shown ? "text" : "password"}
          value={value}
          autoComplete={autoComplete}
          onChange={(event) => onChange(event.target.value)}
          aria-label={label}
          className={`min-h-12 w-full rounded-lg border bg-white pl-3 pr-12 text-sm outline-none focus:border-2 focus:border-[#0386FF] ${error ? "border-[#DC2626]" : "border-[#D1D5DB]"}`}
        />
        <button type="button" onClick={() => setShown((value) => !value)} aria-label={shown ? `Hide ${label}` : `Show ${label}`} className="absolute right-1 top-1/2 grid h-10 w-10 -translate-y-1/2 place-items-center rounded-full text-[#6B7280] hover:bg-[#F3F4F6]">
          {shown ? <EyeOff size={20} /> : <Eye size={20} />}
        </button>
      </span>
      {error ? <span className="mt-1.5 block text-xs text-[#DC2626]">{error}</span> : null}
    </label>
  );
}
