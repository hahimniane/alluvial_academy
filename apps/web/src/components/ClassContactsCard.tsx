"use client";

import { onAuthStateChanged } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { Check, Copy, Phone } from "lucide-react";
import { useEffect, useState } from "react";
import { auth, functions } from "@/lib/firebase";
import { parseClassContacts, telHref, type ClassContact, type ClassContacts } from "@/lib/classContacts";
import { useT } from "@/lib/i18n";

type LoadState = "loading" | "ready" | "error";

const RELATIONSHIP_LABELS: Record<ClassContact["relationship"], string> = {
  parent: "Parent",
  student: "Student",
  teacher: "Teacher",
};

/**
 * Tap-to-call phone numbers for the people the signed-in user has classes
 * with. `teacher` lists each student with their parents; `student` lists the
 * student's own teachers. Renders nothing when there is no one to show.
 */
export function ClassContactsCard({ variant }: { variant: "teacher" | "student" }) {
  const t = useT();
  const [state, setState] = useState<LoadState>("loading");
  const [contacts, setContacts] = useState<ClassContacts>({ students: [], children: [], teachers: [] });
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let active = true;
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      setState("loading");
      try {
        const callable = httpsCallable<Record<string, never>, unknown>(functions, "getClassContacts");
        const result = await callable({});
        if (!active) return;
        setContacts(parseClassContacts(result.data));
        setState("ready");
      } catch {
        if (active) setState("error");
      }
    });
    return () => {
      active = false;
      unsubscribe();
    };
  }, [reloadKey]);

  const title = variant === "teacher" ? t("Contacts") : t("Your teachers");
  const helper = variant === "teacher" ? t("Call a parent if a student hasn't joined.") : t("Call your teacher if you can't reach them in the app.");

  if (state === "loading") return null;
  if (state === "ready") {
    const empty = variant === "teacher" ? contacts.students.length === 0 : contacts.teachers.length === 0;
    if (empty) return null;
  }

  return (
    <section className="mt-5 rounded-2xl border border-black/5 bg-white p-4 shadow-[0_6px_18px_rgba(15,23,42,0.05)]" aria-labelledby={`class-contacts-${variant}`}>
      <div className="mb-3 flex items-center gap-3">
        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-emerald-50 text-emerald-600">
          <Phone size={18} />
        </span>
        <div className="min-w-0">
          <h2 id={`class-contacts-${variant}`} className="text-base font-black text-[#0F172A]">{title}</h2>
          <p className="text-xs font-semibold text-[#64748B]">{helper}</p>
        </div>
      </div>

      {state === "error" ? (
        <div className="flex flex-wrap items-center gap-3 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm font-semibold text-amber-800" role="alert">
          <span className="min-w-0 flex-1">{t("Could not load phone numbers.")}</span>
          <button type="button" onClick={() => setReloadKey((k) => k + 1)} className="min-h-9 rounded-lg bg-amber-700 px-3 text-xs font-bold text-white">
            {t("Try again")}
          </button>
        </div>
      ) : variant === "teacher" ? (
        <ul className="grid max-h-96 gap-2 overflow-y-auto sm:grid-cols-2">
          {contacts.students.map((group, index) => (
            <li key={`${group.studentName}-${index}`} className="rounded-xl border border-black/5 bg-[#F8FAFC] px-3 py-2.5">
              <p className="truncate text-sm font-bold text-[#0F172A]">{group.studentName || t("Student")}</p>
              {group.contacts.length === 0 ? (
                <p className="mt-1 text-xs font-semibold text-[#94A3B8]">{t("No phone number on file")}</p>
              ) : (
                <ul className="mt-1 grid gap-1">
                  {group.contacts.map((contact) => (
                    <ContactRow key={contact.tel} contact={contact} />
                  ))}
                </ul>
              )}
            </li>
          ))}
        </ul>
      ) : (
        <ul className="grid gap-2 sm:grid-cols-2">
          {contacts.teachers.map((contact) => (
            <li key={contact.tel} className="rounded-xl border border-black/5 bg-[#F8FAFC] px-3 py-2">
              <ul>
                <ContactRow contact={contact} />
              </ul>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function ContactRow({ contact }: { contact: ClassContact }) {
  const t = useT();
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(contact.phone);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1500);
    } catch {}
  };

  return (
    <li className="flex items-center gap-2">
      <span className="min-w-0 flex-1">
        <span className="block truncate text-xs font-semibold text-[#475569]">
          {contact.name || t(RELATIONSHIP_LABELS[contact.relationship])}
          <span className="text-[#94A3B8]"> · {t(RELATIONSHIP_LABELS[contact.relationship])}</span>
        </span>
        <a href={telHref(contact)} className="block truncate text-sm font-bold text-[#0386FF] hover:underline">
          {contact.phone}
        </a>
      </span>
      <a href={telHref(contact)} aria-label={t("Call {name}", { name: contact.name || contact.phone })} className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-emerald-600 text-white">
        <Phone size={16} />
      </a>
      <button type="button" onClick={() => void copy()} aria-label={copied ? t("Copied") : t("Copy number")} title={copied ? t("Copied") : t("Copy number")} className="grid h-9 w-9 shrink-0 place-items-center rounded-lg border border-[#E2E8F0] bg-white text-[#64748B]">
        {copied ? <Check size={16} /> : <Copy size={16} />}
      </button>
    </li>
  );
}
