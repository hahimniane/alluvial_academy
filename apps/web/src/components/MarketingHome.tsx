"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  BookOpen,
  Check,
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
import { useEffect, useMemo, useState } from "react";
import { fallbackPricing, loadPublicMarketingBundle, type PublicSiteMarketingBundle } from "@/lib/publicSiteCms";

const subjects = [
  "Islamic Program (Arabic, Quran, etc...)",
  "AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)",
  "After School Tutoring (Math, Science, Physics, etc...)",
  "Adult Literacy (Reading and Writing English & French, etc...)",
  "Coding",
  "Entrepreneurship",
];

const quickCategories = [
  { href: "/programs/?category=islamic", label: "Islamic Studies" },
  { href: "/programs/?category=languages", label: "Languages" },
  { href: "/programs/?category=adult-literacy", label: "Adult Literacy" },
  { href: "/programs/?category=after-school", label: "After School Tutoring" },
  { href: "/programs/?category=math", label: "Maths" },
  { href: "/programs/?category=programming", label: "Programming" },
  { href: "/programs/?category=english", label: "English (Students)" },
];

const courseColumns = [
  {
    title: "Islamic & AfroLanguages",
    color: "#1e88e5",
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
    color: "#43a047",
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
    accent: "#2563eb",
    icon: MoonStar,
    defaults: ["1-on-1 Quran, Arabic, and AdLam", "Flexible weekday scheduling", "Discount at 4+ hours/week"],
  },
  {
    id: "tutoring",
    title: "Tutoring & Literacy",
    subtitle: "1 hour sessions",
    accent: "#16a34a",
    icon: School,
    defaults: ["Math, science, literacy support", "Personalized one-on-one coaching", "Discount at 4+ hours/week"],
  },
  {
    id: "group",
    title: "Group Classes",
    subtitle: "Fri / Sat / Sun, 2 hours per day",
    accent: "#7c3aed",
    icon: UsersRound,
    defaults: ["Weekend group classes", "Flat hourly rate", "Community learning setting"],
  },
];

const featureItems = [
  "Meet the tutor. Try for free",
  "Get help with your quran and islamic studies",
  "Get help from our engineers and programmers",
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
    color: "#10B981",
    icon: Eye,
  },
];

export function MarketingHome() {
  const router = useRouter();
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
  const heroColor = landing?.heroBackgroundColorHex || "#00484E";
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

  return (
    <>
      <section className="relative overflow-hidden text-white" style={{ backgroundColor: heroColor }}>
        <div className="mx-auto grid max-w-[1200px] items-center gap-9 px-6 pb-10 pt-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:gap-12 lg:py-12">
          <div>
            <h1 className="max-w-3xl whitespace-pre-line text-[30px] font-bold leading-[1.22] tracking-normal md:text-5xl md:leading-[1.2]">
              Learn with online tutoring{"\n"}from anywhere in the world
            </h1>
            <p className="mt-4 max-w-2xl text-[15px] leading-[1.45] text-white/88 md:mt-5 md:text-base">
              Browse the full catalog, set your hours, and learn online with qualified tutors.
            </p>

            <div className="mt-7">
              <Link
                href="/programs/"
                className="inline-flex min-h-[39px] w-full items-center justify-center gap-2 rounded-full bg-white px-7 text-base font-bold shadow-lg shadow-black/20 transition hover:-translate-y-0.5 sm:w-auto md:min-h-[44px] md:px-9"
                style={{ color: heroColor }}
              >
                <Grid3X3 size={21} />
                Explore Our Programs
              </Link>
            </div>

            <form
              className="relative mt-5 max-w-[600px]"
              onSubmit={(event) => {
                event.preventDefault();
                if (query.trim()) selectSubject(query.trim());
              }}
            >
              <div className="flex h-[46px] items-center rounded-full bg-white shadow-lg shadow-black/10 md:h-[50px]">
                <input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  className="h-full min-w-0 flex-1 rounded-full border-0 bg-transparent px-5 text-[14px] text-slate-900 outline-none placeholder:text-[#9CA3AF] md:px-6 md:text-[15px]"
                  placeholder="What would you like to learn?"
                  aria-label="What would you like to learn?"
                />
                <button
                  type="submit"
                  className="mr-3 inline-flex h-9 w-9 items-center justify-center rounded-full text-[#3B82F6]"
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
              className="mt-3 inline-flex min-h-[42px] items-center gap-2 rounded-full border border-white/40 px-4 py-2 text-sm font-semibold text-white/95 transition hover:bg-white/10"
            >
              <GraduationCap size={18} />
              Our Teachers
            </Link>

            <div className="mt-[22px] flex flex-wrap gap-x-4 gap-y-3">
              {quickCategories.map((category) => (
                <Link
                  key={category.label}
                  href={category.href}
                  className="text-base font-bold leading-6 text-white transition hover:text-white/78"
                >
                  {category.label}
                </Link>
              ))}
            </div>

            <div className="mt-8 grid gap-2">
              {featureItems.map((item) => (
                <div key={item} className="flex items-start gap-2 text-[15px] leading-6 text-white">
                  <Check size={20} className="mt-0.5 shrink-0" />
                  <span>{item}</span>
                </div>
              ))}
            </div>

            <div className="mt-10">
              <div className="flex flex-wrap items-center gap-3">
                <span className="text-sm font-medium text-white">Excellent</span>
                <div className="flex gap-0.5">
                  {Array.from({ length: 5 }, (_, index) => (
                    <span
                      key={index}
                      className="inline-flex h-6 w-6 items-center justify-center bg-[#00B67A] text-base leading-none text-white"
                    >
                      ★
                    </span>
                  ))}
                </div>
              </div>
              <p className="mt-2 text-xs text-white/80">Trusted by Muslim families worldwide</p>
            </div>
          </div>

          <div className="hero-collage-float relative mx-auto h-[360px] w-full max-w-[520px] lg:-top-5 lg:mx-0 lg:h-[450px] lg:max-w-none">
            <div className="absolute bottom-[58px] right-8 top-5 w-[76%] overflow-hidden rounded-[40px_40px_100px_40px] border-4 border-white bg-white shadow-2xl shadow-black/20 lg:bottom-[60px] lg:right-10 lg:w-[400px]">
              <img src={heroMain} alt="Smiling student learning online" className="h-full w-full object-cover" />
            </div>
            <div
              className="absolute bottom-[70px] left-0 h-[132px] w-[132px] overflow-hidden rounded-full border-4 bg-[#A5D6A7] md:bottom-20 md:h-40 md:w-40"
              style={{ borderColor: heroColor }}
            >
              <img src={heroLeft} alt="Teacher profile" className="h-full w-full object-cover" />
            </div>
            <div
              className="absolute bottom-8 right-0 h-[118px] w-[118px] overflow-hidden rounded-[999px_999px_10px_999px] border-4 bg-[#FFE082] md:bottom-10 md:h-[140px] md:w-[140px]"
              style={{ borderColor: heroColor }}
            >
              <img src={heroRight} alt="Teacher profile" className="h-full w-full object-cover" />
            </div>
          </div>
        </div>
      </section>

      <section id="programs" className="bg-white py-12 md:py-[52px]">
        <div className="container-shell text-center">
          <h2 className="text-[26px] font-bold text-[#1e3a5f] md:text-[32px]">Explore Our Main Courses</h2>
          <p className="mx-auto mt-3 max-w-[700px] text-base leading-[1.6] text-[#6b7280]">
            Discover comprehensive learning paths designed for non-Arabic speakers to master the Quran, Islamic Studies, and Arabic language.
          </p>

          <div className="mt-9 grid gap-6 text-left lg:grid-cols-2">
            {courseColumns.map((column) => (
              <div
                key={column.title}
                className="overflow-hidden rounded-2xl border border-[#e5e7eb] bg-white shadow-[0_4px_12px_rgba(0,0,0,0.06)]"
              >
                <div className="px-5 py-4 text-base font-bold text-white" style={{ backgroundColor: column.color }}>
                  {column.title}
                </div>
                <div>
                  {column.items.map(({ title, subtitle, href, icon: Icon }, index) => (
                    <Link
                      key={title}
                      href={href}
                      className={`flex h-[72px] items-center px-5 transition hover:bg-[#f9fafb] ${
                        index < column.items.length - 1 ? "border-b border-slate-100" : ""
                      }`}
                    >
                      <Icon size={22} className="shrink-0" style={{ color: column.color }} />
                      <span className="ml-3.5 min-w-0 flex-1">
                        <span className="block truncate text-[15px] font-semibold text-[#1f2937]">{title}</span>
                        <span className="mt-1 block line-clamp-2 text-xs leading-[1.35] text-[#6b7280]">{subtitle}</span>
                      </span>
                      <ChevronRight size={20} className="ml-3 shrink-0 text-slate-400" />
                    </Link>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="pricing" className="bg-[#F7F5F2] py-12 md:py-[52px]">
        <div className="container-shell text-center">
          <h2 className="text-[26px] font-bold text-[#1a1a1a] md:text-[32px]">Transparent & Affordable Rates</h2>
          <p className="mx-auto mt-3 max-w-[700px] text-base leading-[1.6] text-[#6b6560]">
            Choose the plan that fits your schedule. All prices are informational - contact us to enroll.
          </p>

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
            {pricingTracks.map((track) => (
              <PricingCard
                key={track.id}
                track={track}
                hoursPerWeek={hoursPerWeek}
                pricing={pricing}
              />
            ))}
          </div>

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
        </div>
      </section>

      <section id="about" className="bg-white px-6 py-14">
        <div className="mx-auto max-w-[1200px] text-center">
          <h2 className="text-[32px] font-extrabold leading-tight text-[#111827] md:text-[42px]">
            About Alluwal Education Hub
          </h2>
          <p className="mx-auto mt-4 max-w-[700px] text-[18px] leading-[1.6] text-[#6B7280]">
            We are fostering a world where diverse knowledge—Islamic, African, and Western—comes together to prepare students for a globalized future.
          </p>

          <div className="mt-12 grid gap-6 lg:grid-cols-2">
            {aboutCards.map(({ title, body, color, icon: Icon }) => (
              <article
                key={title}
                className="rounded-[20px] border border-[#E5E7EB] bg-white p-8 text-left shadow-[0_10px_30px_rgba(15,23,42,0.04)]"
              >
                <span
                  className="inline-flex h-16 w-16 items-center justify-center rounded-2xl"
                  style={{ backgroundColor: `${color}1a`, color }}
                >
                  <Icon size={34} />
                </span>
                <h3 className="mt-7 text-2xl font-extrabold text-[#111827]">{title}</h3>
                <p className="mt-4 text-[16px] leading-[1.7] text-[#6B7280]">{body}</p>
              </article>
            ))}
          </div>

          <Link
            href="/about/"
            className="mt-10 inline-flex min-h-[48px] items-center justify-center rounded-xl bg-[#001E4E] px-10 text-base font-bold text-white shadow-[0_6px_14px_rgba(0,30,78,0.25)]"
          >
            Learn More About Us
          </Link>
        </div>
      </section>

      <section id="contact" className="bg-gradient-to-br from-[#001E4E] to-[#003399] py-14 text-white">
        <div className="container-shell grid gap-6 md:grid-cols-[1fr_auto] md:items-center">
          <div>
            <h2 className="text-[32px] font-extrabold leading-tight md:text-[42px]">Ready to start learning?</h2>
            <p className="mt-4 max-w-3xl text-lg leading-8 text-white/82">
              Explore our programs and get in touch when you are ready to enroll.
            </p>
          </div>
          <Link href="/programs/" className="alluwal-button bg-white text-[#001E4E] hover:bg-white/92">
            Explore Our Programs
          </Link>
        </div>
      </section>
    </>
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
    <div className="mx-auto flex h-[448px] w-full max-w-[390px] flex-col overflow-hidden rounded-[18px] border border-[#ebe8e3] bg-white text-left shadow-[0_4px_14px_rgba(0,0,0,0.06)]">
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
          className="inline-flex min-h-[46px] w-full items-center justify-center rounded-xl text-sm font-semibold text-white"
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
