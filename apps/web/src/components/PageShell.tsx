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
    <section className="bg-[#001E4E] py-20 text-white">
      <div className="container-shell max-w-4xl text-center">
        <div className="mb-4 text-sm font-black uppercase tracking-[0.16em] text-blue-200">{kicker}</div>
        <h1 className="text-4xl font-black leading-tight md:text-6xl">{title}</h1>
        <p className="mx-auto mt-5 max-w-2xl text-lg leading-8 text-blue-100">{body}</p>
      </div>
    </section>
  );
}
