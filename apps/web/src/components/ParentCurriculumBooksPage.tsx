"use client";

import { Cairo } from "next/font/google";
import { useEffect, useState } from "react";
import { BookOpen, Download, ExternalLink, SquarePlay, Users } from "lucide-react";
import { useLocale } from "@/lib/i18n";
import { alpha } from "@/components/ParentUi";
import { BOOKS_TEXT, CURRICULUM_BOOKS, bookOpenUrl, parentLearningText, type CurriculumBook } from "@/lib/parentLearning";

/** Flutter draws the Arabic titles in Cairo (GoogleFonts.cairo, w800). */
const cairo = Cairo({ subsets: ["arabic"], weight: ["800"], display: "swap" });

/**
 * Curriculum Books (CurriculumBooksScreen as Flutter web shows it, C-300…C-310):
 * the same four hard-coded books for every role. "Open" opens the PDF in a new
 * tab and "Download" the PowerPoint, as on Flutter web; if the browser blocks
 * the new tab the parent is told, as Flutter's snackbar does.
 */
export default function ParentCurriculumBooksPage() {
  const fr = useLocale() === "fr";
  const words = parentLearningText(fr);
  const [snack, setSnack] = useState<string | null>(null);

  useEffect(() => {
    if (!snack) return;
    const timer = window.setTimeout(() => setSnack(null), 4000);
    return () => window.clearTimeout(timer);
  }, [snack]);

  const launch = (url: string) => {
    const opened = window.open(url, "_blank");
    if (!opened) {
      setSnack(BOOKS_TEXT.openFailed);
      return;
    }
    opened.opener = null;
  };

  return (
    <div className="min-h-full bg-[#F8FAFC] p-6 text-[#0F172A]">
      <div className="mx-auto max-w-[1280px]">
        <section className="rounded-[28px] border border-[#D9F0FF] bg-gradient-to-br from-[#ECFEFF] to-[#EFF6FF] p-7">
          <span className="inline-flex rounded-full bg-white px-3 py-2 text-xs font-bold tracking-[0.2px] text-[#0369A1]">{BOOKS_TEXT.badge}</span>
          <h1 className="mt-[18px] text-[32px] font-black leading-[1.05] text-[#0F172A]">{BOOKS_TEXT.title}</h1>
          <p className="mt-2.5 text-[15px] font-medium leading-[1.6] text-[#475569]">{BOOKS_TEXT.intro}</p>
          <div className="mt-[18px] flex flex-wrap gap-2.5">
            {BOOKS_TEXT.chips.map((label, index) => {
              const Icon = [Users, SquarePlay, BookOpen][index];
              return (
                <span key={label} className="inline-flex items-center gap-2 rounded-full border border-[#E2E8F0] bg-white/85 px-3 py-2 text-xs font-bold text-[#334155]">
                  <Icon size={16} className="text-[#475569]" />
                  {label}
                </span>
              );
            })}
          </div>
        </section>

        <div className="mt-6 grid grid-cols-1 gap-5 min-[1100px]:grid-cols-2">
          {CURRICULUM_BOOKS.map((book) => (
            <BookCard
              key={book.downloadUrl}
              book={book}
              downloadLabel={words.download}
              onOpen={() => launch(bookOpenUrl(book))}
              onDownload={() => launch(book.downloadUrl)}
            />
          ))}
        </div>
      </div>

      {snack ? (
        <div role="alert" className="fixed bottom-6 left-1/2 z-[120] w-[min(560px,calc(100%-32px))] -translate-x-1/2 rounded-[4px] bg-[#323232] px-4 py-3.5 text-sm font-semibold text-white shadow-xl">
          {snack}
        </div>
      ) : null}
    </div>
  );
}

function BookCard({ book, downloadLabel, onOpen, onDownload }: { book: CurriculumBook; downloadLabel: string; onOpen: () => void; onDownload: () => void }) {
  return (
    <article className="flex aspect-[1.1] flex-col rounded-3xl border border-[#E2E8F0] bg-white p-[22px] shadow-[0_10px_24px_rgba(0,0,0,0.04)] min-[700px]:aspect-[1.85] min-[1100px]:aspect-[1.55]">
      <div className="flex items-start gap-3.5">
        <span className="grid h-[52px] w-[52px] shrink-0 place-items-center rounded-2xl" style={{ backgroundColor: alpha(book.accent, 0.12), color: book.accent }}>
          <SquarePlay size={28} />
        </span>
        <div className="min-w-0 flex-1">
          <h2 lang="ar" className={`${cairo.className} text-[22px] font-extrabold leading-[1.25] text-[#0F172A]`}>
            {book.title}
          </h2>
          <p className="mt-1.5 text-[13px] font-bold" style={{ color: book.accent }}>
            {book.subtitle}
          </p>
        </div>
      </div>
      <p className="mt-[18px] text-sm leading-[1.6] text-[#475569]">{book.description}</p>
      <div className="flex-1" />
      <div className="mt-[18px] flex flex-wrap gap-2.5">
        <button
          type="button"
          onClick={onOpen}
          className="inline-flex items-center gap-2 rounded-[14px] border px-4 py-3 text-[13px] font-bold text-white"
          style={{ backgroundColor: book.accent, borderColor: alpha(book.accent, 0.35) }}
        >
          <ExternalLink size={18} />
          {BOOKS_TEXT.open}
        </button>
        <button
          type="button"
          onClick={onDownload}
          className="inline-flex items-center gap-2 rounded-[14px] border bg-transparent px-4 py-3 text-[13px] font-bold"
          style={{ color: book.accent, borderColor: alpha(book.accent, 0.35) }}
        >
          <Download size={18} />
          {downloadLabel}
        </button>
      </div>
    </article>
  );
}
