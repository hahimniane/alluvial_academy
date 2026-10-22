"use client";

import Link from "next/link";
import { doc, onSnapshot } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useEffect, useState } from "react";
import { useFinance } from "@/components/finance/FinanceShell";
import { db, functions } from "@/lib/firebase";
import { financeHref } from "@/lib/finance/links";
import { DEFAULT_SETTINGS, type FinanceSettings } from "@/lib/finance/model";
import { NUMERIC_SETTINGS, ordinal, parseNumericSetting, type NumericSettingKey } from "@/lib/finance/settings";
import { errorMessage } from "@/lib/finance/summaryClient";

type SwitchKey = "auto_billing_enabled" | "parent_messages_enabled";

function mergeSettings(data: Record<string, unknown> | undefined): FinanceSettings {
  const d = data ?? {};
  const bool = (v: unknown, fallback: boolean) => (typeof v === "boolean" ? v : fallback);
  const int = (v: unknown, fallback: number) => (typeof v === "number" && Number.isInteger(v) ? v : fallback);
  const connected = (v: unknown) => Boolean(v && typeof v === "object" && (v as { connected?: unknown }).connected === true);
  return {
    auto_billing_enabled: bool(d.auto_billing_enabled, DEFAULT_SETTINGS.auto_billing_enabled),
    parent_messages_enabled: bool(d.parent_messages_enabled, DEFAULT_SETTINGS.parent_messages_enabled),
    issue_day: int(d.issue_day, DEFAULT_SETTINGS.issue_day),
    due_day: int(d.due_day, DEFAULT_SETTINGS.due_day),
    first_invoice_due_days: int(d.first_invoice_due_days, DEFAULT_SETTINGS.first_invoice_due_days),
    reminder_days_before: int(d.reminder_days_before, DEFAULT_SETTINGS.reminder_days_before),
    plaid: { connected: connected(d.plaid) },
    whatsapp: { connected: connected(d.whatsapp) },
  };
}

function Switch({
  id, label, on, busy, onToggle, children,
}: { id: string; label: string; on: boolean; busy: boolean; onToggle: () => void; children: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3 rounded-xl border border-slate-200 bg-white p-4">
      <button
        type="button"
        role="switch"
        id={id}
        aria-checked={on}
        aria-labelledby={`${id}-label`}
        aria-describedby={`${id}-help`}
        disabled={busy}
        onClick={onToggle}
        className={`relative mt-0.5 h-11 w-[72px] shrink-0 rounded-full border-0 p-0 transition-colors disabled:opacity-60 ${on ? "bg-[#0386FF]" : "bg-slate-300"}`}
      >
        <span aria-hidden="true" className={`absolute top-1.5 h-8 w-8 rounded-full bg-white shadow transition-all ${on ? "left-[34px]" : "left-1.5"}`} />
        <span className="sr-only">{on ? "On" : "Off"}</span>
      </button>
      <div className="min-w-0 flex-1">
        <div id={`${id}-label`} className="font-bold">
          {label} <span className="font-semibold text-slate-600">· {on ? "On" : "Off"}</span>
        </div>
        <div id={`${id}-help`} className="mt-1 text-[13px] text-slate-700">{children}</div>
      </div>
    </div>
  );
}

export function FinanceSettingsPage() {
  const { month } = useFinance();
  const [settings, setSettings] = useState<FinanceSettings | null>(null);
  const [loadError, setLoadError] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState("");
  const [confirming, setConfirming] = useState<SwitchKey | null>(null);
  const [drafts, setDrafts] = useState<Partial<Record<NumericSettingKey, string>>>({});
  const [fieldErrors, setFieldErrors] = useState<Partial<Record<NumericSettingKey, string>>>({});

  useEffect(
    () =>
      onSnapshot(
        doc(db, "finance_settings", "main"),
        (snap) => setSettings(mergeSettings(snap.exists() ? snap.data() : undefined)),
        (err) => setLoadError(errorMessage(err)),
      ),
    [],
  );

  const save = async (patch: Record<string, boolean | number>, message: string) => {
    setBusy(true);
    setError("");
    setSaved("");
    try {
      await httpsCallable(functions, "updateFinanceSettings")({ patch });
      setSaved(message);
      return true;
    } catch (err) {
      setError(errorMessage(err));
      return false;
    } finally {
      setBusy(false);
    }
  };

  if (loadError) {
    return <p role="alert" className="m-0 rounded-xl border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-900">{loadError}</p>;
  }
  if (!settings) return <p className="m-0 text-sm text-slate-600">Loading…</p>;

  const toggle = async (key: SwitchKey) => {
    if (!settings[key]) {
      setConfirming(key);
      return;
    }
    await save({ [key]: false }, "Saved.");
  };
  const confirmOn = async () => {
    if (!confirming) return;
    const key = confirming;
    setConfirming(null);
    await save({ [key]: true }, "Saved.");
  };

  const changed = NUMERIC_SETTINGS.filter((s) => drafts[s.key] !== undefined && drafts[s.key]!.trim() !== String(settings[s.key]));

  const saveNumbers = async () => {
    const patch: Record<string, number> = {};
    const errors: Partial<Record<NumericSettingKey, string>> = {};
    for (const s of changed) {
      const parsed = parseNumericSetting(s.key, drafts[s.key] ?? "");
      if (parsed.ok) patch[s.key] = parsed.value;
      else errors[s.key] = parsed.error;
    }
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0 || Object.keys(patch).length === 0) return;
    if (await save(patch, "Saved.")) setDrafts({});
  };

  const confirmText: Record<SwitchKey, { title: string; body: string }> = {
    auto_billing_enabled: {
      title: "Turn on automatic billing?",
      body: `One invoice per family is created each month, issued on the ${ordinal(settings.issue_day)} and due on the ${ordinal(settings.due_day)}.`,
    },
    parent_messages_enabled: {
      title: "Turn on messages to parents?",
      body: `Parents get a reminder ${settings.reminder_days_before} days before an invoice is due and on the due date.`,
    },
  };

  return (
    <div className="flex flex-col gap-4">
      <h2 className="m-0 text-2xl font-extrabold">Settings</h2>

      <section aria-labelledby="fin-switches" className="flex flex-col gap-3">
        <h3 id="fin-switches" className="m-0 text-base font-bold">Switches</h3>
        <Switch id="fin-auto-billing" label="Automatic monthly billing" on={settings.auto_billing_enabled} busy={busy} onToggle={() => toggle("auto_billing_enabled")}>
          On: one invoice per family is created each month, issued on the {ordinal(settings.issue_day)} and due on the {ordinal(settings.due_day)}, with discounts and open credit applied.
          Off: today&apos;s billing keeps running as it is.
        </Switch>
        <Switch id="fin-parent-messages" label="Messages to parents" on={settings.parent_messages_enabled} busy={busy} onToggle={() => toggle("parent_messages_enabled")}>
          On: parents get a reminder {settings.reminder_days_before} days before an invoice is due and on the due date, and a message when an invoice is edited.
          Off: nothing new is sent to parents.
        </Switch>
        {confirming ? (
          <div role="alertdialog" aria-labelledby="fin-confirm-title" aria-describedby="fin-confirm-body" className="rounded-xl border border-amber-500 bg-amber-50 p-4">
            <div id="fin-confirm-title" className="font-bold text-amber-950">{confirmText[confirming].title}</div>
            <p id="fin-confirm-body" className="m-0 mt-1 text-sm text-amber-950">{confirmText[confirming].body}</p>
            <div className="mt-3 flex flex-wrap gap-2">
              <button type="button" onClick={confirmOn} disabled={busy} className="h-11 rounded-lg bg-[#0386FF] px-4 font-bold text-white disabled:opacity-60">
                Turn on
              </button>
              <button type="button" onClick={() => setConfirming(null)} className="h-11 rounded-lg border border-slate-300 bg-white px-4 font-semibold">
                Cancel
              </button>
            </div>
          </div>
        ) : null}
      </section>

      <section aria-labelledby="fin-numbers" className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4">
        <h3 id="fin-numbers" className="m-0 text-base font-bold">Billing days</h3>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          {NUMERIC_SETTINGS.map((s) => {
            const value = drafts[s.key] ?? String(settings[s.key]);
            const err = fieldErrors[s.key];
            return (
              <label key={s.key} className="flex flex-col gap-1 text-xs font-semibold text-slate-700">
                {s.label}
                <input
                  type="text"
                  inputMode="numeric"
                  value={value}
                  onChange={(e) => setDrafts((d) => ({ ...d, [s.key]: e.target.value }))}
                  aria-invalid={Boolean(err)}
                  aria-describedby={`fin-${s.key}-hint`}
                  className={`h-11 rounded-lg border px-2.5 text-sm font-normal ${err ? "border-red-500" : "border-slate-300"}`}
                />
                <span id={`fin-${s.key}-hint`} className={`font-normal ${err ? "text-red-700" : "text-slate-600"}`}>{err ?? s.hint}</span>
              </label>
            );
          })}
        </div>
        <div>
          <button
            type="button"
            onClick={saveNumbers}
            disabled={busy || changed.length === 0}
            className="h-11 rounded-lg bg-[#0386FF] px-4 font-bold text-white disabled:cursor-not-allowed disabled:bg-slate-300 disabled:text-slate-600"
          >
            Save
          </button>
        </div>
      </section>

      <section aria-labelledby="fin-connections" className="flex flex-col gap-2 rounded-xl border border-slate-200 bg-white p-4">
        <h3 id="fin-connections" className="m-0 text-base font-bold">Connections</h3>
        <ul className="m-0 flex list-none flex-col gap-2 p-0">
          {[
            { label: "Bank (Plaid)", on: settings.plaid.connected, off: "Bank deposits are not read until the bank is connected." },
            { label: "WhatsApp", on: settings.whatsapp.connected, off: "Payment proofs are not read until WhatsApp is connected." },
          ].map((c) => (
            <li key={c.label} className="flex flex-wrap items-center gap-2.5 rounded-[10px] bg-slate-50 px-3 py-2.5">
              <span className="font-semibold">{c.label}</span>
              <span className={`rounded-full px-2.5 py-0.5 text-xs font-bold ${c.on ? "bg-green-100 text-green-900" : "bg-slate-200 text-slate-800"}`}>
                {c.on ? "Connected" : "Not connected"}
              </span>
              {!c.on ? <span className="text-[13px] text-slate-600">{c.off}</span> : null}
            </li>
          ))}
        </ul>
        <Link href={financeHref("/admin/finance/bank/", month)} className="inline-flex min-h-11 items-center font-semibold text-[#0369C9]">
          Open Bank deposits
        </Link>
      </section>

      <div role="status" aria-live="polite">
        {saved ? <p className="m-0 text-sm font-semibold text-green-800">{saved}</p> : null}
        {error ? <p role="alert" className="m-0 rounded-[10px] border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-900">{error}</p> : null}
      </div>
    </div>
  );
}
