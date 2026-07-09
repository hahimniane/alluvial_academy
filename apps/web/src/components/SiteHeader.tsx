"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BookOpen,
  ChevronDown,
  Code2,
  Globe2,
  Landmark,
  Menu,
  School,
  Sigma,
  UsersRound,
  X,
} from "lucide-react";
import { useState } from "react";

const navItems = [
  { href: "/", label: "Home" },
  { href: "/#pricing", label: "Pricing" },
  { href: "/#about", label: "About" },
  { href: "/team/", label: "Our Team" },
  { href: "/contact/", label: "Contact Us" },
];

const megaTracks = [
  {
    href: "/programs/?category=islamic",
    title: "Islamic & AfroLanguages",
    subtitle: "Islamic Studies · AfroLanguages & AdLam",
    icon: Landmark,
    tint: "#1D4ED8",
  },
  {
    href: "/programs/?category=academic",
    title: "Academic & tutoring",
    subtitle: "Math Classes · Programming · After School",
    icon: School,
    tint: "#059669",
  },
  {
    href: "/programs/?category=english",
    title: "Adults & literacy",
    subtitle: "Adult Literacy",
    icon: BookOpen,
    tint: "#D97706",
  },
];

const mobileProgramLinks = [
  { href: "/programs/", label: "All Programs", icon: BookOpen },
  { href: "/programs/?category=islamic", label: "Islamic Studies", icon: Landmark },
  { href: "/programs/?category=languages", label: "AfroLanguages & AdLam", icon: Globe2 },
  { href: "/programs/?category=math", label: "Math Classes", icon: Sigma },
  { href: "/programs/?category=programming", label: "Programming", icon: Code2 },
  { href: "/programs/?category=after-school", label: "After School Tutoring", icon: School },
  { href: "/programs/?category=adult-literacy", label: "Adult Literacy", icon: BookOpen },
];

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  const [megaOpen, setMegaOpen] = useState(false);
  const pathname = usePathname();

  const closeAll = () => {
    setOpen(false);
    setMegaOpen(false);
  };

  return (
    <header className="site-header sticky top-0 z-50 bg-white shadow-[0_2px_10px_rgba(0,0,0,0.02)]">
      <div className="bg-[linear-gradient(90deg,#0B1B3A_0%,#1D4ED8_48%,#F59E0B_120%)] text-white">
        <div className="flex items-center gap-3 px-3 py-[3px] md:px-5 md:py-[5px]">
          <Link
            href="/enroll/"
            className="inline-flex min-h-0 items-center rounded-full border border-white/70 bg-white/12 px-2.5 py-0 text-[10.5px] font-bold leading-[1.45] tracking-[0.3px] shadow-[0_8px_24px_rgba(0,0,0,0.12)] backdrop-blur transition hover:bg-white/20 md:px-3.5 md:py-1 md:text-[11.5px]"
          >
            Sign Up For New Class
          </Link>
          <div className="ml-auto hidden text-right text-[10px] font-semibold leading-tight text-white/90 xl:block">
            <div>Faith-centered learning online.</div>
            <div className="font-medium text-white/75">Islamic, African & academic paths.</div>
          </div>
        </div>
      </div>

      <div className="border-b border-slate-100 bg-white/95 backdrop-blur">
        <div className="flex min-h-[55px] items-center gap-3 px-3 py-1.5 md:px-5">
          <Link href="/" className="flex shrink-0 items-center gap-3" aria-label="Alluwal Education Hub home">
            <img
              src="/assets/Alluwal_Education_Hub_Logo.png"
              alt=""
              className="h-8 w-[124px] object-contain lg:h-9 lg:w-[158px]"
            />
            <div className="hidden leading-tight lg:block">
              <div className="text-lg font-black tracking-normal text-[#111827]">Alluwal</div>
              <div className="text-[9px] font-semibold uppercase tracking-[1.5px] text-[#3B82F6]">Education Hub</div>
            </div>
          </Link>

          <nav className="ml-3 hidden items-center gap-3 xl:flex" aria-label="Primary navigation">
            <Link
              href="/"
              className="text-[13.5px] font-semibold text-[#111827] transition hover:text-[#0386FF]"
              onClick={closeAll}
            >
              Home
            </Link>

            <div
              className="relative"
              onMouseEnter={() => setMegaOpen(true)}
              onMouseLeave={() => setMegaOpen(false)}
            >
              <button
                type="button"
                className="flex min-h-[44px] items-center gap-1 bg-transparent px-0 text-[13.5px] font-semibold text-[#111827]"
                onClick={() => setMegaOpen((value) => !value)}
                aria-expanded={megaOpen}
              >
                Courses
                <ChevronDown
                  size={17}
                  className={`transition-transform ${megaOpen ? "rotate-180" : ""}`}
                />
              </button>

              {megaOpen ? (
                <div className="absolute left-1/2 top-[42px] w-[920px] -translate-x-1/2 pt-4">
                  <div className="menu-pop rounded-2xl border border-slate-200 bg-white p-5 shadow-2xl shadow-slate-900/14">
                    <div className="grid gap-3 md:grid-cols-3">
                      {megaTracks.map(({ href, title, subtitle, icon: Icon, tint }) => (
                        <Link
                          key={title}
                          href={href}
                          className="flex gap-3 rounded-xl px-3.5 py-3.5 transition hover:bg-slate-100"
                          onClick={closeAll}
                        >
                          <span
                            className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
                            style={{ backgroundColor: `${tint}1f`, color: tint }}
                          >
                            <Icon size={22} />
                          </span>
                          <span>
                            <span className="block text-sm font-extrabold text-[#111827]">{title}</span>
                            <span className="mt-1 block text-xs leading-5 text-slate-500">{subtitle}</span>
                          </span>
                        </Link>
                      ))}
                    </div>
                    <div className="mt-4 border-t border-slate-200 pt-3">
                      <div className="flex justify-center gap-3">
                        <Link
                          href="/team/?category=teacher"
                          className="inline-flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold text-[#4F46E5] hover:bg-slate-50"
                          onClick={closeAll}
                        >
                          <UsersRound size={20} />
                          Our Teachers
                        </Link>
                        <Link
                          href="/teacher-application/"
                          className="inline-flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold text-[#4F46E5] hover:bg-slate-50"
                          onClick={closeAll}
                        >
                          Become a Tutor
                        </Link>
                      </div>
                    </div>
                  </div>
                </div>
              ) : null}
            </div>

            {navItems.slice(1).map((item) => {
              const active =
                item.href !== "/" &&
                !item.href.startsWith("/#") &&
                pathname.startsWith(item.href.replace(/\/$/, ""));
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`text-[13.5px] font-semibold transition hover:text-[#0386FF] ${
                    active ? "text-[#0386FF]" : "text-[#111827]"
                  }`}
                  onClick={closeAll}
                >
                  {item.label}
                </Link>
              );
            })}

            <Link
              href="/login/"
              className="ml-1 inline-flex min-h-[42px] items-center rounded-[10px] bg-[#111827] px-[18px] text-[13px] font-semibold text-white transition hover:bg-[#0b1220]"
              onClick={closeAll}
            >
              Log In
            </Link>
          </nav>

          <div className="ml-auto flex items-center gap-1 xl:hidden">
            <Link
              href="/login/"
              className="rounded-md px-2 py-1 text-[13px] font-bold tracking-[0.2px] text-[#111827]"
              onClick={closeAll}
            >
              Log In
            </Link>
            <button
                type="button"
                className="inline-flex h-10 w-10 items-center justify-center rounded-md text-[#111827]"
                aria-label="Open navigation menu"
              aria-expanded={open}
              onClick={() => setOpen((value) => !value)}
            >
              {open ? <X size={26} /> : <Menu size={26} />}
            </button>
          </div>
        </div>
      </div>

      {open ? (
        <div className="menu-pop border-b border-slate-200 bg-white xl:hidden">
          <nav className="grid gap-1 px-3 py-4" aria-label="Mobile navigation">
            <Link href="/" className="rounded-md px-3 py-3 text-base font-extrabold text-slate-900" onClick={closeAll}>
              Home
            </Link>
            <div className="rounded-md bg-slate-50 p-2">
              <div className="px-2 pb-2 text-xs font-black uppercase tracking-[0.14em] text-slate-500">Courses</div>
              {mobileProgramLinks.map(({ href, label, icon: Icon }) => (
                <Link
                  key={label}
                  href={href}
                  className="flex items-center gap-3 rounded-md px-2 py-3 text-sm font-bold text-slate-800"
                  onClick={closeAll}
                >
                  <Icon size={18} className="text-[#1D4ED8]" />
                  {label}
                </Link>
              ))}
            </div>
            {navItems.slice(1).map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="rounded-md px-3 py-3 text-base font-extrabold text-slate-900"
                onClick={closeAll}
              >
                {item.label}
              </Link>
            ))}
            <Link
              href="/teacher-application/"
              className="rounded-md px-3 py-3 text-base font-extrabold text-slate-900"
              onClick={closeAll}
            >
              Become a Tutor
            </Link>
            <Link
              href="/team/?category=teacher"
              className="rounded-md px-3 py-3 text-base font-extrabold text-slate-900"
              onClick={closeAll}
            >
              Our Teachers
            </Link>
          </nav>
        </div>
      ) : null}
    </header>
  );
}
