import Link from "next/link";
import { flutterLoginUrl } from "@/lib/flutterApp";

const exploreLinks = [
  { href: "/programs/", label: "Programs" },
  { href: "/team/", label: "Team" },
  { href: "/about/", label: "About" },
  { href: "/contact/", label: "Contact" },
  { href: "/privacy-policy/", label: "Privacy Policy" },
];

const applyLinks = [
  { href: "/teacher-application/", label: "Teacher application" },
  { href: "/leadership-application/", label: "Leadership application" },
  { href: flutterLoginUrl, label: "Staff login", external: true },
];

export function SiteFooter() {
  return (
    <footer className="relative bg-[#001E4E] text-white">
      <div
        className="h-[3px] w-full bg-[linear-gradient(90deg,#F59E0B_0%,#1D4ED8_55%,#001E4E_100%)]"
        aria-hidden="true"
      />
      <div className="container-shell grid gap-10 py-14 md:grid-cols-[1.4fr_1fr_1fr_1.1fr]">
        <div>
          <div className="flex items-center gap-3">
            <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="" className="h-12 w-12 rounded-xl bg-white object-contain p-1" />
            <div>
              <div className="font-display text-xl font-bold">Alluwal Education Hub</div>
              <div className="text-sm text-blue-200/90">Learning with identity, excellence, and purpose.</div>
            </div>
          </div>
          <p className="mt-5 max-w-md text-sm leading-7 text-blue-100/85">
            Online education for tutoring, languages, entrepreneurship, and faith studies — taught live by
            tutors who know every student by name.
          </p>
        </div>
        <div>
          <div className="mb-4 text-xs font-black uppercase tracking-[0.16em] text-[#FBBF24]">Explore</div>
          <div className="grid gap-2.5 text-sm">
            {exploreLinks.map(({ href, label }) => (
              <Link key={href} href={href} className="w-fit text-blue-100/85 transition hover:text-white">
                {label}
              </Link>
            ))}
          </div>
        </div>
        <div>
          <div className="mb-4 text-xs font-black uppercase tracking-[0.16em] text-[#FBBF24]">Apply</div>
          <div className="grid gap-2.5 text-sm">
            {applyLinks.map(({ href, label, external }) =>
              external ? (
                // Login lives in the Flutter app on the main domain, so this
                // leaves the Next site rather than routing within it.
                <a key={href} href={href} className="w-fit text-blue-100/85 transition hover:text-white">
                  {label}
                </a>
              ) : (
                <Link key={href} href={href} className="w-fit text-blue-100/85 transition hover:text-white">
                  {label}
                </Link>
              )
            )}
          </div>
        </div>
        <div>
          <div className="mb-4 text-xs font-black uppercase tracking-[0.16em] text-[#FBBF24]">Get in touch</div>
          <div className="grid gap-2.5 text-sm text-blue-100/85">
            <a href="https://wa.me/16468728590" className="w-fit transition hover:text-white">
              WhatsApp: (+1) 646-872-8590
            </a>
            <a href="mailto:alluwalacademy@gmail.com" className="w-fit transition hover:text-white">
              alluwalacademy@gmail.com
            </a>
          </div>
          <Link
            href="/enroll/"
            className="mt-5 inline-flex min-h-[42px] items-center justify-center rounded-full bg-white px-6 text-sm font-bold text-[#001E4E] transition hover:bg-blue-50"
          >
            Enroll a Student
          </Link>
        </div>
      </div>
      <div className="border-t border-white/10 py-5">
        <div className="container-shell flex flex-wrap items-center justify-between gap-3 text-sm text-blue-100/75">
          <span>© {new Date().getFullYear()} Alluwal Education Hub. All rights reserved.</span>
          <span className="text-blue-100/60">Tutoring · Languages · Math · Coding · Enterprise · Faith</span>
        </div>
      </div>
    </footer>
  );
}
