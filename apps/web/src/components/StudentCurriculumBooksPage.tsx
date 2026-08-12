"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { useEffect, useState } from "react";
import { BookOpen, Download, ExternalLink, Menu, Presentation, Shuffle, Users, X } from "lucide-react";
import { auth } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell, openStudentMobileMenu, StudentAvatar } from "@/components/StudentDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;

type StudentSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type CurriculumBook = {
  title: string;
  subtitle: string;
  description: string;
  pdfUrl: string;
  downloadUrl: string;
  accent: string;
  accentSoft: string;
};

const baseUrl = "https://storage.googleapis.com/alluwal-academy.firebasestorage.app/curriculum";

const books: CurriculumBook[] = [
  {
    title: "الحُرُوفُ الهِجَائِيَّةُ وَالمَفْتُوحَةُ",
    subtitle: "Alphabet and open-vowel practice",
    description: "Foundational Arabic letters material used for early reading and pronunciation lessons.",
    pdfUrl: `${baseUrl}/alphabet_and_fatha.pdf`,
    downloadUrl: `${baseUrl}/alphabet_and_fatha.pptx`,
    accent: "#0F766E",
    accentSoft: "#DBF5F0",
  },
  {
    title: "الحُرُوفُ المَضْمُومَةُ",
    subtitle: "Damma lessons",
    description: "Curriculum slides for Arabic letters with damma reading and repetition practice.",
    pdfUrl: `${baseUrl}/damma_lessons.pdf`,
    downloadUrl: `${baseUrl}/damma_lessons.pptx`,
    accent: "#2563EB",
    accentSoft: "#DBEAFE",
  },
  {
    title: "الحروف المفتوحة",
    subtitle: "Open-vowel reading practice",
    description: "Practice deck for reading and recognizing Arabic letters with fatha.",
    pdfUrl: `${baseUrl}/open_letters_practice.pdf`,
    downloadUrl: `${baseUrl}/open_letters_practice.pptx`,
    accent: "#D97706",
    accentSoft: "#FEF3C7",
  },
  {
    title: "الحروف المكسورة",
    subtitle: "Kasra lessons",
    description: "Curriculum slides for kasra reading drills used by teachers and students.",
    pdfUrl: `${baseUrl}/kasra_lessons.pdf`,
    downloadUrl: `${baseUrl}/kasra_lessons.pptx`,
    accent: "#7C3AED",
    accentSoft: "#EDE9FE",
  },
];

export function StudentCurriculumBooksPage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [reading, setReading] = useState<CurriculumBook | null>(null);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      if (!nextUser) {
        setAccess("signedOut");
        return;
      }

      if (!cachedStudentSession()) setAccess("checking");
      try {
        const session = await resolveStudentSession(nextUser);
        const allowed = session.isStudent;
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          return;
        }
        if (!mounted) return;
        setSummary(session.summary);
        setIsAdultStudent(session.isAdultStudent);
        setAccess("allowed");
      } catch {
        if (mounted) setAccess("denied");
      }
    });
  }, []);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  return (
    <StudentShell activeLabel="Curriculum Books" breadcrumb="Learning / Curriculum Books" summary={summary} isAdultStudent={isAdultStudent}>
      <main className="min-h-screen bg-[#F8FAFC] pb-10 text-[#0F172A] lg:min-h-[calc(100vh-56px)]">
        <section className="mx-auto max-w-[1280px] px-6 py-6 lg:px-6">
          <div className="rounded-[28px] border border-[#D9F0FF] bg-gradient-to-br from-[#ECFEFF] to-[#EFF6FF] px-7 py-7">
            <span className="inline-flex min-h-8 items-center rounded-full bg-white px-3 text-xs font-bold text-[#0369A1]">
              Shared Learning Materials
            </span>
            <h1 className="mt-5 max-w-lg text-[32px] font-black leading-[1.05] text-[#0F172A] sm:text-[36px]">Curriculum Books</h1>
            <p className="mt-3 max-w-[1040px] text-[15px] font-medium leading-7 text-[#475569]">
              These are the Arabic curriculum PowerPoints used across classes. Teachers, students, parents, and administrators can open or download them from here.
            </p>
            <div className="mt-5 flex flex-wrap gap-2.5">
              <MetaChip icon={<Users size={16} />} label="All roles" />
              <MetaChip icon={<Presentation size={16} />} label="PowerPoint files" />
              <MetaChip icon={<BookOpen size={16} />} label="Arabic curriculum" />
            </div>
          </div>

          <div className="mt-6 grid gap-5 lg:grid-cols-2">
            {books.map((book) => (
              <BookCard key={book.downloadUrl} book={book} onRead={() => setReading(book)} />
            ))}
          </div>
        </section>
        {reading ? <BookReader book={reading} onClose={() => setReading(null)} /> : null}
      </main>
    </StudentShell>
  );
}


/**
 * Reads the book inside the dashboard.
 *
 * Linking straight to the PDF handed the file to the browser, which downloads
 * it whenever the built-in PDF viewer is turned off — so "Open" looked like a
 * download. The Flutter screen avoids that by embedding Google's viewer
 * (curriculum_books_screen.dart), and this does the same, so the book renders
 * regardless of the reader's browser settings. Download still offers the
 * editable PowerPoint.
 */
function BookReader({ book, onClose }: { book: CurriculumBook; onClose: () => void }) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-[90] flex flex-col bg-black/70 p-3 sm:p-6" role="dialog" aria-modal="true" aria-label={book.subtitle}>
      <div className="mx-auto flex h-full w-full max-w-[1100px] flex-col overflow-hidden rounded-2xl bg-white">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-4 py-3">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl" style={{ backgroundColor: book.accentSoft, color: book.accent }}>
            <Presentation size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-black text-[#0F172A]">{book.subtitle}</p>
            <p className="truncate text-xs font-semibold text-[#64748B]" dir="rtl">{book.title}</p>
          </div>
          <a
            href={`${book.pdfUrl}#view=Fit`}
            target="_blank"
            rel="noreferrer"
            className="hidden min-h-9 items-center gap-1.5 rounded-xl border border-[#E2E8F0] px-3 text-xs font-bold text-[#334155] sm:inline-flex"
          >
            <ExternalLink size={15} />
            New tab
          </a>
          <a
            href={book.downloadUrl}
            className="hidden min-h-9 items-center gap-1.5 rounded-xl border border-[#E2E8F0] px-3 text-xs font-bold text-[#334155] sm:inline-flex"
          >
            <Download size={15} />
            Download
          </a>
          <button type="button" onClick={onClose} aria-label="Close book" className="grid h-9 w-9 shrink-0 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={18} />
          </button>
        </header>
        <iframe
          title={book.subtitle}
          src={`https://docs.google.com/gview?embedded=true&url=${encodeURIComponent(book.pdfUrl)}`}
          className="min-h-0 flex-1 border-0 bg-[#F8FAFC]"
        />
      </div>
    </div>
  );
}

function MobileStudentTopBar({ summary }: { summary: StudentSummary }) {
  return (
    <header className="grid min-h-14 grid-cols-[56px_1fr_96px] items-center bg-white px-4 lg:hidden">
      <button type="button" aria-label="Open student menu" onClick={openStudentMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={24} />
      </button>
      <div className="min-w-0 text-center text-base font-bold text-[#111827]">Alluwal Education Hub</div>
      <div className="flex items-center justify-end gap-3">
        <button type="button" aria-label="Open student account options" onClick={openStudentMobileMenu} className="grid h-10 w-10 place-items-center rounded-xl text-[#111827]"><Shuffle size={20} /></button>
        <StudentAvatar summary={summary} size={36} textClass="text-xs" />
      </div>
    </header>
  );
}

function MetaChip({ icon, label }: { icon: React.ReactNode; label: string }) {
  return (
    <span className="inline-flex min-h-9 items-center gap-2 rounded-full border border-[#E2E8F0] bg-white/85 px-3 text-xs font-bold text-[#334155]">
      <span className="text-[#475569]">{icon}</span>
      {label}
    </span>
  );
}

function BookCard({ book, onRead }: { book: CurriculumBook; onRead: () => void }) {
  return (
    <article className="flex min-h-[318px] flex-col rounded-3xl border border-[#E2E8F0] bg-white p-5 shadow-[0_10px_24px_rgba(15,23,42,0.04)] sm:p-[22px]">
      <div className="flex items-start gap-3.5">
        <span className="grid h-[52px] w-[52px] shrink-0 place-items-center rounded-2xl" style={{ backgroundColor: book.accentSoft, color: book.accent }}>
          <Presentation size={28} />
        </span>
        <div className="min-w-0 flex-1">
          {/* dir="rtl" so the Arabic renders correctly, but the block stays
              left-aligned beside the icon and above its subtitle, matching the
              Flutter screen. text-right pushed it to the far edge. */}
          <h2 className="text-left text-[24px] font-black leading-tight text-[#0F172A]" dir="rtl">
            {book.title}
          </h2>
          <p className="mt-1.5 text-[13px] font-bold" style={{ color: book.accent }}>
            {book.subtitle}
          </p>
        </div>
      </div>
      <p className="mt-5 max-w-[540px] text-sm leading-6 text-[#475569]">{book.description}</p>
      <div className="flex-1" />
      <div className="mt-5 flex flex-wrap gap-2.5">
        <button
          type="button"
          onClick={onRead}
          className="inline-flex min-h-11 items-center gap-2 rounded-[14px] border px-4 text-[13px] font-bold text-white"
          style={{ backgroundColor: book.accent, borderColor: book.accent }}
        >
          <BookOpen size={18} />
          Open
        </button>
        <a
          href={book.downloadUrl}
          target="_blank"
          rel="noreferrer"
          className="inline-flex min-h-11 items-center gap-2 rounded-[14px] border bg-transparent px-4 text-[13px] font-bold"
          style={{ color: book.accent, borderColor: `${book.accent}59` }}
        >
          <Download size={18} />
          Download
        </a>
      </div>
    </article>
  );
}

function summaryForUser(user: User, data: UserRecord | null): StudentSummary {
  const firstName = stringValue(data?.first_name) || stringValue(data?.firstName);
  const lastName = stringValue(data?.last_name) || stringValue(data?.lastName);
  const fullName = [firstName, lastName].filter(Boolean).join(" ").trim();
  const displayName = fullName || user.displayName || user.email || "Student";
  return {
    displayName,
    firstName: firstName || displayName.split(/\s+/)[0] || "Student",
    initials: initialsFor(displayName),
  };
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFor(name: string) {
  return (
    name
      .split(/[^a-zA-Z0-9]+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? "")
      .join("") || "TE"
  );
}
