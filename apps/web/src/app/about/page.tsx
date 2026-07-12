import { AboutContent } from "@/components/AboutContent";
import { SiteHeader } from "@/components/SiteHeader";

export default function AboutPage() {
  return (
    <>
      <SiteHeader />
      <main>
        <AboutContent />
      </main>
      <footer className="bg-[#111827] px-6 py-10 text-center text-sm text-white/55">
        © 2024 Alluwal Education Hub
      </footer>
    </>
  );
}
