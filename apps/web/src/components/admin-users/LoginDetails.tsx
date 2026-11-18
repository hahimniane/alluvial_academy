"use client";

import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import { Mail, MessageCircle, Printer } from "lucide-react";
import { displayNameOf, type UserRow } from "@/lib/adminUsers";
import { failed } from "@/lib/adminUsersActions";
import {
  SCHOOL_LOGO,
  SCHOOL_NAME,
  SIGN_IN_ADDRESS,
  emailResultText,
  guardianContacts,
  loginDetailsProblem,
  loginFactsOf,
  loginMessage,
  whatsAppUrl,
  type LoginFacts,
  type MessageLanguage,
} from "@/lib/loginDetails";
import { readStudentPassword } from "@/lib/studentCredentials";
import { emailLoginDetails } from "@/lib/usersExtrasData";
import { BTN_SECONDARY, DialogShell, useOnce } from "./UserDialogs";
import type { Say } from "./UserPanel";

type PasswordLoad = { state: "loading" } | { state: "ready"; value: string } | { state: "error"; text: string };

/**
 * Send login details (F2): WhatsApp to a guardian (opens on this device with
 * the text filled in), email to a guardian (sent by the server), or a printed
 * login card. The password is read once when the dialog opens.
 */
export function SendLoginDialog({
  row,
  rows,
  byId,
  say,
  onClose,
}: {
  row: UserRow;
  rows: readonly UserRow[];
  byId: Map<string, UserRow>;
  say: Say;
  onClose: () => void;
}) {
  const [pw, setPw] = useState<PasswordLoad>({ state: "loading" });
  const [language, setLanguage] = useState<MessageLanguage>("en");
  const [printing, setPrinting] = useState(false);
  const [emailNote, setEmailNote] = useState<{ text: string; tone: "ok" | "error" } | null>(null);
  const { busy, run } = useOnce();
  const contacts = useMemo(() => guardianContacts(row, rows, byId), [row, rows, byId]);
  const name = displayNameOf(row);

  useEffect(() => {
    let live = true;
    readStudentPassword(row.id)
      .then((value) => live && setPw({ state: "ready", value }))
      .catch((e) => live && setPw({ state: "error", text: failed("The password could not be read", e) }));
    return () => {
      live = false;
    };
  }, [row.id]);

  const password = pw.state === "ready" ? pw.value : "";
  const problem = loginDetailsProblem(row, pw.state === "ready" ? pw.value : null);
  const ready = pw.state === "ready" && !problem;
  const facts = loginFactsOf(row, password);

  const email = (guardianId: string, guardianName: string) =>
    run(async () => {
      setEmailNote(null);
      try {
        const result = await emailLoginDetails(row.id, [guardianId]);
        const note = emailResultText(result);
        setEmailNote(note);
        if (note.tone === "ok") say(note.text);
      } catch (e) {
        setEmailNote({ text: failed(`Could not email ${guardianName}`, e), tone: "error" });
      }
    });

  if (printing) return <LoginCards cards={[facts]} onClose={() => setPrinting(false)} />;

  return (
    <DialogShell label="Send login details" title={`Send ${name}'s login details`} busy={busy} onClose={onClose}>
      {pw.state === "loading" ? <p className="m-0 text-[#64748B]">Reading the password…</p> : null}
      {pw.state === "error" ? (
        <p role="alert" className="m-0 rounded-[10px] bg-[#FEF2F2] px-3 py-2 text-[13px] font-semibold text-[#B91C1C]">
          {pw.text}
        </p>
      ) : null}
      {problem && pw.state === "ready" ? (
        <p role="alert" className="m-0 rounded-[10px] bg-[#FFFBEB] px-3 py-2 text-[13px] font-semibold text-[#92400E]">
          {problem}
        </p>
      ) : null}

      <div className="flex items-center justify-between gap-2">
        <span className="text-[13px] font-semibold text-[#334155]">Message language</span>
        <div className="flex rounded-[10px] bg-[#F1F5F9] p-1" role="group" aria-label="Message language">
          {(
            [
              ["en", "English"],
              ["fr", "Français"],
            ] as const
          ).map(([v, label]) => (
            <button
              key={v}
              type="button"
              aria-pressed={language === v}
              onClick={() => setLanguage(v)}
              className={`min-h-9 rounded-lg px-3 text-[13px] font-semibold ${language === v ? "bg-white text-[#0F172A] shadow-sm" : "text-[#475569]"}`}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      <div className="flex flex-col gap-2">
        {contacts.length === 0 ? (
          <div className="rounded-xl border border-[#E2E8F0] p-3 text-[13px] text-[#475569]">
            No guardian is linked. You can still open WhatsApp and choose the contact there, or print the card.
            <div className="mt-2">
              <WhatsAppLink href={ready ? whatsAppUrl(null, loginMessage(facts, "", language)) : null} label="Open WhatsApp" />
            </div>
          </div>
        ) : (
          contacts.map((c) => (
            <div key={c.id} className="flex flex-col gap-2 rounded-xl border border-[#E2E8F0] p-3">
              <div className="flex flex-wrap items-baseline justify-between gap-x-2">
                <span className="font-semibold">{c.name}</span>
                {!c.isActive ? <span className="text-xs font-semibold text-[#B91C1C]">Archived</span> : null}
              </div>
              <div className="flex flex-wrap gap-2">
                <WhatsAppLink href={ready ? whatsAppUrl(c.whatsApp, loginMessage(facts, c.name, language)) : null} label={c.whatsApp ? "WhatsApp" : "WhatsApp (pick the contact)"} />
                <button
                  type="button"
                  disabled={!ready || busy || !c.email || !c.onStudentDoc}
                  onClick={() => email(c.id, c.name)}
                  className="flex min-h-10 items-center gap-1.5 rounded-[10px] border border-[#BFDBFE] bg-[#EFF6FF] px-3 text-[13px] font-semibold text-[#1D4ED8] disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <Mail size={15} aria-hidden="true" />
                  {busy ? "Sending…" : "Email"}
                </button>
              </div>
              <span className="text-xs text-[#64748B]">
                {!c.email
                  ? "No email address on their account."
                  : !c.onStudentDoc
                    ? "Linked on their account only. Fix the link in Edit details to email them."
                    : c.email}
                {c.whatsApp ? "" : c.email ? " · No phone number for WhatsApp." : " No phone number for WhatsApp."}
              </span>
            </div>
          ))
        )}
      </div>

      {emailNote ? (
        <p role={emailNote.tone === "error" ? "alert" : "status"} className={`m-0 rounded-[10px] px-3 py-2 text-[13px] font-semibold ${emailNote.tone === "error" ? "bg-[#FEF2F2] text-[#B91C1C]" : "bg-[#ECFDF5] text-[#065F46]"}`}>
          {emailNote.text}
        </p>
      ) : null}

      <p className="m-0 text-xs text-[#64748B]">WhatsApp opens on this device with the message filled in. Nothing is sent until you press send there.</p>

      <div className="flex flex-wrap justify-end gap-2.5">
        <button type="button" disabled={!ready} onClick={() => setPrinting(true)} className={`${BTN_SECONDARY} flex items-center gap-2`}>
          <Printer size={16} aria-hidden="true" />
          Print login card
        </button>
        <button type="button" data-autofocus disabled={busy} onClick={onClose} className="min-h-11 rounded-[10px] bg-[#0369D9] px-4 font-semibold text-white">
          Done
        </button>
      </div>
    </DialogShell>
  );
}

function WhatsAppLink({ href, label }: { href: string | null; label: string }) {
  const cls = "flex min-h-10 items-center gap-1.5 rounded-[10px] border border-[#BBF7D0] bg-[#F0FDF4] px-3 text-[13px] font-semibold text-[#15803D]";
  if (!href) {
    return (
      <span aria-disabled="true" className={`${cls} cursor-not-allowed opacity-50`}>
        <MessageCircle size={15} aria-hidden="true" />
        {label}
      </span>
    );
  }
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className={cls} data-testid="whatsapp-link">
      <MessageCircle size={15} aria-hidden="true" />
      {label}
    </a>
  );
}

const PRINT_CSS = `
@page { margin: 12mm; }
.login-print { position: fixed; inset: 0; z-index: 80; overflow: auto; background: #F8FAFC; }
.login-cards { display: grid; grid-template-columns: repeat(auto-fill, 88mm); gap: 6mm; justify-content: center; padding: 6mm 0; }
.login-card { width: 88mm; min-height: 58mm; box-sizing: border-box; break-inside: avoid; page-break-inside: avoid; }
@media print {
  body > *:not(.login-print) { display: none !important; }
  .login-print { position: static; overflow: visible; background: #fff; }
  .login-print-bar { display: none !important; }
  .login-cards { padding: 0; }
  .login-card { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
}
`;

/**
 * Printable login cards: school logo and name, the student's name, Student
 * ID, login email, password and where to sign in. 88 × 58 mm each, two
 * across, which fits both A4 and Letter; a card never splits across pages.
 */
export function LoginCards({ cards, onClose }: { cards: LoginFacts[]; onClose: () => void }) {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);
  if (!mounted) return null;
  return createPortal(
    <div className="login-print font-sans text-[#0F172A]" role="dialog" aria-label="Login cards">
      <style>{PRINT_CSS}</style>
      <div className="login-print-bar sticky top-0 flex flex-wrap items-center justify-between gap-3 border-b border-[#E2E8F0] bg-white px-4 py-3">
        <span className="font-semibold">
          {cards.length === 1 ? "1 login card" : `${cards.length} login cards`} · cut along the lines
        </span>
        <span className="flex gap-2">
          <button type="button" onClick={onClose} className={BTN_SECONDARY}>
            Close
          </button>
          <button type="button" onClick={() => window.print()} className="flex min-h-11 items-center gap-2 rounded-[10px] bg-[#0369D9] px-4 font-semibold text-white">
            <Printer size={16} aria-hidden="true" />
            Print
          </button>
        </span>
      </div>
      <div className="login-cards">
        {cards.map((c, i) => (
          <div key={`${c.studentCode}-${i}`} className="login-card flex flex-col gap-2 rounded-[10px] border border-dashed border-[#94A3B8] bg-white p-[5mm]" data-testid="login-card">
            <div className="flex items-center gap-2">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={SCHOOL_LOGO} alt="" width={28} height={28} className="h-7 w-7 object-contain" />
              <span className="text-[13px] font-bold text-[#024E96]">{SCHOOL_NAME}</span>
            </div>
            <div className="text-[15px] font-bold leading-tight">{c.studentName}</div>
            <dl className="m-0 grid grid-cols-[auto_1fr] gap-x-3 gap-y-0.5 text-[12px]">
              <dt className="text-[#475569]">Student ID</dt>
              <dd className="m-0 break-all font-mono font-semibold">{c.studentCode}</dd>
              <dt className="text-[#475569]">Password</dt>
              <dd className="m-0 break-all font-mono font-semibold">{c.password}</dd>
              <dt className="text-[#475569]">Login email</dt>
              <dd className="m-0 break-all font-mono text-[11px]">{c.loginEmail}</dd>
            </dl>
            <div className="mt-auto text-[11px] text-[#334155]">
              Sign in at <span className="font-semibold">{SIGN_IN_ADDRESS}</span> or in the Alluwal app with the Student ID and password.
            </div>
          </div>
        ))}
      </div>
    </div>,
    document.body,
  );
}
