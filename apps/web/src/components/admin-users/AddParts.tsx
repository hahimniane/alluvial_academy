"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { X } from "lucide-react";
import type { ParentChoice } from "@/lib/adminUsers";
import { COMMON_COUNTRY_ISOS, COUNTRIES, countryByIso } from "@/lib/phoneNumbers";
import { outcomeLine, outcomeTone, type RowOutcome } from "@/lib/addUsers";
import { reasonText, type DuplicateMatch } from "@/lib/userDuplicates";
import { ParentPicker } from "./ParentPicker";

/** Building blocks shared by Add users and Enroll a family. */

export const INPUT = "min-h-11 w-full rounded-[10px] border bg-white px-3 text-sm text-[#0F172A]";
export const BTN = "min-h-11 rounded-[10px] px-4 font-semibold disabled:cursor-not-allowed disabled:opacity-60";
export const BTN_PRIMARY = `${BTN} bg-[#0369D9] text-white hover:bg-[#024E96]`;
export const BTN_SECONDARY = `${BTN} border border-[#CBD5E1] bg-white text-[#334155] hover:bg-[#F8FAFC]`;

const border = (error?: string) => (error ? "border-[#DC2626]" : "border-[#CBD5E1]");

export function ErrorText({ id, text }: { id?: string; text?: string }) {
  return text ? (
    <span id={id} className="text-xs font-semibold text-[#B91C1C]">
      {text}
    </span>
  ) : null;
}

export function TextField({
  label,
  value,
  onChange,
  error,
  type = "text",
  placeholder,
  inputMode,
  autoComplete = "off",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  error?: string;
  type?: string;
  placeholder?: string;
  inputMode?: "decimal" | "email" | "tel" | "text";
  autoComplete?: string;
}) {
  return (
    <label className="flex min-w-0 flex-col gap-1.5">
      <span className="text-[13px] font-semibold text-[#334155]">{label}</span>
      <input
        type={type}
        value={value}
        placeholder={placeholder}
        inputMode={inputMode}
        autoComplete={autoComplete}
        aria-invalid={!!error}
        onChange={(e) => onChange(e.target.value)}
        className={`${INPUT} ${border(error)}`}
      />
      <ErrorText text={error} />
    </label>
  );
}

const COUNTRY_OPTIONS = (() => {
  const common = COMMON_COUNTRY_ISOS.map((iso) => countryByIso(iso)).filter((c): c is NonNullable<typeof c> => !!c);
  const rest = [...COUNTRIES].sort((a, b) => a.name.localeCompare(b.name));
  return { common, rest };
})();

export function PhoneField({
  iso,
  value,
  onIso,
  onChange,
  error,
  label = "Phone (optional)",
}: {
  iso: string;
  value: string;
  onIso: (iso: string) => void;
  onChange: (v: string) => void;
  error?: string;
  label?: string;
}) {
  return (
    <div className="flex min-w-0 flex-col gap-1.5">
      <span className="text-[13px] font-semibold text-[#334155]">{label}</span>
      <span className="flex gap-1.5">
        <select
          aria-label="Phone country"
          value={iso}
          onChange={(e) => onIso(e.target.value)}
          className={`min-h-11 w-[104px] flex-none rounded-[10px] border bg-white px-2 text-sm ${border(error)}`}
        >
          {COUNTRY_OPTIONS.common.map((c) => (
            <option key={`c-${c.iso}`} value={c.iso}>{`${c.iso} +${c.dial} ${c.name}`}</option>
          ))}
          <option disabled>──────────</option>
          {COUNTRY_OPTIONS.rest.map((c) => (
            <option key={c.iso} value={c.iso}>{`${c.iso} +${c.dial} ${c.name}`}</option>
          ))}
        </select>
        <input
          type="tel"
          aria-label={`${label}, number`}
          aria-invalid={!!error}
          value={value}
          placeholder={iso === "GN" ? "621 12 34 56" : "646 555 0100"}
          onChange={(e) => onChange(e.target.value.replace(/[^\d\s()+.-]/g, ""))}
          className={`${INPUT} min-w-0 flex-1 ${border(error)}`}
        />
      </span>
      <ErrorText text={error} />
    </div>
  );
}

export function Segmented<T extends string>({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: T;
  options: [T, string][];
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-[13px] font-semibold text-[#334155]">{label}</span>
      <div className="flex w-max overflow-hidden rounded-[10px] border border-[#CBD5E1]" role="group" aria-label={label}>
        {options.map(([v, text]) => (
          <button
            key={v}
            type="button"
            aria-pressed={value === v}
            onClick={() => onChange(v)}
            className={`min-h-[42px] px-[18px] font-semibold ${value === v ? "bg-[#0369D9] text-white" : "bg-white text-[#334155]"}`}
          >
            {text}
          </button>
        ))}
      </div>
    </div>
  );
}

/** The parent / guardian field: shows the chosen parent, opens the picker. */
export function ParentField({
  parents,
  selectedId,
  onPick,
  error,
  label = "Parent / guardian",
}: {
  parents: ParentChoice[];
  selectedId: string | null;
  onPick: (id: string | null) => void;
  error?: string;
  label?: string;
}) {
  const [open, setOpen] = useState(false);
  const chosen = selectedId ? parents.find((p) => p.id === selectedId) : undefined;
  return (
    <div className="relative flex min-w-0 flex-1 flex-col gap-1.5 sm:min-w-[260px]">
      <span className="text-[13px] font-semibold text-[#334155]">{label}</span>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        aria-invalid={!!error}
        className={`flex min-h-11 w-full items-center gap-2.5 rounded-[10px] border px-3 text-left ${
          chosen ? "border-[#DDD6FE] bg-[#F5F3FF]" : `${border(error)} bg-white`
        }`}
      >
        {chosen ? (
          <>
            <span aria-hidden="true" className="grid h-7 w-7 flex-none place-items-center rounded-lg bg-[#EDE9FE] font-bold text-[#5B21B6]">
              {(chosen.name || chosen.email || "?").charAt(0).toUpperCase()}
            </span>
            <span className="min-w-0 flex-1 truncate">
              {chosen.name || chosen.id}
              {chosen.email ? <span className="text-[#64748B]"> · {chosen.email}</span> : null}
            </span>
            <span className="flex-none font-semibold text-[#5B21B6]">Change</span>
          </>
        ) : (
          <span className="text-[#64748B]">{parents.length ? "Pick a parent" : "No parents yet: add the parent first"}</span>
        )}
      </button>
      <ErrorText text={error} />
      {open ? (
        <ParentPicker
          parents={parents}
          selectedId={selectedId}
          clearLabel="No parent"
          onPick={(id) => {
            onPick(id);
            setOpen(false);
          }}
          onClear={() => {
            onPick(null);
            setOpen(false);
          }}
          onClose={() => setOpen(false)}
        />
      ) : null}
    </div>
  );
}

/** "They will log in with" box for a student. */
export function LoginPreview({ code, existingCode, note }: { code: string; existingCode: string | null; note: string }) {
  if (existingCode !== null) {
    return (
      <div className="flex flex-col gap-1 rounded-xl border border-[#FDE68A] bg-[#FFFBEB] px-3.5 py-3 text-[#92400E]">
        <span className="font-bold">Already this parent&apos;s child</span>
        <span className="text-[13px]">
          Their account (Student ID <span className="font-mono font-semibold">{existingCode || "—"}</span>) is used; nothing new is created.
        </span>
      </div>
    );
  }
  return (
    <div className="flex flex-wrap gap-x-6 gap-y-2 rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-3.5 py-3">
      <span className="basis-full font-bold text-[#1E3A8A]">They will log in with</span>
      <span className="min-w-0 break-all">
        <span className="text-[#475569]">Student ID </span>
        <span className="font-mono font-semibold">{code || "first.last"}</span>
      </span>
      <span className="min-w-0 break-all">
        <span className="text-[#475569]">Login email </span>
        <span className="font-mono font-semibold">{code ? `${code}@alluwaleducationhub.org` : "first.last@alluwaleducationhub.org"}</span>
      </span>
      <span className="basis-full text-[13px] text-[#475569]">{note}</span>
    </div>
  );
}

export type DuplicateGroup = { key: string; who: string; matches: DuplicateMatch[] };

/** F3: the people already here who look like the ones being added. */
export function DuplicateWarning({ groups, onOpen }: { groups: DuplicateGroup[]; onOpen: (id: string) => void }) {
  return (
    <div role="alert" className="flex flex-col gap-3 rounded-[14px] border border-[#FDE68A] bg-[#FFFBEB] p-4">
      <div>
        <div className="font-bold text-[#92400E]">{groups.length === 1 && groups[0].matches.length === 1 ? "This person may already be here" : "Some of these people may already be here"}</div>
        <div className="text-[13px] text-[#92400E]">Open them to check, or create anyway.</div>
      </div>
      {groups.map((g) => (
        <div key={g.key} className="flex flex-col gap-1.5">
          <div className="text-[13px] font-semibold text-[#334155]">{g.who}</div>
          {g.matches.map((m) => (
            <div key={m.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-[10px] border border-[#FEF3C7] bg-white px-3 py-2">
              <span className="min-w-0 flex-1">
                <span className="font-semibold">{m.label}</span>
                <span className="text-[#64748B]">
                  {" "}
                  · {m.typeLabel}
                  {!m.isActive ? " · Archived" : ""}
                </span>
                <span className="block truncate text-xs text-[#64748B]">
                  {reasonText(m.reasons)}
                  {m.detail ? ` · ${m.detail}` : ""}
                </span>
              </span>
              <button type="button" onClick={() => onOpen(m.id)} className="min-h-9 rounded-lg px-3 font-semibold text-[#0369D9] hover:bg-[#EFF6FF]">
                Open
              </button>
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

const TONE_STYLE = {
  ok: "border-[#BBF7D0] bg-[#F0FDF4] text-[#166534]",
  warn: "border-[#FDE68A] bg-[#FFFBEB] text-[#92400E]",
  error: "border-[#FECACA] bg-[#FEF2F2] text-[#B91C1C]",
} as const;

export function OutcomeList({ outcomes }: { outcomes: RowOutcome[] }) {
  return (
    <ul className="m-0 flex list-none flex-col gap-2 p-0" aria-label="Results">
      {outcomes.map((o, i) => (
        <li key={i} className={`rounded-[10px] border px-3 py-2.5 text-[13px] font-semibold ${TONE_STYLE[outcomeTone(o)]}`}>
          {outcomeLine(o)}
        </li>
      ))}
    </ul>
  );
}

/** Large modal: full screen on a narrow window. Never closes on an outside click (what was typed would be lost). */
export function BigModal({
  label,
  title,
  subtitle,
  hidden,
  busy,
  onClose,
  footer,
  children,
}: {
  label: string;
  title: string;
  subtitle?: ReactNode;
  hidden?: boolean;
  busy: boolean;
  onClose: () => void;
  footer: ReactNode;
  children: ReactNode;
}) {
  const boxRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (hidden) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !busy) onClose();
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [busy, onClose, hidden]);
  useEffect(() => {
    if (!hidden) boxRef.current?.querySelector<HTMLElement>("input")?.focus();
  }, [hidden]);
  return (
    <div className={`fixed inset-0 z-[45] items-center justify-center bg-[rgba(15,23,42,0.45)] md:p-6 ${hidden ? "hidden" : "flex"}`}>
      <div
        ref={boxRef}
        role="dialog"
        aria-modal="true"
        aria-label={label}
        className="flex h-full w-full flex-col overflow-hidden bg-white shadow-[0_24px_60px_rgba(15,23,42,0.3)] md:h-auto md:max-h-[calc(100vh-48px)] md:max-w-[960px] md:rounded-[18px]"
      >
        <div className="flex items-start justify-between gap-4 border-b border-[#E2E8F0] px-4 py-4 md:px-7 md:py-[22px]">
          <div className="flex min-w-0 flex-col gap-1">
            <h2 className="m-0 text-xl font-bold">{title}</h2>
            {subtitle ? <p className="m-0 text-[#64748B]">{subtitle}</p> : null}
          </div>
          <button
            type="button"
            aria-label="Close"
            disabled={busy}
            onClick={onClose}
            className="grid h-10 w-10 flex-none place-items-center rounded-[10px] bg-[#F1F5F9] text-[#334155] disabled:opacity-50"
          >
            <X size={18} aria-hidden="true" />
          </button>
        </div>
        <div className="flex flex-1 flex-col gap-3.5 overflow-y-auto bg-[#F8FAFC] px-4 py-5 md:px-7">{children}</div>
        <div className="flex flex-wrap items-center justify-end gap-2.5 border-t border-[#E2E8F0] px-4 py-4 md:px-7">{footer}</div>
      </div>
    </div>
  );
}

/** "Discard what you typed?" in the footer instead of losing it on one click. */
export function useDiscardGuard(dirty: boolean, close: () => void) {
  const [asking, setAsking] = useState(false);
  const request = () => {
    if (dirty) setAsking(true);
    else close();
  };
  const bar = asking ? (
    <div className="mr-auto flex flex-wrap items-center gap-2.5" role="alert">
      <span className="font-semibold text-[#334155]">Discard what you typed?</span>
      <button type="button" onClick={() => setAsking(false)} className={BTN_SECONDARY}>
        Keep editing
      </button>
      <button type="button" onClick={close} className={`${BTN} bg-[#B91C1C] text-white`}>
        Discard
      </button>
    </div>
  ) : null;
  return { request, asking, bar };
}
