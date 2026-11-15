/**
 * Parent Curriculum Books (CurriculumBooksScreen,
 * lib/features/curriculum/screens/curriculum_books_screen.dart) and the words
 * the parent Recordings / Books pages translate. Flutter translates only
 * "Try Again" on Recordings and "Download" on Books; every other text on those
 * two screens is English in both languages, and stays so here.
 */

export type CurriculumBook = {
  title: string;
  subtitle: string;
  description: string;
  pdfUrl: string;
  downloadUrl: string;
  accent: string;
};

const BASE_URL = "https://storage.googleapis.com/alluwal-academy.firebasestorage.app/curriculum";

/** The four books, in Flutter's order, with Flutter's text, files and colours. */
export const CURRICULUM_BOOKS: readonly CurriculumBook[] = [
  {
    title: "الحُرُوفُ الهِجَائِيَّةُ وَالمَفْتُوحَةُ",
    subtitle: "Alphabet and open-vowel practice",
    description: "Foundational Arabic letters material used for early reading and pronunciation lessons.",
    pdfUrl: `${BASE_URL}/alphabet_and_fatha.pdf`,
    downloadUrl: `${BASE_URL}/alphabet_and_fatha.pptx`,
    accent: "#0F766E",
  },
  {
    title: "الحُرُوفُ المَضْمُومَةُ",
    subtitle: "Damma lessons",
    description: "Curriculum slides for Arabic letters with damma reading and repetition practice.",
    pdfUrl: `${BASE_URL}/damma_lessons.pdf`,
    downloadUrl: `${BASE_URL}/damma_lessons.pptx`,
    accent: "#2563EB",
  },
  {
    title: "الحروف المفتوحة",
    subtitle: "Open-vowel reading practice",
    description: "Practice deck for reading and recognizing Arabic letters with fatha.",
    pdfUrl: `${BASE_URL}/open_letters_practice.pdf`,
    downloadUrl: `${BASE_URL}/open_letters_practice.pptx`,
    accent: "#D97706",
  },
  {
    title: "الحروف المكسورة",
    subtitle: "Kasra lessons",
    description: "Curriculum slides for kasra reading drills used by teachers and students.",
    pdfUrl: `${BASE_URL}/kasra_lessons.pdf`,
    downloadUrl: `${BASE_URL}/kasra_lessons.pptx`,
    accent: "#7C3AED",
  },
];

/** "Open" on the web: the PDF in a new tab, fitted to the window. */
export const bookOpenUrl = (book: Pick<CurriculumBook, "pdfUrl">) => `${book.pdfUrl}#view=Fit`;

export const BOOKS_TEXT = {
  badge: "Shared Learning Materials",
  title: "Curriculum Books",
  intro:
    "These are the Arabic curriculum PowerPoints used across classes. Teachers, students, parents, and administrators can open or download them from here.",
  chips: ["All roles", "PowerPoint files", "Arabic curriculum"] as const,
  open: "Open",
  openFailed: "Unable to open this curriculum book right now.",
} as const;

/** The only translated words on the two screens (app_en.arb / app_fr.arb). */
export function parentLearningText(fr: boolean) {
  return {
    tryAgain: fr ? "Réessayer" : "Try Again",
    download: fr ? "Télécharger" : "Download",
  };
}
