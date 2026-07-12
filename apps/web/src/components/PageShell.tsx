import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";

export function PageShell({ children }: { children: React.ReactNode }) {
  return (
    <>
      <SiteHeader />
      <main>{children}</main>
      <SiteFooter />
    </>
  );
}

export function PageHero({
  kicker,
  title,
  body,
}: {
  kicker: string;
  title: string;
  body: string;
}) {
  return (
    <section className="relative overflow-hidden bg-[#001E4E] py-20 text-white">
      <div
        className="absolute inset-0 bg-[radial-gradient(circle_at_18%_20%,rgba(29,78,216,0.45),transparent_42%),radial-gradient(circle_at_82%_78%,rgba(245,158,11,0.18),transparent_38%)]"
        aria-hidden="true"
      />
      <div className="container-shell relative max-w-4xl text-center">
        <div className="mb-4 text-sm font-black uppercase tracking-[0.16em] text-[#FBBF24]">{kicker}</div>
        <h1 className="font-display text-4xl font-bold leading-tight md:text-6xl">{title}</h1>
        <p className="mx-auto mt-5 max-w-2xl text-lg leading-8 text-blue-100">{body}</p>
      </div>
    </section>
  );
}
