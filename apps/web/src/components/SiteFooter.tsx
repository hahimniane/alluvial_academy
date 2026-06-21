import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="bg-[#001E4E] text-white">
      <div className="container-shell grid gap-8 py-12 md:grid-cols-[1.3fr_1fr_1fr]">
        <div>
          <div className="flex items-center gap-3">
            <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="" className="h-12 w-12 rounded-lg bg-white object-contain" />
            <div>
              <div className="text-lg font-black">Alluwal Education Hub</div>
              <div className="text-sm text-blue-100">Learning with faith, identity, and excellence.</div>
            </div>
          </div>
          <p className="mt-5 max-w-md text-sm leading-7 text-blue-100">
            Online education for Islamic studies, academic tutoring, languages, and student growth.
          </p>
        </div>
        <div>
          <div className="mb-3 text-sm font-black uppercase tracking-[0.12em] text-blue-200">Explore</div>
          <div className="grid gap-2 text-sm text-blue-50">
            <Link href="/programs/">Programs</Link>
            <Link href="/team/">Team</Link>
            <Link href="/about/">About</Link>
            <Link href="/contact/">Contact</Link>
          </div>
        </div>
        <div>
          <div className="mb-3 text-sm font-black uppercase tracking-[0.12em] text-blue-200">Apply</div>
          <div className="grid gap-2 text-sm text-blue-50">
            <Link href="/teacher-application/">Teacher application</Link>
            <Link href="/leadership-application/">Leadership application</Link>
            <Link href="/login/">Staff login</Link>
          </div>
        </div>
      </div>
      <div className="border-t border-white/10 py-5">
        <div className="container-shell text-sm text-blue-100">
          © {new Date().getFullYear()} Alluwal Education Hub. All rights reserved.
        </div>
      </div>
    </footer>
  );
}
