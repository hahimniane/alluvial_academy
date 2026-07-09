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
  School,
  UsersRound,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState, type CSSProperties, type PointerEvent } from "react";
import { Reveal } from "@/components/Reveal";
import { fallbackPricing, loadPublicMarketingBundle, type PublicSiteMarketingBundle } from "@/lib/publicSiteCms";

function enterDelay(ms: number) {
  return { "--enter-delay": `${ms}ms` } as CSSProperties;
}

const subjects = [
  "Islamic Program (Arabic, Quran, etc...)",
  "AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)",
  "After School Tutoring (Math, Science, Physics, etc...)",
  "Adult Literacy (Reading and Writing English & French, etc...)",
  "Coding",
  "Entrepreneurship",
];

const courseColumns = [
  {
    title: "Islamic & AfroLanguages",
    color: "#2563EB",
    items: [
      {
        title: "Islamic Studies",
        subtitle: "Quran, Arabic, Tawhid, Hadith, Tafsir",
        href: "/programs/?category=islamic",
        icon: MoonStar,
      },
      {
        title: "AfroLanguages & AdLam",
        subtitle: "Pular, Mandingo, Swahili, Wolof, Yoruba",
        href: "/programs/?category=languages",
        icon: Languages,
      },
    ],
  },
  {
    title: "Academic & tutoring",
    color: "#F59E0B",
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
    title: "Islamic & AdLam",
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

const aboutCards = [
  {
    title: "Our Mission",
    body: "To integrate Islamic, African, and Western education, offering a holistic curriculum that prepares students to navigate and succeed in a diverse world.",
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

  const landing = bundle?.landing;
  const pricing = bundle?.pricing ?? fallbackPricing;
  const heroMain = landing?.heroMainImageUrl || "/assets/background_images/smiling_student.jpg";
  const heroLeft = landing?.heroLeftImageUrl || "/assets/teachers/elham_shifa.jpg";
  const heroRight = landing?.heroRightImageUrl || "/assets/teachers/mohammed_kosiah.jpg";

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
              className="hero-enter max-w-3xl text-[38px] font-black leading-[1.05] tracking-normal text-[#0B1B3A] md:text-[60px] md:leading-[0.98]"
              style={enterDelay(90)}
            >
              Learn with tutors who know your child by name.
            </h1>
            <p
              className="hero-enter mt-5 max-w-2xl text-[16px] leading-[1.7] text-[#475569] md:text-[18px]"
              style={enterDelay(180)}
            >
              Quran, languages, math, coding, and literacy support in one warm online learning space for families around the world.
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
              <span className="inline-flex items-center rounded-full bg-white/70 px-3 py-1.5 shadow-[0_10px_24px_rgba(15,23,42,0.06)]">Quran</span>
              <span className="inline-flex items-center rounded-full bg-white/70 px-3 py-1.5 shadow-[0_10px_24px_rgba(15,23,42,0.06)]">Math</span>
              <span className="inline-flex items-center rounded-full bg-white/70 px-3 py-1.5 shadow-[0_10px_24px_rgba(15,23,42,0.06)]">Languages</span>
              <span className="inline-flex items-center rounded-full bg-white/70 px-3 py-1.5 shadow-[0_10px_24px_rgba(15,23,42,0.06)]">Coding</span>
            </div>
          </div>

          <div
            className="hero-enter relative mx-auto h-[285px] w-full max-w-[500px] lg:-top-2 lg:mx-0 lg:h-[430px] lg:max-w-none"
            style={enterDelay(320)}
          >
            <div className="hero-collage-float relative h-full w-full">
              <LearningPathMotion />
              <div className="hero-photo-card absolute right-5 top-2 z-10 h-[220px] w-[78%] overflow-hidden rounded-[30px] bg-white p-3 shadow-[0_30px_90px_rgba(15,23,42,0.18)] lg:top-8 lg:h-[310px] lg:w-[420px]">
                <div className="h-full overflow-hidden rounded-[24px]">
                  <img src={heroMain} alt="Smiling student learning online" className="h-full w-full object-cover" />
                </div>
              </div>
              <div className="hero-badge-float absolute left-1 top-[18px] z-20 rounded-3xl border border-white bg-white/86 p-3 shadow-[0_20px_50px_rgba(15,23,42,0.12)] backdrop-blur md:left-0 lg:top-[42px] lg:p-4">
                <div className="flex items-center gap-3">
                  <span className="inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-[#DBEAFE] text-[#2563EB]">
                    <MoonStar size={23} />
                  </span>
                  <span>
                    <span className="block text-sm font-black text-[#0B1B3A]">Quran + academics</span>
                    <span className="block text-xs font-semibold text-[#64748B]">One trusted place</span>
                  </span>
                </div>
              </div>
              <div className="absolute bottom-[54px] left-0 z-20 h-[110px] w-[110px] overflow-hidden rounded-[28px] border-[5px] border-white bg-[#EFF6FF] shadow-[0_22px_60px_rgba(15,23,42,0.16)] md:h-[132px] md:w-[132px] lg:bottom-[92px] lg:h-40 lg:w-40">
                <img src={heroLeft} alt="Teacher profile" className="h-full w-full object-cover" />
              </div>
              <div className="absolute bottom-8 right-2 z-20 h-[104px] w-[104px] overflow-hidden rounded-full border-[5px] border-white bg-[#FEF3C7] shadow-[0_22px_60px_rgba(15,23,42,0.16)] md:h-[122px] md:w-[122px] lg:h-[148px] lg:w-[148px]">
                <img src={heroRight} alt="Teacher profile" className="h-full w-full object-cover" />
              </div>
              <div className="hero-badge-float absolute bottom-0 left-[92px] z-30 rounded-3xl border border-white bg-[#0B1B3A] px-4 py-3 text-white shadow-[0_24px_70px_rgba(15,23,42,0.22)] md:left-[126px] lg:px-5 lg:py-4">
                <div className="text-[28px] font-black leading-none">5★</div>
                <div className="mt-1 text-xs font-bold text-white/72">family-rated classes</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="programs" className="bg-[#F8FAFC] py-14 md:py-16">
        <div className="container-shell text-center">
          <Reveal>
            <h2 className="text-[26px] font-bold text-[#1e3a5f] md:text-[32px]">Explore Our Main Courses</h2>
            <p className="mx-auto mt-3 max-w-[700px] text-base leading-[1.6] text-[#6b7280]">
              Discover comprehensive learning paths designed for non-Arabic speakers to master the Quran, Islamic Studies, and Arabic language.
            </p>
          </Reveal>

          <div className="mt-9 grid gap-6 text-left lg:grid-cols-2">
            {courseColumns.map((column, columnIndex) => (
              <Reveal key={column.title} delay={columnIndex * 140}>
                <div className="hover-lift overflow-hidden rounded-2xl border border-[#e5e7eb] bg-white shadow-[0_4px_12px_rgba(0,0,0,0.06)]">
                  <div className="px-5 py-4 text-base font-bold text-white" style={{ backgroundColor: column.color }}>
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
            <h2 className="text-[26px] font-bold text-[#1a1a1a] md:text-[32px]">Transparent & Affordable Rates</h2>
            <p className="mx-auto mt-3 max-w-[700px] text-base leading-[1.6] text-[#6b6560]">
              Choose the plan that fits your schedule. All prices are informational - contact us to enroll.
            </p>
          </Reveal>

          <div className="mt-7 flex flex-wrap justify-center gap-2">
            {Array.from({ length: 8 }, (_, index) => index + 1).map((hour) => {
              const selected = hour === hoursPerWeek;
              return (
                <button
                  key={hour}
                  type="button"
                  className={`rounded-full border px-3.5 py-2 text-sm font-semibold transition ${
                    selected
                      ? "border-[#1e88e5] bg-[#1e88e5] text-white"
                      : "border-slate-300 bg-white text-slate-700 hover:border-[#1e88e5]"
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
              <Reveal key={track.id} delay={index * 120}>
                <PricingCard
                  track={track}
                  hoursPerWeek={hoursPerWeek}
                  pricing={pricing}
                />
              </Reveal>
            ))}
          </div>

          <Reveal>
          <div className="mx-auto mt-10 max-w-4xl rounded-xl border border-[#ffc107] bg-[#fff3cd] p-5">
            <p className="text-[15px] font-bold text-[#c62828]">
              Payment must be made at the beginning of each month, not at the end.
            </p>
            <p className="mt-2 text-sm leading-[1.5] text-[#374151]">
              Payment methods: Zelle (646-338-1286), MoneyGram, Bank Transfer, CashApp, or Western Union.
            </p>
          </div>

          <div className="mt-4 inline-flex rounded-full bg-[#dbeafe] px-5 py-2.5 text-[13px] font-semibold text-[#1e40af]">
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

      <section id="about" className="bg-white px-6 py-14">
        <div className="mx-auto max-w-[1200px] text-center">
          <Reveal>
            <h2 className="text-[32px] font-extrabold leading-tight text-[#111827] md:text-[42px]">
              About Alluwal Education Hub
            </h2>
            <p className="mx-auto mt-4 max-w-[700px] text-[18px] leading-[1.6] text-[#6B7280]">
              We are fostering a world where diverse knowledge—Islamic, African, and Western—comes together to prepare students for a globalized future.
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
                  <h3 className="mt-7 text-2xl font-extrabold text-[#111827]">{title}</h3>
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
            <h2 className="text-[32px] font-extrabold leading-tight md:text-[42px]">Ready to start learning?</h2>
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
    <div className="hover-lift mx-auto flex h-[448px] w-full max-w-[390px] flex-col overflow-hidden rounded-[18px] border border-[#ebe8e3] bg-white text-left shadow-[0_4px_14px_rgba(0,0,0,0.06)]">
      <div className="h-2" style={{ backgroundColor: track.accent }} />
      <div className="flex min-h-0 flex-1 flex-col p-4 pb-2">
        <Icon size={24} style={{ color: track.accent }} />
        <h3 className="mt-2.5 font-serif text-lg font-bold text-[#111827]">{track.title}</h3>
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
        <div className="mt-auto text-xs font-semibold text-[#374151]">
          {hoursPerWeek} hrs x ${hourly.toFixed(2)}/hr x {track.id === "group" ? "4.33" : "4"} weeks ≈ ${monthly.toFixed(0)}/mo
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
