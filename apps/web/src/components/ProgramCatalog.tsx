"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  BookOpen,
  ChevronDown,
  CircleCheck,
  Code2,
  Clock3,
  Globe2,
  GraduationCap,
  Landmark,
  MinusCircle,
  PlusCircle,
  School,
  Sigma,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import {
  fallbackPricing,
  loadPublicMarketingBundle,
  type PublicSitePlanPricing,
  type PublicSitePricingDoc,
} from "@/lib/publicSiteCms";

type CatalogItem = {
  id: string;
  title: string;
  description: string;
  age: string;
  emoji: string;
  accentColor: string;
  features: string[];
};

type CatalogCategory = {
  id: string;
  title: string;
  description: string;
  color: string;
  emoji: string;
  icon: LucideIcon;
  trackId: "islamic" | "tutoring" | "group";
  enrollSubject: string;
  items: CatalogItem[];
};
type PricingPlans = Record<string, PublicSitePlanPricing>;

const categories: CatalogCategory[] = [
  {
    id: "islamic",
    title: "Islamic studies",
    description: "Quran, Hadith, Arabic Language, Tawhid, Tafsir, and Fiqh",
    color: "#3B82F6",
    emoji: "🕌",
    icon: Landmark,
    trackId: "islamic",
    enrollSubject: "Islamic Program (Arabic, Quran, etc...)",
    items: [
      item("islam_quran", "Quran", "Complete Quran learning program including recitation, memorization, and understanding.", "All ages", "📖", "#3B82F6", ["Proper recitation with Tajweed rules", "Memorization techniques for Hifz", "Understanding the meanings"]),
      item("islam_hadith", "Hadith", "Study the sayings and teachings of Prophet Muhammad (PBUH).", "Ages 10+", "📚", "#10B981", ["Authentic Hadith collections", "Understanding Hadith sciences", "Practical application in daily life"]),
      item("islam_arabic", "Arabic language", "Learn the language of the Quran from basics to fluency.", "Ages 7+", "🇸🇦", "#F59E0B", ["Arabic alphabet and writing", "Grammar (Nahw) and morphology", "Vocabulary building"]),
      item("islam_tawhid", "Tawhid", "Understanding the oneness of Allah and core Islamic beliefs.", "Ages 8+", "☪️", "#8B5CF6", ["Fundamentals of Islamic faith", "Understanding Allah's attributes", "Pillars of faith (Iman)"]),
      item("islam_tafsir", "Tafsir", "Deep understanding and interpretation of the Holy Quran.", "Ages 12+", "📜", "#EF4444", ["Verse by verse explanation", "Historical context", "Practical life applications"]),
      item("islam_fiqh", "Fiqh", "Understanding Islamic law and practical worship.", "Ages 10+", "🕌", "#06B6D4", ["Rules of prayer and fasting", "Halal and Haram guidelines", "Islamic business ethics"]),
    ],
  },
  {
    id: "languages",
    title: "Languages",
    description: "English, French, Adlam, Swahili, Yoruba, and more",
    color: "#F59E0B",
    emoji: "🌍",
    icon: Globe2,
    trackId: "tutoring",
    enrollSubject: "AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)",
    items: [
      item("lang_english", "English", "Complete support for reading, writing, grammar, vocabulary, and exam prep.", "Global", "🇬🇧", "#3B82F6", ["Homework help and comprehension", "Grammar and vocabulary", "Exam preparation"]),
      item("lang_french", "French", "Master French language skills including conversation, grammar, and cultural understanding.", "Global", "🇫🇷", "#6366F1", ["Conversation practice", "Grammar and writing", "Cultural context"]),
      item("lang_adlam", "Adlam", "Learn the Adlam script for writing Fulani with a modern West African alphabet.", "West Africa", "🔤", "#8B5CF6", ["Script and reading fundamentals", "Fulfulde/Pular connection", "Cultural preservation focus"]),
      item("lang_swahili", "Swahili", "East African Swahili with authentic instruction.", "East Africa", "🇹🇿", "#10B981", ["Speaking and listening", "Reading and writing", "Cultural immersion"]),
      item("lang_yoruba", "Yoruba", "West African Yoruba with structured lessons.", "West Africa", "🇳🇬", "#8B5CF6", ["Pronunciation and tones", "Everyday conversation", "Reading practice"]),
      item("lang_amharic", "Amharic", "Horn of Africa Amharic with clear progression.", "Horn of Africa", "🇪🇹", "#EF4444", ["Ge'ez script introduction", "Conversation skills", "Cultural context"]),
      item("lang_wolof", "Wolof", "West African Wolof for learners at any level.", "West Africa", "🇸🇳", "#06B6D4", ["Greetings and daily speech", "Grammar essentials", "Listening practice"]),
      item("lang_hausa", "Hausa", "Hausa across West and Central Africa.", "West and Central Africa", "🇳🇬", "#F59E0B", ["Core vocabulary", "Conversation", "Reading support"]),
    ],
  },
  {
    id: "english",
    title: "English & literacy",
    description: "Grammar, Reading, Creative Writing, and Test Prep",
    color: "#F59E0B",
    emoji: "📖",
    icon: BookOpen,
    trackId: "tutoring",
    enrollSubject: "Adult Literacy (Reading and Writing English & French, etc...)",
    items: [
      item("lit_grammar", "Grammar & vocabulary", "Master English grammar rules, sentence structure, and expand your vocabulary.", "All levels", "📝", "#10B981", ["Clear grammar explanations", "Sentence patterns", "Vocabulary expansion"]),
      item("lit_reading", "Reading comprehension", "Develop critical reading skills and analyze texts across various genres.", "Elementary to advanced", "📖", "#3B82F6", ["Close reading strategies", "Genre variety", "Discussion and reflection"]),
      item("lit_creative", "Creative writing", "Express yourself through stories, poetry, and creative narratives.", "Grades 3-12", "✍️", "#8B5CF6", ["Story structure", "Voice and style", "Peer feedback"]),
      item("lit_academic", "Academic writing", "Master essays, research papers, and formal academic composition.", "High school & college", "📄", "#EF4444", ["Thesis and argumentation", "Research skills", "Citation basics"]),
      item("lit_literature", "Literature analysis", "Explore classic and contemporary literature with in-depth analysis.", "High school", "📚", "#06B6D4", ["Themes and symbolism", "Textual evidence", "Discussion skills"]),
      item("lit_testprep", "Test preparation", "Prepare for standardized tests including SAT, ACT, IELTS, and TOEFL.", "All ages", "🎯", "#F59E0B", ["Timed practice", "Strategy coaching", "Weak-area focus"]),
    ],
  },
  {
    id: "math",
    title: "Mathematics",
    description: "Elementary through Calculus and Statistics",
    color: "#3B82F6",
    emoji: "📐",
    icon: Sigma,
    trackId: "tutoring",
    enrollSubject: "After School Tutoring (Math, Science, Physics, etc...)",
    items: [
      item("math_elem", "Elementary math", "Building a strong foundation in arithmetic, shapes, and problem-solving.", "Grades K-5", "➕", "#10B981", ["Number sense", "Word problems", "Confidence building"]),
      item("math_algebra", "Pre-algebra & algebra", "Mastering variables, equations, functions, and graphing.", "Grades 6-9", "🔢", "#F59E0B", ["Equation solving", "Functions and graphs", "Real-world modeling"]),
      item("math_geometry", "Geometry", "Exploring shapes, sizes, relative positions, and properties of space.", "Grades 8-10", "📐", "#8B5CF6", ["Proofs and reasoning", "Area and volume", "Spatial thinking"]),
      item("math_trig", "Trigonometry", "Understanding relationships between side lengths and angles of triangles.", "Grades 10-11", "📏", "#EF4444", ["Unit circle", "Identities", "Applications"]),
      item("math_calc", "Calculus", "Limits, derivatives, integrals, and infinite series.", "Grades 11-12+", "∫", "#06B6D4", ["Conceptual understanding", "Problem sets", "Exam readiness"]),
      item("math_stats", "Statistics", "Analyzing data, probability, distributions, and inference.", "High school & college", "📊", "#3B82F6", ["Data literacy", "Probability models", "Interpretation skills"]),
    ],
  },
  {
    id: "programming",
    title: "Coding & technology",
    description: "Kids Coding, Web, Mobile, Python, and Game Dev",
    color: "#111827",
    emoji: "💻",
    icon: Code2,
    trackId: "tutoring",
    enrollSubject: "Coding",
    items: [
      item("code_kids", "Coding for kids", "Introduction to logic, algorithms, and creativity through Scratch and Python basics.", "Ages 7-12", "🧒", "#F59E0B", ["Games and stories", "Logical thinking", "Safe, paced lessons"]),
      item("code_web", "Web development", "Build responsive websites using HTML, CSS, JavaScript, and modern frameworks.", "Teens & adults", "🌐", "#3B82F6", ["Layout and design", "Interactivity", "Portfolio projects"]),
      item("code_mobile", "Mobile app development", "Create iOS and Android apps with Flutter and Dart.", "Teens & adults", "📱", "#10B981", ["UI basics", "State and navigation", "Ship a small app"]),
      item("code_python", "Python programming", "Data science, automation, and backend development with Python.", "All ages", "🐍", "#8B5CF6", ["Syntax and structures", "Projects and scripts", "Career-relevant skills"]),
      item("code_game", "Game development", "Design and code your own video games using Unity or Godot.", "Teens", "🎮", "#EF4444", ["Game loops", "Assets and levels", "Playtesting"]),
      item("code_cs", "Intro to computer science", "Preparation for AP Computer Science and university-level studies.", "High school", "💻", "#06B6D4", ["Algorithms", "Complexity intuition", "Exam alignment"]),
    ],
  },
  {
    id: "afterschool",
    title: "After-school tutoring",
    description: "Elementary, Middle School, and High School support",
    color: "#10B981",
    emoji: "🎒",
    icon: School,
    trackId: "tutoring",
    enrollSubject: "After School Tutoring (Math, Science, Physics, etc...)",
    items: [
      item("as_elem", "Elementary (K-5)", "Foundational support across subjects with caring tutors.", "Grades K-5", "🎒", "#10B981", ["Homework help", "Skill gaps", "Confidence"]),
      item("as_middle", "Middle school (6-8)", "Support through middle grades with structured study habits.", "Grades 6-8", "📘", "#3B82F6", ["Study strategies", "Core subjects", "Organization"]),
      item("as_high", "High school (9-12)", "Rigorous support for high school courses and exams.", "Grades 9-12", "🎓", "#8B5CF6", ["AP/IB readiness", "Time management", "Subject depth"]),
    ],
  },
];

const aliases: Record<string, string> = {
  "adult-literacy": "english",
  "after-school": "afterschool",
  academic: "math",
};

export function ProgramCatalog() {
  const searchParams = useSearchParams();
  const requestedProgramId = searchParams.get("programId");
  const requestedCategory =
    categoryIdForProgram(requestedProgramId) ??
    normalizeCategory(searchParams.get("category")) ??
    normalizeCategory(searchParams.get("subject"));
  const [activeCategoryId, setActiveCategoryId] = useState(requestedCategory ?? categories[0].id);
  const [selectedCategoryId, setSelectedCategoryId] = useState<string | null>(requestedCategory ?? null);
  const [expandedIds, setExpandedIds] = useState<string[]>(requestedCategory ? [requestedCategory] : []);
  const [hoursPerWeek, setHoursPerWeek] = useState(2);
  const [pricing, setPricing] = useState<PublicSitePricingDoc>(fallbackPricing);

  const activeCategory = useMemo(
    () => categories.find((category) => category.id === activeCategoryId) ?? categories[0],
    [activeCategoryId],
  );

  const focusCategory = (categoryId: string) => {
    setActiveCategoryId(categoryId);
    setExpandedIds((current) => (current.includes(categoryId) ? current : [...current, categoryId]));
    document.getElementById(`program-${categoryId}`)?.scrollIntoView({ block: "start", behavior: "smooth" });
  };

  useEffect(() => {
    if (!requestedProgramId) return;
    window.setTimeout(() => {
      document.getElementById(`program-row-${requestedProgramId}`)?.scrollIntoView({
        block: "center",
        behavior: "smooth",
      });
    }, 60);
  }, [requestedProgramId]);

  useEffect(() => {
    let active = true;
    loadPublicMarketingBundle().then((bundle) => {
      if (active) setPricing(bundle.pricing);
    });
    return () => {
      active = false;
    };
  }, []);

  const handleCategoryHeader = (categoryId: string, expanded: boolean) => {
    setActiveCategoryId(categoryId);
    if (!expanded) {
      setExpandedIds((current) => (current.includes(categoryId) ? current : [...current, categoryId]));
      setSelectedCategoryId(categoryId);
      return;
    }
    setSelectedCategoryId((current) => (current === categoryId ? null : categoryId));
  };

  const collapseCategory = (categoryId: string) => {
    setActiveCategoryId(categoryId);
    setExpandedIds((current) => current.filter((id) => id !== categoryId));
  };

  return (
    <section className="bg-[#F8FAFC]">
      <div className="mx-auto max-w-[780px] px-4 pb-8 pt-[5px] sm:px-6 lg:px-0">
        <div className="-mx-4 bg-gradient-to-br from-[#F0F9FF] via-[#E0F2FE] to-[#DBEAFE] px-6 py-8 text-center sm:mx-0 sm:px-8 sm:py-6">
          <h1 className="text-[28px] font-black leading-tight tracking-normal text-[#111827] md:text-[32px]">
            Explore our programs
          </h1>
          <p className="mx-auto mt-3 max-w-[720px] text-[15px] leading-6 text-slate-600">
            Choose a program, preview pricing by hours per week, then continue to enrollment — all in one place.
          </p>
          <button
            type="button"
            className="mt-4 inline-flex min-h-[50px] w-full items-center justify-center gap-2 rounded-full bg-[#2563EB] px-7 text-sm font-bold text-white sm:min-h-[34px] sm:w-auto"
            onClick={() => focusCategory(categories[0].id)}
          >
            <ChevronDown size={18} />
            Browse Programs
          </button>
          <div className="mt-4 flex flex-wrap justify-center gap-x-3 gap-y-2 text-xs font-semibold text-slate-500">
            <span className="inline-flex items-center gap-1.5">
              <GraduationCap size={14} className="text-slate-400" />
              35+ Programs
            </span>
            <span className="text-slate-300">•</span>
            <span className="inline-flex items-center gap-1.5">
              <Clock3 size={14} className="text-slate-400" />
              Flexible Scheduling
            </span>
            <span className="text-slate-300">•</span>
            <span className="inline-flex items-center gap-1.5">
              <Users size={14} className="text-slate-400" />
              Expert Tutors
            </span>
          </div>
        </div>

        <div className="sticky top-[98px] z-20 -mx-4 bg-[#F8FAFC] px-4 pb-3 pt-0 sm:-mx-6 sm:px-6 lg:mx-0 lg:px-0">
          <div className="flex gap-2 overflow-x-auto pb-1">
            {categories.map((category) => {
              const selected = category.id === activeCategory.id;
              return (
                <button
                  key={category.id}
                  type="button"
                  className={`inline-flex min-h-[42px] shrink-0 items-center gap-2 rounded-full border px-3 text-sm font-bold transition ${
                    selected ? "text-white shadow-md" : "border-slate-200 bg-white text-slate-700"
                  }`}
                  style={selected ? { backgroundColor: category.color, borderColor: category.color } : undefined}
                  onClick={() => focusCategory(category.id)}
                >
                  <category.icon size={18} aria-hidden="true" />
                  {category.title}
                  <span className={selected ? "text-white/75" : "text-slate-400"}>({category.items.length})</span>
                </button>
              );
            })}
          </div>
        </div>

        <div className="grid gap-3">
          {categories.map((category) => (
            <CategoryCard
              key={category.id}
              category={category}
              expanded={expandedIds.includes(category.id)}
              selected={selectedCategoryId === category.id}
              hoursPerWeek={hoursPerWeek}
              pricingPlans={pricing.plans}
              onHoursPerWeekChange={setHoursPerWeek}
              onHeaderClick={() => handleCategoryHeader(category.id, expandedIds.includes(category.id))}
              onCollapse={() => collapseCategory(category.id)}
              targetProgramId={requestedProgramId}
            />
          ))}
        </div>
      </div>
    </section>
  );
}

function CategoryCard({
  category,
  expanded,
  selected,
  hoursPerWeek,
  pricingPlans,
  onHoursPerWeekChange,
  onHeaderClick,
  onCollapse,
  targetProgramId,
}: {
  category: CatalogCategory;
  expanded: boolean;
  selected: boolean;
  hoursPerWeek: number;
  pricingPlans: PricingPlans;
  onHoursPerWeekChange: (hours: number) => void;
  onHeaderClick: () => void;
  onCollapse: () => void;
  targetProgramId: string | null;
}) {
  const hourly = hourlyRate(category.trackId, hoursPerWeek, pricingPlans);
  const monthly = monthlyEstimateRaw(category.trackId, hoursPerWeek, pricingPlans);
  const baseHourly = baseHourlyRate(category.trackId, pricingPlans);
  const hasDiscount = hourly < baseHourly;
  const onAccent = textColorForBackground(category.color);

  return (
    <article
      id={`program-${category.id}`}
      className={`overflow-hidden rounded-[20px] border bg-white shadow-[0_4px_10px_rgba(15,23,42,0.05)] ${
        selected ? "border-2" : "border-slate-100"
      }`}
      style={selected ? { backgroundColor: `${category.color}08`, borderColor: category.color } : undefined}
    >
      <button type="button" className="block w-full text-left" onClick={onHeaderClick} aria-expanded={expanded}>
        <div className="h-1" style={{ backgroundColor: category.color }} />
        <div className="flex items-center gap-3 px-4 py-4">
          <span
            className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
            style={{ backgroundColor: `${category.color}1A`, color: category.color }}
          >
            <span className="text-[22px] leading-none">{category.emoji}</span>
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[16px] font-black leading-tight text-[#0F172A] sm:text-[17px]">{category.title}</span>
            <span className="mt-1 block text-xs leading-5 text-slate-500">{category.description}</span>
          </span>
          <span className="inline-flex rounded-lg px-2 py-1 text-[10px] font-black" style={{ backgroundColor: `${category.color}14`, color: category.color }}>
            {category.items.length} subjects
          </span>
          {selected ? <CircleCheck size={18} className="shrink-0" style={{ color: category.color }} /> : null}
          <span
            role={expanded ? "button" : undefined}
            aria-label={expanded ? `Collapse ${category.title}` : undefined}
            className="shrink-0 rounded-lg p-1"
            onClick={(event) => {
              if (!expanded) return;
              event.stopPropagation();
              onCollapse();
            }}
          >
            <ChevronDown
              size={22}
              className={`text-slate-400 transition ${expanded ? "rotate-180" : ""}`}
            />
          </span>
        </div>
      </button>

      {expanded ? (
        <div>
          <div className="border-t border-slate-100 px-4 py-3">
            {category.items.map((program, index) => (
              <ProgramFeatureRow
                key={program.id}
                program={program}
                showDivider={index < category.items.length - 1}
                targeted={program.id === targetProgramId}
              />
            ))}
          </div>

          <div
            className="border-t px-3 py-3"
            style={{ backgroundColor: `${category.color}10`, borderColor: `${category.color}33` }}
          >
            <div className="flex items-center gap-3">
              <div className="min-w-[138px] flex-1">
                <p className="text-xs font-semibold text-slate-900">Hours per week</p>
                <div className="mt-1 flex items-center gap-1.5">
                  <button
                    type="button"
                    className="inline-flex h-8 w-8 items-center justify-center rounded-full text-slate-600 disabled:text-slate-300"
                    disabled={hoursPerWeek <= 1}
                    onClick={() => onHoursPerWeekChange(Math.max(1, hoursPerWeek - 1))}
                    aria-label="Decrease hours per week"
                  >
                    <MinusCircle size={20} />
                  </button>
                  <span className="min-w-5 text-center text-sm font-black text-slate-900">{hoursPerWeek}</span>
                  <button
                    type="button"
                    className="inline-flex h-8 w-8 items-center justify-center rounded-full text-slate-600 disabled:text-slate-300"
                    disabled={hoursPerWeek >= 8}
                    onClick={() => onHoursPerWeekChange(Math.min(8, hoursPerWeek + 1))}
                    aria-label="Increase hours per week"
                  >
                    <PlusCircle size={20} />
                  </button>
                </div>
              </div>
              <div className="min-w-0 flex-[1.6]">
                <div className="flex flex-wrap items-baseline gap-x-1">
                  {hasDiscount ? (
                    <span className="text-[11px] text-slate-400 line-through">${baseHourly.toFixed(2)}</span>
                  ) : null}
                  <span className="text-sm font-bold text-slate-900">${hourly.toFixed(2)}</span>
                  <span className="text-[10px] text-slate-400">per hour</span>
                </div>
                <p className="mt-1 text-[11px] leading-4 text-slate-600">
                  {hoursPerWeek} hrs/wk × ${hourly.toFixed(2)}/hr · ≈ ${monthly.toFixed(0)}/mo
                </p>
              </div>
            </div>
            <div className="mt-3">
              <Link
                href={`/enroll/?category=${category.id}&track=${category.trackId}&hours=${hoursPerWeek}&subject=${encodeURIComponent(category.enrollSubject)}`}
                className="inline-flex min-h-10 w-full items-center justify-center rounded-[10px] px-5 text-sm font-bold"
                style={{ backgroundColor: category.color, color: onAccent }}
              >
                Continue to enrollment
              </Link>
            </div>
          </div>
        </div>
      ) : null}
    </article>
  );
}

function item(
  id: string,
  title: string,
  description: string,
  age: string,
  emoji: string,
  accentColor: string,
  features: string[],
): CatalogItem {
  return { id, title, description, age, emoji, accentColor, features };
}

function ProgramFeatureRow({
  program,
  showDivider,
  targeted,
}: {
  program: CatalogItem;
  showDivider: boolean;
  targeted: boolean;
}) {
  return (
    <div>
      <div
        id={`program-row-${program.id}`}
        className={`flex scroll-mt-36 items-start gap-3 rounded-xl px-1.5 py-2 transition ${
          targeted ? "bg-white" : ""
        }`}
        style={targeted ? { boxShadow: `0 0 0 2px ${program.accentColor}` } : undefined}
      >
        <span
          className="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-sm"
          style={{ backgroundColor: `${program.accentColor}14` }}
        >
          {program.emoji}
        </span>
        <span className="min-w-0 flex-1">
          <span className="flex items-start gap-2">
            <h2 className="min-w-0 flex-1 text-[13px] font-semibold leading-[1.2] text-[#1E293B]">
              {program.title}
            </h2>
            <span className="shrink-0 text-[9px] font-semibold leading-4" style={{ color: program.accentColor }}>
              {program.age}
            </span>
          </span>
          <p className="mt-1 text-[11.5px] leading-[1.3] text-[#64748B]">{program.description}</p>
        </span>
      </div>
      {showDivider ? <div className="ml-10 mr-2 h-px bg-[#F1F5F9]" /> : null}
    </div>
  );
}

function categoryIdForProgram(programId: string | null) {
  if (!programId) return null;
  for (const category of categories) {
    if (category.items.some((program) => program.id === programId)) return category.id;
  }
  return null;
}

function hourlyRate(trackId: string, hours: number, pricingPlans?: PricingPlans) {
  const plan = pricingPlans?.[trackId];
  if (trackId === "islamic") {
    const threshold = numberValue(plan?.islamicDiscountThreshold, 4);
    return hours > threshold
      ? numberValue(plan?.islamicDiscountUsd ?? plan?.islamicHr5PlusUsd, 6.99)
      : numberValue(plan?.islamicBaseUsd ?? plan?.islamicHrUnder5Usd, 8.5);
  }
  if (trackId === "group") return numberValue(plan?.groupHourlyUsd ?? plan?.hourlyUsd, 2.5);
  const threshold = numberValue(plan?.tutoringDiscountThreshold, 4);
  return hours > threshold
    ? numberValue(plan?.tutoringDiscountUsd ?? plan?.tutoringHr4PlusUsd, 9.99)
    : numberValue(plan?.tutoringBaseUsd ?? plan?.tutoringHrUnder4Usd, 11.99);
}

function baseHourlyRate(trackId: string, pricingPlans?: PricingPlans) {
  const plan = pricingPlans?.[trackId];
  if (trackId === "islamic") return numberValue(plan?.islamicBaseUsd ?? plan?.islamicHrUnder5Usd, 8.5);
  if (trackId === "group") return numberValue(plan?.groupHourlyUsd ?? plan?.hourlyUsd, 2.5);
  return numberValue(plan?.tutoringBaseUsd ?? plan?.tutoringHrUnder4Usd, 11.99);
}

function monthlyEstimateRaw(trackId: string, hours: number, pricingPlans?: PricingPlans) {
  return hourlyRate(trackId, hours, pricingPlans) * hours * (trackId === "group" ? 4.33 : 4);
}

function numberValue(value: unknown, fallback: number) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function textColorForBackground(hexColor: string) {
  const normalized = hexColor.replace("#", "");
  const r = parseInt(normalized.slice(0, 2), 16) / 255;
  const g = parseInt(normalized.slice(2, 4), 16) / 255;
  const b = parseInt(normalized.slice(4, 6), 16) / 255;
  const luminance = [r, g, b]
    .map((channel) => (channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4))
    .reduce((sum, channel, index) => sum + channel * [0.2126, 0.7152, 0.0722][index], 0);
  return luminance > 0.55 ? "#0F172A" : "#FFFFFF";
}

function normalizeCategory(value: string | null) {
  if (!value) return null;
  const lower = value.toLowerCase();
  if (aliases[lower]) return aliases[lower];
  if (categories.some((category) => category.id === lower)) return lower;
  if (lower.includes("islamic")) return "islamic";
  if (lower.includes("afro") || lower.includes("language")) return "languages";
  if (lower.includes("literacy") || lower.includes("english")) return "english";
  if (lower.includes("math")) return "math";
  if (lower.includes("coding") || lower.includes("programming")) return "programming";
  if (lower.includes("after school") || lower.includes("tutoring")) return "afterschool";
  return null;
}
