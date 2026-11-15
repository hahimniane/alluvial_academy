"use client";

import { doc, serverTimestamp, updateDoc } from "firebase/firestore";
import { useEffect, useState, type ReactNode } from "react";
import { CheckCircle2, Loader2, Mail, Phone, UserRound } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { useParentSession, useUpdateParentSession } from "@/components/ParentArea";
import { ParentErrorCard, ParentSpinner } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import { parentFormsText } from "@/lib/parentFormsText";
import { parentDisplayName, parentGreeting } from "@/lib/parentWeb";
import { getCurrentUserRecord } from "@/lib/userRoles";

type Fields = { first: string; last: string; email: string; phone: string };

/**
 * Profile (ParentProfileScreen, A-086…A-089): the parent's name, e-mail
 * (read-only) and phone. Saving updates users/{uid} with the same fields the
 * app writes. The top-bar name follows the saved name straight away.
 */
export default function ParentProfilePage() {
  const session = useParentSession();
  const updateSession = useUpdateParentSession();
  const fr = useLocale() === "fr";
  const text = parentFormsText(fr);
  const [state, setState] = useState<"loading" | "error" | "ready">("loading");
  const [saved, setSaved] = useState<Fields>({ first: "", last: "", email: "", phone: "" });
  const [fields, setFields] = useState<Fields>(saved);
  const [errors, setErrors] = useState<{ first?: string; last?: string }>({});
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ ok: boolean; text: string } | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const user = auth.currentUser;
    if (!user) return;
    let active = true;
    setState("loading");
    getCurrentUserRecord(user)
      .then((record) => {
        if (!active) return;
        const data = (record ?? {}) as Record<string, unknown>;
        const next = {
          first: String(data.first_name ?? ""),
          last: String(data.last_name ?? ""),
          phone: String(data.phone_number ?? ""),
          email: String(data["e-mail"] ?? data.email ?? user.email ?? ""),
        };
        setSaved(next);
        setFields(next);
        setState("ready");
      })
      .catch(() => active && setState("error"));
    return () => {
      active = false;
    };
  }, [session.uid, attempt]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 3500);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const save = async () => {
    const nextErrors = {
      first: fields.first.trim() ? undefined : "First name is required",
      last: fields.last.trim() ? undefined : "Last name is required",
    };
    setErrors(nextErrors);
    if (nextErrors.first || nextErrors.last || saving) return;
    setSaving(true);
    try {
      const patch = { first_name: fields.first.trim(), last_name: fields.last.trim(), phone_number: fields.phone.trim() };
      await updateDoc(doc(db, "users", session.uid), { ...patch, updated_at: serverTimestamp() });
      const next = { ...fields, first: patch.first_name, last: patch.last_name, phone: patch.phone_number };
      setSaved(next);
      setFields(next);
      updateSession({ displayName: parentDisplayName(patch), greeting: parentGreeting(patch) });
      setToast({ ok: true, text: text.profileSaved });
    } catch {
      setToast({ ok: false, text: text.profileSaveFailed });
    } finally {
      setSaving(false);
    }
  };

  const name = `${saved.first} ${saved.last}`.trim() || "Parent";

  return (
    <div className="min-h-full bg-[#F8FAFC]">
      <div className="mx-auto w-full max-w-[860px] p-6 max-[600px]:p-4">
        <h1 className="mb-6 text-lg font-bold text-[#111827]">{text.editProfile}</h1>
        {state === "loading" ? <ParentSpinner padding={48} label="Loading" /> : null}
        {state === "error" ? <ParentErrorCard message={text.profileLoadFailed} onRetry={() => setAttempt((n) => n + 1)} retryLabel={text.tryAgain} /> : null}
        {state === "ready" ? (
          <form
            noValidate
            onSubmit={(event) => {
              event.preventDefault();
              void save();
            }}
          >
            <section className="flex items-center gap-4 rounded-2xl border border-[#E5E7EB] bg-white p-6">
              <span className="grid h-16 w-16 shrink-0 place-items-center rounded-full bg-[#EFF6FF] text-[#1D4ED8]">
                <UserRound size={32} />
              </span>
              <div className="min-w-0">
                <p className="truncate text-xl font-bold text-[#111827]">{name}</p>
                <p className="mt-1 truncate text-sm text-[#6B7280]">{saved.email}</p>
              </div>
            </section>

            <h2 className="mb-4 mt-6 text-base font-semibold text-[#111827]">{text.personalInformation}</h2>
            <section className="rounded-2xl border border-[#E5E7EB] bg-white p-6 max-[600px]:p-4">
              <div className="grid grid-cols-2 gap-4 max-[520px]:grid-cols-1">
                <Field label={text.firstName} icon={<UserRound size={20} />} error={errors.first}>
                  <input value={fields.first} onChange={(event) => setFields({ ...fields, first: event.target.value })} placeholder={`Enter ${text.firstName}`} aria-label={text.firstName} className={inputClass(Boolean(errors.first))} />
                </Field>
                <Field label={text.lastName} icon={<UserRound size={20} />} error={errors.last}>
                  <input value={fields.last} onChange={(event) => setFields({ ...fields, last: event.target.value })} placeholder={`Enter ${text.lastName}`} aria-label={text.lastName} className={inputClass(Boolean(errors.last))} />
                </Field>
              </div>
              <div className="mt-5">
                <Field label={text.email} icon={<Mail size={20} />}>
                  <input value={fields.email} disabled placeholder="Email cannot be changed" aria-label={text.email} className={`${inputClass(false)} cursor-not-allowed bg-[#F9FAFB] text-[#6B7280]`} />
                </Field>
              </div>
              <div className="mt-5">
                <Field label={text.phone} icon={<Phone size={20} />}>
                  <input value={fields.phone} type="tel" inputMode="tel" onChange={(event) => setFields({ ...fields, phone: event.target.value })} placeholder={`Enter ${text.phone}`} aria-label={text.phone} className={inputClass(false)} />
                </Field>
              </div>
            </section>

            <button type="submit" disabled={saving} className="mt-8 inline-flex min-h-[52px] w-full items-center justify-center rounded-xl bg-[#0386FF] text-base font-semibold text-white disabled:opacity-70">
              {saving ? <Loader2 size={20} className="animate-spin" aria-label={text.saveChanges} /> : text.saveChanges}
            </button>
          </form>
        ) : null}
      </div>
      {toast ? (
        <div role="status" className={`fixed bottom-6 left-1/2 z-50 flex max-w-[92vw] -translate-x-1/2 items-center gap-2 rounded-lg px-4 py-3 text-sm font-medium text-white shadow-lg ${toast.ok ? "bg-[#10B981]" : "bg-[#EF4444]"}`}>
          {toast.ok ? <CheckCircle2 size={18} /> : null}
          {toast.text}
        </div>
      ) : null}
    </div>
  );
}

function Field({ label, icon, error, children }: { label: string; icon: ReactNode; error?: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="mb-2 block text-sm font-medium text-[#374151]">{label}</span>
      <span className="relative block">
        <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]">{icon}</span>
        {children}
      </span>
      {error ? <span className="mt-1.5 block text-xs text-[#DC2626]">{error}</span> : null}
    </label>
  );
}

function inputClass(invalid: boolean) {
  return `min-h-12 w-full rounded-lg border bg-white pl-11 pr-3 text-sm text-[#111827] outline-none placeholder:text-[#9CA3AF] focus:border-2 focus:border-[#0386FF] ${invalid ? "border-[#DC2626]" : "border-[#E5E7EB]"}`;
}
