import { LeadershipApplicationForm } from "@/components/ApplicationForms";
import { PageShell } from "@/components/PageShell";

export default function LeadershipApplicationPage() {
  return (
    <PageShell>
      <section className="bg-[#F8FAFC] px-4 py-10">
        <div className="container-shell">
          <LeadershipApplicationForm />
        </div>
      </section>
    </PageShell>
  );
}
