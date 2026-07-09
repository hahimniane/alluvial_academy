import { LeadershipApplicationForm } from "@/components/ApplicationForms";
import { SiteHeader } from "@/components/SiteHeader";

export default function LeadershipApplicationPage() {
  return (
    <>
      <SiteHeader />
      <main>
        <section className="min-h-[calc(100vh-92px)] bg-[#F8FAFC] px-4 py-10">
          <div className="container-shell">
            <LeadershipApplicationForm />
          </div>
        </section>
      </main>
    </>
  );
}
