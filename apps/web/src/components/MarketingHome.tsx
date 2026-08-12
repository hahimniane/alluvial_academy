"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  BookOpen,
  CheckCircle2,
  ChevronRight,
  Code2,
  FunctionSquare,
  GraduationCap,
  Grid3X3,
  Eye,
  Languages,
  MoonStar,
  Rocket,
  Search,
  Sparkles,
  School,
  Star,
  UsersRound,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState, type CSSProperties, type PointerEvent } from "react";
import { Reveal } from "@/components/Reveal";
import { fallbackPricing, loadPublicMarketingBundle, type PublicSiteMarketingBundle } from "@/lib/publicSiteCms";
import { PRICING_HOUR_OPTIONS } from "@/lib/enrollmentHours";

function enterDelay(ms: number) {
  return { "--enter-delay": `${ms}ms` } as CSSProperties;
}

const subjects = [
  "After School Tutoring (Math, Science, Physics, etc...)",
  "African Languages (Pular, Mandingo, Swahili, Wolof, etc...)",
  "Entrepreneurship",
  "Coding",
  "Adult Literacy (Reading and Writing English & French, etc...)",
  "Religious Studies (Quran, Arabic, etc...)",
];

const courseColumns = [
  {
    title: "Languages & Religious Studies",
    color: "#2563EB",
    gradient: "linear-gradient(120deg, #1E3A8A 0%, #2563EB 100%)",
    items: [
      {
        title: "Religious Studies",
        subtitle: "Quran, Arabic, Tawhid, Hadith, Tafsir",
        href: "/programs/?category=islamic",
        icon: MoonStar,
      },
      {
        title: "African Languages & AdLam",
        subtitle: "Pular, Mandingo, Swahili, Wolof, Yoruba",
        href: "/programs/?category=languages",
        icon: Languages,
      },
    ],
  },
  {
    title: "Academic & tutoring",
    color: "#F59E0B",
    gradient: "linear-gradient(120deg, #B45309 0%, #F59E0B 100%)",
    items: [
      {
        title: "Math Classes",
        subtitle: "Elementary through advanced calculus",
        href: "/programs/?category=math",
        icon: FunctionSquare,
      },
      {
        title: "Programming",
        subtitle: "Web, mobile, and software development",
        href: "/programs/?category=programming",
        icon: Code2,
      },
      {
        title: "Adult Literacy",
        subtitle: "Reading and writing in English and French",
        href: "/programs/?category=adult-literacy",
        icon: BookOpen,
      },
      {
        title: "After School Tutoring",
        subtitle: "Math, science, physics, and more",
        href: "/programs/?category=after-school",
        icon: School,
      },
    ],
  },
];

const pricingTracks = [
  {
    id: "islamic",
    title: "Religious Studies & AdLam",
    subtitle: "30 min and 1 hour sessions",
    accent: "#2563EB",
    icon: MoonStar,
    defaults: ["1-on-1 Quran, Arabic, and AdLam", "Flexible weekday scheduling", "Discount at 4+ hours/week"],
  },
  {
    id: "tutoring",
    title: "Tutoring & Literacy",
    subtitle: "1 hour sessions",
    accent: "#F59E0B",
    icon: School,
    defaults: ["Math, science, literacy support", "Personalized one-on-one coaching", "Discount at 4+ hours/week"],
  },
  {
    id: "group",
    title: "Group Classes",
    subtitle: "Fri / Sat / Sun, 2 hours per day",
    accent: "#E11D48",
    icon: UsersRound,
    defaults: ["Weekend group classes", "Flat hourly rate", "Community learning setting"],
  },
];

const communityStats = [
  { value: 200, suffix: "+", label: "students learning with us" },
  { value: 40, suffix: "+", label: "expert teachers" },
  { value: 15, suffix: "+", label: "countries represented" },
  { value: 200, suffix: "+", label: "live classes every week" },
];

const communityVoices = [
  {
    quote:
      "Allah directed me to Alluwal — one of the best Arabic learning institutions, with qualified teachers and leaders of true integrity.",
    name: "Abdulai Diallo",
    role: "Ustaz · Kenema, Sierra Leone",
  },
  {
    quote:
      "Alluwal is professional and well-organized — exactly the kind of environment where meaningful education can thrive.",
    name: "Mamadou Saidou Diallo",
    role: "Teacher · Morocco",
  },
  {
    quote:
      "I chose Alluwal because of its strong educational values, supportive leadership, and genuine commitment to student success.",
    name: "Zainab Sall",
    role: "Teacher · Turkey",
  },
];

const aboutCards = [
  {
    title: "Our Mission",
    body: "To bring together African, Western, and faith-based education in one holistic curriculum that prepares students to navigate and succeed in a diverse world.",
    color: "#3B82F6",
    icon: Rocket,
  },
  {
    title: "Our Vision",
    body: "To create an inclusive, inspiring environment where students are encouraged to become leaders in their communities.",
    color: "#F59E0B",
    icon: Eye,
  },
];

export function MarketingHome() {
  const router = useRouter();
  const heroRef = useRef<HTMLElement>(null);
  const [bundle, setBundle] = useState<PublicSiteMarketingBundle | null>(null);
  const [query, setQuery] = useState("");
  const [hoursPerWeek, setHoursPerWeek] = useState(4);

  useEffect(() => {
    let active = true;
    loadPublicMarketingBundle().then((next) => {
      if (active) setBundle(next);
    });
    return () => {
      active = false;
    };
  }, []);

  const pricing = bundle?.pricing ?? fallbackPricing;

  const suggestions = useMemo(() => {
    const needle = query.trim().toLowerCase();
    if (!needle) return [];
    return subjects.filter((subject) => subject.toLowerCase().includes(needle));
  }, [query]);

  const selectSubject = (subject: string) => {
    if (subject === "Entrepreneurship") {
      router.push("/enroll/?category=entrepreneurship&track=tutoring&subject=Entrepreneurship");
      return;
    }
    router.push(`/programs/?subject=${encodeURIComponent(subject)}`);
  };

  const moveHero = (event: PointerEvent<HTMLElement>) => {
    const node = heroRef.current;
    if (!node) return;
    const rect = node.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width - 0.5).toFixed(3);
    const y = ((event.clientY - rect.top) / rect.height - 0.5).toFixed(3);
    node.style.setProperty("--hero-px", x);
    node.style.setProperty("--hero-py", y);
  };

  const resetHero = () => {
    const node = heroRef.current;
    if (!node) return;
    node.style.setProperty("--hero-px", "0");
    node.style.setProperty("--hero-py", "0");
  };

  return (
    <>
      <section
        ref={heroRef}
        className="marketing-hero relative overflow-hidden"
        onPointerMove={moveHero}
        onPointerLeave={resetHero}
      >
        <div className="hero-warm-mesh absolute inset-0" aria-hidden="true" />
        <div className="hero-soft-pattern absolute inset-0" aria-hidden="true" />
        <div className="hero-story-thread hero-story-thread-one" aria-hidden="true" />
        <div className="hero-story-thread hero-story-thread-two" aria-hidden="true" />
        <div className="hero-blob left-[-120px] top-[-80px] h-[340px] w-[340px] bg-[#93C5FD]/34" aria-hidden="true" />
        <div
          className="hero-blob bottom-[-140px] right-[-100px] h-[380px] w-[380px] bg-[#FBBF24]/34"
          style={{ animationDelay: "-7s" }}
          aria-hidden="true"
        />
        <div
          className="hero-blob right-[24%] top-[70px] h-[240px] w-[240px] bg-[#F472B6]/18"
          style={{ animationDelay: "-12s" }}
          aria-hidden="true"
        />
        <div className="relative mx-auto grid max-w-[1200px] items-center gap-8 px-6 pb-8 pt-12 lg:grid-cols-[minmax(0,1fr)_minmax(420px,520px)] lg:gap-12 lg:py-12">
          <div>
            <div className="hero-enter mb-5 inline-flex items-center gap-2 rounded-full border border-[#BFDBFE] bg-white/78 px-3.5 py-2 text-sm font-extrabold text-[#1D4ED8] shadow-[0_10px_30px_rgba(37,99,235,0.12)] backdrop-blur" style={enterDelay(0)}>
              <span className="h-2 w-2 rounded-full bg-[#F59E0B]" />
              Live online classes with real tutors
            </div>
            <h1
              className="hero-enter font-display max-w-3xl text-[40px] font-bold leading-[1.08] text-[#0B1B3A] md:text-[62px] md:leading-[1.04]"
              style={enterDelay(90)}
            >
              Learn with tutors who know your child <span className="headline-accent">by name.</span>
            </h1>
            <p
              className="hero-enter mt-5 max-w-2xl text-[16px] leading-[1.7] text-[#475569] md:text-[18px]"
              style={enterDelay(180)}
            >
              Tutoring, languages, math, coding, enterprise, and faith studies in one warm online learning space for families around the world.
            </p>

            <div className="hero-enter mt-8 flex flex-col gap-3 sm:flex-row" style={enterDelay(280)}>
              <Link
                href="/enroll/"
                className="alluwal-button hero-primary-cta w-full rounded-full px-8 text-base sm:w-auto"
              >
                Enroll a Student
                <Rocket size={19} />
              </Link>
              <Link
                href="/programs/"
                className="alluwal-button w-full rounded-full border border-[#CBD5E1] bg-white/82 px-8 text-base text-[#0F172A] shadow-[0_10px_30px_rgba(15,23,42,0.08)] backdrop-blur hover:bg-white sm:w-auto"
              >
                <Grid3X3 size={21} />
                Explore Programs
              </Link>
            </div>

            <form
              className="hero-enter relative mt-6 max-w-[650px]"
              style={enterDelay(380)}
              onSubmit={(event) => {
                event.preventDefault();
                if (query.trim()) selectSubject(query.trim());
              }}
            >
              <div className="hero-search-shell flex h-[52px] items-center rounded-full bg-white shadow-[0_24px_70px_rgba(15,23,42,0.12)] ring-1 ring-slate-200/80 md:h-[58px]">
                <input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  className="h-full min-w-0 flex-1 rounded-full border-0 bg-transparent px-5 text-[14px] text-slate-900 outline-none placeholder:text-[#9CA3AF] md:px-6 md:text-[15px]"
                  placeholder="What would you like to learn?"
                  aria-label="What would you like to learn?"
                />
                <button
                  type="submit"
                  className="mr-3 inline-flex h-10 w-10 items-center justify-center rounded-full bg-[#EFF6FF] text-[#2563EB] transition hover:bg-[#DBEAFE]"
                  aria-label="Search programs"
                >
                  <Search size={22} />
                </button>
              </div>

              {suggestions.length > 0 ? (
                <div className="absolute left-3 right-3 top-[54px] z-20 overflow-hidden rounded-2xl bg-white py-2 shadow-2xl shadow-slate-900/16">
                  {suggestions.map((subject) => (
                    <button
                      key={subject}
                      type="button"
                      className="flex w-full items-center gap-3 px-6 py-3 text-left text-[15px] font-medium text-slate-700 transition hover:bg-slate-50"
                      onClick={() => selectSubject(subject)}
                    >
                      <Search size={18} className="text-slate-400" />
                      {subject}
                    </button>
                  ))}
                </div>
              ) : null}
            </form>

            <Link
              href="/team/?category=teacher"
              className="hero-enter mt-4 inline-flex min-h-[42px] items-center gap-2 rounded-full border border-[#CBD5E1] bg-white/60 px-4 py-2 text-sm font-bold text-[#1E3A8A] shadow-[0_10px_30px_rgba(15,23,42,0.07)] backdrop-blur transition hover:border-[#93C5FD] hover:bg-white"
              style={enterDelay(460)}
            >
              <GraduationCap size={18} />
              Our Teachers
            </Link>

            <div className="hero-enter mt-5 flex flex-wrap items-center gap-2 text-sm font-bold text-[#64748B]" style={enterDelay(540)}>
              <span className="inline-flex items-center rounded-full bg-white/70 px-3 py-1.5 shadow-[0_10px_24px_rgba(15,23,42,0.06)]">Tutoring</span>
              <span className="inline-flex items-center rounded-full bg-white/70 px-3 py-1.5 shadow-[0_10px_24px_rgba(15,23,42,0.06)]">Math</span>
              <span className="inline-flex items-center rounded-full bg-white/70 px-3 py-1.5 shadow-[0_10px_24px_rgba(15,23,42,0.06)]">Languages</span>
              <span className="inline-flex items-center rounded-full bg-white/70 px-3 py-1.5 shadow-[0_10px_24px_rgba(15,23,42,0.06)]">Coding</span>
            </div>
          </div>

          <div
            // Tall enough that the floating badges clear the schedule board
            // instead of covering its last rows.
            className="hero-enter relative mx-auto h-[470px] w-full max-w-[500px] lg:-top-2 lg:mx-0 lg:h-[524px] lg:max-w-none"
            style={enterDelay(320)}
          >
            <div className="hero-collage-float relative h-full w-full">
              <LearningPathMotion />
              <LiveScheduleBoard />
              <div className="hero-badge-float absolute left-0 top-1 z-30 rounded-2xl border border-white bg-white/90 px-3.5 py-2.5 shadow-[0_20px_50px_rgba(15,23,42,0.14)] backdrop-blur lg:top-4">
                <div className="flex items-center gap-2.5">
                  <span className="inline-flex h-9 w-9 items-center justify-center rounded-xl bg-[#DBEAFE] text-[#1D4ED8]">
                    <Sparkles size={19} />
                  </span>
                  <span>
                    <span className="block text-[13px] font-black text-[#0B1B3A]">Six subjects</span>
                    <span className="block text-[11px] font-semibold text-[#64748B]">One trusted place</span>
                  </span>
                </div>
              </div>
              <div className="hero-badge-float absolute bottom-[8px] left-[26px] z-30 flex items-center gap-2.5 rounded-2xl border border-white bg-white/94 px-3.5 py-2.5 shadow-[0_22px_60px_rgba(15,23,42,0.16)] backdrop-blur lg:bottom-[18px] lg:left-[40px]">
                <span className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-[#FEF3C7] text-[#B45309]">
                  <Star size={16} fill="currentColor" />
                </span>
                <span>
                  <span className="block text-[13px] font-black text-[#0B1B3A]">“She nailed it today.”</span>
                  <span className="block text-[11px] font-semibold text-[#64748B]">Mariama, tutor · just now</span>
                </span>
              </div>
              <div className="hero-badge-float absolute bottom-0 right-2 z-30 rounded-2xl border border-white bg-[#0B1B3A] px-4 py-3 text-white shadow-[0_24px_70px_rgba(15,23,42,0.22)] lg:right-4">
                <div className="flex items-center gap-1 text-[22px] font-black leading-none">
                  5<Star size={17} className="text-[#FBBF24]" fill="currentColor" />
                </div>
                <div className="mt-1 text-[11px] font-bold text-white/72">family-rated classes</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="border-y border-slate-100 bg-white py-9 md:py-11" aria-label="Alluwal community at a glance">
        <div className="container-shell">
          <Reveal>
            <div className="grid grid-cols-2 gap-x-4 gap-y-7 md:grid-cols-4">
              {communityStats.map(({ value, suffix, label }) => (
                <div key={label} className="text-center">
                  <div className="font-display text-[34px] font-bold leading-none text-[#0B1B3A] md:text-[42px]">
                    <CountUp target={value} />
                    <span className="text-[#F59E0B]">{suffix}</span>
                  </div>
                  <div className="mx-auto mt-2 max-w-[170px] text-[13px] font-semibold leading-snug text-[#64748B]">{label}</div>
                </div>
              ))}
            </div>
          </Reveal>
        </div>
      </section>

      <section id="programs" className="bg-[#F8FAFC] py-14 md:py-16">
        <div className="container-shell text-center">
          <Reveal>
            <span className="section-eyebrow">Programs</span>
            <h2 className="font-display mt-4 text-[30px] font-bold text-[#0B1B3A] md:text-[40px]">Explore Our Main Courses</h2>
            <p className="mx-auto mt-3 max-w-[700px] text-base leading-[1.6] text-[#6b7280]">
              Discover comprehensive learning paths across tutoring, languages, enterprise, and faith studies — built for learners of every background.
            </p>
          </Reveal>

          <div className="mt-9 grid gap-6 text-left lg:grid-cols-2">
            {courseColumns.map((column, columnIndex) => (
              <Reveal key={column.title} delay={columnIndex * 140}>
                <div className="hover-lift overflow-hidden rounded-2xl border border-[#e5e7eb] bg-white shadow-[0_4px_12px_rgba(0,0,0,0.06)]">
                  <div className="px-5 py-4 text-base font-bold text-white" style={{ background: column.gradient }}>
                    {column.title}
                  </div>
                  <div>
                    {column.items.map(({ title, subtitle, href, icon: Icon }, index) => (
                      <Link
                        key={title}
                        href={href}
                        className={`group flex h-[72px] items-center px-5 transition hover:bg-[#f9fafb] ${
                          index < column.items.length - 1 ? "border-b border-slate-100" : ""
                        }`}
                      >
                        <Icon
                          size={22}
                          className="shrink-0 transition-transform duration-300 group-hover:scale-110"
                          style={{ color: column.color }}
                        />
                        <span className="ml-3.5 min-w-0 flex-1">
                          <span className="block truncate text-[15px] font-semibold text-[#1f2937]">{title}</span>
                          <span className="mt-1 block line-clamp-2 text-xs leading-[1.35] text-[#6b7280]">{subtitle}</span>
                        </span>
                        <ChevronRight
                          size={20}
                          className="ml-3 shrink-0 text-slate-400 transition-transform duration-300 group-hover:translate-x-1.5 group-hover:text-slate-600"
                        />
                      </Link>
                    ))}
                  </div>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section id="pricing" className="bg-[#F7F5F2] py-12 md:py-[52px]">
        <div className="container-shell text-center">
          <Reveal>
            <span className="section-eyebrow">Pricing</span>
            <h2 className="font-display mt-4 text-[30px] font-bold text-[#0B1B3A] md:text-[40px]">Transparent & Affordable Rates</h2>
            <p className="mx-auto mt-3 max-w-[700px] text-base leading-[1.6] text-[#6b6560]">
              Choose the plan that fits your schedule. All prices are informational - contact us to enroll.
            </p>
          </Reveal>

          <div className="mt-7 flex flex-wrap justify-center gap-2">
            {PRICING_HOUR_OPTIONS.map((hour) => {
              const selected = hour === hoursPerWeek;
              return (
                <button
                  key={hour}
                  type="button"
                  className={`rounded-full border px-3.5 py-2 text-sm font-semibold transition ${
                    selected
                      ? "border-[#1D4ED8] bg-[#1D4ED8] text-white shadow-[0_10px_24px_rgba(29,78,216,0.28)]"
                      : "border-slate-300 bg-white text-slate-700 hover:border-[#1D4ED8] hover:text-[#1D4ED8]"
                  }`}
                  onClick={() => setHoursPerWeek(hour)}
                >
                  {hour} hrs/wk
                </button>
              );
            })}
          </div>

          <div className="mt-7 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {pricingTracks.map((track, index) => (
              <Reveal key={track.id} delay={index * 120} className="h-full">
                <PricingCard
                  track={track}
                  hoursPerWeek={hoursPerWeek}
                  pricing={pricing}
                />
              </Reveal>
            ))}
          </div>

          <Reveal>
          <div className="mx-auto mt-10 flex max-w-4xl items-start gap-4 rounded-2xl border border-[#FDE68A] bg-[#FFFBEB] p-5 text-left shadow-[0_10px_30px_rgba(245,158,11,0.08)]">
            <span className="mt-0.5 inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#FEF3C7] text-[#B45309]">
              <CheckCircle2 size={22} />
            </span>
            <div>
              <p className="text-[15px] font-extrabold text-[#92400E]">
                Payment is due at the beginning of each month, not at the end.
              </p>
              <p className="mt-1.5 text-sm leading-[1.6] text-[#78350F]/80">
                Payment methods: Zelle (646-338-1286), MoneyGram, Bank Transfer, CashApp, or Western Union.
              </p>
            </div>
          </div>

          <div className="mt-4 inline-flex rounded-full border border-[#BFDBFE] bg-[#EFF6FF] px-5 py-2.5 text-[13px] font-semibold text-[#1e40af]">
            WhatsApp: (+1) 646-872-8590 | alluwalacademy@gmail.com
          </div>

          <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <Link href="/enroll/" className="alluwal-button alluwal-button-primary w-full sm:w-[300px]">
              Enroll Now
            </Link>
          </div>
          <div className="mt-3 flex flex-wrap justify-center gap-2">
            <Link href="/teacher-application/" className="inline-flex items-center gap-2 px-3 py-2 text-[13px] font-semibold text-[#2563EB]">
              <School size={18} />
              Apply to Teach
            </Link>
            <Link href="/enroll/?students=multiple" className="inline-flex items-center gap-2 px-3 py-2 text-[13px] font-semibold text-[#2563EB]">
              <UsersRound size={18} />
              Enroll multiple students
            </Link>
          </div>
          </Reveal>
        </div>
      </section>

      <section className="bg-white py-14 md:py-16" aria-label="Voices from our community">
        <div className="container-shell text-center">
          <Reveal>
            <span className="section-eyebrow">Community</span>
            <h2 className="font-display mt-4 text-[30px] font-bold text-[#0B1B3A] md:text-[40px]">Voices from our community</h2>
            <p className="mx-auto mt-3 max-w-[700px] text-base leading-[1.6] text-[#6b7280]">
              Real words from the teachers and mentors who show up for your children every day.
            </p>
          </Reveal>
          <div className="mt-9 grid gap-5 text-left md:grid-cols-3">
            {communityVoices.map(({ quote, name, role }, index) => (
              <Reveal key={name} delay={index * 130} className="h-full">
                <figure className="hover-lift flex h-full flex-col rounded-2xl border border-[#E5E7EB] bg-[#F8FAFC] p-6">
                  <span className="font-display text-[44px] font-bold leading-none text-[#F59E0B]" aria-hidden="true">
                    “
                  </span>
                  <blockquote className="mt-1 flex-1 text-[15px] leading-[1.7] text-[#334155]">{quote}</blockquote>
                  <figcaption className="mt-5 border-t border-slate-200 pt-4">
                    <div className="text-sm font-black text-[#0B1B3A]">{name}</div>
                    <div className="mt-0.5 text-xs font-semibold text-[#64748B]">{role}</div>
                  </figcaption>
                </figure>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section id="about" className="bg-white px-6 py-14">
        <div className="mx-auto max-w-[1200px] text-center">
          <Reveal>
            <span className="section-eyebrow">Who We Are</span>
            <h2 className="font-display mt-4 text-[32px] font-bold leading-tight text-[#0B1B3A] md:text-[42px]">
              About Alluwal Education Hub
            </h2>
            <p className="mx-auto mt-4 max-w-[700px] text-[18px] leading-[1.6] text-[#6B7280]">
              We are fostering a world where diverse knowledge—African, Western, and faith traditions—comes together to prepare students for a globalized future.
            </p>
          </Reveal>

          <div className="mt-12 grid gap-6 lg:grid-cols-2">
            {aboutCards.map(({ title, body, color, icon: Icon }, index) => (
              <Reveal key={title} delay={index * 140}>
                <article className="hover-lift group rounded-[20px] border border-[#E5E7EB] bg-white p-8 text-left shadow-[0_10px_30px_rgba(15,23,42,0.04)]">
                  <span
                    className="inline-flex h-16 w-16 items-center justify-center rounded-2xl transition-transform duration-300 group-hover:scale-110"
                    style={{ backgroundColor: `${color}1a`, color }}
                  >
                    <Icon size={34} />
                  </span>
                  <h3 className="font-display mt-7 text-2xl font-bold text-[#0B1B3A]">{title}</h3>
                  <p className="mt-4 text-[16px] leading-[1.7] text-[#6B7280]">{body}</p>
                </article>
              </Reveal>
            ))}
          </div>

          <Reveal delay={120}>
            <Link
              href="/about/"
              className="mt-10 inline-flex min-h-[48px] items-center justify-center rounded-xl bg-[#001E4E] px-10 text-base font-bold text-white shadow-[0_6px_14px_rgba(0,30,78,0.25)] transition hover:-translate-y-0.5 hover:shadow-[0_12px_24px_rgba(0,30,78,0.32)]"
            >
              Learn More About Us
            </Link>
          </Reveal>
        </div>
      </section>

      <section id="contact" className="relative overflow-hidden bg-gradient-to-br from-[#001E4E] to-[#003399] py-14 text-white">
        <div className="hero-blob right-[-120px] top-[-120px] h-[300px] w-[300px] bg-[#0386ff]/30" aria-hidden="true" />
        <div className="container-shell relative grid gap-6 md:grid-cols-[1fr_auto] md:items-center">
          <Reveal>
            <h2 className="font-display text-[32px] font-bold leading-tight md:text-[42px]">Ready to start learning?</h2>
            <p className="mt-4 max-w-3xl text-lg leading-8 text-white/82">
              Explore our programs and get in touch when you are ready to enroll.
            </p>
          </Reveal>
          <Reveal delay={140}>
            <Link href="/programs/" className="alluwal-button bg-white text-[#001E4E] hover:bg-white/92">
              Explore Our Programs
            </Link>
          </Reveal>
        </div>
      </section>
    </>
  );
}

function CountUp({ target }: { target: number }) {
  const ref = useRef<HTMLSpanElement>(null);
  const [value, setValue] = useState(0);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;
    if (
      typeof IntersectionObserver === "undefined" ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      setValue(target);
      return;
    }
    let frame = 0;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        observer.disconnect();
        const startedAt = performance.now();
        const durationMs = 1400;
        const tick = (now: number) => {
          const progress = Math.min((now - startedAt) / durationMs, 1);
          const eased = 1 - Math.pow(1 - progress, 3);
          setValue(Math.round(target * eased));
          if (progress < 1) frame = requestAnimationFrame(tick);
        };
        frame = requestAnimationFrame(tick);
      },
      { threshold: 0.4 },
    );
    observer.observe(node);
    return () => {
      observer.disconnect();
      cancelAnimationFrame(frame);
    };
  }, [target]);

  return <span ref={ref}>{value}</span>;
}

const classmates = [
  { initials: "AY", name: "Amina", tint: "linear-gradient(135deg, #F59E0B, #E11D48)", raisedHand: true, muted: false },
  { initials: "YB", name: "Yusuf", tint: "linear-gradient(135deg, #0EA5E9, #4F46E5)", raisedHand: false, muted: false },
  { initials: "FD", name: "Fatou", tint: "linear-gradient(135deg, #10B981, #0F766E)", raisedHand: false, muted: true },
];

/**
 * Today's live classes.
 *
 * The hero used to mock up a single lesson, which forced the whole homepage to
 * pick one subject — and it picked Quran recitation. A schedule shows the
 * breadth instead of claiming it: six subjects side by side, each with its own
 * accent, faith studies among them rather than ahead of them.
 */
const todaysClasses = [
  { time: "09:00", subject: "Algebra II", track: "Tutoring", initials: "AB", tint: "#2563EB" },
  { time: "10:30", subject: "Pular", track: "Languages", initials: "MD", tint: "#0D9488" },
  { time: "12:00", subject: "Python", track: "Coding", initials: "SK", tint: "#7C3AED" },
  { time: "14:00", subject: "Pitch practice", track: "Enterprise", initials: "FT", tint: "#EA580C" },
  { time: "16:00", subject: "Quran", track: "Faith", initials: "IB", tint: "#0F766E" },
  { time: "17:30", subject: "Reading", track: "Literacy", initials: "NJ", tint: "#DB2777" },
];

function LiveScheduleBoard() {
  return (
    // Sits below the floating badge above it so the board's own header stays legible.
    <div className="hero-photo-card absolute right-0 top-[52px] z-20 w-[88%] max-w-[420px] rounded-[26px] border border-white/70 bg-white/85 p-2 shadow-[0_30px_90px_rgba(15,23,42,0.2)] backdrop-blur lg:top-[58px]">
      <div className="overflow-hidden rounded-[20px] bg-[#0B1B3A]">
        <div className="flex items-center justify-between border-b border-white/10 px-4 py-2.5">
          <div className="flex items-center gap-2 text-[12px] font-extrabold tracking-wide text-white">
            <span className="live-dot" aria-hidden="true" />
            TODAY&rsquo;S CLASSES
          </div>
          <span className="text-[11px] font-semibold text-white/60">6 subjects</span>
        </div>

        <ul className="m-0 list-none p-2">
          {todaysClasses.map(({ time, subject, track, initials, tint }, index) => (
            <li
              key={subject}
              className="schedule-row flex items-center gap-3 rounded-xl px-2 py-[7px]"
              style={{ "--row-index": index } as CSSProperties}
            >
              <span className="w-[38px] shrink-0 font-mono text-[11px] font-semibold tabular-nums text-white/55">
                {time}
              </span>
              <span
                className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-[11px] font-black text-white"
                style={{ background: tint }}
                aria-hidden="true"
              >
                {initials}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13px] font-bold leading-tight text-white">{subject}</span>
                <span className="block text-[10.5px] font-semibold uppercase tracking-[0.07em]" style={{ color: tint }}>
                  {track}
                </span>
              </span>
              <span className="schedule-live shrink-0 rounded-full bg-[#22C55E]/15 px-2 py-[3px] text-[9.5px] font-black uppercase tracking-[0.08em] text-[#4ADE80]">
                Live
              </span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function LearningPathMotion() {
  return (
    <div className="hero-learning-system absolute inset-[-38px] z-0" aria-hidden="true">
      <div className="knowledge-ring knowledge-ring-one" />
      <div className="knowledge-ring knowledge-ring-two" />
      <svg className="knowledge-map" viewBox="0 0 560 450" fill="none">
        <defs>
          <linearGradient id="knowledge-flow-gradient" x1="96" y1="86" x2="496" y2="360" gradientUnits="userSpaceOnUse">
            <stop stopColor="#2563EB" stopOpacity="0.08" />
            <stop offset="0.48" stopColor="#2563EB" stopOpacity="0.52" />
            <stop offset="1" stopColor="#F59E0B" stopOpacity="0.16" />
          </linearGradient>
          <linearGradient id="knowledge-gold-gradient" x1="56" y1="350" x2="498" y2="76" gradientUnits="userSpaceOnUse">
            <stop stopColor="#F59E0B" stopOpacity="0.1" />
            <stop offset="0.52" stopColor="#0F172A" stopOpacity="0.28" />
            <stop offset="1" stopColor="#2563EB" stopOpacity="0.1" />
          </linearGradient>
        </defs>
        <path className="knowledge-orbit knowledge-orbit-one" d="M70 244C112 86 298 24 436 96C548 154 540 322 414 374C258 439 80 392 70 244Z" />
        <path className="knowledge-orbit knowledge-orbit-two" d="M110 124C236 34 414 78 474 210C524 320 398 410 244 378C104 350 20 204 110 124Z" />
        <path className="knowledge-flow knowledge-flow-one" d="M88 326C176 272 194 160 276 156C358 152 384 260 482 214" />
        <path className="knowledge-flow knowledge-flow-two" d="M102 118C190 156 232 250 314 246C396 242 420 124 492 92" />
        <circle className="knowledge-pulse knowledge-pulse-one" cx="116" cy="326" r="5" />
        <circle className="knowledge-pulse knowledge-pulse-two" cx="278" cy="156" r="5" />
        <circle className="knowledge-pulse knowledge-pulse-three" cx="462" cy="214" r="5" />
        <circle className="knowledge-pulse knowledge-pulse-four" cx="320" cy="246" r="4" />
      </svg>
      <span className="knowledge-node knowledge-node-faith"><MoonStar size={20} /></span>
      <span className="knowledge-node knowledge-node-language"><Languages size={20} /></span>
      <span className="knowledge-node knowledge-node-academic"><FunctionSquare size={20} /></span>
      <span className="knowledge-node knowledge-node-code"><Code2 size={20} /></span>
    </div>
  );
}

function PricingCard({
  track,
  hoursPerWeek,
  pricing,
}: {
  track: (typeof pricingTracks)[number];
  hoursPerWeek: number;
  pricing: typeof fallbackPricing;
}) {
  const plan = pricing.plans[track.id] ?? { bullets: track.defaults };
  const hourly = hourlyPrice(track.id, hoursPerWeek, plan);
  const monthlyMultiplier = track.id === "group" ? 4.33 : 4;
  const monthly = hourly * hoursPerWeek * monthlyMultiplier;
  const Icon = track.icon;
  const features = plan.bullets.length > 0 ? plan.bullets : track.defaults;
  const showDiscountBadge = track.id !== "group";
  const discountApplied = showDiscountBadge && hoursPerWeek > Number(
    track.id === "islamic"
      ? plan.islamicDiscountThreshold ?? 4
      : plan.tutoringDiscountThreshold ?? 4,
  );

  return (
    <div className="hover-lift mx-auto flex h-full min-h-[400px] w-full max-w-[390px] flex-col overflow-hidden rounded-[18px] border border-[#ebe8e3] bg-white text-left shadow-[0_4px_14px_rgba(0,0,0,0.06)]">
      <div className="h-2" style={{ backgroundColor: track.accent }} />
      <div className="flex min-h-0 flex-1 flex-col p-4 pb-2">
        <Icon size={24} style={{ color: track.accent }} />
        <h3 className="font-display mt-2.5 text-lg font-bold text-[#111827]">{track.title}</h3>
        <p className="mt-1 text-xs font-medium text-[#6b7280]">{track.subtitle}</p>
        <div className="mt-2.5 text-[28px] font-extrabold" style={{ color: track.accent }}>
          ${hourly.toFixed(2)}/hr
        </div>
        {showDiscountBadge ? (
          <div
            className={`mt-2 inline-flex w-fit rounded-full px-2.5 py-1.5 text-[11px] font-bold ${
              discountApplied ? "bg-[#ecfdf3] text-[#15803d]" : "bg-[#f3f4f6] text-[#6b7280]"
            }`}
          >
            Lower rate for over 4 hrs/week
          </div>
        ) : null}
        <ul className="mt-3 grid gap-1.5">
          {features.slice(0, 3).map((feature) => (
            <li key={feature} className="flex items-start gap-2 text-xs text-[#4b5563]">
              <CheckCircle2 size={16} className="mt-0.5 shrink-0" style={{ color: track.accent }} />
              <span>{feature}</span>
            </li>
          ))}
        </ul>
        <div className="mt-auto pt-3 text-xs font-semibold text-[#374151]">
          {/* Hourly rate only. Projecting it to a monthly total made the plan
              look like a bill, and rates are negotiated with each family. */}
          {hoursPerWeek} hrs/week · rates are flexible
        </div>
      </div>
      <div className="p-3.5 pt-0">
        <Link
          href={`/enroll/?track=${track.id}&hours=${hoursPerWeek}`}
          className="inline-flex min-h-[46px] w-full items-center justify-center rounded-xl text-sm font-semibold text-white transition hover:brightness-110"
          style={{ backgroundColor: track.accent }}
        >
          Continue with this plan
        </Link>
      </div>
    </div>
  );
}

function hourlyPrice(trackId: string, hoursPerWeek: number, plan: Record<string, unknown>) {
  if (trackId === "islamic") {
    const threshold = Number(plan.islamicDiscountThreshold ?? 4);
    const base = Number(plan.islamicBaseUsd ?? plan.islamicHrUnder5Usd ?? 8.5);
    const discount = Number(plan.islamicDiscountUsd ?? plan.islamicHr5PlusUsd ?? 6.99);
    return hoursPerWeek > threshold ? discount : base;
  }
  if (trackId === "tutoring") {
    const threshold = Number(plan.tutoringDiscountThreshold ?? 4);
    const base = Number(plan.tutoringBaseUsd ?? plan.tutoringHrUnder4Usd ?? 11.99);
    const discount = Number(plan.tutoringDiscountUsd ?? plan.tutoringHr4PlusUsd ?? 9.99);
    return hoursPerWeek > threshold ? discount : base;
  }
  return Number(plan.groupHourlyUsd ?? plan.hourlyUsd ?? 2.5);
}
